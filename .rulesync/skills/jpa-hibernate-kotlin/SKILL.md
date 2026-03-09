---
name: jpa-hibernate-kotlin
description: "Kotlin implementation patterns for JPA/Hibernate. Use with `jpa-hibernate` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# JPA / Hibernate — Kotlin

Prerequisites: load `jpa-hibernate` skill for foundational concepts.

## Entity Design

### Kotlin Entity

```kotlin
@Entity
@Table(name = "users")
class User(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @Column(nullable = false, unique = true)
    val email: String,

    @Column(nullable = false)
    val name: String,

    @Column(nullable = false)
    val active: Boolean = true,

    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: OffsetDateTime = OffsetDateTime.now(),

    @Column(name = "updated_at", nullable = false)
    var updatedAt: OffsetDateTime = OffsetDateTime.now(),

    @Version
    val version: Long = 0
)
```

**Kotlin plugins required:**

```kotlin
// build.gradle.kts
plugins {
    kotlin("plugin.jpa") version "2.0.0"     // no-arg constructor
    kotlin("plugin.allopen") version "2.0.0"  // open classes for proxying
}

allOpen {
    annotation("jakarta.persistence.Entity")
    annotation("jakarta.persistence.Embeddable")
    annotation("jakarta.persistence.MappedSuperclass")
}
```

### ID Generation Strategies

```kotlin
// UUID generation (Hibernate 6.2+)
@Id
@UuidGenerator
val id: UUID? = null

// Sequence with allocation size for batch performance
@Id
@GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "user_seq")
@SequenceGenerator(name = "user_seq", sequenceName = "user_id_seq", allocationSize = 50)
val id: Long? = null
```

## Column Mapping

### @Enumerated

```kotlin
// String storage (preferred -- survives enum reordering)
@Enumerated(EnumType.STRING)
@Column(nullable = false)
val status: OrderStatus = OrderStatus.PENDING

// Or use a converter for custom DB values
@Convert(converter = OrderStatusConverter::class)
val status: OrderStatus = OrderStatus.PENDING
```

```kotlin
@Converter(autoApply = true)
class OrderStatusConverter : AttributeConverter<OrderStatus, String> {
    override fun convertToDatabaseColumn(attribute: OrderStatus): String = attribute.dbValue
    override fun convertToEntityAttribute(dbData: String): OrderStatus =
        OrderStatus.entries.first { it.dbValue == dbData }
}
```

### @Embedded

```kotlin
@Embeddable
data class Address(
    val street: String = "",
    val city: String = "",
    val zipCode: String = "",
    val country: String = ""
)

@Entity
@Table(name = "users")
class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @Embedded
    val address: Address = Address()
)
```

## Relationships

### @ManyToOne / @OneToMany (Most Common)

```kotlin
// Parent side (User)
@Entity
@Table(name = "users")
class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    val name: String,

    @OneToMany(mappedBy = "user", cascade = [CascadeType.ALL], orphanRemoval = true)
    val orders: MutableList<Order> = mutableListOf()
) {
    fun addOrder(order: Order) {
        orders.add(order)
        // order.user is set via constructor
    }
}

// Child side (Order)
@Entity
@Table(name = "orders")
class Order(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @ManyToOne(fetch = FetchType.LAZY) // ALWAYS LAZY
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    val total: BigDecimal
)
```

### @ManyToMany

```kotlin
@Entity
@Table(name = "users")
class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @ManyToMany
    @JoinTable(
        name = "user_roles",
        joinColumns = [JoinColumn(name = "user_id")],
        inverseJoinColumns = [JoinColumn(name = "role_id")]
    )
    val roles: MutableSet<Role> = mutableSetOf()
)
```

## N+1 Prevention

### The Problem

```kotlin
// This triggers N+1: 1 query for users, N queries for orders
val users = userRepository.findAll()
users.forEach { println(it.orders.size) } // Each access fires a query
```

### Solution 1: JOIN FETCH (JPQL)

```kotlin
interface UserRepository : JpaRepository<User, Long> {
    @Query("SELECT u FROM User u JOIN FETCH u.orders WHERE u.active = true")
    fun findActiveUsersWithOrders(): List<User>
}
```

### Solution 2: @EntityGraph

```kotlin
interface UserRepository : JpaRepository<User, Long> {
    @EntityGraph(attributePaths = ["orders"])
    fun findByActiveTrue(): List<User>

    @EntityGraph(attributePaths = ["orders", "orders.items"])
    fun findByIdWithOrdersAndItems(id: Long): User?
}
```

### Solution 3: @BatchSize

```kotlin
@OneToMany(mappedBy = "user")
@BatchSize(size = 20) // Loads orders for up to 20 users in one query
val orders: MutableList<Order> = mutableListOf()
```

### Solution 4: Subselect Fetch

```kotlin
@OneToMany(mappedBy = "user")
@Fetch(FetchMode.SUBSELECT) // One subselect query for all collections
val orders: MutableList<Order> = mutableListOf()
```

## Fetch Types

```kotlin
// Override the default EAGER on @ManyToOne
@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(name = "user_id")
val user: User
```

## Second-Level Cache

### Entity Configuration

```kotlin
@Entity
@Table(name = "categories")
@Cacheable
@Cache(usage = CacheConcurrencyStrategy.READ_WRITE)
class Category(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,
    val name: String,

    @OneToMany(mappedBy = "category")
    @Cache(usage = CacheConcurrencyStrategy.READ_WRITE)
    val products: MutableList<Product> = mutableListOf()
)
```

## Optimistic Locking

```kotlin
@Entity
class Product(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    var name: String,
    var price: BigDecimal,

    @Version
    val version: Long = 0 // Hibernate increments automatically
)
```

```kotlin
// Handling optimistic lock failure
try {
    productRepository.save(updatedProduct)
} catch (e: OptimisticLockingFailureException) {
    // Reload and retry, or inform user of conflict
    throw ConflictException("Product was modified by another user")
}
```

## Lifecycle Callbacks

```kotlin
@Entity
@Table(name = "users")
class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    val email: String,
    var name: String,

    @Column(name = "created_at", updatable = false)
    var createdAt: OffsetDateTime? = null,

    @Column(name = "updated_at")
    var updatedAt: OffsetDateTime? = null
) {
    @PrePersist
    fun prePersist() {
        createdAt = OffsetDateTime.now()
        updatedAt = OffsetDateTime.now()
    }

    @PreUpdate
    fun preUpdate() {
        updatedAt = OffsetDateTime.now()
    }
}
```

Or use a shared `@MappedSuperclass`:

```kotlin
@MappedSuperclass
abstract class BaseEntity {
    @Column(name = "created_at", updatable = false)
    var createdAt: OffsetDateTime? = null

    @Column(name = "updated_at")
    var updatedAt: OffsetDateTime? = null

    @PrePersist
    fun onPrePersist() {
        createdAt = OffsetDateTime.now()
        updatedAt = OffsetDateTime.now()
    }

    @PreUpdate
    fun onPreUpdate() {
        updatedAt = OffsetDateTime.now()
    }
}
```

## Entity Equality

```kotlin
// Use business key
@Entity
@Table(name = "users")
class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long? = null,

    @Column(nullable = false, unique = true)
    val email: String,

    val name: String
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is User) return false
        return email == other.email
    }

    override fun hashCode(): Int = email.hashCode()
}
```

## Kotlin-Specific Considerations

- **Do NOT use `data class` for entities** -- copy() and componentN() break Hibernate proxying
- Use `class` with manual equals/hashCode on business key
- `kotlin-jpa` plugin generates no-arg constructor
- `kotlin-allopen` plugin opens entity classes for proxying
- Use `var` for mutable fields, `val` for immutable (id, createdAt)

## Testing with @DataJpaTest

```kotlin
@DataJpaTest
@Testcontainers
class UserRepositoryTest {
    companion object {
        @Container
        val postgres = PostgreSQLContainer("postgres:16-alpine")

        @JvmStatic
        @DynamicPropertySource
        fun properties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
        }
    }

    @Autowired
    lateinit var userRepository: UserRepository

    @Autowired
    lateinit var entityManager: TestEntityManager

    @Test
    fun `should find user by email`() {
        val user = User(email = "test@example.com", name = "Test")
        entityManager.persistAndFlush(user)
        entityManager.clear() // Clear first-level cache

        val found = userRepository.findByEmail("test@example.com")

        assertThat(found).isNotNull
        assertThat(found!!.name).isEqualTo("Test")
    }
}
```

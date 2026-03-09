---
name: jpa-hibernate-java
description: "Java implementation patterns for JPA/Hibernate. Use with `jpa-hibernate` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# JPA / Hibernate — Java

Prerequisites: load `jpa-hibernate` skill for foundational concepts.

## Entity Design

### Java Entity

```java
@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private boolean active = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();

    @Version
    private Long version;

    protected User() {} // JPA requires no-arg constructor

    public User(String email, String name) {
        this.email = email;
        this.name = name;
    }

    // Getters (no setters for immutability where possible)
    public Long getId() { return id; }
    public String getEmail() { return email; }
    public String getName() { return name; }
    public boolean isActive() { return active; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public Long getVersion() { return version; }
}
```

### ID Generation Strategies

<!-- TODO: Add Java equivalent for UUID and Sequence ID generation -->

## Column Mapping

### @Enumerated

<!-- TODO: Add Java equivalent for @Enumerated and @Converter -->

### @Embedded

<!-- TODO: Add Java equivalent for @Embedded -->

## Relationships

### @ManyToOne / @OneToMany (Most Common)

```java
// Parent side
@Entity
@Table(name = "users")
public class User {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Order> orders = new ArrayList<>();

    public void addOrder(Order order) {
        orders.add(order);
    }
}

// Child side
@Entity
@Table(name = "orders")
public class Order {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    private BigDecimal total;
}
```

### @ManyToMany

<!-- TODO: Add Java equivalent for @ManyToMany -->

## N+1 Prevention

<!-- TODO: Add Java equivalent for N+1 Prevention (JOIN FETCH, @EntityGraph, @BatchSize, SUBSELECT) -->

## Fetch Types

<!-- TODO: Add Java equivalent for Fetch Types -->

## Second-Level Cache

### Entity Configuration

<!-- TODO: Add Java equivalent for Second-Level Cache Entity Configuration -->

## Optimistic Locking

<!-- TODO: Add Java equivalent for Optimistic Locking -->

## Lifecycle Callbacks

<!-- TODO: Add Java equivalent for Lifecycle Callbacks -->

## Entity Equality

```java
// Use business key
@Entity
@Table(name = "users")
public class User {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof User other)) return false;
        return Objects.equals(email, other.email);
    }

    @Override
    public int hashCode() {
        return Objects.hash(email);
    }
}
```

## Java-Specific Considerations

- Records (`record`) cannot be JPA entities (no no-arg constructor, final)
- Use Lombok `@Getter` but avoid `@Data` (generates equals on all fields)
- Protected no-arg constructor for JPA, public constructor for application code

## Testing with @DataJpaTest

```java
@DataJpaTest
@Testcontainers
class UserRepositoryTest {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    UserRepository userRepository;

    @Autowired
    TestEntityManager entityManager;

    @Test
    void shouldFindUserByEmail() {
        var user = new User("test@example.com", "Test");
        entityManager.persistAndFlush(user);
        entityManager.clear();

        var found = userRepository.findByEmail("test@example.com");

        assertThat(found).isNotNull();
        assertThat(found.getName()).isEqualTo("Test");
    }
}
```

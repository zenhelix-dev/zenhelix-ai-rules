---
name: jooq-kotlin
description: "Kotlin implementation patterns for jOOQ. Use with `jooq` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# jOOQ — Kotlin

Prerequisites: load `jooq` skill for foundational concepts.

## Basic CRUD

### Select

```kotlin
import com.example.generated.jooq.Tables.USERS

// Single record
val user = dsl.selectFrom(USERS)
    .where(USERS.ID.eq(userId))
    .fetchOne()

// Multiple records with specific columns
val names = dsl.select(USERS.ID, USERS.EMAIL, USERS.NAME)
    .from(USERS)
    .where(USERS.ACTIVE.isTrue)
    .orderBy(USERS.NAME.asc())
    .fetch()

// Fetch into a DTO
data class UserDto(val id: Long, val email: String, val name: String)

val users = dsl.select(USERS.ID, USERS.EMAIL, USERS.NAME)
    .from(USERS)
    .fetchInto(UserDto::class.java)
```

### Insert

```kotlin
// Using record
val record = dsl.newRecord(USERS).apply {
    email = "user@example.com"
    name = "John"
}
record.store()

// Using DSL (returns generated ID)
val id = dsl.insertInto(USERS)
    .set(USERS.EMAIL, "user@example.com")
    .set(USERS.NAME, "John")
    .returning(USERS.ID)
    .fetchOne()!!
    .id
```

### Update

```kotlin
val rowsAffected = dsl.update(USERS)
    .set(USERS.NAME, "Jane")
    .set(USERS.UPDATED_AT, OffsetDateTime.now())
    .where(USERS.ID.eq(userId))
    .execute()
```

### Delete

```kotlin
val deleted = dsl.deleteFrom(USERS)
    .where(USERS.ID.eq(userId))
    .execute()
```

## Type-Safe Conditions

```kotlin
// Building conditions dynamically
fun searchUsers(email: String?, name: String?, active: Boolean?): List<UserDto> {
    var condition = DSL.noCondition()

    email?.let { condition = condition.and(USERS.EMAIL.eq(it)) }
    name?.let { condition = condition.and(USERS.NAME.likeIgnoreCase("%$it%")) }
    active?.let { condition = condition.and(USERS.ACTIVE.eq(it)) }

    return dsl.selectFrom(USERS)
        .where(condition)
        .fetchInto(UserDto::class.java)
}
```

## Joins

```kotlin
// Explicit join
val ordersWithUsers = dsl
    .select(ORDERS.ID, ORDERS.TOTAL, USERS.NAME, USERS.EMAIL)
    .from(ORDERS)
    .join(USERS).on(ORDERS.USER_ID.eq(USERS.ID))
    .where(ORDERS.STATUS.eq("COMPLETED"))
    .fetch()

// Left join
val usersWithOrders = dsl
    .select(USERS.NAME, DSL.count(ORDERS.ID).`as`("order_count"))
    .from(USERS)
    .leftJoin(ORDERS).on(USERS.ID.eq(ORDERS.USER_ID))
    .groupBy(USERS.NAME)
    .fetch()
```

## Aggregations

```kotlin
val stats = dsl
    .select(
        ORDERS.STATUS,
        DSL.count().`as`("count"),
        DSL.sum(ORDERS.TOTAL).`as`("total_sum"),
        DSL.avg(ORDERS.TOTAL).`as`("avg_total")
    )
    .from(ORDERS)
    .groupBy(ORDERS.STATUS)
    .having(DSL.count().gt(10))
    .fetch()
```

## Subqueries and CTEs

```kotlin
// Subquery
val highSpenders = dsl.selectFrom(USERS)
    .where(USERS.ID.`in`(
        dsl.select(ORDERS.USER_ID)
            .from(ORDERS)
            .groupBy(ORDERS.USER_ID)
            .having(DSL.sum(ORDERS.TOTAL).gt(BigDecimal("1000")))
    ))
    .fetch()

// CTE (Common Table Expression)
val orderTotals = DSL.name("order_totals").`as`(
    dsl.select(ORDERS.USER_ID, DSL.sum(ORDERS.TOTAL).`as`("total"))
        .from(ORDERS)
        .groupBy(ORDERS.USER_ID)
)

val result = dsl.with(orderTotals)
    .select()
    .from(orderTotals)
    .join(USERS).on(USERS.ID.eq(orderTotals.field("user_id", Long::class.java)))
    .where(orderTotals.field("total", BigDecimal::class.java)!!.gt(BigDecimal("500")))
    .fetch()
```

## Transaction Management

### With jOOQ API

```kotlin
val result = dsl.transactionResult { config ->
    val txDsl = DSL.using(config)

    val userId = txDsl.insertInto(USERS)
        .set(USERS.EMAIL, "new@example.com")
        .returning(USERS.ID)
        .fetchOne()!!.id

    txDsl.insertInto(ORDERS)
        .set(ORDERS.USER_ID, userId)
        .set(ORDERS.TOTAL, BigDecimal("99.99"))
        .execute()

    userId
}
```

### With Spring @Transactional

```kotlin
@Service
class OrderService(private val dsl: DSLContext) {

    @Transactional
    fun createOrder(userId: Long, total: BigDecimal): Long {
        return dsl.insertInto(ORDERS)
            .set(ORDERS.USER_ID, userId)
            .set(ORDERS.TOTAL, total)
            .returning(ORDERS.ID)
            .fetchOne()!!.id
    }
}
```

## Batch Operations

```kotlin
// Batch insert
dsl.batch(
    users.map { user ->
        dsl.insertInto(USERS)
            .set(USERS.EMAIL, user.email)
            .set(USERS.NAME, user.name)
    }
).execute()

// Bulk insert with VALUES
dsl.insertInto(USERS, USERS.EMAIL, USERS.NAME)
    .apply { users.forEach { values(it.email, it.name) } }
    .execute()
```

## jOOQ Alongside JPA (Read/Write Split)

```kotlin
@Service
class UserService(
    private val userRepository: UserRepository,  // JPA for writes
    private val dsl: DSLContext                   // jOOQ for reads
) {
    // Complex read with jOOQ
    fun getUserDashboard(userId: Long): DashboardDto {
        return dsl.select(
            USERS.NAME,
            DSL.count(ORDERS.ID).`as`("order_count"),
            DSL.sum(ORDERS.TOTAL).`as`("total_spent")
        )
        .from(USERS)
        .leftJoin(ORDERS).on(USERS.ID.eq(ORDERS.USER_ID))
        .where(USERS.ID.eq(userId))
        .groupBy(USERS.NAME)
        .fetchOneInto(DashboardDto::class.java)!!
    }

    // Simple write with JPA
    fun createUser(request: CreateUserRequest): User {
        return userRepository.save(User(email = request.email, name = request.name))
    }
}
```

## Record Mapping to DTOs

```kotlin
// Custom RecordMapper
val mapper = RecordMapper<Record, UserDto> { record ->
    UserDto(
        id = record[USERS.ID],
        email = record[USERS.EMAIL],
        name = record[USERS.NAME]
    )
}

val users = dsl.selectFrom(USERS).fetch(mapper)

// Or use fetchInto with matching field names
data class UserDto(val id: Long, val email: String, val name: String)
val users = dsl.selectFrom(USERS).fetchInto(UserDto::class.java)
```

## Testing with TestContainers

```kotlin
@Testcontainers
class UserRepositoryTest {

    companion object {
        @Container
        val postgres = PostgreSQLContainer("postgres:16-alpine")
            .withDatabaseName("testdb")

        @JvmStatic
        @DynamicPropertySource
        fun properties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
        }
    }

    @Autowired
    lateinit var dsl: DSLContext

    @Test
    fun `should insert and fetch user`() {
        val id = dsl.insertInto(USERS)
            .set(USERS.EMAIL, "test@example.com")
            .set(USERS.NAME, "Test User")
            .returning(USERS.ID)
            .fetchOne()!!.id

        val user = dsl.selectFrom(USERS).where(USERS.ID.eq(id)).fetchOne()

        assertThat(user).isNotNull
        assertThat(user!!.email).isEqualTo("test@example.com")
    }
}
```

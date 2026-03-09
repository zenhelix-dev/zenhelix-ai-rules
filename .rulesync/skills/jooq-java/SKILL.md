---
name: jooq-java
description: "Java implementation patterns for jOOQ. Use with `jooq` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# jOOQ — Java

Prerequisites: load `jooq` skill for foundational concepts.

## Basic CRUD

### Select

```java
import static com.example.generated.jooq.Tables.USERS;

// Single record
UsersRecord user = dsl.selectFrom(USERS)
    .where(USERS.ID.eq(userId))
    .fetchOne();

// Multiple records
Result<Record3<Long, String, String>> result = dsl
    .select(USERS.ID, USERS.EMAIL, USERS.NAME)
    .from(USERS)
    .where(USERS.ACTIVE.isTrue())
    .orderBy(USERS.NAME.asc())
    .fetch();

// Fetch into a DTO
List<UserDto> users = dsl.select(USERS.ID, USERS.EMAIL, USERS.NAME)
    .from(USERS)
    .fetchInto(UserDto.class);
```

### Insert

```java
Long id = dsl.insertInto(USERS)
    .set(USERS.EMAIL, "user@example.com")
    .set(USERS.NAME, "John")
    .returning(USERS.ID)
    .fetchOne()
    .getId();
```

### Update

```java
int rowsAffected = dsl.update(USERS)
    .set(USERS.NAME, "Jane")
    .set(USERS.UPDATED_AT, OffsetDateTime.now())
    .where(USERS.ID.eq(userId))
    .execute();
```

### Delete

<!-- TODO: Add Java equivalent for Delete -->

## Type-Safe Conditions

```java
// Building conditions dynamically
public List<UserDto> searchUsers(String email, String name, Boolean active) {
    Condition condition = DSL.noCondition();

    if (email != null) condition = condition.and(USERS.EMAIL.eq(email));
    if (name != null) condition = condition.and(USERS.NAME.likeIgnoreCase("%" + name + "%"));
    if (active != null) condition = condition.and(USERS.ACTIVE.eq(active));

    return dsl.selectFrom(USERS)
        .where(condition)
        .fetchInto(UserDto.class);
}
```

## Joins

```java
Result<?> ordersWithUsers = dsl
    .select(ORDERS.ID, ORDERS.TOTAL, USERS.NAME, USERS.EMAIL)
    .from(ORDERS)
    .join(USERS).on(ORDERS.USER_ID.eq(USERS.ID))
    .where(ORDERS.STATUS.eq("COMPLETED"))
    .fetch();
```

## Aggregations

<!-- TODO: Add Java equivalent for Aggregations -->

## Subqueries and CTEs

<!-- TODO: Add Java equivalent for Subqueries and CTEs -->

## Transaction Management

### With jOOQ API

```java
Long result = dsl.transactionResult(config -> {
    DSLContext txDsl = DSL.using(config);

    Long userId = txDsl.insertInto(USERS)
        .set(USERS.EMAIL, "new@example.com")
        .returning(USERS.ID)
        .fetchOne()
        .getId();

    txDsl.insertInto(ORDERS)
        .set(ORDERS.USER_ID, userId)
        .set(ORDERS.TOTAL, BigDecimal.valueOf(99.99))
        .execute();

    return userId;
});
```

### With Spring @Transactional

<!-- TODO: Add Java equivalent for Spring @Transactional -->

## Batch Operations

```java
// Batch insert
dsl.batch(
    users.stream()
        .map(user -> dsl.insertInto(USERS)
            .set(USERS.EMAIL, user.getEmail())
            .set(USERS.NAME, user.getName()))
        .collect(Collectors.toList())
).execute();
```

## jOOQ Alongside JPA (Read/Write Split)

<!-- TODO: Add Java equivalent for jOOQ Alongside JPA -->

## Record Mapping to DTOs

<!-- TODO: Add Java equivalent for Record Mapping to DTOs -->

## Testing with TestContainers

```java
@Testcontainers
class UserRepositoryTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("testdb");

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    DSLContext dsl;

    @Test
    void shouldInsertAndFetchUser() {
        Long id = dsl.insertInto(USERS)
            .set(USERS.EMAIL, "test@example.com")
            .set(USERS.NAME, "Test User")
            .returning(USERS.ID)
            .fetchOne()
            .getId();

        UsersRecord user = dsl.selectFrom(USERS).where(USERS.ID.eq(id)).fetchOne();

        assertThat(user).isNotNull();
        assertThat(user.getEmail()).isEqualTo("test@example.com");
    }
}
```

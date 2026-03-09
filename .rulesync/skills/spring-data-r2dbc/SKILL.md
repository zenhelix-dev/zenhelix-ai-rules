---
name: spring-data-r2dbc
description: "Spring Data R2DBC: foundational concepts, reactive repositories, DatabaseClient, R2DBC patterns"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Data R2DBC

This skill provides foundational concepts. For implementation examples, use `spring-data-r2dbc-kotlin` or `spring-data-r2dbc-java` skill.

Comprehensive guide for reactive database access with Spring Data R2DBC: repositories, DatabaseClient, transactions, and coroutine support.

## When to Use R2DBC vs JPA

| Criteria             | R2DBC                              | JPA                                   |
|----------------------|------------------------------------|---------------------------------------|
| Application type     | Reactive/WebFlux                   | Traditional/Web MVC                   |
| ORM features needed  | None (no lazy loading, cascading)  | Full ORM (relationships, caching)     |
| Performance priority | High concurrency, non-blocking I/O | Moderate load, developer productivity |
| Schema complexity    | Simple to moderate                 | Complex with deep relationships       |
| Kotlin style         | Coroutines (suspend/Flow)          | Blocking                              |

Key difference: R2DBC has no lazy loading, no cascading, no entity graphs. Manage relationships manually.

## Entity Mapping

Entities use `@Table` and `@Id` annotations. R2DBC supports immutable entities (data classes in Kotlin, records in Java). Use
`@CreatedDate` / `@LastModifiedDate` for auditing fields.

## Reactive Repositories

- Kotlin: Use `CoroutineCrudRepository` with `suspend` functions and `Flow` return types
- Java: Use `ReactiveCrudRepository` with `Mono` and `Flux` return types
- Support `@Query` for custom SQL and `@Modifying` for update/delete operations

## DatabaseClient for Complex Queries

Use `DatabaseClient` for:

- Complex joins and aggregations not supported by derived queries
- Dynamic query building with conditional filters
- Manual row mapping for custom projections

## Transaction Management

- **Declarative**: Use `@Transactional` on service methods (not repository methods)
- **Programmatic**: Use `TransactionalOperator` for fine-grained control
    - Kotlin: `transactionalOperator.executeAndAwait { ... }`
    - Java: `transactionalOperator.transactional(mono)`

## Connection Pool Configuration

```yaml
spring:
  r2dbc:
    url: r2dbc:postgresql://localhost:5432/orders
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
    pool:
      initial-size: 5
      max-size: 20
      max-idle-time: 30m
      validation-query: SELECT 1
```

## Schema Initialization

```yaml
spring:
  sql:
    init:
      mode: always
      schema-locations: classpath:schema.sql
```

```sql
-- schema.sql
CREATE TABLE IF NOT EXISTS orders (
    id BIGSERIAL PRIMARY KEY,
    customer_id VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'CREATED',
    total_amount DECIMAL(12, 2) NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

CREATE TABLE IF NOT EXISTS order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id VARCHAR(255) NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
```

## R2DBC Auditing

Enable with `@EnableR2dbcAuditing` configuration. Provide a `ReactiveAuditorAware<String>` bean to resolve the current auditor (e.g., from
`ReactiveSecurityContextHolder`).

## Testing Reactive Repositories

Use `@DataR2dbcTest` with embedded or Testcontainers database. Clean up data in `@BeforeEach` using `DatabaseClient`.

## Best Practices

1. **Use CoroutineCrudRepository** with Kotlin for cleaner code
2. **Manage relationships manually** — R2DBC has no lazy loading or cascading
3. **Use DatabaseClient** for complex joins and aggregations
4. **Configure connection pooling** — always set max-size and idle-time
5. **Use schema.sql** for DDL — R2DBC does not auto-generate schemas
6. **Prefer immutable entities** — use Kotlin data classes with copy()
7. **Use @Transactional** on service methods, not repository methods
8. **Index foreign keys** — R2DBC does not create them automatically
9. **Test with @DataR2dbcTest** — uses embedded or Testcontainers database
10. **Handle empty results** — `awaitOneOrNull()` in Kotlin, `switchIfEmpty()` in Java

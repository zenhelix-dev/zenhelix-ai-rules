---
name: jpa-hibernate
description: "JPA/Hibernate: foundational concepts — entity mapping, relationships, N+1 prevention, second-level cache, performance"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# JPA / Hibernate Reference

This skill provides foundational concepts. For implementation examples, use `jpa-hibernate-kotlin` or `jpa-hibernate-java` skill.

## Entity Design

Entities map Java/Kotlin classes to database tables. Use `@Entity`, `@Table`, `@Id`, `@GeneratedValue`, `@Column`, and `@Version` for basic
mapping.

### ID Generation Strategies

| Strategy   | Use When                                  | Notes                                          |
|------------|-------------------------------------------|------------------------------------------------|
| `IDENTITY` | PostgreSQL `GENERATED ALWAYS AS IDENTITY` | Simple, auto-increment. Disables batch inserts |
| `SEQUENCE` | Need batch inserts                        | Use `@SequenceGenerator` with `allocationSize` |
| `UUID`     | Distributed systems                       | Use `@UuidGenerator` (Hibernate 6.2+)          |

## Column Mapping

### @Enumerated

Use `EnumType.STRING` (preferred -- survives enum reordering) or a custom `@Converter` for mapping enums.

### @Embedded

Use `@Embeddable` for value objects (Address, Money, etc.) that map to columns in the parent table.

## Relationships

### @ManyToOne / @OneToMany (Most Common)

- Parent owns the collection (`@OneToMany(mappedBy = ...)`)
- Child references the parent (`@ManyToOne(fetch = FetchType.LAZY)`)
- Always use `CascadeType.ALL` with `orphanRemoval = true` on the parent side when the child lifecycle is bound to the parent

### @ManyToMany

Use `@JoinTable` to define the join table. For join tables with extra columns, model the join table as an entity with two `@ManyToOne`
relationships.

## Fetch Types

| Type  | Default For                 | Recommendation  |
|-------|-----------------------------|-----------------|
| LAZY  | `@OneToMany`, `@ManyToMany` | Always use LAZY |
| EAGER | `@ManyToOne`, `@OneToOne`   | Change to LAZY  |

**Rule: ALL relationships should be LAZY. Fetch eagerly only when needed via JOIN FETCH or @EntityGraph.**

## N+1 Prevention

### The Problem

Accessing a lazy collection in a loop triggers one query per entity (N+1 queries total).

### Solution 1: JOIN FETCH (JPQL)

Use `JOIN FETCH` in JPQL queries to load associations in a single query.

### Solution 2: @EntityGraph

Use `@EntityGraph(attributePaths = [...])` on Spring Data repository methods.

### Solution 3: @BatchSize

Annotate the collection with `@BatchSize(size = 20)` to batch lazy loading.

### Solution 4: Subselect Fetch

Use `@Fetch(FetchMode.SUBSELECT)` to load all collections for a result set in one subselect query.

### Which to Use?

| Approach     | Best For                                           |
|--------------|----------------------------------------------------|
| JOIN FETCH   | Specific queries where you know the access pattern |
| @EntityGraph | Spring Data methods, flexible graph loading        |
| @BatchSize   | Global default, reduces N+1 to N/batch queries     |
| SUBSELECT    | Loading all collections for a result set           |

## Second-Level Cache

### Configuration

```yaml
# application.yml
spring:
  jpa:
    properties:
      hibernate:
        cache:
          use_second_level_cache: true
          use_query_cache: true
          region.factory_class: org.hibernate.cache.jcache.JCacheRegionFactory
        javax:
          cache:
            provider: org.ehcache.jsr107.EhcacheCachingProvider
```

### Cache Strategies

| Strategy             | Use Case                                |
|----------------------|-----------------------------------------|
| READ_ONLY            | Immutable reference data                |
| READ_WRITE           | General purpose, read-heavy             |
| NONSTRICT_READ_WRITE | Rarely updated, eventual consistency OK |
| TRANSACTIONAL        | JTA transactions (rare)                 |

## Optimistic Locking

Use `@Version` on a `Long` field. Hibernate increments it automatically on each update. Catch `OptimisticLockingFailureException` to handle
conflicts.

## HikariCP Configuration

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20        # Default: 10
      minimum-idle: 5
      idle-timeout: 300000         # 5 min
      max-lifetime: 1800000        # 30 min
      connection-timeout: 30000    # 30 sec
      leak-detection-threshold: 60000  # 1 min - log warning for leaked connections
```

## Hibernate Statistics and Query Logging

```yaml
spring:
  jpa:
    properties:
      hibernate:
        generate_statistics: true   # Dev/test only
        format_sql: true
    show-sql: false                 # Use logging config instead

logging:
  level:
    org.hibernate.SQL: DEBUG                       # Log SQL
    org.hibernate.orm.jdbc.bind: TRACE             # Log bind parameters
    org.hibernate.stat: DEBUG                      # Log statistics
```

## Common Anti-Patterns

1. **EAGER fetch everywhere** -- causes unnecessary joins, use LAZY + fetch when needed
2. **toString() with lazy collections** -- triggers lazy loading outside transaction, causes LazyInitializationException
3. **Open-session-in-view (OSIV)** -- set `spring.jpa.open-in-view=false`; fetch in service layer
4. **Entity as API response** -- use DTOs to avoid exposing internal structure and lazy proxies
5. **equals/hashCode on all fields** -- use business key (e.g., email) or natural id
6. **CascadeType.ALL without orphanRemoval** -- orphans remain in DB
7. **Not using @Version** -- lost updates in concurrent scenarios
8. **Large batch operations via JPA** -- use JDBC or jOOQ for bulk writes


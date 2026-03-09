---
name: spring-data-jpa
description: "Spring Data JPA foundational concepts: repository patterns, specifications, projections, auditing, query optimization, transaction management"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Data JPA

This skill provides foundational concepts. For implementation examples, use `spring-data-jpa-kotlin` or `spring-data-jpa-java` skill.

Comprehensive guide for Spring Data JPA: repositories, specifications, projections, auditing, and query optimization.

## Entity Design

JPA entities map Java/Kotlin classes to database tables. Key annotations:

| Annotation                          | Purpose                                      |
|-------------------------------------|----------------------------------------------|
| `@Entity`                           | Marks class as JPA entity                    |
| `@Table`                            | Specifies table name                         |
| `@Id`                               | Primary key field                            |
| `@GeneratedValue`                   | ID generation strategy                       |
| `@Column`                           | Column mapping (nullable, precision, etc.)   |
| `@Enumerated`                       | Enum mapping (STRING preferred over ORDINAL) |
| `@OneToMany`, `@ManyToOne`          | Relationship mapping                         |
| `@CreatedDate`, `@LastModifiedDate` | Auditing timestamps                          |

Best practices:

- Always use `FetchType.LAZY` for `@OneToMany` and `@ManyToMany`
- Use `CascadeType.ALL` + `orphanRemoval = true` for owned collections
- Use `mappedBy` on the non-owning side of relationships

## Repository Interface

Spring Data JPA repositories provide CRUD and query methods through interface declarations:

- `JpaRepository<T, ID>` — CRUD + pagination + sorting
- `JpaSpecificationExecutor<T>` — dynamic queries via Specifications
- Derived query methods — auto-generated from method names
- `@Query` — JPQL or native SQL queries
- `@Modifying` — for UPDATE/DELETE queries

## Specifications for Dynamic Queries

Specifications enable type-safe, composable query criteria. Use `Specification.where()` and `.and()` / `.or()` to combine.

Best for search/filter endpoints where criteria are optional and combined dynamically.

## Projections

### Interface-Based Projection

Closed projections fetch only specified fields. Open projections allow SpEL expressions.

### Class-Based Projection (DTO)

Use constructor expressions in JPQL: `SELECT new com.example.dto.Dto(...)`.

### Dynamic Projections

Pass projection type as method parameter: `<T> findById(Long id, Class<T> type)`.

## EntityGraph (N+1 Prevention)

`@EntityGraph` eagerly fetches specified associations in a single query, preventing N+1 problems.

Options:

- `@NamedEntityGraph` on entity class — reusable named graphs
- `@EntityGraph(attributePaths = [...])` on repository methods — ad-hoc graphs

## Auditing

Enable with `@EnableJpaAuditing`. Use `@CreatedDate`, `@LastModifiedDate`, `@CreatedBy`, `@LastModifiedBy`.

Provide `AuditorAware<String>` bean for `@CreatedBy` / `@LastModifiedBy` support.

Create a `@MappedSuperclass` base entity with audit fields for reuse across entities.

## Pagination

- `Pageable` / `PageRequest` — page-based pagination
- `Page<T>` — includes total count (extra COUNT query)
- `Slice<T>` — no total count (better for infinite scroll)
- `Sort` — ordering

## Custom Repository Implementation

For queries too complex for derived methods or JPQL:

1. Define custom interface (`OrderRepositoryCustom`)
2. Implement it (`OrderRepositoryCustomImpl`) using `EntityManager`
3. Extend custom interface in main repository

## Transaction Management

Key annotations:

- `@Transactional` — wraps method in transaction
- `@Transactional(readOnly = true)` — enables query optimizations
- `@Transactional(propagation = Propagation.REQUIRES_NEW)` — independent transaction

## Best Practices

1. **Use @Transactional(readOnly = true)** for read operations — enables query optimizations
2. **Avoid SELECT *** — use projections or DTOs for read queries
3. **Use @EntityGraph** to prevent N+1 queries
4. **Use Specifications** for dynamic filtering instead of multiple query methods
5. **Use Pageable** for all collection queries — never return unbounded lists
6. **Use @Modifying** for bulk updates — avoids loading entities into memory
7. **Always use FetchType.LAZY** for @OneToMany and @ManyToMany
8. **Use batch operations** — configure `spring.jpa.properties.hibernate.jdbc.batch_size=50`
9. **Validate at service layer** — not in entities
10. **Never expose entities to controllers** — always use DTOs/projections
11. **Use @Version** for optimistic locking when concurrent updates are possible
12. **Index frequently queried columns** — especially foreign keys and filter fields

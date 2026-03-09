---
root: false
targets: ["claudecode"]
description: "Java patterns: repository, service layer, DTO mapping, builder, strategy, exception hierarchy, and pagination"
globs: ["*.java"]
---

# Java Patterns

> Detailed examples: use skills `springboot-patterns`, `jpa-patterns`, `backend-patterns`, `api-design`

## Repository Pattern

- Define repositories as interfaces extending `JpaRepository`
- Use custom repository extensions for complex queries (Criteria API, Specification)
- Use `@Query` with named parameters for custom JPQL

## Service Layer

- Services contain business logic, inject repositories via constructor
- Use `@Transactional` for write operations, `@Transactional(readOnly = true)` for reads
- Keep transactions short — no external API calls inside transactions
- Let exceptions propagate for automatic rollback

## DTO Mapping

- Use static factory methods (`UserResponse.from(user)`) for simple mappings
- Use MapStruct for complex mappings with `@Mapper(componentModel = "spring")`
- Never expose entities directly in API responses

## Builder Pattern

- Use for objects with many optional parameters
- Prefer records with inner `Builder` class, or Lombok `@Builder`

## Strategy Pattern

- Define strategy as interface, implement as `@Component` beans
- Collect all implementations via `List<Strategy>` injection
- Build a `Map<Key, Strategy>` for runtime lookup

## Exception Hierarchy

- Create a base `AppException` with error code and HTTP status
- Extend for specific cases: `NotFoundException`, `ConflictException`, `ValidationException`
- Handle globally with `@RestControllerAdvice` + `@ExceptionHandler`

## Pagination

- Use Spring Data `Pageable` and `Page<T>`
- Create generic `PageResponse<T>` record for API responses
- Use Specification pattern for dynamic query filters

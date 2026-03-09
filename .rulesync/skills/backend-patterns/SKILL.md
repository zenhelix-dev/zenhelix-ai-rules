---
name: backend-patterns
description: "Backend architecture: layered design, caching strategies, error handling, retry, rate limiting, logging concepts"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Backend Architecture Patterns

> For implementation examples, use `backend-patterns-kotlin` or `backend-patterns-java` skill.

## Layered Architecture

```
Controller (HTTP layer)
    ↓ DTO / Request objects
Service (Business logic)
    ↓ Domain entities
Repository (Data access)
    ↓ SQL / JPA
Database
```

Rules:

- Controllers handle HTTP concerns only (request parsing, response formatting, status codes)
- Services contain business logic, transaction boundaries, orchestration
- Repositories handle data access only
- No upward dependencies (Repository must not know about Controller)
- Use DTOs between layers to avoid leaking internal representations

## RESTful API Structure

Standard CRUD controller pattern:

| Method | Path                      | Action           | Status |
|--------|---------------------------|------------------|--------|
| GET    | `/api/v1/{resource}`      | List (paginated) | 200    |
| GET    | `/api/v1/{resource}/{id}` | Get by ID        | 200    |
| POST   | `/api/v1/{resource}`      | Create           | 201    |
| PUT    | `/api/v1/{resource}/{id}` | Update           | 200    |
| DELETE | `/api/v1/{resource}/{id}` | Delete           | 204    |

Conventions:

- Use `@Valid` on request bodies for bean validation
- Map domain entities to response DTOs before returning
- Support pagination via `page` and `size` query parameters

## Service Layer

Responsibilities:

- Business logic and validation
- Transaction management (`@Transactional`)
- Event publishing
- Orchestration of repository calls
- Password encoding, data transformation

Key patterns:

- `findById` should throw `NotFoundException` if entity not found
- `create` should check for uniqueness constraints before saving
- `update` should produce a new copy of the entity with changed fields (immutability)
- `delete` should verify entity exists before deletion

## Repository Pattern

- Extend `JpaRepository<Entity, ID>` for JPA-based access
- Define custom query methods using Spring Data naming conventions
- Use `@Query` with JPQL for complex queries
- Use `@EntityGraph` for eager loading specific associations

## N+1 Prevention

| Solution                   | When to Use                          |
|----------------------------|--------------------------------------|
| `JOIN FETCH` in JPQL       | Single entity with associations      |
| `@EntityGraph`             | Repository method with eager loading |
| `@BatchSize` on collection | Bulk loading of lazy collections     |
| DTO projection query       | Aggregated data, reports             |

## Transaction Patterns

| Pattern      | Annotation                                   | Use Case                               |
|--------------|----------------------------------------------|----------------------------------------|
| Read-only    | `@Transactional(readOnly = true)`            | Queries, no dirty checking overhead    |
| Read-write   | `@Transactional`                             | Create, update, delete                 |
| Independent  | `@Transactional(propagation = REQUIRES_NEW)` | Audit logging, independent operations  |
| Programmatic | `TransactionTemplate.execute {}`             | Complex logic requiring manual control |

## Caching

### Spring Cache with Caffeine

- Enable with `@EnableCaching` configuration
- Configure `CaffeineCacheManager` with TTL, max size, stats recording
- Use `@Cacheable(value, key)` on read methods
- Use `@CacheEvict(value, key)` on write methods
- Use `@CacheEvict(allEntries = true)` for full cache invalidation

### Cache with Redis

- Use `RedisCacheManager` with `RedisCacheConfiguration`
- Configure serialization (e.g., `GenericJackson2JsonRedisSerializer`)
- Set per-cache TTL via `withCacheConfiguration`
- Disable caching null values

## Error Handling

### Exception Hierarchy

Design a sealed exception hierarchy mapping to HTTP status codes:

| Exception             | HTTP Status | Use Case                    |
|-----------------------|-------------|-----------------------------|
| `NotFoundException`   | 404         | Entity not found            |
| `ValidationException` | 400         | Business validation failure |
| `ConflictException`   | 409         | Duplicate/conflict          |
| `ForbiddenException`  | 403         | Access denied               |

### Global Exception Handler

- Use `@RestControllerAdvice` with `@ExceptionHandler` methods
- Return RFC 7807 `ProblemDetail` responses
- Log unexpected exceptions at ERROR level
- Never expose internal details in error responses
- Handle `MethodArgumentNotValidException` for bean validation errors

## Retry with Resilience4j

```yaml
# application.yml
resilience4j:
  retry:
    instances:
      payment:
        max-attempts: 3
        wait-duration: 1s
        exponential-backoff-multiplier: 2
        retry-exceptions:
          - java.io.IOException
          - java.util.concurrent.TimeoutException
        ignore-exceptions:
          - com.example.ValidationException
```

- Use `@Retry(name, fallbackMethod)` on service methods
- Define fallback methods with same signature + `Exception` parameter
- Configure retry instances in `application.yml`

## Rate Limiting with Bucket4j

- Implement as a servlet filter (`OncePerRequestFilter`)
- Use `ConcurrentHashMap` keyed by client IP for per-client buckets
- Configure bandwidth: capacity + refill rate
- Return `429 Too Many Requests` when bucket is exhausted

## Structured Logging

- Use SLF4J `LoggerFactory.getLogger(javaClass)` / `LoggerFactory.getLogger(ClassName.class)`
- Use MDC for contextual data (userId, requestId)
- Always clean MDC in a `finally` block

### MDC Filter for Request Tracing

- Extract or generate `X-Request-ID` header
- Set into MDC at request start, clear at request end
- Echo the request ID in the response header

### Logback Pattern

```xml
<pattern>%d{ISO8601} [%thread] %-5level %logger{36} [%X{requestId}] [%X{userId}] - %msg%n</pattern>
```

## Background Jobs

- Enable with `@EnableScheduling` and `@EnableAsync`
- Configure `ThreadPoolTaskExecutor` with core/max pool size and queue capacity
- Use `@Scheduled(cron = "...")` for periodic jobs
- Use `@Async` for asynchronous method execution (returns `CompletableFuture`)

## Spring Security JWT Flow

Key configuration points:

- Disable CSRF for stateless JWT APIs
- Set `SessionCreationPolicy.STATELESS`
- Define URL authorization rules (permit public endpoints, authenticate everything else)
- Add JWT filter before `UsernamePasswordAuthenticationFilter`

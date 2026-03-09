---
name: spring-webflux
description: "Spring WebFlux foundational concepts: reactive programming model, backpressure, WebClient architecture, SSE, router functions"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring WebFlux

This skill provides foundational concepts. For implementation examples, use `spring-webflux-kotlin` or `spring-webflux-java` skill.

Comprehensive guide for reactive web applications with Spring WebFlux: annotated controllers, functional endpoints, WebClient, SSE, and
reactive programming patterns.

## When to Use WebFlux vs Web MVC

| Criteria        | WebFlux                              | Web MVC                      |
|-----------------|--------------------------------------|------------------------------|
| I/O pattern     | Many concurrent I/O-bound requests   | CPU-bound or simple CRUD     |
| Database        | R2DBC, reactive MongoDB              | JPA/Hibernate, JDBC          |
| Team experience | Comfortable with reactive/coroutines | Traditional imperative style |
| Ecosystem       | Reactive libraries available         | Blocking libraries dominant  |
| Streaming       | SSE, WebSockets, backpressure needed | Request-response only        |

## Annotated Controllers with Mono/Flux

WebFlux supports the same annotation-based programming model as Web MVC (`@RestController`, `@GetMapping`, etc.) but with reactive return
types:

- **Java**: `Mono<T>` (0..1 element), `Flux<T>` (0..N elements)
- **Kotlin**: `suspend` functions (coroutines), `Flow<T>` (streaming)

## Functional Endpoints (Router Functions)

An alternative to annotated controllers. Define routes as functions:

- `RouterFunction<ServerResponse>` — defines routes
- `HandlerFunction` / handler class — processes requests
- Compose routes with `.nest()`, `.path()`, `.filter()`

Prefer functional endpoints for lightweight microservices; use annotated controllers when team is more familiar with Spring MVC style.

## WebClient

`WebClient` is the reactive, non-blocking HTTP client replacing `RestTemplate` in reactive applications.

Key features:

- Fluent API for building requests
- Supports streaming responses
- Built-in error handling with `onStatus()`
- Configurable timeouts and retries

Always configure:

- Base URL and default headers
- Timeouts on all calls
- Retry strategies for transient failures

## Server-Sent Events (SSE)

SSE enables server-to-client streaming over HTTP. Use `text/event-stream` media type.

`ServerSentEvent<T>` builder supports:

- `id` — event identifier for reconnection
- `event` — event type name
- `data` — payload
- `retry` — reconnection interval
- `comment` — comment line

## Reactive Error Handling

Error handling in reactive pipelines differs from imperative:

- Use `onErrorResume()` for fallback values
- Use `onErrorMap()` to transform exceptions
- Use `onErrorReturn()` for default values
- In Kotlin coroutines, use standard try/catch

Key principle: an empty Mono is NOT an error — treat it appropriately (e.g., map to 404).

## R2DBC Integration

R2DBC provides reactive database access. Use with:

- `ReactiveCrudRepository` (Java) or `CoroutineCrudRepository` (Kotlin)
- `@Query` for custom queries
- Never mix R2DBC with JDBC/JPA in the same application

## Testing with WebTestClient

`WebTestClient` supports both mock and live server testing for WebFlux endpoints.

Features:

- Fluent API for building requests
- Response assertions (status, headers, body)
- JSON path assertions
- Integration with `@WebFluxTest` slice

## Best Practices

1. **Use Kotlin coroutines** over raw Mono/Flux when using Kotlin
2. **Never block** in a reactive pipeline — no `.block()`, no blocking I/O
3. **Use WebClient** instead of RestTemplate in WebFlux applications
4. **Handle backpressure** — use `.limitRate()`, `.buffer()` when needed
5. **Prefer functional endpoints** for lightweight microservices
6. **Use annotated controllers** when team is more familiar with Spring MVC style
7. **Test with WebTestClient** — supports both mock and live server modes
8. **Configure timeouts** on all WebClient calls
9. **Use R2DBC** for database access — never use JDBC in WebFlux
10. **Handle errors explicitly** — empty Mono is not an error, treat it appropriately

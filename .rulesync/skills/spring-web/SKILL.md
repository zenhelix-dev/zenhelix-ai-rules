---
name: spring-web
description: "Spring Web MVC foundational concepts: REST architecture, request mapping, validation principles, exception handling patterns, interceptors, CORS"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Web MVC

This skill provides foundational concepts. For implementation examples, use `spring-web-kotlin` or `spring-web-java` skill.

Comprehensive guide for building REST APIs with Spring Web MVC: controllers, validation, exception handling, interceptors, and CORS.

## REST Controllers

REST controllers handle HTTP requests and return data directly (no view resolution). Use `@RestController` (combines `@Controller` +
`@ResponseBody`).

Key annotations:

- `@RequestMapping` — base path for all endpoints in controller
- `@GetMapping`, `@PostMapping`, `@PutMapping`, `@DeleteMapping`, `@PatchMapping` — HTTP method-specific
- `@PathVariable` — extract values from URI path
- `@RequestParam` — extract query parameters
- `@RequestBody` — deserialize request body
- `@Valid` — trigger Bean Validation on request body

## Request and Response DTOs with Validation

Use dedicated DTOs for request/response. Never expose entity classes directly.

Key validation annotations:

- `@NotBlank` — non-null, non-empty string
- `@NotEmpty` — non-null, non-empty collection
- `@Size` — string/collection length bounds
- `@Min`, `@Max` — numeric bounds
- `@DecimalMin`, `@DecimalMax` — BigDecimal bounds
- `@Valid` — cascade validation to nested objects

## ResponseEntity Patterns

`ResponseEntity` gives explicit control over:

- HTTP status code
- Response headers
- Response body

Common patterns: `ResponseEntity.ok()`, `ResponseEntity.created(location)`, `ResponseEntity.noContent()`, `ResponseEntity.notFound()`.

## Global Exception Handling with ProblemDetail (RFC 7807)

Use `@RestControllerAdvice` with `@ExceptionHandler` methods to centralize error handling.

ProblemDetail (Spring 6+) provides RFC 7807 compliant error responses with:

- `type` — URI identifying the problem type
- `title` — short human-readable summary
- `status` — HTTP status code
- `detail` — human-readable explanation
- Custom properties via `setProperty()`

## Custom Domain Exceptions

Define a sealed exception hierarchy for domain-specific errors. Map them to HTTP status codes in the global exception handler.

## HandlerInterceptor

Interceptors execute before/after controller methods. Use for cross-cutting concerns:

- Request logging and timing
- Authentication/authorization checks
- Rate limiting
- Request/response modification

Lifecycle: `preHandle()` -> Controller -> `postHandle()` -> `afterCompletion()`

Register interceptors via `WebMvcConfigurer.addInterceptors()`.

## Content Negotiation

Configure content negotiation to support multiple response formats (JSON, XML).

```yaml
spring:
  mvc:
    contentnegotiation:
      favor-parameter: true
      parameter-name: format
      media-types:
        json: application/json
        xml: application/xml
```

Use `produces` attribute on `@GetMapping` to declare supported media types.

## File Upload

Handle multipart file uploads with `MultipartFile`. Always validate:

- File is not empty
- File size is within limits
- File type is allowed

### Configuration

```yaml
spring:
  servlet:
    multipart:
      max-file-size: 10MB
      max-request-size: 10MB
```

## CORS Configuration

Configure CORS globally via `WebMvcConfigurer.addCorsMappings()` or per-controller/method with `@CrossOrigin`.

Key settings:

- `allowedOrigins` — specific origins (never use `*` with credentials)
- `allowedMethods` — HTTP methods
- `allowedHeaders` — request headers
- `allowCredentials` — whether to allow cookies/auth
- `maxAge` — preflight cache duration

## Best Practices

1. **Use DTOs** — never expose entity classes directly in controllers
2. **Validate all input** — @Valid on @RequestBody, constraints on @RequestParam
3. **Return ProblemDetail** — follow RFC 7807 for consistent error responses
4. **Use ResponseEntity** — for explicit control over status codes and headers
5. **Keep controllers thin** — delegate business logic to service layer
6. **Version your API** — use path versioning `/api/v1/`
7. **Paginate collections** — always use Pageable for list endpoints
8. **Log server-side, sanitize client-side** — never leak stack traces to clients
9. **Use @ResponseStatus** — for simple status-only responses (204 No Content)
10. **Configure CORS explicitly** — never use `allowedOrigins("*")` with credentials

---
name: api-design-kotlin
description: "Kotlin implementation patterns for REST API design. Use with `api-design` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# REST API Design — Kotlin

Prerequisites: load `api-design` skill for foundational concepts.

## Spring Controller

```kotlin
@RestController
@RequestMapping("/api/v1/users")
class UserController(private val userService: UserService) {

    @GetMapping
    fun list(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
        @RequestParam(required = false) status: UserStatus?
    ): ResponseEntity<PageResponse<UserResponse>> {
        val result = userService.findAll(status, PageRequest.of(page, size))
        return ResponseEntity.ok(
            PageResponse(
                data = result.content.map { it.toResponse() },
                meta = PaginationMeta.from(result)
            )
        )
    }

    @GetMapping("/{id}")
    fun getById(@PathVariable id: Long): ResponseEntity<DataResponse<UserResponse>> {
        val user = userService.findById(id)
        return ResponseEntity.ok(DataResponse(data = user.toResponse()))
    }

    @PostMapping
    fun create(@Valid @RequestBody request: CreateUserRequest): ResponseEntity<DataResponse<UserResponse>> {
        val user = userService.create(request)
        val location = URI.create("/api/v1/users/${user.id}")
        return ResponseEntity.created(location)
            .body(DataResponse(data = user.toResponse()))
    }

    @PutMapping("/{id}")
    fun update(
        @PathVariable id: Long,
        @Valid @RequestBody request: UpdateUserRequest
    ): ResponseEntity<DataResponse<UserResponse>> {
        val user = userService.update(id, request)
        return ResponseEntity.ok(DataResponse(data = user.toResponse()))
    }

    @PatchMapping("/{id}")
    fun patch(
        @PathVariable id: Long,
        @Valid @RequestBody request: PatchUserRequest
    ): ResponseEntity<DataResponse<UserResponse>> {
        val user = userService.patch(id, request)
        return ResponseEntity.ok(DataResponse(data = user.toResponse()))
    }

    @DeleteMapping("/{id}")
    fun delete(@PathVariable id: Long): ResponseEntity<Void> {
        userService.delete(id)
        return ResponseEntity.noContent().build()
    }
}
```

## Response DTOs

```kotlin
data class DataResponse<T>(val data: T)

data class PageResponse<T>(
    val data: List<T>,
    val meta: PaginationMeta
)

data class PaginationMeta(
    val page: Int,
    val size: Int,
    val totalElements: Long,
    val totalPages: Int
) {
    companion object {
        fun from(page: Page<*>) = PaginationMeta(
            page = page.number,
            size = page.size,
            totalElements = page.totalElements,
            totalPages = page.totalPages
        )
    }
}
```

## Error Handling with @ControllerAdvice

```kotlin
@RestControllerAdvice
class GlobalExceptionHandler : ResponseEntityExceptionHandler() {

    @ExceptionHandler(ResourceNotFoundException::class)
    fun handleNotFound(ex: ResourceNotFoundException): ProblemDetail {
        val problem = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.message ?: "Resource not found")
        problem.title = "Not Found"
        problem.setProperty("timestamp", OffsetDateTime.now())
        return problem
    }

    @ExceptionHandler(ConflictException::class)
    fun handleConflict(ex: ConflictException): ProblemDetail {
        val problem = ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.message ?: "Conflict")
        problem.title = "Conflict"
        return problem
    }

    override fun handleMethodArgumentNotValid(
        ex: MethodArgumentNotValidException,
        headers: HttpHeaders,
        status: HttpStatusCode,
        request: WebRequest
    ): ResponseEntity<Any>? {
        val problem = ProblemDetail.forStatusAndDetail(HttpStatus.UNPROCESSABLE_ENTITY, "Validation failed")
        problem.title = "Validation Error"
        problem.setProperty("errors", ex.bindingResult.fieldErrors.map { fieldError ->
            mapOf("field" to fieldError.field, "message" to (fieldError.defaultMessage ?: "invalid"))
        })
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(problem)
    }

    @ExceptionHandler(Exception::class)
    fun handleGeneric(ex: Exception): ProblemDetail {
        // Log the full exception server-side
        logger.error("Unexpected error", ex)
        // Return generic message to client (no internal details)
        return ProblemDetail.forStatusAndDetail(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "An unexpected error occurred"
        )
    }
}
```

## Pagination

### Offset-Based (Simple Cases)

```kotlin
@GetMapping("/orders")
fun list(
    @RequestParam(defaultValue = "0") page: Int,
    @RequestParam(defaultValue = "20") size: Int,
    @RequestParam(defaultValue = "createdAt,desc") sort: String
): ResponseEntity<PageResponse<OrderResponse>> {
    val pageable = PageRequest.of(page, size, Sort.by(parseSortParams(sort)))
    val result = orderService.findAll(pageable)
    return ResponseEntity.ok(PageResponse(
        data = result.content.map { it.toResponse() },
        meta = PaginationMeta.from(result)
    ))
}
```

### Cursor-Based (Large Datasets)

```kotlin
data class CursorPage<T>(
    val data: List<T>,
    val nextCursor: String?,
    val hasMore: Boolean
)

@GetMapping("/events")
fun listEvents(
    @RequestParam(required = false) cursor: String?,
    @RequestParam(defaultValue = "50") limit: Int
): ResponseEntity<CursorPage<EventResponse>> {
    val decodedCursor = cursor?.let { decodeCursor(it) }
    val events = eventService.findAfter(decodedCursor, limit + 1)

    val hasMore = events.size > limit
    val page = events.take(limit)
    val nextCursor = if (hasMore) encodeCursor(page.last()) else null

    return ResponseEntity.ok(CursorPage(
        data = page.map { it.toResponse() },
        nextCursor = nextCursor,
        hasMore = hasMore
    ))
}

private fun encodeCursor(event: Event): String =
    Base64.getUrlEncoder().encodeToString("${event.createdAt}|${event.id}".toByteArray())

private fun decodeCursor(cursor: String): CursorData {
    val decoded = String(Base64.getUrlDecoder().decode(cursor))
    val (timestamp, id) = decoded.split("|")
    return CursorData(OffsetDateTime.parse(timestamp), id.toLong())
}
```

## Filtering and Sorting

```kotlin
@GetMapping("/orders")
fun list(
    @RequestParam(required = false) status: OrderStatus?,
    @RequestParam(required = false) minTotal: BigDecimal?,
    @RequestParam(required = false) maxTotal: BigDecimal?,
    @RequestParam(defaultValue = "-createdAt") sort: String,
    @RequestParam(defaultValue = "0") page: Int,
    @RequestParam(defaultValue = "20") size: Int
): ResponseEntity<PageResponse<OrderResponse>> {
    val filter = OrderFilter(status = status, minTotal = minTotal, maxTotal = maxTotal)
    val pageable = PageRequest.of(page, size, parseSort(sort))
    val result = orderService.findAll(filter, pageable)
    return ResponseEntity.ok(PageResponse(
        data = result.content.map { it.toResponse() },
        meta = PaginationMeta.from(result)
    ))
}

private fun parseSort(sort: String): Sort {
    val orders = sort.split(",").map { param ->
        val trimmed = param.trim()
        if (trimmed.startsWith("-")) {
            Sort.Order.desc(trimmed.substring(1))
        } else {
            Sort.Order.asc(trimmed.removePrefix("+"))
        }
    }
    return Sort.by(orders)
}
```

## Versioning

```kotlin
@RestController
@RequestMapping("/api/v1/users")
class UserV1Controller { ... }

@RestController
@RequestMapping("/api/v2/users")
class UserV2Controller { ... }
```

## Rate Limiting

```kotlin
@Component
class RateLimitFilter : OncePerRequestFilter() {
    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        // After rate limit check
        response.setHeader("X-RateLimit-Limit", "100")
        response.setHeader("X-RateLimit-Remaining", remaining.toString())
        response.setHeader("X-RateLimit-Reset", resetTimestamp.toString())
        filterChain.doFilter(request, response)
    }
}
```

## Validation

```kotlin
data class CreateUserRequest(
    @field:NotBlank(message = "Email is required")
    @field:Email(message = "Must be a valid email")
    val email: String,

    @field:NotBlank(message = "Name is required")
    @field:Size(min = 2, max = 100, message = "Name must be 2-100 characters")
    val name: String,

    @field:Size(max = 500, message = "Bio must not exceed 500 characters")
    val bio: String? = null
)
```

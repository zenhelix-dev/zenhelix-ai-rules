---
name: spring-web-kotlin
description: "Kotlin implementation patterns for Spring Web MVC. Use with `spring-web` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Web MVC — Kotlin

Prerequisites: load `spring-web` skill for foundational concepts.

## REST Controllers

```kotlin
@RestController
@RequestMapping("/api/v1/orders")
class OrderController(
    private val orderService: OrderService
) {

    @GetMapping
    fun listOrders(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
        @RequestParam(required = false) status: OrderStatus?
    ): Page<OrderResponse> =
        orderService.findAll(status, PageRequest.of(page, size))

    @GetMapping("/{id}")
    fun getOrder(@PathVariable id: Long): ResponseEntity<OrderResponse> =
        orderService.findById(id)
            ?.let { ResponseEntity.ok(it) }
            ?: ResponseEntity.notFound().build()

    @PostMapping
    fun createOrder(
        @Valid @RequestBody request: CreateOrderRequest
    ): ResponseEntity<OrderResponse> {
        val order = orderService.create(request)
        val location = URI.create("/api/v1/orders/${order.id}")
        return ResponseEntity.created(location).body(order)
    }

    @PutMapping("/{id}")
    fun updateOrder(
        @PathVariable id: Long,
        @Valid @RequestBody request: UpdateOrderRequest
    ): OrderResponse =
        orderService.update(id, request)

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun deleteOrder(@PathVariable id: Long) {
        orderService.delete(id)
    }
}
```

## Request and Response DTOs with Validation

```kotlin
data class CreateOrderRequest(
    @field:NotBlank(message = "Customer ID is required")
    val customerId: String,

    @field:NotEmpty(message = "At least one item is required")
    val items: List<@Valid OrderItemRequest>,

    @field:Size(max = 500, message = "Notes must be at most 500 characters")
    val notes: String? = null
)

data class OrderItemRequest(
    @field:NotBlank
    val productId: String,

    @field:Min(1)
    @field:Max(999)
    val quantity: Int,

    @field:DecimalMin("0.01")
    val unitPrice: BigDecimal
)

data class OrderResponse(
    val id: Long,
    val customerId: String,
    val items: List<OrderItemResponse>,
    val totalAmount: BigDecimal,
    val status: OrderStatus,
    val createdAt: Instant
)
```

## ResponseEntity Patterns

```kotlin
// Conditional response
@GetMapping("/{id}")
fun getOrder(@PathVariable id: Long): ResponseEntity<OrderResponse> =
    orderService.findById(id)
        ?.let { ResponseEntity.ok(it) }
        ?: ResponseEntity.notFound().build()

// Created with location header
@PostMapping
fun create(@Valid @RequestBody request: CreateOrderRequest): ResponseEntity<OrderResponse> {
    val order = orderService.create(request)
    return ResponseEntity
        .created(URI.create("/api/v1/orders/${order.id}"))
        .body(order)
}

// No content
@DeleteMapping("/{id}")
fun delete(@PathVariable id: Long): ResponseEntity<Void> {
    orderService.delete(id)
    return ResponseEntity.noContent().build()
}

// Custom headers
@GetMapping("/export")
fun export(): ResponseEntity<ByteArray> {
    val data = orderService.exportCsv()
    return ResponseEntity.ok()
        .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=orders.csv")
        .contentType(MediaType.APPLICATION_OCTET_STREAM)
        .body(data)
}
```

## Global Exception Handling with ProblemDetail (RFC 7807)

```kotlin
@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(EntityNotFoundException::class)
    fun handleNotFound(ex: EntityNotFoundException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.message ?: "Resource not found")
            .apply {
                title = "Resource Not Found"
                setProperty("timestamp", Instant.now())
            }

    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun handleValidation(ex: MethodArgumentNotValidException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Validation failed")
            .apply {
                title = "Validation Error"
                setProperty("errors", ex.bindingResult.fieldErrors.map { error ->
                    mapOf(
                        "field" to error.field,
                        "message" to (error.defaultMessage ?: "Invalid value"),
                        "rejectedValue" to error.rejectedValue
                    )
                })
            }

    @ExceptionHandler(AccessDeniedException::class)
    fun handleAccessDenied(ex: AccessDeniedException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.FORBIDDEN, "Access denied")

    @ExceptionHandler(ConflictException::class)
    fun handleConflict(ex: ConflictException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.message ?: "Conflict")

    @ExceptionHandler(Exception::class)
    fun handleGeneric(ex: Exception, request: WebRequest): ProblemDetail {
        // Log full exception server-side, return safe message to client
        logger.error("Unhandled exception for request: ${request.getDescription(false)}", ex)
        return ProblemDetail.forStatusAndDetail(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "An unexpected error occurred"
        )
    }

    companion object {
        private val logger = LoggerFactory.getLogger(GlobalExceptionHandler::class.java)
    }
}
```

## Custom Domain Exceptions

```kotlin
sealed class DomainException(message: String) : RuntimeException(message)

class EntityNotFoundException(entity: String, id: Any) :
    DomainException("$entity with id $id not found")

class ConflictException(message: String) : DomainException(message)

class BusinessRuleViolationException(message: String) : DomainException(message)
```

## HandlerInterceptor

```kotlin
@Component
class RequestLoggingInterceptor : HandlerInterceptor {

    override fun preHandle(
        request: HttpServletRequest,
        response: HttpServletResponse,
        handler: Any
    ): Boolean {
        request.setAttribute("startTime", System.currentTimeMillis())
        logger.info("→ {} {} from {}", request.method, request.requestURI, request.remoteAddr)
        return true
    }

    override fun afterCompletion(
        request: HttpServletRequest,
        response: HttpServletResponse,
        handler: Any,
        ex: Exception?
    ) {
        val startTime = request.getAttribute("startTime") as? Long ?: return
        val duration = System.currentTimeMillis() - startTime
        logger.info("← {} {} [{}] in {}ms",
            request.method, request.requestURI, response.status, duration)
    }

    companion object {
        private val logger = LoggerFactory.getLogger(RequestLoggingInterceptor::class.java)
    }
}

@Configuration
class WebMvcConfig(
    private val loggingInterceptor: RequestLoggingInterceptor
) : WebMvcConfigurer {

    override fun addInterceptors(registry: InterceptorRegistry) {
        registry.addInterceptor(loggingInterceptor)
            .addPathPatterns("/api/**")
            .excludePathPatterns("/api/health")
    }
}
```

## Content Negotiation

```kotlin
@GetMapping(value = ["/{id}"], produces = [MediaType.APPLICATION_JSON_VALUE, MediaType.APPLICATION_XML_VALUE])
fun getOrder(@PathVariable id: Long): OrderResponse =
    orderService.findById(id) ?: throw EntityNotFoundException("Order", id)
```

## File Upload

```kotlin
@RestController
@RequestMapping("/api/v1/files")
class FileUploadController(
    private val storageService: StorageService
) {

    @PostMapping(consumes = [MediaType.MULTIPART_FORM_DATA_VALUE])
    fun upload(
        @RequestParam("file") file: MultipartFile,
        @RequestParam("description", required = false) description: String?
    ): ResponseEntity<FileResponse> {
        if (file.isEmpty) {
            throw BadRequestException("File must not be empty")
        }
        if (file.size > 10_000_000) {
            throw BadRequestException("File size must be under 10MB")
        }
        val stored = storageService.store(file, description)
        return ResponseEntity.created(URI.create("/api/v1/files/${stored.id}")).body(stored)
    }

    @GetMapping("/{id}")
    fun download(@PathVariable id: String): ResponseEntity<Resource> {
        val file = storageService.load(id)
        return ResponseEntity.ok()
            .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"${file.filename}\"")
            .contentType(MediaType.parseMediaType(file.contentType))
            .body(file.resource)
    }
}
```

## CORS Configuration

```kotlin
@Configuration
class CorsConfig : WebMvcConfigurer {

    override fun addCorsMappings(registry: CorsRegistry) {
        registry.addMapping("/api/**")
            .allowedOrigins("https://app.example.com", "https://admin.example.com")
            .allowedMethods("GET", "POST", "PUT", "DELETE", "PATCH")
            .allowedHeaders("*")
            .allowCredentials(true)
            .maxAge(3600)
    }
}
```

Per-controller or per-method CORS:

```kotlin
@CrossOrigin(origins = ["https://app.example.com"])
@GetMapping("/public-data")
fun getPublicData(): List<PublicItem> = service.findPublicItems()
```

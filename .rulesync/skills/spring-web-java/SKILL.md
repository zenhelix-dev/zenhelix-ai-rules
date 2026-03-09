---
name: spring-web-java
description: "Java implementation patterns for Spring Web MVC. Use with `spring-web` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Web MVC — Java

Prerequisites: load `spring-web` skill for foundational concepts.

## REST Controllers

```java
@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @GetMapping
    public Page<OrderResponse> listOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) OrderStatus status) {
        return orderService.findAll(status, PageRequest.of(page, size));
    }

    @GetMapping("/{id}")
    public ResponseEntity<OrderResponse> getOrder(@PathVariable Long id) {
        return orderService.findById(id)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<OrderResponse> createOrder(
            @Valid @RequestBody CreateOrderRequest request) {
        OrderResponse order = orderService.create(request);
        URI location = URI.create("/api/v1/orders/" + order.id());
        return ResponseEntity.created(location).body(order);
    }

    @PutMapping("/{id}")
    public OrderResponse updateOrder(
            @PathVariable Long id,
            @Valid @RequestBody UpdateOrderRequest request) {
        return orderService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteOrder(@PathVariable Long id) {
        orderService.delete(id);
    }
}
```

## Request and Response DTOs with Validation

```java
public record CreateOrderRequest(
    @NotBlank(message = "Customer ID is required")
    String customerId,

    @NotEmpty(message = "At least one item is required")
    List<@Valid OrderItemRequest> items,

    @Size(max = 500, message = "Notes must be at most 500 characters")
    String notes
) {}

public record OrderItemRequest(
    @NotBlank String productId,
    @Min(1) @Max(999) int quantity,
    @DecimalMin("0.01") BigDecimal unitPrice
) {}

public record OrderResponse(
    Long id,
    String customerId,
    List<OrderItemResponse> items,
    BigDecimal totalAmount,
    OrderStatus status,
    Instant createdAt
) {}
```

## ResponseEntity Patterns

<!-- TODO: Add Java equivalent -->

## Global Exception Handling with ProblemDetail (RFC 7807)

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger logger = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(EntityNotFoundException.class)
    public ProblemDetail handleNotFound(EntityNotFoundException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.NOT_FOUND, ex.getMessage());
        problem.setTitle("Resource Not Found");
        problem.setProperty("timestamp", Instant.now());
        return problem;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.BAD_REQUEST, "Validation failed");
        problem.setTitle("Validation Error");
        List<Map<String, Object>> errors = ex.getBindingResult().getFieldErrors().stream()
            .map(error -> Map.<String, Object>of(
                "field", error.getField(),
                "message", Objects.requireNonNullElse(error.getDefaultMessage(), "Invalid value"),
                "rejectedValue", Objects.toString(error.getRejectedValue(), "null")
            ))
            .toList();
        problem.setProperty("errors", errors);
        return problem;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleGeneric(Exception ex, WebRequest request) {
        logger.error("Unhandled exception for request: {}", request.getDescription(false), ex);
        return ProblemDetail.forStatusAndDetail(
            HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred");
    }
}
```

## Custom Domain Exceptions

<!-- TODO: Add Java equivalent -->

## HandlerInterceptor

<!-- TODO: Add Java equivalent -->

## Content Negotiation

<!-- TODO: Add Java equivalent -->

## File Upload

<!-- TODO: Add Java equivalent -->

## CORS Configuration

```java
@Configuration
public class CorsConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
            .allowedOrigins("https://app.example.com", "https://admin.example.com")
            .allowedMethods("GET", "POST", "PUT", "DELETE", "PATCH")
            .allowedHeaders("*")
            .allowCredentials(true)
            .maxAge(3600);
    }
}
```

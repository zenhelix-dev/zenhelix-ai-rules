---
name: spring-webflux-java
description: "Java implementation patterns for Spring WebFlux. Use with `spring-webflux` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring WebFlux — Java

Prerequisites: load `spring-webflux` skill for foundational concepts.

## Annotated Controllers (Mono/Flux)

```java
@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {

    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @GetMapping
    public Flux<OrderResponse> listOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return orderService.findAll(page, size);
    }

    @GetMapping("/{id}")
    public Mono<ResponseEntity<OrderResponse>> getOrder(@PathVariable Long id) {
        return orderService.findById(id)
            .map(ResponseEntity::ok)
            .defaultIfEmpty(ResponseEntity.notFound().build());
    }

    @PostMapping
    public Mono<ResponseEntity<OrderResponse>> createOrder(
            @Valid @RequestBody CreateOrderRequest request) {
        return orderService.create(request)
            .map(order -> ResponseEntity
                .created(URI.create("/api/v1/orders/" + order.id()))
                .body(order));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public Mono<Void> deleteOrder(@PathVariable Long id) {
        return orderService.delete(id);
    }
}
```

## Functional Endpoints (Router Functions)

```java
@Configuration
public class OrderRouter {

    @Bean
    public RouterFunction<ServerResponse> orderRoutes(OrderHandler handler) {
        return RouterFunctions.route()
            .path("/api/v1/orders", builder -> builder
                .GET("", handler::listOrders)
                .GET("/{id}", handler::getOrder)
                .POST("", handler::createOrder)
                .DELETE("/{id}", handler::deleteOrder)
            )
            .build();
    }
}

@Component
public class OrderHandler {

    private final OrderService orderService;

    public OrderHandler(OrderService orderService) {
        this.orderService = orderService;
    }

    public Mono<ServerResponse> listOrders(ServerRequest request) {
        int page = Integer.parseInt(request.queryParam("page").orElse("0"));
        int size = Integer.parseInt(request.queryParam("size").orElse("20"));
        return ServerResponse.ok()
            .contentType(MediaType.APPLICATION_JSON)
            .body(orderService.findAll(page, size), OrderResponse.class);
    }

    public Mono<ServerResponse> getOrder(ServerRequest request) {
        Long id = Long.parseLong(request.pathVariable("id"));
        return orderService.findById(id)
            .flatMap(order -> ServerResponse.ok()
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(order))
            .switchIfEmpty(ServerResponse.notFound().build());
    }
}
```

## WebClient

```java
@Service
public class PaymentService {

    private final WebClient webClient;

    public PaymentService(WebClient.Builder webClientBuilder) {
        this.webClient = webClientBuilder
            .baseUrl("https://api.payment.com")
            .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
            .build();
    }

    public Mono<PaymentResponse> processPayment(PaymentRequest request) {
        return webClient.post()
            .uri("/v1/charges")
            .bodyValue(request)
            .retrieve()
            .onStatus(HttpStatusCode::is4xxClientError, response ->
                response.bodyToMono(String.class)
                    .map(body -> new PaymentException("Payment rejected: " + body)))
            .bodyToMono(PaymentResponse.class);
    }

    public Flux<Transaction> getTransactions(String accountId) {
        return webClient.get()
            .uri("/v1/accounts/{id}/transactions", accountId)
            .retrieve()
            .bodyToFlux(Transaction.class);
    }
}
```

### WebClient with Retry and Timeout

<!-- TODO: Add Java equivalent -->

## Server-Sent Events (SSE)

```java
@GetMapping(produces = MediaType.TEXT_EVENT_STREAM_VALUE)
public Flux<ServerSentEvent<EventData>> streamEvents() {
    return eventService.streamEvents()
        .map(event -> ServerSentEvent.<EventData>builder(event)
            .id(String.valueOf(event.id()))
            .event(event.type())
            .retry(Duration.ofSeconds(5))
            .build());
}
```

## Reactive Error Handling

```java
public Mono<OrderResponse> createOrder(CreateOrderRequest request) {
    return orderRepository.save(request.toEntity())
        .flatMap(order -> paymentService.processPayment(order.toPaymentRequest())
            .map(payment -> order.toResponse(payment))
            .onErrorResume(PaymentException.class, ex ->
                orderRepository.updateStatus(order.id(), OrderStatus.PAYMENT_FAILED)
                    .then(Mono.error(new BusinessException(
                        "Payment failed for order " + order.id() + ": " + ex.getMessage()))))
        );
}
```

## R2DBC Integration

<!-- TODO: Add Java equivalent -->

## Testing with WebTestClient

<!-- TODO: Add Java equivalent -->

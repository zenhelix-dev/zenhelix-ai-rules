---
name: spring-webflux-kotlin
description: "Kotlin implementation patterns for Spring WebFlux. Use with `spring-webflux` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring WebFlux — Kotlin

Prerequisites: load `spring-webflux` skill for foundational concepts.

## Annotated Controllers (Coroutines — preferred)

```kotlin
@RestController
@RequestMapping("/api/v1/orders")
class OrderController(
    private val orderService: OrderService
) {

    @GetMapping
    fun listOrders(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): Flow<OrderResponse> =
        orderService.findAll(page, size)

    @GetMapping("/{id}")
    suspend fun getOrder(@PathVariable id: Long): ResponseEntity<OrderResponse> {
        val order = orderService.findById(id)
        return if (order != null) ResponseEntity.ok(order)
        else ResponseEntity.notFound().build()
    }

    @PostMapping
    suspend fun createOrder(
        @Valid @RequestBody request: CreateOrderRequest
    ): ResponseEntity<OrderResponse> {
        val order = orderService.create(request)
        return ResponseEntity
            .created(URI.create("/api/v1/orders/${order.id}"))
            .body(order)
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    suspend fun deleteOrder(@PathVariable id: Long) {
        orderService.delete(id)
    }
}
```

## Functional Endpoints (Router Functions)

```kotlin
@Configuration
class OrderRouter {

    @Bean
    fun orderRoutes(handler: OrderHandler): RouterFunction<ServerResponse> =
        coRouter {
            "/api/v1/orders".nest {
                GET("", handler::listOrders)
                GET("/{id}", handler::getOrder)
                POST("", handler::createOrder)
                DELETE("/{id}", handler::deleteOrder)
            }
        }
}

@Component
class OrderHandler(
    private val orderService: OrderService
) {

    suspend fun listOrders(request: ServerRequest): ServerResponse {
        val page = request.queryParam("page").orElse("0").toInt()
        val size = request.queryParam("size").orElse("20").toInt()
        val orders = orderService.findAll(page, size)
        return ServerResponse.ok()
            .contentType(MediaType.APPLICATION_JSON)
            .bodyAndAwait(orders)
    }

    suspend fun getOrder(request: ServerRequest): ServerResponse {
        val id = request.pathVariable("id").toLong()
        val order = orderService.findById(id)
        return if (order != null) {
            ServerResponse.ok()
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValueAndAwait(order)
        } else {
            ServerResponse.notFound().buildAndAwait()
        }
    }

    suspend fun createOrder(request: ServerRequest): ServerResponse {
        val body = request.awaitBody<CreateOrderRequest>()
        val order = orderService.create(body)
        return ServerResponse.created(URI.create("/api/v1/orders/${order.id}"))
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValueAndAwait(order)
    }

    suspend fun deleteOrder(request: ServerRequest): ServerResponse {
        val id = request.pathVariable("id").toLong()
        orderService.delete(id)
        return ServerResponse.noContent().buildAndAwait()
    }
}
```

## WebClient (Coroutines)

```kotlin
@Service
class PaymentService(
    private val webClientBuilder: WebClient.Builder
) {
    private val webClient = webClientBuilder
        .baseUrl("https://api.payment.com")
        .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
        .build()

    suspend fun processPayment(request: PaymentRequest): PaymentResponse =
        webClient.post()
            .uri("/v1/charges")
            .bodyValue(request)
            .retrieve()
            .onStatus({ it.is4xxClientError }) { response ->
                response.bodyToMono<String>().map { body ->
                    PaymentException("Payment rejected: $body")
                }
            }
            .awaitBody()

    fun getTransactions(accountId: String): Flow<Transaction> =
        webClient.get()
            .uri("/v1/accounts/{id}/transactions", accountId)
            .retrieve()
            .bodyToFlux<Transaction>()
            .asFlow()
}
```

### WebClient with Retry and Timeout

```kotlin
suspend fun fetchWithResilience(id: String): DataResponse =
    webClient.get()
        .uri("/data/{id}", id)
        .retrieve()
        .bodyToMono<DataResponse>()
        .timeout(Duration.ofSeconds(5))
        .retryWhen(Retry.backoff(3, Duration.ofMillis(500))
            .filter { it is WebClientResponseException.ServiceUnavailable })
        .awaitSingle()
```

## Server-Sent Events (SSE)

```kotlin
@RestController
@RequestMapping("/api/v1/events")
class EventController(
    private val eventService: EventService
) {

    @GetMapping(produces = [MediaType.TEXT_EVENT_STREAM_VALUE])
    fun streamEvents(): Flow<ServerSentEvent<EventData>> =
        eventService.streamEvents()
            .map { event ->
                ServerSentEvent.builder(event)
                    .id(event.id.toString())
                    .event(event.type)
                    .retry(Duration.ofSeconds(5))
                    .build()
            }
}
```

## Reactive Error Handling

```kotlin
@Service
class OrderService(
    private val orderRepository: OrderRepository,
    private val paymentService: PaymentService
) {

    suspend fun createOrder(request: CreateOrderRequest): OrderResponse {
        val order = orderRepository.save(request.toEntity())
        val payment = try {
            paymentService.processPayment(order.toPaymentRequest())
        } catch (ex: PaymentException) {
            orderRepository.updateStatus(order.id, OrderStatus.PAYMENT_FAILED)
            throw BusinessException("Payment failed for order ${order.id}: ${ex.message}")
        }
        return orderRepository.updateStatus(order.id, OrderStatus.CONFIRMED)
            .toResponse(payment)
    }
}
```

## R2DBC Integration

```kotlin
@Service
class OrderService(
    private val orderRepository: OrderRepository
) {
    suspend fun findById(id: Long): Order? =
        orderRepository.findById(id)

    fun findByStatus(status: OrderStatus): Flow<Order> =
        orderRepository.findByStatus(status)
}

interface OrderRepository : CoroutineCrudRepository<Order, Long> {
    fun findByStatus(status: OrderStatus): Flow<Order>

    @Query("SELECT * FROM orders WHERE customer_id = :customerId ORDER BY created_at DESC")
    fun findByCustomerId(customerId: String): Flow<Order>
}
```

## Testing with WebTestClient

```kotlin
@WebFluxTest(OrderController::class)
class OrderControllerTest {

    @Autowired
    private lateinit var webTestClient: WebTestClient

    @MockkBean
    private lateinit var orderService: OrderService

    @Test
    fun `should return order by id`() {
        val order = OrderResponse(id = 1, status = OrderStatus.ACTIVE)
        coEvery { orderService.findById(1) } returns order

        webTestClient.get()
            .uri("/api/v1/orders/1")
            .exchange()
            .expectStatus().isOk
            .expectBody<OrderResponse>()
            .isEqualTo(order)
    }

    @Test
    fun `should return 404 when order not found`() {
        coEvery { orderService.findById(999) } returns null

        webTestClient.get()
            .uri("/api/v1/orders/999")
            .exchange()
            .expectStatus().isNotFound
    }

    @Test
    fun `should create order`() {
        val request = CreateOrderRequest(customerId = "cust-1", items = listOf())
        val response = OrderResponse(id = 1, status = OrderStatus.CREATED)
        coEvery { orderService.create(request) } returns response

        webTestClient.post()
            .uri("/api/v1/orders")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(request)
            .exchange()
            .expectStatus().isCreated
            .expectHeader().location("/api/v1/orders/1")
            .expectBody<OrderResponse>()
            .isEqualTo(response)
    }
}
```

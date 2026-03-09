---
name: spring-cloud-kotlin
description: "Kotlin implementation patterns for Spring Cloud. Use with `spring-cloud` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Cloud — Kotlin

Prerequisites: load `spring-cloud` skill for foundational concepts.

## Spring Cloud Config

### Config Server Setup

```kotlin
@SpringBootApplication
@EnableConfigServer
class ConfigServerApplication

fun main(args: Array<String>) {
    runApplication<ConfigServerApplication>(*args)
}
```

### Refresh Configuration at Runtime

```kotlin
@RefreshScope
@Service
class FeatureFlagService(
    @Value("\${app.feature.new-checkout:false}") private val newCheckoutEnabled: Boolean
) {
    fun isNewCheckoutEnabled(): Boolean = newCheckoutEnabled
}
```

## Spring Cloud Gateway

### Route Configuration

```kotlin
@Configuration
class GatewayConfig {

    @Bean
    fun routes(builder: RouteLocatorBuilder): RouteLocator =
        builder.routes()
            .route("order-service") { r ->
                r.path("/api/v1/orders/**")
                    .filters { f ->
                        f.stripPrefix(0)
                            .addRequestHeader("X-Gateway", "true")
                            .circuitBreaker { cb ->
                                cb.setName("orderServiceCB")
                                cb.setFallbackUri("forward:/fallback/orders")
                            }
                            .retry { retry ->
                                retry.retries = 3
                                retry.setStatuses(HttpStatus.SERVICE_UNAVAILABLE)
                            }
                    }
                    .uri("lb://order-service")
            }
            .route("user-service") { r ->
                r.path("/api/v1/users/**")
                    .filters { f ->
                        f.stripPrefix(0)
                            .requestRateLimiter { rl ->
                                rl.rateLimiter = redisRateLimiter()
                            }
                    }
                    .uri("lb://user-service")
            }
            .build()

    @Bean
    fun redisRateLimiter(): RedisRateLimiter =
        RedisRateLimiter(10, 20) // 10 requests/sec, burst of 20
}
```

### Custom Gateway Filter

```kotlin
@Component
class AuthGatewayFilterFactory : AbstractGatewayFilterFactory<AuthGatewayFilterFactory.Config>(Config::class.java) {

    override fun apply(config: Config): GatewayFilter =
        GatewayFilter { exchange, chain ->
            val token = exchange.request.headers.getFirst(HttpHeaders.AUTHORIZATION)
            if (token == null || !token.startsWith("Bearer ")) {
                exchange.response.statusCode = HttpStatus.UNAUTHORIZED
                return@GatewayFilter exchange.response.setComplete()
            }
            chain.filter(exchange)
        }

    class Config
}
```

### Global Filters

```kotlin
@Component
class LoggingGlobalFilter : GlobalFilter, Ordered {

    private val logger = LoggerFactory.getLogger(javaClass)

    override fun filter(exchange: ServerWebExchange, chain: GatewayFilterChain): Mono<Void> {
        val request = exchange.request
        val requestId = UUID.randomUUID().toString()
        logger.info("Gateway request: {} {} [{}]", request.method, request.uri.path, requestId)

        val mutatedExchange = exchange.mutate()
            .request(exchange.request.mutate().header("X-Request-Id", requestId).build())
            .build()

        val startTime = System.currentTimeMillis()
        return chain.filter(mutatedExchange).then(Mono.fromRunnable {
            val duration = System.currentTimeMillis() - startTime
            logger.info("Gateway response: {} {} [{}] in {}ms",
                request.method, request.uri.path, requestId, duration)
        })
    }

    override fun getOrder(): Int = -1
}
```

## Circuit Breaker with Resilience4j

### Dependencies

```kotlin
implementation("org.springframework.cloud:spring-cloud-starter-circuitbreaker-resilience4j")
```

### Service with Circuit Breaker

```kotlin
@Service
class PaymentService(
    private val paymentClient: PaymentClient
) {

    @CircuitBreaker(name = "paymentService", fallbackMethod = "paymentFallback")
    @Retry(name = "paymentService")
    @TimeLimiter(name = "paymentService")
    suspend fun processPayment(request: PaymentRequest): PaymentResponse =
        paymentClient.charge(request)

    private suspend fun paymentFallback(
        request: PaymentRequest,
        ex: Exception
    ): PaymentResponse {
        logger.warn("Payment circuit breaker fallback for order ${request.orderId}: ${ex.message}")
        return PaymentResponse(
            status = PaymentStatus.PENDING,
            message = "Payment processing delayed, will retry"
        )
    }

    companion object {
        private val logger = LoggerFactory.getLogger(PaymentService::class.java)
    }
}
```

## Service Discovery

### Eureka Server

```kotlin
@SpringBootApplication
@EnableEurekaServer
class EurekaServerApplication

fun main(args: Array<String>) {
    runApplication<EurekaServerApplication>(*args)
}
```

## OpenFeign Declarative HTTP Clients

```kotlin
@FeignClient(
    name = "payment-service",
    fallbackFactory = PaymentClientFallbackFactory::class,
    configuration = [PaymentClientConfig::class]
)
interface PaymentClient {

    @PostMapping("/api/v1/payments")
    fun charge(@RequestBody request: PaymentRequest): PaymentResponse

    @GetMapping("/api/v1/payments/{id}")
    fun getPayment(@PathVariable id: String): PaymentResponse

    @GetMapping("/api/v1/payments")
    fun listPayments(
        @RequestParam("customerId") customerId: String,
        @RequestParam("page") page: Int,
        @RequestParam("size") size: Int
    ): Page<PaymentResponse>
}

@Component
class PaymentClientFallbackFactory : FallbackFactory<PaymentClient> {

    private val logger = LoggerFactory.getLogger(javaClass)

    override fun create(cause: Throwable): PaymentClient =
        object : PaymentClient {
            override fun charge(request: PaymentRequest): PaymentResponse {
                logger.error("Fallback for charge: ${cause.message}")
                return PaymentResponse(status = PaymentStatus.PENDING, message = "Service unavailable")
            }

            override fun getPayment(id: String): PaymentResponse {
                throw ServiceUnavailableException("Payment service unavailable")
            }

            override fun listPayments(customerId: String, page: Int, size: Int): Page<PaymentResponse> =
                Page.empty()
        }
}

@Configuration
class PaymentClientConfig {

    @Bean
    fun feignRequestInterceptor(): RequestInterceptor =
        RequestInterceptor { template ->
            val auth = SecurityContextHolder.getContext().authentication
            if (auth != null) {
                template.header(HttpHeaders.AUTHORIZATION, "Bearer ${(auth.credentials as? String)}")
            }
        }
}
```

## Load Balancing

```kotlin
@Configuration
class LoadBalancerConfig {

    @Bean
    fun webClientLoadBalanced(builder: WebClient.Builder): WebClient =
        builder
            .filter(loadBalancerExchangeFilterFunction())
            .build()

    @Bean
    @LoadBalanced
    fun restTemplate(): RestTemplate = RestTemplate()
}
```

## Distributed Tracing with Micrometer

```kotlin
implementation("io.micrometer:micrometer-tracing-bridge-otel")
implementation("io.opentelemetry:opentelemetry-exporter-zipkin")
```

## Spring Cloud Stream

```kotlin
@Configuration
class StreamConfig {

    @Bean
    fun orderCreatedConsumer(): Consumer<OrderCreatedEvent> = Consumer { event ->
        logger.info("Received order created event: ${event.orderId}")
        // Process event
    }

    @Bean
    fun orderStatusSupplier(orderEventService: OrderEventService): Supplier<Flux<OrderStatusEvent>> =
        Supplier { orderEventService.getStatusEvents() }

    @Bean
    fun orderTransformer(): Function<OrderCreatedEvent, NotificationEvent> = Function { event ->
        NotificationEvent(
            recipient = event.customerId,
            message = "Order ${event.orderId} has been created",
            type = NotificationType.EMAIL
        )
    }
}
```

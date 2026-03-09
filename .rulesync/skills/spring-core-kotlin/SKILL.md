---
name: spring-core-kotlin
description: "Kotlin implementation patterns for Spring Core. Use with `spring-core` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Core — Kotlin

Prerequisites: load `spring-core` skill for foundational concepts.

## Stereotype Annotations

```kotlin
@Component
class EmailValidator

@Service
class OrderService(
    private val orderRepository: OrderRepository,
    private val paymentGateway: PaymentGateway
)

@Repository
class JpaOrderRepository(
    private val entityManager: EntityManager
) : OrderRepository

@Controller
class OrderController(
    private val orderService: OrderService
)
```

## Dependency Injection

```kotlin
// PREFERRED: Constructor injection (automatic for single constructor)
@Service
class UserService(
    private val userRepository: UserRepository,
    private val passwordEncoder: PasswordEncoder
) {
    fun findById(id: Long): User? = userRepository.findById(id).orElse(null)
}

// Using @Qualifier when multiple implementations exist
@Service
class NotificationService(
    @Qualifier("email") private val emailSender: MessageSender,
    @Qualifier("sms") private val smsSender: MessageSender
)
```

### Anti-patterns to Avoid

```kotlin
// BAD: Field injection — hides dependencies, untestable without reflection
@Service
class BadService {
    @Autowired
    private lateinit var repository: UserRepository
}

// BAD: Setter injection — allows partially constructed objects
@Service
class AlsoBadService {
    private var repository: UserRepository? = null

    @Autowired
    fun setRepository(repository: UserRepository) {
        this.repository = repository
    }
}
```

## Configuration Classes

```kotlin
@Configuration
class AppConfig {

    @Bean
    fun objectMapper(): ObjectMapper =
        ObjectMapper()
            .registerKotlinModule()
            .registerModule(JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)

    @Bean
    fun restTemplate(builder: RestTemplateBuilder): RestTemplate =
        builder
            .connectTimeout(Duration.ofSeconds(5))
            .readTimeout(Duration.ofSeconds(10))
            .build()

    @Bean
    @ConditionalOnMissingBean
    fun passwordEncoder(): PasswordEncoder = BCryptPasswordEncoder(12)
}
```

## Type-Safe Configuration Properties

```kotlin
@ConfigurationProperties(prefix = "app.payment")
data class PaymentProperties(
    val gatewayUrl: String,
    val timeout: Duration = Duration.ofSeconds(5),
    val retryAttempts: Int = 3
)

@ConfigurationProperties(prefix = "app.notification")
data class NotificationProperties(
    val enabled: Boolean = true,
    val fromEmail: String
)

// Enable in main class or config
@SpringBootApplication
@ConfigurationPropertiesScan
class Application
```

### @Value for Simple Cases

```kotlin
@Service
class FeatureFlagService(
    @Value("\${app.feature.new-checkout:false}") private val newCheckoutEnabled: Boolean
)
```

## Profiles

```kotlin
@Configuration
@Profile("local")
class LocalConfig {
    @Bean
    fun dataSource(): DataSource =
        EmbeddedDatabaseBuilder()
            .setType(EmbeddedDatabaseType.H2)
            .build()
}

@Configuration
@Profile("production")
class ProductionConfig {
    @Bean
    fun dataSource(props: DataSourceProperties): DataSource =
        HikariDataSource(HikariConfig().apply {
            jdbcUrl = props.url
            username = props.username
            password = props.password
            maximumPoolSize = 20
        })
}

// Profile-specific beans
@Service
@Profile("!test")
class RealPaymentGateway : PaymentGateway

@Service
@Profile("test")
class MockPaymentGateway : PaymentGateway
```

## Custom Health Indicator

```kotlin
@Component
class PaymentGatewayHealthIndicator(
    private val paymentClient: PaymentClient
) : HealthIndicator {

    override fun health(): Health =
        try {
            paymentClient.ping()
            Health.up()
                .withDetail("gateway", "reachable")
                .build()
        } catch (ex: Exception) {
            Health.down()
                .withDetail("gateway", "unreachable")
                .withException(ex)
                .build()
        }
}
```

## Custom Metrics

```kotlin
@Service
class OrderService(
    private val meterRegistry: MeterRegistry,
    private val orderRepository: OrderRepository
) {
    private val orderCounter = Counter.builder("orders.created")
        .description("Number of orders created")
        .register(meterRegistry)

    fun createOrder(request: CreateOrderRequest): Order {
        val order = orderRepository.save(request.toEntity())
        orderCounter.increment()
        return order
    }
}
```

## Custom Auto-Configuration

```kotlin
@AutoConfiguration
@ConditionalOnClass(PaymentClient::class)
@EnableConfigurationProperties(PaymentProperties::class)
class PaymentAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    fun paymentClient(properties: PaymentProperties): PaymentClient =
        DefaultPaymentClient(
            baseUrl = properties.gatewayUrl,
            timeout = properties.timeout
        )

    @Bean
    @ConditionalOnProperty(prefix = "app.payment", name = ["retry-enabled"], havingValue = "true")
    fun retryablePaymentClient(
        delegate: PaymentClient,
        properties: PaymentProperties
    ): PaymentClient =
        RetryablePaymentClient(delegate, properties.retryAttempts)
}
```

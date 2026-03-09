---
name: spring-test-kotlin
description: "Kotlin implementation patterns for Spring Boot Test. Use with `spring-test` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Boot Test — Kotlin

Prerequisites: load `spring-test` skill for foundational concepts.

## @SpringBootTest — Full Context Tests

```kotlin
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class OrderIntegrationTest {

    @Autowired
    private lateinit var restTemplate: TestRestTemplate

    @Autowired
    private lateinit var orderRepository: OrderRepository

    @BeforeEach
    fun setup() {
        orderRepository.deleteAll()
    }

    @Test
    fun `should create and retrieve order`() {
        val request = CreateOrderRequest(
            customerId = "cust-1",
            items = listOf(OrderItemRequest("prod-1", 2, BigDecimal("25.00")))
        )

        val createResponse = restTemplate.postForEntity(
            "/api/v1/orders", request, OrderResponse::class.java
        )

        assertEquals(HttpStatus.CREATED, createResponse.statusCode)
        assertNotNull(createResponse.body?.id)

        val getResponse = restTemplate.getForEntity(
            "/api/v1/orders/${createResponse.body!!.id}", OrderResponse::class.java
        )

        assertEquals(HttpStatus.OK, getResponse.statusCode)
        assertEquals("cust-1", getResponse.body?.customerId)
    }
}
```

## Test Slices

### @WebMvcTest — Controller Layer (MockK + SpringMockK)

```kotlin
@WebMvcTest(OrderController::class)
class OrderControllerTest {

    @Autowired
    private lateinit var mockMvc: MockMvc

    @MockkBean
    private lateinit var orderService: OrderService

    @Test
    fun `should return order list`() {
        val orders = listOf(
            OrderResponse(id = 1, customerId = "c1", totalAmount = BigDecimal("100"), status = OrderStatus.CREATED),
            OrderResponse(id = 2, customerId = "c2", totalAmount = BigDecimal("200"), status = OrderStatus.CONFIRMED)
        )
        every { orderService.findAll(any()) } returns PageImpl(orders)

        mockMvc.get("/api/v1/orders") {
            param("page", "0")
            param("size", "20")
        }.andExpect {
            status { isOk() }
            jsonPath("$.content.length()") { value(2) }
            jsonPath("$.content[0].customerId") { value("c1") }
            jsonPath("$.content[1].status") { value("CONFIRMED") }
        }

        verify(exactly = 1) { orderService.findAll(any()) }
    }

    @Test
    fun `should return 404 when order not found`() {
        every { orderService.findById(999) } returns null

        mockMvc.get("/api/v1/orders/999")
            .andExpect { status { isNotFound() } }
    }

    @Test
    fun `should validate request body`() {
        mockMvc.post("/api/v1/orders") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"customerId": "", "items": []}"""
        }.andExpect {
            status { isBadRequest() }
            jsonPath("$.title") { value("Validation Error") }
            jsonPath("$.detail") { value("Validation failed") }
        }
    }

    @Test
    fun `should create order and return 201`() {
        val response = OrderResponse(
            id = 1, customerId = "cust-1",
            totalAmount = BigDecimal("50.00"), status = OrderStatus.CREATED
        )
        every { orderService.create(any()) } returns response

        mockMvc.post("/api/v1/orders") {
            contentType = MediaType.APPLICATION_JSON
            content = """{
                "customerId": "cust-1",
                "items": [{"productId": "prod-1", "quantity": 2, "unitPrice": 25.00}]
            }"""
        }.andExpect {
            status { isCreated() }
            header { string("Location", "/api/v1/orders/1") }
            jsonPath("$.id") { value(1) }
            jsonPath("$.customerId") { value("cust-1") }
        }
    }
}
```

### @DataJpaTest — Repository Layer

```kotlin
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(JpaAuditingConfig::class)
class OrderRepositoryTest {

    @Autowired
    private lateinit var orderRepository: OrderRepository

    @Autowired
    private lateinit var entityManager: TestEntityManager

    @Test
    fun `should find orders by customer id`() {
        val order1 = entityManager.persist(
            Order(customerId = "cust-1", totalAmount = BigDecimal("100"), status = OrderStatus.CREATED)
        )
        val order2 = entityManager.persist(
            Order(customerId = "cust-1", totalAmount = BigDecimal("200"), status = OrderStatus.CONFIRMED)
        )
        entityManager.persist(
            Order(customerId = "cust-2", totalAmount = BigDecimal("300"), status = OrderStatus.CREATED)
        )
        entityManager.flush()

        val orders = orderRepository.findByCustomerId("cust-1")

        assertEquals(2, orders.size)
        assertTrue(orders.all { it.customerId == "cust-1" })
    }

    @Test
    fun `should paginate results`() {
        repeat(25) { i ->
            entityManager.persist(
                Order(customerId = "cust-$i", totalAmount = BigDecimal(i * 10), status = OrderStatus.CREATED)
            )
        }
        entityManager.flush()

        val page = orderRepository.findAll(PageRequest.of(0, 10, Sort.by("totalAmount")))

        assertEquals(10, page.content.size)
        assertEquals(25, page.totalElements)
        assertEquals(3, page.totalPages)
    }
}
```

### @DataR2dbcTest — Reactive Repository

```kotlin
@DataR2dbcTest
class OrderReactiveRepositoryTest {

    @Autowired
    private lateinit var orderRepository: OrderRepository

    @Test
    fun `should save and find order`() = runBlocking {
        val order = orderRepository.save(
            Order(customerId = "cust-1", totalAmount = BigDecimal("100.00"))
        )
        assertNotNull(order.id)

        val found = orderRepository.findById(order.id!!)
        assertNotNull(found)
        assertEquals("cust-1", found!!.customerId)
    }
}
```

### @RestClientTest

```kotlin
@RestClientTest(PaymentClient::class)
class PaymentClientTest {

    @Autowired
    private lateinit var paymentClient: PaymentClient

    @Autowired
    private lateinit var mockServer: MockRestServiceServer

    @Test
    fun `should call payment API`() {
        mockServer.expect(requestTo("/v1/charges"))
            .andExpect(method(HttpMethod.POST))
            .andExpect(jsonPath("$.amount").value(100))
            .andRespond(withSuccess(
                """{"id": "pay-1", "status": "COMPLETED"}""",
                MediaType.APPLICATION_JSON
            ))

        val response = paymentClient.charge(PaymentRequest(amount = BigDecimal("100")))

        assertEquals("COMPLETED", response.status)
        mockServer.verify()
    }
}
```

## @MockBean and @SpyBean (with MockK)

```kotlin
// Add dependency: com.ninja-squad:springmockk
@WebMvcTest(OrderController::class)
class OrderControllerTest {

    @MockkBean
    private lateinit var orderService: OrderService

    @MockkBean
    private lateinit var paymentService: PaymentService

    @SpykBean
    private lateinit var auditService: AuditService

    @Test
    fun `should mock service and spy on audit`() {
        every { orderService.findById(1) } returns OrderResponse(id = 1, customerId = "c1")
        every { paymentService.getStatus(any()) } returns PaymentStatus.COMPLETED

        // ... test logic ...

        verify { auditService.log(any()) } // Verify spy was called
    }
}
```

## TestContainers

```kotlin
@SpringBootTest
@Testcontainers
class OrderIntegrationTest {

    companion object {
        @Container
        val postgres = PostgreSQLContainer("postgres:16-alpine")
            .withDatabaseName("orders_test")
            .withUsername("test")
            .withPassword("test")

        @Container
        val redis = GenericContainer(DockerImageName.parse("redis:7-alpine"))
            .withExposedPorts(6379)

        @Container
        val kafka = KafkaContainer(DockerImageName.parse("confluentinc/cp-kafka:7.5.0"))

        @JvmStatic
        @DynamicPropertySource
        fun configureProperties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url", postgres::getJdbcUrl)
            registry.add("spring.datasource.username", postgres::getUsername)
            registry.add("spring.datasource.password", postgres::getPassword)
            registry.add("spring.data.redis.host", redis::getHost)
            registry.add("spring.data.redis.port") { redis.getMappedPort(6379) }
            registry.add("spring.kafka.bootstrap-servers", kafka::getBootstrapServers)
        }
    }

    @Autowired
    private lateinit var orderRepository: OrderRepository

    @Test
    fun `should persist order to PostgreSQL`() {
        val order = orderRepository.save(
            Order(customerId = "cust-1", totalAmount = BigDecimal("100.00"))
        )
        assertNotNull(order.id)

        val found = orderRepository.findById(order.id!!)
        assertTrue(found.isPresent)
    }
}
```

### Reusable TestContainer Base Class

```kotlin
@SpringBootTest
abstract class AbstractIntegrationTest {

    companion object {
        private val postgres = PostgreSQLContainer("postgres:16-alpine")
            .withDatabaseName("test")
            .withUsername("test")
            .withPassword("test")

        init {
            postgres.start() // Shared across all test classes
        }

        @JvmStatic
        @DynamicPropertySource
        fun configureProperties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url", postgres::getJdbcUrl)
            registry.add("spring.datasource.username", postgres::getUsername)
            registry.add("spring.datasource.password", postgres::getPassword)
        }
    }
}

class OrderServiceTest : AbstractIntegrationTest() {
    @Test
    fun `should work with real database`() { /* ... */ }
}
```

## Test Configuration

### @TestConfiguration

```kotlin
@TestConfiguration
class TestSecurityConfig {

    @Bean
    fun testSecurityFilterChain(http: HttpSecurity): SecurityFilterChain =
        http
            .csrf { it.disable() }
            .authorizeHttpRequests { it.anyRequest().permitAll() }
            .build()
}

@SpringBootTest
@Import(TestSecurityConfig::class)
class OrderServiceTest { /* ... */ }
```

### Test Properties

```kotlin
@SpringBootTest
@TestPropertySource(properties = [
    "app.payment.gateway-url=http://localhost:8089",
    "app.feature.new-checkout=true"
])
class FeatureToggleTest { /* ... */ }
```

```kotlin
@SpringBootTest
@ActiveProfiles("test")
class OrderServiceTest { /* ... */ }
```

## @Sql for Database Setup

```kotlin
@SpringBootTest
@Sql(scripts = ["/sql/setup-orders.sql"], executionPhase = Sql.ExecutionPhase.BEFORE_TEST_METHOD)
@Sql(scripts = ["/sql/cleanup.sql"], executionPhase = Sql.ExecutionPhase.AFTER_TEST_METHOD)
class OrderReportTest {

    @Test
    fun `should generate report from seeded data`() { /* ... */ }
}
```

## WebTestClient for WebFlux

```kotlin
@WebFluxTest(OrderController::class)
class OrderWebFluxTest {

    @Autowired
    private lateinit var webTestClient: WebTestClient

    @MockkBean
    private lateinit var orderService: OrderService

    @Test
    fun `should stream orders as SSE`() {
        coEvery { orderService.streamOrders() } returns flowOf(
            OrderEvent(id = 1, type = "CREATED"),
            OrderEvent(id = 2, type = "UPDATED")
        )

        webTestClient.get()
            .uri("/api/v1/orders/stream")
            .accept(MediaType.TEXT_EVENT_STREAM)
            .exchange()
            .expectStatus().isOk
            .expectBodyList<OrderEvent>()
            .hasSize(2)
    }
}
```

## JaCoCo Coverage

```kotlin
// build.gradle.kts
plugins {
    jacoco
}

tasks.jacocoTestReport {
    dependsOn(tasks.test)
    reports {
        xml.required.set(true)
        html.required.set(true)
    }
}

tasks.jacocoTestCoverageVerification {
    violationRules {
        rule {
            limit {
                minimum = "0.80".toBigDecimal() // 80% minimum
            }
        }
        rule {
            element = "CLASS"
            excludes = listOf(
                "*.config.*",
                "*.dto.*",
                "*.Application*"
            )
            limit {
                minimum = "0.80".toBigDecimal()
            }
        }
    }
}

tasks.test {
    finalizedBy(tasks.jacocoTestReport)
}
```

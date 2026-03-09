---
name: spring-test-java
description: "Java implementation patterns for Spring Boot Test. Use with `spring-test` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Boot Test — Java

Prerequisites: load `spring-test` skill for foundational concepts.

## @SpringBootTest — Full Context Tests

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class OrderIntegrationTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Autowired
    private OrderRepository orderRepository;

    @BeforeEach
    void setup() {
        orderRepository.deleteAll();
    }

    @Test
    void shouldCreateAndRetrieveOrder() {
        var request = new CreateOrderRequest("cust-1",
            List.of(new OrderItemRequest("prod-1", 2, new BigDecimal("25.00"))));

        var createResponse = restTemplate.postForEntity(
            "/api/v1/orders", request, OrderResponse.class);

        assertEquals(HttpStatus.CREATED, createResponse.getStatusCode());
        assertNotNull(createResponse.getBody().id());

        var getResponse = restTemplate.getForEntity(
            "/api/v1/orders/" + createResponse.getBody().id(), OrderResponse.class);

        assertEquals(HttpStatus.OK, getResponse.getStatusCode());
        assertEquals("cust-1", getResponse.getBody().customerId());
    }
}
```

## Test Slices

### @WebMvcTest — Controller Layer (Mockito)

```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private OrderService orderService;

    @Test
    void shouldReturnOrderList() throws Exception {
        var orders = List.of(
            new OrderResponse(1L, "c1", new BigDecimal("100"), OrderStatus.CREATED));
        when(orderService.findAll(any())).thenReturn(new PageImpl<>(orders));

        mockMvc.perform(get("/api/v1/orders")
                .param("page", "0")
                .param("size", "20"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.content.length()").value(1))
            .andExpect(jsonPath("$.content[0].customerId").value("c1"));

        verify(orderService, times(1)).findAll(any());
    }

    @Test
    void shouldValidateRequestBody() throws Exception {
        mockMvc.perform(post("/api/v1/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"customerId": "", "items": []}"""))
            .andExpect(status().isBadRequest());
    }
}
```

### @DataJpaTest — Repository Layer

<!-- TODO: Add Java equivalent for @DataJpaTest -->

### @DataR2dbcTest — Reactive Repository

<!-- TODO: Add Java equivalent for @DataR2dbcTest -->

### @RestClientTest

<!-- TODO: Add Java equivalent for @RestClientTest -->

## @MockBean and @SpyBean (with Mockito)

```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @MockBean
    private OrderService orderService;

    @SpyBean
    private AuditService auditService;

    @Test
    void shouldMockServiceAndSpyOnAudit() {
        when(orderService.findById(1L)).thenReturn(new OrderResponse(1L, "c1"));
        // ... test logic ...
        verify(auditService).log(any());
    }
}
```

## TestContainers

```java
@SpringBootTest
@Testcontainers
class OrderIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
        .withDatabaseName("orders_test")
        .withUsername("test")
        .withPassword("test");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }
}
```

### Reusable TestContainer Base Class

<!-- TODO: Add Java equivalent for Reusable TestContainer Base Class -->

## Test Configuration

### @TestConfiguration

<!-- TODO: Add Java equivalent for @TestConfiguration -->

### Test Properties

<!-- TODO: Add Java equivalent for Test Properties -->

## @Sql for Database Setup

<!-- TODO: Add Java equivalent for @Sql -->

## WebTestClient for WebFlux

<!-- TODO: Add Java equivalent for WebTestClient -->

## JaCoCo Coverage

<!-- TODO: Add Java equivalent for JaCoCo Coverage (build.gradle or pom.xml) -->

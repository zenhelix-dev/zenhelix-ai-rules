---
name: tdd-guide-java
targets: ["claudecode"]
description: >-
  Java TDD guide with Mockito, MockMvc, AssertJ, Spring Boot Test.
  Use with base `tdd-guide` for TDD methodology.
claudecode:
  model: opus
---

# TDD Specialist — Java

## Unit Test Examples

### Basic Unit Test

```java
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class OrderCalculatorTest {

    @Test
    void should_calculate_total_with_discount_when_order_has_promotion() {
        var order = new Order(List.of(item(100)), Promotion.PERCENT_10);
        var result = orderCalculator.calculateTotal(order);
        assertThat(result).isEqualTo(new Money(90));
    }
}
```

### Service Test with Mockito

```java
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import static org.mockito.Mockito.*;
import static org.assertj.core.api.Assertions.*;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private ApplicationEventPublisher eventPublisher;

    @InjectMocks
    private UserService userService;

    @Test
    void should_return_user_when_found_by_id() {
        var user = new User(1L, "Alice", "alice@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        var result = userService.findById(1L);

        assertThat(result).isEqualTo(user);
    }

    @Test
    void should_throw_NotFoundException_when_user_not_found() {
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> userService.findById(1L))
                .isInstanceOf(NotFoundException.class)
                .hasMessageContaining("id=1");
    }

    @Test
    void should_create_user_and_publish_event() {
        var request = new CreateUserRequest("Bob", "bob@example.com", "secret123");
        when(userRepository.existsByEmail("bob@example.com")).thenReturn(false);
        when(passwordEncoder.encode("secret123")).thenReturn("hashed");
        when(userRepository.save(any())).thenAnswer(invocation -> {
            var u = invocation.<User>getArgument(0);
            return new User(1L, u.getName(), u.getEmail(), u.getPasswordHash());
        });

        var result = userService.create(request);

        assertThat(result.getName()).isEqualTo("Bob");
        assertThat(result.getEmail()).isEqualTo("bob@example.com");
        verify(eventPublisher).publishEvent(any(UserCreatedEvent.class));
    }

    @Test
    void should_throw_ConflictException_when_email_already_exists() {
        var request = new CreateUserRequest("Bob", "existing@example.com", "secret123");
        when(userRepository.existsByEmail("existing@example.com")).thenReturn(true);

        assertThatThrownBy(() -> userService.create(request))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("already in use");
    }
}
```

## Integration Test Examples

### Repository Test with @DataJpaTest

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class UserRepositoryIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private UserRepository userRepository;

    @Test
    void should_persist_and_retrieve_user_with_all_fields() {
        var user = new User("Alice", "alice@test.com", "hash");
        var saved = userRepository.save(user);

        var found = userRepository.findById(saved.getId());

        assertThat(found).isPresent();
        assertThat(found.get().getName()).isEqualTo("Alice");
        assertThat(found.get().getEmail()).isEqualTo("alice@test.com");
    }

    @Test
    void should_find_user_by_email() {
        userRepository.save(new User("Bob", "bob@test.com", "hash"));

        var result = userRepository.findByEmail("bob@test.com");

        assertThat(result).isPresent();
        assertThat(result.get().getName()).isEqualTo("Bob");
    }

    @Test
    void should_return_empty_when_email_not_found() {
        var result = userRepository.findByEmail("nonexistent@test.com");
        assertThat(result).isEmpty();
    }
}
```

### Controller Test with @WebMvcTest

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void should_return_user_when_found() throws Exception {
        var user = new User(1L, "Alice", "alice@example.com");
        when(userService.findById(1L)).thenReturn(user);

        mockMvc.perform(get("/api/v1/users/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Alice"))
                .andExpect(jsonPath("$.email").value("alice@example.com"));
    }

    @Test
    void should_return_404_when_user_not_found() throws Exception {
        when(userService.findById(1L)).thenThrow(new NotFoundException("User not found"));

        mockMvc.perform(get("/api/v1/users/1"))
                .andExpect(status().isNotFound());
    }

    @Test
    void should_return_400_for_invalid_request_body() throws Exception {
        var invalidRequest = """
                {"name": "", "email": "invalid", "password": "short"}
                """;

        mockMvc.perform(
                post("/api/v1/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(invalidRequest))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors").isArray());
    }
}
```

## E2E Test Examples

### Full Flow with TestRestTemplate

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class OrderFlowE2ETest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void should_create_order_and_return_201_with_location_header() {
        var request = new CreateOrderRequest(
                List.of(new OrderItem(1L, 2))
        );

        var response = restTemplate.postForEntity("/api/orders", request, Void.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getHeaders().getLocation()).isNotNull();
    }

    @Test
    void should_return_400_for_order_with_empty_items() {
        var request = new CreateOrderRequest(List.of());

        var response = restTemplate.postForEntity("/api/orders", request, ProblemDetail.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }
}
```

### Full Flow with WebTestClient

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class OrderFlowWebClientE2ETest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private WebTestClient webTestClient;

    @Test
    void should_create_order_and_return_201_with_location_header() {
        var request = new CreateOrderRequest(
                List.of(new OrderItem(1L, 2))
        );

        webTestClient.post().uri("/api/orders")
                .bodyValue(request)
                .exchange()
                .expectStatus().isCreated()
                .expectHeader().exists("Location");
    }

    @Test
    void should_return_400_for_order_with_empty_items() {
        var request = new CreateOrderRequest(List.of());

        webTestClient.post().uri("/api/orders")
                .bodyValue(request)
                .exchange()
                .expectStatus().isBadRequest();
    }
}
```

## JaCoCo Configuration

Gradle Kotlin DSL (also applicable to Java projects):

```kotlin
tasks.jacocoTestReport {
    reports {
        xml.required.set(true)
        html.required.set(true)
    }
}

tasks.jacocoTestCoverageVerification {
    violationRules {
        rule {
            limit {
                counter = "BRANCH"
                minimum = "0.80".toBigDecimal()
            }
            limit {
                counter = "LINE"
                minimum = "0.80".toBigDecimal()
            }
        }
    }
}
```

## Anti-Pattern Examples

### Testing Implementation Details

```java
// BAD: Tests internal method calls
verify(repository, times(1)).findById(any());

// GOOD: Tests observable behavior
assertThat(result.getName()).isEqualTo("expected");
```

### Shared Mutable State Between Tests

```java
// BAD: Shared state across tests
private static final List<Order> sharedList = new ArrayList<>();

// GOOD: Fresh state per test
@BeforeEach
void setup() {
    var orders = List.of(createTestOrder());
}
```

### Too Few Assertions

```java
// BAD: Only checks existence
assertThat(result).isNotNull();

// GOOD: Checks specific properties
assertThat(result.getStatus()).isEqualTo(OrderStatus.CONFIRMED);
assertThat(result.getTotal()).isEqualTo(new Money(250));
assertThat(result.getItems()).hasSize(3);
```

### Missing Mocks for External Dependencies

```java
// BAD: Real HTTP call in unit test
var response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

// GOOD: Mocked external dependency
when(externalClient.fetchData(any())).thenReturn(new ExternalData("mocked"));
```

### Testing Only the Happy Path

```java
// BAD: Only tests success
@Test void should_create_order() { ... }

// GOOD: Tests success AND failure
@Test void should_create_order_when_all_items_in_stock() { ... }
@Test void should_reject_order_when_item_out_of_stock() { ... }
@Test void should_reject_order_when_total_exceeds_credit_limit() { ... }
@Test void should_reject_order_with_empty_items_list() { ... }
```

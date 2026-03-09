---
name: tdd-guide-kotlin
targets: ["claudecode"]
description: >-
  Kotlin TDD guide with MockK, coroutines, Spring Boot Test.
  Use with base `tdd-guide` for TDD methodology.
claudecode:
  model: opus
---

# TDD Specialist — Kotlin

## Unit Test Examples

### Basic Unit Test with MockK

```kotlin
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

class OrderCalculatorTest {

    @Test
    fun `should calculate total with discount when order has promotion`() {
        val order = Order(items = listOf(item(price = 100)), promotion = Promotion.PERCENT_10)
        val result = orderCalculator.calculateTotal(order)
        assertThat(result).isEqualTo(Money(90))
    }
}
```

### Service Test with MockK

```kotlin
class UserServiceTest {

    private val userRepository: UserRepository = mockk()
    private val passwordEncoder: PasswordEncoder = mockk()
    private val eventPublisher: ApplicationEventPublisher = mockk(relaxed = true)
    private val userService = UserService(userRepository, passwordEncoder, eventPublisher)

    @Test
    fun `should return user when found by id`() {
        val user = User(id = 1L, name = "Alice", email = "alice@example.com")
        every { userRepository.findByIdOrNull(1L) } returns user

        val result = userService.findById(1L)

        assertThat(result).isEqualTo(user)
    }

    @Test
    fun `should throw NotFoundException when user not found`() {
        every { userRepository.findByIdOrNull(1L) } returns null

        assertThatThrownBy { userService.findById(1L) }
            .isInstanceOf(NotFoundException::class.java)
            .hasMessageContaining("id=1")
    }

    @Test
    fun `should create user and publish event`() {
        val request = CreateUserRequest(name = "Bob", email = "bob@example.com", password = "secret123")
        every { userRepository.existsByEmail("bob@example.com") } returns false
        every { passwordEncoder.encode("secret123") } returns "hashed"
        every { userRepository.save(any()) } answers { firstArg<User>().copy(id = 1L) }

        val result = userService.create(request)

        assertThat(result.name).isEqualTo("Bob")
        assertThat(result.email).isEqualTo("bob@example.com")
        verify { eventPublisher.publishEvent(any<UserCreatedEvent>()) }
    }

    @Test
    fun `should throw ConflictException when email already exists`() {
        val request = CreateUserRequest(name = "Bob", email = "existing@example.com", password = "secret123")
        every { userRepository.existsByEmail("existing@example.com") } returns true

        assertThatThrownBy { userService.create(request) }
            .isInstanceOf(ConflictException::class.java)
            .hasMessageContaining("already in use")
    }
}
```

## Integration Test Examples

### Repository Test with @DataJpaTest

```kotlin
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class UserRepositoryIntegrationTest {

    @Container
    companion object {
        val postgres = PostgreSQLContainer("postgres:16-alpine")

        @JvmStatic
        @DynamicPropertySource
        fun configureProperties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url", postgres::getJdbcUrl)
            registry.add("spring.datasource.username", postgres::getUsername)
            registry.add("spring.datasource.password", postgres::getPassword)
        }
    }

    @Autowired
    lateinit var userRepository: UserRepository

    @Test
    fun `should persist and retrieve user with all fields`() {
        val user = User(name = "Alice", email = "alice@test.com", passwordHash = "hash")
        val saved = userRepository.save(user)

        val found = userRepository.findById(saved.id!!)

        assertThat(found).isPresent
        assertThat(found.get().name).isEqualTo("Alice")
        assertThat(found.get().email).isEqualTo("alice@test.com")
    }

    @Test
    fun `should find user by email`() {
        userRepository.save(User(name = "Bob", email = "bob@test.com", passwordHash = "hash"))

        val result = userRepository.findByEmail("bob@test.com")

        assertThat(result).isNotNull
        assertThat(result!!.name).isEqualTo("Bob")
    }

    @Test
    fun `should return null when email not found`() {
        val result = userRepository.findByEmail("nonexistent@test.com")
        assertThat(result).isNull()
    }
}
```

### Controller Test with @WebMvcTest

```kotlin
@WebMvcTest(UserController::class)
class UserControllerTest {

    @Autowired
    lateinit var mockMvc: MockMvc

    @MockkBean  // Requires com.ninja-squad:springmockk dependency
    lateinit var userService: UserService

    @Autowired
    lateinit var objectMapper: ObjectMapper

    @Test
    fun `should return user when found`() {
        val user = User(id = 1L, name = "Alice", email = "alice@example.com")
        every { userService.findById(1L) } returns user

        mockMvc.perform(get("/api/v1/users/1"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.name").value("Alice"))
            .andExpect(jsonPath("$.email").value("alice@example.com"))
    }

    @Test
    fun `should return 404 when user not found`() {
        every { userService.findById(1L) } throws NotFoundException("User not found")

        mockMvc.perform(get("/api/v1/users/1"))
            .andExpect(status().isNotFound)
    }

    @Test
    fun `should return 400 for invalid request body`() {
        val invalidRequest = """{"name": "", "email": "invalid", "password": "short"}"""

        mockMvc.perform(
            post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(invalidRequest)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.errors").isArray)
    }
}
```

## E2E Test Examples

### Full Flow with WebTestClient

```kotlin
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class OrderFlowE2ETest(@Autowired val webTestClient: WebTestClient) {

    @Container
    companion object {
        val postgres = PostgreSQLContainer("postgres:16-alpine")

        @JvmStatic
        @DynamicPropertySource
        fun configureProperties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url", postgres::getJdbcUrl)
            registry.add("spring.datasource.username", postgres::getUsername)
            registry.add("spring.datasource.password", postgres::getPassword)
        }
    }

    @Test
    fun `should create order and return 201 with location header`() {
        val request = CreateOrderRequest(
            items = listOf(OrderItem(productId = 1L, quantity = 2))
        )

        webTestClient.post().uri("/api/orders")
            .bodyValue(request)
            .exchange()
            .expectStatus().isCreated
            .expectHeader().exists("Location")
    }

    @Test
    fun `should return 400 for order with empty items`() {
        val request = CreateOrderRequest(items = emptyList())

        webTestClient.post().uri("/api/orders")
            .bodyValue(request)
            .exchange()
            .expectStatus().isBadRequest
    }
}
```

## Coroutine Testing

```kotlin
import kotlinx.coroutines.test.runTest

class AsyncServiceTest {

    @Test
    fun `should process items concurrently`() = runTest {
        val service = AsyncService(mockRepository)
        every { mockRepository.findAll() } returns listOf(item1, item2, item3)

        val results = service.processAll()

        assertThat(results).hasSize(3)
        assertThat(results).allMatch { it.status == ProcessStatus.COMPLETED }
    }
}
```

## JaCoCo Configuration

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

```kotlin
// BAD: Tests internal method calls
verify(exactly = 1) { repository.findById(any()) }

// GOOD: Tests observable behavior
assertThat(result.name).isEqualTo("expected")
```

### Shared Mutable State Between Tests

```kotlin
// BAD: Shared state across tests
companion object {
    val sharedList = mutableListOf<Order>()
}

// GOOD: Fresh state per test
@BeforeEach
fun setup() {
    val orders = listOf(createTestOrder())
}
```

### Too Few Assertions

```kotlin
// BAD: Only checks existence
assertThat(result).isNotNull()

// GOOD: Checks specific properties
assertThat(result.status).isEqualTo(OrderStatus.CONFIRMED)
assertThat(result.total).isEqualTo(Money(250))
assertThat(result.items).hasSize(3)
```

### Missing Mocks for External Dependencies

```kotlin
// BAD: Real HTTP call in unit test
val response = httpClient.get("https://api.external.com/data")

// GOOD: Mocked external dependency
every { externalClient.fetchData(any()) } returns ExternalData("mocked")
```

### Testing Only the Happy Path

```kotlin
// BAD: Only tests success
@Test fun `should create order`() { ... }

// GOOD: Tests success AND failure
@Test fun `should create order when all items in stock`() { ... }
@Test fun `should reject order when item out of stock`() { ... }
@Test fun `should reject order when total exceeds credit limit`() { ... }
@Test fun `should reject order with empty items list`() { ... }
```

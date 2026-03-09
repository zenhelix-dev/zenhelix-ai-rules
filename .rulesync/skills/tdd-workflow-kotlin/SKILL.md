---
name: tdd-workflow-kotlin
description: "Kotlin implementation patterns for TDD workflow. Use with `tdd-workflow` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: opus
---

# TDD Workflow — Kotlin

Prerequisites: load `tdd-workflow` skill for foundational concepts.

## The TDD Cycle

### RED: Write a Failing Test

```kotlin
@Test
fun `should return user when found by id`() {
    val userId = 1L
    val expectedUser = User(id = userId, name = "Alice", email = "alice@example.com")
    every { userRepository.findByIdOrNull(userId) } returns expectedUser

    val result = userService.findById(userId)

    result shouldBe expectedUser
}
```

### GREEN: Minimal Implementation

```kotlin
class UserService(private val userRepository: UserRepository) {
    fun findById(id: Long): User? = userRepository.findByIdOrNull(id)
}
```

## Test Naming Conventions

Kotlin (backtick style):

```kotlin
`should return user when found by id`
`should throw NotFoundException when user does not exist`
`should create user with hashed password`
```

## Test Structure: Arrange-Act-Assert

```kotlin
@Test
fun `should calculate total with discount`() {
    // Arrange (Given)
    val items = listOf(
        OrderItem(product = "Widget", price = 100.toBigDecimal(), quantity = 2),
        OrderItem(product = "Gadget", price = 50.toBigDecimal(), quantity = 1),
    )
    val discount = 10 // percent

    // Act (When)
    val total = orderService.calculateTotal(items, discount)

    // Assert (Then)
    total shouldBe 225.toBigDecimal() // (200 + 50) * 0.90
}
```

## Mock Patterns with MockK

### Basic Mocking

```kotlin
val userRepository = mockk<UserRepository>()
val userService = UserService(userRepository)

// Stub a method
every { userRepository.findByIdOrNull(1L) } returns User(id = 1L, name = "Alice")

// Stub to throw
every { userRepository.findByIdOrNull(999L) } throws NotFoundException("User not found")

// Verify interaction
verify(exactly = 1) { userRepository.findByIdOrNull(1L) }
verify { userRepository.save(any()) wasNot called }
```

### Relaxed Mocks

```kotlin
// Returns default values for unstubbed methods
val logger = mockk<Logger>(relaxed = true)

// Only relax return values (still fails on Unit-returning functions)
val repo = mockk<UserRepository>(relaxUnitFun = true)
```

### Argument Capture

```kotlin
val slot = slot<User>()
every { userRepository.save(capture(slot)) } answers { slot.captured }

userService.create(CreateUserRequest(name = "Bob", email = "bob@test.com"))

slot.captured.name shouldBe "Bob"
slot.captured.email shouldBe "bob@test.com"
slot.captured.passwordHash shouldNotBe null
```

### Coroutine Mocking

```kotlin
coEvery { userRepository.findById(1L) } returns User(id = 1L, name = "Alice")
coVerify { userRepository.save(any()) }
```

### Spy

```kotlin
val service = spyk(UserService(repository))
every { service.validateEmail(any()) } returns true
```

## Test Fixtures

### Kotlin Object Factory

```kotlin
object TestUsers {
    fun alice(
        id: Long = 1L,
        name: String = "Alice",
        email: String = "alice@example.com",
    ): User = User(id = id, name = name, email = email)

    fun bob(
        id: Long = 2L,
        name: String = "Bob",
        email: String = "bob@example.com",
    ): User = User(id = id, name = name, email = email)

    fun createRequest(
        name: String = "NewUser",
        email: String = "newuser@example.com",
        password: String = "SecureP@ss123",
    ): CreateUserRequest = CreateUserRequest(name = name, email = email, password = password)
}
```

## TestContainers for Integration Tests

```kotlin
@Testcontainers
@SpringBootTest
class UserRepositoryIntegrationTest {

    companion object {
        @Container
        @JvmStatic
        val postgres = PostgreSQLContainer("postgres:16-alpine")
            .withDatabaseName("testdb")
            .withUsername("test")
            .withPassword("test")

        @DynamicPropertySource
        @JvmStatic
        fun configureProperties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url", postgres::getJdbcUrl)
            registry.add("spring.datasource.username", postgres::getUsername)
            registry.add("spring.datasource.password", postgres::getPassword)
        }
    }

    @Autowired
    lateinit var userRepository: UserRepository

    @Test
    fun `should persist and retrieve user`() {
        val user = userRepository.save(User(name = "Alice", email = "alice@test.com"))

        val found = userRepository.findByIdOrNull(user.id!!)

        found shouldNotBe null
        found!!.name shouldBe "Alice"
    }
}
```

## Coverage Enforcement with JaCoCo

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
                minimum = "0.80".toBigDecimal()
            }
        }
        rule {
            element = "CLASS"
            excludes = listOf(
                "*.config.*",
                "*.Application*",
            )
            limit {
                counter = "LINE"
                minimum = "0.80".toBigDecimal()
            }
        }
    }
}

tasks.check {
    dependsOn(tasks.jacocoTestCoverageVerification)
}
```

## Spring Test Patterns

```kotlin
// Slice tests
@WebMvcTest(UserController::class)
class UserControllerTest { /* MockMvc tests */ }

@DataJpaTest
class UserRepositoryTest { /* JPA tests with embedded DB */ }

@WebFluxTest(UserHandler::class)
class UserHandlerTest { /* WebTestClient tests */ }

// Full integration
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class UserIntegrationTest { /* Full context tests */ }
```

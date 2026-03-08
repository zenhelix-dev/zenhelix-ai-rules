---
root: false
targets: ["claudecode"]
description: "Kotlin testing: JUnit 5, MockK, coroutine testing, and coverage requirements"
globs: ["*.kt", "*.kts"]
---

# Kotlin Testing

## Framework Stack

- **JUnit 5** — test framework
- **MockK** — mocking (not Mockito)
- **AssertJ** or **kotlin.test** — assertions
- **Kotest** — property-based testing (optional)
- **JaCoCo** — coverage (80%+ required)

## Test Naming

Use backtick syntax for descriptive names:

```kotlin
class UserServiceTest {

    @Test
    fun `should create user when email is valid`() {
        // ...
    }

    @Test
    fun `should throw exception when email is already taken`() {
        // ...
    }
}
```

## Test Organization

Use `@Nested` for logical grouping:

```kotlin
class OrderServiceTest {

    @Nested
    inner class CreateOrder {

        @Test
        fun `should create order with valid items`() { /* ... */ }

        @Test
        fun `should reject order with empty items`() { /* ... */ }
    }

    @Nested
    inner class CancelOrder {

        @Test
        fun `should cancel pending order`() { /* ... */ }

        @Test
        fun `should throw when order is already shipped`() { /* ... */ }
    }
}
```

## MockK

Use MockK for all mocking needs:

```kotlin
class UserServiceTest {

    private val userRepository = mockk<UserRepository>()
    private val emailService = mockk<EmailService>(relaxed = true)
    private val service = UserService(userRepository, emailService)

    @Test
    fun `should save user and send welcome email`() {
        // given
        val user = User(name = "Alice", email = "alice@example.com")
        every { userRepository.save(any()) } returns user.copy(id = 1L)

        // when
        val result = service.createUser(user)

        // then
        assertThat(result.id).isEqualTo(1L)
        verify(exactly = 1) { emailService.sendWelcome(user.email) }
    }
}
```

### Capturing Arguments

```kotlin
@Test
fun `should save user with normalized email`() {
    val slot = slot<User>()
    every { userRepository.save(capture(slot)) } returns mockk()

    service.createUser(User(name = "Alice", email = "ALICE@Example.COM"))

    assertThat(slot.captured.email).isEqualTo("alice@example.com")
}
```

### Coroutine Mocking

Use `coEvery` and `coVerify` for suspend functions:

```kotlin
@Test
fun `should fetch user asynchronously`() = runTest {
    coEvery { userRepository.findById(1L) } returns User("Alice")

    val result = service.getUser(1L)

    assertThat(result.name).isEqualTo("Alice")
    coVerify { userRepository.findById(1L) }
}
```

## Coroutine Testing

Use `runTest` from `kotlinx-coroutines-test`:

```kotlin
class DataSyncServiceTest {

    @Test
    fun `should sync all sources concurrently`() = runTest {
        val service = DataSyncService(
            dispatcher = StandardTestDispatcher(testScheduler),
        )

        val result = service.syncAll()

        assertThat(result.syncedSources).hasSize(3)
    }

    @Test
    fun `should cancel sync on timeout`() = runTest {
        val service = DataSyncService(
            dispatcher = StandardTestDispatcher(testScheduler),
            timeout = 100.milliseconds,
        )

        assertThrows<TimeoutCancellationException> {
            service.syncAll()
        }
    }
}
```

## Test Data Builders

Use `copy()` on data classes for test variations:

```kotlin
object TestData {
    val defaultUser = User(
        id = 1L,
        name = "Test User",
        email = "test@example.com",
        role = Role.USER,
        active = true,
    )
}

@Test
fun `should deactivate admin user`() {
    val admin = TestData.defaultUser.copy(role = Role.ADMIN)
    // ...
}
```

## Assertions

Prefer AssertJ for fluent assertions:

```kotlin
// Basic assertions
assertThat(user.name).isEqualTo("Alice")
assertThat(users).hasSize(3)
assertThat(users).extracting("name").containsExactly("Alice", "Bob", "Carol")

// Exception assertions
assertThatThrownBy { service.process(invalidInput) }
    .isInstanceOf(ValidationException::class.java)
    .hasMessageContaining("invalid input")

// Collection assertions
assertThat(result)
    .filteredOn { it.active }
    .hasSize(2)
    .allSatisfy { assertThat(it.role).isEqualTo(Role.USER) }
```

## Parameterized Tests

```kotlin
@ParameterizedTest
@CsvSource(
    "alice@example.com, true",
    "invalid-email, false",
    "'', false",
)
fun `should validate email format`(email: String, expected: Boolean) {
    assertThat(EmailValidator.isValid(email)).isEqualTo(expected)
}

@ParameterizedTest
@MethodSource("orderStatusTransitions")
fun `should allow valid status transitions`(from: OrderStatus, to: OrderStatus) {
    assertThat(from.canTransitionTo(to)).isTrue()
}

companion object {
    @JvmStatic
    fun orderStatusTransitions() = listOf(
        Arguments.of(OrderStatus.PENDING, OrderStatus.CONFIRMED),
        Arguments.of(OrderStatus.CONFIRMED, OrderStatus.SHIPPED),
    )
}
```

## Coverage

Run JaCoCo and enforce 80% minimum:

```bash
./gradlew test jacocoTestReport jacocoTestCoverageVerification
```

Configure in `build.gradle.kts`:

```kotlin
tasks.jacocoTestCoverageVerification {
    violationRules {
        rule {
            limit {
                minimum = BigDecimal("0.80")
            }
        }
    }
}
```

---
name: coding-standards-kotlin
description: "Kotlin implementation patterns for coding standards. Use with `coding-standards` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Coding Standards — Kotlin

Prerequisites: load `coding-standards` skill for foundational concepts.

## Readability

### Meaningful Names

```kotlin
// BAD
val d = 86400
fun proc(u: User): Boolean

// GOOD
val secondsPerDay = 86400
fun isEligibleForPromotion(user: User): Boolean
```

### Single Responsibility

```kotlin
// BAD: handles validation, persistence, and notification
class UserService {
    fun register(request: RegisterRequest) {
        validate(request)
        val user = save(request)
        sendEmail(user)
    }
}

// GOOD: each concern separated
class UserRegistrationService(
    private val validator: UserValidator,
    private val repository: UserRepository,
    private val notifier: UserNotifier,
) {
    fun register(request: RegisterRequest): User {
        validator.validate(request)
        val user = repository.save(request.toUser())
        notifier.onRegistered(user)
        return user
    }
}
```

## KISS: Keep It Simple

```kotlin
// OVER-ENGINEERED
interface UserFinder<T : Identifiable> : GenericFinder<T, Long> {
    override fun findBySpec(spec: Specification<T>): List<T>
}

// KISS
interface UserRepository {
    fun findById(id: Long): User?
    fun findByEmail(email: String): User?
}
```

## DRY: Don't Repeat Yourself

```kotlin
// First occurrence: inline is fine
// Second occurrence: note it, leave inline
// Third occurrence: extract

// Extracted utility
fun <T> T?.orThrow(message: () -> String): T =
    this ?: throw NotFoundException(message())

// Usage
val user = userRepository.findByIdOrNull(id).orThrow { "User $id not found" }
val order = orderRepository.findByIdOrNull(id).orThrow { "Order $id not found" }
val product = productRepository.findByIdOrNull(id).orThrow { "Product $id not found" }
```

## YAGNI: You Aren't Gonna Need It

```kotlin
// BAD: supports multiple notification channels "just in case"
interface NotificationChannel {
    fun send(message: Message)
}
class EmailChannel : NotificationChannel { ... }
class SmsChannel : NotificationChannel { ... }  // nobody asked for SMS
class PushChannel : NotificationChannel { ... } // nobody asked for push

// GOOD: build what is needed now
class EmailNotifier(private val mailSender: JavaMailSender) {
    fun sendWelcomeEmail(user: User) { ... }
}
// Add abstraction WHEN a second channel is actually needed
```

## Immutability

```kotlin
// Use val, not var
val name: String = "Alice"

// Use immutable collections
val users: List<User> = repository.findAll()

// Use copy() for modifications
val updated = user.copy(name = "Bob")

// Data classes are naturally immutable with val properties
data class User(
    val id: Long,
    val name: String,
    val email: String,
)
```

## Error Handling

### Custom Domain Exceptions

```kotlin
sealed class DomainException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)

class NotFoundException(message: String) : DomainException(message)
class ValidationException(val errors: List<String>) : DomainException(errors.joinToString("; "))
class ConflictException(message: String) : DomainException(message)
class AccessDeniedException(message: String) : DomainException(message)
```

### Structured Error Responses

```kotlin
@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(NotFoundException::class)
    fun handleNotFound(ex: NotFoundException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.message ?: "Not found")

    @ExceptionHandler(ValidationException::class)
    fun handleValidation(ex: ValidationException): ProblemDetail =
        ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, ex.message ?: "Validation error")
}
```

### Never Swallow Exceptions

```kotlin
// BAD
try { riskyOperation() } catch (_: Exception) { }

// GOOD
try {
    riskyOperation()
} catch (e: SpecificException) {
    logger.error(e) { "Failed to perform risky operation for user=$userId" }
    throw ServiceException("Operation failed", e)
}
```

## Type Safety

### Sealed Classes for Finite States

```kotlin
sealed interface PaymentResult {
    data class Success(val transactionId: String, val amount: BigDecimal) : PaymentResult
    data class Declined(val reason: String) : PaymentResult
    data class Error(val exception: Throwable) : PaymentResult
}

// Compiler enforces exhaustive when
fun handle(result: PaymentResult): String = when (result) {
    is PaymentResult.Success -> "Paid: ${result.transactionId}"
    is PaymentResult.Declined -> "Declined: ${result.reason}"
    is PaymentResult.Error -> "Error: ${result.exception.message}"
}
```

### Avoid Stringly-Typed Code

```kotlin
// BAD
fun findUsers(role: String): List<User>  // what values are valid?

// GOOD
enum class Role { ADMIN, USER, MODERATOR }
fun findUsers(role: Role): List<User>
```

### Value Classes for Domain Primitives

```kotlin
@JvmInline
value class UserId(val value: Long)

@JvmInline
value class Email(val value: String) {
    init { require(value.contains("@")) { "Invalid email: $value" } }
}
```

## Coroutine Best Practices

```kotlin
// Use structured concurrency
class UserService(
    private val repository: UserRepository,
    private val notifier: UserNotifier,
) {
    // Let the caller manage the scope
    suspend fun register(request: RegisterRequest): User {
        val user = repository.save(request.toUser())
        notifier.onRegistered(user)
        return user
    }
}

// Parallel execution with coroutineScope
suspend fun fetchDashboard(userId: Long): Dashboard = coroutineScope {
    val userDeferred = async { userService.findById(userId) }
    val ordersDeferred = async { orderService.findByUserId(userId) }
    Dashboard(user = userDeferred.await(), orders = ordersDeferred.await())
}
```

## Input Validation

```kotlin
data class CreateUserRequest(
    @field:NotBlank(message = "Name is required")
    @field:Size(min = 2, max = 100)
    val name: String,

    @field:NotBlank
    @field:Email(message = "Invalid email format")
    val email: String,

    @field:NotBlank
    @field:Size(min = 8, max = 128)
    val password: String,
)
```

Kotlin preconditions:

```kotlin
fun withdraw(amount: BigDecimal) {
    require(amount > BigDecimal.ZERO) { "Amount must be positive: $amount" }
    check(status == AccountStatus.ACTIVE) { "Account is not active" }
}
```

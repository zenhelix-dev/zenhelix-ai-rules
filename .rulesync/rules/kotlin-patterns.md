---
root: false
targets: ["claudecode"]
description: "Kotlin patterns: Result type, sealed state machines, delegation, DSL builders, Flow, and coroutine patterns"
globs: ["*.kt", "*.kts"]
---

# Kotlin Patterns

## Result Type for Error Handling

Avoid exceptions for expected failures. Use a sealed Result type:

```kotlin
sealed interface AppResult<out T> {
    data class Success<T>(val data: T) : AppResult<T>
    data class Failure(val error: AppError) : AppResult<Nothing>
}

sealed interface AppError {
    data class NotFound(val resource: String, val id: String) : AppError
    data class Validation(val violations: List<String>) : AppError
    data class Unauthorized(val reason: String) : AppError
}

fun <T> AppResult<T>.getOrThrow(): T = when (this) {
    is AppResult.Success -> data
    is AppResult.Failure -> throw AppException(error)
}

fun <T, R> AppResult<T>.map(transform: (T) -> R): AppResult<R> = when (this) {
    is AppResult.Success -> AppResult.Success(transform(data))
    is AppResult.Failure -> this
}

fun <T, R> AppResult<T>.flatMap(transform: (T) -> AppResult<R>): AppResult<R> = when (this) {
    is AppResult.Success -> transform(data)
    is AppResult.Failure -> this
}
```

Usage:

```kotlin
class UserService(private val repo: UserRepository) {

    fun findUser(id: Long): AppResult<User> {
        val user = repo.findById(id)
            ?: return AppResult.Failure(AppError.NotFound("User", id.toString()))
        return AppResult.Success(user)
    }
}
```

## Sealed Class State Machines

Model state transitions explicitly:

```kotlin
sealed class OrderState {
    data object Draft : OrderState()
    data class Submitted(val submittedAt: Instant) : OrderState()
    data class Approved(val approvedBy: String) : OrderState()
    data class Rejected(val reason: String) : OrderState()
    data class Shipped(val trackingId: String) : OrderState()

    fun transition(event: OrderEvent): OrderState = when (this) {
        is Draft -> when (event) {
            is OrderEvent.Submit -> Submitted(Instant.now())
            else -> error("Cannot $event from Draft")
        }
        is Submitted -> when (event) {
            is OrderEvent.Approve -> Approved(event.approver)
            is OrderEvent.Reject -> Rejected(event.reason)
            else -> error("Cannot $event from Submitted")
        }
        is Approved -> when (event) {
            is OrderEvent.Ship -> Shipped(event.trackingId)
            else -> error("Cannot $event from Approved")
        }
        is Rejected, is Shipped -> error("Terminal state: cannot transition")
    }
}
```

## Delegation Pattern

Use `by` keyword for composition:

```kotlin
// Interface delegation
class LoggingUserRepository(
    private val delegate: UserRepository,
    private val logger: Logger,
) : UserRepository by delegate {

    override fun save(user: User): User {
        logger.info("Saving user: ${user.id}")
        return delegate.save(user)
    }
}

// Property delegation
class PreferencesManager(private val prefs: SharedPreferences) {
    var theme: String by prefs.string(default = "light")
    var fontSize: Int by prefs.int(default = 14)
}
```

## DSL Builders

Create type-safe DSL builders:

```kotlin
@DslMarker
annotation class QueryDsl

@QueryDsl
class QueryBuilder {
    private val conditions = mutableListOf<String>()
    private var orderByField: String? = null
    private var limitValue: Int? = null

    fun where(condition: String) {
        conditions.add(condition)
    }

    fun orderBy(field: String) {
        orderByField = field
    }

    fun limit(n: Int) {
        limitValue = n
    }

    fun build(): Query = Query(
        conditions = conditions.toList(),
        orderBy = orderByField,
        limit = limitValue,
    )
}

fun query(block: QueryBuilder.() -> Unit): Query =
    QueryBuilder().apply(block).build()

// Usage
val q = query {
    where("age > 18")
    where("active = true")
    orderBy("name")
    limit(10)
}
```

## Flow for Reactive Streams

Use Kotlin Flow for reactive data streams:

```kotlin
class EventStream(private val eventSource: EventSource) {

    fun events(): Flow<Event> = callbackFlow {
        val listener = eventSource.addListener { event ->
            trySend(event)
        }
        awaitClose { eventSource.removeListener(listener) }
    }

    fun processedEvents(): Flow<ProcessedEvent> =
        events()
            .filter { it.type != EventType.HEARTBEAT }
            .map { ProcessedEvent.from(it) }
            .catch { e -> emit(ProcessedEvent.error(e)) }
            .flowOn(Dispatchers.IO)
}

// Collecting
lifecycleScope.launch {
    eventStream.processedEvents().collect { event ->
        updateUI(event)
    }
}
```

## Extension Functions for Repository Pattern

```kotlin
interface CrudRepository<T, ID> {
    fun findById(id: ID): T?
    fun findAll(): List<T>
    fun save(entity: T): T
    fun deleteById(id: ID)
}

fun <T, ID> CrudRepository<T, ID>.findByIdOrThrow(id: ID): T =
    findById(id) ?: throw NotFoundException("Entity not found: $id")

fun <T, ID> CrudRepository<T, ID>.existsById(id: ID): Boolean =
    findById(id) != null
```

## Inline Functions with Reified Types

Use reified type parameters to avoid type erasure:

```kotlin
inline fun <reified T> ObjectMapper.readValue(json: String): T =
    readValue(json, T::class.java)

inline fun <reified T : Any> Logger.logTyped(message: String) {
    info("[${T::class.simpleName}] $message")
}

// Usage — no Class<T> parameter needed
val user = mapper.readValue<User>(jsonString)
```

## Coroutine Patterns

### SupervisorJob for Independent Children

```kotlin
class DataSyncService {
    private val scope = CoroutineScope(
        SupervisorJob() + Dispatchers.IO + CoroutineExceptionHandler { _, e ->
            logger.error("Sync failed", e)
        }
    )

    fun syncAll() {
        // Each child can fail independently
        scope.launch { syncUsers() }
        scope.launch { syncOrders() }
        scope.launch { syncProducts() }
    }
}
```

### Structured Concurrency with async/await

```kotlin
suspend fun loadDashboard(): Dashboard = coroutineScope {
    val users = async { userService.getAll() }
    val orders = async { orderService.getRecent() }
    val stats = async { statsService.compute() }

    Dashboard(
        users = users.await(),
        orders = orders.await(),
        stats = stats.await(),
    )
}
```

### Retry with Exponential Backoff

```kotlin
suspend fun <T> retry(
    times: Int = 3,
    initialDelay: Duration = 100.milliseconds,
    factor: Double = 2.0,
    block: suspend () -> T,
): T {
    var currentDelay = initialDelay
    repeat(times - 1) {
        try {
            return block()
        } catch (e: Exception) {
            delay(currentDelay)
            currentDelay = (currentDelay * factor)
        }
    }
    return block() // last attempt — let exception propagate
}
```

## Value Objects

Use inline value classes for type-safe wrappers:

```kotlin
@JvmInline
value class UserId(val value: Long)

@JvmInline
value class Email(val value: String) {
    init {
        require(value.contains("@")) { "Invalid email: $value" }
    }
}

// Prevents mixing up IDs of different entities
fun findUser(id: UserId): User? = /* ... */
fun findOrder(id: OrderId): Order? = /* ... */
```

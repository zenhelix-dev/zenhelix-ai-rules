---
root: false
targets: ["claudecode"]
description: "Kotlin coding style: immutability, null safety, coroutines, scope functions, and idiomatic patterns"
globs: ["*.kt", "*.kts"]
---

# Kotlin Coding Style

## Immutability (CRITICAL)

Prefer `val` over `var` everywhere. Use `copy()` for updates:

```kotlin
// WRONG: mutable state
var user = User("Alice", 25)
user.name = "Bob"

// CORRECT: immutable with copy
val user = User("Alice", 25)
val updated = user.copy(name = "Bob")
```

Use read-only collections by default:

```kotlin
// WRONG
val items = mutableListOf("a", "b")

// CORRECT — use mutable only when building, then expose as read-only
val items = buildList {
    add("a")
    add("b")
}
```

## Data Classes

Use data classes for DTOs and value objects:

```kotlin
data class UserDto(
    val id: Long,
    val name: String,
    val email: String,
)
```

- Always include trailing comma in multi-line declarations
- Never use data classes for entities with identity (use regular classes instead)

## Sealed Classes and Interfaces

Use sealed hierarchies for restricted type sets:

```kotlin
sealed interface Result<out T> {
    data class Success<T>(val data: T) : Result<T>
    data class Failure(val error: AppError) : Result<Nothing>
}

sealed class PaymentState {
    data object Pending : PaymentState()
    data class Processing(val transactionId: String) : PaymentState()
    data class Completed(val receipt: Receipt) : PaymentState()
    data class Failed(val reason: String) : PaymentState()
}
```

## Null Safety

Never use `!!`. Use safe alternatives:

```kotlin
// WRONG
val length = name!!.length

// CORRECT — safe call + elvis
val length = name?.length ?: 0

// CORRECT — let for conditional execution
user?.let { sendEmail(it) }

// CORRECT — run for scoped operations
config?.run {
    applyTimeout(timeout)
    applyRetries(retries)
}
```

## Extension Functions

Use for utility code and improving readability:

```kotlin
fun String.toSlug(): String =
    lowercase()
        .replace(Regex("[^a-z0-9\\s-]"), "")
        .replace(Regex("\\s+"), "-")
        .trim('-')

fun <T> List<T>.secondOrNull(): T? = getOrNull(1)
```

- Keep extensions close to their usage (same package)
- Do not use extensions to access private members of a class — that indicates a design issue

## Coroutines

Use structured concurrency. Never use `GlobalScope`:

```kotlin
// WRONG
GlobalScope.launch { doWork() }

// CORRECT — scoped to lifecycle
class UserService(private val scope: CoroutineScope) {
    fun refreshUser(id: Long) {
        scope.launch {
            val user = withContext(Dispatchers.IO) { repo.findById(id) }
            cache.update(user)
        }
    }
}
```

Use `withContext` for dispatcher switching:

```kotlin
suspend fun loadData(): Data = withContext(Dispatchers.IO) {
    repository.fetchAll()
}
```

## Scope Functions

Use each scope function for its intended purpose:

| Function | Object ref | Return value  | Use case                           |
|----------|------------|---------------|------------------------------------|
| `let`    | `it`       | Lambda result | Null checks, transformations       |
| `run`    | `this`     | Lambda result | Object config + compute result     |
| `with`   | `this`     | Lambda result | Grouping calls on an object        |
| `apply`  | `this`     | Object itself | Object configuration               |
| `also`   | `it`       | Object itself | Side effects (logging, validation) |

```kotlin
// let — null-safe transformation
val email = user?.let { "${it.name}@example.com" }

// apply — object configuration
val connection = Connection().apply {
    timeout = 5000
    retries = 3
}

// also — side effects
val user = createUser(request).also { logger.info("Created user: ${it.id}") }
```

## Naming Conventions

- `camelCase` for functions, properties, local variables
- `PascalCase` for classes, interfaces, type aliases, enum entries
- `UPPER_SNAKE_CASE` for compile-time constants (`const val`)
- Prefix boolean properties/functions: `is`, `has`, `should`, `can`

## Object Declarations

Use `object` for singletons:

```kotlin
object DatabaseMigrator {
    fun migrate(dataSource: DataSource) { /* ... */ }
}
```

Use companion objects for factory methods:

```kotlin
class Connection private constructor(val url: String) {
    companion object {
        fun create(config: Config): Connection =
            Connection(config.buildUrl())
    }
}
```

## When Expressions

Prefer `when` over `if-else` chains:

```kotlin
// WRONG
if (status == "active") { /* ... */ }
else if (status == "pending") { /* ... */ }
else if (status == "closed") { /* ... */ }

// CORRECT
when (status) {
    "active" -> handleActive()
    "pending" -> handlePending()
    "closed" -> handleClosed()
    else -> throw IllegalArgumentException("Unknown status: $status")
}
```

Use exhaustive `when` with sealed classes (no `else` branch needed):

```kotlin
fun render(state: PaymentState): String = when (state) {
    is PaymentState.Pending -> "Waiting..."
    is PaymentState.Processing -> "Processing ${state.transactionId}"
    is PaymentState.Completed -> "Done: ${state.receipt}"
    is PaymentState.Failed -> "Error: ${state.reason}"
}
```

## Preconditions

Use `require()`, `check()`, and `error()`:

```kotlin
fun processOrder(order: Order) {
    require(order.items.isNotEmpty()) { "Order must have at least one item" }
    check(order.status == OrderStatus.CONFIRMED) { "Order must be confirmed" }

    // proceed with processing
}
```

- `require()` — validates function arguments (throws `IllegalArgumentException`)
- `check()` — validates object state (throws `IllegalStateException`)
- `error()` — unconditional failure (throws `IllegalStateException`)

## Sequences vs Iterables

Use sequences for large collections with chained operations:

```kotlin
// Eager — creates intermediate lists at each step
val result = hugeList
    .filter { it.isActive }
    .map { it.name }
    .take(10)

// Lazy — processes element by element, stops after 10
val result = hugeList.asSequence()
    .filter { it.isActive }
    .map { it.name }
    .take(10)
    .toList()
```

## Destructuring

Use destructuring for clarity:

```kotlin
val (name, age) = user
val (key, value) = entry

users.forEachIndexed { index, (name, email) ->
    println("$index: $name <$email>")
}
```

## Type Aliases

Use for complex types:

```kotlin
typealias UserId = Long
typealias UserCache = MutableMap<UserId, User>
typealias EventHandler = (Event) -> Unit
```

## Logging

Use SLF4J with Kotlin idioms:

```kotlin
private val logger = LoggerFactory.getLogger(this::class.java)

// Or with kotlin-logging
private val logger = KotlinLogging.logger {}
```

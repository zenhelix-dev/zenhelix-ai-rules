---
root: false
targets: ["claudecode"]
description: "Kotlin security: input validation, SQL safety, null safety, coroutine safety, and serialization"
globs: ["*.kt", "*.kts"]
---

# Kotlin Security

## Input Validation

Use `require()` and `check()` at system boundaries:

```kotlin
fun createUser(request: CreateUserRequest): User {
    require(request.name.isNotBlank()) { "Name must not be blank" }
    require(request.email.contains("@")) { "Invalid email format" }
    require(request.age in 13..150) { "Age must be between 13 and 150" }

    check(!userRepository.existsByEmail(request.email)) {
        "Email already registered"
    }

    return userRepository.save(request.toUser())
}
```

For complex validation, accumulate errors:

```kotlin
data class ValidationError(val field: String, val message: String)

fun validate(request: CreateUserRequest): List<ValidationError> = buildList {
    if (request.name.isBlank()) add(ValidationError("name", "must not be blank"))
    if (!request.email.matches(EMAIL_REGEX)) add(ValidationError("email", "invalid format"))
    if (request.age !in 13..150) add(ValidationError("age", "must be between 13 and 150"))
}
```

## Parameterized Queries

NEVER concatenate strings for SQL. Always use parameterized queries:

```kotlin
// WRONG — SQL injection vulnerability
fun findByName(name: String): User? {
    val sql = "SELECT * FROM users WHERE name = '$name'"
    return jdbcTemplate.queryForObject(sql, userMapper)
}

// CORRECT — parameterized query
fun findByName(name: String): User? {
    val sql = "SELECT * FROM users WHERE name = ?"
    return jdbcTemplate.queryForObject(sql, userMapper, name)
}

// CORRECT — JPA named parameters
@Query("SELECT u FROM User u WHERE u.name = :name")
fun findByName(@Param("name") name: String): User?

// CORRECT — Exposed DSL (type-safe)
fun findByName(name: String): User? =
    Users.selectAll().where { Users.name eq name }.singleOrNull()?.toUser()
```

## Secret Management

Load secrets from environment variables. Validate at startup:

```kotlin
data class AppSecrets(
    val databaseUrl: String,
    val jwtSecret: String,
    val apiKey: String,
) {
    companion object {
        fun fromEnvironment(): AppSecrets = AppSecrets(
            databaseUrl = requireEnv("DATABASE_URL"),
            jwtSecret = requireEnv("JWT_SECRET"),
            apiKey = requireEnv("API_KEY"),
        )

        private fun requireEnv(name: String): String =
            System.getenv(name)
                ?: error("Required environment variable $name is not set")
    }
}
```

- Never log secrets, even at DEBUG level
- Never include secrets in error messages or exception details
- Never commit secrets to version control

## Null Safety as Security

Kotlin's type system prevents null-related vulnerabilities. Maintain this guarantee:

```kotlin
// WRONG — bypasses null safety
val userId = request.getHeader("X-User-Id")!!.toLong()

// CORRECT — handle null explicitly
val userId = request.getHeader("X-User-Id")
    ?.toLongOrNull()
    ?: throw UnauthorizedException("Missing or invalid user ID")
```

Never use `!!` operator. It defeats Kotlin's null safety and can cause unexpected crashes at runtime.

## Coroutine Cancellation Safety

Ensure resources are cleaned up on cancellation:

```kotlin
suspend fun processFile(path: Path) {
    val stream = withContext(Dispatchers.IO) { Files.newInputStream(path) }
    try {
        // Process stream
        processStream(stream)
    } finally {
        // Use NonCancellable to ensure cleanup runs even on cancellation
        withContext(NonCancellable) {
            stream.close()
            logger.info("Stream closed for $path")
        }
    }
}
```

Use `use` extension for AutoCloseable resources:

```kotlin
suspend fun readFile(path: Path): String = withContext(Dispatchers.IO) {
    Files.newBufferedReader(path).use { reader ->
        reader.readText()
    }
}
```

## Serialization Security

Use kotlinx.serialization with explicit schemas. Never deserialize untrusted data without validation:

```kotlin
@Serializable
data class ApiRequest(
    val action: String,
    @Serializable(with = SanitizedStringSerializer::class)
    val payload: String,
) {
    init {
        require(action in ALLOWED_ACTIONS) { "Unknown action: $action" }
        require(payload.length <= MAX_PAYLOAD_SIZE) { "Payload too large" }
    }
}

// Reject unknown keys to prevent mass assignment
val json = Json {
    ignoreUnknownKeys = false
    isLenient = false
}
```

- Set `ignoreUnknownKeys = false` to detect unexpected fields
- Set `isLenient = false` to reject malformed JSON
- Validate all deserialized values in `init` blocks
- Define explicit `@Serializable` models — never deserialize into `Map<String, Any>`

## Dependency Security

Scan dependencies for known vulnerabilities:

```kotlin
// build.gradle.kts — OWASP dependency check
plugins {
    id("org.owasp.dependencycheck") version "9.0.0"
}

dependencyCheck {
    failBuildOnCVSS = 7.0f
}
```

```bash
./gradlew dependencyCheckAnalyze
```

## Logging Security

Never log sensitive data:

```kotlin
// WRONG
logger.info("User login: email=${user.email}, password=${user.password}")

// CORRECT
logger.info("User login: userId=${user.id}")
```

Sanitize log messages to prevent log injection:

```kotlin
fun sanitizeForLog(input: String): String =
    input.replace(Regex("[\\r\\n]"), "_")
```

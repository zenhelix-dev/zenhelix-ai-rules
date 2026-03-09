---
root: false
targets: ["claudecode"]
description: "Kotlin security: input validation, SQL safety, null safety, coroutine safety, and serialization"
globs: ["*.kt", "*.kts"]
---

# Kotlin Security

> Detailed examples: use skills `security-review`, `springboot-security`

## Input Validation

- Use `require()` and `check()` at system boundaries
- For complex validation, accumulate errors into a list before rejecting

## SQL Injection Prevention

- NEVER concatenate strings for SQL
- Use parameterized queries: JDBC `?` placeholders, JPA `@Param`, or Exposed DSL

## Secret Management

- Load secrets from environment variables via data class with `fromEnvironment()` factory
- Validate all required secrets at startup — fail fast if missing
- Never log, return in errors, or commit secrets

## Null Safety as Security

- **Never use `!!`** — it defeats Kotlin's null safety
- Parse external input with safe functions (`?.toLongOrNull()`) and handle null explicitly
- Treat null-unsafe code as a security vulnerability

## Coroutine Cancellation Safety

- Clean up resources in `finally` with `withContext(NonCancellable)`
- Use `.use {}` extension for all `AutoCloseable` resources

## Serialization Security

- Use `kotlinx.serialization` with explicit `@Serializable` data classes
- Set `ignoreUnknownKeys = false` and `isLenient = false`
- Validate deserialized values in `init` blocks
- Never deserialize into `Map<String, Any>`

## Dependency Security

- Use OWASP Dependency-Check plugin (fail build on CVSS >= 7)

## Logging

- Never log passwords, tokens, or PII
- Sanitize user input before logging to prevent log injection

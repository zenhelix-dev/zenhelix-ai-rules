---
root: false
targets: ["claudecode"]
description: "Kotlin patterns: Result type, sealed state machines, delegation, DSL builders, Flow, and coroutine patterns"
globs: ["*.kt", "*.kts"]
---

# Kotlin Patterns

> Detailed examples: use skills `backend-patterns`, `springboot-patterns`

## Result Type for Error Handling

- Use sealed `AppResult<T>` (Success/Failure) instead of exceptions for expected failures
- Provide `map()`, `flatMap()`, `getOrThrow()` extension functions
- Use `AppError` sealed interface for typed error variants (NotFound, Validation, Unauthorized)

## Sealed Class State Machines

- Model state transitions explicitly with sealed classes
- Define `transition(event)` function that returns new state
- Use exhaustive `when` — compiler ensures all states are handled

## Delegation Pattern

- Use `by` keyword for interface delegation (decorator/logging/caching wrappers)
- Use property delegation for preferences, lazy init, observable values

## DSL Builders

- Use `@DslMarker` annotation to prevent scope leaking
- Create builder class with `apply(block)` pattern
- Expose top-level function that creates builder and returns result

## Flow (Reactive Streams)

- Use `callbackFlow` to bridge callback-based APIs
- Chain with `filter`, `map`, `catch`, `flowOn`
- Use `flowOn(Dispatchers.IO)` for upstream context switching

## Repository Pattern

- Define `CrudRepository<T, ID>` interface with standard operations
- Add extension functions like `findByIdOrThrow()`

## Coroutine Patterns

- `SupervisorJob()` — independent children, one failure doesn't cancel others
- `coroutineScope { async {} }` — structured concurrency with parallel execution
- Retry with exponential backoff utility function

## Value Objects

- Use `@JvmInline value class` for type-safe wrappers (UserId, Email, OrderId)
- Add validation in `init` block
- Prevents mixing up IDs of different entities at compile time

## Inline Functions

- Use `reified` type parameters to avoid passing `Class<T>` explicitly
- Useful for JSON deserialization, logging, DI container lookups

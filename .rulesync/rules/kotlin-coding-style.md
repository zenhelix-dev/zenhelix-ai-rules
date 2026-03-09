---
root: false
targets: ["claudecode"]
description: "Kotlin coding style: immutability, null safety, coroutines, scope functions, and idiomatic patterns"
globs: ["*.kt", "*.kts"]
---

# Kotlin Coding Style

> Detailed examples: use skill `coding-standards`

## Immutability (CRITICAL)

- Prefer `val` over `var` everywhere
- Use `copy()` for data class updates — never mutate in place
- Use read-only collections by default; `buildList {}` / `buildMap {}` for construction

## Data Classes and Sealed Types

- Use `data class` for DTOs and value objects (always include trailing comma)
- Never use data classes for entities with identity — use regular classes
- Use `sealed interface` / `sealed class` for restricted type hierarchies

## Null Safety

- **Never use `!!`** — use safe call `?.`, elvis `?:`, `let`, `run`
- Handle nulls explicitly with `?.toLongOrNull()`, `?: throw/default`

## Extension Functions

- Use for utility code and improving readability
- Keep extensions close to their usage (same package)
- Do not use extensions to access private members

## Coroutines

- Use structured concurrency — **never use `GlobalScope`**
- Use `withContext(Dispatchers.IO)` for blocking I/O
- Scope coroutines to lifecycle

## Scope Functions

- `let` — null checks, transformations (refers to object as `it`)
- `apply` — object configuration (refers as `this`, returns object)
- `also` — side effects like logging (refers as `it`, returns object)
- `run` — scoped computation (refers as `this`, returns result)
- `with` — grouping calls on an object

## Naming

- `camelCase` — functions, properties, variables
- `PascalCase` — classes, interfaces, type aliases
- `UPPER_SNAKE_CASE` — `const val` constants
- Boolean: `is`, `has`, `should`, `can` prefix

## Key Rules

- Use `when` over `if-else` chains; exhaustive `when` with sealed types (no `else`)
- Use `require()` for argument validation, `check()` for state validation
- Use sequences for large collections with chained operations
- Use `@JvmInline value class` for type-safe wrappers (IDs, emails)
- Use `object` for singletons, `companion object` for factory methods
- Use SLF4J or kotlin-logging for logging

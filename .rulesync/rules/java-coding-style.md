---
root: false
targets: ["claudecode"]
description: "Java coding style: modern Java 17+ features, immutability, Optional, streams, and naming conventions"
globs: ["*.java"]
---

# Java Coding Style

> Detailed examples and patterns: use skill `java-coding-standards` or `coding-standards`

## Java 17+ Features

- Use **records** for immutable data carriers (DTOs, value objects)
- Use **sealed classes/interfaces** for restricted type hierarchies
- Use **pattern matching** for `instanceof` and `switch` (Java 21+)
- Use **text blocks** for multi-line strings (SQL, JSON, etc.)

## Immutability

- Mark fields `final` wherever possible
- Return `List.copyOf()`, `Collections.unmodifiableList()` — never expose mutable internals
- Use `List.of()`, `Map.of()`, `Set.of()` for creating immutable collections

## Optional

- Use `Optional` ONLY as return type — never as field or parameter
- Never call `Optional.get()` without check — use `orElse()`, `orElseGet()`, `orElseThrow()`
- Chain with `map()`, `flatMap()`, `filter()`

## Streams

- Prefer streams over imperative loops for filter/map/collect transformations
- Use `Collectors.groupingBy()`, `Collectors.joining()` for aggregations

## Naming

- `camelCase` — methods, fields, variables
- `PascalCase` — classes, interfaces, enums, records
- `UPPER_SNAKE_CASE` — constants (`static final`)
- No `I` prefix for interfaces
- Boolean methods: `is`, `has`, `can`, `should` prefix

## Key Rules

- Never use raw generic types — always specify type parameters
- Use `try-with-resources` for all `AutoCloseable` resources
- Use `var` only when the type is obvious from the right-hand side
- Use SLF4J for logging — never `System.out.println`
- Always use `@Override`, `@Nullable`, `@NonNull` annotations
- Prefer composition over inheritance

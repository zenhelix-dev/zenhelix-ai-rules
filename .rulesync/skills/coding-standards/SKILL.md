---
name: coding-standards
description: "Coding standards: readability, KISS/DRY/YAGNI, error handling, type safety, REST conventions, file organization"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Coding Standards

> This skill provides foundational concepts. For implementation examples, use `coding-standards-kotlin` or `coding-standards-java` skill.

## Readability

### Meaningful Names

Choose names that reveal intent. Avoid abbreviations and single-letter variables outside of lambdas/loops.

### Small Functions

Each function should do ONE thing:

- 5-20 lines is ideal
- 50 lines maximum
- If you need comments to explain sections, extract functions instead
- Name functions after their intent, not their implementation

### Single Responsibility

Each class has ONE reason to change. Separate concerns: validation, persistence, notification into distinct classes.

## KISS: Keep It Simple

Choose the simplest solution that correctly solves the problem.

Avoid:

- Premature abstraction
- Generic type parameters unless truly needed
- Design patterns for the sake of patterns
- Framework features you do not need

## DRY: Don't Repeat Yourself

Extract when a pattern repeats THREE or more times, not before.

## YAGNI: You Aren't Gonna Need It

Do not build for hypothetical future requirements. Add abstraction WHEN a second use case is actually needed.

## Immutability

Prefer immutable data structures, final/val fields, and copy-on-write patterns. Never mutate shared state.

## Error Handling

### Principles

- Define custom domain exceptions for business-level errors
- Use structured error responses (ProblemDetail / RFC 7807)
- Never swallow exceptions silently
- Log detailed context server-side, return generic messages to clients

## Type Safety

- Use enums instead of strings for finite sets of values
- Prefer sealed types for finite state representations
- Avoid "stringly-typed" code

## REST API Conventions

- URLs: kebab-case, plural nouns — `/api/v1/user-accounts`
- HTTP methods: GET (read), POST (create), PUT (full update), PATCH (partial), DELETE
- Status codes: 200 (OK), 201 (Created), 204 (No Content), 400, 401, 403, 404, 409, 500
- Request/response bodies: camelCase JSON
- Pagination: `?page=0&size=20&sort=name,asc`
- Versioning: URL path (`/api/v1/`) or header

## File Organization

- Organize by feature/domain, not by type:
  ```
  user/
  ├── UserController
  ├── UserService
  ├── UserRepository
  └── User
  ```
- 200-400 lines per file is typical
- 800 lines maximum — split if larger
- One public class/interface per file

## Code Smells Checklist

- Long functions (> 50 lines)
- Deep nesting (> 4 levels)
- Magic numbers/strings
- God classes (> 800 lines, too many responsibilities)
- Feature envy (method uses another class's data more than its own)
- Primitive obsession (String for email, Int for ID everywhere)
- Shotgun surgery (one change requires edits in many classes)
- Long parameter lists (> 4 parameters — use a data class/record)

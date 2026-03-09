---
name: postgresql-kotlin
description: "Kotlin implementation patterns for PostgreSQL. Use with `postgresql` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: haiku
---

# PostgreSQL — Kotlin

Prerequisites: load `postgresql` skill for foundational concepts.

## Setting Context for RLS

```kotlin
// In your application, set the session variable before queries
dslContext.execute("SET LOCAL app.current_user_id = '${userId}'")
```

## Cursor-Based Pagination

```kotlin
@GetMapping("/orders")
fun getOrders(@RequestParam cursor: Long?, @RequestParam size: Int = 20): Page {
    val orders = if (cursor != null) {
        orderRepository.findByIdGreaterThanOrderByIdAsc(cursor, PageRequest.of(0, size))
    } else {
        orderRepository.findAllByOrderByIdAsc(PageRequest.of(0, size))
    }
    val nextCursor = orders.lastOrNull()?.id
    return Page(data = orders, nextCursor = nextCursor)
}
```

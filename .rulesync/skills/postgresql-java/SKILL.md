---
name: postgresql-java
description: "Java implementation patterns for PostgreSQL. Use with `postgresql` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: haiku
---

# PostgreSQL — Java

Prerequisites: load `postgresql` skill for foundational concepts.

## Setting Context for RLS

```java
// Java/JDBC
connection.createStatement().execute(
    "SET LOCAL app.current_user_id = '" + userId + "'"
);
```

## Cursor-Based Pagination

```java
@GetMapping("/orders")
public Page getOrders(
        @RequestParam(required = false) Long cursor,
        @RequestParam(defaultValue = "20") int size) {
    List<Order> orders = (cursor != null)
        ? orderRepository.findByIdGreaterThanOrderByIdAsc(cursor, PageRequest.of(0, size))
        : orderRepository.findAllByOrderByIdAsc(PageRequest.of(0, size));
    Long nextCursor = orders.isEmpty() ? null : orders.get(orders.size() - 1).getId();
    return new Page(orders, nextCursor);
}
```

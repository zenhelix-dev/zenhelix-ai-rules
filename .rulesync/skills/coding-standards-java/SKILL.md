---
name: coding-standards-java
description: "Java implementation patterns for coding standards. Use with `coding-standards` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Coding Standards — Java

Prerequisites: load `coding-standards` skill for foundational concepts.

## Readability

### Meaningful Names

```java
// BAD
List<int[]> getThem() { ... }

// GOOD
List<Cell> getFlaggedCells() { ... }
```

## Immutability

```java
// Use records for immutable data
public record User(Long id, String name, String email) {}

// Use final fields
public final class Config {
    private final String host;
    private final int port;
}

// Use unmodifiable collections
var users = List.of(user1, user2);
var map = Map.of("key", "value");
var copy = List.copyOf(mutableList);
```

## CompletableFuture Best Practices

```java
public CompletableFuture<Dashboard> fetchDashboard(Long userId) {
    var userFuture = userService.findById(userId);
    var ordersFuture = orderService.findByUserId(userId);

    return userFuture.thenCombine(ordersFuture, Dashboard::new)
        .orTimeout(5, TimeUnit.SECONDS)
        .exceptionally(ex -> {
            logger.error("Dashboard fetch failed for user={}", userId, ex);
            throw new ServiceException("Failed to load dashboard", ex);
        });
}
```

<!-- TODO: Add Java custom domain exceptions example -->

<!-- TODO: Add Java sealed classes for finite states example (Java 17+) -->

<!-- TODO: Add Java input validation example -->

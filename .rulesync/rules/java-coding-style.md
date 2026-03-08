---
root: false
targets: ["claudecode"]
description: "Java coding style: modern Java 17+ features, immutability, Optional, streams, and naming conventions"
globs: ["*.java"]
---

# Java Coding Style

## Java 17+ Features

Use modern Java features wherever applicable:

### Records

Use records for immutable data carriers:

```java
public record UserDto(
    Long id,
    String name,
    String email
) {}

public record PageResponse<T>(
    List<T> items,
    int page,
    int totalPages,
    long totalItems
) {}
```

### Sealed Classes

Use sealed classes for restricted hierarchies:

```java
public sealed interface Shape
    permits Circle, Rectangle, Triangle {
}

public record Circle(double radius) implements Shape {}
public record Rectangle(double width, double height) implements Shape {}
public record Triangle(double base, double height) implements Shape {}
```

### Pattern Matching

Use pattern matching for instanceof and switch:

```java
// Pattern matching for instanceof
if (shape instanceof Circle c) {
    return Math.PI * c.radius() * c.radius();
}

// Pattern matching for switch (Java 21+)
return switch (shape) {
    case Circle c -> Math.PI * c.radius() * c.radius();
    case Rectangle r -> r.width() * r.height();
    case Triangle t -> 0.5 * t.base() * t.height();
};
```

### Text Blocks

Use text blocks for multi-line strings:

```java
String query = """
    SELECT u.id, u.name, u.email
    FROM users u
    WHERE u.active = true
    ORDER BY u.name
    """;
```

## Immutability

Use `final` wherever possible. Return unmodifiable collections:

```java
// WRONG — mutable return
public List<User> getUsers() {
    return users;
}

// CORRECT — unmodifiable
public List<User> getUsers() {
    return Collections.unmodifiableList(users);
}

// CORRECT — Java 10+ copy
public List<User> getUsers() {
    return List.copyOf(users);
}
```

Prefer `List.of()`, `Map.of()`, `Set.of()` for creating immutable collections:

```java
var allowedRoles = Set.of(Role.ADMIN, Role.MODERATOR);
var defaults = Map.of("timeout", "5000", "retries", "3");
```

## Optional

Use Optional for return values that may be absent. NEVER use as a field type or parameter:

```java
// WRONG — Optional as field
public class User {
    private Optional<String> nickname; // Don't do this
}

// WRONG — Optional as parameter
public void process(Optional<String> filter) { } // Don't do this

// CORRECT — Optional return value
public Optional<User> findByEmail(String email) {
    return Optional.ofNullable(userMap.get(email));
}

// CORRECT — chaining
public String getDisplayName(Long userId) {
    return userRepository.findById(userId)
        .map(User::nickname)
        .orElse("Anonymous");
}
```

Never use `Optional.get()` without `isPresent()` check. Prefer `orElse()`, `orElseGet()`, `orElseThrow()`.

## Streams

Prefer streams over imperative loops for transformations:

```java
// WRONG — imperative
List<String> names = new ArrayList<>();
for (User user : users) {
    if (user.isActive()) {
        names.add(user.getName());
    }
}

// CORRECT — stream
List<String> names = users.stream()
    .filter(User::isActive)
    .map(User::getName)
    .toList();
```

Use collectors for complex aggregations:

```java
Map<Role, List<User>> usersByRole = users.stream()
    .collect(Collectors.groupingBy(User::getRole));

String csv = users.stream()
    .map(User::getName)
    .collect(Collectors.joining(", "));
```

## Naming Conventions

- `camelCase` — methods, fields, local variables
- `PascalCase` — classes, interfaces, enums, records
- `UPPER_SNAKE_CASE` — constants (`static final`)
- `I` prefix for interfaces — NEVER (`UserService`, not `IUserService`)
- Boolean methods: `is`, `has`, `can`, `should` prefix

## Generic Types

Never use raw types:

```java
// WRONG
List items = new ArrayList();
Map cache = new HashMap();

// CORRECT
List<Item> items = new ArrayList<>();
Map<String, CacheEntry> cache = new HashMap<>();
```

## Resource Management

Always use try-with-resources for AutoCloseable:

```java
// CORRECT
try (var reader = Files.newBufferedReader(path);
     var writer = Files.newBufferedWriter(output)) {
    // process
}
```

## Builder Pattern

Use for objects with many optional parameters:

```java
public record ServerConfig(
    int port,
    String host,
    Duration timeout,
    int maxRetries
) {
    public static Builder builder() {
        return new Builder();
    }

    public static class Builder {
        private int port = 8080;
        private String host = "localhost";
        private Duration timeout = Duration.ofSeconds(30);
        private int maxRetries = 3;

        public Builder port(int port) { this.port = port; return this; }
        public Builder host(String host) { this.host = host; return this; }
        public Builder timeout(Duration timeout) { this.timeout = timeout; return this; }
        public Builder maxRetries(int maxRetries) { this.maxRetries = maxRetries; return this; }

        public ServerConfig build() {
            return new ServerConfig(port, host, timeout, maxRetries);
        }
    }
}
```

## Local Variable Type Inference

Use `var` where the type is obvious from the right-hand side:

```java
// GOOD — type is obvious
var users = new ArrayList<User>();
var response = client.send(request, HttpResponse.BodyHandlers.ofString());

// BAD — type is not obvious
var result = process(data); // What type is result?
```

## Logging

Use SLF4J. Never use `System.out.println`:

```java
private static final Logger log = LoggerFactory.getLogger(UserService.class);

// Parameterized logging (no string concatenation)
log.info("User created: id={}", user.getId());
log.error("Failed to process order: orderId={}", orderId, exception);
```

## Annotations

Always use:

```java
@Override  // on every overridden method
@Nullable  // when null is a valid return value
@NonNull   // when null is never expected (or use @NonnullByDefault)
```

## Composition Over Inheritance

```java
// WRONG — fragile inheritance
public class CachingUserRepository extends JpaUserRepository { }

// CORRECT — composition
public class CachingUserRepository implements UserRepository {
    private final UserRepository delegate;
    private final Cache<Long, User> cache;

    public CachingUserRepository(UserRepository delegate, Cache<Long, User> cache) {
        this.delegate = delegate;
        this.cache = cache;
    }

    @Override
    public Optional<User> findById(Long id) {
        return Optional.ofNullable(
            cache.get(id, key -> delegate.findById(key).orElse(null))
        );
    }
}
```

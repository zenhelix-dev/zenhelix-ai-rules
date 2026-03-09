---
name: api-design-java
description: "Java implementation patterns for REST API design. Use with `api-design` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# REST API Design — Java

Prerequisites: load `api-design` skill for foundational concepts.

## Spring Controller

```java
@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping
    public ResponseEntity<PageResponse<UserResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) UserStatus status) {
        Page<User> result = userService.findAll(status, PageRequest.of(page, size));
        List<UserResponse> data = result.getContent().stream()
            .map(UserResponse::from)
            .toList();
        return ResponseEntity.ok(new PageResponse<>(data, PaginationMeta.from(result)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<DataResponse<UserResponse>> getById(@PathVariable Long id) {
        User user = userService.findById(id);
        return ResponseEntity.ok(new DataResponse<>(UserResponse.from(user)));
    }

    @PostMapping
    public ResponseEntity<DataResponse<UserResponse>> create(
            @Valid @RequestBody CreateUserRequest request) {
        User user = userService.create(request);
        URI location = URI.create("/api/v1/users/" + user.getId());
        return ResponseEntity.created(location)
            .body(new DataResponse<>(UserResponse.from(user)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<DataResponse<UserResponse>> update(
            @PathVariable Long id,
            @Valid @RequestBody UpdateUserRequest request) {
        User user = userService.update(id, request);
        return ResponseEntity.ok(new DataResponse<>(UserResponse.from(user)));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        userService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
```

## Response DTOs

```java
public record DataResponse<T>(T data) {}

public record PageResponse<T>(List<T> data, PaginationMeta meta) {}

public record PaginationMeta(int page, int size, long totalElements, int totalPages) {
    public static PaginationMeta from(Page<?> page) {
        return new PaginationMeta(
            page.getNumber(), page.getSize(),
            page.getTotalElements(), page.getTotalPages()
        );
    }
}
```

## Error Handling with @ControllerAdvice

```java
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ProblemDetail handleNotFound(ResourceNotFoundException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.NOT_FOUND, ex.getMessage());
        problem.setTitle("Not Found");
        return problem;
    }

    @ExceptionHandler(ConflictException.class)
    public ProblemDetail handleConflict(ConflictException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.CONFLICT, ex.getMessage());
        problem.setTitle("Conflict");
        return problem;
    }

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException ex,
            HttpHeaders headers,
            HttpStatusCode status,
            WebRequest request) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.UNPROCESSABLE_ENTITY, "Validation failed");
        problem.setTitle("Validation Error");
        problem.setProperty("errors", ex.getBindingResult().getFieldErrors().stream()
            .map(e -> Map.of("field", e.getField(), "message", e.getDefaultMessage()))
            .toList());
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(problem);
    }
}
```

## Pagination

### Cursor-Based (Large Datasets)

```java
public record CursorPage<T>(List<T> data, String nextCursor, boolean hasMore) {}

@GetMapping("/events")
public ResponseEntity<CursorPage<EventResponse>> listEvents(
        @RequestParam(required = false) String cursor,
        @RequestParam(defaultValue = "50") int limit) {
    CursorData decodedCursor = cursor != null ? decodeCursor(cursor) : null;
    List<Event> events = eventService.findAfter(decodedCursor, limit + 1);

    boolean hasMore = events.size() > limit;
    List<Event> page = events.subList(0, Math.min(events.size(), limit));
    String nextCursor = hasMore ? encodeCursor(page.get(page.size() - 1)) : null;

    return ResponseEntity.ok(new CursorPage<>(
        page.stream().map(EventResponse::from).toList(),
        nextCursor,
        hasMore
    ));
}
```

## Validation

```java
public record CreateUserRequest(
    @NotBlank(message = "Email is required")
    @Email(message = "Must be a valid email")
    String email,

    @NotBlank(message = "Name is required")
    @Size(min = 2, max = 100, message = "Name must be 2-100 characters")
    String name,

    @Size(max = 500, message = "Bio must not exceed 500 characters")
    String bio
) {}
```

<!-- TODO: Add Java filtering and sorting example -->

<!-- TODO: Add Java rate limiting filter example -->

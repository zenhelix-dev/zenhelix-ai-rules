---
root: false
targets: ["claudecode"]
description: "Java patterns: repository, service layer, DTO mapping, builder, strategy, exception hierarchy, and pagination"
globs: ["*.java"]
---

# Java Patterns

## Repository Pattern with Spring Data JPA

Define repositories as interfaces. Let Spring Data generate implementations:

```java
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    @Query("SELECT u FROM User u WHERE u.role = :role AND u.active = true")
    List<User> findActiveByRole(@Param("role") Role role);

    boolean existsByEmail(String email);
}
```

For complex queries, use custom repository extensions:

```java
public interface UserRepositoryCustom {
    List<User> searchUsers(UserSearchCriteria criteria);
}

public class UserRepositoryCustomImpl implements UserRepositoryCustom {

    @PersistenceContext
    private EntityManager entityManager;

    @Override
    public List<User> searchUsers(UserSearchCriteria criteria) {
        var cb = entityManager.getCriteriaBuilder();
        var query = cb.createQuery(User.class);
        var root = query.from(User.class);
        var predicates = new ArrayList<Predicate>();

        if (criteria.name() != null) {
            predicates.add(cb.like(cb.lower(root.get("name")),
                "%" + criteria.name().toLowerCase() + "%"));
        }
        if (criteria.role() != null) {
            predicates.add(cb.equal(root.get("role"), criteria.role()));
        }

        query.where(predicates.toArray(new Predicate[0]));
        return entityManager.createQuery(query).getResultList();
    }
}

public interface UserRepository
    extends JpaRepository<User, Long>, UserRepositoryCustom { }
```

## Service Layer

Services contain business logic. Use `@Transactional` for data consistency:

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrderRepository orderRepository;
    private final InventoryService inventoryService;
    private final EventPublisher eventPublisher;

    @Transactional
    public Order createOrder(CreateOrderRequest request) {
        // Validate
        request.items().forEach(item ->
            inventoryService.checkAvailability(item.productId(), item.quantity())
        );

        // Create
        var order = Order.create(request);
        var saved = orderRepository.save(order);

        // Reserve inventory
        request.items().forEach(item ->
            inventoryService.reserve(item.productId(), item.quantity())
        );

        // Publish event
        eventPublisher.publish(new OrderCreatedEvent(saved.getId()));

        return saved;
    }

    @Transactional(readOnly = true)
    public Optional<Order> findById(Long id) {
        return orderRepository.findById(id);
    }
}
```

- Use `@Transactional(readOnly = true)` for read-only operations
- Keep transactions short — no external API calls inside transactions
- Let exceptions propagate for automatic rollback

## DTO Mapping

### Manual Mapping (Preferred for Simple Cases)

```java
public record UserResponse(Long id, String name, String email, String role) {

    public static UserResponse from(User user) {
        return new UserResponse(
            user.getId(),
            user.getName(),
            user.getEmail(),
            user.getRole().name()
        );
    }
}
```

### MapStruct (For Complex Mappings)

```java
@Mapper(componentModel = "spring")
public interface UserMapper {

    UserResponse toResponse(User user);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdAt", expression = "java(Instant.now())")
    User toEntity(CreateUserRequest request);
}
```

## Builder Pattern

### Records with Builder

```java
public record SearchQuery(
    String term,
    List<String> filters,
    SortOrder sortOrder,
    int page,
    int size
) {
    public static Builder builder() {
        return new Builder();
    }

    public static class Builder {
        private String term = "";
        private List<String> filters = List.of();
        private SortOrder sortOrder = SortOrder.ASC;
        private int page = 0;
        private int size = 20;

        public Builder term(String term) { this.term = term; return this; }
        public Builder filters(List<String> filters) { this.filters = List.copyOf(filters); return this; }
        public Builder sortOrder(SortOrder sortOrder) { this.sortOrder = sortOrder; return this; }
        public Builder page(int page) { this.page = page; return this; }
        public Builder size(int size) { this.size = size; return this; }

        public SearchQuery build() {
            return new SearchQuery(term, filters, sortOrder, page, size);
        }
    }
}
```

### Lombok Builder (When Lombok is Available)

```java
@Builder
@Value
public class NotificationRequest {
    String recipient;
    String subject;
    String body;
    @Builder.Default
    NotificationType type = NotificationType.EMAIL;
    @Builder.Default
    Priority priority = Priority.NORMAL;
}
```

## Strategy Pattern with Spring DI

```java
public interface PaymentProcessor {
    PaymentResult process(PaymentRequest request);
    PaymentMethod supportedMethod();
}

@Component
public class CreditCardProcessor implements PaymentProcessor {
    @Override
    public PaymentResult process(PaymentRequest request) { /* ... */ }

    @Override
    public PaymentMethod supportedMethod() { return PaymentMethod.CREDIT_CARD; }
}

@Component
public class PayPalProcessor implements PaymentProcessor {
    @Override
    public PaymentResult process(PaymentRequest request) { /* ... */ }

    @Override
    public PaymentMethod supportedMethod() { return PaymentMethod.PAYPAL; }
}

@Service
public class PaymentService {

    private final Map<PaymentMethod, PaymentProcessor> processors;

    public PaymentService(List<PaymentProcessor> processorList) {
        this.processors = processorList.stream()
            .collect(Collectors.toMap(
                PaymentProcessor::supportedMethod,
                Function.identity()
            ));
    }

    public PaymentResult processPayment(PaymentRequest request) {
        var processor = processors.get(request.method());
        if (processor == null) {
            throw new UnsupportedPaymentMethodException(request.method());
        }
        return processor.process(request);
    }
}
```

## Exception Hierarchy

Define a structured exception hierarchy:

```java
public abstract class AppException extends RuntimeException {
    private final String code;
    private final HttpStatus httpStatus;

    protected AppException(String message, String code, HttpStatus httpStatus) {
        super(message);
        this.code = code;
        this.httpStatus = httpStatus;
    }

    public String getCode() { return code; }
    public HttpStatus getHttpStatus() { return httpStatus; }
}

public class NotFoundException extends AppException {
    public NotFoundException(String resource, Object id) {
        super(
            "%s not found: %s".formatted(resource, id),
            "NOT_FOUND",
            HttpStatus.NOT_FOUND
        );
    }
}

public class ConflictException extends AppException {
    public ConflictException(String message) {
        super(message, "CONFLICT", HttpStatus.CONFLICT);
    }
}

public class ValidationException extends AppException {
    private final List<FieldError> errors;

    public ValidationException(List<FieldError> errors) {
        super("Validation failed", "VALIDATION_ERROR", HttpStatus.BAD_REQUEST);
        this.errors = List.copyOf(errors);
    }

    public List<FieldError> getErrors() { return errors; }
}
```

Handle with a global exception handler:

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(AppException.class)
    public ResponseEntity<ErrorResponse> handleAppException(AppException ex) {
        var body = new ErrorResponse(ex.getCode(), ex.getMessage());
        return ResponseEntity.status(ex.getHttpStatus()).body(body);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException ex) {
        var errors = ex.getBindingResult().getFieldErrors().stream()
            .map(e -> new FieldError(e.getField(), e.getDefaultMessage()))
            .toList();
        var body = new ErrorResponse("VALIDATION_ERROR", "Validation failed", errors);
        return ResponseEntity.badRequest().body(body);
    }
}
```

## Pagination

Use Spring Data `Pageable`:

```java
// Controller
@GetMapping("/users")
public PageResponse<UserResponse> getUsers(
    @RequestParam(defaultValue = "0") int page,
    @RequestParam(defaultValue = "20") int size,
    @RequestParam(defaultValue = "name") String sortBy
) {
    var pageable = PageRequest.of(page, size, Sort.by(sortBy));
    var result = userService.findAll(pageable);
    return PageResponse.from(result, UserResponse::from);
}

// Generic page response
public record PageResponse<T>(
    List<T> items,
    int page,
    int totalPages,
    long totalItems
) {
    public static <E, T> PageResponse<T> from(Page<E> page, Function<E, T> mapper) {
        return new PageResponse<>(
            page.getContent().stream().map(mapper).toList(),
            page.getNumber(),
            page.getTotalPages(),
            page.getTotalElements()
        );
    }
}
```

## Specification Pattern for Dynamic Queries

```java
public class UserSpecifications {

    public static Specification<User> hasName(String name) {
        return (root, query, cb) ->
            name == null ? null : cb.like(cb.lower(root.get("name")),
                "%" + name.toLowerCase() + "%");
    }

    public static Specification<User> hasRole(Role role) {
        return (root, query, cb) ->
            role == null ? null : cb.equal(root.get("role"), role);
    }

    public static Specification<User> isActive() {
        return (root, query, cb) -> cb.isTrue(root.get("active"));
    }
}

// Usage
var spec = Specification.where(UserSpecifications.hasName(filter.name()))
    .and(UserSpecifications.hasRole(filter.role()))
    .and(UserSpecifications.isActive());

var users = userRepository.findAll(spec, pageable);
```

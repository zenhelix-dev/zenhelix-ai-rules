---
name: backend-patterns-java
description: "Java implementation patterns for backend architecture. Use with `backend-patterns` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Backend Architecture Patterns — Java

## RESTful API Structure

```java
@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping
    public Page<UserResponse> findAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return userService.findAll(PageRequest.of(page, size))
                .map(User::toResponse);
    }

    @GetMapping("/{id}")
    public UserResponse findById(@PathVariable Long id) {
        return userService.findById(id).toResponse();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse create(@Valid @RequestBody CreateUserRequest request) {
        return userService.create(request).toResponse();
    }

    @PutMapping("/{id}")
    public UserResponse update(
            @PathVariable Long id,
            @Valid @RequestBody UpdateUserRequest request) {
        return userService.update(id, request).toResponse();
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        userService.delete(id);
    }
}
```

## Service Layer

```java
@Service
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final ApplicationEventPublisher eventPublisher;

    public UserService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder,
                       ApplicationEventPublisher eventPublisher) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.eventPublisher = eventPublisher;
    }

    @Transactional(readOnly = true)
    public User findById(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("User with id=" + id + " not found"));
    }

    @Transactional(readOnly = true)
    public Page<User> findAll(Pageable pageable) {
        return userRepository.findAll(pageable);
    }

    @Transactional
    public User create(CreateUserRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new ConflictException("Email " + request.email() + " already in use");
        }
        var user = new User(
                request.name(),
                request.email(),
                passwordEncoder.encode(request.password())
        );
        var saved = userRepository.save(user);
        eventPublisher.publishEvent(new UserCreatedEvent(saved.getId()));
        return saved;
    }

    @Transactional
    public User update(Long id, UpdateUserRequest request) {
        var user = findById(id);
        var updated = user.withName(request.name() != null ? request.name() : user.getName())
                         .withEmail(request.email() != null ? request.email() : user.getEmail());
        return userRepository.save(updated);
    }

    @Transactional
    public void delete(Long id) {
        var user = findById(id);
        userRepository.delete(user);
    }
}
```

## Repository Pattern

```java
public interface UserRepository extends JpaRepository<User, Long> {

    boolean existsByEmail(String email);

    Optional<User> findByEmail(String email);

    @Query("SELECT u FROM User u JOIN FETCH u.roles WHERE u.id = :id")
    Optional<User> findByIdWithRoles(@Param("id") Long id);

    @EntityGraph(attributePaths = {"roles", "permissions"})
    @Override
    Page<User> findAll(Pageable pageable);
}
```

## N+1 Prevention

```java
// PROBLEM: N+1 queries
@OneToMany(mappedBy = "user")
private List<Order> orders; // each user triggers a separate query for orders

// SOLUTION 1: JOIN FETCH in JPQL
@Query("SELECT u FROM User u JOIN FETCH u.orders WHERE u.id = :id")
Optional<User> findByIdWithOrders(@Param("id") Long id);

// SOLUTION 2: @EntityGraph
@EntityGraph(attributePaths = {"orders"})
Optional<User> findById(Long id);

// SOLUTION 3: @BatchSize on the collection
@OneToMany(mappedBy = "user")
@BatchSize(size = 50)
private List<Order> orders;

// SOLUTION 4: Projection/DTO query
@Query("SELECT new com.example.dto.UserOrderSummary(u.name, COUNT(o)) FROM User u LEFT JOIN u.orders o GROUP BY u.name")
List<UserOrderSummary> findUserOrderSummaries();
```

## Transaction Patterns

```java
// Read-only transaction: performance optimization, no dirty checking
@Transactional(readOnly = true)
public List<User> findAll() { ... }

// Default: read-write transaction
@Transactional
public User create(CreateUserRequest request) { ... }

// Propagation: REQUIRES_NEW for independent transaction
@Transactional(propagation = Propagation.REQUIRES_NEW)
public void logAuditEvent(AuditEvent event) { ... }

// Programmatic transaction (when annotation is insufficient)
@Autowired
private TransactionTemplate transactionTemplate;

public void complexOperation() {
    transactionTemplate.execute(status -> {
        // transactional code
        return null;
    });
}
```

## Caching

### Spring Cache with Caffeine

```java
@Configuration
@EnableCaching
public class CacheConfig {

    @Bean
    public CacheManager cacheManager() {
        var manager = new CaffeineCacheManager();
        manager.setCaffeine(
                Caffeine.newBuilder()
                        .maximumSize(1000)
                        .expireAfterWrite(Duration.ofMinutes(10))
                        .recordStats()
        );
        return manager;
    }
}

@Service
public class ProductService {

    private final ProductRepository productRepository;

    public ProductService(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    @Cacheable(value = "products", key = "#id")
    public Product findById(Long id) {
        return productRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Product " + id + " not found"));
    }

    @CacheEvict(value = "products", key = "#id")
    public Product update(Long id, UpdateProductRequest request) { ... }

    @CacheEvict(value = "products", allEntries = true)
    public void clearCache() { }
}
```

### Cache with Redis

```java
@Configuration
@EnableCaching
public class RedisCacheConfig {

    @Bean
    public RedisCacheManager cacheManager(RedisConnectionFactory connectionFactory) {
        var defaultConfig = RedisCacheConfiguration.defaultCacheConfig()
                .entryTtl(Duration.ofMinutes(30))
                .serializeValuesWith(
                        RedisSerializationContext.SerializationPair.fromSerializer(
                                new GenericJackson2JsonRedisSerializer()
                        )
                )
                .disableCachingNullValues();

        return RedisCacheManager.builder(connectionFactory)
                .cacheDefaults(defaultConfig)
                .withCacheConfiguration("products", defaultConfig.entryTtl(Duration.ofHours(1)))
                .build();
    }
}
```

## Error Handling

### Exception Hierarchy

```java
public sealed class DomainException extends RuntimeException
        permits NotFoundException, ValidationException, ConflictException, ForbiddenException {

    protected DomainException(String message) {
        super(message);
    }

    protected DomainException(String message, Throwable cause) {
        super(message, cause);
    }
}

public final class NotFoundException extends DomainException {
    public NotFoundException(String message) { super(message); }
}

public final class ValidationException extends DomainException {
    private final List<FieldError> errors;

    public ValidationException(List<FieldError> errors) {
        super("Validation failed");
        this.errors = List.copyOf(errors);
    }

    public List<FieldError> getErrors() { return errors; }
}

public final class ConflictException extends DomainException {
    public ConflictException(String message) { super(message); }
}

public final class ForbiddenException extends DomainException {
    public ForbiddenException(String message) { super(message); }
}

public record FieldError(String field, String message) {}
```

### Global Exception Handler

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger logger = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(NotFoundException.class)
    public ProblemDetail handleNotFound(NotFoundException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
    }

    @ExceptionHandler(ConflictException.class)
    public ProblemDetail handleConflict(ConflictException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.getMessage());
    }

    @ExceptionHandler(ValidationException.class)
    public ProblemDetail handleValidation(ValidationException ex) {
        var problem = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, ex.getMessage());
        problem.setProperty("errors", ex.getErrors());
        return problem;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleBindingErrors(MethodArgumentNotValidException ex) {
        var errors = ex.getBindingResult().getFieldErrors().stream()
                .map(fe -> new FieldError(fe.getField(), fe.getDefaultMessage() != null ? fe.getDefaultMessage() : ""))
                .toList();
        var problem = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Validation failed");
        problem.setProperty("errors", errors);
        return problem;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception ex) {
        logger.error("Unexpected error", ex);
        return ProblemDetail.forStatusAndDetail(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "An unexpected error occurred"
        );
    }
}
```

## Retry with Resilience4j

```java
@Service
public class PaymentService {

    private static final Logger logger = LoggerFactory.getLogger(PaymentService.class);
    private final PaymentClient paymentClient;

    public PaymentService(PaymentClient paymentClient) {
        this.paymentClient = paymentClient;
    }

    @Retry(name = "payment", fallbackMethod = "paymentFallback")
    public PaymentResult processPayment(PaymentRequest request) {
        return paymentClient.charge(request);
    }

    public PaymentResult paymentFallback(PaymentRequest request, Exception ex) {
        logger.error("Payment failed after retries for order={}", request.orderId(), ex);
        return PaymentResult.error(ex);
    }
}
```

## Rate Limiting with Bucket4j

```java
@Configuration
public class RateLimitConfig {

    @Bean
    public FilterRegistrationBean<RateLimitFilter> rateLimitFilter() {
        var registration = new FilterRegistrationBean<RateLimitFilter>();
        registration.setFilter(new RateLimitFilter());
        registration.addUrlPatterns("/api/*");
        return registration;
    }
}

public class RateLimitFilter extends OncePerRequestFilter {

    private final ConcurrentHashMap<String, Bucket> buckets = new ConcurrentHashMap<>();

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        var clientIp = request.getRemoteAddr();
        var bucket = buckets.computeIfAbsent(clientIp, key -> createBucket());

        if (bucket.tryConsume(1)) {
            filterChain.doFilter(request, response);
        } else {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.getWriter().write("{\"error\": \"Rate limit exceeded\"}");
        }
    }

    private Bucket createBucket() {
        return Bucket.builder()
                .addLimit(
                        BandwidthBuilder.builder()
                                .capacity(100)
                                .refillGreedy(100, Duration.ofMinutes(1))
                                .build()
                )
                .build();
    }
}
```

## Structured Logging

```java
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;

public class UserService {

    private static final Logger logger = LoggerFactory.getLogger(UserService.class);
    private final UserRepository repository;

    public UserService(UserRepository repository) {
        this.repository = repository;
    }

    public User findById(Long id) {
        MDC.put("userId", id.toString());
        try {
            logger.info("Fetching user");
            var user = repository.findById(id)
                    .orElseThrow(() -> {
                        logger.warn("User not found");
                        return new NotFoundException("User " + id + " not found");
                    });
            logger.debug("User found: name={}", user.getName());
            return user;
        } finally {
            MDC.remove("userId");
        }
    }
}
```

### MDC Filter for Request Tracing

```java
@Component
public class RequestIdFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        var requestId = request.getHeader("X-Request-ID");
        if (requestId == null) {
            requestId = UUID.randomUUID().toString();
        }
        MDC.put("requestId", requestId);
        response.setHeader("X-Request-ID", requestId);
        try {
            filterChain.doFilter(request, response);
        } finally {
            MDC.clear();
        }
    }
}
```

## Background Jobs

```java
@Configuration
@EnableScheduling
@EnableAsync
public class AsyncConfig {

    @Bean
    public TaskExecutor taskExecutor() {
        var executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(10);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("async-");
        executor.initialize();
        return executor;
    }
}

@Service
public class ReportService {

    private static final Logger logger = LoggerFactory.getLogger(ReportService.class);
    private final ReportRepository reportRepository;

    public ReportService(ReportRepository reportRepository) {
        this.reportRepository = reportRepository;
    }

    @Scheduled(cron = "0 0 2 * * *") // daily at 2 AM
    public void generateDailyReport() {
        logger.info("Starting daily report generation");
        // generate report
    }

    @Async
    public CompletableFuture<Report> generateReportAsync(ReportRequest request) {
        var report = generateReport(request);
        return CompletableFuture.completedFuture(report);
    }
}
```

## Spring Security JWT Flow

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtFilter;

    public SecurityConfig(JwtAuthenticationFilter jwtFilter) {
        this.jwtFilter = jwtFilter;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
                .csrf(csrf -> csrf.disable())
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/api/v1/auth/**").permitAll()
                        .requestMatchers("/actuator/health").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/v1/products/**").permitAll()
                        .anyRequest().authenticated()
                )
                .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
                .build();
    }
}
```

---
root: false
targets: ["claudecode"]
description: "Java security: Spring Security, input validation, parameterized queries, password hashing, JWT, CORS, and dependency scanning"
globs: ["*.java"]
---

# Java Security

## Spring Security Configuration

Use SecurityFilterChain (not deprecated WebSecurityConfigurerAdapter):

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(csrf -> csrf
                .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse()))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated())
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
            .build();
    }
}
```

## Input Validation

Use Bean Validation annotations with `@Valid`:

```java
public record CreateUserRequest(
    @NotBlank(message = "Name is required")
    @Size(min = 2, max = 100, message = "Name must be between 2 and 100 characters")
    String name,

    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    String email,

    @NotNull(message = "Age is required")
    @Min(value = 13, message = "Must be at least 13 years old")
    @Max(value = 150, message = "Invalid age")
    Integer age
) {}

@PostMapping("/users")
public ResponseEntity<UserResponse> createUser(@Valid @RequestBody CreateUserRequest request) {
    // request is already validated
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(userService.createUser(request));
}
```

Use `@Validated` for method-level validation:

```java
@Service
@Validated
public class UserService {

    public User createUser(@Valid CreateUserRequest request) {
        // ...
    }
}
```

### Custom Validators

```java
@Target({ElementType.FIELD, ElementType.PARAMETER})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = SafeStringValidator.class)
public @interface SafeString {
    String message() default "Contains unsafe characters";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

public class SafeStringValidator implements ConstraintValidator<SafeString, String> {
    private static final Pattern UNSAFE = Pattern.compile("[<>\"'&;]");

    @Override
    public boolean isValid(String value, ConstraintValidatorContext context) {
        return value == null || !UNSAFE.matcher(value).find();
    }
}
```

## Parameterized Queries

NEVER use string concatenation for SQL:

```java
// WRONG — SQL injection vulnerability
String sql = "SELECT * FROM users WHERE name = '" + name + "'";

// CORRECT — JPA parameterized query
@Query("SELECT u FROM User u WHERE u.name = :name")
Optional<User> findByName(@Param("name") String name);

// CORRECT — JDBC parameterized query
var sql = "SELECT * FROM users WHERE name = ?";
jdbcTemplate.queryForObject(sql, userMapper, name);

// CORRECT — Criteria API (type-safe)
var cb = entityManager.getCriteriaBuilder();
var query = cb.createQuery(User.class);
var root = query.from(User.class);
query.where(cb.equal(root.get("name"), name));
```

## Password Hashing

Use BCrypt. Never store plaintext passwords:

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);
}

@Service
public class AuthService {

    private final PasswordEncoder passwordEncoder;

    public User register(RegisterRequest request) {
        var hashedPassword = passwordEncoder.encode(request.password());
        return userRepository.save(new User(request.email(), hashedPassword));
    }

    public boolean authenticate(String rawPassword, String encodedPassword) {
        return passwordEncoder.matches(rawPassword, encodedPassword);
    }
}
```

## JWT Token Handling

```java
@Component
public class JwtTokenProvider {

    private final SecretKey key;
    private final Duration expiration;

    public JwtTokenProvider(
        @Value("${jwt.secret}") String secret,
        @Value("${jwt.expiration:PT1H}") Duration expiration
    ) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expiration = expiration;
    }

    public String generateToken(UserDetails userDetails) {
        var now = Instant.now();
        return Jwts.builder()
            .subject(userDetails.getUsername())
            .issuedAt(Date.from(now))
            .expiration(Date.from(now.plus(expiration)))
            .signWith(key)
            .compact();
    }

    public Optional<String> extractUsername(String token) {
        try {
            var claims = Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
            return Optional.of(claims.getSubject());
        } catch (JwtException e) {
            return Optional.empty();
        }
    }
}
```

- Never store JWT secret in source code
- Use short expiration times (1 hour or less)
- Implement token refresh mechanism
- Validate all claims (expiration, issuer, audience)

## CORS Configuration

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    var config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("https://app.example.com"));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
    config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
    config.setExposedHeaders(List.of("X-Total-Count"));
    config.setAllowCredentials(true);
    config.setMaxAge(3600L);

    var source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
}
```

- NEVER use `allowedOrigins("*")` with `allowCredentials(true)`
- Specify exact allowed origins in production
- Restrict allowed methods to only those needed

## Rate Limiting

Use Bucket4j or Resilience4j:

```java
@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();

    @Override
    protected void doFilterInternal(
        HttpServletRequest request,
        HttpServletResponse response,
        FilterChain chain
    ) throws ServletException, IOException {
        var clientIp = request.getRemoteAddr();
        var bucket = buckets.computeIfAbsent(clientIp, this::createBucket);

        if (bucket.tryConsume(1)) {
            chain.doFilter(request, response);
        } else {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.getWriter().write("{\"error\":\"Rate limit exceeded\"}");
        }
    }

    private Bucket createBucket(String key) {
        return Bucket.builder()
            .addLimit(Bandwidth.classic(100, Refill.greedy(100, Duration.ofMinutes(1))))
            .build();
    }
}
```

## Secret Management

Load secrets from environment variables. Fail fast if missing:

```java
@Configuration
public class SecretsConfig {

    @Value("${DATABASE_URL}")
    private String databaseUrl;

    @Value("${JWT_SECRET}")
    private String jwtSecret;

    @PostConstruct
    public void validateSecrets() {
        Objects.requireNonNull(databaseUrl, "DATABASE_URL must be set");
        Objects.requireNonNull(jwtSecret, "JWT_SECRET must be set");

        if (jwtSecret.length() < 32) {
            throw new IllegalStateException("JWT_SECRET must be at least 32 characters");
        }
    }
}
```

- Never log secrets, even at DEBUG level
- Never include secrets in error responses
- Never commit secrets to version control
- Use `.env` files for local development (add to `.gitignore`)

## Dependency Scanning

Use OWASP Dependency-Check:

```xml
<!-- Maven -->
<plugin>
    <groupId>org.owasp</groupId>
    <artifactId>dependency-check-maven</artifactId>
    <version>9.0.0</version>
    <configuration>
        <failBuildOnCVSS>7</failBuildOnCVSS>
    </configuration>
</plugin>
```

```kotlin
// Gradle
plugins {
    id("org.owasp.dependencycheck") version "9.0.0"
}

dependencyCheck {
    failBuildOnCVSS = 7.0f
}
```

Run regularly:

```bash
mvn dependency-check:check     # Maven
./gradlew dependencyCheckAnalyze   # Gradle
```

## Logging Security

```java
// WRONG — leaks sensitive data
log.info("Login attempt: user={}, password={}", email, password);
log.error("DB error: url={}", connectionString);

// CORRECT — log only safe identifiers
log.info("Login attempt: user={}", email);
log.error("DB connection failed for pool={}", poolName);
```

Sanitize user input before logging to prevent log injection:

```java
public static String sanitize(String input) {
    return input.replaceAll("[\\r\\n]", "_");
}
```

---
name: security-review-java
description: "Java implementation patterns for security review: Spring Security, input validation, OWASP. Use with `security-review` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: opus
  allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Security Review — Java

## A01: Broken Access Control

```java
// VERIFY: proper authorization checks
@PreAuthorize("hasRole('ADMIN') or #userId == authentication.principal.id")
public UserProfile getUserProfile(Long userId) { ... }

// VERIFY: no direct object reference without ownership check
public Order getOrder(Long orderId) {
    var order = orderRepository.findById(orderId)
            .orElseThrow(() -> new NotFoundException("Order not found"));
    var currentUserId = ((CustomUserDetails) SecurityContextHolder.getContext()
            .getAuthentication().getPrincipal()).getId();
    if (!order.getUserId().equals(currentUserId) && !hasRole("ADMIN")) {
        throw new ForbiddenException("Access denied");
    }
    return order;
}
```

## A02: Cryptographic Failures

```java
// GOOD: BCrypt with strength 12
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);
}

// BETTER: Argon2id
@Bean
public PasswordEncoder passwordEncoder() {
    return Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();
}
```

## A03: Injection

### SQL Injection

```java
// VULNERABLE: string concatenation
@Query("SELECT u FROM User u WHERE u.name = '" + name + "'")  // NEVER DO THIS

// SAFE: parameterized queries
@Query("SELECT u FROM User u WHERE u.name = :name")
Optional<User> findByName(@Param("name") String name);

// SAFE: JPA method queries
Optional<User> findByEmailAndStatus(String email, UserStatus status);

// SAFE: jOOQ (parameterized by default)
dsl.selectFrom(USERS).where(USERS.EMAIL.eq(email)).fetchOne();

// SAFE: JDBC with PreparedStatement
try (var stmt = connection.prepareStatement("SELECT * FROM users WHERE id = ?")) {
    stmt.setLong(1, id);
    stmt.executeQuery();
}
```

### LDAP Injection

```java
// Sanitize LDAP special characters: *, (, ), \, NUL
public static String sanitizeLdapInput(String input) {
    return input.replace("\\", "\\\\")
            .replace("*", "\\*")
            .replace("(", "\\(")
            .replace(")", "\\)")
            .replace("\u0000", "");
}
```

## A05: Security Misconfiguration

```java
// VERIFY: security headers configured
@Bean
public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    return http
            .headers(headers -> {
                headers.contentSecurityPolicy(csp ->
                        csp.policyDirectives("default-src 'self'; script-src 'self'; style-src 'self'"));
                headers.frameOptions(fo -> fo.deny());
                headers.httpStrictTransportSecurity(hsts -> {
                    hsts.includeSubDomains(true);
                    hsts.maxAgeInSeconds(31536000);
                });
                headers.contentTypeOptions(cto -> {}); // X-Content-Type-Options: nosniff
            })
            .build();
}
```

## A06: Vulnerable and Outdated Components

```kts
// build.gradle.kts — applies to both Kotlin and Java projects
plugins {
    id("org.owasp.dependencycheck") version "10.0.3"
}

dependencyCheck {
    failBuildOnCVSS = 7.0f
    suppressionFile = "config/owasp-suppressions.xml"
    analyzers.assemblyEnabled = false
}
```

## A07: Identification and Authentication Failures

```java
// VERIFY: proper authentication configuration
@Bean
public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    return http
            .sessionManagement(session ->
                    session.sessionCreationPolicy(SessionCreationPolicy.STATELESS)) // for JWT APIs
            .build();
}

// VERIFY: JWT token validation
public class JwtTokenProvider {

    private final String secret;
    private final long expirationMs;

    public JwtTokenProvider(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.expiration-ms}") long expirationMs) {
        this.secret = secret;
        this.expirationMs = expirationMs;
    }

    // Token must be validated: signature, expiration, issuer
    public boolean validateToken(String token) {
        try {
            var claims = Jwts.parserBuilder()
                    .setSigningKey(Keys.hmacShaKeyFor(secret.getBytes()))
                    .build()
                    .parseClaimsJws(token);
            return !claims.getBody().getExpiration().before(new Date());
        } catch (JwtException ex) {
            logger.warn("Invalid JWT token: {}", ex.getMessage());
            return false;
        }
    }
}
```

## A09: Security Logging and Monitoring Failures

```java
// LOG security-relevant events
logger.info("User login successful: userId={}", userId);
logger.warn("Failed login attempt: email={}, ip={}", email, remoteAddr);
logger.warn("Unauthorized access attempt: userId={}, resource={}", userId, resource);
logger.info("Password changed: userId={}", userId);
logger.warn("Account locked: userId={}, reason={}", userId, reason);

// NEVER log sensitive data
logger.info("User authenticated: email={}", email);  // OK
logger.info("User authenticated: password={}", password);  // NEVER
logger.info("Payment processed: cardNumber={}", cardNumber);  // NEVER
logger.info("Token issued: token={}", token);  // NEVER
```

## A10: Server-Side Request Forgery (SSRF)

```java
// VALIDATE URLs before making requests
public static URI validateUrl(String url) throws URISyntaxException, UnknownHostException {
    var uri = new URI(url);
    var host = InetAddress.getByName(uri.getHost());
    if (host.isLoopbackAddress()) {
        throw new IllegalArgumentException("Loopback addresses not allowed");
    }
    if (host.isSiteLocalAddress()) {
        throw new IllegalArgumentException("Private addresses not allowed");
    }
    if (host.isLinkLocalAddress()) {
        throw new IllegalArgumentException("Link-local addresses not allowed");
    }
    if (!List.of("http", "https").contains(uri.getScheme())) {
        throw new IllegalArgumentException("Only HTTP(S) allowed");
    }
    return uri;
}
```

## Secrets Management

```java
// Java — reading secrets
var dbPassword = System.getenv("DB_PASSWORD");
if (dbPassword == null) {
    throw new IllegalStateException("DB_PASSWORD environment variable is required");
}

// Spring — @Value with env fallback
@Value("${database.password:${DB_PASSWORD:}}")
private String dbPassword;

// Spring — @ConfigurationProperties (preferred)
@ConfigurationProperties(prefix = "app.security")
public record SecurityProperties(
        String jwtSecret,
        @DefaultValue("3600000") long jwtExpirationMs,
        @DefaultValue("12") int bcryptStrength
) {}
```

## Input Validation

```java
// Bean Validation on request DTOs
public record CreateUserRequest(
        @NotBlank(message = "Name is required")
        @Size(min = 2, max = 100, message = "Name must be 2-100 characters")
        @Pattern(regexp = "^[a-zA-Z\\s-']+$", message = "Name contains invalid characters")
        String name,

        @NotBlank
        @Email(message = "Invalid email format")
        @Size(max = 255)
        String email,

        @NotBlank
        @Size(min = 8, max = 128)
        String password
) {}

// Custom validator
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = SafeHtmlValidator.class)
public @interface SafeHtml {
    String message() default "Contains unsafe HTML";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

public class SafeHtmlValidator implements ConstraintValidator<SafeHtml, String> {
    private static final Pattern UNSAFE_PATTERN =
            Pattern.compile("<script|javascript:|on\\w+=", Pattern.CASE_INSENSITIVE);

    @Override
    public boolean isValid(String value, ConstraintValidatorContext context) {
        if (value == null) return true;
        return !UNSAFE_PATTERN.matcher(value).find();
    }
}
```

## XSS Prevention

```java
// Content-Type headers prevent MIME sniffing
// Spring Security sets X-Content-Type-Options: nosniff by default

// CSP header blocks inline scripts
.headers(headers -> headers
        .contentSecurityPolicy(csp ->
                csp.policyDirectives("default-src 'self'; script-src 'self'; object-src 'none'"))
)

// HTML sanitization if accepting rich text
public static String sanitizeHtml(String input) {
    return Jsoup.clean(input, Safelist.basic());
}
```

## CSRF Configuration

```java
// Stateless JWT API: CSRF can be disabled
http.csrf(csrf -> csrf.disable());

// Session-based application: CSRF MUST be enabled
http.csrf(csrf -> {
    csrf.csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse());
    csrf.csrfTokenRequestHandler(new CsrfTokenRequestAttributeHandler());
});
```

## CORS Configuration

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    var config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("https://app.example.com")); // NEVER use "*" with credentials
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "PATCH"));
    config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
    config.setAllowCredentials(true);
    config.setMaxAge(3600L);

    var source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
}
```

## Dependency Scanning

```kts
// build.gradle.kts — applies to both Kotlin and Java projects
plugins {
    id("org.owasp.dependencycheck") version "10.0.3"
}

dependencyCheck {
    failBuildOnCVSS = 7.0f
    formats = listOf("HTML", "JSON")
    outputDirectory = "${layout.buildDirectory.get()}/reports/dependency-check"
    suppressionFile = "config/owasp-suppressions.xml"
}
```

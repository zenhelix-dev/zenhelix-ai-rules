---
name: security-review-kotlin
description: "Kotlin implementation patterns for security review: Spring Security, input validation, OWASP. Use with `security-review` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: opus
  allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Security Review — Kotlin

## A01: Broken Access Control

```kotlin
// VERIFY: proper authorization checks
@PreAuthorize("hasRole('ADMIN') or #userId == authentication.principal.id")
fun getUserProfile(userId: Long): UserProfile

// VERIFY: no direct object reference without ownership check
fun getOrder(orderId: Long): Order {
    val order = orderRepository.findByIdOrNull(orderId)
        ?: throw NotFoundException("Order not found")
    val currentUserId = SecurityContextHolder.getContext().authentication.principal.id
    if (order.userId != currentUserId && !hasRole("ADMIN")) {
        throw ForbiddenException("Access denied")
    }
    return order
}
```

## A02: Cryptographic Failures

```kotlin
// GOOD: BCrypt with strength 12
@Bean
fun passwordEncoder(): PasswordEncoder = BCryptPasswordEncoder(12)

// BETTER: Argon2id
@Bean
fun passwordEncoder(): PasswordEncoder = Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8()
```

## A03: Injection

### SQL Injection

```kotlin
// VULNERABLE: string concatenation
@Query("SELECT u FROM User u WHERE u.name = '" + name + "'")  // NEVER DO THIS

// SAFE: parameterized queries
@Query("SELECT u FROM User u WHERE u.name = :name")
fun findByName(@Param("name") name: String): User?

// SAFE: JPA method queries
fun findByEmailAndStatus(email: String, status: UserStatus): User?

// SAFE: jOOQ (parameterized by default)
dsl.selectFrom(USERS).where(USERS.EMAIL.eq(email)).fetchOne()

// SAFE: JDBC with PreparedStatement
connection.prepareStatement("SELECT * FROM users WHERE id = ?").use { stmt ->
    stmt.setLong(1, id)
    stmt.executeQuery()
}
```

### LDAP Injection

```kotlin
// Sanitize LDAP special characters: *, (, ), \, NUL
fun sanitizeLdapInput(input: String): String =
    input.replace("\\", "\\\\")
        .replace("*", "\\*")
        .replace("(", "\\(")
        .replace(")", "\\)")
        .replace("\u0000", "")
```

## A05: Security Misconfiguration

```kotlin
// VERIFY: security headers configured
@Bean
fun securityFilterChain(http: HttpSecurity): SecurityFilterChain = http
    .headers {
        it.contentSecurityPolicy { csp ->
            csp.policyDirectives("default-src 'self'; script-src 'self'; style-src 'self'")
        }
        it.frameOptions { fo -> fo.deny() }
        it.httpStrictTransportSecurity { hsts ->
            hsts.includeSubDomains(true)
            hsts.maxAgeInSeconds(31536000)
        }
        it.contentTypeOptions { } // X-Content-Type-Options: nosniff
    }
    .build()
```

## A06: Vulnerable and Outdated Components

```kotlin
// build.gradle.kts
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

```kotlin
// VERIFY: proper authentication configuration
@Bean
fun securityFilterChain(http: HttpSecurity): SecurityFilterChain = http
    .sessionManagement {
        it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) // for JWT APIs
    }
    .build()

// VERIFY: JWT token validation
class JwtTokenProvider(
    @Value("\${jwt.secret}") private val secret: String,
    @Value("\${jwt.expiration-ms}") private val expirationMs: Long,
) {
    // Token must be validated: signature, expiration, issuer
    fun validateToken(token: String): Boolean {
        try {
            val claims = Jwts.parserBuilder()
                .setSigningKey(Keys.hmacShaKeyFor(secret.toByteArray()))
                .build()
                .parseClaimsJws(token)
            return !claims.body.expiration.before(Date())
        } catch (ex: JwtException) {
            logger.warn("Invalid JWT token: ${ex.message}")
            return false
        }
    }
}
```

## A09: Security Logging and Monitoring Failures

```kotlin
// LOG security-relevant events
logger.info("User login successful: userId={}", userId)
logger.warn("Failed login attempt: email={}, ip={}", email, remoteAddr)
logger.warn("Unauthorized access attempt: userId={}, resource={}", userId, resource)
logger.info("Password changed: userId={}", userId)
logger.warn("Account locked: userId={}, reason={}", userId, reason)

// NEVER log sensitive data
logger.info("User authenticated: email={}", email)  // OK
logger.info("User authenticated: password={}", password)  // NEVER
logger.info("Payment processed: cardNumber={}", cardNumber)  // NEVER
logger.info("Token issued: token={}", token)  // NEVER
```

## A10: Server-Side Request Forgery (SSRF)

```kotlin
// VALIDATE URLs before making requests
fun validateUrl(url: String): URI {
    val uri = URI(url)
    val host = InetAddress.getByName(uri.host)
    require(!host.isLoopbackAddress) { "Loopback addresses not allowed" }
    require(!host.isSiteLocalAddress) { "Private addresses not allowed" }
    require(!host.isLinkLocalAddress) { "Link-local addresses not allowed" }
    require(uri.scheme in listOf("http", "https")) { "Only HTTP(S) allowed" }
    return uri
}
```

## Secrets Management

```kotlin
// Kotlin — reading secrets
val dbPassword = System.getenv("DB_PASSWORD")
    ?: throw IllegalStateException("DB_PASSWORD environment variable is required")

// Spring — @Value with env fallback
@Value("\${database.password:\${DB_PASSWORD:}}")
private lateinit var dbPassword: String

// Spring — @ConfigurationProperties (preferred)
@ConfigurationProperties(prefix = "app.security")
data class SecurityProperties(
    val jwtSecret: String,
    val jwtExpirationMs: Long = 3600000,
    val bcryptStrength: Int = 12,
)
```

## Input Validation

```kotlin
// Bean Validation on request DTOs
data class CreateUserRequest(
    @field:NotBlank(message = "Name is required")
    @field:Size(min = 2, max = 100, message = "Name must be 2-100 characters")
    @field:Pattern(regexp = "^[a-zA-Z\\s-']+$", message = "Name contains invalid characters")
    val name: String,

    @field:NotBlank
    @field:Email(message = "Invalid email format")
    @field:Size(max = 255)
    val email: String,

    @field:NotBlank
    @field:Size(min = 8, max = 128)
    val password: String,
)

// Custom validator
@Target(AnnotationTarget.FIELD)
@Constraint(validatedBy = [SafeHtmlValidator::class])
annotation class SafeHtml(
    val message: String = "Contains unsafe HTML",
    val groups: Array<KClass<*>> = [],
    val payload: Array<KClass<out Payload>> = [],
)

class SafeHtmlValidator : ConstraintValidator<SafeHtml, String> {
    override fun isValid(value: String?, context: ConstraintValidatorContext): Boolean {
        if (value == null) return true
        return !value.contains(Regex("<script|javascript:|on\\w+=", RegexOption.IGNORE_CASE))
    }
}
```

## XSS Prevention

```kotlin
// Content-Type headers prevent MIME sniffing
// Spring Security sets X-Content-Type-Options: nosniff by default

// CSP header blocks inline scripts
.headers {
    it.contentSecurityPolicy { csp ->
        csp.policyDirectives("default-src 'self'; script-src 'self'; object-src 'none'")
    }
}

// HTML sanitization if accepting rich text
fun sanitizeHtml(input: String): String =
    Jsoup.clean(input, Safelist.basic())
```

## CSRF Configuration

```kotlin
// Stateless JWT API: CSRF can be disabled
http.csrf { it.disable() }

// Session-based application: CSRF MUST be enabled
http.csrf { csrf ->
    csrf.csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
    csrf.csrfTokenRequestHandler(CsrfTokenRequestAttributeHandler())
}
```

## CORS Configuration

```kotlin
@Bean
fun corsConfigurationSource(): CorsConfigurationSource {
    val config = CorsConfiguration().apply {
        allowedOrigins = listOf("https://app.example.com") // NEVER use "*" with credentials
        allowedMethods = listOf("GET", "POST", "PUT", "DELETE", "PATCH")
        allowedHeaders = listOf("Authorization", "Content-Type")
        allowCredentials = true
        maxAge = 3600
    }
    val source = UrlBasedCorsConfigurationSource()
    source.registerCorsConfiguration("/api/**", config)
    return source
}
```

## Dependency Scanning

```kotlin
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

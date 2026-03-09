---
name: backend-patterns
description: "Backend architecture patterns, API design, database optimization, and server-side best practices for Spring Boot with Kotlin and Java."
targets: ["claudecode"]
claudecode:
  model: sonnet
  allowed-tools: ["Read", "Grep", "Glob"]
---

# Backend Development Patterns

Backend architecture patterns and best practices for scalable server-side applications.

## When to Activate

- Designing REST or GraphQL API endpoints
- Implementing repository, service, or controller layers
- Optimizing database queries (N+1, indexing, connection pooling)
- Adding caching (Redis, in-memory, Spring Cache)
- Setting up background jobs or async processing
- Structuring error handling and validation for APIs
- Building filters, interceptors, or Spring Security configurations

## API Design Patterns

### RESTful API Structure

```kotlin
// Resource-based URLs
GET    /api/markets                 # List resources
GET    /api/markets/:id             # Get single resource
POST   /api/markets                 # Create resource
PUT    /api/markets/:id             # Replace resource
PATCH  /api/markets/:id             # Update resource
DELETE /api/markets/:id             # Delete resource

// Query parameters for filtering, sorting, pagination
GET /api/markets?status=active&sort=volume&limit=20&offset=0
```

### Repository Pattern

```kotlin
// Abstract data access logic
interface MarketRepository : JpaRepository<Market, String> {

    fun findByStatus(status: MarketStatus): List<Market>

    @Query("SELECT m FROM Market m WHERE m.status = :status ORDER BY m.volume DESC")
    fun findByStatusOrderByVolumeDesc(
        @Param("status") status: MarketStatus,
        pageable: Pageable
    ): Page<Market>
}

// Custom repository for complex queries
interface MarketRepositoryCustom {
    fun findAllWithFilters(filters: MarketFilters): List<Market>
}

class MarketRepositoryCustomImpl(
    private val entityManager: EntityManager
) : MarketRepositoryCustom {

    override fun findAllWithFilters(filters: MarketFilters): List<Market> {
        val cb = entityManager.criteriaBuilder
        val query = cb.createQuery(Market::class.java)
        val root = query.from(Market::class.java)
        val predicates = mutableListOf<Predicate>()

        filters.status?.let {
            predicates.add(cb.equal(root.get<MarketStatus>("status"), it))
        }

        query.where(*predicates.toTypedArray())

        return entityManager.createQuery(query)
            .setMaxResults(filters.limit ?: 20)
            .resultList
    }
}
```

### Service Layer Pattern

```kotlin
// Business logic separated from data access
@Service
class MarketService(
    private val marketRepository: MarketRepository,
    private val embeddingService: EmbeddingService,
    private val vectorSearchService: VectorSearchService
) {

    suspend fun searchMarkets(query: String, limit: Int = 10): List<Market> {
        // Business logic
        val embedding = embeddingService.generateEmbedding(query)
        val results = vectorSearchService.search(embedding, limit)

        // Fetch full data
        val markets = marketRepository.findAllById(results.map { it.id })

        // Sort by similarity
        val scoreMap = results.associate { it.id to it.score }
        return markets.sortedByDescending { scoreMap[it.id] ?: 0.0 }
    }
}
```

### Filter/Interceptor Pattern

```kotlin
// Request/response processing pipeline (replaces middleware)
@Component
class AuthenticationFilter(
    private val tokenService: TokenService
) : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        val token = request.getHeader("Authorization")?.removePrefix("Bearer ")

        if (token == null) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Unauthorized")
            return
        }

        try {
            val user = tokenService.verifyToken(token)
            SecurityContextHolder.getContext().authentication =
                UsernamePasswordAuthenticationToken(user, null, user.authorities)
            filterChain.doFilter(request, response)
        } catch (e: InvalidTokenException) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid token")
        }
    }
}

// HandlerInterceptor for cross-cutting concerns
@Component
class RequestLoggingInterceptor : HandlerInterceptor {

    override fun preHandle(request: HttpServletRequest, response: HttpServletResponse, handler: Any): Boolean {
        logger.info("Incoming request: {} {}", request.method, request.requestURI)
        return true
    }

    override fun afterCompletion(
        request: HttpServletRequest, response: HttpServletResponse,
        handler: Any, ex: Exception?
    ) {
        logger.info("Completed: {} {} -> {}", request.method, request.requestURI, response.status)
    }
}
```

## Database Patterns

### Query Optimization

```kotlin
// GOOD: Select only needed columns with projections
interface MarketSummary {
    val id: String
    val name: String
    val status: MarketStatus
    val volume: Long
}

@Query("SELECT m.id as id, m.name as name, m.status as status, m.volume as volume " +
       "FROM Market m WHERE m.status = :status ORDER BY m.volume DESC")
fun findActiveSummaries(@Param("status") status: MarketStatus, pageable: Pageable): Page<MarketSummary>

// BAD: Select everything
fun findAll(): List<Market>
```

### N+1 Query Prevention

```kotlin
// BAD: N+1 query problem
val markets = marketRepository.findAll()
for (market in markets) {
    market.creator = userRepository.findById(market.creatorId).orElse(null)  // N queries
}

// GOOD: Fetch join in JPQL
@Query("SELECT m FROM Market m JOIN FETCH m.creator WHERE m.status = :status")
fun findWithCreator(@Param("status") status: MarketStatus): List<Market>

// GOOD: Batch fetch with @EntityGraph
@EntityGraph(attributePaths = ["creator", "categories"])
fun findByStatus(status: MarketStatus): List<Market>
```

### Transaction Pattern

```kotlin
@Service
class MarketService(
    private val marketRepository: MarketRepository,
    private val positionRepository: PositionRepository
) {

    @Transactional
    fun createMarketWithPosition(
        marketData: CreateMarketDto,
        positionData: CreatePositionDto
    ): Market {
        val market = marketRepository.save(
            Market(
                name = marketData.name,
                description = marketData.description,
                status = MarketStatus.ACTIVE
            )
        )

        positionRepository.save(
            Position(
                marketId = market.id,
                amount = positionData.amount,
                side = positionData.side
            )
        )

        return market
        // Transaction commits automatically; rolls back on exception
    }
}
```

## Caching Strategies

### Spring Cache with Redis

```kotlin
@Service
class CachedMarketService(
    private val marketRepository: MarketRepository
) {

    @Cacheable(value = ["markets"], key = "#id")
    fun findById(id: String): Market? {
        return marketRepository.findById(id).orElse(null)
    }

    @CacheEvict(value = ["markets"], key = "#id")
    fun invalidateCache(id: String) {
        // Cache entry removed
    }

    @CachePut(value = ["markets"], key = "#result.id")
    fun updateMarket(id: String, data: UpdateMarketDto): Market {
        val market = marketRepository.findById(id)
            .orElseThrow { NotFoundException("Market not found: $id") }

        val updated = market.copy(
            name = data.name ?: market.name,
            description = data.description ?: market.description
        )

        return marketRepository.save(updated)
    }
}
```

### Cache-Aside Pattern with RedisTemplate

```kotlin
@Service
class MarketCacheService(
    private val redisTemplate: RedisTemplate<String, Market>,
    private val marketRepository: MarketRepository
) {

    fun getMarketWithCache(id: String): Market {
        val cacheKey = "market:$id"

        // Try cache
        val cached = redisTemplate.opsForValue().get(cacheKey)
        if (cached != null) return cached

        // Cache miss - fetch from DB
        val market = marketRepository.findById(id)
            .orElseThrow { NotFoundException("Market not found") }

        // Update cache with 5-minute TTL
        redisTemplate.opsForValue().set(cacheKey, market, Duration.ofMinutes(5))

        return market
    }
}
```

## Error Handling Patterns

### Centralized Error Handler

```kotlin
// Custom exception hierarchy
sealed class ApiException(
    val statusCode: HttpStatus,
    override val message: String,
    cause: Throwable? = null
) : RuntimeException(message, cause)

class NotFoundException(message: String) : ApiException(HttpStatus.NOT_FOUND, message)
class ValidationException(message: String) : ApiException(HttpStatus.BAD_REQUEST, message)
class UnauthorizedException(message: String) : ApiException(HttpStatus.UNAUTHORIZED, message)
class ForbiddenException(message: String) : ApiException(HttpStatus.FORBIDDEN, message)

// Global exception handler
@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(ApiException::class)
    fun handleApiException(ex: ApiException): ResponseEntity<ApiResponse<Nothing>> {
        return ResponseEntity.status(ex.statusCode).body(
            ApiResponse(success = false, error = ex.message)
        )
    }

    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun handleValidation(ex: MethodArgumentNotValidException): ResponseEntity<ApiResponse<Nothing>> {
        val errors = ex.bindingResult.fieldErrors
            .map { "${it.field}: ${it.defaultMessage}" }

        return ResponseEntity.badRequest().body(
            ApiResponse(success = false, error = "Validation failed", details = errors)
        )
    }

    @ExceptionHandler(Exception::class)
    fun handleUnexpected(ex: Exception): ResponseEntity<ApiResponse<Nothing>> {
        logger.error("Unexpected error", ex)

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(
            ApiResponse(success = false, error = "Internal server error")
        )
    }
}

// Usage in controller
@GetMapping("/api/markets")
fun getMarkets(): ResponseEntity<ApiResponse<List<Market>>> {
    val markets = marketService.findAll()
    return ResponseEntity.ok(ApiResponse(success = true, data = markets))
}
```

### Retry with Exponential Backoff

```kotlin
// Using Spring Retry
@Retryable(
    value = [ServiceUnavailableException::class],
    maxAttempts = 3,
    backoff = Backoff(delay = 1000, multiplier = 2.0)
)
suspend fun fetchFromExternalApi(): ExternalData {
    return externalApiClient.fetch()
}

@Recover
fun recoverFromFetch(ex: ServiceUnavailableException): ExternalData {
    logger.error("All retries exhausted for external API", ex)
    throw ServiceException("External API unavailable after retries", ex)
}

// Manual retry with Kotlin coroutines
suspend fun <T> withRetry(
    maxRetries: Int = 3,
    block: suspend () -> T
): T {
    var lastException: Exception? = null

    repeat(maxRetries) { attempt ->
        try {
            return block()
        } catch (e: Exception) {
            lastException = e
            if (attempt < maxRetries - 1) {
                val delayMs = 1000L * 2.0.pow(attempt).toLong()
                delay(delayMs)
            }
        }
    }

    throw lastException!!
}

// Usage
val data = withRetry { fetchFromExternalApi() }
```

## Authentication & Authorization

### Spring Security with JWT

```kotlin
@Configuration
@EnableWebSecurity
class SecurityConfig(
    private val jwtTokenProvider: JwtTokenProvider
) {

    @Bean
    fun securityFilterChain(http: HttpSecurity): SecurityFilterChain {
        return http
            .csrf { it.disable() }
            .sessionManagement { it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
            .authorizeHttpRequests {
                it.requestMatchers("/api/auth/**").permitAll()
                it.requestMatchers("/api/admin/**").hasRole("ADMIN")
                it.anyRequest().authenticated()
            }
            .addFilterBefore(JwtAuthenticationFilter(jwtTokenProvider), UsernamePasswordAuthenticationFilter::class.java)
            .build()
    }
}

@Component
class JwtTokenProvider(
    @Value("\${jwt.secret}") private val secretKey: String
) {

    fun verifyToken(token: String): UserDetails {
        return try {
            val claims = Jwts.parserBuilder()
                .setSigningKey(Keys.hmacShaKeyFor(secretKey.toByteArray()))
                .build()
                .parseClaimsJws(token)
                .body

            UserPrincipal(
                userId = claims.subject,
                email = claims["email"] as String,
                role = claims["role"] as String
            )
        } catch (e: JwtException) {
            throw UnauthorizedException("Invalid token")
        }
    }
}
```

### Role-Based Access Control

```kotlin
enum class Permission {
    READ, WRITE, DELETE, ADMIN
}

enum class Role(val permissions: Set<Permission>) {
    ADMIN(setOf(Permission.READ, Permission.WRITE, Permission.DELETE, Permission.ADMIN)),
    MODERATOR(setOf(Permission.READ, Permission.WRITE, Permission.DELETE)),
    USER(setOf(Permission.READ, Permission.WRITE))
}

// Method-level security
@PreAuthorize("hasRole('ADMIN')")
@DeleteMapping("/api/markets/{id}")
fun deleteMarket(@PathVariable id: String): ResponseEntity<ApiResponse<Nothing>> {
    marketService.delete(id)
    return ResponseEntity.ok(ApiResponse(success = true))
}

// Custom permission check
@PreAuthorize("@permissionEvaluator.hasPermission(authentication, #id, 'MARKET', 'DELETE')")
@DeleteMapping("/api/markets/{id}")
fun deleteMarket(@PathVariable id: String): ResponseEntity<ApiResponse<Nothing>> {
    marketService.delete(id)
    return ResponseEntity.ok(ApiResponse(success = true))
}
```

## Rate Limiting

### Bucket4j Rate Limiter

```kotlin
@Component
class RateLimitingFilter(
    private val cacheManager: CacheManager
) : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        val ip = request.getHeader("X-Forwarded-For") ?: request.remoteAddr
        val bucket = resolveBucket(ip)

        if (bucket.tryConsume(1)) {
            filterChain.doFilter(request, response)
        } else {
            response.status = HttpServletResponse.SC_TOO_MANY_REQUESTS
            response.writer.write("""{"success": false, "error": "Rate limit exceeded"}""")
        }
    }

    private fun resolveBucket(key: String): Bucket {
        return Bucket4j.builder()
            .addLimit(Bandwidth.classic(100, Refill.intervally(100, Duration.ofMinutes(1))))
            .build()
    }
}
```

## Background Jobs & Queues

### Spring Scheduling

```kotlin
@Component
class MarketIndexingJob(
    private val marketService: MarketService,
    private val indexService: IndexService
) {

    @Scheduled(fixedDelay = 60_000) // Every 60 seconds
    fun reindexPendingMarkets() {
        val pending = marketService.findPendingIndexing()

        for (market in pending) {
            try {
                indexService.index(market)
                marketService.markIndexed(market.id)
            } catch (e: Exception) {
                logger.error("Failed to index market: ${market.id}", e)
            }
        }
    }
}

// Async processing with @Async
@Service
class AsyncMarketService(
    private val indexService: IndexService
) {

    @Async
    fun indexMarketAsync(marketId: String): CompletableFuture<Void> {
        indexService.indexById(marketId)
        return CompletableFuture.completedFuture(null)
    }
}

// Controller usage
@PostMapping("/api/markets")
fun createMarket(@Valid @RequestBody request: CreateMarketRequest): ResponseEntity<ApiResponse<Market>> {
    val market = marketService.create(request)

    // Add to async queue instead of blocking
    asyncMarketService.indexMarketAsync(market.id)

    return ResponseEntity.status(HttpStatus.CREATED)
        .body(ApiResponse(success = true, data = market))
}
```

## Logging & Monitoring

### Structured Logging with SLF4J + MDC

```kotlin
@Component
class RequestContextFilter : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        val requestId = UUID.randomUUID().toString()
        MDC.put("requestId", requestId)
        MDC.put("method", request.method)
        MDC.put("path", request.requestURI)

        try {
            filterChain.doFilter(request, response)
        } finally {
            MDC.clear()
        }
    }
}

// Usage in service
@Service
class MarketService(
    private val marketRepository: MarketRepository
) {

    private val logger = LoggerFactory.getLogger(MarketService::class.java)

    fun findAll(): List<Market> {
        logger.info("Fetching all markets")

        return try {
            val markets = marketRepository.findAll()
            logger.info("Found {} markets", markets.size)
            markets
        } catch (e: Exception) {
            logger.error("Failed to fetch markets", e)
            throw ServiceException("Failed to fetch markets", e)
        }
    }
}

// logback-spring.xml for structured JSON output
// <encoder class="net.logstash.logback.encoder.LogstashEncoder"/>
```

**Remember**: Backend patterns enable scalable, maintainable server-side applications. Choose patterns that fit your complexity level.

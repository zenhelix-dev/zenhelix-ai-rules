---
name: coding-standards
description: "Universal coding standards, best practices, and patterns for Kotlin and Java development."
targets: ["claudecode"]
claudecode:
  model: sonnet
  allowed-tools: ["Read", "Grep", "Glob"]
---

# Coding Standards & Best Practices

Universal coding standards applicable across all projects.

## When to Activate

- Starting a new project or module
- Reviewing code for quality and maintainability
- Refactoring existing code to follow conventions
- Enforcing naming, formatting, or structural consistency
- Setting up linting, formatting, or static analysis rules
- Onboarding new contributors to coding conventions

## Code Quality Principles

### 1. Readability First

- Code is read more than written
- Clear variable and function names
- Self-documenting code preferred over comments
- Consistent formatting

### 2. KISS (Keep It Simple, Stupid)

- Simplest solution that works
- Avoid over-engineering
- No premature optimization
- Easy to understand > clever code

### 3. DRY (Don't Repeat Yourself)

- Extract common logic into functions
- Create reusable components
- Share utilities across modules
- Avoid copy-paste programming

### 4. YAGNI (You Aren't Gonna Need It)

- Don't build features before they're needed
- Avoid speculative generality
- Add complexity only when required
- Start simple, refactor when needed

## Kotlin Standards

### Variable Naming

```kotlin
// GOOD: Descriptive names
val marketSearchQuery = "election"
val isUserAuthenticated = true
val totalRevenue = 1000L

// BAD: Unclear names
val q = "election"
val flag = true
val x = 1000L
```

### Function Naming

```kotlin
// GOOD: Verb-noun pattern
suspend fun fetchMarketData(marketId: String): MarketData { }
fun calculateSimilarity(a: DoubleArray, b: DoubleArray): Double { }
fun isValidEmail(email: String): Boolean { }

// BAD: Unclear or noun-only
suspend fun market(id: String): Any { }
fun similarity(a: DoubleArray, b: DoubleArray): Any { }
fun email(e: String): Any { }
```

### Immutability Pattern (CRITICAL)

```kotlin
// ALWAYS use data class copy
val updatedUser = user.copy(name = "New Name")

val updatedList = items + newItem

// NEVER mutate directly
user.name = "New Name"          // BAD (use val + copy)
(items as MutableList).add(newItem)  // BAD
```

### Error Handling

```kotlin
// GOOD: Comprehensive error handling
suspend fun fetchData(url: String): ResponseData {
    return try {
        val response = httpClient.get(url)

        if (!response.status.isSuccess()) {
            throw HttpException("HTTP ${response.status.value}: ${response.status.description}")
        }

        response.body()
    } catch (e: HttpException) {
        logger.error("Fetch failed: ${e.message}", e)
        throw ServiceException("Failed to fetch data", e)
    }
}

// BAD: No error handling
suspend fun fetchData(url: String): ResponseData {
    val response = httpClient.get(url)
    return response.body()
}
```

### Coroutines Best Practices

```kotlin
// GOOD: Parallel execution when possible
val (users, markets, stats) = coroutineScope {
    Triple(
        async { fetchUsers() },
        async { fetchMarkets() },
        async { fetchStats() }
    )
}.let { (u, m, s) -> Triple(u.await(), m.await(), s.await()) }

// BAD: Sequential when unnecessary
val users = fetchUsers()
val markets = fetchMarkets()
val stats = fetchStats()
```

### Type Safety

```kotlin
// GOOD: Proper types with sealed classes/enums
data class Market(
    val id: String,
    val name: String,
    val status: MarketStatus,
    val createdAt: Instant
)

enum class MarketStatus {
    ACTIVE, RESOLVED, CLOSED
}

fun getMarket(id: String): Market {
    // Implementation
}

// BAD: Using Any or unchecked types
fun getMarket(id: Any): Any {
    // Implementation
}
```

## Java Standards

### Variable Naming

```java
// GOOD: Descriptive names
final String marketSearchQuery = "election";
final boolean isUserAuthenticated = true;
final long totalRevenue = 1000L;

// BAD: Unclear names
final String q = "election";
final boolean flag = true;
final long x = 1000L;
```

### Immutability Pattern (CRITICAL)

```java
// GOOD: Use records (Java 16+) or immutable classes
public record User(String id, String name, String email) {}

// Creating updated copies with builders or wither methods
var updatedUser = new User(user.id(), "New Name", user.email());

// Use List.of / List.copyOf for immutable collections
var updatedList = Stream.concat(items.stream(), Stream.of(newItem))
    .toList();

// BAD: Mutable state
user.setName("New Name");  // BAD
items.add(newItem);        // BAD
```

### Error Handling

```java
// GOOD: Comprehensive error handling
public ResponseData fetchData(String url) {
    try {
        var response = httpClient.send(request, BodyHandlers.ofString());

        if (response.statusCode() >= 400) {
            throw new HttpException("HTTP %d: %s".formatted(response.statusCode(), response.body()));
        }

        return objectMapper.readValue(response.body(), ResponseData.class);
    } catch (HttpException e) {
        logger.error("Fetch failed: {}", e.getMessage(), e);
        throw new ServiceException("Failed to fetch data", e);
    }
}
```

### CompletableFuture Best Practices

```java
// GOOD: Parallel execution when possible
var usersFuture = CompletableFuture.supplyAsync(() -> fetchUsers());
var marketsFuture = CompletableFuture.supplyAsync(() -> fetchMarkets());
var statsFuture = CompletableFuture.supplyAsync(() -> fetchStats());

CompletableFuture.allOf(usersFuture, marketsFuture, statsFuture).join();

var users = usersFuture.join();
var markets = marketsFuture.join();
var stats = statsFuture.join();

// BAD: Sequential when unnecessary
var users = fetchUsers();
var markets = fetchMarkets();
var stats = fetchStats();
```

## API Design Standards

### REST API Conventions

```
GET    /api/markets              # List all markets
GET    /api/markets/:id          # Get specific market
POST   /api/markets              # Create new market
PUT    /api/markets/:id          # Update market (full)
PATCH  /api/markets/:id          # Update market (partial)
DELETE /api/markets/:id          # Delete market

# Query parameters for filtering
GET /api/markets?status=active&limit=10&offset=0
```

### Response Format

```kotlin
// GOOD: Consistent response structure
data class ApiResponse<T>(
    val success: Boolean,
    val data: T? = null,
    val error: String? = null,
    val meta: PageMeta? = null
)

data class PageMeta(
    val total: Long,
    val page: Int,
    val limit: Int
)

// Success response
ResponseEntity.ok(
    ApiResponse(success = true, data = markets, meta = PageMeta(total = 100, page = 1, limit = 10))
)

// Error response
ResponseEntity.badRequest().body(
    ApiResponse<Nothing>(success = false, error = "Invalid request")
)
```

### Input Validation

```kotlin
// GOOD: Schema validation with Jakarta Validation
data class CreateMarketRequest(
    @field:NotBlank
    @field:Size(min = 1, max = 200)
    val name: String,

    @field:NotBlank
    @field:Size(min = 1, max = 2000)
    val description: String,

    @field:Future
    val endDate: Instant,

    @field:NotEmpty
    val categories: List<String>
)

@PostMapping("/api/markets")
fun createMarket(@Valid @RequestBody request: CreateMarketRequest): ResponseEntity<ApiResponse<Market>> {
    // Validation is handled automatically by Spring
    val market = marketService.create(request)
    return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse(success = true, data = market))
}
```

## File Organization

### Project Structure

```
src/
├── main/
│   ├── kotlin/com/example/app/
│   │   ├── config/              # Spring configuration
│   │   ├── market/              # Market feature
│   │   │   ├── MarketController.kt
│   │   │   ├── MarketService.kt
│   │   │   ├── MarketRepository.kt
│   │   │   ├── Market.kt        # Entity/domain model
│   │   │   └── MarketDto.kt     # Request/response DTOs
│   │   ├── auth/                # Auth feature
│   │   └── common/              # Shared utilities
│   │       ├── exception/       # Custom exceptions
│   │       ├── util/            # Helper functions
│   │       └── dto/             # Shared DTOs
│   └── resources/
│       ├── application.yml
│       └── db/migration/        # Flyway migrations
└── test/
    └── kotlin/com/example/app/
        ├── market/
        │   ├── MarketControllerTest.kt
        │   ├── MarketServiceTest.kt
        │   └── MarketRepositoryTest.kt
        └── integration/
```

### File Naming

```
MarketController.kt          # PascalCase for classes
MarketService.kt             # PascalCase for classes
MarketRepository.kt          # PascalCase for interfaces/classes
MarketDto.kt                 # PascalCase with Dto suffix
DateUtils.kt                 # PascalCase for utility classes
market-schema.graphql         # kebab-case for non-Kotlin resources
```

## Comments & Documentation

### When to Comment

```kotlin
// GOOD: Explain WHY, not WHAT
// Use exponential backoff to avoid overwhelming the API during outages
val delay = minOf(1000L * 2.0.pow(retryCount).toLong(), 30_000L)

// Deliberately using mutable list here for performance with large datasets
val items = mutableListOf<Item>()

// BAD: Stating the obvious
// Increment counter by 1
count++

// Set name to user's name
name = user.name
```

### KDoc for Public APIs

```kotlin
/**
 * Searches markets using semantic similarity.
 *
 * @param query Natural language search query
 * @param limit Maximum number of results (default: 10)
 * @return List of markets sorted by similarity score
 * @throws ServiceException If embedding API fails or database is unavailable
 *
 * @sample
 * ```

* val results = searchMarkets("election", 5)
* println(results[0].name) // "Trump vs Biden"
* ```

*/
suspend fun searchMarkets(
query: String,
limit: Int = 10
): List<Market> {
// Implementation
}
```

## Performance Best Practices

### Caching with Spring Cache

```kotlin
@Cacheable("markets", key = "#id")
fun findMarketById(id: String): Market? {
    return marketRepository.findById(id).orElse(null)
}

@CacheEvict("markets", key = "#id")
fun updateMarket(id: String, data: UpdateMarketRequest): Market {
    // Update logic
}
```

### Lazy Initialization

```kotlin
// GOOD: Lazy initialization for expensive resources
val heavyResource: ExpensiveService by lazy {
    ExpensiveService.create()
}
```

### Database Queries

```kotlin
// GOOD: Select only needed columns with projections
@Query("SELECT m.id, m.name, m.status FROM Market m WHERE m.status = :status")
fun findActiveMarketSummaries(@Param("status") status: MarketStatus): List<MarketSummary>

// BAD: Select everything
fun findAll(): List<Market>  // Fetches all columns
```

## Testing Standards

### Test Structure (AAA Pattern)

```kotlin
@Test
fun `calculates similarity correctly`() {
    // Arrange
    val vector1 = doubleArrayOf(1.0, 0.0, 0.0)
    val vector2 = doubleArrayOf(0.0, 1.0, 0.0)

    // Act
    val similarity = calculateCosineSimilarity(vector1, vector2)

    // Assert
    assertThat(similarity).isEqualTo(0.0)
}
```

### Test Naming

```kotlin
// GOOD: Descriptive test names
@Test fun `returns empty list when no markets match query`() { }
@Test fun `throws exception when API key is missing`() { }
@Test fun `falls back to substring search when Redis unavailable`() { }

// BAD: Vague test names
@Test fun `works`() { }
@Test fun `test search`() { }
```

## Code Smell Detection

Watch for these anti-patterns:

### 1. Long Functions

```kotlin
// BAD: Function > 50 lines
fun processMarketData() {
    // 100 lines of code
}

// GOOD: Split into smaller functions
fun processMarketData(): ProcessedData {
    val validated = validateData()
    val transformed = transformData(validated)
    return saveData(transformed)
}
```

### 2. Deep Nesting

```kotlin
// BAD: 5+ levels of nesting
if (user != null) {
    if (user.isAdmin) {
        if (market != null) {
            if (market.isActive) {
                if (hasPermission) {
                    // Do something
                }
            }
        }
    }
}

// GOOD: Early returns
if (user == null) return
if (!user.isAdmin) return
if (market == null) return
if (!market.isActive) return
if (!hasPermission) return

// Do something
```

### 3. Magic Numbers

```kotlin
// BAD: Unexplained numbers
if (retryCount > 3) { }
delay(500)

// GOOD: Named constants
const val MAX_RETRIES = 3
const val DEBOUNCE_DELAY_MS = 500L

if (retryCount > MAX_RETRIES) { }
delay(DEBOUNCE_DELAY_MS)
```

**Remember**: Code quality is not negotiable. Clear, maintainable code enables rapid development and confident refactoring.

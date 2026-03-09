---
name: tdd-workflow
description: "Use this skill when writing new features, fixing bugs, or refactoring code. Enforces test-driven development with 80%+ coverage including unit, integration, and E2E tests."
targets: ["claudecode"]
claudecode:
  model: opus
  allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
---

# Test-Driven Development Workflow

This skill ensures all code development follows TDD principles with comprehensive test coverage.

## When to Activate

- Writing new features or functionality
- Fixing bugs or issues
- Refactoring existing code
- Adding API endpoints
- Creating new services or components

## Core Principles

### 1. Tests BEFORE Code

ALWAYS write tests first, then implement code to make tests pass.

### 2. Coverage Requirements

- Minimum 80% coverage (unit + integration + E2E)
- All edge cases covered
- Error scenarios tested
- Boundary conditions verified

### 3. Test Types

#### Unit Tests

- Individual functions and utilities
- Service layer logic
- Pure functions
- Helpers and utilities

#### Integration Tests

- API endpoints (Spring MVC Test)
- Database operations (Spring Data JPA + Testcontainers)
- Service interactions
- External API calls

#### E2E Tests (Selenium / Testcontainers)

- Critical user flows
- Complete workflows
- Full application stack testing
- API contract verification

## TDD Workflow Steps

### Step 1: Write User Journeys

```
As a [role], I want to [action], so that [benefit]

Example:
As a user, I want to search for markets semantically,
so that I can find relevant markets even without exact keywords.
```

### Step 2: Generate Test Cases

For each user journey, create comprehensive test cases:

```kotlin
@Nested
inner class SemanticSearch {

    @Test
    fun `returns relevant markets for query`() {
        // Test implementation
    }

    @Test
    fun `handles empty query gracefully`() {
        // Test edge case
    }

    @Test
    fun `falls back to substring search when Redis unavailable`() {
        // Test fallback behavior
    }

    @Test
    fun `sorts results by similarity score`() {
        // Test sorting logic
    }
}
```

### Step 3: Run Tests (They Should Fail)

```bash
./gradlew test
# Tests should fail - we haven't implemented yet
```

### Step 4: Implement Code

Write minimal code to make tests pass:

```kotlin
// Implementation guided by tests
suspend fun searchMarkets(query: String): List<Market> {
    // Implementation here
}
```

### Step 5: Run Tests Again

```bash
./gradlew test
# Tests should now pass
```

### Step 6: Refactor

Improve code quality while keeping tests green:

- Remove duplication
- Improve naming
- Optimize performance
- Enhance readability

### Step 7: Verify Coverage

```bash
./gradlew test jacocoTestReport
# Verify 80%+ coverage achieved
```

## Testing Patterns

### Unit Test Pattern (JUnit 5 + MockK)

```kotlin
import io.mockk.coEvery
import io.mockk.mockk
import io.mockk.verify
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test

class MarketServiceTest {

    private val marketRepository = mockk<MarketRepository>()
    private val embeddingService = mockk<EmbeddingService>()
    private val marketService = MarketService(marketRepository, embeddingService)

    @Test
    fun `returns markets matching the query`() {
        // Arrange
        val expectedMarkets = listOf(
            Market(id = "1", name = "Test Market", status = MarketStatus.ACTIVE)
        )
        coEvery { marketRepository.findByStatus(MarketStatus.ACTIVE) } returns expectedMarkets

        // Act
        val result = marketService.findActiveMarkets()

        // Assert
        assertThat(result).hasSize(1)
        assertThat(result[0].name).isEqualTo("Test Market")
    }

    @Test
    fun `throws exception when repository fails`() {
        // Arrange
        coEvery { marketRepository.findByStatus(any()) } throws RuntimeException("DB error")

        // Act & Assert
        assertThatThrownBy { marketService.findActiveMarkets() }
            .isInstanceOf(ServiceException::class.java)
            .hasMessageContaining("Failed to fetch markets")
    }
}
```

### Unit Test Pattern (JUnit 5 + Mockito for Java)

```java
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MarketServiceTest {

    @Mock
    private MarketRepository marketRepository;

    @InjectMocks
    private MarketService marketService;

    @Test
    void returnsMarketsMatchingQuery() {
        // Arrange
        var expected = List.of(new Market("1", "Test Market", MarketStatus.ACTIVE));
        when(marketRepository.findByStatus(MarketStatus.ACTIVE)).thenReturn(expected);

        // Act
        var result = marketService.findActiveMarkets();

        // Assert
        assertThat(result).hasSize(1);
        assertThat(result.get(0).getName()).isEqualTo("Test Market");
    }
}
```

### API Integration Test Pattern (Spring MVC Test)

```kotlin
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post

@SpringBootTest
@AutoConfigureMockMvc
class MarketControllerTest(
    private val mockMvc: MockMvc
) {

    @Test
    fun `GET markets returns list successfully`() {
        mockMvc.get("/api/markets")
            .andExpect {
                status { isOk() }
                jsonPath("$.success") { value(true) }
                jsonPath("$.data") { isArray() }
            }
    }

    @Test
    fun `GET markets validates query parameters`() {
        mockMvc.get("/api/markets?limit=invalid")
            .andExpect {
                status { isBadRequest() }
            }
    }

    @Test
    fun `POST markets creates resource with valid data`() {
        mockMvc.post("/api/markets") {
            contentType = MediaType.APPLICATION_JSON
            content = """
                {
                    "name": "Test Market",
                    "description": "A test market",
                    "endDate": "2025-12-31T00:00:00Z",
                    "categories": ["politics"]
                }
            """.trimIndent()
        }.andExpect {
            status { isCreated() }
            jsonPath("$.data.name") { value("Test Market") }
        }
    }
}
```

### Database Integration Test with Testcontainers

```kotlin
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers

@SpringBootTest
@Testcontainers
class MarketRepositoryIntegrationTest(
    private val marketRepository: MarketRepository
) {

    companion object {
        @Container
        val postgres = PostgreSQLContainer("postgres:16-alpine")

        @JvmStatic
        @DynamicPropertySource
        fun configureProperties(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
        }
    }

    @Test
    fun `saves and retrieves market by status`() {
        // Arrange
        val market = Market(name = "Test Market", status = MarketStatus.ACTIVE)
        marketRepository.save(market)

        // Act
        val found = marketRepository.findByStatus(MarketStatus.ACTIVE)

        // Assert
        assertThat(found).hasSize(1)
        assertThat(found[0].name).isEqualTo("Test Market")
    }

    @Test
    fun `returns empty list when no markets match status`() {
        val found = marketRepository.findByStatus(MarketStatus.CLOSED)
        assertThat(found).isEmpty()
    }
}
```

### E2E Test Pattern (Testcontainers + RestAssured)

```kotlin
import io.restassured.RestAssured
import io.restassured.module.kotlin.extensions.Given
import io.restassured.module.kotlin.extensions.Then
import io.restassured.module.kotlin.extensions.When
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.web.server.LocalServerPort

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class MarketE2ETest {

    @LocalServerPort
    private var port: Int = 0

    @BeforeEach
    fun setUp() {
        RestAssured.port = port
    }

    @Test
    fun `user can create and search for markets`() {
        // Create a market
        Given {
            contentType(ContentType.JSON)
            body("""
                {
                    "name": "Election Market",
                    "description": "Will candidate X win?",
                    "endDate": "2025-12-31T00:00:00Z",
                    "categories": ["politics"]
                }
            """.trimIndent())
        } When {
            post("/api/markets")
        } Then {
            statusCode(201)
            body("data.name", equalTo("Election Market"))
        }

        // Search for the market
        Given {
            param("q", "election")
        } When {
            get("/api/markets/search")
        } Then {
            statusCode(200)
            body("data.size()", greaterThan(0))
            body("data[0].name", containsStringIgnoringCase("election"))
        }
    }
}
```

## Test File Organization

```
src/
├── main/
│   └── kotlin/com/example/app/
│       ├── market/
│       │   ├── MarketController.kt
│       │   ├── MarketService.kt
│       │   ├── MarketRepository.kt
│       │   └── Market.kt
│       └── auth/
└── test/
    └── kotlin/com/example/app/
        ├── market/
        │   ├── MarketServiceTest.kt           # Unit tests (MockK)
        │   ├── MarketControllerTest.kt        # MVC integration tests
        │   └── MarketRepositoryTest.kt        # DB integration tests
        ├── integration/
        │   └── MarketE2ETest.kt               # E2E tests (Testcontainers)
        └── support/
            ├── TestContainersConfig.kt         # Shared container config
            └── TestFixtures.kt                 # Test data builders
```

## Mocking External Services

### MockK (Kotlin)

```kotlin
// Mocking a repository
private val marketRepository = mockk<MarketRepository>()

every { marketRepository.findById("test-id") } returns Optional.of(testMarket)
coEvery { marketRepository.findByStatus(any()) } returns listOf(testMarket)

// Verifying interactions
verify(exactly = 1) { marketRepository.save(any()) }
coVerify { embeddingService.generateEmbedding("election") }
```

### Mockito (Java)

```java
// Mocking a repository
@Mock
private MarketRepository marketRepository;

when(marketRepository.findById("test-id")).thenReturn(Optional.of(testMarket));
when(marketRepository.findByStatus(any())).thenReturn(List.of(testMarket));

// Verifying interactions
verify(marketRepository, times(1)).save(any());
verify(embeddingService).generateEmbedding("election");
```

### WireMock for External APIs

```kotlin
@WireMockTest(httpPort = 8089)
class ExternalApiServiceTest {

    @Test
    fun `handles external API failure gracefully`() {
        stubFor(
            get(urlEqualTo("/api/external/data"))
                .willReturn(aResponse().withStatus(503))
        )

        assertThatThrownBy { externalApiService.fetchData() }
            .isInstanceOf(ServiceUnavailableException::class.java)
    }

    @Test
    fun `parses external API response correctly`() {
        stubFor(
            get(urlEqualTo("/api/external/data"))
                .willReturn(
                    aResponse()
                        .withStatus(200)
                        .withHeader("Content-Type", "application/json")
                        .withBody("""{"result": "success", "value": 42}""")
                )
        )

        val result = externalApiService.fetchData()
        assertThat(result.value).isEqualTo(42)
    }
}
```

## Test Coverage Verification

### Run Coverage Report

```bash
./gradlew test jacocoTestReport
# Report generated at build/reports/jacoco/test/html/index.html
```

### Coverage Thresholds (build.gradle.kts)

```kotlin
tasks.jacocoTestCoverageVerification {
    violationRules {
        rule {
            limit {
                counter = "LINE"
                minimum = "0.80".toBigDecimal()
            }
            limit {
                counter = "BRANCH"
                minimum = "0.80".toBigDecimal()
            }
        }
    }
}

tasks.check {
    dependsOn(tasks.jacocoTestCoverageVerification)
}
```

## Common Testing Mistakes to Avoid

### WRONG: Testing Implementation Details

```kotlin
// Don't test internal state
assertThat(service.internalCache.size).isEqualTo(5)
```

### CORRECT: Test Observable Behavior

```kotlin
// Test what callers observe
val result = service.findAll()
assertThat(result).hasSize(5)
```

### WRONG: Brittle Test Setup

```kotlin
// Breaks easily with any schema change
val market = Market("id-1", "name", "desc", MarketStatus.ACTIVE, Instant.now(), Instant.now(), null, null, 0L)
```

### CORRECT: Test Data Builders

```kotlin
// Resilient to changes
fun testMarket(
    id: String = "test-id",
    name: String = "Test Market",
    status: MarketStatus = MarketStatus.ACTIVE
) = Market(id = id, name = name, status = status)

val market = testMarket(name = "Custom Name")
```

### WRONG: No Test Isolation

```kotlin
// Tests depend on each other
@Test fun `creates user`() { /* ... */ }
@Test fun `updates same user`() { /* depends on previous test */ }
```

### CORRECT: Independent Tests

```kotlin
// Each test sets up its own data
@Test
fun `creates user`() {
    val user = testUser()
    // Test logic
}

@Test
fun `updates user`() {
    val user = testUser()
    userRepository.save(user)
    // Update logic
}
```

## Continuous Testing

### Watch Mode During Development

```bash
./gradlew test --continuous
# Tests run automatically on file changes
```

### Pre-Commit Hook

```bash
# Runs before every commit
./gradlew test && ./gradlew detekt
```

### CI/CD Integration

```yaml
# GitHub Actions
- name: Run Tests
  run: ./gradlew test jacocoTestReport
- name: Verify Coverage
  run: ./gradlew jacocoTestCoverageVerification
- name: Upload Coverage
  uses: codecov/codecov-action@v4
  with:
    files: build/reports/jacoco/test/jacocoTestReport.xml
```

## Best Practices

1. **Write Tests First** - Always TDD
2. **One Assert Per Test** - Focus on single behavior
3. **Descriptive Test Names** - Use backtick names in Kotlin for readability
4. **Arrange-Act-Assert** - Clear test structure
5. **Mock External Dependencies** - Use MockK (Kotlin) or Mockito (Java)
6. **Test Edge Cases** - Null, empty, boundary values
7. **Test Error Paths** - Not just happy paths
8. **Keep Tests Fast** - Unit tests < 50ms each
9. **Use Testcontainers** - Real databases for integration tests
10. **Review Coverage Reports** - Identify gaps with JaCoCo

## Success Metrics

- 80%+ code coverage achieved (JaCoCo)
- All tests passing (green)
- No skipped or disabled tests
- Fast test execution (< 30s for unit tests)
- Integration tests use Testcontainers for real database verification
- Tests catch bugs before production

---

**Remember**: Tests are not optional. They are the safety net that enables confident refactoring, rapid development, and production
reliability.

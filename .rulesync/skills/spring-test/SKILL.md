---
name: spring-test
description: "Spring Boot Test: foundational concepts — test slices, TestContainers, MockMvc, test configuration"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Boot Test

This skill provides foundational concepts. For implementation examples, use `spring-test-kotlin` or `spring-test-java` skill.

Comprehensive guide for testing Spring Boot applications: test slices, MockMvc, TestContainers, MockBean, and best practices.

## @SpringBootTest — Full Context Tests

Loads the complete application context. Use `webEnvironment = RANDOM_PORT` for integration tests with real HTTP.

## Test Slices

| Slice             | Loads                            | Use For                   |
|-------------------|----------------------------------|---------------------------|
| `@WebMvcTest`     | Controllers, filters, converters | Controller layer tests    |
| `@DataJpaTest`    | JPA repositories, EntityManager  | Repository layer tests    |
| `@DataR2dbcTest`  | R2DBC repositories               | Reactive repository tests |
| `@RestClientTest` | RestTemplate/WebClient           | HTTP client tests         |
| `@WebFluxTest`    | WebFlux controllers              | Reactive controller tests |

## @MockBean and @SpyBean

- `@MockBean` replaces a bean in the application context with a mock
- `@SpyBean` wraps the real bean with a spy
- For Kotlin, use `@MockkBean` / `@SpykBean` from `com.ninja-squad:springmockk`
- For Java, use standard `@MockBean` / `@SpyBean` from Spring (Mockito-based)

## TestContainers

Use TestContainers for integration tests with real infrastructure (databases, message brokers, caches). Configure with
`@DynamicPropertySource` to inject container-provided connection properties.

### Reusable TestContainer Base Class

Create an abstract base class with shared containers started in a `companion object` / `static` block. Containers are shared across all test
classes for performance.

## Test Configuration

### @TestConfiguration

Create test-specific beans (e.g., disabled security, mock services) using `@TestConfiguration` and `@Import`.

### Test Properties

Use `@TestPropertySource` for inline properties or `application-test.yml` with `@ActiveProfiles("test")`.

```yaml
# src/test/resources/application-test.yml
spring:
  datasource:
    url: jdbc:h2:mem:testdb
  jpa:
    hibernate:
      ddl-auto: create-drop

app:
  payment:
    gateway-url: http://localhost:8089
```

## @Sql for Database Setup

Use `@Sql` to run SQL scripts before/after test methods for data seeding and cleanup.

## Parallel Test Execution

```
# junit-platform.properties (src/test/resources)
junit.jupiter.execution.parallel.enabled=true
junit.jupiter.execution.parallel.mode.default=concurrent
junit.jupiter.execution.parallel.mode.classes.default=concurrent
junit.jupiter.execution.parallel.config.strategy=fixed
junit.jupiter.execution.parallel.config.fixed.parallelism=4
```

Ensure tests are independent:

- Use unique data per test
- Clean up in @BeforeEach
- Avoid shared mutable state

## JaCoCo Coverage

Configure JaCoCo in `build.gradle.kts` for coverage reports and verification (80% minimum).

## Dependencies Summary

### Kotlin

```kotlin
// build.gradle.kts
testImplementation("org.springframework.boot:spring-boot-starter-test") {
    exclude(module = "mockito-core")
}
testImplementation("io.mockk:mockk:1.13.13")
testImplementation("com.ninja-squad:springmockk:4.0.2")
testImplementation("org.testcontainers:testcontainers")
testImplementation("org.testcontainers:junit-jupiter")
testImplementation("org.testcontainers:postgresql")
testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test")
```

### Java

```kotlin
testImplementation("org.springframework.boot:spring-boot-starter-test")
testImplementation("org.testcontainers:testcontainers")
testImplementation("org.testcontainers:junit-jupiter")
testImplementation("org.testcontainers:postgresql")
```

## Best Practices

1. **Use test slices** (@WebMvcTest, @DataJpaTest) over @SpringBootTest when possible
2. **Use TestContainers** for integration tests with real databases
3. **Share containers** across test classes for performance
4. **Use @DynamicPropertySource** for container-provided properties
5. **Use MockK** for Kotlin, Mockito for Java
6. **Test negative cases** — validation errors, not found, unauthorized
7. **Aim for 80%+ coverage** but focus on meaningful tests, not line count
8. **Clean up test data** in @BeforeEach, not @AfterEach (resilient to failures)
9. **Use test profiles** to isolate test configuration
10. **Parallel execution** — ensure test independence for speed
11. **Name tests descriptively** — use backtick syntax in Kotlin
12. **Test at the right level** — unit for logic, integration for wiring, E2E for flows

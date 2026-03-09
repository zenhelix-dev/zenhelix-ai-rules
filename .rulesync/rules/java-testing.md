---
root: false
targets: ["claudecode"]
description: "Java testing: JUnit 5, Mockito, AssertJ, Spring Boot test slices, Testcontainers, and coverage"
globs: ["*.java"]
---

# Java Testing

> Detailed examples: use skills `springboot-tdd`, `tdd-workflow`

## Framework Stack

- **JUnit 5** — test framework
- **Mockito** — mocking
- **AssertJ** — fluent assertions
- **MockMvc** — controller testing
- **Testcontainers** — integration testing with real databases
- **JaCoCo** — coverage (80%+ required)

## Test Naming

- Pattern: `methodName_scenario_expectedResult`
- Use `@Nested` classes for logical grouping

## Mockito

- Use `@ExtendWith(MockitoExtension.class)`, `@Mock`, `@InjectMocks`
- Use `argThat()` and `ArgumentCaptor` for complex verifications
- Structure tests: given/when/then

## Spring Boot Test Slices

- Prefer sliced tests over `@SpringBootTest`:
    - `@WebMvcTest` — controller layer (MockMvc + MockBean)
    - `@DataJpaTest` — repository layer (TestEntityManager)
    - `@SpringBootTest` + `@Testcontainers` — full integration tests

## Testcontainers

- Use `@Container` with `@DynamicPropertySource` for database integration tests
- Prefer PostgreSQL/MySQL containers matching production database

## Test Data

- Create `TestData` class with static factory methods
- Use builder pattern or records for test data variations

## Coverage

- JaCoCo 80%+ minimum enforced via build plugin
- Run: `mvn verify` or `./gradlew test jacocoTestReport`

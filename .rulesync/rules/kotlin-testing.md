---
root: false
targets: ["claudecode"]
description: "Kotlin testing: JUnit 5, MockK, coroutine testing, and coverage requirements"
globs: ["*.kt", "*.kts"]
---

# Kotlin Testing

> Detailed examples: use skills `tdd-workflow`, `springboot-tdd`

## Framework Stack

- **JUnit 5** — test framework
- **MockK** — mocking (not Mockito)
- **AssertJ** or **kotlin.test** — assertions
- **Kotest** — property-based testing (optional)
- **JaCoCo** — coverage (80%+ required)

## Test Naming

- Use backtick syntax: `` fun `should create user when email is valid`() ``
- Use `@Nested inner class` for logical grouping

## MockK

- Use `mockk<T>()`, `every { }`, `verify { }` for regular functions
- Use `coEvery { }`, `coVerify { }` for suspend functions
- Use `slot<T>()` and `capture()` for argument capturing
- Use `relaxed = true` for mocks that don't need strict setup

## Coroutine Testing

- Use `runTest { }` from `kotlinx-coroutines-test`
- Use `StandardTestDispatcher(testScheduler)` for controlled execution

## Test Data

- Use `TestData` object with default instances
- Use `copy()` on data classes for test variations

## Assertions

- Prefer AssertJ fluent assertions
- Use `assertThatThrownBy { }` for exception testing
- Use `filteredOn`, `extracting`, `allSatisfy` for collection assertions

## Parameterized Tests

- Use `@CsvSource` for simple value pairs
- Use `@MethodSource` with `companion object` `@JvmStatic` factory for complex cases

## Coverage

- JaCoCo 80%+ minimum enforced in `build.gradle.kts`
- Run: `./gradlew test jacocoTestReport jacocoTestCoverageVerification`

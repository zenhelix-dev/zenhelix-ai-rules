---
name: tdd-workflow
description: "TDD workflow: Red-Green-Refactor cycle, test structure, coverage enforcement, Spring test patterns, edge cases and anti-patterns"
targets: ["claudecode"]
claudecode:
  model: opus
---

# TDD Workflow

> This skill provides foundational concepts. For implementation examples, use `tdd-workflow-kotlin` or `tdd-workflow-java` skill.

## The TDD Cycle

### RED: Write a Failing Test

Write the test FIRST, before any implementation.

Run the test — it MUST fail. If it passes, the test is wrong or unnecessary.

### GREEN: Minimal Implementation

Write the absolute minimum code to make the test pass.

Run the test — it MUST pass now.

### REFACTOR: Improve Without Changing Behavior

Clean up both test and production code:

- Extract common setup to fixtures
- Remove duplication
- Improve naming
- Run tests again — they MUST still pass

## Test Naming Conventions

Pattern: `should <expected behavior> when <condition>`

## Test Structure: Arrange-Act-Assert

Keep each section clearly separated. One Act per test.

- **Arrange (Given)** — set up the test data and dependencies
- **Act (When)** — execute the behavior under test
- **Assert (Then)** — verify the expected outcome

## Coverage Enforcement with JaCoCo

Configure JaCoCo in `build.gradle.kts` to enforce minimum 80% coverage, with exclusions for config classes and Application entry points.

## Spring Test Patterns

- **Slice tests**: `@WebMvcTest`, `@DataJpaTest`, `@WebFluxTest` — test a single layer with minimal context
- **Full integration**: `@SpringBootTest(webEnvironment = RANDOM_PORT)` — full context tests

## Edge Cases to Always Test

- Null/missing values
- Empty collections and strings
- Boundary values (0, -1, MAX_VALUE, empty page)
- Error/exception paths
- Concurrent access (where applicable)
- Invalid input formats
- Duplicate entries
- Unauthorized access attempts

## Anti-Patterns to Avoid

- Testing implementation details instead of behavior
- Shared mutable state between tests
- Brittle assertions (exact timestamp matching, unstable ordering)
- Testing framework code (Spring, Hibernate internals)
- Excessive mocking (more than 3-4 mocks per test suggests design issue)
- Tests that pass in isolation but fail together (ordering dependency)
- Ignoring flaky tests instead of fixing root cause

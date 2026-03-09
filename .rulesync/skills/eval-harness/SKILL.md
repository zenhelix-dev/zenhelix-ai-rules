---
name: eval-harness
description: "Full Eval-Driven Development (EDD) framework — define evals before implementation, track regressions, measure pass@k metrics"
targets: ["claudecode"]
claudecode:
  model: opus
---

# Eval-Driven Development (EDD) Framework

## Philosophy

Evals are unit tests for AI-assisted development. Just as TDD requires writing tests before code, EDD requires defining evaluation criteria
before implementation.

Core principles:

- **Define before implement** — write eval criteria before asking Claude to generate code
- **Track regressions** — every change must not break previously passing evals
- **Measure objectively** — use pass@k metrics to quantify capability
- **Iterate on evidence** — use eval results to refine prompts, rules, and skills

## Eval Types

### Capability Evals

Verify that Claude can perform a specific task correctly.

- "Can Claude generate a working Spring REST controller with validation?"
- "Can Claude write a Flyway migration that adds a column with a default value?"
- "Can Claude create a Kotlin coroutine-based service with proper error handling?"

### Regression Evals

Verify that changes to rules/skills/prompts don't break existing capabilities.

- "Does the auth module still compile after refactoring the security rule?"
- "Do existing test generation patterns still produce valid JUnit 5 tests?"

### Performance Evals

Measure latency, cost, and token usage.

- "How many tokens does it take to generate a CRUD repository?"
- "Does the new skill reduce average implementation time?"

### Security Evals

Verify OWASP compliance and security best practices.

- "Does generated code use parameterized queries?"
- "Are user inputs validated at controller boundaries?"
- "Does generated auth code follow Spring Security best practices?"

## Grader Types

### 1. Code-Based (Deterministic)

The most reliable grader. Uses build tools and test runners:

```bash
# Compilation check
./gradlew compileKotlin && echo "PASS" || echo "FAIL"

# Test execution
./gradlew test --tests "com.example.UserServiceTest" && echo "PASS" || echo "FAIL"

# Static analysis
./gradlew detekt && echo "PASS" || echo "FAIL"
```

### 2. Rule-Based (Regex/Schema)

Pattern matching and structural validation:

```bash
# Check that generated code contains required annotations
grep -q "@RestController" src/main/kotlin/controller/UserController.kt && echo "PASS" || echo "FAIL"

# Validate JSON schema
ajv validate -s schema.json -d output.json && echo "PASS" || echo "FAIL"

# Check SQL migration naming
[[ "$MIGRATION_FILE" =~ ^V[0-9]+__[a-z_]+\.sql$ ]] && echo "PASS" || echo "FAIL"
```

### 3. Model-Based (LLM-as-Judge)

Use a rubric for subjective quality assessment:

```markdown
## Rubric: Code Quality Assessment
Rate the generated code on a scale of 1-5 for each criterion:
- [ ] Follows Kotlin idioms (data classes, sealed classes, extension functions)
- [ ] Proper error handling (no swallowed exceptions, meaningful messages)
- [ ] Immutability (val over var, immutable collections)
- [ ] Naming clarity (descriptive, consistent with domain)
- [ ] Single responsibility (functions < 50 lines, classes < 400 lines)

PASS threshold: average >= 4.0
```

### 4. Human (Manual Review Flag)

For cases requiring human judgment:

```markdown
## Manual Review Required
- [ ] Architecture decision aligns with team conventions
- [ ] API design is consistent with existing endpoints
- [ ] Migration is safe for zero-downtime deployment
```

## pass@k Metrics

### pass@1 (First Try)

The generated output passes on the first attempt. Target: >70% for standard tasks.

### pass@3 (Within 3 Tries)

At least one of 3 attempts passes. Target: >90% for all capability evals.

### pass^3 (All 3 Must Pass)

All 3 attempts must pass. Used for critical paths where consistency matters. Target: 100% for regression evals.

### Measurement Protocol

```bash
# Run eval N times, collect results
PASS_COUNT=0
FIRST_RESULT="FAIL"
TOTAL=3
for i in $(seq 1 $TOTAL); do
  # Replace eval_passes with actual evaluation command (e.g., ./gradlew test)
  if eval_passes; then
    PASS_COUNT=$((PASS_COUNT + 1))
    [[ $i -eq 1 ]] && FIRST_RESULT="PASS"
  fi
done

# Calculate metrics
echo "pass@1: $([ $FIRST_RESULT = PASS ] && echo YES || echo NO)"
echo "pass@3: $([ $PASS_COUNT -ge 1 ] && echo YES || echo NO)"
echo "pass^3: $([ $PASS_COUNT -eq $TOTAL ] && echo YES || echo NO)"
```

## Eval Workflow

### 1. Define

Write eval criteria before implementation:

```markdown
## EVAL: user-crud-api
### Capability Evals
- [ ] Generates UserController with GET/POST/PUT/DELETE endpoints
- [ ] Includes input validation annotations (@Valid, @NotBlank)
- [ ] Returns proper HTTP status codes (200, 201, 204, 404)
- [ ] Uses ResponseEntity wrapper consistently

### Regression Evals
- [ ] Existing AuthController still compiles
- [ ] OpenAPI spec generation still works
- [ ] Integration tests for /api/health still pass

### Success Metrics
- pass@3 > 90% for capability evals
- pass^3 = 100% for regression evals
```

### 2. Implement

Proceed with implementation, using the eval criteria as acceptance criteria.

### 3. Evaluate

Run all evals against the implementation:

```bash
# Capability evals
./gradlew compileKotlin                          # Code compiles
./gradlew test --tests "*UserControllerTest*"     # Tests pass
grep -q "@Valid" UserController.kt                # Validation present

# Regression evals
./gradlew test --tests "*AuthControllerTest*"     # Auth still works
./gradlew test --tests "*HealthCheckTest*"        # Health check intact
```

### 4. Report

Summarize results:

```markdown
## Eval Report: user-crud-api
Date: 2026-03-09
### Results
| Eval | pass@1 | pass@3 | pass^3 |
|------|--------|--------|--------|
| Compilation | PASS | PASS | PASS |
| Validation annotations | PASS | PASS | PASS |
| HTTP status codes | FAIL | PASS | FAIL |
| Regression: AuthController | PASS | PASS | PASS |

### Action Items
- HTTP status codes inconsistent on first try — add explicit example to spring-web skill
```

## JVM Eval Templates

### Kotlin Code Generation Eval

```markdown
## EVAL: kotlin-code-gen
- [ ] Output compiles with `./gradlew compileKotlin`
- [ ] Uses `val` over `var` (grep -c "var " < grep -c "val ")
- [ ] Data classes for DTOs (grep "@JsonProperty\|data class")
- [ ] No Java-style getters/setters
- [ ] Follows project package conventions
```

### Spring REST Endpoint Eval

```markdown
## EVAL: spring-rest-endpoint
- [ ] Controller annotated with @RestController
- [ ] Request mapping follows RESTful conventions
- [ ] Input validation with @Valid on @RequestBody
- [ ] Proper exception handling (ControllerAdvice or per-endpoint)
- [ ] OpenAPI annotations present (@Operation, @ApiResponse)
- [ ] Integration test exists and passes
```

### SQL Migration Safety Eval

```markdown
## EVAL: sql-migration-safety
- [ ] Migration file follows naming convention (V{version}__{description}.sql)
- [ ] No DROP TABLE without explicit confirmation
- [ ] ALTER TABLE ADD COLUMN has DEFAULT or is nullable
- [ ] No full table locks (CHECK for ALTER TYPE, ADD CONSTRAINT NOT VALID)
- [ ] Rollback migration exists (for Flyway: matching U{version} file)
- [ ] Dry-run against test database passes
```

### Test Generation Eval

```markdown
## EVAL: test-generation
- [ ] Test class compiles
- [ ] All tests pass on first run
- [ ] Uses JUnit 5 annotations (@Test, @BeforeEach, @Nested)
- [ ] Mocking framework matches project (MockK for Kotlin, Mockito for Java)
- [ ] Covers happy path and at least one error case
- [ ] Assertions are specific (not just assertNotNull)
```

### Build Compilation Eval

```markdown
## EVAL: build-compilation
- [ ] `./gradlew compileKotlin` exits 0
- [ ] `./gradlew compileJava` exits 0 (if Java sources exist)
- [ ] `./gradlew test` exits 0
- [ ] No new compiler warnings introduced
- [ ] `./gradlew detekt` passes (if configured)
```

## Eval Storage

Evals are stored in `.claude/evals/` directory:

```
.claude/evals/
├── user-crud-api.md
├── auth-module.md
├── migration-safety.md
└── reports/
    ├── 2026-03-09-user-crud-api.md
    └── 2026-03-09-auth-module.md
```

## Anti-Patterns

### Overfitting to Eval Examples

Problem: Tuning prompts/rules to pass specific eval cases rather than general capability.
Fix: Use diverse eval inputs. Rotate examples periodically.

### Happy-Path Only

Problem: All evals test the success case, none test error handling or edge cases.
Fix: Include at least one error-case eval for every capability eval.

### Ignoring Cost Drift

Problem: Improving pass@k without monitoring token usage — capability improves but cost doubles.
Fix: Track tokens-per-eval alongside pass rates.

### Flaky Graders

Problem: Eval results vary between runs without code changes (non-deterministic graders).
Fix: Use code-based graders where possible. For model-based graders, use pass@3 and require consistency.

### Eval Rot

Problem: Evals become outdated as the project evolves.
Fix: Review and update evals quarterly. Archive evals for deprecated features.

## Integration with /eval Command

This skill provides the framework; the `/eval` command executes it:

1. `/eval define feature-name` — create eval file from template
2. `/eval run feature-name` — execute all evals for a feature
3. `/eval report` — generate summary of all eval results
4. `/eval regression` — run all regression evals across the project

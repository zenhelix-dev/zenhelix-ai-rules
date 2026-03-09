---
description: "Start an autonomous development loop with periodic checkpoints and quality gates"
targets: ["claudecode"]
---

# Loop Start Command

## Purpose

Initiate an autonomous coding loop that executes phases of a development plan
with periodic checkpoints and quality gates. Designed for multi-phase implementation
where each phase is validated before proceeding to the next.

## Usage

`/loop-start [--plan=<path>] [--phases=<range>] [--mode=safe|fast]`

- `--plan=<path>` — Path to a plan file (typically output from `/plan` command).
  If omitted, reads the current TodoWrite list as the plan.
- `--phases=<range>` — Which phases to execute: `1-3`, `2`, `all` (default: `all`)
- `--mode=safe|fast` — Execution mode:
    - `safe` (default) — Strict quality gates, full test suite, checkpoint every phase
    - `fast` — Reduced checks: lint + compile only, checkpoint every 2 phases

## Workflow

### 1. Load Plan

- Read plan from `--plan` file or current TodoWrite state
- Parse phases, identify dependencies between them
- Validate that all phases have clear acceptance criteria
- If plan is ambiguous or missing acceptance criteria, STOP and ask the user

### 2. Confirm Repo State

Before starting the loop, verify:

- Working tree is clean (`git status` shows no uncommitted changes)
- On the correct feature branch (not `main` or `master`)
- Tests pass (`./gradlew test` or equivalent)
- Build succeeds (`./gradlew build` or equivalent)

If any check fails, report the issue and STOP. Do not attempt to fix repo state automatically.

### 3. Execute Phases

For each phase in the requested range:

1. **Checkpoint**: Create a named checkpoint via `/checkpoint create phase-N-start`
2. **Implement**: Execute the phase using TDD workflow:
    - Write tests first (RED)
    - Implement to pass tests (GREEN)
    - Refactor (IMPROVE)
3. **Quality Gate**: Run `/quality-gate` after completion:
    - `safe` mode: full test suite, lint, format, compile
    - `fast` mode: compile + lint only
4. **On Success**:
    - Create checkpoint: `/checkpoint create phase-N-complete`
    - Mark phase as done in TodoWrite
    - Summarize completed work
    - Proceed to next phase
5. **On Failure**:
    - Log the failure with details (test name, error message, file:line)
    - Increment consecutive failure counter
    - Attempt to fix if the error is clear and localized
    - Re-run quality gate after fix attempt

### 4. Stop Conditions

The loop MUST stop when any of these occur:

- **Quality gate failure**: 3 consecutive failures without progress
- **Plan complete**: All requested phases successfully executed
- **User interrupt**: User sends any message during execution
- **Build broken**: Build fails and cannot be fixed within 2 attempts
- **Merge conflict**: Detected during any git operation

### 5. On Terminal Failure

When the loop stops due to failure:

1. Restore the last successful checkpoint
2. Report what failed:
    - Which phase and step
    - Error details
    - Files involved
3. Suggest a fix or ask for guidance
4. Leave the repo in a clean, buildable state

## Safety

- ALWAYS create a checkpoint before starting each phase
- NEVER skip quality gates in `safe` mode
- NEVER force-push or rewrite history
- NEVER perform destructive git operations without user confirmation
- Stop after 3 consecutive failures — do not retry indefinitely
- Branch/worktree isolation is recommended for long-running loops
- Prefer reversible actions: checkpoint before risky changes

## Agent

Invokes the `loop-operator` subagent to execute the autonomous loop.
The subagent handles phase execution, checkpoint management, and failure detection.

## Integration

- `/checkpoint` — Creates and restores save points
- `/quality-gate` — Validates phase completion
- `tdd-guide` subagent — Drives the TDD workflow within each phase
- `/plan` — Generates the plan that this command executes

## Output Format

### During Execution

```
## Loop Progress

| Phase | Status | Duration | Tests | Checkpoint |
|-------|--------|----------|-------|------------|
| 1. Setup entities | DONE | 3m | 12/12 | phase-1-complete |
| 2. Add repositories | IN PROGRESS | — | — | phase-2-start |
| 3. Wire services | PENDING | — | — | — |
```

### On Completion

```
## Loop Complete

- Phases executed: 3/3
- Total duration: 12m
- Tests: 47 passing, 0 failing
- Checkpoints: 6 (3 start + 3 complete)
- Quality gates: 3 passed, 0 failed

All phases completed successfully. Run `/verify` for final validation.
```

### On Failure

```
## Loop Stopped: Quality Gate Failure

- Completed phases: 1/3
- Failed at: Phase 2, step "implement"
- Error: `OrderRepositoryTest.shouldFindByStatus` — expected 3 results, got 0
- File: `src/test/kotlin/com/example/OrderRepositoryTest.kt:45`
- Restored checkpoint: phase-1-complete

Suggested fix: The query method `findByStatus` is not implemented in `OrderRepository`.
Add the query method or a `@Query` annotation.
```

## Rules

- NEVER start a loop on `main` or `master` branch
- ALWAYS confirm repo state before starting
- ALWAYS use TDD workflow within each phase
- Keep phase summaries concise — focus on what changed and test results
- If a phase has no clear acceptance criteria, ask the user before executing

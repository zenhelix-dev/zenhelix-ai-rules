---
description: "Audit AI agent harness configuration and report coverage gaps with a prioritized scorecard"
targets: ["claudecode"]
---

# Harness Audit Command

## Purpose

Analyze the current project's AI harness setup (hooks, skills, commands, subagents, evals)
and produce a coverage scorecard. Identifies gaps, redundancies, and improvement opportunities
across all harness components.

## Usage

`/harness-audit [scope]`

- `all` (default) — audit every category
- `hooks` — audit hook lifecycle coverage only
- `skills` — audit skill completeness and eval pairing
- `commands` — audit command coverage and consistency
- `agents` — audit subagent definitions and model routing
- `evals` — audit eval definitions, pass rates, regression tracking

## Scoring Categories

Each category is scored 0-10. Total possible: 70.

| # | Category            | What It Measures                                                          |
|---|---------------------|---------------------------------------------------------------------------|
| 1 | Tool Coverage       | Hooks, skills, commands completeness relative to project stack            |
| 2 | Context Efficiency  | Compaction strategy, memory usage, context window management              |
| 3 | Quality Gates       | Lint, format, test automation via hooks and commands                      |
| 4 | Memory Persistence  | Session state, instincts, learned patterns in CLAUDE.md / memory          |
| 5 | Eval Coverage       | Eval definitions, pass rates, regression tracking                         |
| 6 | Security Guardrails | Secret scanning, input validation, dependency checks                      |
| 7 | Cost Efficiency     | Model routing (opus/sonnet/haiku), context management, token optimization |

### Scoring Rubric

- **0-2**: Missing or non-functional
- **3-4**: Minimal coverage, significant gaps
- **5-6**: Adequate coverage, known gaps
- **7-8**: Good coverage, minor improvements possible
- **9-10**: Comprehensive, well-maintained, no obvious gaps

## Workflow

1. **Scan `.rulesync/`** for hooks, skills, commands, subagents:
    - Count and categorize each component
    - Check for frontmatter validity (required fields present)
    - Identify orphaned or duplicate definitions
2. **Scan `.claude/evals/`** for eval definitions:
    - Count eval files, check format validity
    - Map evals to skills and commands they cover
    - Identify skills/commands without eval coverage
3. **Check `hooks.json`** for lifecycle coverage:
    - Verify `preToolUse`, `postToolUse`, `stop` hooks exist
    - Check hook scripts are executable and exit 0
    - Identify missing lifecycle stages
4. **Cross-reference skills with eval coverage**:
    - List skills that have no corresponding eval
    - List evals that reference non-existent skills
    - Calculate coverage percentage
5. **Score each category** using the rubric above
6. **Generate report** with overall score, breakdown, and recommendations

## Output Format

```
## Harness Audit Report

### Overall Score: XX / 70

| Category | Score | Key Finding |
|----------|-------|-------------|
| Tool Coverage | X/10 | ... |
| Context Efficiency | X/10 | ... |
| Quality Gates | X/10 | ... |
| Memory Persistence | X/10 | ... |
| Eval Coverage | X/10 | ... |
| Security Guardrails | X/10 | ... |
| Cost Efficiency | X/10 | ... |

### Component Inventory

| Type | Count | With Evals | Coverage |
|------|-------|------------|----------|
| Skills | N | M | M/N% |
| Commands | N | M | M/N% |
| Subagents | N | — | — |
| Hooks | N | — | — |

### Top 3 Recommended Actions

1. **[Category]** Action description.
   - File: `path/to/relevant/file`
   - Expected impact: +N points

2. **[Category]** Action description.
   - File: `path/to/relevant/file`
   - Expected impact: +N points

3. **[Category]** Action description.
   - File: `path/to/relevant/file`
   - Expected impact: +N points
```

## Integration

- Uses `eval-harness` skill for eval analysis methodology
- References `harness-optimizer` subagent for applying improvements after audit
- Pairs with `/quality-gate` for ongoing quality tracking

## Rules

- NEVER modify any files during audit — this is a read-only analysis
- ALWAYS report actual counts and paths, not estimates
- Score conservatively — round down when uncertain
- Flag any frontmatter validation errors as findings
- If a scope filter is provided, still report overall score but detail only the requested category

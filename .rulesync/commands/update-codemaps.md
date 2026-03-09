---
description: 'Analyze codebase structure and generate token-lean architecture documentation'
targets: ["claudecode"]
---

# Update Codemaps

Analyze the codebase structure and generate token-lean architecture documentation.

## Step 1: Scan Project Structure

1. Identify the project type (multi-module Gradle/Maven, single module, library, microservice)
2. Find all source directories (`src/main/kotlin/`, `src/main/java/`, submodule `src/` trees)
3. Map entry points (`fun main()`, `@SpringBootApplication`, `public static void main(String[] args)`, etc.)

## Step 2: Generate Codemaps

Create or update codemaps in `docs/CODEMAPS/` (or `.reports/codemaps/`):

| File              | Contents                                                                   |
|-------------------|----------------------------------------------------------------------------|
| `architecture.md` | High-level system diagram, module boundaries, data flow                    |
| `api.md`          | API routes (controllers), filter/interceptor chain, service → repo mapping |
| `modules.md`      | Gradle/Maven module tree, inter-module dependencies, package structure     |
| `data.md`         | Database tables, JPA/Exposed entities, relationships, migration history    |
| `dependencies.md` | External services, third-party libraries (from build.gradle.kts/pom.xml)   |

### Codemap Format

Each codemap should be token-lean — optimized for AI context consumption:

```markdown
# API Architecture

## Routes
POST /api/users → UserController.create() → UserService.create() → UserRepository.save()
GET  /api/users/{id} → UserController.get() → UserService.findById() → UserRepository.findById()

## Key Files
com.example.service.UserService (business logic, 120 lines)
com.example.repository.UserRepository (data access, 80 lines)

## Module Dependencies (from build.gradle.kts / pom.xml)
- spring-boot-starter-web (REST API)
- spring-boot-starter-data-jpa (persistence)
- postgresql (primary data store)
- caffeine (caching)

## Package Structure (from jdeps / Gradle dependencies task)
com.example
├── controller/   (REST endpoints)
├── service/      (business logic)
├── repository/   (data access)
├── model/        (domain entities)
└── config/       (Spring configuration)
```

## Step 3: Diff Detection

1. If previous codemaps exist, calculate the diff percentage
2. If changes > 30%, show the diff and request user approval before overwriting
3. If changes <= 30%, update in place

## Step 4: Add Metadata

Add a freshness header to each codemap:

```markdown
<!-- Generated: 2026-02-11 | Files scanned: 142 | Token estimate: ~800 -->
```

## Step 5: Save Analysis Report

Write a summary to `.reports/codemap-diff.txt`:

- Files added/removed/modified since last scan
- New dependencies detected
- Architecture changes (new routes, new services, etc.)
- Staleness warnings for docs not updated in 90+ days

## Tips

- Focus on **high-level structure**, not implementation details
- Prefer **package paths and function signatures** over full code blocks
- Use `./gradlew dependencies` or `mvn dependency:tree` to map external deps
- Use `jdeps` to analyze module/package-level dependencies for Java 9+ projects
- Keep each codemap under **1000 tokens** for efficient context loading
- Use ASCII diagrams for data flow instead of verbose descriptions
- Run after major feature additions or refactoring sessions

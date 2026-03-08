---
root: true
targets: [ "claudecode" ]
description: "Project overview and general development guidelines"
globs: ["**/*"]
---

# Project Overview

## General Guidelines

- Follow consistent naming conventions across all languages
- Write self-documenting code with clear variable and function names
- Prefer composition over inheritance
- Use meaningful comments for complex business logic
- Primary stack: Kotlin/Java (JVM ecosystem), but principles apply to any language

## Architecture Principles

- Organize code by feature/domain, not by file type
- Keep related files close together
- Use dependency injection for better testability
- Implement proper error handling at every layer
- Follow single responsibility principle
- Prefer immutability and pure functions where possible

---
root: false
targets: ["claudecode"]
description: "Java security: Spring Security, input validation, parameterized queries, password hashing, JWT, CORS, and dependency scanning"
globs: ["*.java"]
---

# Java Security

> Detailed examples: use skills `springboot-security`, `security-review`

## Spring Security

- Use `SecurityFilterChain` bean (not deprecated `WebSecurityConfigurerAdapter`)
- Configure CSRF, authorization rules, session management, and OAuth2/JWT
- Use `STATELESS` session policy for REST APIs

## Input Validation

- Use Bean Validation annotations (`@NotBlank`, `@Email`, `@Size`, `@Min`, `@Max`) with `@Valid`
- Use `@Validated` on service classes for method-level validation
- Create custom validators with `@Constraint` for domain-specific rules

## SQL Injection Prevention

- NEVER use string concatenation for SQL
- Use JPA `@Query` with named parameters, JDBC `?` placeholders, or Criteria API

## Authentication

- Use BCrypt (strength 12+) for password hashing — never store plaintext
- JWT: load secret from env vars, use short expiration (<1h), validate all claims
- Implement token refresh mechanism

## CORS

- Never use `allowedOrigins("*")` with `allowCredentials(true)`
- Specify exact allowed origins, methods, and headers
- Apply CORS config only to API paths

## Rate Limiting

- Implement per-client rate limiting (Bucket4j or Resilience4j)
- Return HTTP 429 when limit exceeded

## Secret Management

- Load from environment variables, fail fast if missing at startup
- Never log secrets, include in error responses, or commit to VCS
- Use `.env` for local development (add to `.gitignore`)

## Dependency Security

- Use OWASP Dependency-Check plugin (fail build on CVSS >= 7)
- Run `dependencyCheckAnalyze` regularly

## Logging

- Never log passwords, tokens, connection strings, or PII
- Sanitize user input before logging to prevent log injection

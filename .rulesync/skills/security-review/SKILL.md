---
name: security-review
description: "Security review: OWASP Top 10, Spring Security audit, dependency scanning, secrets detection"
targets: ["claudecode"]
claudecode:
  model: opus
  allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Security Review

> For language-specific code examples, use `security-review-kotlin` or `security-review-java` skill.

## When to Activate

Trigger a security review when changes involve:

- Authentication or authorization logic
- User input handling (forms, query params, request bodies)
- New API endpoints or route changes
- Secrets, tokens, API keys, or credentials
- Payment processing or financial data
- File upload or download functionality
- Database queries or schema changes
- Third-party integrations
- CORS or security header configuration
- Session management changes

## OWASP Top 10 Checklist for Spring Applications

### A01: Broken Access Control

- Verify `@PreAuthorize` / `@Secured` on all sensitive endpoints
- Check that users cannot access other users' data (IDOR)
- Verify role hierarchy is correctly configured
- Ensure default-deny: `anyRequest().authenticated()` as the last rule
- Test that disabled accounts cannot authenticate

### A02: Cryptographic Failures

- Passwords stored with BCrypt (cost 12+) or Argon2id
- Sensitive data encrypted at rest
- TLS enforced for all external communications
- No sensitive data in URLs or query parameters
- No sensitive data in logs

### A03: Injection

#### SQL Injection

Prevention rules:

- NEVER use string concatenation in queries
- ALWAYS use parameterized queries (`@Query` with `@Param`, JPA method queries)
- jOOQ is parameterized by default
- JDBC must use `PreparedStatement`

#### LDAP Injection

- Sanitize LDAP special characters: `*`, `(`, `)`, `\`, NUL

### A04: Insecure Design

- Review business logic for abuse scenarios
- Validate all state transitions
- Implement rate limiting on sensitive operations
- Add account lockout after failed login attempts

### A05: Security Misconfiguration

Key configuration checks:

```yaml
# VERIFY: no debug/dev settings in production
spring:
  jpa:
    show-sql: false          # NEVER true in production
    open-in-view: false      # Disable OSIV
  devtools:
    restart:
      enabled: false         # Disable in production
server:
  error:
    include-stacktrace: never
    include-message: never   # Do not expose error details
```

Security headers to verify:

- Content-Security-Policy (CSP)
- X-Frame-Options: DENY
- Strict-Transport-Security (HSTS) with includeSubDomains
- X-Content-Type-Options: nosniff

### A06: Vulnerable and Outdated Components

- Run OWASP Dependency-Check regularly: `./gradlew dependencyCheckAnalyze`
- Configure `failBuildOnCVSS = 7.0f`
- Also consider: Snyk (`snyk test --all-projects`)

### A07: Identification and Authentication Failures

- Use `SessionCreationPolicy.STATELESS` for JWT APIs
- JWT tokens must be validated: signature, expiration, issuer
- Log invalid token attempts at WARN level

### A08: Software and Data Integrity Failures

- Verify CI/CD pipeline integrity
- Check that dependencies are from trusted sources
- Use Gradle dependency verification: `gradle/verification-metadata.xml`
- Sign release artifacts

### A09: Security Logging and Monitoring Failures

Events to log:

- Successful/failed login attempts
- Unauthorized access attempts
- Password changes
- Account lockouts

NEVER log:

- Passwords
- Credit card numbers
- Authentication tokens
- PII beyond what is necessary

### A10: Server-Side Request Forgery (SSRF)

URL validation requirements:

- Reject loopback addresses
- Reject private/site-local addresses
- Reject link-local addresses
- Allow only HTTP(S) schemes

## Secrets Management

### Environment Variables

- Read secrets from environment variables or Spring `@ConfigurationProperties`
- Validate required secrets at startup (fail fast)
- Use `@Value` with environment variable fallback

### Detecting Hardcoded Secrets

Search patterns to audit:

```
# API keys and tokens
password\s*=\s*["'][^"']+["']
secret\s*=\s*["'][^"']+["']
api[_-]?key\s*=\s*["'][^"']+["']
token\s*=\s*["'][^"']+["']

# Connection strings with credentials
jdbc:.*password=
mongodb://.*:.*@

# AWS/Cloud keys
AKIA[0-9A-Z]{16}
```

Files to check:

- `application.yml` / `application.properties`
- `docker-compose.yml`
- `*.env` files
- Test configuration files
- CI/CD pipeline definitions

## Input Validation

Requirements:

- Use Bean Validation annotations on request DTOs (`@NotBlank`, `@Size`, `@Email`, `@Pattern`)
- Create custom validators for domain-specific rules (e.g., `@SafeHtml`)
- Validate at controller level with `@Valid`

## XSS Prevention

- CSP headers block inline scripts
- Spring Security sets `X-Content-Type-Options: nosniff` by default
- Use HTML sanitization (e.g., Jsoup `Safelist.basic()`) if accepting rich text

## CSRF Configuration

- Stateless JWT API: CSRF can be disabled
- Session-based application: CSRF MUST be enabled with `CookieCsrfTokenRepository`

## CORS Configuration

- NEVER use `"*"` with credentials
- Specify exact allowed origins
- Limit allowed methods and headers
- Set `maxAge` for preflight cache

## Dependency Scanning

### OWASP Dependency-Check (Gradle)

- Configure `failBuildOnCVSS`, output formats, suppression file
- Run: `./gradlew dependencyCheckAnalyze`

### Snyk Integration

```bash
snyk test --all-projects --severity-threshold=high
snyk monitor --all-projects
```

## Pre-Deployment Security Checklist

- [ ] No hardcoded secrets in source code or configuration
- [ ] All endpoints have proper authentication and authorization
- [ ] Input validation on all user-facing parameters
- [ ] SQL injection prevention (parameterized queries only)
- [ ] XSS prevention (CSP headers, output encoding)
- [ ] CSRF protection enabled for session-based auth
- [ ] CORS configured with specific origins (no wildcards with credentials)
- [ ] Security headers configured (HSTS, CSP, X-Frame-Options)
- [ ] Passwords stored with BCrypt(12+) or Argon2id
- [ ] JWT tokens validated (signature, expiration, issuer)
- [ ] Rate limiting on authentication and sensitive endpoints
- [ ] No sensitive data in logs (passwords, tokens, PII)
- [ ] OWASP Dependency-Check passes (no CVE >= 7.0)
- [ ] Error responses do not leak internal details
- [ ] TLS enforced for all external communication
- [ ] Actuator endpoints secured or disabled in production
- [ ] Debug/dev features disabled in production
- [ ] File upload validated (type, size, content)
- [ ] Account lockout after repeated failed logins
- [ ] Audit logging for security-relevant events

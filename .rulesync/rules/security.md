---
root: false
targets: ["claudecode"]
description: "Security guidelines: mandatory checks, secret management, OWASP, response protocol"
globs: ["**/*"]
---

# Security Guidelines

## Pre-Commit Security Checklist

Before ANY commit, verify:

- [ ] No hardcoded secrets (API keys, passwords, tokens, connection strings)
- [ ] All user inputs validated and sanitized
- [ ] SQL injection prevention (parameterized queries only)
- [ ] XSS prevention (sanitized HTML output, proper encoding)
- [ ] CSRF protection enabled on state-changing endpoints (disable only for stateless/JWT-based APIs)
- [ ] Authentication and authorization verified on all protected resources
- [ ] Rate limiting configured on all public endpoints
- [ ] Error messages do not leak sensitive data (stack traces, internal paths, DB schemas)

## Secret Management

- NEVER hardcode secrets in source code, config files, or comments
- ALWAYS use environment variables or a dedicated secret manager
- Validate that all required secrets are present at application startup
- Rotate any secrets that may have been exposed immediately
- Use .gitignore / .env.example patterns to prevent accidental commits
- Separate secrets per environment (dev, staging, production)

## OWASP Top 10 Awareness

- Injection: parameterized queries, input validation
- Broken Authentication: strong password policies, MFA where possible
- Sensitive Data Exposure: encrypt at rest and in transit (TLS)
- Broken Access Control: principle of least privilege, deny by default
- Security Misconfiguration: disable debug in production, remove defaults
- Insecure Deserialization: validate and restrict deserialized types
- Logging & Monitoring: log security events, never log secrets

## Dependency Security

- Use OWASP Dependency-Check Gradle plugin to scan for known vulnerabilities
- Run dependency checks in CI pipeline
- Update vulnerable dependencies promptly
- Review transitive dependencies periodically

## Logging Security

- Never log sensitive data: passwords, tokens, API keys, PII, credit card numbers
- Use parameterized logging to prevent log injection
- Sanitize user input before including in log messages
- Log security events (failed logins, authorization failures)

## Security Response Protocol

If a security issue is found:

1. STOP current work immediately
2. Assess severity (CRITICAL / HIGH / MEDIUM / LOW)
3. Fix CRITICAL and HIGH issues before any other work
4. Rotate any exposed secrets
5. Review the entire codebase for similar vulnerabilities
6. Document the issue and the fix
7. Add tests to prevent regression

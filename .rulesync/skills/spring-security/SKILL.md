---
name: spring-security
description: "Spring Security: foundational concepts for authentication, JWT, OAuth2, RBAC, method security, CORS"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Security

This skill provides foundational concepts. For implementation examples, use `spring-security-kotlin` or `spring-security-java` skill.

Comprehensive guide for Spring Security: authentication flows, JWT, OAuth2, role-based access control, method security, and testing.

## SecurityFilterChain Configuration

The main entry point for HTTP security configuration. Key elements:

- CSRF policy (disable for stateless JWT APIs, enable for session-based apps)
- Session management (STATELESS for JWT)
- URL-based authorization rules with `authorizeHttpRequests`
- Custom filter insertion (e.g., JWT filter before `UsernamePasswordAuthenticationFilter`)
- Exception handling (authentication entry point, access denied handler)
- Security headers (frame options, CSP)

## JWT Authentication

### JWT Token Service

Responsible for:

- Generating access and refresh tokens with configurable expiration
- Signing tokens with HMAC secret key
- Extracting username from token claims
- Validating token (signature + expiration)

### JWT Authentication Filter

A `OncePerRequestFilter` that:

1. Extracts Bearer token from Authorization header
2. Validates token and loads user details
3. Sets `SecurityContext` authentication if valid

### Auth Controller

Endpoints:

- `POST /api/v1/auth/login` — authenticates credentials, returns access + refresh tokens
- `POST /api/v1/auth/refresh` — validates refresh token, returns new access token

## Custom UserDetailsService

Loads user from repository, maps to Spring Security `UserDetails` with:

- Username and password hash
- Granted authorities (roles prefixed with `ROLE_`)
- Account status (locked/active)

## OAuth2 Resource Server

Configure with `oauth2ResourceServer` DSL:

- JWT validation with `JwtAuthenticationConverter`
- Custom authorities mapping from JWT claims
- Issuer URI or JWK Set URI configuration

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.example.com
          # or jwk-set-uri: https://auth.example.com/.well-known/jwks.json
```

## Method-Level Security

Use `@EnableMethodSecurity` with:

- `@PreAuthorize` — check before method execution (SpEL expressions)
- `@PostAuthorize` — check after method execution (access `returnObject`)
- Common patterns: `hasRole('ADMIN')`, `#param == authentication.name`, `hasAnyRole(...)`

## CORS with Security

Configure CORS via `SecurityFilterChain`:

- Set allowed origins, methods, headers
- Enable credentials if needed
- Register configuration for specific URL patterns

## CSRF Guidelines

| Scenario                    | CSRF                                  |
|-----------------------------|---------------------------------------|
| Stateless REST API with JWT | Disable                               |
| Session-based web app       | Enable (default)                      |
| SPA with cookie auth        | Enable with CookieCsrfTokenRepository |
| Public read-only API        | Disable                               |

## Testing Security

Test both allowed and denied access patterns:

- `@WithMockUser` for simulating authenticated users with roles
- Verify 401 for unauthenticated requests
- Verify 403 for insufficient roles
- Test JWT token generation and validation

## Security Headers Configuration

```yaml
server:
  servlet:
    session:
      cookie:
        http-only: true
        secure: true
        same-site: strict
```

## Best Practices

1. **Use BCrypt with strength 12+** for password hashing
2. **Never disable CSRF** for session-based applications
3. **Disable CSRF** for stateless JWT APIs
4. **Validate JWT signatures** — never trust unsigned tokens
5. **Set short access token expiry** (15-60 minutes) with refresh tokens
6. **Use @PreAuthorize** for fine-grained access control
7. **Deny by default** — use `.anyRequest().denyAll()` as catch-all
8. **Never return security details** in error messages to clients
9. **Use HTTPS only** — configure `server.ssl` or terminate at load balancer
10. **Rotate secrets** — store JWT secret in vault, not in code
11. **Test security rules** — write tests for both allowed and denied access
12. **Use Security headers** — Content-Security-Policy, X-Frame-Options, HSTS

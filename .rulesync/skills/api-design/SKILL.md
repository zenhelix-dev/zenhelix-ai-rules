---
name: api-design
description: "REST API design: resource naming, HTTP methods, status codes, pagination, versioning, error handling principles"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# REST API Design Reference

> This skill provides foundational concepts. For implementation examples, use `api-design-kotlin` or `api-design-java` skill.

## Resource Naming

- Use **nouns**, not verbs: `/users`, not `/getUsers`
- **Plural** form: `/users`, `/orders`, `/products`
- **Lowercase** with **kebab-case**: `/order-items`, not `/orderItems`
- **Hierarchical** for sub-resources: `/users/{id}/orders`
- No trailing slashes: `/users`, not `/users/`
- No file extensions: `/users/42`, not `/users/42.json`

### Examples

```
GET    /api/v1/users              # List users
GET    /api/v1/users/{id}         # Get user
POST   /api/v1/users              # Create user
PUT    /api/v1/users/{id}         # Full update
PATCH  /api/v1/users/{id}         # Partial update
DELETE /api/v1/users/{id}         # Delete user
GET    /api/v1/users/{id}/orders  # List user's orders
```

## HTTP Methods

| Method | Semantics        | Safe | Idempotent | Request Body | Response Body  |
|--------|------------------|------|------------|--------------|----------------|
| GET    | Read resource(s) | Yes  | Yes        | No           | Yes            |
| POST   | Create resource  | No   | No         | Yes          | Yes (201)      |
| PUT    | Full replace     | No   | Yes        | Yes          | Yes (200)      |
| PATCH  | Partial update   | No   | No         | Yes          | Yes (200)      |
| DELETE | Remove resource  | No   | Yes        | No           | 204 No Content |

## Status Codes

### Success (2xx)

| Code           | When                       | Example                                   |
|----------------|----------------------------|-------------------------------------------|
| 200 OK         | Successful GET, PUT, PATCH | Return resource                           |
| 201 Created    | Successful POST            | Return created resource + Location header |
| 204 No Content | Successful DELETE          | No body                                   |

### Client Error (4xx)

| Code                     | When                             | Example                           |
|--------------------------|----------------------------------|-----------------------------------|
| 400 Bad Request          | Malformed request                | Invalid JSON                      |
| 401 Unauthorized         | Not authenticated                | Missing/invalid token             |
| 403 Forbidden            | Authenticated but not authorized | Insufficient permissions          |
| 404 Not Found            | Resource does not exist          | Unknown ID                        |
| 409 Conflict             | State conflict                   | Duplicate email, version mismatch |
| 422 Unprocessable Entity | Validation failure               | Invalid field values              |
| 429 Too Many Requests    | Rate limit exceeded              | Include Retry-After header        |

### Server Error (5xx)

| Code                      | When                      |
|---------------------------|---------------------------|
| 500 Internal Server Error | Unexpected server error   |
| 502 Bad Gateway           | Upstream service failure  |
| 503 Service Unavailable   | Overloaded or maintenance |

## Response Format

### Success Response

```json
{
  "data": {
    "id": 42,
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

### Paginated Response

```json
{
  "data": [
    { "id": 1, "name": "Alice" },
    { "id": 2, "name": "Bob" }
  ],
  "meta": {
    "page": 0,
    "size": 20,
    "totalElements": 142,
    "totalPages": 8
  }
}
```

### Error Response (RFC 7807 ProblemDetail)

```json
{
  "type": "https://api.example.com/problems/validation-error",
  "title": "Validation Failed",
  "status": 422,
  "detail": "One or more fields have invalid values",
  "instance": "/api/v1/users",
  "errors": [
    { "field": "email", "message": "must be a valid email address" },
    { "field": "name", "message": "must not be blank" }
  ]
}
```

## Pagination

### Offset-Based (Simple Cases)

Use `?page=0&size=20&sort=createdAt,desc` query parameters. Return `meta` with page, size, totalElements, totalPages.

### Cursor-Based (Large Datasets)

Use a cursor parameter encoding the last seen position (e.g., Base64-encoded timestamp+id). Return `nextCursor` and `hasMore` in the
response.

## Filtering and Sorting

```
GET /api/v1/orders?status=PENDING&minTotal=100&sort=-createdAt,+total
```

Sort prefix: `-` for descending, `+` (or no prefix) for ascending.

## Versioning

### URL Path Versioning (Preferred)

```
/api/v1/users
/api/v2/users
```

### Header Versioning (Alternative)

```
GET /api/users
Accept: application/vnd.myapp.v2+json
```

## Rate Limiting Headers

Include in responses:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1700000000
Retry-After: 30
```

## API Design Checklist

- [ ] Resources are nouns, plural, kebab-case
- [ ] Correct HTTP methods for each operation
- [ ] Appropriate status codes (not just 200 for everything)
- [ ] Consistent response envelope (data + meta)
- [ ] ProblemDetail (RFC 7807) for errors
- [ ] Pagination on all list endpoints
- [ ] Validation on all inputs with clear error messages
- [ ] Versioning strategy decided and applied
- [ ] No sensitive data in error responses
- [ ] Rate limiting headers on all endpoints
- [ ] Location header on 201 Created responses
- [ ] Idempotent PUT and DELETE
- [ ] HATEOAS links if applicable
- [ ] Request/response DTOs separate from domain entities
- [ ] Consistent naming across all endpoints

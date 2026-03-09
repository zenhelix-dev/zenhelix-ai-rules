---
name: spring-core
description: "Spring Core foundational concepts: dependency injection principles, configuration patterns, profiles, properties binding, actuator, auto-configuration"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Core

This skill provides foundational concepts. For implementation examples, use `spring-core-kotlin` or `spring-core-java` skill.

Comprehensive guide for Spring Framework core concepts: dependency injection, configuration, profiles, properties, actuator, and
auto-configuration.

## Stereotype Annotations

Use stereotype annotations to mark classes for component scanning. Each conveys intent about the layer the class belongs to.

| Annotation        | Layer          | Purpose                                        |
|-------------------|----------------|------------------------------------------------|
| `@Component`      | Generic        | General-purpose Spring-managed bean            |
| `@Service`        | Business logic | Service layer classes                          |
| `@Repository`     | Data access    | DAO classes, enables exception translation     |
| `@Controller`     | Web            | MVC controllers (with view resolution)         |
| `@RestController` | Web            | REST controllers (@Controller + @ResponseBody) |

## Dependency Injection

**Always prefer constructor injection.** It makes dependencies explicit, enables immutability, and simplifies testing.

Principles:

- Single constructor does not need `@Autowired`
- Use `@Qualifier` when multiple implementations exist
- Avoid field injection (hides dependencies, untestable without reflection)
- Avoid setter injection (allows partially constructed objects)

## Configuration Classes

Use `@Configuration` classes to define beans programmatically with `@Bean` methods.

Key annotations:

- `@Bean` — declares a bean
- `@ConditionalOnMissingBean` — creates bean only if no other of same type exists
- `@ConditionalOnClass` — creates bean only if class is on classpath
- `@ConditionalOnProperty` — creates bean based on property value

## Properties and Configuration Binding

### application.yml Structure

```yaml
server:
  port: 8080
  shutdown: graceful

spring:
  application:
    name: order-service
  datasource:
    url: jdbc:postgresql://localhost:5432/orders
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5

app:
  payment:
    gateway-url: https://api.payment.com
    timeout: 5s
    retry-attempts: 3
  notification:
    enabled: true
    from-email: noreply@example.com
```

### Type-Safe Configuration Properties

Use `@ConfigurationProperties` for structured, type-safe configuration binding. Enable scanning with `@ConfigurationPropertiesScan`.

**Prefer @ConfigurationProperties over @Value** for anything beyond a single simple property.

## Profiles

Profiles allow environment-specific configuration:

- `@Profile("local")` / `@Profile("production")` on `@Configuration` or `@Bean`
- `@Profile("!test")` — active when profile is NOT active
- Profile-specific YAML: `application-{profile}.yml`

### Profile-Specific YAML

```yaml
# application-local.yml
spring:
  datasource:
    url: jdbc:h2:mem:testdb
logging:
  level:
    root: DEBUG

# application-production.yml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:5432/orders
logging:
  level:
    root: WARN
```

Activate profiles via: `SPRING_PROFILES_ACTIVE=production` or `--spring.profiles.active=production`.

## Spring Boot Actuator

### Dependencies

```kotlin
// build.gradle.kts
implementation("org.springframework.boot:spring-boot-starter-actuator")
```

### Configuration

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized
      probes:
        enabled: true
  info:
    env:
      enabled: true
  metrics:
    tags:
      application: ${spring.application.name}
```

### Custom Health Indicator

Implement `HealthIndicator` interface to add custom health checks for external dependencies.

### Custom Metrics

Use `MeterRegistry` to define custom metrics (counters, gauges, timers, distribution summaries).

## Auto-Configuration

### Custom Auto-Configuration

Define auto-configuration classes with conditional annotations to provide default beans that users can override.

### Registration

Register auto-configuration in `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`:

```
com.example.payment.PaymentAutoConfiguration
```

### Common Conditional Annotations

| Annotation                     | Purpose                                        |
|--------------------------------|------------------------------------------------|
| `@ConditionalOnClass`          | Bean exists only if class is on classpath      |
| `@ConditionalOnMissingBean`    | Bean exists only if no other bean of same type |
| `@ConditionalOnProperty`       | Bean exists only if property matches value     |
| `@ConditionalOnMissingClass`   | Bean exists only if class is NOT on classpath  |
| `@ConditionalOnWebApplication` | Bean exists only in web application context    |
| `@ConditionalOnExpression`     | Bean exists based on SpEL expression           |

## Best Practices

1. **Constructor injection only** — never field or setter injection
2. **Use @ConfigurationProperties** over @Value for structured config
3. **Keep @Configuration classes focused** — one concern per class
4. **Use profiles sparingly** — prefer feature flags for runtime toggles
5. **Externalize all secrets** — use environment variables or vault
6. **Enable actuator selectively** — expose only needed endpoints in production
7. **Validate configuration** — use `@Validated` on @ConfigurationProperties
8. **Use immutable config** — Kotlin data classes or Java records for properties

---
name: spring-cloud
description: "Spring Cloud: foundational concepts for Config Server, Gateway, Circuit breaker, Service discovery, Feign"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Cloud

This skill provides foundational concepts. For implementation examples, use `spring-cloud-kotlin` or `spring-cloud-java` skill.

Comprehensive guide for Spring Cloud: Config Server, Gateway, Circuit Breaker, Service Discovery, Feign, and distributed tracing.

## Spring Cloud Config

### Config Server Setup

Annotate the main application class with `@EnableConfigServer`. Configure Git or native filesystem as the config backend.

```yaml
# Config Server application.yml
server:
  port: 8888

spring:
  cloud:
    config:
      server:
        git:
          uri: https://github.com/org/config-repo
          default-label: main
          search-paths: "{application}"
          clone-on-start: true
        # Or native filesystem
        # native:
        #   search-locations: classpath:/config
```

### Config Client

```yaml
# Client application.yml
spring:
  application:
    name: order-service
  config:
    import: configserver:http://localhost:8888
  cloud:
    config:
      fail-fast: true
      retry:
        max-attempts: 5
        initial-interval: 1000
```

### Refresh Configuration at Runtime

Use `@RefreshScope` on beans that need dynamic configuration. Trigger refresh via actuator: `POST /actuator/refresh`.

For bus-based refresh across instances:

```yaml
spring:
  cloud:
    bus:
      enabled: true
  rabbitmq:
    host: localhost
    port: 5672
```

Trigger: `POST /actuator/busrefresh`

## Spring Cloud Gateway

### Route Configuration (YAML)

```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: order-service
          uri: lb://order-service
          predicates:
            - Path=/api/v1/orders/**
          filters:
            - AddRequestHeader=X-Gateway, true
            - name: CircuitBreaker
              args:
                name: orderServiceCB
                fallbackUri: forward:/fallback/orders
            - name: Retry
              args:
                retries: 3
                statuses: SERVICE_UNAVAILABLE

      default-filters:
        - name: RequestRateLimiter
          args:
            redis-rate-limiter.replenishRate: 10
            redis-rate-limiter.burstCapacity: 20
```

## Circuit Breaker with Resilience4j

### Configuration

```yaml
resilience4j:
  circuitbreaker:
    instances:
      paymentService:
        slidingWindowSize: 10
        failureRateThreshold: 50
        waitDurationInOpenState: 30s
        permittedNumberOfCallsInHalfOpenState: 3
        registerHealthIndicator: true

  retry:
    instances:
      paymentService:
        maxAttempts: 3
        waitDuration: 1s
        enableExponentialBackoff: true
        exponentialBackoffMultiplier: 2

  timelimiter:
    instances:
      paymentService:
        timeoutDuration: 5s
```

Use `@CircuitBreaker`, `@Retry`, and `@TimeLimiter` annotations on service methods with `fallbackMethod` for graceful degradation.

## Service Discovery

### Eureka Server

Annotate with `@EnableEurekaServer`.

```yaml
# Eureka Server
server:
  port: 8761

eureka:
  client:
    register-with-eureka: false
    fetch-registry: false
```

### Eureka Client

```yaml
# Service application.yml
spring:
  application:
    name: order-service

eureka:
  client:
    service-url:
      defaultZone: http://localhost:8761/eureka/
  instance:
    prefer-ip-address: true
    lease-renewal-interval-in-seconds: 10
    lease-expiration-duration-in-seconds: 30
```

## OpenFeign Declarative HTTP Clients

Define interfaces annotated with `@FeignClient`. Support fallback factories for circuit breaker integration.

### Feign Configuration

```yaml
spring:
  cloud:
    openfeign:
      client:
        config:
          default:
            connect-timeout: 5000
            read-timeout: 10000
            logger-level: basic
          payment-service:
            connect-timeout: 3000
            read-timeout: 5000
```

## Load Balancing

Use `@LoadBalanced` on `RestTemplate` or `WebClient.Builder` beans. Spring Cloud LoadBalancer replaces deprecated Ribbon.

## Distributed Tracing with Micrometer

```yaml
management:
  tracing:
    sampling:
      probability: 1.0
  zipkin:
    tracing:
      endpoint: http://localhost:9411/api/v2/spans

logging:
  pattern:
    level: "%5p [${spring.application.name},%X{traceId:-},%X{spanId:-}]"
```

## Spring Cloud Stream

Configure function-based bindings (Consumer, Supplier, Function) for event-driven microservices.

```yaml
spring:
  cloud:
    stream:
      bindings:
        orderCreatedConsumer-in-0:
          destination: order-created
          group: notification-service
        orderStatusSupplier-out-0:
          destination: order-status
      kafka:
        binder:
          brokers: localhost:9092
```

## Health Checks and Readiness Probes

```yaml
management:
  endpoint:
    health:
      probes:
        enabled: true
      show-details: when-authorized
      group:
        readiness:
          include: db,diskSpace,discoveryComposite
        liveness:
          include: ping

# Kubernetes probes
# livenessProbe: /actuator/health/liveness
# readinessProbe: /actuator/health/readiness
```

## Best Practices

1. **Externalize configuration** — use Config Server for centralized management
2. **Circuit breakers on all external calls** — prevent cascade failures
3. **Configure timeouts everywhere** — Feign, WebClient, circuit breaker, gateway
4. **Use service discovery** — avoid hardcoded URLs
5. **Propagate trace IDs** — enable distributed tracing across all services
6. **Use gateway for cross-cutting concerns** — rate limiting, auth, logging
7. **Design for failure** — implement fallbacks for all circuit breakers
8. **Use Spring Cloud Stream** for async communication between services
9. **Health checks per dependency** — separate liveness from readiness probes
10. **Test with WireMock** — mock external services in integration tests
11. **Configuration refresh** — use bus refresh for coordinated config updates
12. **Load balancing** — use Spring Cloud LoadBalancer (Ribbon is deprecated)

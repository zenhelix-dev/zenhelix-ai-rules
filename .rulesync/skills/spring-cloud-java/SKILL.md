---
name: spring-cloud-java
description: "Java implementation patterns for Spring Cloud. Use with `spring-cloud` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Cloud — Java

Prerequisites: load `spring-cloud` skill for foundational concepts.

## Spring Cloud Config

### Config Server Setup

<!-- TODO: Add Java equivalent -->

### Refresh Configuration at Runtime

<!-- TODO: Add Java equivalent -->

## Spring Cloud Gateway

### Route Configuration

<!-- TODO: Add Java equivalent (Gateway uses reactive stack, Kotlin examples in spring-cloud-kotlin apply similarly) -->

### Custom Gateway Filter

<!-- TODO: Add Java equivalent -->

### Global Filters

<!-- TODO: Add Java equivalent -->

## Circuit Breaker with Resilience4j

```java
@Service
public class PaymentService {

    private final PaymentClient paymentClient;

    @CircuitBreaker(name = "paymentService", fallbackMethod = "paymentFallback")
    @Retry(name = "paymentService")
    public PaymentResponse processPayment(PaymentRequest request) {
        return paymentClient.charge(request);
    }

    private PaymentResponse paymentFallback(PaymentRequest request, Exception ex) {
        return new PaymentResponse(PaymentStatus.PENDING, "Payment processing delayed");
    }
}
```

## Service Discovery

### Eureka Server

<!-- TODO: Add Java equivalent -->

## OpenFeign Declarative HTTP Clients

```java
@FeignClient(
    name = "payment-service",
    fallbackFactory = PaymentClientFallbackFactory.class
)
public interface PaymentClient {

    @PostMapping("/api/v1/payments")
    PaymentResponse charge(@RequestBody PaymentRequest request);

    @GetMapping("/api/v1/payments/{id}")
    PaymentResponse getPayment(@PathVariable String id);
}
```

## Load Balancing

<!-- TODO: Add Java equivalent -->

## Distributed Tracing with Micrometer

<!-- TODO: Add Java equivalent -->

## Spring Cloud Stream

<!-- TODO: Add Java equivalent -->

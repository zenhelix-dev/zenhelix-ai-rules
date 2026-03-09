---
name: spring-core-java
description: "Java implementation patterns for Spring Core. Use with `spring-core` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Core — Java

Prerequisites: load `spring-core` skill for foundational concepts.

## Stereotype Annotations

```java
@Component
public class EmailValidator { }

@Service
public class OrderService {
    private final OrderRepository orderRepository;
    private final PaymentGateway paymentGateway;

    public OrderService(OrderRepository orderRepository, PaymentGateway paymentGateway) {
        this.orderRepository = orderRepository;
        this.paymentGateway = paymentGateway;
    }
}

@Repository
public class JpaOrderRepository implements OrderRepository {
    private final EntityManager entityManager;

    public JpaOrderRepository(EntityManager entityManager) {
        this.entityManager = entityManager;
    }
}
```

## Dependency Injection

```java
// PREFERRED: Constructor injection
@Service
public class UserService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }
}

// Using @Qualifier
@Service
public class NotificationService {
    private final MessageSender emailSender;
    private final MessageSender smsSender;

    public NotificationService(
            @Qualifier("email") MessageSender emailSender,
            @Qualifier("sms") MessageSender smsSender) {
        this.emailSender = emailSender;
        this.smsSender = smsSender;
    }
}
```

### Anti-patterns to Avoid

<!-- TODO: Add Java equivalent (field injection, setter injection anti-patterns) -->

## Configuration Classes

```java
@Configuration
public class AppConfig {

    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    }

    @Bean
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        return builder
            .connectTimeout(Duration.ofSeconds(5))
            .readTimeout(Duration.ofSeconds(10))
            .build();
    }

    @Bean
    @ConditionalOnMissingBean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }
}
```

## Type-Safe Configuration Properties

```java
@ConfigurationProperties(prefix = "app.payment")
public record PaymentProperties(
    String gatewayUrl,
    @DefaultValue("5s") Duration timeout,
    @DefaultValue("3") int retryAttempts
) {}

@ConfigurationProperties(prefix = "app.notification")
public record NotificationProperties(
    @DefaultValue("true") boolean enabled,
    String fromEmail
) {}
```

### @Value for Simple Cases

<!-- TODO: Add Java equivalent -->

## Profiles

<!-- TODO: Add Java equivalent -->

## Custom Health Indicator

```java
@Component
public class PaymentGatewayHealthIndicator implements HealthIndicator {

    private final PaymentClient paymentClient;

    public PaymentGatewayHealthIndicator(PaymentClient paymentClient) {
        this.paymentClient = paymentClient;
    }

    @Override
    public Health health() {
        try {
            paymentClient.ping();
            return Health.up()
                .withDetail("gateway", "reachable")
                .build();
        } catch (Exception ex) {
            return Health.down()
                .withDetail("gateway", "unreachable")
                .withException(ex)
                .build();
        }
    }
}
```

## Custom Metrics

<!-- TODO: Add Java equivalent -->

## Custom Auto-Configuration

```java
@AutoConfiguration
@ConditionalOnClass(PaymentClient.class)
@EnableConfigurationProperties(PaymentProperties.class)
public class PaymentAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    public PaymentClient paymentClient(PaymentProperties properties) {
        return new DefaultPaymentClient(
            properties.gatewayUrl(),
            properties.timeout()
        );
    }

    @Bean
    @ConditionalOnProperty(prefix = "app.payment", name = "retry-enabled", havingValue = "true")
    public PaymentClient retryablePaymentClient(
            PaymentClient delegate,
            PaymentProperties properties) {
        return new RetryablePaymentClient(delegate, properties.retryAttempts());
    }
}
```

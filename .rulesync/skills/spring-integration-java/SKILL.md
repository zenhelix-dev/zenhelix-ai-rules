---
name: spring-integration-java
description: "Java implementation patterns for Spring Integration. Use with `spring-integration` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Integration — Java

Prerequisites: load `spring-integration` skill for foundational concepts.

## Integration DSL: IntegrationFlows

```java
@Configuration
public class OrderIntegrationConfig {

    @Bean
    public IntegrationFlow orderProcessingFlow(OrderService orderService) {
        return IntegrationFlow.from("orderInputChannel")
            .filter(OrderMessage.class, msg -> msg.getTotalAmount().compareTo(BigDecimal.ZERO) > 0)
            .transform(OrderMessage.class, msg -> new Order(
                msg.getCustomerId(),
                msg.getTotalAmount(),
                msg.getItems().stream().map(OrderItemMessage::toOrderItem).toList()
            ))
            .handle(Order.class, (order, headers) -> orderService.create(order))
            .channel("orderOutputChannel")
            .get();
    }
}
```

## Channel Types

<!-- TODO: Add Java equivalent -->

## Adapters

### File Adapter

<!-- TODO: Add Java equivalent -->

### HTTP Adapter

<!-- TODO: Add Java equivalent -->

### JDBC Adapter

<!-- TODO: Add Java equivalent -->

### AMQP Adapter (RabbitMQ)

<!-- TODO: Add Java equivalent -->

### TCP Adapter

<!-- TODO: Add Java equivalent -->

## Transformers and Filters

<!-- TODO: Add Java equivalent -->

## Service Activator

<!-- TODO: Add Java equivalent -->

## Gateway Interface

```java
@MessagingGateway
public interface OrderGateway {

    @Gateway(requestChannel = "orderInputChannel", replyChannel = "orderOutputChannel")
    Order submitOrder(OrderMessage order);

    @Gateway(requestChannel = "orderInputChannel")
    Future<Order> submitOrderAsync(OrderMessage order);
}
```

## Splitter/Aggregator Patterns

<!-- TODO: Add Java equivalent -->

## Error Handling

<!-- TODO: Add Java equivalent -->

## Poller Configuration

<!-- TODO: Add Java equivalent -->

## Testing with MockIntegrationContext

<!-- TODO: Add Java equivalent -->

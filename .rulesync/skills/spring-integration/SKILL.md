---
name: spring-integration
description: "Spring Integration: foundational concepts for message channels, adapters, transformers, gateways, flows"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Integration

This skill provides foundational concepts. For implementation examples, use `spring-integration-kotlin` or `spring-integration-java` skill.

Comprehensive guide for Spring Integration: messaging concepts, integration DSL, channels, adapters, transformers, gateways, and patterns.

## Core Concepts

- **Message**: Payload + Headers — the unit of data in the integration flow
- **MessageChannel**: Pipe connecting components
- **MessageHandler**: Processes messages (endpoints, adapters, transformers)
- **Gateway**: Entry point to the messaging system from application code
- **Adapter**: Connects to external systems (file, HTTP, JMS, AMQP, etc.)

## Integration DSL: IntegrationFlows

Use `IntegrationFlow.from(...)` to define flows declaratively with filters, transforms, handlers, and channel routing.

## Channel Types

- **Direct Channel** — Synchronous, point-to-point
- **Queue Channel** — Asynchronous, point-to-point, with configurable capacity
- **Publish-Subscribe Channel** — Fan-out to multiple subscribers
- **Priority Channel** — Messages ordered by priority header

## Adapters

### File Adapter

Read files from directories with pattern filtering and duplicate prevention. Write files with auto-created directories and custom file name
generators.

### HTTP Adapter

Inbound HTTP gateways for receiving requests. Outbound HTTP adapters for calling external APIs with header mapping.

### JDBC Adapter

Poll database tables for pending records. Write audit logs or results back to database.

### AMQP Adapter (RabbitMQ)

Inbound adapters with configurable concurrent consumers and prefetch. Outbound adapters with exchange and routing key configuration.

### TCP Adapter

Server connection factories with serializers/deserializers for raw TCP communication.

## Transformers and Filters

- Filter messages based on payload conditions
- Transform between types (JSON, custom mapping)
- Enrich headers with static values or SpEL expressions

## Service Activator

Route messages to service methods using `.handle(ServiceClass::class.java, "methodName")` or `@ServiceActivator` annotation.

## Gateway Interface

Define `@MessagingGateway` interfaces as the entry point from application code. Support synchronous, async (Future), and batch operations.

## Splitter/Aggregator Patterns

- **Splitter**: Break batch messages into individual items
- **Aggregator**: Collect related messages with correlation strategy, release strategy, and timeout
- Use executor channels for parallel processing between split and aggregate

## Error Handling

- **Global error channel**: Handle all unhandled exceptions
- **Per-flow error handling**: Use advice (e.g., `RequestHandlerRetryAdvice`) on specific handlers
- **Dead letter storage**: Persist failed messages for later retry
- Configure retry with exponential backoff

## Poller Configuration

Configure triggers (periodic, cron), max messages per poll, task executors, and error handlers for polled channels.

## Testing with MockIntegrationContext

Use `@SpringIntegrationTest` with `MockIntegrationContext` to substitute message handlers for isolated testing. Send messages to input
channels and assert on output channels.

## Best Practices

1. **Use the DSL** over XML or annotation-based configuration
2. **Name your channels** explicitly for clarity and debugging
3. **Use error channels** — configure per-flow and global error handling
4. **Configure pollers** — set appropriate delays and batch sizes
5. **Use thread pools** — configure task executors for concurrent processing
6. **Use gateways** as the entry point from application code into flows
7. **Idempotent receivers** — use `IdempotentReceiverInterceptor` for at-least-once delivery
8. **Monitor channels** — use `MessageChannelMetrics` for observability
9. **Use message store** — persist messages for reliability (JDBC, MongoDB)
10. **Test with MockIntegrationContext** — substitute handlers for isolated testing

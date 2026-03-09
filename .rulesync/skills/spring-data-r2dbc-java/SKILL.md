---
name: spring-data-r2dbc-java
description: "Java implementation patterns for Spring Data R2DBC. Use with `spring-data-r2dbc` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Data R2DBC — Java

Prerequisites: load `spring-data-r2dbc` skill for foundational concepts.

## Entity Mapping

```java
@Table("orders")
public record Order(
    @Id Long id,
    String customerId,
    OrderStatus status,
    BigDecimal totalAmount,
    String notes,
    @CreatedDate Instant createdAt,
    @LastModifiedDate Instant updatedAt
) {
    public Order withStatus(OrderStatus newStatus) {
        return new Order(id, customerId, newStatus, totalAmount, notes, createdAt, updatedAt);
    }
}
```

## Reactive Repositories (Reactive Repository)

```java
public interface OrderRepository extends ReactiveCrudRepository<Order, Long> {

    Flux<Order> findByCustomerId(String customerId);

    Flux<Order> findByStatus(OrderStatus status);

    Mono<Order> findByCustomerIdAndStatus(String customerId, OrderStatus status);

    @Query("SELECT * FROM orders WHERE status = :status ORDER BY created_at DESC LIMIT :limit")
    Flux<Order> findRecentByStatus(OrderStatus status, int limit);

    @Modifying
    @Query("UPDATE orders SET status = :status WHERE id = :id")
    Mono<Integer> updateStatus(Long id, OrderStatus status);
}
```

## DatabaseClient for Complex Queries

```java
@Repository
public class OrderCustomRepository {

    private final DatabaseClient databaseClient;

    public OrderCustomRepository(DatabaseClient databaseClient) {
        this.databaseClient = databaseClient;
    }

    public Mono<OrderWithItems> findWithItems(Long orderId) {
        Mono<Order> orderMono = databaseClient.sql("SELECT * FROM orders WHERE id = :id")
            .bind("id", orderId)
            .map((row, metadata) -> new Order(
                row.get("id", Long.class),
                row.get("customer_id", String.class),
                OrderStatus.valueOf(row.get("status", String.class)),
                row.get("total_amount", BigDecimal.class),
                null, null, null
            ))
            .one();

        return orderMono.flatMap(order -> {
            Flux<OrderItem> items = databaseClient.sql("SELECT * FROM order_items WHERE order_id = :orderId")
                .bind("orderId", orderId)
                .map((row, metadata) -> new OrderItem(
                    row.get("id", Long.class),
                    row.get("order_id", Long.class),
                    row.get("product_id", String.class),
                    row.get("quantity", Integer.class),
                    row.get("unit_price", BigDecimal.class)
                ))
                .all();
            return items.collectList().map(itemList -> new OrderWithItems(order, itemList));
        });
    }
}
```

## Transaction Management

```java
@Service
public class OrderService {

    private final OrderRepository orderRepository;
    private final TransactionalOperator transactionalOperator;

    @Transactional
    public Mono<OrderResponse> createOrder(CreateOrderRequest request) {
        return orderRepository.save(new Order(null, request.customerId(),
                OrderStatus.CREATED, request.totalAmount(), null, null, null))
            .flatMap(order -> Flux.fromIterable(request.items())
                .flatMap(item -> orderItemRepository.save(new OrderItem(
                    null, order.id(), item.productId(), item.quantity(), item.unitPrice())))
                .collectList()
                .map(items -> new OrderResponse(order, items)));
    }
}
```

## R2DBC Auditing

<!-- TODO: Add Java equivalent -->

## Testing Reactive Repositories

<!-- TODO: Add Java equivalent -->

---
name: spring-data-jpa-java
description: "Java implementation patterns for Spring Data JPA. Use with `spring-data-jpa` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Data JPA — Java

Prerequisites: load `spring-data-jpa` skill for foundational concepts.

## Entity Design

```java
@Entity
@Table(name = "orders")
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String customerId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OrderStatus status = OrderStatus.CREATED;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal totalAmount;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderItem> items = new ArrayList<>();

    @CreatedDate
    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(nullable = false)
    private Instant updatedAt;

    // Getters, equals/hashCode by id
}
```

## Repository Interface

```java
public interface OrderRepository extends JpaRepository<Order, Long>, JpaSpecificationExecutor<Order> {

    List<Order> findByCustomerId(String customerId);
    Page<Order> findByStatus(OrderStatus status, Pageable pageable);
    boolean existsByCustomerIdAndStatus(String customerId, OrderStatus status);

    @Query("SELECT o FROM Order o WHERE o.status = :status AND o.createdAt > :since")
    List<Order> findRecentByStatus(@Param("status") OrderStatus status, @Param("since") Instant since);

    @Modifying
    @Query("UPDATE Order o SET o.status = :status WHERE o.id IN :ids")
    int updateStatusByIds(@Param("ids") List<Long> ids, @Param("status") OrderStatus status);
}
```

## Specifications for Dynamic Queries

```java
public class OrderSpecifications {

    public static Specification<Order> hasCustomerId(String customerId) {
        return (root, query, cb) ->
            customerId != null ? cb.equal(root.get("customerId"), customerId) : null;
    }

    public static Specification<Order> hasStatus(OrderStatus status) {
        return (root, query, cb) ->
            status != null ? cb.equal(root.get("status"), status) : null;
    }

    public static Specification<Order> createdAfter(Instant since) {
        return (root, query, cb) ->
            since != null ? cb.greaterThan(root.get("createdAt"), since) : null;
    }
}
```

## Projections

<!-- TODO: Add Java equivalent for interface-based projections -->

<!-- TODO: Add Java equivalent for class-based projections (DTO) -->

<!-- TODO: Add Java equivalent for dynamic projections -->

## EntityGraph (N+1 Prevention)

<!-- TODO: Add Java equivalent -->

## Auditing

<!-- TODO: Add Java equivalent for auditing configuration and base entity -->

## Pagination

<!-- TODO: Add Java equivalent -->

## Custom Repository Implementation

<!-- TODO: Add Java equivalent -->

## Transaction Management

<!-- TODO: Add Java equivalent -->

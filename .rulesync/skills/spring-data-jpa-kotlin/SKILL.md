---
name: spring-data-jpa-kotlin
description: "Kotlin implementation patterns for Spring Data JPA. Use with `spring-data-jpa` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Data JPA — Kotlin

Prerequisites: load `spring-data-jpa` skill for foundational concepts.

## Entity Design

```kotlin
@Entity
@Table(name = "orders")
class Order(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(nullable = false)
    val customerId: String,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var status: OrderStatus = OrderStatus.CREATED,

    @Column(nullable = false, precision = 12, scale = 2)
    val totalAmount: BigDecimal,

    @OneToMany(mappedBy = "order", cascade = [CascadeType.ALL], orphanRemoval = true)
    val items: MutableList<OrderItem> = mutableListOf(),

    @CreatedDate
    @Column(nullable = false, updatable = false)
    var createdAt: Instant = Instant.now(),

    @LastModifiedDate
    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
) {
    fun addItem(item: OrderItem) {
        items.add(item)
        item.order = this
    }
}

@Entity
@Table(name = "order_items")
class OrderItem(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id", nullable = false)
    var order: Order? = null,

    @Column(nullable = false)
    val productId: String,

    @Column(nullable = false)
    val quantity: Int,

    @Column(nullable = false, precision = 10, scale = 2)
    val unitPrice: BigDecimal
)
```

## Repository Interface

```kotlin
interface OrderRepository : JpaRepository<Order, Long>, JpaSpecificationExecutor<Order> {

    // Derived query methods
    fun findByCustomerId(customerId: String): List<Order>
    fun findByStatus(status: OrderStatus, pageable: Pageable): Page<Order>
    fun existsByCustomerIdAndStatus(customerId: String, status: OrderStatus): Boolean
    fun countByStatus(status: OrderStatus): Long

    // JPQL queries
    @Query("SELECT o FROM Order o WHERE o.status = :status AND o.createdAt > :since")
    fun findRecentByStatus(
        @Param("status") status: OrderStatus,
        @Param("since") since: Instant
    ): List<Order>

    // Native SQL queries
    @Query(
        value = "SELECT customer_id, COUNT(*) as order_count, SUM(total_amount) as total " +
                "FROM orders WHERE status = :status GROUP BY customer_id",
        nativeQuery = true
    )
    fun getCustomerOrderStats(@Param("status") status: String): List<CustomerOrderStatsProjection>

    // Modifying queries
    @Modifying
    @Query("UPDATE Order o SET o.status = :status WHERE o.id IN :ids")
    fun updateStatusByIds(@Param("ids") ids: List<Long>, @Param("status") status: OrderStatus): Int
}
```

## Specifications for Dynamic Queries

```kotlin
object OrderSpecifications {

    fun hasCustomerId(customerId: String?): Specification<Order> =
        Specification { root, _, cb ->
            customerId?.let { cb.equal(root.get<String>("customerId"), it) }
        }

    fun hasStatus(status: OrderStatus?): Specification<Order> =
        Specification { root, _, cb ->
            status?.let { cb.equal(root.get<OrderStatus>("status"), it) }
        }

    fun createdAfter(since: Instant?): Specification<Order> =
        Specification { root, _, cb ->
            since?.let { cb.greaterThan(root.get("createdAt"), it) }
        }

    fun totalAmountBetween(min: BigDecimal?, max: BigDecimal?): Specification<Order> =
        Specification { root, _, cb ->
            val predicates = mutableListOf<Predicate>()
            min?.let { predicates.add(cb.greaterThanOrEqualTo(root.get("totalAmount"), it)) }
            max?.let { predicates.add(cb.lessThanOrEqualTo(root.get("totalAmount"), it)) }
            cb.and(*predicates.toTypedArray())
        }
}

// Usage in service
@Service
class OrderService(private val orderRepository: OrderRepository) {

    fun search(filter: OrderFilter, pageable: Pageable): Page<Order> {
        val spec = Specification.where(OrderSpecifications.hasCustomerId(filter.customerId))
            .and(OrderSpecifications.hasStatus(filter.status))
            .and(OrderSpecifications.createdAfter(filter.since))
            .and(OrderSpecifications.totalAmountBetween(filter.minAmount, filter.maxAmount))
        return orderRepository.findAll(spec, pageable)
    }
}
```

## Projections

### Interface-Based Projection

```kotlin
// Closed projection — only specified fields are fetched
interface OrderSummary {
    val id: Long
    val customerId: String
    val status: OrderStatus
    val totalAmount: BigDecimal
    val createdAt: Instant
}

// Open projection with SpEL
interface OrderWithItemCount {
    val id: Long
    val customerId: String

    @get:Value("#{target.items.size()}")
    val itemCount: Int
}

// Usage in repository
interface OrderRepository : JpaRepository<Order, Long> {
    fun findSummaryByStatus(status: OrderStatus): List<OrderSummary>
}
```

### Class-Based Projection (DTO)

```kotlin
data class OrderDto(
    val id: Long,
    val customerId: String,
    val totalAmount: BigDecimal,
    val status: OrderStatus
)

interface OrderRepository : JpaRepository<Order, Long> {
    @Query("SELECT new com.example.dto.OrderDto(o.id, o.customerId, o.totalAmount, o.status) FROM Order o WHERE o.status = :status")
    fun findDtosByStatus(@Param("status") status: OrderStatus): List<OrderDto>
}
```

### Dynamic Projections

```kotlin
interface OrderRepository : JpaRepository<Order, Long> {
    fun <T> findById(id: Long, type: Class<T>): T?
}

// Usage
val summary: OrderSummary? = orderRepository.findById(1L, OrderSummary::class.java)
val full: Order? = orderRepository.findById(1L, Order::class.java)
```

## EntityGraph (N+1 Prevention)

```kotlin
@Entity
@NamedEntityGraph(
    name = "Order.withItems",
    attributeNodes = [NamedAttributeNode("items")]
)
class Order(/* ... */)

interface OrderRepository : JpaRepository<Order, Long> {

    @EntityGraph("Order.withItems")
    fun findWithItemsById(id: Long): Order?

    // Ad-hoc entity graph
    @EntityGraph(attributePaths = ["items", "items.product"])
    fun findWithItemsAndProductsByCustomerId(customerId: String): List<Order>

    // Override default method with entity graph
    @EntityGraph(attributePaths = ["items"])
    override fun findAll(pageable: Pageable): Page<Order>
}
```

## Auditing

### Configuration

```kotlin
@Configuration
@EnableJpaAuditing
class JpaAuditingConfig {

    @Bean
    fun auditorProvider(): AuditorAware<String> =
        AuditorAware {
            Optional.ofNullable(SecurityContextHolder.getContext().authentication)
                .map { it.name }
        }
}
```

### Auditable Base Entity

```kotlin
@MappedSuperclass
@EntityListeners(AuditingEntityListener::class)
abstract class AuditableEntity(
    @CreatedDate
    @Column(nullable = false, updatable = false)
    var createdAt: Instant = Instant.now(),

    @LastModifiedDate
    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @CreatedBy
    @Column(updatable = false)
    var createdBy: String? = null,

    @LastModifiedBy
    var updatedBy: String? = null
)

@Entity
@Table(name = "orders")
class Order(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,
    val customerId: String,
    val totalAmount: BigDecimal
) : AuditableEntity()
```

## Pagination

```kotlin
@GetMapping
fun listOrders(
    @RequestParam(defaultValue = "0") page: Int,
    @RequestParam(defaultValue = "20") size: Int,
    @RequestParam(defaultValue = "createdAt,desc") sort: String
): Page<OrderResponse> {
    val pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"))
    return orderRepository.findAll(pageable).map { it.toResponse() }
}
```

### Slice for Infinite Scroll

```kotlin
interface OrderRepository : JpaRepository<Order, Long> {
    fun findByCustomerId(customerId: String, pageable: Pageable): Slice<Order>
}
```

## Custom Repository Implementation

```kotlin
interface OrderRepositoryCustom {
    fun findOrdersWithComplexCriteria(filter: ComplexFilter): List<Order>
}

class OrderRepositoryCustomImpl(
    private val entityManager: EntityManager
) : OrderRepositoryCustom {

    override fun findOrdersWithComplexCriteria(filter: ComplexFilter): List<Order> {
        val cb = entityManager.criteriaBuilder
        val query = cb.createQuery(Order::class.java)
        val root = query.from(Order::class.java)

        val predicates = mutableListOf<Predicate>()
        filter.customerId?.let { predicates.add(cb.equal(root.get<String>("customerId"), it)) }
        filter.statuses?.let { predicates.add(root.get<OrderStatus>("status").`in`(it)) }

        query.where(*predicates.toTypedArray())
        query.orderBy(cb.desc(root.get<Instant>("createdAt")))

        return entityManager.createQuery(query)
            .setMaxResults(filter.limit)
            .resultList
    }
}

// Combine with standard repository
interface OrderRepository : JpaRepository<Order, Long>,
    JpaSpecificationExecutor<Order>,
    OrderRepositoryCustom
```

## Transaction Management

```kotlin
@Service
class OrderService(
    private val orderRepository: OrderRepository,
    private val inventoryService: InventoryService,
    private val paymentService: PaymentService
) {

    @Transactional
    fun createOrder(request: CreateOrderRequest): OrderResponse {
        val order = orderRepository.save(request.toEntity())
        inventoryService.reserve(order.items)
        paymentService.charge(order.customerId, order.totalAmount)
        return order.toResponse()
    }

    @Transactional(readOnly = true)
    fun findById(id: Long): OrderResponse? =
        orderRepository.findById(id).orElse(null)?.toResponse()

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun updateStatusIndependently(id: Long, status: OrderStatus) {
        orderRepository.findById(id).ifPresent { order ->
            order.status = status
            orderRepository.save(order)
        }
    }
}
```

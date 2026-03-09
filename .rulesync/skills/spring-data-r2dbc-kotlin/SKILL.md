---
name: spring-data-r2dbc-kotlin
description: "Kotlin implementation patterns for Spring Data R2DBC. Use with `spring-data-r2dbc` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Data R2DBC — Kotlin

Prerequisites: load `spring-data-r2dbc` skill for foundational concepts.

## Entity Mapping

```kotlin
@Table("orders")
data class Order(
    @Id
    val id: Long? = null,
    val customerId: String,
    val status: OrderStatus = OrderStatus.CREATED,
    val totalAmount: BigDecimal,
    val notes: String? = null,
    @CreatedDate
    val createdAt: Instant? = null,
    @LastModifiedDate
    val updatedAt: Instant? = null
)

@Table("order_items")
data class OrderItem(
    @Id
    val id: Long? = null,
    val orderId: Long,
    val productId: String,
    val quantity: Int,
    val unitPrice: BigDecimal
)
```

## Reactive Repositories (Coroutine Repository)

```kotlin
interface OrderRepository : CoroutineCrudRepository<Order, Long> {

    fun findByCustomerId(customerId: String): Flow<Order>

    fun findByStatus(status: OrderStatus): Flow<Order>

    suspend fun findByCustomerIdAndStatus(customerId: String, status: OrderStatus): Order?

    @Query("SELECT * FROM orders WHERE status = :status ORDER BY created_at DESC LIMIT :limit")
    fun findRecentByStatus(status: OrderStatus, limit: Int): Flow<Order>

    @Query("SELECT * FROM orders WHERE total_amount > :minAmount")
    fun findByMinAmount(minAmount: BigDecimal): Flow<Order>

    @Modifying
    @Query("UPDATE orders SET status = :status WHERE id = :id")
    suspend fun updateStatus(id: Long, status: OrderStatus): Int

    @Modifying
    @Query("DELETE FROM orders WHERE status = 'CANCELLED' AND created_at < :before")
    suspend fun deleteOldCancelled(before: Instant): Int
}
```

## DatabaseClient for Complex Queries

```kotlin
@Repository
class OrderCustomRepository(
    private val databaseClient: DatabaseClient
) {

    suspend fun findWithItems(orderId: Long): OrderWithItems? {
        val order = databaseClient.sql("SELECT * FROM orders WHERE id = :id")
            .bind("id", orderId)
            .map { row, _ ->
                Order(
                    id = row.get("id", java.lang.Long::class.java)?.toLong(),
                    customerId = row.get("customer_id", String::class.java)!!,
                    status = OrderStatus.valueOf(row.get("status", String::class.java)!!),
                    totalAmount = row.get("total_amount", BigDecimal::class.java)!!
                )
            }
            .awaitOneOrNull() ?: return null

        val items = databaseClient.sql("SELECT * FROM order_items WHERE order_id = :orderId")
            .bind("orderId", orderId)
            .map { row, _ ->
                OrderItem(
                    id = row.get("id", java.lang.Long::class.java)?.toLong(),
                    orderId = row.get("order_id", java.lang.Long::class.java)!!.toLong(),
                    productId = row.get("product_id", String::class.java)!!,
                    quantity = row.get("quantity", Integer::class.java)!!.toInt(),
                    unitPrice = row.get("unit_price", BigDecimal::class.java)!!
                )
            }
            .flow()
            .toList()

        return OrderWithItems(order = order, items = items)
    }

    fun searchOrders(filter: OrderFilter): Flow<Order> {
        val conditions = mutableListOf<String>()
        val bindings = mutableMapOf<String, Any>()

        filter.customerId?.let {
            conditions.add("customer_id = :customerId")
            bindings["customerId"] = it
        }
        filter.status?.let {
            conditions.add("status = :status")
            bindings["status"] = it.name
        }
        filter.minAmount?.let {
            conditions.add("total_amount >= :minAmount")
            bindings["minAmount"] = it
        }

        val where = if (conditions.isNotEmpty()) "WHERE ${conditions.joinToString(" AND ")}" else ""
        val sql = "SELECT * FROM orders $where ORDER BY created_at DESC LIMIT :limit OFFSET :offset"
        bindings["limit"] = filter.size
        bindings["offset"] = filter.page * filter.size

        var spec = databaseClient.sql(sql)
        bindings.forEach { (key, value) -> spec = spec.bind(key, value) }

        return spec.map { row, _ -> mapToOrder(row) }.flow()
    }
}
```

## Transaction Management

```kotlin
@Service
class OrderService(
    private val orderRepository: OrderRepository,
    private val orderItemRepository: OrderItemRepository,
    private val transactionalOperator: TransactionalOperator
) {

    // Declarative transactions with @Transactional
    @Transactional
    suspend fun createOrder(request: CreateOrderRequest): OrderResponse {
        val order = orderRepository.save(
            Order(customerId = request.customerId, totalAmount = request.totalAmount)
        )
        val items = request.items.map { item ->
            orderItemRepository.save(
                OrderItem(
                    orderId = order.id!!,
                    productId = item.productId,
                    quantity = item.quantity,
                    unitPrice = item.unitPrice
                )
            )
        }
        return OrderResponse(order = order, items = items)
    }

    // Programmatic transactions
    suspend fun transferOrder(fromId: Long, toCustomerId: String): Order {
        return transactionalOperator.executeAndAwait { status ->
            val order = orderRepository.findById(fromId)
                ?: throw EntityNotFoundException("Order $fromId not found")
            val updated = order.copy(customerId = toCustomerId)
            orderRepository.save(updated)
        }!!
    }
}
```

## R2DBC Auditing

```kotlin
@Configuration
@EnableR2dbcAuditing
class R2dbcAuditConfig {

    @Bean
    fun auditorProvider(): ReactiveAuditorAware<String> =
        ReactiveAuditorAware {
            ReactiveSecurityContextHolder.getContext()
                .map { it.authentication.name }
                .defaultIfEmpty("system")
        }
}
```

## Testing Reactive Repositories

```kotlin
@DataR2dbcTest
@Import(R2dbcAuditConfig::class)
class OrderRepositoryTest {

    @Autowired
    private lateinit var orderRepository: OrderRepository

    @Autowired
    private lateinit var databaseClient: DatabaseClient

    @BeforeEach
    fun setup() = runBlocking {
        databaseClient.sql("DELETE FROM order_items").await()
        databaseClient.sql("DELETE FROM orders").await()
    }

    @Test
    fun `should save and find order`() = runBlocking {
        val order = Order(
            customerId = "cust-1",
            totalAmount = BigDecimal("99.99"),
            status = OrderStatus.CREATED
        )

        val saved = orderRepository.save(order)
        assertNotNull(saved.id)

        val found = orderRepository.findById(saved.id!!)
        assertNotNull(found)
        assertEquals("cust-1", found!!.customerId)
        assertEquals(BigDecimal("99.99"), found.totalAmount)
    }

    @Test
    fun `should find orders by status`() = runBlocking {
        orderRepository.save(Order(customerId = "c1", totalAmount = BigDecimal("10"), status = OrderStatus.CREATED))
        orderRepository.save(Order(customerId = "c2", totalAmount = BigDecimal("20"), status = OrderStatus.CONFIRMED))
        orderRepository.save(Order(customerId = "c3", totalAmount = BigDecimal("30"), status = OrderStatus.CREATED))

        val created = orderRepository.findByStatus(OrderStatus.CREATED).toList()
        assertEquals(2, created.size)
    }
}
```

---
name: spring-batch
description: "Spring Batch: foundational concepts — job/step design, chunk processing, readers/writers/processors, scheduling"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Batch

This skill provides foundational concepts. For implementation examples, use `spring-batch-kotlin` or `spring-batch-java` skill.

Comprehensive guide for Spring Batch: job and step design, chunk-oriented processing, built-in readers/writers, error handling, and
scheduling.

## Core Concepts

- **Job**: A complete batch process (e.g., "daily order export")
- **Step**: A single phase within a Job (e.g., "read orders → transform → write CSV")
- **Chunk**: A group of items processed together in a single transaction
- **ItemReader**: Reads data from a source
- **ItemProcessor**: Transforms/validates data
- **ItemWriter**: Writes processed data to a destination

## Job and Step Configuration

A Job consists of one or more Steps. Each Step can be chunk-oriented (reader → processor → writer) or tasklet-based (single operation).
Steps support fault tolerance via skip and retry policies.

## Built-In Readers

### JdbcCursorItemReader

Reads from a database using a JDBC cursor. Suitable for large datasets — streams rows one by one without loading all into memory.

### JpaPagingItemReader

Reads from a database using JPA pagination. Loads one page at a time.

### FlatFileItemReader (CSV)

Reads from flat files (CSV, TSV, fixed-width). Supports header skipping, custom delimiters, and field mapping.

## ItemProcessor

Transforms or filters items. Return `null` from `process()` to skip an item.

### Composite Processor

Chains multiple processors using `CompositeItemProcessor`. Delegates execute in order.

## Built-In Writers

### JdbcBatchItemWriter

Writes items to a database using JDBC batch operations. Supports named parameters via `beanMapped()` or `columnMapped()`.

### FlatFileItemWriter (CSV)

Writes items to flat files. Supports header/footer callbacks and custom delimiters.

### JpaItemWriter

Writes items using JPA `EntityManager.merge()`.

### Composite Writer

Chains multiple writers using `CompositeItemWriter`. All delegates write the same items.

## Job Parameters and Execution Context

- **JobParameters**: Immutable parameters passed at job launch time. Access via `@Value("#{jobParameters['key']}")` with `@StepScope`.
- **ExecutionContext**: Mutable key-value store for sharing data between steps or across restarts.

## Step Flow: Sequential, Conditional, Parallel

### Conditional Flow

Use `.on("STATUS").to(step)` to define conditional transitions based on step exit status.

### Parallel Steps

Use `FlowBuilder.split()` with `AsyncTaskExecutor` to run steps in parallel.

## Partitioning

Split a step's workload across multiple threads using a `Partitioner`. Each partition gets its own `ExecutionContext` with range
parameters (e.g., minId/maxId). Configure `gridSize` for number of partitions.

## Error Handling

### Skip Policy

Configure skippable exceptions and skip limits. Use `SkipListener` to log skipped items for observability.

### Retry Policy

Configure retryable exceptions and retry limits. Useful for transient errors (deadlocks, optimistic locking).

## Job Scheduling

Jobs can be launched via `@Scheduled`, external schedulers (cron, Kubernetes CronJob), or REST endpoints using `JobLauncher`.

## Testing Batch Jobs

Use `@SpringBatchTest` for `JobLauncherTestUtils` and `JobRepositoryTestUtils`. Test individual steps with `launchStep()` for isolation.

## Best Practices

1. **Choose appropriate chunk size** — 100-1000 items, balance memory vs transaction overhead
2. **Use @StepScope** for late-binding of job parameters
3. **Configure skip and retry** — always handle expected errors gracefully
4. **Use partitioning** for large datasets to enable parallel processing
5. **Monitor with actuator** — expose batch job metrics
6. **Test individual steps** — use `launchStep()` for isolated testing
7. **Idempotent jobs** — design jobs to be safely re-runnable
8. **Clean up job metadata** — purge old executions from repository tables
9. **Use Tasklet** for simple steps (file cleanup, notifications)
10. **Log skip/retry events** — implement SkipListener for observability

---
name: spring-batch-java
description: "Java implementation patterns for Spring Batch. Use with `spring-batch` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# Spring Batch — Java

Prerequisites: load `spring-batch` skill for foundational concepts.

## Job and Step Configuration

```java
@Configuration
public class OrderExportJobConfig {

    private final JobRepository jobRepository;
    private final PlatformTransactionManager transactionManager;

    public OrderExportJobConfig(JobRepository jobRepository,
                                 PlatformTransactionManager transactionManager) {
        this.jobRepository = jobRepository;
        this.transactionManager = transactionManager;
    }

    @Bean
    public Job orderExportJob(Step exportStep, Step cleanupStep) {
        return new JobBuilder("orderExportJob", jobRepository)
            .start(exportStep)
            .next(cleanupStep)
            .listener(jobExecutionListener())
            .build();
    }

    @Bean
    public Step exportStep(ItemReader<Order> reader,
                           ItemProcessor<Order, OrderCsvRecord> processor,
                           ItemWriter<OrderCsvRecord> writer) {
        return new StepBuilder("exportStep", jobRepository)
            .<Order, OrderCsvRecord>chunk(100, transactionManager)
            .reader(reader)
            .processor(processor)
            .writer(writer)
            .faultTolerant()
            .skipLimit(10)
            .skip(FlatFileParseException.class)
            .retryLimit(3)
            .retry(DeadlockLoserDataAccessException.class)
            .build();
    }
}
```

## Built-In Readers

<!-- TODO: Add Java equivalent for JdbcCursorItemReader -->

<!-- TODO: Add Java equivalent for JpaPagingItemReader -->

<!-- TODO: Add Java equivalent for FlatFileItemReader (CSV) -->

## ItemProcessor

<!-- TODO: Add Java equivalent for ItemProcessor -->

<!-- TODO: Add Java equivalent for Composite Processor -->

## Built-In Writers

<!-- TODO: Add Java equivalent for JdbcBatchItemWriter -->

<!-- TODO: Add Java equivalent for FlatFileItemWriter (CSV) -->

<!-- TODO: Add Java equivalent for JpaItemWriter -->

<!-- TODO: Add Java equivalent for Composite Writer -->

## Job Parameters and Execution Context

<!-- TODO: Add Java equivalent for Job Parameters and Execution Context -->

## Step Flow: Sequential, Conditional, Parallel

<!-- TODO: Add Java equivalent for Conditional Flow -->

<!-- TODO: Add Java equivalent for Parallel Steps -->

## Partitioning

<!-- TODO: Add Java equivalent for Partitioning -->

## Error Handling

### Skip Policy

<!-- TODO: Add Java equivalent for Skip Policy -->

### Retry Policy

<!-- TODO: Add Java equivalent for Retry Policy -->

## Job Scheduling

<!-- TODO: Add Java equivalent for Job Scheduling with @Scheduled -->

## Testing Batch Jobs

<!-- TODO: Add Java equivalent for Testing Batch Jobs -->

---
name: jooq
description: "jOOQ: foundational concepts — code generation, typesafe queries, transactions, integration with JPA"
targets: ["claudecode"]
claudecode:
  model: sonnet
---

# jOOQ Reference

This skill provides foundational concepts. For implementation examples, use `jooq-kotlin` or `jooq-java` skill.

## Code Generation

### Gradle Plugin Setup

```kotlin
// build.gradle.kts
plugins {
    id("nu.studer.jooq") version "9.0"
}

dependencies {
    jooqGenerator("org.postgresql:postgresql:42.7.3")
}

jooq {
    version.set("3.19.6")
    configurations {
        create("main") {
            jooqConfiguration.apply {
                jdbc.apply {
                    driver = "org.postgresql.Driver"
                    url = "jdbc:postgresql://localhost:5432/mydb"
                    user = "postgres"
                    password = "postgres"
                }
                generator.apply {
                    name = "org.jooq.codegen.KotlinGenerator" // or JavaGenerator
                    database.apply {
                        name = "org.jooq.meta.postgres.PostgresDatabase"
                        inputSchema = "public"
                        excludes = "flyway_schema_history"
                    }
                    generate.apply {
                        isDeprecated = false
                        isRecords = true
                        isPojos = true
                        isImmutablePojos = true
                        isFluentSetters = true
                        isDaos = true
                        isKotlinNotNullPojoAttributes = true
                        isKotlinNotNullRecordAttributes = true
                    }
                    target.apply {
                        packageName = "com.example.generated.jooq"
                        directory = "build/generated-src/jooq/main"
                    }
                }
            }
        }
    }
}
```

### Maven Plugin Setup

```xml
<plugin>
    <groupId>org.jooq</groupId>
    <artifactId>jooq-codegen-maven</artifactId>
    <version>3.19.6</version>
    <executions>
        <execution>
            <goals><goal>generate</goal></goals>
        </execution>
    </executions>
    <configuration>
        <jdbc>
            <driver>org.postgresql.Driver</driver>
            <url>jdbc:postgresql://localhost:5432/mydb</url>
            <user>postgres</user>
            <password>postgres</password>
        </jdbc>
        <generator>
            <database>
                <name>org.jooq.meta.postgres.PostgresDatabase</name>
                <inputSchema>public</inputSchema>
            </database>
            <target>
                <packageName>com.example.generated.jooq</packageName>
            </target>
        </generator>
    </configuration>
</plugin>
```

## Common Condition Methods

```
USERS.EMAIL.eq("value")                // =
USERS.EMAIL.ne("value")                // !=
USERS.AGE.gt(18)                       // >
USERS.AGE.ge(18)                       // >=
USERS.AGE.lt(65)                       // <
USERS.AGE.between(18, 65)             // BETWEEN
USERS.EMAIL.like("%@example.com")      // LIKE
USERS.EMAIL.likeIgnoreCase("%test%")   // ILIKE
USERS.STATUS.in_(Status.ACTIVE, Status.PENDING) // IN
USERS.DELETED_AT.isNull                // IS NULL
USERS.DELETED_AT.isNotNull             // IS NOT NULL
```

## jOOQ Alongside JPA (Read/Write Split)

Use jOOQ for complex reads, JPA for writes. Inject both `DSLContext` (jOOQ) and JPA repositories into services.

## Transaction Management

### With jOOQ API

Use `dsl.transactionResult { config -> ... }` for jOOQ-managed transactions.

### With Spring @Transactional

Use Spring's `@Transactional` annotation — jOOQ participates in the Spring-managed transaction automatically when configured with Spring's
`DataSource`.

---
name: flyway-kotlin
description: "Kotlin implementation patterns for Flyway. Use with `flyway` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: haiku
---

# Flyway — Kotlin

Prerequisites: load `flyway` skill for foundational concepts.

## Java/Kotlin Callbacks

```kotlin
@Component
class AfterMigrateCallback : Callback {
    override fun supports(event: Event, context: Context): Boolean =
        event == Event.AFTER_MIGRATE

    override fun canHandleInTransaction(event: Event, context: Context): Boolean = true

    override fun handle(event: Event, context: Context) {
        // Custom logic after migration
        context.connection.createStatement().use { stmt ->
            stmt.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY mv_user_stats")
        }
    }

    override fun getCallbackName(): String = "afterMigrateCallback"
}
```

## Java-Based Migrations

For complex migrations that need procedural logic:

```kotlin
// V4__migrate_user_data.kt
package db.migration

import org.flywaydb.core.api.migration.BaseJavaMigration
import org.flywaydb.core.api.migration.Context

class V4__migrate_user_data : BaseJavaMigration() {
    override fun migrate(context: Context) {
        context.connection.createStatement().use { stmt ->
            val rs = stmt.executeQuery("SELECT id, full_name FROM users WHERE first_name IS NULL")
            val update = context.connection.prepareStatement(
                "UPDATE users SET first_name = ?, last_name = ? WHERE id = ?"
            )
            while (rs.next()) {
                val parts = rs.getString("full_name").split(" ", limit = 2)
                update.setString(1, parts[0])
                update.setString(2, parts.getOrElse(1) { "" })
                update.setLong(3, rs.getLong("id"))
                update.addBatch()
            }
            update.executeBatch()
        }
    }
}
```

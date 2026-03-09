---
name: flyway-java
description: "Java implementation patterns for Flyway. Use with `flyway` skill for foundational concepts."
targets: ["claudecode"]
claudecode:
  model: haiku
---

# Flyway — Java

Prerequisites: load `flyway` skill for foundational concepts.

## Java Callbacks

```java
@Component
public class AfterMigrateCallback implements Callback {
    @Override
    public boolean supports(Event event, Context context) {
        return event == Event.AFTER_MIGRATE;
    }

    @Override
    public boolean canHandleInTransaction(Event event, Context context) {
        return true;
    }

    @Override
    public void handle(Event event, Context context) {
        try (var stmt = context.getConnection().createStatement()) {
            stmt.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY mv_user_stats");
        } catch (SQLException e) {
            throw new RuntimeException("Failed to refresh materialized view", e);
        }
    }

    @Override
    public String getCallbackName() {
        return "afterMigrateCallback";
    }
}
```

## Java-Based Migrations

For complex migrations that need procedural logic:

```java
// V4__migrate_user_data.java
package db.migration;

import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;
import java.sql.*;

public class V4__migrate_user_data extends BaseJavaMigration {
    @Override
    public void migrate(Context context) throws Exception {
        try (Statement stmt = context.getConnection().createStatement()) {
            ResultSet rs = stmt.executeQuery(
                "SELECT id, full_name FROM users WHERE first_name IS NULL"
            );
            PreparedStatement update = context.getConnection().prepareStatement(
                "UPDATE users SET first_name = ?, last_name = ? WHERE id = ?"
            );
            while (rs.next()) {
                String[] parts = rs.getString("full_name").split(" ", 2);
                update.setString(1, parts[0]);
                update.setString(2, parts.length > 1 ? parts[1] : "");
                update.setLong(3, rs.getLong("id"));
                update.addBatch();
            }
            update.executeBatch();
        }
    }
}
```

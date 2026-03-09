---
name: database-migrations
description: "Database migration best practices for schema changes, data migrations, rollbacks, and zero-downtime deployments across PostgreSQL, MySQL, and JVM tools (Flyway, Liquibase, JPA/Hibernate)."
targets: ["claudecode"]
claudecode:
  model: opus
  allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
---

# Database Migration Patterns

Safe, reversible database schema changes for production systems.

## When to Activate

- Creating or altering database tables
- Adding/removing columns or indexes
- Running data migrations (backfill, transform)
- Planning zero-downtime schema changes
- Setting up migration tooling for a new project

## Core Principles

1. **Every change is a migration** -- never alter production databases manually
2. **Migrations are forward-only in production** -- rollbacks use new forward migrations
3. **Schema and data migrations are separate** -- never mix DDL and DML in one migration
4. **Test migrations against production-sized data** -- a migration that works on 100 rows may lock on 10M
5. **Migrations are immutable once deployed** -- never edit a migration that has run in production

## Migration Safety Checklist

Before applying any migration:

- [ ] Migration has both UP and DOWN (or is explicitly marked irreversible)
- [ ] No full table locks on large tables (use concurrent operations)
- [ ] New columns have defaults or are nullable (never add NOT NULL without default)
- [ ] Indexes created concurrently (not inline with CREATE TABLE for existing tables)
- [ ] Data backfill is a separate migration from schema change
- [ ] Tested against a copy of production data
- [ ] Rollback plan documented

## PostgreSQL Patterns

### Adding a Column Safely

```sql
-- GOOD: Nullable column, no lock
ALTER TABLE users ADD COLUMN avatar_url TEXT;

-- GOOD: Column with default (Postgres 11+ is instant, no rewrite)
ALTER TABLE users ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;

-- BAD: NOT NULL without default on existing table (requires full rewrite)
ALTER TABLE users ADD COLUMN role TEXT NOT NULL;
-- This locks the table and rewrites every row
```

### Adding an Index Without Downtime

```sql
-- BAD: Blocks writes on large tables
CREATE INDEX idx_users_email ON users (email);

-- GOOD: Non-blocking, allows concurrent writes
CREATE INDEX CONCURRENTLY idx_users_email ON users (email);

-- Note: CONCURRENTLY cannot run inside a transaction block
-- Both Flyway and Liquibase need special handling for this
```

### Renaming a Column (Zero-Downtime)

Never rename directly in production. Use the expand-contract pattern:

```sql
-- Step 1: Add new column (migration V3__add_display_name.sql)
ALTER TABLE users ADD COLUMN display_name TEXT;

-- Step 2: Backfill data (migration V4__backfill_display_name.sql)
UPDATE users SET display_name = username WHERE display_name IS NULL;

-- Step 3: Update application code to read/write both columns
-- Deploy application changes

-- Step 4: Stop writing to old column, drop it (migration V5__drop_username.sql)
ALTER TABLE users DROP COLUMN username;
```

### Removing a Column Safely

```sql
-- Step 1: Remove all application references to the column (update JPA entity)
-- Step 2: Deploy application without the column reference
-- Step 3: Drop column in next migration
ALTER TABLE orders DROP COLUMN legacy_status;
```

### Large Data Migrations

```sql
-- BAD: Updates all rows in one transaction (locks table)
UPDATE users SET normalized_email = LOWER(email);

-- GOOD: Batch update with progress
DO $$
DECLARE
  batch_size INT := 10000;
  rows_updated INT;
BEGIN
  LOOP
    UPDATE users
    SET normalized_email = LOWER(email)
    WHERE id IN (
      SELECT id FROM users
      WHERE normalized_email IS NULL
      LIMIT batch_size
      FOR UPDATE SKIP LOCKED
    );
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    RAISE NOTICE 'Updated % rows', rows_updated;
    EXIT WHEN rows_updated = 0;
    COMMIT;
  END LOOP;
END $$;
```

## Flyway (Kotlin/Java)

### Workflow

```bash
# Migrations auto-apply on Spring Boot startup (default behavior)
# Or run manually via Gradle
./gradlew flywayMigrate

# Show migration status
./gradlew flywayInfo

# Repair failed migration metadata
./gradlew flywayRepair

# Clean database (dev only)
./gradlew flywayClean
```

### Migration File Naming

```
src/main/resources/db/migration/
├── V1__create_users_table.sql
├── V2__create_markets_table.sql
├── V3__add_user_avatar.sql
├── V4__backfill_display_name.sql      # Data migration
├── V5__add_email_index.sql
└── R__refresh_market_stats_view.sql   # Repeatable migration
```

### SQL Migration Example

```sql
-- V1__create_users_table.sql
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       VARCHAR(255) NOT NULL UNIQUE,
    name        VARCHAR(255),
    avatar_url  TEXT,
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_active ON users (is_active) WHERE is_active = true;
```

### Java-Based Migration (for complex logic)

```kotlin
import org.flywaydb.core.api.migration.BaseJavaMigration
import org.flywaydb.core.api.migration.Context

class V6__BackfillNormalizedEmails : BaseJavaMigration() {

    override fun migrate(context: Context) {
        val batchSize = 10_000
        val connection = context.connection

        while (true) {
            val statement = connection.prepareStatement(
                """
                UPDATE users
                SET normalized_email = LOWER(email)
                WHERE id IN (
                    SELECT id FROM users
                    WHERE normalized_email IS NULL
                    LIMIT ?
                    FOR UPDATE SKIP LOCKED
                )
            """
            )
            statement.setInt(1, batchSize)
            val updated = statement.executeUpdate()

            if (updated == 0) break
        }
    }
}
```

### Concurrent Index in Flyway

```sql
-- V5__add_email_index.sql
-- Flyway wraps migrations in a transaction by default.
-- CONCURRENTLY cannot run inside a transaction.
-- Use the Flyway configuration or annotation to disable transaction for this migration.

-- In application.yml: spring.flyway.out-of-order=true
-- Or use callback / Java migration with manual connection management

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email ON users (email);
```

### Flyway Configuration (application.yml)

```yaml
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true
    out-of-order: false
    validate-on-migrate: true
```

## Liquibase (Kotlin/Java)

### Workflow

```bash
# Migrations auto-apply on Spring Boot startup (default behavior)
# Or run manually via Gradle
./gradlew liquibaseUpdate

# Show migration status
./gradlew liquibaseStatus

# Rollback last N changesets
./gradlew liquibaseRollbackCount -PliquibaseCommandValue=1

# Generate diff from JPA entities
./gradlew liquibaseDiffChangelog
```

### Changelog Structure

```
src/main/resources/db/changelog/
├── db.changelog-master.yaml          # Master changelog
├── changes/
│   ├── 001-create-users-table.yaml
│   ├── 002-create-markets-table.yaml
│   ├── 003-add-user-avatar.yaml
│   └── 004-backfill-display-name.yaml
```

### Master Changelog

```yaml
# db.changelog-master.yaml
databaseChangeLog:
  - includeAll:
      path: db/changelog/changes/
      relativeToChangelogFile: false
```

### Changeset Example (YAML)

```yaml
# 001-create-users-table.yaml
databaseChangeLog:
  - changeSet:
      id: 001-create-users-table
      author: developer
      changes:
        - createTable:
            tableName: users
            columns:
              - column:
                  name: id
                  type: UUID
                  defaultValueComputed: gen_random_uuid()
                  constraints:
                    primaryKey: true
              - column:
                  name: email
                  type: VARCHAR(255)
                  constraints:
                    nullable: false
                    unique: true
              - column:
                  name: name
                  type: VARCHAR(255)
              - column:
                  name: is_active
                  type: BOOLEAN
                  defaultValueBoolean: true
                  constraints:
                    nullable: false
              - column:
                  name: created_at
                  type: TIMESTAMP WITH TIME ZONE
                  defaultValueComputed: now()
                  constraints:
                    nullable: false
        - createIndex:
            indexName: idx_users_email
            tableName: users
            columns:
              - column:
                  name: email
      rollback:
        - dropTable:
            tableName: users
```

### Changeset with Raw SQL

```yaml
# 004-backfill-display-name.yaml
databaseChangeLog:
  - changeSet:
      id: 004-backfill-display-name
      author: developer
      changes:
        - sql:
            sql: UPDATE users SET display_name = username WHERE display_name IS NULL
      rollback:
        - sql:
            sql: UPDATE users SET display_name = NULL WHERE display_name = username
```

### Liquibase Configuration (application.yml)

```yaml
spring:
  liquibase:
    enabled: true
    change-log: classpath:db/changelog/db.changelog-master.yaml
```

## JPA/Hibernate Integration

### Entity Mapping

```kotlin
@Entity
@Table(name = "users")
data class User(
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    val id: String? = null,

    @Column(nullable = false, unique = true)
    val email: String,

    @Column
    val name: String? = null,

    @Column(name = "avatar_url")
    val avatarUrl: String? = null,

    @Column(name = "is_active", nullable = false)
    val isActive: Boolean = true,

    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: Instant = Instant.now(),

    @Column(name = "updated_at", nullable = false)
    val updatedAt: Instant = Instant.now()
)
```

### Hibernate DDL Configuration

```yaml
# NEVER use ddl-auto in production -- always use Flyway or Liquibase
spring:
  jpa:
    hibernate:
      ddl-auto: validate  # validate schema matches entities; create/update only in dev
    show-sql: false
    properties:
      hibernate:
        format_sql: true
        jdbc:
          batch_size: 50
        order_inserts: true
        order_updates: true
```

## Zero-Downtime Migration Strategy

For critical production changes, follow the expand-contract pattern:

```
Phase 1: EXPAND
  - Add new column/table (nullable or with default)
  - Deploy: app writes to BOTH old and new
  - Backfill existing data

Phase 2: MIGRATE
  - Deploy: app reads from NEW, writes to BOTH
  - Verify data consistency

Phase 3: CONTRACT
  - Deploy: app only uses NEW
  - Drop old column/table in separate migration
```

### Timeline Example

```
Day 1: Migration adds new_status column (nullable)
Day 1: Deploy app v2 -- writes to both status and new_status
Day 2: Run backfill migration for existing rows
Day 3: Deploy app v3 -- reads from new_status only
Day 7: Migration drops old status column
```

## Anti-Patterns

| Anti-Pattern                         | Why It Fails                         | Better Approach                             |
|--------------------------------------|--------------------------------------|---------------------------------------------|
| Manual SQL in production             | No audit trail, unrepeatable         | Always use migration files                  |
| Editing deployed migrations          | Causes drift between environments    | Create new migration instead                |
| NOT NULL without default             | Locks table, rewrites all rows       | Add nullable, backfill, then add constraint |
| Inline index on large table          | Blocks writes during build           | CREATE INDEX CONCURRENTLY                   |
| Schema + data in one migration       | Hard to rollback, long transactions  | Separate migrations                         |
| Dropping column before removing code | Application errors on missing column | Remove code first, drop column next deploy  |
| Using hibernate ddl-auto in prod     | Unpredictable schema changes         | Use Flyway/Liquibase, set ddl-auto=validate |

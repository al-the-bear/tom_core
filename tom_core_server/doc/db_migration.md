# Database Migration Module

Versioned, file-driven schema migrations. A directory tree describes the
migrations for each data source and schema; the orchestrator
(`TomDbMigrations`) walks it and applies each script through a
database-specific migrator (`TomDbMigrator`), which records what it applied so
re-runs are idempotent and edits to past migrations are detected. A MariaDB
implementation (`MariadbMigrationAdaptor`) is provided.

## Table of Contents

- [Overview](#overview)
- [The Directory Layout](#the-directory-layout)
- [Running Migrations](#running-migrations)
- [Adaptor Discovery](#adaptor-discovery)
- [The MariaDB Adaptor](#the-mariadb-adaptor)
- [Idempotency and Stability](#idempotency-and-stability)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomDbMigrations` | class | The orchestrator; `migrateDatabases(directory)` drives a whole tree |
| `TomDbMigrator` | abstract class | The per-database migrator contract (`initializeMigration` / `applyMigration` / `reset`) |
| `TomDbMigrationAdaptor` | annotation | Binds a migrator to a data-source type for reflection discovery |
| `TomDbMigrationException` | class | Orchestration / discovery / parsing failures |
| `MariadbMigrationAdaptor` | reflected class | The MariaDB migrator |
| `MariadbMigrationException` | class | MariaDB migration failures |
| `TomDbVersion` | reflected class | One row of a `<schema>_versioning` table |

## The Directory Layout

Migrations live in a directory tree keyed by **data-source name** then
**schema name**, with one file per migration:

```text
migrations/
  main/                     # a registered TomDataSourceInfo name
    app/                    # a schema in that data source
      [1]-create_users.sql
      [2]-add_orders.sql
  reporting/
    analytics/
      [1]-create_facts.sql
```

Each file name must match `[<numeric version>]-<description>` followed by any
extension, where the description is letters and underscores
(`[a-zA-Z_]+`). A name that does not match aborts the run with a
`TomDbMigrationException`. Within a schema, files are applied in **ascending
name order**.

## Running Migrations

```dart
// Data sources must already be registered (see the datasources module):
await TomDataSourceInfo.initializeDatasourceInfo(config);

// Apply every pending migration under the tree:
await TomDbMigrations.migrateDatabases('migrations');
```

For each `<datasourceName>/<schemaName>` the orchestrator:

1. resolves the `TomDataSourceInfo` by name (missing → exception);
2. resolves the migrator for the data source's `type` (missing → exception);
3. calls `reset()` (a migrator instance may serve several data sources of the
   same type);
4. calls `initializeMigration(dsi, schemaName)` once per schema;
5. parses each file's version/description and calls
   `applyMigration(dsi, schemaName, version, description, sql)`.

## Adaptor Discovery

A migrator registers by annotating its class with
`@TomDbMigrationAdaptor("<type>")` and `@tomReflector`.
`TomDbMigrations` scans `tomReflector.annotatedClasses` on first use, builds one
migrator per type, and rejects duplicate or non-conforming registrations with a
`TomDbMigrationException`. The `<type>` must match the data source's
`TomDataSourceInfo.type`.

## The MariaDB Adaptor

`MariadbMigrationAdaptor` keeps a `<schema>_versioning` table per schema:

| Column | Meaning |
| ------ | ------- |
| `installedRank` | auto-increment insertion order (primary key) |
| `version` | the migration version number |
| `description` | the description from the file name |
| `script` | the full migration script text |
| `checksum` | the script's `hashCode` (as text), to detect later edits |
| `installedBy` / `installedOn` | who/when (DB defaults) |
| `executionTimeMs` | how long the script took |
| `success` | `1` on success, `0` on failure |

`initializeMigration` creates the table if absent and loads the applied
versions (mapped onto `TomDbVersion`). `applyMigration` then, per script:

- if the `version` is already recorded, verifies the **description and checksum
  match** (a mismatch means a past migration was edited → failure) and skips;
- otherwise runs the script, records the outcome — including a failed script
  with `success = 0` — and rethrows on failure.

## Idempotency and Stability

Recording every applied version makes re-running `migrateDatabases` safe: only
genuinely new versions execute. Recording the **checksum** enforces that
historical migrations stay immutable — editing an already-applied script is a
hard error rather than a silent divergence between environments.

> The MariaDB adaptor records each migration's `script` and `description` into
> the versioning table by interpolating them directly into an `INSERT`.
> Migration scripts are developer-authored build artifacts, not user input; the
> general literal-escaping follow-up tracked for the datasources module applies
> here too.

## Core Components

- **`TomDbMigrations`** — the orchestrator and reflection-based adaptor
  discovery; `migrateDatabases`.
- **`TomDbMigrator`** (+ the `TomDbMigrationAdaptor` annotation) — the migrator
  contract.
- **`MariadbMigrationAdaptor`** and **`TomDbVersion`** — the MariaDB
  implementation and its versioning-row type.
- **`TomDbMigrationException` / `MariadbMigrationException`** — the error types.

## Dependencies

- `tom_core_kernel` — `tomReflector` (adaptor discovery, row mapping), `tomLog`.
- The datasources module — `TomDataSourceInfo` (named data sources) and its
  `executeCommand` / `executeQuery`.
- The object-persistence module — `TomDbTable` / `TomDbColumn` on `TomDbVersion`.
- `path` — migration-file name parsing.
- `dart:io` — walking the migration directory tree.

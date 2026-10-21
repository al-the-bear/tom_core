# db_migration

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Flyway-style versioned schema migrations, **and** the convergence checks that
prove a migration chain builds the shape the rest of the code expects.

The two halves answer different questions and are used at different times.
The **engine** answers *bring this database up to date*: `TomDbMigrations` walks
a directory tree of scripts laid out per data source and schema, a
`TomDbMigrator` applies the pending ones, and each is recorded as a
`TomDbVersion` row (version, description, checksum, who/when, duration, success)
so re-runs are idempotent and edited scripts are caught by checksum.
`TomSqlMigrationAdaptor` is that history, written once for every SQL database;
`MariadbMigrationAdaptor` (MariaDB/MySQL) and `PostgresMigrationAdaptor`
(PostgreSQL) differ only in how a script runs — statement by statement with a
failure recorded on MariaDB, which does not roll DDL back, and in one
transaction with the version row on PostgreSQL, which does. Every run takes the
database's **migration lock**, so replicas starting together apply each script
once; a failed record is **repaired** — removed or marked resolved — by an
operator, from code or with `--repair-migration` / `--repair-action`. A
migration with a **down script** beside it (`[3]-add_column.down.sql` for
`[3]-add_column.sql`) can be **rolled back**: the migrations applied above a
version are undone newest first, from code or with
`--rollback-migrations=<datasource>/<schema>/<version>`. The two-phase
data-source types (`mariadb_xa`, `postgresql_xa`) migrate through the adaptor of
their database.

The **checks** answer *does this chain build what we say it builds* — and answer
it **with no database at all**, by replaying the chain's DDL text into an
in-memory schema model and diffing that against what the entity annotations and
the framework table descriptors declare. That is a requirement rather than an
optimisation: a check that needs a live server cannot gate code generation.

## Key types

### The migration engine

| Type | What it is |
| ---- | ---------- |
| `TomDbMigrations` | The orchestrator. A static entry point that holds no scripts: it discovers migrators by reflection and drives a directory tree of them, each data source under its migration lock. `withMigrationLock` holds the lock around a wider run (a per-tenant walk); `repair` and `repairFromArgs` resolve a failed migration; `rollback`, `rollbackDataSource` and `rollbackFromArgs` undo applied ones with their down scripts, which `collectDownMigrationFiles` collects and `collectMigrationFiles` skips. |
| `TomDbMigrator` | The contract a database-specific migrator implements. One instance serves one `(data source, schema)` pair at a time. `withMigrationLock` runs one migration run per database at a time; `repair` resolves a failed record without running a script; `rollback` undoes the migrations applied above a version with their down scripts. |
| `TomMigrationRepair` | What `repair` does with a failed record: `remove` it, so the next run applies the migration again, or `markResolved`, so the next run skips it. |
| `TomDbMigrationAdaptor` | A `const` annotation binding a migrator class to a data-source **type** string (e.g. `"mariadb"`), and to the further types in `alsoServes` (e.g. `"mariadb_xa"`), so reflection can find it. It adapts nothing itself. |
| `TomMigrationScript` | One migration's description, up script and down script, as a rollback reads them from the tree. |
| `TomMigrationFileName` | A parsed migration file name: `version`, `description`, and an optional environment tag. |
| `TomSqlMigrationAdaptor` | The database-neutral SQL `TomDbMigrator`: the `<schema>_versioning` history, checksum stability (`checksumOf`), rebinding per schema, the refusal of a history that records a failed script and its repair, the checks of a rollback, and the migration lock — the data source's session lock named `migrationLockName(databaseName)`, waited for up to `lockWait`. |
| `MariadbMigrationAdaptor` | The MariaDB/MySQL migrator, registered for the `"mariadb"` and `"mariadb_xa"` types. Records a failed script with `success = 0`; a failed down script leaves what it ran done and the migration recorded. |
| `PostgresMigrationAdaptor` | The PostgreSQL migrator, registered for the `"postgresql"` and `"postgresql_xa"` types. Runs a script and its version row — or a down script and the deletion of its record — in one transaction, so a failure leaves nothing behind. |
| `TomDbVersion` | One row of a `<schema>_versioning` table — the record of a single applied (or attempted) migration. |
| `TomMigrationRun` · `TomMigrationRunState` | `TomDbMigrations.lastRun`: where the process's most recent `migrateDatabases` call stands — `notRun`, `running`, `succeeded` or `failed` with its error. The framework readiness check on `GET /ready` answers not ready while it is `running` or `failed`. |
| `TomDbMigrationException` | Thrown when a migration cannot be discovered, parsed or applied. |
| `TomSqlMigrationException` | The SQL migrators' failure type, including a changed description or checksum on an already-applied version. |
| `MariadbMigrationException` · `PostgresMigrationException` | Its two subtypes; their keys are prefixed `mariadb_migration…` and `postgres_migration…`. |

### The convergence checks

| Type | What it is |
| ---- | ---------- |
| `TomSchemaConvergenceCheck` | The CE-DB ↔ CE-MG validator: proof that a schema's migration chain builds exactly the shape its entity model declares. |
| `TomEntitySchemaReader` | The **expected** side — reduces `@TomDbTable` / `@TomDbColumn` to a `TomSchemaModel` through reflection. |
| `TomSchemaConvergenceReport` | The outcome of one `<datasource>/<schema>` check. |
| `TomSchemaDivergence` | One disagreement between the entity model and the migration chain. |
| `TomSchemaDivergenceKind` | What kind of disagreement a `TomSchemaDivergence` reports — including `nullableVersionColumn`, a `@TomVersion` column the chain leaves nullable, which no versioned save could ever match. |
| `TomFrameworkSchemaCheck` | The framework-table guard: compares framework-owned table descriptors against everything else that spells their columns. |
| `TomInformationSchemaColumnRow` | One `information_schema.COLUMNS` row, as the live half of the framework check reads it. |

### The shared schema model and DDL replay

Both checks compare through one vocabulary, so a difference is a real
disagreement rather than two spellings of the same thing.

| Type | What it is |
| ---- | ---------- |
| `TomSchemaDdlReader` | The **actual** side — builds the schema a migration chain cumulatively produces, without touching a database. |
| `TomMigrationArtifact` | One artifact as the reader consumes it: the basename the chain orders it by, and the SQL it contains. Deliberately not a `File`. |
| `TomDdlReplayResult` | The outcome of replaying a chain. |
| `TomDdlReplayError` | Something in the chain that could not be replayed. Reported, never thrown, so one bad statement cannot hide everything after it. |
| `TomSchemaModel` | A whole schema — the tables of one `<datasource>/<schema>` pair. Immutable. |
| `TomSchemaTable` | One table of a `TomSchemaModel`. |
| `TomSchemaColumn` | One column of a `TomSchemaTable`. |
| `TomSchemaBuilder` | The mutable accumulator both sides build their `TomSchemaModel` through, so the two halves cannot drift apart in shape. |
| `TomSqlTypeFamilyCompatibility` | How tolerantly the two sides compare their `TomSqlTypeFamily` classifications. The families are the dialect's vocabulary; the tolerance is the check's policy. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

void main() {
  // The version table tracks what has already been applied.
  final record = TomDbVersion()
    ..version = 1
    ..description = 'create todo tables'
    ..success = 1;

  print(record.version);     // 1
  print(record.description); // create todo tables
}
```

See [`doc/db_migration.md`](../../../../doc/db_migration.md) for the full
treatment: the directory layout and file-name grammar — including the two
classes of file a schema directory may hold without being migrations, which is
everything a machine put there and nothing a developer did — environment tags,
adaptor discovery, idempotency and checksum stability, the whole
schema-convergence chapter, the migration lock, the repair of a failed
migration, down scripts and the rollback, and what returns a `Future` and why. The connection-free surface runs
in `example/db_migration/db_migration_example.dart` and
`example/db_migration/db_migration_repair_example.dart`;
`test/db_migration_test.dart` and `test/schema_convergence_test.dart` cover the
two halves, `test/db_migration_db_test.dart` covers the adaptor and
`test/db_migration_lock_db_test.dart` the lock and the repair and
`test/db_migration_rollback_db_test.dart` the rollback of whichever database the DB suites run against — MariaDB through `tool/run_db_tests.sh`, PostgreSQL
through `tool/run_db_tests_postgres.sh`.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

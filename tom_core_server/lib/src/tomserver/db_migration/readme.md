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
`MariadbMigrationAdaptor` is the MariaDB/MySQL implementation.

The **checks** answer *does this chain build what we say it builds* — and answer
it **with no database at all**, by replaying the chain's DDL text into an
in-memory schema model and diffing that against what the entity annotations and
the framework table descriptors declare. That is a requirement rather than an
optimisation: a check that needs a live server cannot gate code generation.

## Key types

### The migration engine

| Type | What it is |
| ---- | ---------- |
| `TomDbMigrations` | The orchestrator. A static entry point that holds no scripts: it discovers migrators by reflection and drives a directory tree of them. |
| `TomDbMigrator` | The contract a database-specific migrator implements. One instance serves one `(data source, schema)` pair at a time. |
| `TomDbMigrationAdaptor` | A `const` annotation binding a migrator class to a data-source **type** string (e.g. `"mariadb"`) so reflection can find it. It adapts nothing itself. |
| `TomMigrationFileName` | A parsed migration file name: `version`, `description`, and an optional environment tag. |
| `MariadbMigrationAdaptor` | The MariaDB/MySQL `TomDbMigrator`, registered for the `"mariadb"` type. |
| `TomDbVersion` | One row of a `<schema>_versioning` table — the record of a single applied (or attempted) migration. |
| `TomDbMigrationException` | Thrown when a migration cannot be discovered, parsed or applied. |
| `MariadbMigrationException` | Thrown for MariaDB-specific migration failures, including a changed description or checksum on an already-applied version. |

### The convergence checks

| Type | What it is |
| ---- | ---------- |
| `TomSchemaConvergenceCheck` | The CE-DB ↔ CE-MG validator: proof that a schema's migration chain builds exactly the shape its entity model declares. |
| `TomEntitySchemaReader` | The **expected** side — reduces `@TomDbTable` / `@TomDbColumn` to a `TomSchemaModel` through reflection. |
| `TomSchemaConvergenceReport` | The outcome of one `<datasource>/<schema>` check. |
| `TomSchemaDivergence` | One disagreement between the entity model and the migration chain. |
| `TomSchemaDivergenceKind` | What kind of disagreement a `TomSchemaDivergence` reports. |
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
| `TomSqlLexer` | The lexing primitives every consumer of raw SQL text in this module shares — quoted runs, comments, and the module's one `splitStatements`. |

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
schema-convergence chapter, and what returns a `Future` and why. The connection-free surface runs
in `example/db_migration/db_migration_example.dart`; `test/db_migration_test.dart`
and `test/schema_convergence_test.dart` cover the two halves, and
`test/db_migration_db_test.dart` covers the MariaDB adaptor against a live
server.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

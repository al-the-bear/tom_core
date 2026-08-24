# db_migration

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Flyway-style, versioned schema migrations. `TomDbMigrations` holds the ordered
set of migration scripts; a `TomDbMigrator` applies the pending ones and records
each as a `TomDbVersion` row (version, description, checksum, who/when, success)
so re-runs are idempotent and edited scripts are detected by checksum. The
`MariadbMigrationAdaptor` is the MariaDB/MySQL implementation.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomDbMigrations` | The ordered collection of migration scripts to apply. |
| `TomDbMigrator` | Abstract migrator: applies pending migrations and reconciles the version table. |
| `MariadbMigrationAdaptor` | MariaDB/MySQL implementation of `TomDbMigrator`. |
| `TomDbVersion` | A persisted migration record: `installedRank`, `version`, `description`, `script`, `checksum`, `installedBy`, `installedOn`, `executionTimeMs`, `success`. |
| `TomDbMigrationAdaptor` | Adapts a datasource for migration execution. |

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

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

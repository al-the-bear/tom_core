# Tom Core Server API Reference: Database Migration Module

Versioned, file-driven schema migrations. A directory tree describes the
migrations for each data source and schema; the orchestrator (`TomDbMigrations`)
walks it and applies each script through a database-specific migrator
(`TomDbMigrator`), which records what it applied so re-runs are idempotent and
edits to past migrations are detected. A MariaDB implementation
(`MariadbMigrationAdaptor`) is provided.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomDbMigrations](#tomdbmigrations)
  - [TomDbMigrator](#tomdbmigrator)
  - [TomDbMigrationAdaptor](#tomdbmigrationadaptor)
  - [TomMigrationFileName](#tommigrationfilename)
  - [MariadbMigrationAdaptor](#mariadbmigrationadaptor)
  - [TomDbVersion](#tomdbversion)
  - [Exceptions](#exceptions)
    - [TomDbMigrationException](#tomdbmigrationexception)
    - [MariadbMigrationException](#mariadbmigrationexception)
- [Enums](#enums)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/db_migration/db_migration.dart`,
`lib/src/tomserver/db_migration/mariadb_migration_adapter.dart`.

`TomDbMigrations` is the orchestrator: `migrateDatabases(directory)` walks
`<directory>/<datasourceName>/<schemaName>/` and applies every
`[<version>]-<description>[@<env>…].<ext>` file in ascending version order
through the data source's migrator, resolved from its `type` via the
`@TomDbMigrationAdaptor` annotation. `TomDbMigrator` is the per-database migrator
contract (`initializeMigration` / `applyMigration` / `reset`). A migration file
name is parsed into a `TomMigrationFileName` (version, description, optional
environment tag). The MariaDB implementation, `MariadbMigrationAdaptor`,
maintains a `<schema>_versioning` table whose rows are `TomDbVersion` records,
verifying description/checksum stability of already-applied versions.

## Class Hierarchy

```
TomDbMigrator  (abstract)
    └── MariadbMigrationAdaptor

TomDbMigrations
TomDbMigrationAdaptor  (annotation)
TomMigrationFileName
TomDbVersion

TomServerException  (server)
    ├── TomDbMigrationException
    └── MariadbMigrationException
```

## Classes

### TomDbMigrations

The migration orchestrator: discovers migrator adaptors by reflection and drives
migrations from a directory tree matching the configured data sources and their
schemas.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `parseMigrationFileName` | `static TomMigrationFileName parseMigrationFileName(String basename)` | Parses a migration file's basename (without extension) into version, description and optional environment tag; throws `TomDbMigrationException` on a malformed name. |
| `orderMigrationNames` | `static List<({String basename, TomMigrationFileName parsed})> orderMigrationNames(Iterable<String> basenames)` | Parses `basenames` and returns them ordered by ascending numeric version, each paired with its parsed name. |
| `resolveActiveEnvironment` | `static String resolveActiveEnvironment()` | The environment name migrations are filtered against, via `TomRuntime` (falling back to the production-safe default). |
| `selectForEnvironment` | `static List<({String basename, TomMigrationFileName parsed})> selectForEnvironment(Iterable<({String basename, TomMigrationFileName parsed})> ordered, String environmentName)` | Filters an ordered migration list to those applying in `environmentName`, preserving order. |
| `migrateDatabases` | `static Future<void> migrateDatabases(String directory)` | Runs all pending migrations under `directory`; throws `TomDbMigrationException` on a missing data source/migrator, malformed name, or failed script. |

### TomDbMigrator

The contract a database-specific migrator implements: prepares version tracking,
applies (or verifies) each migration script in ascending version order, and
clears per-run state.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `initializeMigration` | `Future<int> initializeMigration(TomDataSourceInfo dsi, String schemaName)` | Prepares version tracking for `schemaName` in `dsi` and returns the earliest recorded version (implementation-defined sentinel when none). |
| `applyMigration` | `Future<void> applyMigration(TomDataSourceInfo dsi, String schemaName, int version, String description, String sql)` | Applies — or verifies, if already applied — the identified migration. |
| `reset` | `void reset()` | Clears per-run state so this migrator can be reused for another data source of the same type. |

### TomDbMigrationAdaptor

Annotation marking a `TomDbMigrator` implementation as the migrator for a named
data-source `type`. Migrators are discovered by scanning `tomReflector`.

#### Constructors

```dart
const TomDbMigrationAdaptor(String type)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `type` | `String` | The data-source type this migrator serves (matches `TomDataSourceInfo.type`). |

### TomMigrationFileName

A migration file name parsed into its numeric `version`, `description` and
optional `environments` tag. An untagged migration applies in every environment;
a tagged one applies only when the active environment name is listed.

#### Constructors

```dart
const TomMigrationFileName(
  int version,
  String description, [
  List<String> environments = const [],
])
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `version` | `int` | The numeric version from the `[<version>]` prefix. |
| `description` | `String` | The `<description>` part (letters and underscores). |
| `environments` | `List<String>` | The environment names this migration is tagged for; empty means untagged (applies everywhere). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `appliesInEnvironment` | `bool appliesInEnvironment(String environmentName)` | Whether this migration applies when the active environment is `environmentName`. |

### MariadbMigrationAdaptor

The MariaDB `TomDbMigrator` (registered for the `"mariadb"` type). Per schema it
maintains a `<schema>_versioning` table recording every applied migration and
verifies description/checksum stability of already-applied versions.

- **Implements:** `TomDbMigrator`

#### Constructors

```dart
MariadbMigrationAdaptor()
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `splitSqlStatements` | `static List<String> splitSqlStatements(String sql)` | Splits a multi-statement migration script into individual statements on unquoted, uncommented semicolons. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `versions` | `List<TomDbVersion>` | The migrations already applied to the current schema, loaded by `initializeMigration` and appended to as `applyMigration` runs. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `reset` | `void reset()` | *(override)* Clears the initialised flag and applied-versions list. |
| `applyMigration` | `Future<void> applyMigration(TomDataSourceInfo dsi, String schemaName, int version, String description, String sql)` | *(override)* Skips (after verifying) an applied version, otherwise runs the script and records the outcome. |
| `initializeMigration` | `Future<int> initializeMigration(TomDataSourceInfo dsi, String schemaName)` | *(override)* Creates the versioning table if absent, loads applied versions, and returns the earliest version (or `-1`). |

### TomDbVersion

One row of a `<schema>_versioning` table: the record of a single applied (or
attempted) migration. Mapped from query results by reflection
(`@tomReflector` / `@TomDbTable` / `@TomDbColumn`).

#### Constructors

```dart
TomDbVersion()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `installedRank` | `int` | Auto-incrementing insertion order (primary key). |
| `version` | `int` | The migration version number. |
| `description` | `String` | The migration description (from the file name). |
| `script` | `String` | The full migration script text. |
| `checksum` | `String` | The script's `hashCode`, stored as a string, used to detect later edits. |
| `installedBy` | `String` | The database user that applied the migration. |
| `installedOn` | `DateTime` | When the migration was applied. |
| `success` | `int` | `1` if the migration script succeeded, `0` if it failed. |

### Exceptions

#### TomDbMigrationException

Thrown when a database migration cannot be discovered, parsed, or applied
(missing adaptor or data source, a malformed migration filename, a failed
script, …).

- **Extends:** `TomServerException`

#### Constructors

```dart
TomDbMigrationException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? stack,
  Object? rootException,
  bool autoLog = false,
})
```

#### MariadbMigrationException

Thrown for MariaDB migration failures (versioning-table creation, version query,
a changed description/checksum for an already-applied version, or a failed
migration script).

- **Extends:** `TomServerException`

#### Constructors

```dart
MariadbMigrationException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? stack,
  Object? rootException,
  bool autoLog = false,
})
```

## Enums

None — this module exposes no public enums.

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `frameworkOwnedTables` | `List<TomFrameworkTable> frameworkOwnedTables({String jobRun = defaultJobRunTable, String lease = defaultLeaseTable, String schedulerNode = defaultSchedulerNodeTable, String blobManifest = defaultBlobManifestTable, String blobChunk = defaultBlobChunkTable, String auditTrail = defaultAuditTrailTable, String oauthState = defaultOAuthStateTable})` | Every table the framework owns, at the names it uses when nothing overrides them — so that "all of them" is a thing a caller can name rather than a list each caller assembles and each forgets to extend. A deployment that renames a table passes the corresponding argument. The dependency runs one way: this module reads the descriptors of `scheduling/`, `file_storage/`, `audit/` and `authentication/`, and none of them reads back, so the scheduler runs without loading a migration. |

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
  - [TomSqlLexer](#tomsqllexer)
  - [TomDbVersion](#tomdbversion)
  - [Exceptions](#exceptions)
    - [TomDbMigrationException](#tomdbmigrationexception)
    - [MariadbMigrationException](#mariadbmigrationexception)
- [Enums](#enums)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/db_migration/db_migration.dart`,
`lib/src/tomserver/db_migration/mariadb_migration_adapter.dart`,
`lib/src/tomserver/db_migration/sql_lexer.dart`.

`TomDbMigrations` is the orchestrator: `migrateDatabases(directory)` walks
`<directory>/<datasourceName>/<schemaName>/` and applies every
`[<version>]-<description>[@<env>…].<ext>` file in ascending version order
through the data source's migrator, resolved from its `type` via the
`@TomDbMigrationAdaptor` annotation; `migrateDataSource(migrator, dsi, dir, env)`
is the per-data-source half of that walk, taking the migrator as a parameter.
`TomDbMigrator` is the per-database migrator contract (`initializeMigration` /
`applyMigration` / `reset`), and a migrator serves **one `(data source, schema)`
pair at a time** — the orchestrator resets and re-initialises it once per schema,
because each schema keeps its own applied-version history. A migration file
name is parsed into a `TomMigrationFileName` (version, description, optional
environment tag). The MariaDB implementation, `MariadbMigrationAdaptor`,
maintains a `<schema>_versioning` table whose rows are `TomDbVersion` records,
verifying description/checksum stability of already-applied versions. The
checksum is a content digest (`MariadbMigrationAdaptor.checksumOf`), because it
is written by one process and read back by every later one; a stored value that
is not such a digest (`isWellFormedChecksum`) is reported as unreadable rather
than as an edit.

Both the applier and the DDL reader walk raw SQL text, and both do it through
`TomSqlLexer` — the module's single quote/comment scanner and its single
statement splitter.

## Class Hierarchy

```
TomDbMigrator  (abstract)
    └── MariadbMigrationAdaptor

TomDbMigrations
TomDbMigrationAdaptor  (annotation)
TomMigrationFileName
TomSqlLexer
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
| `migrateDataSource` | `static Future<void> migrateDataSource(TomDbMigrator migrator, TomDataSourceInfo dsInfo, Directory dataSourceDirectory, String environmentName)` | Applies every schema under `dataSourceDirectory` through `migrator`, resetting and re-initialising it **once per schema**. Split out of `migrateDatabases` so the walk can be driven with a caller-supplied migrator — the reflection-scanned registry is not injectable. |

### TomDbMigrator

The contract a database-specific migrator implements: binds to a
`(data source, schema)` pair and prepares its version tracking, applies (or
verifies) each migration script in ascending version order, and releases the
binding. The unit of state is the **pair**, not the data source — one data
source routinely holds several schemas, each with its own applied-version
history.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `initializeMigration` | `Future<int> initializeMigration(TomDataSourceInfo dsi, String schemaName)` | Binds this migrator to the `(dsi, schemaName)` pair — **rebinding**, so the loaded version state is replaced, not accumulated — prepares that pair's version tracking, and returns the earliest recorded version (implementation-defined sentinel when none). |
| `applyMigration` | `Future<void> applyMigration(TomDataSourceInfo dsi, String schemaName, int version, String description, String sql)` | Applies — or verifies, if already applied — the identified migration. |
| `reset` | `void reset()` | Releases the current `(data source, schema)` binding and its applied-version state, so this instance can serve the next pair. |

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

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `versions` | `List<TomDbVersion>` | The migrations already applied to the schema this instance is bound to — a snapshot taken by `initializeMigration`, **not** extended as `applyMigration` runs (an applied migration is written to the table, not added here). |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `checksumOf` | `static String checksumOf(String sql)` | The checksum recorded for a migration script: the lowercase hex SHA-256 of its UTF-8 bytes. Public because it *is* the definition of the stored value — a test pins it to a constant, and an operator repairing a row needs to compute what the adaptor expects. It replaced `String.hashCode`, which Dart guarantees only within one run. |
| `isWellFormedChecksum` | `static bool isWellFormedChecksum(String checksum)` | Whether `checksum` is a value this adaptor could have written — exactly 64 lowercase hex characters, anchored. The counterpart of `checksumOf`: a stored value that fails it is not evidence of an edit but of a row written by something else (the column's `DEFAULT ''`, an older schema, a hand-written repair), and is reported as `checksum_unreadable` rather than `checksum_mismatch`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `reset` | `void reset()` | *(override)* Drops the `(data source, schema)` binding and the applied-versions list. |
| `applyMigration` | `Future<void> applyMigration(TomDataSourceInfo dsi, String schemaName, int version, String description, String sql)` | *(override)* Throws `mariadb_migration.apply_migration.not_initialized_for_schema` unless bound to this exact pair; then skips (after verifying) an applied version, otherwise runs the script and records the outcome. Verification of an applied version fails with `description_mismatch`, `checksum_unreadable` (the stored value is not a digest this adaptor could have written) or `checksum_mismatch` (it is a digest, but a different one) — each message naming the data source, schema and version, since one instance walks them all. |
| `initializeMigration` | `Future<int> initializeMigration(TomDataSourceInfo dsi, String schemaName)` | *(override)* Rebinds to `(dsi, schemaName)`, creating the versioning table if absent and **replacing** `versions` with that schema's history; returns the earliest version (or `-1`). |

### TomSqlLexer

The shared SQL lexing primitives — the one place this module decides where a
quoted run ends and where one statement ends and the next begins. Both the
applier (`MariadbMigrationAdaptor.applyMigration`) and the reader
(`TomSchemaDdlReader`) are written on it, because a scan that disagrees with the
server does not fail loudly: it cuts a statement in half inside a string literal,
or swallows a closing quote and welds two statements into one.

Escaping is not uniform across the three quote characters, and the lexer
implements what MariaDB actually does under the default `sql_mode`
(`NO_BACKSLASH_ESCAPES` off):

| Quote | `''` doubling | `\'` backslash |
| ----- | ------------- | -------------- |
| `'` string literal | yes | yes |
| `"` string literal | yes | yes |
| `` ` `` identifier | yes | **no** |

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `quoteCharacters` | `String` | The three characters that open a quoted run: `'`, `"` and `` ` ``. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `endOfQuotedRun` | `static int endOfQuotedRun(String sql, int openIndex)` | The index of the closing quote of the run opened at `openIndex`, or `sql.length - 1` when the run is never closed (reported, not thrown — this is a lexer, not a validator). |
| `endOfComment` | `static int endOfComment(String sql, int startIndex)` | The index of the last character of the comment starting at `startIndex`; a line comment ends before its newline, a block comment at its `*/`. |
| `commentOpensAt` | `static bool commentOpensAt(String sql, int index)` | Whether a comment opens at `index` — `--`, `#` or `/*`. Only meaningful outside a quoted run. |
| `splitStatements` | `static List<String> splitStatements(String sql)` | Splits `sql` into its statements on unquoted, uncommented semicolons, trimmed, dropping whitespace-only fragments. **Comments are preserved** — `/*!40101 … */` is executable, version-gated SQL, so dropping it would silently remove a statement. |

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
| `checksum` | `String` | The script's content digest — lowercase hex SHA-256, as produced by `MariadbMigrationAdaptor.checksumOf` — used to detect later edits. |
| `installedBy` | `String` | The database user that applied the migration. |
| `installedOn` | `DateTime` | When the migration was applied. |
| `executionTimeMs` | `int` | How long the script took, in milliseconds, as measured by `applyMigration`. Covers the script's statements only — the clock stops before this row is inserted — and a row recorded for a failed script carries the time spent before the failure. |
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

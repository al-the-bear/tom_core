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
  - [TomSchemaColumn](#tomschemacolumn)
  - [TomSchemaTable](#tomschematable)
  - [TomSchemaModel](#tomschemamodel)
  - [TomSchemaBuilder](#tomschemabuilder)
  - [TomMigrationArtifact](#tommigrationartifact)
  - [TomDdlReplayError](#tomddlreplayerror)
  - [TomDdlReplayResult](#tomddlreplayresult)
  - [TomSchemaDdlReader](#tomschemaddlreader)
  - [TomEntitySchemaReader](#tomentityschemareader)
  - [TomSchemaDivergence](#tomschemadivergence)
  - [TomSchemaConvergenceReport](#tomschemaconvergencereport)
  - [TomSchemaConvergenceCheck](#tomschemaconvergencecheck)
  - [TomFrameworkSchemaCheck](#tomframeworkschemacheck)
  - [TomInformationSchemaColumnRow](#tominformationschemacolumnrow)
  - [Exceptions](#exceptions)
    - [TomDbMigrationException](#tomdbmigrationexception)
    - [MariadbMigrationException](#mariadbmigrationexception)
- [Enums](#enums)
  - [TomSchemaDivergenceKind](#tomschemadivergencekind)
- [Extensions](#extensions)
  - [TomSqlTypeFamilyCompatibility](#tomsqltypefamilycompatibility)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources: `lib/src/tomserver/db_migration/db_migration.dart`,
`lib/src/tomserver/db_migration/framework_convergence.dart`,
`lib/src/tomserver/db_migration/mariadb_migration_adapter.dart`,
`lib/src/tomserver/db_migration/schema_convergence.dart`,
`lib/src/tomserver/db_migration/schema_ddl_reader.dart`,
`lib/src/tomserver/db_migration/schema_model.dart`,
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

The module's second half answers a different question: not *what has been
applied*, but *whether what the migrations describe still matches what the code
expects*. It is built on one vocabulary — a `TomSchemaModel` of
`TomSchemaTable`s of `TomSchemaColumn`s, assembled by a `TomSchemaBuilder` — and
that vocabulary has exactly **two producers**. `TomSchemaDdlReader.replay`
folds a list of `TomMigrationArtifact`s into the model the migration chain
describes, reporting anything it could not read as a `TomDdlReplayError` inside
a `TomDdlReplayResult` rather than throwing. `TomEntitySchemaReader.read` builds
the model the annotated entity classes expect. `TomSchemaConvergenceCheck` puts
the two side by side and reports each disagreement as a `TomSchemaDivergence`
(kind, table, column, origin) in a `TomSchemaConvergenceReport`.
`TomFrameworkSchemaCheck` is the same comparison for the tables the framework
itself owns, and adds the one variant that needs a connection —
`verifyLive`, which reads `information_schema.COLUMNS` into
`TomInformationSchemaColumnRow`s.

**A `Future` in this module means a database is involved.** Reading migration
files is synchronous throughout: `checkAll`, `checkSchema`, `readChain`,
`verify`, `replay`, `verifyChain` and `verifyRowTypes` all return their result
directly, and refuse directly. Only `migrateDatabases`, `migrateDataSource`,
`applyMigration`, `initializeMigration` and `verifyLive` are asynchronous.

## Class Hierarchy

```
TomDbMigrator  (abstract)
    └── MariadbMigrationAdaptor

TomDbMigrations
TomDbMigrationAdaptor  (annotation)
TomMigrationFileName
TomSqlLexer
TomDbVersion

schema vocabulary
    TomSchemaModel
        └── TomSchemaTable
            └── TomSchemaColumn
    TomSchemaBuilder        (mutable accumulator → TomSchemaModel)

producers of a model
    TomSchemaDdlReader      (migration chain → TomDdlReplayResult)
        TomMigrationArtifact
        TomDdlReplayResult
            └── TomDdlReplayError
    TomEntitySchemaReader   (annotated entities → model + divergences)

comparison
    TomSchemaConvergenceCheck   (migrations vs. entities)
    TomFrameworkSchemaCheck     (migrations/live vs. framework descriptors)
        TomInformationSchemaColumnRow
    TomSchemaConvergenceReport
        └── TomSchemaDivergence
            └── TomSchemaDivergenceKind  (enum)

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
| `requireMigrationsDirectory` | `static void requireMigrationsDirectory(Directory directory, String role)` | Asserts that `directory` — playing the role named by `role` — exists, throwing `db_migration.migration.migrations_directory_not_found` if it does not. A tree a tool is told to walk is an input, not content: absent, it means the configured path is wrong, and tolerating it makes both tools succeed vacuously (the engine reports migrations complete against an untouched database; `TomSchemaConvergenceCheck.checkAll` returns an empty report list no call site can tell apart from "every pair converged"). A relative path is reported with what it resolved to as well, since its usual cause is the right path read from the wrong working directory; an absolute one is not repeated. Shared with the convergence check so the two entry points cannot disagree about whether an absent tree is a failure. |
| `collectMigrationFiles` | `static Map<String, File> collectMigrationFiles(Iterable<FileSystemEntity> entries)` | Collects the files among `entries` keyed by basename without extension — the key everything downstream identifies a migration by — skipping non-file entries. Two files whose basenames collide (`[3]-add_index.sql` and `[3]-add_index.ddl`, or a stray `[3]-add_index.orig`) throw `db_migration.migration.duplicate_migration_basename` naming both paths in a stable order. Keeping whichever the directory listing yielded last was not a tie-break but a silent coin toss, and an editor backup ending in `.orig` strips to the same key as the `.sql` it backed up — so the losing file could be the one meant to run. Shared with `TomSchemaConvergenceCheck.readChain`, so the check cannot accept a tree the engine refuses. |
| `parseMigrationFileName` | `static TomMigrationFileName parseMigrationFileName(String basename)` | Parses a migration file's basename (without extension) into version, description and optional environment tag; throws `TomDbMigrationException` on a malformed name. |
| `orderMigrationNames` | `static List<({String basename, TomMigrationFileName parsed})> orderMigrationNames(Iterable<String> basenames)` | Parses `basenames` and returns them ordered by ascending numeric version, each paired with its parsed name. Two names claiming the **same version** throw `db_migration.migration.duplicate_migration_version`, naming both in a stable order. The version is the whole of a migration's recorded identity, so a pair sharing one applies twice on the first run — a migrator's applied-version list is an initialisation snapshot, so the second call cannot see the first — in an order the sort does not define, and leaves the versioning table holding two rows for one version; the next run matches the first of them against the other's script and reports a description/checksum mismatch, blaming an edit that never happened. Compared on the parsed integer, so `[1]` and `[001]` collide, and checked **before** environment selection, so a tagged and an untagged file cannot share a version either — a tag decides which of the pair runs *here*, not which row the shared history keeps, and a tree may not be valid on one box and broken on the next. Shared with `TomSchemaConvergenceCheck.readChain`, which has no environment to filter by at all. |
| `resolveActiveEnvironment` | `static String resolveActiveEnvironment()` | The environment name migrations are filtered against, via `TomRuntime` (falling back to the production-safe default). |
| `selectForEnvironment` | `static List<({String basename, TomMigrationFileName parsed})> selectForEnvironment(Iterable<({String basename, TomMigrationFileName parsed})> ordered, String environmentName)` | Filters an ordered migration list to those applying in `environmentName`, preserving order. |
| `migrateDatabases` | `static Future<void> migrateDatabases(String directory)` | Runs all pending migrations under `directory`; throws `TomDbMigrationException` on a missing data source/migrator, malformed name, or failed script. |
| `migrateDataSource` | `static Future<void> migrateDataSource(TomDbMigrator migrator, TomDataSourceInfo dsInfo, Directory dataSourceDirectory, String environmentName)` | Applies every schema under `dataSourceDirectory` through `migrator`, resetting and re-initialising it **once per schema**. Split out of `migrateDatabases` so the walk can be driven with a caller-supplied migrator — the reflection-scanned registry is not injectable. |
| `instantiateMigrator` | `static TomDbMigrator instantiateMigrator(Object? candidate, Object? Function() construct)` | Builds one scanned adaptor candidate, turning a throwing constructor or a class that does not implement `TomDbMigrator` into a `TomDbMigrationException` naming `candidate`. A constructor error and its trace are forwarded as the raised exception's **root cause**. Parameterised by `construct` rather than the reflected class, because the scan's registry is a global no test can populate. |

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
| `initializeMigration` | `Future<void> initializeMigration(TomDataSourceInfo dsi, String schemaName)` | Binds this migrator to the `(dsi, schemaName)` pair — **rebinding**, so the loaded version state is replaced, not accumulated — and prepares that pair's version tracking. Returns nothing: the applied-version history it loads is the useful output, and no single number stands for it, so representing it is left to the implementation (see `MariadbMigrationAdaptor.versions`). |
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
| `versions` | `List<TomDbVersion>` | The migrations already applied to the schema this instance is bound to — a snapshot taken by `initializeMigration`, **not** extended as `applyMigration` runs (an applied migration is written to the table, not added here). Ordered by **installation order, oldest first** (`installedRank`), which differs from version order whenever migrations were applied out of numeric order — ordinary once environment tags (C-16) are in play. Sort a copy by `version` if version order is what you need. |

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
| `initializeMigration` | `Future<void> initializeMigration(TomDataSourceInfo dsi, String schemaName)` | *(override)* Rebinds to `(dsi, schemaName)`, creating the versioning table if absent and **replacing** `versions` with that schema's history, read `ORDER BY installedRank`. `versions` is its whole output. |

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

### TomSchemaColumn

One column of a `TomSchemaTable`, in the dialect-neutral vocabulary both sides of
the convergence check are reduced to before they are compared.

#### Constructors

```dart
const TomSchemaColumn({
  required String name,
  required TomSqlTypeFamily family,
  required String declaredType,
  required String origin,
  bool nullable = true,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The column name as written on the side it was read from. Lookups are case-insensitive (`TomSchemaTable.column`); this field keeps the original spelling so a report names the column the way its author wrote it. |
| `family` | `TomSqlTypeFamily` | The type class this column is compared in — the only type information the diff looks at. |
| `declaredType` | `String` | The type as declared on the source side: a SQL type (`VARCHAR(255)`) for a column read from DDL, a Dart or `TomDbType` name for one derived from an entity. **Reported, never compared** — the two sides spell the same type differently by nature. |
| `nullable` | `bool` | Whether the column accepts `NULL`. Parsed from DDL and carried, but **not** part of the comparison: the entity side has no nullability declaration to compare against (every mapped field is Dart-nullable so an unsaved record can exist). Modelled anyway so a future entity-side declaration can turn the comparison on without re-parsing anything; defaults to `true` on the entity side, where it is unknown. |
| `origin` | `String` | Where this column came from — the migration artifact basename that last defined it, or the entity type name that declares it. This is the locality a divergence points at: "column `x` is missing from `app_items`" is only actionable together with "and `UserRecord` expects it". |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `renamedTo` | `TomSchemaColumn renamedTo(String name, String origin)` | A copy under a new `name`, attributed to `origin` — the replay of a `RENAME COLUMN`. |

### TomSchemaTable

One table of a `TomSchemaModel`.

#### Constructors

```dart
const TomSchemaTable({
  required String name,
  required Map<String, TomSchemaColumn> columns,
  required List<String> primaryKey,
  required String origin,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The table name as written on the side it was read from. |
| `columns` | `Map<String, TomSchemaColumn>` | The columns keyed by **lower-cased** name, in declaration order. Order is preserved through renames because column order is what a reader compares against the DDL by eye. |
| `primaryKey` | `List<String>` | The primary-key column names in key order; empty when none is declared. |
| `origin` | `String` | The migration artifact or entity type that created this table. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `column` | `TomSchemaColumn? column(String name)` | The column called `name`, case-insensitively, or `null`. |

### TomSchemaModel

A whole schema — the tables of one `<datasource>/<schema>` pair. The single
vocabulary the diff runs in: the entity model and the cumulative DDL of a
migration chain describe the same schema from two sides in two vocabularies, and
neither can be compared to the other directly.

#### Constructors

```dart
const TomSchemaModel(Map<String, TomSchemaTable> tables)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `tables` | `Map<String, TomSchemaTable>` | The schema's tables keyed by **lower-cased** name, in creation order. |

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `empty` | `TomSchemaModel` | An empty schema — what a datasource with no migrations replays to. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `table` | `TomSchemaTable? table(String name)` | The table called `name`, case-insensitively, or `null`. |

### TomSchemaBuilder

The mutable accumulator both sides build their `TomSchemaModel` through. The DDL
side needs mutation by construction — replaying a chain means applying `CREATE`,
then `ALTER`, then `DROP` to a schema that is only complete at the tip. Rather
than give `TomSchemaModel` mutating members nothing may call after the build, the
mutation lives here and the model comes out immutable. The entity side uses the
same builder, so both halves of the check are assembled through one API and
cannot drift apart in shape.

Every mutation is a **silent no-op on a table or column the builder does not
have**, never an error: `addColumn`, `dropColumn`, `renameColumn` and
`setPrimaryKey` against an unknown table all return with the model unchanged.
The builder accumulates; it never reports.

That is a division of labour, not leniency. Whether a statement operating on
something absent is a *defect* depends on the statement text — `DROP TABLE IF
EXISTS` on a table the chain never created is the guard doing its job, the same
drop without the guard is a chain defect worth reporting — and the builder is
handed parsed names and columns, never the SQL, so it is the one participant
that cannot tell those two apart. `TomSchemaDdlReader` can, and does: it asks
`hasTable` / `hasColumn` *before* mutating, and the answer decides whether it
records a `TomDdlReplayError`, not whether the call is safe to make.

Two consequences follow, and both are why the checking is not moved down here.
The reader collects its errors and keeps replaying, so one run reports every
divergence in a chain rather than only the first; a builder that threw would end
the replay at the earliest defect. And the entity side builds from
`information_schema` rows, where there is no chain to contradict and nothing to
report — a builder that demanded a pre-check would impose guards on a caller
that cannot fail that way.

#### Constructors

```dart
TomSchemaBuilder()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `tableNames` | `Iterable<String>` | *(read-only)* The table names currently in the builder, in creation order. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `hasTable` | `bool hasTable(String table)` | Whether a table called `table` exists (case-insensitively). |
| `hasColumn` | `bool hasColumn(String table, String column)` | Whether `table` exists and has a column called `column`. |
| `addTable` | `void addTable(String name, String origin)` | Creates an empty table called `name`, attributed to `origin`, replacing any table of that name. |
| `dropTable` | `void dropTable(String name)` | Removes `name` if present. |
| `renameTable` | `void renameTable(String from, String to)` | Renames table `from` to `to`; does nothing when `from` is absent. |
| `addColumn` | `void addColumn(String table, TomSchemaColumn column)` | Adds or replaces `column` on `table`; does nothing when `table` is absent. |
| `dropColumn` | `void dropColumn(String table, String column)` | Removes `column` from `table`; does nothing when either is absent. |
| `renameColumn` | `void renameColumn(String table, String from, String to, String origin)` | Renames column `from` to `to` on `table`, **preserving its position** and attributing the change to `origin`; does nothing when either is absent. |
| `setPrimaryKey` | `void setPrimaryKey(String table, List<String> columns)` | Declares `columns` as the primary key of `table`; does nothing when `table` is absent. |
| `build` | `TomSchemaModel build()` | Freezes the accumulated state into an immutable `TomSchemaModel`. **Every level is wrapped**, the table map included: a model whose tables could still be added to would let a consumer edit the very thing the check just compared. |

### TomMigrationArtifact

One migration artifact as the reader consumes it: the basename the chain orders
it by, and the SQL it contains. Deliberately **not** a `File` — the reader
replays a chain that has already been *read*, so it works the same over a
directory, over strings in a test, and over a generator's in-memory output.

#### Constructors

```dart
const TomMigrationArtifact(String basename, String sql)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `basename` | `String` | The artifact basename (`[004]-auth_two_factor_columns`), used as the locality every schema element is attributed to. |
| `sql` | `String` | The artifact's SQL body. |

### TomDdlReplayError

Something in the chain that could not be replayed — a statement that contradicts
the schema built so far, or one the reader cannot parse. A chain problem is
**reported, never thrown**: the point of the convergence check is to hand back a
complete picture of what is wrong, and a throw would stop at the first artifact
and hide everything after it.

#### Constructors

```dart
const TomDdlReplayError({
  required String artifact,
  required String message,
  required String statement,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `artifact` | `String` | The basename of the artifact whose statement failed. |
| `message` | `String` | What went wrong, phrased for the person who has to fix the artifact. |
| `statement` | `String` | The offending statement, truncated for reporting. |

### TomDdlReplayResult

The outcome of replaying a migration chain: the schema it produces together with
whatever could not be replayed on the way.

#### Constructors

```dart
const TomDdlReplayResult(TomSchemaModel schema, List<TomDdlReplayError> errors)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `schema` | `TomSchemaModel` | The schema the chain cumulatively produces. |
| `errors` | `List<TomDdlReplayError>` | Statements that could not be replayed, in chain order. |

### TomSchemaDdlReader

Builds the schema a migration chain cumulatively produces, **without touching a
database**. This is the *actual* side of the convergence check: it applies each
artifact's DDL to an in-memory `TomSchemaBuilder` in the order the migration
engine would, so the result is the shape a fresh database would have after
`TomDbMigrations.migrateDatabases`. It reads the same artifacts the engine reads
and changes nothing about how the engine behaves.

**What it understands.** `CREATE TABLE <name> (<column list>)` — the one
`CREATE TABLE` form that spells its columns out, which is the whole of what the
reader is for — plus `DROP TABLE`, `ALTER TABLE`
(`ADD`/`DROP`/`MODIFY`/`CHANGE`/`RENAME` of columns, `ADD PRIMARY KEY`,
`RENAME TO`), and the `IF [NOT] EXISTS` guards that make an artifact idempotent.
Statements that do not shape the schema (`INSERT`, `UPDATE`, `DELETE`, `SET`,
`CREATE INDEX`, `CREATE VIEW`, …) are recognised and skipped rather than
reported, because seed data and secondary indexes are legitimate migration
content the check has no opinion on.

**What the guards mean.** A statement that would fail against a live server is a
chain defect and is reported; the `IF [NOT] EXISTS` guard is what says the author
meant it conditionally. One rule, applied the same way in every direction — a
`DROP` that stayed quiet would let a mistyped table name replay clean here and
then reappear far downstream as a table the entity model has no entity for.

**What it does not.** Stored routines and anything using a `DELIMITER` override;
the `CREATE TABLE` forms that derive their columns from elsewhere (`AS SELECT …`,
`LIKE other`); and vendor extensions beyond the above.

**Rejection is atomic at the level of the statement form.** A `CREATE TABLE`
whose header carries anything between the table name and the column list is
rejected before the builder is touched, so an unmodelled form leaves no trace: a
table committed with a fabricated column list turns every column its entity
declares into a `missingColumn` divergence, a second wave of findings caused by
the parse failure rather than by any real disagreement. *Within* a genuine column
list the opposite applies deliberately — an unreadable entry is reported on its
own and the rest of the table survives.

#### Constructors

```dart
TomSchemaDdlReader(TomStandardSqlDialect dialect)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `dialect` | `TomStandardSqlDialect` | The dialect that classifies column types (`TomStandardSqlDialect.typeFamily`). |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `splitStatements` | `static List<String> splitStatements(String sql)` | The statements of `sql` with comments removed first — `TomSqlLexer.splitStatements(stripComments(sql))`. The composition differs from the lexer's own splitter, which preserves comments because it feeds a *sender*: `/*!40101 … */` is executable, version-gated SQL. |
| `stripComments` | `static String stripComments(String sql)` | Replaces every comment with whitespace — a line comment with its newline, a block comment with a space, so tokens on either side stay separated. Executable `/*! … */` blocks are stripped too, which is right for a parser reading structure and wrong for anything that sends the SQL on. |
| `splitTopLevel` | `static List<String> splitTopLevel(String text)` | Splits `text` on commas that are outside parentheses and outside quoted runs — the split a column list, a key list and an `ALTER` action list all need, and the one a naive `split(',')` gets wrong on `DECIMAL(10,2)`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `replay` | `TomDdlReplayResult replay(List<TomMigrationArtifact> chain)` | Replays `chain` in order into a `TomDdlReplayResult`, collecting every unreadable statement as a `TomDdlReplayError` instead of stopping at the first. |

### TomEntitySchemaReader

The *expected* side of the convergence check: the schema the annotated entity
classes describe, read straight out of the reflection metadata.

The comparison scope is bounded by what the annotations actually declare, and the
boundary is deliberate rather than provisional. **Compared** — table existence,
column existence, column type family, and the primary key. **Not compared,
because the entity model does not declare it** — length and precision, defaults,
`AUTO_INCREMENT`, unique keys, secondary indexes, foreign keys, charset,
collation and engine. **Not compared, because the entity side carries no usable
signal** — nullability. **Out of scope entirely** — seed data, generated
columns, partitioning and stored routines.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `discoverEntityTypes` | `static List<Type> discoverEntityTypes()` | Every `@TomDbTable`-annotated type registered with `tomReflector`. The check discovers entities the same way the rest of the persistence layer does, so a type the repository can load is a type the check can see. |
| `selectFor` | `static List<Type> selectFor(Iterable<Type> entityTypes, String datasource, String schema)` | The entity types that map into `datasource` / `schema`. An entity matches on `TomDbTable.datasource` — the same name the migration engine resolves its directory by; `TomDbTable.schema` narrows further when declared, and an entity that declares none belongs to the datasource's only schema. |
| `read` | `static ({TomSchemaModel schema, List<TomSchemaDivergence> divergences}) read(Iterable<Type> entityTypes)` | Builds the model `entityTypes` expect. The **first** entity to declare a table fixes its primary key; a later entity that disagrees yields a `conflictingEntityPrimaryKey` divergence and the first key is kept — a contradiction inside the entity model, reported before the migration chain is consulted at all. |
| `primaryKeyOf` | `static List<String> primaryKeyOf(TomTypePersistenceInfo info)` | The primary-key column names an entity declares, resolved in order of specificity: `@TomEntityId`-annotated columns, else the table's `idColumn`, else its `primaryKeyField`. |

### TomSchemaDivergence

One disagreement between the two sides of a convergence check — the unit a
`TomSchemaConvergenceReport` is a list of.

#### Constructors

```dart
const TomSchemaDivergence({
  required TomSchemaDivergenceKind kind,
  required String table,
  required String origin,
  required String message,
  String? column,
  bool isError = true,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `kind` | `TomSchemaDivergenceKind` | What kind of disagreement this is. |
| `table` | `String` | The table it concerns; empty for a chain-level error that belongs to no table. |
| `column` | `String?` | The column it concerns, or `null` for a table-level disagreement. |
| `origin` | `String` | Both localities, so the reader knows where each side's claim came from — typically `'<entity> vs <artifact>'`. |
| `message` | `String` | The finding phrased for whoever has to fix it, naming what each side declares. |
| `isError` | `bool` | Whether this fails the check. `false` marks the findings that are legitimately common — an unexpected table, an unmapped column. |
| `subject` | `String` | *(read-only)* What the divergence is about: `table`, or `table.column` when a column is named. |

### TomSchemaConvergenceReport

The outcome of checking one `<datasource>/<schema>` pair: what was compared, and
every way the two sides disagreed.

#### Constructors

```dart
const TomSchemaConvergenceReport({
  required String datasource,
  required String schema,
  required List<String> chain,
  required List<TomSchemaDivergence> divergences,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `String` | The datasource name the pair was read under. |
| `schema` | `String` | The schema name the pair was read under. |
| `chain` | `List<String>` | The artifact basenames the actual side was replayed from, in order — so a report says which migrations it saw, not merely that it saw some. `['information_schema']` for a live check. |
| `divergences` | `List<TomSchemaDivergence>` | Every disagreement found, errors and warnings together. |
| `errors` | `List<TomSchemaDivergence>` | *(read-only)* The divergences with `isError` set. |
| `warnings` | `List<TomSchemaDivergence>` | *(read-only)* The divergences without it. |
| `converged` | `bool` | *(read-only)* Whether `errors` is empty. Warnings do not fail a check. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `describe` | `String describe()` | A multi-line, human-readable rendering — the pair, the chain, and each divergence — for a startup log or a failing test's message. |

### TomSchemaConvergenceCheck

Compares what the **entity model** declares against what the **migration chain**
builds, for every `<datasource>/<schema>` pair under a migrations directory, and
does it without a database.

Everything here is **synchronous**. Reading migration files is file I/O the check
performs eagerly, and the signatures say so: a future-returning check hands a
caller who forgets an `await` precisely the vacuous pass this guard exists to
prevent, with the refusal surfacing later as an unhandled rejection nothing is
watching.

#### Constructors

```dart
TomSchemaConvergenceCheck({
  TomStandardSqlDialect? dialect,
  String? environment,
})
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `checkName` | `String` | `'ce-mg.schema-convergence'` — the stable name this check is referred to by. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `dialect` | `TomStandardSqlDialect` | The dialect SQL types are classified with; defaults to `MariadbSqlDialect`. |
| `environment` | `String` | The environment migrations are filtered against, so the check replays the chain the engine would actually apply; defaults to `TomDbMigrations.resolveActiveEnvironment()`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `checkAll` | `List<TomSchemaConvergenceReport> checkAll(String migrationsDirectory, {Iterable<Type>? entityTypes})` | One report per `<datasource>/<schema>` pair under `migrationsDirectory`, which must exist — an absent tree throws (via `TomDbMigrations.requireMigrationsDirectory`) rather than yielding an empty list no caller could tell apart from "every pair converged". `entityTypes` defaults to every `@TomDbTable` type known to `tomReflector`. |
| `checkSchema` | `TomSchemaConvergenceReport checkSchema(String migrationsDirectory, String datasource, String schema, {Iterable<Type>? entityTypes})` | The same check for one named pair. |
| `readChain` | `List<TomMigrationArtifact> readChain(String schemaDirectory)` | The migration artifacts of one schema directory, ordered and environment-filtered exactly as the engine would order and filter them — it shares `collectMigrationFiles` and `orderMigrationNames` with `TomDbMigrations`, so the check cannot accept a tree the engine refuses. A **missing** schema directory yields an empty chain rather than an error: unlike the root, it is a pair that has no migrations yet, which the diff then reports as missing tables. |
| `verify` | `TomSchemaConvergenceReport verify({required String datasource, required String schema, required List<TomMigrationArtifact> chain, required Iterable<Type> entityTypes, bool reportUnschemedEntitiesAsAmbiguous = false})` | The pure core: compares an already-read `chain` against `entityTypes` with no file system and no database involved, which is what makes the comparison testable over string literals. Set `reportUnschemedEntitiesAsAmbiguous` when the datasource has more than one schema directory, so an entity that declares no `schema` is reported as `ambiguousEntitySchema` instead of being silently attributed. |
| `diff` | `List<TomSchemaDivergence> diff(TomSchemaModel expected, TomSchemaModel actual)` | Every way `actual` fails to satisfy `expected`, in the one vocabulary both sides were reduced to. Public because `TomFrameworkSchemaCheck` runs the *same* comparison over different inputs — one diff, so the two checks cannot come to disagree about what counts as convergence. |

### TomFrameworkSchemaCheck

The convergence check for the tables the **framework itself** owns
(`frameworkOwnedTables`): scheduling, file storage, audit and OAuth state. A
sibling of `TomSchemaConvergenceCheck` rather than the same class, because the
application check can only run where an application's entities and migrations
exist, while this one holds for the framework and is meaningful in an empty
project.

#### Constructors

```dart
TomFrameworkSchemaCheck({TomStandardSqlDialect? dialect})
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `checkName` | `String` | `'ce-fw.schema-convergence'` — deliberately a sibling of `TomSchemaConvergenceCheck.checkName`, not the same name. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `dialect` | `TomStandardSqlDialect` | The dialect column types are classified with; defaults to `MariadbSqlDialect`, the only dialect these tables ship for and the one whose `TINYINT(1)` spelling of a truth value the classification has to know about. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `modelOf` | `TomSchemaModel modelOf(Iterable<TomFrameworkTable> tables)` | The schema `tables` declare, in the vocabulary the diff compares in — rendered as DDL and replayed through `TomSchemaDdlReader`, so the descriptors are classified by the same reader as everything else rather than by a second, drifting one. A descriptor that will not replay is a defect in the framework's own DDL rendering, so it **throws** a `StateError` rather than being reported as a divergence of the subject under test. |
| `verifyChain` | `TomSchemaConvergenceReport verifyChain({required String datasource, required String schema, required Iterable<TomFrameworkTable> tables, required List<TomMigrationArtifact> chain})` | Checks `tables` against the migration `chain` that also builds them. The chain is narrowed to the descriptors' tables before the diff, so a chain that legitimately creates others — an application's own, or the engine's version table — does not produce a warning per table. |
| `verifyRowTypes` | `List<TomSchemaDivergence> verifyRowTypes(TomFrameworkTable table, Iterable<Type> rowTypes)` | Checks the reflected row types that read `table` against the columns it declares: a column a row type maps but the table does not declare is an **error**, a column the table declares that no row type maps is a **warning**. A `String` field is exempt from the type check — the MariaDB driver decodes every column value to `String` before the mapper sees it, so a `String` field is the driver's raw form and claims nothing; a field of any other type *is* a coercion claim, and is checked. |
| `verifyLive` | `Future<TomSchemaConvergenceReport> verifyLive(TomDataSource datasource, Iterable<TomFrameworkTable> tables, {String datasourceName = 'live', String schema = 'DATABASE()'})` | Checks `tables` against the schema `datasource` is actually connected to, reading `information_schema.COLUMNS` into `TomInformationSchemaColumnRow`s. The only variant that needs a server, and the only one that catches a database whose schema was applied correctly once and then edited outside the migration chain. Defaults to `DATABASE()` so the check asks the connection what it is connected to instead of being told, and cannot be pointed at the wrong schema by a stale setting. It reads `COLUMN_TYPE`, not `DATA_TYPE`, because only the former carries the length that distinguishes `tinyint(1)` from `tinyint(4)`. |

### TomInformationSchemaColumnRow

One `information_schema.COLUMNS` row, as `TomFrameworkSchemaCheck.verifyLive`
reads it. Mapped by reflection (`@tomReflector` / `@TomDbTable` /
`@TomDbColumn`); the columns are aliased to lower case in the query because the
mapper matches by name and `information_schema` spells its own columns in upper
case.

#### Constructors

```dart
TomInformationSchemaColumnRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `columnName` | `String` | The column's name. |
| `columnType` | `String` | The full type including length — `varchar(191)`, `tinyint(1)`. |
| `isNullable` | `String` | `YES` when the column accepts `NULL`. |
| `columnKey` | `String` | `PRI` when the column is part of the primary key. |

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

### TomSchemaDivergenceKind

What kind of disagreement a `TomSchemaDivergence` reports. The kinds are not
graded by severity — each names a *different culprit*, and so a different fix.

| Value | Severity | Meaning |
| ----- | -------- | ------- |
| `missingTable` | error | The entity model declares a table the migration chain never creates. |
| `unexpectedTable` | warning | The chain creates a table no entity maps to. Version-tracking tables, join tables and tables read only through raw SQL legitimately have no entity. |
| `missingColumn` | error | The entity model declares a column the chain never adds to the table. |
| `unmappedColumn` | warning | The chain creates a column the entity does not map. An entity may deliberately project a subset of its table. |
| `columnTypeMismatch` | error | Both sides have the column, in incompatible type families (see `TomSqlTypeFamilyCompatibility.accepts`). |
| `primaryKeyMismatch` | error | The two sides disagree on which columns form the primary key. |
| `conflictingEntityPrimaryKey` | error | Two entities map to the same table but declare different primary keys — a contradiction *within* the entity model, reported before the chain is consulted at all. Distinct from `primaryKeyMismatch`, which is the entity model disagreeing with the chain: reporting this one as that would send the reader to the migration scripts to correct something no migration script did. |
| `chainError` | error | A statement in the chain could not be replayed, so the actual side is incomplete and everything downstream of it is unreliable. |
| `ambiguousEntitySchema` | error | An entity declares no `TomDbTable.schema` in a datasource that has more than one schema directory, so which schema it belongs to is unknowable. |

## Extensions

### TomSqlTypeFamilyCompatibility

- **On:** `TomSqlTypeFamily`

How tolerantly the two sides of the convergence check compare their type-family
classifications. The families themselves are the *dialect's* vocabulary (a
dialect decides that `TINYINT(1)` is a truth value); how much difference between
two families still counts as *agreement* is the *check's* policy, and so lives
here rather than on the dialect.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `accepts` | `bool accepts(TomSqlTypeFamily actual)` | Whether a column of this (expected) family may be stored as `actual`. The direction matters — the receiver is what the entity model declares, `actual` what the DDL creates. `integer` ↔ `boolean` both ways: a truth value stored as `TINYINT(1)` is the normal MariaDB spelling, and an entity reading that column as an `int` is equally valid. `decimal` accepts `integer` but **not** the reverse — reading a whole number as a `double` is lossless, while declaring an `int` over a `DECIMAL` column truncates. `dateTime` ↔ `date` both ways, since whether the time-of-day part is stored is a storage decision the entity model leaves open. `unknown` on either side is compatible with everything. |

## Global Functions and Constants

| Name | Signature | Description |
| ---- | --------- | ----------- |
| `frameworkOwnedTables` | `List<TomFrameworkTable> frameworkOwnedTables({String jobRun = defaultJobRunTable, String lease = defaultLeaseTable, String schedulerNode = defaultSchedulerNodeTable, String blobManifest = defaultBlobManifestTable, String blobChunk = defaultBlobChunkTable, String auditTrail = defaultAuditTrailTable, String oauthState = defaultOAuthStateTable})` | Every table the framework owns, at the names it uses when nothing overrides them — so that "all of them" is a thing a caller can name rather than a list each caller assembles and each forgets to extend. A deployment that renames a table passes the corresponding argument. The dependency runs one way: this module reads the descriptors of `scheduling/`, `file_storage/`, `audit/` and `authentication/`, and none of them reads back, so the scheduler runs without loading a migration. |

The signature names the defaulting constants rather than their values, and each
is declared by the module that owns the table — so the seven names the check
actually covers in a deployment that renames nothing are spread across four other
modules. They are, parameter → constant → table name (owner):

- `jobRun` → `defaultJobRunTable` → `tom_job_run` (Scheduling)
- `lease` → `defaultLeaseTable` → `tom_lease` (Scheduling)
- `schedulerNode` → `defaultSchedulerNodeTable` → `tom_scheduler_node` (Scheduling)
- `blobManifest` → `defaultBlobManifestTable` → `tom_blob` (File Storage)
- `blobChunk` → `defaultBlobChunkTable` → `tom_blob_chunk` (File Storage)
- `auditTrail` → `defaultAuditTrailTable` → `tom_audit_trail` (Audit)
- `oauthState` → `defaultOAuthStateTable` → `tom_oauth_state` (Authentication)

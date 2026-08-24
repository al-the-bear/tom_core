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
- [Schema Convergence](#schema-convergence)
  - [The Application's Entities](#the-applications-entities)
  - [The Framework's Own Tables](#the-frameworks-own-tables)
  - [The Four Places a Column Name Could Have Been Spelled](#the-four-places-a-column-name-could-have-been-spelled)
  - [What the Live Check Adds](#what-the-live-check-adds)
  - [Pinning the Entity-Owned Migrations](#pinning-the-entity-owned-migrations)
- [Reading raw SQL: one lexer, not five](#reading-raw-sql-one-lexer-not-five)
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
    audit/                  # a second schema in the *same* data source
      [1]-create_audit_log.sql
  reporting/
    analytics/
      [1]-create_facts.sql
```

A data source may hold **any number of schemas**, as `main` does above. Each
keeps its own independent version history, so the `[1]` under `audit` and the
`[1]` under `app` are unrelated migrations that both apply.

Each file name must match `[<numeric version>]-<description>` followed by any
extension, where the description is letters and underscores
(`[a-zA-Z_]+`). A name that does not match aborts the run with a
`TomDbMigrationException`. Within a schema, files are applied in **ascending
numeric version order** — so `[2]` precedes `[10]`.

## Running Migrations

```dart
// Data sources must already be registered (see the datasources module):
await TomDataSourceInfo.initializeDatasourceInfo(config);

// Apply every pending migration under the tree:
await TomDbMigrations.migrateDatabases('migrations');
```

For each `<datasourceName>` the orchestrator:

1. resolves the `TomDataSourceInfo` by name (missing → exception);
2. resolves the migrator for the data source's `type` (missing → exception);
3. hands both to `TomDbMigrations.migrateDataSource`, which walks the schemas.

Then, **for each `<schemaName>` under that data source**, `migrateDataSource`:

1. calls `reset()`, releasing whatever `(data source, schema)` pair the migrator
   was serving before;
2. calls `initializeMigration(dsi, schemaName)`, binding it to this pair and
   loading *this schema's* applied-version history;
3. parses each file's version/description and calls
   `applyMigration(dsi, schemaName, version, description, sql)` in ascending
   version order.

The reset/initialise pair runs **once per schema, not once per data source**.
A migrator's applied-version state belongs to a `(data source, schema)` pair:
one data source routinely holds several schemas, and each keeps its own
`<schema>_versioning` history, so two schemas may legitimately both be at
version 1. A migrator that carried the first schema's history into the second
would read the second's version 1 as already applied and skip it silently. The
MariaDB adaptor enforces the same invariant from its own side — see below.

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

`initializeMigration` binds the instance to one `(data source, schema)` pair,
creates that pair's table if absent and loads its applied versions (mapped onto
`TomDbVersion`). Because one instance serves every `"mariadb"` schema in turn,
binding is a **rebind**: the loaded version list is *replaced*, never extended,
so it always describes the schema currently in hand. `applyMigration` refuses —
with `mariadb_migration.apply_migration.not_initialized_for_schema` — to run
against any pair the instance is not currently bound to, rather than judging a
migration against another schema's history.

`applyMigration` then, per script:

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

## Schema Convergence

A migration chain is a *history*: it says how the schema was reached, never what
it is now. Nothing in the chain relates its DDL back to the code that reads and
writes those tables, so the two can part company silently — a column widened in
one and not the other surfaces as a runtime failure, on whichever path happens to
touch it first.

The convergence checks close that gap. Both build a `TomSchemaModel` — a
dialect-neutral table/column model — from each side and compare them, and neither
needs a database to do it.

### The Application's Entities

`TomSchemaConvergenceCheck` (`ce-mg.schema-convergence`) takes the **expected**
schema from the reflected `@TomDbTable` / `@TomDbColumn` declarations on the
application's entities, and the **actual** schema by replaying the migration
chain's DDL text through `TomSchemaDdlReader`. A column an entity declares and
the chain never creates is an error; so is a type family the chain cannot hold.

### The Framework's Own Tables

The framework's tables — `tom_job_run`, `tom_lease`, `tom_scheduler_node`,
`tom_blob`, `tom_blob_chunk`, `tom_audit_trail`, `tom_oauth_state` — are not
application entities
and deliberately stay that way: making them entities would pull them into the
application's reflection build and have `discoverEntityTypes()` report them
against every application schema. So they sit outside the guard above, and used
to be the one part of the schema with no guard at all.

Each is now declared exactly once, as a **`TomFrameworkTable`** descriptor
(`datasources/framework_table.dart`) — a name, an ordered column list with types
and nullability, and its keys. Everything else is derived from it:

| Derived from the descriptor | By |
| --------------------------- | -- |
| The `CREATE TABLE IF NOT EXISTS` each store issues on first use | `createTableDdl` |
| The column list of every `SELECT` the store issues | `columnList` / `columnsOf([…])` |
| Every `INSERT` / `REPLACE` / `INSERT IGNORE` the store issues | `insert(verb, {column: bind})` |

`insert` is keyed by **column name**, not position. A positional list would put
the column list and the value list in lock-step, so adding a column would shift
every value one place along — a worse failure than the one this design removes,
because it type-checks.

Table names stay per-instance constructor arguments, so the descriptor is a
*factory* (`jobRunTable(name)`), and index names are derived from the table name
so two queues in one schema cannot collide.

`frameworkOwnedTables()` returns them all at their default names.

### The Four Places a Column Name Could Have Been Spelled

`TomFrameworkSchemaCheck` (`ce-fw.schema-convergence`) exists so that the single
declaration is provably the *only* one. Each of the four ways a second spelling
could survive is closed by a check, and each check has a negative test in
`test/framework_schema_test.dart` that proves it can fail:

1. **The shipped reference migration.** `verifyChain` compares the descriptors
   against the hand-written SQL under `example/*/migrations/`. Those files stay
   hand-written and reviewable on purpose — a migration is what a DBA applies and
   must read like it. What is generated is the *comparison*, not the migration.
   `modelOf` renders the descriptor's `CREATE TABLE` and feeds it through the same
   `TomSchemaDdlReader` the migration side uses, so one parser cannot disagree
   with itself about what `TINYINT(1)` means. This covers the migrations that
   ship a *descriptor* table; the ones that ship an *entity* table are pinned
   character-for-character against the entity's `createTableSql` instead — see
   [Pinning the entity-owned migrations](#pinning-the-entity-owned-migrations).
2. **The reflected row type.** `verifyRowTypes` checks that every column the row
   mapper maps is a column the descriptor declares (absent → error) and that its
   Dart type can hold the declared SQL type (mismatch → error). A descriptor
   column that no row type maps is a warning, not an error — a table may
   legitimately carry a column the mapper does not need. `String` fields are
   exempt from the type comparison: the MariaDB driver decodes every column value
   to a Dart `String`, so a `String` field is the driver's raw form and claims
   nothing, which is exactly why the scheduling row types read `DATETIME(6)` as
   text and parse it with `parseSqlInstant`. A non-`String` field *is* a coercion
   claim, and is checked.
3. **The statements the stores issue.** `unknownFrameworkColumns(sql, tables)`
   audits arbitrary SQL for identifiers that no descriptor declares. The suite
   drives every statement-issuing method of every store through a recording data
   source and puts each captured statement through it.
4. **The provisioned database.** See below.

### What the Live Check Adds

The three checks above are readings of the *source tree*, so all three stay true
of a deployment whose database was provisioned correctly once and then edited by
hand: the drop of a "redundant" index, the widening of a column, the `ALTER`
applied outside the chain.

`verifyLive(datasource, tables)` reads `information_schema` and compares what is
actually there with the descriptors. `test/framework_schema_db_test.dart` runs it
against both provisioning routes — the stores' create-on-first-use and the
shipped migration files, which must not diverge — and then hand-edits a column to
prove the comparison reports something. It is tagged `db` and skips when no
server is reachable; bring one up with `tool/run_db_tests.sh`.

### Pinning the Entity-Owned Migrations

Not every framework table is a descriptor. Seven of them —
`tom_user_two_factor_enrolment`, `tom_external_identity`,
`tom_external_identity_token`, `tom_resource_grant`,
`tom_principal_resource_grant`, `tom_principal_delegation` and
`tom_user_preference` — are ordinary reflected **entities**, each carrying its
own `createTableSql`. There is no descriptor to converge against, so the shipped
`.sql` is compared to that constant **verbatim**: a substring match, not a
parse. `test/reference_migrations_test.dart` holds all seven, and its negative
test mutates a constant to prove the comparison can fail.

The guard that matters most there is not any individual pin but the one that
counts them. A pin that was never written leaves nothing behind to fail — the
absence is invisible, which is exactly how two of these seven shipped unpinned.
So the same file walks `example/*/migrations/main/tomcore/` and requires every
`.sql` it finds to be named either by the entity-pin table or by the list of
migrations covered elsewhere (`framework_schema_test.dart` for descriptors,
`audit_sql_test.dart` and `scheduling_schema_test.dart` for the triggers and
their chains). A reverse test catches list entries whose file is gone. Adding a
migration without a guard therefore fails when it is added, rather than when it
drifts.

## Reading raw SQL: one lexer, not five

Two things in this module walk migration text character by character: the
**applier**, which must send a script one statement at a time, and the
**reader**, which parses a schema out of it. Both need the same answer to the
same question — *is this character inside a quoted run?* — and getting it wrong
does not fail loudly. It cuts a statement in half inside a string literal and
sends a syntactically broken fragment to the server, or it swallows a closing
quote and welds two statements into one.

`TomSqlLexer` is the single place that answers it. `endOfQuotedRun` finds where
a quoted run closes; `splitStatements` is built on it and is the module's one
statement splitter, used by the applier directly and by the reader through
`TomSchemaDdlReader.splitStatements`.

The escaping rules it implements are the ones MariaDB actually has, which are
not uniform across the three quote characters:

| Quote | `''` doubling | `\'` backslash |
| ----- | ------------- | -------------- |
| `'` string literal | yes | yes |
| `"` string literal | yes | yes |
| `` ` `` identifier | yes | **no** |

A backslash is an ordinary character inside a backtick identifier:
``CREATE TABLE `bs\` (id INT)`` creates a table genuinely named ``bs\`` and
terminates at that second backtick. Both backslash columns assume the default
`sql_mode` (`NO_BACKSLASH_ESCAPES` off), which is the mode migrations run under.

**The splitter keeps comments.** They are not noise that can be dropped on the
way to the server: `/*!40101 SET NAMES utf8 */` is a MariaDB *executable*
comment — real, version-gated SQL — so stripping it would silently discard a
statement the migration author wrote. Comment removal is therefore a separate,
opt-in step, `TomSchemaDdlReader.stripComments`, which only the reader takes
because it compares declared structure rather than executing anything.

Splitting at all matters because the underlying `mysql_client` only half-reads a
multi-statement command: it consumes the first result set and leaves the rest,
desyncing the single shared connection so every later read returns stale data.

## Core Components

- **`TomSqlLexer`** — the shared SQL lexing primitives: `endOfQuotedRun`,
  `commentOpensAt`, `endOfComment`, and the module's one `splitStatements`.
- **`TomDbMigrations`** — the orchestrator and reflection-based adaptor
  discovery; `migrateDatabases`.
- **`TomDbMigrator`** (+ the `TomDbMigrationAdaptor` annotation) — the migrator
  contract.
- **`MariadbMigrationAdaptor`** and **`TomDbVersion`** — the MariaDB
  implementation and its versioning-row type.
- **`TomDbMigrationException` / `MariadbMigrationException`** — the error types.
- **`TomSchemaConvergenceCheck`** — the application-entity guard, plus
  `TomSchemaModel` / `TomSchemaDdlReader`, the model and the DDL parser both
  guards share.
- **`TomFrameworkSchemaCheck`** — the framework-table guard: `verifyChain`,
  `verifyRowTypes`, `verifyLive`, and `frameworkOwnedTables()`.
- **`TomFrameworkTable`** (in the datasources module) — the single declaration
  every framework table's DDL and statements are derived from.

## Dependencies

- `tom_core_kernel` — `tomReflector` (adaptor discovery, row mapping), `tomLog`.
- The datasources module — `TomDataSourceInfo` (named data sources) and its
  `executeCommand` / `executeQuery`.
- The object-persistence module — `TomDbTable` / `TomDbColumn` on `TomDbVersion`.
- `path` — migration-file name parsing.
- `dart:io` — walking the migration directory tree.

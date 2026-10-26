# Database Migration Module

Versioned, file-driven schema migrations. A directory tree describes the
migrations for each data source and schema; the orchestrator
(`TomDbMigrations`) walks it and applies each script through a
database-specific migrator (`TomDbMigrator`), which records what it applied so
re-runs are idempotent and edits to past migrations are detected. Two SQL
implementations are provided on one database-neutral base
(`TomSqlMigrationAdaptor`): MariaDB (`MariadbMigrationAdaptor`, for the
`mariadb` and `mariadb_xa` data-source types) and PostgreSQL
(`PostgresMigrationAdaptor`, for `postgresql` and `postgresql_xa`). A migration
with a down script beside it can be [rolled back](#rolling-migrations-back).

## Table of Contents

- [Overview](#overview)
  - [The migration engine](#the-migration-engine)
  - [The convergence checks](#the-convergence-checks)
  - [The shared schema model and DDL replay](#the-shared-schema-model-and-ddl-replay)
- [The Directory Layout](#the-directory-layout)
  - [One File per Migration](#one-file-per-migration)
  - [What a Schema Directory May Hold Besides Migrations](#what-a-schema-directory-may-hold-besides-migrations)
  - [One Migration per Version](#one-migration-per-version)
  - [Environment Tags](#environment-tags)
  - [Down Scripts](#down-scripts)
  - [The Tree Root Has to Be There](#the-tree-root-has-to-be-there)
- [Running Migrations](#running-migrations)
  - [One run per database at a time: the migration lock](#one-run-per-database-at-a-time-the-migration-lock)
  - [Per-tenant migrations](#per-tenant-migrations)
  - [Where the last run stands](#where-the-last-run-stands)
- [Adaptor Discovery](#adaptor-discovery)
- [The SQL Adaptors](#the-sql-adaptors)
  - [The outcome row is written with bound parameters](#the-outcome-row-is-written-with-bound-parameters)
  - [A failed script: recorded on MariaDB, rolled back on PostgreSQL](#a-failed-script-recorded-on-mariadb-rolled-back-on-postgresql)
  - [Reference migrations for PostgreSQL](#reference-migrations-for-postgresql)
- [Idempotency and Stability](#idempotency-and-stability)
  - [A recorded failure stops the next run](#a-recorded-failure-stops-the-next-run)
  - [The checksum has to outlive the process that wrote it](#the-checksum-has-to-outlive-the-process-that-wrote-it)
  - [An unreadable checksum is not an edited migration](#an-unreadable-checksum-is-not-an-edited-migration)
- [Repairing a Failed Migration](#repairing-a-failed-migration)
  - [Remove, or mark resolved](#remove-or-mark-resolved)
  - [From the command line](#from-the-command-line)
  - [What repair refuses](#what-repair-refuses)
- [Rolling Migrations Back](#rolling-migrations-back)
  - [What is checked before anything is undone](#what-is-checked-before-anything-is-undone)
  - [A failed down script: left half-way on MariaDB, rolled back on PostgreSQL](#a-failed-down-script-left-half-way-on-mariadb-rolled-back-on-postgresql)
  - [Rolling back from the command line](#rolling-back-from-the-command-line)
  - [What a rollback refuses](#what-a-rollback-refuses)
- [Schema Convergence](#schema-convergence)
  - [The Application's Entities](#the-applications-entities)
  - [When the Entity Model Contradicts Itself](#when-the-entity-model-contradicts-itself)
  - [A Version Column Must Hold a Value](#a-version-column-must-hold-a-value)
  - [Replaying the Chain: What the Guards Mean](#replaying-the-chain-what-the-guards-mean)
  - [What the Reader Refuses to Guess At](#what-the-reader-refuses-to-guess-at)
  - [The Framework's Own Tables](#the-frameworks-own-tables)
  - [The Four Places a Column Name Could Have Been Spelled](#the-four-places-a-column-name-could-have-been-spelled)
  - [What the Live Check Adds](#what-the-live-check-adds)
  - [Pinning the Entity-Owned Migrations](#pinning-the-entity-owned-migrations)
- [What Returns a Future, and Why](#what-returns-a-future-and-why)
- [Reading raw SQL: one lexer, not five](#reading-raw-sql-one-lexer-not-five)
  - [Structure comes from tokens, never from `indexOf`](#structure-comes-from-tokens-never-from-indexof)
- [Verification](#verification)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

The module has two halves, and which one a type belongs to is the first thing
worth knowing about it. The **engine** brings a database up to date: it walks a
directory tree, applies the pending scripts, and records what it applied. The
**checks** answer a different question — *does this chain build the shape the
rest of the code expects* — and answer it with no database at all, by replaying
the chain's DDL text into an in-memory model. Between them sits a third group
that is neither: the schema vocabulary and the SQL reading both halves are built
on. A single flat list hides that structure, and a reader who cannot tell the
replay types from the engine types has to open the source to find out which of
them run against a live server.

### The migration engine

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomDbMigrations` | class | The orchestrator; `migrateDatabases(directory)` drives a whole tree |
| `TomDbMigrator` | abstract class | The per-database migrator contract (`initializeMigration` / `applyMigration` / `reset`, and `withMigrationLock` / `repair` / `rollback`) |
| `TomMigrationRepair` | enum | What `repair` does with a migration recorded as failed: `remove` it or `markResolved` |
| `TomDbMigrationAdaptor` | class | Binds a migrator to its data-source types (`type` and `alsoServes`) for reflection discovery |
| `TomMigrationScript` | class | One migration's description, up script and down script, as a rollback reads them from the tree |
| `TomMigrationFileName` | class | A migration file name parsed into version, description and environment tags |
| `TomSqlMigrationAdaptor` | abstract class | Everything a SQL migrator does that does not depend on the database: the versioning history, checksum stability, rebinding per schema, the migration lock, the repair of a failed record and the checks of a rollback |
| `MariadbMigrationAdaptor` | class | The MariaDB migrator, for `mariadb` and `mariadb_xa` |
| `PostgresMigrationAdaptor` | class | The PostgreSQL migrator, for `postgresql` and `postgresql_xa` — a script and its version row in one transaction |
| `TomDbVersion` | class | One row of a `<schema>_versioning` table |
| `TomMigrationRun` | class | The process's most recent `migrateDatabases` call: its state, start, end and error (`TomDbMigrations.lastRun`) |
| `TomMigrationRunState` | enum | `notRun`, `running`, `succeeded` or `failed` — what the framework readiness check reads |
| `TomDbMigrationException` | class | Orchestration / discovery / parsing failures |
| `TomSqlMigrationException` | class | SQL migration failures, whichever adaptor raised them |
| `MariadbMigrationException` / `PostgresMigrationException` | class | Its MariaDB and PostgreSQL subtypes |

### The convergence checks

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomSchemaConvergenceCheck` | class | The comparison: entity model against migration chain |
| `TomEntitySchemaReader` | class | Reads the schema the `@TomDbTable` entity classes expect |
| `TomSchemaConvergenceReport` | class | What one `<datasource>/<schema>` pair was checked against, and how it disagreed |
| `TomSchemaDivergence` | class | One disagreement: kind, table, column, origin, message |
| `TomSchemaDivergenceKind` | enum | Which of the ten disagreements it is — each a different culprit |
| `TomFrameworkSchemaCheck` | class | The same comparison for the tables the framework itself owns |
| `TomInformationSchemaColumnRow` | class | One `information_schema.COLUMNS` row, as the live check reads it |
| `frameworkOwnedTables` | function | Every framework-owned table, at its default name |

### The shared schema model and DDL replay

Both halves compare through one vocabulary, so a difference between them is a
real disagreement rather than two spellings of the same thing.

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomSchemaDdlReader` | class | Replays a chain of artifacts into the schema it produces |
| `TomMigrationArtifact` | class | One migration artifact as the reader consumes it — a basename and its SQL |
| `TomDdlReplayResult` | class | That schema, together with whatever would not replay |
| `TomDdlReplayError` | class | One statement that could not be replayed — reported, never thrown |
| `TomSchemaModel` | class | A whole schema, in the one vocabulary both sides are reduced to |
| `TomSchemaTable` | class | One table: its columns, primary key and origin |
| `TomSchemaColumn` | class | One column: its type family, declared type and origin |
| `TomSchemaBuilder` | class | The mutable accumulator both sides build their model through |
| `TomSqlTypeFamilyCompatibility` | extension | How much difference between two type families still counts as agreement |

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

Each file name must match

```text
[<numeric version>]-<description>[@<env>[,<env>...]].<anyfileextension>
```

which is the grammar `parseMigrationFileName` quotes back when it refuses a
name. The description is letters and underscores (`[a-zA-Z_]+`) — no digits —
and the `@<env>` tag is **optional**: `[3]-demo_seed@dev.sql` applies only under
the `dev` environment, `[3]-demo_seed@dev,test.sql` under either, and an
untagged name applies everywhere. A name that does not match aborts the run with
a `TomDbMigrationException` keyed
`db_migration.migration.illegal_filename_in_migrations_directory`; see [Environment Tags](#environment-tags) for what
the tag does.

Within a schema, files are applied in **ascending numeric version order** — so
`[2]` precedes `[10]`, which is exactly where numeric order and name order
disagree.

### One File per Migration

The extension is not part of a migration's identity: a migration *is* its
basename, which is what the version ordering, the environment tag and the
recorded applied-version history are all read from. Two files in one schema
directory that differ only in extension therefore claim the same migration, and
the run aborts naming both paths:

```text
app/
  [3]-add_index.sql
  [3]-add_index.ddl     # both claim "[3]-add_index" → the run aborts
```

```text
Duplicate migration filename in migrations directory: [3]-add_index.
A migration is identified by its filename without extension, so
…/[3]-add_index.ddl and …/[3]-add_index.sql cannot be told apart.
Remove or rename one.
```

The key is `db_migration.migration.duplicate_migration_basename`.

The alternative is not a tie-break but a coin toss. Collecting the directory
into a map keyed by basename means the second file the listing yields
overwrites the first, and the run continues as though the directory had always
held one — with no record of which of the two ran, and no guarantee that the
next machine, whose file system enumerates the directory differently, makes the
same choice.

What turns that from untidy into dangerous is the shape of the names involved.
An editor or a merge leaves `[3]-add_index.orig` beside `[3]-add_index.sql`,
and `.orig` strips to exactly the same basename — so the *backup* can be the
file that wins, and the migration it was a backup of never runs. The failure is
silent at every stage: the engine records version 3 as applied, the checksum it
stores is the backup's, and the schema is left in a state no artifact in the
tree describes.

Aborting is also the rule this module already follows everywhere else. A file
whose name it cannot parse does not get skipped — it stops the run, on the
reasoning that a surprising file in a migrations directory is far more likely to
be a migration nobody noticed was not running than deliberate clutter. A
duplicate is that same hazard with a sharper edge, and gets the same answer.

The rule is enforced by one function, `TomDbMigrations.collectMigrationFiles`,
which both the engine and the [convergence check](#schema-convergence) collect
through — for the same reason they share the name parser and the ordering. A
check that quietly read one of two colliding files would report on a chain the
engine refuses to apply, which is worse than either behaviour on its own.

### What a Schema Directory May Hold Besides Migrations

Refusing a name it cannot parse is the rule this module follows, and it stays.
But the argument for it — a surprising file in a migrations directory is more
likely a migration nobody noticed was not running than deliberate clutter — is
about files **a developer put there**. It does not reach the ones an operating
system, a file explorer or an editor writes without being asked, and for those
the refusal is a hard startup failure whose fix is to delete a file the operator
did not create.

Two classes are therefore skipped, and only two:

| Skipped | Why |
| ------- | --- |
| Any **dot-file** — `.DS_Store`, `.gitkeep`, `.gitignore`, the swap file an editor leaves beside the migration it has open | A dot-file is hidden by convention on every platform this runs on, which is as close as a file system comes to saying "not content" |
| The fixed list `readme.md`, `thumbs.db`, `desktop.ini`, matched case-insensitively | Each is written by something other than the author of the chain: a file explorer, or a person documenting the directory |

Everything else is collected, and so must parse. That is the point of drawing
the line here rather than at the extension:

```text
app/
  [3]-add_index.sql     # applied
  [3]-add_index.sqll    # a mis-typed migration → reported, not skipped
  [3]-add_index.orig    # an editor's backup   → reported as a duplicate
  README.md             # ignored
  .DS_Store             # ignored
```

An extension filter — "only `.sql` counts" — would be simpler to state and would
make the first two invisible, which is exactly the failure the abort exists to
prevent: the file that was meant to run simply would not, and nothing would say
so. A file a developer put there under a name that is neither a migration nor
recognised clutter still stops the run.

The rule is one predicate, `TomDbMigrations.isNotAMigrationFile`, applied inside
`collectMigrationFiles` — so the engine and the
[convergence check](#schema-convergence) ignore the same files, and it is
applied *before* the duplicate-basename check, so an ignored name can never be
reported as half of a collision.

### One Migration per Version

The rule above is about files that cannot be told apart *as files*. Two files
can also be perfectly distinct and still claim the same migration, by sharing a
version number:

```text
app/
  [1]-schema.sql
  [1]-seed.sql          # distinct basenames, one version → the run aborts
```

```text
Duplicate migration version in migrations directory: version 1 is claimed by
both [1]-schema and [1]-seed. A migration is recorded and skipped by its
version, so two files sharing one cannot be told apart once they are applied.
Renumber one of them.
```

The version is the whole of a migration's *recorded* identity. The versioning
table stores it, and `applyMigration` decides "already applied" by scanning the
loaded history for it — so two migrations sharing a version are two rows that no
later run can attribute to the right file.

Left unguarded the pair fails in three stages, and only the first is visible
while it is happening:

1. **Both apply, in one pass.** A migrator's applied-version list is a snapshot
   taken by `initializeMigration` and is deliberately not extended as
   `applyMigration` runs, so the second call cannot see what the first just did
   and the skip check does not fire.
2. **In an order nothing defines.** Ordering is by version, and these two
   compare equal, so which runs first is whatever the sort left them in — a
   `[1]-seed` can run before the `[1]-schema` that creates the table it inserts
   into, and differently on the next machine.
3. **The next run cannot proceed at all.** The table now holds two rows for
   version 1. The skip check stops at the first row it finds whatever file it is
   being offered, so one of the two migrations is compared against the other's
   description and script — and the run aborts reporting a description or
   checksum mismatch. That message means "a past migration was edited", which is
   not what happened; the operator is sent looking for a change to a file nobody
   touched.

So the collision is refused while it is still a pair of filenames, by
`TomDbMigrations.orderMigrationNames`, as
`db_migration.migration.duplicate_migration_version` naming both files. Two details of *how* it is refused are
deliberate:

- **The comparison is on the parsed integer**, not the bracketed text, so `[1]`
  and `[001]` collide as they should. Leading zeroes are formatting, not
  identity.
- **The check runs before environment selection**, so an untagged `[1]-schema`
  and a `[1]-seed@dev` are refused even on a box that would only apply one of
  them. A tag decides which of the pair runs *here*; it does not give them
  separate rows in the history they share, and a box switched between
  environments (which [environment tags](#environment-tags) explicitly support)
  meets the other one's row. A tree that is valid on production and broken on a
  developer's machine is exactly the failure this module refuses to allow.

  Placing it before selection is what makes the answer *environment-independent*,
  and that matters for the [convergence check](#schema-convergence) as much as
  for the engine. The check filters the chain by an environment too —
  `TomSchemaConvergenceCheck` takes one and defaults it to the active name — so
  had the duplicate check run after selection, the same tree would be pronounced
  sound when the check ran under `prod` and unsound under `dev`. Refusing the
  pair while it is still two filenames gives both tools one answer.

### Environment Tags

A migration may name the environments it belongs to by appending
`@<env>[,<env>...]` to its description. The tag is matched against the **active
environment name** — `TomDbMigrations.resolveActiveEnvironment()`, resolved
through `TomRuntime` rather than a raw environment-variable read:

```text
app/
  [1]-create_users.sql          # untagged → applies in every environment
  [2]-demo_seed@dev.sql         # only under `dev`
  [3]-add_indexes.sql           # untagged
  [4]-fixtures@dev,test.sql     # under `dev` or `test`
```

**Untagged is the safe default.** A migration with no tag applies everywhere, so
schema never becomes environment-scoped by accident — the tag is something you
opt into for the data you did *not* want in production. Matching is on the
environment name directly, with no hierarchy walk: a `@dev` migration is skipped
under `prod` and applied under `dev`, and nothing makes `dev` a "kind of" any
other environment. When no environment has been initialized at all, the engine
falls back to `defaultTomEnvironment`, under which only untagged migrations
apply — the production-safe reading of an unanswerable question.

The rule is spelled in two places, one per file and one per chain.
`TomMigrationFileName.appliesInEnvironment(name)` is the whole predicate — true
when the tag list is empty, or when it contains `name` — and
`TomDbMigrations.selectForEnvironment(ordered, name)` applies it across an
already-ordered chain, preserving order. Selection is therefore the **last**
step: the names are parsed, checked for duplicate versions and sorted by version
first, and only the surviving order is filtered. Nothing is reordered by being
tagged.

Skipping is a **pure omission**. The applied-version bookkeeping is untouched —
a skipped migration is not recorded as applied, failed, or anything else — so
re-running in the same environment skips it again and stays idempotent, and
switching environments later finds it still pending rather than already spent.

A tagged migration still occupies its version number in the schema's single
history — the tag decides *whether* it runs, not which number it takes — so
`[2]-demo_seed@dev` and an untagged `[2]-add_orders` are the same migration
claiming one slot, not two alternatives.

Skipping is therefore not the same as not existing, and the difference shows up
as a history that is not in version order. A box that ran the tree above under
`prod` applied `[1]` and `[3]` and skipped the other two; switched to `dev`, it
applies `[2]` and `[4]` next, leaving `1, 3, 2, 4` in installation order. That
is why
`initializeMigration` hands back the applied list in installation order rather
than a single "current version" — see [Running
Migrations](#running-migrations).

### Down Scripts

A migration may have a **down script** beside it: a file named after the
migration's basename plus `.down`, which undoes it.

```text
app/
  [1]-create_users.sql
  [2]-add_orders.sql
  [2]-add_orders.down.sql       # undoes [2]-add_orders
  [3]-demo_seed@dev.sql
  [3]-demo_seed@dev.down.sql    # the environment tag stays in the name
```

The suffix is `TomDbMigrations.downSuffix` (`.down`), and
`TomDbMigrations.isDownMigration(basename)` recognises a down script by its
basename without extension. Like a migration, a down script is identified by
its basename, so its extension is free and two down scripts for one migration —
`[2]-add_orders.down.sql` and `[2]-add_orders.down.ddl` — are refused with
`db_migration.migration.duplicate_migration_basename`, naming both paths.

A down script is not a migration. `collectMigrationFiles` skips it, so the
forward run never applies one and the [convergence check](#schema-convergence)
never replays one into the chain it compares; `collectDownMigrationFiles`
collects them, keyed by the basename of the migration each undoes, for a
[rollback](#rolling-migrations-back). A down script is optional: a migration
without one runs forward and cannot be rolled back.

### The Tree Root Has to Be There

A migrations directory a tool is *told* to walk is an **input**, not content.
Handed a path that does not exist, both `TomDbMigrations.migrateDatabases` and
`TomSchemaConvergenceCheck.checkAll` / `checkSchema` abort with
`db_migration.migration.migrations_directory_not_found`:

```text
Migrations directory not found: migrations (resolved to
/srv/app/build/migrations). The migration tree has to exist where it is
configured — check the path and the working directory the process was started
in.
```

A **relative** path is reported with what it resolved to as well, because its
most common cause is the right path read from the wrong working directory, and
the path on its own cannot tell that apart from a typo. An absolute path is
already unambiguous and is not repeated.

Tolerating the absence is the worst of the available answers, because *both*
tools then succeed while having done nothing:

- the engine walks zero data sources, applies zero migrations, and returns
  normally — so the server boots reporting migrations complete against a
  database that was never touched;
- the check returns an empty report list, which no call site can distinguish
  from "every pair converged". A CI gate written as
  `reports.every((r) => r.converged)` passes **vacuously** on a path that was
  never read.

The two tools also have to agree. Before this rule they did not: the check
returned `[]` while the engine surfaced a raw `PathNotFoundException` — a
`dart:io` type from outside this module's exception family, carrying no key and
no mention of migrations, so a caller matching on `TomDbMigrationException` saw
a mistyped path as an unrelated crash. Two entry points over one tree cannot
hold different opinions about whether the tree being absent is a failure.

Three things are deliberately **not** errors:

| Case | Behaviour | Why |
| ---- | --------- | --- |
| The root exists but is empty | No migrations run; no reports | "Nothing to migrate yet" is a legitimate state for a project whose migrations have not been written. |
| A datasource directory holds no schema sub-directories | Nothing runs | Same reason; the walk simply has no schemas to visit. |
| A `<datasource>/<schema>` pair is absent below an existing root | `readChain` yields an empty chain | This is content below a root already proven to exist, and an empty chain lets `verify` report every entity as *missing from the migrations* — a precise finding, which is what the check exists to produce. An exception here would replace that finding with a crash. |

The guard is one function, `TomDbMigrations.requireMigrationsDirectory`, shared
by the engine and the check for the same reason `collectMigrationFiles` and the
name parser are.

The engine checks the path **before** scanning for adaptors, so a caller who
gets the path wrong is told about the path rather than about reflection not
being initialised.

On the check's side the refusal is raised by the call rather than delivered in a
future — `checkAll` and `checkSchema` are synchronous. That is what keeps it
un-ignorable: a future-returning check hands a caller who forgets an `await`
precisely the vacuous pass this guard exists to prevent, with the exception
surfacing later as an unhandled rejection nothing is watching.

## Running Migrations

```dart
// Data sources must already be registered (see the datasources module):
await TomDataSourceInfo.initializeDatasourceInfo(config);

// Apply every pending migration under the tree:
await TomDbMigrations.migrateDatabases('migrations');
```

For each `<datasourceName>` the orchestrator:

1. resolves the `TomDataSourceInfo` by name (missing →
   `db_migration.migration.no_datasource_info_found`);
2. resolves the migrator for the data source's `type` (missing →
   `db_migration.migration.no_migrator_found_for_datasource_type`);
3. hands both to `TomDbMigrations.migrateDataSource`, which takes the data
   source's [migration lock](#one-run-per-database-at-a-time-the-migration-lock)
   and walks the schemas while holding it.

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
SQL adaptors enforce the same invariant from their own side — see below.

### One run per database at a time: the migration lock

Several replicas of one server starting together each run `migrateDatabases`
against the same database. Without arbitration each reads an applied-version
history that predates the others, and each applies the same scripts: a
`CREATE TABLE` meets a table another process created a moment earlier, and the
versioning table gains a row per process for one version. So
`migrateDataSource` runs every schema of a data source under that data source's
**migration lock**, `TomDbMigrator.withMigrationLock(dsi, body)`: one migration
run per database at a time, across every process that migrates it. A second
process waits for the first to finish, then reads a history that holds the
first's migrations and skips them.

The SQL adaptors take the lock through the data source's
[session lock](datasources.md#session-locks), `TomSqlDatasource.withSessionLock`:

| Database | Lock | Name |
| -------- | ---- | ---- |
| MariaDB | `GET_LOCK(name, 0)` / `RELEASE_LOCK(name)` | `tom_db_migration:<databaseName>` |
| PostgreSQL | `pg_try_advisory_lock(hashtextextended(name, 0))` / `pg_advisory_unlock(…)` | the same name, hashed into the advisory lock's number |

`TomSqlMigrationAdaptor.migrationLockName(databaseName)` is that name. MariaDB's
lock names are server-wide and at most 64 characters, so the name carries the
database — two databases on one server migrate side by side — and a database
name too long to fit is replaced by the leading characters of its checksum.

The lock is held on a **connection of its own**, opened beside the data
source's pool for the length of the run and closed when it ends. The scripts run
on the pool as usual; the lock is a mutual exclusion between processes, not a
transaction. That is what makes it safe to leave to the database:

- **Released on every exit.** It is released when the run returns and when it
  throws, and the connection is closed either way.
- **Released when the process dies.** A session lock belongs to the session
  that took it, and the database ends the session when its connection goes —
  a killed process, a lost host. There is no lease to expire and no row left
  behind for an operator to clear: the next process takes the lock at once.
- **Waited for, within a bound.** A process finding the lock held tries again
  every 250 ms for up to `TomSqlMigrationAdaptor.lockWait` (10 minutes), then
  gives up with `error.datasource.session_lock_timeout`, naming the lock and the
  wait. The bound is generous on purpose: the process holding the lock is
  migrating, and a long migration is not a dead process — a dead one releases
  at once. Lower `lockWait` for a deployment whose migrations are known to be
  short; raise it for one that rebuilds large tables.
- **Re-entrant.** A run inside a run that already holds the lock of the same
  database takes it without waiting for itself, so a caller may hold it around
  several runs.

A data source that is not a `TomSqlDatasource` has no session lock to migrate
under, and the SQL adaptors refuse it with
`<initialize>.lock.not_a_sql_datasource`
(`mariadb_migration_adapter.lock.not_a_sql_datasource`,
`postgres_migration_adapter.lock.not_a_sql_datasource`).

`TomDbMigrations.withMigrationLock(datasourceName, body)` takes the lock of a
registered data source by name, for a run wider than one `migrateDatabases`
call — the per-tenant walk below.

### Per-tenant migrations

`migrateDatabases` looks each data source up through
`TomDataSourceInfo.getDataSourceInfo`, which in a multi-tenant deployment
routes to the current tenant's schema or database (see
[tenancy.md](tenancy.md)). The same tree applied inside each tenant therefore
lands in each tenant's place, and each keeps its own versioning table:

```dart
// The framework's own tables, once, outside any tenant.
await TomDbMigrations.migrateDatabases('migrations/deployment');

// The application's tenant tables, once per tenant — every tenant under one
// hold of the migration lock, so no other process migrates between two of them.
await TomDbMigrations.withMigrationLock(
  'main',
  () => TomTenancy.current!.forEachTenant(
    (_) => TomDbMigrations.migrateDatabases('migrations/tenant'),
  ),
);
```

Each tenant's run takes its own data source's lock as well; the outer hold makes
the walk one unit. A second replica starting during it waits for the whole walk
rather than slipping in between two tenants, and the runs inside take the lock
of their database without waiting for themselves, because it is re-entrant. The
lock is named by database, so it covers the tenants that share the outer data
source's database — every `shared` and, on PostgreSQL, every `schema` tenant. A
tenant with a database of its own is serialised by its own run's lock.

Keep the two trees apart. The framework's tables (below) are deployment-wide —
their stores are built over a data source once and never routed — so their
migrations run once, outside every tenant; run inside each tenant they would
create unused copies in every tenant's schema. A shared tenant's per-tenant run
reaches the shared database, where the versioning table makes every run after
the first a no-op. A tenant onboarded later is brought to the current version by
the same call inside `TomTenancy.runFor`.

### Where the last run stands

Every `migrateDatabases` call records how it stands in
`TomDbMigrations.lastRun`, a `TomMigrationRun`:

| `state` | When | Also set |
| ------- | ---- | -------- |
| `notRun` | `migrateDatabases` has not been called in this process | — |
| `running` | a call has started and not returned | `startedAt` |
| `succeeded` | the last call applied every migration | `startedAt`, `finishedAt` |
| `failed` | the last call threw | `startedAt`, `finishedAt`, `error` (the thrown error as text) |

A failed call still throws as it always does; the record is what lets something
other than the caller see it. The framework readiness check on `GET /ready`
reads it: a server whose migration is running or failed answers not ready, with
the error in the body, and a process that never migrates — its schema applied
by a DBA or a job — passes (see
[healthcheck.md](healthcheck.md#the-framework-readiness-checks)).

The record is the process's, not a data source's: in a per-tenant loop it
describes the most recent tenant's call, and a later call replaces an earlier
failure. A boot step that migrates per tenant and wants a failure to stay
visible stops at the first one, which is what letting the exception propagate
does. `TomDbMigrations.resetLastRun()` returns the record to `notRun`, as a
fresh process starts — for tests.

## Adaptor Discovery

A migrator registers by annotating its class with
`@TomDbMigrationAdaptor("<type>")` and `@tomReflector`; further types it serves
are listed in `alsoServes` —
`@TomDbMigrationAdaptor("mariadb", alsoServes: ["mariadb_xa"])`. A two-phase
data source speaks the same SQL as the plain one, so one migrator serves both.
`TomDbMigrations` scans `tomReflector.annotatedClasses` on first use, builds
**one instance per adaptor class** and registers it under each of its types,
and rejects duplicate or non-conforming registrations with a
`TomDbMigrationException`: a second adaptor for a type already claimed —
through `type` or `alsoServes` — is
`db_migration.initialization.found_more_than_one_migration_adapter`, and an
annotated class that does not implement `TomDbMigrator` is
`db_migration.initialization.migrator_does_not_implement_tom_db_migrator`. The `<type>` must match the data source's
`TomDataSourceInfo.type`.

Building a candidate is the one step here that can fail for a reason outside
the module, so `instantiateMigrator` reports it in full, as
`db_migration.initialization.failed_to_instantiate_migrator`: the constructor's
error is named in the message **and** forwarded as the raised exception's root
cause, together with the trace from where it was thrown. The name of the class
that could not be built says nothing about why — a missing zero-argument
constructor, a throwing field initialiser and a failed dependency lookup all
read alike from the outside — and this runs at startup, over a registry
assembled by reflection, which is the worst position from which to reconstruct
a cause by hand.

## The SQL Adaptors

Two adaptors ship, one per database, and everything they have in common lives
once in `TomSqlMigrationAdaptor`: the versioning table and its history, the
checksum, the rebinding, and the refusal of a history that records a failure.
What differs is the versioning table's DDL (`versioningTableDdl`), how a
script runs (`applyScript`) and how a down script runs (`revertScript`):

| `type` | Adaptor | A script runs | A failed script | A failed down script |
| ------ | ------- | ------------- | --------------- | -------------------- |
| `mariadb`, `mariadb_xa` | `MariadbMigrationAdaptor` | statement by statement | its statements so far stay applied, and it is recorded with `success = 0` | its statements so far stay done, and the migration stays recorded |
| `postgresql`, `postgresql_xa` | `PostgresMigrationAdaptor` | statement by statement, with the version row, inside one transaction | rolled back entirely, and nothing is recorded | rolled back entirely; the migration stays applied and recorded |

The two-phase types (`mariadb_xa`, `postgresql_xa`; see
[datasources.md](datasources.md)) migrate through the adaptor of their database:
a migration run uses the data source's ordinary statements, not a two-phase
transaction.

Each raises its keys under its own prefixes, so a key names the database it came
from — `mariadb_migration.` / `mariadb_migration_adapter.` for MariaDB,
`postgres_migration.` / `postgres_migration_adapter.` for PostgreSQL. Below,
`<apply>` stands for the first of each pair and `<initialize>` for the second.

Each keeps a `<schema>_versioning` table per schema:

| Column | Meaning |
| ------ | ------- |
| `installedRank` | auto-increment insertion order (primary key) |
| `version` | the migration version number |
| `description` | the description from the file name |
| `script` | the full migration script text |
| `checksum` | the script's content digest (hex SHA-256), to detect later edits |
| `installedBy` / `installedOn` | who/when (DB defaults) |
| `executionTimeMs` | how long the script's statements took, in ms — including a script that failed part-way, where it is the time spent before the failure |
| `success` | `1` on success, `0` on failure |

Every column is mapped onto a `TomDbVersion` field, so everything the table
records is readable from the loaded history rather than only by querying the
table by hand. The PostgreSQL table is the same, column for column, in
PostgreSQL's words (`installedRank` an identity, `script` a `TEXT`, `success` a
`SMALLINT`); its camel-case column names fold to lower case and read back under
the same names, because PostgreSQL results are matched without regard to
case.

`initializeMigration` binds the instance to one `(data source, schema)` pair,
creates that pair's table if absent and loads its applied versions (mapped onto
`TomDbVersion`); a failure to create the table is
`<initialize>.initialize.schema_creation_failed`
(`mariadb_migration_adapter.initialize.schema_creation_failed`,
`postgres_migration_adapter.initialize.schema_creation_failed`), and a failure
to read the history `<initialize>.initialize.version_query_failed`
(`mariadb_migration_adapter.initialize.version_query_failed`,
`postgres_migration_adapter.initialize.version_query_failed`). Because one
instance serves every schema of its type in turn,
binding is a **rebind**: the loaded version list is *replaced*, never extended,
so it always describes the schema currently in hand. `applyMigration` refuses —
with `<apply>.apply_migration.not_initialized_for_schema`
(`mariadb_migration.apply_migration.not_initialized_for_schema`,
`postgres_migration.apply_migration.not_initialized_for_schema`) — to run
against any pair the instance is not currently bound to, rather than judging a
migration against another schema's history.

That loaded list **is** the method's output — it returns nothing. The history is
what a caller wants, and no single number stands for it: once environment tags
(C-16) are in play, "the lowest version" and "the version installed first" are
different rows. The list comes back in **installation order, oldest first**
(`installedRank`, read with an explicit `ORDER BY`), which is *not* version
order whenever migrations were applied out of numeric order — a box switched to
`dev` applies `[1]@dev` after the untagged `[3]` it already had, leaving the
history `3, 1, 2`. Sort a copy by `version` if version order is what you need.

`applyMigration` then, per script:

- if the `version` is already recorded, verifies the **description matches**
  (`<apply>.apply_migration.description_mismatch` —
  `mariadb_migration.apply_migration.description_mismatch`,
  `postgres_migration.apply_migration.description_mismatch`), the recorded
  **checksum is readable**, and the **checksum matches**
  (`<apply>.apply_migration.checksum_mismatch` —
  `mariadb_migration.apply_migration.checksum_mismatch`,
  `postgres_migration.apply_migration.checksum_mismatch`; a mismatch means a
  past migration was edited) and skips;
- otherwise hands the script to `applyScript`, which runs it and records the
  outcome, and on failure throws `<apply>.apply_migration.failed`
  (`mariadb_migration.apply_migration.failed`,
  `postgres_migration.apply_migration.failed`), carrying the script's error as
  its root cause. A failure to write the outcome row is reported instead as
  `<apply>.apply_migration.update_version_table_failed`
  (`mariadb_migration.apply_migration.update_version_table_failed`,
  `postgres_migration.apply_migration.update_version_table_failed`).

### The outcome row is written with bound parameters

The `INSERT` into `<schema>_versioning` binds every value — `version`,
`description`, `script`, `checksum`, `executionTimeMs`, `success` — as a named
parameter. Nothing is interpolated into the statement text, and there is no
escaping step to get right.

That is not a stylistic preference. The `script` column stores the migration's
**full body**, and a migration script routinely contains quote characters: a
seed row with a JSON payload, an apostrophe in an English comment, a default
like `'["a","b"]'`. Interpolated, the first of those closes the string literal
early and the server is handed a fragment — so the *recording* of a perfectly
good migration fails after the migration itself has already run, which is the
worst moment for this module to fail. Binding removes the question rather than
answering it.

The **table name** is the one part that is interpolated (`${schemaName}_versioning`,
in all three of the adaptor's statements), because an identifier cannot be a
bound parameter. It is not migration content: it is the schema directory's name,
taken from the tree the deployment ships and fixed before any script is read.

### A failed script: recorded on MariaDB, rolled back on PostgreSQL

**MariaDB does not roll DDL back.** Each DDL statement commits on its own, so a
script that fails at its third statement has applied the first two, and nothing
can take them back. `MariadbMigrationAdaptor` therefore runs the script
statement by statement, times it, and records the outcome whichever way it
went: a failed script gets a row with `success = 0` and the time spent before
the failure, and then the error is rethrown. That row is what makes the next run
stop — see [A recorded failure stops the next run](#a-recorded-failure-stops-the-next-run).

**PostgreSQL rolls DDL back, and its adaptor relies on it.**
`PostgresMigrationAdaptor` runs the script's statements and the row recording
it inside one `TomTransactionManager.runInTransaction`. A script that fails
part-way is undone entirely — its first `CREATE TABLE` included — nothing is
recorded, and the error is thrown as `postgres_migration.apply_migration.failed`
with a message saying it was rolled back. The next run applies the script again
from the start, against a schema exactly as it was before the attempt, so a
failure on PostgreSQL never needs the human repair a MariaDB failure does.

The one kind of statement that cannot ride along is one PostgreSQL refuses
inside a transaction — `CREATE INDEX CONCURRENTLY`, `CREATE DATABASE`,
`VACUUM`. A script containing one fails with the server's own message naming the
statement. Such a statement belongs outside the migration chain, as a separate
single-statement operation.

### Reference migrations for PostgreSQL

Every module that owns framework tables ships its reference migrations under
`example/<module>/migrations/main/tomcore/`, written in the framework's
canonical DDL — MariaDB's spelling, which is also what the convergence guard
reads ([The Framework's Own Tables](#the-frameworks-own-tables)). Beside each
such tree sits its PostgreSQL form, `example/<module>/migrations_postgresql/main/tomcore/`,
under the same file names: the canonical script put through
`PostgresSqlDialect.translateCanonicalScript` (see
[datasources.md](datasources.md#one-declaration-every-database)) under a
three-line header naming the file it came from. A PostgreSQL deployment copies
that tree the way a MariaDB one copies the other.

The PostgreSQL files are **generated, never edited**: change the canonical file
and regenerate them all.

```bash
dart run tool/generate_postgres_migrations.dart
```

`test/postgres_migrations_test.dart` requires every canonical reference
migration to have a PostgreSQL form and each form to be exactly what the
generator writes for its source, so a canonical migration changed without
regenerating fails the suite rather than a PostgreSQL deployment.

## Idempotency and Stability

Recording every applied version makes re-running `migrateDatabases` safe: only
genuinely new versions execute. Recording the **checksum** enforces that
historical migrations stay immutable — editing an already-applied script is a
hard error rather than a silent divergence between environments.

### A recorded failure stops the next run

The outcome row is written on both paths: a script that raised is recorded with
`success = 0` before the error is rethrown. That row is read back.
`initializeMigration` refuses to bind to a schema whose history holds one,
raising `<initialize>.initialize.failed_migration_recorded`
(`mariadb_migration_adapter.initialize.failed_migration_recorded`,
`postgres_migration_adapter.initialize.failed_migration_recorded`) and naming
the version, the description, the schema and the repair. Only the MariaDB
adaptor writes such a row; the PostgreSQL adaptor reads the same history and
refuses the same way when it holds one — a row a hand-written repair or an
imported history left behind.

Read back, because for a long time it was not, and the consequence is the reason
this section exists at all. A failed version is *present* in the history, and its
description and checksum agree with the script — both were written from it — so
the idempotency rule above found it applied and skipped it, silently, from then
on. The column recording the failure was written by this module and read by
nobody in it.

The refusal is deliberately blunt. MariaDB does not roll DDL back, so a script
that failed halfway left statements behind and the schema is in a state nothing
describes; re-running it blindly meets its own `CREATE TABLE` on a table that
now exists. So the run stops, before any script is offered — which also stops
the migrations *after* the failed one, and stops on a node whose environment
tags mean it would never have run that script. Both follow from where the
damage is: in the database the node is about to use, not in the tree it would
have applied.

Repair is a human's. Finish or undo what the script left, then repair the
record — mark it resolved to count the migration as applied, or remove it to
have the migration applied again. See
[Repairing a Failed Migration](#repairing-a-failed-migration).

### The checksum has to outlive the process that wrote it

The checksum is written once, when a migration is applied, and read back on
every startup thereafter — by a different process, quite possibly on a different
machine, a different platform and a different SDK. So it can only be a value
that means the same thing everywhere: `TomSqlMigrationAdaptor.checksumOf`
returns the lowercase hex **SHA-256 of the script's UTF-8 bytes**, and the
comparison is a string comparison of that text.

`String.hashCode` stored as a decimal string is the obvious cheaper choice and
is not usable here. Dart guarantees that value only within a single run: it
varies with the SDK release, the platform, and the isolate's hash seed. Nothing
shows until it changes — and then *every row already recorded, in every deployed
database, becomes a mismatch at the same moment*. The failure is total, it
happens at startup, and it presents as `checksum_mismatch`, which is the module
saying "someone edited a migration". An operator's first instinct would be to
look for an edit that never happened.

A digest is checkable in a way a hash code is not: a test pins
`checksumOf('CREATE TABLE orders (id INT PRIMARY KEY);')` to the literal
`9ad9167c…`, so a change of algorithm fails the suite instead of a deployment.
The value is also reproducible outside Dart, so an operator repairing a row can
compute what the adaptor expects (`shasum -a 256 < the-script.sql`).

The comparison being textual matters too: it cannot throw. The previous code
parsed the column with `int.parse`, so a stored value that was not a number
escaped the module as an unhandled `FormatException` — naming neither the schema
nor the migration.

> **No upgrade path is provided.** A database whose versioning table still holds
> the old hash-code checksums will fail its stability check on the next run. Fix
> it by recomputing each row's `checksum` from its stored `script`
> (`UPDATE <schema>_versioning SET checksum = <sha256 of script>`).

### An unreadable checksum is not an edited migration

Before the two checksums are compared, the stored one is checked for *shape*:
`TomSqlMigrationAdaptor.isWellFormedChecksum` — the counterpart of `checksumOf`
— accepts exactly 64 lowercase hex characters, anchored at both ends. A value
that fails it is rejected with its own key,
`<apply>.apply_migration.checksum_unreadable`
(`mariadb_migration.apply_migration.checksum_unreadable`,
`postgres_migration.apply_migration.checksum_unreadable`), and never reaches the
comparison.

The distinction is not pedantry: the two facts call for opposite responses.

| Stored value | Key | What it means | What to do |
| ------------ | --- | ------------- | ---------- |
| a digest, but a different one | `checksum_mismatch` | the script was edited after it was applied | find the edit |
| not a digest at all | `checksum_unreadable` | the row was not written by `applyMigration` | recompute it from the row's `script` |

The unreadable case is reachable by ordinary means, not just by tampering. The
versioning DDL declares `checksum VARCHAR(200) NOT NULL DEFAULT ''`, so any row
inserted by anything other than `applyMigration` — a hand-written repair, a
partially applied insert, an older schema — carries the empty string. A database
written before the checksum became a content digest carries a decimal
`String.hashCode`. Reporting either as a mismatch would tell the operator to go
looking for an edit that never happened — the same misdirection the hash-code
checksum would eventually have caused, arriving by a different route.

Anchoring the pattern is deliberate. An unanchored one would accept a padded or
prefixed value (`" 9ad9167c… "`, `"sha256:9ad9167c…"`) as well-formed, and no
string comparison could ever match it — an unreadable row would become a
permanent, unexplainable mismatch instead.

## Repairing a Failed Migration

A failed MariaDB script leaves its schema part-applied and its record with
`success = 0`, and every later run refuses the schema until the record is
resolved ([A recorded failure stops the next run](#a-recorded-failure-stops-the-next-run)).
Resolving it is two steps, and only the second is the module's:

1. **The operator puts the schema right**, by hand — undoes what the script
   left behind, or finishes what it set out to do. Nothing in the module can do
   this: which statements ran is in the database, and what they should have
   been is a judgement.
2. **The operator repairs the record**, telling the next run which of the two
   was done:

```dart
await TomDbMigrations.repair(
  'app_db',                     // the data source
  'app_schema',                 // the schema
  7,                            // the version recorded as failed
  TomMigrationRepair.remove,    // or TomMigrationRepair.markResolved
);
```

`TomDbMigrations.repair(datasourceName, schemaName, version, action)` resolves
the registered data source and its migrator as `migrateDatabases` does and
calls `TomDbMigrator.repair(dsi, schemaName, version, action)`. Repair changes
the history only — **it never runs a script** — and it runs under the
[migration lock](#one-run-per-database-at-a-time-the-migration-lock), so it
cannot interleave with a migration run of another process. It touches only the
rows of that version whose `success` is not `1`, and it logs what it did, naming
the version, its description and the action.

On PostgreSQL a failed script is rolled back together with its record (see
[A failed script](#a-failed-script-recorded-on-mariadb-rolled-back-on-postgresql)),
so the case repair resolves arises chiefly on MariaDB. The PostgreSQL adaptor
repairs the same way when its history holds such a record — one an imported
history left behind.

### Remove, or mark resolved

The two actions answer what the operator did to the schema:

| Action | The operator | The record | The next run |
| ------ | ------------ | ---------- | ------------ |
| `TomMigrationRepair.remove` (`--repair-action=remove`) | undid what the script left behind, and may have corrected the script | deleted | applies the migration again, from the script file as it is then |
| `TomMigrationRepair.markResolved` (`--repair-action=resolve`) | finished by hand what the script set out to do | kept, with `success = 1` | skips the migration, as applied |

Choose `remove` when the schema is back where it was before the script ran.
The script file may be corrected first — its record is gone, so there is no
checksum to disagree with — and that is the usual case: the script failed for a
reason, and the reason is in the script.

Choose `markResolved` when the schema is where the script meant to take it.
The kept record carries the checksum of the script **as it was recorded**, so
the script file must stay exactly as it was: a corrected file fails the next
run's [checksum check](#the-checksum-has-to-outlive-the-process-that-wrote-it)
with `<apply>.apply_migration.checksum_mismatch`. A correction that has to ship
belongs in the next migration.

### From the command line

A repair is an operator's one-off command, not a step of every start, so a
server's start script offers it as two options and exits once it ran:

```dart
// After the data sources are registered, before migrateDatabases:
if (await TomDbMigrations.repairFromArgs(args)) {
  tomLog.info('Migration repaired, exiting.');
  exit(0);
}
```

```sh
dart run bin/server_start.dart \
  --repair-migration=app_db/app_schema/7 --repair-action=remove
dart run bin/server_start.dart \
  --repair-migration=app_db/app_schema/7 --repair-action=resolve
```

`TomDbMigrations.repairFromArgs(args)` reads
`--repair-migration=<datasource>/<schema>/<version>`
(`TomDbMigrations.repairMigrationOption`) and `--repair-action=remove|resolve`
(`TomDbMigrations.repairActionOption`), runs the repair and answers `true`.
Without `--repair-migration` it does nothing and answers `false`, so the start
goes on. A request it cannot read — a target that is not three `/`-separated
parts with a whole-number version, or an action other than `remove` or
`resolve`, including a missing one — throws
`db_migration.repair.invalid_arguments`, naming the two options and what was
given; nothing is repaired. The four servers in `tom_core_samples` wire it this
way.

### What repair refuses

| Key | When |
| --- | ---- |
| `db_migration.repair.invalid_arguments` | `repairFromArgs` was given a malformed `--repair-migration` or `--repair-action` |
| `db_migration.migration.no_datasource_info_found` | no data source is registered under the name |
| `db_migration.migration.no_migrator_found_for_datasource_type` | no migrator is registered for the data source's `type` |
| `<initialize>.repair.no_failed_record` (`mariadb_migration_adapter.repair.no_failed_record`, `postgres_migration_adapter.repair.no_failed_record`) | the schema holds no failed record of that version — it is applied, or was never attempted. An applied migration is not repaired; repair resolves failures only. The exception carries `schema`, `datasource` and `version` |
| `<initialize>.repair.failed` (`mariadb_migration_adapter.repair.failed`, `postgres_migration_adapter.repair.failed`) | the history could not be read, or the record could not be deleted or updated; the database's error is the root cause |
| `<initialize>.lock.not_a_sql_datasource` | the data source has no session lock to repair under |
| `error.datasource.session_lock_timeout` | another process held the migration lock for longer than `lockWait` |

## Rolling Migrations Back

A rollback undoes applied migrations with their [down scripts](#down-scripts):
every migration of one schema applied above a version, newest first.

```dart
final undone = await TomDbMigrations.rollback(
  configuration.databaseMigrationsDirectory, // the migration tree
  datasource: 'app_db',
  schema: 'app_schema',
  toVersion: 4,                              // keep 4 and below; -1 keeps none
);
// undone: the versions undone, in the order they were — e.g. [7, 6, 5]
```

`TomDbMigrations.rollback(directory, datasource:, schema:, toVersion:)`
resolves the registered data source and its migrator as `migrateDatabases`
does, reads the schema directory `<directory>/<datasource>/<schema>/` and
calls `rollbackDataSource(migrator, dsInfo, dataSourceDirectory, schema,
toVersion:)`, which takes the migrator as a parameter as `migrateDataSource`
does. That reads every migration of the tree with its down script into a
`TomMigrationScript(description, up, down)` per version and hands them to
`TomDbMigrator.rollback(dsi, schemaName, toVersion, scripts)`, under the
[migration lock](#one-run-per-database-at-a-time-the-migration-lock).

The order is the history's, not the file names': the migrations recorded above
`toVersion` are undone **newest installed first**, by `installedRank`. Where
migrations were applied out of numeric order — a box switched to `dev` that
applied `[1]@dev` after the untagged `[3]` — that is the reverse of the order
they went in, which is the only order in which each down script meets the
schema its migration left. Environment tags do not filter a rollback: it undoes
what the history records, and the history may hold a migration this process's
environment would not apply.

Each migration is undone by running its down script and then **deleting its
record** from `<schema>_versioning` (`forgetMigration`), so the next forward run
applies it again. Nothing is undone when nothing was applied above `toVersion`;
the answer is then an empty list.

### What is checked before anything is undone

A rollback that stops half-way for a reason it could have seen leaves a schema
between two versions nobody chose, so everything is checked before the first
down script runs:

1. **The history holds no failed record.** The rollback starts with
   `initializeMigration`, which refuses a schema whose history records a failed
   script ([A recorded failure stops the next run](#a-recorded-failure-stops-the-next-run));
   [repair](#repairing-a-failed-migration) it first.
2. **Every migration to undo has a down script.** One without is refused with
   `<apply>.rollback_migration.no_down_script`.
3. **Every migration to undo is recorded with the script the tree holds** — the
   same description and the same checksum of the up script. A down script is
   written against the migration it undoes; when the up script in the tree is
   not the one that ran, nothing says the down script undoes what ran, and the
   rollback is refused with `<apply>.rollback_migration.script_changed`.

Both refusals carry the parameters `version` and `schema`, and leave the schema
and its history exactly as they were.

### A failed down script: left half-way on MariaDB, rolled back on PostgreSQL

A down script fails the way a migration does, and the two databases leave
different things behind:

- **PostgreSQL** runs the down script's statements and the deletion of the
  record inside one `TomTransactionManager.runInTransaction`. A down script
  that fails undoes nothing: the migration stays applied and recorded, and the
  rollback stops with `postgres_migration.rollback_migration.failed`. The
  migrations undone before it stay undone.
- **MariaDB does not roll DDL back.** A down script that fails part-way leaves
  the statements it ran done, and the migration **stays recorded** — the schema
  is between the two versions, as after a failed migration. The rollback stops
  with `mariadb_migration.rollback_migration.failed`; the operator puts the
  schema right by hand and either corrects the down script and rolls back
  again, or reapplies what the down script took away.

### Rolling back from the command line

A rollback is an operator's one-off command, like a repair, so the start
scripts offer it beside the repair and exit once it ran:

```dart
// After the data sources are registered, before migrateDatabases:
if (await TomDbMigrations.rollbackFromArgs(
  args,
  configuration.databaseMigrationsDirectory,
)) {
  tomLog.info('Migrations rolled back, exiting.');
  exit(0);
}
```

```sh
dart run bin/server_start.dart --rollback-migrations=app_db/app_schema/4
dart run bin/server_start.dart --rollback-migrations=app_db/app_schema/-1
```

`TomDbMigrations.rollbackFromArgs(args, directory)` reads
`--rollback-migrations=<datasource>/<schema>/<version>`
(`TomDbMigrations.rollbackMigrationsOption`), runs the rollback against the
migration tree `directory`, logs the versions it undid and answers `true`.
Without the option it does nothing and answers `false`, so the start goes on. A
target that is not three `/`-separated parts with a non-empty data source and
schema and a whole-number version throws
`db_migration.rollback.invalid_arguments`, naming the option and what was
given; nothing is rolled back. The four servers in `tom_core_samples` wire it
this way.

### What a rollback refuses

| Key | When |
| --- | ---- |
| `db_migration.rollback.invalid_arguments` | `rollbackFromArgs` was given a malformed `--rollback-migrations` |
| `db_migration.rollback.invalid_target` | `toVersion` is below `-1` |
| `db_migration.migration.no_datasource_info_found` | no data source is registered under the name |
| `db_migration.migration.no_migrator_found_for_datasource_type` | no migrator is registered for the data source's `type` |
| `db_migration.migration.migrations_directory_not_found` | the schema directory is not in the tree |
| `db_migration.migration.duplicate_migration_basename` | two up files, or two down scripts, claim one migration |
| `<initialize>.initialize.failed_migration_recorded` (`mariadb_migration_adapter.initialize.failed_migration_recorded`, `postgres_migration_adapter.initialize.failed_migration_recorded`) | the schema's history records a failed script |
| `<apply>.rollback_migration.no_down_script` (`mariadb_migration.rollback_migration.no_down_script`, `postgres_migration.rollback_migration.no_down_script`) | a migration to undo has no down script in the tree; nothing is undone |
| `<apply>.rollback_migration.script_changed` (`mariadb_migration.rollback_migration.script_changed`, `postgres_migration.rollback_migration.script_changed`) | a migration to undo is recorded with a different description or up script than the tree holds; nothing is undone |
| `<apply>.rollback_migration.failed` (`mariadb_migration.rollback_migration.failed`, `postgres_migration.rollback_migration.failed`) | a down script, or the deletion of its record, failed; the database's error is the root cause |
| `<initialize>.lock.not_a_sql_datasource` | the data source has no session lock to roll back under |
| `error.datasource.session_lock_timeout` | another process held the migration lock for longer than `lockWait` |

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

### When the Entity Model Contradicts Itself

Several entities may map the same table, and that is normal: a table is often
read through more than one projection, and the projections differ only in which
columns and which member shapes they present. `TomEntitySchemaReader.read`
merges their columns for exactly that reason.

Their **primary keys** cannot be merged, because a table has exactly one. If two
entities on one table declare different keys, one of the two declarations is
wrong, and no migration chain can reconcile them. `read` therefore returns
findings alongside the model: the first entity to declare a table fixes both its
reported origin and its key, and a later entity whose key differs produces a
`conflictingEntityPrimaryKey` error. Keys are compared as case-insensitive sets,
the same tolerance the chain comparison applies, since field declaration order
carries no intent.

The finding is distinct from `primaryKeyMismatch` on purpose. That one says the
entity model and the migration chain disagree, and sends the reader to the
migration scripts; this one says the entity model disagrees with itself, before
the chain is consulted at all, and the scripts are not where the fix goes.

The first key is kept rather than the last because the reported origin and the
reported key then describe the same entity. A union of the two would put a key
in the model that neither entity declares, and the chain comparison would then
report a second, invented mismatch against DDL that is in fact correct. The
verdict is order-independent — the contradiction is reported whichever entity is
read first — while which key survives follows the origin.

### A Version Column Must Hold a Value

Nullability is compared for one kind of column only. Every other mapped field
is Dart-nullable so that an unsaved record can exist, which says nothing about
the column; a `@TomVersion` field is the one declaration that says its column
must hold a value. `TomEntitySchemaReader` therefore reads a version column as
`nullable: false`, and when the chain leaves that column nullable the check
reports `nullableVersionColumn`, an error.

It is an error rather than a warning because the feature cannot work over such a
column: a versioned update matches its row by `version = ?`, and `NULL` equals
nothing, so every save of a row whose version is `NULL` would be refused as a
conflict (see
[Optimistic Locking](object_persistence.md#optimistic-locking)). A table that
gains a version column adds it `NOT NULL` with a default, so the rows already
there take a value:

```sql
ALTER TABLE invoice ADD COLUMN version BIGINT NOT NULL DEFAULT 0;
```

Those rows load at version `0` and move to `1` on their first save. A chain that
never adds the column at all reports the ordinary `missingColumn`.

### Replaying the Chain: What the Guards Mean

`TomSchemaDdlReader` applies each artifact's DDL to an in-memory model in the
order the engine would. Because it is modelling what a *real* server would do, a
statement that would fail against one is a chain defect and is reported — and the
`IF [NOT] EXISTS` guard is precisely how an author says the statement was meant
conditionally.

That gives one rule, applied identically in every direction:

| Statement | Unguarded | Guarded |
| --------- | --------- | ------- |
| `CREATE TABLE` of a table the chain already has | reported | `IF NOT EXISTS` → silent no-op |
| `ADD COLUMN` of a column the table already has | reported | `IF NOT EXISTS` → silent no-op |
| `ALTER TABLE` on a table the chain does not have | reported | — |
| `DROP TABLE` of a table the chain does not have | reported | `IF EXISTS` → silent no-op |

A `DROP` that stayed quiet would be the one hole in that rule, and it would not
stay local: a mistyped table name replays clean, the table it was meant to remove
stays standing in the model, and the mistake resurfaces much later as a table the
entity model has no entity for — a finding that points at the entities, which is
not where the fix goes. `DROP TABLE` takes a list (`DROP TABLE a, b`), and every
name in it is read, for the same reason: a half-applied list leaves tables in the
model that the chain does in fact drop.

### What the Reader Refuses to Guess At

Only one `CREATE TABLE` form is modelled: `CREATE TABLE <name> (<column list>)`,
the one that spells its columns out. The forms that derive their columns from
somewhere else — `AS SELECT …`, `AS (SELECT …)`, `LIKE other` — are rejected as
an unsupported form, because the reader has no way to know what those columns
are without executing the statement, which is precisely what it does not do.

The rejection happens **before the builder is touched**, and that is the part
worth stating. Half-reading one of these is not a contained mistake:

- `CREATE TABLE copy AS SELECT id, name FROM src WHERE x = COALESCE(a, b)` — the
  first parenthesis in the statement belongs to `COALESCE`, so a header parser
  that trusts it reads `a, b` as the column list. Two "unreadable column" errors,
  **and** a table `copy` committed with no columns at all.
- `CREATE TABLE copy AS (SELECT id FROM src)` — worse, because the parenthesised
  SELECT parses *cleanly* as a one-entry column list. No error at all, and a
  fabricated column named `select`.

Either way the bogus table reaches the convergence diff, where every column the
entity model declares on it becomes a `missingColumn` divergence. The report then
describes a disagreement between the entities and the chain that does not exist —
findings generated by the parse failure, pointing away from it.

*Inside* a genuine column list the opposite rule applies, deliberately: an entry
the reader cannot read is reported on its own and the rest of the table survives.
Discarding the table there would manufacture the same derived noise for the sake
of one bad entry. Atomicity is at the level of the statement **form**, not the
entry.

### The Framework's Own Tables

The framework's tables — `tom_job_run`, `tom_lease`, `tom_scheduler_node`,
`tom_job_pause`, `tom_job_run_archive`,
`tom_blob`, `tom_blob_chunk`, `tom_audit_trail`, `tom_oauth_state`,
`tom_scim_resource`, `tom_delivery_report`, `tom_message_inbox`,
`tom_cache_invalidation`, `tom_idempotency_key`, `tom_saga`,
`tom_encryption_key`, `tom_subject_key`, `tom_transaction_decision`,
`tom_export` — are not
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
| The `CREATE TABLE IF NOT EXISTS` each store issues on first use, in the connected database's words | `create(datasource)` / `createStatements(dialect)` |
| The canonical `CREATE TABLE` this check reads | `createTableDdl` |
| The column list of every `SELECT` the store issues | `columnList` / `columnsOf([…])` |
| Every insert and replacing write the store issues | `insertRow(dialect, {column: bind}, ignoreConflict: …)` / `replaceRow(datasource, …)` |

The row writes are keyed by **column name**, not position. A positional list would put
the column list and the value list in lock-step, so adding a column would shift
every value one place along — a worse failure than the one this design removes,
because it type-checks.

Table names stay per-instance constructor arguments, so the descriptor is a
*factory* (`jobRunTable(name)`), and index names are derived from the table name
so two queues in one schema cannot collide.

`frameworkOwnedTables()` returns them all at their default names.

The set is the same in a multi-tenant deployment: these tables serve the whole
deployment and are not created per tenant. Two of them carry the tenant as a
column — `tom_job_run.tenant` (`VARCHAR(32) NOT NULL DEFAULT ''`, part of the
unique window key `(job_name, tenant, scheduled_for)`) and
`tom_delivery_report.tenant` (`VARCHAR(32) NULL`) — and their reference
migrations, `example/scheduling/migrations/main/tomcore/[1]-create_tom_job_run.sql`
and `example/messaging/migrations/main/tomcore/[1]-create_tom_delivery_report.sql`,
declare them.

Five of them can live where a tenant's data lives instead. `tom_message_inbox`
belongs in the data source the consumer's work writes to,
`tom_idempotency_key` in the data source the idempotency store names,
`tom_saga` in the data source the saga store names, beside the data the saga's
steps change, `tom_encryption_key` in the data source the field-encryption
configuration names, beside the data its keys encrypt, and `tom_subject_key` in
the data source the privacy configuration names — which, when tenancy routes
that data source, is the tenant's own schema or database.
Their migrations then belong in the per-tenant tree; see
[tenancy.md](tenancy.md#what-stays-deployment-wide).

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
   exempt from the type comparison: every SQL driver hands the mapper each
   column value as text, so a `String` field is the driver's raw form and claims
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

`verifyLive(datasource, tables)` reads the catalogue through the data source's
dialect (`tableColumnsQuery` — `information_schema.COLUMNS` on MariaDB, the
same view joined to `pg_attribute` on PostgreSQL, both in MariaDB's column
shape) and compares what is actually there with the descriptors. Both sides are
classified in the connected database's dialect: the descriptors' canonical
`TINYINT(1)` is a truth value to MariaDB, and the `smallint` PostgreSQL stores
it as is an integer to PostgreSQL, so each side is read the way the other one
will be. `test/framework_schema_db_test.dart` runs it against both provisioning
routes — the stores' create-on-first-use and the shipped migration files (on
PostgreSQL, the generated `migrations_postgresql` ones), which must not diverge
— and then hand-edits a column to prove the comparison reports something. It is
tagged `db` and skips when no server is reachable; bring one up with
`tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`
(PostgreSQL).

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

## What Returns a Future, and Why

Reading migration files is synchronous everywhere in this module, and the
signatures say so. **A `Future` here means a database is involved** — nothing
else does:

| Synchronous | Asynchronous |
| ----------- | ------------ |
| `TomSchemaConvergenceCheck.checkAll` / `checkSchema` / `readChain` / `verify` | `TomDbMigrations.migrateDatabases` / `migrateDataSource` |
| `TomFrameworkSchemaCheck.verifyChain` / `verifyRowTypes` | `TomDbMigrator.applyMigration` / `initializeMigration` |
| `TomSchemaDdlReader.replay`, `TomDbMigrations.collectMigrationFiles` / `collectDownMigrationFiles` / `isDownMigration` | `TomFrameworkSchemaCheck.verifyLive` |
| `TomSqlMigrationAdaptor.migrationLockName` | `TomDbMigrations.withMigrationLock` / `repair` / `repairFromArgs` / `rollback` / `rollbackDataSource` / `rollbackFromArgs`, `TomDbMigrator.withMigrationLock` / `repair` / `rollback` |

An `async` method whose I/O is all synchronous never yields: the future is
complete before the first `await`, so the signature promises the caller that the
walk is off the event loop while it blocks the loop entirely — a mis-signalled
cost that matters most where these checks actually run, at startup.

The rule is worth keeping because it is what makes the signature readable at a
glance. A caller seeing `Future` knows a connection is in play and a failure can
be a network failure; a caller seeing a plain return knows the work is a file
walk that either produces a report or throws on the spot.

## Reading raw SQL: one lexer, not five

Two things in this module walk migration text character by character: the
**applier**, which must send a script one statement at a time, and the
**reader**, which parses a schema out of it. Both need the same answer to the
same question — *is this character inside a quoted run?* — and getting it wrong
does not fail loudly. It cuts a statement in half inside a string literal and
sends a syntactically broken fragment to the server, or it swallows a closing
quote and welds two statements into one.

`TomSqlLexer` is the single place that answers it. `endOfQuotedRun` finds where
a quoted run closes; `splitStatements` is built on it and is the package's one
statement splitter, used by the applier directly and by the reader through
`TomSchemaDdlReader.splitStatements`. It lives one layer down, in
[datasources](datasources.md) (`sql_lexer.dart`), because the SQL drivers need
the same answer — they refuse a multi-statement command — and a module below
this one cannot import from it.

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
PostgreSQL reads a backslash in an ordinary literal as itself, so `'C:\'` is a
complete literal there. The lexer takes the database's rule as
`backslashEscapes` — a dialect states it as
`TomStandardSqlDialect.backslashEscapes`, `false` for PostgreSQL — and the
PostgreSQL adaptor splits its scripts, and the SQL drivers check for a second
statement, by their own database's rule. The driver's placeholder scan reads the
same rule (`SqlPlaceholderScan.toPositional(backslashEscapes: false)`).

**The splitter keeps comments.** They are not noise that can be dropped on the
way to the server: `/*!40101 SET NAMES utf8 */` is a MariaDB *executable*
comment — real, version-gated SQL — so stripping it would silently discard a
statement the migration author wrote. Comment removal is therefore a separate,
opt-in step, `TomSchemaDdlReader.stripComments`, which only the reader takes
because it compares declared structure rather than executing anything.

Splitting at all matters because the underlying `mysql_client` only half-reads a
multi-statement command: it consumes the first result set and leaves the rest,
desyncing the single shared connection so every later read returns stale data.

### Structure comes from tokens, never from `indexOf`

Once a statement is split off, the reader has to find things inside it: where the
column list opens, where the `ALTER` actions begin, which columns a
`PRIMARY KEY` names. Every one of those is a question about *structure* — about
the token after the table name, or the bracket that opens a group — and none of
them can be answered by searching the raw text for a name or a character.

Searching answers a different question: the **first** place those characters
occur. That is a different place whenever the name is a substring of what
precedes it, and names are substrings of keywords far more often than the
examples suggest. `ALTER TABLE ab ADD COLUMN …` written in ordinary lowercase
finds the `ab` inside `table`; uppercase DDL escapes only because `indexOf` is
case-sensitive. A bracket inside a quoted identifier is likewise a character of a
name, not structure: ``CREATE TABLE `w(1)` (id BIGINT)`` opens its column list at
the *second* `(`.

The failure mode is what makes this worth a rule. Neither misfire raises a parse
error — the reader carries on and builds a **wrong schema**: a table registered
under a truncated name, a column silently never added, a primary key quietly
dropped. The comparison then reports a divergence the chain does not have, with a
message naming a fragment of a keyword. A false divergence that points at the
wrong thing costs more to diagnose than an outright parse failure.

So the reader derives structure two ways only, and never a third:

- **From the token list** produced by its own tokenizer — `ALTER` actions are
  everything past the third token, not everything past the first textual
  occurrence of the name. The tokenizer keeps quoted runs whole and keeps a
  parenthesised group attached to the word before it, so `KEY(a, b)` (which
  MariaDB accepts) is one token; keyword comparisons take the head of a token for
  that reason.
- **From a quote-aware scan** when a character genuinely is the target — finding
  the bracket that opens a group skips quoted runs via `TomSqlLexer`, so brackets
  inside an identifier are passed over.

## Verification

Four suites always run: one per half of the module, the orchestrator, and the
module's error vocabulary.

`test/db_migration_error_keys_test.dart` pins the module's error vocabulary: each case reaches a raise with a real input and asserts the exact key, so a key the module stops raising, or raises for a different condition, fails by name. None needs a database.

`test/db_migration_test.dart` covers the connection-free surface: file-name
parsing and its refusals, ascending-version ordering on the parsed integer,
duplicate basenames and duplicate versions, environment tag parsing and
selection, `resolveActiveEnvironment` and its uninitialised-environment
fallback, adaptor discovery and instantiation, the checksum and its
well-formedness test, and the missing-directory refusal. It also drives
`migrateDataSource` through a stub migrator, which is how the schema lifecycle
— rebind, apply, reset — is asserted without a server.

`test/schema_convergence_test.dart` covers the reading half: type-family
classification and compatibility, `TomSchemaBuilder`, the DDL reader's statement
lexing and its replay of `CREATE` / `ALTER` / `DROP`, `TomEntitySchemaReader`,
and `TomSchemaConvergenceCheck` end to end, including the duplicate-basename and
missing-directory refusals. Two of its groups check the *document* rather than
the code — that the tolerance the summary states is the tolerance the code
applies, and that the builder documents the contract it actually has.

`test/optimistic_locking_test.dart` covers [A Version Column Must Hold a
Value](#a-version-column-must-hold-a-value): an `ADD COLUMN … NOT NULL DEFAULT`
migration converges, a nullable one is reported as `nullableVersionColumn`, and
a chain that never adds the column is a `missingColumn`.
`test/optimistic_locking_db_test.dart` applies that migration through the
adaptor of the database the DB suites run against to a table that already holds
a row.

`test/framework_schema_test.dart` covers the framework-table check against the
shipped migrations, the reflected row types and the statements the stores issue,
and `test/reference_migrations_test.dart` pins the seven entity-owned
migrations; both are described under [Schema
Convergence](#schema-convergence).

`test/structured_logs_readiness_test.dart`, in the group
`framework readiness`, pins `TomDbMigrations.lastRun`: a call against a missing
directory throws and leaves the record `failed`, and the readiness check then
answers not ready — see [Where the last run stands](#where-the-last-run-stands).

`test/db_migration_lock_db_test.dart` covers the [migration
lock](#one-run-per-database-at-a-time-the-migration-lock) and
[repair](#repairing-a-failed-migration) against a live server, two data sources
on one database standing for two processes: two migrators started together, of
which exactly one applies the script; a run that waits for the holder and one
that gives up after `lockWait` with `error.datasource.session_lock_timeout`; a
holder whose session ends — the process gone — releasing the lock to the next;
a run inside `withMigrationLock` not waiting for itself; and repair — `remove`
followed by a run that applies the corrected script, `markResolved` followed by
a run that skips the migration, a version with no failed record refused with
`repair.no_failed_record`, and `repairFromArgs` running the repair the command
line names. Its last group needs no database: no repair option answers `false`,
and a malformed request is refused with `db_migration.repair.invalid_arguments`.

`test/db_migration_rollback_db_test.dart` covers [down scripts and the
rollback](#rolling-migrations-back) against a live server: a set of three
migrations applied, rolled back to a version — newest first, the down scripts'
effects visible — and applied again; `-1` undoing everything and a second
rollback finding nothing to undo; a missing down script and an up script
changed since it was applied refused before anything is undone; a failing down
script leaving the migration recorded; `rollbackFromArgs` running the rollback
the command line names and refusing malformed requests and a target below
`-1`; and a two-phase data source (`mariadb_xa` / `postgresql_xa`) migrating and
rolling back through the adaptor of its database.

`test/postgres_migrations_test.dart` holds the generated PostgreSQL reference
migrations to the generator's output for their canonical sources — see
[Reference migrations for PostgreSQL](#reference-migrations-for-postgresql).

`test/db_migration_db_test.dart` is what only a real server can substantiate, on
whichever database the DB suites run against:
`migrateDatabases` walking the committed tree under `test/fixtures/migrations/`,
the adaptor creating the `<schema>_versioning` table, running the script and
recording the row — then skipping it idempotently on a second run. It carries
the cases a stub cannot reach honestly: the recorded execution time on both the
succeeding and the failing path, an unreadable stored checksum, a script full of
quote characters going in and coming back out intact, and **two schemas under
one data source**, which is the only arrangement that can tell a migrator whose
applied-version state is per `(data source, schema)` pair from one whose state
is per data source. The failure path is asserted per database: on MariaDB a
failed script is recorded with `success = 0` and the next run refuses the
schema; on PostgreSQL a failed script leaves neither its first statement's table
nor a history row behind. `test/framework_schema_db_test.dart` adds the live
catalogue comparison. Both are tagged `db` and skip themselves when no server is
reachable, so the default `testkit :test` run stays green without one; bring a
server up with `tool/run_db_tests.sh` (MariaDB) or
`tool/run_db_tests_postgres.sh` (PostgreSQL).

`example/db_migration/db_migration_example.dart` shows the connection-free
surface a caller touches — the `TomDbMigrationAdaptor` type binding, a
`TomDbVersion` row with its checksum, the file-name grammar and the ordering
rule. The names it exhibits are **parsed rather than printed**, so an example
that claimed a legal name the parser rejects would throw instead of misinforming
its reader. `example/db_migration/db_migration_repair_example.dart` shows the
half of the lock, the repair and the rollback that needs no database: the
lock's name, a command line without a repair answered `false`, malformed repair
requests refused before anything is touched, down scripts collected beside
their migrations and skipped by the forward collection, a command line without
a rollback answered `false`, and malformed rollback requests refused.

One guard is worth naming separately, because it is the reason this page can be
trusted on the subject it is most likely to be wrong about. The file-name
grammar is stated in three places — the source, this guide and the example — and
`db_migration_test.dart` holds all three to what
`parseMigrationFileName` actually accepts, reading the canonical form out of the
parser's own refusal message. It further requires every migration file name any
of the three *exhibits* to parse — a down script's name by the migration it
undoes — and fails on any text still claiming
migrations run in name order. Prose about a grammar drifts from the grammar;
here it cannot drift silently.

## Core Components

- **`TomDbMigrations`** — the orchestrator and reflection-based adaptor
  discovery; `migrateDatabases`, and `lastRun` (a `TomMigrationRun` with its
  `TomMigrationRunState`), the record of the most recent call that readiness
  reads.
- **`TomDbMigrator`** (+ the `TomDbMigrationAdaptor` annotation) — the migrator
  contract, including `withMigrationLock` (one run per database at a time),
  `repair` with its **`TomMigrationRepair`** action, and `rollback` with the
  **`TomMigrationScript`**s it undoes with.
- **`TomDbMigrations.withMigrationLock` / `repair` / `repairFromArgs`** — the
  migration lock by data-source name, the repair of a failed record, and its
  command-line form (`--repair-migration`, `--repair-action`).
- **`TomDbMigrations.rollback` / `rollbackDataSource` / `rollbackFromArgs`**,
  with `collectDownMigrationFiles` / `isDownMigration` / `downSuffix` — the
  rollback of applied migrations with their down scripts, and its command-line
  form (`--rollback-migrations`).
- **`TomSqlMigrationAdaptor`**, **`MariadbMigrationAdaptor`**,
  **`PostgresMigrationAdaptor`** and **`TomDbVersion`** — the database-neutral
  SQL migrator, its MariaDB (`mariadb`, `mariadb_xa`) and PostgreSQL
  (`postgresql`, `postgresql_xa`) implementations, and the versioning-row type.
- **`TomDbMigrationException` / `TomSqlMigrationException` /
  `MariadbMigrationException` / `PostgresMigrationException`** — the error
  types.
- **`TomSchemaConvergenceCheck`** — the application-entity guard, plus
  `TomSchemaModel` / `TomSchemaDdlReader`, the model and the DDL parser both
  guards share.
- **`TomFrameworkSchemaCheck`** — the framework-table guard: `verifyChain`,
  `verifyRowTypes`, `verifyLive`, and `frameworkOwnedTables()`.
- **`TomFrameworkTable`** (in the datasources module) — the single declaration
  every framework table's DDL and statements are derived from.

## Not Yet Implemented

- **A failed MariaDB migration is refused until an operator repairs it.**
  `initializeMigration` reads the history and stops the run when it holds a
  `success = 0` row, naming the version, the description, the schema and the
  repair — see [Idempotency and Stability](#idempotency-and-stability). Nothing
  retries the script and nothing undoes what it left: the operator finishes or
  reverses the part-applied change by hand and then
  [repairs the record](#repairing-a-failed-migration), which only changes the
  history.

  On PostgreSQL the case does not arise: a failed script is rolled back with
  its version row and is simply applied again on the next run (see
  [A failed script](#a-failed-script-recorded-on-mariadb-rolled-back-on-postgresql)).
  On MariaDB, refusing is the answer rather than retrying because **MariaDB does
  not roll DDL back**: a script that failed halfway has already applied the statements
  before the failure, so a blind re-run meets its own `CREATE TABLE` on a table
  that now exists and fails again, every time. And the refusal is not
  conditional on the node caring about that migration — a schema whose middle is
  unknown is not one later statements can be reasoned about, so it blocks the
  migrations after it too, and blocks on a node whose environment tags mean it
  would never have run the script. The damage is in the database the node is
  about to use, not in the tree it would have applied.
  <!-- pinned: test/db_migration_db_test.dart › stops the whole run, not just its own version -->
- **A down script is not recorded.** The versioning row holds the up script
  and its checksum; a down script is read from the tree when a rollback runs,
  and only its presence is checked. The up script's checksum is what ties a
  down script to the migration it undoes — an edit to the down script itself
  is not detected.
  <!-- unpinned: absence — the versioning table has no column for a down script -->
- **Nothing checks that a down script undoes its migration.** The
  [convergence check](#schema-convergence) replays the forward chain only; a
  down script that leaves a table behind, or drops one its migration did not
  create, is found when a rollback runs, not before.
  <!-- unpinned: absence — no check replays a down script -->
- **The migration lock excludes only runs made through this module.** It is a
  session lock the migrators take; SQL applied by anything else — a database
  container's init hook running the same tree, a DBA's session, another
  migration tool — does not ask for it and is not held back by it.
  <!-- unpinned: absence — the lock is advisory; nothing outside the migrators takes it -->
- **The application-entity check never reads a live database.**
  `TomFrameworkSchemaCheck` has [a live half](#what-the-live-check-adds);
  `TomSchemaConvergenceCheck` has no counterpart. It compares the entity model
  to the *migration chain*, so it proves the chain would build the right shape
  and says nothing about the shape a given server actually has. A hand-edited
  application table is invisible to it, which is precisely the class of drift
  the framework-table check added `verifyLive` to catch.
  <!-- unpinned: absence — no live counterpart to the convergence check exists -->

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `sql_migration_adaptor.dart` | `Future` |
| `dart:convert` | dart | `sql_migration_adaptor.dart` | `utf8` |
| `dart:io` | dart | `db_migration.dart`, `schema_convergence.dart` | walking the migration directory tree |
| `crypto` | package | `sql_migration_adaptor.dart` | `sha256`, for the checksum that pins a migration's SQL to the row recording it |
| `meta` | package | `sql_migration_adaptor.dart` | `@protected` on the members an adaptor supplies or calls |
| `path` | package | `db_migration.dart`, `schema_convergence.dart` | migration-file name parsing |
| `tom_core_kernel` | package | `db_migration.dart`, `framework_convergence.dart`, `mariadb_migration_adapter.dart`, `postgres_migration_adapter.dart`, `sql_migration_adaptor.dart`, `schema_convergence.dart` | `tomReflector` (adaptor discovery, row mapping), `tomLog` |
| [audit](audit.md) | module | `framework_convergence.dart` | `auditTrailTable`, `defaultAuditTrailTable` |
| [authentication](authentication.md) | module | `framework_convergence.dart` | `defaultOAuthStateTable`, `defaultScimResourceTable`, `oauthStateTable`, `scimResourceTable` |
| [cache](cache.md) | module | `framework_convergence.dart` | `defaultInvalidationTable`, `invalidationTable` |
| [cmdline](cmdline.md) | module | `db_migration.dart` | `TomArgs.parseArgsToMap`, reading `--repair-migration`, `--repair-action` and `--rollback-migrations` |
| [datasources](datasources.md) | module | 8 of 8 files | `TomDataSourceInfo` (named data sources) and its `executeCommand` / `executeQuery`; `TomSqlLexer`, the statement splitter and quote scanner; the connected data source's dialect, which `verifyLive` classifies and queries the catalogue with; `TomSqlDatasource.withSessionLock`, which holds the migration lock |
| [endpoints](endpoints.md) | module | `framework_convergence.dart` | `defaultIdempotencyTable`, `idempotencyTable` |
| [export](export.md) | module | `framework_convergence.dart` | `defaultExportRegisterTable`, `exportRegisterTable` |
| [file_storage](file_storage.md) | module | `framework_convergence.dart` | `blobChunkTable`, `blobManifestTable`, `defaultBlobChunkTable`, `defaultBlobManifestTable` |
| [little_things](little_things.md) | module | `db_migration.dart`, `mariadb_migration_adapter.dart`, `postgres_migration_adapter.dart`, `sql_migration_adaptor.dart` | `TomServerException` |
| [messaging](messaging.md) | module | `framework_convergence.dart` | `defaultDeliveryReportTable`, `deliveryReportTable`, `defaultInboxTable`, `inboxTable` |
| [object_persistence](object_persistence.md) | module | `framework_convergence.dart`, `sql_migration_adaptor.dart`, `schema_convergence.dart` | `TomDbTable` / `TomDbColumn` on `TomDbVersion`; `defaultEncryptionKeyTable` and `encryptionKeyTable`, the data-key table of field-level encryption |
| [privacy](privacy.md) | module | `framework_convergence.dart` | `defaultSubjectKeyTable`, `subjectKeyTable` |
| [scheduling](scheduling.md) | module | `framework_convergence.dart` | `defaultJobRunTable`, `defaultLeaseTable`, `defaultSchedulerNodeTable`, `defaultJobPauseTable`, `defaultJobRunArchiveTable`, `jobRunTable`, `leaseTable`, `schedulerNodeTable`, `jobPauseTable`, `jobRunArchiveTable` |
| [transactions](transactions.md) | module | `framework_convergence.dart`, `postgres_migration_adapter.dart` | `defaultSagaTable` and `sagaTable`, `defaultDecisionTable` and `decisionTable`; `TomTransactionManager.runInTransaction`, which runs a PostgreSQL script and its version row — or a down script and the deletion of its record — as one transaction |

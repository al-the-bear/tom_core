# Database Migration Module

Versioned, file-driven schema migrations. A directory tree describes the
migrations for each data source and schema; the orchestrator
(`TomDbMigrations`) walks it and applies each script through a
database-specific migrator (`TomDbMigrator`), which records what it applied so
re-runs are idempotent and edits to past migrations are detected. A MariaDB
implementation (`MariadbMigrationAdaptor`) is provided.

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
  - [The Tree Root Has to Be There](#the-tree-root-has-to-be-there)
- [Running Migrations](#running-migrations)
- [Adaptor Discovery](#adaptor-discovery)
- [The MariaDB Adaptor](#the-mariadb-adaptor)
  - [The outcome row is written with bound parameters](#the-outcome-row-is-written-with-bound-parameters)
- [Idempotency and Stability](#idempotency-and-stability)
  - [A recorded failure stops the next run](#a-recorded-failure-stops-the-next-run)
  - [The checksum has to outlive the process that wrote it](#the-checksum-has-to-outlive-the-process-that-wrote-it)
  - [An unreadable checksum is not an edited migration](#an-unreadable-checksum-is-not-an-edited-migration)
- [Schema Convergence](#schema-convergence)
  - [The Application's Entities](#the-applications-entities)
  - [When the Entity Model Contradicts Itself](#when-the-entity-model-contradicts-itself)
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
| `TomDbMigrator` | abstract class | The per-database migrator contract (`initializeMigration` / `applyMigration` / `reset`) |
| `TomDbMigrationAdaptor` | class | Binds a migrator to a data-source type for reflection discovery |
| `TomMigrationFileName` | class | A migration file name parsed into version, description and environment tags |
| `MariadbMigrationAdaptor` | class | The MariaDB migrator |
| `TomDbVersion` | class | One row of a `<schema>_versioning` table |
| `TomDbMigrationException` | class | Orchestration / discovery / parsing failures |
| `MariadbMigrationException` | class | MariaDB migration failures |

### The convergence checks

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomSchemaConvergenceCheck` | class | The comparison: entity model against migration chain |
| `TomEntitySchemaReader` | class | Reads the schema the `@TomDbTable` entity classes expect |
| `TomSchemaConvergenceReport` | class | What one `<datasource>/<schema>` pair was checked against, and how it disagreed |
| `TomSchemaDivergence` | class | One disagreement: kind, table, column, origin, message |
| `TomSchemaDivergenceKind` | enum | Which of the nine disagreements it is — each a different culprit |
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
| `TomSqlLexer` | class | The module's one quote/comment scanner and statement splitter |

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
a `TomDbMigrationException`; see [Environment Tags](#environment-tags) for what
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
`TomDbMigrations.orderMigrationNames`. Two details of *how* it is refused are
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

Building a candidate is the one step here that can fail for a reason outside
the module, so `instantiateMigrator` reports it in full: the constructor's
error is named in the message **and** forwarded as the raised exception's root
cause, together with the trace from where it was thrown. The name of the class
that could not be built says nothing about why — a missing zero-argument
constructor, a throwing field initialiser and a failed dependency lookup all
read alike from the outside — and this runs at startup, over a registry
assembled by reflection, which is the worst position from which to reconstruct
a cause by hand.

## The MariaDB Adaptor

`MariadbMigrationAdaptor` keeps a `<schema>_versioning` table per schema:

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
table by hand.

`initializeMigration` binds the instance to one `(data source, schema)` pair,
creates that pair's table if absent and loads its applied versions (mapped onto
`TomDbVersion`). Because one instance serves every `"mariadb"` schema in turn,
binding is a **rebind**: the loaded version list is *replaced*, never extended,
so it always describes the schema currently in hand. `applyMigration` refuses —
with `mariadb_migration.apply_migration.not_initialized_for_schema` — to run
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

- if the `version` is already recorded, verifies the **description matches**, the
  recorded **checksum is readable**, and the **checksum matches** (a mismatch
  means a past migration was edited → failure) and skips;
- otherwise runs the script, records the outcome — including a failed script
  with `success = 0` — and rethrows on failure.

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

## Idempotency and Stability

Recording every applied version makes re-running `migrateDatabases` safe: only
genuinely new versions execute. Recording the **checksum** enforces that
historical migrations stay immutable — editing an already-applied script is a
hard error rather than a silent divergence between environments.

### A recorded failure stops the next run

The outcome row is written on both paths: a script that raised is recorded with
`success = 0` before the error is rethrown. That row is read back.
`initializeMigration` refuses to bind to a schema whose history holds one,
raising `mariadb_migration_adapter.initialize.failed_migration_recorded` and
naming the version, the description, the schema and the repair.

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

Repair is a human's. Finish or undo what the script left, then set `success = 1`
on the row to record it as applied, or delete the row to have the migration run
again.

### The checksum has to outlive the process that wrote it

The checksum is written once, when a migration is applied, and read back on
every startup thereafter — by a different process, quite possibly on a different
machine, a different platform and a different SDK. So it can only be a value
that means the same thing everywhere: `MariadbMigrationAdaptor.checksumOf`
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
`MariadbMigrationAdaptor.isWellFormedChecksum` — the counterpart of `checksumOf`
— accepts exactly 64 lowercase hex characters, anchored at both ends. A value
that fails it is rejected with its own key,
`mariadb_migration.apply_migration.checksum_unreadable`, and never reaches the
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

## What Returns a Future, and Why

Reading migration files is synchronous everywhere in this module, and the
signatures say so. **A `Future` here means a database is involved** — nothing
else does:

| Synchronous | Asynchronous |
| ----------- | ------------ |
| `TomSchemaConvergenceCheck.checkAll` / `checkSchema` / `readChain` / `verify` | `TomDbMigrations.migrateDatabases` / `migrateDataSource` |
| `TomFrameworkSchemaCheck.verifyChain` / `verifyRowTypes` | `TomDbMigrator.applyMigration` / `initializeMigration` |
| `TomSchemaDdlReader.replay`, `TomDbMigrations.collectMigrationFiles` | `TomFrameworkSchemaCheck.verifyLive` |

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

Three suites always run, one per half of the module plus the orchestrator.

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

`test/framework_schema_test.dart` covers the framework-table check against the
shipped migrations, the reflected row types and the statements the stores issue,
and `test/reference_migrations_test.dart` pins the seven entity-owned
migrations; both are described under [Schema
Convergence](#schema-convergence).

`test/db_migration_db_test.dart` is what only a real server can substantiate:
`migrateDatabases` walking the committed tree under `test/fixtures/migrations/`,
the adaptor creating the `<schema>_versioning` table, running the script and
recording the row — then skipping it idempotently on a second run. It carries
the cases a stub cannot reach honestly: the recorded execution time on both the
succeeding and the failing path, an unreadable stored checksum, a script full of
quote characters going in and coming back out intact, and **two schemas under
one data source**, which is the only arrangement that can tell a migrator whose
applied-version state is per `(data source, schema)` pair from one whose state
is per data source. `test/framework_schema_db_test.dart` adds the live
`information_schema` comparison. Both are tagged `db` and skip themselves when
no server is reachable, so the default `testkit :test` run stays green without
one; bring a server up with `tool/run_db_tests.sh`.

`example/db_migration/db_migration_example.dart` shows the connection-free
surface a caller touches — the `TomDbMigrationAdaptor` type binding, a
`TomDbVersion` row with its checksum, the file-name grammar and the ordering
rule. The names it exhibits are **parsed rather than printed**, so an example
that claimed a legal name the parser rejects would throw instead of misinforming
its reader.

One guard is worth naming separately, because it is the reason this page can be
trusted on the subject it is most likely to be wrong about. The file-name
grammar is stated in three places — the source, this guide and the example — and
`db_migration_test.dart` holds all three to what
`parseMigrationFileName` actually accepts, reading the canonical form out of the
parser's own refusal message. It further requires every migration file name any
of the three *exhibits* to parse, and fails on any text still claiming
migrations run in name order. Prose about a grammar drifts from the grammar;
here it cannot drift silently.

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

## Not Yet Implemented

- **A failed migration is not repaired, only refused.** `initializeMigration`
  reads the history and stops the run when it holds a `success = 0` row, naming
  the version, the description and the table to correct — see
  [Idempotency and Stability](#idempotency-and-stability). That is the whole of
  the handling: nothing retries the script and nothing undoes what it left, so a
  failed migration wedges the schema until a human finishes or reverses the
  part-applied change and then sets `success = 1` or deletes the row.

  Refusing is the answer rather than retrying because **MariaDB does not roll
  DDL back**: a script that failed halfway has already applied the statements
  before the failure, so a blind re-run meets its own `CREATE TABLE` on a table
  that now exists and fails again, every time. And the refusal is not
  conditional on the node caring about that migration — a schema whose middle is
  unknown is not one later statements can be reasoned about, so it blocks the
  migrations after it too, and blocks on a node whose environment tags mean it
  would never have run the script. The damage is in the database the node is
  about to use, not in the tree it would have applied.
- **Migrations are forward-only.** `TomDbMigrator` is `initializeMigration` /
  `applyMigration` / `reset`; there is no down-migration and no `TomDbVersion`
  state for one. Undoing a release means writing the next migration.
- **Nothing arbitrates between two processes migrating at once.** There is no
  lock of any kind — advisory, table-based or otherwise. Two servers starting
  together both read an applied-version list that predates the other, and both
  apply. What saves an ordinary deployment is that the versioning table's insert
  is the only write either of them makes to shared state, not any guard here.
- **One adaptor ships.** `MariadbMigrationAdaptor` is the only implementation of
  `TomDbMigrator` in the package. The annotation-driven discovery described
  under [Adaptor Discovery](#adaptor-discovery) is a real seam — a second
  adaptor needs no change here — but it has never been exercised by a second
  implementation.
- **The application-entity check never reads a live database.**
  `TomFrameworkSchemaCheck` has [a live half](#what-the-live-check-adds);
  `TomSchemaConvergenceCheck` has no counterpart. It compares the entity model
  to the *migration chain*, so it proves the chain would build the right shape
  and says nothing about the shape a given server actually has. A hand-edited
  application table is invisible to it, which is precisely the class of drift
  the framework-table check added `verifyLive` to catch.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `mariadb_migration_adapter.dart` | `Future` |
| `dart:convert` | dart | `mariadb_migration_adapter.dart` | `utf8` |
| `dart:io` | dart | `db_migration.dart`, `schema_convergence.dart` | walking the migration directory tree |
| `crypto` | package | `mariadb_migration_adapter.dart` | `sha256`, for the checksum that pins a migration's SQL to the row recording it |
| `path` | package | `db_migration.dart`, `schema_convergence.dart` | migration-file name parsing |
| `tom_core_kernel` | package | `db_migration.dart`, `framework_convergence.dart`, `mariadb_migration_adapter.dart`, `schema_convergence.dart` | `tomReflector` (adaptor discovery, row mapping), `tomLog` |
| [audit](audit.md) | module | `framework_convergence.dart` | `auditTrailTable`, `defaultAuditTrailTable` |
| [authentication](authentication.md) | module | `framework_convergence.dart` | `defaultOAuthStateTable`, `oauthStateTable` |
| [datasources](datasources.md) | module | `db_migration.dart`, `framework_convergence.dart`, `mariadb_migration_adapter.dart`, `schema_convergence.dart`, `schema_ddl_reader.dart`, `schema_model.dart` | `TomDataSourceInfo` (named data sources) and its `executeCommand` / `executeQuery` |
| [file_storage](file_storage.md) | module | `framework_convergence.dart` | `blobChunkTable`, `blobManifestTable`, `defaultBlobChunkTable`, `defaultBlobManifestTable` |
| [little_things](little_things.md) | module | `db_migration.dart`, `mariadb_migration_adapter.dart` | `TomServerException` |
| [messaging](messaging.md) | module | `framework_convergence.dart` | `defaultDeliveryReportTable`, `deliveryReportTable` |
| [object_persistence](object_persistence.md) | module | `framework_convergence.dart`, `mariadb_migration_adapter.dart`, `schema_convergence.dart` | `TomDbTable` / `TomDbColumn` on `TomDbVersion` |
| [scheduling](scheduling.md) | module | `framework_convergence.dart` | `defaultJobRunTable`, `defaultLeaseTable`, `defaultSchedulerNodeTable`, `jobRunTable`, `leaseTable`, `schedulerNodeTable` |

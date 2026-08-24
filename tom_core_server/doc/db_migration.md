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
  - [One File per Migration](#one-file-per-migration)
  - [The Tree Root Has to Be There](#the-tree-root-has-to-be-there)
- [Running Migrations](#running-migrations)
- [Adaptor Discovery](#adaptor-discovery)
- [The MariaDB Adaptor](#the-mariadb-adaptor)
- [Idempotency and Stability](#idempotency-and-stability)
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

## Idempotency and Stability

Recording every applied version makes re-running `migrateDatabases` safe: only
genuinely new versions execute. Recording the **checksum** enforces that
historical migrations stay immutable — editing an already-applied script is a
hard error rather than a silent divergence between environments.

### The checksum has to outlive the process that wrote it

The checksum is written once, when a migration is applied, and read back on
every startup thereafter — by a different process, quite possibly on a different
machine, a different platform and a different SDK. So it can only be a value
that means the same thing everywhere: `MariadbMigrationAdaptor.checksumOf`
returns the lowercase hex **SHA-256 of the script's UTF-8 bytes**, and the
comparison is a string comparison of that text.

It used to be `String.hashCode`, stored as a decimal string. Dart guarantees
that value only within a single run: it varies with the SDK release, the
platform, and the isolate's hash seed. Nothing would have gone wrong until it
changed — and then *every row already recorded, in every deployed database,
would have become a mismatch at the same moment*. The failure is total, it
happens at startup, and it presents as `checksum_mismatch`, which is the module
saying "someone edited a migration". An operator's first instinct would have
been to look for the edit that never happened.

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

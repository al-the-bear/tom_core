# Scheduling Module

The relational half of the framework's job scheduler: a shared queue and a
shared lock, in the database a server already has, for a cluster whose nodes do
not share a filesystem.

This module implements two contracts and defines nothing. The scheduling *model*
— schedules, windows, retries, missed-window policy, lease semantics, the
execution guarantee — lives in `tom_core_kernel` and is documented in
`tom_core_kernel/doc/scheduling/scheduling.md`. Read that first; this document
covers only what changes when the substrate is a database.

## Table of Contents

- [Overview](#overview)
- [Why the Pair, and Why in One Database](#why-the-pair-and-why-in-one-database)
- [How Exclusion Is Arbitrated](#how-exclusion-is-arbitrated)
- [Why the Claim Is One Statement per Run](#why-the-claim-is-one-statement-per-run)
- [The Schema](#the-schema)
  - [tom_job_run](#tom_job_run)
  - [tom_lease](#tom_lease)
- [Creating the Schema](#creating-the-schema)
- [Time](#time)
- [Wiring a Cluster Node](#wiring-a-cluster-node)
- [Operating Notes](#operating-notes)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomSqlJobStore` | class | `TomJobStore` over one row per scheduled run |
| `TomSqlLeaseLock` | class | `TomLeaseLock` over one row per contended resource |
| `jobRunTableDdl` / `leaseTableDdl` | function | The shipped DDL, parameterised by table name |
| `defaultJobRunTable` / `defaultLeaseTable` | constant | `tom_job_run`, `tom_lease` |
| `sqlInstant` / `parseSqlInstant` | function | The UTC `DATETIME(6)` encoding both stores use |

Both types are ordinary implementations of contracts declared in the kernel.
Nothing here extends, narrows or reinterprets those contracts, and both are
verified against the kernel's own parameterised contract suite rather than
against tests written to fit them.

## Why the Pair, and Why in One Database

`tom_core_kernel` ships two pairs already: memory (one process) and file (any
number of processes that mount the same filesystem). The file pair is a correct
multi-node implementation — it is what the kernel's cross-process isolate tests
exercise — but its assumption is a shared mount, and most clusters do not have
one. They do have a database.

The queue and the lock **must share a failure domain**. A lock in one system and
a queue in another can each be healthy while the other is unreachable, and the
resulting disagreement — the queue says node A claimed the run, the lock says
node B holds it — has no resolution, because neither side is authoritative over
the other. So `TomSqlJobStore` and `TomSqlLeaseLock` are meant to be pointed at
the same `TomDataSource`: one thing to be up, or down.

| Store | Lock | Shared by |
| ----- | ---- | --------- |
| `TomMemoryJobStore` | `TomMemoryLeaseLock` | nothing — one process |
| `TomFileJobStore` | `TomFileLeaseLock` | a filesystem |
| `TomSqlJobStore` | `TomSqlLeaseLock` | a database |

## How Exclusion Is Arbitrated

The database decides, never the application. Every transition is a conditional
statement whose affected-row count *is* the answer:

| Transition | Statement | Winner |
| ---------- | --------- | ------ |
| claim a due run | `UPDATE … WHERE id = :id AND state = 'pending'` | the one update that changes a row |
| first acquisition of a free resource | `INSERT IGNORE` | the insert that creates the row |
| takeover of a lapsed lease | `UPDATE … WHERE resource = :r AND token = :t AND version = :v` | the compare-and-set that matches |
| renewal | `UPDATE … WHERE owner = :o AND token = :t AND released = 0 AND expires_at > :now` | the holder, while it still holds |

Reads exist only to nominate candidates. Every write revalidates each condition
the read relied on, so a candidate that went stale between the two loses at the
database rather than being trusted in Dart.

## Why the Claim Is One Statement per Run

`TomScheduler` **always** supplies an `accept` predicate to `claimDue`, and that
predicate is a stateful Dart closure: it is how the scheduler enforces
`allowOverlap`, and its answer for one run depends on the runs it has already
accepted in the same pass. A Dart closure cannot execute inside SQL.

The two ways to reconcile that with a single batch statement are both worse:

- **Claim the batch, then release the rejects.** During the window between the
  two statements the rejected runs are `running` and therefore invisible to
  peers that *would* have accepted them. Contention would then depend on
  timing rather than on state.
- **Push the predicate into SQL.** It is application logic; it does not
  translate, and pretending it does would fork the kernel's contract.

So `claimDue` scans candidates (`SELECT` due, pending, ordered by `seq`), runs
`accept` in Dart, and issues a conditional `UPDATE … WHERE id = :id AND state =
'pending'` **per accepted candidate**. `affectedRows == 1` means this node won;
`0` means a peer took it first, and the candidate is simply skipped. The claim is
still arbitrated entirely by the database — it is one atomic statement *per run*
rather than one for the batch.

The scan reads `limit * candidateFactor` rows (8× by default) so that a pass
whose predicate rejects most candidates still fills its batch.

One consequence is documented rather than hidden: when the database refuses a
claim, the scheduler's own bookkeeping may briefly record the window as busy even
though this node never ran it. That is conservative in the safe direction — the
window is retried on the next tick, so a run is delayed by a tick, never executed
twice.

## The Schema

The DDL lives in `sql_scheduling_sql.dart` and is shipped verbatim as migration
files under `example/scheduling/migrations/`. `test/scheduling_schema_test.dart`
compares the two and fails if they drift, because a schema that exists in two
places and is checked in one will eventually exist in two versions.

Table names are constructor arguments, and the index names follow them — two
queues in one schema would otherwise collide on `uq_…_window`.

### tom_job_run

One row per scheduled run of a job, shared by every node.

| Column | Type | Role |
| ------ | ---- | ---- |
| `seq` | `BIGINT AUTO_INCREMENT` | Insertion order, so every node scans the queue in the same order |
| `id` | `VARCHAR(191)` | Primary key; what every claim, completion and failure addresses |
| `job_name`, `scheduled_for` | `VARCHAR(160)`, `DATETIME(6)` | The window |
| `run_at` | `DATETIME(6)` | When this run should next be attempted |
| `state`, `attempt` | `VARCHAR(16)`, `INT` | `pending` / `running` / `succeeded` / `failed`, and which attempt |
| `claimed_by`, `claimed_at` | `VARCHAR(191)`, `DATETIME(6)` | The store's own lease on the run |
| `last_error`, `completed_at`, `payload` | `TEXT`, `DATETIME(6)`, `LONGTEXT` | Outcome and carried data |

Two indexes exist because two scans do: `ix_…_due (state, run_at)` for the claim
and `ix_…_lease (state, claimed_at)` for recovery.

**`UNIQUE (job_name, scheduled_for)`** is the load-bearing constraint. It turns
the scheduler's idempotence key — one run per job per window — from a convention
into a database invariant, so a duplicate window cannot exist even when two nodes
plan the same window in the same instant. `job_name` is `VARCHAR(160)`: 640 bytes
in utf8mb4 plus an 8-byte `DATETIME(6)` stays under the 767-byte index limit of
the older InnoDB row formats, so the table can be created on a server that has
not been switched to `DYNAMIC`.

### tom_lease

One row per contended resource. Two columns are load-bearing and neither is
obvious.

**`token`** is the fencing counter, and it is why a released lease keeps its row
(flagged `released = 1`) rather than being deleted. Deleting would restart the
counter at 1 for the next holder, and a token that repeats is not a fencing
token. Retaining the row is also what lets `inspect()` distinguish an orderly
departure from a holder that vanished.

**`version`** is incremented on every write. MariaDB reports *changed* rows, not
matched rows, so an `UPDATE` writing values already present affects zero rows — a
renewal landing in the same clock instant with the same TTL would look like a
lost lease and fall through to takeover. That is precisely the class of bug the
kernel's contract suite caught during csex8 (a self-re-acquisition that wrongly
issued a new token). `version` makes a matching update always change the row, and
doubles as the compare-and-set guard that lets exactly one of several racing
takeovers win.

## Creating the Schema

Two supported routes, and the choice is about who is allowed to run DDL:

- **`createSchema: true`** (the default) — each store issues its
  `CREATE TABLE IF NOT EXISTS` once, lazily, on first use. Right for tests and
  for a single-service deployment.
- **`createSchema: false`** — the schema is owned by the migration module. Copy
  the two files from `example/scheduling/migrations/main/tomcore/` into the
  application's own migration tree and let `TomDbMigrations.migrateDatabases()`
  apply them. Right when the application's database user may not run DDL, which
  is the usual production posture.

The migration layout is the module's standard one:
`<directory>/<datasourceName>/<schemaName>/[<version>]-<description>.sql`.

## Time

Instants are stored as UTC `DATETIME(6)` and are carried through `String` fields
in the row classes. This is deliberate: the MariaDB driver materialises a
`DATETIME` column with `DateTime.parse`, which yields a *local* `DateTime`, and
`DateTime.==` compares `isUtc` as well as the instant — so a UTC value written
would not compare equal to the value read back.

`sqlInstant` renders a fixed-width `YYYY-MM-DD HH:MM:SS.ffffff` literal in UTC.
Fixed width keeps the text ordered in SQL exactly as the instants are ordered in
Dart, so a `run_at <= :now` comparison cannot be surprised by a shorter fraction.
`parseSqlInstant` reconstructs it as UTC.

A caller that passes a local `DateTime` gets a UTC one back: the same moment,
differently labelled. A cluster must not compare wall clocks, so every caller
receives a UTC instant regardless of what it supplied. Clocks are compared across
nodes only through expiry timestamps, so **`leaseTtl` must comfortably exceed the
fleet's worst clock skew**.

## Wiring a Cluster Node

```dart
final store = TomSqlJobStore.named('main', createSchema: false);
final lock = TomSqlLeaseLock.named('main', createSchema: false);

final scheduler = TomScheduler(
  store: store,
  dispatcher: const TomInlineJobDispatcher(),
  ownerId: Platform.localHostname,   // must differ per node
  lock: lock,
  leaseTtl: const Duration(minutes: 1),
);
```

`.named()` resolves a registered `TomDataSourceInfo` and raises
`scheduling.store.unknown_datasource` / `scheduling.lock.unknown_datasource` when
it is absent — a scheduler pointed at a data source that was never registered is
a configuration error, not an empty queue. Pass the same data-source name to
both.

**`ownerId` must be distinct per node.** It is what the lock uses to tell holders
apart; two nodes sharing one would each treat the other's lease as its own.

## Operating Notes

- **The queue is a table, so it can be inspected.** `SELECT state, COUNT(*) FROM
  tom_job_run GROUP BY state` answers "is anything stuck" without a tool.
- **Finished runs accumulate.** `purgeFinished(before:)` deletes terminal runs
  older than a cutoff; the scheduler calls it, but a queue with a high window
  rate wants that cutoff set deliberately.
- **`tom_lease` rows are not garbage.** A released row is retained on purpose
  (see [tom_lease](#tom_lease)); deleting rows to tidy up would reset fencing
  counters. `forget` exists for the per-run resource names that are genuinely
  single-use.
- **Both stores hold no connection state of their own.** They take a
  `TomDataSource` and issue statements; the connection lifecycle is the data
  source's.

## Verification

`test/scheduling_db_test.dart` runs the kernel's contract suite — imported
directly from `tom_core_kernel/test/contracts/scheduling_contract.dart`, not
copied — against both implementations, then adds what only a real database can
substantiate: contended claims across independent connections resolving to
exactly one winner, a rejected candidate remaining claimable by a peer, the
window uniqueness constraint, holder death and recovery, eight-way lease races on
both the free and the lapsed paths, the fencing counter surviving release, and
the shipped migrations building the schema on a dropped database.

It is tagged `db` and skips when no server is reachable, so the default
`testkit :test` run stays green without one. `test/scheduling_schema_test.dart`
covers the connection-free surface (DDL drift, schema invariants, instant
encoding) and always runs.

## Core Components

| File | Contents |
| ---- | -------- |
| `lib/src/tomserver/scheduling/sql_job_store.dart` | `TomSqlJobStore` and its row types |
| `lib/src/tomserver/scheduling/sql_lease_lock.dart` | `TomSqlLeaseLock` and its row type |
| `lib/src/tomserver/scheduling/sql_scheduling_sql.dart` | DDL, table-name defaults, instant encoding |
| `example/scheduling/scheduling_example.dart` | The connection-free surface, runnable |
| `example/scheduling/migrations/main/tomcore/` | The shipped reference migrations |

## Dependencies

- **`tom_core_kernel`** — `TomJobStore`, `TomLeaseLock`, `TomJobRun`, `TomLease`
  and the scheduler that drives them.
- **`datasources`** — `TomDataSource` / `TomDataSourceInfo` for connections and
  parameterised statements.
- **`db_migration`** — optional; the route by which a deployment creates the
  schema instead of letting the stores create it.
- **`reflection`** — the row types are reflected so the data source can
  materialise query results into them.

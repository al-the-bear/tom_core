# Tom Core Server API Reference: Scheduling Module

The relational half of the framework's job scheduler: a shared queue, a shared
lock and a cluster roll call, all rows in the database the application already
has, for nodes that do not share a filesystem.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomSqlJobStore](#tomsqljobstore)
  - [TomJobRunRow](#tomjobrunrow)
  - [TomJobRunWindowRow](#tomjobrunwindowrow)
  - [TomJobBacklogRow](#tomjobbacklogrow)
  - [TomSqlLeaseLock](#tomsqlleaselock)
  - [TomLeaseRow](#tomleaserow)
  - [TomSchedulerNode](#tomschedulernode)
  - [TomSqlSchedulerNodes](#tomsqlschedulernodes)
  - [TomSchedulerNodeRow](#tomschedulernoderow)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/scheduling/sql_job_store.dart`,
`lib/src/tomserver/scheduling/sql_lease_lock.dart`,
`lib/src/tomserver/scheduling/sql_scheduler_nodes.dart`,
`lib/src/tomserver/scheduling/sql_scheduling_sql.dart`.

This module contains only the SQL-backed persistence half of scheduling. It
implements two contracts and defines none of them: the scheduling *model* —
schedules, windows, retries, missed-window policy, lease semantics, the
execution guarantee — and `TomScheduler` itself live in `tom_core_kernel`.
`TomSqlJobStore` implements the kernel's `TomJobStore` over one row per
scheduled run, and `TomSqlLeaseLock` implements `TomLeaseLock` over one row per
contended resource. Both are verified against the kernel's own parameterised
contract suite. There is no scheduler, no job registry and no schedule
expression here.

The queue and the lock must share a failure domain — a queue that says node A
claimed a run while the lock says node B holds it has no resolution — so the
pair is meant to be pointed at the same `TomDataSource`. Exclusion is arbitrated
entirely by the database: every transition is a conditional statement whose
affected-row count *is* the answer. `claimDue` scans candidates, applies the
scheduler's `accept` closure in Dart (a Dart predicate cannot run inside SQL),
and issues one conditional `UPDATE … WHERE id = :id AND state = 'pending' AND
claim_token = :current` per accepted candidate, raising `claim_token` as it goes.
That counter is the queue's fencing token: it makes the returned `TomJobClaim`
name one particular claim of the run, so a node whose lease lapsed while it was
partitioned cannot record an outcome over the peer that took its work. Every
transition out of a claim carries `AND claimed_by = :owner AND claim_token =
:token` for that reason. The claim is the one statement whose lost
acknowledgement is genuinely ambiguous, so a failed claim is classified with
`classifySqlFailure` and, when the server never answered, settled by re-reading
the row.

`TomSqlSchedulerNodes` implements no kernel contract; it is an optional
accelerator this module owns outright. It maintains one row per node, rewritten
on every check-in, so that a departed *node* — as distinct from an expired
*lease* — is noticed within a poll interval and named. Passing it to the store
as `nodes:` makes `recoverAbandoned` check in first and then recover the work of
any peer the roll call declares failed. The lease TTL remains the correctness
floor; the roll call only makes recovery earlier and attributable, and every
roll-call failure is logged rather than propagated. The failure test itself is
Quartz's, exposed as the pure functions `schedulerNodeFailedAfter` and
`isSchedulerNodeFailed` so it can be asserted without a database.

All three tables are declared exactly once, as `TomFrameworkTable` descriptors
in `sql_scheduling_sql.dart`; the `CREATE TABLE` each store issues (in its data
source's dialect), the column list of every `SELECT` and every replacing write
and insert are derived from that one declaration. Table names are constructor arguments, and index names follow them.
Instants are stored as UTC `DATETIME(6)` and carried through `String` fields in
the row types, because the driver materialises a `DATETIME` as a *local*
`DateTime` that would not compare equal to the UTC value written.

## Class Hierarchy

```
TomJobStore  (tom_core_kernel)
    └── TomSqlJobStore  (implements)

TomLeaseLock  (tom_core_kernel)
    └── TomSqlLeaseLock

TomSqlSchedulerNodes
TomSchedulerNode

TomJobRunRow
TomJobRunWindowRow
TomJobBacklogRow
TomLeaseRow
TomSchedulerNodeRow
```

## Classes

### TomSqlJobStore

A `TomJobStore` whose queue is a table in a `TomDataSource`. Holds no connection
state of its own: it takes a data source and issues statements, and every claim,
release and recovery is decided by the affected-row count of a conditional
statement.

- **Implements:** `TomJobStore`

#### Constructors

```dart
TomSqlJobStore(
  TomDataSource datasource, {
  String table = defaultJobRunTable,
  bool createSchema = true,
  int candidateFactor = 8,
  TomSqlSchedulerNodes? nodes,
})
```

#### Factory Constructors

```dart
factory TomSqlJobStore.named(
  String datasourceName, {
  String table = defaultJobRunTable,
  bool createSchema = true,
  int candidateFactor = 8,
  TomSqlSchedulerNodes? nodes,
})
```

Resolves the registered `TomDataSourceInfo` named `datasourceName` and throws a
`TomServerException` (`scheduling.store.unknown_datasource`) when none is
registered — a configuration error better caught at start-up than on the first
tick.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `TomDataSource` | Where the queue table lives (final). |
| `table` | `String` | Name of the queue table; index names follow it, so two queues can share a schema (final). |
| `createSchema` | `bool` | Whether `CREATE TABLE IF NOT EXISTS` is issued lazily on first use; `false` leaves the schema to the migration module (final). |
| `candidateFactor` | `int` | How many due runs to scan per claim when an `accept` predicate is present, as a multiple of `limit`, so rejected candidates do not starve the accepted ones behind them (final). |
| `nodes` | `TomSqlSchedulerNodes?` | The cluster roll call, or `null` when the lease timeout is the only liveness signal (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the queue table if it does not exist. Idempotent, called by every operation, and exposed so a start-up sequence can provision the schema before serving traffic. |
| `enqueue` | `Future<void> enqueue(TomJobRun run)` | *(override)* Writes the run with a replacing write (`TomFrameworkTable.replaceRow`: `REPLACE` on MariaDB; on PostgreSQL a `DELETE` of the rows it supersedes and an upsert, in one transaction), so re-planning a window overwrites it; the unique key on `(job_name, tenant, scheduled_for)` keeps one-run-per-window — per tenant — a database invariant. A payload that is not JSON-encodable is refused by `TomJobStore.encodePayload` while the bind map is built, so no statement is sent. |
| `findWindow` | `Future<TomJobRun?> findWindow(String jobName, DateTime scheduledFor, {String? tenant})` | *(override)* The run recorded for that job and window for `tenant` (`null` matching the stored `''` of a run of no tenant), or `null`. |
| `lastWindow` | `Future<DateTime?> lastWindow(String jobName)` | *(override)* The greatest `scheduled_for` recorded for the job, as a UTC instant, or `null` when it has no runs. |
| `claimDue` | `Future<List<TomJobClaim>> claimDue(DateTime now, String owner, {int limit = 16, bool Function(TomJobRun run)? accept})` | *(override)* Scans pending runs due at `now` ordered by `seq`, applies `accept` in Dart, and issues one conditional compare-and-set per survivor; a candidate a peer claimed first is skipped. Returns a ticket per run actually won, at most `limit`. |
| `release` | `Future<void> release(TomJobClaim claim)` | *(override)* Returns a claimed run to `pending` and clears its lease, fenced on the claim so a completion that raced the release wins. `claim_token` is left where it is — the next claim raises it, and a token that repeats is not a fence. |
| `markStarted` | `Future<void> markStarted(TomJobClaim claim, DateTime now)` | *(override)* Stamps `started_at` at the moment the dispatcher takes the run, fenced on the claim; this is what lets recovery tell an interrupted execution from an abandoned reservation. |
| `renewClaim` | `Future<void> renewClaim(TomJobClaim claim, DateTime now)` | *(override)* Re-stamps `claimed_at`, fenced on the claim, so a run the lease recovered elsewhere is not renewed. Only the heartbeat moves; the token is the claim's identity and touching it would let an attempt's first heartbeat invalidate its own ticket. |
| `complete` | `Future<void> complete(TomJobClaim claim, DateTime now)` | *(override)* Moves the run to `succeeded`, records `completed_at` and clears the lease, fenced on the claim so a late outcome cannot overwrite a peer's or restart a purged run's retention clock. |
| `fail` | `Future<void> fail(TomJobClaim claim, String error, DateTime now, {DateTime? retryAt})` | *(override)* Without `retryAt`, writes the run off as `failed`; with it, returns the run to `pending` at that instant and increments `attempt` in the statement rather than from a possibly stale copy. Both branches are fenced on the claim — the retrying one doubly needs it, since it spends a retry. |
| `recoverAbandoned` | `Future<List<TomJobRun>> recoverAbandoned(DateTime now, Duration leaseTimeout, {bool Function(String jobName)? requestsRecovery})` | *(override)* Checks this node in, then re-queues runs whose lease lapsed (and, with a roll call wired, those held by a failed peer). A run that never started is always re-queued; a started one only when the job opted in, otherwise it is written off with `TomJobStore.recoveryDeclinedError`. |
| `all` | `Future<List<TomJobRun>> all()` | *(override)* Every row in the queue, in insertion order. |
| `backlog` | `Future<List<TomJobBacklog>> backlog(DateTime now)` | *(override)* One `TomJobBacklog` per job with pending runs due at `now` — how many, and the earliest `run_at` among them — in one grouped `SELECT` (projected as `TomJobBacklogRow`). The kernel scheduler reads it for the `tom_job_backlog` and `tom_job_backlog_age_seconds` gauges when a scrape or an export takes a snapshot. |
| `purgeFinished` | `Future<int> purgeFinished(DateTime before)` | *(override)* Deletes terminal runs completed before the cutoff and returns how many were removed. |
| `deleteAll` | `Future<void> deleteAll()` | Empties the queue table. Not part of `TomJobStore` — for provisioning and for tests that need a known-empty queue. |
| `toString` | `String toString()` | *(override)* Renders `"TomSqlJobStore(<table>)"`. |

### TomJobRunRow

One row of the job queue table, as the result mapper materialises it. Reflected
and `@TomDbTable`-annotated because the row mapper requires both; the annotation
values are placeholders, since the real table name is a constructor argument of
`TomSqlJobStore`.

#### Constructors

```dart
TomJobRunRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | The run's stable id, and the primary key every other statement addresses. |
| `jobName` | `String` | The job this run belongs to. |
| `tenant` | `String` | The run's tenant, or `''` for a run of no tenant — `''` rather than `NULL` because a unique key never treats two `NULL`s as equal. |
| `scheduledFor` | `String` | The schedule window, as stored UTC text. |
| `runAt` | `String` | When the run may next be attempted, as stored UTC text. |
| `state` | `String` | The `TomJobRunState` name. |
| `attempt` | `int` | How many times the run has been attempted, counting from one. |
| `claimedBy` | `String?` | The node currently holding the run, or `null` when it is unclaimed. |
| `claimedAt` | `String?` | When the claim was last stamped, as stored UTC text. |
| `claimToken` | `int` | Which claim of this run is current — the queue's fencing token. |
| `startedAt` | `String?` | When the body began executing, as stored UTC text; `null` if it never did — the one column separating an interrupted execution from an abandoned reservation. |
| `lastError` | `String?` | The message of the most recent failure. |
| `completedAt` | `String?` | When the run reached a terminal state, as stored UTC text. |
| `payload` | `String?` | The JSON text of the run's payload, written by the kernel's `TomJobStore.encodePayload` so that every store refuses the same payloads under the same key. |
| `seq` | `int` | Insertion order, which is the queue's natural order. |

### TomJobRunWindowRow

The single aggregate column `TomSqlJobStore.lastWindow` projects. A separate row
type because the mapper binds by column name and the aggregate select has no
other columns to fill.

#### Constructors

```dart
TomJobRunWindowRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `scheduledFor` | `String?` | The latest window, as stored UTC text, or `null` when the job has no runs at all. |

### TomJobBacklogRow

One job's aggregate row of `TomSqlJobStore.backlog`: how many of its runs are
due and unclaimed, and the earliest `run_at` among them. Reflected and
`@TomDbTable`-annotated with placeholder values, like `TomJobRunWindowRow`,
because the mapper binds by column name.

#### Constructors

```dart
TomJobBacklogRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `jobName` | `String` | The job (`job_name`). |
| `due` | `int` | How many of its runs are due and unclaimed (`due`). |
| `oldestRunAt` | `String?` | The earliest due `run_at`, as stored UTC text (`oldest_run_at`). |

### TomSqlLeaseLock

A `TomLeaseLock` whose leases are rows in a `TomDataSource`. First acquisition is
an insert that keeps a stored row on a conflict (`INSERT IGNORE` on MariaDB,
`ON CONFLICT DO NOTHING` on PostgreSQL), extension by the live holder keeps the token, and takeover of
a released or lapsed lease is a compare-and-set on `(token, version)` that writes
`token + 1`. Meant to live in the same data source as `TomSqlJobStore`.

- **Extends:** `TomLeaseLock`

#### Constructors

```dart
TomSqlLeaseLock(
  TomDataSource datasource, {
  String table = defaultLeaseTable,
  bool createSchema = true,
  DateTime Function()? clock,
})
```

#### Factory Constructors

```dart
factory TomSqlLeaseLock.named(
  String datasourceName, {
  String table = defaultLeaseTable,
  bool createSchema = true,
  DateTime Function()? clock,
})
```

Resolves the registered `TomDataSourceInfo` named `datasourceName` and throws a
`TomServerException` (`scheduling.lock.unknown_datasource`) when none is
registered.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `TomDataSource` | Where the lease table lives (final). |
| `table` | `String` | Name of the lease table (final). |
| `createSchema` | `bool` | Whether the table is created lazily on first use (final). |
| `clock` | `DateTime Function()` | The clock every expiry is computed against; injectable so tests can expire leases without waiting. Defaults to `DateTime.now` (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the lease table if it does not exist. Idempotent, called by every operation, and exposed for start-up provisioning. |
| `acquire` | `Future<TomLease?> acquire(String resource, String owner, Duration ttl)` | *(override)* Grants the lease and returns it, or `null` when another node holds it. A free resource is created with token 1; the live holder re-acquiring gets an extension keeping its token; a released or lapsed lease is taken over with the next token up. |
| `renew` | `Future<TomLease?> renew(TomLease lease, Duration ttl)` | *(override)* Extends the lease if this owner still holds it under the same token and it has not lapsed; returns the renewed lease or `null`. |
| `release` | `Future<void> release(TomLease lease)` | *(override)* Marks the row `released = 1`, guarded on the token so a displaced holder's late release does nothing. The row is never deleted — it carries the fencing counter. |
| `inspect` | `Future<TomLeaseInfo> inspect(String resource)` | *(override)* Reports the current or most recent lease, whether it is held now, and whether it was released deliberately; `TomLeaseInfo.free` when no row exists. |
| `forget` | `Future<void> forget(TomOneShotResource resource)` | *(override)* Deletes the resource's row. Destroys the fencing counter, which is why it takes the kernel's `TomOneShotResource` — a name declared single-use where it was built — rather than any `String`. |
| `deleteAll` | `Future<void> deleteAll()` | Empties the lease table. Not part of `TomLeaseLock`, and destructive in the same way `forget` is: every fencing counter goes back to zero. For provisioning and tests only. |
| `toString` | `String toString()` | *(override)* Renders `"TomSqlLeaseLock(<table>)"`. |

### TomLeaseRow

One row of the lease table, as the result mapper materialises it. The instant
columns are typed `String` so the UTC round trip stays exact, and `released` is
an `int` because the column is `TINYINT(1)`.

#### Constructors

```dart
TomLeaseRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `resource` | `String` | The resource the lease names, and the table's primary key. |
| `owner` | `String` | The node holding — or last to have held — the resource. |
| `token` | `int` | The fencing token of the current or most recent lease. |
| `acquiredAt` | `String` | When the lease was granted, as stored UTC text. |
| `expiresAt` | `String` | When the lease lapses, as stored UTC text. |
| `released` | `int` | `1` when the holder released the lease deliberately. |
| `version` | `int` | The write counter, incremented on every update of this row; makes a matching update always change a row and doubles as the takeover compare-and-set guard. |

### TomSchedulerNode

One node of the cluster, as the roll call knows it: its published check-in
instant and the cadence it claims to keep.

#### Constructors

```dart
const TomSchedulerNode({
  required String nodeId,
  required DateTime checkinAt,
  required Duration checkinInterval,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `nodeId` | `String` | The node's identity, deliberately the same string it claims runs under, so an attribution can be joined back to the runs it explains (final). |
| `checkinAt` | `DateTime` | When the node last announced itself (final). |
| `checkinInterval` | `Duration` | How often the node says it intends to check in; carried in the row rather than assumed, so nodes with different poll intervals judge each other by the interval each actually keeps (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Renders the node id, check-in instant and interval. |

### TomSqlSchedulerNodes

The roll call, backed by a table in a `TomDataSource`. One instance per node: it
writes this node's row and reads everyone else's. It holds no lock and arbitrates
nothing — a heartbeat that could block a peer would be a liveness dependency, and
this is only ever an accelerator over the lease timeout.

#### Constructors

```dart
TomSqlSchedulerNodes(
  TomDataSource datasource, {
  required String nodeId,
  String table = defaultSchedulerNodeTable,
  Duration checkinInterval = const Duration(seconds: 30),
  bool createSchema = true,
  Duration slack = defaultNodeFailureSlack,
})
```

#### Factory Constructors

```dart
factory TomSqlSchedulerNodes.named(
  String datasourceName, {
  required String nodeId,
  String table = defaultSchedulerNodeTable,
  Duration checkinInterval = const Duration(seconds: 30),
  bool createSchema = true,
  Duration slack = defaultNodeFailureSlack,
})
```

Resolves the registered `TomDataSourceInfo` named `datasourceName` and throws a
`TomServerException` (`scheduling.nodes.unknown_datasource`) when none is
registered.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `TomDataSource` | Where the roll-call table lives (final). |
| `nodeId` | `String` | This node's identity; must be the same string the scheduler claims runs under (`TomScheduler.ownerId`), or a failed node's work cannot be attributed to it (final). |
| `table` | `String` | Name of the roll-call table (final). |
| `checkinInterval` | `Duration` | The cadence this node publishes — what it promises, not what it enforces. Set it to the scheduler's tick interval; a shorter value makes a healthy node look late on every pass (final). |
| `createSchema` | `bool` | Whether the table is created lazily on first use (final). |
| `slack` | `Duration` | The grace period applied on top of a peer's expected check-in (final). |
| `lastCheckin` | `DateTime?` | *(getter)* When this node last checked in, in UTC, or `null` before its first pass. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the roll-call table if it does not exist. Idempotent and called by every operation. |
| `checkIn` | `Future<void> checkIn(DateTime now)` | Announces this node as alive at `now`, rewriting its single row with a replacing write (`replaceRow`) and recording the instant as `lastCheckin`. |
| `nodes` | `Future<List<TomSchedulerNode>> nodes()` | Every node in the roll call, including this one, ordered by node id. |
| `failedNodes` | `Future<List<TomSchedulerNode>> failedNodes(DateTime now)` | The peers that have missed their check-in long enough to count as failed at `now`, judged by `isSchedulerNodeFailed` with this node's own lateness granted to them. Never includes this node. |
| `forget` | `Future<void> forget(String nodeId)` | Removes that node's row, so the cluster stops re-reporting a departure it has already dealt with; also the clean way for a node to leave on shutdown. |
| `deleteAll` | `Future<void> deleteAll()` | Empties the roll-call table. For provisioning and tests. |
| `toString` | `String toString()` | *(override)* Renders `"TomSqlSchedulerNodes(<table>, node: <nodeId>)"`. |

### TomSchedulerNodeRow

One row of the roll-call table, as the result mapper materialises it. `checkinAt`
is typed `String` for the same reason the queue's instants are.

#### Constructors

```dart
TomSchedulerNodeRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `nodeId` | `String` | The node's identity, and the table's primary key. |
| `checkinAt` | `String` | When the node last checked in, as stored UTC text. |
| `checkinInterval` | `int` | The node's published cadence, in milliseconds. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `defaultNodeFailureSlack` | `Duration` | Quartz's 7.5 s grace period added on top of a peer's expected check-in, absorbing the jitter of a poll that waited on a slow query or a busy pool. |
| `defaultJobRunTable` | `String` | The default name of the job queue table, `tom_job_run`. |
| `defaultLeaseTable` | `String` | The default name of the lease table, `tom_lease`. |
| `defaultSchedulerNodeTable` | `String` | The default name of the scheduler roll-call table, `tom_scheduler_node`. |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `schedulerNodeFailedAfter` | `DateTime schedulerNodeFailedAfter({required TomSchedulerNode peer, required DateTime now, required DateTime lastSelfCheckin, Duration slack = defaultNodeFailureSlack})` | The instant after which `peer` counts as failed: its last check-in plus the greater of its own published interval and the asking node's lateness, plus `slack`. Pure, so the judgement is assertable without a database. |
| `isSchedulerNodeFailed` | `bool isSchedulerNodeFailed({required TomSchedulerNode peer, required DateTime now, required DateTime lastSelfCheckin, Duration slack = defaultNodeFailureSlack})` | Whether `now` is past `schedulerNodeFailedAfter` for that peer. |
| `jobRunTable` | `TomFrameworkTable jobRunTable(String table)` | The one declaration of the job queue table: `seq` as an auto-increment ordering surrogate, `id` as the key, the `tenant` column (`VARCHAR(32)`, default `''`), the unique key on `(job_name, tenant, scheduled_for)`, and the `(state, run_at)` and `(state, claimed_at)` indexes the claim and recovery scans ride. |
| `leaseTable` | `TomFrameworkTable leaseTable(String table)` | The one declaration of the lease table, keyed by `resource`, carrying the fencing `token` and the `version` write counter. |
| `schedulerNodeTable` | `TomFrameworkTable schedulerNodeTable(String table)` | The one declaration of the roll-call table, keyed by `node_id`, with no index beyond its key because a cluster is read in full. |
| `jobRunTableDdl` | `String jobRunTableDdl(String table)` | The `CREATE TABLE` statement for the job queue table, derived from `jobRunTable`. |
| `leaseTableDdl` | `String leaseTableDdl(String table)` | The `CREATE TABLE` statement for the lease table, derived from `leaseTable`. |
| `schedulerNodeTableDdl` | `String schedulerNodeTableDdl(String table)` | The `CREATE TABLE` statement for the roll-call table, derived from `schedulerNodeTable`. |

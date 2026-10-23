# Tom Core Server API Reference: Transactions Module

A lightweight transaction coordinator: enlistable participants, a unit of work
that commits or rolls them back as a group, and an ambient manager that holds
the current transaction of the running flow — zone-scoped, so concurrent flows
in one isolate do not share it — allowing the endpoint pipeline and data sources
to join it without threading a handle through every call. The conclusion is a
**two-phase commit** — every participant is prepared before any is committed —
see [TomTransactionParticipant](#tomtransactionparticipant) for what that asks
of an implementer and for the one outcome it cannot rule out.

Work that spans services, whose data no transaction reaches, is a **saga**: an
orchestrator runs each step as a local transaction and, when a step fails for
good, runs the compensations of the steps already done, last first — see
[TomSagaOrchestrator](#tomsagaorchestrator).

A process that dies between the two phases leaves its branches prepared. The
coordinator records its decision before the commit phase in a
[TomTransactionDecisionLog](#tomtransactiondecisionlog), and
[TomTransactionRecovery](#tomtransactionrecovery) commits the branches a
recorded decision names and rolls back the rest.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomTransactionException](#tomtransactionexception)
  - [TomTransactionParticipant](#tomtransactionparticipant)
  - [TomTransactionResult](#tomtransactionresult)
  - [TomTransaction](#tomtransaction)
  - [TomTransactionManager](#tomtransactionmanager)
  - [TomPreparedBranchHolder](#tompreparedbranchholder)
  - [TomTransactionDecisionLog](#tomtransactiondecisionlog)
  - [TomMemoryDecisionLog](#tommemorydecisionlog)
  - [TomSqlDecisionLog](#tomsqldecisionlog)
  - [TomDecisionRow](#tomdecisionrow)
  - [TomTwoPhaseRecoverable](#tomtwophaserecoverable)
  - [TomRecoveryReport](#tomrecoveryreport)
  - [TomTransactionRecovery](#tomtransactionrecovery)
  - [TomTransactionRecoveryException](#tomtransactionrecoveryexception)
  - [TomSagaException](#tomsagaexception)
  - [TomSagaWork](#tomsagawork)
  - [TomSagaStep](#tomsagastep)
  - [TomSaga](#tomsaga)
  - [TomSagaContext](#tomsagacontext)
  - [TomSagaState](#tomsagastate)
  - [TomSagaStore](#tomsagastore)
  - [TomMemorySagaStore](#tommemorysagastore)
  - [TomSqlSagaStore](#tomsqlsagastore)
  - [TomSagaRow](#tomsagarow)
  - [TomSagaOrchestrator](#tomsagaorchestrator)
- [Enums](#enums)
  - [TomTransactionOutcome](#tomtransactionoutcome)
  - [TomSagaStatus](#tomsagastatus)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/transactions/transaction_manager.dart`,
`lib/src/tomserver/transactions/transaction_recovery.dart`,
`lib/src/tomserver/transactions/saga.dart`,
`lib/src/tomserver/transactions/saga_sql.dart`.

`TomTransactionParticipant` is the contract for a resource (e.g. a data source)
that can enlist in a transaction, keyed by `getParticipantId`. `TomTransaction`
is a single unit of work: participants enlist via `registerParticipant`, and the
work concludes with `commitTransaction` (prepare-all then commit-all, rolling
back if any participant vetoes during prepare) or `rollbackTransaction`. Instances are created only by
`TomTransactionManager.startTransaction` (the constructor is private).

`TomTransactionManager` provides ambient access to the current transaction. The
transaction lives in a `Zone` value, so "current" means current to the running
flow rather than to the isolate: two requests interleaving in one isolate hold
two independent transactions. A scope is established by `runInTransactionScope`
— the server's authentication middleware opens one per request, and the endpoint
pipeline opens one for a `@TomTransactional` endpoint whose request has none.
Code outside every scope shares one process-wide fallback scope. The pipeline
opens a transaction for a `@TomTransactional` endpoint and commits/rolls it back
when the call returns; the transaction clears itself from its scope on
completion.

`transaction_recovery.dart` holds the recovery of prepared branches. Between
the phases the coordinator records the prepared branches of the participants
that are `TomPreparedBranchHolder`s under `TomTransaction.id`, in
`TomTransactionManager.decisionLog` — a `TomSqlDecisionLog` over the
`tom_transaction_decision` table (`decisionTable`) of a one-phase data source —
and forgets them once every branch committed. A record that cannot be written
rolls the transaction back. `TomTransactionRecovery.recover` lists the prepared
branches of every `TomTwoPhaseRecoverable` data source, passes over those it
does not own and those younger than `minimumAge`, commits those a decision
names, rolls back the rest, forgets the resolved decisions, and returns a
`TomRecoveryReport`. `TomTransactionRecovery.configure` applies the
`transactions` configuration, which `TomServer.recoverTransactions` reads at
start.

`saga.dart` holds the sagas. A `TomSaga` declares its `TomSagaStep`s, each an
action and an optional compensation; `TomSagaOrchestrator` registers sagas,
begins them and runs every step and every compensation as a job run of an
inline `TomScheduler` of its own, so retries, recovery and alerts are the
scheduler's. A transition runs in `TomTransactionManager.runInTransaction`
together with the update that moves the saga on, written only over the version
the run was queued for, so a step that throws leaves no trace and a step that
committed never runs again. Saga states (`TomSagaState`) are kept in a
`TomSagaStore`: `TomMemorySagaStore`, or `TomSqlSagaStore` over the `tom_saga`
table that `saga_sql.dart` declares once (`sagaTable`). `resume` re-queues every
unfinished saga whose run is gone — at start, every `sweepInterval`, and in
every tenant of an installed `TomTenancy`.

## Class Hierarchy

```
TomServerException  (little_things)
    └── TomTransactionException

TomTransactionParticipant  (abstract)
TomTransaction
TomTransactionManager  (abstract, static-only)

TomServerException  (little_things)
    └── TomTransactionRecoveryException

TomPreparedBranchHolder  (abstract interface)
TomTransactionDecisionLog  (abstract interface)
    ├── TomMemoryDecisionLog  (implements)
    └── TomSqlDecisionLog  (implements)
TomTwoPhaseRecoverable  (abstract interface)
TomRecoveryReport
TomTransactionRecovery  (abstract final, static-only)
TomDecisionRow

TomServerException  (little_things)
    └── TomSagaException

TomClosable  (tom_core_kernel)
    └── TomSagaOrchestrator  (implements)

TomSagaStore  (abstract)
    ├── TomMemorySagaStore  (implements)
    └── TomSqlSagaStore  (implements)

TomSaga
TomSagaStep
TomSagaContext
TomSagaState
TomSagaRow
```

## Classes

### TomTransactionException

Raised when a transaction operation is attempted in an invalid state (e.g.
registering a participant with a transaction that is no longer running). Flows
through the standard server error mapping.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomTransactionException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool autoLog = false,
})
```

### TomTransactionParticipant

A resource that can enlist in a `TomTransaction`. Implemented by
`TomDataSource`, so any data source used during a transaction joins it. The
coordinator drives the lifecycle: `startTransaction` on enlistment, then
`prepare`/`commit`/`endTransaction` on success or `rollback`/`endTransaction` on
failure. Every hook is handed the transaction it concerns, so a participant
serving several transactions at once — a pooled data source holds a connection
per transaction — knows which of them each call concludes.

**This is two-phase commit.** `prepare` runs on every participant before
`commit` runs on any of them, so a veto — a `false` from `prepare`, or a throw —
arrives while nothing is durable and the coordinator can abort by rolling
everyone back. Everything that can fail therefore belongs in `prepare`: it is
the last point at which failing is free, and the only place a refusal is a veto.
`commit` is the promise being kept, not a decision.

The outcome two phases cannot rule out is a participant that promises and then
fails in `commit`. That leaves the transaction **partially committed**: the
coordinator logs it at error level naming the participants that failed, commits
the rest, and rolls nobody back, because rolling back a peer whose commit
succeeded would discard work the transaction decided to keep. A participant with
nothing to prepare returns `true`; `MariaDbXADatasource` is the two-phase one,
mapping `prepare` onto `XA END` + `XA PREPARE` and `commit` onto `XA COMMIT`.

- **Extends:** none (abstract)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getParticipantId` | `String getParticipantId()` | A stable id naming the **resource** this participant speaks for, not the object — `MariaDbDatasource` answers `"MariaDb-<database>@<host>:@<port>"`. Registering the same participant twice enlists once; a *different* object claiming an enlisted id is refused with `…duplicate_id`. A participant needing its own enlistment returns an id nothing else answers. |
| `startTransaction` | `Future<bool> startTransaction(TomTransaction transaction)` | Begins the participant's part of `transaction`; called once on enlist. The transaction is handed over rather than looked up, which is how `isReadOnly` reaches the resource that can act on it — `MariaDbDatasource` opens `START TRANSACTION READ ONLY` for one. |
| `prepare` | `Future<bool> prepare(TomTransaction transaction)` | Phase one: promises that `commit` will succeed. Returning `false` — or throwing — vetoes the transaction, while nothing is durable. A participant with nothing to prepare returns `true`. |
| `commit` | `Future<bool> commit(TomTransaction transaction)` | Phase two: makes the work durable. Reached only after every participant prepared, so a `false` is not a veto — it reports a broken promise and leaves the transaction partially committed. |
| `rollback` | `Future<bool> rollback(TomTransaction transaction)` | Undoes the participant's work when the transaction is rolled back. Reachable after a successful `prepare`, never after this participant's own `commit`. `false` is the one outcome needing a human — the work was neither committed nor undone — and puts this participant in `TomTransactionResult.failed` with the transaction reported as `rolledBackWithFailures`. |
| `endTransaction` | `Future<bool> endTransaction(TomTransaction transaction)` | Releases per-transaction resources after commit or rollback — for a pooled data source, handing the transaction's connection back to the pool. Decides nothing. |

### TomTransactionResult

What a transaction's conclusion did, and to whom. Returned by
`commitTransaction` and `rollbackTransaction` in place of a boolean, which could
not say which of four things had happened — committed, partially committed,
rolled back, rolled back badly — and merged them further with a fifth,
unrelated fact: whether every participant released its per-transaction
resources. A caller reading `false` could not tell "your work is gone" from
"your work is durable and a connection leaked", and those call for opposite
responses, since the second must not be retried.

- **Extends:** none

#### Constructors

| Constructor | Signature | Description |
| ----------- | --------- | ----------- |
| `TomTransactionResult` | `const TomTransactionResult(TomTransactionOutcome outcome, {List<String> failed = const [], List<String> notReleased = const []})` | Creates a result. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `outcome` | `TomTransactionOutcome` | What became of the work (final). |
| `failed` | `List<String>` | The participants whose commit or rollback did not do what it said — names rather than a count, because repairing a partial commit or a failed rollback means going to those resources (final). |
| `notReleased` | `List<String>` | The participants whose `endTransaction` did not release. Separate because it is a separate fact: the work may be perfectly durable and a pooled connection still lost (final). |
| `isCommitted` | `bool` | *(getter)* Whether the work committed — `outcome == committed`. The question most callers are asking. |
| `isClean` | `bool` | *(getter)* Whether the conclusion left nothing outstanding at all. Stronger than `isCommitted`: a transaction whose work committed and whose connection leaked is committed and not clean. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | Names the outcome and everyone who failed or did not release — the result reaches a log line or an exception message more often than it is destructured. |

### TomTransaction

A single unit of work coordinating one or more `TomTransactionParticipant`s.
Instances are created only by `TomTransactionManager.startTransaction`. A
transaction runs once: after it commits or rolls back, `isRunning` is `false`
and it can no longer accept participants.

#### Constructors

None — the constructor is private; obtain instances via
`TomTransactionManager.startTransaction`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isReadOnly` | `bool` | Whether this transaction was opened as read-only. Handed to every participant through `startTransaction`, which is the only path from the `@TomTransactional(isReadOnly: true)` that declares it to the resource that can act on it. The coordinator enforces nothing — it has no idea what a write is — so what it means is each participant's to decide: `MariaDbDatasource` opens `START TRANSACTION READ ONLY` and the server refuses the writes; `MariaDbXADatasource` cannot, XA having no read-only branch, and warns rather than appearing to. |
| `isRunning` | `bool` | *(getter)* Whether the transaction is still open (not yet committed or rolled back). |
| `id` | `String` | The transaction's id, `tx_<process tag>_<counter>`: unique in the process, and through a random process tag across the processes sharing a decision log. The key its commit decision is recorded under (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `registerParticipant` | `Future<void> registerParticipant(TomTransactionParticipant ttp)` | Enlists `ttp`, calling its `startTransaction(transaction)` once; registering the same participant again is a no-op. A **different** object claiming an enlisted id is refused with `…duplicate_id` rather than dropped — a dropped resource's work is neither committed with the transaction nor rolled back with it. Enlistment is all or nothing: the participant is recorded only after a `true`, and a `false` or a throw leaves it unenlisted and raises `TomTransactionException` naming it (`…start_failed` / `…start_threw`, the latter carrying the original as `rootException`). Also throws when the transaction is no longer running. |
| `commitTransaction` | `Future<TomTransactionResult> commitTransaction()` | Prepares every participant, then — only if all promised — records the decision in `TomTransactionManager.decisionLog` when one is installed and a participant holds a prepared branch (rolling back instead when the record cannot be written), commits every participant, forgets the decision once all committed, then ends them all. A veto or a throw during prepare rolls the transaction back instead; a `commit` that fails after a successful prepare does not, and is logged as a partial commit. Clears the transaction from its scope (in a `finally`, so a transaction that is not running is never the current one) and returns a `TomTransactionResult` — a vetoed transaction returns the rollback's own result rather than claiming a commit that did not happen. Participants are driven **one at a time**: the order is what makes a veto's meaning knowable, and a transaction spanning *n* resources pays *n* round trips per phase. |
| `rollbackTransaction` | `Future<TomTransactionResult> rollbackTransaction()` | Rolls back every participant then ends them; clears the transaction from its scope (in a `finally`). Returns `rolledBack` when every participant undid its work and `rolledBackWithFailures` when one did not, naming it. |

"Ends them" is unconditional on both paths: a participant whose
`endTransaction` returns `false` does not stop the ones behind it from being
ended, and the returned boolean is the conjunction of all the end calls rather
than the last one. An implementer can therefore rely on their release running
even after a peer's has failed — which matters because nothing runs afterwards
to release what a skipped participant would still hold.

A transaction remembers the scope it is current in, because it may conclude in a
different zone from the one that opened it (after an `await`, or from a callback
scheduled elsewhere). Clearing is identity-guarded, so a concluded transaction
cannot wipe a successor.

### TomTransactionManager

Ambient access to the current `TomTransaction`, so participants and the endpoint
pipeline can join or conclude it without threading a handle through every call,
plus `runInTransaction` to drive one from end to end.
"Current" means current to the running flow: the transaction lives in a `Zone`
value, exactly as the request principal does, so two flows interleaving in one
isolate cannot see each other's work. Abstract with a static-only surface.

- **Extends:** none (abstract, static members only)

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `runInTransaction` | `static Future<R> runInTransaction<R>(FutureOr<R> Function(TomTransaction transaction) body, {bool isReadOnly = false})` | Runs `body` in a transaction, committing it on a normal return and **rolling it back on a throw**, rethrowing the body's own exception. Establishes a scope if the flow has none; joins a transaction that is already running and concludes nothing it did not open. A commit that does not succeed raises `TomTransactionException` (`transaction_manager.run_in_transaction.commit_failed`) rather than returning quietly. |
| `runInTransactionScope` | `static R runInTransactionScope<R>(R Function() body)` | Runs `body` with its own current transaction, isolated from every other flow in this isolate. Establishes the scope and opens no transaction — what the authentication middleware needs, since every request gets one whether or not its endpoint is transactional. Returns whatever `body` returns, so an asynchronous body is awaited by the caller. |
| `startTransaction` | `static (TomTransaction, bool) startTransaction([bool isReadOnly = false])` | Returns the current transaction, creating one if none is active; the boolean is `true` when a new one was created. `isReadOnly` is honoured only for a new transaction. |
| `getCurrentTransaction` | `static TomTransaction? getCurrentTransaction()` | The current transaction, or `null` if none is active. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `hasTransactionScope` | `static bool` | *(getter)* Whether the current zone carries a transaction scope of its own; `false` means `startTransaction` would use the process-wide fallback scope. |
| `transactional` | `static bool` | *(getter)* Whether a transaction is currently active and still running. |
| `decisionLog` | `static TomTransactionDecisionLog?` | Where two-phase commit decisions are recorded; `null` (the default) records none, and a process that dies between the phases then leaves its prepared branches to a recovery that can only roll them back. Set by `TomTransactionRecovery.configure` from the `transactions` configuration. |

### TomPreparedBranchHolder

A participant holding a two-phase branch: the id of the branch it prepared for
a transaction, which the coordinator records before the commit phase.
`MariaDbXADatasource` and `PostgresXADatasource` implement it through
`TomSqlTwoPhaseRecovery`.

- **Extends:** none (abstract interface)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `preparedBranchOf` | `String? preparedBranchOf(TomTransaction transaction)` | The id of the branch prepared for `transaction`, or `null` for none. |

### TomTransactionDecisionLog

The coordinator's durable record of commit decisions: written before a
two-phase transaction's commit phase, outside the transaction's scope;
forgotten once every branch committed; read by a recovery to tell the prepared
branches it must commit from those it must roll back. It belongs in a one-phase
data source, and every process whose transactions reach a recovered database
records into the same one.

- **Extends:** none (abstract interface)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `recordCommit` | `Future<void> recordCommit(String transactionId, List<String> branches)` | Records that `transactionId` decided to commit its `branches`. A throw means the decision is not taken: the coordinator rolls back. |
| `forget` | `Future<void> forget(String transactionId)` | Forgets the decision of `transactionId`. |
| `decisions` | `Future<Map<String, Set<String>>> decisions()` | Every recorded decision: transaction id to its branches. |

### TomMemoryDecisionLog

Records decisions in memory — for a test, or the example. It does not survive
the process it protects, so it protects nothing in a deployment.

- **Implements:** `TomTransactionDecisionLog`

#### Constructors

```dart
TomMemoryDecisionLog()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `recordCommit` | `Future<void> recordCommit(String transactionId, List<String> branches)` | *(override)* Keeps the branches under `transactionId`, replacing a decision kept for it. |
| `forget` | `Future<void> forget(String transactionId)` | *(override)* Drops the decision. |
| `decisions` | `Future<Map<String, Set<String>>> decisions()` | *(override)* A copy of every kept decision. |

### TomSqlDecisionLog

Records decisions in a table of a SQL data source, one row per decided branch.
The data source is resolved by name on every call; it has to be a one-phase
data source, because the record must be durable on its own before the commit
phase, and a two-phase one would hold it in a branch of its own.

- **Implements:** `TomTransactionDecisionLog`

#### Constructors

```dart
TomSqlDecisionLog(
  String datasourceName, {
  String table = defaultDecisionTable,
  bool createSchema = true,
})
```

A name that is not registered raises `transactions.recovery.no_datasource` at
the first call. With `createSchema` the table is created on first use; a
deployment whose database user may not run DDL applies the shipped migration
and passes `false`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasourceName` | `String` | The registered name of the data source (final). |
| `table` | `String` | The table's name (final). |
| `createSchema` | `bool` | Whether the table is created on first use (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `recordCommit` | `Future<void> recordCommit(String transactionId, List<String> branches)` | *(override)* Inserts one row per branch, stamped with the current UTC time, in a single multi-row `INSERT`: the decision is recorded whole or not at all. |
| `forget` | `Future<void> forget(String transactionId)` | *(override)* Deletes the transaction's rows. |
| `decisions` | `Future<Map<String, Set<String>>> decisions()` | *(override)* Reads the whole table, grouped by transaction. |

### TomDecisionRow

One row of the decision table, as `TomSqlDecisionLog` reads it. Reflected
(`@tomReflector`) and annotated `@TomDbTable` with placeholder values, so the
driver can map it; the real table name is a constructor argument of the log.

#### Constructors

```dart
TomDecisionRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `transactionId` | `String` | `transaction_id` — the transaction that decided. |
| `branchId` | `String` | `branch_id` — a branch it decided to commit. |
| `decidedAt` | `DateTime` | `decided_at` — when the decision was recorded. |

### TomTwoPhaseRecoverable

A data source whose two-phase branches a recovery can list and resolve.
`MariaDbXADatasource` and `PostgresXADatasource` implement it through
`TomSqlTwoPhaseRecovery`.

- **Extends:** none (abstract interface)

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `recoveryLabel` | `String` | *(getter)* The name it describes itself by in a report and the recovery's log lines. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `listPreparedBranches` | `Future<List<String>> listPreparedBranches()` | The ids of the branches prepared on its database and not yet resolved — every program's, for MariaDB's server-wide `XA RECOVER`. |
| `ownsBranch` | `bool ownsBranch(String branchId)` | Whether `branchId` is a branch this data source's kind opened on its database. A recovery touches no other. |
| `branchOpenedAt` | `DateTime? branchOpenedAt(String branchId)` | When `branchId` was opened, read from the id, or `null` when it does not say. A recovery leaves a branch younger than its minimum age alone. |
| `commitPreparedBranch` | `Future<void> commitPreparedBranch(String branchId)` | Commits the prepared branch `branchId`. |
| `rollbackPreparedBranch` | `Future<void> rollbackPreparedBranch(String branchId)` | Rolls the prepared branch `branchId` back. |

### TomRecoveryReport

What one `TomTransactionRecovery.recover` did. Branches are named by id,
decisions by transaction id.

#### Constructors

```dart
TomRecoveryReport()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `committed` | `List<String>` | Branches committed because their transaction had decided to commit (final). |
| `rolledBack` | `List<String>` | Branches rolled back because no decision was recorded for them (final). |
| `tooYoung` | `List<String>` | Branches left alone because they were younger than the minimum age (final). |
| `failed` | `Map<String, String>` | Branches whose resolution failed, with the error (final). |
| `forgotten` | `List<String>` | Decisions forgotten because none of their branches is left (final). |
| `isClean` | `bool` | *(getter)* Whether every branch found was resolved or deliberately left alone — `failed.isEmpty`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | The five counts, for a log line. |

### TomTransactionRecovery

Resolves the prepared branches a dead process left behind, and applies the
`transactions` configuration. Abstract final with a static-only surface.

A recovery reads the decisions of the log, then for each prepared branch of
each source: passes over a branch the source does not own; leaves a branch
younger than `minimumAge` alone (`tooYoung`), because it may belong to a live
process between its two phases; commits a branch a decision names; rolls back
every other. A failure on one branch is reported in `failed` and the rest are
still resolved — another node recovering at the same time is one cause. A
decision is forgotten once none of its branches is still prepared, provided
every one of them belongs to a scanned source.

- **Extends:** none (abstract final, static members only)

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `configurationKey` | `String` | `const`, `'transactions'`: the key of the server configuration `configure` reads. |
| `minimumAge` | `Duration` | How old a prepared branch has to be, by the time its id carries, before a recovery resolves it; one minute by default. Longer than any two-phase transaction stays open, plus the clock skew between nodes. |
| `recoverOnStart` | `bool` | Whether the server recovers at start; `false` by default, set by `configure`. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `configure` | `static void configure(Object? config)` | Applies the `transactions` section: `decisionLog` installs a `TomSqlDecisionLog` (with `decisionTable` and `createSchema`) as `TomTransactionManager.decisionLog`; `recoverOnStart` is set when the value is `true`; `recoveryMinimumAgeSeconds` sets `minimumAge`. `null` leaves everything as it is. A value that is not a map, or an age that is not a whole number of seconds or is negative, raises `transactions.recovery.config.invalid`. |
| `reset` | `static void reset()` | Restores the defaults — no decision log, a one-minute minimum age, no start recovery. For tests. |
| `recover` | `static Future<TomRecoveryReport> recover({Iterable<TomTwoPhaseRecoverable>? sources, TomTransactionDecisionLog? log, DateTime? now})` | Resolves the prepared branches of `sources` — every operational registered data source that is a `TomTwoPhaseRecoverable` when `null` — against the decisions of `log` — `TomTransactionManager.decisionLog` when `null`, and then none, so every old enough branch is rolled back. `now` is the time ages are measured against, the current UTC time by default. |

### TomTransactionRecoveryException

Raised when transaction recovery is misconfigured, or its decision log names a
data source that is not registered.

| Key | Meaning |
| --- | ------- |
| `transactions.recovery.no_datasource` | The data source a `TomSqlDecisionLog` names is not registered. |
| `transactions.recovery.config.invalid` | The `transactions` configuration is not a map, or its `recoveryMinimumAgeSeconds` is not a whole number of seconds or is negative. |

- **Extends:** `TomServerException`

#### Constructors

```dart
TomTransactionRecoveryException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
})
```

### TomSagaException

A saga that cannot be declared, begun or stored. Raised with
`clientThrow: false`: it reaches the caller of `TomSaga`, `register`, `begin`
or a store, not a client.

| Key | Meaning |
| --- | ------- |
| `transactions.saga.invalid_definition` | A saga's name is empty or longer than 120 characters, it has no steps, or two steps share a name. |
| `transactions.saga.already_registered` | A saga of that name is registered with the orchestrator already. |
| `transactions.saga.unknown` | `TomSagaOrchestrator.begin` names a saga that is not registered. |
| `transactions.saga.invalid_id` | The saga id given to `begin` is empty or longer than 128 characters. |
| `transactions.saga.id_taken` | A saga with that id exists already. |
| `transactions.saga.data_not_json` | The saga's data is not JSON-encodable. |
| `transactions.saga.closed` | The orchestrator has been closed. |
| `transactions.saga.no_datasource` | The data source a `TomSqlSagaStore` names is not registered. |
| `transactions.saga.superseded` | A transition found its saga moved on since its run was queued — another node, or a redelivered run, got there first. Raised inside the transition's transaction to roll it back and caught by the orchestrator; it never reaches a caller. |

- **Extends:** `TomServerException`

#### Constructors

```dart
TomSagaException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
})
```

### TomSagaWork

```dart
typedef TomSagaWork = FutureOr<void> Function(TomSagaContext context);
```

The work of a step or a compensation. It runs in a local transaction with the
saga's transition; a throw rolls both back.

### TomSagaStep

One step of a saga: an action and, optionally, the compensation that undoes it.

#### Constructors

```dart
const TomSagaStep(
  String name, {
  required TomSagaWork action,
  TomSagaWork? compensation,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The step's name, unique within its saga (final). |
| `action` | `TomSagaWork` | The step's work, run in a local transaction with the saga's transition (final). |
| `compensation` | `TomSagaWork?` | What undoes `action` once a later step has failed for good, or `null` for a step with nothing to undo — a read, or the last step. A step without one is passed over while the saga compensates (final). |

### TomSaga

The declaration of a saga: its steps, in order, and how they are retried. The
constructor throws `transactions.saga.invalid_definition` for a name that is
empty or longer than 120 characters, no steps, or two steps of one name.

#### Constructors

```dart
TomSaga({
  required String name,
  required List<TomSagaStep> steps,
  TomRetryPolicy retryPolicy = const TomRetryPolicy(),
  TomRetryPolicy compensationRetryPolicy = const TomRetryPolicy(
    maxAttempts: 10,
    initialBackoff: Duration(seconds: 30),
    maxBackoff: Duration(minutes: 30),
  ),
  Duration timeout = const Duration(minutes: 2),
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The saga's name, which its state records and its jobs are named after (final). |
| `steps` | `List<TomSagaStep>` | The steps, run in order; unmodifiable (final). |
| `retryPolicy` | `TomRetryPolicy` | How a failing step is retried before the saga compensates (final). |
| `compensationRetryPolicy` | `TomRetryPolicy` | How a failing compensation is retried before the saga fails — ten attempts by default, because a compensation that gives up leaves the system half done (final). |
| `timeout` | `Duration` | How long one attempt of a step or a compensation may take (final). |

### TomSagaContext

What a step's action or compensation is given. Created by the orchestrator; the
constructor is private.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sagaId` | `String` | The saga's id (final). |
| `sagaName` | `String` | The saga's name (final). |
| `stepName` | `String` | The step being run or compensated (final). |
| `attempt` | `int` | Which attempt this is, 1-based (final). |
| `isCompensating` | `bool` | Whether this is a compensation (final). |
| `failure` | `String?` | While compensating: why the saga compensates (final). |
| `data` | `Map<String, Object?>` | A copy of the saga's data. An action may change it, and the change is saved with the step, so a later step and the step's own compensation see what it recorded; it must stay JSON-encodable. Changes by a compensation are saved too; changes by an attempt that fails are not (final). |

### TomSagaState

The persisted progress of one saga.

#### Constructors

```dart
const TomSagaState({
  required String id,
  required String name,
  required String tenant,
  required TomSagaStatus status,
  required int step,
  required int version,
  required Map<String, Object?> data,
  required DateTime runWindow,
  required DateTime createdAt,
  required DateTime updatedAt,
  String? error,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | The saga's id, unique within its tenant (final). |
| `name` | `String` | The saga's name: which `TomSaga` it runs (final). |
| `tenant` | `String` | The tenant the saga runs for, `''` for none (final). |
| `status` | `TomSagaStatus` | Where the saga is (final). |
| `step` | `int` | The cursor: the next step to run while `running`, the next step to compensate while `compensating` (final). |
| `version` | `int` | Grows by one with every transition; a transition is written only over the version it was made from (final). |
| `data` | `Map<String, Object?>` | The saga's data (final). |
| `error` | `String?` | Why the saga compensates, or failed (final). |
| `runWindow` | `DateTime` | The window instant of the job run that carries this version — its identity in the job store, not when it is due (final). |
| `createdAt` | `DateTime` | When the saga began (final). |
| `updatedAt` | `DateTime` | When the saga last moved (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* `TomSagaState(<name> <id>: <status> at step <step>, v<version>)`. |

### TomSagaStore

Where saga states are kept. Every operation works in the tenant in context:
`load` and `unfinished` see only that tenant's sagas.

- **Abstract.** Implemented by `TomMemorySagaStore` and `TomSqlSagaStore`.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `prepare` | `Future<void> prepare()` | *(abstract)* Makes the store ready — creates its table — for the data source this context resolves. Called outside any transaction, before the others. |
| `insert` | `Future<bool> insert(TomSagaState state)` | *(abstract)* Stores a new saga; answers `false` when its id is taken. |
| `load` | `Future<TomSagaState?> load(String id)` | *(abstract)* The saga `id` of the tenant in context, or `null`. |
| `update` | `Future<bool> update(TomSagaState state, {required int expectedVersion})` | *(abstract)* Writes `state` when the stored version is `expectedVersion`; answers whether it did. |
| `unfinished` | `Future<List<TomSagaState>> unfinished()` | *(abstract)* The unfinished sagas of the tenant in context. |
| `purgeFinishedBefore` | `Future<int> purgeFinishedBefore(DateTime before)` | *(abstract)* Removes the sagas of the tenant in context that finished before `before`; answers how many. Nothing in the framework calls it. |

### TomMemorySagaStore

Saga states in memory: for tests, and for a single process that may lose its
sagas on restart. `update` encodes the data as JSON as the SQL store does, so
data that would not survive a database fails here as well.

- **Implements:** `TomSagaStore`

#### Constructors

```dart
TomMemorySagaStore()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `prepare` | `Future<void> prepare()` | *(override)* Does nothing. |
| `insert` | `Future<bool> insert(TomSagaState state)` | *(override)* Keeps the state under its tenant and id; `false` when one is kept already. |
| `load` | `Future<TomSagaState?> load(String id)` | *(override)* The state kept for the tenant in context and `id`. |
| `update` | `Future<bool> update(TomSagaState state, {required int expectedVersion})` | *(override)* Replaces the kept state when its version is `expectedVersion`. |
| `unfinished` | `Future<List<TomSagaState>> unfinished()` | *(override)* The kept states of the tenant in context that are not finished. |
| `purgeFinishedBefore` | `Future<int> purgeFinishedBefore(DateTime before)` | *(override)* Removes the tenant in context's finished states last moved before `before`. |

### TomSqlSagaStore

Saga states in a SQL data source — the store a saga's steps share their local
transaction with. Every statement derives from the single `sagaTable`
declaration; a transition is `UPDATE … WHERE tenant = :tenant AND saga_id = :id
AND version = :expected`, so of two nodes advancing one saga only one succeeds.

The data source is resolved by name on every call, through
`TomDataSourceInfo.getDataSourceInfo`, which routes under tenancy — so a
tenant's sagas are kept in the tenant's data source.

- **Implements:** `TomSagaStore`

#### Constructors

```dart
TomSqlSagaStore(
  String this.datasourceName, {
  String table = defaultSagaTable,
  bool createSchema = true,
})

TomSqlSagaStore.over(
  TomDataSource datasource, {
  String table = defaultSagaTable,
  bool createSchema = true,
})
```

The unnamed constructor resolves the data source registered as
`datasourceName` per call; an unregistered name raises
`transactions.saga.no_datasource`. `over` binds `datasource` itself, resolved
once. With `createSchema` (the default) the table is created on first use in
each data source; a deployment whose database user may not run DDL applies the
shipped migration and passes `false`.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasourceName` | `String?` | The registered name of the data source, or `null` for a store built `over` one (final). |
| `table` | `String` | The table's name (final). |
| `createSchema` | `bool` | Whether the table is created on first use (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `prepare` | `Future<void> prepare()` | *(override)* Creates the table, once per data source, when `createSchema` is set. |
| `insert` | `Future<bool> insert(TomSagaState state)` | *(override)* Inserts the row, ignoring a conflict on `(tenant, saga_id)`; `false` when it conflicted. |
| `load` | `Future<TomSagaState?> load(String id)` | *(override)* Reads the row of the tenant in context and `id`. |
| `update` | `Future<bool> update(TomSagaState state, {required int expectedVersion})` | *(override)* One conditional `UPDATE` over the stored version; `false` when it affected no row. |
| `unfinished` | `Future<List<TomSagaState>> unfinished()` | *(override)* The tenant in context's rows `running` or `compensating`, oldest move first. |
| `purgeFinishedBefore` | `Future<int> purgeFinishedBefore(DateTime before)` | *(override)* Deletes the tenant in context's `completed`, `compensated` and `failed` rows last moved before `before`; the `(status, updated_at)` index serves it. |
| `deleteAll` | `Future<void> deleteAll()` | Empties the table of the data source this context resolves. Not part of `TomSagaStore`; for tests. |

### TomSagaRow

One row of the saga table, as `TomSqlSagaStore` reads it. Reflected
(`@tomReflector`) and annotated `@TomDbTable` with placeholder values, so the
driver can map it; the real table name is a constructor argument of the store.

#### Constructors

```dart
TomSagaRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `tenant` | `String` | `tenant` — the tenant, `''` for none. |
| `sagaId` | `String` | `saga_id` — the saga's id. |
| `sagaName` | `String` | `saga_name` — the saga's name. |
| `status` | `String` | `status` — the `TomSagaStatus` name. |
| `step` | `int` | `step` — the cursor. |
| `version` | `int` | `version` — the version. |
| `data` | `String` | `data` — the data, as JSON. |
| `error` | `String?` | `error` — why the saga compensates or failed. |
| `runWindow` | `String` | `run_window` — the current run's window instant, as stored UTC text. |
| `createdAt` | `String` | `created_at` — when the saga began, as stored UTC text. |
| `updatedAt` | `String` | `updated_at` — when the saga last moved, as stored UTC text. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toState` | `TomSagaState toState()` | The state this row stores, its instants as UTC. |

### TomSagaOrchestrator

Runs sagas. Owns no retry logic: like the message outbox it runs an inline
`TomScheduler` of its own over a `TomJobStore`, and every transition of a saga —
one step, or one compensation — is a job run. A saga `place_order` runs its
steps as job `saga.place_order` and its compensations as
`saga.place_order.compensation`; the jobs are never clock-driven (a transition
is queued by the one before it), allow overlap, and request recovery.

A step's action runs in `TomTransactionManager.runInTransaction` together with
the update that moves the saga on, written only over the version the run was
queued for: a step that throws leaves no trace and is retried by
`TomSaga.retryPolicy`; a run for an older version does nothing. When the last
attempt fails, or the action throws a `TomPermanentFailure`, the saga turns to
`compensating` and compensates the steps that completed, last first, each by
`TomSaga.compensationRetryPolicy`. A compensation that fails for good ends the
saga `failed` and fails its run with a `TomPermanentJobFailure`, which raises
the scheduler's alert. The run of the next transition is queued after the
transaction commits; one lost in between is found by `resume`.

- **Implements:** `TomClosable`

#### Factory Constructors

```dart
factory TomSagaOrchestrator({
  TomSagaStore? store,
  TomJobStore? jobStore,
  String jobPrefix = tomSagaJobPrefix,
  Duration tickInterval = const Duration(seconds: 15),
  Duration sweepInterval = const Duration(minutes: 5),
  Duration leaseTimeout = const Duration(minutes: 15),
  DateTime Function()? clock,
  TomJobAlertSink? onAlert,
  TomLeaseLock? lock,
})
```

`store` defaults to a `TomMemorySagaStore` and `jobStore` to a
`TomMemoryJobStore`, which is right for tests and wrong for any deployment: a
saga kept in memory is lost by a restart, which is what a saga exists to
survive. Give a `TomSqlSagaStore` and the durable job store the outbox and the
application's scheduler use. `tickInterval`, `leaseTimeout`, `clock`, `onAlert`
and `lock` configure the scheduler.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `store` | `TomSagaStore` | Where saga states are kept (final). |
| `jobStore` | `TomJobStore` | The queue the saga runs are in (final). |
| `jobPrefix` | `String` | The prefix of the job names — `tomSagaJobPrefix` by default (final). |
| `sweepInterval` | `Duration` | How often started orchestration looks for sagas whose run is gone (final). |
| `scheduler` | `TomScheduler` | The scheduler running the transitions, dispatching inline. Owned and closed by `close` (final). |
| `sagas` | `Map<String, TomSaga>` | *(getter)* The registered sagas, by name; unmodifiable. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `stepJobName` | `String stepJobName(String saga)` | The job running the steps of `saga`: `<jobPrefix>.<saga>`. |
| `compensationJobName` | `String compensationJobName(String saga)` | The job running the compensations of `saga`: `<jobPrefix>.<saga>.compensation`. |
| `register` | `void register(TomSaga saga)` | Registers `saga` and its two jobs, so it can be begun and its runs executed. Every node that may run a saga registers it under the same name — the scheduler takes no run of a job it has not registered. Throws `transactions.saga.already_registered` for a name registered already, `transactions.saga.closed` after `close`. |
| `begin` | `Future<String> begin(String sagaName, {Map<String, Object?> data = const {}, String? id})` | Begins the saga `sagaName` with a copy of `data`, for the tenant in context, and answers its id: `id`, or a new UUID. Returns once the saga is stored and its first step queued. Called inside a transaction on the saga store's data source, the saga begins only if that transaction commits. Throws `transactions.saga.unknown`, `…invalid_id`, `…data_not_json`, `…id_taken` and `…closed`. |
| `find` | `Future<TomSagaState?> find(String id)` | The saga `id` of the tenant in context, or `null`. |
| `resume` | `Future<int> resume()` | Re-queues the run of every unfinished saga whose run is no longer in the job store, or has finished, and answers how many it re-queued. Looks in the context's tenant and, when a `TomTenancy` is installed, in every tenant's; passes over sagas not registered here. Called by `start` and every `sweepInterval` after it. |
| `start` | `Future<void> start()` | Resumes the unfinished sagas, then runs transitions on the scheduler's tick and calls `resume` every `sweepInterval`; a sweep that fails is logged as a warning. |
| `tick` | `Future<void> tick()` | Runs one pass of due transitions and waits for them to finish — for tests, and for a caller that wants a saga moved on now. While the orchestrator is started, a pass of its own may be under way; this one then returns at once, and the transitions are that pass's. |
| `close` | `Future<void> close()` | *(override)* Stops running sagas and closes the scheduler, releasing its leases. The sagas stay where they are, and the next `start` resumes them. Idempotent. |

## Enums

### TomTransactionOutcome

What became of a transaction's **work**. The four are distinguished because
three of them need different things done about them, and a boolean merged all
four into "did something go wrong".

| Value | Meaning |
| ----- | ------- |
| `committed` | Every participant committed. The work is durable. |
| `partiallyCommitted` | Every participant promised in `prepare` and at least one then failed to commit. Some of the work is durable and some is not, and no coordinator can repair that. |
| `rolledBack` | The transaction was rolled back — a veto during prepare, or an explicit `rollbackTransaction()` — and every participant undid its work. Nothing is durable and nothing is outstanding. |
| `rolledBackWithFailures` | Rolled back, and at least one participant could not undo its work. The outcome a caller most needs told, because it is the one that requires a human: the work was neither committed nor undone. |

### TomSagaStatus

Where a saga is in its life.

| Value | Meaning |
| ----- | ------- |
| `running` | Running its steps. |
| `compensating` | A step failed for good; compensating the steps done before it. |
| `completed` | Every step ran. |
| `compensated` | A step failed for good, and every step before it was compensated. |
| `failed` | A compensation failed for good: the saga is left half done, for an operator. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isFinished` | `bool` | *(getter)* Whether the saga has ended: `completed`, `compensated` or `failed`. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `parse` | `static TomSagaStatus parse(String name)` | The status stored as `name`. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `tomSagaJobPrefix` | `String` | `'saga'`, the default prefix of the orchestrator's job names: a saga `place_order` runs its steps as job `saga.place_order` and its compensations as `saga.place_order.compensation`. Stable across restarts by necessity, like every job name: it ties queued runs to the definitions that execute them. |
| `defaultSagaTable` | `String` | `'tom_saga'`, the saga table's name when nothing overrides it. |
| `defaultDecisionTable` | `String` | `'tom_transaction_decision'`, the decision table's name when nothing overrides it. |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `sagaTable` | `TomFrameworkTable sagaTable(String table)` | The one declaration of the saga table: primary key `(tenant, saga_id)`, `status` and the `step` cursor, the `version` optimistic lock, the JSON `data` and the `error`, the `run_window` instant a resumption looks its run up by, `created_at` and `updated_at`, and the `(status, updated_at)` index resumption and the purge read. Listed by `frameworkOwnedTables`. |
| `sagaTableDdl` | `String sagaTableDdl(String table)` | The `CREATE TABLE` statement for the saga table, derived from `sagaTable`. |
| `decisionTable` | `TomFrameworkTable decisionTable(String table)` | The one declaration of the decision table: `transaction_id`, `branch_id` and `decided_at`, primary key `(transaction_id, branch_id)` — one row per decided branch. Listed by `frameworkOwnedTables`. |
| `decisionTableDdl` | `String decisionTableDdl(String table)` | The `CREATE TABLE` statement for the decision table, derived from `decisionTable`. |

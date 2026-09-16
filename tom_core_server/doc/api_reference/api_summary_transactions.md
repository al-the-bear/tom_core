# Tom Core Server API Reference: Transactions Module

A lightweight transaction coordinator: enlistable participants, a unit of work
that commits or rolls them back as a group, and an ambient manager that holds
the current transaction of the running flow — zone-scoped, so concurrent flows
in one isolate do not share it — allowing the endpoint pipeline and data sources
to join it without threading a handle through every call. The conclusion is a
**two-phase commit** — every participant is prepared before any is committed —
see [TomTransactionParticipant](#tomtransactionparticipant) for what that asks
of an implementer and for the one outcome it cannot rule out.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomTransactionException](#tomtransactionexception)
  - [TomTransactionParticipant](#tomtransactionparticipant)
  - [TomTransaction](#tomtransaction)
  - [TomTransactionManager](#tomtransactionmanager)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/transactions/transaction_manager.dart`.

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

## Class Hierarchy

```
TomServerException  (little_things)
    └── TomTransactionException

TomTransactionParticipant  (abstract)
TomTransaction
TomTransactionManager  (abstract, static-only)
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
failure.

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
| `getParticipantId` | `String getParticipantId()` | A stable id used to deduplicate this participant within a transaction. |
| `startTransaction` | `Future<bool> startTransaction()` | Begins the participant's part of the transaction; called once on enlist. |
| `prepare` | `Future<bool> prepare()` | Phase one: promises that `commit` will succeed. Returning `false` — or throwing — vetoes the transaction, while nothing is durable. A participant with nothing to prepare returns `true`. |
| `commit` | `Future<bool> commit()` | Phase two: makes the work durable. Reached only after every participant prepared, so a `false` is not a veto — it reports a broken promise and leaves the transaction partially committed. |
| `rollback` | `Future<void> rollback()` | Undoes the participant's work when the transaction is rolled back. Reachable after a successful `prepare`, never after this participant's own `commit`. |
| `endTransaction` | `Future<bool> endTransaction()` | Releases per-transaction resources after commit or rollback. Decides nothing. |

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
| `isReadOnly` | `bool` | Whether this transaction was opened as read-only (advisory; does not itself prevent writes). |
| `isRunning` | `bool` | *(getter)* Whether the transaction is still open (not yet committed or rolled back). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `registerParticipant` | `Future<void> registerParticipant(TomTransactionParticipant ttp)` | Enlists `ttp`, calling its `startTransaction()` once; deduplicated by participant id. Enlistment is all or nothing: the participant is recorded only after a `true`, and a `false` or a throw leaves it unenlisted and raises `TomTransactionException` naming it (`…start_failed` / `…start_threw`, the latter carrying the original as `rootException`). Also throws when the transaction is no longer running. |
| `commitTransaction` | `Future<bool> commitTransaction()` | Prepares every participant, then — only if all promised — commits every participant, then ends them all. A veto or a throw during prepare rolls the transaction back instead; a `commit` that fails after a successful prepare does not, and is logged as a partial commit. Clears the transaction from its scope and returns whether it succeeded. |
| `rollbackTransaction` | `Future<bool> rollbackTransaction()` | Rolls back every participant then ends them; clears the transaction from its scope and returns whether all end calls succeeded. |

"Ends them" is unconditional on both paths: a participant whose
`endTransaction()` returns `false` does not stop the ones behind it from being
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
pipeline can join or conclude it without threading a handle through every call.
"Current" means current to the running flow: the transaction lives in a `Zone`
value, exactly as the request principal does, so two flows interleaving in one
isolate cannot see each other's work. Abstract with a static-only surface.

- **Extends:** none (abstract, static members only)

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `runInTransactionScope` | `static R runInTransactionScope<R>(R Function() body)` | Runs `body` with its own current transaction, isolated from every other flow in this isolate. Returns whatever `body` returns, so an asynchronous body is awaited by the caller. |
| `startTransaction` | `static (TomTransaction, bool) startTransaction([bool isReadOnly = false])` | Returns the current transaction, creating one if none is active; the boolean is `true` when a new one was created. `isReadOnly` is honoured only for a new transaction. |
| `getCurrentTransaction` | `static TomTransaction? getCurrentTransaction()` | The current transaction, or `null` if none is active. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `hasTransactionScope` | `static bool` | *(getter)* Whether the current zone carries a transaction scope of its own; `false` means `startTransaction` would use the process-wide fallback scope. |
| `transactional` | `static bool` | *(getter)* Whether a transaction is currently active and still running. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.

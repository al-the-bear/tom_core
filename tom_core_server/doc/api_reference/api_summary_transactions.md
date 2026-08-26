# Tom Core Server API Reference: Transactions Module

A lightweight transaction coordinator: enlistable participants, a unit of work
that commits or rolls them back as a group, and an ambient manager that holds
the current transaction of the running flow — zone-scoped, so concurrent flows
in one isolate do not share it — allowing the endpoint pipeline and data sources
to join it without threading a handle through every call. There is no prepare
phase, so this is not two-phase commit; see
[TomTransactionParticipant](#tomtransactionparticipant) for what that costs an
implementer.

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
work concludes with `commitTransaction` (commit-all, rolling back if any
participant vetoes) or `rollbackTransaction`. Instances are created only by
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
`commit`/`endTransaction` on success or `rollback`/`endTransaction` on failure.

**This is not two-phase commit: there is no prepare step.** Under a prepare
phase a veto arrives while nothing has been committed yet; here `commit` *is*
the commit, participants are committed in registration order, and a veto from
the third arrives after the first two have already committed. The coordinator
answers by calling `rollback` on all of them, so an implementer must treat
`rollback` as reachable after their own `commit` has returned `true`, and the
transaction is repaired only if that rollback can undo committed work. A
participant that cannot undo its commit should do the work that can fail inside
`commit` itself, so its veto is raised before anything is made durable.

- **Extends:** none (abstract)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `getParticipantId` | `String getParticipantId()` | A stable id used to deduplicate this participant within a transaction. |
| `startTransaction` | `Future<bool> startTransaction()` | Begins the participant's part of the transaction; called once on enlist. |
| `endTransaction` | `Future<bool> endTransaction()` | Releases per-transaction resources after commit or rollback. |
| `commit` | `Future<bool> commit()` | Commits the participant's work; returning `false` vetoes the transaction. |
| `rollback` | `Future<void> rollback()` | Undoes the participant's work when the transaction is rolled back. |

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
| `registerParticipant` | `Future<void> registerParticipant(TomTransactionParticipant ttp)` | Enlists `ttp`, calling its `startTransaction()` once; deduplicated by participant id. Throws `TomTransactionException` if the transaction is no longer running. |
| `commitTransaction` | `Future<bool> commitTransaction()` | Commits every participant then ends them; if any vetoes, rolls back instead. Clears the transaction from its scope and returns whether it succeeded. |
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

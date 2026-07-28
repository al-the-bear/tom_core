# Tom Core Server API Reference: Transactions Module

A lightweight two-phase transaction coordinator: enlistable participants, a unit
of work that commits or rolls them back as a group, and an ambient manager that
holds the single current transaction per isolate so the endpoint pipeline and
data sources can join it without threading a handle through every call.

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

`TomTransactionManager` provides ambient access to the current transaction — a
single static, so it models one active transaction per isolate. The pipeline
opens one for a `@TomTransactional` endpoint and commits/rolls it back when the
call returns; the transaction clears itself from the manager on completion.

## Class Hierarchy

```
TomServerException  (server module)
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
  Object? stack,
  Object? rootException,
  bool autoLog = false,
})
```

### TomTransactionParticipant

A resource that can enlist in a `TomTransaction` (two-phase style). Implemented
by `TomDataSource`, so any data source used during a transaction joins it. The
coordinator drives the lifecycle: `startTransaction` on enlistment, then
`commit`/`endTransaction` on success or `rollback`/`endTransaction` on failure.

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
| `commitTransaction` | `Future<bool> commitTransaction()` | Commits every participant then ends them; if any vetoes, rolls back instead. Clears the current transaction and returns whether it succeeded. |
| `rollbackTransaction` | `Future<bool> rollbackTransaction()` | Rolls back every participant then ends them; clears the current transaction and returns whether all end calls succeeded. |

### TomTransactionManager

Ambient access to the current `TomTransaction`. Holds a single current
transaction (per isolate) so participants and the endpoint pipeline can join or
conclude it without threading a handle through every call. Abstract with a
static-only surface.

- **Extends:** none (abstract, static members only)

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `startTransaction` | `static (TomTransaction, bool) startTransaction([bool isReadOnly = false])` | Returns the current transaction, creating one if none is active; the boolean is `true` when a new one was created. `isReadOnly` is honoured only for a new transaction. |
| `getCurrentTransaction` | `static TomTransaction? getCurrentTransaction()` | The current transaction, or `null` if none is active. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `transactional` | `static bool` | *(getter)* Whether a transaction is currently active and still running. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.

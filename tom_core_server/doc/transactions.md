# Transactions Module

A lightweight transaction coordinator. A `TomTransaction` groups one or more
`TomTransactionParticipant`s (data sources) so they commit or roll back together,
and `TomTransactionManager` provides ambient access to the current transaction so
participants and the request pipeline can join or conclude it without passing a
handle around.

## Table of Contents

- [Overview](#overview)
- [The Participant Contract](#the-participant-contract)
- [The Transaction Lifecycle](#the-transaction-lifecycle)
- [Ambient Access](#ambient-access)
- [How the Pipeline Uses It](#how-the-pipeline-uses-it)
- [Concurrency Model](#concurrency-model)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomTransactionParticipant` | abstract class | A resource that can enlist in a transaction |
| `TomTransaction` | class | One unit of work coordinating its participants |
| `TomTransactionManager` | abstract class (statics) | Ambient access to the current transaction |
| `TomTransactionException` | class | Raised on an invalid transaction operation |

## The Participant Contract

A participant is keyed by a stable id and exposes the two-phase hooks:

```dart
abstract class TomTransactionParticipant {
  String getParticipantId();
  Future<bool> startTransaction(); // on enlistment
  Future<bool> commit();           // returning false vetoes the transaction
  Future<void> rollback();         // undo on failure
  Future<bool> endTransaction();   // release resources, after commit or rollback
}
```

`TomDataSource` implements this contract, so any data source touched during a
transaction enlists in it.

## The Transaction Lifecycle

A `TomTransaction` is created only through `TomTransactionManager.startTransaction`
(its constructor is private). Participants enlist with `registerParticipant`,
which calls their `startTransaction()` exactly once — registering the same id
again is a no-op, so callers never have to track membership. Enlisting after the
transaction has concluded throws `TomTransactionException`.

The work is concluded one of two ways:

- **`commitTransaction()`** — marks the transaction not-running, then calls
  `commit()` on each participant in registration order. If any participant
  returns `false`, the whole transaction falls back to `rollbackTransaction()`.
  On a clean commit, `endTransaction()` is called on every participant and the
  current transaction is cleared.
- **`rollbackTransaction()`** — marks not-running, calls `rollback()` then
  `endTransaction()` on every participant, and clears the current transaction.

A transaction runs once: after it concludes, `isRunning` is `false`.

## Ambient Access

`TomTransactionManager.startTransaction([isReadOnly])` returns
`(TomTransaction, bool)` — the boolean is `true` only when a *new* transaction
was created, so the caller that actually opened the transaction is the one
responsible for concluding it; a nested caller receives the existing transaction
and `false`. `getCurrentTransaction()` and the `transactional` getter expose the
current state. `isReadOnly` is advisory and only honoured when a new transaction
is created.

## How the Pipeline Uses It

For an endpoint annotated `@TomTransactional`, the endpoint pipeline opens a
transaction around the call:

```dart
final (transaction, _) = TomTransactionManager.startTransaction();
try {
  // ... invoke the endpoint; data sources enlist as they are used ...
  await transaction.commitTransaction();
} catch (_) {
  await transaction.rollbackTransaction();
}
```

## Concurrency Model

The current transaction is held in a single static field, so the manager models
**one active transaction per isolate** at a time (it is not zone-scoped). This
fits the server's request flow — each request opens, uses, and clears the
transaction — but it does not isolate concurrently-interleaved requests within
the same isolate. A zone-scoped current transaction is a possible future
improvement (tracked in the quest completion steps).

## Core Components

- **`TomTransactionParticipant`** — the enlist/commit/rollback/end contract,
  implemented by data sources.
- **`TomTransaction`** — registration, dedup-by-id, and the commit/rollback
  drive (with commit-veto → rollback).
- **`TomTransactionManager`** — the ambient single-transaction accessor.
- **`TomTransactionException`** — invalid-state signalling (a
  `TomServerException`).

## Dependencies

- The little-things module — `TomServerException` (base of
  `TomTransactionException`).
- The datasources module — `TomDataSource` is the concrete
  `TomTransactionParticipant`.
- The endpoints module — drives `startTransaction` / `commitTransaction` /
  `rollbackTransaction` for `@TomTransactional` endpoints.

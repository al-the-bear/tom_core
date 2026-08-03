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
- [Transaction Scopes](#transaction-scopes)
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
| `TomTransactionManager` | abstract class (statics) | Zone-scoped ambient access to the current transaction |
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

"Current" means current *to this flow of work*, not to this isolate — see
[Transaction Scopes](#transaction-scopes).

## Transaction Scopes

The current transaction lives in a `Zone` value, exactly as the request principal
does. A scope is the unit of isolation: the transaction opened inside one is
invisible outside it, and a transaction opened outside is invisible within.

```dart
await TomTransactionManager.runInTransactionScope(() async {
  final (txn, _) = TomTransactionManager.startTransaction();
  await doWork();               // data sources enlist with *this* transaction
  await txn.commitTransaction();
});
```

`runInTransactionScope` returns whatever its body returns, so an asynchronous
body is awaited by the caller rather than swallowed. `hasTransactionScope`
reports whether the current zone carries a scope of its own; `false` means
`startTransaction()` would fall back to the process-wide scope.

Scopes are established for you on the request path:

- the server's authentication middleware opens one per request, so every request
  has its own current transaction;
- the endpoint pipeline opens one for a `@TomTransactional` endpoint whose
  request does not already have a scope. The authentication middleware is
  replaceable (`TomBaseServerConfiguration.authenticationMiddleware`), so this is
  a guard rather than a second mechanism — the failure it prevents (one request
  committing another's work) is silent.

Code running outside every scope — a script, a test, a `main()` — shares one
process-wide fallback scope. That is correct for a program with a single flow of
work, and it is what preserves the nesting contract for existing callers. Code
that runs *concurrent* flows off the request path (a scheduler running two jobs,
a batch tool fanning out) must wrap each flow in `runInTransactionScope` to get
the isolation a request gets for free.

## How the Pipeline Uses It

For an endpoint annotated `@TomTransactional`, the endpoint pipeline ensures a
scope exists and opens a transaction around the call:

```dart
final (transaction, _) =
    TomTransactionManager.startTransaction(transactionInfo.isReadOnly);
try {
  // ... invoke the endpoint; data sources enlist as they are used ...
  await transaction.commitTransaction();
} catch (_) {
  await transaction.rollbackTransaction();
}
```

`@TomTransactional(isReadOnly: true)` is passed through to the transaction, so a
read-only endpoint opens a read-only transaction and participants can act on the
flag.

## Concurrency Model

The current transaction is **per flow of work, not per isolate**. Two requests
interleaving in one isolate hold two independent current transactions: neither
can enlist in, commit, or roll back the other's work, and an `await` inside a
transactional block cannot let a second request conclude the first one's
transaction.

A transaction may conclude in a different zone from the one that opened it (after
an `await`, or from a callback scheduled elsewhere), so each `TomTransaction`
holds a reference to the scope it is current in and clears *that* scope —
identity-guarded, so a concluded transaction can never wipe a successor.

## Core Components

- **`TomTransactionParticipant`** — the enlist/commit/rollback/end contract,
  implemented by data sources.
- **`TomTransaction`** — registration, dedup-by-id, and the commit/rollback
  drive (with commit-veto → rollback).
- **`TomTransactionManager`** — the zone-scoped ambient accessor, plus
  `runInTransactionScope` / `hasTransactionScope` for establishing and detecting
  a scope.
- **`TomTransactionException`** — invalid-state signalling (a
  `TomServerException`).

## Dependencies

- The little-things module — `TomServerException` (base of
  `TomTransactionException`).
- The datasources module — `TomDataSource` is the concrete
  `TomTransactionParticipant`.
- The endpoints module — drives `startTransaction` / `commitTransaction` /
  `rollbackTransaction` for `@TomTransactional` endpoints, and guards that such
  an endpoint runs inside a scope.
- The server module — the authentication middleware opens a transaction scope
  per request.

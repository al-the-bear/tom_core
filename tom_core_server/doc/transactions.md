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
  - [Failure keys](#failure-keys)
- [Ambient Access](#ambient-access)
- [Transaction Scopes](#transaction-scopes)
- [How the Pipeline Uses It](#how-the-pipeline-uses-it)
- [Read-Only](#read-only)
- [Concurrency Model](#concurrency-model)
- [Not Yet Implemented](#not-yet-implemented)
- [Verification](#verification)
- [Core Components](#core-components)
- [Dependencies](#dependencies)

---

## Overview

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomTransactionParticipant` | abstract class | A resource that can enlist in a transaction |
| `TomTransaction` | class | One unit of work coordinating its participants |
| `TomTransactionManager` | abstract class | Zone-scoped ambient access to the current transaction, and `runInTransaction` to drive one. Statics only |
| `TomTransactionException` | class | Raised on an invalid transaction operation |

## The Participant Contract

A participant is keyed by a stable id and exposes five lifecycle hooks:

```dart
abstract class TomTransactionParticipant {
  String getParticipantId();
  Future<bool> startTransaction(TomTransaction transaction); // on enlistment
  Future<bool> prepare();          // phase one; returning false vetoes
  Future<bool> commit();           // phase two; the promise being kept
  Future<void> rollback();         // undo on failure
  Future<bool> endTransaction();   // release resources, after commit or rollback
}
```

`TomDataSource` implements this contract, so any data source touched during a
transaction enlists in it.

**This is two-phase commit.** `prepare()` runs on every participant before
`commit()` runs on any of them, so a veto arrives while nothing is durable and
aborting costs nothing: the coordinator rolls everyone back and no participant
has to undo committed work. That is the whole reason for the phase, and it is
what makes a transaction spanning two resources atomic.

Two things follow for anyone implementing a participant. **Everything that can
fail belongs in `prepare()`** — it is the last point at which failing is free,
and it is the only place a refusal is a veto. And `commit()` is a promise being
kept rather than a decision: a `false` there is not acted on as a refusal,
because peers may already be durable.

The residue is the outcome two phases cannot rule out. A participant that
promises and then fails in `commit()` leaves the transaction **partially
committed** — the coordinator logs it at error level naming the participants
that failed, commits the rest anyway, and rolls nobody back, because rolling
back a peer whose commit succeeded would discard work the transaction decided to
keep. No coordinator can repair that; the repair is at the named resources.

A participant with nothing to prepare returns `true` and does its work in
`commit()`. `MariaDbDatasource` is that participant — a plain
`START TRANSACTION` / `COMMIT` has no statement that makes a commit certain
without performing it — so enlisting one beside an XA data source weakens the
guarantee to "atomic unless the one-phase participant's commit fails". Use
`MariaDbXADatasource` for every resource in a transaction that has to be atomic
across them: it maps `prepare()` onto `XA END` + `XA PREPARE` and `commit()`
onto `XA COMMIT`, and a prepared XA branch is one the server has undertaken to
be able to commit.

## The Transaction Lifecycle

A `TomTransaction` is created only through `TomTransactionManager.startTransaction`
(its constructor is private). Participants enlist with `registerParticipant`,
which calls their `startTransaction()` exactly once — registering the *same
participant* again is a no-op, so callers never have to track membership.
Enlisting after the transaction has concluded throws `TomTransactionException`.

**An id belongs to one object.** `getParticipantId()` names a *resource* rather
than an object — `MariaDbDatasource` answers
`"MariaDb-<database>@<host>:@<port>"` — so two instances configured for one
database share an id by construction. Registering the second is not a
re-registration and is refused with `…duplicate_id`, because the two are two
connections with two transactions of their own and only one of them can be the
transaction's. Collapsing the second to the first is the one failure here that
says nothing at all: the caller's `await` completes, the resource is never
started, prepared, committed, rolled back or ended, and the work issued against
it is neither committed with the transaction nor rolled back with it — the first
sign being data that should have been undone and was not. A participant that
needs an enlistment of its own returns an id nothing else answers.

**Enlistment is all or nothing.** A participant is recorded only after its
`startTransaction()` returns `true`. One that returns `false` or throws is not
enlisted, and either way `registerParticipant` raises a
`TomTransactionException` naming it —
`transaction_manager.register_participant.start_failed` for the refusal,
`…start_threw` for the throw, the latter carrying the participant's own failure
as its `rootException`. So a caller either has the participant in the
transaction or has an exception, never a transaction holding a resource that
never opened one.

Both failures are reported alike because they are the same event to the
coordinator, and because the data sources that can fail here return `false`
rather than throwing — a contract that handled only the throw would be
documenting the path that does not occur. What makes it worth stating is what
the alternative costs: a participant left enlisted is one `commitTransaction`
commits with nothing open. For `MariaDbXADatasource` that is `XA COMMIT null;`
against the branch its failed start cleared — a commit-time error naming the
wrong operation, arriving exactly when the coordinator is deciding whether to
roll everyone back.

A failed enlistment does not conclude the transaction. The participants that did
enlist are unaffected, so a caller that catches the exception may carry on with
them or roll back; and because the failed id was never recorded, a later attempt
with a participant that *can* start is a first enlistment rather than a
deduplicated no-op.

### Failure keys

Every one is raised by `registerParticipant`, and every one is a
`TomTransactionException` — a `TomServerException`, so it flows through the
standard server error mapping. Concluding a transaction raises none of these:
`commitTransaction` and `rollbackTransaction` report failure by returning
`false`, because a participant refusing to commit is an outcome the coordinator
knows what to do with, while a participant that cannot enlist leaves nothing
coherent to drive.

| Key | Meaning |
| --- | ------- |
| `transaction_manager.register_participant.transaction_not_running` | The transaction has already committed or rolled back. Nothing was enlisted. |
| `transaction_manager.register_participant.duplicate_id` | A *different* object claimed an id already enlisted. `parameters['participant']` names the id; the newcomer is not enlisted and was never started, and the participant already holding the id is untouched. Registering the same object again is a no-op and raises nothing. |
| `transaction_manager.register_participant.start_failed` | The participant's `startTransaction()` returned `false`. `parameters['participant']` names it; it is not enlisted. |
| `transaction_manager.register_participant.start_threw` | The participant's `startTransaction()` threw. `parameters['participant']` names it and `rootException` carries what it raised; it is not enlisted. |

The work is concluded one of two ways:

- **`commitTransaction()`** — marks the transaction not-running, then runs the
  two phases in registration order: `prepare()` on every participant, and only
  if all of them answered `true`, `commit()` on every participant. A participant
  that vetoes — or throws — during prepare turns the whole thing into a
  `rollbackTransaction()`. A `commit()` that fails after a successful prepare
  does **not**: the remaining participants are committed anyway and the partial
  commit is logged by name. Either way `endTransaction()` is called on every
  participant and the current transaction is cleared.
- **`rollbackTransaction()`** — marks not-running, calls `rollback()` then
  `endTransaction()` on every participant, and clears the current transaction.

"Every participant" is unconditional on both paths: a participant whose
`endTransaction()` returns `false` does not stop the participants behind it from
being ended, so when implementing one you can count on your release running even
when a peer's has already failed. Nothing calls back afterwards to release what a
skipped participant still holds — the transaction is over — which for a data
source would mean a connection that never returns to the pool. The boolean each
method returns is the conjunction of *all* the end calls, so one failure among
them is reported however many succeed after it.

**A transaction that is not running is never the current one.** Both
conclusions clear the scope in a `finally`, so the invariant holds however the
method leaves — and every participant call inside them is caught, so a data
source whose connection drops mid-conclusion is logged against its id rather
than propagated. The two are separate guarantees on purpose: the catches keep
one participant's failure from stopping its neighbours, and the `finally` keeps
*anything* that escapes from leaving the scope pinned to a dead transaction.

That state is worth naming, because each of its symptoms points away from its
cause. `getCurrentTransaction()` answers non-null while `transactional` answers
`false`, so a caller that tests the other accessor gets the opposite answer.
Every later `startTransaction()` in that scope hands back the dead transaction
with `isNew == false`, which the caller reads as "I am nested inside somebody
else's transaction" — so it neither concludes it nor opens one of its own. And
every enlistment on it is refused with `transaction_not_running`. On the request
path the scope goes away with the request; off it, the scope is the process-wide
fallback and the state outlives the flow that produced it.

A transaction runs once: after it concludes, `isRunning` is `false`.

## Ambient Access

`TomTransactionManager.startTransaction([isReadOnly])` returns
`(TomTransaction, bool)` — the boolean is `true` only when a *new* transaction
was created, so the caller that actually opened the transaction is the one
responsible for concluding it; a nested caller receives the existing transaction
and `false`. `getCurrentTransaction()` and the `transactional` getter expose the
current state. `isReadOnly` is only honoured when a new transaction is created —
a nested caller receives the enclosing transaction unchanged.

"Current" means current *to this flow of work*, not to this isolate — see
[Transaction Scopes](#transaction-scopes).

## Transaction Scopes

The current transaction lives in a `Zone` value, exactly as the request principal
does. A scope is the unit of isolation: the transaction opened inside one is
invisible outside it, and a transaction opened outside is invisible within.

```dart
await TomTransactionManager.runInTransaction((txn) async {
  await doWork();               // data sources enlist with *this* transaction
});
```

`runInTransaction` establishes the scope if the flow has none, opens the
transaction, commits it when the body returns and **rolls it back when the body
throws**, rethrowing the body's own exception. It joins a transaction that is
already running instead of nesting a second one, and concludes nothing it did
not open — the `isNew` contract of `startTransaction`, reached without the
caller having to read it.

The last part is the reason it exists. Written out, the same flow is a scope, a
`startTransaction`, the work, a `commitTransaction` *and* a `catch` that rolls
back and rethrows; the version without the `catch` is shorter, reads correctly,
and leaks — the participants that enlisted are never rolled back, never ended,
their connections never return to the pool, and the transaction stays current in
its scope. Off the request path that scope is the process-wide fallback, so the
next flow inherits it.

A commit that does not succeed is a `TomTransactionException`
(`transaction_manager.run_in_transaction.commit_failed`) rather than a quiet
return, because a `false` from `commitTransaction` means the work was vetoed and
rolled back, partially committed, or committed with a participant failing to
release — none of which is a result to hand back as though the body had
succeeded.

Drive the transaction yourself when you need to decide commit-or-rollback on
something other than a throw, or to tell those three apart:

```dart
await TomTransactionManager.runInTransactionScope(() async {
  final (txn, isNew) = TomTransactionManager.startTransaction();
  try {
    await doWork();
    if (!await txn.commitTransaction()) reportNotCommitted();
  } catch (_) {
    await txn.rollbackTransaction();   // the part that is easy to forget
    rethrow;
  }
});
```

`runInTransactionScope` returns whatever its body returns, so an asynchronous
body is awaited by the caller rather than swallowed. It establishes a scope and
opens no transaction, which is what the authentication middleware needs — every
request gets a scope whether or not its endpoint turns out to be transactional.
`hasTransactionScope` reports whether the current zone carries a scope of its
own; `false` means `startTransaction()` would fall back to the process-wide
scope.

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
a batch tool fanning out) must wrap each flow in `runInTransaction` — or, where
the transaction is opened separately, `runInTransactionScope` — to get
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

`@TomTransactional(isReadOnly: true)` is passed through to the transaction and
reaches every participant as the argument of `startTransaction`, so a read-only
endpoint opens a read-only transaction and the data source opens
`START TRANSACTION READ ONLY` — see [Read-Only](#read-only).

## Read-Only

A transaction opened read-only —
`TomTransactionManager.startTransaction(true)`, or
`@TomTransactional(isReadOnly: true)` on an endpoint — carries that as
`TomTransaction.isReadOnly`, and every participant is handed the transaction as
the argument of `startTransaction`. That argument is the only path between the
annotation that declares the intent and the resource that can act on it.

**The coordinator enforces nothing.** It has no idea what a write is. What the
flag means is therefore decided by each participant:

| Participant | What it does with it |
| ----------- | -------------------- |
| `MariaDbDatasource` | Opens `START TRANSACTION READ ONLY`, so the server refuses every write on that connection until the transaction ends (`ER_CANT_EXECUTE_IN_READ_ONLY_TRANSACTION`). |
| `MariaDbXADatasource` | Cannot honour it — `XA START` has no `READ ONLY` form — and logs a warning saying so rather than appearing to. |
| Anything else | Whatever it chooses; the flag is an argument, not an instruction. |

The transaction is **handed over, not looked up**. A participant could in
principle read `TomTransactionManager.getCurrentTransaction()` from inside the
hook the coordinator just called, and it would be wrong in the case the scoping
exists for: the answer comes from whatever zone the call is running in, which
need not be the zone the transaction was opened in.

## Concurrency Model

The current transaction is **per flow of work, not per isolate**. Two requests
interleaving in one isolate hold two independent current transactions: neither
can enlist in, commit, or roll back the other's work, and an `await` inside a
transactional block cannot let a second request conclude the first one's
transaction.

A transaction may conclude in a different zone from the one that opened it (after
an `await`, or from a callback scheduled elsewhere), so each `TomTransaction`
holds a reference to the scope it is current in and clears *that* scope —
identity-guarded, so a concluded transaction can never wipe a successor, and in
a `finally`, so it clears it whatever happens on the way.

## Not Yet Implemented

- **A participant that breaks its promise leaves the transaction partially
  committed.** A `commit()` that fails after a successful `prepare()` is not a
  veto and cannot be answered with a rollback — peers are already durable. The
  coordinator logs the failure at error level naming every participant that
  broke its promise and commits the rest, and repair is at those resources. Two
  phases make a veto free; they do not make a commit infallible.
- **`isReadOnly` is not enforced on an XA branch.** `MariaDbXADatasource` gets
  the flag like every participant and cannot act on it: `XA START` has no
  `READ ONLY` form in MariaDB or MySQL, so writes on that connection are not
  prevented. It warns rather than failing the start, because refusing would take
  the distributed transaction with it. See [Read-Only](#read-only).
- **There is no transaction log, so a process that dies mid-commit is not
  recovered.** The coordinator's state lives in a zone value; nothing is written
  down between the phases and nothing replays afterwards. A crash after the
  prepare phase leaves every participant's work prepared and unresolved — for
  `MariaDbXADatasource`, XA branches holding their locks until somebody issues
  `XA RECOVER`, which nothing here does. The prepare phase is what makes those
  branches *recoverable*; recovering them is the operator's.
- **The commit is not concurrent and has no timeout.** Participants are driven
  one at a time, awaited in order, with no deadline — so one participant that
  blocks blocks the transaction and the request behind it indefinitely. Timeouts
  belong to the participant.

## Verification

`test/transactions_test.dart` covers the manager end to end against a scripted
participant: opening and concluding a transaction, the two phases in order
across two participants — every participant prepared before any is committed —
the prepare veto and the prepare that throws, the commit that fails after a
successful prepare and is reported rather than rolled back,
`registerParticipant`'s all-or-nothing enlistment — including the two failures a
participant can present, a `startTransaction` that returns `false` and one that
throws — a participant throwing from each of the four conclusion hooks, which
has to leave the scope clear and the next `startTransaction()` new, with the
`finally` that guarantees it read from the source because nothing can reach it —
scope isolation through `runInTransactionScope`, ambient enlistment,
and `TomTransactionException`.

Every failure path is driven with **two** participants. One is exactly the
population size at which a drive that stops at the first failure looks correct:
the single participant reports its failure, the return value carries it, and
nothing shows that the participant *behind* it was never concluded. And because
a throwing participant is caught rather than propagated — one resource's failure
must not stop its neighbours — the suite pins the other half of that bargain:
for every conclusion hook, the swallowed throw is logged naming the participant
that raised it and what it raised. It also holds the group named `The example runs
green`, which spawns the example and asserts its transcript, and a check that
this guide and the contract agree about the prepare phase.

```bash
dart run example/transactions/transactions_example.dart
```

`example/transactions/transactions_example.dart` drives the same lifecycle with
an in-memory participant, so the mechanics are visible without a data source. In
production the participants are data sources — `TomDataSource` implements
`TomTransactionParticipant` — and the endpoint pipeline opens and closes the
transaction around a `@TomTransactional` endpoint.

## Core Components

- **`TomTransactionParticipant`** — the enlist/commit/rollback/end contract,
  implemented by data sources.
- **`TomTransaction`** — registration, dedup-by-id, and the commit/rollback
  drive (with commit-veto → rollback).
- **`TomTransactionManager`** — the zone-scoped ambient accessor, plus
  `runInTransaction` for the whole flow, and `runInTransactionScope` /
  `hasTransactionScope` for establishing and detecting a scope without opening
  a transaction.
- **`TomTransactionException`** — invalid-state signalling (a
  `TomServerException`).

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | every file | `Future`, `Zone` |
| `tom_core_kernel` | package | `transaction_manager.dart` | `tomLog`, for the coordinator's own account of a veto, a participant that threw, and a partial commit |
| [little_things](little_things.md) | module | every file | `TomServerException` (base of `TomTransactionException`) |

- The datasources module — `TomDataSource` is the concrete
  `TomTransactionParticipant`.
- The endpoints module — drives `startTransaction` / `commitTransaction` /
  `rollbackTransaction` for `@TomTransactional` endpoints, and guards that such
  an endpoint runs inside a scope.
- The server module — the authentication middleware opens a transaction scope
  per request.

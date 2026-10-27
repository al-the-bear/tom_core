# Transactions Module

A lightweight transaction coordinator. A `TomTransaction` groups one or more
`TomTransactionParticipant`s (data sources) so they commit or roll back together,
and `TomTransactionManager` provides ambient access to the current transaction so
participants and the request pipeline can join or conclude it without passing a
handle around.

Work that spans services, whose data no one transaction can reach, is a
**saga**: a `TomSagaOrchestrator` runs each step as a local transaction and,
when a step fails for good, runs the compensations of the steps already done,
last first — see [Sagas](#sagas).

A process that dies between the two phases of a two-phase commit leaves its
branches prepared. The coordinator records its decision before the commit
phase, and `TomTransactionRecovery` commits the branches a recorded decision
names and rolls back the rest — see
[Recovering Prepared Branches](#recovering-prepared-branches).

## Table of Contents

- [Overview](#overview)
- [The Participant Contract](#the-participant-contract)
- [The Transaction Lifecycle](#the-transaction-lifecycle)
  - [Failure keys](#failure-keys)
  - [The Result](#the-result)
- [Ambient Access](#ambient-access)
- [Transaction Scopes](#transaction-scopes)
- [How the Pipeline Uses It](#how-the-pipeline-uses-it)
- [Tracing](#tracing)
- [Read-Only](#read-only)
- [Sequential by design](#sequential-by-design)
- [Concurrency Model](#concurrency-model)
- [Recovering Prepared Branches](#recovering-prepared-branches)
  - [The decision record](#the-decision-record)
  - [The decision log](#the-decision-log)
  - [The recovery](#the-recovery)
  - [Configuration and start](#configuration-and-start)
  - [The decision table](#the-decision-table)
  - [Recovery failure keys](#recovery-failure-keys)
- [Sagas](#sagas)
  - [A saga or a distributed transaction](#a-saga-or-a-distributed-transaction)
  - [Declaring a saga](#declaring-a-saga)
  - [Beginning a saga](#beginning-a-saga)
  - [Failure and compensation](#failure-and-compensation)
  - [One transition, one local transaction](#one-transition-one-local-transaction)
  - [Other data sources and other services](#other-data-sources-and-other-services)
  - [Sending a message from a step](#sending-a-message-from-a-step)
  - [Resumption and the sweep](#resumption-and-the-sweep)
  - [Sagas per tenant](#sagas-per-tenant)
  - [The saga store and its table](#the-saga-store-and-its-table)
  - [Saga failure keys](#saga-failure-keys)
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
| `TomTransactionResult` | class | What a conclusion did, and to whom |
| `TomTransactionOutcome` | enum | What became of the work: committed, partially committed, rolled back, rolled back with failures |
| `TomTransactionManager` | abstract class | Zone-scoped ambient access to the current transaction, and `runInTransaction` to drive one. Statics only |
| `TomTransactionException` | class | Raised on an invalid transaction operation |

The recovery of prepared branches a dead process left behind:

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomPreparedBranchHolder` | abstract interface class | A participant holding a two-phase branch: answers the id of the branch it prepared for a transaction, which the coordinator records |
| `TomTransactionDecisionLog` | abstract interface class | The coordinator's durable record of commit decisions: written before the commit phase, forgotten once every branch committed, read by a recovery |
| `TomMemoryDecisionLog` | class | Decisions in memory, for tests; it does not survive the process it protects |
| `TomSqlDecisionLog` | class | Decisions in the `tom_transaction_decision` table of a one-phase SQL data source, resolved by name on every call |
| `TomDecisionRow` | class | One row of the decision table, as `TomSqlDecisionLog` reads it |
| `TomTwoPhaseRecoverable` | abstract interface class | A data source whose prepared branches a recovery can list, recognise, date, commit and roll back |
| `TomTransactionRecovery` | abstract final class | The recovery: commits the prepared branches a recorded decision names, rolls back the rest, forgets resolved decisions; and the `transactions` configuration. Statics only |
| `TomRecoveryReport` | class | What one recovery did: the branches committed, rolled back, too young and failed, and the decisions forgotten |
| `TomTransactionRecoveryException` | class | Raised when recovery is misconfigured or its log's data source is not registered |
| `defaultDecisionTable` | const String | `'tom_transaction_decision'` — the decision table's default name |
| `decisionTable` / `decisionTableDdl` | function | The decision table's one declaration, and the DDL derived from it |

The sagas — work across services, undone by compensation rather than rolled
back:

| Symbol | Kind | Purpose |
| ------ | ---- | ------- |
| `TomSagaOrchestrator` | class | Registers sagas, begins them, runs every step and compensation as a job run of its own inline scheduler, and resumes unfinished sagas |
| `TomSaga` | class | A saga's declaration: its name, its steps in order, how a step and a compensation are retried, and how long one attempt may take |
| `TomSagaStep` | class | One step: its action and the compensation that undoes it, if any |
| `TomSagaWork` | typedef | The signature of an action or a compensation: `FutureOr<void> Function(TomSagaContext)` |
| `TomSagaContext` | class | What an action or a compensation is given: the saga, the step, the attempt, why the saga compensates, and the saga's data |
| `TomSagaStatus` | enum | `running`, `compensating`, `completed`, `compensated`, `failed` |
| `TomSagaState` | class | The persisted progress of one saga: status, cursor, version, data, error, the window instant of its current run |
| `TomSagaStore` | abstract class | Where saga states are kept, in the tenant in context |
| `TomMemorySagaStore` | class | Saga states in memory, for tests and for a process that may lose its sagas on restart |
| `TomSqlSagaStore` | class | Saga states in the `tom_saga` table of a SQL data source, resolved by name on every call |
| `TomSagaRow` | class | One row of the saga table, as `TomSqlSagaStore` reads it |
| `TomSagaException` | class | Raised when a saga cannot be declared, begun or stored |
| `tomSagaJobPrefix` | const String | `'saga'` — the default prefix of the orchestrator's job names |
| `defaultSagaTable` | const String | `'tom_saga'` — the saga table's default name |
| `sagaTable` / `sagaTableDdl` | function | The saga table's one declaration, and the DDL derived from it |

## The Participant Contract

A participant is keyed by a stable id and exposes five lifecycle hooks:

```dart
abstract class TomTransactionParticipant {
  String getParticipantId();
  Future<bool> startTransaction(TomTransaction transaction); // on enlistment
  Future<bool> prepare(TomTransaction transaction);  // phase one; false vetoes
  Future<bool> commit(TomTransaction transaction);   // phase two; the promise kept
  Future<bool> rollback(TomTransaction transaction); // undo; false = it did not
  Future<bool> endTransaction(TomTransaction transaction); // release, after either
}
```

Every hook is handed the transaction it concerns, the same one
`startTransaction` received. A participant serving several transactions at
once needs that to know which of them a call concludes: a SQL data source
(`TomSqlDatasource`, the base of the MariaDB and PostgreSQL drivers) holds a
connection per transaction, and `commit(transaction)` is what tells it
which connection to issue `COMMIT` on.

`TomDataSource` implements this contract, and a SQL data source enlists
itself **at the point of use**: the first statement it runs while a transaction
is running — `executeCommand`, `executeQuery`, a prepared statement's
`execute` or `run` — calls `registerParticipant` first. No call site asks for it, and
none can be forgotten. That is what gives `@TomTransactional` its meaning: the
endpoint pipeline opens and concludes the transaction, but it cannot know which
data sources the endpoint will touch, and the data source is the one place that
does. A data source whose `startTransaction` fails fails the statement that
triggered the enlistment — a statement run outside the transaction it was meant
to join is exactly the defect enlistment exists to prevent.

A driver of your own honours the same contract: enlist before issuing a
statement inside a running transaction.

**This is two-phase commit.** `prepare` runs on every participant before
`commit` runs on any of them, so a veto arrives while nothing is durable and
aborting costs nothing: the coordinator rolls everyone back and no participant
has to undo committed work. That is the whole reason for the phase, and it is
what makes a transaction spanning two resources atomic.

Two things follow for anyone implementing a participant. **Everything that can
fail belongs in `prepare`** — it is the last point at which failing is free,
and it is the only place a refusal is a veto. And `commit` is a promise being
kept rather than a decision: a `false` there is not acted on as a refusal,
because peers may already be durable.

The residue is the outcome two phases cannot rule out. A participant that
promises and then fails in `commit` leaves the transaction **partially
committed** — the coordinator logs it at error level naming the participants
that failed, commits the rest anyway, and rolls nobody back, because rolling
back a peer whose commit succeeded would discard work the transaction decided to
keep. No coordinator can repair that; the repair is at the named resources.

A participant with nothing to prepare returns `true` and does its work in
`commit`. The one-phase SQL drivers are that participant — `MariaDbDatasource`
(`"mariadb"`) and `PostgresDatasource` (`"postgresql"`): a plain
`START TRANSACTION` / `BEGIN` … `COMMIT` has no statement that makes a commit
certain without performing it — so enlisting one beside a two-phase data source
weakens the guarantee to "atomic unless the one-phase participant's commit
fails". Use a two-phase data source for every resource in a transaction that
has to be atomic across them:

| `type` | Data source | `prepare` | `commit` | `rollback` |
| ------ | ----------- | --------- | -------- | ---------- |
| `mariadb_xa` | `MariaDbXADatasource` | `XA END` + `XA PREPARE` | `XA COMMIT` | `XA END` (if still active) + `XA ROLLBACK` |
| `postgresql_xa` | `PostgresXADatasource` | `PREPARE TRANSACTION '<id>'` | `COMMIT PREPARED '<id>'` | `ROLLBACK` while open, `ROLLBACK PREPARED '<id>'` once prepared |

A prepared branch is one the server has undertaken to be able to commit — a
PostgreSQL prepared transaction survives a server restart. PostgreSQL allows
none until `max_prepared_transactions` is raised above its default of `0`; with
`0`, every `PREPARE TRANSACTION` fails, which vetoes every transaction a
`postgresql_xa` data source joins. See
[datasources.md](datasources.md#transactions) for how the drivers name and
track a branch. A branch a dead process left prepared is resolved by a
recovery — see [Recovering Prepared Branches](#recovering-prepared-branches).

## The Transaction Lifecycle

A `TomTransaction` is created only through `TomTransactionManager.startTransaction`
(its constructor is private). Participants enlist with `registerParticipant`,
which calls their `startTransaction(transaction)` exactly once — registering the *same
participant* again is a no-op, so callers never have to track membership.
Enlisting after the transaction has concluded throws `TomTransactionException`.

**An id belongs to one object.** `getParticipantId()` names a *resource* rather
than an object — `MariaDbDatasource` answers
`"MariaDb-<database>@<host>:@<port>"`, `PostgresDatasource`
`"Postgres-<database>@<host>:@<port>"` — so two instances configured for one
database share an id by construction. Registering the second is not a
re-registration and is refused with `…duplicate_id`, because the two are two
data sources, each with its own connection and transaction, and only one of them
can be the transaction's. Collapsing the second to the first is the one failure here that
says nothing at all: the caller's `await` completes, the resource is never
started, prepared, committed, rolled back or ended, and the work issued against
it is neither committed with the transaction nor rolled back with it — the first
sign being data that should have been undone and was not. A participant that
needs an enlistment of its own returns an id nothing else answers.

**Enlistment is all or nothing.** A participant is recorded only after its
`startTransaction` returns `true`. One that returns `false` or throws is not
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
| `transaction_manager.register_participant.start_failed` | The participant's `startTransaction` returned `false`. `parameters['participant']` names it; it is not enlisted. |
| `transaction_manager.register_participant.start_threw` | The participant's `startTransaction` threw. `parameters['participant']` names it and `rootException` carries what it raised; it is not enlisted. |

The work is concluded one of two ways:

- **`commitTransaction()`** — marks the transaction not-running, then runs the
  two phases in registration order: `prepare` on every participant, and only
  if all of them answered `true`, `commit` on every participant. A participant
  that vetoes — or throws — during prepare turns the whole thing into a
  `rollbackTransaction()`. Between the phases, when a decision log is
  installed, the decision is recorded — see
  [The decision record](#the-decision-record). A `commit` that fails after a
  successful prepare does **not** roll back: the remaining participants are
  committed anyway and the partial commit is logged by name. Either way `endTransaction` is called on every
  participant and the current transaction is cleared.
- **`rollbackTransaction()`** — marks not-running, calls `rollback` then
  `endTransaction` on every participant, and clears the current transaction.

Both return a **`TomTransactionResult`** rather than a boolean — see
[The Result](#the-result).

"Every participant" is unconditional on both paths: a participant whose
`endTransaction` returns `false` does not stop the participants behind it from
being ended, so when implementing one you can count on your release running even
when a peer's has already failed. Nothing calls back afterwards to release what a
skipped participant still holds — the transaction is over — which for a data
source would mean a connection that never returns to the pool.

### The Result

```dart
final result = await txn.commitTransaction();
result.outcome;       // TomTransactionOutcome
result.failed;        // the participants that did not do what they said
result.notReleased;   // the participants that did not release
result.isCommitted;   // outcome == committed
result.isClean;       // failed.isEmpty && notReleased.isEmpty
```

| Outcome | Meaning |
| ------- | ------- |
| `committed` | Every participant committed. The work is durable. |
| `partiallyCommitted` | Every participant promised in `prepare` and at least one then failed to commit. Some of the work is durable and some is not, and no coordinator can repair that. |
| `rolledBack` | The transaction was rolled back — a veto, or an explicit `rollbackTransaction()` — and every participant undid its work. Nothing is durable and nothing is outstanding. |
| `rolledBackWithFailures` | Rolled back, and at least one participant could not undo its work. **The outcome that requires a human**: the work was neither committed nor undone. |

A boolean could not say which of the four it was, and it merged them further
with a fifth, unrelated fact: whether every participant released its
per-transaction resources. A caller reading `false` could not tell "your work is
gone" from "your work is durable and a connection leaked" — and those call for
opposite responses, since the second must not be retried. `notReleased` is
therefore a separate list, and `outcome` describes the *work* alone.

`rollback` returning `bool` is what makes `rolledBackWithFailures` reachable.
While it returned `void`, the coordinator never learned that an undo had failed,
and the value it returned was built only from the subsequent `endTransaction`
calls — so a rollback in which every participant failed to undo its work and
every participant released cleanly reported success.

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

## Tracing

With a tracer installed (`TomTracing`; a server installs one when `tracing` is
on, see [tracing.md](tracing.md)) a `TomTransaction` opened inside traced work —
a request, a job run, another span — is a span named `transaction`, started
with the transaction and ended with its conclusion. It is
`TomTransaction.span`: `null` with tracing off, and `null` for a transaction
opened outside any trace, which the span is started `childOnly` to leave
unrecorded.

| Attribute | Value |
| --------- | ----- |
| `tom.transaction.id` | `TomTransaction.id` |
| `tom.transaction.read_only` | `TomTransaction.isReadOnly` |
| `tom.transaction.outcome` | The conclusion's `TomTransactionOutcome`: `committed`, `partiallyCommitted`, `rolledBack`, `rolledBackWithFailures` |
| `tom.transaction.participants` | How many participants were enlisted |

`TomTransaction.runInSpan(body)` runs `body` inside the span, so the spans it
opens — the statements of the enlisted data sources — are the transaction's
children. `TomTransactionManager.runInTransaction` runs its body that way, and
so does the endpoint pipeline for a `@TomTransactional` endpoint; a transaction
driven by hand with `startTransaction` runs its work in the span only through
`runInSpan`. The conclusion itself — prepare, commit or roll back — runs inside
the span too.

An outcome that left work outstanding — `partiallyCommitted` or
`rolledBackWithFailures` — marks the span failed; a conclusion that throws
records the error. A commit that concludes by rolling back ends the span once,
with the rollback's outcome.
<!-- pinned: test/tracing_test.dart › is a span around its work, ending with its outcome -->

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
| `PostgresDatasource` / `PostgresXADatasource` | Open `BEGIN READ ONLY`, so the server refuses every write until the transaction ends (SQLSTATE `25006`, `read_only_sql_transaction`). The two-phase variant honours it too: its branch begins with the same `BEGIN`. |
| Anything else | Whatever it chooses; the flag is an argument, not an instruction. |

The transaction is **handed over, not looked up**. A participant could in
principle read `TomTransactionManager.getCurrentTransaction()` from inside the
hook the coordinator just called, and it would be wrong in the case the scoping
exists for: the answer comes from whatever zone the call is running in, which
need not be the zone the transaction was opened in.

## Sequential by design

Both conclusions are `for` loops with an `await` in the body, and the phases
differ in what that costs:

| Phase | What one participant does | Sequential cost |
| ----- | ------------------------- | --------------- |
| prepare | `XA END` then `XA PREPARE` for a MariaDB XA source, as two calls; `PREPARE TRANSACTION` for a PostgreSQL two-phase one; nothing for a one-phase one | two round trips per MariaDB XA participant, one per PostgreSQL one |
| commit / rollback | `COMMIT` / `ROLLBACK`, or the two-phase forms | a round trip per participant |
| end | hands the connection back to the pool — issues no statement, unless the connection has a forgotten prepared statement to deallocate or is due to be retired | microseconds, measured below |

So a transaction spanning *n* resources pays *n* sequential round trips on the
deciding phases, at the point in a request where the client is waiting and the
connections are still held. That cost is real and is not an oversight.

**The order is the contract.** `commitTransaction` prepares and commits "in
registration order", and a veto depends on it: which participants have already
been reached when one arrives is knowable only because they were reached one at
a time. Driven with `Future.wait`, "the participants that had already been
asked" stops being a knowable set, and the rollback a veto triggers has to undo
an arbitrary subset.

**And the latency is the wrong thing to optimise first.** A transaction spanning
enough resources for the sum to matter is a design problem before it is a
performance one — the framework's own answer to "this must be atomic across two
databases" is a two-phase data source (`MariaDbXADatasource`,
`PostgresXADatasource`), not more of them. Nobody has reported this
latency; weakening a guarantee two suites enforce, to buy an unmeasured
improvement, is the wrong trade.

**The end phase is sequential for a different reason: it is free.** Releasing a
connection is ordered by nothing, so the order argument does not reach it; what
keeps it a loop is that there is nothing to win. `tool/bench_transaction_end_phase.dart`
drives participants whose release completes a completer and does no I/O — the
cost of a pooled data source's hand-back when it neither deallocates nor retires
anything — and on
2026-10-07 it measured the whole sequential end phase at 0.01–0.04 µs for one
to four participants and about 2 µs for sixteen, with `Future.wait` *slower* at
every size — it allocates a list and a future per participant to save awaits
that cost less. A whole committed transaction through the coordinator, with no
I/O, took 1.7–11.6 µs over the same range; one `COMMIT` on a database is a
network round trip. A participant whose release is itself a round trip would
change the answer, and the benchmark is the place to show it before the loop
changes.

The end phase is still the one most likely to be quietly parallelised, because
nothing about its *meaning* forbids it. `test/transactions_test.dart` holds the group
`the drives are sequential, not merely ordered`, which drives participants that
suspend inside every hook and fails if any two are ever inside one phase at
once. Ordering tests alone cannot see this: a fake that completes without
yielding records the same order under `Future.wait` as under a loop.

## Concurrency Model

The current transaction is **per flow of work, not per isolate**. Two requests
interleaving in one isolate hold two independent current transactions: neither
can enlist in, commit, or roll back the other's work, and an `await` inside a
transactional block cannot let a second request conclude the first one's
transaction.

Concurrent transactions do not wait for each other on a shared data source.
A SQL data source gives each transaction it is enlisted in a connection of
its own from its pool, pinned from the transaction's first statement on it to
`endTransaction`, so two requests' transactions on one database run side by side
and one slow transaction stalls nobody else. A transaction waits only when every
pooled connection is lent — see
[The Connection Pool](datasources.md#the-connection-pool).

A transaction may conclude in a different zone from the one that opened it (after
an `await`, or from a callback scheduled elsewhere), so each `TomTransaction`
holds a reference to the scope it is current in and clears *that* scope —
identity-guarded, so a concluded transaction can never wipe a successor, and in
a `finally`, so it clears it whatever happens on the way.

## Recovering Prepared Branches

A process that dies between the two phases leaves its two-phase branches
**prepared**: durable, holding their locks, and resolved by nobody — an XA
branch of `MariaDbXADatasource` stays in `XA RECOVER`, a prepared transaction
of `PostgresXADatasource` in `pg_prepared_xacts`, until something commits or
rolls it back. Whether that something should commit or roll back depends on
one fact only the dead process knew: whether it had decided to commit. So the
coordinator writes that decision down before it acts on it, and a recovery
reads it back.

```dart
TomTransactionManager.decisionLog = TomSqlDecisionLog('main');

// later — at start, or whenever an operator asks
final report = await TomTransactionRecovery.recover();
report.committed;   // branches whose transaction had decided to commit
report.rolledBack;  // branches no decision was recorded for
```

### The decision record

Every `TomTransaction` has an `id`, `tx_<process tag>_<counter>`: the counter
makes it unique in the process, and the process tag — eight random hex digits
drawn once per process — makes it unique across the processes that share a
decision log.

When every participant has prepared, and before the first `commit`, the
coordinator collects the prepared branches of the participants that hold one —
a participant implementing `TomPreparedBranchHolder` answers
`preparedBranchOf(transaction)`; `MariaDbXADatasource` and
`PostgresXADatasource` do — and records them under the transaction's id with
`TomTransactionManager.decisionLog.recordCommit(id, branches)`.

| When | What the coordinator does with the record |
| ---- | ----------------------------------------- |
| No `decisionLog` is installed, or no participant holds a prepared branch | Records nothing. A transaction of one-phase participants has nothing a recovery could resolve. |
| The record is written | Commits every participant. |
| The record cannot be written | **The decision is not taken**: the transaction rolls back, and the failure is logged at error level. A branch committed without a record would be one a recovery could only roll back while its peers stay committed. |
| Every participant committed | Forgets the record (`forget(id)`). A failure to forget is logged as a warning and changes nothing: the work is committed, and a recovery finds nothing prepared and forgets the record then. |
| A participant broke its promise | Keeps the record. The transaction is partially committed, and a recovery commits the branches still prepared — what the transaction decided. |

The record is written **outside the transaction's scope**, in a scope of its
own (`runInTransactionScope`). Inside it, a decision log over a data source the
transaction had enlisted would write the record on that participant's
connection, as part of the very transaction it is about — and the record would
become durable only when that participant committed, which is exactly the point
it exists to precede.

### The decision log

`TomTransactionDecisionLog` is the contract: `recordCommit(transactionId,
branches)`, `forget(transactionId)` and `decisions()`, every recorded decision
as transaction id to its branches.

| Log | Keeps decisions in |
| --- | ------------------ |
| `TomSqlDecisionLog(datasourceName, {table, createSchema})` | The `tom_transaction_decision` table of the data source registered under that name, resolved per call; a name not registered raises `transactions.recovery.no_datasource`. A decision is one multi-row `INSERT`, so it is recorded whole or not at all — a partial record would have a recovery commit some branches and roll back the rest |
| `TomMemoryDecisionLog` | Memory — tests, and the example. It does not survive the process it protects, so it protects nothing in a deployment |

**Where the log lives decides whether it works.** It has to be a **one-phase**
data source (`mariadb`, `postgresql`): the record has to be durable on its own
before the commit phase, and a two-phase data source would hold it in a branch
of its own, prepared and in doubt like the ones it describes. It may be a
one-phase data source over the same database as one of the two-phase ones.

**Every process whose two-phase transactions reach a database records into the
same log**, and a recovery reads that log. A branch is judged by the decisions
the recovery can see, so a decided branch recorded in a log the recovery does
not read looks undecided and is rolled back.

`decisions()` reads the whole table. Records live only between a transaction's
prepare and its last commit, so the table holds the transactions in that window
plus those left by a crash or a broken commit — not a history.

### The recovery

`TomTransactionRecovery.recover({sources, log, now})` resolves what is left. It
reads the decisions of `log` (the installed `TomTransactionManager.decisionLog`
when not given), then asks every source — `TomTwoPhaseRecoverable` data sources;
when `sources` is not given, every operational registered data source that is
one — for its prepared branches, and for each:

1. **A branch the source does not own is passed over.** `ownsBranch` reads the
   branch id: a branch the framework opens names its data source in its head
   (`<database>@<host>:<port>`, see
   [datasources.md](datasources.md#recovering-prepared-branches)), and only the
   branches naming this source's database are its. MariaDB's `XA RECOVER` is
   server-wide, so this is what keeps a recovery of one database from resolving
   another's branches — or a branch another program prepared.
2. **A branch younger than `TomTransactionRecovery.minimumAge`** (one minute by
   default) **is left alone** and reported as `tooYoung`. Its age is read from
   the time its id carries, the moment the branch was opened. A young branch
   may belong to a live process between its two phases — one that has
   prepared and is about to record its decision or to commit — and resolving it
   under that process would turn its commit into a failure. The minimum age has
   to exceed the longest a two-phase transaction stays open, from its first
   statement through its commit phase.
3. **A branch a recorded decision names is committed**; every other branch is
   **rolled back**. No record means the process died before it decided, and a
   transaction that never decided to commit has to end as if it had rolled
   back.
4. **A decision is forgotten** once none of its branches is still prepared —
   provided every one of its branches belongs to a source this recovery
   scanned, so a decision about a database it was not asked to look at is kept
   for the recovery that is.

The returned `TomRecoveryReport` lists the branch ids `committed`,
`rolledBack` and `tooYoung`, the `failed` ones with their errors, and the
transaction ids `forgotten`; `isClean` is `failed.isEmpty`. Each resolution is
logged at info level, each failure at error level.

**A failure is reported, not raised.** A branch whose commit or rollback fails
is recorded in `failed`, its decision is kept, and the rest are still resolved:
one stuck branch must not hold up the others. One cause is a second node
recovering at the same time — both list the branch, one resolves it, and the
other's statement finds it gone. Concurrent recoveries are therefore safe: they
agree on what each branch needs, because they read the same log, and the loser
of a race only reports a failure. The next recovery forgets what the race left
recorded.

**Without a decision log** a recovery can only roll back: every owned branch
older than the minimum age is rolled back, which is the right end for a
transaction that died before it decided and the wrong one for one that died
after. That is why the log is installed wherever two-phase data sources are.

### Configuration and start

The `transactions` key of the configuration resources
(`TomTransactionRecovery.configurationKey`) installs the decision log and asks
for a recovery at start. `TomServer.start` applies it through
`TomServer.recoverTransactions` right after `privacy`, before the deployment's
own login and before the socket is bound:

```yaml
# assets/config-resources_default.yaml
transactions:
  decisionLog: main            # a one-phase data source
  decisionTable: tom_transaction_decision
  createSchema: true
  recoverOnStart: true
  recoveryMinimumAgeSeconds: 60
```

| Key | Type | Default | What it decides |
| --- | ---- | ------- | --------------- |
| `decisionLog` | `String` | none | The registered one-phase data source decisions are recorded in. `TomTransactionRecovery.configure` installs a `TomSqlDecisionLog` over it as `TomTransactionManager.decisionLog`; without it nothing is recorded. |
| `decisionTable` | `String` | `tom_transaction_decision` | The decision table's name. |
| `createSchema` | `bool` | `true` | Whether the log creates the table on first use. Only `false` turns it off. |
| `recoverOnStart` | `bool` | `false` | Whether `start()` runs `recover()` over every registered two-phase data source before the server takes a request. Only `true` turns it on. |
| `recoveryMinimumAgeSeconds` | `int` | `60` | `TomTransactionRecovery.minimumAge`, in whole seconds. |

With `recoverOnStart`, the recovery scans the two-phase data sources
registered when `start()` is called — the application registers them first —
and runs before the server takes a request that could meet the prepared
branches' locks; the report is logged. A restarted node therefore resolves what its
predecessor left — and what any other node left, since the recovery resolves
every old enough branch of its data sources, whoever prepared it. Every node of
a cluster recovering at its start is the intended use: see above for why two
recoveries at once are safe.

A `transactions` value that is not a map, or a `recoveryMinimumAgeSeconds` that
is not a whole number of seconds or is negative, stops the start with a
`TomTransactionRecoveryException` keyed `transactions.recovery.config.invalid`.
Without the key nothing is installed and nothing is recovered.
`recoverTransactions` returns the report, or `null` when no recovery ran; it is
public for a server composed some other way, and takes the configuration
provider to read as an optional argument. `TomTransactionRecovery.reset()`
restores the defaults, for tests.

### The decision table

The table is declared once, by `decisionTable` in `transaction_recovery.dart`,
as every framework table is (see
[Schema Convergence](db_migration.md#schema-convergence)) and listed by
`frameworkOwnedTables`; `TomDecisionRow` is its row as the log reads it.

| Column | Type | Meaning |
| ------ | ---- | ------- |
| `transaction_id` | `VARCHAR(64)` | The `TomTransaction.id` that decided; with `branch_id`, the primary key |
| `branch_id` | `VARCHAR(200)` | One prepared branch it decided to commit — one row per branch |
| `decided_at` | `DATETIME(6)` | When the decision was recorded, UTC |

With `createSchema` (the default) the log creates the table on first use; a
deployment whose database user may not run DDL applies
`example/transactions/migrations/main/tomcore/[2]-create_tom_transaction_decision.sql`
(or its `migrations_postgresql/` twin) to the decision log's data source and
sets `createSchema: false`. `test/framework_schema_test.dart` replays the
migration chain and compares the schema it builds with `decisionTable`, so the
two cannot drift apart.

### Recovery failure keys

Every one is a `TomTransactionRecoveryException`, a `TomServerException`.

| Key | Meaning |
| --- | ------- |
| `transactions.recovery.no_datasource` | The data source a `TomSqlDecisionLog` names is not registered. `parameters['datasource']` names it. Raised where the log is used: by a recovery, which it stops, and inside a commit, which then rolls back. |
| `transactions.recovery.config.invalid` | The `transactions` configuration is not a map, or its `recoveryMinimumAgeSeconds` is not a whole number of seconds or is negative. |

A branch id the drivers would not write is refused before it reaches a
statement, with the data source's own `error.datasource.invalid_branch_id` —
see [datasources.md](datasources.md#recovering-prepared-branches).

## Sagas

An order that reserves stock in one service, charges a card in a second and
books a shipment in a third cannot commit in one transaction: the three own
their data. A **saga** does each step as a local transaction and, when a later
step fails for good, runs the **compensations** of the steps already done, in
reverse order — the stock is released and the charge refunded, so the system
ends where it started, by explicit undo rather than by rollback.

`TomSagaOrchestrator` orchestrates: one coordinator drives each saga, and the
saga's progress is a row in the saga store — which step comes next, the saga's
data, and a version. A saga whose services merely react to each other's events
(choreography) needs nothing from the framework; it is an application using its
message bus.

```dart
final orchestrator = TomSagaOrchestrator(
  store: TomSqlSagaStore('main'),
  jobStore: TomSqlJobStore.named('main'),
)..register(TomSaga(
    name: 'place_order',
    steps: [
      TomSagaStep('reserve', action: reserve, compensation: release),
      TomSagaStep('charge', action: charge, compensation: refund),
      TomSagaStep('ship', action: ship),
    ],
  ));
await orchestrator.start();
final id = await orchestrator.begin('place_order', data: {'order': 42});
```

### A saga or a distributed transaction

Use a distributed transaction — two XA data sources in one `TomTransaction` —
when every resource is a database this process can enlist, and the work must
be atomic: no reader may ever see one half committed. The coordinator holds the
locks of every resource until the commit, so it suits short work over a handful
of databases.

Use a saga when a step is not a database the process can enlist — another
service's API, a payment provider, a carrier — or when the work is long enough
that holding locks across all of it is not acceptable. The price is isolation:
between a step and its compensation the step's effect is visible to everyone,
and a reader may see stock reserved for an order that is then cancelled. A saga
is atomic in the end, not at every moment, and each compensation must be
written to undo a step that others may already have seen.

### Declaring a saga

A `TomSaga` names its steps, in order. Each `TomSagaStep` has an `action` and,
optionally, a `compensation` — a step with nothing to undo (a read, a
notification, usually the last step) leaves it out. Both are `TomSagaWork`,
`FutureOr<void> Function(TomSagaContext context)`.

| Argument | Default | Meaning |
| -------- | ------- | ------- |
| `name` | — | 1 to 120 characters; the saga's state records it and its jobs are named after it |
| `steps` | — | At least one, with distinct names |
| `retryPolicy` | `TomRetryPolicy()` — three attempts | How a failing step is retried before the saga compensates |
| `compensationRetryPolicy` | ten attempts, 30 s to 30 min apart | How a failing compensation is retried before the saga fails |
| `timeout` | two minutes | How long one attempt of a step or a compensation may take |

A declaration that breaks those rules is refused with
`transactions.saga.invalid_definition`.

`register` makes a saga known to the orchestrator: it can then be begun, and its
runs are executed. **Every node that may run a saga registers it, under the same
name** — the scheduler takes no run of a job it has not registered. A name
registered twice is refused with `transactions.saga.already_registered`.

The context an action or a compensation is given carries `sagaId`, `sagaName`,
`stepName`, `attempt` (1-based), `isCompensating`, `failure` (while
compensating: why) and `data`. **`data` is the saga's data, and a step may
change it**: the change is saved with the step, so a later step — and the
step's own compensation — sees what it recorded, a reservation id or a payment
reference. It must stay JSON-encodable. Changes made by an attempt that fails
are not saved; changes made by a compensation are.

### Beginning a saga

`begin(sagaName, data: …, id: …)` stores a new saga for the tenant in context,
queues its first step, and answers its id — the `id` given, or a new UUID. It
returns once the saga is stored and its first step queued; the steps run on the
orchestrator's scheduler, not inside `begin`. Called inside a transaction on the
saga store's data source, the saga begins only if that transaction commits, so
an endpoint that records an order and begins the saga for it does both or
neither.

`find(id)` answers the saga's `TomSagaState` — its `status`, `step` cursor,
`version`, `data` and `error` — or `null`.

| Status | Meaning |
| ------ | ------- |
| `running` | Running its steps; `step` is the next one to run |
| `compensating` | A step failed for good; `step` is the next one to compensate |
| `completed` | Every step ran |
| `compensated` | A step failed for good, and every step before it was compensated |
| `failed` | A compensation failed for good: the saga is left half done, for an operator |

`TomSagaStatus.isFinished` is `true` for the last three.

### Failure and compensation

A step that throws is retried by its saga's `retryPolicy`, each attempt a new
run of the step's job. When its last attempt fails, or it throws a
`TomPermanentFailure`, the saga turns to `compensating`, records why in
`error` (`step '<name>': <error>`) and compensates the steps that completed,
last first; a step without a compensation is passed over. A first step that
fails leaves nothing to compensate, and the saga is `compensated` at once.

A compensation is retried by `compensationRetryPolicy` — generously, because a
compensation that gives up leaves the system half done. One that fails for good
ends the saga `failed`, with the compensation's failure appended to `error`,
and fails its run with a `TomPermanentJobFailure`: the scheduler's alert names
the saga and the step, and what remains is for an operator. The steps before it
stay done.

```text
reserve#1, charge#1, ship#1, ship#2          ship fails on both attempts
undo charge, undo reserve                    compensated, last first
```

### One transition, one local transaction

Every transition of a saga — one step, or one compensation — is one job run,
and its work runs in a transaction (`TomTransactionManager.runInTransaction`)
together with the update that moves the saga on. That update is
`UPDATE … WHERE version = :expected`: it succeeds only for the version the run
was queued for. So:

- a step whose action throws leaves no trace — its work and the saga's move roll
  back together, and the run is retried;
- a step that committed is never run again: a run for an older version finds
  the saga moved on and does nothing, however it came to run twice — a
  redelivery, two nodes, a recovered run;
- a process that dies mid-step rolls the step back, and the run is taken up
  again — by the scheduler's recovery on another node, or by `start` on this
  one.

The run for the next transition is queued after that transaction commits. A
process that dies between the two leaves a saga with no run, which
[Resumption and the sweep](#resumption-and-the-sweep) finds.

The orchestrator owns no retry logic. Like the [message
outbox](messaging.md#delivery-semantics-one-retry-mechanism) it runs an inline
scheduler of its own over a `TomJobStore`, so the retries and their backoff, one
runner per run, the recovery of a run whose node died, and the alerts all come
from the kernel's scheduler. Point it at the job store the outbox and the
application's scheduler use; each takes only the runs of its own jobs. A saga
`place_order` runs its steps as job `saga.place_order` and its compensations as
`saga.place_order.compensation` (`stepJobName`, `compensationJobName`; the
prefix is `jobPrefix`, `tomSagaJobPrefix` by default). The jobs allow overlap —
sagas are independent — and request recovery, which is safe because an
interrupted transition rolled back with its process.

### Other data sources and other services

The guarantee above holds for the work a step does **in the saga store's data
source**. Two other kinds of work are reached from a step, and neither is
covered the same way:

| A step's work in | What happens |
| ---------------- | ------------ |
| The saga store's data source | Commits or rolls back with the transition: exactly once |
| Another data source | Joins the same transaction only when both are two-phase data sources (`MariaDbXADatasource`, `PostgresXADatasource`) — see [the participant contract](#the-participant-contract). Otherwise it commits on its own, and a step that fails after it ran repeats it on the retry |
| Another service | Is part of no local transaction: it runs at least once and must be idempotent — an idempotency key the service honours, or a lookup before the call |

A call to another service that must not happen unless the step commits goes
through the outbox, below.

### Sending a message from a step

A message sent through a `TomMessageOutbox` whose job store is a
`TomSqlJobStore` on the saga store's data source is queued in the step's
transaction: the job store enlists in it on its first statement. The message is
delivered after the step commits, or not at all — a step that fails rolls the
queued message back with the rest of its work. That turns "call the other
service" into "queue a message to it" for every step that must not call twice.

```dart
TomSagaStep(
  'confirm',
  action: (context) => outbox.send(TomMessage.email(
    to: [TomRecipient(context.data['email']! as String)],
    subject: 'Order ${context.data['order']} confirmed',
    text: '…',
  )),
)
```

### Resumption and the sweep

A saga's progress is in its store, so a restart loses nothing.
`resume()` re-queues the run of every unfinished saga whose run is no longer in
the job store — a run lost between a transition's commit and the queueing of
the next one, or one whose attempts ran out — and answers how many it
re-queued. A saga whose run is still queued is left alone, and a saga whose name
is not registered on this node is passed over.

`start()` calls `resume()`, then lets the scheduler run transitions on its tick
(`tickInterval`, fifteen seconds by default) and calls `resume()` again every
`sweepInterval` (five minutes by default); a sweep that fails is logged as a
warning and the next one tries again. `tick()` runs one pass of due transitions
and waits for them to finish, for tests and for a caller that wants a saga moved
on now; while the orchestrator is started, a pass of its own may be under way,
and `tick()` then returns at once. `close()` stops running sagas and closes the
scheduler, releasing its leases; the sagas stay where they are, and the next
`start()` resumes them.

`TomSagaOrchestrator`'s store and job store both default to memory, which is
right for tests and wrong for any deployment: a saga kept in memory is lost by a
restart, which is what a saga exists to survive. Give it a `TomSqlSagaStore`
and a durable job store.

### Sagas per tenant

A saga belongs to the tenant `begin` was called in: its state records the
tenant, its runs carry it, and the scheduler runs every step and compensation
inside it. `find` and the store see only the tenant in context's sagas.
`TomSqlSagaStore` resolves its data source by name on every call, so under
tenancy a tenant's sagas live in the tenant's data source, beside the data its
steps change — which is what lets a step's work and its transition commit
together.

`resume()` looks in the context's tenant and, when a `TomTenancy` is installed,
in every tenant's, so one sweep finds every tenant's unfinished sagas. See
[tenancy.md](tenancy.md#what-stays-deployment-wide).

### The saga store and its table

`TomSagaStore` is the contract: `prepare` (create the table for the data source
this context resolves), `insert` (`false` when the id is taken), `load`,
`update(state, expectedVersion:)` (`false` when the stored version differs),
`unfinished` and `purgeFinishedBefore(before)`. Every operation works in the
tenant in context.

| Store | Keeps sagas in |
| ----- | -------------- |
| `TomMemorySagaStore` | Memory — tests, and a process that may lose its sagas |
| `TomSqlSagaStore(datasourceName, {table, createSchema})` | The `tom_saga` table of the data source registered under that name, resolved per call; a name not registered raises `transactions.saga.no_datasource` |
| `TomSqlSagaStore.over(datasource, {table, createSchema})` | The table of that data source itself, resolved once |

The table is declared once, by `sagaTable` in `saga_sql.dart`, as every
framework table is (see
[Schema Convergence](db_migration.md#schema-convergence)):

| Column | Type | Meaning |
| ------ | ---- | ------- |
| `tenant` | `VARCHAR(32)` | The tenant, `''` outside tenancy; with `saga_id`, the primary key |
| `saga_id` | `VARCHAR(191)` | The saga's id |
| `saga_name` | `VARCHAR(120)` | Which `TomSaga` it runs |
| `status` | `VARCHAR(16)` | The `TomSagaStatus` name |
| `step` | `INT` | The cursor: the next step to run, or to compensate |
| `version` | `INT` | Grows by one with every transition; the optimistic lock |
| `data` | `LONGTEXT` | The saga's data, as JSON |
| `error` | `TEXT NULL` | Why it compensates or failed |
| `run_window` | `DATETIME(6)` | The window instant of the job run carrying the current version — how a resumption tells whether that run still exists |
| `created_at`, `updated_at` | `DATETIME(6)` | When the saga began, and last moved |

`(status, updated_at)` is indexed for resumption and the purge. With
`createSchema` (the default) the store creates the table on first use in each
data source; a deployment whose database user may not run DDL applies
`example/transactions/migrations/main/tomcore/[1]-create_tom_saga.sql` (or its
`migrations_postgresql/` twin) and passes `createSchema: false`. Under tenancy
with a database or schema per tenant the migration belongs in each tenant's
tree.

Finished sagas stay in the table: `purgeFinishedBefore(before)` removes the
tenant in context's sagas that finished before `before`, and nothing calls it on
a deployment's behalf.

### Saga failure keys

Every one is a `TomSagaException`, a `TomServerException` raised to the caller
rather than to a client (`clientThrow: false`).

| Key | Meaning |
| --- | ------- |
| `transactions.saga.invalid_definition` | A saga's name is empty or longer than 120 characters, it has no steps, or two steps share a name. |
| `transactions.saga.already_registered` | A saga of that name is registered with the orchestrator already. |
| `transactions.saga.unknown` | `begin` names a saga that is not registered. |
| `transactions.saga.invalid_id` | The saga id given to `begin` is empty or longer than 128 characters. |
| `transactions.saga.id_taken` | A saga with that id exists already. |
| `transactions.saga.data_not_json` | The saga's data is not JSON-encodable. |
| `transactions.saga.closed` | The orchestrator has been closed. |
| `transactions.saga.no_datasource` | The data source a `TomSqlSagaStore` names is not registered. |
| `transactions.saga.superseded` | A transition found its saga moved on since its run was queued — another node, or a redelivered run, got there first. Raised inside the transition's transaction to roll it back and caught by the orchestrator; it never reaches a caller. |

A step or a compensation that fails is not a `TomSagaException`: it is the
step's own error, retried and then answered by compensation, and it reaches an
operator through the saga's `error` and the scheduler's alert.

## Not Yet Implemented

- **A participant that breaks its promise leaves the transaction partially
  committed.** A `commit` that fails after a successful `prepare` is not a
  veto and cannot be answered with a rollback — peers are already durable. The
  coordinator logs the failure at error level naming every participant that
  broke its promise and commits the rest, and repair is at those resources. Two
  phases make a veto free; they do not make a commit infallible.
  <!-- pinned: test/transactions_test.dart › and the partial commit is reported by name -->
- **`isReadOnly` is not enforced on an XA branch.** `MariaDbXADatasource` gets
  the flag like every participant and cannot act on it: `XA START` has no
  `READ ONLY` form in MariaDB or MySQL, so writes on that connection are not
  prevented. It warns rather than failing the start, because refusing would take
  the distributed transaction with it. See [Read-Only](#read-only).
  <!-- pinned: test/datasources_test.dart › the XA driver says it cannot honour it, and does not pretend -->
- **A recovery runs when it is asked.** `recoverOnStart` runs one at a
  server's start and `TomTransactionRecovery.recover()` runs one on demand;
  nothing runs it periodically. A branch left prepared while every node keeps
  running waits for the next start or call, holding its locks.
  <!-- unpinned: absence — no periodic recovery exists -->
- **A branch's age is counted from its start, on the clock of the node that
  opened it.** The id carries the time the branch was opened, not the time it
  was prepared, and a recovery compares it with its own clock. So
  `TomTransactionRecovery.minimumAge` has to exceed the longest a two-phase
  transaction stays open, from its first statement through its commit, plus
  the clock skew between nodes; a recovery on another node can otherwise
  resolve a live transaction's prepared branch under it.
  <!-- pinned: test/transaction_recovery_test.dart › a branch id names its data source and when it was opened -->
- **A one-phase participant has nothing to recover.** Beside two-phase ones it
  commits in the commit phase like the rest, and a process that dies before
  its turn loses its work with its connection, while a recovery commits the
  two-phase branches the decision names. Use two-phase data sources for every
  resource that has to be atomic with the others.
  <!-- unpinned: absence — a one-phase transaction leaves no prepared branch -->
- **A conclusion has no deadline.** Participants are awaited with no timeout, so
  one that blocks blocks the transaction and the request behind it indefinitely.
  Timeouts belong to the participant, which is the layer that knows what its
  resource's round trip should cost. (That participants are driven *one at a
  time* is not part of this — see [Sequential by design](#sequential-by-design).)
  <!-- unpinned: decision — timeouts belong to the participant -->
- **Nothing purges finished sagas.** A completed, compensated or failed saga
  stays in `tom_saga`; `TomSagaStore.purgeFinishedBefore` removes those that
  finished before a cutoff, and how long to keep them is a deployment's decision,
  so nothing calls it on its behalf.
  <!-- unpinned: absence — no automatic purge exists -->
- **A saga's definition must not change while sagas of it are in flight.** A
  saga's state records its name and the index of its next step, not the steps
  themselves; a deployment that reorders, inserts or removes steps while sagas
  are running moves their cursor onto other steps. Give the changed saga a new
  name, and let the old one finish under the old definition.
  <!-- unpinned: decision — versioning saga definitions is the deployment's -->
- **Resumption across tenants needs the `TomTenancy` installed.** `resume()`
  looks in the context's tenant and in the tenants of `TomTenancy.current`; an
  orchestrator started before the tenancy is installed, or in a process that
  never installs it, sweeps only the context's tenant — the sagas of the others
  are resumed by the next sweep after the tenancy is installed, or not at all.
  <!-- pinned: test/saga_test.dart › resume looks into every tenant of the installed tenancy -->
- **A compensation that fails for good is left to an operator.** The saga ends
  `failed`, half done, and the scheduler's alert names it; nothing retries it
  later or escalates further.
  <!-- pinned: test/saga_test.dart › a compensation that fails for good ends the saga failed and alerts -->

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

`test/transaction_recovery_test.dart` covers recovery without a database: the
decision recorded before the first commit and forgotten after the last, a
decision log that fails rolling the transaction back, a broken commit keeping
the record, transaction ids, a recovery committing decided branches, rolling
back the rest, forgetting what is resolved, leaving a young branch alone and
reporting a failure while resolving the rest, branch-id ownership and age —
including a truncated head — a branch id the drivers never write refused, and
the `transactions` configuration with both `transactions.recovery.*` keys.
`test/transaction_recovery_db_test.dart` runs the process death itself against
MariaDB and PostgreSQL: a separate process (`test/fixtures/xa_recovery_probe.dart`)
writes through two two-phase data sources over two databases in one
transaction and exits mid-commit. Dying after the decision is recorded, the
recovery commits both branches and forgets the record; dying before it, the
recovery rolls both back; a branch younger than the minimum age is left alone
and then resolved; and a normal commit leaves no record and nothing prepared.
It is tagged `db` and skips without a server, or on PostgreSQL without
prepared transactions.

```bash
dart run example/transactions/transaction_recovery_example.dart
```

`example/transactions/transaction_recovery_example.dart` records decisions in
a `TomMemoryDecisionLog` from two in-memory participants, shows a decision
that cannot be recorded rolling the transaction back, and recovers an
in-memory data source — the decided branch committed, the undecided one rolled
back, another database's branch and a young one left alone.

`test/saga_test.dart` covers the sagas in memory: steps in order, data a step
records seen by the steps after it and by its compensation, compensation last
first after a retried and after a permanently failed step, a step without a
compensation passed over, a failed compensation ending the saga `failed` with
an alert, a run for a version the saga has left doing nothing, a restart mid-saga
and a lost run resumed — in every tenant of the installed tenancy — and every
`transactions.saga.*` key. `test/saga_db_test.dart` runs the flows over
`TomSqlSagaStore` and `TomSqlJobStore` against a live database: each step
committing in its own transaction, a failed step rolled back while the steps
before it are compensated, a restart resumed from the store, the version guard
refusing a stale write, and a message sent through the outbox committing with
its step and rolled back with a failed one. It is tagged `db` and skips without
a server.

```bash
dart run example/transactions/saga_example.dart
```

`example/transactions/saga_example.dart` runs sagas on the memory stores and
checks the order of the steps and compensations, a failed compensation, a saga
resumed by a second orchestrator, and an unknown saga refused.

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
- **`TomTransactionRecovery`** (`transaction_recovery.dart`) — the recovery of
  prepared branches and the `transactions` configuration; with
  **`TomTransactionDecisionLog`** (`TomSqlDecisionLog`, `TomMemoryDecisionLog`)
  where the coordinator records its decisions, **`TomPreparedBranchHolder`**
  by which a participant reports its branch, and **`TomTwoPhaseRecoverable`**
  by which a data source lists and resolves its prepared branches;
  `decisionTable` declares the table.
- **`TomSagaOrchestrator`** (`saga.dart`) — sagas: registration, `begin`,
  every step and compensation as a job run of its own inline scheduler, each a
  local transaction guarded by the saga's version, and resumption.
- **`TomSagaStore`**, **`TomMemorySagaStore`**, **`TomSqlSagaStore`** — where
  saga states are kept; `sagaTable` (`saga_sql.dart`) declares the table.

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `saga.dart`, `transaction_manager.dart`, `transaction_recovery.dart` | `Future`, `FutureOr`, `Timer`, `Zone`, `unawaited` |
| `dart:convert` | dart | `saga.dart` | `jsonEncode` / `jsonDecode`, for a saga's data and its copy |
| `dart:math` | dart | `transaction_manager.dart` | `Random.secure`, the process tag in a transaction's id |
| `tom_core_kernel` | package | `saga.dart`, `transaction_manager.dart`, `transaction_recovery.dart` | `tomLog`, for the coordinator's own account of a veto, a participant that threw, a partial commit and a decision it could not record, and the recovery's account of each branch; and the scheduling a saga runs on — `TomScheduler`, `TomJobStore`, `TomMemoryJobStore`, `TomJobDefinition`, `TomEventSchedule`, `TomInlineJobDispatcher`, `TomRetryPolicy`, `TomPermanentFailure`, `TomPermanentJobFailure`, `TomJobAlertSink`, `TomLeaseLock`, `TomCommand`, `TomClosable` — plus `TomTenantContext`, `tomReflector`, and `TomTracing` / `TomSpan` (the transaction's span) |
| `uuid` | package | `saga.dart` | `UuidV4`, for a saga id when `begin` is given none |
| [datasources](datasources.md) | module | `saga.dart`, `saga_sql.dart`, `transaction_recovery.dart` | `TomFrameworkTable` / `TomFrameworkColumn`, the saga and decision tables' single declarations; `TomDataSource`, `TomDataSourceInfo` and `TomSchemaProvisioning`, to resolve and provision the store's and the log's data source, and to find the registered two-phase data sources a recovery scans; `sqlInstant` / `parseSqlInstant` |
| [little_things](little_things.md) | module | `saga.dart`, `transaction_manager.dart`, `transaction_recovery.dart` | `TomServerException` (base of `TomTransactionException`, `TomSagaException` and `TomTransactionRecoveryException`) |
| [object_persistence](object_persistence.md) | module | `saga.dart`, `transaction_recovery.dart` | `TomDbTable` / `TomDbColumn` on `TomSagaRow` and `TomDecisionRow` |
| [scheduling](scheduling.md) | module | `saga.dart` | `TomEventInstants`, the window instant of each saga run |
| [tenancy](tenancy.md) | module | `saga.dart` | `TomTenancy.current`, whose tenants `resume` looks into |

- The datasources module — `TomDataSource` is the concrete
  `TomTransactionParticipant`; `MariaDbXADatasource` and `PostgresXADatasource`
  are the `TomPreparedBranchHolder`s and `TomTwoPhaseRecoverable`s, through
  `TomSqlTwoPhaseRecovery`.
- The endpoints module — drives `startTransaction` / `commitTransaction` /
  `rollbackTransaction` for `@TomTransactional` endpoints, and guards that such
  an endpoint runs inside a scope.
- The server module — the authentication middleware opens a transaction scope
  per request, and `TomServer.recoverTransactions` applies the `transactions`
  configuration at start.

# transactions

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Commit/rollback coordination across participants (datasources and other
resources). A `TomTransaction` collects `TomTransactionParticipant`s and
concludes them with a **two-phase commit**: `prepare()` on every participant
first, and only if all of them promise does `commit()` run on any of them. A
`false` from `prepare()` is the veto, and it arrives while nothing is durable,
so the transaction aborts by rolling everyone back. The `TomTransactionManager`
binds a transaction to a `@TomTransactional` endpoint call and commits or rolls
it back when the call returns.

Two phases do not make a commit infallible. A participant that promises and then
fails leaves the transaction **partially committed** — its peers are durable and
cannot be rolled back — which the coordinator reports by name and no coordinator
can repair. Nor is a rollback infallible: a participant that cannot undo its
work leaves it **neither committed nor undone**. Both conclusions therefore
return a `TomTransactionResult` naming the `TomTransactionOutcome` and the
participants involved, rather than a boolean that merged the four states with a
fifth — whether every participant released its connection.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomTransactionManager` | Zone-scoped coordinator; `runInTransaction(body)` opens a transaction, commits it on return and rolls it back on a throw. Also `startTransaction([isReadOnly])` returning `(transaction, isNew)`, `getCurrentTransaction()`, `transactional`, plus `runInTransactionScope(body)` / `hasTransactionScope` for isolating one flow of work from another. Binds the transaction to a `@TomTransactional` endpoint call. |
| `TomTransaction` | The running transaction (created via the manager); `registerParticipant` (all or nothing — a participant whose `startTransaction` refuses or throws is not enlisted, and the failure is raised naming it), `commitTransaction()` (prepare-all then commit-all, rolling back on any veto), `rollbackTransaction()`. Both answer a `TomTransactionResult` naming what became of the work and which participants did not do what they said. |
| `TomTransactionParticipant` | Abstract resource that enlists in a transaction (`startTransaction(transaction)`, `prepare`, `commit`, `rollback`, `endTransaction`). `rollback` answers whether the work was undone; `false` is the outcome needing a human. The transaction is handed over on enlistment, which is how `isReadOnly` reaches the resource — `MariaDbDatasource` opens `START TRANSACTION READ ONLY` for one. Datasources implement this; `MariaDbXADatasource` maps `prepare` onto `XA END` + `XA PREPARE` and `commit` onto `XA COMMIT`. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final committed = await TomTransactionManager.runInTransaction((tx) async {
    // A data source enlists itself on its first statement in here; any other
    // resource enlists explicitly:
    // await tx.registerParticipant(myResource);
    return true;
  });
  print(committed); // true  (the body returned, so the transaction committed)
}
```

`runInTransaction` opens the transaction, commits it when the body returns, and
**rolls it back when the body throws** — rethrowing the body's own exception.
Written by hand the last part is a `catch` that is easy to leave out, and the
version without it leaks: the participants that enlisted are never rolled back,
never ended, and their connections never return to the pool.

The current transaction is scoped to the flow of work that opened it, and
`runInTransaction` establishes that scope when the flow has none — so
*concurrent* flows are isolated for free, neither able to see, commit or roll
back the other's transaction (requests get the same from the server
automatically):

```dart
await Future.wait([
  TomTransactionManager.runInTransaction((tx) async => saveOrder(tx)),
  TomTransactionManager.runInTransaction((tx) async => saveInvoice(tx)),
]);
```

A caller that needs to decide commit-or-rollback on something other than a
throw drives the transaction itself, with `runInTransactionScope`,
`startTransaction` and its own `try`/`catch`; `doc/transactions.md` shows that
form beside this one.

See [`doc/transactions.md`](../../../../doc/transactions.md) for the
participant contract, what the prepare phase buys and what it cannot, and how a
request acquires its scope, and
`example/transactions/transactions_example.dart` for a walkthrough
that checks its own results against an in-memory participant, so it needs no
database. `test/transactions_test.dart` covers the module, runs the example, and
holds this readme, `doc/transactions.md` and the API summary to what
`TomTransactionParticipant` actually declares — so the prepare phase being
removed from the contract fails the suite rather than leaving four texts
describing yesterday's answer. `test/readme_quick_start_test.dart` runs the snippet above.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

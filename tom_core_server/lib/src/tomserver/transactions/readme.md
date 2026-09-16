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
can repair.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomTransactionManager` | Zone-scoped coordinator; `startTransaction([isReadOnly])` returns `(transaction, isNew)`, `getCurrentTransaction()`, `transactional`, plus `runInTransactionScope(body)` / `hasTransactionScope` for isolating one flow of work from another. Binds the transaction to a `@TomTransactional` endpoint call. |
| `TomTransaction` | The running transaction (created via the manager); `registerParticipant` (all or nothing — a participant whose `startTransaction` refuses or throws is not enlisted, and the failure is raised naming it), `commitTransaction()` (prepare-all then commit-all, rolling back on any veto), `rollbackTransaction()`. |
| `TomTransactionParticipant` | Abstract resource that enlists in a transaction (`prepare`, `commit`, `rollback`, `endTransaction`). Datasources implement this; `MariaDbXADatasource` maps `prepare` onto `XA END` + `XA PREPARE` and `commit` onto `XA COMMIT`. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final (tx, isNew) = TomTransactionManager.startTransaction();
  print(isNew); // true  (no transaction was active)

  // Datasources and other resources enlist as participants:
  // tx.registerParticipant(myDatasource);

  final committed = await tx.commitTransaction();
  print(committed); // true  (no participant vetoed the commit)
}
```

The current transaction is scoped to the flow of work that opened it. A single
flow — the `main()` above, a script, a test — needs no scope of its own. Code
that runs *concurrent* flows wraps each one, so neither can see, commit, or roll
back the other's transaction (requests get this from the server automatically):

```dart
await Future.wait([
  TomTransactionManager.runInTransactionScope(() async {
    final (tx, _) = TomTransactionManager.startTransaction();
    await tx.commitTransaction();
  }),
  TomTransactionManager.runInTransactionScope(() async {
    final (tx, _) = TomTransactionManager.startTransaction();
    await tx.rollbackTransaction();
  }),
]);
```

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

# transactions

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Two-phase transaction coordination across participants (datasources and other
resources). A `TomTransaction` collects `TomTransactionParticipant`s; on commit
it calls `commit()` on each — if any returns `false` the whole transaction rolls
back. The `TomTransactionManager` binds a transaction to a `@TomTransactional`
endpoint call and commits or rolls it back when the call returns.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomTransactionManager` | Zone-scoped coordinator; `startTransaction([isReadOnly])` returns `(transaction, isNew)`, `getCurrentTransaction()`, `transactional`, plus `runInTransactionScope(body)` / `hasTransactionScope` for isolating one flow of work from another. Binds the transaction to a `@TomTransactional` endpoint call. |
| `TomTransaction` | The running transaction (created via the manager); `registerParticipant`, `commitTransaction()` (rolls back on any failed participant), `rollbackTransaction()`. |
| `TomTransactionParticipant` | Abstract resource that enlists in a transaction (`commit`, `rollback`, `endTransaction`). Datasources implement this. |

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

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

/// Executable example for the transactions module of `tom_core_server`.
///
/// Shows the transaction lifecycle with a fake in-memory participant: opening a
/// transaction through [TomTransactionManager], enlisting participants, and
/// concluding with a commit or a rollback (including the commit-veto path). In
/// production the participants are data sources (`TomDataSource` implements
/// [TomTransactionParticipant]) and the endpoint pipeline opens/closes the
/// transaction around a `@TomTransactional` endpoint.
///
/// Run with `dart run example/transactions/transactions_example.dart`. The same
/// behaviour is covered by `test/transactions_test.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// A participant that records the lifecycle calls made on it. [vetoCommit]
/// makes [commit] return `false`, which turns a commit into a rollback.
class _RecordingParticipant extends TomTransactionParticipant {
  _RecordingParticipant(this.id, {this.vetoCommit = false});

  final String id;
  final bool vetoCommit;
  final List<String> calls = [];

  @override
  String getParticipantId() => id;

  @override
  Future<bool> startTransaction() async {
    calls.add('start');
    return true;
  }

  @override
  Future<bool> commit() async {
    calls.add('commit');
    return !vetoCommit;
  }

  @override
  Future<void> rollback() async {
    calls.add('rollback');
  }

  @override
  Future<bool> endTransaction() async {
    calls.add('end');
    return true;
  }
}

Future<void> run() async {
  // 1. Opening a transaction reports it as new; opening again reuses it.
  final (txn, isNew) = TomTransactionManager.startTransaction();
  final (sameTxn, isNew2) = TomTransactionManager.startTransaction();
  print('1. first=$isNew second=$isNew2 same=${identical(txn, sameTxn)} '
      'transactional=${TomTransactionManager.transactional}');
  assert(isNew == true && isNew2 == false && identical(txn, sameTxn));
  assert(TomTransactionManager.transactional == true);

  // 2. Enlist a participant and commit; it is committed then ended.
  final a = _RecordingParticipant('a');
  await txn.registerParticipant(a);
  final ok = await txn.commitTransaction();
  print('2. commit ok=$ok calls=${a.calls} '
      'cleared=${TomTransactionManager.getCurrentTransaction() == null}');
  assert(ok == true);
  assert(a.calls.contains('commit') && a.calls.contains('end'));
  assert(TomTransactionManager.getCurrentTransaction() == null);

  // 3. A participant that vetoes the commit turns it into a rollback.
  final (txn3, _) = TomTransactionManager.startTransaction();
  final b = _RecordingParticipant('b', vetoCommit: true);
  await txn3.registerParticipant(b);
  final ok3 = await txn3.commitTransaction();
  print('3. veto -> ok=$ok3 calls=${b.calls}');
  assert(b.calls.contains('rollback'));
  assert(TomTransactionManager.getCurrentTransaction() == null);

  // 4. Registering after the transaction concluded is rejected. enlistment is
  //    awaitable, so the guard's exception surfaces directly to the caller and
  //    is caught with a plain try/catch.
  assert(txn3.isRunning == false);
  Object? captured;
  try {
    await txn3.registerParticipant(_RecordingParticipant('late'));
  } catch (error) {
    captured = error;
  }
  print('4. enlist-after-conclude threw '
      '${captured is TomTransactionException ? captured.key : captured}');
  assert(captured is TomTransactionException);

  print('\nTransactions example completed.');
}

void main() => run();

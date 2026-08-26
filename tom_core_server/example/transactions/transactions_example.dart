/// Executable example for the transactions module of `tom_core_server`.
///
/// Shows the transaction lifecycle with a fake in-memory participant: opening a
/// transaction through [TomTransactionManager], enlisting participants, and
/// concluding with a commit or a rollback (including the commit-veto path),
/// isolating two concurrent flows from each other with
/// [TomTransactionManager.runInTransactionScope], testing for a scope with
/// [TomTransactionManager.hasTransactionScope], and finally opening a read-only
/// transaction. In production the participants are data sources
/// (`TomDataSource` implements [TomTransactionParticipant]) and the endpoint
/// pipeline opens/closes the transaction around a `@TomTransactional`
/// endpoint — inside a scope the server establishes per request.
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

/// Throws unless [ok] holds, naming the expectation that failed.
///
/// Deliberately not `assert`: `dart run` leaves assertions **disabled** — that
/// is what its `--enable-asserts` flag is for — so an `assert` here compiles
/// out under the very command this file's header gives. An example whose
/// checks vanish under its own documented invocation is worse than one with no
/// checks at all, because it still prints a plausible transcript and still
/// exits 0 while every expectation in it is violated. A plain `if`/`throw`
/// holds however the file is run.
void check(bool ok, String expectation) {
  if (!ok) throw StateError('transactions example failed: $expectation');
}

Future<void> run() async {
  // 1. Opening a transaction reports it as new; opening again reuses it.
  final (txn, isNew) = TomTransactionManager.startTransaction();
  final (sameTxn, isNew2) = TomTransactionManager.startTransaction();
  print(
    '1. first=$isNew second=$isNew2 same=${identical(txn, sameTxn)} '
    'transactional=${TomTransactionManager.transactional}',
  );
  check(isNew, 'the first startTransaction reports that it created one');
  check(!isNew2, 'the second reports that it found one, not created it');
  check(identical(txn, sameTxn), 'both callers hold the same transaction');
  check(TomTransactionManager.transactional, 'a transaction is now active');

  // 2. Enlist a participant and commit; it is committed then ended.
  final a = _RecordingParticipant('a');
  await txn.registerParticipant(a);
  final ok = await txn.commitTransaction();
  print(
    '2. commit ok=$ok calls=${a.calls} '
    'cleared=${TomTransactionManager.getCurrentTransaction() == null}',
  );
  check(ok, 'the commit succeeded');
  check(
    a.calls.join(',') == 'start,commit,end',
    'the participant was started, committed and then ended, in that order',
  );
  check(
    TomTransactionManager.getCurrentTransaction() == null,
    'a concluded transaction clears itself from its scope',
  );

  // 3. A participant that vetoes the commit turns it into a rollback.
  final (txn3, _) = TomTransactionManager.startTransaction();
  final b = _RecordingParticipant('b', vetoCommit: true);
  await txn3.registerParticipant(b);
  final ok3 = await txn3.commitTransaction();
  print('3. veto -> ok=$ok3 calls=${b.calls}');
  check(
    b.calls.join(',') == 'start,commit,rollback,end',
    'the veto turned the commit into a rollback, and the participant that '
    'had already been asked to commit was rolled back too',
  );
  check(
    TomTransactionManager.getCurrentTransaction() == null,
    'the vetoed transaction cleared itself as well',
  );

  // 4. Registering after the transaction concluded is rejected. enlistment is
  //    awaitable, so the guard's exception surfaces directly to the caller and
  //    is caught with a plain try/catch.
  check(!txn3.isRunning, 'the vetoed transaction is no longer running');
  Object? captured;
  try {
    await txn3.registerParticipant(_RecordingParticipant('late'));
  } catch (error) {
    captured = error;
  }
  print(
    '4. enlist-after-conclude threw '
    '${captured is TomTransactionException ? captured.key : captured}',
  );
  check(
    captured is TomTransactionException,
    'enlisting in a concluded transaction throws rather than silently '
    'joining work that will never be committed',
  );

  // 5. Two concurrent flows, each in its own scope, hold independent current
  //    transactions. Steps 1-4 above ran outside every scope and so shared the
  //    process-wide fallback one, which is right for a single flow of work —
  //    but anything that fans out (a scheduler, a batch tool, and every request
  //    the server serves) must wrap each flow, or one flow can commit another's
  //    work. Each flow below yields at the point where the other is guaranteed
  //    to have opened its transaction, which is exactly the interleave.
  final opened = <String, TomTransaction>{};
  Future<void> flow(String name) =>
      TomTransactionManager.runInTransactionScope(() async {
        final (txn, isNew) = TomTransactionManager.startTransaction();
        opened[name] = txn;
        check(isNew, 'flow $name opened its own transaction');
        await Future<void>.delayed(Duration.zero);
        check(
          identical(TomTransactionManager.getCurrentTransaction(), txn),
          'flow $name still sees its own transaction after yielding to the '
          'other flow',
        );
        await txn.commitTransaction();
      });
  await Future.wait([flow('left'), flow('right')]);
  print(
    '5. concurrent flows shared a transaction='
    '${identical(opened['left'], opened['right'])} '
    'outside any scope current='
    '${TomTransactionManager.getCurrentTransaction()}',
  );
  check(
    !identical(opened['left'], opened['right']),
    'the two flows held independent transactions, so neither could commit '
    "the other's work",
  );
  check(
    TomTransactionManager.getCurrentTransaction() == null,
    'nothing is current outside every scope',
  );

  // 6. `hasTransactionScope` distinguishes a flow that carries a scope of its
  //    own from one falling back to the process-wide scope. It is the test a
  //    caller makes before establishing a scope, so that it opens one only when
  //    the code in front of it did not — what the endpoint pipeline does for a
  //    `@TomTransactional` endpoint whose request arrived without one.
  final atTopLevel = TomTransactionManager.hasTransactionScope;
  final insideScope = await TomTransactionManager.runInTransactionScope(
    () async => TomTransactionManager.hasTransactionScope,
  );
  print('6. hasTransactionScope top-level=$atTopLevel inside=$insideScope');
  check(!atTopLevel, 'no scope at top level, so the fallback one is in use');
  check(insideScope, 'a scope established by runInTransactionScope is seen');

  // 7. A transaction can be opened read-only. The flag is advisory — it tells
  //    participants and callers what kind of work the transaction was opened
  //    for, and does not by itself prevent writes.
  final (readOnly, _) = TomTransactionManager.startTransaction(true);
  print('7. isReadOnly=${readOnly.isReadOnly}');
  check(readOnly.isReadOnly, 'the flag is honoured on a created transaction');
  await readOnly.commitTransaction();

  //    It is honoured only when a transaction is *created*. Below, a read-write
  //    transaction is open and a nested caller asks for a read-only one: it
  //    receives the existing transaction unchanged. A nested request therefore
  //    cannot downgrade a transaction somebody opened for writing — which would
  //    otherwise retroactively mislabel the writes already made in it.
  final (readWrite, _) = TomTransactionManager.startTransaction();
  final (joined, isNewJoined) = TomTransactionManager.startTransaction(true);
  print(
    '   nested read-only request: reused=${!isNewJoined} '
    'still read-write=${!joined.isReadOnly}',
  );
  check(!isNewJoined, 'the nested caller found the open transaction');
  check(identical(joined, readWrite), 'and got that very transaction back');
  check(
    !joined.isReadOnly,
    'asking read-only did not downgrade a transaction opened for writing',
  );
  await readWrite.commitTransaction();

  print('\nTransactions example completed.');
}

void main() => run();

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the transactions module: the [TomTransaction] lifecycle, the
/// commit/rollback drive (including the commit-veto path and participant
/// deduplication), and the ambient [TomTransactionManager] singleton. The
/// module is self-contained (no reflection, no database), so the whole surface
/// is exercised here with a recording fake participant.

/// A participant that records the lifecycle calls made on it.
///
/// [vetoCommit] makes `commit()` return `false` (vetoing the transaction).
/// [endResult] is the value returned by `endTransaction()` — set it `false` to
/// exercise the "an end call failed" branch of the commit/rollback drive. When
/// a [sharedLog] is supplied, every call is also appended to it as `id:call`,
/// so a test spanning several participants can assert cross-participant
/// ordering.
class _RecordingParticipant extends TomTransactionParticipant {
  _RecordingParticipant(
    this.id, {
    this.vetoCommit = false,
    this.endResult = true,
    this.sharedLog,
  });

  final String id;
  final bool vetoCommit;
  final bool endResult;
  final List<String>? sharedLog;
  final List<String> calls = [];

  void _record(String call) {
    calls.add(call);
    sharedLog?.add('$id:$call');
  }

  @override
  String getParticipantId() => id;

  @override
  Future<bool> startTransaction() async {
    _record('start');
    return true;
  }

  @override
  Future<bool> commit() async {
    _record('commit');
    return !vetoCommit;
  }

  @override
  Future<void> rollback() async {
    _record('rollback');
  }

  @override
  Future<bool> endTransaction() async {
    _record('end');
    return endResult;
  }
}

void main() {
  // The manager holds a single static transaction; ensure each test starts and
  // ends with no active transaction.
  tearDown(() async {
    await TomTransactionManager.getCurrentTransaction()?.rollbackTransaction();
  });

  group('TomTransactionManager', () {
    test('first startTransaction creates a new transaction', () {
      final (txn, isNew) = TomTransactionManager.startTransaction();
      expect(isNew, isTrue);
      expect(identical(TomTransactionManager.getCurrentTransaction(), txn),
          isTrue);
      expect(TomTransactionManager.transactional, isTrue);
    });

    test('a second startTransaction returns the existing one', () {
      final (txn, _) = TomTransactionManager.startTransaction();
      final (txn2, isNew2) = TomTransactionManager.startTransaction();
      expect(isNew2, isFalse);
      expect(identical(txn, txn2), isTrue);
    });

    test('isReadOnly is honoured for a newly created transaction', () {
      final (txn, _) = TomTransactionManager.startTransaction(true);
      expect(txn.isReadOnly, isTrue);
    });

    test('startTransaction defaults to read-write', () {
      final (txn, _) = TomTransactionManager.startTransaction();
      expect(txn.isReadOnly, isFalse);
    });

    test('transactional is false when no transaction is active', () {
      expect(TomTransactionManager.transactional, isFalse);
      expect(TomTransactionManager.getCurrentTransaction(), isNull);
    });

    test('transactional is false once the transaction has concluded', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.commitTransaction();
      // The concluded transaction is cleared, so no transaction is active and
      // transactional reports false even though the handle still exists.
      expect(TomTransactionManager.transactional, isFalse);
      expect(txn.isRunning, isFalse);
    });
  });

  group('commitTransaction', () {
    test('commits then ends every participant and clears the manager',
        () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final p = _RecordingParticipant('a');
      await txn.registerParticipant(p);
      final ok = await txn.commitTransaction();
      expect(ok, isTrue);
      expect(p.calls, ['start', 'commit', 'end']);
      expect(txn.isRunning, isFalse);
      expect(TomTransactionManager.getCurrentTransaction(), isNull);
    });

    test('commits then ends all participants in registration order', () async {
      final log = <String>[];
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(_RecordingParticipant('a', sharedLog: log));
      await txn.registerParticipant(_RecordingParticipant('b', sharedLog: log));
      final ok = await txn.commitTransaction();
      expect(ok, isTrue);
      // All commits run (in order) before any endTransaction, and both phases
      // follow registration order.
      expect(log, ['a:start', 'b:start', 'a:commit', 'b:commit', 'a:end', 'b:end']);
    });

    test('a vetoing participant turns the commit into a rollback', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final p = _RecordingParticipant('a', vetoCommit: true);
      await txn.registerParticipant(p);
      await txn.commitTransaction();
      expect(p.calls, contains('rollback'));
      expect(TomTransactionManager.getCurrentTransaction(), isNull);
    });

    test('a later veto also rolls back the participants that already committed',
        () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final committed = _RecordingParticipant('a');
      final vetoer = _RecordingParticipant('b', vetoCommit: true);
      await txn.registerParticipant(committed);
      await txn.registerParticipant(vetoer);
      final ok = await txn.commitTransaction();
      // The veto aborts the commit loop and rolls the whole transaction back,
      // so the participant that already committed successfully is still rolled
      // back and ended.
      expect(ok, isTrue); // rollback's end calls all succeeded
      expect(committed.calls, ['start', 'commit', 'rollback', 'end']);
      expect(vetoer.calls, ['start', 'commit', 'rollback', 'end']);
    });

    test('a failing endTransaction makes a clean commit report false', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final p = _RecordingParticipant('a', endResult: false);
      await txn.registerParticipant(p);
      final ok = await txn.commitTransaction();
      // The work committed, but the resource-release step failed, which the
      // return value surfaces.
      expect(ok, isFalse);
      expect(p.calls, ['start', 'commit', 'end']);
      expect(TomTransactionManager.getCurrentTransaction(), isNull);
    });
  });

  group('rollbackTransaction', () {
    test('rolls back then ends every participant and clears the manager',
        () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final p = _RecordingParticipant('a');
      await txn.registerParticipant(p);
      final ok = await txn.rollbackTransaction();
      expect(ok, isTrue);
      expect(p.calls, ['start', 'rollback', 'end']);
      expect(txn.isRunning, isFalse);
      expect(TomTransactionManager.getCurrentTransaction(), isNull);
    });

    test('rolls back then ends all participants in registration order', () async {
      final log = <String>[];
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(_RecordingParticipant('a', sharedLog: log));
      await txn.registerParticipant(_RecordingParticipant('b', sharedLog: log));
      final ok = await txn.rollbackTransaction();
      expect(ok, isTrue);
      expect(log,
          ['a:start', 'b:start', 'a:rollback', 'b:rollback', 'a:end', 'b:end']);
    });

    test('a failing endTransaction makes rollback report false', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final p = _RecordingParticipant('a', endResult: false);
      await txn.registerParticipant(p);
      final ok = await txn.rollbackTransaction();
      expect(ok, isFalse);
      expect(p.calls, ['start', 'rollback', 'end']);
    });
  });

  group('registerParticipant', () {
    test('deduplicates participants by id, enlisting only once', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final p = _RecordingParticipant('same');
      await txn.registerParticipant(p);
      await txn.registerParticipant(p);
      // startTransaction() called exactly once despite two registrations.
      expect(p.calls.where((c) => c == 'start').length, 1);
    });

    test('rejects enlistment once the transaction has concluded', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.commitTransaction();
      // registerParticipant returns a Future, so the guard's exception surfaces
      // to the awaiting caller and is directly catchable.
      await expectLater(
        txn.registerParticipant(_RecordingParticipant('late')),
        throwsA(
          isA<TomTransactionException>().having(
            (e) => e.key,
            'key',
            'transaction_manager.register_participant.transaction_not_running',
          ),
        ),
      );
    });

    test('rejects enlistment once the transaction has rolled back', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.rollbackTransaction();
      await expectLater(
        txn.registerParticipant(_RecordingParticipant('late')),
        throwsA(isA<TomTransactionException>()),
      );
    });
  });

  group('TomTransactionException', () {
    test('is a TomServerException subtype', () {
      expect(
        TomTransactionException('k', 'm'),
        isA<TomServerException>(),
      );
    });

    test('carries its key and default user message', () {
      final e = TomTransactionException('a.key', 'a message');
      expect(e.key, 'a.key');
      expect(e, isA<TomException>());
    });
  });
}

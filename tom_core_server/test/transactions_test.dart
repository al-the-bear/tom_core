import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the transactions module: the [TomTransaction] lifecycle, the
/// commit/rollback drive (including the commit-veto path and participant
/// deduplication), and the ambient [TomTransactionManager] singleton. The
/// module is self-contained (no reflection, no database), so the whole surface
/// is exercised here with a recording fake participant.

/// A participant that records the lifecycle calls made on it.
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

    test('transactional is false when no transaction is active', () {
      expect(TomTransactionManager.transactional, isFalse);
      expect(TomTransactionManager.getCurrentTransaction(), isNull);
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

    test('a vetoing participant turns the commit into a rollback', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      final p = _RecordingParticipant('a', vetoCommit: true);
      await txn.registerParticipant(p);
      await txn.commitTransaction();
      expect(p.calls, contains('rollback'));
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
  });

  group('TomTransactionException', () {
    test('is a TomServerException subtype', () {
      expect(
        TomTransactionException('k', 'm'),
        isA<TomServerException>(),
      );
    });
  });
}

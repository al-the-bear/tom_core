/// The coordinator's decision record and the recovery pass, without a
/// database: participants and sources are fakes. The process-death case runs
/// against MariaDB and PostgreSQL in `transaction_recovery_db_test.dart`.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

/// A two-phase participant holding branch [branch]; [onCommit] runs during
/// its commit, [commits] says whether it succeeds.
class _Branch implements TomTransactionParticipant, TomPreparedBranchHolder {
  _Branch(this.branch, {this.onCommit, this.commits = true});

  final String branch;
  final Future<void> Function()? onCommit;
  final bool commits;
  bool rolledBack = false;

  @override
  String getParticipantId() => 'branch:$branch';

  @override
  String? preparedBranchOf(TomTransaction transaction) => branch;

  @override
  Future<bool> startTransaction(TomTransaction transaction) async => true;

  @override
  Future<bool> prepare(TomTransaction transaction) async => true;

  @override
  Future<bool> commit(TomTransaction transaction) async {
    await onCommit?.call();
    return commits;
  }

  @override
  Future<bool> rollback(TomTransaction transaction) async => rolledBack = true;

  @override
  Future<bool> endTransaction(TomTransaction transaction) async => true;
}

class _FailingLog implements TomTransactionDecisionLog {
  @override
  Future<void> recordCommit(String transactionId, List<String> branches) =>
      throw StateError('log unavailable');

  @override
  Future<void> forget(String transactionId) async {}

  @override
  Future<Map<String, Set<String>>> decisions() async => {};
}

/// A source holding [prepared] branches; branches starting with `own` are
/// its own, and [failing] ones fail to resolve.
class _Source implements TomTwoPhaseRecoverable {
  _Source(this.prepared, {this.opened, this.failing = const {}});

  final Set<String> prepared;
  final DateTime? opened;
  final Set<String> failing;
  final List<String> committed = [];
  final List<String> rolledBack = [];

  @override
  String get recoveryLabel => 'fake';

  @override
  Future<List<String>> listPreparedBranches() async => [...prepared];

  @override
  bool ownsBranch(String branchId) => branchId.startsWith('own');

  @override
  DateTime? branchOpenedAt(String branchId) => opened;

  @override
  Future<void> commitPreparedBranch(String branchId) async {
    if (failing.contains(branchId)) throw StateError('gone');
    committed.add(branchId);
    prepared.remove(branchId);
  }

  @override
  Future<void> rollbackPreparedBranch(String branchId) async {
    if (failing.contains(branchId)) throw StateError('gone');
    rolledBack.add(branchId);
    prepared.remove(branchId);
  }
}

void main() {
  tearDown(TomTransactionRecovery.reset);

  group('the coordinator records its decision before the commit phase', () {
    test(
      'recorded before the first commit, forgotten after the last',
      () async {
        final log = TomMemoryDecisionLog();
        TomTransactionManager.decisionLog = log;
        Map<String, Set<String>>? seen;
        await TomTransactionManager.runInTransaction((tx) async {
          await tx.registerParticipant(
            _Branch('a', onCommit: () async => seen = await log.decisions()),
          );
          await tx.registerParticipant(_Branch('b'));
        });
        expect(seen!.values.single, {'a', 'b'});
        expect(await log.decisions(), isEmpty);
      },
    );

    test('a decision that cannot be recorded is not taken: the transaction '
        'rolls back', () async {
      TomTransactionManager.decisionLog = _FailingLog();
      final branch = _Branch('a');
      await expectLater(
        TomTransactionManager.runInTransaction(
          (tx) => tx.registerParticipant(branch),
        ),
        _throwsKey('transaction_manager.run_in_transaction.commit_failed'),
      );
      expect(branch.rolledBack, isTrue);
    });

    test(
      'a branch that fails to commit keeps the record for a recovery',
      () async {
        final log = TomMemoryDecisionLog();
        TomTransactionManager.decisionLog = log;
        await expectLater(
          TomTransactionManager.runInTransaction((tx) async {
            await tx.registerParticipant(_Branch('a'));
            await tx.registerParticipant(_Branch('b', commits: false));
          }),
          _throwsKey('transaction_manager.run_in_transaction.commit_failed'),
        );
        expect((await log.decisions()).values.single, {'a', 'b'});
      },
    );

    test('every transaction has its own id', () async {
      final ids = <String>{};
      for (var i = 0; i < 3; i++) {
        await TomTransactionManager.runInTransaction((tx) => ids.add(tx.id));
      }
      expect(ids, hasLength(3));
      expect(ids.first, startsWith('tx_'));
    });
  });

  group('recovery', () {
    final long = DateTime.utc(2026, 1, 1);
    final now = DateTime.utc(2026, 10, 21);

    test('commits decided branches, rolls back the rest, forgets what is '
        'resolved', () async {
      final log = TomMemoryDecisionLog();
      await log.recordCommit('tx1', ['own-a', 'own-b']);
      final source = _Source({
        'own-a',
        'own-b',
        'own-c',
        'foreign-d',
      }, opened: long);
      final report = await TomTransactionRecovery.recover(
        sources: [source],
        log: log,
        now: now,
      );
      expect(source.committed, unorderedEquals(['own-a', 'own-b']));
      expect(source.rolledBack, ['own-c']);
      expect(source.prepared, {'foreign-d'}, reason: 'not its own');
      expect(report.forgotten, ['tx1']);
      expect(await log.decisions(), isEmpty);
      expect(report.isClean, isTrue);
    });

    test(
      'a branch younger than the minimum age is left to its process',
      () async {
        final source = _Source({'own-a'}, opened: now);
        final report = await TomTransactionRecovery.recover(
          sources: [source],
          log: TomMemoryDecisionLog(),
          now: now.add(const Duration(seconds: 5)),
        );
        expect(report.tooYoung, ['own-a']);
        expect(source.rolledBack, isEmpty);
      },
    );

    test(
      'a failure is reported, the decision kept, and the rest resolved',
      () async {
        final log = TomMemoryDecisionLog();
        await log.recordCommit('tx1', ['own-a']);
        final source = _Source(
          {'own-a', 'own-b'},
          opened: long,
          failing: {'own-a'},
        );
        final report = await TomTransactionRecovery.recover(
          sources: [source],
          log: log,
          now: now,
        );
        expect(report.failed.keys, ['own-a']);
        expect(report.rolledBack, ['own-b']);
        expect(report.forgotten, isEmpty);
        expect(report.isClean, isFalse);
      },
    );

    test('without a log every old branch is rolled back', () async {
      final source = _Source({'own-a'}, opened: long);
      final report = await TomTransactionRecovery.recover(
        sources: [source],
        now: now,
      );
      expect(report.rolledBack, ['own-a']);
    });
  });

  group('branch ids', () {
    test('a branch id names its data source and when it was opened', () {
      final before = DateTime.now().toUtc();
      final id = tomSqlBranchId(
        databaseName: 'orders',
        host: 'db.example.com',
        port: 3306,
        processTag: '0123abcd',
        counter: 7,
        maxBytes: 64,
      );
      expect(
        tomSqlOwnsBranch(
          id,
          databaseName: 'orders',
          host: 'db.example.com',
          port: 3306,
        ),
        isTrue,
      );
      expect(
        tomSqlOwnsBranch(
          id,
          databaseName: 'billing',
          host: 'db.example.com',
          port: 3306,
        ),
        isFalse,
      );
      expect(
        tomSqlBranchOpenedAt(id)!.difference(before).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('a truncated head still names its data source', () {
      final host = 'a-very-long-database-host-name.internal.example.com';
      final id = tomSqlBranchId(
        databaseName: 'orders',
        host: host,
        port: 3306,
        processTag: '0123abcd',
        counter: 1,
        maxBytes: 64,
      );
      expect(id.length, lessThanOrEqualTo(64));
      expect(
        tomSqlOwnsBranch(id, databaseName: 'orders', host: host, port: 3306),
        isTrue,
      );
    });

    test('an id of characters the drivers never write is refused before it '
        'reaches a statement', () {
      for (final source in <TomTwoPhaseRecoverable>[
        MariaDbXADatasource(),
        PostgresXADatasource(),
      ]) {
        expect(
          () => source.commitPreparedBranch("x'; DROP TABLE t; --"),
          _throwsKey('error.datasource.invalid_branch_id'),
        );
        expect(
          () => source.rollbackPreparedBranch('x y'),
          _throwsKey('error.datasource.invalid_branch_id'),
        );
      }
    });

    test('an id of another shape is not one of ours', () {
      expect(
        tomSqlOwnsBranch('some-xid', databaseName: 'd', host: 'h', port: 1),
        isFalse,
      );
      expect(tomSqlBranchOpenedAt('some-xid'), isNull);
    });
  });

  group('configuration', () {
    test(
      'the transactions section installs the log and the start recovery',
      () {
        TomTransactionRecovery.configure({
          'decisionLog': 'main',
          'recoverOnStart': true,
          'recoveryMinimumAgeSeconds': 30,
        });
        expect(TomTransactionManager.decisionLog, isA<TomSqlDecisionLog>());
        expect(
          (TomTransactionManager.decisionLog! as TomSqlDecisionLog)
              .datasourceName,
          'main',
        );
        expect(TomTransactionRecovery.recoverOnStart, isTrue);
        expect(TomTransactionRecovery.minimumAge, const Duration(seconds: 30));
      },
    );

    test('a decision log over an unregistered data source is refused', () {
      expect(
        TomSqlDecisionLog('no_such_datasource').decisions(),
        _throwsKey('transactions.recovery.no_datasource'),
      );
    });

    test('a malformed section is refused', () {
      expect(
        () => TomTransactionRecovery.configure('main'),
        _throwsKey('transactions.recovery.config.invalid'),
      );
      expect(
        () =>
            TomTransactionRecovery.configure({'recoveryMinimumAgeSeconds': -1}),
        _throwsKey('transactions.recovery.config.invalid'),
      );
    });
  });
}

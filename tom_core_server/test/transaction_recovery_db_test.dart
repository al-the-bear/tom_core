/// Recovery after a process died between the two phases of a two-phase
/// commit, against a live database.
///
/// A separate process (`test/fixtures/xa_recovery_probe.dart`) writes a row
/// through two two-phase data sources in one transaction and exits in the
/// middle of it; this suite then recovers, as the restarted process would.
/// The two branches live in two databases on the test server.
///
/// `@Tags(['db'])`, self-skipping without a server, and without prepared
/// transactions on PostgreSQL; bring one up with `tool/run_db_tests.sh`
/// (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? await TestDatabase.twoPhaseSkipReason()
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  final first = TestDatabase.databaseName;
  final second = '${first}_x2';
  final plain = TestDatabase.isPostgres ? 'postgresql' : 'mariadb';
  final twoPhase = '${plain}_xa';
  final base =
      TestDatabase.datasourceConfig[TestDatabase.datasourceName]
          as Map<String, dynamic>;
  Map<String, dynamic> at(String database, String type) => {
    ...base,
    'databaseName': database,
    'type': type,
  };
  final probeSettings = {
    'xa_one': at(first, twoPhase),
    'xa_two': at(second, twoPhase),
    'decision_log': at(first, plain),
  };

  late TomDataSource readOne;
  late TomDataSource readTwo;
  late TomTwoPhaseRecoverable xaOne;
  late TomTwoPhaseRecoverable xaTwo;
  late TomSqlDecisionLog log;

  Future<TomRecoveryReport> recover() =>
      TomTransactionRecovery.recover(sources: [xaOne, xaTwo], log: log);

  setUpAll(() async {
    if (skip != null) return;
    initializeReflection();
    final main = (await TestDatabase.register()).datasource;
    await TestDatabase.createDatabase(main, second);
    await TomDataSourceInfo.initializeDatasourceInfo({
      'read_one': at(first, plain),
      'read_two': at(second, plain),
      ...probeSettings,
    });
    TomDataSource ds(String name) =>
        TomDataSourceInfo.getDataSourceInfo(name)!.datasource;
    readOne = ds('read_one');
    readTwo = ds('read_two');
    xaOne = ds('xa_one') as TomTwoPhaseRecoverable;
    xaTwo = ds('xa_two') as TomTwoPhaseRecoverable;
    log = TomSqlDecisionLog('decision_log');
    for (final reader in [readOne, readTwo]) {
      await TestDatabase.execute(
        reader,
        'CREATE TABLE xr_note (id BIGINT NOT NULL AUTO_INCREMENT, '
        'text VARCHAR(40) NULL, PRIMARY KEY (id))',
      );
    }
    addTearDown(() async {
      // Nothing prepared may outlive the suite: PostgreSQL will not drop a
      // database holding a prepared transaction.
      TomTransactionRecovery.minimumAge = Duration.zero;
      await recover();
      await TestDatabase.dropDatabase(main, second);
      await TestDatabase.reset();
    });
  });

  setUp(() async {
    if (skip != null) return;
    TomTransactionRecovery.minimumAge = Duration.zero;
    await recover();
    for (final reader in [readOne, readTwo]) {
      await reader.executeCommand('DELETE FROM xr_note');
    }
  });

  tearDown(TomTransactionRecovery.reset);

  /// Runs the probe in [mode]; it has to die rather than finish.
  Future<void> crash(String mode) async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'test/fixtures/xa_recovery_probe.dart',
      jsonEncode(probeSettings),
      mode,
    ]);
    expect(
      result.exitCode,
      3,
      reason:
          'the probe died in its transaction\n${result.stdout}\n'
          '${result.stderr}',
    );
  }

  Future<List<int>> rows() async => [
    for (final reader in [readOne, readTwo])
      (await reader.executeQuery<TomCountResult>(
        'SELECT COUNT(*) AS count FROM xr_note',
      )).single.count,
  ];

  test(
    'a process that died after deciding: the restart commits both '
    'branches',
    () async {
      await crash('after-decision');
      expect(await rows(), [0, 0], reason: 'prepared, not committed');
      expect(await log.decisions(), hasLength(1));

      final report = await recover();
      expect(report.committed, hasLength(2));
      expect(report.rolledBack, isEmpty);
      expect(report.forgotten, hasLength(1));
      expect(await rows(), [1, 1]);
      expect(await log.decisions(), isEmpty);
      expect(
        (await xaOne.listPreparedBranches()).where(xaOne.ownsBranch),
        isEmpty,
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'a process that died before deciding: the restart rolls both '
    'branches back',
    () async {
      await crash('before-decision');
      expect(await log.decisions(), isEmpty);

      final report = await recover();
      expect(report.rolledBack, hasLength(2));
      expect(report.committed, isEmpty);
      expect(await rows(), [0, 0]);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'a branch younger than the minimum age is left to its process',
    () async {
      await crash('after-decision');
      TomTransactionRecovery.minimumAge = const Duration(hours: 1);
      final young = await recover();
      expect(young.tooYoung, hasLength(2));
      expect(await rows(), [0, 0]);

      TomTransactionRecovery.minimumAge = Duration.zero;
      expect((await recover()).committed, hasLength(2));
      expect(await rows(), [1, 1]);
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'a transaction that commits leaves no decision and nothing prepared',
    () async {
      TomTransactionManager.decisionLog = log;
      await TomTransactionManager.runInTransaction((tx) async {
        for (final source in [xaOne, xaTwo]) {
          final ds = source as TomSqlDatasource;
          await tx.registerParticipant(ds);
          await ds.executeCommand(
            "INSERT INTO xr_note (text) VALUES ('committed')",
          );
        }
      });
      expect(await rows(), [1, 1]);
      expect(await log.decisions(), isEmpty);
      expect(
        (await xaOne.listPreparedBranches()).where(xaOne.ownsBranch),
        isEmpty,
      );
      expect(
        (await xaTwo.listPreparedBranches()).where(xaTwo.ownsBranch),
        isEmpty,
      );
    },
    skip: skip,
  );
}

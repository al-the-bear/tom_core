/// The XA lifecycle against a real server, driven by the real coordinator.
///
/// `datasources_test.dart` proves the *order* of the statements by recording
/// them; this file proves that the order is one MariaDB accepts. The two are
/// not the same claim, and only the second would have caught the defect this
/// file was written for: `XA END` + `XA PREPARE` lived in `endTransaction()`,
/// which `TomTransaction.commitTransaction` calls only after its `commit()`
/// loop has run — so `XA COMMIT` reached the server against a branch still
/// ACTIVE. A recorder cannot object to that; a server does.
///
/// Durability is read back through a *separate* data source, on its own
/// connection. Reading through the one that wrote is what makes a commit test
/// pass without a commit: the writing connection can see its own uncommitted
/// work, so the assertion would hold whether or not anything was committed.
///
/// The whole group is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring
/// a server up with `tool/run_db_tests.sh`.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart' show FixtureTaskRecord;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// The XA data source's registered name, distinct from the plain one so both
/// can be live at once — the reader has to be a different connection.
const String _xaName = 'tom_core_server_test_xa';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('MariaDbXADatasource through TomTransaction (DB-backed)', () {
    late MariaDbXADatasource xa;
    late MariaDbDatasource reader;

    setUpAll(() async {
      initializeReflection();
      // This suite builds its own XA config rather than calling
      // `TestDatabase.register`, so it provisions its database itself.
      await TestDatabase.provision();
      await TomDataSourceInfo.initializeDatasourceInfo(<String, dynamic>{
        ...TestDatabase.datasourceConfig,
        _xaName: <String, dynamic>{
          'type': 'mariadb_xa',
          'username': TestDatabase.username,
          'password': TestDatabase.password,
          'host': TestDatabase.host,
          'port': TestDatabase.port,
          'databaseName': TestDatabase.databaseName,
        },
      });
      final plain = TomDataSourceInfo.getDataSourceInfo(
        TestDatabase.datasourceName,
      )!;
      reader = plain.datasource as MariaDbDatasource;
      await TestDatabase.ensureFixtureTaskTable(plain);
      xa =
          TomDataSourceInfo.getDataSourceInfo(_xaName)!.datasource
              as MariaDbXADatasource;
    });

    tearDown(() async {
      await TomTransactionManager.getCurrentTransaction()
          ?.rollbackTransaction();
      await reader.executeCommand(
        "DELETE FROM fixture_task WHERE title LIKE 'xa-%'",
      );
    });

    /// The `fixture_task` titles the *reader's* connection can see.
    Future<List<String?>> visibleTitles() async {
      final rows = await reader.executeQuery<FixtureTaskRecord>(
        "SELECT id, title, priority, done FROM fixture_task "
        "WHERE title LIKE 'xa-%' ORDER BY id",
      );
      return rows.map((r) => r.title).toList();
    }

    test('a committed branch is durable on another connection', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(xa);
      await xa.executeCommand(
        "INSERT INTO fixture_task (title, priority, done) "
        "VALUES ('xa-committed', 1, 0)",
      );

      final result = await txn.commitTransaction();
      expect(
        result.outcome,
        TomTransactionOutcome.committed,
        reason: 'the coordinator must report success, not veto its own commit',
      );
      expect(result.isClean, isTrue, reason: 'the branch must be released');
      expect(await visibleTitles(), ['xa-committed']);
    });

    test('a rolled-back branch leaves nothing behind', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(xa);
      await xa.executeCommand(
        "INSERT INTO fixture_task (title, priority, done) "
        "VALUES ('xa-rolled-back', 1, 0)",
      );

      final result = await txn.rollbackTransaction();
      expect(result.outcome, TomTransactionOutcome.rolledBack);
      expect(result.isClean, isTrue, reason: 'the branch must be released');
      expect(await visibleTitles(), isEmpty);
    });

    test('the branch is released, so a second transaction can run', () async {
      // The failure mode a wrongly-ordered lifecycle leaves behind is not a
      // wrong answer but a stuck resource: a branch left ACTIVE holds its locks
      // and nothing issues `XA RECOVER`. Two transactions back to back is the
      // cheapest assertion that nothing was stranded — the second `XA START`
      // is refused outright if the first branch is still open on the driver,
      // and blocks on the row lock if it is still open on the server.
      for (final title in const ['xa-first', 'xa-second']) {
        final (txn, _) = TomTransactionManager.startTransaction();
        await txn.registerParticipant(xa);
        await xa.executeCommand(
          "INSERT INTO fixture_task (title, priority, done) "
          "VALUES ('$title', 1, 0)",
        );
        final result = await txn.commitTransaction();
        expect(result.outcome, TomTransactionOutcome.committed);
        expect(result.isClean, isTrue, reason: 'the branch must be released');
      }
      expect(await visibleTitles(), ['xa-first', 'xa-second']);
    });

    test('the XA connection stays in step after a commit', () async {
      // The defect this pins was intermittent through the reader and certain
      // through the writer. `prepare` once sent `XA END` and `XA PREPARE` as
      // one command; the driver returns on the first reply, so the PREPARE's
      // reply was left for the next call — `XA COMMIT` returned on it before
      // the server had committed, which the reader saw only when it won the
      // race. A query on the XA connection itself has no race to win: it is
      // handed the COMMIT's reply, an empty one, every time.
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(xa);
      await xa.executeCommand(
        "INSERT INTO fixture_task (title, priority, done) "
        "VALUES ('xa-in-step', 1, 0)",
      );
      expect((await txn.commitTransaction()).isClean, isTrue);

      final rows = await xa.executeQuery<FixtureTaskRecord>(
        "SELECT id, title, priority, done FROM fixture_task "
        "WHERE title LIKE 'xa-%' ORDER BY id",
      );
      expect(rows.map((r) => r.title), ['xa-in-step']);
    });

    test('the XA connection stays in step after a rollback', () async {
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(xa);
      await xa.executeCommand(
        "INSERT INTO fixture_task (title, priority, done) "
        "VALUES ('xa-abandoned', 1, 0)",
      );
      expect((await txn.rollbackTransaction()).isClean, isTrue);

      final rows = await xa.executeQuery<FixtureTaskRecord>(
        "SELECT id, title, priority, done FROM fixture_task "
        "WHERE title LIKE 'xa-%' ORDER BY id",
      );
      expect(rows, isEmpty);
      // The emptiness above is also what a desynchronised connection returns,
      // so the connection is then asked something it can only answer in step:
      // a row committed elsewhere, which an out-of-step reply cannot contain.
      await reader.executeCommand(
        "INSERT INTO fixture_task (title, priority, done) "
        "VALUES ('xa-probe', 1, 0)",
      );
      final probe = await xa.executeQuery<FixtureTaskRecord>(
        "SELECT id, title, priority, done FROM fixture_task "
        "WHERE title LIKE 'xa-%' ORDER BY id",
      );
      expect(probe.map((r) => r.title), ['xa-probe']);
    });
  }, skip: skipReason);
}

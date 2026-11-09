/// DB-backed tests for the audit_reports module: the relational trail read
/// across its writers, and the saved questions kept in their table.
///
/// The whole file is `@Tags(['db'])` and skips itself when no database is
/// reachable. Bring one up with `tool/run_db_tests.sh` (MariaDB) or
/// `tool/run_db_tests_postgres.sh` (PostgreSQL).
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

TomAuditRecord _record(String id, int minute, TomAuditOutcome outcome) =>
    TomAuditRecord(
      id: id,
      timestamp: DateTime.utc(2026, 11, 7, 9, minute),
      actor: const TomAuditActor(username: 'ada', userId: '1'),
      action: TomAuditAction.delete,
      target: 'Order',
      targetKey: id,
      outcome: outcome,
    );

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('audit reports over the relational trail', () {
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.dropAuditTrailTable(dsi);
      await TestDatabase.execute(
        dsi.datasource,
        'DROP TABLE IF EXISTS $defaultAuditQuestionTable',
      );
    });

    tearDownAll(TestDatabase.reset);

    test('ARD-1: a question is answered across every writer of the table, '
        'merged by time', () async {
      final a = TomSqlAuditSink(dsi.datasource, writer: 'node-a');
      final b = TomSqlAuditSink(dsi.datasource, writer: 'node-b');
      await a.write(_record('o1', 1, TomAuditOutcome.denied));
      await b.write(_record('o2', 2, TomAuditOutcome.denied));
      await a.write(_record('o3', 3, TomAuditOutcome.succeeded));
      await b.write(_record('o4', 4, TomAuditOutcome.denied));

      final source = TomSqlAuditTrailSource(dsi.datasource);
      expect(await source.writers(), ['node-a', 'node-b']);
      final answer = await TomAuditView(
        source,
      ).query(const TomAuditQuery(outcome: TomAuditOutcome.denied));
      expect(
        [for (final e in answer.entries) e.entry.record.id],
        ['o4', 'o2', 'o1'],
      );
      expect(
        [for (final e in answer.entries) e.writer],
        ['node-b', 'node-b', 'node-a'],
      );
      expect(answer.entries.last.entry.index, 0);
    });

    test(
      'ARD-2: saved questions round-trip, list by owner and fall due',
      () async {
        final store = TomSqlAuditQuestionStore(dsi.datasource);
        final weekly = TomAuditQuestion(
          id: 'q1',
          name: 'Denied this week',
          owner: 'audrey',
          filter: TomAuditQuestionFilter(
            outcome: TomAuditOutcome.denied,
            lastHours: 168,
            writers: const ['node-a'],
          ),
          schedule: '0 6 * * 1',
          recipients: const ['auditor@example.com'],
          format: 'pdf',
          nextDeliveryAt: DateTime.utc(2026, 11, 9, 6),
        );
        await store.save(weekly);
        await store.save(
          TomAuditQuestion(
            id: 'q2',
            name: 'All deletions',
            owner: 'audrey',
            filter: TomAuditQuestionFilter(action: TomAuditAction.delete),
          ),
        );
        await store.save(
          TomAuditQuestion(
            id: 'q3',
            name: 'Theirs',
            owner: 'mallory',
            filter: TomAuditQuestionFilter(),
          ),
        );

        final read = (await TomSqlAuditQuestionStore(
          dsi.datasource,
        ).find('q1'))!;
        expect(read.filter.toJson(), weekly.filter.toJson());
        expect(read.recipients, ['auditor@example.com']);
        expect(read.format, 'pdf');
        expect(read.schedule, '0 6 * * 1');
        expect(read.nextDeliveryAt, DateTime.utc(2026, 11, 9, 6));

        expect(
          [for (final q in await store.ownedBy('audrey')) q.name],
          ['All deletions', 'Denied this week'],
        );
        expect(await store.due(DateTime.utc(2026, 11, 9, 5, 59)), isEmpty);
        expect(
          [for (final q in await store.due(DateTime.utc(2026, 11, 9, 6))) q.id],
          ['q1'],
        );
        expect(await store.remove('q3'), isTrue);
        expect(await store.remove('q3'), isFalse);
      },
    );
  }, skip: skipReason);
}

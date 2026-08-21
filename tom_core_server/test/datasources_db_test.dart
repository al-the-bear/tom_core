/// DB-backed tests for the MariaDB data-source driver (RCK13).
///
/// The connection-free surface (dialect literals/predicates, positional-
/// placeholder rewriting, port parsing, XA lifecycle bookkeeping) is covered by
/// `datasources_test.dart`. This file exercises the parts that *only* a real
/// server can: opening a connection, `executeCommand` returning an affected-row
/// count, `executeQuery` mapping result rows onto a reflected entity,
/// `prepareStatement` binding positional parameters, and the plain
/// (non-XA) transaction lifecycle actually committing or rolling back rows.
///
/// The whole group is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring a
/// server up with `tool/run_db_tests.sh` (or point `TOM_CORE_SERVER_TEST_DB_*`
/// at your own) to run it.
@Tags(['db'])
library;

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

// The reflection root (which now also captures FixtureTaskRecord) and its
// generated bootstrap: `initializeReflection()` populates the global reflection
// data so the row mapper can construct the result entity by mirror.
import 'fixtures/reflection_fixture.dart' show FixtureTaskRecord;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// Reads every `fixture_task` row through the driver's reflection row mapper,
/// so the tests can assert on persisted state without repeating the SELECT.
Future<List<FixtureTaskRecord>> _allTasks(MariaDbDatasource ds) =>
    ds.executeQuery<FixtureTaskRecord>(
      'SELECT id, title, priority, done FROM fixture_task ORDER BY id',
    );

void main() async {
  // Probe once, before declaring the group, so the group can skip when nothing
  // is listening — keeping the default run green with no database.
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('MariaDbDatasource (DB-backed)', () {
    late TomDataSourceInfo dsi;
    late MariaDbDatasource ds;

    setUpAll(() async {
      // Reflection first: the row mapper resolves the result type by mirror and
      // the driver is discovered by scanning @TomDatasourceDriver metadata.
      initializeReflection();
      dsi = await TestDatabase.register();
      ds = dsi.datasource as MariaDbDatasource;
      await TestDatabase.ensureFixtureTaskTable(dsi);
    });

    // Each test starts from an empty table with the AUTO_INCREMENT reset, so id
    // assertions are independent of ordering.
    setUp(() => TestDatabase.truncateFixtureTask(dsi));

    tearDownAll(TestDatabase.reset);

    test('connect opens a live connection', () {
      expect(ds.connected, isTrue);
      expect(ds.isOperational(), isTrue);
    });

    test('executeCommand INSERT reports one affected row', () async {
      final affected = await ds.executeCommand(
        "INSERT INTO fixture_task (title, priority, done) "
        "VALUES ('write', 1, 1)",
      );
      expect(affected, BigInt.one);
    });

    test('executeQuery maps rows onto the reflected entity', () async {
      await ds.executeCommand(
        "INSERT INTO fixture_task (title, priority, done) "
        "VALUES ('map me', 7, 1)",
      );
      final rows = await _allTasks(ds);
      expect(rows, hasLength(1));
      expect(rows.single.title, 'map me');
      expect(rows.single.priority, 7);
      // The Dart bool round-trips through the TINYINT(1) column.
      expect(rows.single.done, isTrue);
      // The AUTO_INCREMENT surrogate is read back as a non-null int.
      expect(rows.single.id, isNotNull);
    });

    test('executeQuery binds named parameters', () async {
      await ds.executeCommand(
        "INSERT INTO fixture_task (title, priority) VALUES ('low', 1)",
      );
      await ds.executeCommand(
        "INSERT INTO fixture_task (title, priority) VALUES ('high', 9)",
      );
      final rows = await ds.executeQuery<FixtureTaskRecord>(
        'SELECT id, title, priority, done FROM fixture_task '
        'WHERE priority = :priority',
        {'priority': 9},
      );
      expect(rows, hasLength(1));
      expect(rows.single.title, 'high');
    });

    test(
      'prepareStatement binds positional parameters and maps rows',
      () async {
        await ds.executeCommand(
          "INSERT INTO fixture_task (title, priority) VALUES ('alpha', 5)",
        );
        await ds.executeCommand(
          "INSERT INTO fixture_task (title, priority) VALUES ('beta', 5)",
        );
        final stmt = await ds.prepareStatement<FixtureTaskRecord>(
          TomLiteralSelect(
            [FixtureTaskRecord],
            query:
                'SELECT id, title, priority, done FROM fixture_task '
                'WHERE priority = :priority ORDER BY title',
            parameters: ['priority'],
          ),
        );
        try {
          final rows = await stmt.execute({'priority': 5});
          expect(rows.map((r) => r.title), ['alpha', 'beta']);
        } finally {
          await stmt.deallocate();
        }
      },
    );

    test('a rolled-back transaction discards its inserts', () async {
      expect(await ds.startTransaction(), isTrue);
      await ds.executeCommand(
        "INSERT INTO fixture_task (title) VALUES ('temporary')",
      );
      await ds.rollback();
      expect(await _allTasks(ds), isEmpty);
    });

    test('a committed transaction persists its inserts', () async {
      expect(await ds.startTransaction(), isTrue);
      await ds.executeCommand(
        "INSERT INTO fixture_task (title) VALUES ('kept')",
      );
      expect(await ds.commit(), isTrue);
      final rows = await _allTasks(ds);
      expect(rows, hasLength(1));
      expect(rows.single.title, 'kept');
    });

    test('startTransaction rejects a second concurrent transaction', () async {
      expect(await ds.startTransaction(), isTrue);
      await expectLater(ds.startTransaction, throwsA(isA<Exception>()));
      // Leave the fixture clean for the next test.
      await ds.rollback();
    });
  }, skip: skipReason);
}

/// DB-backed tests for the MariaDB data-source driver.
///
/// The connection-free surface (dialect literals/predicates, positional-
/// placeholder rewriting, port parsing, XA lifecycle bookkeeping) is covered by
/// `datasources_test.dart`. This file exercises the parts that *only* a real
/// server can: opening a connection, `executeCommand` returning an affected-row
/// count, `executeQuery` mapping result rows onto a reflected entity,
/// `prepareStatement` binding positional parameters, and the plain
/// (non-XA) transaction lifecycle actually committing or rolling back rows.
///
/// It also covers **driver discovery**, which needs no server but does need
/// generated reflection: `createDatasourceOf` resolves a type by scanning
/// `tomReflector.annotatedClasses` for `@TomDatasourceDriver`, which raises
/// "Reflection has not been initialized" in the connection-free suite. This
/// file bootstraps a reflection root, so the scan here is a real scan rather
/// than a stand-in for one.
///
/// The whole group is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring a
/// server up with `tool/run_db_tests.sh` (or point `TOM_CORE_SERVER_TEST_DB_*`
/// at your own) to run it.
@Tags(['db'])
library;

import 'dart:io';

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
      // Against a real server, because this is the one place where the guard
      // and a genuine database refusal are both reachable through the same
      // call: `isA<Exception>()` would pass on either, and so would pass on a
      // driver that had merely fallen over. The module's own type says the
      // start was refused *by the guard*, and the key says why.
      await expectLater(
        ds.startTransaction,
        throwsA(
          isA<MariadbDatasourceException>().having(
            (e) => e.key,
            'key',
            'error.transaction.already_active',
          ),
        ),
      );
      // Leave the fixture clean for the next test.
      await ds.rollback();
    });

    // Driver discovery scans `tomReflector.annotatedClasses` for
    // `@TomDatasourceDriver`, so it needs generated reflection to run at all —
    // which is why it is tested here rather than in `datasources_test.dart`,
    // where the scan raises "Reflection has not been initialized". The scan has
    // already happened by the time these run: `TestDatabase.register` resolved
    // the driver in `setUpAll`, so what is asserted is the populated registry,
    // which is the state a server runs in.
    group('driver discovery', () {
      test('mariadb resolves to the plain driver', () {
        final resolved = TomDataSource.createDatasourceOf('mariadb');
        expect(resolved, isA<MariaDbDatasource>());
        // Not the XA subclass: it *is* a MariaDbDatasource, so a bare isA would
        // pass for either, and the two type names have to resolve apart.
        expect(resolved, isNot(isA<MariaDbXADatasource>()));
      });

      test('mariadb_xa resolves to the XA driver', () {
        expect(
          TomDataSource.createDatasourceOf('mariadb_xa'),
          isA<MariaDbXADatasource>(),
        );
      });

      test('each call returns a fresh data source', () {
        // The registry holds the class, not an instance: two named entries
        // configured with the same driver type must not share a connection.
        final first = TomDataSource.createDatasourceOf('mariadb');
        final second = TomDataSource.createDatasourceOf('mariadb');
        expect(identical(first, second), isFalse);
      });

      test('an unknown type is refused, naming the type', () {
        expect(
          () => TomDataSource.createDatasourceOf('postgres'),
          throwsA(
            isA<TomDatasourceInitException>()
                .having(
                  (e) => e.key,
                  'key',
                  'tom_datasource.create_datasource_of.no_driver_found',
                )
                .having(
                  (e) => e.defaultUserMessage,
                  'message',
                  contains('postgres'),
                ),
          ),
        );
      });

      // The duplicate-driver guard is asserted from the source rather than by
      // running it, and the reason is structural: the scan reads the whole
      // reflected graph, so provoking it means putting a second
      // `@TomDatasourceDriver("mariadb")` class into the fixture — which would
      // make the scan throw on its *first* call, in `setUpAll`, and take every
      // other test in this file with it. A duplicate is a build-time mistake in
      // an application's own graph; what is checkable here is that the scan
      // refuses it rather than letting the second registration win silently.
      test('a duplicate driver is refused rather than overwritten', () {
        final source = File(
          'lib/src/tomserver/datasources/datasource_initialization.dart',
        ).readAsStringSync();
        final scan = source.substring(
          source.indexOf('static void _initializeDatasourceTypes()'),
          source.indexOf('static TomDataSource? createDatasourceOf('),
        );
        // The collision is detected before the map is written, so the first
        // registration stands and the second raises.
        expect(scan, contains('if (_datasourceTypes[driver.type] != null)'));
        expect(
          scan,
          contains(
            'tom_datasource.initialize_datasource_types.duplicate_driver',
          ),
        );
        // And the assignment is in the `else`, so no path overwrites an
        // existing entry.
        expect(
          scan.indexOf('duplicate_driver'),
          lessThan(scan.indexOf('_datasourceTypes[driver.type] = candidate')),
        );
      });
    });
  }, skip: skipReason);
}

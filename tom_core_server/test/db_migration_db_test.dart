/// DB-backed tests for the migration orchestrator + MariaDB adaptor (RCK13).
///
/// The connection-free surface (filename parsing, ascending-version ordering,
/// environment selection, statement splitting) is covered by
/// `db_migration_test.dart`. This file exercises what only a real server can:
/// [TomDbMigrations.migrateDatabases] walking the committed migration tree and
/// [MariadbMigrationAdaptor] creating the `<schema>_versioning` table, running
/// the script, recording the applied version — and skipping it (idempotently)
/// on a second run.
///
/// The migration tree lives under `test/fixtures/migrations/` (committed, not a
/// temp dir), keyed by the registered data-source name so the orchestrator
/// resolves its migrator by the data source's `type`.
///
/// The whole group is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring a
/// server up with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'package:path/path.dart' as p;
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// The committed migration tree root. `migrateDatabases` walks
/// `<root>/<datasourceName>/<schemaName>/[<version>]-<desc>.sql`; the
/// `tom_core_server_test` sub-directory matches the registered data source.
const String _migrationsDir = 'test/fixtures/migrations';

/// The schema directory under the data source; the adaptor maintains a
/// `<schema>_versioning` table for it.
const String _schemaName = 'fixture_schema';

/// A **second** schema under the same data source.
///
/// The fixture tree deliberately carries two, because one schema cannot
/// distinguish a migrator whose applied-version state is per `(data source,
/// schema)` pair from one whose state is per data source — and the second kind
/// aborts the run outright on the second schema, or (with the abort removed)
/// judges the second schema's migrations against the first schema's history.
/// Both fixture schemas are at version 0, which is exactly what a
/// cross-contaminated version list would misread as "already applied".
const String _secondSchemaName = 'fixture_schema_two';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('TomDbMigrations.migrateDatabases (DB-backed)', () {
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      // Reflection first: the migrator is discovered by @TomDbMigrationAdaptor
      // metadata and TomDbVersion rows are mapped by mirror.
      initializeReflection();
      dsi = await TestDatabase.register();
    });

    setUp(() async {
      // Start each test from a clean slate: drop the versioning table and the
      // table the fixture migration creates, so a re-run genuinely re-applies.
      await dsi.datasource.executeCommand(
        'DROP TABLE IF EXISTS ${_schemaName}_versioning',
      );
      await dsi.datasource.executeCommand(
        'DROP TABLE IF EXISTS ${_secondSchemaName}_versioning',
      );
      await dsi.datasource.executeCommand(
        'DROP TABLE IF EXISTS fixture_widget',
      );
      await dsi.datasource.executeCommand(
        'DROP TABLE IF EXISTS fixture_gadget',
      );
    });

    tearDownAll(TestDatabase.reset);

    /// Reads the applied-migration rows the adaptor records for [schema].
    Future<List<TomDbVersion>> appliedVersionsOf(String schema) =>
        dsi.datasource.executeQuery<TomDbVersion>(
          'SELECT installedRank, version, description, checksum, installedBy, '
          'installedOn, executionTimeMs, success, script '
          'FROM ${schema}_versioning ORDER BY installedRank',
        );

    /// Reads the applied-migration rows for the first fixture schema.
    Future<List<TomDbVersion>> appliedVersions() =>
        appliedVersionsOf(_schemaName);

    /// Whether [table] exists in the test database.
    Future<bool> tableExists(String table) async {
      final rows = await dsi.datasource.executeQuery<TomCountResult>(
        'SELECT COUNT(*) AS count FROM information_schema.tables '
        'WHERE table_schema = :schema AND table_name = :table',
        {'schema': TestDatabase.databaseName, 'table': table},
      );
      return rows.single.count == 1;
    }

    test('applies the pending migration and records it as succeeded', () async {
      await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

      final versions = await appliedVersions();
      expect(versions, hasLength(1));
      expect(versions.single.version, 0);
      expect(versions.single.description, 'create_fixture_widget');
      expect(versions.single.success, 1);

      // The migration's own DDL ran: the table it creates now exists.
      expect(await tableExists('fixture_widget'), isTrue);
    });

    test('a second run is idempotent — no duplicate version rows', () async {
      await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));
      await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

      final versions = await appliedVersions();
      // The already-applied version is verified and skipped, not re-inserted.
      expect(versions, hasLength(1));
      expect(versions.single.version, 0);
    });

    // A data source with more than one schema is the shape both this module's
    // guide and TomSchemaConvergenceCheck.checkAll assume works, and it did
    // not: the orchestrator reset the migrator once per data source but
    // initialised it once per schema, so the second schema aborted the whole
    // run with `initialize.initialized_twice`. Removing only that guard would
    // have left the quieter half — the adaptor appended each schema's history
    // to the previous one's, so the second schema's version 0 read as already
    // applied.
    group('a data source with two schemas', () {
      test('applies both schemas in one run', () async {
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

        // Each schema got its own versioning table and its own single row —
        // and each row is the migration belonging to *that* schema, which is
        // what a shared version list would get wrong.
        final first = await appliedVersions();
        expect(first, hasLength(1));
        expect(first.single.version, 0);
        expect(first.single.description, 'create_fixture_widget');
        expect(first.single.success, 1);

        final second = await appliedVersionsOf(_secondSchemaName);
        expect(second, hasLength(1));
        expect(second.single.version, 0);
        expect(second.single.description, 'create_fixture_gadget');
        expect(second.single.success, 1);

        // Both migrations genuinely ran. The second schema is the one at risk:
        // under the cross-contaminated reading its version 0 is "already
        // applied", so its table is never created while the run reports
        // success.
        expect(await tableExists('fixture_widget'), isTrue);
        expect(await tableExists('fixture_gadget'), isTrue);
      });

      test('re-running leaves each schema at its own single version', () async {
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

        expect(await appliedVersions(), hasLength(1));
        expect(await appliedVersionsOf(_secondSchemaName), hasLength(1));
      });

      test('initializeMigration rebinds and replaces the loaded '
          'history', () async {
        // Give both schemas a recorded version 0, so a list that accumulated
        // would hold two rows after the second initialisation rather than one.
        await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

        final adaptor = MariadbMigrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);
        expect(adaptor.versions.map((v) => v.description), [
          'create_fixture_widget',
        ]);

        // The second initialisation used to abort with
        // `initialize.initialized_twice`. It now rebinds — and *replaces* the
        // loaded history rather than adding to it, so what is in hand describes
        // the second schema and nothing else.
        await adaptor.initializeMigration(dsi, _secondSchemaName);
        expect(adaptor.versions.map((v) => v.description), [
          'create_fixture_gadget',
        ]);
      });

      test('refuses to apply a migration against another schema\'s '
          'history', () async {
        final adaptor = MariadbMigrationAdaptor();
        await adaptor.initializeMigration(dsi, _schemaName);

        // Bound to the first schema, asked about the second: the version list
        // in hand cannot answer, and answering from it anyway is the silent
        // half of this defect.
        await expectLater(
          adaptor.applyMigration(
            dsi,
            _secondSchemaName,
            0,
            'create_fixture_gadget',
            'SELECT 1',
          ),
          throwsA(
            isA<MariadbMigrationException>().having(
              (e) => e.key,
              'key',
              'mariadb_migration.apply_migration.not_initialized_for_schema',
            ),
          ),
        );
      });
    });
  }, skip: skipReason);
}

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
      await dsi.datasource
          .executeCommand('DROP TABLE IF EXISTS ${_schemaName}_versioning');
      await dsi.datasource.executeCommand('DROP TABLE IF EXISTS fixture_widget');
    });

    tearDownAll(TestDatabase.reset);

    /// Reads the applied-migration rows the adaptor records for the schema.
    Future<List<TomDbVersion>> appliedVersions() =>
        dsi.datasource.executeQuery<TomDbVersion>(
          'SELECT installedRank, version, description, checksum, installedBy, '
          'installedOn, executionTimeMs, success, script '
          'FROM ${_schemaName}_versioning ORDER BY installedRank',
        );

    test('applies the pending migration and records it as succeeded', () async {
      await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

      final versions = await appliedVersions();
      expect(versions, hasLength(1));
      expect(versions.single.version, 0);
      expect(versions.single.description, 'create_fixture_widget');
      expect(versions.single.success, 1);

      // The migration's own DDL ran: the table it creates now exists.
      final tables = await dsi.datasource.executeQuery<TomCountResult>(
        "SELECT COUNT(*) AS count FROM information_schema.tables "
        "WHERE table_schema = :schema AND table_name = 'fixture_widget'",
        {'schema': TestDatabase.databaseName},
      );
      expect(tables.single.count, 1);
    });

    test('a second run is idempotent — no duplicate version rows', () async {
      await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));
      await TomDbMigrations.migrateDatabases(p.normalize(_migrationsDir));

      final versions = await appliedVersions();
      // The already-applied version is verified and skipped, not re-inserted.
      expect(versions, hasLength(1));
      expect(versions.single.version, 0);
    });
  }, skip: skipReason);
}

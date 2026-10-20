/// The live half of the framework-schema guard.
///
/// `framework_schema_test.dart` proves that a framework table's single
/// declaration agrees with the shipped migration, with the reflected row types,
/// and with the statements the stores issue. All three are readings of the
/// *source tree*, and so all three stay true of a deployment whose database was
/// provisioned correctly once and then edited by hand — the drop of a "redundant"
/// index, the widening of a column, the ALTER applied outside the chain.
///
/// This file is the only variant that can see that. It creates each framework
/// table by the route a deployment would, reads the result back out of
/// `information_schema`, and compares it with the descriptor. It needs a server,
/// so it is `@Tags(['db'])` and skips itself when none is reachable; bring one up
/// with `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
///
/// Both provisioning routes are covered, because a deployment may take either
/// and they must not diverge: the stores' own create-on-first-use, and the
/// reference migration files a DBA applies when the application's credential may
/// not run DDL.
@Tags(['db'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// The migration schema the shipped chains are applied under here.
///
/// Distinct from the name `scheduling_db_test.dart` uses, so the two files'
/// `<schema>_versioning` bookkeeping tables cannot collide when both run.
const String _migrationSchema = 'tomframework';

/// Every shipped migration chain, discovered rather than listed.
///
/// A deployment applies all of them, so this test has to. It used to name four
/// of the seven, and the three it did not name were invisible: the check only
/// reports a table some descriptor claims, so a chain went unapplied for as
/// long as no framework-owned table lived in it. `tom_delivery_report` was the
/// first that did, and even then the failure only surfaced against an **empty**
/// database — on a warm one the table is already there from whichever suite
/// created it, and the missing chain is indistinguishable from an applied one.
///
/// Discovering them removes the whole class: a chain added under
/// `example/<module>/migrations/main/tomcore` is applied here the moment it
/// exists, with nothing to remember. Sorted, so the concatenated version
/// numbers are the same on every run and on every machine.
List<String> _migrationChains() {
  final chains = [
    for (final module in Directory('example').listSync().whereType<Directory>())
      if (Directory(
        '${module.path}/${TestDatabase.referenceMigrations}/main/tomcore',
      ).existsSync())
        '${module.path}/${TestDatabase.referenceMigrations}/main/tomcore',
  ]..sort();
  // The discovery is the point of failure if `example/` is ever restructured,
  // and an empty list would make the migration half of this suite assert
  // nothing while still passing.
  expect(
    chains,
    hasLength(greaterThan(3)),
    reason: 'the shipped migration chains were not found under example/',
  );
  return chains;
}

/// The shipped migration files, laid out the way
/// [TomDbMigrations.migrateDatabases] expects: `<dir>/<datasource>/<schema>/`.
///
/// The **contents** are copied verbatim, so what is applied is the SQL a
/// deployment applies. Only the leading `[n]` is rewritten, because each chain
/// numbers its own files from `[1]` and they are concatenated into one
/// schema here — the migration adapter admits a single initialisation per
/// process, so several schemas cannot be migrated in one call. The position of an
/// artifact within a chain is what the numbering encodes, and concatenating in
/// chain order preserves it.
Directory _migrationDirectory() {
  final root = Directory.systemTemp.createTempSync('tom_framework_migration_');
  final target = Directory(
    '${root.path}/${TestDatabase.datasourceName}/$_migrationSchema',
  )..createSync(recursive: true);
  var version = 0;
  for (final chain in _migrationChains()) {
    final files = Directory(chain).listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final tail = name.substring(name.indexOf(']-') + 2);
      file.copySync('${target.path}/[${++version}]-$tail');
    }
  }
  return root;
}

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  group('the provisioned schema is the schema the descriptors declare', () {
    late TomDataSourceInfo dsi;
    final check = TomFrameworkSchemaCheck();

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
    });

    /// Asserts that [tables], as they currently exist in the database, are what
    /// their descriptors declare.
    Future<void> matchesLiveSchema(List<TomFrameworkTable> tables) async {
      final report = await check.verifyLive(dsi.datasource, tables);
      expect(report.converged, isTrue, reason: report.describe());
    }

    test('what the stores create on first use', () async {
      // Dropped first, so what is measured is what *this* code creates and not
      // what an earlier run happened to leave behind.
      await TestDatabase.dropSchedulingTables(dsi);
      await TestDatabase.dropBlobTables(dsi);
      await TestDatabase.dropOAuthStateTable(dsi);

      await TomSqlJobStore(dsi.datasource).ensureSchema();
      await TomSqlLeaseLock(dsi.datasource).ensureSchema();
      await TomSqlSchedulerNodes(
        dsi.datasource,
        nodeId: 'node-a',
        checkinInterval: const Duration(seconds: 5),
      ).ensureSchema();
      await TomDatabaseBlobStore(dsi.datasource).ensureSchema();
      await TomSqlOAuthStateStore(dsi.datasource).ensureSchema();
      await dsi.datasource.executeCommand(
        'DROP TABLE IF EXISTS $defaultInboxTable',
      );
      await TomSqlInbox(dsi.datasource).ensureSchema();

      await matchesLiveSchema([
        jobRunTable(defaultJobRunTable),
        leaseTable(defaultLeaseTable),
        schedulerNodeTable(defaultSchedulerNodeTable),
        blobManifestTable(defaultBlobManifestTable),
        blobChunkTable(defaultBlobChunkTable),
        oauthStateTable(defaultOAuthStateTable),
        inboxTable(defaultInboxTable),
      ]);
    });

    test('what the shipped migration files build', () async {
      // The other provisioning route. A deployment whose database user may not
      // run DDL applies these files instead, and the two routes must produce
      // the same tables or the guarantee holds for only half of the field.
      await TestDatabase.dropSchedulingTables(dsi);
      await TestDatabase.dropBlobTables(dsi);
      await TestDatabase.dropOAuthStateTable(dsi);
      await dsi.datasource.executeCommand(
        'DROP TABLE IF EXISTS $defaultAuditTrailTable',
      );
      await dsi.datasource.executeCommand(
        'DROP TABLE IF EXISTS ${_migrationSchema}_versioning',
      );

      final directory = _migrationDirectory();
      try {
        await TomDbMigrations.migrateDatabases(directory.path);
      } finally {
        directory.deleteSync(recursive: true);
      }

      await matchesLiveSchema(frameworkOwnedTables());
    });

    test('a hand-edited column is caught', () async {
      // The guard's own proof, and the case no source-tree reading can reach:
      // a table that was provisioned correctly and then altered outside the
      // chain. Without this test the two above would pass equally well against
      // a comparison that reported nothing.
      await TestDatabase.execute(
        dsi.datasource,
        'ALTER TABLE $defaultSchedulerNodeTable '
        'MODIFY COLUMN checkin_interval VARCHAR(32) NOT NULL',
      );
      try {
        final report = await check.verifyLive(dsi.datasource, [
          schedulerNodeTable(defaultSchedulerNodeTable),
        ]);
        expect(report.converged, isFalse);
        expect(
          report.errors.map((e) => e.column),
          contains('checkin_interval'),
          reason: report.describe(),
        );
      } finally {
        await TestDatabase.dropSchedulingTables(dsi);
      }
    });
  }, skip: skip);
}

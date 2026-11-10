/// Tenant tables and system tables against a live database, under every place
/// a tenant's rows can live — the system schema (a shared tenant of the type
/// `default`), its type's shared schema, a schema of its own, a database of its
/// own:
///
/// - a tenant table's rows land where the tenant's data lives, a system
///   table's in the system schema, also when written inside a tenant;
/// - the tenant predicate holds in every model;
/// - one transaction holding a tenant table and a system table runs where
///   they share a data source, is refused where they do not and one of them
///   commits in one phase, and commits in two phases where both are `*_xa`;
/// - sync keeps a tenant table's change log beside the tenant's rows;
/// - retention, run with no tenant, is applied in every tenant.
///
/// The whole file is `@Tags(['db'])` and skips itself when no database is
/// reachable; run it with tool/run_db_tests.sh (MariaDB) or
/// tool/run_db_tests_postgres.sh (PostgreSQL).
@Tags(['db'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const String _tenantNoteDdl = '''
CREATE TABLE IF NOT EXISTS fixture_tenant_note (
  id        BIGINT       NOT NULL AUTO_INCREMENT,
  tenant_id VARCHAR(32)  NULL,
  text      VARCHAR(255) NULL,
  PRIMARY KEY (id)
)''';

const String _systemNoteDdl = '''
CREATE TABLE IF NOT EXISTS fixture_system_note (
  id   BIGINT       NOT NULL AUTO_INCREMENT,
  text VARCHAR(255) NULL,
  PRIMARY KEY (id)
)''';

const String _tenantSyncNoteDdl = '''
CREATE TABLE IF NOT EXISTS fixture_tenant_sync_note (
  id        VARCHAR(64)  NOT NULL,
  tenant_id VARCHAR(32)  NULL,
  version   BIGINT       NOT NULL,
  text      VARCHAR(255) NULL,
  PRIMARY KEY (id)
)''';

const String _tenantVisitDdl = '''
CREATE TABLE IF NOT EXISTS fixture_tenant_visit (
  id         BIGINT      NOT NULL AUTO_INCREMENT,
  tenant_id  VARCHAR(32) NULL,
  visitor_id BIGINT      NULL,
  at         DATETIME(6) NULL,
  PRIMARY KEY (id)
)''';

/// Where the tenants of one group keep their tenant tables.
enum _Placement {
  /// Shared isolation, type `default`: the system schema.
  systemSchema,

  /// Shared isolation, type `standard`: the type's shared schema.
  typeSchema,

  /// A schema of each tenant's own.
  ownSchema,

  /// A database of each tenant's own.
  ownDatabase,
}

Future<int> _count(
  TomDataSourceInfo info,
  String table, [
  String where = '',
]) async {
  final rows = await info.datasource.executeQuery<TomCountResult>(
    'SELECT COUNT(*) AS count FROM $table $where',
  );
  return rows.single.count;
}

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';
  final name = TestDatabase.datasourceName;

  group('tenant tables and system tables', () {
    late TomDataSourceInfo base;
    late Directory trees;

    setUpAll(() async {
      initializeReflection();
      base = await TestDatabase.register();
      for (final ddl in [
        _tenantNoteDdl,
        _systemNoteDdl,
        _tenantSyncNoteDdl,
        _tenantVisitDdl,
      ]) {
        await TestDatabase.execute(base.datasource, ddl);
      }
      trees = Directory.systemTemp.createTempSync('tom_tenant_tables_');
      for (final type in ['default', 'standard']) {
        Directory(
          TomTenantType.treeUnder(trees.path, type),
        ).createSync(recursive: true);
      }
    });

    tearDownAll(() async {
      await TomTenancy.reset();
      trees.deleteSync(recursive: true);
      await TestDatabase.reset();
    });

    for (final placement in _Placement.values) {
      group('placed in ${placement.name}', () {
        late TomTenancy tenancy;
        final schemas = <String>[];
        final databases = <String>[];

        TomDataSourceInfo routed() =>
            TomDataSourceInfo.getDataSourceInfo(name)!;

        setUpAll(() async {
          TomTenant tenant(String id) => switch (placement) {
            _Placement.systemSchema => TomTenant(id),
            _Placement.typeSchema => TomTenant(id, type: 'standard'),
            _Placement.ownSchema => TomTenant(
              id,
              isolation: TomTenantIsolation.schema,
            ),
            _Placement.ownDatabase => TomTenant(
              id,
              isolation: TomTenantIsolation.database,
              datasources: {
                name: {
                  ...(TestDatabase.datasourceConfig[name] as Map)
                      .cast<String, Object>(),
                  'databaseName': '${TestDatabase.databaseName}_tt$id',
                },
              },
            ),
          };
          switch (placement) {
            case _Placement.typeSchema:
              schemas.add('${TestDatabase.databaseName}_standard');
            case _Placement.ownSchema:
              schemas.addAll([
                for (final id in ['acme', 'globex'])
                  '${TestDatabase.databaseName}_$id',
              ]);
            case _Placement.ownDatabase:
              for (final id in ['acme', 'globex']) {
                final database = '${TestDatabase.databaseName}_tt$id';
                databases.add(database);
                await TestDatabase.createDatabase(base.datasource, database);
              }
            case _Placement.systemSchema:
              break;
          }
          tenancy = TomTenancy(
            tenants: [tenant('acme'), tenant('globex')],
            types: [
              for (final type in ['default', 'standard'])
                TomTenantType(
                  type,
                  migrations: TomTenantType.treeUnder(trees.path, type),
                ),
            ],
            datasources: {name},
            createSchemas: true,
          );
          await TomTenancy.install(tenancy);
          // The tenant tables, where each tenant's data lives.
          await tenancy.forEachTenant((_) async {
            for (final ddl in [
              _tenantNoteDdl,
              _tenantSyncNoteDdl,
              _tenantVisitDdl,
            ]) {
              await TestDatabase.execute(routed().datasource, ddl);
            }
          });
        });

        tearDownAll(() async {
          TomSync.reset();
          TomPrivacy.reset();
          await TomTenancy.reset();
          for (final schema in schemas) {
            await TestDatabase.dropSchema(base.datasource, schema);
          }
          for (final database in databases) {
            await TestDatabase.dropDatabase(base.datasource, database);
          }
        });

        setUp(() async {
          for (final table in [
            'fixture_tenant_note',
            'fixture_system_note',
            'fixture_tenant_visit',
          ]) {
            await base.datasource.executeCommand('DELETE FROM $table');
          }
          await tenancy.forEachTenant((_) async {
            for (final table in [
              'fixture_tenant_note',
              'fixture_tenant_visit',
            ]) {
              await routed().datasource.executeCommand('DELETE FROM $table');
            }
          });
        });

        test('TTB-1: tenant rows land where the tenant lives, system rows in '
            'the system schema; the predicate holds in every model', () async {
          final tenantNotes = FixtureTenantNoteRepository();
          final systemNotes = FixtureSystemNoteRepository();
          for (final id in ['acme', 'globex']) {
            await tenancy.runFor(id, () async {
              await tenantNotes.save(FixtureTenantNote()..text = '$id note');
              await systemNotes.save(FixtureSystemNote()..text = '$id entry');
            });
          }
          // A system table is the deployment's, in the system schema: both
          // tenants' entries, seen from either.
          expect(await _count(base, 'fixture_system_note'), 2);
          for (final id in ['acme', 'globex']) {
            expect(
              (await tenancy.runFor(id, systemNotes.findAll)).length,
              2,
              reason: 'a system table is not filtered by tenant',
            );
          }
          // A tenant table is the tenant's, where its data lives.
          final acmeRoute = await tenancy.runFor('acme', routed);
          switch (placement) {
            case _Placement.systemSchema:
              expect(acmeRoute, same(base));
              expect(await _count(base, 'fixture_tenant_note'), 2);
            case _Placement.typeSchema:
              expect(acmeRoute.name, '$name@type.standard');
              expect(await tenancy.runFor('globex', routed), same(acmeRoute));
              expect(await _count(acmeRoute, 'fixture_tenant_note'), 2);
              expect(await _count(base, 'fixture_tenant_note'), 0);
            case _Placement.ownSchema || _Placement.ownDatabase:
              expect(acmeRoute.name, '$name@acme');
              expect(await _count(acmeRoute, 'fixture_tenant_note'), 1);
              expect(await _count(base, 'fixture_tenant_note'), 0);
          }
          // A row of another tenant where acme's data lives stays invisible.
          await acmeRoute.datasource.executeCommand(
            "INSERT INTO fixture_tenant_note (tenant_id, text) "
            "VALUES ('umbrella', 'stray')",
          );
          expect(
            (await tenancy.runFor(
              'acme',
              tenantNotes.findAll,
            )).map((n) => n.text),
            ['acme note'],
          );
        });

        test(
          'TTB-2: one transaction over a tenant table and a system table '
          'runs on one data source and is refused on two one-phase ones',
          () async {
            final tenantNotes = FixtureTenantNoteRepository();
            final systemNotes = FixtureSystemNoteRepository();
            Future<void> both() => tenancy.runFor(
              'acme',
              () => TomTransactionManager.runInTransaction((_) async {
                await tenantNotes.save(FixtureTenantNote()..text = 'in tx');
                await systemNotes.save(FixtureSystemNote()..text = 'in tx');
              }),
            );
            if (placement == _Placement.systemSchema) {
              await both();
              expect(await _count(base, 'fixture_system_note'), 1);
              expect(await _count(base, 'fixture_tenant_note'), 1);
              return;
            }
            await expectLater(
              both(),
              throwsA(
                isA<TomRepositoryException>().having(
                  (e) => e.key,
                  'key',
                  TomSqlDatasourceRepository.tenantSystemTransactionKey,
                ),
              ),
            );
            expect(
              await _count(
                await tenancy.runFor('acme', routed),
                'fixture_tenant_note',
              ),
              0,
              reason: 'the tenant write was rolled back with the transaction',
            );
            expect(await _count(base, 'fixture_system_note'), 0);
          },
        );

        test("TTB-3: sync keeps a tenant table's change log beside the "
            "tenant's rows: each tenant pulls its own changes", () async {
          TomSync.reset();
          await TomSync.expose('tnotes', FixtureTenantSyncNoteRepository());
          final notes = FixtureTenantSyncNoteRepository();
          await tenancy.runFor(
            'acme',
            () => notes.insert(
              FixtureTenantSyncNote()
                ..id = 'n-${placement.name}'
                ..text = 'acme',
            ),
          );
          final acme = await tenancy.runFor(
            'acme',
            () => TomSync.pull('tnotes', 0),
          );
          expect(acme.changes.map((c) => c.id), ['n-${placement.name}']);
          final globex = await tenancy.runFor(
            'globex',
            () => TomSync.pull('tnotes', 0),
          );
          expect(globex.changes, isEmpty);
        });

        test('TTB-4: retention run with no tenant is applied in every '
            'tenant', () async {
          TomPrivacy.reset();
          TomPrivacy.register(FixtureTenantVisitRepository());
          final visits = FixtureTenantVisitRepository();
          final now = DateTime.utc(2026, 11, 10, 12);
          for (final id in ['acme', 'globex']) {
            await tenancy.runFor(id, () async {
              await visits.save(
                FixtureTenantVisit()
                  ..visitorId = 1
                  ..at = now.subtract(const Duration(days: 30)),
              );
              await visits.save(
                FixtureTenantVisit()
                  ..visitorId = 2
                  ..at = now.subtract(const Duration(days: 1)),
              );
            });
          }
          final results = await TomPrivacy.applyRetention(now: now);
          expect(results.single.affected, 2, reason: 'one in each tenant');
          for (final id in ['acme', 'globex']) {
            expect(
              (await tenancy.runFor(
                id,
                visits.findAll,
              )).map((v) => v.visitorId),
              [2],
            );
          }
        });
      });
    }
  }, skip: skipReason);

  group('two-phase data sources', () {
    late TomDataSourceInfo base;

    setUpAll(() async {
      initializeReflection();
      await TestDatabase.provision();
      await TomDataSourceInfo.initializeDatasourceInfo(<String, dynamic>{
        name: <String, dynamic>{
          ...(TestDatabase.datasourceConfig[name] as Map)
              .cast<String, Object>(),
          'type': TestDatabase.isPostgres ? 'postgresql_xa' : 'mariadb_xa',
        },
      });
      base = TomDataSourceInfo.getBaseDataSourceInfo(name)!;
      await TestDatabase.execute(base.datasource, _tenantNoteDdl);
      await TestDatabase.execute(base.datasource, _systemNoteDdl);
    });

    tearDownAll(() async {
      await TomTenancy.reset();
      await TestDatabase.reset();
    });

    test('TTB-5: a schema tenant and the system schema on two-phase data '
        'sources commit in one transaction, two branches', () async {
      final tenancy = TomTenancy(
        tenants: [TomTenant('acme', isolation: TomTenantIsolation.schema)],
        datasources: {name},
        createSchemas: true,
      );
      await TomTenancy.install(tenancy);
      final acmeRoute = await tenancy.runFor(
        'acme',
        () => TomDataSourceInfo.getDataSourceInfo(name)!,
      );
      expect(acmeRoute.datasource, isA<TomSqlTwoPhaseRecovery>());
      await TestDatabase.execute(acmeRoute.datasource, _tenantNoteDdl);
      await tenancy.runFor(
        'acme',
        () => TomTransactionManager.runInTransaction((transaction) async {
          await FixtureTenantNoteRepository().save(
            FixtureTenantNote()..text = 'two-phase',
          );
          await FixtureSystemNoteRepository().save(
            FixtureSystemNote()..text = 'two-phase',
          );
          expect(transaction.participantIds, hasLength(2));
        }),
      );
      expect(await _count(acmeRoute, 'fixture_tenant_note'), 1);
      expect(await _count(base, 'fixture_system_note'), 1);
      // Dropped here, while the suite's database still exists.
      await TomTenancy.reset();
      await TestDatabase.dropSchema(
        base.datasource,
        '${TestDatabase.databaseName}_acme',
      );
    });
  }, skip: skipReason ?? await TestDatabase.twoPhaseSkipReason());
}

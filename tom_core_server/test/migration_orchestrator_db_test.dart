/// `TomDbMigrations.migrateAll` against a real MariaDB or PostgreSQL: two
/// tenant types, three tenants — acme in a schema of its own and globex
/// shared, both of `standard`; initech in a database of its own, of
/// `enterprise` — and initech's migration failing.
///
/// Asserted: the system tree lands in the system schema only; `standard`'s
/// tree once in acme's schema and once in the type's shared schema, each with
/// its own versioning table; initech is `migration-failed` in the SQL registry
/// while the others are active; a tenant repair and a re-run of initech alone
/// bring it to `active`; a tenant rollback undoes acme's migration and leaves
/// the shared schema's.
///
/// The whole file is `@Tags(['db'])` and skips itself when no database is
/// reachable; `tool/run_db_tests.sh` and `tool/run_db_tests_postgres.sh` start
/// one.
@Tags(['db'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('migrateAll: two types, three tenants, one failing', () {
    late TomDataSourceInfo main;
    late Directory root;
    late TomTenancy tenancy;
    late TomSqlTenantRegistry registry;
    final initechDatabase = '${TestDatabase.databaseName}_moinitech';
    final acmeSchema = '${TestDatabase.databaseName}_moacme';
    final sharedSchema = '${TestDatabase.databaseName}_standard';

    void file(String path, String sql) => File(p.join(root.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(sql);

    // The maintenance route: a tenant whose migration failed is not routed
    // for ordinary work, and initech's tables are read while it is.
    Future<TomDataSourceInfo> routed(String tenant) async =>
        tenancy.routeForMaintenance(tenant, main);

    Future<bool> hasTable(TomDataSourceInfo info, String table) async =>
        (await info.datasource.executeQuery<TomCountResult>(
          'SELECT COUNT(*) AS count FROM information_schema.tables '
          'WHERE table_schema = ${info.datasource.sqlDialect.currentSchema} '
          'AND table_name = :t',
          {'t': table},
        )).single.count ==
        1;

    Future<bool> hasColumn(TomDataSourceInfo info, String column) async =>
        (await info.datasource.executeQuery<TomCountResult>(
          'SELECT COUNT(*) AS count FROM information_schema.columns '
          'WHERE table_schema = ${info.datasource.sqlDialect.currentSchema} '
          "AND table_name = 'mo_invoice' AND column_name = :c",
          {'c': column},
        )).single.count ==
        1;

    // The suite database is dropped when this group ends; the tenants'
    // databases and schemas are dropped by the inner group's tearDownAll,
    // which runs first.
    setUpAll(() async {
      initializeReflection();
      await TestDatabase.register();
      await TomDataSourceInfo.initializeDatasourceInfo(<String, dynamic>{
        'main': TestDatabase.datasourceConfig[TestDatabase.datasourceName],
      });
      main = TomDataSourceInfo.getBaseDataSourceInfo('main')!;
    });

    tearDownAll(() async {
      if (reachable) await TestDatabase.reset();
    });

    group('in one run', () {
      setUpAll(() async {
        final base = main;
        for (final table in [
          'mo_system',
          'mo_invoice',
          'tomcore_versioning',
          'tenant_standard_versioning',
        ]) {
          await main.datasource.executeCommand('DROP TABLE IF EXISTS $table');
        }
        await TestDatabase.dropDatabase(base.datasource, initechDatabase);
        await TestDatabase.dropSchema(base.datasource, acmeSchema);
        await TestDatabase.dropSchema(base.datasource, sharedSchema);
        await TestDatabase.createDatabase(base.datasource, initechDatabase);

        root = Directory.systemTemp.createTempSync('tom_migrate_all_db_');
        file(
          'system/main/tomcore/[1]-create_mo_system.sql',
          'CREATE TABLE mo_system (id INT);',
        );
        file(
          'tenant/standard/main/[1]-create_mo_invoice.sql',
          'CREATE TABLE mo_invoice (id INT);',
        );
        file(
          'tenant/standard/main/[1]-create_mo_invoice.down.sql',
          'DROP TABLE mo_invoice;',
        );
        file(
          'tenant/standard/main/[2]-add_mo_invoice_note.sql',
          'ALTER TABLE mo_invoice ADD COLUMN note VARCHAR(20);',
        );
        file(
          'tenant/standard/main/[2]-add_mo_invoice_note.down.sql',
          'ALTER TABLE mo_invoice DROP COLUMN note;',
        );
        // Fails: the table it inserts into does not exist.
        file(
          'tenant/enterprise/main/[1]-create_mo_contract.sql',
          'CREATE TABLE mo_contract (id INT);\n'
              'INSERT INTO mo_missing (id) VALUES (1);',
        );

        registry = TomSqlTenantRegistry(main.datasource);
        await registry.deleteAll();
        tenancy = TomTenancy(
          types: [
            TomTenantType(
              'standard',
              migrations: TomTenantType.treeUnder(root.path, 'standard'),
            ),
            TomTenantType(
              'enterprise',
              migrations: TomTenantType.treeUnder(root.path, 'enterprise'),
            ),
          ],
          tenants: [
            TomTenant(
              'moacme',
              type: 'standard',
              isolation: TomTenantIsolation.schema,
            ),
            TomTenant(
              'moglobex',
              type: 'standard',
              isolation: TomTenantIsolation.shared,
            ),
            TomTenant(
              'moinitech',
              type: 'enterprise',
              isolation: TomTenantIsolation.database,
              datasources: {
                'main': {
                  ...(TestDatabase.datasourceConfig[TestDatabase.datasourceName]
                          as Map)
                      .cast<String, Object>(),
                  'databaseName': initechDatabase,
                },
              },
            ),
          ],
          createSchemas: true,
          registry: registry,
        );
        await TomTenancy.install(tenancy);
      });

      tearDownAll(() async {
        if (!reachable) return;
        await TomTenancy.reset();
        for (final table in [
          'mo_system',
          'mo_invoice',
          'tomcore_versioning',
          'tenant_standard_versioning',
        ]) {
          await main.datasource.executeCommand('DROP TABLE IF EXISTS $table');
        }
        await registry.deleteAll();
        await TestDatabase.dropDatabase(main.datasource, initechDatabase);
        await TestDatabase.dropSchema(main.datasource, acmeSchema);
        await TestDatabase.dropSchema(main.datasource, sharedSchema);
        TomDbMigrations.resetRuns();
        root.deleteSync(recursive: true);
      });

      test('MOD-1: the system schema, the shared schema, then each tenant; the '
          'failing one is marked and the others are active', () async {
        final result = await TomDbMigrations.migrateAll(root.path);

        expect(result.runs.map((r) => r.target), [
          'system',
          'shared:standard',
          'tenant:moacme',
          'tenant:moinitech',
        ]);
        expect(result.failed.map((r) => r.target), ['tenant:moinitech']);

        final acme = await routed('moacme');
        final globex = await routed('moglobex');
        final initech = await routed('moinitech');
        expect(await hasTable(main, 'mo_system'), isTrue);
        expect(
          await hasTable(main, 'mo_invoice'),
          isFalse,
          reason: 'tenant tables stay out of the system schema',
        );
        expect(await hasTable(acme, 'mo_system'), isFalse);
        for (final info in [acme, globex]) {
          expect(await hasColumn(info, 'note'), isTrue, reason: info.name);
          expect(
            await hasTable(info, 'tenant_standard_versioning'),
            isTrue,
            reason: 'each target keeps its own versioning table',
          );
        }

        final records = {for (final r in await registry.all()) r.id: r};
        expect(records['moacme']!.status, TomTenantStatus.active);
        expect(records['moacme']!.migrated, {'main': 2, 'main/requires': 2});
        expect(records['moglobex']!.status, TomTenantStatus.active);
        expect(records['moinitech']!.status, TomTenantStatus.migrationFailed);
        expect(records['moinitech']!.statusDetail, isNotEmpty);
        expect(tenancy.statusOf('moinitech'), TomTenantStatus.migrationFailed);
        expect(await hasTable(initech, 'tenant_enterprise_versioning'), isTrue);
      }, skip: skipReason);

      test(
        'MOD-2: a tenant repair and a re-run of the tenant alone bring it to '
        'active',
        () async {
          file(
            'tenant/enterprise/main/[1]-create_mo_contract.sql',
            'CREATE TABLE IF NOT EXISTS mo_contract (id INT);',
          );
          // MariaDB keeps the failed record of a script it could not roll
          // back and refuses the tenant until it is repaired; PostgreSQL
          // rolled the script back and recorded nothing, so a re-run is all
          // it needs.
          if (!TestDatabase.isPostgres) {
            expect(
              await TomDbMigrations.repairFromArgs([
                '--repair-migration=tenant:moinitech/main/1',
                '--repair-action=remove',
              ]),
              isTrue,
            );
          }
          final result = await TomDbMigrations.migrateFromArgs([
            '--migrate-tenant=moinitech',
          ], root.path);
          expect(result!.runs.map((r) => r.target), ['tenant:moinitech']);
          expect(result.succeeded, isTrue);
          expect(
            (await registry.find('moinitech'))!.status,
            TomTenantStatus.active,
          );
          expect(
            await hasTable(await routed('moinitech'), 'mo_contract'),
            isTrue,
          );
        },
        skip: skipReason,
      );

      test('MOD-3: a tenant rollback undoes its own target only', () async {
        expect(
          await TomDbMigrations.rollbackFromArgs([
            '--rollback-migrations=tenant:moacme/main/1',
          ], root.path),
          isTrue,
        );
        expect(await hasColumn(await routed('moacme'), 'note'), isFalse);
        expect(await hasColumn(await routed('moglobex'), 'note'), isTrue);

        // And applied again by the next run.
        final again = await TomDbMigrations.migrateAll(root.path);
        expect(again.succeeded, isTrue);
        expect(await hasColumn(await routed('moacme'), 'note'), isTrue);
      }, skip: skipReason);

      test('MOD-4: the version guard reads the versioning tables and the '
          'registry: every schema is current', () async {
        final migrator = TomDbMigrations.newMigratorFor(main);
        expect(await migrator.appliedScripts(main, 'tomcore'), {
          1: 'CREATE TABLE mo_system (id INT);',
        });
        expect(
          await migrator.appliedScripts(main, 'no_such_history'),
          isEmpty,
          reason: 'a history never migrated, and no table created for it',
        );
        final system = await TomDbMigrations.guardSystemSchema(root.path);
        expect(system.skew, TomSchemaSkew.current);
        expect(system.code, {'main/tomcore': 1});

        await tenancy.checkSchemaVersions();
        for (final id in ['moacme', 'moglobex', 'moinitech']) {
          expect(
            tenancy.schemaCheckOf(id)!.skew,
            TomSchemaSkew.current,
            reason: id,
          );
        }
      }, skip: skipReason);
    });
  }, skip: skipReason);
}

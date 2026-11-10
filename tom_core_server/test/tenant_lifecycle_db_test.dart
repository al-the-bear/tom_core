/// The tenant lifecycle against a real MariaDB or PostgreSQL: a schema tenant
/// onboarded in one call — provisioned and migrated by its type's tree; a
/// tenant whose migration fails left `migration-failed` and brought back by
/// `migrateTenant`; removal cancelling its queued runs and closing its pool;
/// the purge dropping its schema and deleting its system-table records, and
/// a shared tenant's purge deleting its rows only; and the tenant pools
/// opening no connection until used and closing them when idle.
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

Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('the tenant lifecycle', () {
    late TomDataSourceInfo main;

    // The suite database is dropped when this group ends; the tenants'
    // schemas by the inner group's tearDownAll, which runs first.
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

    group('in one deployment', () {
      late Directory root;
      late TomTenancy tenancy;
      late TomSqlTenantRegistry registry;
      late TomSqlJobStore jobs;
      late TomDatabaseBlobStore blobs;
      final database = TestDatabase.databaseName;
      final schemas = [
        for (final id in [
          'lcacme',
          'lcbroken',
          'lclazy1',
          'lclazy2',
          for (var i = 0; i < 12; i++) 'lcload$i',
        ])
          '${database}_$id',
        '${database}_standard',
      ];

      void file(String path, String sql) => File(p.join(root.path, path))
        ..createSync(recursive: true)
        ..writeAsStringSync(sql);

      Future<TomDataSourceInfo> routed(String tenant) => tenancy.runFor(
        tenant,
        () async => TomDataSourceInfo.getDataSourceInfo('main')!,
      );

      Future<bool> hasTable(TomDataSourceInfo info, String table) async =>
          (await info.datasource.executeQuery<TomCountResult>(
            'SELECT COUNT(*) AS count FROM information_schema.tables '
            'WHERE table_schema = ${info.datasource.sqlDialect.currentSchema} '
            'AND table_name = :t',
            {'t': table},
          )).single.count ==
          1;

      Future<bool> schemaExists(String schema) async =>
          (await main.datasource.executeQuery<TomCountResult>(
            'SELECT COUNT(*) AS count FROM information_schema.schemata '
            'WHERE schema_name = :s',
            {'s': schema},
          )).single.count ==
          1;

      int openConnections(TomDataSourceInfo info) =>
          (info.datasource as TomSqlDatasource).openConnectionCount;

      setUpAll(() async {
        for (final schema in schemas) {
          await TestDatabase.dropSchema(main.datasource, schema);
        }
        root = Directory.systemTemp.createTempSync('tom_lifecycle_db_');
        file(
          'tenant/standard/main/[1]-create_lc_note.sql',
          'CREATE TABLE lc_note (id INT, tenant_id VARCHAR(32));',
        );
        // Fails: the table it inserts into does not exist.
        file(
          'tenant/broken/main/[1]-create_lc_contract.sql',
          'CREATE TABLE lc_contract (id INT);\n'
              'INSERT INTO lc_missing (id) VALUES (1);',
        );
        registry = TomSqlTenantRegistry(main.datasource);
        await registry.deleteAll();
        jobs = TomSqlJobStore(main.datasource);
        await jobs.deleteAll();
        blobs = TomDatabaseBlobStore(main.datasource);
        tenancy = TomTenancy(
          types: [
            for (final type in ['standard', 'broken'])
              TomTenantType(
                type,
                migrations: TomTenantType.treeUnder(root.path, type),
              ),
          ],
          tenants: const [],
          datasources: {'main'},
          createSchemas: true,
          registry: registry,
          pool: const TomTenantPoolSettings(
            perTenant: 2,
            idleTimeout: Duration(seconds: 1),
          ),
        );
        await TomTenancy.install(tenancy);
      });

      tearDownAll(() async {
        if (!reachable) return;
        await TomTenancy.reset();
        for (final schema in schemas) {
          await TestDatabase.dropSchema(main.datasource, schema);
        }
        await registry.deleteAll();
        await jobs.deleteAll();
        TomDbMigrations.resetRuns();
        root.deleteSync(recursive: true);
      });

      test('LCD-1: addTenant provisions, migrates and serves a schema tenant '
          'in one call', () async {
        final run = await tenancy.addTenant(
          TomTenant(
            'lcacme',
            type: 'standard',
            isolation: TomTenantIsolation.schema,
          ),
        );
        expect(run!.state, TomMigrationRunState.succeeded);
        expect(tenancy.statusOf('lcacme'), TomTenantStatus.active);
        expect((await registry.find('lcacme'))!.migrated, {
          'main': 1,
          'main/requires': 1,
        });
        final acme = await routed('lcacme');
        expect(acme.name, 'main@lcacme');
        expect(await hasTable(acme, 'lc_note'), isTrue);
        expect(await hasTable(main, 'lc_note'), isFalse);
      }, skip: skipReason);

      test('LCD-2: a failing migration leaves the tenant migration-failed and '
          'unrouted; repaired and migrated again, it is served', () async {
        await expectLater(
          tenancy.addTenant(
            TomTenant(
              'lcbroken',
              type: 'broken',
              isolation: TomTenantIsolation.schema,
            ),
          ),
          _throwsKey('tenancy.tenant.migration_failed'),
        );
        expect(tenancy.statusOf('lcbroken'), TomTenantStatus.migrationFailed);
        expect(
          (await registry.find('lcbroken'))!.status,
          TomTenantStatus.migrationFailed,
        );
        await expectLater(
          routed('lcbroken'),
          _throwsKey('tenancy.tenant.migration_failed'),
        );

        file(
          'tenant/broken/main/[1]-create_lc_contract.sql',
          'CREATE TABLE IF NOT EXISTS lc_contract (id INT);',
        );
        if (!TestDatabase.isPostgres) {
          // MariaDB recorded the failed script; PostgreSQL rolled it back.
          await TomDbMigrations.repairTenant(
            'lcbroken',
            'main',
            1,
            TomMigrationRepair.remove,
          );
        }
        final run = await tenancy.migrateTenant('lcbroken');
        expect(run!.state, TomMigrationRunState.succeeded);
        expect(tenancy.statusOf('lcbroken'), TomTenantStatus.active);
        expect(await hasTable(await routed('lcbroken'), 'lc_contract'), isTrue);
      }, skip: skipReason);

      test('LCD-3: removal cancels the queued runs and closes the pool; the '
          'purge drops the schema and deletes the records', () async {
        final at = DateTime.now().toUtc();
        await jobs.enqueue(
          TomJobRun(
            id: 'lc-acme',
            jobName: 'job',
            scheduledFor: at,
            runAt: at,
            tenant: 'lcacme',
          ),
        );
        await tenancy.runFor(
          'lcacme',
          () => blobs.put(key: 'lc-acme-file', bytes: Stream.value([1, 2])),
        );

        await tenancy.removeTenant('lcacme', jobStores: [jobs]);
        final run = (await jobs.findRun('lc-acme'))!;
        expect(run.state, TomJobRunState.failed);
        expect(run.lastError, TomJobStore.tenantRemovedError);
        expect(
          TomDataSourceInfo.datasources.containsKey('main@lcacme'),
          isFalse,
        );
        expect(await schemaExists('${database}_lcacme'), isTrue);

        await expectLater(
          tenancy.purgeTenant('lcacme'),
          _throwsKey('tenancy.purge.retention'),
        );
        final report = await tenancy.purgeTenant(
          'lcacme',
          force: true,
          stores: [blobs],
          jobStores: [jobs],
        );
        expect(report.dropped, ['main: schema ${database}_lcacme']);
        expect(await schemaExists('${database}_lcacme'), isFalse);
        expect(await jobs.findRun('lc-acme'), isNull);
        expect(await blobs.keysOfTenant('lcacme'), isEmpty);
        expect(await registry.find('lcacme'), isNull);
      }, skip: skipReason);

      test('LCD-4: a shared tenant\'s purge deletes its rows in the shared '
          'schema and leaves the others\'', () async {
        for (final id in ['lcglobex', 'lcinitech']) {
          await tenancy.addTenant(
            TomTenant(
              id,
              type: 'standard',
              isolation: TomTenantIsolation.shared,
            ),
          );
        }
        final shared = await routed('lcglobex');
        expect(shared.name, 'main@type.standard');
        final inbox = inboxTable(defaultInboxTable);
        await inbox.create(shared.datasource);
        for (final id in ['lcglobex', 'lcinitech']) {
          await shared.datasource.executeCommand(
            'INSERT INTO $defaultInboxTable '
            '(tenant, consumer, message_id, processed_at) '
            "VALUES (:t, 'billing', 'm-1', :at)",
            {'t': id, 'at': sqlInstant(DateTime.now().toUtc())},
          );
        }

        await tenancy.removeTenant('lcglobex');
        final report = await tenancy.purgeTenant('lcglobex', force: true);
        expect(report.deleted[defaultInboxTable], 1);
        final left = await shared.datasource.executeQuery<TomCountResult>(
          'SELECT COUNT(*) AS count FROM $defaultInboxTable',
        );
        expect(left.single.count, 1, reason: "lcinitech's row stays");
        expect(await schemaExists('${database}_standard'), isTrue);
      }, skip: skipReason);

      test('LCD-5: a tenant pool opens no connection until used, and closes '
          'its idle ones', () async {
        for (final id in ['lclazy1', 'lclazy2']) {
          await tenancy.addTenant(
            TomTenant(
              id,
              type: 'standard',
              isolation: TomTenantIsolation.schema,
            ),
          );
        }
        // Installed again — as a node starting — the tenants' pools open
        // without a connection.
        final again = TomTenancy(
          types: tenancy.types.values,
          tenants: const [],
          datasources: {'main'},
          createSchemas: true,
          registry: registry,
          pool: const TomTenantPoolSettings(
            perTenant: 2,
            idleTimeout: Duration(seconds: 1),
          ),
        );
        await TomTenancy.install(again);
        tenancy = again;
        final pools = [
          for (final id in ['lclazy1', 'lclazy2']) await routed(id),
        ];
        expect(pools.map(openConnections), [0, 0]);

        for (final pool in pools) {
          await pool.datasource.executeCommand('SELECT 1');
        }
        expect(pools.map(openConnections), [1, 1]);

        await Future<void>.delayed(const Duration(milliseconds: 2500));
        expect(pools.map(openConnections), [
          0,
          0,
        ], reason: 'closed by the idle sweep, with no statement since');
      }, skip: skipReason);

      test('LCD-6: under load each tenant pool stays within its size, and an '
          'idle deployment holds no tenant connection', () async {
        final ids = [for (var i = 0; i < 12; i++) 'lcload$i'];
        for (final id in ids) {
          await tenancy.addTenant(
            TomTenant(
              id,
              type: 'standard',
              isolation: TomTenantIsolation.schema,
            ),
          );
        }
        final pools = [for (final id in ids) await routed(id)];
        // Wait out the connections the migrations left.
        await Future<void>.delayed(const Duration(milliseconds: 2500));
        expect(pools.map(openConnections).every((n) => n == 0), isTrue);

        // 12 tenants, 10 concurrent statements each.
        var peak = 0;
        final watch = Stopwatch()..start();
        await Future.wait([
          for (final pool in pools)
            for (var i = 0; i < 10; i++)
              pool.datasource
                  .executeQuery<TomCountResult>(
                    'SELECT COUNT(*) AS count FROM lc_note',
                  )
                  .then((_) {
                    final open = pools
                        .map(openConnections)
                        .reduce((a, b) => a + b);
                    if (open > peak) peak = open;
                  }),
        ]);
        watch.stop();
        printOnFailure(
          'LCD-6 measurement: 120 statements over 12 tenant pools in '
          '${watch.elapsedMilliseconds} ms, peak $peak connections',
        );
        expect(peak, lessThanOrEqualTo(12 * 2));
        expect(pools.every((pool) => openConnections(pool) <= 2), isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 2500));
        expect(pools.map(openConnections).every((n) => n == 0), isTrue);
      }, skip: skipReason);
    });
  }, skip: skipReason);
}

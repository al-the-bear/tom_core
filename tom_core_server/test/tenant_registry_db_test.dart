/// The SQL tenant registry against a live database: the table in the system
/// schema, the round trip of every field, and two nodes over one registry — a
/// schema-isolated tenant added on one is provisioned, routed and dropped by
/// the other at its refresh.
///
/// The whole file is `@Tags(['db'])` and skips itself when no database is
/// reachable; run it with tool/run_db_tests.sh (MariaDB) or
/// tool/run_db_tests_postgres.sh (PostgreSQL).
@Tags(['db'])
library;

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

  group('the SQL tenant registry', () {
    late TomDataSourceInfo base;
    final name = TestDatabase.datasourceName;
    final schemas = <String>[];

    setUpAll(() async {
      initializeReflection();
      base = await TestDatabase.register();
    });

    tearDownAll(() async {
      await TomTenancy.reset();
      await TestDatabase.reset();
    });

    setUp(() async {
      await TomTenancy.reset();
      await TomSqlTenantRegistry.named(name).deleteAll();
    });

    test('TRD-1: every field survives the round trip, and status and versions '
        'change in place', () async {
      final registry = TomSqlTenantRegistry.named(name);
      final created = DateTime.utc(2026, 11, 10, 9, 30, 15, 123, 456);
      await registry.put(
        TomTenantRecord(
          id: 'initech',
          type: 'enterprise',
          name: 'Initech GmbH',
          isolation: TomTenantIsolation.database,
          datasources: {
            name: {'host': 'db.eu', 'password': 'secret:vault:db#pw'},
            'audit': 'shared_audit',
          },
          status: TomTenantStatus.provisioning,
          createdAt: created,
          updatedAt: created,
        ),
      );
      final read = (await registry.find('initech'))!;
      expect(read.type, 'enterprise');
      expect(read.name, 'Initech GmbH');
      expect(read.isolation, TomTenantIsolation.database);
      expect(read.schema, isNull);
      expect(read.datasources, {
        name: {'host': 'db.eu', 'password': 'secret:vault:db#pw'},
        'audit': 'shared_audit',
      });
      expect(read.status, TomTenantStatus.provisioning);
      expect(read.createdAt, created);

      final later = created.add(const Duration(minutes: 5));
      await registry.setStatus(
        'initech',
        TomTenantStatus.migrationFailed,
        detail: 'migration 3 failed',
        at: later,
      );
      await registry.setMigrated('initech', '$name/app', 2, at: later);
      final changed = (await registry.find('initech'))!;
      expect(changed.status, TomTenantStatus.migrationFailed);
      expect(changed.statusDetail, 'migration 3 failed');
      expect(changed.migrated, {'$name/app': 2});
      expect(changed.createdAt, created);
      expect(changed.updatedAt, later);
      expect((await registry.all()).map((r) => r.id), ['initech']);
    });

    test('TRD-2: install seeds the registry in the system schema; a second '
        "node's schema-isolated tenant is provisioned, routed and dropped at "
        'the refresh', () async {
      final registry = TomSqlTenantRegistry.named(name);
      final schema = '${TestDatabase.databaseName}_globex';
      schemas.add(schema);

      final nodeA = TomTenancy(
        tenants: [TomTenant('acme')],
        datasources: {name},
        createSchemas: true,
        registry: registry,
      );
      await TomTenancy.install(nodeA);
      expect((await registry.all()).map((r) => (r.id, r.status)), [
        ('acme', TomTenantStatus.active),
      ]);

      // Another node, sharing only the registry table.
      final nodeB = TomTenancy(
        tenants: const [],
        datasources: {name},
        createSchemas: true,
        registry: TomSqlTenantRegistry.named(name),
      );
      await nodeB.addTenant(
        TomTenant('globex', isolation: TomTenantIsolation.schema),
      );
      expect((await registry.find('globex'))!.status, TomTenantStatus.active);

      final refresh = await nodeA.refreshFromRegistry();
      expect(refresh.added, ['globex']);
      final routed = await TomTenantContext.run(
        'globex',
        () async => TomDataSourceInfo.getDataSourceInfo(name)!,
      );
      expect(routed.name, '$name@globex');
      expect((routed.datasource as TomSqlDatasource).schemaName, schema);
      // The registry is read unrouted, also inside the tenant.
      final insideTenant = await TomTenantContext.run(
        'globex',
        () => registry.all(),
      );
      expect(insideTenant.map((r) => r.id), ['acme', 'globex']);

      await nodeB.removeTenant('globex');
      final dropped = await nodeA.refreshFromRegistry();
      expect(dropped.removed, ['globex']);
      expect(
        TomDataSourceInfo.datasources.containsKey('$name@globex'),
        isFalse,
      );
      expect(nodeA.tenants.keys, {'acme'});
      await TomTenancy.reset();
      // nodeB was never installed; close what it opened.
      for (final info in List.of(TomDataSourceInfo.datasources.values)) {
        if (info.name.contains('@')) {
          TomDataSourceInfo.datasources.remove(info.name);
          await info.datasource.close();
        }
      }
      // Dropped here, while the suite's database still exists: the fixture
      // drops the database itself when the group ends.
      for (final schema in schemas) {
        await TestDatabase.dropSchema(base.datasource, schema);
      }
    });
  }, skip: skipReason);
}

/// Tenant types against a live database: the shared-isolation tenants of one
/// type share one tenant schema, reached through one pool, so the type's tree
/// is applied to it once however many shared tenants it holds; a shared tenant
/// of the type `default` stays in the system schema, and a schema tenant of the
/// same type has its own.
///
/// The whole file is `@Tags(['db'])` and skips itself when no database is
/// reachable; run it with tool/run_db_tests.sh (MariaDB) or
/// tool/run_db_tests_postgres.sh (PostgreSQL).
@Tags(['db'])
library;

import 'dart:io';

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

  group('a type shares one schema among its shared tenants', () {
    late TomDataSourceInfo base;
    final name = TestDatabase.datasourceName;

    setUpAll(() async {
      initializeReflection();
      base = await TestDatabase.register();
    });

    tearDownAll(() async {
      await TomTenancy.reset();
      await TestDatabase.reset();
    });

    test('TTD-1: two shared tenants of one type reach one schema, a migration '
        'applied once serves both; the default type stays in the system '
        'schema, and a schema tenant has its own', () async {
      final shared = '${TestDatabase.databaseName}_standard';
      final own = '${TestDatabase.databaseName}_initech';
      final tree = Directory.systemTemp.createTempSync('tom_tenant_types_');
      addTearDown(() => tree.deleteSync(recursive: true));

      final tenancy = TomTenancy(
        tenants: [
          TomTenant('acme', type: 'standard'),
          TomTenant('globex', type: 'standard'),
          TomTenant(
            'initech',
            type: 'standard',
            isolation: TomTenantIsolation.schema,
          ),
          TomTenant('umbrella'),
        ],
        types: [
          TomTenantType(TomTenant.defaultType, migrations: tree.path),
          TomTenantType(
            'standard',
            isolation: TomTenantIsolation.shared,
            migrations: tree.path,
          ),
        ],
        datasources: {name},
        createSchemas: true,
      );
      try {
        await TomTenancy.install(tenancy);
        TomDataSourceInfo reach(String tenant) => TomTenantContext.run(
          tenant,
          () => TomDataSourceInfo.getDataSourceInfo(name)!,
        );
        final acme = reach('acme');
        expect(acme.name, '$name@type.standard');
        expect((acme.datasource as TomSqlDatasource).schemaName, shared);
        expect(reach('globex'), same(acme), reason: 'one pool for the type');
        expect(reach('umbrella'), same(base), reason: 'the system schema');
        final initech = reach('initech');
        expect(initech.name, '$name@initech');
        expect((initech.datasource as TomSqlDatasource).schemaName, own);

        // The type's tree, applied once — here through acme's route.
        await acme.datasource.executeCommand(
          'CREATE TABLE tt_widget (tenant_id VARCHAR(32) NOT NULL, '
          'label VARCHAR(64) NOT NULL)',
        );
        for (final tenant in ['acme', 'globex']) {
          await reach(tenant).datasource.executeCommand(
            "INSERT INTO tt_widget (tenant_id, label) VALUES ('$tenant', 'w')",
          );
        }
        // globex's route sees acme's row too: one table, one schema.
        expect(
          await reach(
            'globex',
          ).datasource.executeCommand("UPDATE tt_widget SET label = 'x'"),
          BigInt.two,
        );

        // Removing one shared tenant leaves the type's pool to the others.
        await tenancy.removeTenant('acme');
        expect(
          TomDataSourceInfo.datasources.containsKey('$name@type.standard'),
          isTrue,
        );
        expect(
          await reach(
            'globex',
          ).datasource.executeCommand("UPDATE tt_widget SET label = 'y'"),
          BigInt.two,
        );
      } finally {
        await TomTenancy.reset();
        // Dropped here, while the suite's database still exists.
        for (final schema in [shared, own]) {
          await TestDatabase.dropSchema(base.datasource, schema);
        }
      }
    });
  }, skip: skipReason);
}

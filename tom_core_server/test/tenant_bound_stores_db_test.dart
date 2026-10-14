/// The framework stores that follow the tenant, against a real MariaDB, under
/// each of the three isolation models: the SQL SCIM store over a routed data
/// source name, and the SQL pending sign-in state store's tenant predicate.
///
/// SCIM: two tenants' identity providers create a user of the same `userName`
/// and each lists only its own — in each tenant's schema or database under
/// `schema` and `database`, in the one table under `shared`, where the tenant
/// column is the wall. The state table is deployment-wide in every model, so a
/// record is kept apart by its tenant column alone.
///
/// The whole file is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable; `tool/run_db_tests.sh` starts one.
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
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('tenant-bound stores', () {
    late TomDataSourceInfo base;

    setUpAll(() async {
      initializeReflection();
      base = await TestDatabase.register();
      // Registered as a data source of its own (not an alias) so tenancy can
      // route it like any other: a schema or a database per tenant.
      await TomDataSourceInfo.initializeDatasourceInfo(<String, dynamic>{
        'main': TestDatabase.datasourceConfig[TestDatabase.datasourceName],
      });
    });

    tearDownAll(() async {
      await TomTenancy.reset();
      await TestDatabase.reset();
    });

    for (final isolation in TomTenantIsolation.values) {
      group('isolated by ${isolation.name}', () {
        late TomTenancy tenancy;
        final extraDatabases = <String>[];

        setUpAll(() async {
          TomTenant tenant(String id) {
            if (isolation != TomTenantIsolation.database) {
              return TomTenant(id, isolation: isolation);
            }
            final database = '${TestDatabase.databaseName}_tdb$id';
            extraDatabases.add(database);
            return TomTenant(
              id,
              isolation: isolation,
              datasources: {
                'main': {
                  ...(TestDatabase.datasourceConfig[TestDatabase.datasourceName]
                          as Map)
                      .cast<String, Object>(),
                  'databaseName': database,
                },
              },
            );
          }

          final tenants = [tenant('acme'), tenant('globex')];
          if (isolation == TomTenantIsolation.schema) {
            for (final id in ['acme', 'globex']) {
              extraDatabases.add('${TestDatabase.databaseName}_$id');
            }
          }
          if (isolation == TomTenantIsolation.database) {
            for (final database in extraDatabases) {
              await base.datasource.executeCommand(
                'CREATE DATABASE IF NOT EXISTS `$database`',
              );
            }
          }
          tenancy = TomTenancy(
            tenants: tenants,
            datasources: {'main'},
            createSchemas: true,
          );
          await TomTenancy.install(tenancy);
        });

        tearDownAll(() async {
          await TomTenancy.reset();
          for (final database in extraDatabases) {
            await base.datasource.executeCommand(
              'DROP DATABASE IF EXISTS `$database`',
            );
          }
        });

        test('SCIM: each tenant\'s client sees only its own users', () async {
          final store = TomSqlScimStore.named('main');
          await tenancy.forEachTenant((_) => store.deleteAll());

          Future<List<String>> names(String tenant) => tenancy.runFor(
            tenant,
            () async => [
              for (final r in await store.list(TomScimResourceType.user))
                r.nameKey,
            ]..sort(),
          );

          await tenancy.runFor(
            'acme',
            () => store.create(TomScimResourceType.user, {'userName': 'alice'}),
          );
          // The same userName in the other tenant is another user, not a
          // uniqueness conflict.
          await tenancy.runFor(
            'globex',
            () => store.create(TomScimResourceType.user, {'userName': 'alice'}),
          );
          final globexBob = await tenancy.runFor(
            'globex',
            () => store.create(TomScimResourceType.user, {'userName': 'bob'}),
          );

          expect(await names('acme'), ['alice']);
          expect(await names('globex'), ['alice', 'bob']);
          // acme has no user of bob's id: under shared the row is globex's,
          // under schema and database acme's table has no such id.
          expect(
            await tenancy.runFor(
              'acme',
              () => store.read(TomScimResourceType.user, globexBob.id),
            ),
            isNull,
            reason: 'acme cannot read globex\'s user by its id',
          );
          expect(
            await tenancy.runFor(
              'acme',
              () => store.delete(TomScimResourceType.user, globexBob.id),
            ),
            isFalse,
            reason: 'nor delete it',
          );
          expect(await names('globex'), ['alice', 'bob']);

          // Where the rows land: one table under shared, each tenant's own
          // under schema and database.
          final routed = await tenancy.runFor(
            'acme',
            () async => TomDataSourceInfo.getDataSourceInfo('main')!.datasource,
          );
          final rows = await routed.executeQuery<TomCountResult>(
            'SELECT COUNT(*) AS count FROM tom_scim_resource',
          );
          expect(
            rows.single.count,
            isolation == TomTenantIsolation.shared ? 3 : 1,
          );
        });

        test(
          'sign-in state: a flow is completed only in its own tenant',
          () async {
            // The state table is deployment-wide: built over the base data
            // source, not routed.
            final store = TomSqlOAuthStateStore(base.datasource);
            await store.deleteAll();
            await tenancy.runFor(
              'acme',
              () => store.store(
                TomOAuthAuthorizationState(
                  state: 'flow-1',
                  providerId: 'staff',
                  createdAt: DateTime.now().toUtc(),
                ),
              ),
            );

            expect(
              await tenancy.runFor('globex', () => store.peek('flow-1')),
              isNull,
            );
            expect(
              await tenancy.runFor('globex', () => store.consume('flow-1')),
              isNull,
            );
            expect(await store.consume('flow-1'), isNull);
            final record = await tenancy.runFor(
              'acme',
              () => store.consume('flow-1'),
            );
            expect(record?.tenant, 'acme');
            expect(
              await tenancy.runFor('acme', () => store.consume('flow-1')),
              isNull,
              reason: 'spent once',
            );
          },
        );
      });
    }
  }, skip: skipReason);
}

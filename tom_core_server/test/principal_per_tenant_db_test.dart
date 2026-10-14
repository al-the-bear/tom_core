/// One principal id in two tenants, against a real MariaDB, under each of the
/// three isolation models: `alice` with id `u1` in `acme` and `alice` with id
/// `u1` in `globex` are two people, and the framework's per-principal tables
/// keep their rows apart.
///
/// A principal id is unique within its tenant only. Under `schema` and
/// `database` isolation the tables are each tenant's own; under `shared` both
/// tenants' rows sit in one table, and the tenant-qualified key
/// ([TomPrincipal.qualifiedId]) is what keeps them apart. The same assertions
/// run under every model, and the stored key is the same in every model too.
///
/// The whole file is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable; `tool/run_db_tests.sh` starts one.
@Tags(['db'])
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// `alice`, id `u1`, bound to [tenant] — the same username and the same id in
/// every tenant.
TomPrincipal _alice(String tenant) => TomPrincipal(
  authenticated: true,
  tenant: tenant,
  user: TomUser(id: 'u1', username: 'alice'),
  aci: TomAccessControlInformation(roles: const ['user']),
);

/// Strips a framework DDL's statement terminator; the driver takes one
/// statement and rejects the trailing `;`.
String _ddl(String createTableSql) {
  final ddl = createTableSql.trim();
  return ddl.endsWith(';') ? ddl.substring(0, ddl.length - 1) : ddl;
}

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('one principal id in two tenants', () {
    late TomDataSourceInfo base;

    setUpAll(() async {
      initializeReflection();
      base = await TestDatabase.register();
      // The framework entities declare `datasource: 'main'`. Registered as a
      // data source of its own (not an alias) so tenancy can route it like any
      // other: a schema or a database per tenant.
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

        TomDataSourceInfo main() =>
            TomDataSourceInfo.getDataSourceInfo('main')!;

        setUpAll(() async {
          TomTenant tenant(String id) {
            if (isolation != TomTenantIsolation.database) {
              return TomTenant(id, isolation: isolation);
            }
            final database = '${TestDatabase.databaseName}_pdb$id';
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
          for (final database in extraDatabases) {
            if (isolation == TomTenantIsolation.database) {
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
          await tenancy.forEachTenant((_) async {
            await main().datasource.executeCommand(
              _ddl(TomUserTwoFactorEnrolment.createTableSql),
            );
            await main().datasource.executeCommand(
              _ddl(TomUserPreference.createTableSql),
            );
          });
        });

        tearDownAll(() async {
          await TomTenancy.reset();
          for (final database in extraDatabases) {
            await base.datasource.executeCommand(
              'DROP DATABASE IF EXISTS `$database`',
            );
          }
        });

        setUp(() async {
          await tenancy.forEachTenant((_) async {
            await main().datasource.executeCommand(
              'DELETE FROM tom_user_two_factor_enrolment',
            );
            await main().datasource.executeCommand(
              'DELETE FROM tom_user_preference',
            );
          });
        });

        /// Runs [body] in [tenant] as that tenant's `alice`.
        Future<T> asAlice<T>(String tenant, Future<T> Function() body) =>
            tenancy.runFor(
              tenant,
              () => runZoned(
                body,
                zoneValues: <Object, Object?>{TomPrincipal: _alice(tenant)},
              ),
            );

        /// The `principal_id` of every enrolment [tenant]'s data source
        /// holds — read with raw SQL, past every scope.
        Future<List<String>> storedFactorKeys(String tenant) =>
            tenancy.runFor(tenant, () async {
              final rows = await main().datasource
                  .executeQuery<TomUserTwoFactorEnrolment>(
                    'SELECT id, principal_id, enrolment_id, mechanism, hint, '
                    'enrolled_at, is_primary, secret_data '
                    'FROM tom_user_two_factor_enrolment ORDER BY principal_id',
                  );
              return [for (final row in rows) row.principalId];
            });

        /// The `principal_id` of every preference [tenant]'s data source
        /// holds — read with raw SQL, past every scope.
        Future<List<String>> storedPreferenceKeys(String tenant) =>
            tenancy.runFor(tenant, () async {
              final rows = await main().datasource
                  .executeQuery<TomUserPreference>(
                    'SELECT id, principal_id, preference_key, value_type, '
                    'value_json, updated_at '
                    'FROM tom_user_preference ORDER BY principal_id',
                  );
              return [for (final row in rows) row.principalId];
            });

        test('2FA: each tenant\'s alice keeps her own factors', () async {
          Future<List<String>> factors(String tenant) => asAlice(
            tenant,
            () async => [
              for (final e in await TomPersistent2FAEnrolmentStore(
                TomUserTwoFactorEnrolmentRepository(),
              ).enrolmentsFor(Tom2FAContext(principal: _alice(tenant))))
                e.enrolmentId,
            ],
          );

          await asAlice('acme', () async {
            await TomPersistent2FAEnrolmentStore(
              TomUserTwoFactorEnrolmentRepository(),
            ).store(
              Tom2FAContext(principal: _alice('acme')),
              Tom2FAEnrolment(type: 'totp', enrolmentId: 'acme-phone'),
            );
          });
          expect(await factors('acme'), ['acme-phone']);
          expect(
            await factors('globex'),
            isEmpty,
            reason: 'globex\'s alice is another person',
          );

          await asAlice('globex', () async {
            await TomPersistent2FAEnrolmentStore(
              TomUserTwoFactorEnrolmentRepository(),
            ).store(
              Tom2FAContext(principal: _alice('globex')),
              Tom2FAEnrolment(type: 'totp', enrolmentId: 'globex-phone'),
            );
          });
          expect(await factors('acme'), ['acme-phone']);
          expect(await factors('globex'), ['globex-phone']);

          // Under shared both rows sit in one table; under schema and database
          // each tenant's own table holds its own. The key is the same in every
          // model, so moving a tenant between models is a copy of its rows.
          if (isolation == TomTenantIsolation.shared) {
            expect(await storedFactorKeys('acme'), [
              'tenant:acme/u1',
              'tenant:globex/u1',
            ]);
          } else {
            expect(await storedFactorKeys('acme'), ['tenant:acme/u1']);
            expect(await storedFactorKeys('globex'), ['tenant:globex/u1']);
          }
        });

        test('preferences: each tenant\'s alice reads her own', () async {
          Future<void> setTheme(String tenant, String theme) => asAlice(
            tenant,
            () => TomUserPreferences(
              TomUserPreferenceRepository(),
            ).set<String>('device.theme', theme),
          );
          Future<String?> theme(String tenant) => asAlice(
            tenant,
            () => TomUserPreferences(
              TomUserPreferenceRepository(),
            ).get<String>('device.theme'),
          );

          await setTheme('acme', 'dark');
          expect(await theme('acme'), 'dark');
          expect(await theme('globex'), isNull);

          await setTheme('globex', 'light');
          expect(await theme('acme'), 'dark');
          expect(await theme('globex'), 'light');

          if (isolation == TomTenantIsolation.shared) {
            expect(await storedPreferenceKeys('acme'), [
              'tenant:acme/u1',
              'tenant:globex/u1',
            ]);
          } else {
            expect(await storedPreferenceKeys('acme'), ['tenant:acme/u1']);
            expect(await storedPreferenceKeys('globex'), ['tenant:globex/u1']);
          }
        });
      });
    }
  }, skip: skipReason);
}

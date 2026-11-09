/// How many SQL statements one request makes for its row scope, pinned.
///
/// A request reading grant-scoped rows asks the row scope once per statement,
/// and the scope reads the caller's grants and delegations from their tables.
/// Inside a request (`TomRequestCache.run`, as the endpoint pipeline runs every
/// handler) the two reads happen once; a write in the request drops them, so a
/// grant the request itself wrote is seen by its next read.
///
/// The group is `@Tags(['db'])` and skips itself when no database is
/// reachable; `tool/run_db_tests.sh` and `tool/run_db_tests_postgres.sh` run it.
@Tags(['db'])
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

class _Grants
    extends TomSqlDatasourceRepository<TomPrincipalResourceGrant, int> {}

class _Delegations
    extends TomSqlDatasourceRepository<TomPrincipalDelegation, int> {}

TomPrincipal _principal(int id) => TomPrincipal(
  authenticated: true,
  user: TomUser(id: '$id', username: 'user$id'),
  aci: TomAccessControlInformation(roles: const ['user']),
);

/// The statements every data source has executed, from the statement-duration
/// histogram every statement records into — preparing one is recorded as an
/// operation of its own and not counted.
Future<int> _statements() async {
  var count = 0;
  for (final family in await TomMetrics.registry.collect()) {
    if (family.name != tomDbStatementDurationMetric) continue;
    for (final point in family.points) {
      if (point.labels['operation'] == 'prepare') continue;
      count += point.histogram?.count ?? 0;
    }
  }
  return count;
}

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('the statements of one request', () {
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.registerMainAlias();
      await TestDatabase.ensureFixtureResourceTable(dsi);
      for (final ddl in [
        TomPrincipalResourceGrant.createTableSql,
        TomPrincipalDelegation.createTableSql,
      ]) {
        final statement = ddl.trim();
        await TestDatabase.execute(
          dsi.datasource,
          statement.endsWith(';')
              ? statement.substring(0, statement.length - 1)
              : statement,
        );
      }
    });

    setUp(() async {
      await TestDatabase.truncateFixtureResource(dsi);
      await TestDatabase.execute(
        dsi.datasource,
        'DELETE FROM tom_principal_resource_grant',
      );
      await TestDatabase.execute(
        dsi.datasource,
        'DELETE FROM tom_principal_delegation',
      );
      TomResourceRoleRegistry.reset();
      TomResourceRoleRegistry.registerAll({
        'owner': TomAuthState.full,
        'viewer': TomAuthState.read,
      });
      TomResourceDataScope.install(
        TomDelegationResolver(
          RepositoryPrincipalDelegationStore(_Delegations()),
          TomPrincipalResourceRoleResolver(
            RepositoryPrincipalResourceGrantStore(_Grants()),
          ),
        ),
      );
      await _Grants().save(
        TomPrincipalResourceGrant(
          principalId: '1',
          resourceKey: 'project:alpha',
          role: 'owner',
        ),
      );
      await dsi.datasource.executeCommand(
        'INSERT INTO fixture_resource_document (resource_key, title) '
        "VALUES ('project:alpha', 'Alpha plan')",
      );
    });

    tearDown(() {
      TomResourceDataScope.uninstall();
      TomResourceRoleRegistry.reset();
    });

    tearDownAll(TestDatabase.reset);

    /// Three scoped reads as user 1, in a request when [inRequest].
    Future<int> threeReads({required bool inRequest}) async {
      Future<void> reads() => runZoned(() async {
        final documents = FixtureResourceRepository();
        expect(await documents.findAll(), hasLength(1));
        expect(await documents.findAll(), hasLength(1));
        expect((await documents.count()).get(), 1);
      }, zoneValues: {TomPrincipal: _principal(1)});
      final before = await _statements();
      await (inRequest ? TomRequestCache.run(reads) : reads());
      return await _statements() - before;
    }

    test('RS-1: within a request the grants and delegations are read once: '
        'three scoped reads make five statements', () async {
      expect(await threeReads(inRequest: true), 5);
    });

    test('RS-2: outside a request each scoped read reads them again: nine '
        'statements', () async {
      expect(await threeReads(inRequest: false), 9);
    });

    test('RS-3: a write in the request drops what it read, so a grant the '
        'request wrote is seen by its next read', () async {
      await dsi.datasource.executeCommand(
        'INSERT INTO fixture_resource_document (resource_key, title) '
        "VALUES ('project:beta', 'Beta plan')",
      );
      await TomRequestCache.run(
        () => runZoned(() async {
          final documents = FixtureResourceRepository();
          expect(await documents.findAll(), hasLength(1));
          await _Grants().save(
            TomPrincipalResourceGrant(
              principalId: '1',
              resourceKey: 'project:beta',
              role: 'owner',
            ),
          );
          expect(await documents.findAll(), hasLength(2));
        }, zoneValues: {TomPrincipal: _principal(1)}),
      );
    });
  }, skip: skipReason);
}

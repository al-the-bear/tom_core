/// Tenant tables and system tables without a database: the classification
/// (`@TomTenantTable`) and the set the analyzer reports, the refusal of a
/// statement mixing the two kinds, the data source a repository picks for
/// each, the tenant tenant-table work runs as, and the framework's own tenant
/// tables.
///
/// Every isolation model against MariaDB and PostgreSQL, transactions, sync
/// and retention are `test/tenant_table_db_test.dart`.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

const String _name = 'tom_core_server_test';

Matcher _refusedWith(String key) =>
    throwsA(isA<TomException>().having((e) => e.key, 'key', key));

/// The eight framework entities that hold a tenant's data.
const List<Type> _frameworkTenantTables = [
  TomUserPreference,
  TomPreferenceDefault,
  TomResourceGrant,
  TomPrincipalResourceGrant,
  TomPrincipalDelegation,
  TomUserTwoFactorEnrolment,
  TomExternalIdentityLink,
  TomExternalIdentityToken,
];

void main() {
  setUpAll(initializeReflection);
  tearDown(TomTenancy.reset);

  group('the classification', () {
    test('TC-1: @TomTenantTable makes a tenant table, everything else is a '
        'system table; the analyzer reports the tenant tables', () {
      expect(TomAnnotationAnalyzer.isTenantTable(FixtureTenantNote), isTrue);
      expect(TomAnnotationAnalyzer.isTenantTable(FixtureSystemNote), isFalse);
      expect(
        TomAnnotationAnalyzer.findTenantTable(FixtureTenantNote)!.field,
        'tenantId',
      );
      final tables = TomTenancy.tenantTables;
      expect(tables[FixtureTenantNote]!.table, 'fixture_tenant_note');
      expect(tables, isNot(contains(FixtureSystemNote)));
      expect(tables.keys, containsAll(_frameworkTenantTables));
      expect(
        tables.keys,
        isNot(contains(FixtureMixedReferenceRecord)),
        reason: 'a class without @TomDbTable maps no table',
      );
    });

    test("TC-2: the framework's per-tenant entities are tenant tables with a "
        'tenant_id column leading their unique keys', () {
      for (final type in _frameworkTenantTables) {
        final info = TomAnnotationAnalyzer.analysePersistentType(type);
        expect(
          info.columnInfo.map((c) => c.column?.columnName),
          contains('tenant_id'),
          reason: '$type',
        );
      }
      for (final ddl in [
        TomUserPreference.createTableSql,
        TomPreferenceDefault.createTableSql,
        TomResourceGrant.createTableSql,
        TomPrincipalResourceGrant.createTableSql,
        TomUserTwoFactorEnrolment.createTableSql,
        TomExternalIdentityLink.createTableSql,
        TomExternalIdentityToken.createTableSql,
      ]) {
        expect(
          ddl,
          contains("tenant_id VARCHAR(32) NOT NULL DEFAULT 'default'"),
        );
        expect(ddl, matches(RegExp(r'UNIQUE KEY \w+ \(tenant_id, ')));
      }
      expect(
        TomPrincipalDelegation.createTableSql,
        contains('KEY idx_tom_principal_delegation_tenant (tenant_id)'),
      );
    });
  });

  group('a tenant table and a system table never meet in one statement', () {
    setUp(() {
      TomDataSourceInfo.datasources[_name] = TomDataSourceInfo(_name, const {});
      addTearDown(() => TomDataSourceInfo.datasources.remove(_name));
    });

    test('TC-3: an association, a subquery and a repository over both kinds '
        'are refused when analysed', () {
      expect(
        () => TomAnnotationAnalyzer.getPersistentColumns(
          FixtureMixedReferenceRecord,
        ),
        _refusedWith('annotation_analyzer.tenant_table.mixed'),
      );
      expect(
        () => TomSubquery([FixtureTenantNote, FixtureSystemNote]),
        _refusedWith('annotation_analyzer.tenant_table.mixed'),
      );
      expect(
        () => TomTestRepository([FixtureSystemNote, FixtureTenantNote]),
        _refusedWith('annotation_analyzer.tenant_table.mixed'),
      );
      // One kind is fine.
      expect(TomSubquery([FixtureTenantNote]).types, [FixtureTenantNote]);
    });

    test("TC-4: a subquery over the other kind in a repository's query is "
        'refused before anything runs', () async {
      final repository = FixtureSystemNoteRepository();
      final query = TomSelect([
        FixtureSystemNote,
      ], query: repository.exists(TomSubquery([FixtureTenantNote])));
      await expectLater(
        repository.findByQuery(query, const {}),
        _refusedWith('annotation_analyzer.tenant_table.mixed'),
      );
    });

    test("TC-5: a subquery over tenant tables binds the enclosing query's "
        'tenant', () {
      final subquery = TomSubquery([FixtureTenantNote]);
      final dialect = MariadbSqlDialect();
      expect(subquery.generate(dialect), contains('tenant_id'));
      expect(subquery.getParameters(dialect), [
        '${TomSqlDatasourceRepository.tenantParameterPrefix}0',
      ]);
      expect(
        TomSubquery([FixtureSystemNote]).getParameters(dialect),
        isEmpty,
        reason: 'a system table binds no tenant',
      );
    });
  });

  group('the data source a repository picks', () {
    final registered = <String>[_name, 'acme_db'];

    setUp(() {
      for (final name in registered) {
        TomDataSourceInfo.datasources[name] = TomDataSourceInfo(name, const {});
      }
      addTearDown(() {
        for (final name in registered) {
          TomDataSourceInfo.datasources.remove(name);
        }
      });
    });

    test('TC-6: inside a tenant a tenant table reaches its route and a system '
        'table the registered data source, unrouted', () async {
      await TomTenancy.install(
        TomTenancy(
          tenants: [
            TomTenant(
              'acme',
              isolation: TomTenantIsolation.database,
              datasources: {_name: 'acme_db'},
            ),
          ],
          datasources: {_name},
        ),
      );
      final tenantNotes = FixtureTenantNoteRepository();
      final systemNotes = FixtureSystemNoteRepository();
      await TomTenantContext.run('acme', () async {
        expect(tenantNotes.isTenantTable, isTrue);
        expect(tenantNotes.datasourceInfo.name, 'acme_db');
        expect(systemNotes.isTenantTable, isFalse);
        expect(systemNotes.datasourceInfo.name, _name);
      });
      // With no tenant: the system table works, the tenant table is refused.
      expect(systemNotes.datasourceInfo.name, _name);
      expect(
        () => tenantNotes.datasourceInfo,
        _refusedWith('tenancy.context.missing'),
      );
      expect(
        () => TomTenancy.tenantForWork('invoices'),
        _refusedWith('tenancy.context.missing'),
      );
    });

    test('TC-7: without a tenancy, tenant-table work runs as the implicit '
        'tenant default, on the registered data source', () {
      expect(TomTenancy.current, isNull);
      expect(TomTenancy.implicitTenant, 'default');
      expect(TomTenancy.tenantForWork('invoices'), 'default');
      expect(FixtureTenantNoteRepository().datasourceInfo.name, _name);
      expect(
        TomTenantContext.run('acme', () => TomTenancy.tenantForWork('x')),
        'acme',
        reason: 'a tenant in context is used as it is',
      );
    });
  });
}

/// A repository over several entity types, for TC-3.
class TomTestRepository
    extends TomSqlDatasourceRepository<FixtureSystemNote, int> {
  TomTestRepository(List<Type> types) : super(types);
}

/// Tenant types without a database: the implicit type, `tenancy.types` read
/// from configuration, the refusals (an unknown type, a type without a
/// migration tree, an isolation the type does not allow, a type changed in
/// place), and the data sources a type routes.
///
/// One shared schema per type, against MariaDB and PostgreSQL, is
/// `test/tenant_type_db_test.dart`.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A scratch migrations root holding a tree for each of [names].
String _root(List<String> names) {
  final root = Directory.systemTemp.createTempSync('tom_tenant_types_');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final name in names) {
    Directory(
      TomTenantType.treeUnder(root.path, name),
    ).createSync(recursive: true);
  }
  return root.path;
}

/// A declared type with a migration tree.
TomTenantType _type(
  String name, {
  TomTenantIsolation? isolation,
  Set<TomTenantIsolation>? isolations,
  Set<String>? datasources,
}) => TomTenantType(
  name,
  isolation: isolation,
  isolations: isolations,
  datasources: datasources,
  migrations: TomTenantType.treeUnder(_root([name]), name),
);

Matcher _refusedWith(String key) =>
    throwsA(isA<TomTenancyException>().having((e) => e.key, 'key', key));

TomTenancy _configured(Map<String, Object?> tenancy) =>
    TomTenancy.fromConfiguration(
      TomServerConfigResourceProvider.from({'tenancy': tenancy}),
    );

void main() {
  tearDown(TomTenancy.reset);

  group('the implicit type', () {
    test('TT-1: a deployment that declares no types has the type default, '
        'allowing every model and routing its data sources, with no tree to '
        'check', () async {
      final tenancy = TomTenancy(
        tenants: [TomTenant('acme')],
        datasources: const {'main'},
      );
      expect(tenancy.typesDeclared, isFalse);
      expect(tenancy.types.keys, [TomTenant.defaultType]);
      final type = tenancy.types[TomTenant.defaultType]!;
      expect(type.isolations, TomTenantIsolation.values.toSet());
      expect(type.migrations, isNull);
      expect(tenancy.datasourcesOf(type), {'main'});
      expect(tenancy.typeOf(tenancy.tenants['acme']!), same(type));
      await TomTenancy.install(tenancy);
      expect(TomTenancy.current, same(tenancy));
    });
  });

  group('the configuration', () {
    test('TT-2: tenancy.types declares each type, its tree under '
        'tenancy.migrations unless it names its own', () {
      final tenancy = _configured({
        'datasources': ['main'],
        'migrations': 'migrations',
        'types': {
          'standard': {
            'isolation': 'shared',
            'isolations': ['shared', 'schema'],
          },
          'enterprise': {
            'isolation': 'database',
            'datasources': ['main', 'reporting'],
            'migrations': 'enterprise_tree',
          },
        },
        'tenants': {
          'acme': {'type': 'standard'},
          'initech': {'type': 'enterprise'},
        },
      });
      expect(tenancy.typesDeclared, isTrue);
      final standard = tenancy.types['standard']!;
      expect(standard.isolation, TomTenantIsolation.shared);
      expect(standard.isolations, {
        TomTenantIsolation.shared,
        TomTenantIsolation.schema,
      });
      expect(standard.datasources, isNull);
      expect(tenancy.datasourcesOf(standard), {'main'});
      expect(standard.migrations, 'migrations/tenant/standard');
      final enterprise = tenancy.types['enterprise']!;
      expect(enterprise.isolations, TomTenantIsolation.values.toSet());
      expect(enterprise.datasources, {'main', 'reporting'});
      expect(enterprise.migrations, 'enterprise_tree');
      expect(tenancy.routedDatasources, {'main', 'reporting'});
      expect(
        tenancy.isolationOf(tenancy.tenants['initech']!),
        TomTenantIsolation.database,
        reason: "the type's default",
      );
      expect(tenancy.tenants['acme']!.type, 'standard');
    });

    test('TT-3: a type name that is not one, a default isolation the type '
        'does not allow, and types that are not a map are refused', () {
      expect(
        () => _configured({
          'types': {'Standard': <String, Object?>{}},
        }),
        _refusedWith('tenancy.type.invalid'),
      );
      expect(
        () => _configured({
          'types': {
            'standard': {
              'isolation': 'database',
              'isolations': ['shared'],
            },
          },
        }),
        _refusedWith('tenancy.type.isolation_not_allowed'),
      );
      expect(
        () => _configured({'types': 'standard'}),
        _refusedWith('tenancy.config.not_a_map'),
      );
    });
  });

  group('install', () {
    test('TT-4: a declared type without a migration tree refuses the start, '
        'before anything is seeded', () async {
      final registry = TomMemoryTenantRegistry();
      final missing = TomTenancy(
        tenants: [TomTenant('acme', type: 'standard')],
        types: [
          TomTenantType(
            'standard',
            migrations: '${_root(const [])}/tenant/standard',
          ),
        ],
        registry: registry,
      );
      await expectLater(
        TomTenancy.install(missing),
        _refusedWith('tenancy.type.missing_migrations'),
      );
      final unnamed = TomTenancy(
        tenants: const [],
        types: [TomTenantType('standard')],
        registry: registry,
      );
      await expectLater(
        TomTenancy.install(unnamed),
        _refusedWith('tenancy.type.missing_migrations'),
      );
      expect(await registry.all(), isEmpty);
      expect(TomTenancy.current, isNull);
    });

    test(
      'TT-5: a configured tenant of an unknown type is refused and not '
      'seeded; a registry row of an unknown type refuses the start',
      () async {
        final registry = TomMemoryTenantRegistry();
        final configured = TomTenancy(
          tenants: [TomTenant('acme', type: 'premium')],
          types: [_type('standard', datasources: const {})],
          registry: registry,
        );
        await expectLater(
          TomTenancy.install(configured),
          _refusedWith('tenancy.type.unknown'),
        );
        expect(await registry.all(), isEmpty);

        final at = DateTime.utc(2026, 11, 10);
        await registry.put(
          TomTenantRecord(
            id: 'globex',
            type: 'premium',
            status: TomTenantStatus.active,
            createdAt: at,
            updatedAt: at,
          ),
        );
        final registered = TomTenancy(
          tenants: const [],
          types: [_type('standard', datasources: const {})],
          registry: registry,
        );
        await expectLater(
          TomTenancy.install(registered),
          _refusedWith('tenancy.type.unknown'),
        );
      },
    );

    test('TT-6: a tenant whose isolation its type does not allow is refused, '
        'at install and when added', () async {
      final shared = _type(
        'standard',
        isolations: const {TomTenantIsolation.shared},
        datasources: const {},
      );
      await expectLater(
        TomTenancy.install(
          TomTenancy(
            tenants: [
              TomTenant(
                'acme',
                type: 'standard',
                isolation: TomTenantIsolation.schema,
              ),
            ],
            types: [shared],
          ),
        ),
        _refusedWith('tenancy.type.isolation_not_allowed'),
      );

      final registry = TomMemoryTenantRegistry();
      final tenancy = TomTenancy(
        tenants: const [],
        types: [shared],
        registry: registry,
      );
      await TomTenancy.install(tenancy);
      await expectLater(
        tenancy.addTenant(
          TomTenant(
            'globex',
            type: 'standard',
            isolation: TomTenantIsolation.database,
          ),
        ),
        _refusedWith('tenancy.type.isolation_not_allowed'),
      );
      await expectLater(
        tenancy.addTenant(TomTenant('initech', type: 'premium')),
        _refusedWith('tenancy.type.unknown'),
      );
      expect(await registry.all(), isEmpty, reason: 'nothing recorded');
    });
  });

  group('a type is not changed in place', () {
    test('TT-7: adding a tenant the registry holds under another type is '
        'refused; a removed one may come back as another type', () async {
      final registry = TomMemoryTenantRegistry();
      final tenancy = TomTenancy(
        tenants: [TomTenant('acme', type: 'standard')],
        types: [
          _type('standard', datasources: const {}),
          _type('enterprise', datasources: const {}),
        ],
        registry: registry,
      );
      await TomTenancy.install(tenancy);
      await expectLater(
        tenancy.addTenant(TomTenant('acme', type: 'enterprise')),
        _refusedWith('tenancy.type.change'),
      );
      expect((await registry.find('acme'))!.type, 'standard');
      expect(tenancy.tenants['acme']!.type, 'standard');

      await tenancy.removeTenant('acme');
      await tenancy.addTenant(TomTenant('acme', type: 'enterprise'));
      expect((await registry.find('acme'))!.type, 'enterprise');
    });

    test('TT-8: a registry row of an unknown type that another node wrote is '
        'reported by the refresh and not served', () async {
      final registry = TomMemoryTenantRegistry();
      final tenancy = TomTenancy(
        tenants: const [],
        types: [_type('standard', datasources: const {})],
        registry: registry,
      );
      await TomTenancy.install(tenancy);
      final at = DateTime.utc(2026, 11, 10);
      await registry.put(
        TomTenantRecord(
          id: 'globex',
          type: 'premium',
          status: TomTenantStatus.active,
          createdAt: at,
          updatedAt: at,
        ),
      );
      final refresh = await tenancy.refreshFromRegistry();
      expect(refresh.added, isEmpty);
      expect(
        refresh.failed['globex'],
        isA<TomTenancyException>().having(
          (e) => e.key,
          'key',
          'tenancy.type.unknown',
        ),
      );
      expect(tenancy.tenants, isNot(contains('globex')));
    });
  });

  group('routing per type', () {
    late TomDataSourceInfo main;
    late TomDataSourceInfo reporting;

    setUp(() {
      main = TomDataSourceInfo('main', const {});
      reporting = TomDataSourceInfo('reporting', const {});
      TomDataSourceInfo.datasources['main'] = main;
      TomDataSourceInfo.datasources['reporting'] = reporting;
      addTearDown(() {
        TomDataSourceInfo.datasources.remove('main');
        TomDataSourceInfo.datasources.remove('reporting');
      });
    });

    test('TT-9: a tenant is routed on the data sources its type routes, and '
        'only those', () async {
      for (final name in ['acme_main', 'initech_main', 'initech_reporting']) {
        TomDataSourceInfo.datasources[name] = TomDataSourceInfo(name, const {});
        addTearDown(() => TomDataSourceInfo.datasources.remove(name));
      }
      final tenancy = TomTenancy(
        tenants: [
          TomTenant(
            'acme',
            type: 'standard',
            datasources: {'main': 'acme_main'},
          ),
          TomTenant(
            'initech',
            type: 'enterprise',
            datasources: {
              'main': 'initech_main',
              'reporting': 'initech_reporting',
            },
          ),
        ],
        types: [
          _type(
            'standard',
            isolation: TomTenantIsolation.database,
            datasources: const {'main'},
          ),
          _type(
            'enterprise',
            isolation: TomTenantIsolation.database,
            datasources: const {'main', 'reporting'},
          ),
        ],
      );
      await TomTenancy.install(tenancy);
      String reach(String tenant, String name) => TomTenantContext.run(
        tenant,
        () => TomDataSourceInfo.getDataSourceInfo(name)!.name,
      );
      expect(reach('acme', 'main'), 'acme_main');
      expect(
        reach('acme', 'reporting'),
        'reporting',
        reason: 'its type does not route reporting',
      );
      expect(reach('initech', 'main'), 'initech_main');
      expect(reach('initech', 'reporting'), 'initech_reporting');
    });

    test('TT-10: shared tenants of the default type stay on the base data '
        "source; a type's shared schema is <databaseName>_<type>, and a "
        "schema tenant may not take it", () async {
      expect(TomTenantType(TomTenant.defaultType).sharedSchema('app'), isNull);
      expect(TomTenantType('standard').sharedSchema('app'), 'app_standard');

      TomDataSourceInfo.datasources['app'] = TomDataSourceInfo('app', const {
        'databaseName': 'app',
      });
      addTearDown(() => TomDataSourceInfo.datasources.remove('app'));
      await expectLater(
        TomTenancy.install(
          TomTenancy(
            tenants: [
              TomTenant(
                'acme',
                type: 'standard',
                isolation: TomTenantIsolation.schema,
                schema: 'app_standard',
              ),
            ],
            types: [
              _type('standard', datasources: const {'app'}),
            ],
          ),
        ),
        _refusedWith('tenancy.config.schema_collision'),
      );
    });
  });
}

/// What a server's start makes of tenancy (`TomTenancyStartup.configure`):
/// a plain application, the implicit tenant, or a configured tenancy, and the
/// contradictions refused with their keys — without a database (the tenants
/// are shared, the registry in memory).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart' show FixtureTenantNote;
import 'fixtures/reflection_fixture.reflection.dart';

Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

const _ds = 'tom_core_server_test';

void main() {
  setUpAll(initializeReflection);

  late Directory root;
  late Map<Type, TomDbTable> notes;

  TomServerConfigResourceProvider config([
    Map<String, Object?> map = const {},
  ]) => TomServerConfigResourceProvider.from(map);

  void chain(String type, String datasource, {bool createsNote = true}) {
    final dir = Directory(p.join(root.path, 'tenant', type, datasource))
      ..createSync(recursive: true);
    File(p.join(dir.path, '[1]-create.sql')).writeAsStringSync(
      createsNote
          ? 'CREATE TABLE fixture_tenant_note (id BIGINT, '
                'tenant_id VARCHAR(32), text VARCHAR(255));'
          : 'CREATE TABLE something_else (id BIGINT);',
    );
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('tom_tenancy_startup_');
    Directory(p.join(root.path, 'system')).createSync();
    notes = {
      FixtureTenantNote:
          TomAnnotationAnalyzer.tenantTables()[FixtureTenantNote]!,
    };
    for (final name in ['main', _ds, 'acme_db']) {
      TomDataSourceInfo.datasources[name] = TomDataSourceInfo(name, const {});
    }
  });

  tearDown(() async {
    await TomTenancy.reset();
    TomDataSourceInfo.datasources.clear();
    root.deleteSync(recursive: true);
  });

  group('without a tenancy configured', () {
    test(
      'TS-1: no tenant table — a plain application, nothing installed',
      () async {
        final report = await TomTenancyStartup.configure(
          config: config(),
          migrationsRoot: root.path,
          tenantTables: const {},
        );
        expect(report.mode, TomTenancyMode.plain);
        expect(TomTenancy.current, isNull);
      },
    );

    test('TS-2: tenant tables — the implicit tenant default, nothing '
        'installed; work with no tenant runs as default', () async {
      final report = await TomTenancyStartup.configure(
        config: config(),
        migrationsRoot: root.path,
        tenantTables: notes,
      );
      expect(report.mode, TomTenancyMode.implicit);
      expect(report.tenantTables.keys, [FixtureTenantNote]);
      expect(TomTenancy.current, isNull);
      expect(TomTenancy.tenantForWork('FixtureTenantNote'), 'default');
    });

    test('TS-3: a tree for a type nobody declares is refused', () async {
      chain('standard', _ds);
      await expectLater(
        TomTenancyStartup.configure(
          config: config(),
          migrationsRoot: root.path,
          tenantTables: notes,
        ),
        _throwsKey('tenancy.start.undeclared_type_tree'),
      );
    });

    test('TS-4: the type default\'s tree must create every tenant table; '
        'without one the tables are migrated with the system tree', () async {
      chain('default', _ds, createsNote: false);
      await expectLater(
        TomTenancyStartup.configure(
          config: config(),
          migrationsRoot: root.path,
          tenantTables: notes,
        ),
        _throwsKey('tenancy.start.table_missing_from_type'),
      );
      chain('default', _ds);
      expect(
        (await TomTenancyStartup.configure(
          config: config(),
          migrationsRoot: root.path,
          tenantTables: notes,
        )).mode,
        TomTenancyMode.implicit,
      );
    });
  });

  group('with a tenancy configured', () {
    Map<String, Object?> tenancy({
      Map<String, Object?> types = const {},
      Map<String, Object?> tenants = const {'acme': <String, Object?>{}},
    }) => {
      'tenancy': {
        'registry': 'memory',
        'datasources': [_ds],
        'migrations': root.path,
        if (types.isNotEmpty) 'types': types,
        'tenants': tenants,
      },
    };

    test('TS-5: the configuration is installed; with no tenant table and no '
        'tenant tree it starts with a warning', () async {
      final report = await TomTenancyStartup.configure(
        config: config(tenancy()),
        migrationsRoot: root.path,
        tenantTables: const {},
      );
      expect(report.mode, TomTenancyMode.configured);
      expect(TomTenancy.current!.tenants.keys, ['acme']);
      expect(
        report.warnings.single,
        startsWith('tenancy.start.no_tenant_tables'),
      );

      await TomTenancy.reset();
      chain('default', _ds);
      final quiet = await TomTenancyStartup.configure(
        config: config(tenancy()),
        migrationsRoot: root.path,
        tenantTables: const {},
      );
      expect(quiet.warnings, isEmpty, reason: 'a tenant tree exists');
    });

    test('TS-6: a declared type without a tree, and a tenant of an unknown '
        'type, are refused', () async {
      await expectLater(
        TomTenancyStartup.configure(
          config: config(
            tenancy(
              types: {'standard': <String, Object?>{}},
              tenants: {
                'acme': {'type': 'standard'},
              },
            ),
          ),
          migrationsRoot: root.path,
          tenantTables: notes,
        ),
        _throwsKey('tenancy.type.missing_migrations'),
      );
      chain('standard', _ds);
      await expectLater(
        TomTenancyStartup.configure(
          config: config(
            tenancy(
              types: {'standard': <String, Object?>{}},
              tenants: {
                'acme': {'type': 'premium'},
              },
            ),
          ),
          migrationsRoot: root.path,
          tenantTables: notes,
        ),
        _throwsKey('tenancy.type.unknown'),
      );
    });

    test(
      'TS-7: a declared type\'s tree must create the tenant tables of the '
      'data sources it routes; a tree of an undeclared type is refused',
      () async {
        chain('standard', _ds, createsNote: false);
        final standard = tenancy(
          types: {'standard': <String, Object?>{}},
          tenants: {
            'acme': {
              'type': 'standard',
              'isolation': 'database',
              'datasource': 'acme_db',
            },
          },
        );
        await expectLater(
          TomTenancyStartup.configure(
            config: config(standard),
            migrationsRoot: root.path,
            tenantTables: notes,
          ),
          _throwsKey('tenancy.start.table_missing_from_type'),
        );
        await TomTenancy.reset();
        chain('standard', _ds);
        chain('premium', _ds);
        await expectLater(
          TomTenancyStartup.configure(
            config: config(standard),
            migrationsRoot: root.path,
            tenantTables: notes,
          ),
          _throwsKey('tenancy.start.undeclared_type_tree'),
        );
        await TomTenancy.reset();
        Directory(
          p.join(root.path, 'tenant', 'premium'),
        ).deleteSync(recursive: true);
        final report = await TomTenancyStartup.configure(
          config: config(standard),
          migrationsRoot: root.path,
          tenantTables: notes,
        );
        expect(report.mode, TomTenancyMode.configured);
      },
    );

    test('TS-8: a type is not asked for the tables of a data source it does '
        'not route', () async {
      chain('standard', 'main', createsNote: false);
      final report = await TomTenancyStartup.configure(
        config: config({
          'tenancy': {
            'registry': 'memory',
            'datasources': ['main'],
            'types': {
              'standard': {
                'migrations': p.join(root.path, 'tenant', 'standard'),
              },
            },
            'tenants': {
              'acme': {
                'type': 'standard',
                'isolation': 'database',
                'datasource': 'acme_db',
              },
            },
          },
        }),
        migrationsRoot: root.path,
        tenantTables: notes,
      );
      expect(report.mode, TomTenancyMode.configured);
    });

    test('TS-9: a tenancy the application installed is kept, not replaced by '
        'the configuration', () async {
      final installed = TomTenancy(
        tenants: [TomTenant('globex')],
        datasources: {_ds},
      );
      await TomTenancy.install(installed);
      final report = await TomTenancyStartup.configure(
        config: config(tenancy()),
        migrationsRoot: root.path,
        tenantTables: notes,
      );
      expect(report.mode, TomTenancyMode.configured);
      expect(identical(TomTenancy.current, installed), isTrue);
    });
  });

  group('the framework\'s own tenant tables', () {
    test('TS-10: are not the application\'s, and are every @TomTenantTable '
        'the package declares', () {
      final application = TomTenancyStartup.applicationTenantTables;
      expect(application, contains(FixtureTenantNote));
      for (final type in TomTenancyStartup.frameworkTenantEntities) {
        expect(TomTenancy.tenantTables, contains(type));
        expect(application, isNot(contains(type)));
      }
      final declared = <String>{};
      final annotated = RegExp(
        r'^@TomTenantTable\(\)[\s\S]*?\nclass (\w+)',
        multiLine: true,
      );
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        for (final match in annotated.allMatches(file.readAsStringSync())) {
          declared.add(match.group(1)!);
        }
      }
      expect(declared, {
        for (final type in TomTenancyStartup.frameworkTenantEntities) '$type',
      });
    });
  });
}

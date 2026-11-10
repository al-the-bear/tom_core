/// The schema version guard: the expand marker and the version arithmetic, the
/// system schema's guard at start (refuse, wait, ahead by expand migrations or
/// not), and a tenant behind or ahead of the code refused on its own while the
/// others are served — with the in-memory migrator, so no database is needed.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

const _expand = '-- tom:expand\nALTER TABLE t ADD COLUMN note VARCHAR(20);';
const _contract = 'ALTER TABLE t DROP COLUMN note;';

void main() {
  setUpAll(initializeReflection);

  group('the expand marker and the version arithmetic', () {
    test('SG-1: a leading comment line marks a migration expand', () {
      expect(TomSchemaVersionCheck.isExpand(_expand), isTrue);
      expect(TomSchemaVersionCheck.isExpand('--TOM:Expand\nSELECT 1;'), isTrue);
      expect(
        TomSchemaVersionCheck.isExpand('-- adds a column\n-- tom:expand\nx;'),
        isTrue,
        reason: 'any of the leading comment lines',
      );
      expect(
        TomSchemaVersionCheck.isExpand('SELECT 1;\n-- tom:expand'),
        isFalse,
        reason: 'after the first statement it is not a header',
      );
      expect(TomSchemaVersionCheck.isExpand(_contract), isFalse);
      expect(TomSchemaVersionCheck.isExpand('-- tom:expanded\nx;'), isFalse);
    });

    test('SG-2: a schema requires the code of its last migration not marked '
        'expand', () {
      expect(
        TomSchemaVersionCheck.requiredCodeVersion({
          1: _contract,
          2: _expand,
          3: _expand,
        }),
        1,
      );
      expect(
        TomSchemaVersionCheck.requiredCodeVersion({1: _expand, 2: _expand}),
        0,
      );
      expect(TomSchemaVersionCheck.requiredCodeVersion({}), 0);
    });

    test('SG-3: behind, current, ahead compatible and ahead incompatible', () {
      expect(TomSchemaVersionCheck.skewOf(3, null, null), TomSchemaSkew.behind);
      expect(TomSchemaVersionCheck.skewOf(3, 2, 2), TomSchemaSkew.behind);
      expect(TomSchemaVersionCheck.skewOf(3, 3, 3), TomSchemaSkew.current);
      expect(
        TomSchemaVersionCheck.skewOf(3, 5, 3),
        TomSchemaSkew.aheadCompatible,
      );
      expect(
        TomSchemaVersionCheck.skewOf(3, 5, 4),
        TomSchemaSkew.aheadIncompatible,
      );
      expect(
        TomSchemaVersionCheck.skewOf(3, 5, null),
        TomSchemaSkew.aheadIncompatible,
        reason: 'a record without its requirement serves only its own version',
      );
      expect(
        TomSchemaVersionCheck.worst([
          TomSchemaSkew.current,
          TomSchemaSkew.aheadCompatible,
          TomSchemaSkew.behind,
        ]),
        TomSchemaSkew.behind,
      );
      expect(TomSchemaSkew.aheadCompatible.isServed, isTrue);
      expect(TomSchemaSkew.aheadIncompatible.isServed, isFalse);
    });
  });

  group('the system schema', () {
    late Directory root;
    late Map<String, List<int>> history;
    late Map<String, Map<int, String>> scripts;
    TomDbMigrator migrator(TomDataSourceInfo _) =>
        TomMemoryDbMigrator(history: history, scripts: scripts);

    void file(String path, String sql) => File(p.join(root.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(sql);

    setUp(() {
      root = Directory.systemTemp.createTempSync('tom_schema_guard_');
      history = {};
      scripts = {};
      TomDataSourceInfo.datasources['main'] = TomDataSourceInfo(
        'main',
        const {},
      );
      file('system/main/tomcore/[1]-create_t.sql', 'CREATE TABLE t (id INT);');
    });

    tearDown(() {
      TomDbMigrations.resetRuns();
      TomDataSourceInfo.datasources.clear();
      root.deleteSync(recursive: true);
    });

    test('SG-4: a schema behind the code refuses the start, naming the '
        'versions', () async {
      await expectLater(
        TomDbMigrations.guardSystemSchema(root.path, migrators: migrator),
        throwsA(
          isA<TomDbMigrationException>()
              .having((e) => e.key, 'key', 'db_migration.schema.system_behind')
              .having((e) => e.parameters?['code'], 'code', {
                'main/tomcore': 1,
              }),
        ),
      );
      expect(TomDbMigrations.systemSchemaCheck!.skew, TomSchemaSkew.behind);
    });

    test(
      'SG-5: waiting, the start goes on once another process migrated',
      () async {
        final waited = TomDbMigrations.guardSystemSchema(
          root.path,
          wait: const Duration(seconds: 5),
          poll: const Duration(milliseconds: 20),
          migrators: migrator,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await TomDbMigrations.migrateAll(root.path, migrators: migrator);
        expect((await waited).skew, TomSchemaSkew.current);
      },
    );

    test('SG-6: a schema ahead by expand migrations is served; by another '
        'migration it is refused', () async {
      file('system/main/tomcore/[2]-add_note.sql', _expand);
      await TomDbMigrations.migrateAll(root.path, migrators: migrator);
      // The older release: its tree ends at [1].
      File(
        p.join(root.path, 'system/main/tomcore/[2]-add_note.sql'),
      ).deleteSync();
      final served = await TomDbMigrations.guardSystemSchema(
        root.path,
        migrators: migrator,
      );
      expect(served.skew, TomSchemaSkew.aheadCompatible);
      expect(served.requires, {
        'main/tomcore': 0,
      }, reason: 'no migration the code lacks is a contract one');

      scripts['main/tomcore']![2] = _contract;
      await expectLater(
        TomDbMigrations.guardSystemSchema(root.path, migrators: migrator),
        _throwsKey('db_migration.schema.system_ahead'),
      );
    });

    test(
      'SG-11: two packages contributing to one history: each is served '
      'while the other\'s migrations are expand, and a gap is behind',
      () async {
        // The other package's tree, contributing [100] to the same history.
        final other = Directory.systemTemp.createTempSync('tom_schema_other_');
        addTearDown(() => other.deleteSync(recursive: true));
        File(p.join(other.path, 'system/main/tomcore/[100]-ops_tables.sql'))
          ..createSync(recursive: true)
          ..writeAsStringSync('-- tom:expand\nCREATE TABLE ops (id INT);');
        await TomDbMigrations.migrateAll(root.path, migrators: migrator);
        await TomDbMigrations.migrateAll(other.path, migrators: migrator);

        expect(
          (await TomDbMigrations.guardSystemSchema(
            root.path,
            migrators: migrator,
          )).skew,
          TomSchemaSkew.aheadCompatible,
        );
        // The first package's [1] lies below the other's [100]: not ahead
        // of it, whatever it is.
        expect(
          (await TomDbMigrations.checkSystemSchema(
            other.path,
            migrators: migrator,
          )).skew,
          TomSchemaSkew.current,
        );

        // A new version of the first package below the history's highest.
        file('system/main/tomcore/[2]-add_note.sql', _expand);
        await expectLater(
          TomDbMigrations.guardSystemSchema(root.path, migrators: migrator),
          _throwsKey('db_migration.schema.system_behind'),
        );
      },
    );

    test(
      'SG-7: guardOnStart runs when the root exists and the guard is on',
      () async {
        expect(
          await TomDbMigrations.guardOnStart(
            null,
            p.join(root.path, 'absent'),
            migrators: migrator,
          ),
          isNull,
        );
        expect(
          await TomDbMigrations.guardOnStart(
            {'guard': false},
            root.path,
            migrators: migrator,
          ),
          isNull,
        );
        await expectLater(
          TomDbMigrations.guardOnStart(null, root.path, migrators: migrator),
          _throwsKey('db_migration.schema.system_behind'),
        );
        for (final bad in [
          {'onBehind': 'ignore'},
          {'onBehind': 'wait', 'waitSeconds': 'long'},
        ]) {
          await expectLater(
            TomDbMigrations.guardOnStart(bad, root.path, migrators: migrator),
            _throwsKey('db_migration.config.invalid'),
            reason: '$bad',
          );
        }
        await TomDbMigrations.migrateAll(root.path, migrators: migrator);
        expect(
          (await TomDbMigrations.guardOnStart(
            {'onBehind': 'wait', 'waitSeconds': 1},
            root.path,
            migrators: migrator,
          ))!.skew,
          TomSchemaSkew.current,
        );
      },
    );
  });

  group('a tenant behind or ahead of the code', () {
    late Directory root;
    late Map<String, List<int>> history;
    late TomMemoryTenantRegistry registry;
    TomDbMigrator migrator(TomDataSourceInfo _) =>
        TomMemoryDbMigrator(history: history);

    void file(String path, String sql) => File(p.join(root.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(sql);

    Future<TomTenancy> install() async {
      final tenancy = TomTenancy(
        types: [
          TomTenantType(
            'standard',
            migrations: TomTenantType.treeUnder(root.path, 'standard'),
          ),
        ],
        tenants: [
          for (final id in ['acme', 'umbrella'])
            TomTenant(
              id,
              type: 'standard',
              isolation: TomTenantIsolation.database,
              datasources: {'main': '${id}_db'},
            ),
        ],
        registry: registry,
      );
      await TomTenancy.install(tenancy);
      return tenancy;
    }

    String? refusal(TomTenancy tenancy, String tenant) => tenancy
        .resolveRequest(Request('GET', Uri.parse('http://x/')), claim: tenant)
        .key;

    setUp(() {
      root = Directory.systemTemp.createTempSync('tom_tenant_guard_');
      history = {};
      registry = TomMemoryTenantRegistry();
      for (final name in ['main', 'acme_db', 'umbrella_db']) {
        TomDataSourceInfo.datasources[name] = TomDataSourceInfo(name, const {});
      }
      file('tenant/standard/main/[1]-create_invoice.sql', 'CREATE TABLE i;');
    });

    tearDown(() async {
      await TomTenancy.reset();
      TomDbMigrations.resetRuns();
      TomDataSourceInfo.datasources.clear();
      root.deleteSync(recursive: true);
    });

    test('SG-8: a tenant never migrated is behind and refused; migrated, it '
        'is served', () async {
      final tenancy = await install();
      expect(tenancy.schemaCheckOf('acme')!.skew, TomSchemaSkew.behind);
      expect(refusal(tenancy, 'acme'), 'tenancy.tenant.schema_behind');

      await TomDbMigrations.migrateAll(
        root.path,
        tenant: 'acme',
        migrators: migrator,
      );
      expect(tenancy.schemaCheckOf('acme')!.skew, TomSchemaSkew.current);
      expect(refusal(tenancy, 'acme'), isNull);
      expect(
        refusal(tenancy, 'umbrella'),
        'tenancy.tenant.schema_behind',
        reason: 'the other tenant is judged on its own',
      );

      final checks = await TomFrameworkReadinessAnalyzer().checks();
      final schema = checks.singleWhere(
        (c) => c.subject == 'schema tenant:umbrella',
      );
      expect(schema.passed, isTrue);
      expect(schema.detail, startsWith('behind'));
    });

    test('SG-9: a newer release migrated the tenant; the older code serves it '
        'only when the migrations between are expand', () async {
      file('tenant/standard/main/[2]-add_note.sql', _expand);
      await install();
      await TomDbMigrations.migrateAll(root.path, migrators: migrator);

      // The older release, whose tree ends at [1].
      File(
        p.join(root.path, 'tenant/standard/main/[2]-add_note.sql'),
      ).deleteSync();
      var tenancy = await install();
      expect(
        tenancy.schemaCheckOf('acme')!.skew,
        TomSchemaSkew.aheadCompatible,
      );
      expect(refusal(tenancy, 'acme'), isNull);

      // A newer migration that is not expand.
      file('tenant/standard/main/[2]-add_note.sql', _expand);
      file('tenant/standard/main/[3]-drop_note.sql', _contract);
      await TomDbMigrations.migrateAll(root.path, migrators: migrator);
      for (final v in ['2', '3']) {
        File(
          p.join(
            root.path,
            'tenant/standard/main/[$v]-'
            '${v == '2' ? 'add_note' : 'drop_note'}.sql',
          ),
        ).deleteSync();
      }
      tenancy = await install();
      expect(
        tenancy.schemaCheckOf('acme')!.skew,
        TomSchemaSkew.aheadIncompatible,
      );
      expect(refusal(tenancy, 'acme'), 'tenancy.tenant.schema_ahead');
    });

    test('SG-10: a refresh from the registry judges again', () async {
      final tenancy = await install();
      expect(refusal(tenancy, 'umbrella'), 'tenancy.tenant.schema_behind');
      // Another node migrated umbrella and recorded it.
      final at = DateTime.now().toUtc();
      await registry.setMigrated('umbrella', 'main', 1, at: at);
      await registry.setMigrated('umbrella', 'main/requires', 1, at: at);
      await tenancy.refreshFromRegistry();
      expect(refusal(tenancy, 'umbrella'), isNull);
    });
  });
}

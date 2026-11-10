/// `TomDbMigrations.migrateAll` with the in-memory migrator: the order of the
/// targets, the per-tenant statuses and outcomes, the checks of the tree
/// before anything runs, the one-tenant run, the start-script options and the
/// readiness report per target.
///
/// The tenants are `database`-isolated onto data sources registered by name,
/// so routing needs no database; the SQL side is
/// `migration_orchestrator_db_test.dart`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

void main() {
  setUpAll(initializeReflection);

  late Directory root;
  late Map<String, List<int>> history;
  late Set<String> failing;
  TomDbMigrator migrator(TomDataSourceInfo _) =>
      TomMemoryDbMigrator(history: history, failing: failing);

  void file(String path) => File(p.join(root.path, path))
    ..createSync(recursive: true)
    ..writeAsStringSync('-- $path');

  void register(Iterable<String> names) {
    for (final name in names) {
      TomDataSourceInfo.datasources[name] = TomDataSourceInfo(name, const {});
    }
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('tom_migrate_all_');
    history = {};
    failing = {};
    register(['main', 'acme_db', 'umbrella_db', 'initech_db']);
    file('system/main/tomcore/[1]-create_tom_job_run.sql');
    file('system/main/tomcore/[2]-create_tom_lease.sql');
  });

  tearDown(() async {
    await TomTenancy.reset();
    TomDbMigrations.resetRuns();
    TomDataSourceInfo.datasources.clear();
    root.deleteSync(recursive: true);
  });

  /// Two types, three tenants: acme and umbrella of `standard`, initech of
  /// `enterprise`, each on a database of its own.
  Future<TomTenancy> installTwoTypes({TomTenantRegistry? registry}) async {
    file('tenant/standard/main/[1]-create_invoice.sql');
    file('tenant/standard/main/[2]-add_invoice_note.sql');
    file('tenant/enterprise/main/[1]-create_contract.sql');
    TomTenant database(String id, String type) => TomTenant(
      id,
      type: type,
      isolation: TomTenantIsolation.database,
      datasources: {'main': '${id}_db'},
    );
    final tenancy = TomTenancy(
      types: [
        TomTenantType(
          'standard',
          migrations: TomTenantType.treeUnder(root.path, 'standard'),
        ),
        TomTenantType(
          'enterprise',
          migrations: TomTenantType.treeUnder(root.path, 'enterprise'),
        ),
      ],
      tenants: [
        database('acme', 'standard'),
        database('umbrella', 'standard'),
        database('initech', 'enterprise'),
      ],
      registry: registry,
    );
    await TomTenancy.install(tenancy);
    return tenancy;
  }

  group('without tenancy', () {
    test('MO-1: the system tree, then the implicit type default on the '
        'registered data sources', () async {
      file('tenant/default/main/[1]-create_tom_message_inbox.sql');
      final result = await TomDbMigrations.migrateAll(
        root.path,
        migrators: migrator,
      );
      expect(result.succeeded, isTrue);
      expect(result.runs.map((r) => r.target), ['system', 'shared:default']);
      expect(history, {
        'main/tomcore': [1, 2],
        'main/tenant_default': [1],
      });
    });

    test('MO-2: a second run applies nothing again', () async {
      await TomDbMigrations.migrateAll(root.path, migrators: migrator);
      file('system/main/tomcore/[3]-create_tom_scheduler_node.sql');
      await TomDbMigrations.migrateAll(root.path, migrators: migrator);
      expect(history['main/tomcore'], [1, 2, 3]);
    });

    test('MO-3: a system failure is fatal and recorded', () async {
      failing.add('main/tomcore/2');
      await expectLater(
        TomDbMigrations.migrateAll(root.path, migrators: migrator),
        _throwsKey('db_migration.memory.apply_failed'),
      );
      expect(TomDbMigrations.runs.single.target, 'system');
      expect(TomDbMigrations.runs.single.state, TomMigrationRunState.failed);
    });

    test('MO-4: the flat layout is refused, as the system schema', () async {
      file('main/tomcore/[1]-create_tom_job_run.sql');
      await expectLater(
        TomDbMigrations.migrateAll(root.path, migrators: migrator),
        _throwsKey('db_migration.layout.unknown_entry'),
      );
      expect(history, isEmpty, reason: 'checked before anything runs');
      expect(TomDbMigrations.runs.single.state, TomMigrationRunState.failed);
    });

    test('MO-5: a type tree other than default is refused', () async {
      file('tenant/standard/main/[1]-create_invoice.sql');
      await expectLater(
        TomDbMigrations.migrateAll(root.path, migrators: migrator),
        _throwsKey('db_migration.tenant.undeclared_type'),
      );
      expect(history, isEmpty);
    });

    test('MO-6: no tenant can be named without a tenancy', () async {
      await expectLater(
        TomDbMigrations.migrateAll(
          root.path,
          tenant: 'acme',
          migrators: migrator,
        ),
        _throwsKey('tenancy.tenant.unknown'),
      );
    });

    test('MO-7: parallelism below one is refused', () async {
      await expectLater(
        TomDbMigrations.migrateAll(
          root.path,
          parallelism: 0,
          migrators: migrator,
        ),
        _throwsKey('db_migration.migration.invalid_parallelism'),
      );
    });
  });

  group('two types, three tenants, one failing', () {
    test('MO-8: system first, then every tenant by its type; the failing '
        'one is marked and the others go on', () async {
      final tenancy = await installTwoTypes();
      failing.add('initech_db/tenant_enterprise/1');

      final result = await TomDbMigrations.migrateAll(
        root.path,
        migrators: migrator,
      );

      expect(result.runs.map((r) => r.target), [
        'system',
        'tenant:acme',
        'tenant:umbrella',
        'tenant:initech',
      ]);
      expect(result.succeeded, isFalse);
      expect(result.failed.single.target, 'tenant:initech');
      expect(result.failed.single.error, contains('initech_db'));
      expect(history, {
        'main/tomcore': [1, 2],
        'acme_db/tenant_standard': [1, 2],
        'umbrella_db/tenant_standard': [1, 2],
        'initech_db/tenant_enterprise': <int>[],
      });

      expect(tenancy.statusOf('acme'), TomTenantStatus.active);
      expect(tenancy.statusOf('initech'), TomTenantStatus.migrationFailed);
      final initech = await tenancy.registry.find('initech');
      expect(initech!.status, TomTenantStatus.migrationFailed);
      expect(initech.statusDetail, contains('tenant_enterprise'));
      final acme = await tenancy.registry.find('acme');
      expect(acme!.migrated, {'main': 2});
      expect(acme.statusDetail, isNull);
    });

    test('MO-9: a failed tenant is migrated again once fixed', () async {
      final tenancy = await installTwoTypes();
      failing.add('initech_db/tenant_enterprise/1');
      await TomDbMigrations.migrateAll(root.path, migrators: migrator);
      failing.clear();

      final result = await TomDbMigrations.migrateAll(
        root.path,
        tenant: 'initech',
        migrators: migrator,
      );

      expect(result.runs.map((r) => r.target), ['tenant:initech']);
      expect(result.succeeded, isTrue);
      expect(tenancy.statusOf('initech'), TomTenantStatus.active);
      expect((await tenancy.registry.find('initech'))!.statusDetail, isNull);
      expect(history['main/tomcore'], [1, 2], reason: 'system not touched');
    });

    test(
      'MO-10: parallelism changes how many run at once, not what runs',
      () async {
        await installTwoTypes();
        final result = await TomDbMigrations.migrateAll(
          root.path,
          parallelism: 3,
          migrators: migrator,
        );
        expect(result.succeeded, isTrue);
        expect(result.runs.map((r) => r.target).toSet(), {
          'system',
          'tenant:acme',
          'tenant:umbrella',
          'tenant:initech',
        });
      },
    );

    test('MO-11: a suspended tenant is migrated and stays suspended', () async {
      final tenancy = await installTwoTypes();
      await tenancy.suspendTenant('umbrella');
      await TomDbMigrations.migrateAll(root.path, migrators: migrator);
      expect(tenancy.statusOf('umbrella'), TomTenantStatus.suspended);
      expect(history['umbrella_db/tenant_standard'], [1, 2]);
    });

    test('MO-12: a removed tenant is not migrated', () async {
      final tenancy = await installTwoTypes();
      await tenancy.removeTenant('umbrella');
      final result = await TomDbMigrations.migrateAll(
        root.path,
        migrators: migrator,
      );
      expect(result.runOf('tenant:umbrella'), isNull);
      expect(history.containsKey('umbrella_db/tenant_standard'), isFalse);
    });

    test('MO-13: a type tree migrating a data source the type does not '
        'route is refused before anything runs', () async {
      await installTwoTypes();
      file('tenant/standard/acme_db/[1]-stray.sql');
      await expectLater(
        TomDbMigrations.migrateAll(root.path, migrators: migrator),
        _throwsKey('db_migration.tenant.unrouted_datasource'),
      );
      expect(history, isEmpty);
    });

    test('MO-14: a tree for an undeclared type is refused', () async {
      await installTwoTypes();
      file('tenant/premium/main/[1]-create_extra.sql');
      await expectLater(
        TomDbMigrations.migrateAll(root.path, migrators: migrator),
        _throwsKey('db_migration.tenant.undeclared_type'),
      );
    });

    test('MO-15: the readiness check reports every target; a failed tenant '
        'does not hold the server back', () async {
      await installTwoTypes();
      failing.add('initech_db/tenant_enterprise/1');
      await TomDbMigrations.migrateAll(root.path, migrators: migrator);

      final checks = await TomFrameworkReadinessAnalyzer().checks();
      final migrations = [
        for (final c in checks)
          if (c.subject.startsWith('migrations')) c,
      ];
      expect(migrations.map((c) => c.subject), [
        'migrations system',
        'migrations tenant:acme',
        'migrations tenant:umbrella',
        'migrations tenant:initech',
      ]);
      expect(migrations.every((c) => c.passed), isTrue);
      expect(migrations.last.detail, startsWith('failed:'));
    });

    test('MO-16: the registry lock keeps one target to one migration at a '
        'time', () async {
      final registry = TomMemoryTenantRegistry();
      final order = <String>[];
      final first = registry.withMigrationLock('tenant:acme', () async {
        order.add('first in');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        order.add('first out');
      });
      final second = registry.withMigrationLock('tenant:acme', () async {
        order.add('second in');
      });
      final other = registry.withMigrationLock('tenant:umbrella', () async {
        order.add('other in');
      });
      await Future.wait([first, second, other]);
      expect(
        order.indexOf('second in'),
        greaterThan(order.indexOf('first out')),
      );
      expect(order.indexOf('other in'), lessThan(order.indexOf('first out')));
    });
  });

  group('a shared tenant of the type default', () {
    test('MO-17: the type tree is applied once to the system schema for the '
        'shared tenants, and once per own target', () async {
      file('tenant/default/main/[1]-create_invoice.sql');
      final tenancy = TomTenancy(
        tenants: [
          TomTenant('solo', isolation: TomTenantIsolation.shared),
          TomTenant('duo', isolation: TomTenantIsolation.shared),
          TomTenant(
            'acme',
            isolation: TomTenantIsolation.database,
            datasources: {'main': 'acme_db'},
          ),
        ],
      );
      await TomTenancy.install(tenancy);

      final result = await TomDbMigrations.migrateAll(
        root.path,
        migrators: migrator,
      );

      expect(result.runs.map((r) => r.target), [
        'system',
        'shared:default',
        'tenant:acme',
      ]);
      expect(result.runOf('shared:default')!.tenants, ['duo', 'solo']);
      expect(history, {
        'main/tomcore': [1, 2],
        'main/tenant_default': [1],
        'acme_db/tenant_default': [1],
      });
      expect(tenancy.statusOf('solo'), TomTenantStatus.active);
      expect((await tenancy.registry.find('duo'))!.migrated, {'main': 1});

      final one = await TomDbMigrations.migrateAll(
        root.path,
        tenant: 'solo',
        migrators: migrator,
      );
      expect(one.runs.map((r) => r.target), ['shared:default']);
    });
  });

  group('the in-memory migrator', () {
    final main = TomDataSourceInfo('main', const {});

    test(
      'MO-21: a migration to a pair it is not bound to is refused',
      () async {
        final memory = TomMemoryDbMigrator();
        await memory.initializeMigration(main, 'tomcore');
        await expectLater(
          memory.applyMigration(main, 'other', 1, 'create', ''),
          _throwsKey('db_migration.memory.not_initialized'),
        );
      },
    );

    test(
      'MO-22: a rollback needs every down script, and undoes newest first',
      () async {
        final memory = TomMemoryDbMigrator();
        await memory.initializeMigration(main, 'tomcore');
        for (final v in [1, 2, 3]) {
          await memory.applyMigration(main, 'tomcore', v, 'step', '');
        }
        await expectLater(
          memory.rollback(main, 'tomcore', 1, {
            2: const TomMigrationScript('step', '', 'undo'),
            3: const TomMigrationScript('step', ''),
          }),
          _throwsKey('db_migration.memory.no_down_script'),
        );
        expect(memory.applied(main, 'tomcore'), [1, 2, 3]);
        expect(
          await memory.rollback(main, 'tomcore', 1, {
            2: const TomMigrationScript('step', '', 'undo'),
            3: const TomMigrationScript('step', '', 'undo'),
          }),
          [3, 2],
        );
        expect(memory.applied(main, 'tomcore'), [1]);
      },
    );
  });

  group('the start script and the configuration', () {
    test('MO-18: migrateFromArgs runs only when asked', () async {
      expect(
        await TomDbMigrations.migrateFromArgs(['port=8080'], root.path),
        isNull,
      );
      await expectLater(
        TomDbMigrations.migrateFromArgs([
          '--migrate',
          '--migrate-parallelism=x',
        ], root.path),
        _throwsKey('db_migration.migration.invalid_arguments'),
      );
    });

    test('MO-23: --migrate and onStart run migrateAll on the root', () async {
      // A root with nothing to apply: the adaptor scan runs, nothing else
      // needs a database.
      final empty = Directory.systemTemp.createTempSync('tom_migrate_empty_');
      addTearDown(() => empty.deleteSync(recursive: true));
      Directory(p.join(empty.path, 'system')).createSync();

      final fromArgs = await TomDbMigrations.migrateFromArgs([
        '--migrate',
        '--migrate-parallelism=2',
      ], empty.path);
      expect(fromArgs!.succeeded, isTrue);
      expect(fromArgs.runs.map((r) => r.target), ['system']);

      final onStart = await TomDbMigrations.migrateOnStart({
        'onStart': true,
        'root': empty.path,
      }, 'not/this/one');
      expect(onStart!.runs.map((r) => r.target), ['system']);
    });

    test('MO-19: migrateOnStart runs only with onStart', () async {
      expect(await TomDbMigrations.migrateOnStart(null, root.path), isNull);
      expect(
        await TomDbMigrations.migrateOnStart({'onStart': false}, root.path),
        isNull,
      );
      await expectLater(
        TomDbMigrations.migrateOnStart('yes', root.path),
        _throwsKey('db_migration.config.invalid'),
      );
      await expectLater(
        TomDbMigrations.migrateOnStart({
          'onStart': true,
          'parallelism': 'many',
        }, root.path),
        _throwsKey('db_migration.config.invalid'),
      );
    });

    test('MO-20: a repair or rollback target names the system tree or a '
        'tenant', () async {
      for (final raw in [
        'main/tomcore/1',
        'system/main/1',
        'tenant:acme/main',
        'tenant:/main/1',
      ]) {
        await expectLater(
          TomDbMigrations.rollbackFromArgs([
            '--rollback-migrations=$raw',
          ], root.path),
          _throwsKey('db_migration.rollback.invalid_arguments'),
          reason: raw,
        );
      }
      await expectLater(
        TomDbMigrations.rollbackFromArgs([
          '--rollback-migrations=tenant:acme/main/1',
        ], root.path),
        _throwsKey('tenancy.tenant.unknown'),
        reason: 'well-formed, but no tenancy is installed',
      );
    });
  });
}

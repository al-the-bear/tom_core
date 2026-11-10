/// The tenant registry without a database: the in-memory store, how
/// `TomTenancy` seeds and reads it, the lifecycle calls writing it before
/// routing changes, a second node seeing the first's changes, and the
/// configuration of the registry.
///
/// The SQL store against MariaDB and PostgreSQL is
/// `test/tenant_registry_db_test.dart`.
library;

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

Request _claiming(String tenant) =>
    Request('GET', Uri.parse('https://app.example.test/things'));

/// A memory registry that remembers the order statuses were written in.
class _RecordingRegistry extends TomMemoryTenantRegistry {
  final List<String> writes = [];

  @override
  Future<void> put(TomTenantRecord record) async {
    writes.add('${record.id}:${record.status.wireName}');
    await super.put(record);
  }
}

final DateTime _at = DateTime.utc(2026, 11, 10);

/// Declared types, each with an (empty) migration tree in a scratch folder
/// and no routed data sources: these tests are about the registry, not where
/// a tenant's rows go.
List<TomTenantType> _types(List<String> names) {
  final root = Directory.systemTemp.createTempSync('tom_tenant_types_');
  addTearDown(() => root.deleteSync(recursive: true));
  return [
    for (final name in names)
      TomTenantType(
        name,
        datasources: const {},
        migrations: (Directory(
          TomTenantType.treeUnder(root.path, name),
        )..createSync(recursive: true)).path,
      ),
  ];
}

void main() {
  tearDown(TomTenancy.reset);

  group('the in-memory registry', () {
    test(
      'TR-1: records, finds, lists, and changes status and versions',
      () async {
        final registry = TomMemoryTenantRegistry();
        await registry.put(
          TomTenantRecord(
            id: 'globex',
            status: TomTenantStatus.active,
            createdAt: _at,
            updatedAt: _at,
          ),
        );
        await registry.put(
          TomTenantRecord(
            id: 'acme',
            type: 'standard',
            status: TomTenantStatus.provisioning,
            createdAt: _at,
            updatedAt: _at,
          ),
        );
        expect((await registry.all()).map((r) => r.id), ['acme', 'globex']);
        expect((await registry.find('acme'))!.type, 'standard');
        expect(await registry.find('initech'), isNull);

        final later = _at.add(const Duration(hours: 1));
        final failed = await registry.setStatus(
          'acme',
          TomTenantStatus.migrationFailed,
          detail: 'boom',
          at: later,
        );
        expect(failed.status, TomTenantStatus.migrationFailed);
        expect(failed.statusDetail, 'boom');
        expect(failed.updatedAt, later);
        expect(failed.createdAt, _at);
        final active = await registry.setStatus(
          'acme',
          TomTenantStatus.active,
          at: later,
        );
        expect(active.statusDetail, isNull, reason: 'a new status clears it');

        await registry.setMigrated('acme', 'main/app', 3, at: later);
        await registry.setMigrated('acme', 'main/audit', 1, at: later);
        expect((await registry.find('acme'))!.migrated, {
          'main/app': 3,
          'main/audit': 1,
        });

        expect(
          () =>
              registry.setStatus('initech', TomTenantStatus.active, at: later),
          throwsA(
            isA<TomTenancyException>().having(
              (e) => e.key,
              'key',
              'tenancy.registry.unknown_tenant',
            ),
          ),
        );
      },
    );

    test('TR-2: a status is stored by its wire name and read back from it', () {
      expect(TomTenantStatus.migrationFailed.wireName, 'migration-failed');
      for (final status in TomTenantStatus.values) {
        expect(TomTenantStatus.parse(status.wireName), status);
      }
      expect(
        () => TomTenantStatus.parse('dormant'),
        throwsA(
          isA<TomTenancyException>().having(
            (e) => e.key,
            'key',
            'tenancy.registry.unknown_status',
          ),
        ),
      );
    });

    test('TR-3: a literal password is never written; a secret reference is, '
        'and the configured password is merged back', () {
      final tenant = TomTenant(
        'initech',
        isolation: TomTenantIsolation.database,
        datasources: {
          'main': {'host': 'db.eu', 'password': 'hunter2'},
          'reporting': {'host': 'db.eu', 'password': 'secret:vault:db#pw'},
          'audit': 'shared_audit',
        },
      );
      final record = TomTenantRecord.of(tenant, TomTenantStatus.active, _at);
      expect(record.datasources, {
        'main': {'host': 'db.eu'},
        'reporting': {'host': 'db.eu', 'password': 'secret:vault:db#pw'},
        'audit': 'shared_audit',
      });
      expect(record.differencesFrom(tenant), isEmpty);
      final back = record.toTenant(configured: tenant);
      expect(back.datasources['main'], {
        'host': 'db.eu',
        'password': 'hunter2',
      });
      expect(record.toTenant().datasources['main'], {'host': 'db.eu'});
      // Provisioning casts a tenant's settings to Map<String, dynamic>.
      expect(back.datasources['main'], isA<Map<String, dynamic>>());
      expect(
        record.toTenant().datasources['main'],
        isA<Map<String, dynamic>>(),
      );
    });
  });

  group('the tenancy and its registry', () {
    test(
      'TR-4: install seeds the configured tenants it lacks, as active',
      () async {
        final registry = TomMemoryTenantRegistry();
        final tenancy = TomTenancy(
          tenants: [
            TomTenant('acme'),
            TomTenant('globex', type: 'standard'),
          ],
          types: _types(['default', 'standard']),
          registry: registry,
          clock: () => _at,
        );
        await TomTenancy.install(tenancy);
        final records = await registry.all();
        expect(records.map((r) => (r.id, r.type, r.status)), [
          ('acme', 'default', TomTenantStatus.active),
          ('globex', 'standard', TomTenantStatus.active),
        ]);
        expect(records.first.createdAt, _at);
        expect(tenancy.registryConflicts, isEmpty);
        expect(tenancy.tenants.keys, {'acme', 'globex'});
      },
    );

    test('TR-5: the registry is the source of truth: its tenants are served, '
        'and a configured tenant it contradicts is reported', () async {
      final registry = TomMemoryTenantRegistry();
      await registry.put(
        TomTenantRecord(
          id: 'acme',
          type: 'enterprise',
          status: TomTenantStatus.active,
          createdAt: _at,
          updatedAt: _at,
        ),
      );
      await registry.put(
        TomTenantRecord(
          id: 'initech',
          status: TomTenantStatus.suspended,
          createdAt: _at,
          updatedAt: _at,
        ),
      );
      await registry.put(
        TomTenantRecord(
          id: 'globex',
          status: TomTenantStatus.removed,
          createdAt: _at,
          updatedAt: _at,
        ),
      );
      final tenancy = TomTenancy(
        tenants: [TomTenant('acme'), TomTenant('globex')],
        types: _types(['default', 'enterprise']),
        registry: registry,
      );
      await TomTenancy.install(tenancy);

      expect(tenancy.tenants.keys, {'acme', 'initech'});
      expect(tenancy.tenants['acme']!.type, 'enterprise', reason: 'the row');
      expect(tenancy.statusOf('initech'), TomTenantStatus.suspended);
      expect(tenancy.statusOf('globex'), isNull);
      final conflicts = {
        for (final c in tenancy.registryConflicts) c.tenant: c.differences,
      };
      expect(conflicts.keys, {'acme', 'globex'});
      expect(conflicts['acme']!['type'], ('default', 'enterprise'));
      expect(conflicts['globex']!['status'], ('configured', 'removed'));
      expect(
        (await registry.find('acme'))!.type,
        'enterprise',
        reason: 'a configured tenant never overwrites its row',
      );
    });

    test('TR-6: add, suspend, resume and remove write the registry before '
        'routing changes, and a request sees the status', () async {
      final registry = _RecordingRegistry();
      final tenancy = TomTenancy(
        tenants: const [],
        registry: registry,
        clock: () => _at,
      );
      await TomTenancy.install(tenancy);

      await tenancy.addTenant(TomTenant('acme'));
      expect(registry.writes, ['acme:provisioning', 'acme:active']);
      expect(tenancy.statusOf('acme'), TomTenantStatus.active);
      expect(
        tenancy.resolveRequest(_claiming('acme'), claim: 'acme').tenant,
        'acme',
      );

      await tenancy.suspendTenant('acme');
      expect((await registry.find('acme'))!.status, TomTenantStatus.suspended);
      final suspended = tenancy.resolveRequest(
        _claiming('acme'),
        claim: 'acme',
      );
      expect(
        (suspended.status, suspended.key),
        (403, 'tenancy.tenant.suspended'),
      );

      await tenancy.resumeTenant('acme');
      expect(
        tenancy.resolveRequest(_claiming('acme'), claim: 'acme').tenant,
        'acme',
      );

      await registry.setStatus('acme', TomTenantStatus.migrating, at: _at);
      await tenancy.refreshFromRegistry();
      final migrating = tenancy.resolveRequest(
        _claiming('acme'),
        claim: 'acme',
      );
      expect(
        (migrating.status, migrating.key),
        (503, 'tenancy.tenant.unavailable'),
      );

      await tenancy.removeTenant('acme');
      expect((await registry.find('acme'))!.status, TomTenantStatus.removed);
      expect(tenancy.tenants, isEmpty);
      expect(
        tenancy.resolveRequest(_claiming('acme'), claim: 'acme').key,
        'tenancy.tenant.unknown',
      );
      expect(
        () => tenancy.suspendTenant('acme'),
        throwsA(
          isA<TomTenancyException>().having(
            (e) => e.key,
            'key',
            'tenancy.tenant.unknown',
          ),
        ),
      );
    });

    test('TR-7: a tenant added or removed on one node is served or dropped '
        'by another at its refresh', () async {
      final registry = TomMemoryTenantRegistry();
      final nodeA = TomTenancy(
        tenants: [TomTenant('acme')],
        registry: registry,
      );
      await TomTenancy.install(nodeA);
      final nodeB = TomTenancy(tenants: const [], registry: registry);

      await nodeB.addTenant(TomTenant('globex'));
      expect(nodeA.tenants.keys, {'acme'});
      final added = await nodeA.refreshFromRegistry();
      expect(added.added, ['globex']);
      expect(nodeA.tenants.keys, {'acme', 'globex'});

      await nodeB.suspendTenant('globex');
      expect((await nodeA.refreshFromRegistry()).changed, ['globex']);
      expect(nodeA.statusOf('globex'), TomTenantStatus.suspended);

      await nodeB.removeTenant('globex');
      final removed = await nodeA.refreshFromRegistry();
      expect(removed.removed, ['globex']);
      expect(nodeA.tenants.keys, {'acme'});
      expect((await nodeA.refreshFromRegistry()).isEmpty, isTrue);
    });

    test('TR-8: with a refresh interval the installed tenancy refreshes by '
        'itself, and reset stops it', () async {
      final registry = TomMemoryTenantRegistry();
      final nodeA = TomTenancy(
        tenants: const [],
        registry: registry,
        refreshInterval: const Duration(milliseconds: 10),
      );
      await TomTenancy.install(nodeA);
      await TomTenancy(
        tenants: const [],
        registry: registry,
      ).addTenant(TomTenant('globex'));
      for (var i = 0; i < 100 && !nodeA.tenants.containsKey('globex'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(nodeA.tenants.keys, {'globex'});

      await TomTenancy.reset();
      await TomTenancy(
        tenants: const [],
        registry: registry,
      ).addTenant(TomTenant('initech'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(nodeA.tenants.keys, {'globex'}, reason: 'no longer refreshing');
    });
  });

  group('the configuration', () {
    TomTenancy configured(Map<String, Object?> tenancy) =>
        TomTenancy.fromConfiguration(
          TomServerConfigResourceProvider.from({'tenancy': tenancy}),
        );

    test('TR-9: by default a SQL registry on the first routed data source, '
        'refreshed every 30 seconds', () {
      final tenancy = configured({
        'datasources': ['app', 'reporting'],
        'tenants': {
          'acme': {'type': 'standard'},
        },
      });
      final registry = tenancy.registry as TomSqlTenantRegistry;
      expect(registry.datasourceName, 'app');
      expect(registry.table, defaultTenantTable);
      expect(registry.createSchema, isTrue);
      expect(tenancy.refreshInterval, const Duration(seconds: 30));
      expect(tenancy.tenants['acme']!.type, 'standard');
    });

    test('TR-10: the registry can be named, kept in memory, or not refreshed; '
        'a bad interval is refused', () {
      final named = configured({
        'registry': {
          'datasource': 'system',
          'table': 'tenants',
          'createSchema': false,
          'refreshSeconds': 0,
        },
      });
      final registry = named.registry as TomSqlTenantRegistry;
      expect(
        (registry.datasourceName, registry.table, registry.createSchema),
        ('system', 'tenants', false),
      );
      expect(named.refreshInterval, isNull);

      final memory = configured({'registry': 'memory'});
      expect(memory.registry, isA<TomMemoryTenantRegistry>());
      expect(memory.refreshInterval, isNull);

      expect(
        () => configured({
          'registry': {'refreshSeconds': 'often'},
        }),
        throwsA(
          isA<TomTenancyException>().having(
            (e) => e.key,
            'key',
            'tenancy.config.invalid_registry',
          ),
        ),
      );
    });

    test('TR-11: a SQL registry over a data source that is not registered is '
        'refused when it is used', () async {
      final registry = TomSqlTenantRegistry.named('no_such_datasource');
      await expectLater(
        registry.all(),
        throwsA(
          isA<TomTenancyException>().having(
            (e) => e.key,
            'key',
            'tenancy.registry.unknown_datasource',
          ),
        ),
      );
    });
  });
}

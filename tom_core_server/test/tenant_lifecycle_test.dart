/// The tenant lifecycle without a database: onboarding in one call, the
/// suspended tenant's work held, removal cancelling queued work, restoring a
/// removed tenant, purging after the retention period, a tenant whose
/// migration failed refused and not routed, and the tenant pool settings.
///
/// The tenants are `database`-isolated onto data sources registered by name,
/// so nothing is opened; `tenant_lifecycle_db_test.dart` runs the lifecycle
/// against MariaDB and PostgreSQL.
library;

import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

Matcher _throwsKey(String key) =>
    throwsA(isA<TomServerException>().having((e) => e.key, 'key', key));

class _CountingStore implements TomTenantData {
  final List<String> purged = [];

  @override
  Future<int> purgeTenant(String tenant) async {
    purged.add(tenant);
    return 3;
  }
}

void main() {
  setUpAll(initializeReflection);

  late DateTime now;
  late TomMemoryTenantRegistry registry;

  TomTenant tenant(String id) => TomTenant(
    id,
    isolation: TomTenantIsolation.database,
    datasources: {'main': '${id}_db'},
  );

  Future<TomTenancy> install({List<String> ids = const ['acme']}) async {
    final tenancy = TomTenancy(
      tenants: [for (final id in ids) tenant(id)],
      registry: registry,
      clock: () => now,
    );
    await TomTenancy.install(tenancy);
    return tenancy;
  }

  String? refusal(TomTenancy tenancy, String id) => tenancy
      .resolveRequest(Request('GET', Uri.parse('http://x/')), claim: id)
      .key;

  setUp(() {
    now = DateTime.utc(2026, 11, 10, 12);
    registry = TomMemoryTenantRegistry();
    for (final name in ['main', 'acme_db', 'globex_db', 'umbrella_db']) {
      TomDataSourceInfo.datasources[name] = TomDataSourceInfo(name, const {});
    }
  });

  tearDown(() async {
    await TomTenancy.reset();
    TomDbMigrations.resetRuns();
    TomDataSourceInfo.datasources.clear();
  });

  test(
    'LC-1: addTenant records, provisions and serves a tenant in one call',
    () async {
      final tenancy = await install();
      final run = await tenancy.addTenant(tenant('umbrella'));
      expect(run, isNull, reason: 'its type has no migration tree');
      expect((await registry.find('umbrella'))!.status, TomTenantStatus.active);
      expect(tenancy.statusOf('umbrella'), TomTenantStatus.active);
      expect(refusal(tenancy, 'umbrella'), isNull);
    },
  );

  test('LC-2: a suspended tenant is refused and its queued work held; '
      'resumed, both go on', () async {
    final tenancy = await install(ids: ['acme', 'globex']);
    expect(TomScheduler.tenantGate, isNotNull);
    expect(TomScheduler.tenantGate!('acme'), isTrue);

    await tenancy.suspendTenant('acme');
    expect(refusal(tenancy, 'acme'), 'tenancy.tenant.suspended');
    expect(TomScheduler.tenantGate!('acme'), isFalse);
    expect(TomScheduler.tenantGate!('globex'), isTrue);
    expect(
      TomScheduler.tenantGate!('initech'),
      isFalse,
      reason: 'a tenant this node does not serve is held, not run',
    );

    await tenancy.resumeTenant('acme');
    expect(refusal(tenancy, 'acme'), isNull);
    expect(TomScheduler.tenantGate!('acme'), isTrue);

    await TomTenancy.reset();
    expect(TomScheduler.tenantGate, isNull);
  });

  test(
    'LC-3: removing a tenant cancels its queued work, and only its',
    () async {
      final tenancy = await install(ids: ['acme', 'globex']);
      final store = TomMemoryJobStore();
      for (final (id, owner) in [('a', 'acme'), ('g', 'globex')]) {
        await store.enqueue(
          TomJobRun(
            id: id,
            jobName: 'job',
            scheduledFor: now,
            runAt: now,
            tenant: owner,
          ),
        );
      }
      await tenancy.removeTenant('acme', jobStores: [store]);
      final a = (await store.findRun('a'))!;
      expect(a.state, TomJobRunState.failed);
      expect(a.lastError, TomJobStore.tenantRemovedError);
      expect((await store.findRun('g'))!.state, TomJobRunState.pending);
      expect(refusal(tenancy, 'acme'), 'tenancy.tenant.unknown');
      expect((await registry.find('acme'))!.status, TomTenantStatus.removed);
    },
  );

  test(
    'LC-4: a removed tenant is restored; one not removed is refused',
    () async {
      final tenancy = await install(ids: ['acme', 'globex']);
      await expectLater(
        tenancy.restoreTenant('acme'),
        _throwsKey('tenancy.tenant.not_removed'),
      );
      await expectLater(
        tenancy.restoreTenant('nobody'),
        _throwsKey('tenancy.tenant.unknown'),
      );
      await tenancy.removeTenant('acme');
      await tenancy.restoreTenant('acme');
      expect(tenancy.statusOf('acme'), TomTenantStatus.active);
      expect(refusal(tenancy, 'acme'), isNull);
    },
  );

  test('LC-5: a tenant is purged only once removed and its retention has '
      'passed, or by force; its records and its registry row go', () async {
    final tenancy = await install(ids: ['acme', 'globex']);
    await expectLater(
      tenancy.purgeTenant('acme'),
      _throwsKey('tenancy.purge.not_removed'),
    );
    await tenancy.removeTenant('acme');
    await expectLater(
      tenancy.purgeTenant('acme'),
      _throwsKey('tenancy.purge.retention'),
    );

    final jobs = TomMemoryJobStore();
    await jobs.enqueue(
      TomJobRun(
        id: 'a',
        jobName: 'job',
        scheduledFor: now,
        runAt: now,
        tenant: 'acme',
      ),
    );
    final other = _CountingStore();
    now = now.add(TomTenancy.defaultPurgeAfter);
    final report = await tenancy.purgeTenant(
      'acme',
      stores: [other],
      jobStores: [jobs],
    );
    expect(other.purged, ['acme']);
    expect(await jobs.findRun('a'), isNull);
    expect(report.deleted['_CountingStore'], 3);
    expect(report.kept, ["main: data source 'acme_db', the deployment's"]);
    expect(report.dropped, isEmpty);
    expect(await registry.find('acme'), isNull);

    await tenancy.removeTenant('globex');
    await tenancy.purgeTenant('globex', force: true);
    expect(await registry.find('globex'), isNull);
  });

  test('LC-6: a tenant whose migration failed is refused and not routed, '
      'and readiness lists it', () async {
    final tenancy = await install();
    await tenancy.setStatus(
      'acme',
      TomTenantStatus.migrationFailed,
      detail: 'boom',
    );
    expect(refusal(tenancy, 'acme'), 'tenancy.tenant.migration_failed');
    expect(
      () => TomTenantContext.run(
        'acme',
        () => TomDataSourceInfo.getDataSourceInfo('main'),
      ),
      _throwsKey('tenancy.tenant.migration_failed'),
    );
    expect(TomScheduler.tenantGate!('acme'), isFalse);
    final checks = await TomFrameworkReadinessAnalyzer().checks();
    final line = checks.singleWhere((c) => c.subject == 'tenant acme');
    expect(line.passed, isTrue);
    expect(line.detail, startsWith('migration-failed'));
  });

  test('LC-7: a failing migration leaves the added tenant migration-failed; '
      'migrateTenant brings it back', () async {
    final root = Directory.systemTemp.createTempSync('tom_lifecycle_tree_');
    addTearDown(() => root.deleteSync(recursive: true));
    final tree = Directory('${root.path}/tenant/default/main')
      ..createSync(recursive: true);
    // A data source the type does not route is refused before anything is
    // applied — which needs no database to show the failure path.
    Directory('${root.path}/tenant/default/acme_db').createSync();
    final tenancy = TomTenancy(
      types: [
        TomTenantType(
          TomTenant.defaultType,
          migrations: '${root.path}/tenant/default',
        ),
      ],
      tenants: const [],
      registry: registry,
      clock: () => now,
    );
    await TomTenancy.install(tenancy);
    await expectLater(
      tenancy.addTenant(tenant('acme')),
      _throwsKey('db_migration.tenant.unrouted_datasource'),
    );
    expect(tenancy.statusOf('acme'), TomTenantStatus.migrationFailed);
    expect(refusal(tenancy, 'acme'), 'tenancy.tenant.migration_failed');

    // The tree fixed — here, emptied: nothing to apply, the tenant comes up.
    Directory('${root.path}/tenant/default/acme_db').deleteSync();
    tree.deleteSync();
    expect(await tenancy.migrateTenant('acme'), isNull);
    expect(tenancy.statusOf('acme'), TomTenantStatus.active);
    expect(refusal(tenancy, 'acme'), isNull);
  });

  group('the tenant pools', () {
    test('LC-8: settings from configuration, refused when malformed', () {
      final pool = TomTenantPoolSettings.fromMap({
        'perTenant': 2,
        'idleSeconds': 5,
        'maxTotal': 20,
      });
      expect(pool.perTenant, 2);
      expect(pool.idleTimeout, const Duration(seconds: 5));
      expect(pool.maxTotal, 20);
      expect(pool.settings, {
        'poolMaxSize': 2,
        'poolIdleTimeoutMs': 5000,
        'poolSweepIdle': true,
        'connectLazily': true,
      });
      expect(
        () => TomTenantPoolSettings.fromMap({'perTenant': 0}),
        _throwsKey('tenancy.config.invalid_number'),
      );
      const defaults = TomTenantPoolSettings();
      expect(defaults.perTenant, 4);
      expect(defaults.maxTotal, isNull);
    });

    test('LC-9: a pool past the deployment-wide cap is refused before it '
        'opens', () async {
      TomDataSourceInfo.datasources['main'] = TomDataSourceInfo('main', const {
        'databaseName': 'app',
      });
      final tenancy = TomTenancy(
        tenants: const [],
        registry: registry,
        pool: const TomTenantPoolSettings(perTenant: 4, maxTotal: 3),
      );
      await TomTenancy.install(tenancy);
      await expectLater(
        tenancy.addTenant(
          TomTenant('acme', isolation: TomTenantIsolation.schema),
        ),
        _throwsKey('tenancy.pool.cap_exceeded'),
      );
      expect(
        (await registry.find('acme'))!.status,
        TomTenantStatus.provisioning,
        reason: 'a failed provisioning is left recorded, with its error',
      );
    });
  });
}

/// The sample's walk through tenancy, asserted step by step against a live
/// database: MariaDB, or PostgreSQL with `MT_DB_ENGINE=postgresql`.
///
/// Skips when nothing answers at the configured address, so that `dart test`
/// stays green without Docker — unless `MT_REQUIRE_DB=1`, which
/// `tool/run_integration.sh` sets, where a missing database fails the run.
/// The steps build on each other and run in order, on a fresh database.
@Tags(['live'])
library;

import 'dart:io';

import 'package:multi_tenant_sample/multi_tenant_sample.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../bin/multi_tenant_start.reflection.dart';

void main() async {
  final database = MtDatabase.fromEnvironment();
  final reachable = await database.isReachable();
  final required = Platform.environment['MT_REQUIRE_DB'] == '1';
  final String? skip = reachable || required
      ? null
      : 'No ${database.engine} at ${database.host}:${database.port} — '
            'run tool/run_integration.sh';

  group('the multi-tenant sample on ${database.engine}', () {
    late MultiTenantSample sample;
    late MtStart start;

    setUpAll(() async {
      if (skip != null) return;
      if (!reachable) fail('MT_REQUIRE_DB=1 but no database answers.');
      initializeReflection();
      sample = MultiTenantSample(database);
      start = await sample.start();
    });

    tearDownAll(() async {
      if (skip == null && reachable) await sample.stop();
    });

    test('MT-1: the start installs the configured tenancy, migrates the '
        'system schema, the type\'s shared schema and the schema tenant, and '
        'finds the system schema current', () {
      expect(start.tenancy.mode, TomTenancyMode.configured);
      expect(start.tenancy.tenantTables.keys.toSet(), {MtInvoice, MtContract});
      final runs = start.migration!.runs;
      expect(runs.map((r) => r.target), [
        'system',
        'shared:standard',
        'tenant:initech',
      ]);
      expect(start.migration!.succeeded, isTrue);
      expect(start.guard!.skew.name, 'current');
    }, skip: skip);

    test('MT-2: a system table reads the same in every tenant', () async {
      expect(await sample.plansIn('acme'), ['business', 'starter']);
      expect(await sample.plansIn('initech'), ['business', 'starter']);
    }, skip: skip);

    test('MT-3: a tenant table holds each tenant\'s rows apart, in the '
        'type\'s shared schema and in a schema of its own', () async {
      await sample.invoice('acme', 'inv-acme-1', 'starter', 900);
      await sample.invoice('globex', 'inv-globex-1', 'business', 4900);
      await sample.invoice('initech', 'inv-initech-1', 'business', 4900);
      await sample.contract('initech', 'ctr-initech-1', 'Support');
      expect(await sample.invoicesOf('acme'), ['inv-acme-1']);
      expect(await sample.invoicesOf('globex'), ['inv-globex-1']);
      expect(await sample.invoicesOf('initech'), ['inv-initech-1']);
    }, skip: skip);

    test('MT-4: a tenant onboarded at runtime is provisioned, migrated by '
        'its type\'s tree and served', () async {
      final run = await sample.onboard('umbrella', 'enterprise');
      expect(run!.target, 'tenant:umbrella');
      expect(sample.tenancy.statusOf('umbrella')!.wireName, 'active');
      await sample.contract('umbrella', 'ctr-umbrella-1', 'Hosting');
      await sample.contract('umbrella', 'ctr-umbrella-2', 'Audit');
      expect(await sample.invoicesOf('umbrella'), isEmpty);
    }, skip: skip);

    test('MT-5: the per-type job runs once per enterprise tenant, in it, and '
        'writes the system table', () async {
      expect(await sample.reviewContracts(), {'initech': 1, 'umbrella': 2});
    }, skip: skip);

    test('MT-6: every tenant\'s schema is current; a suspended tenant is '
        'refused and served again once resumed', () async {
      await sample.tenancy.checkSchemaVersions();
      for (final tenant in ['acme', 'globex', 'initech', 'umbrella']) {
        expect(
          sample.tenancy.schemaCheckOf(tenant)!.skew.name,
          'current',
          reason: tenant,
        );
      }
      await sample.tenancy.suspendTenant('globex');
      expect(sample.refusalOf('globex'), 'tenancy.tenant.suspended');
      await sample.tenancy.resumeTenant('globex');
      expect(sample.refusalOf('globex'), isNull);
    }, skip: skip);

    test('MT-7: one transaction over a tenant table and a system table is '
        'refused on one-phase data sources', () async {
      expect(
        await sample.invoiceWithReport('acme'),
        'crud_repository.transaction.tenant_and_system_one_phase',
      );
      expect(await sample.invoicesOf('acme'), ['inv-acme-1']);
    }, skip: skip);

    test('MT-8: a tenant moves from the shared schema into one of its own; a '
        'backup holds a tenant\'s rows', () async {
      final moved = await sample.tenancy.moveTenant(
        'globex',
        isolation: TomTenantIsolation.schema,
      );
      expect(moved.copied, {'main/mt_invoice': 1});
      expect(await sample.invoicesOf('globex'), ['inv-globex-1']);
      expect(await sample.invoicesOf('acme'), ['inv-acme-1']);
      final backup = await sample.tenancy.exportTenant('acme');
      expect(backup.counts, {'main/mt_invoice': 1, 'main/mt_contract': 0});
    }, skip: skip);

    test('MT-9: a restarted node serves what the registry holds: the tenant '
        'onboarded at runtime, the moved tenant where it is now', () async {
      expect(await sample.restart(), ['acme', 'globex', 'initech', 'umbrella']);
      expect(
        sample.tenancy.isolationOf(sample.tenancy.tenants['globex']!),
        TomTenantIsolation.schema,
      );
      expect(await sample.invoicesOf('globex'), ['inv-globex-1']);
      expect(await sample.invoicesOf('umbrella'), isEmpty);
    }, skip: skip);
  }, skip: skip);
}

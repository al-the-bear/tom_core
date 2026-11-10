/// `TomDbMigrations.migrateAll` end to end, on the in-memory migrator: no
/// database is needed, because [TomMemoryDbMigrator] records what it would
/// apply.
///
///  1. a migration root with a system tree and two tenant types' trees;
///  2. a tenancy of two types and three tenants, each on a database of its own;
///  3. `migrateAll`: the system schema first, then every tenant by its type,
///     one tenant failing while the others become active;
///  4. the failed tenant, fixed, migrated alone;
///  5. the readiness check, one line per target.
///
/// Run with `dart run example/db_migration/migrate_all_example.dart`.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

void check(bool condition, String what) {
  if (!condition) throw StateError('Check failed: $what');
  print('   ok: $what');
}

Future<void> run() async {
  // 1. The root: `system/<datasource>/<schema>/` and
  //    `tenant/<type>/<datasource>/`.
  final root = Directory.systemTemp.createTempSync('migrate_all_example_');
  void file(String path) => File('${root.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync('-- $path');
  file('system/main/tomcore/[1]-create_tom_job_run.sql');
  file('tenant/standard/main/[1]-create_invoice.sql');
  file('tenant/standard/main/[2]-add_invoice_note.sql');
  file('tenant/enterprise/main/[1]-create_contract.sql');
  print('1. a migration root: system/ and tenant/<type>/');

  // 2. Each tenant on a database of its own, registered by name.
  for (final name in ['main', 'acme_db', 'umbrella_db', 'initech_db']) {
    TomDataSourceInfo.datasources[name] = TomDataSourceInfo(name, const {});
  }
  TomTenant tenant(String id, String type) => TomTenant(
    id,
    type: type,
    isolation: TomTenantIsolation.database,
    datasources: {'main': '${id}_db'},
  );
  final tenancy = TomTenancy(
    types: [
      for (final type in ['standard', 'enterprise'])
        TomTenantType(
          type,
          migrations: TomTenantType.treeUnder(root.path, type),
        ),
    ],
    tenants: [
      tenant('acme', 'standard'),
      tenant('umbrella', 'standard'),
      tenant('initech', 'enterprise'),
    ],
  );
  await TomTenancy.install(tenancy);
  print('2. a tenancy: two types, three tenants');

  // One history map stands for the databases every migrator works on.
  final history = <String, List<int>>{};
  final failing = {'initech_db/tenant_enterprise/1'};
  TomDbMigrator migrator(TomDataSourceInfo _) =>
      TomMemoryDbMigrator(history: history, failing: failing);

  try {
    // 3. Everything, in order; initech's migration fails.
    print('3. migrateAll');
    final result = await TomDbMigrations.migrateAll(
      root.path,
      migrators: migrator,
    );
    for (final run in result.runs) {
      print('   ${run.target}: ${run.state.name}');
    }
    check(result.runs.first.target == 'system', 'the system schema first');
    check(
      history['acme_db/tenant_standard']!.length == 2,
      "acme's database holds its type's tree under its own history",
    );
    check(
      tenancy.statusOf('initech') == TomTenantStatus.migrationFailed,
      'the failing tenant is marked migration-failed',
    );
    check(
      tenancy.statusOf('umbrella') == TomTenantStatus.active,
      'and the others went on',
    );

    // 4. The cause fixed, the tenant alone — not the system schema again.
    print('4. migrateAll(tenant: initech)');
    failing.clear();
    final retry = await TomDbMigrations.migrateAll(
      root.path,
      tenant: 'initech',
      migrators: migrator,
    );
    check(
      retry.runs.map((r) => r.target).join(',') == 'tenant:initech',
      'only the tenant runs',
    );
    check(
      tenancy.statusOf('initech') == TomTenantStatus.active,
      'and it is active',
    );

    // 5. Readiness lists every target of the last call.
    print('5. readiness');
    for (final c in await TomFrameworkReadinessAnalyzer().checks()) {
      if (c.subject.startsWith('migrations')) print('   $c');
    }
  } finally {
    await TomTenancy.reset();
    TomDbMigrations.resetRuns();
    TomDataSourceInfo.datasources.clear();
    root.deleteSync(recursive: true);
  }
  print('\nmigrateAll example completed.');
}

Future<void> main() => run();

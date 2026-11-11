/// Runs the multi-tenant sample against the database the environment names
/// (`MT_DB_ENGINE` and friends, see `MtDatabase`) and prints what each step
/// found. Run it from the package root, the database up:
///
/// ```sh
/// docker compose up -d --wait mariadb
/// dart run bin/multi_tenant_start.dart
/// MT_DB_ENGINE=postgresql dart run bin/multi_tenant_start.dart  # with postgres up
/// ```
///
/// It expects a fresh database; `tool/run_integration.sh` gives it one per
/// engine. This file is also the reflection root (`build.yaml`); regenerate
/// with `./reflection_generation.sh` after changing a reflected shape.
library;

import 'dart:io';

import 'package:multi_tenant_sample/multi_tenant_sample.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'multi_tenant_start.reflection.dart';

Future<void> main() async {
  initializeReflection();
  final sample = MultiTenantSample(MtDatabase.fromEnvironment());
  void say(String line) => stdout.writeln(line);
  try {
    final start = await sample.start();
    say(
      'start: tenancy ${start.tenancy.mode.name}, '
      '${start.tenancy.tenantTables.length} tenant tables',
    );
    say(
      'start: migrated ${start.migration?.runs.map((r) => r.target).join(', ')}',
    );
    say('start: system schema ${start.guard?.skew.name}');
    say('plans in acme: ${await sample.plansIn('acme')}');
    await sample.invoice('acme', 'inv-acme-1', 'starter', 900);
    await sample.invoice('globex', 'inv-globex-1', 'business', 4900);
    await sample.contract('initech', 'ctr-initech-1', 'Support');
    say(
      'acme sees ${await sample.invoicesOf('acme')}, '
      'globex sees ${await sample.invoicesOf('globex')}',
    );
    await sample.onboard('umbrella', 'enterprise');
    await sample.contract('umbrella', 'ctr-umbrella-1', 'Hosting');
    await sample.contract('umbrella', 'ctr-umbrella-2', 'Audit');
    say('umbrella onboarded: ${sample.tenancy.statusOf('umbrella')!.wireName}');
    say(
      'contract review per enterprise tenant: ${await sample.reviewContracts()}',
    );
    await sample.tenancy.suspendTenant('globex');
    say(
      'globex suspended: a request is refused with ${sample.refusalOf('globex')}',
    );
    await sample.tenancy.resumeTenant('globex');
    say(
      'one transaction over a tenant and a system table: '
      '${await sample.invoiceWithReport('acme') ?? 'committed'}',
    );
    final moved = await sample.tenancy.moveTenant(
      'globex',
      isolation: TomTenantIsolation.schema,
    );
    say('moved: $moved');
    final backup = await sample.tenancy.exportTenant('acme');
    say('backup of acme: ${backup.counts}');
    say('after a restart the registry serves ${await sample.restart()}');
  } finally {
    await sample.stop();
  }
}

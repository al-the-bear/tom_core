/// The plain application: this sample declares no tenant table and
/// configures no tenancy, so its start installs nothing and asks for nothing
/// — the path every application without tenants takes.
///
/// Database-free: `TomTenancyStartup.configure` decides from the reflected
/// entities and the configuration alone.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../bin/server_start.reflection.dart';

void main() {
  setUpAll(initializeReflection);

  tearDown(TomTenancy.reset);

  test('TP-1: no application tenant table — the framework\'s own are '
      'reflected and do not count', () {
    expect(TomTenancyStartup.applicationTenantTables, isEmpty);
    expect(
      TomTenancy.tenantTables.keys,
      containsAll(TomTenancyStartup.frameworkTenantEntities),
    );
  });

  test('TP-2: the sample\'s configuration and migration tree start a plain '
      'application: nothing installed', () async {
    final config = TomServerConfigResourceProvider.from(
      TomYaml.loadYamlFile('assets/config-resources_default.yaml'),
    );
    expect(config.exists(TomTenancy.configurationKey), isFalse);
    final report = await TomTenancyStartup.configure(
      config: config,
      migrationsRoot: 'database_migrations',
    );
    expect(report.mode, TomTenancyMode.plain);
    expect(TomTenancy.current, isNull);
  });
}

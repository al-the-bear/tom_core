/// What the sample declares, checked without a database: its tenant tables
/// and system tables, and that every migration tree creates the tables its
/// tenants or the system schema hold.
library;

import 'package:multi_tenant_sample/multi_tenant_sample.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../bin/multi_tenant_start.reflection.dart';

void main() {
  setUpAll(initializeReflection);

  test('MC-1: the application\'s tenant tables are the invoices and the '
      'contracts; the plans and the review reports are system tables', () {
    expect(TomTenancyStartup.applicationTenantTables.keys.toSet(), {
      MtInvoice,
      MtContract,
    });
    expect(TomAnnotationAnalyzer.isTenantTable(MtPlan), isFalse);
    expect(TomAnnotationAnalyzer.isTenantTable(MtReviewReport), isFalse);
  });

  test('MC-2: the system tree and both types\' trees converge with the '
      'entities', () {
    final reports = TomSchemaConvergenceCheck().checkAll(
      'database_migrations',
      entityTypes: [MtPlan, MtReviewReport, MtInvoice, MtContract],
    );
    expect(reports.map((r) => '${r.datasource}/${r.schema}').toSet(), {
      'main/app',
      'main/tenant_standard',
      'main/tenant_enterprise',
    });
    for (final report in reports) {
      expect(report.errors, isEmpty, reason: report.describe());
    }
  });

  test('MC-3: the configuration names two types and seeds three tenants', () {
    final tenancy = TomTenancy.fromConfiguration(
      TomServerConfigResourceProvider.from(
        TomYaml.loadYamlFile('assets/config.yaml'),
      ),
    );
    expect(tenancy.types.keys.toSet(), {'standard', 'enterprise'});
    expect(tenancy.tenants.keys.toSet(), {'acme', 'globex', 'initech'});
    expect(
      tenancy.isolationOf(tenancy.tenants['initech']!),
      TomTenantIsolation.schema,
    );
    expect(
      tenancy.isolationOf(tenancy.tenants['acme']!),
      TomTenantIsolation.shared,
    );
  });
}

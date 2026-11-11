/// The sample's tables: one application **system table** shared by every
/// tenant, and two **tenant tables** whose rows belong to one tenant each.
///
/// Every entity is on the data source `main`. Whether its rows are a tenant's
/// is the one annotation `@TomTenantTable`: the tenancy routes a tenant table to
/// the tenant's placement — its type's shared schema, or a schema of its own —
/// and reads and writes a system table in the system schema, also inside a
/// tenant.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// A subscription plan: the deployment's catalogue, the same for every tenant
/// — a **system table** (no `@TomTenantTable`), created by the system tree
/// `database_migrations/system/main/app/`.
@tomReflector
@TomDbTable(datasource: 'main', table: 'mt_plan', primaryKeyFields: ['code'])
class MtPlan {
  /// The plan's code, e.g. `starter`.
  @TomEntityId()
  @TomDbColumn(columnName: 'code')
  String? code;

  /// What the plan is called.
  @TomDbColumn(columnName: 'name')
  String? name;

  /// Its monthly price, in cents.
  @TomDbColumn(columnName: 'monthly_cents')
  int? monthlyCents;
}

/// The repository for [MtPlan].
class MtPlanRepository extends TomSqlDatasourceRepository<MtPlan, String> {}

/// An invoice of a tenant — a **tenant table**, created by both types' trees:
/// `standard`'s in its shared schema, `enterprise`'s in each tenant's schema.
///
/// Its key is a text id the application chooses, unique across tenants, so
/// a tenant's invoices can be moved into a shared schema other tenants already
/// use (`TomTenancy.moveTenant`).
@tomReflector
@TomTenantTable()
@TomDbTable(datasource: 'main', table: 'mt_invoice', primaryKeyFields: ['id'])
class MtInvoice {
  /// The invoice id.
  @TomEntityId()
  @TomDbColumn(columnName: 'id')
  String? id;

  /// The tenant the invoice belongs to — filled by the framework.
  @TomDbColumn(columnName: 'tenant_id')
  String? tenantId;

  /// The plan invoiced — a code of the system table [MtPlan].
  @TomDbColumn(columnName: 'plan_code')
  String? planCode;

  /// The amount, in cents.
  @TomDbColumn(columnName: 'amount_cents')
  int? amountCents;
}

/// The repository for [MtInvoice].
class MtInvoiceRepository
    extends TomSqlDatasourceRepository<MtInvoice, String> {}

/// A contract of a tenant — a **tenant table**, created by both types' trees;
/// the `enterprise` tree also indexes it by title.
@tomReflector
@TomTenantTable()
@TomDbTable(datasource: 'main', table: 'mt_contract', primaryKeyFields: ['id'])
class MtContract {
  /// The contract id.
  @TomEntityId()
  @TomDbColumn(columnName: 'id')
  String? id;

  /// The tenant the contract belongs to — filled by the framework.
  @TomDbColumn(columnName: 'tenant_id')
  String? tenantId;

  /// What the contract is about.
  @TomDbColumn(columnName: 'title')
  String? title;
}

/// The repository for [MtContract].
class MtContractRepository
    extends TomSqlDatasourceRepository<MtContract, String> {}

/// One run of the contract review — a **system table** a job planned per
/// tenant writes from inside each tenant: the row lands in the system schema,
/// naming the tenant it reviewed.
@tomReflector
@TomDbTable(
  datasource: 'main',
  table: 'mt_review_report',
  primaryKeyFields: ['id'],
)
class MtReviewReport {
  /// `<tenant>@<window>`.
  @TomEntityId()
  @TomDbColumn(columnName: 'id')
  String? id;

  /// The tenant whose contracts were reviewed.
  @TomDbColumn(columnName: 'tenant')
  String? tenant;

  /// How many contracts it held.
  @TomDbColumn(columnName: 'contracts')
  int? contracts;
}

/// The repository for [MtReviewReport].
class MtReviewReportRepository
    extends TomSqlDatasourceRepository<MtReviewReport, String> {}

/// The schema of the tenant registry table.
///
/// Declared **once**, as a [TomFrameworkTable]: the DDL the store issues, the
/// column lists its statements interpolate and the schema model the
/// convergence guard compares are derived from this one declaration. The
/// shipped migration under `example/tenancy/migrations/` stays hand-written,
/// and `test/framework_schema_test.dart` fails if the two drift apart.
library;

import '../datasources/framework_table.dart';

/// The default name of the tenant registry table.
const String defaultTenantTable = 'tom_tenant';

/// The tenant registry table [table], declared once.
///
/// Notes on the shape:
///
///  * `id` is the primary key: a tenant id is at most 32 characters
///    (`TomTenantContext.idPattern`).
///  * the table is the deployment's: it lives in the system schema, the base
///    data source's own schema, and is never routed.
///  * `datasources` and `migrated` are JSON text — a map of routed data-source
///    name to a registered name or settings, and a map of migration target
///    (`<datasource>/<schema>`) to the version applied.
///  * `status` is indexed for listing the tenants a node serves.
///  * instants are `DATETIME(6)` and always written in UTC — see `sqlInstant` in
///    `datasources/sql_instant.dart`.
TomFrameworkTable tenantTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'tenantTable',
  columns: const [
    TomFrameworkColumn('id', 'VARCHAR(32)'),
    TomFrameworkColumn('type', 'VARCHAR(64)'),
    TomFrameworkColumn('name', 'VARCHAR(191)', nullable: true),
    TomFrameworkColumn('isolation', 'VARCHAR(16)', nullable: true),
    TomFrameworkColumn('schema_name', 'VARCHAR(64)', nullable: true),
    TomFrameworkColumn('datasources', 'TEXT', nullable: true),
    TomFrameworkColumn('status', 'VARCHAR(32)'),
    TomFrameworkColumn('status_detail', 'TEXT', nullable: true),
    TomFrameworkColumn('migrated', 'TEXT', nullable: true),
    TomFrameworkColumn('created_at', 'DATETIME(6)'),
    TomFrameworkColumn('updated_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['id'],
  keys: const [
    TomFrameworkKey('status', ['status']),
  ],
);

/// The DDL for the tenant registry table [table].
String tenantTableDdl(String table) => tenantTable(table).createTableDdl;

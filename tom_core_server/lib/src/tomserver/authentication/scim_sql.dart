/// The schema of the SCIM resource table.
///
/// Declared **once**, as a [TomFrameworkTable], like every framework-owned
/// table: the DDL the store issues, the column lists its statements
/// interpolate and the schema model the convergence guard compares are all
/// derived from this one declaration. The shipped migration under
/// `example/authentication/migrations/` stays hand-written, and
/// `test/framework_schema_test.dart` fails if the two drift apart.
library;

import '../datasources/framework_table.dart';

/// The default name of the SCIM resource table.
const String defaultScimResourceTable = 'tom_scim_resource';

/// The SCIM resource table [table], declared once.
///
/// Notes on the shape:
///
///  * `id` is an auto-increment key and is the resource's SCIM `id`, in
///    decimal. It is never reused, which is what SCIM requires of an id.
///  * `tenant` is the tenant the resource belongs to, `''` for none; every
///    statement names the tenant in context, so under `shared` isolation two
///    tenants' resources stay apart in the one table.
///  * `name_key` is the name attribute — a user's `userName`, a group's
///    `displayName` — lower-cased, and unique within a `resource_type` of one
///    tenant. Both
///    are compared case-insensitively by SCIM, so the key stores the form the
///    comparison uses, and the database refuses a second resource of one name.
///  * `external_id` is indexed for the identity provider's reconciliation, and
///    nullable: a resource created without one has none.
///  * `document` is the resource's JSON without `id` and `meta` — every
///    attribute the identity provider maps survives, whatever its schema.
///  * instants are `DATETIME(6)` and always written in UTC — see `sqlInstant`
///    in `datasources/sql_instant.dart`.
TomFrameworkTable scimResourceTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'scimResourceTable',
  columns: const [
    TomFrameworkColumn('id', 'BIGINT', autoIncrement: true),
    TomFrameworkColumn('resource_type', 'VARCHAR(16)'),
    TomFrameworkColumn('name_key', 'VARCHAR(191)'),
    TomFrameworkColumn('external_id', 'VARCHAR(191)', nullable: true),
    TomFrameworkColumn('document', 'LONGTEXT'),
    TomFrameworkColumn('created_at', 'DATETIME(6)'),
    TomFrameworkColumn('last_modified', 'DATETIME(6)'),
    TomFrameworkColumn('version', 'BIGINT'),
    TomFrameworkColumn('tenant', 'VARCHAR(32)'),
  ],
  primaryKey: const ['id'],
  keys: const [
    TomFrameworkKey.unique('name', ['tenant', 'resource_type', 'name_key']),
    TomFrameworkKey('external', ['tenant', 'resource_type', 'external_id']),
  ],
);

/// The DDL for the SCIM resource table [table].
String scimResourceTableDdl(String table) =>
    scimResourceTable(table).createTableDdl;

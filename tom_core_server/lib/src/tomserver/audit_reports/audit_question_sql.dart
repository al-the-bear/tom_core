/// The schema of the saved-question table.
///
/// Declared **once**, as a [TomFrameworkTable], like every framework table:
/// the DDL `TomSqlAuditQuestionStore` issues, the column lists its statements
/// interpolate and the schema model the convergence guard compares all derive
/// from this one declaration. The shipped migration under
/// `example/audit_reports/migrations/` stays hand-written, and
/// `test/framework_schema_test.dart` fails if the two drift apart.
library;

import '../datasources/framework_table.dart';

/// The default name of the saved-question table.
const String defaultAuditQuestionTable = 'tom_audit_question';

/// The saved-question table, as the framework declares it.
TomFrameworkTable auditQuestionTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'auditQuestionTable',
  kind: TomTableKind.system,
  columns: const [
    TomFrameworkColumn('id', 'VARCHAR(64)'),
    TomFrameworkColumn('owner', 'VARCHAR(191)'),
    TomFrameworkColumn('name', 'VARCHAR(255)'),
    TomFrameworkColumn('definition', 'TEXT'),
    TomFrameworkColumn('schedule', 'VARCHAR(255)', nullable: true),
    TomFrameworkColumn('next_delivery_at', 'DATETIME(6)', nullable: true),
    TomFrameworkColumn('last_delivered_at', 'DATETIME(6)', nullable: true),
    TomFrameworkColumn('updated_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['id'],
  keys: const [
    TomFrameworkKey('owner', ['owner', 'name']),
    TomFrameworkKey('due', ['next_delivery_at']),
  ],
);

/// The `CREATE TABLE` of [auditQuestionTable].
String auditQuestionTableDdl(String table) =>
    auditQuestionTable(table).createTableDdl;

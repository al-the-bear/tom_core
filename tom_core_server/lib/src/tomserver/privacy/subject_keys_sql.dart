/// The schema of the subject-key table of crypto-shredding.
///
/// Declared **once**, as a [TomFrameworkTable], like every framework table;
/// the shipped migration under `example/privacy/migrations/` stays hand-written
/// and `test/framework_schema_test.dart` fails if the two drift.
library;

import '../datasources/framework_table.dart';

/// The default name of the subject-key table.
const String defaultSubjectKeyTable = 'tom_subject_key';

/// The subject-key table [table], declared once.
///
/// Notes on the shape:
///
///  * one row per data subject: the key their personal values in the audit
///    trail are sealed under. Erasing the subject deletes the row, and with it
///    every way to read those values — the trail itself is never rewritten.
///  * the primary key is `(tenant, subject_id)`; `tenant` is `''` outside
///    tenancy.
///  * `wrapped_key` is the key encrypted under the key-encryption key `kek_id`
///    names (base64): the table never holds a usable key.
TomFrameworkTable subjectKeyTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'subjectKeyTable',
  kind: TomTableKind.tenant,
  columns: const [
    TomFrameworkColumn('tenant', 'VARCHAR(32)'),
    TomFrameworkColumn('subject_id', 'VARCHAR(191)'),
    TomFrameworkColumn('kek_id', 'VARCHAR(128)'),
    TomFrameworkColumn('wrapped_key', 'VARCHAR(255)'),
    TomFrameworkColumn('created_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['tenant', 'subject_id'],
);

/// The DDL for the subject-key table [table].
String subjectKeyTableDdl(String table) =>
    subjectKeyTable(table).createTableDdl;

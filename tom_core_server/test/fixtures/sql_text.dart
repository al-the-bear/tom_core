/// Reading a shipped reference migration, and comparing it to generated DDL.
///
/// Three suites — `scheduling_schema_test.dart`, `audit_sql_test.dart` and
/// `file_storage_schema_test.dart` — make the same comparison for their own
/// module: the `.sql` file a DBA applies against the `CREATE TABLE` text the
/// package generates. The two helpers that comparison needs were written out
/// twice before this file existed and were about to be written a third time,
/// which is the point at which a copy stops being a coincidence.
///
/// Keeping them together also keeps the *normalisation* single. What counts as
/// "the same statement" is a judgement — comments do not count, layout does not
/// count, a trailing semicolon does not count — and three copies of that
/// judgement can drift into three different comparisons while every suite still
/// reports green.
library;

import 'dart:io';

/// Strips SQL comments and collapses whitespace, so a comparison is about the
/// statement rather than about how it was laid out or documented.
String normaliseSql(String sql) => sql
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty && !line.startsWith('--'))
    .join(' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r';\s*$'), '')
    .trim();

/// The text of [basename] in [module]'s shipped `main/tomcore` chain.
///
/// Read from disk rather than re-typed, so what is compared is the file a
/// deployment applies and not a parallel copy of it.
String readMigration(String module, String basename) => File(
  'example/$module/migrations/main/tomcore/$basename',
).readAsStringSync();

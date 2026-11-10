/// The drift guard over this package's copy of the `tom_resource_grant` DDL.
///
/// `database_migrations/system/todo_db/todo_schema/[001]-todo_authz_grants.sql` restates the table the framework owns — its header says the DDL is
/// `TomResourceGrant.createTableSql` "reused verbatim". tom_core_server pins its
/// own reference migration against that constant, but a copy in a consuming
/// package is outside that test's reach, and nothing in the language relates a
/// `.sql` file to a Dart string. A drift would surface only when a live
/// migration met a real database. This suite makes "verbatim" a checked fact:
/// the `CREATE TABLE` statement in the file must equal the constant, byte for
/// byte.
///
/// Shared in shape with `advanced_auth_server/test/entity_table_ddl_test.dart`,
/// which guards that server's copies of four framework entity tables, this one
/// among them.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// The migration that creates `tom_resource_grant`.
const String _grantsMigration =
    'database_migrations/system/todo_db/todo_schema/[001]-todo_authz_grants.sql';

/// Every `CREATE TABLE` statement in [sql], from the keyword to the `);` that
/// closes it.
///
/// Non-greedy up to the first `);` at a line start, which is where both the
/// framework constant and the file close the statement.
List<String> _createTableStatements(String sql) => RegExp(
  r'CREATE TABLE[\s\S]*?\n\);',
).allMatches(sql).map((m) => m.group(0)!).toList();

void main() {
  group('the tom_resource_grant DDL', () {
    final sql = File(_grantsMigration).readAsStringSync();

    test('the migration creates exactly one table', () {
      // Guards the extraction below: a second statement, or a reformatted one
      // the pattern no longer recognises, fails here naming the count rather
      // than comparing the wrong text.
      expect(_createTableStatements(sql), hasLength(1));
    });

    test('is TomResourceGrant.createTableSql, verbatim', () {
      expect(
        _createTableStatements(sql).single,
        TomResourceGrant.createTableSql,
        reason:
            '$_grantsMigration claims to reuse the framework DDL verbatim; '
            'copy TomResourceGrant.createTableSql into it again',
      );
    });
  });
}

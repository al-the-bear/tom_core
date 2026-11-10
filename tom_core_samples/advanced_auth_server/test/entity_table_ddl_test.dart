/// The drift guard over this server's copies of framework entity-table DDL.
///
/// Four framework tables are created by migrations in this repository whose
/// headers say the DDL is the owning entity's `createTableSql` "reused
/// verbatim": `tom_resource_grant`, `tom_principal_resource_grant` and
/// `tom_principal_delegation` in `[001]`, `tom_user_two_factor_enrolment` in
/// `[007]`. tom_core_server pins its own reference migrations against those
/// constants, but a copy in a consuming package is outside that test's reach,
/// and nothing in the language relates a `.sql` file to a Dart string. A drift
/// would surface only when a live migration met a real database. This suite
/// makes "verbatim" a checked fact, byte for byte.
///
/// The framework tables whose DDL is owned by a descriptor rather than an entity
/// — `tom_blob` and `tom_blob_chunk` — are guarded structurally by
/// `auth_blob_schema_test.dart` instead. The first test below requires every
/// `tom_*` table the chain creates to be claimed by one guard or the other, so a
/// framework table added to a migration without a pin fails here rather than
/// leaving no trace.
///
/// Shared in shape with `core_server_sample/test/grant_table_ddl_test.dart`,
/// which guards the other sample copy of `tom_resource_grant`.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// The auth schema migration directory, relative to the package root.
const String _authSchemaDir = 'database_migrations/system/auth_db/auth_schema/';

/// A framework table this server creates from a copy of its entity's DDL.
typedef _EntityPin = ({String migration, String table, String ddl});

/// Every entity-owned framework table in the chain, paired with the constant
/// that owns its DDL.
final List<_EntityPin> _entityPins = [
  (
    migration: '[001]-auth_authz_grants.sql',
    table: 'tom_resource_grant',
    ddl: TomResourceGrant.createTableSql,
  ),
  (
    migration: '[001]-auth_authz_grants.sql',
    table: 'tom_principal_resource_grant',
    ddl: TomPrincipalResourceGrant.createTableSql,
  ),
  (
    migration: '[001]-auth_authz_grants.sql',
    table: 'tom_principal_delegation',
    ddl: TomPrincipalDelegation.createTableSql,
  ),
  (
    migration: '[007]-auth_two_factor_enrolments.sql',
    table: 'tom_user_two_factor_enrolment',
    ddl: TomUserTwoFactorEnrolment.createTableSql,
  ),
];

/// The framework tables whose DDL is owned by a descriptor, and which
/// `auth_blob_schema_test.dart` guards structurally.
const Set<String> _descriptorTables = {'tom_blob', 'tom_blob_chunk'};

/// Every `CREATE TABLE` statement in [sql], keyed by table name, from the
/// keyword to the `);` at a line start that closes it — where both the
/// framework constants and the migration files close the statement.
Map<String, String> _createTableStatements(String sql) => {
  for (final m in RegExp(
    r'CREATE TABLE IF NOT EXISTS (\w+) \([\s\S]*?\n\);',
  ).allMatches(sql))
    m.group(1)!: m.group(0)!,
};

void main() {
  group('framework entity-table DDL', () {
    test('every tom_* table the chain creates is claimed by a guard', () {
      final created = <String>{
        for (final file in Directory(
          _authSchemaDir,
        ).listSync().whereType<File>())
          ..._createTableStatements(
            file.readAsStringSync(),
          ).keys.where((t) => t.startsWith('tom_')),
      };
      expect(created, {
        ..._entityPins.map((p) => p.table),
        ..._descriptorTables,
      });
    });

    for (final pin in _entityPins) {
      test('${pin.table} is the entity createTableSql, verbatim', () {
        final sql = File('$_authSchemaDir${pin.migration}').readAsStringSync();
        expect(
          _createTableStatements(sql)[pin.table],
          pin.ddl,
          reason:
              '${pin.migration} claims to reuse the framework DDL for '
              '${pin.table} verbatim; copy the entity constant into it again',
        );
      });
    }
  });
}

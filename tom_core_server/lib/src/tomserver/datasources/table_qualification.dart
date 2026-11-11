/// The schema the table names of a statement are qualified with while it is
/// rendered — how a system table's statements run on a tenant's connection.
///
/// A statement normally names its tables bare, and the connection it runs on
/// resolves them in its own schema. A system table written inside a tenant's
/// transaction runs on the tenant's connection, so the transaction stays one
/// branch, and names its table with the system schema instead
/// (`TomSqlDatasource.qualify`). Only the table positions are qualified —
/// `FROM`, `INSERT INTO`, `UPDATE`, `DELETE FROM`; a column stays `table.column`,
/// which both MariaDB and PostgreSQL resolve against a qualified table by its
/// bare name.
library;

import 'dart:async';

/// Renders table names qualified while a statement is built in [run].
abstract final class TomSqlTableQualification {
  static const Symbol _key = #tomSqlTableQualification;

  /// [table] as the statement being rendered in this zone names it: qualified
  /// inside [run] with a qualifier, else unchanged.
  static String table(String table) {
    final qualify = Zone.current[_key];
    return qualify is String Function(String) ? qualify(table) : table;
  }

  /// Whether the statements rendered in this zone qualify their tables.
  static bool get isActive => Zone.current[_key] is String Function(String);

  /// Runs [body] with every table position rendered in it qualified by
  /// [qualify]; with `null`, runs it unchanged.
  static R run<R>(String Function(String table)? qualify, R Function() body) =>
      qualify == null ? body() : runZoned(body, zoneValues: {_key: qualify});
}

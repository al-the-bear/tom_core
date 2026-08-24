import 'sql_dialects.dart';

/// The SQL dialect for MariaDB.
///
/// It inherits standard SQL *generation* unchanged from
/// [TomStandardSqlDialect]. Override a fragment method here if a future
/// MariaDB-specific syntax diverges from the standard.
///
/// Nothing looks this class up. A dialect reaches a query because the data
/// source hands it over — `MariaDbDatasource.sqlDialect` returns an instance of
/// this class, and everything that renders SQL asks its data source. Driver
/// discovery is what reflection resolves by type name (`@TomDatasourceDriver`),
/// and once a driver is chosen its dialect comes with it, so a dialect registry
/// keyed by the same string would be a second answer to a question already
/// answered. A dialect for another database therefore arrives as part of that
/// database's driver, not on its own.
class MariadbSqlDialect extends TomStandardSqlDialect {
  /// Classifies `TINYINT(1)` as a truth value, everything else as standard.
  ///
  /// MariaDB has no distinct boolean storage: `BOOLEAN` is a synonym for
  /// `TINYINT(1)`, and that is how a `bool` entity field is spelled in DDL. A
  /// schema-convergence check that classified it as an integer would report
  /// every boolean column of every migration as a type divergence.
  ///
  /// Only the exact `(1)` display width is boolean — a plain `TINYINT` or a
  /// `TINYINT(4)` really is a small integer.
  @override
  TomSqlTypeFamily typeFamily(String sqlType) {
    if (baseTypeName(sqlType) == 'TINYINT') {
      final arguments = typeArguments(sqlType);
      if (arguments.length == 1 && arguments.first == '1') {
        return TomSqlTypeFamily.boolean;
      }
    }
    return super.typeFamily(sqlType);
  }
}

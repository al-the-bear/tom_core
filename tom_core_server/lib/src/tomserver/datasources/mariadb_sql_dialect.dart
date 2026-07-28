import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'sql_dialects.dart';

/// The SQL dialect for MariaDB.
///
/// It inherits standard SQL *generation* unchanged from [TomStandardSqlDialect];
/// the `@TomSqlDialect("mariadb")` annotation registers it as the dialect for
/// the `"mariadb"` data-source type, and `@tomReflector` makes it discoverable
/// by the reflection-based dialect lookup. Override a fragment method here if a
/// future MariaDB-specific syntax diverges from the standard.
@tomReflector
@TomSqlDialect("mariadb")
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

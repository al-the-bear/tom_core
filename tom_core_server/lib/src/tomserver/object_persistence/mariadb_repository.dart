import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../datasources/mariadb_sql_dialect.dart';
import '../datasources/sql_dialects.dart';

import 'crud_repository.dart';

/// A [TomSqlDatasourceRepository] for MariaDB-backed entities.
///
/// Registered via `@TomRepositoryType("mariadb")` so reflection-based repository
/// discovery selects it for data sources of type `"mariadb"`. It overrides
/// [sqlDialect] to render queries with [MariadbSqlDialect]; all CRUD/query
/// behaviour is inherited from the base repository.
@tomReflector
@TomRepositoryType("mariadb")
class MariadbRepository<T extends Object, K>
    extends TomSqlDatasourceRepository<T, K> {
  /// Creates a MariaDB repository for the given [queryTypes] and result type.
  MariadbRepository([super.queryTypes, super.resultType]);

  final TomStandardSqlDialect _sqlDialect = MariadbSqlDialect();

  /// The MariaDB SQL dialect used to render queries.
  @override
  TomStandardSqlDialect get sqlDialect => _sqlDialect;
}

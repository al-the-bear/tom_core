import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../datasources/mariadb_sql_dialect.dart';
import '../datasources/sql_dialects.dart';

import 'crud_repository.dart';

/// A [TomSqlDatasourceRepository] for MariaDB-backed entities.
///
/// Constructed directly — `MariadbRepository<User, int>([User])` — which is
/// what every caller and every guide does. There is no repository registry to
/// resolve it from a data-source name: the type argument is what makes a
/// repository the repository *for an entity*, and a lookup keyed on a string
/// cannot supply one.
///
/// It overrides [sqlDialect] to render queries with [MariadbSqlDialect]; all
/// CRUD/query behaviour is inherited from the base repository.
@tomReflector
class MariadbRepository<T extends Object, K>
    extends TomSqlDatasourceRepository<T, K> {
  /// Creates a MariaDB repository for the given [queryTypes] and result type.
  MariadbRepository([super.queryTypes, super.resultType]);

  final TomStandardSqlDialect _sqlDialect = MariadbSqlDialect();

  /// The MariaDB SQL dialect used to render queries.
  @override
  TomStandardSqlDialect get sqlDialect => _sqlDialect;
}

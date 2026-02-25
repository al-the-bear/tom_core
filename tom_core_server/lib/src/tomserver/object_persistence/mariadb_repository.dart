import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../datasources/mariadb_sql_dialect.dart';
import '../datasources/sql_dialects.dart';

import 'crud_repository.dart';

// TODO: inject correct implementation...

@tomReflector
@TomRepositoryType("mariadb")
class MariadbRepository<T extends Object, K>
    extends TomSqlDatasourceRepository<T, K> {
  MariadbRepository([super.queryTypes, super.resultType]);

  final TomStandardSqlDialect _sqlDialect = MariadbSqlDialect();
  @override
  TomStandardSqlDialect get sqlDialect => _sqlDialect;
}

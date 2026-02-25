import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'sql_dialects.dart';

@tomReflector
@TomSqlDialect("mariadb")
class MariadbSqlDialect extends TomStandardSqlDialect {}

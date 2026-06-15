import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'sql_dialects.dart';

/// The SQL dialect for MariaDB.
///
/// It inherits standard SQL generation unchanged from [TomStandardSqlDialect];
/// the `@TomSqlDialect("mariadb")` annotation registers it as the dialect for
/// the `"mariadb"` data-source type, and `@tomReflector` makes it discoverable
/// by the reflection-based dialect lookup. Override a fragment method here if a
/// future MariaDB-specific syntax diverges from the standard.
@tomReflector
@TomSqlDialect("mariadb")
class MariadbSqlDialect extends TomStandardSqlDialect {}

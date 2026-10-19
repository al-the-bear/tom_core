import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/sql_lexer.dart';
import '../little_things/server_exception.dart';
import 'db_migration.dart';
import 'sql_migration_adaptor.dart';

/// Thrown for MariaDB migration failures; see [TomSqlMigrationException].
class MariadbMigrationException extends TomSqlMigrationException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomSqlMigrationException].
  MariadbMigrationException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// The MariaDB [TomDbMigrator] (registered for the `"mariadb"` type); see
/// [TomSqlMigrationAdaptor] for the history, checksum and rebinding rules every
/// SQL adaptor shares.
///
/// **MariaDB does not roll DDL back.** A script is run statement by statement,
/// and a failed one is still recorded (with `success = 0`) before the error is
/// rethrown — that row is what makes [initializeMigration] refuse a schema the
/// failure left part-applied.
@TomDbMigrationAdaptor("mariadb")
@tomReflector
class MariadbMigrationAdaptor extends TomSqlMigrationAdaptor {
  @override
  String get adaptorLabel => "MariadbMigrationAdaptor";

  @override
  String get applyKeyPrefix => "mariadb_migration";

  @override
  String get initializeKeyPrefix => "mariadb_migration_adapter";

  @override
  TomServerException migrationException(
    String key,
    String message, {
    Map<String, dynamic>? parameters,
    Object? rootException,
    bool autoLog = false,
  }) => MariadbMigrationException(
    key,
    message,
    parameters: parameters,
    rootException: rootException,
    autoLog: autoLog,
  );

  @override
  String versioningTableDdl(String schemaName) =>
      '''
CREATE TABLE IF NOT EXISTS ${schemaName}_versioning (
  installedRank INTEGER(11) AUTO_INCREMENT PRIMARY KEY,
  version INTEGER(11) NOT NULL DEFAULT -1,
  description VARCHAR(500) NOT NULL DEFAULT '',
  script MEDIUMTEXT NOT NULL DEFAULT '',
  checksum VARCHAR(200) NOT NULL DEFAULT '',
  installedBy VARCHAR(30) NOT NULL DEFAULT CURRENT_USER,
  installedOn TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  executionTimeMs INTEGER(11) NOT NULL DEFAULT 0,
  success INTEGER(1) NOT NULL DEFAULT 0
);
''';

  @override
  Future<void> applyScript(
    TomDataSourceInfo dsi,
    String schemaName,
    int version,
    String description,
    String sql,
  ) async {
    final timer = Stopwatch()..start();
    Object? exception;
    try {
      // A migration script is typically a multi-statement DDL file, and the
      // driver carries one statement per call — see `TomSqlLexer`.
      for (final statement in TomSqlLexer.splitStatements(sql)) {
        await dsi.datasource.executeCommand(statement);
      }
    } catch (error) {
      exception = migrationException(
        "$applyKeyPrefix.apply_migration.failed",
        "Failed to apply migration $version, $description: $error",
        autoLog: true,
        rootException: error,
      );
    }
    // Read on both paths: a script that ran for a while and then failed is
    // precisely when the duration is worth having.
    final elapsedMs = (timer..stop()).elapsedMilliseconds;
    await recordMigration(
      dsi,
      schemaName,
      version,
      description,
      sql,
      success: exception == null,
      elapsedMs: elapsedMs,
    );
    if (exception != null) throw exception;
  }
}

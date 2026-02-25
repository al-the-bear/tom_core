import 'dart:async';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import '../datasources/datasource_initialization.dart';
import 'db_migration.dart';

class MariadbMigrationException extends TomServerException {
  MariadbMigrationException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

@TomDbMigrationAdaptor("mariadb")
@tomReflector
class MariadbMigrationAdaptor implements TomDbMigrator {
  bool _initialized = false;
  List<TomDbVersion> versions = [];

  @override
  void reset() {
    _initialized = false;
    versions = [];
  }

  @override
  Future<void> applyMigration(
    TomDataSourceInfo dsi,
    String schemaName,
    int version,
    String description,
    String sql,
  ) async {
    // check if this has already been applied
    for (var v in versions) {
      if (v.version == version) {
        if (v.description != description) {
          throw MariadbMigrationException(
            "mariadb_migration.apply_migration.description_mismatch",
            "MariadbDatabaseMigrator: Description for version $version has changed. Migrations must stay stable. Database migrations has failed.",
          );
        }
        if (int.parse(v.checksum) != sql.hashCode) {
          throw MariadbMigrationException(
            "mariadb_migration.apply_migration.checksum_mismatch",
            "MariadbDatabaseMigrator: Script checksum for version $version has changed. Migrations must stay stable. Database migrations has failed.",
          );
        }
        // version found, no need to apply
        tomLog.info(
          "Database migration $version $description for datasource ${dsi.name} schema $schemaName already applied.",
        );
        return;
      }
    }
    tomLog.info(
      "Applying migration to datasource ${dsi.name}, schema $schemaName, version $version, description $description",
    );
    // apply new migration
    Stopwatch timer = Stopwatch()..start();
    bool failed = false;
    Object? exception;
    int timeElapsedMs = 0;
    try {
      await dsi.datasource.executeCommand(sql);
      timeElapsedMs = (timer..stop()).elapsedMilliseconds;
      failed = false;
    } catch (error) {
      failed = true;
      exception = MariadbMigrationException(
        "mariadb_migration.apply_migration.failed",
        "Failed to apply migration $version, $description: $error",
        autoLog: true,
        rootException: error,
      );
    }
    String insertMigration =
        '''
INSERT INTO ${schemaName}_versioning (version, description,script,checksum,executionTimeMs,success) VALUES
("$version", "$description", "$sql", "${sql.hashCode}", $timeElapsedMs, ${failed ? "0" : "1"} );
''';
    try {
      await dsi.datasource.executeCommand(insertMigration);
    } catch (error) {
      throw MariadbMigrationException(
        "mariadb_migration.apply_migration.update_version_table_failed",
        "Failed to update/insert version table for migration $version, $description: $error",
        autoLog: true,
        rootException: error,
      );
    }
    if (failed) {
      throw exception!;
    }
    return;
  }

  @override
  Future<int> initializeMigration(
    TomDataSourceInfo dsi,
    String schemaName,
  ) async {
    if (_initialized == true) {
      throw MariadbMigrationException(
        "mariadb_migration_adapter.initialize.initialized_twice",
        "MariadbMigrationAdapter can only be initialized once",
      );
    }
    _initialized = true;
    tomLog.info(
      "Initializing database migrations for schema $schemaName in datasource $dsi",
    );
    String schemaCreate =
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
    try {
      await dsi.datasource.executeCommand(schemaCreate);
    } catch (error) {
      throw MariadbMigrationException(
        "mariadb_migration_adapter.initialize.schema_creation_failed",
        "Failed to create migration versioning schema for schema $schemaName: $error",
        autoLog: true,
        rootException: error,
      );
    }
    String versionQuery =
        '''
SELECT installedRank, version, description, checksum, installedBy, installedOn, executionTimeMs, success, script FROM ${schemaName}_versioning 
''';

    List<TomDbVersion>? currentVersions;
    try {
      currentVersions = await dsi.datasource.executeQuery<TomDbVersion>(
        versionQuery,
      );
    } catch (error) {
      throw MariadbMigrationException(
        "mariadb_migration_adapter.initialize.version_query_failed",
        "Failed to query migration versions for schema $schemaName: $error",
        autoLog: true,
        rootException: error,
      );
    }
    currentVersions.sort(
      (v1, v2) => (v1.installedRank).compareTo(v2.installedRank),
    );
    versions.addAll(currentVersions);
    if (currentVersions.isEmpty) return -1;
    return currentVersions[0].version;
  }
}

@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyField: "irrelevant",
)
class TomDbVersion {
  @TomDbColumn(columnName: "installedRank")
  int installedRank = 0;
  @TomDbColumn(columnName: "version")
  int version = 0;
  @TomDbColumn(columnName: "description")
  String description = "";
  @TomDbColumn(columnName: "script")
  String script = "";
  @TomDbColumn(columnName: "checksum")
  String checksum = "";
  @TomDbColumn(columnName: "installedBy")
  String installedBy = "";
  @TomDbColumn(columnName: "installedOn")
  DateTime installedOn = DateTime.now();
  @TomDbColumn(columnName: "success")
  int success = 0;
}

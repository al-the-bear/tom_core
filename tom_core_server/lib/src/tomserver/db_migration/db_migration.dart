import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../little_things/server_exception.dart';

class TomDbMigrationException extends TomServerException {
  TomDbMigrationException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

class TomDbMigrationAdaptor {
  final String type;

  const TomDbMigrationAdaptor(this.type);
}

abstract class TomDbMigrator {
  Future<int> initializeMigration(TomDataSourceInfo dsi, String schemaName);
  Future<void> applyMigration(
    TomDataSourceInfo dsi,
    String schemaName,
    int version,
    String description,
    String sql,
  );
  void reset();
}

class TomDbMigrations {
  static final Map<String, TomDbMigrator> _migrationAdaptorTypes = {};

  static void _initializeMigrationAdaptorTypes() {
    for (var candidate in tomReflector.annotatedClasses) {
      if (candidate.metadata.any((o) => o is TomDbMigrationAdaptor)) {
        TomDbMigrationAdaptor adaptor =
            candidate.metadata.firstWhere((o) => o is TomDbMigrationAdaptor)
                as TomDbMigrationAdaptor;
        if (_migrationAdaptorTypes[adaptor.type] != null) {
          throw TomDbMigrationException(
            "db_migration.initialization.found_more_than_one_migration_adapter",
            "Found more than one datasource migration adaptor for ${adaptor.type} first is ${_migrationAdaptorTypes[adaptor.type]}, additional found $candidate",
            autoLog: true,
          );
        } else {
          Object? migrator;
          try {
            migrator = candidate.newInstance("", []);
          } catch (error) {
            throw TomDbMigrationException(
              "db_migration.initialization.failed_to_instantiate_migrator",
              "Migration adaptor scan: Failed to instantiate migrator $candidate",
              autoLog: true,
            );
          }
          if (migrator is TomDbMigrator) {
            _migrationAdaptorTypes[adaptor.type] = migrator;
          } else {
            throw TomDbMigrationException(
              "db_migration.initialization.migrator_does_not_implement_tom_db_migrator",
              "Migration adaptor scan: Migrator class is not implementing TomDbMigrator",
              autoLog: true,
            );
          }
        }
      }
    }
  }

  static Future<void> migrateDatabases(String directory) async {
    if (_migrationAdaptorTypes.isEmpty) {
      _initializeMigrationAdaptorTypes();
    }
    Directory dir = Directory(directory);
    await for (var database in dir.list()) {
      if (database is Directory) {
        String datasourceName = p.basename(database.path);
        var dsInfo = TomDataSourceInfo.getDataSourceInfo(datasourceName);
        if (dsInfo == null) {
          throw TomDbMigrationException(
            "db_migration.migration.no_datasource_info_found",
            "Database migration failed: No Datasource info found for datasource $datasourceName",
            autoLog: true,
          );
        }
        var migrator = _migrationAdaptorTypes[dsInfo.type];
        if (migrator == null) {
          throw TomDbMigrationException(
            "db_migration.migration.no_migrator_found_for_datasource_type",
            "Database migration for datasource $datasourceName failed. No Migrator found for type ${dsInfo.type}",
            autoLog: true,
          );
        }
        migrator
            .reset(); // there might be more than one database of the same type
        await for (var schema in database.list()) {
          if (schema is Directory) {
            String schemaName = p.basename(schema.path);
            await migrator.initializeMigration(dsInfo, schemaName);
            List<File> migrations = [];
            await for (var migration in schema.list()) {
              if (migration is File) {
                migrations.add(migration);
              }
            }
            migrations.sort(
              (f1, f2) => p.basename(f1.path).compareTo(p.basename(f2.path)),
            );
            RegExp nameSplitter = RegExp(r'\[([0-9]+)]-([a-zA-Z_]+)');
            for (var migration in migrations) {
              RegExpMatch? match = nameSplitter.firstMatch(
                p.basenameWithoutExtension(migration.path),
              );
              if (match != null && match.groupCount == 2) {
                String description = "";
                int version = -1;
                try {
                  version = int.parse(match[1]!);
                } catch (error) {
                  throw TomDbMigrationException(
                    "db_migration.migration.version_parsing_failed",
                    "Failed to parse version for file ${p.basenameWithoutExtension(migration.path)}",
                    autoLog: true,
                    rootException: error,
                  );
                }
                try {
                  description = match[2]!;
                } catch (error) {
                  throw TomDbMigrationException(
                    "db_migration.migration.version_parsing_failed_description_parsing",
                    "Failed to parse description for file ${p.basenameWithoutExtension(migration.path)}",
                    autoLog: true,
                    rootException: error,
                  );
                }
                if (version >= 0 && description.isNotEmpty) {
                  await migrator.applyMigration(
                    dsInfo,
                    schemaName,
                    version,
                    description,
                    migration.readAsStringSync(),
                  );
                }
              } else {
                throw TomDbMigrationException(
                  "db_migration.migration.illegal_filename_in_migrations_directory",
                  "Illegal filename in migrations directory: ${p.basenameWithoutExtension(migration.path)}. Filename must follow [<numeric version>]-<description>.<anyfileextension> pattern.",
                  autoLog: true,
                );
              }
            }
          }
        }
      }
    }
  }
}

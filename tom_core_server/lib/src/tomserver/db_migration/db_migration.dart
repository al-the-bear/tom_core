import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../little_things/server_exception.dart';

/// Thrown when a database migration cannot be discovered, parsed, or applied
/// (missing adaptor or data source, a malformed migration filename, a failed
/// script, …).
class TomDbMigrationException extends TomServerException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomServerException].
  TomDbMigrationException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// Annotation marking a [TomDbMigrator] implementation as the migrator for a
/// named data-source [type] (e.g. `"mariadb"`). Migrators are discovered by
/// scanning [tomReflector] for this annotation.
class TomDbMigrationAdaptor {
  /// The data-source type this migrator serves (matches `TomDataSourceInfo.type`).
  final String type;

  /// Binds the annotated class to [type].
  const TomDbMigrationAdaptor(this.type);
}

/// The contract a database-specific migrator implements.
///
/// For one schema, [initializeMigration] prepares the version-tracking state
/// (e.g. creating a versioning table and reading already-applied versions) and
/// returns the earliest recorded version (or a sentinel when none). Each
/// migration script is then handed to [applyMigration] in ascending version
/// order; an already-applied version is verified (description/checksum) and
/// skipped, a new one is executed and recorded. [reset] clears per-run state so
/// one migrator instance can serve several data sources of the same type.
abstract class TomDbMigrator {
  /// Prepares version tracking for [schemaName] in data source [dsi] and
  /// returns the earliest recorded version (implementation-defined sentinel
  /// when nothing has been applied yet).
  Future<int> initializeMigration(TomDataSourceInfo dsi, String schemaName);

  /// Applies — or verifies, if already applied — the migration identified by
  /// [version] / [description] with body [sql] to [schemaName] in [dsi].
  Future<void> applyMigration(
    TomDataSourceInfo dsi,
    String schemaName,
    int version,
    String description,
    String sql,
  );

  /// Clears per-run state so this migrator can be reused for another data
  /// source of the same type.
  void reset();
}

/// The migration orchestrator: discovers migrator adaptors by reflection and
/// drives migrations from a directory tree.
///
/// The directory layout mirrors the configured data sources and their schemas:
///
/// ```text
/// <directory>/
///   <datasourceName>/        # matches a registered TomDataSourceInfo name
///     <schemaName>/          # one schema within that data source
///       [1]-create_users.sql
///       [2]-add_index.sql
/// ```
///
/// Each migration file name must match `[<numeric version>]-<description>` (the
/// description being letters and underscores), followed by any extension. Files
/// are applied in ascending name order through the data source's migrator,
/// resolved from its `type` via [TomDbMigrationAdaptor].
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

  /// Runs all pending migrations under [directory].
  ///
  /// Walks `<directory>/<datasourceName>/<schemaName>/` and, for each schema,
  /// initialises the data source's migrator and applies every
  /// `[<version>]-<description>.<ext>` file in ascending name order. Throws a
  /// [TomDbMigrationException] if a data source or migrator is missing, a file
  /// name is malformed, or a script fails.
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

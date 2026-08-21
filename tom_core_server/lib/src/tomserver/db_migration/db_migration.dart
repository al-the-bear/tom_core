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

/// A migration file name parsed into its numeric [version], [description] and
/// optional [environments] tag (C-16).
///
/// Produced by [TomDbMigrations.parseMigrationFileName] from a basename matching
/// the `[<numeric version>]-<description>[@<env>[,<env>…]]` scheme.
///
/// An **untagged** migration ([environments] empty) applies in **every**
/// environment — the safe default, so schema is never accidentally
/// environment-scoped. A **tagged** migration applies only when the active
/// environment name is one of [environments] (see [appliesInEnvironment]).
class TomMigrationFileName {
  /// The numeric version from the `[<version>]` prefix.
  final int version;

  /// The `<description>` part (letters and underscores).
  final String description;

  /// The environment names this migration is tagged for, in file order.
  ///
  /// Empty means **untagged** — the migration applies in every environment.
  /// A non-empty list restricts the migration to exactly those environments
  /// (e.g. `@dev` → `['dev']`, `@dev,test` → `['dev', 'test']`).
  final List<String> environments;

  /// Binds a parsed [version] / [description] / [environments] tag.
  const TomMigrationFileName(
    this.version,
    this.description, [
    this.environments = const [],
  ]);

  /// Whether this migration applies when the active environment is
  /// [environmentName].
  ///
  /// An untagged migration ([environments] empty) applies everywhere; a tagged
  /// one applies only when [environmentName] is in its tag list. The match is
  /// on the environment *name* directly (no hierarchy walk): a `@dev` migration
  /// is skipped under `prod`, applied under `dev`.
  bool appliesInEnvironment(String environmentName) =>
      environments.isEmpty || environments.contains(environmentName);
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

  /// The anchored migration-filename pattern: a `[<numeric version>]` prefix
  /// followed by `-<description>` (letters and underscores) and an **optional**
  /// environment tag `@<env>[,<env>…]` (C-16), spanning the *whole* basename
  /// (no surrounding text).
  static final RegExp _migrationNamePattern = RegExp(
    r'^\[([0-9]+)]-([a-zA-Z_]+)(?:@([a-zA-Z_]+(?:,[a-zA-Z_]+)*))?$',
  );

  /// Parses a migration file's [basename] (without extension) into its version,
  /// description and optional environment tag.
  ///
  /// The basename must match `[<numeric version>]-<description>[@<env>[,<env>…]]`
  /// in full; anything else — surrounding text, a digit inside the description,
  /// an empty description, a malformed tag — is rejected with a
  /// [TomDbMigrationException] (`…illegal_filename_in_migrations_directory`).
  ///
  /// The `@<env>` tag is optional: `[003]-demo_seed@dev` parses with
  /// `environments == ['dev']`, `[000]-app_core_schema` with an empty
  /// (all-environments) tag.
  static TomMigrationFileName parseMigrationFileName(String basename) {
    final match = _migrationNamePattern.firstMatch(basename);
    if (match == null) {
      throw TomDbMigrationException(
        "db_migration.migration.illegal_filename_in_migrations_directory",
        "Illegal filename in migrations directory: $basename. Filename must follow [<numeric version>]-<description>[@<env>[,<env>...]].<anyfileextension> pattern.",
        autoLog: true,
      );
    }
    final tag = match[3];
    return TomMigrationFileName(
      int.parse(match[1]!),
      match[2]!,
      tag == null ? const [] : tag.split(','),
    );
  }

  /// Parses [basenames] (file basenames without extension) and returns them
  /// ordered by **ascending numeric version**, each paired with its parsed
  /// [TomMigrationFileName].
  ///
  /// Ordering is by the parsed integer version — not lexicographic — so e.g.
  /// `[2]-…` precedes `[10]-…`. Any malformed name reaches
  /// [parseMigrationFileName] and throws.
  static List<({String basename, TomMigrationFileName parsed})>
  orderMigrationNames(Iterable<String> basenames) {
    final parsed = basenames
        .map((b) => (basename: b, parsed: parseMigrationFileName(b)))
        .toList();
    parsed.sort((a, b) => a.parsed.version.compareTo(b.parsed.version));
    return parsed;
  }

  /// The environment name migrations are filtered against (C-16).
  ///
  /// Resolved via [TomRuntime] — never a raw `Platform`/env-var read (G-ENV-1).
  /// When no environment has been initialized the engine falls back to
  /// [defaultTomEnvironment]: the production-safe default, under which only
  /// untagged migrations apply and every `@dev`/`@test`-tagged migration is
  /// skipped.
  static String resolveActiveEnvironment() {
    // TomRuntime.getCurrentEnvironment throws when nothing has been
    // initialized; that documented state maps to the production-safe default.
    try {
      return TomRuntime.getCurrentEnvironment().env;
    } on Exception {
      return defaultTomEnvironment.env;
    }
  }

  /// Filters an [ordered] migration list to those applying in [environmentName]
  /// (C-16), preserving order.
  ///
  /// A migration whose parsed tag does not include [environmentName] is skipped;
  /// untagged (schema) migrations always pass. Skipping is a pure omission — the
  /// applied-version bookkeeping is unchanged, so a re-run in the same
  /// environment stays idempotent.
  static List<({String basename, TomMigrationFileName parsed})>
  selectForEnvironment(
    Iterable<({String basename, TomMigrationFileName parsed})> ordered,
    String environmentName,
  ) => [
    for (final entry in ordered)
      if (entry.parsed.appliesInEnvironment(environmentName)) entry,
  ];

  /// Runs all pending migrations under [directory].
  ///
  /// Walks `<directory>/<datasourceName>/<schemaName>/` and, for each schema,
  /// initialises the data source's migrator and applies every
  /// `[<version>]-<description>[@<env>…].<ext>` file in ascending version order.
  /// Migrations tagged for an environment other than the active one
  /// ([resolveActiveEnvironment]) are skipped (C-16); untagged migrations always
  /// apply. Throws a [TomDbMigrationException] if a data source or migrator is
  /// missing, a file name is malformed, or a script fails.
  static Future<void> migrateDatabases(String directory) async {
    if (_migrationAdaptorTypes.isEmpty) {
      _initializeMigrationAdaptorTypes();
    }
    final environmentName = resolveActiveEnvironment();
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
            Map<String, File> migrations = {};
            await for (var migration in schema.list()) {
              if (migration is File) {
                migrations[p.basenameWithoutExtension(migration.path)] =
                    migration;
              }
            }
            // Parse + validate the names, apply in ascending version order
            // (numeric, so [2] precedes [10]) and skip any migration tagged for
            // a non-active environment (C-16); a malformed name throws.
            final ordered = orderMigrationNames(migrations.keys);
            for (final entry in selectForEnvironment(
              ordered,
              environmentName,
            )) {
              await migrator.applyMigration(
                dsInfo,
                schemaName,
                entry.parsed.version,
                entry.parsed.description,
                migrations[entry.basename]!.readAsStringSync(),
              );
            }
          }
        }
      }
    }
  }
}

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
/// A migrator instance serves **one schema at a time**. [initializeMigration]
/// binds it to a `(data source, schema)` pair and prepares that pair's
/// version-tracking state (e.g. creating a versioning table and reading
/// already-applied versions). Each migration script is then handed to
/// [applyMigration] in ascending version order; an already-applied version is
/// verified (description/checksum) and skipped, a new one is executed and
/// recorded. [reset] releases the binding so the same instance can serve the
/// next pair.
///
/// The unit of state is the **pair**, not the data source: one data source
/// routinely holds several schemas, and each keeps its own applied-version
/// history. A migrator that carried one schema's history into the next would
/// treat the next schema's version 1 as already applied and skip it. The
/// orchestrator therefore resets once per schema, not once per data source —
/// see [TomDbMigrations.migrateDataSource].
abstract class TomDbMigrator {
  /// Binds this migrator to [schemaName] in data source [dsi] and prepares that
  /// pair's version tracking.
  ///
  /// Binding is a **rebind**: whatever pair the instance was serving before is
  /// dropped, along with its applied-version state. An implementation must not
  /// accumulate — the version list after this call describes [schemaName] and
  /// nothing else.
  ///
  /// Returns nothing on purpose. The applied-version history it loads is the
  /// useful output, and no single number stands for it: "the earliest version"
  /// and "the version installed first" are different numbers the moment
  /// migrations are applied out of numeric order, which environment tags
  /// (C-16) make ordinary. The history belongs to the implementation that
  /// knows how to represent it — see [MariadbMigrationAdaptor.versions].
  Future<void> initializeMigration(TomDataSourceInfo dsi, String schemaName);

  /// Applies — or verifies, if already applied — the migration identified by
  /// [version] / [description] with body [sql] to [schemaName] in [dsi].
  Future<void> applyMigration(
    TomDataSourceInfo dsi,
    String schemaName,
    int version,
    String description,
    String sql,
  );

  /// Releases the current `(data source, schema)` binding and its
  /// applied-version state, so this instance can serve the next pair.
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
///       [3]-demo_seed@dev.sql    # only under the `dev` environment
/// ```
///
/// Each migration file name must match
/// `[<numeric version>]-<description>[@<env>[,<env>…]]` — the description being
/// letters and underscores, the environment tag optional — followed by any
/// extension. This is the grammar [parseMigrationFileName] enforces and quotes
/// back when it refuses a name.
///
/// Files are applied in ascending **numeric version** order, not name order:
/// the sort is on the parsed integer, so `[2]` precedes `[10]` where a
/// lexicographic sort would not. They run through the data source's migrator,
/// resolved from its `type` via [TomDbMigrationAdaptor]. A migration tagged for
/// an environment other than the active one is skipped (C-16) — see
/// [TomMigrationFileName.appliesInEnvironment] and
/// [resolveActiveEnvironment].
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
          _migrationAdaptorTypes[adaptor.type] = instantiateMigrator(
            candidate,
            () => candidate.newInstance("", []),
          );
        }
      }
    }
  }

  /// Builds one scanned adaptor candidate, turning either failure mode — a
  /// constructor that throws, or a class that does not implement
  /// [TomDbMigrator] — into a [TomDbMigrationException] naming [candidate].
  ///
  /// When [construct] throws, the error and its trace are forwarded as the
  /// raised exception's root cause. This is a startup failure on a reflective
  /// code path: the candidate's name alone says *which* class could not be
  /// built but nothing about *why* — a missing zero-argument constructor, a
  /// throwing field initialiser, a failed dependency lookup all read alike —
  /// and that is precisely the context an operator cannot reconstruct from the
  /// outside. Forwarding the caught trace rather than letting the exception
  /// capture its own matters for the same reason: captured here, the trace
  /// describes the scan, from which the constructor has already unwound.
  ///
  /// Split out of the scan and parameterised by [construct] rather than taking
  /// the reflected class, because the scan reads a global registry a test
  /// cannot populate — and populating it would be worse than untestable, since
  /// a fixture whose constructor throws would break the scan for every real
  /// caller. The one call the scan makes on the mirror is therefore the seam,
  /// leaving [candidate] to carry the identity for the message.
  static TomDbMigrator instantiateMigrator(
    Object? candidate,
    Object? Function() construct,
  ) {
    Object? migrator;
    try {
      migrator = construct();
    } catch (error, stack) {
      throw TomDbMigrationException(
        "db_migration.initialization.failed_to_instantiate_migrator",
        "Migration adaptor scan: Failed to instantiate migrator $candidate: $error",
        autoLog: true,
        rootException: error,
        stack: stack,
      );
    }
    if (migrator is! TomDbMigrator) {
      throw TomDbMigrationException(
        "db_migration.initialization.migrator_does_not_implement_tom_db_migrator",
        "Migration adaptor scan: Migrator class $candidate is not implementing TomDbMigrator",
        autoLog: true,
      );
    }
    return migrator;
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

  /// Asserts that [directory] — playing the role named by [role] — exists,
  /// throwing `db_migration.migration.migrations_directory_not_found` if it does
  /// not.
  ///
  /// A migration tree a tool is *told* to walk is an input, not content: absent,
  /// it means the configured path is wrong, not that the deployment has no
  /// migrations. Tolerating it is the worst available outcome, because both
  /// tools then succeed vacuously — the engine reports migrations complete
  /// against an untouched database, and
  /// [TomSchemaConvergenceCheck.checkAll] returns an empty report list that no
  /// call site can tell apart from "every pair converged".
  ///
  /// A **relative** path is reported with what it resolved to as well, because
  /// its usual cause is the right path read from the wrong working directory,
  /// and the path alone cannot distinguish that from a typo. An absolute one is
  /// already unambiguous and is not repeated.
  ///
  /// Shared with the convergence check for the reason [collectMigrationFiles]
  /// and [orderMigrationNames] are: two entry points over one tree must not
  /// disagree about whether the tree being absent is a failure.
  static void requireMigrationsDirectory(Directory directory, String role) {
    if (directory.existsSync()) return;
    final where = p.isAbsolute(directory.path)
        ? directory.path
        : "${directory.path} (resolved to ${directory.absolute.path})";
    throw TomDbMigrationException(
      "db_migration.migration.migrations_directory_not_found",
      "$role not found: $where. The migration tree has to exist where it is "
          "configured — check the path and the working directory the process "
          "was started in.",
      autoLog: true,
    );
  }

  /// Collects the migration files among [entries], keyed by basename without
  /// extension — the key everything downstream identifies a migration by.
  ///
  /// Two files whose basenames collide (`[3]-add_index.sql` and
  /// `[3]-add_index.ddl`, or a stray `[3]-add_index.orig` beside the real
  /// migration) throw
  /// `db_migration.migration.duplicate_migration_basename`, naming both paths.
  ///
  /// The alternative — keeping whichever the directory listing yielded last —
  /// is not a tie-break but a coin toss, and a silent one: the run proceeds as
  /// though the tree had always held a single file. It is also the wrong shape
  /// for this module, which aborts on a name it cannot parse precisely because
  /// a surprising file in a migrations directory is more likely a migration
  /// nobody noticed was not running than deliberate clutter. A duplicate is
  /// that same hazard with a sharper edge: an editor backup ending in `.orig`
  /// strips to the same key as the `.sql` it was a backup *of*, so the losing
  /// file can be the one that was meant to run.
  ///
  /// Non-file entries are skipped, so a sub-directory in a schema folder is
  /// ignored rather than collected.
  ///
  /// Shared with [TomSchemaConvergenceCheck.readChain] for the reason
  /// [orderMigrationNames] is: a check that accepted a tree the engine refuses
  /// would report a chain that cannot be applied.
  static Map<String, File> collectMigrationFiles(
    Iterable<FileSystemEntity> entries,
  ) {
    final files = <String, File>{};
    for (final entry in entries) {
      if (entry is! File) continue;
      final basename = p.basenameWithoutExtension(entry.path);
      final existing = files[basename];
      if (existing != null) {
        // Sorted, not listing order: the same broken tree has to produce the
        // same message on every machine.
        final pair = [existing.path, entry.path]..sort();
        throw TomDbMigrationException(
          "db_migration.migration.duplicate_migration_basename",
          "Duplicate migration filename in migrations directory: $basename. "
              "A migration is identified by its filename without extension, so "
              "${pair.first} and ${pair.last} cannot be told apart. Remove or "
              "rename one.",
          autoLog: true,
        );
      }
      files[basename] = entry;
    }
    return files;
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
  /// `[<version>]-<description>[@<env>[,<env>…]].<ext>` file in ascending
  /// numeric version order.
  /// Migrations tagged for an environment other than the active one
  /// ([resolveActiveEnvironment]) are skipped (C-16); untagged migrations always
  /// apply. Throws a [TomDbMigrationException] if [directory] does not exist, a
  /// data source or migrator is missing, a file name is malformed, or a script
  /// fails.
  static Future<void> migrateDatabases(String directory) async {
    Directory dir = Directory(directory);
    // Validated before the adaptor scan: the path is the argument this call was
    // handed, and answering a wrong one with "reflection has not been
    // initialized" names the wrong problem entirely.
    requireMigrationsDirectory(dir, 'Migrations directory');
    if (_migrationAdaptorTypes.isEmpty) {
      _initializeMigrationAdaptorTypes();
    }
    final environmentName = resolveActiveEnvironment();
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
        await migrateDataSource(migrator, dsInfo, database, environmentName);
      }
    }
  }

  /// Applies every schema under [dataSourceDirectory] to data source [dsInfo]
  /// through [migrator], selecting migrations for [environmentName].
  ///
  /// Each immediate sub-directory is one schema. Per schema the migrator is
  /// **reset and then re-initialised**, because a migrator's applied-version
  /// state belongs to one `(data source, schema)` pair: resetting once for the
  /// whole data source would let the first schema's history stand for the
  /// second's, and the second schema's version 1 would be silently skipped as
  /// already applied. Within a schema, files are applied in ascending numeric
  /// version order, skipping any tagged for another environment (C-16).
  ///
  /// Split out of [migrateDatabases] so the walk can be driven with a
  /// caller-supplied [migrator] — the reflection-scanned registry
  /// [migrateDatabases] resolves from is not injectable, which left this
  /// per-schema lifecycle testable only against a live server.
  static Future<void> migrateDataSource(
    TomDbMigrator migrator,
    TomDataSourceInfo dsInfo,
    Directory dataSourceDirectory,
    String environmentName,
  ) async {
    requireMigrationsDirectory(
      dataSourceDirectory,
      'Migrations directory for data source ${dsInfo.name}',
    );
    await for (var schema in dataSourceDirectory.list()) {
      if (schema is Directory) {
        String schemaName = p.basename(schema.path);
        migrator.reset();
        await migrator.initializeMigration(dsInfo, schemaName);
        // Collected before anything is applied, so a directory holding two
        // files that claim the same version aborts the schema instead of
        // applying whichever one the listing happened to favour.
        final migrations = collectMigrationFiles(await schema.list().toList());
        // Parse + validate the names, apply in ascending version order
        // (numeric, so [2] precedes [10]) and skip any migration tagged for
        // a non-active environment (C-16); a malformed name throws.
        final ordered = orderMigrationNames(migrations.keys);
        for (final entry in selectForEnvironment(ordered, environmentName)) {
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

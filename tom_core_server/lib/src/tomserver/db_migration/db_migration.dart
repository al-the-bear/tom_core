import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../cmdline/args.dart';
import '../datasources/datasource_initialization.dart';
import '../little_things/server_exception.dart';
import '../tenancy/tenancy.dart';
import '../tenancy/tenant_registry.dart';
import '../tenancy/tenant_type.dart';
import 'migration_run.dart';
import 'schema_versions.dart';

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
/// named data-source [type] (e.g. `"mariadb"`), and for every type in
/// [alsoServes] — the two-phase variant of a database speaks the same SQL as
/// the plain one. Migrators are discovered by scanning [tomReflector] for this
/// annotation; one instance serves all of its types.
class TomDbMigrationAdaptor {
  /// The data-source type this migrator serves (matches `TomDataSourceInfo.type`).
  final String type;

  /// Further data-source types this migrator serves.
  final List<String> alsoServes;

  /// Binds the annotated class to [type] and [alsoServes].
  const TomDbMigrationAdaptor(this.type, {this.alsoServes = const []});
}

/// One migration's scripts, as a rollback reads them from the tree: the
/// [description] and the [up] script it was applied with, and its [down]
/// script — `null` when the tree has none.
class TomMigrationScript {
  /// The scripts of one migration.
  const TomMigrationScript(this.description, this.up, [this.down]);

  /// The description from the file name.
  final String description;

  /// The script the migration was applied with.
  final String up;

  /// The script that undoes it, or `null`.
  final String? down;
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

  /// The migrations applied successfully to [schemaName] in [dsi], version to
  /// recorded script — empty when nothing was ever applied there. Read only:
  /// it creates no versioning table and binds nothing. What the schema version
  /// guard compares with the code ([TomDbMigrations.checkSystemSchema]).
  Future<Map<int, String>> appliedScripts(
    TomDataSourceInfo dsi,
    String schemaName,
  );

  /// Runs [body] holding [dsi]'s migration lock: one migration run per
  /// database at a time, across every process that migrates it.
  ///
  /// A second process waits for the first to finish, then finds its
  /// migrations applied and skips them. The lock is released when [body]
  /// returns or throws, and by the database when the process holding it dies.
  /// Re-entrant, so a caller may hold it around several runs — every tenant's
  /// — and the runs inside take it without waiting for themselves.
  Future<R> withMigrationLock<R>(
    TomDataSourceInfo dsi,
    Future<R> Function() body,
  );

  /// Resolves the failed record of migration [version] in [schemaName] — the
  /// record that makes [initializeMigration] refuse the schema — by [action],
  /// under the migration lock.
  ///
  /// Repair changes the history only; it never runs a script. The next
  /// migration run applies a [TomMigrationRepair.remove]d migration again and
  /// skips a [TomMigrationRepair.markResolved] one.
  Future<void> repair(
    TomDataSourceInfo dsi,
    String schemaName,
    int version,
    TomMigrationRepair action,
  );

  /// Undoes every migration of [schemaName] applied above [toVersion] — all
  /// of them for `-1` — newest first by installation order, with the down
  /// scripts of [scripts] (keyed by version), and answers the versions it
  /// undid in that order.
  ///
  /// Checked before anything runs: every migration to undo has a down script
  /// and is recorded with the description and the up script [scripts] holds.
  /// The caller holds the migration lock.
  Future<List<int>> rollback(
    TomDataSourceInfo dsi,
    String schemaName,
    int toVersion,
    Map<int, TomMigrationScript> scripts,
  );
}

/// What [TomDbMigrator.repair] does with a migration recorded as failed.
///
/// The operator chooses by what was done to the schema the failed script left
/// part-applied.
enum TomMigrationRepair {
  /// Deletes the failed record, so the next run applies the migration again —
  /// after the operator undid what the script left behind, and perhaps
  /// corrected the script.
  remove,

  /// Marks the failed record applied, so the next run skips the migration —
  /// after the operator finished by hand what the script set out to do. The
  /// script file must stay as recorded: a changed one fails the next run's
  /// checksum check.
  markResolved,
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
/// One root holds two trees ([migrateAll]):
///
/// ```text
/// <root>/
///   system/                  # the system schema
///     <datasourceName>/      # a registered TomDataSourceInfo name
///       <schemaName>/        # one history (versioning table) of it
///         [1]-create_users.sql
///         [2]-add_index.sql
///         [3]-demo_seed@dev.sql    # only under the `dev` environment
///   tenant/                  # the tenants' tables
///     <type>/                # one tree per tenant type
///       <datasourceName>/    # a data source the type routes
///         [1]-create_invoice.sql
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
  static final Map<String, TomDbMigrator Function()> _migrationAdaptorTypes =
      {};

  static void _initializeMigrationAdaptorTypes() {
    for (var candidate in tomReflector.annotatedClasses) {
      if (candidate.metadata.any((o) => o is TomDbMigrationAdaptor)) {
        TomDbMigrationAdaptor adaptor =
            candidate.metadata.firstWhere((o) => o is TomDbMigrationAdaptor)
                as TomDbMigrationAdaptor;
        final types = [adaptor.type, ...adaptor.alsoServes];
        for (final type in types) {
          if (_migrationAdaptorTypes[type] != null) {
            throw TomDbMigrationException(
              "db_migration.initialization.found_more_than_one_migration_adapter",
              "Found more than one datasource migration adaptor for $type first is ${_migrationAdaptorTypes[type]}, additional found $candidate",
              autoLog: true,
            );
          }
        }
        TomDbMigrator create() =>
            instantiateMigrator(candidate, () => candidate.newInstance("", []));
        // Built once here, so a candidate that cannot be built fails the
        // scan rather than the first migration.
        create();
        for (final type in types) {
          _migrationAdaptorTypes[type] = create;
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

  /// The names, lower-cased, that a schema directory may hold without them
  /// being migrations.
  ///
  /// Everything on this list is written by something other than the author of
  /// the migration chain: a file explorer (`thumbs.db`, `desktop.ini`) or a
  /// person documenting the directory (`readme.md`). `.DS_Store`, `.gitkeep`
  /// and an editor's swap file need no entry — they are dot-files, which
  /// [isNotAMigrationFile] skips as a class.
  static const Set<String> _nonMigrationFileNames = {
    'readme.md',
    'thumbs.db',
    'desktop.ini',
  };

  /// Whether [name] — a file's basename *with* its extension — is one a schema
  /// directory may hold that is not a migration.
  ///
  /// A file in a schema directory whose name does not parse is refused, and
  /// that stays: a surprising file there is more likely a migration nobody
  /// noticed was not running than deliberate clutter, and the cost of the two
  /// mistakes is not symmetric. But the argument is about files *a developer
  /// put there*. It does not reach the ones an operating system, a file
  /// explorer or an editor writes without being asked, and for those the
  /// refusal is a hard startup failure whose fix is to delete a file the
  /// operator did not create.
  ///
  /// So two classes are skipped, and only two:
  ///
  /// * **dot-files** — `.DS_Store`, `.gitkeep`, `.gitignore`, and the swap file
  ///   an editor leaves beside the migration it has open, whose name begins
  ///   with a dot. A dot-file is hidden by convention on every platform this
  ///   runs on, which is as close as a file system comes to saying "not
  ///   content";
  /// * the fixed list [_nonMigrationFileNames], matched case-insensitively.
  ///
  /// Everything else still aborts, which is the point of drawing the line here
  /// rather than at the extension. `[3]-add_index.sqll` is a mis-typed
  /// migration, `[3]-add_index.orig` is an editor's backup of one — under an
  /// extension filter both would be invisible, and the file that was meant to
  /// run would simply not run. Under this rule both are still reported, the
  /// second as a duplicate basename.
  static bool isNotAMigrationFile(String name) =>
      name.startsWith('.') ||
      _nonMigrationFileNames.contains(name.toLowerCase());

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
  /// ignored rather than collected, and so are the entries
  /// [isNotAMigrationFile] recognises — the files a machine put in the
  /// directory rather than a person.
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
      if (isNotAMigrationFile(p.basename(entry.path))) continue;
      final basename = p.basenameWithoutExtension(entry.path);
      if (isDownMigration(basename)) continue;
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

  /// The suffix that marks a down script: `[3]-add_column.down.sql` undoes
  /// `[3]-add_column.sql`.
  static const String downSuffix = '.down';

  /// Whether [basename] (without its extension) names a down script.
  static bool isDownMigration(String basename) => basename.endsWith(downSuffix);

  /// The down scripts among [entries], keyed by the basename of the
  /// migration each undoes. Two files undoing one migration are refused with
  /// `db_migration.migration.duplicate_migration_basename`, as two up files
  /// are.
  static Map<String, File> collectDownMigrationFiles(
    Iterable<FileSystemEntity> entries,
  ) {
    final files = <String, File>{};
    for (final entry in entries) {
      if (entry is! File) continue;
      if (isNotAMigrationFile(p.basename(entry.path))) continue;
      final basename = p.basenameWithoutExtension(entry.path);
      if (!isDownMigration(basename)) continue;
      final up = basename.substring(0, basename.length - downSuffix.length);
      final existing = files[up];
      if (existing != null) {
        final pair = [existing.path, entry.path]..sort();
        throw TomDbMigrationException(
          "db_migration.migration.duplicate_migration_basename",
          "Duplicate down script in migrations directory for $up: "
              "${pair.first} and ${pair.last}. Remove or rename one.",
          autoLog: true,
        );
      }
      files[up] = entry;
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
  ///
  /// Two names claiming the same version throw
  /// `db_migration.migration.duplicate_migration_version`, naming both. A
  /// version is what the versioning table records and what a migrator decides
  /// "already applied" from, so a pair sharing one cannot both be recorded
  /// distinguishably — and the damage outlives the run that causes it. Both
  /// scripts apply in the first pass (a migrator's applied-version list is a
  /// snapshot taken at initialisation, so the second call cannot see the
  /// first), in an order the sort does not define, and the table is left with
  /// two rows for one version; the *next* run meets the first of them while
  /// being offered the second's script, and reports a description or checksum
  /// mismatch — accusing someone of editing a past migration when nobody did.
  ///
  /// Checked on the parsed integer, so `[1]` and `[001]` collide as they
  /// should, and checked **before** environment selection, so a tagged and an
  /// untagged file cannot share a version either. The tag does not make the
  /// pair safe: it only decides which of them runs *here*, while the row they
  /// collide over is written to a history that a box switched between
  /// environments will read back. A tree that is valid on some machines and
  /// broken on others is the failure this module exists to prevent, so the
  /// answer cannot depend on the active environment — and
  /// [TomSchemaConvergenceCheck.readChain], which shares this helper, has no
  /// environment to depend on in the first place.
  static List<({String basename, TomMigrationFileName parsed})>
  orderMigrationNames(Iterable<String> basenames) {
    final parsed = basenames
        .map((b) => (basename: b, parsed: parseMigrationFileName(b)))
        .toList();
    final byVersion = <int, String>{};
    for (final entry in parsed) {
      final existing = byVersion[entry.parsed.version];
      if (existing != null) {
        // Sorted, not input order: the input is a directory listing, and the
        // same broken tree has to produce the same message on every machine.
        final pair = [existing, entry.basename]..sort();
        throw TomDbMigrationException(
          "db_migration.migration.duplicate_migration_version",
          "Duplicate migration version in migrations directory: version "
              "${entry.parsed.version} is claimed by both ${pair.first} and "
              "${pair.last}. A migration is recorded and skipped by its "
              "version, so two files sharing one cannot be told apart once "
              "they are applied. Renumber one of them.",
          autoLog: true,
        );
      }
      byVersion[entry.parsed.version] = entry.basename;
    }
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

  /// The configuration path of the migration settings:
  ///
  /// ```yaml
  /// migrations:
  ///   onStart: true         # TomServer.start runs migrateAll
  ///   root: ./database_migrations   # default: databaseMigrationsDirectory
  ///   parallelism: 2        # tenants migrated at once; default 1
  /// ```
  static const String configurationKey = 'migrations';

  /// The history label of tenant type [type]'s tree: its versioning table is
  /// `tenant_<type>_versioning` in every target the tree is applied to, apart
  /// from the system tree's labels even where a type's shared schema is the
  /// system schema.
  static String tenantHistoryLabel(String type) => 'tenant_$type';

  /// The directory of tenant type [type]'s tree: its own
  /// [TomTenantType.migrations] when it names one, else
  /// `<root>/tenant/<type>`.
  static String tenantTreeOf(String root, TomTenantType? type, String name) =>
      type?.migrations ?? TomTenantType.treeUnder(root, name);

  /// Migrates the system schema, then every tenant by its type.
  ///
  /// The tree under [root]:
  ///
  /// ```text
  /// <root>/
  ///   system/<datasource>/<schema>/   # a chain of migration files
  ///   tenant/<type>/<datasource>/     # a chain of migration files
  /// ```
  ///
  /// In order:
  ///
  /// 1. `system/` — every `<datasource>/<schema>/` chain applied to the
  ///    registered (unrouted) data source, under its migration lock. **A
  ///    failure is fatal**: it is recorded, rethrown, and nothing else runs.
  /// 2. Each tenant type's **shared schema**, once, for the type's
  ///    shared-isolation tenants: the type's tree applied to the schema they
  ///    share (the system schema for the type `default`).
  /// 3. Each tenant with a schema or database of its own, by its type's tree.
  ///
  /// Steps 2 and 3 run at most [parallelism] targets at once. Each target is
  /// migrated under its database's migration lock and the registry's lock of
  /// the target ([TomTenantRegistry.withMigrationLock]), so two processes
  /// never migrate one tenant at once. Its tenants go `migrating`, then
  /// `active` — a `suspended` tenant stays suspended — with the highest
  /// applied version per data source recorded ([TomTenantRegistry.setMigrated]),
  /// or `migration-failed` with the error as the status detail; **a failing
  /// target does not stop the others**. The result lists every target's run.
  ///
  /// A type's tree is applied with the history label [tenantHistoryLabel], so
  /// each target keeps its own versioning table. Its `<datasource>` folders
  /// must be data sources the type routes
  /// (`db_migration.tenant.unrouted_datasource`), and every folder under
  /// `tenant/` must be a declared type (`db_migration.tenant.undeclared_type`);
  /// any entry at the root other than `system/` and `tenant/` is refused
  /// (`db_migration.layout.unknown_entry`). All of it is checked before
  /// anything runs.
  ///
  /// Without an installed [TomTenancy] only `system/` and the implicit type
  /// `default`'s tree are applied — the latter to the registered data sources
  /// themselves, as the shared schema of the implicit tenant.
  ///
  /// [tenant] migrates that one tenant's target alone — its own, or its
  /// type's shared schema for a shared tenant — and not the system schema.
  /// [migrators] supplies the migrator of each target, a fresh one per
  /// target by default ([newMigratorFor]).
  static Future<TomMigrationResult> migrateAll(
    String root, {
    int parallelism = 1,
    String? tenant,
    TomDbMigrator Function(TomDataSourceInfo dsInfo)? migrators,
  }) async {
    if (parallelism < 1) {
      throw TomDbMigrationException(
        'db_migration.migration.invalid_parallelism',
        'Migrations run at least one target at a time; got $parallelism.',
        parameters: {'parallelism': parallelism},
      );
    }
    final migratorOf = migrators ?? newMigratorFor;
    final environmentName = resolveActiveEnvironment();
    final tenancy = TomTenancy.current;
    final runs = <TomMigrationRun>[];
    _currentRuns.clear();
    // The system schema's run covers the checks of the whole tree as well: a
    // root that is missing or malformed fails the system schema, so readiness
    // reports it.
    final systemRun = tenant == null
        ? _start(
            TomMigrationRun.systemTarget,
            TomMigrationTargetKind.system,
            const [],
          )
        : null;
    final List<_TomTenantTarget> plan;
    try {
      // Validated before the adaptor scan: the path is the argument this call
      // was handed, and answering a wrong one with "reflection has not been
      // initialized" names the wrong problem entirely.
      requireMigrationsDirectory(Directory(root), 'Migrations directory');
      if (migrators == null && _migrationAdaptorTypes.isEmpty) {
        _initializeMigrationAdaptorTypes();
      }
      plan = _planTenantTargets(root, tenancy, tenant);
      final system = Directory(p.join(root, systemTreeName));
      if (systemRun != null && system.existsSync()) {
        for (final database in _subdirectoriesOf(system)) {
          final dsInfo = _baseInfoOf(p.basename(database.path));
          await migrateDataSource(
            migratorOf(dsInfo),
            dsInfo,
            database,
            environmentName,
          );
        }
      }
    } catch (error) {
      if (systemRun != null) runs.add(_finish(systemRun, error));
      rethrow;
    }
    if (systemRun != null) runs.add(_finish(systemRun, null));

    final shared = [
      for (final target in plan)
        if (target.kind == TomMigrationTargetKind.shared) target,
    ];
    final own = [
      for (final target in plan)
        if (target.kind == TomMigrationTargetKind.tenant) target,
    ];
    for (final phase in [shared, own]) {
      final results = List<TomMigrationRun?>.filled(phase.length, null);
      var next = 0;
      Future<void> worker() async {
        while (next < phase.length) {
          final index = next++;
          results[index] = await _migrateTenantTarget(
            phase[index],
            tenancy,
            migratorOf,
            environmentName,
          );
        }
      }

      await Future.wait([
        for (var i = 0; i < min(parallelism, phase.length); i++) worker(),
      ]);
      runs.addAll(results.whereType<TomMigrationRun>());
    }
    final result = TomMigrationResult(runs);
    for (final run in result.failed) {
      tomLog.warn('Migration of ${run.target} failed: ${run.error}');
    }
    return result;
  }

  /// The folder of the system tree under a migration root.
  static const String systemTreeName = 'system';

  /// The folder of the tenant types' trees under a migration root.
  static const String tenantTreesName = 'tenant';

  /// The registered data source [name] itself, unrouted: the system schema.
  static TomDataSourceInfo _baseInfoOf(String name) {
    final info = TomDataSourceInfo.getBaseDataSourceInfo(name);
    if (info == null) {
      throw TomDbMigrationException(
        "db_migration.migration.no_datasource_info_found",
        "Database migration failed: No Datasource info found for datasource $name",
        autoLog: true,
      );
    }
    return info;
  }

  /// The tenant targets of [root], checked before anything runs.
  static List<_TomTenantTarget> _planTenantTargets(
    String root,
    TomTenancy? tenancy,
    String? only,
  ) {
    for (final entry in Directory(root).listSync()) {
      final name = p.basename(entry.path);
      if (isNotAMigrationFile(name)) continue;
      if (entry is Directory &&
          (name == systemTreeName || name == tenantTreesName)) {
        continue;
      }
      throw TomDbMigrationException(
        'db_migration.layout.unknown_entry',
        "The migration root $root holds '$name'; it holds only "
            "'$systemTreeName/' (<datasource>/<schema>/ chains for the system "
            "schema) and '$tenantTreesName/' (<type>/<datasource>/ chains for "
            'the tenants of each type).',
        parameters: {'root': root, 'entry': name},
      );
    }
    final Map<String, TomTenantType?> declared =
        tenancy?.types ?? {TomTenant.defaultType: null};
    final trees = Directory(p.join(root, tenantTreesName));
    if (trees.existsSync()) {
      for (final entry in trees.listSync()) {
        if (entry is! Directory) continue;
        final type = p.basename(entry.path);
        if (!declared.containsKey(type)) {
          throw TomDbMigrationException(
            'db_migration.tenant.undeclared_type',
            "The migration tree of tenant type '$type' belongs to no declared "
                'type.',
            parameters: {'type': type},
          );
        }
      }
    }
    final routedOf = <String, Set<String>>{
      for (final name in declared.keys)
        name: tenancy == null
            ? TomDataSourceInfo.datasources.keys.toSet()
            : tenancy.datasourcesOf(tenancy.types[name]!),
    };
    final treeOf = <String, Directory>{};
    for (final name in declared.keys) {
      final tree = Directory(tenantTreeOf(root, declared[name], name));
      if (!tree.existsSync()) continue;
      for (final entry in tree.listSync()) {
        if (entry is! Directory) continue;
        final datasource = p.basename(entry.path);
        if (!routedOf[name]!.contains(datasource)) {
          throw TomDbMigrationException(
            'db_migration.tenant.unrouted_datasource',
            "The tree of tenant type '$name' migrates the data source "
                "'$datasource', which the type does not route: its tenant "
                'tables would land in the system schema.',
            parameters: {'type': name, 'datasource': datasource},
          );
        }
      }
      treeOf[name] = tree;
    }

    if (tenancy == null) {
      if (only != null) throw TomTenancy.unknownTenant(only);
      final tree = treeOf[TomTenant.defaultType];
      return [
        if (tree != null)
          _TomTenantTarget(
            TomMigrationTargetKind.shared,
            TomTenant.defaultType,
            tree,
            const [],
          ),
      ];
    }
    if (only != null && !tenancy.tenants.containsKey(only)) {
      throw TomTenancy.unknownTenant(only);
    }
    final sharedOf = <String, List<String>>{};
    final targets = <_TomTenantTarget>[];
    for (final t in tenancy.tenants.values) {
      final tree = treeOf[t.type];
      if (tree == null) continue;
      if (tenancy.isolationOf(t) == TomTenantIsolation.shared) {
        (sharedOf[t.type] ??= []).add(t.id);
      } else if (only == null || only == t.id) {
        targets.add(
          _TomTenantTarget(TomMigrationTargetKind.tenant, t.type, tree, [t.id]),
        );
      }
    }
    final onlyType = only == null ? null : tenancy.tenants[only]!.type;
    return [
      for (final MapEntry(key: type, value: ids) in sharedOf.entries)
        if (only == null || (ids.contains(only) && onlyType == type))
          _TomTenantTarget(
            TomMigrationTargetKind.shared,
            type,
            treeOf[type]!,
            ids..sort(),
          ),
      ...targets,
    ];
  }

  /// Migrates the target of the installed tenancy's tenant [tenantId] by its
  /// type's tree — its own schema or database, or its type's shared schema
  /// for a shared tenant — and answers the run, or `null` when the type has
  /// no tree (its [TomTenantType.migrations], else `<root>/tenant/<type>`
  /// with [root]). As [migrateAll] does for one target: `migrating`, then
  /// `active` or `migration-failed`, under the registry's lock, recorded in
  /// [runs]; it does not throw for a failed migration — the run says so.
  /// [tenancy] is the installed one unless given. What `TomTenancy.addTenant`
  /// and `migrateTenant` call.
  static Future<TomMigrationRun?> migrateTenant(
    String tenantId, {
    String? root,
    TomTenancy? tenancy,
    TomDbMigrator Function(TomDataSourceInfo dsInfo)? migrators,
  }) async {
    tenancy ??= TomTenancy.current;
    final tenant = tenancy?.tenants[tenantId];
    if (tenancy == null || tenant == null) {
      throw TomTenancy.unknownTenant(tenantId);
    }
    final type = tenancy.typeOf(tenant);
    final path = root == null
        ? type.migrations
        : tenantTreeOf(root, type, type.name);
    if (path == null || !Directory(path).existsSync()) return null;
    final tree = Directory(path);
    if (_subdirectoriesOf(tree).isEmpty) return null;
    final routed = tenancy.datasourcesOf(type);
    for (final chain in _subdirectoriesOf(tree)) {
      final datasource = p.basename(chain.path);
      if (!routed.contains(datasource)) {
        throw TomDbMigrationException(
          'db_migration.tenant.unrouted_datasource',
          "The tree of tenant type '${type.name}' migrates the data source "
              "'$datasource', which the type does not route: its tenant "
              'tables would land in the system schema.',
          parameters: {'type': type.name, 'datasource': datasource},
        );
      }
    }
    if (migrators == null && _migrationAdaptorTypes.isEmpty) {
      _initializeMigrationAdaptorTypes();
    }
    final shared = tenancy.isolationOf(tenant) == TomTenantIsolation.shared;
    final target = _TomTenantTarget(
      shared ? TomMigrationTargetKind.shared : TomMigrationTargetKind.tenant,
      type.name,
      tree,
      shared
          ? ([
              for (final t in tenancy.tenants.values)
                if (t.type == type.name &&
                    tenancy.isolationOf(t) == TomTenantIsolation.shared)
                  t.id,
            ]..sort())
          : [tenantId],
    );
    return _migrateTenantTarget(
      target,
      tenancy,
      migrators ?? newMigratorFor,
      resolveActiveEnvironment(),
    );
  }

  /// Migrates one tenant target, recording its tenants' statuses; never
  /// throws — a failure is the run's.
  static Future<TomMigrationRun> _migrateTenantTarget(
    _TomTenantTarget target,
    TomTenancy? tenancy,
    TomDbMigrator Function(TomDataSourceInfo) migratorOf,
    String environmentName,
  ) async {
    final name = target.kind == TomMigrationTargetKind.shared
        ? TomMigrationRun.sharedTarget(target.type)
        : TomMigrationRun.tenantTarget(target.tenants.single);
    final run = _start(name, target.kind, target.tenants);
    Future<void> body() async {
      final previous = {
        for (final id in target.tenants) id: tenancy?.statusOf(id),
      };
      for (final id in target.tenants) {
        await tenancy!.setStatus(id, TomTenantStatus.migrating);
      }
      final label = tenantHistoryLabel(target.type);
      final migrated = <String, TomChainVersion>{};
      Object? failure;
      try {
        for (final chain in _subdirectoriesOf(target.tree)) {
          final datasource = p.basename(chain.path);
          final dsInfo = target.tenants.isEmpty
              ? _baseInfoOf(datasource)
              : tenancy!.routeForMaintenance(
                  target.tenants.first,
                  _baseInfoOf(datasource),
                );
          final applied = await migrateTree(
            migratorOf(dsInfo),
            dsInfo,
            chain,
            label,
            environmentName,
          );
          if (applied != null) migrated[datasource] = applied;
        }
      } catch (error) {
        failure = error;
      }
      final at = DateTime.now().toUtc();
      for (final id in target.tenants) {
        if (failure != null) {
          await tenancy!.setStatus(
            id,
            TomTenantStatus.migrationFailed,
            detail: '$failure',
          );
          continue;
        }
        for (final MapEntry(:key, :value) in migrated.entries) {
          await tenancy!.registry.setMigrated(id, key, value.version, at: at);
          await tenancy.registry.setMigrated(
            id,
            requiresKey(key),
            value.requires,
            at: at,
          );
        }
        await tenancy!.setStatus(
          id,
          previous[id] == TomTenantStatus.suspended
              ? TomTenantStatus.suspended
              : TomTenantStatus.active,
        );
      }
      // The node's guard judges the target's tenants again against what was
      // just recorded.
      if (tenancy != null && target.tenants.isNotEmpty) {
        await tenancy.checkSchemaVersions(target.tenants);
      }
      if (failure != null) throw failure;
    }

    try {
      final registry = tenancy?.registry;
      if (registry == null) {
        await body();
      } else {
        await registry.withMigrationLock(name, body);
      }
      return _finish(run, null);
    } catch (error) {
      return _finish(run, error);
    }
  }

  static List<Directory> _subdirectoriesOf(Directory directory) =>
      directory.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  static final Map<String, TomMigrationRun> _currentRuns = {};

  static TomMigrationRun _start(
    String target,
    TomMigrationTargetKind kind,
    List<String> tenants,
  ) => _currentRuns[target] = TomMigrationRun(
    target,
    kind,
    TomMigrationRunState.running,
    tenants: tenants,
    startedAt: DateTime.now(),
  );

  static TomMigrationRun _finish(TomMigrationRun run, Object? error) =>
      _currentRuns[run.target] = run.finished(
        error == null
            ? TomMigrationRunState.succeeded
            : TomMigrationRunState.failed,
        at: DateTime.now(),
        error: error == null ? null : '$error',
      );

  /// Every target's run in this process's most recent [migrateAll] call, as it
  /// stands now — running ones included, in the order they started. Empty
  /// before the first call. The fact the framework readiness check reads: a
  /// running or failed system schema keeps the server from traffic; a failed
  /// tenant is reported while the others are served.
  static List<TomMigrationRun> get runs =>
      List.unmodifiable(_currentRuns.values);

  /// Forgets [runs] and [systemSchemaCheck], as a fresh process starts. For
  /// tests.
  static void resetRuns() {
    _currentRuns.clear();
    _systemCheck = null;
  }

  /// A fresh migrator for [dsInfo]'s type, from the adaptors the reflection
  /// scan found ([TomDbMigrationAdaptor]) — one per target, so targets
  /// migrated at once do not share a binding.
  static TomDbMigrator newMigratorFor(TomDataSourceInfo dsInfo) {
    if (_migrationAdaptorTypes.isEmpty) {
      _initializeMigrationAdaptorTypes();
    }
    final factory = _migrationAdaptorTypes[dsInfo.type];
    if (factory == null) {
      throw TomDbMigrationException(
        "db_migration.migration.no_migrator_found_for_datasource_type",
        "Database migration for datasource ${dsInfo.name} failed. No Migrator found for type ${dsInfo.type}",
        autoLog: true,
      );
    }
    return factory();
  }

  /// The registered data source [datasourceName] itself — unrouted, the
  /// system schema — and a migrator for its type.
  static (TomDataSourceInfo, TomDbMigrator) _migratorFor(
    String datasourceName,
  ) {
    final dsInfo = _baseInfoOf(datasourceName);
    return (dsInfo, newMigratorFor(dsInfo));
  }

  /// The data source [datasource] as tenant [tenant] reaches it — its own
  /// schema or database, or its type's shared schema — and a migrator for it.
  static Future<(TomDataSourceInfo, TomDbMigrator)> _tenantMigratorFor(
    String tenant,
    String datasource,
  ) async {
    final tenancy = TomTenancy.current;
    if (tenancy == null) throw TomTenancy.unknownTenant(tenant);
    final dsInfo = tenancy.routeForMaintenance(tenant, _baseInfoOf(datasource));
    return (dsInfo, newMigratorFor(dsInfo));
  }

  /// Runs [body] holding the migration lock of the registered data source
  /// [datasourceName] — see [TomDbMigrator.withMigrationLock].
  static Future<R> withMigrationLock<R>(
    String datasourceName,
    Future<R> Function() body,
  ) {
    final (dsInfo, migrator) = _migratorFor(datasourceName);
    return migrator.withMigrationLock(dsInfo, body);
  }

  /// Resolves the failed record of migration [version] in schema [schemaName]
  /// of the system tree's data source [datasourceName] by [action] — see
  /// [TomDbMigrator.repair].
  static Future<void> repair(
    String datasourceName,
    String schemaName,
    int version,
    TomMigrationRepair action,
  ) {
    final (dsInfo, migrator) = _migratorFor(datasourceName);
    return migrator.repair(dsInfo, schemaName, version, action);
  }

  /// Resolves the failed record of migration [version] of data source
  /// [datasource] in tenant [tenant]'s target — its own schema or database,
  /// or its type's shared schema — by [action].
  static Future<void> repairTenant(
    String tenant,
    String datasource,
    int version,
    TomMigrationRepair action,
  ) async {
    final (dsInfo, migrator) = await _tenantMigratorFor(tenant, datasource);
    final type = TomTenancy.current!.tenants[tenant]!.type;
    await migrator.repair(dsInfo, tenantHistoryLabel(type), version, action);
  }

  /// The command-line option asking for [migrateAll]: `--migrate`.
  static const String migrateOption = 'migrate';

  /// The command-line option asking for one tenant's migration:
  /// `--migrate-tenant=<id>`.
  static const String migrateTenantOption = 'migrate-tenant';

  /// The command-line option bounding how many tenants migrate at once:
  /// `--migrate-parallelism=<n>`.
  static const String migrateParallelismOption = 'migrate-parallelism';

  /// Runs the migration [args] ask for against the migration [root] and
  /// answers its result, or `null` when they ask for none — a start script
  /// calls it once its data sources and tenancy are installed, and exits when
  /// it answers a result (non-zero when it did not succeed).
  ///
  /// `--migrate` runs [migrateAll]; `--migrate-tenant=<id>` migrates that
  /// tenant alone; `--migrate-parallelism=<n>` bounds the tenants migrated at
  /// once. A failure of the system schema throws.
  static Future<TomMigrationResult?> migrateFromArgs(
    List<String> args,
    String root,
  ) async {
    final options = TomArgs.parseArgsToMap(args);
    final all = options[migrateOption];
    final tenant = options[migrateTenantOption];
    if ((all == null || all == false) && tenant == null) return null;
    final rawParallelism = options[migrateParallelismOption];
    final parallelism = rawParallelism == null
        ? 1
        : int.tryParse('$rawParallelism');
    if (parallelism == null || (tenant != null && '$tenant'.isEmpty)) {
      throw TomDbMigrationException(
        'db_migration.migration.invalid_arguments',
        'A migration is --$migrateOption or --$migrateTenantOption=<id>, '
            'with --$migrateParallelismOption=<n> optional; got '
            '--$migrateTenantOption=$tenant '
            '--$migrateParallelismOption=$rawParallelism.',
        autoLog: true,
      );
    }
    final result = await migrateAll(
      root,
      parallelism: parallelism,
      tenant: tenant == null ? null : '$tenant',
    );
    tomLog.info('Migrations: $result');
    return result;
  }

  /// Runs [migrateAll] when the [configurationKey] settings [config] ask for
  /// it with `onStart: true`, against their `root` or [defaultRoot], with
  /// their `parallelism`; answers the result, or `null` when not asked.
  /// Called by `TomServer.start`.
  static Future<TomMigrationResult?> migrateOnStart(
    Object? config,
    String defaultRoot,
  ) async {
    if (config == null) return null;
    if (config is! Map) {
      throw TomDbMigrationException(
        'db_migration.config.invalid',
        'The migrations settings must be a map, not a ${config.runtimeType}.',
      );
    }
    if (config['onStart'] != true) return null;
    final rawParallelism = config['parallelism'] ?? 1;
    final parallelism = rawParallelism is int
        ? rawParallelism
        : int.tryParse('$rawParallelism');
    if (parallelism == null) {
      throw TomDbMigrationException(
        'db_migration.config.invalid',
        "The migrations setting 'parallelism' must be a whole number, not "
            "'$rawParallelism'.",
      );
    }
    final result = await migrateAll(
      '${config['root'] ?? defaultRoot}',
      parallelism: parallelism,
    );
    tomLog.info('Migrations at start: $result');
    return result;
  }

  /// The command-line option naming the record to repair:
  /// `--repair-migration=system/<datasource>/<schema>/<version>` or
  /// `--repair-migration=tenant:<id>/<datasource>/<version>`.
  static const String repairMigrationOption = 'repair-migration';

  /// The command-line option choosing the repair: `--repair-action=remove`
  /// or `--repair-action=resolve`.
  static const String repairActionOption = 'repair-action';

  /// A repair or rollback target: `system/<datasource>/<schema>/<version>`
  /// or `tenant:<id>/<datasource>/<version>`; `null` when malformed.
  static ({String? tenant, String datasource, String? schema, int version})?
  _parseTarget(String raw) {
    final parts = raw.split('/');
    if (parts.any((part) => part.isEmpty)) return null;
    if (parts.length == 4 && parts[0] == systemTreeName) {
      final version = int.tryParse(parts[3]);
      return version == null
          ? null
          : (
              tenant: null,
              datasource: parts[1],
              schema: parts[2],
              version: version,
            );
    }
    if (parts.length == 3 && parts[0].startsWith('tenant:')) {
      final tenant = parts[0].substring('tenant:'.length);
      final version = int.tryParse(parts[2]);
      return version == null || tenant.isEmpty
          ? null
          : (
              tenant: tenant,
              datasource: parts[1],
              schema: null,
              version: version,
            );
    }
    return null;
  }

  /// Runs the repair [args] ask for, and answers whether they asked for one.
  ///
  /// A server's start script calls it once its data sources (and tenancy) are
  /// installed and exits when it answers `true`: a repair is an operator's
  /// one-off command, not a step of every start. Without
  /// [repairMigrationOption] it does nothing and answers `false`. A malformed
  /// request throws `db_migration.repair.invalid_arguments`.
  static Future<bool> repairFromArgs(List<String> args) async {
    final options = TomArgs.parseArgsToMap(args);
    final raw = options[repairMigrationOption];
    if (raw == null) return false;
    final target = _parseTarget('$raw');
    final action = switch ('${options[repairActionOption]}') {
      'remove' => TomMigrationRepair.remove,
      'resolve' => TomMigrationRepair.markResolved,
      _ => null,
    };
    if (target == null || action == null) {
      throw TomDbMigrationException(
        "db_migration.repair.invalid_arguments",
        "A migration repair is --$repairMigrationOption=system/<datasource>/"
            "<schema>/<version> or --$repairMigrationOption=tenant:<id>/"
            "<datasource>/<version>, with --$repairActionOption=remove (apply "
            "it again on the next run) or --$repairActionOption=resolve "
            "(count it as applied); got --$repairMigrationOption=$raw "
            "--$repairActionOption=${options[repairActionOption]}.",
        autoLog: true,
      );
    }
    final tenant = target.tenant;
    if (tenant == null) {
      await repair(target.datasource, target.schema!, target.version, action);
    } else {
      await repairTenant(tenant, target.datasource, target.version, action);
    }
    return true;
  }

  /// Undoes the migrations of schema [schema] of the system tree's data
  /// source [datasource] applied above [toVersion] — every one for `-1` —
  /// newest first, with the down scripts beside them under the migration
  /// [root] (`<root>/system/<datasource>/<schema>/[<v>]-<name>.down.<ext>`),
  /// under the migration lock. Answers the versions undone, in the order they
  /// were.
  ///
  /// Refused before anything runs when a migration to undo has no down
  /// script, or when the tree's up script is not the one recorded — see
  /// [TomDbMigrator.rollback].
  static Future<List<int>> rollback(
    String root, {
    required String datasource,
    required String schema,
    required int toVersion,
  }) {
    final (dsInfo, migrator) = _migratorFor(datasource);
    return rollbackDataSource(
      migrator,
      dsInfo,
      Directory(p.join(root, systemTreeName, datasource)),
      schema,
      toVersion: toVersion,
    );
  }

  /// [rollback] for tenant [tenant]'s target — its own schema or database, or
  /// its type's shared schema — with the down scripts of its type's tree
  /// (`<root>/tenant/<type>/<datasource>/`), under the migration lock and the
  /// registry's lock of the target.
  static Future<List<int>> rollbackTenant(
    String root, {
    required String tenant,
    required String datasource,
    required int toVersion,
  }) async {
    final (dsInfo, migrator) = await _tenantMigratorFor(tenant, datasource);
    final tenancy = TomTenancy.current!;
    final served = tenancy.tenants[tenant]!;
    final type = served.type;
    final chain = Directory(
      p.join(tenantTreeOf(root, tenancy.types[type], type), datasource),
    );
    final target = tenancy.isolationOf(served) == TomTenantIsolation.shared
        ? TomMigrationRun.sharedTarget(type)
        : TomMigrationRun.tenantTarget(tenant);
    return tenancy.registry.withMigrationLock(
      target,
      () => _rollbackChain(
        migrator,
        dsInfo,
        chain,
        tenantHistoryLabel(type),
        toVersion: toVersion,
      ),
    );
  }

  /// [rollback] with a caller-supplied [migrator], for the schema directory
  /// [schema] under [dataSourceDirectory].
  static Future<List<int>> rollbackDataSource(
    TomDbMigrator migrator,
    TomDataSourceInfo dsInfo,
    Directory dataSourceDirectory,
    String schema, {
    required int toVersion,
  }) => _rollbackChain(
    migrator,
    dsInfo,
    Directory(p.join(dataSourceDirectory.path, schema)),
    schema,
    toVersion: toVersion,
  );

  static Future<List<int>> _rollbackChain(
    TomDbMigrator migrator,
    TomDataSourceInfo dsInfo,
    Directory chain,
    String label, {
    required int toVersion,
  }) async {
    if (toVersion < -1) {
      throw TomDbMigrationException(
        "db_migration.rollback.invalid_target",
        "A rollback keeps the migrations up to a version, or none with -1; "
            "got $toVersion.",
      );
    }
    requireMigrationsDirectory(
      chain,
      'Migrations directory for $label of data source ${dsInfo.name}',
    );
    final entries = await chain.list().toList();
    final ups = collectMigrationFiles(entries);
    final downs = collectDownMigrationFiles(entries);
    // Every version in the tree, whatever its environment tag: a rollback
    // undoes what the history records, and the history may hold a migration
    // this process's environment would not apply.
    final scripts = <int, TomMigrationScript>{
      for (final entry in orderMigrationNames(ups.keys))
        entry.parsed.version: TomMigrationScript(
          entry.parsed.description,
          ups[entry.basename]!.readAsStringSync(),
          downs[entry.basename]?.readAsStringSync(),
        ),
    };
    return migrator.withMigrationLock(dsInfo, () {
      migrator.reset();
      return migrator.rollback(dsInfo, label, toVersion, scripts);
    });
  }

  /// The command-line option asking for a rollback:
  /// `--rollback-migrations=system/<datasource>/<schema>/<version>` or
  /// `--rollback-migrations=tenant:<id>/<datasource>/<version>`, keeping the
  /// migrations up to `<version>` (`-1` for none).
  static const String rollbackMigrationsOption = 'rollback-migrations';

  /// Runs the rollback [args] ask for against the migration [root], and
  /// answers whether they asked for one — the counterpart of
  /// [repairFromArgs], called by a start script that exits on `true`. A
  /// malformed request throws `db_migration.rollback.invalid_arguments`.
  static Future<bool> rollbackFromArgs(List<String> args, String root) async {
    final raw = TomArgs.parseArgsToMap(args)[rollbackMigrationsOption];
    if (raw == null) return false;
    final target = _parseTarget('$raw');
    if (target == null) {
      throw TomDbMigrationException(
        "db_migration.rollback.invalid_arguments",
        "A rollback is --$rollbackMigrationsOption=system/<datasource>/"
            "<schema>/<version> or --$rollbackMigrationsOption=tenant:<id>/"
            "<datasource>/<version>, keeping the migrations up to <version> "
            "(-1 for none); got --$rollbackMigrationsOption=$raw.",
        autoLog: true,
      );
    }
    final tenant = target.tenant;
    final undone = tenant == null
        ? await rollback(
            root,
            datasource: target.datasource,
            schema: target.schema!,
            toVersion: target.version,
          )
        : await rollbackTenant(
            root,
            tenant: tenant,
            datasource: target.datasource,
            toVersion: target.version,
          );
    tomLog.info(
      "Rolled back $raw to version ${target.version}: "
      "${undone.isEmpty ? 'nothing to undo' : 'undid ${undone.join(', ')}'}.",
    );
    return true;
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
  /// Split out of [migrateAll] so the walk can be driven with a
  /// caller-supplied [migrator].
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
    // One run per database at a time: a second process waits here, then finds
    // the first's migrations applied.
    await migrator.withMigrationLock(dsInfo, () async {
      for (final schema in _subdirectoriesOf(dataSourceDirectory)) {
        await _applyChain(
          migrator,
          dsInfo,
          schema,
          p.basename(schema.path),
          environmentName,
        );
      }
    });
  }

  /// Applies the one chain in [chain] — a tenant type's `<datasource>/`
  /// folder — to [dsInfo] under the history [label], through [migrator] and
  /// under [dsInfo]'s migration lock; answers the highest version it holds
  /// for [environmentName] and the lowest code version that schema serves
  /// ([TomSchemaVersionCheck.requiredCodeVersion]), or `null` when it holds
  /// none.
  static Future<TomChainVersion?> migrateTree(
    TomDbMigrator migrator,
    TomDataSourceInfo dsInfo,
    Directory chain,
    String label,
    String environmentName,
  ) {
    requireMigrationsDirectory(
      chain,
      'Migrations directory for $label of data source ${dsInfo.name}',
    );
    return migrator.withMigrationLock(
      dsInfo,
      () => _applyChain(migrator, dsInfo, chain, label, environmentName),
    );
  }

  static Future<TomChainVersion?> _applyChain(
    TomDbMigrator migrator,
    TomDataSourceInfo dsInfo,
    Directory chain,
    String label,
    String environmentName,
  ) async {
    migrator.reset();
    await migrator.initializeMigration(dsInfo, label);
    // Both collision checks run before anything is applied, so an ambiguous
    // chain aborts whole rather than applying whichever file the directory
    // listing happened to favour and leaving the rest for a second run to trip
    // over.
    //
    // They catch different ambiguities. Two files that strip to one basename
    // cannot be told apart as *files*; two that claim one version cannot be
    // told apart once *applied*, because the versioning table records the
    // version and nothing else identifying.
    final migrations = collectMigrationFiles(await chain.list().toList());
    // Parse + validate the names, reject a duplicate version, apply in
    // ascending version order (numeric, so [2] precedes [10]) and skip any
    // migration tagged for a non-active environment (C-16); a malformed name
    // throws.
    final ordered = orderMigrationNames(migrations.keys);
    final applied = <int, String>{};
    for (final entry in selectForEnvironment(ordered, environmentName)) {
      final sql = migrations[entry.basename]!.readAsStringSync();
      await migrator.applyMigration(
        dsInfo,
        label,
        entry.parsed.version,
        entry.parsed.description,
        sql,
      );
      applied[entry.parsed.version] = sql;
    }
    return applied.isEmpty
        ? null
        : (
            version: applied.keys.reduce(max),
            requires: TomSchemaVersionCheck.requiredCodeVersion(applied),
          );
  }

  /// The registry key under which `migrateAll` records, beside a tenant's
  /// version of [datasource], the lowest code version its schema serves:
  /// `<datasource>/requires`.
  static String requiresKey(String datasource) => '$datasource/requires';

  /// The highest version of the one chain in [chain] that applies in
  /// [environmentName], with the lowest code version a schema at it serves;
  /// `null` for a chain with none.
  static TomChainVersion? chainVersion(
    Directory chain,
    String environmentName,
  ) {
    final files = collectMigrationFiles(chain.listSync());
    final selected = selectForEnvironment(
      orderMigrationNames(files.keys),
      environmentName,
    );
    if (selected.isEmpty) return null;
    return (
      version: selected.last.parsed.version,
      requires: TomSchemaVersionCheck.requiredCodeVersion({
        for (final entry in selected)
          entry.parsed.version: files[entry.basename]!.readAsStringSync(),
      }),
    );
  }

  /// The highest version of each `<datasource>/` chain of a tenant type's
  /// [tree] that applies in [environmentName] — what this code expects of a
  /// tenant of the type. Empty for a missing tree.
  static Map<String, int> treeVersions(Directory tree, String environmentName) {
    if (!tree.existsSync()) return const {};
    return {
      for (final chain in _subdirectoriesOf(tree))
        if (chainVersion(chain, environmentName) case final version?)
          p.basename(chain.path): version.version,
    };
  }

  static TomSchemaVersionCheck? _systemCheck;

  /// The last [checkSystemSchema] answer of this process, or `null`. Read by
  /// the framework readiness check.
  static TomSchemaVersionCheck? get systemSchemaCheck => _systemCheck;

  /// Compares the system tree under the migration [root] with the system
  /// schema, per `<datasource>/<schema>` history: a version the code carries
  /// for the active environment that the history has not applied
  /// ([TomDbMigrator.appliedScripts]) is behind — a set comparison, so a gap
  /// below the history's highest version counts; versions the history applied
  /// above the code's highest — a newer release's, or a package contributing
  /// to the same history above this one — are ahead, served when every one is
  /// marked expand ([TomSchemaVersionCheck.expandMarker]). The check's
  /// `requires` is the highest of those not marked expand (`0`: none). Reads
  /// only; a root without `system/` is current.
  static Future<TomSchemaVersionCheck> checkSystemSchema(
    String root, {
    TomDbMigrator Function(TomDataSourceInfo dsInfo)? migrators,
  }) async {
    requireMigrationsDirectory(Directory(root), 'Migrations directory');
    final migratorOf = migrators ?? newMigratorFor;
    final environmentName = resolveActiveEnvironment();
    final code = <String, int>{};
    final recorded = <String, int>{};
    final requires = <String, int>{};
    final skews = <TomSchemaSkew>[];
    final system = Directory(p.join(root, systemTreeName));
    if (system.existsSync()) {
      for (final database in _subdirectoriesOf(system)) {
        final dsInfo = _baseInfoOf(p.basename(database.path));
        for (final chain in _subdirectoriesOf(database)) {
          final files = collectMigrationFiles(chain.listSync());
          final versions = {
            for (final entry in selectForEnvironment(
              orderMigrationNames(files.keys),
              environmentName,
            ))
              entry.parsed.version,
          };
          if (versions.isEmpty) continue;
          final schema = p.basename(chain.path);
          final history = '${dsInfo.name}/$schema';
          final scripts = await migratorOf(
            dsInfo,
          ).appliedScripts(dsInfo, schema);
          final highest = versions.reduce(max);
          code[history] = highest;
          // Behind is a set comparison, not the highest version: several
          // packages may contribute to one history, each carrying only its
          // own versions, so a version the code carries and the schema lacks
          // is behind even below the schema's highest. Ahead counts only what
          // lies above the code's highest — a newer release's migrations, or
          // a package contributing above this one — not another package's
          // versions below it.
          final extras = {
            for (final MapEntry(key: version, value: script) in scripts.entries)
              if (version > highest) version: script,
          };
          if (scripts.isNotEmpty) {
            recorded[history] = scripts.keys.reduce(max);
            requires[history] = TomSchemaVersionCheck.requiredCodeVersion(
              extras,
            );
          }
          skews.add(
            !scripts.keys.toSet().containsAll(versions)
                ? TomSchemaSkew.behind
                : extras.isEmpty
                ? TomSchemaSkew.current
                : extras.values.every(TomSchemaVersionCheck.isExpand)
                ? TomSchemaSkew.aheadCompatible
                : TomSchemaSkew.aheadIncompatible,
          );
        }
      }
    }
    return _systemCheck = TomSchemaVersionCheck(
      TomMigrationRun.systemTarget,
      TomSchemaVersionCheck.worst(skews),
      code: code,
      recorded: recorded,
      requires: requires,
    );
  }

  /// Refuses to go on unless the system schema serves this code
  /// ([checkSystemSchema]): behind the code it throws
  /// `db_migration.schema.system_behind` — after waiting up to [wait] for
  /// another process to migrate it, checking every [poll] — and ahead with a
  /// migration in between not marked expand,
  /// `db_migration.schema.system_ahead`; both name the versions. Answers the
  /// check.
  static Future<TomSchemaVersionCheck> guardSystemSchema(
    String root, {
    Duration wait = Duration.zero,
    Duration poll = const Duration(seconds: 2),
    TomDbMigrator Function(TomDataSourceInfo dsInfo)? migrators,
  }) async {
    final deadline = DateTime.now().add(wait);
    var check = await checkSystemSchema(root, migrators: migrators);
    while (check.skew == TomSchemaSkew.behind &&
        DateTime.now().isBefore(deadline)) {
      tomLog.info('Waiting for the system schema: ${check.detail}');
      await Future<void>.delayed(poll);
      check = await checkSystemSchema(root, migrators: migrators);
    }
    switch (check.skew) {
      case TomSchemaSkew.current:
        break;
      case TomSchemaSkew.aheadCompatible:
        tomLog.info(
          'The system schema is ahead of this code by expand migrations only: '
          '${check.detail}',
        );
      case TomSchemaSkew.behind:
        throw TomDbMigrationException(
          'db_migration.schema.system_behind',
          'The system schema is behind this code — migrate it first: '
              '${check.detail}.',
          parameters: {
            'code': check.code,
            'recorded': check.recorded,
            'waitedSeconds': wait.inSeconds,
          },
          autoLog: true,
        );
      case TomSchemaSkew.aheadIncompatible:
        throw TomDbMigrationException(
          'db_migration.schema.system_ahead',
          'The system schema is ahead of this code by a migration not marked '
              'expand — this release cannot serve it: ${check.detail}.',
          parameters: {
            'code': check.code,
            'recorded': check.recorded,
            'requires': check.requires,
          },
          autoLog: true,
        );
    }
    return check;
  }

  /// Runs [guardSystemSchema] at start as the [configurationKey] settings
  /// [config] say — `guard` (default `true`), `onBehind: refuse | wait`
  /// (default `refuse`), `waitSeconds` (default 300), `root` (else
  /// [defaultRoot]) — when the migration root exists; answers the check, or
  /// `null` when not run. Called by `TomServer.start` after `migrateOnStart`.
  static Future<TomSchemaVersionCheck?> guardOnStart(
    Object? config,
    String defaultRoot, {
    TomDbMigrator Function(TomDataSourceInfo dsInfo)? migrators,
  }) async {
    if (config != null && config is! Map) {
      throw TomDbMigrationException(
        'db_migration.config.invalid',
        'The migrations settings must be a map, not a ${config.runtimeType}.',
      );
    }
    final settings = (config as Map?) ?? const {};
    if (settings['guard'] == false) return null;
    final root = '${settings['root'] ?? defaultRoot}';
    if (!Directory(root).existsSync()) return null;
    final onBehind = '${settings['onBehind'] ?? 'refuse'}';
    final rawWait = settings['waitSeconds'] ?? 300;
    final waitSeconds = rawWait is int ? rawWait : int.tryParse('$rawWait');
    if ((onBehind != 'refuse' && onBehind != 'wait') ||
        waitSeconds == null ||
        waitSeconds < 0) {
      throw TomDbMigrationException(
        'db_migration.config.invalid',
        "The migrations setting 'onBehind' is 'refuse' or 'wait', and "
            "'waitSeconds' a whole number of seconds; got onBehind: "
            "$onBehind, waitSeconds: $rawWait.",
      );
    }
    return guardSystemSchema(
      root,
      wait: onBehind == 'wait' ? Duration(seconds: waitSeconds) : Duration.zero,
      migrators: migrators,
    );
  }
}

/// The highest [version] of a migration chain, and the lowest code version a
/// schema at it serves ([requires]).
typedef TomChainVersion = ({int version, int requires});

/// A tenant target of [TomDbMigrations.migrateAll]: a [type]'s [tree] applied
/// to a shared schema or to one tenant's own.
class _TomTenantTarget {
  const _TomTenantTarget(this.kind, this.type, this.tree, this.tenants);

  final TomMigrationTargetKind kind;
  final String type;
  final Directory tree;
  final List<String> tenants;
}

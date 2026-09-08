import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import '../datasources/datasource_initialization.dart';
import 'db_migration.dart';
import 'sql_lexer.dart';

/// Thrown for MariaDB migration failures (versioning-table creation, version
/// query, a changed description/checksum for an already-applied version, or a
/// failed migration script).
class MariadbMigrationException extends TomServerException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomServerException].
  MariadbMigrationException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// The MariaDB [TomDbMigrator] (registered for the `"mariadb"` type).
///
/// Per schema it maintains a `<schema>_versioning` table recording every
/// applied migration (version, description, script, checksum, timing, success).
/// [initializeMigration] binds the instance to one `(data source, schema)`
/// pair, creates that table if absent and loads the applied [versions];
/// [applyMigration] skips a version already present — but first verifies its
/// description and script checksum are unchanged, failing if a past migration
/// was edited — and otherwise runs the script and records the outcome. A failed
/// script is still recorded (with `success = 0`) before the error is rethrown,
/// and that row is read back: [initializeMigration] refuses to run at all
/// against a schema whose history holds one, because a failed script leaves a
/// part-applied schema and MariaDB does not roll DDL back.
///
/// One instance serves every schema of every `"mariadb"` data source in turn,
/// so [initializeMigration] **rebinds**: it replaces the loaded [versions]
/// rather than adding to them, and [applyMigration] refuses to run against a
/// pair the instance is not currently bound to. Both matter because "already
/// applied" is decided from [versions]: a list still holding the previous
/// schema's history would report that schema's version 1 as applied and skip
/// the new schema's version 1 without a word.
@TomDbMigrationAdaptor("mariadb")
@tomReflector
class MariadbMigrationAdaptor implements TomDbMigrator {
  /// The `(data source, schema)` pair [versions] was loaded for, or `null`
  /// before the first [initializeMigration] and after [reset].
  ///
  /// Tracked as the pair rather than as a bare "initialised" flag because the
  /// applied-version history is per **pair**, not per instance: one data source
  /// holds several schemas, each with its own history. Knowing *which* pair is
  /// loaded is what lets [applyMigration] refuse to judge a migration against
  /// another schema's history.
  String? _boundTo;

  /// The checksum recorded for a migration script: the lowercase hex SHA-256
  /// of its UTF-8 bytes.
  ///
  /// This value outlives the process that wrote it — it is read back on every
  /// later startup to decide whether an already-applied migration has since
  /// been edited — so it must mean the same thing in every process that ever
  /// looks at it. A content digest does; `String.hashCode`, which this replaced,
  /// does not: Dart guarantees it only within one run, and it varies with the
  /// SDK, the platform and the isolate's hash seed. When it changed, *every*
  /// row already recorded became a mismatch at once, and the resulting
  /// `checksum_mismatch` is indistinguishable from a genuinely tampered
  /// migration — so the operator's first instinct would have been the wrong one.
  ///
  /// Public because it is the definition of the stored value: a test pins it to
  /// a constant so a change of algorithm is caught by the suite rather than by
  /// a fleet of deployed databases, and an operator repairing a row needs to be
  /// able to compute the value the adaptor expects.
  static String checksumOf(String sql) =>
      sha256.convert(utf8.encode(sql)).toString();

  /// The shape [checksumOf] produces: exactly 64 lowercase hex characters.
  ///
  /// Anchored deliberately — an unanchored pattern would accept a padded or
  /// prefixed value that no comparison could ever match, turning an unreadable
  /// row into a permanent mismatch.
  static final RegExp _checksumPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Whether [checksum] is a value this adaptor could have written — the
  /// counterpart of [checksumOf].
  ///
  /// A stored checksum that fails this test is not evidence that a migration
  /// was edited; it is evidence that the row came from somewhere else. The
  /// versioning table's own DDL makes that reachable: `checksum` is declared
  /// `NOT NULL DEFAULT ''`, so any row inserted by anything other than
  /// [applyMigration] — a hand-written repair, an older schema, a partially
  /// applied insert — carries the empty string. A database written before the
  /// checksum became a content digest carries a decimal `String.hashCode`.
  ///
  /// The two facts are kept apart because they call for opposite responses:
  /// a mismatch means "find the edit", an unreadable value means "this row was
  /// never written by this adaptor — recompute it". Reporting the second as the
  /// first sends the operator hunting for an edit that never happened.
  static bool isWellFormedChecksum(String checksum) =>
      _checksumPattern.hasMatch(checksum);

  /// Identifies a `(data source, schema)` pair.
  ///
  /// Both halves are directory basenames, so neither can contain the
  /// separator and the key cannot be ambiguous.
  static String _binding(TomDataSourceInfo dsi, String schemaName) =>
      '${dsi.name}/$schemaName';

  /// The migrations already applied to the schema this instance is bound to,
  /// as read from that schema's versioning table by [initializeMigration].
  ///
  /// Ordered by **installation order, oldest first** (by
  /// [TomDbVersion.installedRank]) — the order the migrations were actually
  /// applied, not their version order. The two differ whenever migrations were
  /// applied out of numeric order, which environment tags (C-16) make ordinary:
  /// a box switched to `dev` applies `[1]@dev` after the untagged `[3]` it
  /// already had, leaving the history `3, 1, 2`. Sort a copy by
  /// [TomDbVersion.version] if version order is what you need.
  ///
  /// It is a snapshot taken at initialisation and is **not** extended as
  /// [applyMigration] runs — a migration applied during this run is written to
  /// the table, not added here.
  ///
  /// This is the whole output of [initializeMigration]: the method returns
  /// nothing, because the history is what callers want and a single number
  /// cannot carry it.
  List<TomDbVersion> versions = [];

  @override
  void reset() {
    _boundTo = null;
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
    // Whether a version counts as "already applied" is read from `versions`,
    // which describes exactly one schema. Judging a migration against another
    // schema's history is how the version-1-silently-skipped failure happens,
    // so the mismatch is refused rather than resolved.
    if (_boundTo != _binding(dsi, schemaName)) {
      throw MariadbMigrationException(
        "mariadb_migration.apply_migration.not_initialized_for_schema",
        _boundTo == null
            ? "MariadbMigrationAdaptor: applyMigration called for schema "
                  "$schemaName in datasource ${dsi.name} before "
                  "initializeMigration."
            : "MariadbMigrationAdaptor: applyMigration called for "
                  "${_binding(dsi, schemaName)} while initialized for "
                  "$_boundTo. The applied-version history belongs to one "
                  "schema; call initializeMigration for each.",
      );
    }
    // check if this has already been applied
    for (var v in versions) {
      if (v.version == version) {
        // Every message here names the schema as well as the version: one
        // instance walks every schema of every data source, so "version 0 has
        // changed" is true of a different table in each of them and cannot be
        // acted on.
        if (v.description != description) {
          throw MariadbMigrationException(
            "mariadb_migration.apply_migration.description_mismatch",
            "MariadbMigrationAdaptor: Description for version $version of "
                "schema $schemaName in datasource ${dsi.name} has changed "
                "(recorded '${v.description}', now '$description'). Migrations "
                "must stay stable, so the migration run has been abandoned.",
          );
        }
        // Readability first, and separately from the comparison. A value this
        // adaptor could not have written says nothing about whether the script
        // changed — reporting it as a mismatch would accuse someone of an edit
        // that never happened. This is also the path that used to reach
        // `int.parse` and escape as a bare FormatException naming neither the
        // schema nor the migration.
        if (!isWellFormedChecksum(v.checksum)) {
          throw MariadbMigrationException(
            "mariadb_migration.apply_migration.checksum_unreadable",
            "MariadbMigrationAdaptor: The recorded checksum for version "
                "$version ($description) of schema $schemaName in datasource "
                "${dsi.name} is not a digest this adaptor could have written "
                "(found '${v.checksum}'). The row was not written by "
                "applyMigration — an older schema, a partially applied insert, "
                "or a hand-written repair. Recompute it as the SHA-256 of the "
                "row's stored script. The migration run has been abandoned.",
          );
        }
        // Compared as text rather than parsed as a number, so the comparison
        // cannot throw; by here the stored value is known to be a digest, so an
        // inequality means what it says — the script was edited.
        if (v.checksum != checksumOf(sql)) {
          throw MariadbMigrationException(
            "mariadb_migration.apply_migration.checksum_mismatch",
            "MariadbMigrationAdaptor: Script checksum for version $version "
                "($description) of schema $schemaName in datasource "
                "${dsi.name} has changed — the script was edited after it was "
                "applied. Migrations must stay stable, so the migration run "
                "has been abandoned.",
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
    try {
      // A migration script is typically a multi-statement DDL file. The
      // underlying mysql_client `execute` reads only the first result set of a
      // multi-statement command, leaving the rest unread and the (single,
      // shared) connection desynced — so later reads on it return stale data.
      // Send each statement on its own command instead, which keeps the
      // connection in sync. See `TomSqlLexer.splitStatements`.
      for (final statement in TomSqlLexer.splitStatements(sql)) {
        await dsi.datasource.executeCommand(statement);
      }
    } catch (error) {
      failed = true;
      exception = MariadbMigrationException(
        "mariadb_migration.apply_migration.failed",
        "Failed to apply migration $version, $description: $error",
        autoLog: true,
        rootException: error,
      );
    }
    // Read on both paths, and outside the `try` for that reason. A script that
    // ran for a while and then failed is precisely when the duration is worth
    // having; reading the stopwatch after the loop instead would record a flat
    // 0 for every failed migration.
    final int timeElapsedMs = (timer..stop()).elapsedMilliseconds;
    // Record the outcome with bound parameters rather than interpolating the
    // values into the SQL text. The script ([script]) routinely contains quote
    // characters (e.g. a JSON seed value like `'["a","b"]'`), which would
    // terminate an interpolated string literal early and produce a syntax
    // error; a stray quote in the description would do the same. Binding sidesteps
    // both — and the escaping/SQL-injection risk — entirely.
    final insertMigration =
        'INSERT INTO ${schemaName}_versioning '
        '(version, description, script, checksum, executionTimeMs, success) '
        'VALUES (:version, :description, :script, :checksum, '
        ':executionTimeMs, :success)';
    try {
      await dsi.datasource.executeCommand(insertMigration, {
        'version': version,
        'description': description,
        'script': sql,
        'checksum': checksumOf(sql),
        'executionTimeMs': timeElapsedMs,
        'success': failed ? 0 : 1,
      });
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
  Future<void> initializeMigration(
    TomDataSourceInfo dsi,
    String schemaName,
  ) async {
    // Rebinding is legal and is the normal path: one data source holds several
    // schemas, and the orchestrator walks them through the same instance.
    // Drop the previous pair's state up front, so a failure below leaves the
    // instance unbound rather than bound to a schema whose history never
    // loaded.
    _boundTo = null;
    versions = [];
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
    // The ORDER BY is what makes [versions] install-ordered. A SELECT without
    // one promises nothing about row order — InnoDB happens to return this
    // table by `installedRank` anyway, because it is the clustered primary key,
    // and that is exactly why the ordering has to be *stated*: an accident of
    // the storage engine is not a guarantee, and nothing would report it if the
    // accident stopped holding.
    String versionQuery =
        '''
SELECT installedRank, version, description, checksum, installedBy, installedOn, executionTimeMs, success, script FROM ${schemaName}_versioning ORDER BY installedRank
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
    _refuseFailedHistory(dsi, schemaName, currentVersions);
    // Assigned, never appended: the list describes this schema's history and
    // must not carry the previous schema's versions into it.
    versions = currentVersions;
    _boundTo = _binding(dsi, schemaName);
  }

  /// Throws when [history] holds a migration that was recorded as failed.
  ///
  /// A row with `success = 0` says a script ran and did not finish. **MariaDB
  /// does not roll DDL back**, so what it left behind is a schema in a state
  /// nobody wrote down: some statements applied, one raised, the rest never
  /// reached. That is not a state this module can reason about, and the two
  /// things it could do instead of stopping are both worse.
  ///
  /// It could re-run the script — right when the failure was environmental (a
  /// server that went away mid-run), and wrong when the script is half applied,
  /// where the re-run meets its own `CREATE TABLE` on a table that now exists
  /// and fails again, forever. Or it could do what it did before this check
  /// existed and treat the row as applied, which is how a failed migration came
  /// to be skipped silently from then on: the version is present, and the
  /// description and checksum agree because both were written from the same
  /// script. The column recording the failure was written by this module and
  /// read by nobody in it.
  ///
  /// So the run stops, and stops *here* — as the history is read, before any
  /// script is offered. Two consequences follow from that placement, both
  /// intended. A failed migration blocks the migrations after it as well as its
  /// own, because a schema whose middle is unknown is not a schema later
  /// statements can be reasoned about. And it blocks on every node, including
  /// one whose environment tags mean it would never have run that migration —
  /// the damage is in the database the node is about to use, not in the tree it
  /// would have applied.
  ///
  /// Repair is a human's: finish or undo what the script left, then correct or
  /// delete the row. The message names the version, the description and the
  /// schema, because an operator holding only "a migration failed" has to go
  /// looking for which one.
  void _refuseFailedHistory(
    TomDataSourceInfo dsi,
    String schemaName,
    List<TomDbVersion> history,
  ) {
    final failed = history.where((v) => v.success != 1).toList();
    if (failed.isEmpty) return;
    final named = failed
        .map((v) => '${v.version} (${v.description})')
        .join(', ');
    throw MariadbMigrationException(
      "mariadb_migration_adapter.initialize.failed_migration_recorded",
      "MariadbMigrationAdaptor: schema $schemaName in datasource ${dsi.name} "
          "has ${failed.length == 1 ? 'a migration' : 'migrations'} recorded as "
          "failed: $named. A failed script leaves the schema part-applied — "
          "MariaDB does not roll DDL back — so the migration run has been "
          "abandoned rather than continued over a state nothing describes. "
          "Finish or undo what the script left behind, then correct the "
          "${schemaName}_versioning row (set success = 1) or delete it to have "
          "the migration applied again.",
      parameters: {
        "schema": schemaName,
        "datasource": dsi.name,
        "versions": failed.map((v) => v.version).toList(),
      },
      autoLog: true,
    );
  }
}

/// One row of a `<schema>_versioning` table: the record of a single applied (or
/// attempted) migration.
///
/// It is mapped from query results by reflection, so it is `@tomReflector` and
/// its fields carry `@TomDbColumn` names. The `@TomDbTable` annotation is
/// required by the row mapper but its values are unused here (the table name is
/// computed per schema), hence the `"irrelevant"` placeholders.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyField: "irrelevant",
)
class TomDbVersion {
  /// Auto-incrementing insertion order (primary key).
  @TomDbColumn(columnName: "installedRank")
  int installedRank = 0;

  /// The migration version number.
  @TomDbColumn(columnName: "version")
  int version = 0;

  /// The migration description (from the file name).
  @TomDbColumn(columnName: "description")
  String description = "";

  /// The full migration script text.
  @TomDbColumn(columnName: "script")
  String script = "";

  /// The script's content digest — lowercase hex SHA-256, as produced by
  /// [MariadbMigrationAdaptor.checksumOf] — used to detect later edits.
  @TomDbColumn(columnName: "checksum")
  String checksum = "";

  /// The database user that applied the migration.
  @TomDbColumn(columnName: "installedBy")
  String installedBy = "";

  /// When the migration was applied.
  @TomDbColumn(columnName: "installedOn")
  DateTime installedOn = DateTime.now();

  /// How long the script took to run, in milliseconds, as measured by
  /// [MariadbMigrationAdaptor.applyMigration].
  ///
  /// Covers the script's statements only: the clock stops before this row is
  /// inserted, so the figure is comparable across runs. A row recorded for a
  /// *failed* script carries the time spent before the failure.
  @TomDbColumn(columnName: "executionTimeMs")
  int executionTimeMs = 0;

  /// `1` if the migration script succeeded, `0` if it failed.
  ///
  /// Read back, not merely written: [MariadbMigrationAdaptor.initializeMigration]
  /// refuses to run against a schema whose history holds a row that is not `1`.
  /// A column this module writes and never reads is how a failed migration came
  /// to be skipped from then on.
  @TomDbColumn(columnName: "success")
  int success = 0;
}

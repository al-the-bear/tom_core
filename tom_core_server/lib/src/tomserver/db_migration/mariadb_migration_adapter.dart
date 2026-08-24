import 'dart:async';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import '../datasources/datasource_initialization.dart';
import 'db_migration.dart';

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
/// script is still recorded (with `success = 0`) before the error is rethrown.
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

  /// Identifies a `(data source, schema)` pair.
  ///
  /// Both halves are directory basenames, so neither can contain the
  /// separator and the key cannot be ambiguous.
  static String _binding(TomDataSourceInfo dsi, String schemaName) =>
      '${dsi.name}/$schemaName';

  /// The migrations already applied to the schema this instance is bound to,
  /// as read from that schema's versioning table by [initializeMigration].
  ///
  /// It is a snapshot taken at initialisation and is **not** extended as
  /// [applyMigration] runs — a migration applied during this run is written to
  /// the table, not added here.
  List<TomDbVersion> versions = [];

  @override
  void reset() {
    _boundTo = null;
    versions = [];
  }

  /// Splits a (possibly multi-statement) migration [sql] script into its
  /// individual statements so each can be sent on its own command.
  ///
  /// Statements are separated on unquoted, uncommented semicolons. String
  /// literals (`'…'`, `"…"`), quoted identifiers (`` `…` ``), line comments
  /// (`-- …`, `# …`) and block comments (`/* … */`) are skipped so a semicolon
  /// inside any of them does not split a statement. Trailing whitespace-only
  /// fragments are dropped, so a script ending in `;` yields no empty tail
  /// statement.
  static List<String> splitSqlStatements(String sql) {
    final statements = <String>[];
    final buffer = StringBuffer();
    final chars = sql.split('');
    for (var i = 0; i < chars.length; i++) {
      final ch = chars[i];
      final next = i + 1 < chars.length ? chars[i + 1] : '';

      // Line comment: '-- ' or '#' to end of line.
      if ((ch == '-' && next == '-') || ch == '#') {
        buffer.write(ch);
        while (i + 1 < chars.length && chars[i + 1] != '\n') {
          buffer.write(chars[++i]);
        }
        continue;
      }
      // Block comment: '/* … */'.
      if (ch == '/' && next == '*') {
        buffer.write(ch);
        buffer.write(chars[++i]);
        while (i + 1 < chars.length &&
            !(chars[i] == '*' && chars[i + 1] == '/')) {
          buffer.write(chars[++i]);
        }
        if (i + 1 < chars.length) buffer.write(chars[++i]);
        continue;
      }
      // String literal or quoted identifier: copy verbatim until the matching
      // unescaped closing quote (doubled quote = escaped quote, stays inside).
      if (ch == "'" || ch == '"' || ch == '`') {
        buffer.write(ch);
        while (i + 1 < chars.length) {
          final c = chars[++i];
          buffer.write(c);
          if (c == ch) {
            if (i + 1 < chars.length && chars[i + 1] == ch) {
              buffer.write(chars[++i]); // doubled quote -> escaped, continue
            } else {
              break;
            }
          }
        }
        continue;
      }
      // Statement terminator.
      if (ch == ';') {
        final statement = buffer.toString().trim();
        if (statement.isNotEmpty) statements.add(statement);
        buffer.clear();
        continue;
      }
      buffer.write(ch);
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) statements.add(tail);
    return statements;
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
      // A migration script is typically a multi-statement DDL file. The
      // underlying mysql_client `execute` reads only the first result set of a
      // multi-statement command, leaving the rest unread and the (single,
      // shared) connection desynced — so later reads on it return stale data.
      // Send each statement on its own command instead, which keeps the
      // connection in sync. See `splitSqlStatements`.
      for (final statement in splitSqlStatements(sql)) {
        await dsi.datasource.executeCommand(statement);
      }
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
        'checksum': '${sql.hashCode}',
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
  Future<int> initializeMigration(
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
    // Assigned, never appended: the list describes this schema's history and
    // must not carry the previous schema's versions into it.
    versions = currentVersions;
    _boundTo = _binding(dsi, schemaName);
    if (currentVersions.isEmpty) return -1;
    return currentVersions[0].version;
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

  /// The script's `hashCode`, stored as a string, used to detect later edits.
  @TomDbColumn(columnName: "checksum")
  String checksum = "";

  /// The database user that applied the migration.
  @TomDbColumn(columnName: "installedBy")
  String installedBy = "";

  /// When the migration was applied.
  @TomDbColumn(columnName: "installedOn")
  DateTime installedOn = DateTime.now();

  /// `1` if the migration script succeeded, `0` if it failed.
  @TomDbColumn(columnName: "success")
  int success = 0;
}

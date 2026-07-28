/// Shared MariaDB test-database fixture for the `tom_core_server` suite (RCK13).
///
/// `dart test` runs every test *file* in its own isolate and the DB-backed
/// surfaces — the MariaDB [MariaDbDatasource] driver, the object-persistence
/// [TomSqlDatasourceRepository] CRUD/query paths, and the [TomDbMigrations]
/// orchestrator — cannot be exercised without a real server. This helper is the
/// single place those suites use to:
///
///  * discover the connection coordinates (env-overridable, with defaults that
///    match `docker-compose.test.yaml`);
///  * decide, *before declaring any group*, whether a server is reachable so
///    the group can be `skip:`ped when it is not — keeping the default
///    `testkit :test` run green on a machine with no database (the RCK13 done
///    bar); and
///  * register the `tom_core_server_test` data source (the name the fixture
///    entity's `@TomDbTable` binds to) and provision / clean its schema.
///
/// It is deliberately reusable: the same fixture unblocks RCK20 (the d4rt replay
/// DB surfaces), so nothing here is specific to a single test file.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

/// Connection coordinates and schema helpers for the shared test database.
///
/// Every value is read from an environment variable with a default that matches
/// the bundled `docker-compose.test.yaml`, so a developer (or CI) can point the
/// suite at any MariaDB by exporting `TOM_CORE_SERVER_TEST_DB_*` without editing
/// code. The default port is **3309** — deliberately clear of the stock 3306
/// and the advanced sample's 3307/3308 — so a fixture database can run
/// alongside those without a clash.
class TestDatabase {
  TestDatabase._();

  /// The registered data source name. Must equal the `datasource` of the
  /// fixture entity's `@TomDbTable` (`FixtureTaskRecord`), because the
  /// repository resolves its data source by that name.
  static const String datasourceName = 'tom_core_server_test';

  static String _env(String key, String fallback) =>
      Platform.environment[key]?.trim().isNotEmpty == true
          ? Platform.environment[key]!.trim()
          : fallback;

  /// Database host (`TOM_CORE_SERVER_TEST_DB_HOST`, default `127.0.0.1`).
  static String get host => _env('TOM_CORE_SERVER_TEST_DB_HOST', '127.0.0.1');

  /// Database port (`TOM_CORE_SERVER_TEST_DB_PORT`, default `3309`).
  static int get port =>
      int.parse(_env('TOM_CORE_SERVER_TEST_DB_PORT', '3309'));

  /// Connection user (`TOM_CORE_SERVER_TEST_DB_USER`, default `root`).
  static String get username => _env('TOM_CORE_SERVER_TEST_DB_USER', 'root');

  /// Connection password (`TOM_CORE_SERVER_TEST_DB_PASSWORD`, default
  /// `password`).
  static String get password =>
      _env('TOM_CORE_SERVER_TEST_DB_PASSWORD', 'password');

  /// Schema / database name (`TOM_CORE_SERVER_TEST_DB_NAME`, default
  /// `tom_core_server_test`).
  static String get databaseName =>
      _env('TOM_CORE_SERVER_TEST_DB_NAME', 'tom_core_server_test');

  /// The datasource configuration map for [datasourceName], in the shape
  /// [TomDataSourceInfo.initializeDatasourceInfo] consumes.
  static Map<String, dynamic> get datasourceConfig => <String, dynamic>{
        datasourceName: <String, dynamic>{
          'type': 'mariadb',
          'username': username,
          'password': password,
          'host': host,
          'port': port,
          'databaseName': databaseName,
        },
      };

  /// Whether a server is listening on [host]:[port].
  ///
  /// A short TCP-connect probe (not a full MariaDB handshake): it answers the
  /// only question a suite needs before it decides to `skip:` — *is there
  /// anything to test against*. When it returns `false` the DB groups are
  /// skipped so the default run stays green; when it returns `true` the actual
  /// connect in [register] surfaces any real misconfiguration as a failure, as
  /// it should.
  static Future<bool> isReachable() async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } on SocketException {
      return false;
    } on Exception {
      return false;
    }
  }

  /// Registers [datasourceName] and opens its connection.
  ///
  /// Requires reflection to be initialised first (the driver is discovered by
  /// scanning `@TomDatasourceDriver` metadata), so call `initializeReflection()`
  /// before this. Returns the live [TomDataSourceInfo].
  static Future<TomDataSourceInfo> register() async {
    await TomDataSourceInfo.initializeDatasourceInfo(datasourceConfig);
    return TomDataSourceInfo.getDataSourceInfo(datasourceName)!;
  }

  /// The fixture entity's table DDL, matching [FixtureTaskRecord]'s
  /// `@TomDbColumn` mappings (an AUTO_INCREMENT surrogate key, a text column, an
  /// int column, and a `TINYINT(1)` boolean).
  static const String _fixtureTaskDdl = '''
CREATE TABLE IF NOT EXISTS fixture_task (
  id       BIGINT       NOT NULL AUTO_INCREMENT,
  title    VARCHAR(255) NULL,
  priority INT          NULL,
  done     TINYINT(1)   NULL,
  PRIMARY KEY (id)
)
''';

  /// Creates the `fixture_task` table if it does not already exist.
  static Future<void> ensureFixtureTaskTable(TomDataSourceInfo dsi) async {
    await dsi.datasource.executeCommand(_fixtureTaskDdl);
  }

  /// Empties the `fixture_task` table so each test starts from a known state.
  ///
  /// Uses `TRUNCATE` so the AUTO_INCREMENT counter resets too, keeping the
  /// generated-key assertions independent of test ordering.
  static Future<void> truncateFixtureTask(TomDataSourceInfo dsi) async {
    await dsi.datasource.executeCommand('TRUNCATE TABLE fixture_task');
  }

  /// The DDL for `FixtureSecretRecord`, the entity carrying a column that the
  /// CE-LG audit trail redacts.
  static const String _fixtureSecretDdl = '''
CREATE TABLE IF NOT EXISTS fixture_secret (
  id     BIGINT       NOT NULL AUTO_INCREMENT,
  label  VARCHAR(255) NULL,
  secret VARCHAR(255) NULL,
  PRIMARY KEY (id)
)
''';

  /// Creates the `fixture_secret` table if it does not already exist.
  static Future<void> ensureFixtureSecretTable(TomDataSourceInfo dsi) async {
    await dsi.datasource.executeCommand(_fixtureSecretDdl);
  }

  /// Empties the `fixture_secret` table so each test starts from a known state.
  static Future<void> truncateFixtureSecret(TomDataSourceInfo dsi) async {
    await dsi.datasource.executeCommand('TRUNCATE TABLE fixture_secret');
  }

  /// The DDL for `FixtureDocumentRecord`, the entity whose two columns hold
  /// blob-storage keys rather than bytes (CSFS1).
  static const String _fixtureDocumentDdl = '''
CREATE TABLE IF NOT EXISTS fixture_document (
  id                BIGINT       NOT NULL AUTO_INCREMENT,
  title             VARCHAR(255) NULL,
  attachment        VARCHAR(512) NULL,
  secret_attachment VARCHAR(512) NULL,
  PRIMARY KEY (id)
)
''';

  /// Creates the `fixture_document` table if it does not already exist.
  static Future<void> ensureFixtureDocumentTable(TomDataSourceInfo dsi) async {
    await dsi.datasource.executeCommand(_fixtureDocumentDdl);
  }

  /// Empties the `fixture_document` table so each test starts from a known
  /// state.
  static Future<void> truncateFixtureDocument(TomDataSourceInfo dsi) async {
    await dsi.datasource.executeCommand('TRUNCATE TABLE fixture_document');
  }

  /// The DDL for `FixtureScopedDocumentRecord`, the row-scoped counterpart of
  /// `fixture_document` (CSEXD2). `owner_id` is the `@TomDbScope` field, so it
  /// is the column the repository ANDs into every read's `WHERE`.
  static const String _fixtureScopedDocumentDdl = '''
CREATE TABLE IF NOT EXISTS fixture_scoped_document (
  id         BIGINT       NOT NULL AUTO_INCREMENT,
  owner_id   BIGINT       NULL,
  title      VARCHAR(255) NULL,
  attachment VARCHAR(512) NULL,
  PRIMARY KEY (id)
)
''';

  /// Creates the `fixture_scoped_document` table if it does not already exist.
  static Future<void> ensureFixtureScopedDocumentTable(
    TomDataSourceInfo dsi,
  ) async {
    await dsi.datasource.executeCommand(_fixtureScopedDocumentDdl);
  }

  /// Empties the `fixture_scoped_document` table so each test starts from a
  /// known state.
  static Future<void> truncateFixtureScopedDocument(
    TomDataSourceInfo dsi,
  ) async {
    await dsi.datasource.executeCommand(
      'TRUNCATE TABLE fixture_scoped_document',
    );
  }

  /// Drops the blob store's two tables, so a `TomDatabaseBlobStore` test starts
  /// from an empty store regardless of what an earlier run left behind.
  ///
  /// Dropped rather than truncated because the store creates them on first use:
  /// a run that changed the schema would otherwise keep the previous shape.
  static Future<void> dropBlobTables(
    TomDataSourceInfo dsi, {
    String manifestTable = 'tom_blob',
    String chunkTable = 'tom_blob_chunk',
  }) async {
    await dsi.datasource.executeCommand('DROP TABLE IF EXISTS $chunkTable');
    await dsi.datasource.executeCommand('DROP TABLE IF EXISTS $manifestTable');
  }

  /// Drops the relational scheduler's tables (CSEXB3, CSEXC2).
  ///
  /// Dropped rather than truncated for the same reason as the blob tables: the
  /// stores create them on first use, so a run that changed the DDL would
  /// otherwise keep the previous shape. Dropping also resets `tom_lease`, whose
  /// rows *are* the fencing counters — a contract group that expects tokens to
  /// start at 1 needs the counter gone, not merely the leases.
  static Future<void> dropSchedulingTables(
    TomDataSourceInfo dsi, {
    String jobRunTable = defaultJobRunTable,
    String leaseTable = defaultLeaseTable,
    String nodeTable = defaultSchedulerNodeTable,
  }) async {
    await dsi.datasource.executeCommand('DROP TABLE IF EXISTS $jobRunTable');
    await dsi.datasource.executeCommand('DROP TABLE IF EXISTS $leaseTable');
    await dsi.datasource.executeCommand('DROP TABLE IF EXISTS $nodeTable');
  }

  /// Drops the relational audit trail's table and its optional guard triggers
  /// (CSEXB4).
  ///
  /// The triggers are dropped explicitly even though MariaDB drops a table's
  /// triggers with it: a test that installs a guard and then fails part-way
  /// would otherwise leave an `UPDATE`-rejecting trigger behind for whatever
  /// runs next, and the failure it caused would look like a different bug.
  static Future<void> dropAuditTrailTable(
    TomDataSourceInfo dsi, {
    String table = defaultAuditTrailTable,
  }) async {
    await dsi.datasource.executeCommand(
      'DROP TRIGGER IF EXISTS ${auditTrailNoUpdateTriggerName(table)}',
    );
    await dsi.datasource.executeCommand(
      'DROP TRIGGER IF EXISTS ${auditTrailNoDeleteTriggerName(table)}',
    );
    await dsi.datasource.executeCommand('DROP TABLE IF EXISTS $table');
  }

  /// Drops the `<schemaName>_versioning` table the migration orchestrator keeps.
  ///
  /// The orchestrator is idempotent by design: it skips a version it has already
  /// recorded. So a test that drops the tables a migration created must drop
  /// that record too — otherwise the second run finds nothing to apply and
  /// leaves the schema missing, and the test passes or fails depending only on
  /// whether the database was fresh.
  static Future<void> dropMigrationVersioning(
    TomDataSourceInfo dsi,
    String schemaName,
  ) async {
    await dsi.datasource
        .executeCommand('DROP TABLE IF EXISTS ${schemaName}_versioning');
  }

  /// Closes every registered data source and clears the process-wide registry,
  /// so a torn-down suite leaves no open connection or stale registration for
  /// the next one.
  static Future<void> reset() async {
    await TomDataSourceInfo.closeAll();
    TomDataSourceInfo.datasources.clear();
  }
}

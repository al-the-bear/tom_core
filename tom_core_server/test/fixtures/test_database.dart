/// Shared MariaDB test-database fixture for the `tom_core_server` suite.
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
///    `testkit :test` run green on a machine with no database (the done
///    bar); and
///  * register the `tom_core_server_test` data source (the name the fixture
///    entity's `@TomDbTable` binds to) and provision / clean its schema.
///
/// It is deliberately reusable: nothing here is specific to a single test
/// file, so any suite that needs a live schema can share it.
///
/// **Every suite file gets a database of its own.** Many suites create,
/// truncate and drop the same fixture tables — `fixture_task` alone is used by
/// six — and two runs against one server (two sessions, or a run and a
/// developer's single file) interleave them. A shared schema lets one suite's
/// `setUp` truncate land in the middle of another's assertions, and the failure
/// lands in a different suite each time. [databaseName] is therefore unique to
/// the suite's isolate and to the run; [register] creates it and drops it again
/// when the group that registered it ends. (The package still runs its suite
/// files one at a time, for an unrelated reason `dart_test.yaml` states: two
/// suites change the process-wide working directory.) The data source *name* is unchanged — only the schema
/// behind it moves — so no suite had to change to be isolated.
library;

import 'dart:io';
import 'dart:math';

import 'package:postgres/postgres.dart' as pg;
import 'package:test/test.dart' show addTearDown;
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

  /// The database the suites run against (`TOM_CORE_SERVER_TEST_DB_ENGINE`):
  /// `mariadb` (the default, `docker-compose.test.yaml`) or `postgresql`
  /// (`docker-compose.test.postgres.yaml`). The same suites run against both;
  /// `tool/run_db_tests.sh` and `tool/run_db_tests_postgres.sh` start the one
  /// each needs.
  static String get engine => _env('TOM_CORE_SERVER_TEST_DB_ENGINE', 'mariadb');

  /// Whether the suites run against PostgreSQL.
  static bool get isPostgres => engine == 'postgresql';

  /// Why a test of a MariaDB-only behaviour does not run here, or `null` on
  /// MariaDB — for the `skip:` of a test that exercises the MariaDB client's
  /// own protocol rather than anything the framework does on every database.
  static String? onlyOnMariaDb(String why) =>
      isPostgres ? 'MariaDB only — $why' : null;

  /// The directory a module keeps its reference migrations in for this
  /// engine: `migrations` (the canonical, MariaDB form) or
  /// `migrations_postgresql` (generated from it by
  /// `tool/generate_postgres_migrations.dart`).
  static String get referenceMigrations =>
      isPostgres ? 'migrations_postgresql' : 'migrations';

  /// A new migration adaptor for this engine.
  static TomSqlMigrationAdaptor migrationAdaptor() =>
      isPostgres ? PostgresMigrationAdaptor() : MariadbMigrationAdaptor();

  /// The full key this engine's migration adaptor raises for [suffix] —
  /// `initialize.…` under its initialize prefix, anything else under its
  /// apply prefix.
  static String migrationKey(String suffix) {
    final prefix = suffix.startsWith('initialize.')
        ? (isPostgres
              ? 'postgres_migration_adapter'
              : 'mariadb_migration_adapter')
        : (isPostgres ? 'postgres_migration' : 'mariadb_migration');
    return '$prefix.$suffix';
  }

  /// Why the two-phase (XA) suites cannot run against this server, or `null`
  /// when they can.
  ///
  /// PostgreSQL allows no prepared transaction until `max_prepared_transactions`
  /// is raised from its default of `0` — the bundled compose file raises it —
  /// and with `0` every `PREPARE TRANSACTION` fails. A server configured that
  /// way is a reason to skip, said as such, rather than a failure.
  static Future<String?> twoPhaseSkipReason() async {
    if (!isPostgres) return null;
    String? reason;
    await _withPostgresServer((connection) async {
      final result = await connection.execute('SHOW max_prepared_transactions');
      if ('${result.first.first}' == '0') {
        reason =
            'the PostgreSQL server allows no prepared transactions '
            '(max_prepared_transactions = 0); start it with '
            'docker-compose.test.postgres.yaml';
      }
    });
    return reason;
  }

  /// Database host (`TOM_CORE_SERVER_TEST_DB_HOST`, default `127.0.0.1`).
  static String get host => _env('TOM_CORE_SERVER_TEST_DB_HOST', '127.0.0.1');

  /// Database port (`TOM_CORE_SERVER_TEST_DB_PORT`, default `3309`).
  ///
  /// `5439` when the engine is PostgreSQL.
  static int get port => int.parse(
    _env('TOM_CORE_SERVER_TEST_DB_PORT', isPostgres ? '5439' : '3309'),
  );

  /// Connection user (`TOM_CORE_SERVER_TEST_DB_USER`, default `root`).
  ///
  /// `postgres` when the engine is PostgreSQL.
  static String get username =>
      _env('TOM_CORE_SERVER_TEST_DB_USER', isPostgres ? 'postgres' : 'root');

  /// Connection password (`TOM_CORE_SERVER_TEST_DB_PASSWORD`, default
  /// `password`).
  static String get password =>
      _env('TOM_CORE_SERVER_TEST_DB_PASSWORD', 'password');

  /// The prefix every suite database is named from
  /// (`TOM_CORE_SERVER_TEST_DB_NAME`, default `tom_core_server_test`).
  ///
  /// No suite writes to a database of this name; it need not exist.
  static String get baseDatabaseName =>
      _env('TOM_CORE_SERVER_TEST_DB_NAME', 'tom_core_server_test');

  /// This suite's own database: `<base>_<minutes since epoch>_<6 hex digits>`.
  ///
  /// A static field is per isolate, and `dart test` gives every suite file an
  /// isolate, so each file sees one stable name for its whole run and no two
  /// files — nor two runs — share one. The timestamp is what lets a later run
  /// recognise, and sweep, a database a killed run never dropped
  /// ([staleAfter]).
  static final String databaseName =
      '${baseDatabaseName}_${DateTime.now().millisecondsSinceEpoch ~/ 60000}_'
      '${Random().nextInt(1 << 24).toRadixString(16).padLeft(6, '0')}';

  /// How old a suite database has to be before provisioning drops it as the
  /// leftover of a run that was killed before its teardown ran.
  ///
  /// Far longer than any run, so a sweep never reaches a live suite's database.
  static const Duration staleAfter = Duration(hours: 12);

  /// The datasource configuration map for [datasourceName], in the shape
  /// [TomDataSourceInfo.initializeDatasourceInfo] consumes.
  static Map<String, dynamic> get datasourceConfig => <String, dynamic>{
    datasourceName: <String, dynamic>{
      'type': isPostgres ? 'postgresql' : 'mariadb',
      'username': username,
      'password': password,
      'host': host,
      'port': port,
      'databaseName': databaseName,
      if (isPostgres) 'sslMode': 'disable',
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
  /// Provisions this suite's database first ([provision]), so call it from a
  /// `setUpAll`: the database is dropped when that group ends. Requires
  /// reflection to be initialised first (the driver is discovered by scanning
  /// `@TomDatasourceDriver` metadata), so call `initializeReflection()` before
  /// this. Returns the live [TomDataSourceInfo].
  static Future<TomDataSourceInfo> register() async {
    await provision();
    await TomDataSourceInfo.initializeDatasourceInfo(datasourceConfig);
    return TomDataSourceInfo.getDataSourceInfo(datasourceName)!;
  }

  /// Creates this suite's database, and drops it when the enclosing group
  /// ends.
  ///
  /// Call from a `setUpAll` — [register] does — so the `addTearDown` it makes
  /// is scoped to the group. A suite that builds its own data source config
  /// from [databaseName] instead of calling [register] calls this directly.
  /// Also sweeps suite databases older than [staleAfter], once per isolate.
  static Future<void> provision() async {
    if (isPostgres) {
      await _withPostgresServer((connection) async {
        _swept ??= _sweepStalePostgresDatabases(connection);
        await _swept;
        await connection.execute('CREATE DATABASE "$databaseName"');
      });
      addTearDown(
        () => _withPostgresServer(
          (connection) => connection.execute(
            'DROP DATABASE IF EXISTS "$databaseName" WITH (FORCE)',
          ),
        ),
      );
      return;
    }
    await _withServerConnection((connection) async {
      _swept ??= _sweepStaleDatabases(connection);
      await _swept;
      await connection.execute('CREATE DATABASE IF NOT EXISTS `$databaseName`');
    });
    addTearDown(
      () => _withServerConnection((connection) async {
        await connection.execute('DROP DATABASE IF EXISTS `$databaseName`');
      }),
    );
  }

  static Future<void>? _swept;

  /// The suite-database name shape a sweep recognises, and the cut-off before
  /// which one is stale.
  static (RegExp, int) _staleShape() => (
    RegExp('^${RegExp.escape(baseDatabaseName)}_(\\d+)_[0-9a-f]{6}\$'),
    DateTime.now().subtract(staleAfter).millisecondsSinceEpoch ~/ 60000,
  );

  /// Drops every suite database named from [baseDatabaseName] whose timestamp
  /// is older than [staleAfter]. Names that do not have the suite shape — the
  /// base database itself, or anything else sharing its prefix — are left
  /// alone.
  static Future<void> _sweepStaleDatabases(MySQLConnection connection) async {
    final (shape, cutoff) = _staleShape();
    final result = await connection.execute('SHOW DATABASES');
    for (final row in result.rows) {
      final name = row.colAt(0);
      final match = name == null ? null : shape.firstMatch(name);
      if (match == null || int.parse(match.group(1)!) >= cutoff) continue;
      await connection.execute('DROP DATABASE IF EXISTS `$name`');
    }
  }

  /// The PostgreSQL face of [_sweepStaleDatabases].
  static Future<void> _sweepStalePostgresDatabases(
    pg.Connection connection,
  ) async {
    final (shape, cutoff) = _staleShape();
    final result = await connection.execute('SELECT datname FROM pg_database');
    for (final row in result) {
      final name = row.first as String;
      final match = shape.firstMatch(name);
      if (match == null || int.parse(match.group(1)!) >= cutoff) continue;
      await connection.execute('DROP DATABASE IF EXISTS "$name" WITH (FORCE)');
    }
  }

  /// Runs [action] on a short-lived connection bound to no database —
  /// creating and dropping a suite database needs a connection that is not
  /// inside it.
  static Future<void> _withServerConnection(
    Future<void> Function(MySQLConnection connection) action,
  ) async {
    final connection = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: username,
      password: password,
    );
    await connection.connect();
    try {
      await action(connection);
    } finally {
      await connection.close();
    }
  }

  /// The PostgreSQL face of [_withServerConnection], on the server's
  /// maintenance database.
  static Future<void> _withPostgresServer(
    Future<void> Function(pg.Connection connection) action,
  ) async {
    final connection = await pg.Connection.open(
      pg.Endpoint(
        host: host,
        port: port,
        database: 'postgres',
        username: username,
        password: password,
      ),
      settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
    );
    try {
      await action(connection);
    } finally {
      await connection.close();
    }
  }

  /// Creates the database [name] beside the suite's own, through
  /// [datasource] — for a test of tenants isolated by database.
  static Future<void> createDatabase(TomDataSource datasource, String name) =>
      datasource.executeCommand(
        isPostgres
            ? 'CREATE DATABASE "$name"'
            : 'CREATE DATABASE IF NOT EXISTS `$name`',
      );

  /// Drops the database [name] [createDatabase] made.
  static Future<void> dropDatabase(TomDataSource datasource, String name) =>
      datasource.executeCommand(
        isPostgres
            ? 'DROP DATABASE IF EXISTS "$name" WITH (FORCE)'
            : 'DROP DATABASE IF EXISTS `$name`',
      );

  /// Drops the tenant schema [name] — a database on MariaDB, where the two are
  /// one thing, and a schema inside the suite's database on PostgreSQL.
  static Future<void> dropSchema(TomDataSource datasource, String name) =>
      datasource.executeCommand(
        isPostgres
            ? 'DROP SCHEMA IF EXISTS "$name" CASCADE'
            : 'DROP DATABASE IF EXISTS `$name`',
      );

  /// Runs [sql] — written in the framework's canonical DDL, MariaDB's spelling
  /// — on [datasource], as the statements its database runs to the same
  /// effect (`TomStandardSqlDialect.translateCanonical`). Every DDL statement a
  /// suite issues goes through here, so one fixture declaration serves both
  /// databases.
  static Future<void> execute(TomDataSource datasource, String sql) async {
    for (final statement in datasource.sqlDialect.translateCanonical(sql)) {
      await datasource.executeCommand(statement);
    }
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
    await execute(dsi.datasource, _fixtureTaskDdl);
  }

  /// Empties the `fixture_task` table so each test starts from a known state.
  ///
  /// Uses `TRUNCATE` so the AUTO_INCREMENT counter resets too, keeping the
  /// generated-key assertions independent of test ordering.
  static Future<void> truncateFixtureTask(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, 'TRUNCATE TABLE fixture_task');
  }

  /// The three tables the `@TomReference` fixture needs: the owner, the target
  /// and the join between them.
  ///
  /// Created and truncated together because the association is the thing under
  /// test: a link row pointing at a tag that no longer exists is not a state
  /// any of these tests means to produce, and truncating them apart is how one
  /// arrives.
  static const List<String> _fixtureAssociationDdl = [
    '''
CREATE TABLE IF NOT EXISTS fixture_tag (
  id   BIGINT       NOT NULL AUTO_INCREMENT,
  name VARCHAR(255) NULL,
  PRIMARY KEY (id)
)
''',
    '''
CREATE TABLE IF NOT EXISTS fixture_tagged (
  id    BIGINT       NOT NULL AUTO_INCREMENT,
  label VARCHAR(255) NULL,
  PRIMARY KEY (id)
)
''',
    '''
CREATE TABLE IF NOT EXISTS fixture_tag_link (
  id        BIGINT NOT NULL AUTO_INCREMENT,
  tagged_id BIGINT NULL,
  tag_id    BIGINT NULL,
  PRIMARY KEY (id)
)
''',
  ];

  /// Creates the three association tables if they do not already exist.
  static Future<void> ensureFixtureAssociationTables(
    TomDataSourceInfo dsi,
  ) async {
    for (final ddl in _fixtureAssociationDdl) {
      await execute(dsi.datasource, ddl);
    }
  }

  /// Empties all three, resetting their AUTO_INCREMENT counters.
  static Future<void> truncateFixtureAssociationTables(
    TomDataSourceInfo dsi,
  ) async {
    for (final table in const [
      'fixture_tag_link',
      'fixture_tagged',
      'fixture_tag',
    ]) {
      await execute(dsi.datasource, 'TRUNCATE TABLE $table');
    }
  }

  /// The DDL for `FixtureTaskLabel`, the entity keyed by two columns and no
  /// surrogate — the shape of a legacy join table.
  static const String _fixtureTaskLabelDdl = '''
CREATE TABLE IF NOT EXISTS fixture_task_label (
  task_id BIGINT       NOT NULL,
  label   VARCHAR(64)  NOT NULL,
  note    VARCHAR(255) NULL,
  PRIMARY KEY (task_id, label)
)
''';

  /// Creates the `fixture_task_label` table if it does not already exist.
  static Future<void> ensureFixtureTaskLabelTable(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, _fixtureTaskLabelDdl);
  }

  /// Empties the `fixture_task_label` table so each test starts from a known
  /// state.
  static Future<void> truncateFixtureTaskLabel(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, 'TRUNCATE TABLE fixture_task_label');
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
    await execute(dsi.datasource, _fixtureSecretDdl);
  }

  /// Empties the `fixture_secret` table so each test starts from a known state.
  static Future<void> truncateFixtureSecret(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, 'TRUNCATE TABLE fixture_secret');
  }

  /// The DDL for `FixtureDocumentRecord`, the entity whose two columns hold
  /// blob-storage keys rather than bytes.
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
    await execute(dsi.datasource, _fixtureDocumentDdl);
  }

  /// Empties the `fixture_document` table so each test starts from a known
  /// state.
  static Future<void> truncateFixtureDocument(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, 'TRUNCATE TABLE fixture_document');
  }

  /// The DDL for `FixtureScopedDocumentRecord`, the row-scoped counterpart of
  /// `fixture_document`. `owner_id` is the `@TomDbScope` field, so it
  /// is the column the repository ANDs into every read's `WHERE`.
  static const String _fixtureScopedDocumentDdl = '''
CREATE TABLE IF NOT EXISTS fixture_scoped_document (
  id         BIGINT       NOT NULL AUTO_INCREMENT,
  owner_id   VARCHAR(255) NULL,
  title      VARCHAR(255) NULL,
  attachment VARCHAR(512) NULL,
  PRIMARY KEY (id)
)
''';

  /// Creates the `fixture_scoped_document` table if it does not already exist.
  static Future<void> ensureFixtureScopedDocumentTable(
    TomDataSourceInfo dsi,
  ) async {
    await execute(dsi.datasource, _fixtureScopedDocumentDdl);
  }

  /// Empties the `fixture_scoped_document` table so each test starts from a
  /// known state.
  static Future<void> truncateFixtureScopedDocument(
    TomDataSourceInfo dsi,
  ) async {
    await execute(dsi.datasource, 'TRUNCATE TABLE fixture_scoped_document');
  }

  /// The DDL for `FixtureResourceRecord`, the entity the grant-driven row scope
  /// filters *without* an annotation. `resource_key` is what makes it
  /// scoped: the analyzer sees the column and synthesizes the scope.
  static const String _fixtureResourceDdl = '''
CREATE TABLE IF NOT EXISTS fixture_resource_document (
  id           BIGINT       NOT NULL AUTO_INCREMENT,
  resource_key VARCHAR(255) NULL,
  title        VARCHAR(255) NULL,
  PRIMARY KEY (id)
)
''';

  /// Creates the `fixture_resource_document` table if it does not already
  /// exist.
  static Future<void> ensureFixtureResourceTable(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, _fixtureResourceDdl);
  }

  /// Empties the `fixture_resource_document` table so each test starts from a
  /// known state.
  static Future<void> truncateFixtureResource(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, 'TRUNCATE TABLE fixture_resource_document');
  }

  /// The DDL for `FixtureAmountRecord`, the entity whose numeric columns are
  /// `DECIMAL` rather than `INT`/`DOUBLE`.
  ///
  /// `DECIMAL(10,2)` is what a money column actually is, and the driver reports
  /// it as protocol type `NEWDECIMAL` (246) — the type its `double` and `int`
  /// conversion whitelists both omit. `quantity` is `DECIMAL(10,0)`: the same
  /// protocol type with scale 0, which is an exact integer and must still map
  /// onto a Dart `int`.
  static const String _fixtureAmountDdl = '''
CREATE TABLE IF NOT EXISTS fixture_amount (
  id       BIGINT        NOT NULL AUTO_INCREMENT,
  label    VARCHAR(255)  NULL,
  amount   DECIMAL(10,2) NULL,
  quantity DECIMAL(10,0) NULL,
  PRIMARY KEY (id)
)
''';

  /// The DDL for the temporal-halves fixture.
  ///
  /// `DATE` and `TIME` are the two column types the framework maps
  /// `TomZonedDate` and `TomZonedTime` onto, and they are declared here without
  /// precision on purpose: that is what a migration derived from the type family
  /// produces, and it is the shape whose read-back the renderers have to agree
  /// with. A `TIME(6)` would hide the truncation `sqlTimeOfDay` performs.
  static const String _fixtureTemporalDdl = '''
CREATE TABLE IF NOT EXISTS fixture_temporal (
  id        BIGINT       NOT NULL AUTO_INCREMENT,
  label     VARCHAR(255) NULL,
  due_on    DATE         NULL,
  remind_at TIME         NULL,
  occurred_at DATETIME(6) NULL,
  PRIMARY KEY (id)
)
''';

  /// Creates the `fixture_temporal` table if it does not already exist.
  static Future<void> ensureFixtureTemporalTable(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, _fixtureTemporalDdl);
  }

  /// Empties the `fixture_temporal` table so each test starts from a known
  /// state.
  static Future<void> truncateFixtureTemporal(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, 'TRUNCATE TABLE fixture_temporal');
  }

  /// Creates the `fixture_amount` table if it does not already exist.
  static Future<void> ensureFixtureAmountTable(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, _fixtureAmountDdl);
  }

  /// Empties the `fixture_amount` table so each test starts from a known state.
  static Future<void> truncateFixtureAmount(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, 'TRUNCATE TABLE fixture_amount');
  }

  /// The DDL for the nullable-observable fixtures.
  ///
  /// Every column is deliberately a **plain, long-supported SQL type** — no
  /// `DECIMAL`, no aggregate, no driver quirk. The defect this table exists to
  /// expose is in the mapper's own type matching, so the columns must be ones
  /// the driver converts without complaint; anything exotic here would make a
  /// red step ambiguous between this defect and the driver's `NEWDECIMAL` gap.
  ///
  /// `active` is `TINYINT(1)` rather than `INT` because the driver's `bool`
  /// conversion requires protocol type `Tiny` *and* a column length of 1: an
  /// `INT` column would come back unconvertible and, again, blur the red.
  ///
  /// Every value column is `NULL`-able, because a nullable observable's second
  /// obligation — after mapping at all — is to carry an actual SQL `NULL`
  /// through as `null`.
  static const String _fixtureNullableDdl = '''
CREATE TABLE IF NOT EXISTS fixture_nullable (
  id          BIGINT       NOT NULL AUTO_INCREMENT,
  name        VARCHAR(255) NULL,
  ratio       DOUBLE       NULL,
  quantity    INT          NULL,
  active      TINYINT(1)   NULL,
  occurred_at DATETIME     NULL,
  PRIMARY KEY (id)
)
''';

  /// Creates the `fixture_nullable` table if it does not already exist.
  static Future<void> ensureFixtureNullableTable(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, _fixtureNullableDdl);
  }

  /// Empties the `fixture_nullable` table so each test starts from a known
  /// state.
  static Future<void> truncateFixtureNullable(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, 'TRUNCATE TABLE fixture_nullable');
  }

  /// Drops the blob store's two tables, so a `TomDatabaseBlobStore` test starts
  /// from an empty store regardless of what an earlier run left behind.
  ///
  /// Dropped rather than truncated because the store creates them on first use:
  /// a run that changed the schema would otherwise keep the previous shape.
  static Future<void> dropBlobTables(
    TomDataSourceInfo dsi, {
    String manifestTable = defaultBlobManifestTable,
    String chunkTable = defaultBlobChunkTable,
  }) async {
    await execute(dsi.datasource, 'DROP TABLE IF EXISTS $chunkTable');
    await execute(dsi.datasource, 'DROP TABLE IF EXISTS $manifestTable');
  }

  /// Whether [table] currently exists in the fixture schema.
  ///
  /// Answered by running a statement that selects no rows and seeing whether
  /// the server accepts it: MariaDB resolves the table name before it discovers
  /// that the `WHERE` matches nothing, so a rejection means the table is
  /// missing rather than that the probe went wrong. The exception is not being
  /// swallowed — it **is** the answer, the same arrangement as
  /// `TomSqlAuditSink._permits`.
  ///
  /// Exists so a test can assert that a store left the schema alone. A store
  /// built with `createSchema: false` must issue no DDL, and the only honest
  /// evidence for that is the database still not having the table afterwards.
  static Future<bool> tableExists(TomDataSourceInfo dsi, String table) async {
    try {
      await execute(dsi.datasource, 'SELECT 1 FROM $table WHERE 1 = 0');
      return true;
    } on Object {
      return false;
    }
  }

  /// Creates the blob store's two tables from the module's own shipped DDL.
  ///
  /// The migration-owned arrangement, expressed the way a deployment expresses
  /// it: the schema arrives from somewhere that is not the store. Built from
  /// [blobManifestTableDdl] / [blobChunkTableDdl] rather than from a copy of
  /// the `CREATE TABLE` text, so a test running against tables the framework
  /// did not create is still running against the framework's own shape.
  static Future<void> createBlobTables(
    TomDataSourceInfo dsi, {
    String manifestTable = defaultBlobManifestTable,
    String chunkTable = defaultBlobChunkTable,
  }) async {
    await execute(dsi.datasource, blobManifestTableDdl(manifestTable));
    await execute(dsi.datasource, blobChunkTableDdl(chunkTable));
  }

  /// Drops the relational scheduler's tables.
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
    await execute(dsi.datasource, 'DROP TABLE IF EXISTS $jobRunTable');
    await execute(dsi.datasource, 'DROP TABLE IF EXISTS $leaseTable');
    await execute(dsi.datasource, 'DROP TABLE IF EXISTS $nodeTable');
  }

  /// Drops the relational audit trail's table and its optional guard triggers.
  ///
  /// The triggers are dropped explicitly even though MariaDB drops a table's
  /// triggers with it: a test that installs a guard and then fails part-way
  /// would otherwise leave an `UPDATE`-rejecting trigger behind for whatever
  /// runs next, and the failure it caused would look like a different bug.
  static Future<void> dropAuditTrailTable(
    TomDataSourceInfo dsi, {
    String table = defaultAuditTrailTable,
  }) async {
    if (isPostgres) {
      // A PostgreSQL trigger goes with its table; the function each guard
      // calls does not, and is dropped by name.
      await execute(dsi.datasource, 'DROP TABLE IF EXISTS $table CASCADE');
      for (final trigger in [
        auditTrailNoUpdateTriggerName(table),
        auditTrailNoDeleteTriggerName(table),
      ]) {
        await execute(
          dsi.datasource,
          'DROP FUNCTION IF EXISTS ${trigger}_reject()',
        );
      }
      return;
    }
    await execute(
      dsi.datasource,
      'DROP TRIGGER IF EXISTS ${auditTrailNoUpdateTriggerName(table)}',
    );
    await execute(
      dsi.datasource,
      'DROP TRIGGER IF EXISTS ${auditTrailNoDeleteTriggerName(table)}',
    );
    await execute(dsi.datasource, 'DROP TABLE IF EXISTS $table');
  }

  /// Drops the relational OAuth state store's table.
  ///
  /// Dropped rather than truncated for the same reason as the scheduling
  /// tables: the store creates it on first use, so a run that changed the DDL
  /// would otherwise keep the previous shape.
  static Future<void> dropOAuthStateTable(
    TomDataSourceInfo dsi, {
    String table = defaultOAuthStateTable,
  }) async {
    await execute(dsi.datasource, 'DROP TABLE IF EXISTS $table');
  }

  /// Drops the delivery-correlation table, for the same reason.
  static Future<void> dropDeliveryReportTable(
    TomDataSourceInfo dsi, {
    String table = defaultDeliveryReportTable,
  }) async {
    await execute(dsi.datasource, 'DROP TABLE IF EXISTS $table');
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
    await execute(
      dsi.datasource,
      'DROP TABLE IF EXISTS ${schemaName}_versioning',
    );
  }

  /// Aliases the framework's conventional `main` data source onto this
  /// fixture's connection.
  ///
  /// Framework entities — [TomUserTwoFactorEnrolment], the authorization grant
  /// tables — declare `@TomDbTable(datasource: 'main')`, because that is the
  /// name a deployment configures. A test cannot rename them without diverging
  /// from what ships, and must not open a second connection to answer to the
  /// second name, so it registers `main` as a *delegate* of the fixture source:
  /// one connection, reachable under both names.
  static Future<void> registerMainAlias() async {
    await TomDataSourceInfo.initializeDatasourceInfo(<String, dynamic>{
      'main': <String, Object?>{'delegateTo': datasourceName},
    });
  }

  /// Runs a framework entity's own `createTableSql`.
  ///
  /// Every framework table below is created from the entity's constant rather
  /// than from a copy of its DDL, so a test and the shipped migration cannot
  /// describe different tables. The statement terminator belongs to a migration
  /// *file*, where several statements have to be told apart; the driver takes
  /// one statement and rejects the trailing `;`.
  static Future<void> _ensureEntityTable(
    TomDataSourceInfo dsi,
    String createTableSql,
  ) async {
    final ddl = createTableSql.trim();
    await execute(
      dsi.datasource,
      ddl.endsWith(';') ? ddl.substring(0, ddl.length - 1) : ddl,
    );
  }

  /// Creates the `tom_user_two_factor_enrolment` table from the entity's own
  /// DDL.
  static Future<void> ensureTwoFactorEnrolmentTable(
    TomDataSourceInfo dsi,
  ) async => _ensureEntityTable(dsi, TomUserTwoFactorEnrolment.createTableSql);

  /// Empties `tom_user_two_factor_enrolment` between tests.
  static Future<void> truncateTwoFactorEnrolment(TomDataSourceInfo dsi) async {
    await execute(
      dsi.datasource,
      'TRUNCATE TABLE tom_user_two_factor_enrolment',
    );
  }

  /// Creates the `tom_user_preference` table from the entity's own DDL.
  static Future<void> ensureUserPreferenceTable(TomDataSourceInfo dsi) async =>
      _ensureEntityTable(dsi, TomUserPreference.createTableSql);

  /// Empties `tom_user_preference` between tests.
  static Future<void> truncateUserPreference(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, 'TRUNCATE TABLE tom_user_preference');
  }

  /// Creates the `tom_external_identity` link table from the entity's own DDL.
  static Future<void> ensureExternalIdentityTable(
    TomDataSourceInfo dsi,
  ) async => _ensureEntityTable(dsi, TomExternalIdentityLink.createTableSql);

  /// Empties `tom_external_identity` between tests.
  static Future<void> truncateExternalIdentity(TomDataSourceInfo dsi) async {
    await execute(dsi.datasource, 'TRUNCATE TABLE tom_external_identity');
  }

  /// Creates the `tom_external_identity_token` table from the entity's own DDL.
  static Future<void> ensureExternalIdentityTokenTable(
    TomDataSourceInfo dsi,
  ) async => _ensureEntityTable(dsi, TomExternalIdentityToken.createTableSql);

  /// Empties `tom_external_identity_token` between tests.
  static Future<void> truncateExternalIdentityToken(
    TomDataSourceInfo dsi,
  ) async {
    await execute(dsi.datasource, 'TRUNCATE TABLE tom_external_identity_token');
  }

  /// Closes every registered data source and clears the process-wide registry,
  /// so a torn-down suite leaves no open connection or stale registration for
  /// the next one.
  static Future<void> reset() async {
    await TomDataSourceInfo.closeAll();
    TomDataSourceInfo.datasources.clear();
  }
}

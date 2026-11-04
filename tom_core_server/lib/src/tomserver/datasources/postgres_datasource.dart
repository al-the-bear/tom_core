/// The PostgreSQL driver (PostgreSQL 15 and later), over `package:postgres`.
///
/// Everything a SQL data source does that does not depend on the database —
/// the pool, the transaction a connection is pinned to, the statement paths,
/// the row mapping — is [TomSqlDatasource]'s, shared with the MariaDB driver.
/// What is here is the wire: opening a connection, running a statement on it,
/// and reading its typed result values into the text convention the shared
/// mapper reads.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:postgres/postgres.dart' as pg;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../transactions/transaction_manager.dart';
import 'datasource_initialization.dart';
import 'postgres_sql_dialect.dart';
import 'sql_datasource.dart';
import 'sql_dialects.dart';
import 'sql_failure_mode.dart';
import 'sql_instant.dart';
import 'sql_placeholder_scan.dart';

/// Thrown for PostgreSQL data-source failures (connect, execute, result
/// mapping).
class PostgresDatasourceException extends TomSqlDatasourceException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomSqlDatasourceException].
  PostgresDatasourceException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// Thrown when a PostgreSQL prepared statement failed with no live connection
/// to have run on, signalling that a single reconnect-and-retry may recover
/// it; see [TomSqlConnectionLostException].
class PostgresConnectionLostException extends TomSqlConnectionLostException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomSqlConnectionLostException].
  PostgresConnectionLostException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// One pooled PostgreSQL connection and the statements prepared on it.
class _PostgresLink extends TomSqlLink {
  _PostgresLink(this.connection);

  final pg.Connection connection;

  /// Server-side prepared statements, by SQL text.
  final Map<String, pg.Statement> statements = {};

  /// Statements to dispose of the next time the link is handed back.
  final List<pg.Statement> pendingDisposal = [];

  @override
  bool get connected => connection.isOpen;

  Future<pg.Statement> statement(String command) async =>
      statements[command] ??= await connection.prepare(pg.Sql(command));
}

/// Wraps every bind value as a parameter of unspecified type, sent as text.
///
/// PostgreSQL then infers each parameter's type from where it is used, which is
/// what lets one marshalled value — `tomSqlBindValue`'s `1`, its instant text —
/// read correctly into a `SMALLINT`, a `BOOLEAN` or a `TIMESTAMP` column alike.
/// A typed bind would have to know the column's type before the server does.
List<Object?> _bindList(List<Object?> values) => [
  for (final value in values) pg.TypedValue(pg.Type.unspecified, value),
];

/// A row of a PostgreSQL result, its typed values read as text in the
/// convention [TomSqlRow] states.
class _PostgresRow implements TomSqlRow {
  _PostgresRow(this.row, this.index, this.oids);

  final pg.ResultRow row;

  /// Column position by lower-cased name: PostgreSQL folds unquoted
  /// identifiers, so `SELECT x AS dueAt` answers a column called `dueat`.
  final Map<String, int> index;

  /// Each column's type, by position.
  final List<int> oids;

  Object? _value(String column) {
    final at = index[column.toLowerCase()];
    return at == null ? null : row[at];
  }

  int? _oid(String column) {
    final at = index[column.toLowerCase()];
    return at == null ? null : oids[at];
  }

  @override
  String? text(String column) => _render(_value(column), _oid(column));

  @override
  String? temporalText(String column) => text(column);

  @override
  bool? boolean(String column) {
    final value = _value(column);
    return switch (value) {
      null => null,
      bool b => b,
      int i => i != 0,
      String s => s == '1' || s == 't' || s.toLowerCase() == 'true',
      _ => null,
    };
  }

  static String? _render(Object? value, int? oid) {
    return switch (value) {
      null => null,
      String s => s,
      bool b => b ? '1' : '0',
      int i => '$i',
      double d => '$d',
      DateTime t when oid == pg.Type.date.oid => sqlDate(t),
      DateTime t => sqlInstant(t),
      pg.Time t => _timeText(t),
      Uint8List bytes => utf8.decode(bytes, allowMalformed: true),
      pg.UndecodedBytes u => u.asString,
      Map<dynamic, dynamic>() || List<dynamic>() => jsonEncode(value),
      _ => '$value',
    };
  }

  /// `HH:MM:SS`, with the fraction only when there is one — the form a
  /// MariaDB `TIME` column answers with.
  static String _timeText(pg.Time time) {
    String two(int n) => n.toString().padLeft(2, '0');
    final t = time.utcDateTime;
    final base = '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
    final micros = t.millisecond * 1000 + t.microsecond;
    return micros == 0 ? base : '$base.${micros.toString().padLeft(6, '0')}';
  }
}

/// A PostgreSQL [TomDataSource] driver (registered for the `"postgresql"`
/// type); see [TomSqlDatasource] for the connection, lifecycle and mapping
/// rules every SQL driver shares, and [PostgresSqlDialect] for how the
/// framework's tables and statements read on PostgreSQL.
///
/// Transactions are plain `BEGIN` / `COMMIT` / `ROLLBACK`;
/// [PostgresXADatasource] is the two-phase variant.
///
/// Every session runs with `TimeZone` set to `UTC`, so a server-side
/// `CURRENT_TIMESTAMP` reads in the same zone the framework writes instants in.
@tomReflector
@TomDatasourceDriver("postgresql")
class PostgresDatasource extends TomSqlDatasource {
  /// A driver with PostgreSQL's default port.
  PostgresDatasource() {
    port = 5432;
  }

  final PostgresSqlDialect _sqlDialect = PostgresSqlDialect();

  @override
  TomStandardSqlDialect get sqlDialect => _sqlDialect;

  /// The schema statements resolve unqualified names in (`search_path`), or
  /// empty for the server's default (`public`).
  ///
  /// This is what a schema-isolated tenant is: one database, a schema per
  /// tenant, each data source pointing at its own.
  String schema = "";

  /// How the connection is encrypted: `disable`, `require` (encrypt, accept any
  /// certificate) or `verifyFull` (encrypt and verify). `require` unless set,
  /// so a deployment that has not thought about it still encrypts.
  String sslMode = "require";

  /// A replica of this data source is a plain PostgresDatasource — one-phase even
  /// behind an XA primary, since a replica only ever serves reads.
  @override
  TomSqlDatasource newReplica() => PostgresDatasource();

  @override
  String get driverLabel => "PostgresDatasource";

  @override
  String get dbSystemName => 'postgresql';

  /// [schema], or `public` — the server's default — when none is set.
  @override
  String get schemaName => schema.isEmpty ? 'public' : schema;

  /// Also the same database: PostgreSQL reaches another schema of the
  /// connection's database, never another database.
  @override
  bool canQualify(TomSqlDatasource other) =>
      super.canQualify(other) && other.databaseName == databaseName;

  @override
  String get preparedStatementLabel => "PostgresPreparedStatement";

  @override
  String get participantPrefix => "Postgres";

  @override
  PostgresDatasourceException datasourceException(
    String key,
    String message, {
    Map<String, dynamic>? parameters,
    StackTrace? stack,
    Object? rootException,
    bool autoLog = false,
  }) => PostgresDatasourceException(
    key,
    message,
    parameters: parameters,
    stack: stack,
    rootException: rootException,
    autoLog: autoLog,
  );

  @override
  PostgresConnectionLostException connectionLostException(
    String key,
    String message, {
    Map<String, dynamic>? parameters,
    StackTrace? stack,
    Object? rootException,
  }) => PostgresConnectionLostException(
    key,
    message,
    parameters: parameters,
    stack: stack,
    rootException: rootException,
  );

  pg.SslMode get _sslMode => switch (sslMode) {
    'disable' => pg.SslMode.disable,
    'require' => pg.SslMode.require,
    'verifyFull' => pg.SslMode.verifyFull,
    _ => throw datasourceException(
      "error.initialize.invalid_ssl_mode",
      "$driverLabel: sslMode '$sslMode' is none of disable, require, "
          "verifyFull.",
      parameters: {"sslMode": sslMode},
    ),
  };

  @override
  Future<TomSqlLink> openLink() async {
    final connection = await pg.Connection.open(
      pg.Endpoint(
        host: host,
        port: port,
        database: databaseName.isEmpty ? 'postgres' : databaseName,
        username: username,
        password: password,
      ),
      settings: pg.ConnectionSettings(
        sslMode: _sslMode,
        connectTimeout: Duration(milliseconds: timeOut),
        timeZone: 'UTC',
        applicationName: 'tom_core_server',
      ),
    );
    if (schema.isNotEmpty) {
      await connection.execute(
        pg.Sql('SET search_path TO ${_sqlDialect.quoteIdentifier(schema)}'),
      );
    }
    return _PostgresLink(connection);
  }

  /// PostgreSQL's advisory locks take a number; the name is hashed into one
  /// with `hashtextextended`, the same on every node.
  @override
  Future<bool> tryLockOn(TomSqlLink link, String name) async {
    final result = await runCommandOn(
      link,
      'SELECT pg_try_advisory_lock(hashtextextended(:name, 0)) AS got',
      {'name': name},
    );
    return result.rows.single.boolean('got') ?? false;
  }

  @override
  Future<void> unlockOn(TomSqlLink link, String name) async {
    await runCommandOn(
      link,
      'SELECT pg_advisory_unlock(hashtextextended(:name, 0)) AS released',
      {'name': name},
    );
  }

  @override
  Future<void> closeLink(TomSqlLink link) async {
    try {
      await (link as _PostgresLink).connection.close();
    } catch (error) {
      tomLog.warn(
        "$driverLabel ${getParticipantId()}: closing a pooled connection "
        "failed: $error",
      );
    }
  }

  @override
  Future<bool> validateLink(TomSqlLink link) async {
    try {
      await (link as _PostgresLink).connection.execute(pg.Sql('SELECT 1'));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> prepareOn(TomSqlLink link, String command, int parameterCount) =>
      (link as _PostgresLink).statement(command);

  /// Runs [command] on [link]'s prepared statement, preparing it on first use.
  ///
  /// A statement prepared before its table changed shape — a migration added
  /// a column under a long-lived repository's `SELECT *` — is refused by
  /// PostgreSQL with `cached plan must not change result type` (`0A000`).
  /// MariaDB re-prepares such a statement on its own; here the stale statement
  /// is dropped and prepared again, once, so a schema change does not need
  /// every pooled connection replaced.
  @override
  Future<TomSqlResult> runPreparedOn(
    TomSqlLink link,
    String command,
    List<Object?> parameters,
  ) async {
    final pgLink = link as _PostgresLink;
    try {
      final stmt = await pgLink.statement(command);
      return _resultOf(command, await stmt.run(_bindList(parameters)));
    } on pg.ServerException catch (error) {
      if (error.code != _cachedPlanChanged) rethrow;
      final stale = pgLink.statements.remove(command);
      if (stale != null) await stale.dispose();
      final stmt = await pgLink.statement(command);
      return _resultOf(command, await stmt.run(_bindList(parameters)));
    }
  }

  /// PostgreSQL's SQLSTATE for a cached plan whose result type changed.
  static const String _cachedPlanChanged = '0A000';

  @override
  Future<TomSqlResult> runCommandOn(
    TomSqlLink link,
    String command,
    Map<String, Object?>? params,
  ) async {
    final (sql, names) = toPositional(command);
    final values = [for (final name in names) params?[name]];
    final result = await (link as _PostgresLink).connection.execute(
      pg.Sql(sql),
      parameters: _bindList(values),
    );
    return _resultOf(command, result);
  }

  @override
  void forgetStatementOn(TomSqlLink link, String command) {
    final pgLink = link as _PostgresLink;
    final stmt = pgLink.statements.remove(command);
    if (stmt != null) pgLink.pendingDisposal.add(stmt);
  }

  @override
  Future<void> releaseForgottenOn(TomSqlLink link) async {
    final pgLink = link as _PostgresLink;
    if (pgLink.pendingDisposal.isEmpty) return;
    final pending = List.of(pgLink.pendingDisposal);
    pgLink.pendingDisposal.clear();
    for (final stmt in pending) {
      try {
        await stmt.dispose();
      } catch (error) {
        tomLog.warn("$driverLabel: disposing of a statement failed: $error");
      }
    }
  }

  @override
  bool isLostConnection(Object error, TomSqlLink link) =>
      isLostConnectionFailure(error, connected: link.connected);

  @override
  String beginStatement({required bool readOnly}) =>
      readOnly ? "BEGIN READ ONLY" : "BEGIN";

  @override
  String get commitStatement => "COMMIT";

  @override
  String get rollbackStatement => "ROLLBACK";

  /// `:name` placeholders to PostgreSQL's `$1`, `$2`, …, one slot per
  /// occurrence, with backslashes in string literals read as PostgreSQL reads
  /// them — as themselves.
  @override
  (String, List<String>) toPositional(String namedSql) =>
      SqlPlaceholderScan.toPositional(
        namedSql,
        slot: (index) => '\$${index + 1}',
        backslashEscapes: false,
      );

  static final RegExp _insertReturning = RegExp(
    r'^\s*INSERT\b[\s\S]*\bRETURNING\b',
    caseSensitive: false,
  );

  /// [result] in the driver-neutral form the shared mapper reads.
  ///
  /// An `INSERT … RETURNING` of one row and one integer column reports that
  /// integer as the generated id — the key `TomStandardSqlDialect.returningKey`
  /// asked for — since PostgreSQL has no last-insert id to report it by.
  static TomSqlResult _resultOf(String command, pg.Result result) {
    final columns = [for (final c in result.schema.columns) c.columnName ?? ''];
    final oids = [for (final c in result.schema.columns) c.typeOid];
    final index = <String, int>{
      for (var i = 0; i < columns.length; i++) columns[i].toLowerCase(): i,
    };
    int? generatedId;
    if (result.length == 1 &&
        columns.length == 1 &&
        _insertReturning.hasMatch(command)) {
      final value = result.first.first;
      if (value is int) generatedId = value;
    }
    return TomSqlResultValues(
      columns: columns,
      rows: [for (final row in result) _PostgresRow(row, index, oids)],
      affectedRows: result.affectedRows,
      generatedId: generatedId,
      caseInsensitiveColumns: true,
    );
  }

  @override
  void bindSettings(Map<String, dynamic> settings) =>
      tomReflectionInfo.setValues<PostgresDatasource>(this, settings);
}

/// A PostgreSQL [TomDataSource] taking part in **two-phase commits**
/// (registered for the `"postgresql_xa"` type).
///
/// PostgreSQL's two-phase commit maps onto the coordinator's phases directly:
/// [startTransaction] issues `BEGIN`, [prepare] issues
/// `PREPARE TRANSACTION '<id>'`, [commit] issues `COMMIT PREPARED '<id>'`, and
/// [rollback] issues `ROLLBACK` while the transaction is still open or
/// `ROLLBACK PREPARED '<id>'` once it has been prepared. A prepared transaction
/// survives a server restart and is resolved only by those two statements —
/// which is the promise the prepare phase asks every participant for.
///
/// The server must allow prepared transactions: `max_prepared_transactions`
/// above zero (it is `0` by default, which makes `PREPARE TRANSACTION` fail
/// and so vetoes every two-phase transaction this data source joins).
///
/// Unlike MariaDB's `XA START`, `BEGIN` has a read-only form, so a read-only
/// transaction is honoured here as on the one-phase driver.
@tomReflector
@TomDatasourceDriver("postgresql_xa")
class PostgresXADatasource extends PostgresDatasource
    with TomSqlTwoPhaseRecovery {
  /// The prepared transactions of this database.
  @override
  String get listPreparedSql =>
      'SELECT gid FROM pg_prepared_xacts WHERE database = current_database()';

  @override
  String get preparedIdColumn => 'gid';

  @override
  String commitPreparedSql(String quotedId) => 'COMMIT PREPARED $quotedId';

  @override
  String rollbackPreparedSql(String quotedId) => 'ROLLBACK PREPARED $quotedId';

  /// The most bytes a prepared transaction's id may hold.
  static const int maxBranchIdBytes = 200;

  static final String _processTag = Random.secure()
      .nextInt(1 << 32)
      .toRadixString(16)
      .padLeft(8, '0');

  static int _branchCounter = 0;

  String _newBranchId() => tomSqlBranchId(
    databaseName: databaseName,
    host: host,
    port: port,
    processTag: _processTag,
    counter: _branchCounter++,
    maxBytes: maxBranchIdBytes,
  );

  /// Opens the transaction and names its branch; the branch id doubles as the
  /// in-transaction guard, exactly as on `MariaDbXADatasource`.
  @override
  Future<bool> startTransaction(TomTransaction transaction) async {
    final existing = branchOf(transaction);
    if (existing != null && existing.xaId != null) {
      refuseNestedTransaction(existing.xaId);
    }
    final branch = openBranch(transaction, existing)
      ..xaId = "'${_newBranchId()}'"
      ..ended = false;
    try {
      await lifecycle(
        transaction,
        beginStatement(readOnly: transaction.isReadOnly),
      );
      branch.active = true;
      branch.started.complete(true);
      return true;
    } catch (error) {
      tomLog.error(
        "Starting two-phase database transaction of ${getParticipantId()} "
        "failed $error",
      );
      branch.xaId = null;
      await abandonStart(transaction, branch, existing);
      return false;
    }
  }

  /// Phase one: `PREPARE TRANSACTION`.
  ///
  /// A failure keeps the branch for [rollback], which the coordinator calls on
  /// every participant after a veto. PostgreSQL aborts the transaction when a
  /// `PREPARE TRANSACTION` fails, so that rollback then finds an ordinary
  /// transaction-less session and has only to clear the branch.
  @override
  Future<bool> prepare(TomTransaction transaction) async {
    final branch = branchOf(transaction);
    if (branch == null) return false;
    try {
      await lifecycle(transaction, "PREPARE TRANSACTION ${branch.xaId}");
      branch.ended = true;
      return true;
    } catch (error) {
      tomLog.error(
        "Preparing two-phase database transaction ${branch.xaId} of "
        "${getParticipantId()} failed $error",
      );
      return false;
    }
  }

  /// Phase two: `COMMIT PREPARED`. A failure leaves the branch in doubt, named
  /// in `pg_prepared_xacts`, for an operator to resolve.
  @override
  Future<bool> commit(TomTransaction transaction) async {
    final branch = branchOf(transaction);
    if (branch == null || branch.xaId == null) return false;
    final xaId = branch.xaId;
    try {
      await lifecycle(transaction, "COMMIT PREPARED $xaId");
      branch.xaId = null;
      branch.ended = false;
      return true;
    } catch (error) {
      tomLog.error(
        "Committing prepared database transaction $xaId of "
        "${getParticipantId()} failed $error — the branch is in doubt and is "
        "left in pg_prepared_xacts",
      );
      return false;
    }
  }

  /// `ROLLBACK` while the transaction is open, `ROLLBACK PREPARED` once it was
  /// prepared; nothing when no branch was opened or a commit cleared it.
  @override
  Future<bool> rollback(TomTransaction transaction) async {
    final branch = branchOf(transaction);
    final xaId = branch?.xaId;
    if (branch == null || xaId == null) return true;
    var undone = true;
    try {
      await lifecycle(
        transaction,
        branch.ended ? "ROLLBACK PREPARED $xaId" : "ROLLBACK",
      );
    } catch (error) {
      tomLog.error(
        "Rolling back two-phase database transaction of ${getParticipantId()} "
        "failed $error",
      );
      undone = false;
    } finally {
      branch.xaId = null;
      branch.ended = false;
      branch.active = false;
    }
    return undone;
  }
}

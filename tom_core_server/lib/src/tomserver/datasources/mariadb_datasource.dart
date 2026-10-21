import 'dart:async';
import 'dart:math';

import 'package:mysql_client/mysql_client.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../transactions/transaction_manager.dart';
import 'datasource_initialization.dart';
import 'mariadb_sql_dialect.dart';
import 'sql_datasource.dart';
import 'sql_dialects.dart';
import 'sql_failure_mode.dart';
import 'sql_placeholder_scan.dart';

/// Thrown for MariaDB data-source failures (connect, execute, result mapping).
class MariadbDatasourceException extends TomSqlDatasourceException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomSqlDatasourceException].
  MariadbDatasourceException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// Thrown when a MariaDB prepared statement failed with no live link to have
/// run on, signalling that a single reconnect-and-retry may recover it.
///
/// Which failures qualify is settled by `isLostConnectionFailure`.
class MariadbPreparedStatementException extends TomSqlConnectionLostException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomSqlConnectionLostException].
  MariadbPreparedStatementException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// A MariaDB-backed [TomPreparedStatement]; see [TomSqlPreparedStatement].
class MariadbPreparedStatement<T extends Object>
    extends TomSqlPreparedStatement<T> {
  /// A statement running [command] on [datasource], binding [parameterList]
  /// and mapping rows to [resultType].
  MariadbPreparedStatement(
    super.parameterList,
    MariaDbDatasource super.datasource,
    super.resultType,
    super.command, {
    super.groupedProjection,
  });

  /// Normalises a driver-reported last-insert id into a generated key: the
  /// driver reports `0` when a statement generated no AUTO_INCREMENT value
  /// (e.g. an `UPDATE`, or an `INSERT` into a table without one), and a real
  /// AUTO_INCREMENT value is never `0` — so `0` maps to `null` ("no generated
  /// key") and every other value passes through as an `int`.
  static int? normalizeGeneratedId(BigInt rawLastInsertId) =>
      rawLastInsertId == BigInt.zero ? null : rawLastInsertId.toInt();

  /// See [TomSqlPreparedStatement.buildPositionalParameters].
  static List<Object?> buildPositionalParameters(
    List<String> parameterList,
    Map<String, Object?>? params,
  ) => TomSqlPreparedStatement.buildPositionalParameters(parameterList, params);
}

/// One pooled MariaDB connection and the statements prepared on it.
class _MariaDbLink extends TomSqlLink {
  _MariaDbLink(this.connection);

  /// The driver connection.
  final MySQLConnection connection;

  /// Server-side prepared statements, by SQL text.
  final Map<String, PreparedStmt> statements = {};

  /// Statements to deallocate the next time the link is handed back — the ones
  /// forgotten while the link was lent or idle.
  final List<PreparedStmt> pendingDeallocation = [];

  @override
  bool get connected => connection.connected;

  /// The server-side statement for [command] on this link, prepared on first
  /// use.
  Future<PreparedStmt> statement(String command) async =>
      statements[command] ??= await connection.prepare(command);
}

/// A row of a MariaDB result, read as text.
class _MariaDbRow implements TomSqlRow {
  _MariaDbRow(this.row, {required this.binary});

  final ResultSetRow row;

  /// Whether the row arrived over the binary protocol (a prepared statement),
  /// whose temporal text [temporalText] has to repair.
  final bool binary;

  @override
  String? text(String column) => row.colByName(column);

  @override
  bool? boolean(String column) => row.typedColByName<bool>(column);

  /// Restores the six-digit fraction of a temporal value the driver rendered
  /// from the binary protocol.
  ///
  /// Over the binary protocol `mysql_client` builds a `DATETIME`'s text itself,
  /// and writes the microsecond field as a bare integer: 91 371 µs becomes
  /// `.91371`, which every parser reads as 0.91371 s. Over the text protocol the
  /// *server* formats the value, with exactly the column's precision, so the
  /// same digits there mean what they say — which is why the repair applies
  /// only to binary rows, and why it cannot be done from the text alone: a
  /// binary `.5` is 5 µs and a text `.5` from a `DATETIME(1)` is 500 000 µs.
  @override
  String? temporalText(String column) {
    final raw = row.typedColByName<String>(column);
    if (!binary || raw == null) return raw;
    final match = _binaryFraction.firstMatch(raw);
    if (match == null) return raw;
    return '${match.group(1)}.${match.group(2)!.padLeft(6, '0')}';
  }

  static final RegExp _binaryFraction = RegExp(
    r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.(\d{1,6})$',
  );
}

/// A MariaDB result, read from the driver's [IResultSet] only for what is
/// asked — a command's caller reads only [affectedRows].
class _MariaDbResult implements TomSqlResult {
  _MariaDbResult(this.result)
    // Over the binary protocol (a prepared statement) the driver renders a
    // temporal value's fraction wrongly; the rows carry which protocol they
    // came over so [_MariaDbRow.temporalText] can repair exactly those.
    : binary =
          result is PreparedStmtResultSet ||
          result is IterablePreparedStmtResultSet;

  final IResultSet result;
  final bool binary;

  @override
  late final List<String> columns = [for (final c in result.cols) c.name];

  @override
  late final List<TomSqlRow> rows = [
    for (final row in result.rows) _MariaDbRow(row, binary: binary),
  ];

  @override
  int get affectedRows => result.affectedRows.toInt();

  @override
  int? get generatedId =>
      MariadbPreparedStatement.normalizeGeneratedId(result.lastInsertID);

  @override
  bool hasColumn(String name) => columns.contains(name);
}

/// A MariaDB / MySQL [TomDataSource] driver (registered for the `"mariadb"`
/// type); see [TomSqlDatasource] for the connection, lifecycle and mapping
/// rules every SQL driver shares.
///
/// Transactions are plain `START TRANSACTION` / `COMMIT` / `ROLLBACK`;
/// [MariaDbXADatasource] is the two-phase variant.
@tomReflector
@TomDatasourceDriver("mariadb")
class MariaDbDatasource extends TomSqlDatasource {
  final MariadbSqlDialect _sqlDialect = MariadbSqlDialect();

  @override
  TomStandardSqlDialect get sqlDialect => _sqlDialect;

  /// A replica of this data source is a plain MariaDbDatasource — one-phase even
  /// behind an XA primary, since a replica only ever serves reads.
  @override
  TomSqlDatasource newReplica() => MariaDbDatasource();

  @override
  String get driverLabel => "MariadbDatasource";

  @override
  String get preparedStatementLabel => "MariadbPreparedStatement";

  @override
  String get participantPrefix => "MariaDb";

  @override
  MariadbDatasourceException datasourceException(
    String key,
    String message, {
    Map<String, dynamic>? parameters,
    StackTrace? stack,
    Object? rootException,
    bool autoLog = false,
  }) => MariadbDatasourceException(
    key,
    message,
    parameters: parameters,
    stack: stack,
    rootException: rootException,
    autoLog: autoLog,
  );

  @override
  MariadbPreparedStatementException connectionLostException(
    String key,
    String message, {
    Map<String, dynamic>? parameters,
    StackTrace? stack,
    Object? rootException,
  }) => MariadbPreparedStatementException(
    key,
    message,
    parameters: parameters,
    stack: stack,
    rootException: rootException,
  );

  /// Opens one new connection with the configured settings. The pool calls it
  /// whenever it needs a connection; a driver test overrides it to hand out
  /// stand-in connections.
  Future<MySQLConnection> openConnection() async {
    final opened = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: username,
      password: password,
      databaseName: (databaseName).isEmpty ? null : databaseName,
    );
    // `connect` completes only once the server has accepted the session, and
    // fails otherwise, so a connection it returns from is connected.
    await opened.connect(timeoutMs: timeOut);
    return opened;
  }

  @override
  Future<TomSqlLink> openLink() async => _MariaDbLink(await openConnection());

  @override
  Future<bool> tryLockOn(TomSqlLink link, String name) async {
    final result = await runCommandOn(
      link,
      'SELECT GET_LOCK(:name, 0) AS got',
      {'name': name},
    );
    return result.rows.single.text('got') == '1';
  }

  @override
  Future<void> unlockOn(TomSqlLink link, String name) async {
    await runCommandOn(link, 'SELECT RELEASE_LOCK(:name) AS released', {
      'name': name,
    });
  }

  @override
  Future<void> closeLink(TomSqlLink link) async {
    try {
      await (link as _MariaDbLink).connection.close();
    } catch (error) {
      tomLog.warn(
        "MariadbDatasource ${getParticipantId()}: closing a pooled "
        "connection failed: $error",
      );
    }
  }

  @override
  Future<bool> validateLink(TomSqlLink link) async {
    try {
      await (link as _MariaDbLink).connection.execute("SELECT 1");
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Runs [body] with a driver connection, chosen the way every statement's
  /// is: the running transaction's when this data source is enlisted in one,
  /// otherwise one lent for the call and handed back when [body] completes.
  ///
  /// For work that needs the driver's own API — its typed row accessors, or a
  /// session-scoped lock that must be taken and released on one connection.
  /// The connection must not be kept beyond [body].
  Future<R> withDriverConnection<R>(
    Future<R> Function(MySQLConnection connection) body,
  ) => withLink(
    "withDriverConnection",
    (link) => body((link as _MariaDbLink).connection),
  );

  @override
  Future<void> prepareOn(
    TomSqlLink link,
    String command,
    int parameterCount,
  ) async {
    // Nothing to bind and no rows to answer: [runPreparedOn] runs it over the
    // text protocol, and preparing it would hang — see there. Its errors
    // surface at the run.
    if (parameterCount == 0 && !_answersRows(command)) return;
    await (link as _MariaDbLink).statement(command);
  }

  @override
  Future<TomSqlResult> runPreparedOn(
    TomSqlLink link,
    String command,
    List<Object?> parameters,
  ) async {
    final mariaLink = link as _MariaDbLink;
    // A statement with neither parameters nor result columns — a DELETE or
    // UPDATE that binds nothing — is answered by the server with the
    // PREPARE_OK packet alone, and mysql_client waits for an EOF packet that
    // never comes. With nothing to bind, the text protocol runs the same
    // statement without the prepare step. A statement answering rows keeps
    // the prepared path: the server sends its column definitions, and the
    // binary protocol is what its temporal columns are read through.
    if (parameters.isEmpty && !_answersRows(command)) {
      return _resultOf(await mariaLink.connection.execute(command));
    }
    final stmt = await mariaLink.statement(command);
    return _resultOf(await stmt.execute(parameters));
  }

  @override
  Future<TomSqlResult> runCommandOn(
    TomSqlLink link,
    String command,
    Map<String, Object?>? params,
  ) async => _resultOf(
    await (link as _MariaDbLink).connection.execute(command, params),
  );

  @override
  void forgetStatementOn(TomSqlLink link, String command) {
    final mariaLink = link as _MariaDbLink;
    final stmt = mariaLink.statements.remove(command);
    if (stmt != null) mariaLink.pendingDeallocation.add(stmt);
  }

  @override
  Future<void> releaseForgottenOn(TomSqlLink link) async {
    final mariaLink = link as _MariaDbLink;
    if (mariaLink.pendingDeallocation.isEmpty) return;
    final pending = List.of(mariaLink.pendingDeallocation);
    mariaLink.pendingDeallocation.clear();
    for (final stmt in pending) {
      try {
        await stmt.deallocate();
      } catch (error) {
        tomLog.warn(
          "MariadbDatasource: deallocating a statement failed: $error",
        );
      }
    }
  }

  @override
  bool isLostConnection(Object error, TomSqlLink link) =>
      isLostConnectionFailure(error, connected: link.connected);

  @override
  String beginStatement({required bool readOnly}) =>
      readOnly ? "START TRANSACTION READ ONLY;" : "START TRANSACTION;";

  @override
  String get commitStatement => "COMMIT;";

  @override
  String get rollbackStatement => "ROLLBACK;";

  @override
  (String, List<String>) toPositional(String namedSql) =>
      toPositionalStatement(namedSql);

  /// Translates the generated `:name` [namedSql] into the positional `?` form
  /// the MySQL binary protocol binds, returning the rewritten SQL and the
  /// placeholder names in the exact left-to-right order the `?` slots appear.
  ///
  /// Delegates to the shared, quote-aware [SqlPlaceholderScan.toPositional] so
  /// the data source and the repository's name extraction stay in lock-step.
  static (String, List<String>) toPositionalStatement(String namedSql) =>
      SqlPlaceholderScan.toPositional(namedSql);

  /// [result] in the driver-neutral form the shared mapper reads.
  /// Whether [command] answers rows — a `SELECT`, `WITH`, `SHOW`, or a
  /// bracketed query — rather than only a count.
  static bool _answersRows(String command) {
    final head = command.trimLeft().toUpperCase();
    return head.startsWith('SELECT') ||
        head.startsWith('WITH') ||
        head.startsWith('SHOW') ||
        head.startsWith('(');
  }

  static TomSqlResult _resultOf(IResultSet result) => _MariaDbResult(result);

  /// Maps the driver's [qResult] onto a list of [T]; see
  /// [TomSqlDatasource.mapSqlResult].
  Future<List<T>> mapResultSet<T extends Object>(
    IResultSet qResult, [
    Type? resultType,
    Map<String, Type>? groupedProjection,
  ]) => mapSqlResult<T>(_resultOf(qResult), resultType, groupedProjection);

  @override
  TomSqlPreparedStatement<T> newPreparedStatement<T extends Object>(
    List<String> parameterList,
    Type? resultType,
    String command,
    Map<String, Type>? groupedProjection,
  ) => MariadbPreparedStatement<T>(
    parameterList,
    this,
    resultType,
    command,
    groupedProjection: groupedProjection,
  );

  @override
  void bindSettings(Map<String, dynamic> settings) =>
      tomReflectionInfo.setValues<MariaDbDatasource>(this, settings);

  @override
  Map<String, dynamic> normalizeSettings(Map<String, dynamic> settings) =>
      normalizeIntegerSettings(settings);

  @override
  int parseConfiguredPort(Object? raw) => parsePort(raw);

  /// Returns [settings] with every integer setting given as a string folded to
  /// an `int` (G-DB-3); see [TomSqlDatasource.integerSettings].
  static Map<String, dynamic> normalizeIntegerSettings(
    Map<String, dynamic> settings,
  ) {
    final folded = <String, dynamic>{};
    for (final key in TomSqlDatasource.integerSettings) {
      final raw = settings[key];
      if (raw is! String) continue;
      folded[key] = key == 'port' ? parsePort(raw) : _parseInteger(key, raw);
    }
    return folded.isEmpty
        ? settings
        : <String, dynamic>{...settings, ...folded};
  }

  /// Parses a configured port value into the `int` the driver binds (G-DB-3).
  ///
  /// Accepts an `int` verbatim or a `String` holding an integer literal;
  /// anything else (unparsable string, non-int/non-string, `null`) throws a
  /// [MariadbDatasourceException].
  static int parsePort(Object? raw) {
    if (raw is int) return raw;
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null) return parsed;
    }
    throw MariadbDatasourceException(
      "error.initialize.invalid_port",
      "MariadbDatasource: configured port '$raw' is not a valid integer.",
      parameters: {"port": raw},
    );
  }

  static int _parseInteger(String key, String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed != null) return parsed;
    throw MariadbDatasourceException(
      "error.initialize.invalid_integer",
      "MariadbDatasource: configured $key '$raw' is not a valid integer.",
      parameters: {"setting": key, "value": raw},
    );
  }
}

/// A MariaDB [TomDataSource] that uses **XA (distributed) transactions**
/// (registered for the `"mariadb_xa"` type).
///
/// It inherits all connection and execution behaviour from [MariaDbDatasource]
/// but overrides the transaction lifecycle to issue `XA START` / `XA END` +
/// `XA PREPARE` / `XA COMMIT` / `XA ROLLBACK` against a per-transaction branch
/// id, so this data source can take part in a two-phase commit across multiple
/// resources.
///
/// The lifecycle maps onto the coordinator's two phases exactly: [prepare]
/// issues `XA END` + `XA PREPARE`, [commit] issues `XA COMMIT`, [rollback]
/// issues `XA ROLLBACK` (preceded by `XA END` when the branch is still active),
/// and [endTransaction] has nothing to do. That is what makes this data source
/// able to keep the promise the phase asks for: a prepared branch commits.
///
/// The branch id doubles as the in-transaction guard: [startTransaction] throws
/// while one is set rather than opening a nested branch. **Every exit therefore
/// clears it except a failing [prepare]**, which hands it on to [rollback] —
/// a veto is answered by rolling every participant back, this one included, and
/// [rollback] needs the branch to name.
@tomReflector
@TomDatasourceDriver("mariadb_xa")
class MariaDbXADatasource extends MariaDbDatasource {
  /// The most bytes an XA `gtrid` may hold; `XA START` refuses a longer one.
  static const int maxBranchIdBytes = 64;

  /// Distinguishes this process's branches from another's on the same server.
  static final String _processTag = Random.secure()
      .nextInt(1 << 32)
      .toRadixString(16)
      .padLeft(8, '0');

  /// Distinguishes this process's branches from each other within a clock tick.
  static int _branchCounter = 0;

  String _newBranchId() => tomSqlBranchId(
    databaseName: databaseName,
    host: host,
    port: port,
    processTag: _processTag,
    counter: _branchCounter++,
    maxBytes: maxBranchIdBytes,
  );

  /// Opens an XA branch. A read-only [transaction] cannot be honoured here.
  ///
  /// `XA START` has no `READ ONLY` form in MariaDB or MySQL, so this data
  /// source cannot ask the server to refuse writes the way its one-phase
  /// sibling does. Reported rather than ignored: a deployment that declared
  /// `@TomTransactional(isReadOnly: true)` would otherwise believe the branch
  /// was protected.
  ///
  /// A branch tracks whether it has been `XA END`ed. `XA END` is legal exactly
  /// once, on an ACTIVE branch, and a rollback has to know which side of it the
  /// branch is on: `XA ROLLBACK` is refused on an ACTIVE branch, and `XA END`
  /// is refused on an IDLE or PREPARED one.
  @override
  Future<bool> startTransaction(TomTransaction transaction) async {
    final existing = branchOf(transaction);
    if (existing != null && existing.xaId != null) {
      refuseNestedTransaction(existing.xaId);
    }
    if (transaction.isReadOnly) {
      tomLog.warn(
        "${getParticipantId()} joined a read-only transaction, but XA has no "
        "read-only branch: writes on this connection are not prevented.",
      );
    }
    final branch = openBranch(transaction, existing)
      ..xaId = "'${_newBranchId()}'"
      ..ended = false;
    try {
      await lifecycle(transaction, "XA START ${branch.xaId};");
      branch.active = true;
      branch.started.complete(true);
      return true;
    } catch (error) {
      tomLog.error(
        "Starting XA database transaction of ${getParticipantId()} failed $error",
      );
      // The database never opened the branch, so its id is cleared. Keeping it
      // would refuse the transaction's every later start.
      branch.xaId = null;
      await abandonStart(transaction, branch, existing);
      return false;
    }
  }

  /// Phase one: `XA END` then `XA PREPARE` against this branch, as two calls.
  ///
  /// Two calls, not one command: the driver reads only the first reply of a
  /// multi-statement command, and a PREPARE's reply left on the wire is what a
  /// later `XA COMMIT` would then return on — before the server had committed.
  ///
  /// A failure here keeps the branch, and that is the opposite of every other
  /// exit. The coordinator answers a veto by rolling *every* participant back,
  /// this one included, and [rollback] needs the branch to name.
  @override
  Future<bool> prepare(TomTransaction transaction) async {
    final branch = branchOf(transaction);
    if (branch == null) return false;
    try {
      await lifecycle(transaction, "XA END ${branch.xaId};");
      branch.ended = true;
      await lifecycle(transaction, "XA PREPARE ${branch.xaId};");
      return true;
    } catch (error) {
      tomLog.error(
        "Preparing XA database transaction ${branch.xaId} of "
        "${getParticipantId()} failed $error",
      );
      return false;
    }
  }

  /// Phase two: `XA COMMIT` against the prepared branch.
  ///
  /// A failure is an in-doubt branch rather than a veto: peers have already
  /// committed. The branch is left set and prepared so that an operator — or a
  /// later `XA RECOVER` — has something to name.
  @override
  Future<bool> commit(TomTransaction transaction) async {
    final branch = branchOf(transaction);
    if (branch == null || branch.xaId == null) return false;
    final xaId = branch.xaId;
    try {
      await lifecycle(transaction, "XA COMMIT $xaId;");
      branch.xaId = null;
      branch.ended = false;
      return true;
    } catch (error) {
      tomLog.error(
        "Committing prepared XA database transaction $xaId of "
        "${getParticipantId()} failed $error — the branch is in doubt and is "
        "left for XA RECOVER",
      );
      return false;
    }
  }

  @override
  Future<bool> rollback(TomTransaction transaction) async {
    // A participant that never opened a branch, or whose branch a successful
    // commit already cleared, has nothing to undo; issuing the statement
    // anyway would send `XA ROLLBACK null`.
    final branch = branchOf(transaction);
    final xaId = branch?.xaId;
    if (branch == null || xaId == null) return true;
    var undone = true;
    try {
      // An ACTIVE branch has to be ended before it can be rolled back; an IDLE
      // or prepared one has already been ended and would refuse a second
      // `XA END`.
      if (!branch.ended) await lifecycle(transaction, "XA END $xaId;");
      await lifecycle(transaction, "XA ROLLBACK $xaId;");
    } catch (error) {
      tomLog.error(
        "Rolling back XA database transaction of ${getParticipantId()} failed $error",
      );
      // Reported as well as logged: a branch that would not roll back is still
      // there, holding its locks.
      undone = false;
    } finally {
      // Always clear the branch id — even on a failed rollback — so nothing
      // later names a branch this transaction has finished with.
      branch.xaId = null;
      branch.ended = false;
    }
    return undone;
  }
}

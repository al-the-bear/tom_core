// ignore_for_file: type_literal_in_constant_pattern
import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:mysql_client/mysql_client.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import '../object_persistence/grouped_query.dart';
import '../object_persistence/persistence_annotations.dart';
import '../object_persistence/query_sentence_compiler.dart';
import '../object_persistence/annotation_analyzer.dart';
import 'connection_pool.dart';
import 'sql_lexer.dart';
import '../transactions/transaction_manager.dart';

import 'mariadb_sql_dialect.dart';
import 'sql_dialects.dart';
import 'sql_failure_mode.dart';
import 'sql_instant.dart';
import 'sql_placeholder_scan.dart';
import 'datasource_initialization.dart';
import 'queries.dart';
import 'types_operator.dart';

/// Thrown for MariaDB data-source failures (connect, execute, result mapping).
class MariadbDatasourceException extends TomServerException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomServerException].
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
/// The type carries the whole signal: [MariadbPreparedStatement.execute]
/// catches this and nothing else, so raising it *is* the decision to retry.
/// Which failures qualify is settled by `isLostConnectionFailure`.
class MariadbPreparedStatementException extends TomServerException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomServerException].
  MariadbPreparedStatementException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// A MariaDB-backed [TomPreparedStatement]: the compiled [command], the ordered
/// [parameterList] its placeholders expect, the owning [datasource], and the
/// optional [resultType] used to map result rows.
///
/// The handle belongs to no connection. A server-side prepared statement lives
/// on one connection, while a pooled data source runs each execution on
/// whichever connection it is given — the transaction's, or one lent for the
/// statement — so every pooled connection prepares [command] the first time it
/// runs it and keeps the server-side statement for the next. That is what lets
/// a repository prepare a statement once and keep it for the life of the
/// process.
class MariadbPreparedStatement<T extends Object>
    extends TomPreparedStatement<T> {
  /// The data source that prepared and runs this statement.
  final MariaDbDatasource datasource;

  /// The placeholder names in positional order, mapping `params` to `?` slots.
  final List<String> parameterList;

  /// The type result rows are mapped to (defaults to `T`).
  final Type? resultType;

  /// The compiled SQL command, prepared on each connection that runs it.
  final String command;

  /// For a grouped query, the Dart type of each projected result column keyed
  /// by its alias; `null` for every other statement.
  ///
  /// A grouped row is not an entity — its shape comes from the query, not from
  /// a class — so the projection types travel with the statement instead of
  /// being read off reflected column metadata at mapping time.
  final Map<String, Type>? groupedProjection;

  int? _lastGeneratedId;

  int _lastAffectedRows = 0;

  /// The auto-increment key the most recent [execute] generated, taken from the
  /// insert's own result set (`0` from the driver means "no generated key" and
  /// surfaces here as `null`, since a real AUTO_INCREMENT value is never 0).
  @override
  int? get lastGeneratedId => _lastGeneratedId;

  /// The row count the most recent [execute] reported, taken from that
  /// execute's own result set. `0` until the statement has run.
  @override
  int get lastAffectedRows => _lastAffectedRows;

  /// A statement running [command] on [datasource], binding [parameterList]
  /// and mapping rows to [resultType].
  MariadbPreparedStatement(
    this.parameterList,
    this.datasource,
    this.resultType,
    this.command, {
    this.groupedProjection,
  });

  /// Records the per-execution metadata carried by an execute's [result]: the
  /// generated key and the affected-row count.
  ///
  /// Both are captured in one place so that the retry branch of [execute]
  /// cannot pick up one and forget the other.
  void _captureExecuteResult(IResultSet result) {
    _lastGeneratedId = normalizeGeneratedId(result.lastInsertID);
    _lastAffectedRows = result.affectedRows.toInt();
  }

  /// Normalises a driver-reported last-insert id into a generated key: the
  /// driver reports `0` when a statement generated no AUTO_INCREMENT value
  /// (e.g. an `UPDATE`, or an `INSERT` into a table without one), and a real
  /// AUTO_INCREMENT value is never `0` — so `0` maps to `null` ("no generated
  /// key") and every other value passes through as an `int`.
  static int? normalizeGeneratedId(BigInt rawLastInsertId) =>
      rawLastInsertId == BigInt.zero ? null : rawLastInsertId.toInt();

  /// Maps the named [params] onto the positional bind list its [parameterList]
  /// expects, in placeholder order.
  ///
  /// Values are taken **raw** — a Dart `null` stays `null` (so it binds SQL
  /// `NULL`), a `String` keeps its exact characters (no surrounding quotes), an
  /// `int`/`double`/`DateTime` keeps its native value. They must **not** be
  /// rendered through the SQL-literal renderer (`objectOp`), which would
  /// double-encode them over the binary protocol — a `null` would bind the text
  /// `"NULL"` and a string would carry literal quote characters.
  ///
  /// A [TomDbType] box is the one value that is *not* bound raw: it is the SQL
  /// representation a column's `toDbConverter` produces (e.g. an enum mapped to
  /// a `TomDbString`), and the driver only understands primitives. Binding the
  /// box directly would marshal it through its `toString()` —
  /// `"TomDbType TomDbString full"` — which the server rejects (an `ENUM`
  /// column truncates it to `''`, error 1265). Unwrapping the box to
  /// its primitive here keeps that kernel→driver translation at the single
  /// data-source boundary that owns it. Returns an empty list when [params] is
  /// `null`.
  static List<Object?> buildPositionalParameters(
    List<String> parameterList,
    Map<String, Object?>? params,
  ) {
    if (params == null) return const [];
    return [for (final p in parameterList) _toBindValue(params[p])];
  }

  /// Runs the statement and maps its rows.
  ///
  /// A connection that turns out to be gone is retried once, on another
  /// connection, when the statement runs outside a transaction: the failed
  /// connection is discarded and the pool lends a working one. Inside a
  /// transaction there is nothing to retry on — the transaction lived on the
  /// connection that was lost — so the failure is reported as
  /// `error.failed-to-execute.transaction_connection_lost`.
  @override
  Future<List<T>> execute([Map<String, Object?>? params]) async {
    final List<Object?> parameters = buildPositionalParameters(
      parameterList,
      params,
    );
    IResultSet result;
    try {
      result = await datasource._runPrepared(
        command,
        parameters,
        params,
        resultType,
      );
    } on MariadbPreparedStatementException catch (lost) {
      if (datasource._isInTransactionHere()) {
        throw MariadbDatasourceException(
          "error.failed-to-execute.transaction_connection_lost",
          "MariadbPreparedStatement: the connection of the running transaction "
              "was lost; the transaction cannot continue.",
          parameters: {...?params, "type": resultType},
          rootException: lost,
        );
      }
      result = await datasource._runPrepared(
        command,
        parameters,
        params,
        resultType,
      );
    }
    _captureExecuteResult(result);
    return datasource.mapResultSet<T>(result, resultType, groupedProjection);
  }

  /// Forgets the statement on every connection that prepared it.
  ///
  /// A connection in use keeps its server-side statement until it is handed
  /// back, so nothing is deallocated under a statement that is running.
  @override
  Future<void> deallocate() => datasource._forgetStatement(command);
}

/// One pooled MariaDB connection and the statements prepared on it.
class _MariaDbLink {
  _MariaDbLink(this.connection);

  /// The driver connection.
  final MySQLConnection connection;

  /// Server-side prepared statements, by SQL text.
  final Map<String, PreparedStmt> statements = {};

  /// Statements to deallocate the next time the link is handed back — the ones
  /// forgotten while the link was lent or idle.
  final List<PreparedStmt> pendingDeallocation = [];

  bool get connected => connection.connected;

  /// The server-side statement for [command] on this link, prepared on first
  /// use.
  Future<PreparedStmt> statement(String command) async =>
      statements[command] ??= await connection.prepare(command);
}

/// Tells the pool how to open, close and check a MariaDB connection.
class _MariaDbLinkFactory implements TomConnectionFactory<_MariaDbLink> {
  _MariaDbLinkFactory(this.datasource);

  final MariaDbDatasource datasource;

  @override
  Future<_MariaDbLink> open() async =>
      _MariaDbLink(await datasource.openConnection());

  @override
  Future<void> close(_MariaDbLink link) async {
    if (!link.connected) return;
    try {
      await link.connection.close();
    } catch (error) {
      tomLog.warn(
        "MariadbDatasource ${datasource.getParticipantId()}: closing a pooled "
        "connection failed: $error",
      );
    }
  }

  @override
  bool isUsable(_MariaDbLink link) => link.connected;

  @override
  Future<bool> validate(_MariaDbLink link) async {
    try {
      await link.connection.execute("SELECT 1");
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Marks the zone in which a data source issues one of a transaction's own
/// lifecycle statements (`START TRANSACTION`, `COMMIT`, the `XA` verbs).
class _LifecycleKey {
  const _LifecycleKey(this.datasource, this.transaction);
  final MariaDbDatasource datasource;
  final TomTransaction transaction;
}

/// One transaction's share of a data source: the pooled connection pinned to
/// it, and — for XA — the branch it opened.
class _Branch {
  /// The connection, acquired by the transaction's first statement and held
  /// until [MariaDbDatasource.endTransaction].
  Future<_MariaDbLink>? link;

  /// Completes with whether the transaction's start succeeded; a statement
  /// racing the start waits for it.
  Completer<bool> started = Completer<bool>();

  /// Whether the transaction is open on the connection: started, and not yet
  /// committed or rolled back. A second start is refused only while it is.
  bool active = false;

  /// The XA branch id, quoted; `null` on the plain driver.
  String? xaId;

  /// Whether the XA branch has been `XA END`ed.
  bool ended = false;
}

/// One association read that a mapped row still owes: the `@TomReference`
/// [column], the [owner] mirror that declares it, the [field] to fill, and the
/// [row] instance to fill it in.
///
/// A reference cannot be read while the row is being mapped, because its query
/// binds values from that same row — so the mapper collects these and drains
/// them once the row's own columns are set.
typedef _PendingReference = ({
  TomColumnInformation column,
  ClassMirror owner,
  VariableMirror field,
  InstanceMirror row,
});

/// Marshals one bind [value] into a driver primitive: a [TomDbType] box is
/// unwrapped to the Dart value it holds; a Dart `bool` becomes its MariaDB
/// integer encoding; a [TomZonedDate] becomes its `DATE` text and a
/// [TomZonedTime] its `TIME` text; any other [DateTime] becomes its UTC
/// `DATETIME(6)` text; every other value is bound as-is.
///
/// MariaDB has no native boolean type — `BOOLEAN` is an alias for
/// `TINYINT(1)` stored as `1`/`0`. The driver serializes a bound Dart `bool`
/// as the *string* `'true'`/`'false'`, which the server rejects for an
/// integer column ("Incorrect integer value: 'false'", error 1366).
/// Translating `bool`→`int` here keeps that kernel→driver mapping at the
/// single data-source boundary that already owns the [TomDbType] unwrap.
///
/// MariaDB has no zone-aware `DATETIME` either, and the driver serializes a
/// bound [DateTime] through its `toString()` — which for a UTC instant ends in
/// `Z`. The server rejects the suffix ("Incorrect datetime value:
/// '2000-01-01 00:00:00.000Z'", error 1292), so a `DateTime` must reach the
/// driver with no zone designator — `DateTime.utc(...)` is the ordinary case,
/// not an exotic one.
///
/// Rendered through [sqlInstant] rather than converted with `toLocal()`.
/// `toLocal()` also produces an acceptable suffix-less value and round-trips
/// on the node that wrote it, which is why it stood for a while — but what it
/// stores is *that node's wall clock*, so two servers of one cluster leave
/// different characters in the column for the same moment and each reads the
/// other's rows off by the difference in their offsets. [sqlInstant] writes
/// the instant, identically everywhere, and `TomDbDateTime.of` reads it back
/// as UTC. Callers keep whichever flag they like on their own `DateTime`;
/// only what reaches the driver is normalised.
Object? _toBindValue(Object? value) {
  final unwrapped = value is TomDbType ? value.get() : value;
  if (unwrapped is bool) return unwrapped ? 1 : 0;
  // The two kernel half-instants are tested first because both *are* a
  // `DateTime`, so the general arm below would claim them and bind a whole
  // instant into a column that holds half of one — a `DATE` gaining a time the
  // caller never named and, for a `TIME`, a datetime-shaped string the server
  // refuses outright. Which half a value means is decided by its type, exactly
  // as the dialect decides it for an inlined literal, and by the same three
  // renderers so the two routes cannot disagree.
  if (unwrapped is TomZonedDate) return sqlDate(unwrapped);
  if (unwrapped is TomZonedTime) return sqlTimeOfDay(unwrapped);
  if (unwrapped is DateTime) return sqlInstant(unwrapped);
  return unwrapped;
}

/// Marshals a whole named-parameter map through [_toBindValue].
///
/// Both statement paths need this and only one of them used to have it. The
/// prepared-statement path marshals positionally through
/// [MariadbPreparedStatement.buildPositionalParameters]; `executeQuery` and
/// `executeCommand` handed their map to the driver untouched, so a hand-written
/// store binding a `DateTime` or a `bool` got the driver's own encoding rather
/// than this one — a local wall-clock reading in a column read back as UTC, and
/// the string `'false'` in an integer column. That is why the scheduling, audit
/// and OAuth-state stores render every instant with `sqlInstant` before binding
/// it: they were routing around this hole rather than choosing to. Marshalling
/// here makes the boundary one boundary, whichever path a statement takes.
Map<String, dynamic>? _toBindParams(Map<String, dynamic>? params) =>
    params == null
    ? null
    : {
        for (final entry in params.entries)
          entry.key: _toBindValue(entry.value),
      };

/// A MariaDB / MySQL [TomDataSource] driver (registered for the `"mariadb"`
/// type).
///
/// Connection settings ([username], [password], [host], [port],
/// [databaseName], [timeOut]) and pool settings ([poolMaxSize], [poolMinIdle],
/// [poolAcquireTimeoutMs], [poolIdleTimeoutMs], [poolMaxLifetimeMs],
/// [poolValidateAfterIdleMs]) are filled from the configuration map by
/// reflection in [initialize], which then opens the data source. The driver
/// implements the full data-source surface — [prepareStatement], [executeQuery]
/// (with reflection-based row→object mapping), [executeCommand] — and
/// participates in transactions via plain `START TRANSACTION` / `COMMIT` /
/// `ROLLBACK` (see [MariaDbXADatasource] for the XA variant).
///
/// ## Connections
///
/// The data source holds a [TomConnectionPool] of connections, at most
/// [poolMaxSize] of them. **A transaction gets a connection of its own**: its
/// first statement on this data source takes one from the pool, every later
/// statement of the transaction runs on it, and [endTransaction] hands it back.
/// A statement outside any transaction borrows a connection for that statement
/// alone. So concurrent transactions run side by side, each on its own
/// connection, and wait only when all [poolMaxSize] are in use — for at most
/// [poolAcquireTimeoutMs], after which the statement fails with
/// `error.datasource.pool.acquire_timeout`.
///
/// ## Lifecycle
///
/// **A data source is opened explicitly, and never by the statement that wants
/// to run.** Opening it means either [initialize], which binds the settings and
/// opens, or setting the fields and calling [connect]. Opening creates the pool
/// and opens one connection, so a data source that cannot reach its database
/// fails when it is opened rather than on its first request. Every execution
/// entry point ([prepareStatement], [executeQuery], [executeCommand]) requires
/// an open data source and throws a [MariadbDatasourceException]
/// (`error.datasource.not_opened`) if it is reached before one exists.
///
/// Opening on demand is not offered because it could not work: the pool opens
/// connections with [host], [port] and the credentials, and until they are
/// configured it would dial `:-1` — turning "never opened" into "the database
/// is unreachable".
///
/// A connection that drops is replaced: the pool checks a connection before it
/// lends it, discards one that is down, and opens a new one.
///
/// [close] closes the pool **and lets go of it**, which puts the data source
/// back to not-open: a closed data source refuses statements exactly as one
/// that was never opened does, rather than being silently re-opened by the next
/// one to arrive. [isOperational] and [connected] report the current state, and
/// [toString] distinguishes the two ways of holding no pool — `closed` from
/// `never opened` — because they point at different faults.
@tomReflector
@TomDatasourceDriver("mariadb")
class MariaDbDatasource implements TomDataSource {
  final MariadbSqlDialect _sqlDialect = MariadbSqlDialect();

  @override
  TomStandardSqlDialect get sqlDialect => _sqlDialect;

  /// The connection user name.
  String username = "";

  /// The connection password.
  String password = "";

  /// The database host.
  String host = "";

  /// The database port (`-1` until configured).
  int port = -1;

  /// The schema / database name (empty selects no default schema).
  String databaseName = "";

  /// The connect timeout in milliseconds.
  int timeOut = 10000;

  /// The most connections the pool opens at once.
  int poolMaxSize = 10;

  /// How many idle connections the pool keeps open ahead of demand.
  int poolMinIdle = 0;

  /// How long a statement waits for a free connection, in milliseconds.
  int poolAcquireTimeoutMs = 30000;

  /// How long a connection may sit idle before it is closed, in milliseconds.
  int poolIdleTimeoutMs = 600000;

  /// How long a connection is used at all before it is replaced, in
  /// milliseconds.
  int poolMaxLifetimeMs = 1800000;

  /// How long a connection may sit idle and still be lent without a
  /// `SELECT 1` check, in milliseconds.
  int poolValidateAfterIdleMs = 30000;

  /// The pool settings the fields above describe.
  TomConnectionPoolSettings get poolSettings => TomConnectionPoolSettings(
    maxSize: poolMaxSize,
    minIdle: poolMinIdle,
    acquireTimeout: Duration(milliseconds: poolAcquireTimeoutMs),
    idleTimeout: Duration(milliseconds: poolIdleTimeoutMs),
    maxLifetime: Duration(milliseconds: poolMaxLifetimeMs),
    validateAfterIdle: Duration(milliseconds: poolValidateAfterIdleMs),
  );

  /// The pool (`null` until the data source is opened, and again once [close]
  /// has let go of it).
  TomConnectionPool<_MariaDbLink>? _pool;

  /// Whether [_pool] is `null` because [close] released it, rather than because
  /// the data source was never opened.
  bool _wasClosed = false;

  /// Whether the most recent attempt to open a connection failed.
  bool _lastOpenFailed = false;

  /// Opens the data source with the configured settings: creates the pool and
  /// opens its first connection.
  ///
  /// A server that cannot be reached or refuses the session fails the call
  /// with the driver's own error, and leaves the data source unopened. Calling
  /// it on an open data source does nothing.
  Future<void> connect() async {
    if (_pool != null) return;
    final pool = TomConnectionPool<_MariaDbLink>(
      _MariaDbLinkFactory(this),
      settings: poolSettings,
    );
    // The first connection is opened now so a misconfigured data source fails
    // here, where it was opened, and not on its first request.
    final first = await pool.acquire();
    await pool.release(first);
    _pool = pool;
  }

  /// Opens one new connection with the configured settings. The pool calls it
  /// whenever it needs a connection; a driver test overrides it to hand out
  /// stand-in connections.
  Future<MySQLConnection> openConnection() async {
    try {
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
      _lastOpenFailed = false;
      return opened;
    } catch (_) {
      _lastOpenFailed = true;
      rethrow;
    }
  }

  /// Whether the data source is open and at least one of its connections is
  /// established.
  bool get connected =>
      _pool != null && _pool!.connections.any((link) => link.connected);

  /// How many connections the pool holds, lent or idle; `0` when not open.
  int get openConnectionCount => _pool?.connections.length ?? 0;

  /// How many connections are lent out — to transactions or statements.
  int get lentConnectionCount => _pool?.lentCount ?? 0;

  /// Refuses [command] when it holds more than one statement.
  ///
  /// `mysql_client` completes a call on the first reply it reads and never
  /// checks whether more follow, so every reply after the first stays on the
  /// wire and is read by the *next* call on this connection — which is then
  /// answered by its predecessor's reply, and so on for the connection's life.
  /// Nothing reports it: a query comes back empty, an `XA COMMIT` returns
  /// before the server has committed, and an error in any statement after the
  /// first is never raised. So one call carries one statement, and the check
  /// runs before the connection is touched. A script is split first, with
  /// [TomSqlLexer.splitStatements] — which is what the migration adaptor does.
  ///
  /// A terminating `;`, and a `;` inside a literal, quoted identifier or
  /// comment, are not separators; the lexer is quote- and comment-aware.
  static void _refuseMultipleStatements(String command, String operation) {
    final statements = TomSqlLexer.splitStatements(command);
    if (statements.length <= 1) return;
    throw MariadbDatasourceException(
      "error.datasource.multiple_statements",
      "MariadbDatasource: $operation was given ${statements.length} "
          "statements in one call. The driver reads only the first reply, "
          "which would leave the rest to answer later calls on this "
          "connection; issue one statement per call.",
      parameters: {
        "operation": operation,
        "statements": statements.length,
        "command": command,
      },
    );
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
  ) => _withLink("withDriverConnection", (link) => body(link.connection));

  /// The pool, or the refusal for a data source that is not open.
  ///
  /// A `null` pool means the data source is not open — never opened, or
  /// closed — and that is refused rather than repaired. Opening a never-opened
  /// data source here could not even work: the settings arrive only from
  /// [initialize] or a direct assignment, so before either the pool would dial
  /// `:-1` — reporting an unreachable database where the truth is an
  /// unconfigured one. Re-opening a *closed* one could work, and that is
  /// precisely why it must not happen by accident: it would resurrect a data
  /// source the application deliberately let go.
  ///
  /// [operation] names the calling entry point and is carried in the thrown
  /// exception's parameters alongside the `state` that refused it, so a log
  /// identifies both which call ran too early and which of the two faults it
  /// met.
  TomConnectionPool<_MariaDbLink> _requirePool(String operation) {
    final pool = _pool;
    if (pool != null) return pool;
    throw MariadbDatasourceException(
      "error.datasource.not_opened",
      "MariadbDatasource: $operation needs an open data source, but this one "
          "${_wasClosed ? "has been closed" : "has never been opened"}. Call "
          "initialize() with the connection settings, or set them and call "
          "connect().",
      parameters: {
        "operation": operation,
        "state": _wasClosed ? "closed" : "never_opened",
      },
    );
  }

  /// Runs [body] on the connection [operation] belongs on.
  ///
  /// This is the one place connections are chosen, so every execution path
  /// observes the same rule:
  ///
  /// * a transaction's own lifecycle statement runs on the connection pinned
  ///   to that transaction, taking one from the pool if it has none yet;
  /// * a statement inside a running transaction enlists this data source in it
  ///   first, if it is not enlisted — that is what makes `@TomTransactional`
  ///   mean anything, since the pipeline cannot know which data sources an
  ///   endpoint will touch — and then runs on the transaction's connection;
  /// * any other statement borrows a connection for itself and hands it back,
  ///   discarding it if it went down while in use.
  Future<R> _withLink<R>(
    String operation,
    Future<R> Function(_MariaDbLink link) body,
  ) async {
    final pool = _requirePool(operation);
    final branch = await _branchForThisZone();
    if (branch != null) {
      return body(await _pinnedLink(pool, branch));
    }
    final link = await pool.acquire();
    var lost = false;
    try {
      return await body(link);
    } catch (_) {
      lost = !link.connected;
      rethrow;
    } finally {
      await _handBack(pool, link, discard: lost);
    }
  }

  /// The connection pinned to [branch], taking it from [pool] on first use.
  Future<_MariaDbLink> _pinnedLink(
    TomConnectionPool<_MariaDbLink> pool,
    _Branch branch,
  ) {
    final pinned = branch.link;
    if (pinned != null) return pinned;
    // A failed acquire leaves the branch without a connection, so the next
    // statement tries again rather than inheriting the failure.
    late final Future<_MariaDbLink> acquiring;
    acquiring = pool.acquire().catchError((Object error, StackTrace stack) {
      if (identical(branch.link, acquiring)) branch.link = null;
      Error.throwWithStackTrace(error, stack);
    });
    branch.link = acquiring;
    return acquiring;
  }

  /// Returns [link] to [pool], first deallocating the statements forgotten
  /// while it was out.
  Future<void> _handBack(
    TomConnectionPool<_MariaDbLink> pool,
    _MariaDbLink link, {
    bool discard = false,
  }) async {
    if (link.connected && link.pendingDeallocation.isNotEmpty) {
      final pending = List.of(link.pendingDeallocation);
      link.pendingDeallocation.clear();
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
    if (pool.isLent(link)) {
      await pool.release(link, discard: discard || !link.connected);
    }
  }

  /// The transaction branch statements in the current zone belong to, or
  /// `null` when they belong to none — enlisting this data source in the
  /// running transaction first if it is not enlisted yet.
  Future<_Branch?> _branchForThisZone() async {
    final key = Zone.current[_LifecycleKey];
    if (key is _LifecycleKey && identical(key.datasource, this)) {
      return _branches[key.transaction];
    }
    final current = TomTransactionManager.getCurrentTransaction();
    if (current == null || !current.isRunning) return null;
    final branch = _branches[current];
    if (branch != null) {
      // Another statement of this transaction is starting it; wait, and try
      // the enlistment again if that start failed.
      if (await branch.started.future) return branch;
      return _branchForThisZone();
    }
    await current.registerParticipant(this);
    return _branches[current];
  }

  /// Whether statements in the current zone run inside a transaction this data
  /// source is enlisted in.
  bool _isInTransactionHere() {
    final key = Zone.current[_LifecycleKey];
    if (key is _LifecycleKey && identical(key.datasource, this)) return true;
    final current = TomTransactionManager.getCurrentTransaction();
    return current != null && _branches.containsKey(current);
  }

  /// Runs the prepared [command] with [parameters] on the connection the zone
  /// selects, preparing it there on first use.
  Future<IResultSet> _runPrepared(
    String command,
    List<Object?> parameters,
    Map<String, Object?>? params,
    Type? resultType,
  ) => _withLink("prepared statement", (link) async {
    final stmt = await link.statement(command);
    return runChecked<IResultSet>(() async => await stmt.execute(parameters), (
      e,
      StackTrace s,
    ) {
      tomLog.warn("Error when executing SQL: $e");
      // The exception type this returns *is* the retry signal: the statement
      // catches MariadbPreparedStatementException and nothing else.
      if (isLostConnectionFailure(e, connected: link.connected)) {
        link.statements.remove(command);
        return MariadbPreparedStatementException(
          "error.failed-to-execute.connection_closed",
          "MariadbPreparedStatement: connection closed",
          parameters: {...?params, "type": resultType},
          rootException: e,
          stack: s,
        );
      }
      return MariadbDatasourceException(
        "error.failed-to-execute.exception",
        "MariadbPreparedStatement: execution with $params failed. $e",
        parameters: {
          ...?params,
          "type": resultType,
          "connected": link.connected,
        },
        rootException: e,
        stack: s,
      );
    });
  });

  /// Forgets the server-side statements for [command] on every connection.
  ///
  /// Each is deallocated when its connection is next handed back, so a
  /// statement is never deallocated under a connection someone is using.
  Future<void> _forgetStatement(String command) async {
    final pool = _pool;
    if (pool == null) return;
    for (final link in pool.connections) {
      final stmt = link.statements.remove(command);
      if (stmt != null) link.pendingDeallocation.add(stmt);
    }
  }

  @override
  Future<TomPreparedStatement<T>> prepareStatement<T extends Object>(
    TomQuery query, [
    Type? resultType,
  ]) async {
    _requirePool("prepareStatement");
    final (q, params) = toPositionalStatement(query.generateQuery(sqlDialect));
    // Prepared now, on the connection this zone selects, so a statement the
    // server cannot compile fails here rather than at its first execution.
    // Every other connection prepares it when it first runs it.
    await _withLink("prepareStatement", (link) => link.statement(q));
    return MariadbPreparedStatement<T>(
      params,
      this,
      resultType,
      q,
      groupedProjection: query is TomGroupedSelect
          ? query.projectionTypes
          : null,
    );
  }

  /// Translates the generated `:name` [namedSql] into the positional `?` form
  /// the MySQL binary protocol binds, returning the rewritten SQL and the
  /// placeholder names in the exact left-to-right order the `?` slots appear.
  ///
  /// Delegates to the shared, quote-aware [SqlPlaceholderScan.toPositional] so
  /// the datasource and [TomSqlDatasourceRepository]'s name extraction stay in
  /// lock-step. A whole-identifier scan in occurrence order — not a per-name
  /// `replaceAll(":$p", "?")` — is essential: `replaceAll` corrupts a
  /// placeholder that is a *prefix* of another (`:id` vs `:idx` → `?x`) and
  /// collapses a repeated name to a single slot, desynchronising every
  /// following bind value. The scan is also string-literal aware, so a
  /// `:name`-looking substring inside an inlined literal (`'x:y'`) is not
  /// mistaken for a slot.
  static (String, List<String>) toPositionalStatement(String namedSql) =>
      SqlPlaceholderScan.toPositional(namedSql);

  /// The `Type` literal for [X], including a nullable one.
  ///
  /// A nullable type cannot be written where a `Type` value is expected — there
  /// is no `double?` expression, and `case double?:` is not valid Dart — but it
  /// *can* be named through a type argument. This is the only way to obtain the
  /// `double?` / `String?` values that a nullable observable reports, and it
  /// exists solely to build [_nonNullableElementTypes].
  static Type _typeOf<X>() => X;

  /// Maps each nullable element type an observable can report onto the
  /// non-nullable type the row mapper dispatches on.
  ///
  /// `TomObject<T>.getType()` answers `T` exactly as declared, so a `TomNString`
  /// reports `String?` and a `TomNDouble` reports `double?`. Dispatching on that
  /// answer directly means a nullable member matches no case at all — and since
  /// the nullable observables are the ordinary choice for a column that can be
  /// `NULL`, that rejected most members of most result holders.
  ///
  /// Normalising once, here, is deliberate: the alternative — adding a nullable
  /// case beside every existing one — doubles each switch and has to be
  /// remembered again for every element type ever added.
  static final Map<Type, Type> _nonNullableElementTypes = {
    _typeOf<int?>(): int,
    _typeOf<double?>(): double,
    _typeOf<String?>(): String,
    _typeOf<bool?>(): bool,
    _typeOf<DateTime?>(): DateTime,
  };

  /// [type] with its nullability removed, or [type] unchanged if it has none.
  static Type _nonNullableElementType(Type type) =>
      _nonNullableElementTypes[type] ?? type;

  /// Populates one observable [member] of a [TomClass] row from [row].
  ///
  /// Both `TomClass` mapping variants land here. They differ only in how they
  /// find the column — the table-less one matches the member's own name, the
  /// annotated one takes the `@TomDbColumn` name — so everything after that
  /// point (which element types are supported, how each is read, how an
  /// unsupported one is reported) is one decision, made once. They were
  /// previously two copies of that decision, and the nullable-member defect
  /// this method was extracted to fix was present in both.
  ///
  /// [field] is the result-column name to read; [memberName] and [errorCode]
  /// only shape the failure, which stays distinguishable per variant.
  ///
  /// A `NULL` column yields `null` for every element type, including
  /// `DateTime`. The `DateTime` branch used to skip the assignment instead,
  /// which left the member holding whatever its field initialiser had put
  /// there — a stale value presented as if it had been read.
  ///
  /// A `DateTime` is read through [parseOptionalSqlInstant], the reading half
  /// of the instant convention this data source writes through (`sqlInstant`;
  /// see `sql_instant.dart`). A bare `DateTime.parse` would read the column as
  /// *this node's* local time, which is not the moment the writing node stored.
  static void _setObservableMember(
    ResultSetRow row,
    TomObject member,
    String field, {
    required String memberName,
    required String errorCode,
    required ClassMirror classMirror,
  }) {
    final Type declared = member.getType();
    switch (_nonNullableElementType(declared)) {
      case int:
        member.set(_readInt(row, field));
      case double:
        member.set(_readDouble(row, field));
      case String:
        member.set(row.typedColByName<String>(field));
      case bool:
        member.set(row.typedColByName<bool>(field));
      case DateTime:
        member.set(_readInstant(row, field));
      default:
        throw MariadbDatasourceException(
          errorCode,
          "Unexpected and unsupported type for TomObject value: $declared for "
          "member $memberName in $classMirror",
          parameters: {
            "type": classMirror.reflectedType,
            "fieldType": declared,
            "attribute": memberName,
          },
        );
    }
  }

  /// Reads [field] as a UTC instant through [parseOptionalSqlInstant].
  ///
  /// The row-mapping face of [_readTemporal] for the paths that set a plain
  /// `DateTime` rather than a [TomDbDateTime] box.
  static DateTime? _readInstant(ResultSetRow row, String field) =>
      _readTemporal(row, field, TomDbDateTime.of).get();

  /// Reads [field]'s text through [read] — one of the `TomDbDateTime`,
  /// `TomDbDate` and `TomDbTime` `of` factories — and refuses what it cannot.
  ///
  /// Those factories parse with the public `parseSql…` functions, which keep
  /// Dart's parse contract and throw a [FormatException]. That is the right
  /// answer for a caller parsing text it chose; a stored row is not that. It is
  /// data from outside the process, so an unreadable value is a failure of the
  /// read, and it is reported the way the numeric readers report theirs —
  /// keyed, naming the column and the value, with the parser's exception as the
  /// root. Unconverted, the `FormatException` crossed the endpoints pipeline
  /// unclassified: no key, no `clientThrow`, no column.
  ///
  /// The key names what the column failed to be: `not_a_date` for a `DATE`
  /// holding a timestamp, `not_a_time` for a `TIME` holding an interval,
  /// `not_an_instant` for a `DATETIME` holding neither.
  static B _readTemporal<B extends TomDbType>(
    ResultSetRow row,
    String field,
    B Function(String?) read,
  ) {
    final raw = row.typedColByName<String>(field);
    final text = _binaryRows[row] == true
        ? _repairBinaryTemporalText(raw)
        : raw;
    try {
      return read(text);
    } on FormatException catch (error, stack) {
      final (key, kind) = switch (B) {
        const (TomDbDate) => ('not_a_date', 'a date'),
        const (TomDbTime) => ('not_a_time', 'a time of day'),
        _ => ('not_an_instant', 'an instant'),
      };
      throw MariadbDatasourceException(
        "error.result_processing.$key",
        "Column '$field' holds '$text', which is not readable as $kind",
        parameters: {"attribute": field, "value": text},
        rootException: error,
        stack: stack,
      );
    }
  }

  /// The rows [_rowsOf] handed out from a prepared statement's result, which
  /// arrived over MySQL's binary protocol. Keyed by the row object itself, so
  /// the mark lives exactly as long as the row and costs nothing to clear.
  static final Expando<bool> _binaryRows = Expando<bool>('binary protocol row');

  /// The rows of [result], each marked when [result] came over the binary
  /// protocol, so the temporal readers can repair what the driver renders
  /// there (see [_repairBinaryTemporalText]).
  ///
  /// Every loop that maps a row goes through this rather than `result.rows`:
  /// a row read without the mark is read as text-protocol text, and for a
  /// binary row that is the defect this exists to prevent.
  static Iterable<ResultSetRow> _rowsOf(IResultSet result) sync* {
    final binary =
        result is PreparedStmtResultSet ||
        result is IterablePreparedStmtResultSet;
    for (final row in result.rows) {
      if (binary) _binaryRows[row] = true;
      yield row;
    }
  }

  /// Restores the six-digit fraction of a temporal value the driver rendered
  /// from the binary protocol.
  ///
  /// Over the binary protocol `mysql_client` builds a `DATETIME`'s text itself,
  /// and writes the microsecond field as a bare integer: 91 371 µs becomes
  /// `.91371`, which every parser reads as 0.91371 s. So every instant whose
  /// fraction is under a tenth of a second came back up to 0.9 s late — one
  /// value in ten, with nothing failing. Over the text protocol the *server*
  /// formats the value, with exactly the column's precision, so the same
  /// digits there mean what they say; that is why the repair applies only to
  /// rows [_rowsOf] marked, and why it cannot be done from the text alone: a
  /// binary `.5` is 5 µs and a text `.5` from a `DATETIME(1)` is 500 000 µs.
  ///
  /// Anything that is not `<date> <time>.<digits>` is returned unchanged,
  /// `null` included.
  static String? _repairBinaryTemporalText(String? text) {
    if (text == null) return null;
    final match = _binaryFraction.firstMatch(text);
    if (match == null) return text;
    return '${match.group(1)}.${match.group(2)!.padLeft(6, '0')}';
  }

  static final RegExp _binaryFraction = RegExp(
    r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.(\d{1,6})$',
  );

  /// Reads [field] from [row] as a Dart `double`.
  ///
  /// **This is the only place that knows how this driver yields a double**, and
  /// it exists because `typedColByName<double>` cannot be trusted to widen.
  /// `mysql_client` converts a column to `double` only from a fixed whitelist of
  /// protocol types — TINY, SHORT, LONG, LONGLONG, INT24, FLOAT, DOUBLE
  /// (`mysql_column_type.dart`). `DECIMAL`/`NEWDECIMAL` (246) is in neither that
  /// list nor the `int` one, so asking the driver for a `double` there *throws*
  /// `MySQLProtocolException` instead of widening.
  ///
  /// That matters far beyond aggregates. `DECIMAL` is the correct SQL type for
  /// money — exact where `DOUBLE` is approximate — so an ordinary business
  /// entity hits this on its first select. `SUM`/`AVG` over an integer column
  /// return `NEWDECIMAL` too, so an aggregate reaches it even where no column
  /// is declared `DECIMAL` at all.
  ///
  /// Reading the raw text and parsing it here loses nothing: the driver's own
  /// conversion starts from exactly this text (the whitelist is a gate, not a
  /// decoder), and it reports `DECIMAL` as best-matching Dart `String`. The
  /// exact text form ("1234.56", "43.0000") parses losslessly.
  static double? _readDouble(ResultSetRow row, String field) {
    final text = row.colByName(field);
    if (text == null) {
      return null;
    }
    final value = double.tryParse(text);
    if (value == null) {
      throw MariadbDatasourceException(
        "error.result_processing.not_a_double",
        "Column '$field' holds '$text', which is not readable as a double",
        parameters: {"attribute": field, "value": text},
      );
    }
    return value;
  }

  /// Reads [field] from [row] as a Dart `int`.
  ///
  /// The `int` whitelist has the same `NEWDECIMAL` gap as the `double` one, and
  /// an `int`-declared field over a `DECIMAL` column is not automatically a
  /// modelling error: `DECIMAL(n,0)` *is* an exact integer type, and wide
  /// identifiers and counters are routinely declared that way. Rejecting the
  /// read for being `DECIMAL` would therefore break a legitimate mapping.
  ///
  /// What must not happen is a silent truncation. Reading `DECIMAL(10,2)` into
  /// an `int` and quietly dropping the cents turns a modelling mistake into
  /// wrong money that no test would notice, so this **encodes the decision**
  /// rather than leaving it to the driver: an exact integral value is read, and
  /// a value with a fractional part is refused by name. Neither outcome is the
  /// driver's raw `MySQLProtocolException`, which said only that a conversion
  /// was unavailable and never which column it was reading.
  static int? _readInt(ResultSetRow row, String field) {
    final text = row.colByName(field);
    if (text == null) {
      return null;
    }
    final direct = int.tryParse(text);
    if (direct != null) {
      return direct;
    }
    final asDouble = double.tryParse(text);
    if (asDouble == null) {
      throw MariadbDatasourceException(
        "error.result_processing.not_an_int",
        "Column '$field' holds '$text', which is not readable as an int",
        parameters: {"attribute": field, "value": text},
      );
    }
    if (asDouble != asDouble.truncateToDouble()) {
      throw MariadbDatasourceException(
        "error.result_processing.fractional_int",
        "Column '$field' holds the fractional value '$text' but is mapped to "
            "an int. Reading it would silently discard the fraction; declare "
            "the field as a double, or the column as an integer type.",
        parameters: {"attribute": field, "value": text},
      );
    }
    return asDouble.toInt();
  }

  /// Maps one driver [row] of a grouped result into a [TomGroupedRow], reading
  /// each alias in [projection] as the Dart type the query declared for it.
  ///
  /// The projection is the only type information available: a grouped row has
  /// no entity class and no persistent-column metadata, so the query's own
  /// declaration of "this alias is an `int`" is what makes the read typed.
  static TomGroupedRow mapGroupedRow(
    ResultSetRow row,
    Map<String, Type> projection,
  ) {
    final values = <String, Object?>{};
    for (final entry in projection.entries) {
      final alias = entry.key;
      switch (entry.value) {
        case int:
          values[alias] = _readInt(row, alias);
        case double:
          values[alias] = _readDouble(row, alias);
        case String:
          values[alias] = row.typedColByName<String>(alias);
        case bool:
          values[alias] = row.typedColByName<bool>(alias);
        case DateTime:
          values[alias] = _readInstant(row, alias);
        default:
          throw MariadbDatasourceException(
            "error.result_processing_grouped.unknown_type",
            "Unexpected and unsupported type for grouped result column "
                "'$alias': ${entry.value}",
            parameters: {"alias": alias, "fieldType": entry.value},
          );
      }
    }
    return TomGroupedRow(values);
  }

  @override
  Future<List<T>> executeQuery<T extends Object>(
    String command, [
    Map<String, dynamic>? params,
    Type? resultType,
  ]) async {
    tomLog.trace("MariaDbDatasourceExecuting SQL: $T $resultType $command");
    _refuseMultipleStatements(command, "executeQuery");
    // The rows are mapped after the connection is handed back: mapping a
    // `@TomReference` column runs a query of its own, which must not need a
    // second connection while this one is still held.
    final IResultSet qResult = await _withLink(
      "executeQuery",
      (link) => runChecked<IResultSet>(
        () async =>
            await link.connection.execute(command, _toBindParams(params)),
        (e, StackTrace s) {
          tomLog.warn("Error when executing SQL: $e");
          return MariadbDatasourceException(
            "error.failed-to-execute.exception",
            "MariadbDatasource: execution of $command with $params failed. $e",
            parameters: {...?params, "command": command, "type": resultType},
            rootException: e,
            stack: s,
          );
        },
      ),
    );
    return mapResultSet<T>(qResult, resultType);
  }

  /// Maps the driver's [qResult] onto a list of [T], choosing between the five
  /// row shapes this driver understands.
  ///
  /// This is the module's central decision, and which branch a result takes is
  /// determined entirely by what [resultType] (or [T]) declares:
  ///
  /// 1. a **grouped row**, when [groupedProjection] is non-null — there is no
  ///    class to reflect, so the query's own projection supplies the types;
  /// 2. a **table-less [TomClass]**, bound by observable member name;
  /// 3. an **annotated [TomClass]**, bound by `@TomDbColumn` name;
  /// 4. a **plain reflected holder** with no `@TomDbTable`, bound by declared
  ///    field name — the shape an aggregate query lands on;
  /// 5. an **annotated entity**, bound by its persistent column list.
  ///
  /// It is public, and takes the driver's result set rather than a connection,
  /// because nothing here needs a server: every branch reads column *text* the
  /// protocol has already decoded. Only a `@TomReference` column reaches back
  /// to the database, and only after a row's own columns are set. Keeping the
  /// mapping reachable without a live server is what lets the row-shape
  /// decision be tested in the ordinary run rather than only in the `db`-tagged
  /// one.
  Future<List<T>> mapResultSet<T extends Object>(
    IResultSet qResult, [
    Type? resultType,
    Map<String, Type>? groupedProjection,
  ]) async {
    Type rType = resultType ?? T;
    // A grouped query's rows carry group keys and aggregate values under the
    // aliases the query projected them as. There is no class to reflect — the
    // shape belongs to the query — so this path runs first, before any mirror
    // is taken, and maps straight into a TomGroupedRow using the projection
    // types the statement carries.
    if (groupedProjection != null) {
      return [
        for (final row in _rowsOf(qResult))
          mapGroupedRow(row, groupedProjection) as T,
      ];
    }
    // The one shape this driver cannot map: a result type the reflector does
    // not hold. Every branch below reaches the class through a mirror, so the
    // refusal belongs here, at the step that needs the mirror. It has no home
    // after the branches: between them they accept every reflected type, so a
    // final `else` there is a case no result can reach.
    final TypeMirror typeMirror;
    try {
      typeMirror = tomReflector.reflectType(rType);
    } on NoSuchCapabilityError catch (error, stack) {
      throw MariadbDatasourceException(
        "error.result_processing.unsuitable_class",
        "Class $rType cannot be used for automatic processing of result sets. "
            "It must be marked @tomReflector, and be either a TomClass or "
            "carry persistence annotations.",
        parameters: {"type": "$rType"},
        rootException: error,
        stack: stack,
      );
    }
    if (typeMirror is! ClassMirror) {
      throw MariadbDatasourceException(
        "error.result_processing.unsuitable_class",
        "$rType is registered with tomReflector but is not a class "
            "(${typeMirror.runtimeType}), so no result row can be mapped onto "
            "it.",
        parameters: {"type": "$rType"},
      );
    }
    final ClassMirror classMirror = typeMirror;
    List<T> result = [];
    Object testObject = classMirror.newInstance("", []);
    if (testObject is TomClass &&
        TomAnnotationAnalyzer.findTable(rType) == null) {
      // if this not an annotated TomClass
      for (var row in _rowsOf(qResult)) {
        TomClass rowResult;
        try {
          rowResult = classMirror.newInstance("", []) as TomClass;
        } catch (exception) {
          throw MariadbDatasourceException(
            "error.result_processing_tcp.failed_to_instantiate_row",
            "Failed to instantiate result row instance of type ${classMirror.reflectedType}, error: $exception",
            parameters: {"type": classMirror.reflectedType},
          );
        }
        for (var entry in rowResult.getMembers().entries) {
          if (qResult.cols.any((c) => c.name == entry.key)) {
            // Table-less: the member's own name *is* the column name.
            _setObservableMember(
              row,
              entry.value,
              entry.key,
              memberName: entry.key,
              errorCode: "error.result_processing_tcp.unknown_type",
              classMirror: classMirror,
            );
          }
        }
        result.add(rowResult as T);
      }
    } else if (testObject is TomClass) {
      for (var row in _rowsOf(qResult)) {
        TomClass rowResult;
        try {
          rowResult = classMirror.newInstance("", []) as TomClass;
        } catch (exception) {
          throw MariadbDatasourceException(
            "error.result_processing_tc.failed_to_instantiate_row",
            "Failed to instantiate result row instance of type ${classMirror.reflectedType}, error: $exception",
            parameters: {"type": classMirror.reflectedType},
          );
        }
        // Reached only when the branch above found a @TomDbTable, so this is a
        // mapped entity: analysePersistentType resolves it from the same memos
        // and reports a type that is not, rather than asserting it away.
        for (var col in TomAnnotationAnalyzer.analysePersistentType(
          rType,
        ).columnInfo) {
          if (qResult.cols.any((c) => c.name == col.field)) {
            // Annotated: the column name comes from `@TomDbColumn`, so it may
            // differ from the member's declared name.
            _setObservableMember(
              row,
              rowResult.getMembers()[col.declaredName]!,
              col.field,
              memberName: col.declaredName,
              errorCode: "error.result_processing_tc.unknown_type",
              classMirror: classMirror,
            );
          }
        }
        result.add(rowResult as T);
      }
    } else if (TomAnnotationAnalyzer.findTable(rType) == null) {
      // A plain reflected result holder with no @TomDbTable (e.g.
      // TomCountResult). It cannot be mapped by *persistent columns* — those
      // require a table — so map it by plain field name, the direct analogue of
      // the by-member-name path taken above for a table-less TomClass. Each
      // reflected instance field whose declared name matches a result column is
      // populated through its reflection setter.
      for (var row in _rowsOf(qResult)) {
        Object rowResult;
        try {
          rowResult = classMirror.newInstance("", []);
        } catch (exception) {
          throw MariadbDatasourceException(
            "error.result_processing_field.failed_to_instantiate_row",
            "Failed to instantiate result row instance of type ${classMirror.reflectedType}, error: $exception",
            parameters: {"type": classMirror.reflectedType},
          );
        }
        InstanceMirror im = tomReflector.reflect(rowResult);
        for (var dEntry in classMirror.declarations.entries) {
          if (dEntry.value is! VariableMirror) {
            continue;
          }
          final VariableMirror dm = dEntry.value as VariableMirror;
          final String fieldName = dEntry.key;
          if (!qResult.cols.any((c) => c.name == fieldName)) {
            continue;
          }
          switch (dm.reflectedType) {
            case int:
              im.invokeSetter(dm.simpleName, _readInt(row, fieldName));
            case double:
              im.invokeSetter(dm.simpleName, _readDouble(row, fieldName));
            case String:
              im.invokeSetter(
                dm.simpleName,
                row.typedColByName<String>(fieldName),
              );
            case bool:
              im.invokeSetter(
                dm.simpleName,
                row.typedColByName<bool>(fieldName),
              );
            // Read through the instant convention (`sql_instant.dart`), and set
            // unconditionally like every branch above it: a bare
            // `DateTime.parse` would read the column as this node's local time,
            // and skipping the assignment on `NULL` would leave the field
            // holding its initialiser value, presented as if it had been read.
            case DateTime:
              im.invokeSetter(dm.simpleName, _readInstant(row, fieldName));
            default:
              throw MariadbDatasourceException(
                "error.result_processing_field.unknown_type",
                "Unexpected and unsupported type for result field value: ${dm.reflectedType} for member ${dm.simpleName} in $classMirror",
                parameters: {
                  "type": classMirror.reflectedType,
                  "fieldType": dm.reflectedType,
                  "attribute": dm.simpleName,
                },
              );
          }
        }
        result.add(rowResult as T);
      }
    } else {
      // The annotated entity: reflectable (the mirror above) and carrying a
      // @TomDbTable (every branch before this one ruled its absence out), so
      // analysePersistentType resolves it — and names the type if it somehow
      // cannot, rather than answering a null this branch would have to assert
      // away.
      final persistentColumns = TomAnnotationAnalyzer.analysePersistentType(
        rType,
      ).columnInfo;
      for (var row in _rowsOf(qResult)) {
        // Per row: the stack is drained at the end of this iteration, so a
        // stack that outlived it would re-resolve every earlier row's
        // references once more for each row that follows.
        final refStack = <_PendingReference>[];
        Object rowResult;
        try {
          rowResult = classMirror.newInstance("", []);
        } catch (exception) {
          throw MariadbDatasourceException(
            "error.result_processing.failed_to_instantiate_row",
            "Failed to instantiate result row instance of type ${classMirror.reflectedType}, error: $exception",
            parameters: {"type": classMirror.reflectedType},
          );
        }
        InstanceMirror im = tomReflector.reflect(rowResult);
        for (var col in persistentColumns) {
          VariableMirror dm =
              classMirror.declarations[col.declaredName] as VariableMirror;
          if (col.reference != null) {
            // Deferred: the reference query binds values from this row, so it
            // can only run once every other field has been set.
            refStack.add((column: col, owner: classMirror, field: dm, row: im));
            continue;
          }
          // A column the result does not carry is skipped, as it is on all four
          // shapes above. A projection that selects a subset of an entity's
          // columns is an ordinary query; reading a column that is not there
          // reaches the driver instead, which answers with a
          // MySQLClientException — outside this module's exception family, and
          // naming a column rather than the query that failed to select it.
          if (!qResult.cols.any((c) => c.name == col.field)) {
            continue;
          }
          switch (dm.reflectedType) {
            case int:
              im.invokeSetter(dm.simpleName, _readInt(row, col.field));
            case double:
              im.invokeSetter(dm.simpleName, _readDouble(row, col.field));
            case String:
              im.invokeSetter(
                dm.simpleName,
                row.typedColByName<String>(col.field),
              );
            case bool:
              im.invokeSetter(
                dm.simpleName,
                row.typedColByName<bool>(col.field),
              );
            // As above: the instant convention on the read side, and an
            // unconditional set so a `NULL` column clears the field rather than
            // leaving its initialiser value in place.
            case DateTime:
              im.invokeSetter(dm.simpleName, _readInstant(row, col.field));
            // The two halves a timestamp splits into. Both are `DateTime`
            // subclasses, so neither reaches the case above — a switch on
            // `reflectedType` matches the declared type exactly — and without
            // their own cases an entity declaring either field could be written
            // and never read: the row fell through to `unknown_type`.
            //
            // Read through the same pair of functions the renderers are the
            // other half of, so the column text a `DATE` or `TIME` holds and the
            // text this expects cannot drift apart.
            case TomZonedDate:
              im.invokeSetter(
                dm.simpleName,
                _readTemporal(row, col.field, TomDbDate.of).get(),
              );
            case TomZonedTime:
              im.invokeSetter(
                dm.simpleName,
                _readTemporal(row, col.field, TomDbTime.of).get(),
              );
            default:
              if (col.column != null) {
                if (col.column!.fromDbConverter != null) {
                  try {
                    Object? value = col.column!.fromDbConverter!(
                      _getColumnValue(row, col.field, col.column!.columnType),
                    );
                    im.invokeSetter(dm.simpleName, value);
                    continue;
                  } catch (e, s) {
                    throw MariadbDatasourceException(
                      "error.result_processing.failed_custom_conversion",
                      "Conversion using provided converter failed: ${dm.reflectedType} for member ${dm.simpleName} in $classMirror: $e",
                      parameters: {
                        "type": classMirror.reflectedType,
                        "attribute": col.declaredName,
                        "attributeType": dm.reflectedType,
                        "value": row.colByName(col.field),
                        "converter": col.column!.fromDbConverter,
                      },
                      stack: s,
                      rootException: e,
                    );
                  }
                }
                Type t = col.column!.dartType ?? dm.reflectedType;
                if (col.column!.isJson && tomReflector.canReflectType(t)) {
                  try {
                    String? stringValue = row.typedColByName<String>(col.field);
                    if (stringValue != null) {
                      ClassMirror valueMirror =
                          tomReflector.reflectType(t) as ClassMirror;
                      Object? value = tomReflectionInfo
                          .createInstanceFromJsonString(
                            valueMirror,
                            stringValue,
                          );
                      im.invokeSetter(dm.simpleName, value);
                    } else {
                      im.invokeSetter(dm.simpleName, null);
                    }
                    continue;
                  } catch (e, s) {
                    throw MariadbDatasourceException(
                      "error.result_processing.failed_json_conversion",
                      "Conversion from json failed: ${dm.reflectedType} for member ${dm.simpleName} in $classMirror: $e",
                      parameters: {
                        "type": classMirror.reflectedType,
                        "attribute": col.declaredName,
                        "attributeType": dm.reflectedType,
                        "json": row.typedColByName<String>(col.field),
                      },
                      stack: s,
                      rootException: e,
                    );
                  }
                }
              }
              throw MariadbDatasourceException(
                "error.result_processing.unknown_type",
                "Unexpected and unsupported type for TomObject value: ${dm.reflectedType} for member ${dm.simpleName} in $classMirror",
                parameters: {
                  "type": classMirror.reflectedType,
                  "attribute": col.declaredName,
                  "attributeType": dm.reflectedType,
                },
              );
          }
        }
        if (refStack.isNotEmpty) {
          await _loadReferencedValues(refStack);
        }
        result.add(rowResult as T);
      }
    }
    return result;
  }

  TomDbType _getColumnValue(ResultSetRow row, String field, Type? colType) {
    if (colType == null || colType == TomDbString) {
      return TomDbString.of(row.typedColByName<String>(field));
    } else if (colType == TomDbInt) {
      return TomDbInt(_readInt(row, field));
    } else if (colType == TomDbDouble) {
      return TomDbDouble(_readDouble(row, field));
    } else if (colType == TomDbBool) {
      return TomDbBool(row.typedColByName<bool>(field));
    } else if (colType == TomDbDateTime) {
      return _readTemporal(row, field, TomDbDateTime.of);
    } else if (colType == TomDbDate) {
      return _readTemporal(row, field, TomDbDate.of);
    } else if (colType == TomDbTime) {
      return _readTemporal(row, field, TomDbTime.of);
    }
    throw MariadbDatasourceException(
      "error.result_processing.unknown_type_dbtype_conversion",
      "Unexpected and unsupported col type $colType for $field",
      parameters: {"type": colType, "attribute": field},
    );
  }

  /// Fills each pending association in [refStack] by running its reference
  /// query and writing the results into the row that owes it.
  ///
  /// This is the whole implementation of `@TomReference`: [mapResultSet]
  /// cannot read an association while mapping a row — the query binds values
  /// from that same row — so it stacks the reference columns and calls this
  /// once the row's own columns are set.
  ///
  /// The sentence and its parameters come from
  /// [TomAnnotationAnalyzer.referenceQuery]; what is left here is the part that
  /// needs a connection: compile, run, and write the rows back through the
  /// field's mirror.
  Future<void> _loadReferencedValues(List<_PendingReference> refStack) async {
    for (final (:column, :owner, field: vm, row: im) in refStack) {
      // Built before the try: a malformed expression is an authoring error in
      // the annotation, and surfaces as itself rather than as a data-source
      // failure wrapped around it.
      final reference = TomAnnotationAnalyzer.referenceQuery(
        column.reference!,
        owner.reflectedType,
        (field) => im.invokeGetter(field),
      );
      final query = reference.sentence;
      final referenceQueryParams = reference.parameters;
      try {
        TomQuerySentenceCompiler tsc = runCheckedSync<TomQuerySentenceCompiler>(
          () => TomQuerySentenceCompiler([
            column.reference!.targetEntity,
            column.reference!.joinEntity,
          ]),
          (e, s) {
            var msg =
                "Failed to create TomQuerySentenceCompiler for types ${[column.reference!.targetEntity, column.reference!.joinEntity]} when setting field ${vm.simpleName}";
            tomLog.error(msg);
            return MariadbDatasourceException(
              "error.result_processing.ref_qsc_creation_failed",
              msg,
              parameters: {
                "types": [
                  column.reference!.targetEntity,
                  column.reference!.joinEntity,
                ],
                "attribute": vm.simpleName,
              },
              stack: s,
              rootException: e,
              autoLog: true,
            );
          },
        );
        TomSelect ts = runCheckedSync<TomSelect>(
          () => tsc.compileQuerySentence(query) as TomSelect,
          (e, s) {
            var msg = "Failed to compile query $query to TomSelect. $e";
            return MariadbDatasourceException(
              "error.result_processing.ref_query_compilation_failed",
              msg,
              parameters: {
                "types": [
                  column.reference!.targetEntity,
                  column.reference!.joinEntity,
                ],
                "attribute": vm.simpleName,
                "query": query,
              },
              stack: s,
              rootException: e,
              autoLog: true,
            );
          },
        );
        String queryString = runCheckedSync<String>(
          () => ts.generateQuery(_sqlDialect),
          (e, s) {
            var msg = "Failed to generate SQL from TomSelect $ts. $e";
            return MariadbDatasourceException(
              "error.result_processing.ref_query_generation_failed",
              msg,
              parameters: {
                "types": [
                  column.reference!.targetEntity,
                  column.reference!.joinEntity,
                ],
                "attribute": vm.simpleName,
                "query": query,
              },
              stack: s,
              rootException: e,
              autoLog: true,
            );
          },
        );
        List result = await runChecked<List>(
          () async => (await executeQuery<Object>(
            queryString,
            referenceQueryParams,
            column.reference!.targetEntity,
          )).toList(),
          (e, s) {
            var msg = "Failed to execute query";
            return MariadbDatasourceException(
              "error.result_processing.ref_query_execution_failed",
              msg,
              parameters: {
                "types": [
                  column.reference!.targetEntity,
                  column.reference!.joinEntity,
                ],
                "attribute": vm.simpleName,
                "query": query,
              },
              stack: s,
              rootException: e,
              autoLog: true,
            );
          },
        );
        // Fill the list the entity already holds rather than assigning a fresh
        // one: the declared type is `List<Target>`, and reflection cannot build
        // that instantiation — a mirror of a generic type has no type arguments
        // to construct with. Hence the requirement below that a reference field
        // be non-null and modifiable.
        List? value = im.invokeGetter(vm.simpleName) as List?;
        if (value != null) {
          value.clear();
          try {
            for (var r in result) {
              value.add(r);
            }
          } catch (e, s) {
            var msg =
                "Failed to add result values to List ${vm.simpleName} $result $e";
            throw MariadbDatasourceException(
              "error.result_processing.ref_failed_adding_result_to_value",
              msg,
              parameters: {
                "types": [
                  column.reference!.targetEntity,
                  column.reference!.joinEntity,
                ],
                "attribute": vm.simpleName,
                "field": column.field,
                "query": query,
              },
              stack: s,
              rootException: e,
              autoLog: true,
            );
          }
          try {
            im.invokeSetter(vm.simpleName, value);
          } catch (e, s) {
            var msg =
                "Failed to set updated list value in result instance ${vm.simpleName} $result $e";
            throw MariadbDatasourceException(
              "error.result_processing.ref_failed_invoke_setter",
              msg,
              parameters: {
                "types": [
                  column.reference!.targetEntity,
                  column.reference!.joinEntity,
                ],
                "attribute": vm.simpleName,
                "field": column.field,
                "query": query,
              },
              stack: s,
              rootException: e,
              autoLog: true,
            );
          }
        } else {
          var msg =
              "Reference field has null value. Reference fields must be non-nullable and have modifiable values";
          throw MariadbDatasourceException(
            "error.result_processing.ref_reference_field_must_have_non-null_value",
            msg,
            parameters: {
              "types": [
                column.reference!.targetEntity,
                column.reference!.joinEntity,
              ],
              "attribute": vm.simpleName,
              "field": column.field,
              "query": query,
            },
            autoLog: true,
          );
        }
      } catch (e, s) {
        if (e is MariadbDatasourceException) {
          rethrow;
        }
        var msg =
            "Failed to get and update referenced values: $e ${vm.simpleName}";
        throw MariadbDatasourceException(
          "error.result_processing.ref_failed_unexpected",
          msg,
          parameters: {
            "types": [
              column.reference!.targetEntity,
              column.reference!.joinEntity,
            ],
            "attribute": vm.simpleName,
            "field": column.field,
            "query": query,
          },
          stack: s,
          rootException: e,
          autoLog: true,
        );
      }
    }
  }

  /// Binds [settings] onto this driver's fields and opens the connection.
  ///
  /// [settings] is the datasource block minus the keys the registry reads
  /// itself (`TomDataSourceInfo.registryKeys`), and every key in it has already
  /// been checked against this class's fields — a block with a misspelling in
  /// it never reaches this method. So the shared, tolerant [tomReflectionInfo]
  /// is used here and nothing is lost by it: there is no unknown key left to
  /// tolerate. A driver written outside the framework inherits the same
  /// guarantee, because the check is the registry's rather than each driver's.
  @override
  Future<void> initialize(Map<String, dynamic> settings) async {
    tomReflectionInfo.setValues<MariaDbDatasource>(
      this,
      normalizeIntegerSettings(settings),
    );
    await connect();
  }

  /// The settings this driver binds to `int` fields: the port, the connect
  /// timeout and the six pool settings.
  static const Set<String> integerSettings = {
    'port',
    'timeOut',
    'poolMaxSize',
    'poolMinIdle',
    'poolAcquireTimeoutMs',
    'poolIdleTimeoutMs',
    'poolMaxLifetimeMs',
    'poolValidateAfterIdleMs',
  };

  /// Returns [settings] with every [integerSettings] value given as a string
  /// folded to an `int` (G-DB-3).
  ///
  /// The driver binds these to `int` fields, but application config may
  /// express them either as ints or as strings — an environment substitution
  /// (`port: ${DB_PORT:3306}`, `poolMaxSize: ${DB_POOL:10}`) always yields a
  /// string. Folding before reflection binding lets both forms work. A map with
  /// no string-valued integer setting is returned unchanged. The port is parsed
  /// by [parsePort] and keeps its own error key; every other value that is not
  /// an integer throws `error.initialize.invalid_integer` naming its key.
  static Map<String, dynamic> normalizeIntegerSettings(
    Map<String, dynamic> settings,
  ) {
    final folded = <String, dynamic>{};
    for (final key in integerSettings) {
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

  /// Whether the data source is open and can reach its database: open, and
  /// either holding a live connection or — holding none — having opened the
  /// last one it tried.
  @override
  bool isOperational() {
    final pool = _pool;
    if (pool == null || pool.isClosed) return false;
    final links = pool.connections;
    if (links.isEmpty) return !_lastOpenFailed;
    return links.any((link) => link.connected);
  }

  @override
  Future<BigInt> executeCommand(
    String command, [
    Map<String, dynamic>? params,
  ]) async {
    _refuseMultipleStatements(command, "executeCommand");
    final qResult = await _withLink(
      "executeCommand",
      (link) => runChecked<IResultSet>(
        () async =>
            await link.connection.execute(command, _toBindParams(params)),
        (e, s) {
          return MariadbDatasourceException(
            "error.result_processing.executecommand_failed",
            "ExecuteCommand $command failed: $e",
            parameters: {...?params, "command": command},
            rootException: e,
            stack: s,
            autoLog: true,
          );
        },
      ),
    );
    return qResult.affectedRows;
  }

  /// Closes the pool and lets go of it.
  ///
  /// Idle connections are closed at once; a connection still lent — to a
  /// transaction or a running statement — is closed when it is handed back.
  /// A connection that fails to close is logged and dropped: the caller is done
  /// with it either way.
  ///
  /// The pool is cleared so that a closed data source reads as closed, and
  /// refuses statements, rather than reopening on the next one — on the
  /// shutdown path that would open connections nothing would ever close.
  ///
  /// A data source that was never opened has nothing to release, so closing it
  /// changes nothing and leaves it reading as never opened.
  @override
  Future<void> close() async {
    final pool = _pool;
    if (pool == null) {
      tomLog.warn(
        "MariadbDatasource NOT closing $host:$port/$databaseName: it is not "
        "open.",
      );
      return;
    }
    tomLog.info("MariadbDatasource closing $host:$port/$databaseName");
    _pool = null;
    _wasClosed = true;
    await pool.close();
  }

  @override
  String toString() =>
      "MariadbDatasource $host:$port/$databaseName ${_stateDescription()}";

  /// How this data source describes its state: its pool while it is open, and
  /// otherwise which of the two ways it came to hold none.
  String _stateDescription() {
    final pool = _pool;
    if (pool != null) {
      return "open (${pool.lentCount} lent, ${pool.idleCount} idle)";
    }
    return _wasClosed ? "closed" : "never opened";
  }

  /// The database this source speaks to, not the object speaking to it.
  ///
  /// Two instances configured for one database therefore answer the same id,
  /// which is deliberate: a transaction wants the *resource* enlisted once.
  /// What it does not permit is both of them enlisting — they are two
  /// connections with two transactions of their own, and only one of them can
  /// be the transaction's. `TomTransaction.registerParticipant` refuses the
  /// second with `…duplicate_id` rather than dropping it, because a dropped
  /// connection's writes are neither committed with the transaction nor rolled
  /// back with it.
  ///
  /// A deployment that genuinely needs two enlistments against one database —
  /// two XA branches, say — gives the second source a distinct `databaseName`,
  /// `host` or `port`, or overrides this.
  @override
  String getParticipantId() => "MariaDb-$databaseName@$host:@$port";

  /// Each running transaction's share of this data source, by transaction.
  ///
  /// A transaction is a property of a *connection* — every statement on it
  /// between `START TRANSACTION` and `COMMIT` belongs to that transaction — so
  /// each transaction this data source is enlisted in has a connection of its
  /// own, pinned here from its first statement to [endTransaction].
  final Map<TomTransaction, _Branch> _branches = HashMap.identity();

  /// Issues one of [transaction]'s own lifecycle statements —
  /// `START TRANSACTION`, `COMMIT`, `ROLLBACK`, the `XA` verbs — on its pinned
  /// connection, without enlisting anything.
  ///
  /// Routed through [executeCommand] rather than around it, so there stays one
  /// way a command reaches a connection.
  Future<BigInt> _lifecycle(TomTransaction transaction, String command) =>
      runZoned(
        () => executeCommand(command),
        zoneValues: {_LifecycleKey: _LifecycleKey(this, transaction)},
      );

  /// Hands [transaction]'s connection back to the pool and forgets its branch.
  Future<void> _endBranch(TomTransaction transaction) async {
    final branch = _branches.remove(transaction);
    if (branch == null) return;
    if (!branch.started.isCompleted) branch.started.complete(false);
    final pinned = branch.link;
    final pool = _pool;
    if (pinned == null) return;
    _MariaDbLink link;
    try {
      link = await pinned;
    } catch (_) {
      return; // Never acquired, so nothing to hand back.
    }
    if (pool != null) {
      await _handBack(pool, link);
    } else {
      // Closed while the transaction ran: the connection goes with it.
      try {
        if (link.connected) await link.connection.close();
      } catch (_) {}
    }
  }

  /// Refuses a second start of a transaction this data source is already in.
  ///
  /// Shared by both lifecycles so the refusal cannot drift apart — it is one
  /// programming error, reported one way, whichever data source hits it.
  /// [transactionId] names the XA branch already open where there is one.
  ///
  /// Thrown rather than reported as `false`, and *in front of* the `try` that
  /// turns a failed statement into `false`, because the two are not the same
  /// kind of event. A `START TRANSACTION` the database refuses is a failure
  /// the caller may retry or route around; starting the same transaction twice
  /// is the caller's own mistake, and no retry fixes it. Another transaction
  /// is not refused: it gets a connection of its own.
  Never _refuseNestedTransaction([String? transactionId]) {
    throw MariadbDatasourceException(
      "error.transaction.already_active",
      "MariadbDatasource ${getParticipantId()} is already in this "
          "transaction${transactionId == null ? "" : " ($transactionId)"}. "
          "Conclude it with commit() or rollback() before starting it again.",
      parameters: {
        "participant": getParticipantId(),
        if (transactionId != null) "transactionId": transactionId,
      },
    );
  }

  /// Opens [transaction] on a connection of its own, read-only when it is.
  ///
  /// `START TRANSACTION READ ONLY` is what makes the flag mean something: the
  /// server refuses every write on this connection until the transaction ends,
  /// with `ER_CANT_EXECUTE_IN_READ_ONLY_TRANSACTION`. The coordinator cannot
  /// enforce it — it has no idea what a write is — so the resource that can is
  /// the only place it can be enforced.
  @override
  Future<bool> startTransaction(TomTransaction transaction) async {
    final existing = _branches[transaction];
    if (existing != null && existing.active) _refuseNestedTransaction();
    final branch = _openBranch(transaction, existing);
    try {
      await _lifecycle(
        transaction,
        transaction.isReadOnly
            ? "START TRANSACTION READ ONLY;"
            : "START TRANSACTION;",
      );
      branch.active = true;
      branch.started.complete(true);
      return true;
    } catch (error) {
      tomLog.error(
        "Starting database transaction of ${getParticipantId()} failed $error",
      );
      await _abandonStart(transaction, branch, existing);
      return false;
    }
  }

  /// The branch [transaction] starts on: [existing], when the transaction ran
  /// on this data source before and was concluded, keeping its connection —
  /// otherwise a new one.
  _Branch _openBranch(TomTransaction transaction, _Branch? existing) {
    final branch = existing ?? _Branch();
    if (existing != null) branch.started = Completer<bool>();
    _branches[transaction] = branch;
    return branch;
  }

  /// Undoes a start that failed: a new branch is forgotten with its connection,
  /// since no conclusion will ever release it; a reused one is left as it was.
  Future<void> _abandonStart(
    TomTransaction transaction,
    _Branch branch,
    _Branch? existing,
  ) async {
    branch.active = false;
    if (!branch.started.isCompleted) branch.started.complete(false);
    if (existing == null) await _endBranch(transaction);
  }

  /// Ends this participant's part of [transaction] by handing its connection
  /// back to the pool; always succeeds.
  ///
  /// A one-phase `START TRANSACTION` / `COMMIT` has no prepare step, so there
  /// is no statement to issue. The coordinator calls this on every participant
  /// after either conclusion, which is what makes it the place a transaction's
  /// connection is returned.
  ///
  /// Reporting `true` is not a formality. The coordinator ands every
  /// participant's result into the outcome, so a `false` here would fail a
  /// transaction that had in fact completed.
  @override
  Future<bool> endTransaction(TomTransaction transaction) async {
    await _endBranch(transaction);
    return true;
  }

  /// Phase one for a resource that has no phase one: always `true`.
  ///
  /// A plain `START TRANSACTION` / `COMMIT` has no statement that makes the
  /// commit certain without performing it, so there is nothing to issue here
  /// and nothing this data source can promise beyond what the connection is
  /// already doing. Its `COMMIT` can still fail.
  ///
  /// That is the cost of enlisting it beside a two-phase participant, and it is
  /// worth naming: the transaction is atomic unless *this* participant's commit
  /// fails, at which point the peers that prepared have already committed. A
  /// deployment that needs the full guarantee across two databases uses
  /// [MariaDbXADatasource] for both.
  @override
  Future<bool> prepare(TomTransaction transaction) async => true;

  @override
  Future<bool> commit(TomTransaction transaction) async {
    try {
      await _lifecycle(transaction, "COMMIT;");
      return true;
    } catch (error) {
      tomLog.error(
        "Committing database transaction of ${getParticipantId()} failed $error",
      );
      return false;
    } finally {
      _branches[transaction]?.active = false;
    }
  }

  /// Undoes [transaction] on its connection, reporting whether it was undone.
  ///
  /// A `false` here is the outcome that needs a human: the statements the
  /// connection issued are neither committed nor rolled back. The coordinator
  /// puts this data source in [TomTransactionResult.failed] and reports the
  /// transaction as [TomTransactionOutcome.rolledBackWithFailures].
  @override
  Future<bool> rollback(TomTransaction transaction) async {
    try {
      await _lifecycle(transaction, "ROLLBACK;");
      return true;
    } catch (error) {
      tomLog.error(
        "Rolling back database transaction of ${getParticipantId()} failed $error",
      );
      return false;
    } finally {
      _branches[transaction]?.active = false;
    }
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
/// [rollback] needs the branch to name. An exit that forgets locks this data
/// source out of every later transaction for good, and the caller cannot
/// recover by rolling back, because the branch it would have to name never
/// began.
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

  /// A new branch id: `<database>@<host>:<port>_<process>_<time>_<counter>`.
  ///
  /// Bounded and unique, in that order of necessity. MariaDB refuses a `gtrid`
  /// over [maxBranchIdBytes] as a syntax error, so a branch id built from the
  /// coordinates as written makes every XA transaction fail to start the
  /// moment a real hostname or database name is long enough. The unique tail
  /// is always kept whole and the readable head is what gets truncated: a
  /// shortened name still tells an operator reading `XA RECOVER` whose branch
  /// it is, while a shortened tail could name two branches alike. The tail is
  /// unique across processes (a random tag) as well as within one (the time
  /// plus a counter). Characters outside `[A-Za-z0-9_.@:-]` become `_`, which
  /// keeps the id single-byte and safe to quote.
  String _newBranchId() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final count = (_branchCounter++).toRadixString(36);
    final tail = '_${_processTag}_${time}_$count';
    final head = '$databaseName@$host:$port'.replaceAll(
      RegExp(r'[^A-Za-z0-9_.@:-]'),
      '_',
    );
    final room = maxBranchIdBytes - tail.length;
    return (head.length > room ? head.substring(0, room) : head) + tail;
  }

  /// Opens an XA branch. A read-only [transaction] cannot be honoured here.
  ///
  /// `XA START` has no `READ ONLY` form in MariaDB or MySQL, so this data
  /// source cannot ask the server to refuse writes the way its one-phase
  /// sibling does. Reported rather than ignored: a deployment that declared
  /// `@TomTransactional(isReadOnly: true)` and reads nothing anywhere would
  /// otherwise believe the branch was protected.
  ///
  /// Each transaction gets its own branch id and its own connection; the
  /// branch state lives with the transaction, so concurrent transactions on
  /// this data source are separate branches.
  ///
  /// A branch tracks whether it has been `XA END`ed. `XA END` is legal exactly
  /// once, on an ACTIVE branch, and a rollback has to know which side of it the
  /// branch is on: `XA ROLLBACK` is refused on an ACTIVE branch —
  /// `XAER_RMFAIL: The command cannot be executed when global transaction is in
  /// the ACTIVE state` — and `XA END` is refused on an IDLE or PREPARED one.
  @override
  Future<bool> startTransaction(TomTransaction transaction) async {
    final existing = _branches[transaction];
    if (existing != null && existing.xaId != null) {
      _refuseNestedTransaction(existing.xaId);
    }
    if (transaction.isReadOnly) {
      tomLog.warn(
        "${getParticipantId()} joined a read-only transaction, but XA has no "
        "read-only branch: writes on this connection are not prevented.",
      );
    }
    final branch = _openBranch(transaction, existing)
      ..xaId = "'${_newBranchId()}'"
      ..ended = false;
    try {
      await _lifecycle(transaction, "XA START ${branch.xaId};");
      branch.active = true;
      branch.started.complete(true);
      return true;
    } catch (error) {
      tomLog.error(
        "Starting XA database transaction of ${getParticipantId()} failed $error",
      );
      // The database never opened the branch, so its id is cleared. Keeping it
      // would refuse the transaction's every later start, and the caller
      // cannot clear it by rolling back, because it was just told the
      // transaction did not begin.
      branch.xaId = null;
      await _abandonStart(transaction, branch, existing);
      return false;
    }
  }

  /// Ends this participant's part of [transaction]: it issues no statement and
  /// hands the connection back, exactly as its one-phase sibling's does.
  ///
  /// Every XA statement belongs to a phase the coordinator decides something
  /// with, and this method is called after the decision — so a statement placed
  /// here could not influence the outcome it is part of. `XA END` and
  /// `XA PREPARE` are [prepare]'s; `XA COMMIT` is [commit]'s.
  ///
  /// Reporting `true` is not a formality. The coordinator ands every
  /// participant's result into the outcome, so a `false` here would fail a
  /// transaction that had in fact completed.
  @override
  Future<bool> endTransaction(TomTransaction transaction) =>
      super.endTransaction(transaction);

  /// Phase one: `XA END` then `XA PREPARE` against this branch, as two calls.
  ///
  /// Two calls, not one command: the driver reads only the first reply of a
  /// multi-statement command (see `_refuseMultipleStatements`), and a
  /// PREPARE's reply left on the wire is what a later `XA COMMIT` would then
  /// return on — before the server had committed.
  ///
  /// This is the statement XA exists for. A prepared branch is one the server
  /// has undertaken to be able to commit — it survives a restart, and nothing
  /// but `XA COMMIT` or `XA ROLLBACK` can resolve it — which is exactly the
  /// promise the coordinator's prepare phase asks every participant for.
  ///
  /// A failure here keeps the branch, and that is the opposite of every other
  /// exit. The coordinator answers a veto by rolling *every* participant back,
  /// this one included, and [rollback] needs the branch to name; clearing it
  /// would send `XA ROLLBACK null` and leave the real branch behind.
  /// [rollback] clears it in its `finally`, so the data source is not wedged
  /// either way.
  @override
  Future<bool> prepare(TomTransaction transaction) async {
    final branch = _branches[transaction];
    if (branch == null) return false;
    try {
      await _lifecycle(transaction, "XA END ${branch.xaId};");
      branch.ended = true;
      await _lifecycle(transaction, "XA PREPARE ${branch.xaId};");
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
  /// Reached only once every participant has prepared, so the branch here is
  /// always a prepared one and this call is the promise being kept. A failure
  /// is an in-doubt branch rather than a veto: the coordinator reports the
  /// transaction as partially committed and does not roll anybody back, because
  /// peers have already committed. The branch is left set and prepared so that
  /// an operator — or a later `XA RECOVER` — has something to name.
  @override
  Future<bool> commit(TomTransaction transaction) async {
    final branch = _branches[transaction];
    if (branch == null || branch.xaId == null) return false;
    final xaId = branch.xaId;
    try {
      await _lifecycle(transaction, "XA COMMIT $xaId;");
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
    // A participant that never opened a branch — its `startTransaction` failed
    // — is still rolled back with everyone else, and so is one whose branch a
    // successful commit has already cleared, which happens when a later
    // participant's commit fails. There is nothing to undo in either case, and
    // issuing the statement anyway would send `XA ROLLBACK null`.
    final branch = _branches[transaction];
    final xaId = branch?.xaId;
    if (branch == null || xaId == null) return true;
    var undone = true;
    try {
      // An ACTIVE branch has to be ended before it can be rolled back; an IDLE
      // or prepared one has already been ended and would refuse a second
      // `XA END`. Sending `XA ROLLBACK` alone leaves an active branch exactly
      // where it was — holding its locks, with nothing issuing `XA RECOVER` to
      // find it. A refused `XA END` ends the attempt: the branch is still
      // ACTIVE, and `XA ROLLBACK` would be refused for the same reason.
      if (!branch.ended) await _lifecycle(transaction, "XA END $xaId;");
      await _lifecycle(transaction, "XA ROLLBACK $xaId;");
    } catch (error) {
      tomLog.error(
        "Rolling back XA database transaction of ${getParticipantId()} failed $error",
      );
      // Reported as well as logged. A branch that would not roll back is still
      // there, holding its locks, and the log line was the entire record of it.
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

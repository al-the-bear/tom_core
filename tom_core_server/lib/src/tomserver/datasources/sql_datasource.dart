// ignore_for_file: type_literal_in_constant_pattern
/// The part of a SQL data source that does not depend on the database: the
/// connection pool, the transaction a connection is pinned to, the statement
/// paths, and the mapping of result rows onto Dart objects.
///
/// A driver supplies the rest — how a connection is opened, how a statement
/// runs on it, how its results read as text, which words open and close a
/// transaction — by extending [TomSqlDatasource]. `MariaDbDatasource` and
/// `PostgresDatasource` are the two drivers; everything that makes them behave
/// alike lives here once, so the two cannot drift apart on a rule that has
/// nothing to do with which server is on the other end.
///
/// ## Results as text
///
/// A driver hands its rows over as [TomSqlRow]s, which answer every column as
/// **text in one convention**: an instant as `YYYY-MM-DD HH:MM:SS.ffffff` in
/// UTC (`sql_instant.dart`), a date as `YYYY-MM-DD`, a time as `HH:MM:SS`, a
/// number as its decimal digits, a truth value as `1` or `0`. That is how the
/// MariaDB protocol delivers values anyway; a driver whose protocol delivers
/// typed values (PostgreSQL) renders them into it. The mapper then reads one
/// representation, with one set of parsers and one set of failure keys,
/// whichever database a row came from.
library;

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import '../object_persistence/annotation_analyzer.dart';
import '../object_persistence/field_encryption.dart';
import '../object_persistence/grouped_query.dart';
import '../object_persistence/persistence_annotations.dart';
import '../object_persistence/query_sentence_compiler.dart';
import '../transactions/transaction_manager.dart';
import 'connection_pool.dart';
import 'datasource_initialization.dart';
import 'queries.dart';
import 'read_replicas.dart';
import 'sql_instant.dart';
import 'sql_lexer.dart';
import 'types_operator.dart';

/// A SQL data-source failure: connect, execute, or result mapping.
///
/// Each driver throws its own subtype, so a log names the database; code that
/// handles any of them catches this.
class TomSqlDatasourceException extends TomServerException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomServerException].
  TomSqlDatasourceException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// A prepared statement failed with no live connection to have run on: one
/// reconnect-and-retry may recover it.
///
/// The type carries the whole signal: [TomSqlPreparedStatement.run] catches
/// this and nothing else, so raising it *is* the decision to retry. Which
/// failures qualify is the driver's [TomSqlDatasource.isLostConnection].
class TomSqlConnectionLostException extends TomServerException {
  /// Creates the exception with a message [key] and [defaultUserMessage]; the
  /// remaining parameters mirror [TomServerException].
  TomSqlConnectionLostException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// One row of a statement's result, every column read as text in the
/// convention the library documentation states.
abstract interface class TomSqlRow {
  /// [column] as text, or `null` for SQL `NULL`.
  String? text(String column);

  /// [column] as the text of a temporal value — an instant, a date or a time.
  ///
  /// Separate from [text] because a driver may have to repair what its
  /// protocol renders for a temporal column specifically, and must not touch a
  /// text column that only happens to look like one.
  String? temporalText(String column);

  /// [column] as a truth value: `1`/`0` and `true`/`false` alike.
  bool? boolean(String column);
}

/// What a statement produced: its rows, the rows it changed, and the key it
/// generated.
///
/// An interface so a driver can answer it lazily — reading its own result only
/// for what the statement's caller asks — and [TomSqlResultValues] for one that
/// holds the values outright.
abstract interface class TomSqlResult {
  /// The result columns, in order.
  List<String> get columns;

  /// The rows.
  List<TomSqlRow> get rows;

  /// How many rows the statement changed.
  int get affectedRows;

  /// The key the statement generated, or `null` when it generated none.
  int? get generatedId;

  /// Whether the result carries a column called [name].
  bool hasColumn(String name);
}

/// A [TomSqlResult] holding its values.
class TomSqlResultValues implements TomSqlResult {
  /// A result of [columns] and [rows].
  ///
  /// With [caseInsensitiveColumns], [hasColumn] ignores case — for a database
  /// that folds unquoted identifiers, where `SELECT x AS dueAt` answers a
  /// column called `dueat`.
  TomSqlResultValues({
    this.columns = const [],
    this.rows = const [],
    this.affectedRows = 0,
    this.generatedId,
    this.caseInsensitiveColumns = false,
  }) : _lowerColumns = caseInsensitiveColumns
           ? {for (final c in columns) c.toLowerCase()}
           : const {};

  @override
  final List<String> columns;

  @override
  final List<TomSqlRow> rows;

  @override
  final int affectedRows;

  @override
  final int? generatedId;

  /// Whether column names compare without regard to case.
  final bool caseInsensitiveColumns;

  final Set<String> _lowerColumns;

  @override
  bool hasColumn(String name) => caseInsensitiveColumns
      ? _lowerColumns.contains(name.toLowerCase())
      : columns.contains(name);
}

/// One pooled connection of a [TomSqlDatasource].
abstract class TomSqlLink {
  /// Whether the connection is still established.
  bool get connected;
}

/// Marshals one bind [value] into the primitive a SQL driver binds: a
/// [TomDbType] box is unwrapped to the Dart value it holds; a Dart `bool`
/// becomes `1`/`0`; a [TomZonedDate] becomes its `DATE` text and a
/// [TomZonedTime] its `TIME` text; any other [DateTime] becomes its UTC instant
/// text ([sqlInstant]); every other value is bound as-is.
///
/// One encoding for every driver. MariaDB has no boolean type (`BOOLEAN` is
/// `TINYINT(1)`) and no zone-aware `DATETIME`, and rejects both a bound
/// `'false'` and an instant ending in `Z`. PostgreSQL is sent each value as
/// text with an unspecified type and infers the type from where the
/// parameter is used, so the same text reads correctly into a `SMALLINT`, a
/// `BOOLEAN` or a `TIMESTAMP` column there. Writing the instant rather than
/// a node's wall clock is what lets every node of a cluster read every other
/// node's rows: `TomDbDateTime.of` reads it back as UTC.
Object? tomSqlBindValue(Object? value) {
  final unwrapped = value is TomDbType ? value.get() : value;
  if (unwrapped is bool) return unwrapped ? 1 : 0;
  // The two kernel half-instants are tested first because both *are* a
  // `DateTime`, so the general arm below would claim them and bind a whole
  // instant into a column that holds half of one. Which half a value means is
  // decided by its type, exactly as the dialect decides it for an inlined
  // literal, and by the same three renderers so the two routes cannot
  // disagree.
  if (unwrapped is TomZonedDate) return sqlDate(unwrapped);
  if (unwrapped is TomZonedTime) return sqlTimeOfDay(unwrapped);
  if (unwrapped is DateTime) return sqlInstant(unwrapped);
  return unwrapped;
}

/// [params] with every value marshalled through [tomSqlBindValue].
///
/// Both statement paths marshal, so a hand-written store binding a `DateTime`
/// or a `bool` gets the same encoding as a prepared statement does.
Map<String, Object?>? tomSqlBindParams(Map<String, dynamic>? params) =>
    params == null
    ? null
    : {
        for (final entry in params.entries)
          entry.key: tomSqlBindValue(entry.value),
      };

/// A [TomPreparedStatement] of a [TomSqlDatasource]: the compiled [command],
/// the ordered [parameterList] its placeholders expect, and the [resultType]
/// rows are mapped to.
///
/// The handle belongs to no connection. A server-side prepared statement lives
/// on one connection, while a pooled data source runs each execution on
/// whichever connection it is given — the transaction's, or one lent for the
/// statement — so every pooled connection prepares [command] the first time it
/// runs it and keeps the server-side statement for the next. That is what lets
/// a repository prepare a statement once and keep it for the life of the
/// process.
class TomSqlPreparedStatement<T extends Object>
    extends TomPreparedStatement<T> {
  /// A statement running [command] on [datasource], binding [parameterList]
  /// and mapping rows to [resultType].
  TomSqlPreparedStatement(
    this.parameterList,
    this.datasource,
    this.resultType,
    this.command, {
    this.groupedProjection,
  });

  /// The data source that prepared and runs this statement.
  final TomSqlDatasource datasource;

  /// The placeholder names in positional order.
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

  /// Maps the named [params] onto the positional bind list [parameterList]
  /// expects, in placeholder order, each through [tomSqlBindValue].
  ///
  /// Values are taken **raw** — a Dart `null` stays `null` (so it binds SQL
  /// `NULL`), a `String` keeps its exact characters. They must **not** be
  /// rendered through the SQL-literal renderer (`objectOp`), which would
  /// double-encode them: a `null` would bind the text `"NULL"` and a string
  /// would carry literal quote characters. A [TomDbType] box is the one value
  /// that is unwrapped: it is the SQL representation a column's
  /// `toDbConverter` produces, and a driver only understands primitives.
  /// Returns an empty list when [params] is `null`.
  static List<Object?> buildPositionalParameters(
    List<String> parameterList,
    Map<String, Object?>? params,
  ) {
    if (params == null) return const [];
    return [for (final p in parameterList) tomSqlBindValue(params[p])];
  }

  /// Runs the statement and maps its rows.
  @override
  Future<List<T>> execute([Map<String, Object?>? params]) async =>
      (await run(params)).rows;

  /// Runs the statement and reports its rows, the rows it changed and the key
  /// it generated — all three read from this execution's own result.
  ///
  /// A connection that turns out to be gone is retried once, on another
  /// connection, when the statement runs outside a transaction: the failed
  /// connection is discarded and the pool lends a working one. Inside a
  /// transaction there is nothing to retry on — the transaction lived on the
  /// connection that was lost — so the failure is reported as
  /// `error.failed-to-execute.transaction_connection_lost`.
  @override
  Future<TomStatementOutcome<T>> run([Map<String, Object?>? params]) async {
    final parameters = buildPositionalParameters(parameterList, params);
    TomSqlResult result;
    try {
      result = await datasource._runPrepared(
        command,
        parameters,
        params,
        resultType,
      );
    } on TomSqlConnectionLostException catch (lost) {
      if (datasource._isInTransactionHere()) {
        throw datasource.datasourceException(
          "error.failed-to-execute.transaction_connection_lost",
          "${datasource.preparedStatementLabel}: the connection of the "
              "running transaction was lost; the transaction cannot continue.",
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
    return TomStatementOutcome<T>(
      rows: await datasource.mapSqlResult<T>(
        result,
        resultType,
        groupedProjection,
      ),
      affectedRows: result.affectedRows,
      generatedId: result.generatedId,
    );
  }

  /// Forgets the statement on every connection that prepared it.
  ///
  /// A connection in use keeps its server-side statement until it is handed
  /// back, so nothing is deallocated under a statement that is running.
  @override
  Future<void> deallocate() => datasource._forgetStatement(command);
}

/// Marks the zone in which a data source issues one of a transaction's own
/// lifecycle statements (`START TRANSACTION`, `COMMIT`, the two-phase verbs).
class _LifecycleKey {
  const _LifecycleKey(this.datasource, this.transaction);
  final TomSqlDatasource datasource;
  final TomTransaction transaction;
}

/// One transaction's share of a data source: the pooled connection pinned to
/// it, and — for a two-phase driver — the branch it opened.
class TomSqlBranch {
  /// The connection, acquired by the transaction's first statement and held
  /// until [TomSqlDatasource.endTransaction].
  Future<TomSqlLink>? link;

  /// Completes with whether the transaction's start succeeded; a statement
  /// racing the start waits for it.
  Completer<bool> started = Completer<bool>();

  /// Whether the transaction is open on the connection: started, and not yet
  /// committed or rolled back. A second start is refused only while it is.
  bool active = false;

  /// The two-phase branch id, quoted; `null` on a one-phase driver.
  String? xaId;

  /// Whether a two-phase branch has left its active state — `XA END`ed on
  /// MariaDB, `PREPARE TRANSACTION`ed on PostgreSQL.
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

/// The histogram of SQL statement durations, labelled `datasource` and
/// `operation` (`query`, `command`, `prepare`, `prepared`, `driver`).
const String tomDbStatementDurationMetric = 'tom_db_statement_duration_seconds';

/// The counter of failed SQL statements, labelled as
/// [tomDbStatementDurationMetric].
const String tomDbStatementErrorsMetric = 'tom_db_statement_errors';

/// The observed gauge of a pool's connections, labelled `datasource` and
/// `state` (`idle`, `in_use`, `waiting`, `max`).
const String tomDbPoolConnectionsMetric = 'tom_db_pool_connections';

/// The histogram of the wait for a pooled connection, labelled `datasource`.
const String tomDbPoolAcquireDurationMetric =
    'tom_db_pool_acquire_duration_seconds';

/// The counter of failed connection acquires, labelled `datasource`.
const String tomDbPoolAcquireFailuresMetric = 'tom_db_pool_acquire_failures';

/// A pooled SQL [TomDataSource]; see the library documentation.
///
/// Connection settings ([username], [password], [host], [port],
/// [databaseName], [timeOut]) and pool settings ([poolMaxSize], [poolMinIdle],
/// [poolAcquireTimeoutMs], [poolIdleTimeoutMs], [poolMaxLifetimeMs],
/// [poolValidateAfterIdleMs]) are filled from the configuration map by
/// reflection in [initialize], which then opens the data source.
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
/// entry point requires an open data source and throws
/// `error.datasource.not_opened` if it is reached before one exists — opening
/// on demand could not work, since until the settings are configured the pool
/// would dial `:-1`.
///
/// [close] closes the pool **and lets go of it**, which puts the data source
/// back to not-open: a closed data source refuses statements exactly as one
/// that was never opened does, rather than being silently re-opened by the next
/// one to arrive.
@tomReflector
abstract class TomSqlDatasource implements TomDataSource {
  /// The connection user name.
  String username = "";

  /// The connection password.
  String password = "";

  /// The database host.
  String host = "";

  /// The database port (`-1` until configured).
  int port = -1;

  /// The database name (empty selects no default database where the server
  /// allows that).
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

  /// How long a connection may sit idle and still be lent without a check, in
  /// milliseconds.
  int poolValidateAfterIdleMs = 30000;

  /// The read replicas of this data source: one settings map per replica,
  /// each overriding this data source's own settings — usually only `host`
  /// and `port`. See `read_replicas.dart` for which statements a replica
  /// serves. Empty — the default — routes everything to this data source.
  List<Object?> replicas = [];

  /// How long after a principal's write its reads stay on this data source,
  /// the primary, rather than a replica — read-your-writes. In milliseconds;
  /// should exceed the replicas' usual lag.
  int replicaStickinessMs = 5000;

  /// How long a replica that failed to serve a connection is left out, in
  /// milliseconds; its reads go to the primary meanwhile.
  int replicaRetryMs = 30000;

  /// The pool settings the fields above describe.
  TomConnectionPoolSettings get poolSettings => TomConnectionPoolSettings(
    maxSize: poolMaxSize,
    minIdle: poolMinIdle,
    acquireTimeout: Duration(milliseconds: poolAcquireTimeoutMs),
    idleTimeout: Duration(milliseconds: poolIdleTimeoutMs),
    maxLifetime: Duration(milliseconds: poolMaxLifetimeMs),
    validateAfterIdle: Duration(milliseconds: poolValidateAfterIdleMs),
  );

  TomConnectionPool<TomSqlLink>? _pool;

  /// Whether [_pool] is `null` because [close] released it, rather than because
  /// the data source was never opened.
  bool _wasClosed = false;

  /// Whether the most recent attempt to open a connection failed.
  bool _lastOpenFailed = false;

  String _registeredName = "";

  /// The name this data source is registered under — `app`, or `app@tenant`
  /// for a tenant's own pool — which labels its metrics; the driver label
  /// until [registerAs] names it.
  String get registeredName =>
      _registeredName.isEmpty ? driverLabel : _registeredName;

  /// Records the registry name of this data source; called by
  /// [TomDataSourceInfo] when it creates the driver.
  void registerAs(String name) => _registeredName = name;

  /// The pool gauges of this data source, reported while it is open.
  TomMetricObservation? _poolObservation;

  // ---------------------------------------------------------------------------
  // What a driver supplies
  // ---------------------------------------------------------------------------

  /// How this driver names itself in messages — `MariadbDatasource`.
  @protected
  String get driverLabel;

  /// How this driver's prepared statements name themselves in messages.
  @protected
  String get preparedStatementLabel;

  /// The prefix of [getParticipantId] — `MariaDb`.
  @protected
  String get participantPrefix;

  /// The exception this driver throws, carrying [key].
  @protected
  TomServerException datasourceException(
    String key,
    String message, {
    Map<String, dynamic>? parameters,
    StackTrace? stack,
    Object? rootException,
    bool autoLog = false,
  }) => TomSqlDatasourceException(
    key,
    message,
    parameters: parameters,
    stack: stack,
    rootException: rootException,
    autoLog: autoLog,
  );

  /// The retry signal this driver raises for a statement whose connection was
  /// lost; see [TomSqlConnectionLostException].
  @protected
  TomServerException connectionLostException(
    String key,
    String message, {
    Map<String, dynamic>? parameters,
    StackTrace? stack,
    Object? rootException,
  }) => TomSqlConnectionLostException(
    key,
    message,
    parameters: parameters,
    stack: stack,
    rootException: rootException,
  );

  /// Opens one new connection with the configured settings.
  @protected
  Future<TomSqlLink> openLink();

  /// Closes [link]; a failure is the driver's to log.
  @protected
  Future<void> closeLink(TomSqlLink link);

  /// Whether [link] still answers a trivial statement.
  @protected
  Future<bool> validateLink(TomSqlLink link);

  /// Runs the positional [command] with [parameters] on [link] as a prepared
  /// statement, preparing it on that connection on first use.
  @protected
  Future<TomSqlResult> runPreparedOn(
    TomSqlLink link,
    String command,
    List<Object?> parameters,
  );

  /// Runs the named-parameter [command] with [params] (already marshalled) on
  /// [link].
  @protected
  Future<TomSqlResult> runCommandOn(
    TomSqlLink link,
    String command,
    Map<String, Object?>? params,
  );

  /// Forgets [command]'s server-side statement on [link]; the driver frees it
  /// when [releaseForgottenOn] runs.
  @protected
  void forgetStatementOn(TomSqlLink link, String command);

  /// Frees the statements forgotten on [link] while it was out, before it goes
  /// back to the pool.
  @protected
  Future<void> releaseForgottenOn(TomSqlLink link);

  /// Whether [error] means [link] was lost while the statement ran, so a retry
  /// on another connection may recover it.
  @protected
  bool isLostConnection(Object error, TomSqlLink link);

  /// The statement opening a transaction, read-only when [readOnly].
  @protected
  String beginStatement({required bool readOnly});

  /// The statement committing a one-phase transaction.
  @protected
  String get commitStatement;

  /// The statement rolling a one-phase transaction back.
  @protected
  String get rollbackStatement;

  /// Translates the generated `:name` [namedSql] into the positional form this
  /// driver's protocol binds, returning the SQL and the placeholder names in
  /// slot order.
  (String, List<String>) toPositional(String namedSql);

  // ---------------------------------------------------------------------------
  // Opening and closing
  // ---------------------------------------------------------------------------

  /// Opens the data source with the configured settings: creates the pool and
  /// opens its first connection.
  ///
  /// A server that cannot be reached or refuses the session fails the call
  /// with the driver's own error, and leaves the data source unopened. Calling
  /// it on an open data source does nothing.
  Future<void> connect() async {
    if (_pool != null) return;
    final pool = TomConnectionPool<TomSqlLink>(
      _LinkFactory(this),
      settings: poolSettings,
    );
    // The first connection is opened now so a misconfigured data source fails
    // here, where it was opened, and not on its first request.
    final first = await pool.acquire();
    await pool.release(first);
    _pool = pool;
    _poolObservation = TomMetrics.registry.observe(
      tomDbPoolConnectionsMetric,
      help:
          'Connections of a data source pool, by state: idle, in_use, and '
          'max (the configured ceiling); waiting counts the statements '
          'queued for one.',
      observer: () {
        final labels = {'datasource': registeredName};
        return [
          TomObservedValue(pool.idleCount, {...labels, 'state': 'idle'}),
          TomObservedValue(pool.lentCount, {...labels, 'state': 'in_use'}),
          TomObservedValue(pool.waitingCount, {...labels, 'state': 'waiting'}),
          TomObservedValue(pool.settings.maxSize, {...labels, 'state': 'max'}),
        ];
      },
    );
    await _openReplicas();
  }

  // ---------------------------------------------------------------------------
  // Read replicas
  // ---------------------------------------------------------------------------

  final List<TomSqlDatasource> _replicaSources = [];
  final List<DateTime?> _replicaDownUntil = [];
  final Expando<TomSqlDatasource> _transactionReplica = Expando();
  final Map<String, DateTime> _lastWrites = {};
  int _nextReplica = 0;

  /// The replicas of this data source, one per [replicas] entry.
  List<TomSqlDatasource> get replicaSources =>
      List.unmodifiable(_replicaSources);

  /// A new, unconfigured data source of this driver, to serve as a replica.
  @protected
  TomSqlDatasource newReplica();

  /// The settings a replica starts from: this data source's own, without its
  /// replica settings.
  Map<String, dynamic> _replicaBase() {
    final base = <String, dynamic>{
      ...?_ownSettings,
      'username': username,
      'password': password,
      'host': host,
      'port': port,
      'databaseName': databaseName,
      'timeOut': timeOut,
      'poolMaxSize': poolMaxSize,
      'poolMinIdle': poolMinIdle,
      'poolAcquireTimeoutMs': poolAcquireTimeoutMs,
      'poolIdleTimeoutMs': poolIdleTimeoutMs,
      'poolMaxLifetimeMs': poolMaxLifetimeMs,
      'poolValidateAfterIdleMs': poolValidateAfterIdleMs,
    };
    for (final key in const [
      'replicas',
      'replicaStickinessMs',
      'replicaRetryMs',
    ]) {
      base.remove(key);
    }
    return base;
  }

  /// Creates a data source per [replicas] entry and opens each that answers.
  /// A replica that does not is left out for [replicaRetryMs] and tried again
  /// when a read next wants it: the primary serves its reads meanwhile.
  Future<void> _openReplicas() async {
    if (replicas.isEmpty || _replicaSources.isNotEmpty) return;
    for (final (i, raw) in replicas.indexed) {
      final replica = newReplica()
        ..registerAs('$registeredName.replica${i + 1}');
      final overrides = Map<String, dynamic>.from(raw! as Map);
      replica.bindSettings(
        replica.normalizeSettings({..._replicaBase(), ...overrides}),
      );
      _replicaSources.add(replica);
      _replicaDownUntil.add(null);
      await _connectReplica(i);
    }
  }

  Future<bool> _connectReplica(int i) async {
    final replica = _replicaSources[i];
    if (replica._pool != null) return true;
    try {
      await replica.connect();
      _replicaDownUntil[i] = null;
      return true;
    } catch (error) {
      _replicaFailed(i, error);
      return false;
    }
  }

  void _replicaFailed(int i, Object error) {
    _replicaDownUntil[i] = DateTime.now().add(
      Duration(milliseconds: replicaRetryMs),
    );
    tomLog.warn(
      "$driverLabel: replica ${_replicaSources[i].registeredName} could not "
      "serve a connection and is left out for ${replicaRetryMs}ms; the "
      "primary serves its reads meanwhile: $error",
    );
  }

  /// The principal a write and a later read are matched on: the tenant and
  /// the principal in context.
  static String _writerKey() =>
      '${TomTenantContext.currentId ?? ''}/'
      '${getFromCurrentZone<TomPrincipal>()?.id ?? ''}';

  /// Records that the principal in context writes now, so its reads stay on
  /// the primary for [replicaStickinessMs].
  void _noteWrite() {
    if (_replicaSources.isEmpty) return;
    final now = DateTime.now();
    if (_lastWrites.length > 10000) {
      final horizon = now.subtract(Duration(milliseconds: replicaStickinessMs));
      _lastWrites.removeWhere((_, at) => at.isBefore(horizon));
    }
    _lastWrites[_writerKey()] = now;
  }

  /// Whether the principal in context wrote within [replicaStickinessMs].
  bool _wroteRecently() {
    final at = _lastWrites[_writerKey()];
    return at != null &&
        DateTime.now().difference(at).inMilliseconds < replicaStickinessMs;
  }

  /// The replica [statement] runs on, or `null` for the primary — see
  /// `read_replicas.dart` for the rules.
  Future<TomSqlDatasource?> _replicaFor(
    String operation,
    String? statement,
  ) async {
    if (_replicaSources.isEmpty || statement == null) return null;
    final key = Zone.current[_LifecycleKey];
    if (key is _LifecycleKey && identical(key.datasource, this)) return null;
    if (!TomReplicaRouting.isRepositoryRead ||
        !TomReplicaRouting.isReadOnlyContext ||
        TomReplicaRouting.isPrimaryForced ||
        !TomReplicaRouting.isReadStatement(statement) ||
        _wroteRecently()) {
      return null;
    }
    final transaction = TomTransactionManager.getCurrentTransaction();
    final inTransaction = transaction != null && transaction.isRunning;
    // One replica per read-only transaction: its reads see one snapshot.
    if (inTransaction) {
      final chosen = _transactionReplica[transaction];
      if (chosen != null) return chosen;
    }
    final now = DateTime.now();
    for (var tried = 0; tried < _replicaSources.length; tried++) {
      final i = _nextReplica++ % _replicaSources.length;
      final down = _replicaDownUntil[i];
      if (down != null && now.isBefore(down)) continue;
      if (!await _connectReplica(i)) continue;
      final replica = _replicaSources[i];
      if (inTransaction) _transactionReplica[transaction] = replica;
      return replica;
    }
    return null;
  }

  /// Opens a link through [openLink], recording whether it failed for
  /// [isOperational].
  Future<TomSqlLink> _openLinkRecorded() async {
    try {
      final link = await openLink();
      _lastOpenFailed = false;
      return link;
    } catch (_) {
      _lastOpenFailed = true;
      rethrow;
    }
  }

  /// Tries once to take the session lock [name] on [link]; `true` when this
  /// session now holds it.
  ///
  /// A session lock belongs to the connection that took it, and the database
  /// releases it when that connection ends — closed, or lost with the process
  /// that held it. `GET_LOCK` on MariaDB, `pg_try_advisory_lock` on
  /// PostgreSQL.
  @protected
  Future<bool> tryLockOn(TomSqlLink link, String name);

  /// Releases the session lock [name] [tryLockOn] took on [link].
  @protected
  Future<void> unlockOn(TomSqlLink link, String name);

  static final Object _sessionLocksKey = Object();

  /// Runs [body] while this process holds the database-wide session lock
  /// [name], waiting up to [wait] for another session to release it.
  ///
  /// The lock is taken on a connection of its own, opened beside the pool and
  /// closed when [body] ends, so it is released when [body] returns, when it
  /// throws, and — because the database ends the session — when the process
  /// dies. No lease, no expiry, nothing left behind to recover.
  ///
  /// [body]'s own statements run on the pool as usual; the lock is a mutual
  /// exclusion between processes, not a transaction.
  ///
  /// Re-entrant within the zone: a [body] that asks for the same lock on the
  /// same database again runs without waiting for itself. Waiting longer than
  /// [wait] throws `error.datasource.session_lock_timeout`.
  Future<R> withSessionLock<R>(
    String name,
    Future<R> Function() body, {
    Duration wait = const Duration(minutes: 10),
    Duration poll = const Duration(milliseconds: 250),
  }) async {
    final held = Zone.current[_sessionLocksKey] as Set<String>? ?? const {};
    final key = '$host:$port/$databaseName#$name';
    if (held.contains(key)) return body();
    final link = await _openLinkRecorded();
    try {
      final deadline = DateTime.now().add(wait);
      while (!await tryLockOn(link, name)) {
        if (!DateTime.now().isBefore(deadline)) {
          throw datasourceException(
            "error.datasource.session_lock_timeout",
            "$driverLabel: the session lock '$name' on "
                "$host:$port/$databaseName is held by another session and was "
                "not released within ${wait.inMilliseconds}ms.",
            parameters: {"lock": name, "waitMs": wait.inMilliseconds},
          );
        }
        await Future<void>.delayed(poll);
      }
      tomLog.info("$driverLabel holds session lock '$name' on $databaseName");
      try {
        return await runZoned(
          body,
          zoneValues: {
            _sessionLocksKey: {...held, key},
          },
        );
      } finally {
        try {
          await unlockOn(link, name);
        } catch (error) {
          // Closing the connection below releases it all the same.
          tomLog.warn(
            "$driverLabel could not release session lock '$name': $error",
          );
        }
      }
    } finally {
      await closeLink(link);
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

  /// Every connection of the pool, lent or idle; empty when not open.
  @protected
  Iterable<TomSqlLink> get pooledLinks => _pool?.connections ?? const [];

  /// Refuses [command] when it holds more than one statement.
  ///
  /// One call carries one statement, on every driver. MariaDB's client reads
  /// only the first reply of a multi-statement command and leaves the rest on
  /// the wire to answer later calls; PostgreSQL's extended protocol refuses a
  /// second statement outright. A script is split first, with
  /// [TomSqlLexer.splitStatements] — which is what the migration adaptors do.
  void _refuseMultipleStatements(String command, String operation) {
    final statements = TomSqlLexer.splitStatements(
      command,
      backslashEscapes: sqlDialect.backslashEscapes,
    );
    if (statements.length <= 1) return;
    throw datasourceException(
      "error.datasource.multiple_statements",
      "$driverLabel: $operation was given ${statements.length} "
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

  /// The pool, or the refusal for a data source that is not open.
  ///
  /// A `null` pool means the data source is not open — never opened, or
  /// closed — and that is refused rather than repaired. Re-opening a *closed*
  /// one could work, and that is precisely why it must not happen by accident:
  /// it would resurrect a data source the application deliberately let go.
  TomConnectionPool<TomSqlLink> _requirePool(String operation) {
    final pool = _pool;
    if (pool != null) return pool;
    throw datasourceException(
      "error.datasource.not_opened",
      "$driverLabel: $operation needs an open data source, but this one "
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
  ///
  /// [statement] is the SQL a statement path runs: a repository read of it in
  /// read-only work may be served by a read replica (`read_replicas.dart`). A
  /// replica that cannot lend a connection is left out for [replicaRetryMs],
  /// and the statement runs here.
  @protected
  Future<R> withLink<R>(
    String operation,
    Future<R> Function(TomSqlLink link) body, {
    String? statement,
  }) async {
    final pool = _requirePool(operation);
    final replica = await _replicaFor(operation, statement);
    if (replica != null) {
      var started = false;
      try {
        return await replica.withLink(operation, (link) {
          started = true;
          return body(link);
        });
      } catch (error) {
        if (started) rethrow;
        _replicaFailed(_replicaSources.indexOf(replica), error);
      }
    }
    if (operation == "executeCommand" ||
        (statement != null && !TomReplicaRouting.isReadStatement(statement))) {
      _noteWrite();
    }
    final branch = await _branchForThisZone();
    if (branch != null) {
      final link = await _pinnedLink(pool, branch);
      return _timed(operation, () => body(link));
    }
    final link = await _acquireTimed(pool);
    var lost = false;
    try {
      return await _timed(operation, () => body(link));
    } catch (_) {
      lost = !link.connected;
      rethrow;
    } finally {
      await _handBack(pool, link, discard: lost);
    }
  }

  /// Runs [body] — one statement on a connection already held — recording
  /// its duration in `tom_db_statement_duration_seconds` and, when it throws,
  /// `tom_db_statement_errors`. The wait for the connection is not part of it:
  /// that is `tom_db_pool_acquire_duration_seconds`.
  Future<R> _timed<R>(String operation, Future<R> Function() body) async {
    final labels = {
      'datasource': registeredName,
      'operation': _operationLabels[operation] ?? operation,
    };
    final watch = Stopwatch()..start();
    try {
      return await body();
    } catch (_) {
      TomMetrics.registry
          .counter(
            tomDbStatementErrorsMetric,
            help: 'SQL statements that failed, by data source and operation.',
          )
          .add(1, labels);
      rethrow;
    } finally {
      TomMetrics.registry
          .histogram(
            tomDbStatementDurationMetric,
            help:
                'How long an SQL statement took on its connection, by data '
                'source and operation.',
            unit: 's',
          )
          .recordDuration(watch.elapsed, labels);
    }
  }

  /// Takes a connection from [pool], recording the wait in
  /// `tom_db_pool_acquire_duration_seconds` and a failure — the acquire
  /// timeout, or a connection that could not be opened — in
  /// `tom_db_pool_acquire_failures`.
  Future<TomSqlLink> _acquireTimed(TomConnectionPool<TomSqlLink> pool) async {
    final labels = {'datasource': registeredName};
    final watch = Stopwatch()..start();
    try {
      return await pool.acquire();
    } catch (_) {
      TomMetrics.registry
          .counter(
            tomDbPoolAcquireFailuresMetric,
            help:
                'Connection acquires that failed — timed out or could not '
                'open a connection — by data source.',
          )
          .add(1, labels);
      rethrow;
    } finally {
      TomMetrics.registry
          .histogram(
            tomDbPoolAcquireDurationMetric,
            help:
                'How long a statement waited for a pooled connection, by '
                'data source.',
            unit: 's',
          )
          .recordDuration(watch.elapsed, labels);
    }
  }

  /// The `operation` label of each [withLink] operation.
  static const Map<String, String> _operationLabels = {
    'executeQuery': 'query',
    'executeCommand': 'command',
    'prepared statement': 'prepared',
    'prepareStatement': 'prepare',
    'withDriverConnection': 'driver',
  };

  /// The connection pinned to [branch], taking it from [pool] on first use.
  Future<TomSqlLink> _pinnedLink(
    TomConnectionPool<TomSqlLink> pool,
    TomSqlBranch branch,
  ) {
    final pinned = branch.link;
    if (pinned != null) return pinned;
    // A failed acquire leaves the branch without a connection, so the next
    // statement tries again rather than inheriting the failure.
    late final Future<TomSqlLink> acquiring;
    acquiring = _acquireTimed(pool).catchError((
      Object error,
      StackTrace stack,
    ) {
      if (identical(branch.link, acquiring)) branch.link = null;
      Error.throwWithStackTrace(error, stack);
    });
    branch.link = acquiring;
    return acquiring;
  }

  /// Returns [link] to [pool], first freeing the statements forgotten while it
  /// was out.
  Future<void> _handBack(
    TomConnectionPool<TomSqlLink> pool,
    TomSqlLink link, {
    bool discard = false,
  }) async {
    if (link.connected) await releaseForgottenOn(link);
    if (pool.isLent(link)) {
      await pool.release(link, discard: discard || !link.connected);
    }
  }

  /// The transaction branch statements in the current zone belong to, or
  /// `null` when they belong to none — enlisting this data source in the
  /// running transaction first if it is not enlisted yet.
  Future<TomSqlBranch?> _branchForThisZone() async {
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
  Future<TomSqlResult> _runPrepared(
    String command,
    List<Object?> parameters,
    Map<String, Object?>? params,
    Type? resultType,
  ) => withLink("prepared statement", statement: command, (link) async {
    return runChecked<TomSqlResult>(
      () => runPreparedOn(link, command, parameters),
      (e, StackTrace s) {
        tomLog.warn("Error when executing SQL: $e");
        // The exception type this returns *is* the retry signal: the statement
        // catches TomSqlConnectionLostException and nothing else.
        if (isLostConnection(e, link)) {
          forgetStatementOn(link, command);
          return connectionLostException(
            "error.failed-to-execute.connection_closed",
            "$preparedStatementLabel: connection closed",
            parameters: {...?params, "type": resultType},
            rootException: e,
            stack: s,
          );
        }
        return datasourceException(
          "error.failed-to-execute.exception",
          "$preparedStatementLabel: execution with $params failed. $e",
          parameters: {
            ...?params,
            "type": resultType,
            "connected": link.connected,
          },
          rootException: e,
          stack: s,
        );
      },
    );
  });

  /// Forgets the server-side statements for [command] on every connection.
  ///
  /// Each is freed when its connection is next handed back, so a statement is
  /// never freed under a connection someone is using.
  Future<void> _forgetStatement(String command) async {
    final pool = _pool;
    if (pool == null) return;
    for (final link in pool.connections) {
      forgetStatementOn(link, command);
    }
    // A replica's connections may have prepared it too.
    for (final replica in _replicaSources) {
      await replica._forgetStatement(command);
    }
  }

  @override
  Future<TomPreparedStatement<T>> prepareStatement<T extends Object>(
    TomQuery query, [
    Type? resultType,
  ]) async {
    _requirePool("prepareStatement");
    final (q, params) = toPositional(query.generateQuery(sqlDialect));
    // Prepared now, on the connection this zone selects, so a statement the
    // server cannot compile fails here rather than at its first execution.
    // Every other connection prepares it when it first runs it.
    await withLink(
      "prepareStatement",
      (link) => prepareOn(link, q, params.length),
    );
    return newPreparedStatement<T>(
      params,
      resultType,
      q,
      query is TomGroupedSelect ? query.projectionTypes : null,
    );
  }

  /// Prepares [command], which binds [parameterCount] parameters, on [link]
  /// without running it.
  @protected
  Future<void> prepareOn(TomSqlLink link, String command, int parameterCount);

  /// The prepared-statement handle this driver hands out.
  @protected
  TomSqlPreparedStatement<T> newPreparedStatement<T extends Object>(
    List<String> parameterList,
    Type? resultType,
    String command,
    Map<String, Type>? groupedProjection,
  ) => TomSqlPreparedStatement<T>(
    parameterList,
    this,
    resultType,
    command,
    groupedProjection: groupedProjection,
  );

  // ---------------------------------------------------------------------------
  // Reading rows
  // ---------------------------------------------------------------------------

  /// The `Type` literal for [X], including a nullable one.
  ///
  /// A nullable type cannot be written where a `Type` value is expected — there
  /// is no `double?` expression — but it *can* be named through a type
  /// argument. It exists solely to build [_nonNullableElementTypes].
  static Type _typeOf<X>() => X;

  /// Maps each nullable element type an observable can report onto the
  /// non-nullable type the row mapper dispatches on.
  ///
  /// `TomObject<T>.getType()` answers `T` exactly as declared, so a `TomNString`
  /// reports `String?`. Normalising once, here, keeps every switch below to one
  /// case per element type.
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
  /// point is one decision, made once.
  ///
  /// A `NULL` column yields `null` for every element type, including
  /// `DateTime`, so a member never keeps its initialiser value presented as if
  /// it had been read. A `DateTime` is read through the instant convention
  /// (`sql_instant.dart`), never as this node's local time.
  void _setObservableMember(
    TomSqlRow row,
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
        member.set(row.text(field));
      case bool:
        member.set(row.boolean(field));
      case DateTime:
        member.set(_readInstant(row, field));
      default:
        throw datasourceException(
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

  /// Reads [field] as a UTC instant.
  DateTime? _readInstant(TomSqlRow row, String field) =>
      _readTemporal(row, field, TomDbDateTime.of).get();

  /// Reads [field]'s temporal text through [read] — one of the `TomDbDateTime`,
  /// `TomDbDate` and `TomDbTime` `of` factories — and refuses what it cannot.
  ///
  /// A stored row is data from outside the process, so an unreadable value is a
  /// failure of the read, reported keyed and naming the column and the value,
  /// with the parser's exception as the root. The key names what the column
  /// failed to be: `not_a_date`, `not_a_time`, `not_an_instant`.
  B _readTemporal<B extends TomDbType>(
    TomSqlRow row,
    String field,
    B Function(String?) read,
  ) {
    final text = row.temporalText(field);
    try {
      return read(text);
    } on FormatException catch (error, stack) {
      final (key, kind) = switch (B) {
        const (TomDbDate) => ('not_a_date', 'a date'),
        const (TomDbTime) => ('not_a_time', 'a time of day'),
        _ => ('not_an_instant', 'an instant'),
      };
      throw datasourceException(
        "error.result_processing.$key",
        "Column '$field' holds '$text', which is not readable as $kind",
        parameters: {"attribute": field, "value": text},
        rootException: error,
        stack: stack,
      );
    }
  }

  /// Reads [field] from [row] as a Dart `double`, parsing its text.
  ///
  /// Parsing the text rather than asking a driver to widen is deliberate:
  /// `DECIMAL` — the right type for money, and what `SUM`/`AVG` over an integer
  /// column return — is outside the MariaDB client's conversion whitelist, and
  /// its exact text form parses losslessly.
  double? _readDouble(TomSqlRow row, String field) {
    final text = row.text(field);
    if (text == null) return null;
    final value = double.tryParse(text);
    if (value == null) {
      throw datasourceException(
        "error.result_processing.not_a_double",
        "Column '$field' holds '$text', which is not readable as a double",
        parameters: {"attribute": field, "value": text},
      );
    }
    return value;
  }

  /// Reads [field] from [row] as a Dart `int`.
  ///
  /// An exact integral value is read — `DECIMAL(n,0)` included, which is an
  /// exact integer type — and a value with a fractional part is refused by
  /// name rather than silently truncated: reading `DECIMAL(10,2)` into an `int`
  /// and dropping the cents turns a modelling mistake into wrong money.
  int? _readInt(TomSqlRow row, String field) {
    final text = row.text(field);
    if (text == null) return null;
    final direct = int.tryParse(text);
    if (direct != null) return direct;
    final asDouble = double.tryParse(text);
    if (asDouble == null) {
      throw datasourceException(
        "error.result_processing.not_an_int",
        "Column '$field' holds '$text', which is not readable as an int",
        parameters: {"attribute": field, "value": text},
      );
    }
    if (asDouble != asDouble.truncateToDouble()) {
      throw datasourceException(
        "error.result_processing.fractional_int",
        "Column '$field' holds the fractional value '$text' but is mapped to "
            "an int. Reading it would silently discard the fraction; declare "
            "the field as a double, or the column as an integer type.",
        parameters: {"attribute": field, "value": text},
      );
    }
    return asDouble.toInt();
  }

  /// Maps one [row] of a grouped result into a [TomGroupedRow], reading each
  /// alias in [projection] as the Dart type the query declared for it.
  ///
  /// The projection is the only type information available: a grouped row has
  /// no entity class, so the query's own declaration of "this alias is an
  /// `int`" is what makes the read typed.
  TomGroupedRow mapGroupedRow(TomSqlRow row, Map<String, Type> projection) {
    final values = <String, Object?>{};
    for (final entry in projection.entries) {
      final alias = entry.key;
      switch (entry.value) {
        case int:
          values[alias] = _readInt(row, alias);
        case double:
          values[alias] = _readDouble(row, alias);
        case String:
          values[alias] = row.text(alias);
        case bool:
          values[alias] = row.boolean(alias);
        case DateTime:
          values[alias] = _readInstant(row, alias);
        default:
          throw datasourceException(
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
    tomLog.trace("$driverLabel executing SQL: $T $resultType $command");
    _refuseMultipleStatements(command, "executeQuery");
    // The rows are mapped after the connection is handed back: mapping a
    // `@TomReference` column runs a query of its own, which must not need a
    // second connection while this one is still held.
    final result = await withLink(
      "executeQuery",
      statement: command,
      (link) => runChecked<TomSqlResult>(
        () => runCommandOn(link, command, tomSqlBindParams(params)),
        (e, StackTrace s) {
          tomLog.warn("Error when executing SQL: $e");
          return datasourceException(
            "error.failed-to-execute.exception",
            "$driverLabel: execution of $command with $params failed. $e",
            parameters: {...?params, "command": command, "type": resultType},
            rootException: e,
            stack: s,
          );
        },
      ),
    );
    return mapSqlResult<T>(result, resultType);
  }

  /// Maps [result] onto a list of [T], choosing between the five row shapes a
  /// result can land on.
  ///
  /// Which branch a result takes is determined entirely by what [resultType]
  /// (or [T]) declares:
  ///
  /// 1. a **grouped row**, when [groupedProjection] is non-null — there is no
  ///    class to reflect, so the query's own projection supplies the types;
  /// 2. a **table-less [TomClass]**, bound by observable member name;
  /// 3. an **annotated [TomClass]**, bound by `@TomDbColumn` name;
  /// 4. a **plain reflected holder** with no `@TomDbTable`, bound by declared
  ///    field name — the shape an aggregate query lands on;
  /// 5. an **annotated entity**, bound by its persistent column list.
  ///
  /// Nothing here needs a server: every branch reads column text. Only a
  /// `@TomReference` column reaches back to the database, and only after a
  /// row's own columns are set — which is what lets the row-shape decision be
  /// tested without one.
  Future<List<T>> mapSqlResult<T extends Object>(
    TomSqlResult result, [
    Type? resultType,
    Map<String, Type>? groupedProjection,
  ]) async {
    Type rType = resultType ?? T;
    if (groupedProjection != null) {
      return [
        for (final row in result.rows)
          mapGroupedRow(row, groupedProjection) as T,
      ];
    }
    // The one shape no driver can map: a result type the reflector does not
    // hold. Every branch below reaches the class through a mirror, so the
    // refusal belongs here, at the step that needs the mirror.
    final TypeMirror typeMirror;
    try {
      typeMirror = tomReflector.reflectType(rType);
    } on NoSuchCapabilityError catch (error, stack) {
      throw datasourceException(
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
      throw datasourceException(
        "error.result_processing.unsuitable_class",
        "$rType is registered with tomReflector but is not a class "
            "(${typeMirror.runtimeType}), so no result row can be mapped onto "
            "it.",
        parameters: {"type": "$rType"},
      );
    }
    final ClassMirror classMirror = typeMirror;
    final mapped = <T>[];
    Object testObject = classMirror.newInstance("", []);
    if (testObject is TomClass &&
        TomAnnotationAnalyzer.findTable(rType) == null) {
      for (var row in result.rows) {
        final rowResult =
            _instantiate(
                  classMirror,
                  "error.result_processing_tcp.failed_to_instantiate_row",
                )
                as TomClass;
        for (var entry in rowResult.getMembers().entries) {
          if (result.hasColumn(entry.key)) {
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
        mapped.add(rowResult as T);
      }
    } else if (testObject is TomClass) {
      for (var row in result.rows) {
        final rowResult =
            _instantiate(
                  classMirror,
                  "error.result_processing_tc.failed_to_instantiate_row",
                )
                as TomClass;
        for (var col in TomAnnotationAnalyzer.analysePersistentType(
          rType,
        ).columnInfo) {
          if (result.hasColumn(col.field)) {
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
        mapped.add(rowResult as T);
      }
    } else if (TomAnnotationAnalyzer.findTable(rType) == null) {
      // A plain reflected result holder with no @TomDbTable (e.g.
      // TomCountResult), mapped by plain field name.
      for (var row in result.rows) {
        final rowResult = _instantiate(
          classMirror,
          "error.result_processing_field.failed_to_instantiate_row",
        );
        InstanceMirror im = tomReflector.reflect(rowResult);
        for (var dEntry in classMirror.declarations.entries) {
          if (dEntry.value is! VariableMirror) continue;
          final VariableMirror dm = dEntry.value as VariableMirror;
          final String fieldName = dEntry.key;
          if (!result.hasColumn(fieldName)) continue;
          switch (dm.reflectedType) {
            case int:
              im.invokeSetter(dm.simpleName, _readInt(row, fieldName));
            case double:
              im.invokeSetter(dm.simpleName, _readDouble(row, fieldName));
            case String:
              im.invokeSetter(dm.simpleName, row.text(fieldName));
            case bool:
              im.invokeSetter(dm.simpleName, row.boolean(fieldName));
            case DateTime:
              im.invokeSetter(dm.simpleName, _readInstant(row, fieldName));
            default:
              throw datasourceException(
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
        mapped.add(rowResult as T);
      }
    } else {
      // The annotated entity: reflectable and carrying a @TomDbTable.
      final persistentColumns = TomAnnotationAnalyzer.analysePersistentType(
        rType,
      ).columnInfo;
      // Field-level encryption: a raw read maps stored values as they are;
      // otherwise the data keys the result's ciphertexts name are loaded first,
      // so every value below decrypts without waiting.
      final raw = TomFieldEncryption.isRaw;
      final encrypted = [
        for (final col in persistentColumns)
          if (col.encrypted != null && result.hasColumn(col.field)) col,
      ];
      if (!raw && encrypted.isNotEmpty) {
        await TomFieldEncryption.prepareRead([
          for (final row in result.rows)
            for (final col in encrypted) row.text(col.field),
        ]);
      }
      for (var row in result.rows) {
        // Per row: the stack is drained at the end of this iteration.
        final refStack = <_PendingReference>[];
        final rowResult = _instantiate(
          classMirror,
          "error.result_processing.failed_to_instantiate_row",
        );
        InstanceMirror im = tomReflector.reflect(rowResult);
        for (var col in persistentColumns) {
          VariableMirror dm =
              classMirror.declarations[col.declaredName] as VariableMirror;
          if (col.reference != null) {
            // A raw read is a maintenance read of the row's own columns.
            if (raw) continue;
            // Deferred: the reference query binds values from this row, so it
            // can only run once every other field has been set.
            refStack.add((column: col, owner: classMirror, field: dm, row: im));
            continue;
          }
          // A column the result does not carry is skipped, as it is on all four
          // shapes above: a projection selecting a subset of an entity's
          // columns is an ordinary query.
          if (!result.hasColumn(col.field)) continue;
          switch (dm.reflectedType) {
            case int:
              im.invokeSetter(dm.simpleName, _readInt(row, col.field));
            case double:
              im.invokeSetter(dm.simpleName, _readDouble(row, col.field));
            case String:
              final text = row.text(col.field);
              im.invokeSetter(
                dm.simpleName,
                col.encrypted != null && !raw
                    ? TomFieldEncryption.decrypt(col, text)
                    : text,
              );
            case bool:
              im.invokeSetter(dm.simpleName, row.boolean(col.field));
            case DateTime:
              im.invokeSetter(dm.simpleName, _readInstant(row, col.field));
            // The two halves a timestamp splits into. Both are `DateTime`
            // subclasses, so neither reaches the case above — a switch on
            // `reflectedType` matches the declared type exactly.
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
                    throw datasourceException(
                      "error.result_processing.failed_custom_conversion",
                      "Conversion using provided converter failed: ${dm.reflectedType} for member ${dm.simpleName} in $classMirror: $e",
                      parameters: {
                        "type": classMirror.reflectedType,
                        "attribute": col.declaredName,
                        "attributeType": dm.reflectedType,
                        "value": row.text(col.field),
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
                    String? stringValue = row.text(col.field);
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
                    throw datasourceException(
                      "error.result_processing.failed_json_conversion",
                      "Conversion from json failed: ${dm.reflectedType} for member ${dm.simpleName} in $classMirror: $e",
                      parameters: {
                        "type": classMirror.reflectedType,
                        "attribute": col.declaredName,
                        "attributeType": dm.reflectedType,
                        "json": row.text(col.field),
                      },
                      stack: s,
                      rootException: e,
                    );
                  }
                }
              }
              throw datasourceException(
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
        mapped.add(rowResult as T);
      }
    }
    return mapped;
  }

  /// A new instance of [classMirror]'s class, or the refusal keyed [key].
  Object _instantiate(ClassMirror classMirror, String key) {
    try {
      return classMirror.newInstance("", []);
    } catch (exception) {
      throw datasourceException(
        key,
        "Failed to instantiate result row instance of type ${classMirror.reflectedType}, error: $exception",
        parameters: {"type": classMirror.reflectedType},
      );
    }
  }

  TomDbType _getColumnValue(TomSqlRow row, String field, Type? colType) {
    if (colType == null || colType == TomDbString) {
      return TomDbString.of(row.text(field));
    } else if (colType == TomDbInt) {
      return TomDbInt(_readInt(row, field));
    } else if (colType == TomDbDouble) {
      return TomDbDouble(_readDouble(row, field));
    } else if (colType == TomDbBool) {
      return TomDbBool(row.boolean(field));
    } else if (colType == TomDbDateTime) {
      return _readTemporal(row, field, TomDbDateTime.of);
    } else if (colType == TomDbDate) {
      return _readTemporal(row, field, TomDbDate.of);
    } else if (colType == TomDbTime) {
      return _readTemporal(row, field, TomDbTime.of);
    }
    throw datasourceException(
      "error.result_processing.unknown_type_dbtype_conversion",
      "Unexpected and unsupported col type $colType for $field",
      parameters: {"type": colType, "attribute": field},
    );
  }

  /// Fills each pending association in [refStack] by running its reference
  /// query and writing the results into the row that owes it.
  ///
  /// This is the whole implementation of `@TomReference`: [mapSqlResult]
  /// cannot read an association while mapping a row — the query binds values
  /// from that same row — so it stacks the reference columns and calls this
  /// once the row's own columns are set.
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
      final types = [
        column.reference!.targetEntity,
        column.reference!.joinEntity,
      ];
      try {
        TomQuerySentenceCompiler tsc = runCheckedSync<TomQuerySentenceCompiler>(
          () => TomQuerySentenceCompiler(types),
          (e, s) {
            var msg =
                "Failed to create TomQuerySentenceCompiler for types $types when setting field ${vm.simpleName}";
            tomLog.error(msg);
            return datasourceException(
              "error.result_processing.ref_qsc_creation_failed",
              msg,
              parameters: {"types": types, "attribute": vm.simpleName},
              stack: s,
              rootException: e,
              autoLog: true,
            );
          },
        );
        TomSelect ts = runCheckedSync<TomSelect>(
          () => tsc.compileQuerySentence(query) as TomSelect,
          (e, s) => datasourceException(
            "error.result_processing.ref_query_compilation_failed",
            "Failed to compile query $query to TomSelect. $e",
            parameters: {
              "types": types,
              "attribute": vm.simpleName,
              "query": query,
            },
            stack: s,
            rootException: e,
            autoLog: true,
          ),
        );
        String queryString = runCheckedSync<String>(
          () => ts.generateQuery(sqlDialect),
          (e, s) => datasourceException(
            "error.result_processing.ref_query_generation_failed",
            "Failed to generate SQL from TomSelect $ts. $e",
            parameters: {
              "types": types,
              "attribute": vm.simpleName,
              "query": query,
            },
            stack: s,
            rootException: e,
            autoLog: true,
          ),
        );
        List result = await runChecked<List>(
          () async => (await executeQuery<Object>(
            queryString,
            referenceQueryParams,
            column.reference!.targetEntity,
          )).toList(),
          (e, s) => datasourceException(
            "error.result_processing.ref_query_execution_failed",
            "Failed to execute query",
            parameters: {
              "types": types,
              "attribute": vm.simpleName,
              "query": query,
            },
            stack: s,
            rootException: e,
            autoLog: true,
          ),
        );
        // Fill the list the entity already holds rather than assigning a fresh
        // one: the declared type is `List<Target>`, and reflection cannot build
        // that instantiation. Hence the requirement below that a reference
        // field be non-null and modifiable.
        List? value = im.invokeGetter(vm.simpleName) as List?;
        if (value == null) {
          throw datasourceException(
            "error.result_processing.ref_reference_field_must_have_non-null_value",
            "Reference field has null value. Reference fields must be non-nullable and have modifiable values",
            parameters: {
              "types": types,
              "attribute": vm.simpleName,
              "field": column.field,
              "query": query,
            },
            autoLog: true,
          );
        }
        value.clear();
        try {
          for (var r in result) {
            value.add(r);
          }
        } catch (e, s) {
          throw datasourceException(
            "error.result_processing.ref_failed_adding_result_to_value",
            "Failed to add result values to List ${vm.simpleName} $result $e",
            parameters: {
              "types": types,
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
          throw datasourceException(
            "error.result_processing.ref_failed_invoke_setter",
            "Failed to set updated list value in result instance ${vm.simpleName} $result $e",
            parameters: {
              "types": types,
              "attribute": vm.simpleName,
              "field": column.field,
              "query": query,
            },
            stack: s,
            rootException: e,
            autoLog: true,
          );
        }
      } catch (e, s) {
        if (e is TomSqlDatasourceException) rethrow;
        throw datasourceException(
          "error.result_processing.ref_failed_unexpected",
          "Failed to get and update referenced values: $e ${vm.simpleName}",
          parameters: {
            "types": types,
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

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  /// Binds [settings] onto this driver's fields and opens the connection.
  ///
  /// [settings] is the datasource block minus the keys the registry reads
  /// itself (`TomDataSourceInfo.registryKeys`), and every key in it has already
  /// been checked against this class's fields — a block with a misspelling in
  /// it never reaches this method.
  @override
  Future<void> initialize(Map<String, dynamic> settings) async {
    final own = <String, dynamic>{...settings}..remove('replicas');
    final normalized = normalizeSettings(own);
    bindSettings(normalized);
    replicas = _replicaSettings(settings['replicas']);
    _ownSettings = normalized;
    await connect();
  }

  /// The settings this data source was initialized with, which a replica
  /// starts from; `null` when its fields were set directly.
  Map<String, dynamic>? _ownSettings;

  /// [raw], the `replicas` setting, as a list of settings maps.
  List<Object?> _replicaSettings(Object? raw) {
    if (raw == null) return const [];
    if (raw is List && raw.every((r) => r is Map)) return List.of(raw);
    throw datasourceException(
      "error.initialize.invalid_replicas",
      "$driverLabel: `replicas` is a list of settings maps, one per replica; "
          "got ${raw.runtimeType}.",
      parameters: {"replicas": '$raw'},
    );
  }

  /// Binds [settings] onto this driver's fields by reflection.
  @protected
  void bindSettings(Map<String, dynamic> settings);

  /// The settings a driver binds to `int` fields: the port, the connect
  /// timeout and the six pool settings.
  static const Set<String> integerSettings = {
    'port',
    'timeOut',
    'replicaStickinessMs',
    'replicaRetryMs',
    'poolMaxSize',
    'poolMinIdle',
    'poolAcquireTimeoutMs',
    'poolIdleTimeoutMs',
    'poolMaxLifetimeMs',
    'poolValidateAfterIdleMs',
  };

  /// Returns [settings] with every [integerSettings] value given as a string
  /// folded to an `int`.
  ///
  /// Application config may express these either as ints or as strings — an
  /// environment substitution (`port: ${DB_PORT:3306}`) always yields a
  /// string. The port is parsed by [parseConfiguredPort] and keeps its own error key;
  /// every other value that is not an integer throws
  /// `error.initialize.invalid_integer` naming its key.
  @protected
  Map<String, dynamic> normalizeSettings(Map<String, dynamic> settings) {
    final folded = <String, dynamic>{};
    for (final key in integerSettings) {
      final raw = settings[key];
      if (raw is! String) continue;
      folded[key] = key == 'port'
          ? parseConfiguredPort(raw)
          : _parseInteger(key, raw);
    }
    return folded.isEmpty
        ? settings
        : <String, dynamic>{...settings, ...folded};
  }

  /// Parses a configured port value into the `int` the driver binds.
  ///
  /// Accepts an `int` verbatim or a `String` holding an integer literal;
  /// anything else throws `error.initialize.invalid_port`.
  @protected
  int parseConfiguredPort(Object? raw) {
    if (raw is int) return raw;
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null) return parsed;
    }
    throw datasourceException(
      "error.initialize.invalid_port",
      "$driverLabel: configured port '$raw' is not a valid integer.",
      parameters: {"port": raw},
    );
  }

  int _parseInteger(String key, String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed != null) return parsed;
    throw datasourceException(
      "error.initialize.invalid_integer",
      "$driverLabel: configured $key '$raw' is not a valid integer.",
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
    final result = await withLink(
      "executeCommand",
      (link) => runChecked<TomSqlResult>(
        () => runCommandOn(link, command, tomSqlBindParams(params)),
        (e, s) => datasourceException(
          "error.result_processing.executecommand_failed",
          "ExecuteCommand $command failed: $e",
          parameters: {...?params, "command": command},
          rootException: e,
          stack: s,
          autoLog: true,
        ),
      ),
    );
    return BigInt.from(result.affectedRows);
  }

  /// Closes the pool and lets go of it.
  ///
  /// Idle connections are closed at once; a connection still lent — to a
  /// transaction or a running statement — is closed when it is handed back.
  /// The pool is cleared so that a closed data source reads as closed, and
  /// refuses statements, rather than reopening on the next one. A data source
  /// that was never opened has nothing to release, so closing it changes
  /// nothing and leaves it reading as never opened.
  @override
  Future<void> close() async {
    final pool = _pool;
    if (pool == null) {
      tomLog.warn(
        "$driverLabel NOT closing $host:$port/$databaseName: it is not open.",
      );
      return;
    }
    tomLog.info("$driverLabel closing $host:$port/$databaseName");
    _pool = null;
    _wasClosed = true;
    _poolObservation?.cancel();
    _poolObservation = null;
    await pool.close();
    for (final replica in _replicaSources) {
      if (replica._pool != null) await replica.close();
    }
    _replicaSources.clear();
    _replicaDownUntil.clear();
  }

  @override
  String toString() =>
      "$driverLabel $host:$port/$databaseName ${_stateDescription()}";

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
  /// which is deliberate: a transaction wants the *resource* enlisted once, and
  /// `TomTransaction.registerParticipant` refuses a second enlistment with
  /// `…duplicate_id` rather than dropping it, because a dropped connection's
  /// writes are neither committed with the transaction nor rolled back with it.
  @override
  String getParticipantId() => "$participantPrefix-$databaseName@$host:@$port";

  // ---------------------------------------------------------------------------
  // Transactions
  // ---------------------------------------------------------------------------

  /// Each running transaction's share of this data source, by transaction.
  ///
  /// A transaction is a property of a *connection*, so each transaction this
  /// data source is enlisted in has a connection of its own, pinned here from
  /// its first statement to [endTransaction].
  final Map<TomTransaction, TomSqlBranch> _branches = HashMap.identity();

  /// [transaction]'s branch on this data source, or `null`.
  @protected
  TomSqlBranch? branchOf(TomTransaction transaction) => _branches[transaction];

  /// Issues one of [transaction]'s own lifecycle statements on its pinned
  /// connection, without enlisting anything.
  ///
  /// Routed through [executeCommand] rather than around it, so there stays one
  /// way a command reaches a connection.
  @protected
  Future<BigInt> lifecycle(TomTransaction transaction, String command) =>
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
    TomSqlLink link;
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
        if (link.connected) await closeLink(link);
      } catch (_) {}
    }
  }

  /// Refuses a second start of a transaction this data source is already in.
  ///
  /// Thrown rather than reported as `false`: a `START TRANSACTION` the database
  /// refuses is a failure the caller may retry, while starting the same
  /// transaction twice is the caller's own mistake, and no retry fixes it.
  /// [transactionId] names the two-phase branch already open where there is
  /// one.
  @protected
  Never refuseNestedTransaction([String? transactionId]) {
    throw datasourceException(
      "error.transaction.already_active",
      "$driverLabel ${getParticipantId()} is already in this "
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
  /// The read-only form is what makes the flag mean something: the server
  /// refuses every write on this connection until the transaction ends. The
  /// coordinator cannot enforce it — it has no idea what a write is — so the
  /// resource that can is the only place it can be enforced.
  @override
  Future<bool> startTransaction(TomTransaction transaction) async {
    final existing = _branches[transaction];
    if (existing != null && existing.active) refuseNestedTransaction();
    final branch = openBranch(transaction, existing);
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
        "Starting database transaction of ${getParticipantId()} failed $error",
      );
      await abandonStart(transaction, branch, existing);
      return false;
    }
  }

  /// The branch [transaction] starts on: [existing], when the transaction ran
  /// on this data source before and was concluded, keeping its connection —
  /// otherwise a new one.
  @protected
  TomSqlBranch openBranch(TomTransaction transaction, TomSqlBranch? existing) {
    final branch = existing ?? TomSqlBranch();
    if (existing != null) branch.started = Completer<bool>();
    _branches[transaction] = branch;
    return branch;
  }

  /// Undoes a start that failed: a new branch is forgotten with its connection,
  /// since no conclusion will ever release it; a reused one is left as it was.
  @protected
  Future<void> abandonStart(
    TomTransaction transaction,
    TomSqlBranch branch,
    TomSqlBranch? existing,
  ) async {
    branch.active = false;
    if (!branch.started.isCompleted) branch.started.complete(false);
    if (existing == null) await _endBranch(transaction);
  }

  /// Ends this participant's part of [transaction] by handing its connection
  /// back to the pool; always succeeds.
  ///
  /// The coordinator calls this on every participant after either conclusion,
  /// which is what makes it the place a transaction's connection is returned.
  /// Reporting `true` is not a formality: the coordinator ands every
  /// participant's result into the outcome.
  @override
  Future<bool> endTransaction(TomTransaction transaction) async {
    await _endBranch(transaction);
    return true;
  }

  /// Phase one for a resource that has no phase one: always `true`.
  ///
  /// A one-phase transaction has no statement that makes the commit certain
  /// without performing it. That is the cost of enlisting it beside a two-phase
  /// participant: the transaction is atomic unless *this* participant's commit
  /// fails, at which point the peers that prepared have already committed. A
  /// deployment that needs the full guarantee uses the driver's two-phase
  /// variant for every participant.
  @override
  Future<bool> prepare(TomTransaction transaction) async => true;

  @override
  Future<bool> commit(TomTransaction transaction) async {
    try {
      await lifecycle(transaction, commitStatement);
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
  /// connection issued are neither committed nor rolled back.
  @override
  Future<bool> rollback(TomTransaction transaction) async {
    try {
      await lifecycle(transaction, rollbackStatement);
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

/// Tells the pool how to open, close and check a [TomSqlDatasource]'s
/// connections.
class _LinkFactory implements TomConnectionFactory<TomSqlLink> {
  _LinkFactory(this.datasource);

  final TomSqlDatasource datasource;

  @override
  Future<TomSqlLink> open() => datasource._openLinkRecorded();

  @override
  Future<void> close(TomSqlLink link) async {
    if (!link.connected) return;
    await datasource.closeLink(link);
  }

  @override
  bool isUsable(TomSqlLink link) => link.connected;

  @override
  Future<bool> validate(TomSqlLink link) => datasource.validateLink(link);
}

/// A process-unique two-phase branch id for a data source at [databaseName],
/// [host] and [port]: `<database>@<host>:<port>_<process>_<time>_<counter>`,
/// at most [maxBytes] long.
///
/// Bounded and unique, in that order of necessity: both servers refuse an
/// over-long transaction id, so an id built from the coordinates as written
/// makes every two-phase transaction fail to start once a real hostname is
/// long enough. The unique tail is always kept whole and the readable head is
/// what gets truncated — a shortened name still tells an operator reading the
/// list of prepared transactions whose branch it is, while a shortened tail
/// could name two branches alike. Characters outside `[A-Za-z0-9_.@:-]`
/// become `_`, which keeps the id single-byte and safe to quote.
String tomSqlBranchId({
  required String databaseName,
  required String host,
  required int port,
  required String processTag,
  required int counter,
  required int maxBytes,
}) {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final tail = '_${processTag}_${time}_${counter.toRadixString(36)}';
  final head = '$databaseName@$host:$port'.replaceAll(
    RegExp(r'[^A-Za-z0-9_.@:-]'),
    '_',
  );
  final room = maxBytes - tail.length;
  return (head.length > room ? head.substring(0, room) : head) + tail;
}

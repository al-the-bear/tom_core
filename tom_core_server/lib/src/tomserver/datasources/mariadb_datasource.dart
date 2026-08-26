// ignore_for_file: type_literal_in_constant_pattern
import 'package:mysql_client/mysql_client.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import '../object_persistence/grouped_query.dart';
import '../object_persistence/persistence_annotations.dart';
import '../object_persistence/query_sentence_compiler.dart';
import '../object_persistence/annotation_analyzer.dart';

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

/// A MariaDB-backed [TomPreparedStatement]: wraps a server-side `PreparedStmt`,
/// the ordered [parameterList] its placeholders expect, the owning
/// [datasource], and the optional [resultType] used to map result rows.
class MariadbPreparedStatement<T extends Object>
    extends TomPreparedStatement<T> {
  /// The data source that prepared and runs this statement.
  final MariaDbDatasource datasource;

  /// The live server-side prepared statement handle (replaced on reconnect).
  PreparedStmt preparedStmt;

  /// The placeholder names in positional order, mapping `params` to `?` slots.
  final List<String> parameterList;

  /// The type result rows are mapped to (defaults to `T`).
  final Type? resultType;

  /// The compiled SQL command (kept so the statement can be re-prepared).
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

  /// Wraps the prepared [preparedStmt] with its [parameterList], owning
  /// [datasource], [resultType] and original [command].
  MariadbPreparedStatement(
    this.preparedStmt,
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

  @override
  Future<List<T>> execute([Map<String, Object?>? params]) async {
    final List<Object?> parameters = buildPositionalParameters(
      parameterList,
      params,
    );
    try {
      IResultSet result = await _execute(parameters, params);
      _captureExecuteResult(result);
      return datasource._processResult<T>(
        result,
        resultType,
        groupedProjection,
      );
    } on MariadbPreparedStatementException {
      // One retry, on the link the data source re-opens. Routed through the
      // same helper as the entry points so the lifecycle rule has a single
      // implementation — a statement whose data source has since been torn down
      // is refused here for the same reason and with the same error.
      final link = await datasource._openConnection("prepared-statement retry");
      preparedStmt = await link.prepare(command);
      IResultSet result = await _execute(parameters, params);
      _captureExecuteResult(result);
      return datasource._processResult<T>(
        result,
        resultType,
        groupedProjection,
      );
    }
  }

  Future<IResultSet> _execute(
    List<Object?> parameters,
    Map<String, Object?>? params,
  ) async {
    return await runChecked<IResultSet>(
      () async => await preparedStmt.execute(parameters),
      (e, StackTrace s) {
        tomLog.warn("Error when executing SQL: $e");
        // The exception type this returns *is* the retry signal: [execute]
        // catches MariadbPreparedStatementException and nothing else.
        if (isLostConnectionFailure(e, connected: datasource.connected)) {
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
            "connected": datasource.connected,
          },
          rootException: e,
          stack: s,
        );
      },
    );
  }

  @override
  Future<void> deallocate() async {
    await preparedStmt.deallocate();
  }
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
/// integer encoding; a [DateTime] becomes its UTC `DATETIME(6)` text; every
/// other value is bound as-is.
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
/// [databaseName], [timeOut]) are filled from the configuration map by
/// reflection in [initialize], which then opens the [connection]. The driver
/// implements the full data-source surface — [prepareStatement], [executeQuery]
/// (with reflection-based row→object mapping), [executeCommand] — and
/// participates in transactions via plain `START TRANSACTION` / `COMMIT` /
/// `ROLLBACK` (see [MariaDbXADatasource] for the XA variant).
///
/// ## Connection lifecycle
///
/// **A data source is opened explicitly, and never by the statement that wants
/// to run.** Opening it means either [initialize], which binds the settings and
/// connects, or setting the connection fields and calling [connect] — the two
/// forms the package documents. Every execution entry point
/// ([prepareStatement], [executeQuery], [executeCommand]) then requires an open
/// connection and throws a [MariadbDatasourceException] if it is reached before
/// one exists, so all three behave the same way on the same data source.
///
/// Opening on demand is not offered because it could not work: [connect] binds
/// [host], [port] and the credentials, and until they are configured it would
/// dial `:-1` — turning "never opened" into "the database is unreachable".
///
/// A link that *was* opened and has since dropped is a separate case, and is
/// re-opened automatically: the settings are known, so every entry point
/// reconnects and carries on.
///
/// [close] releases the link **and lets go of it**, which puts the data source
/// back to not-open: a closed data source refuses statements exactly as one
/// that was never opened does, rather than being silently re-opened by the next
/// one to arrive. Deliberate teardown is not a dropped link. [isOperational]
/// and [connected] report the current state, and [toString] distinguishes the
/// two ways of holding no connection — `closed` from `never opened` — because
/// they point at different faults.
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

  /// The live MySQL connection (`null` until [connect] succeeds, and again once
  /// [close] has let go of it).
  MySQLConnection? connection;

  /// Whether [connection] is `null` because [close] released it, rather than
  /// because the data source was never opened.
  ///
  /// Only meaningful while [connection] is `null` — every reader checks that
  /// first — so re-opening does not clear it; it is simply not consulted again
  /// until the next [close] sets it anew.
  bool _wasClosed = false;

  /// Opens a connection using the configured settings.
  ///
  /// Throws a [MariadbDatasourceException] if the connection cannot be created
  /// or remains unconnected after the attempt.
  Future<void> connect() async {
    connection = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: username,
      password: password,
      databaseName: (databaseName).isEmpty ? null : databaseName,
    );
    if (connection != null) {
      await connection!.connect(timeoutMs: timeOut);
    } else {
      throw MariadbDatasourceException(
        "error.failed-to-connect.connect_failed",
        "MariadbDatasource: Failed to connect: createConnection() returned null result. This should be impossible.",
        parameters: {
          "host": host,
          "port": port,
          "userName": username,
          "databaseName": (databaseName).isEmpty ? null : databaseName,
        },
      );
    }
    if (!connection!.connected) {
      throw MariadbDatasourceException(
        "error.failed-to-connect.remained_unconnected",
        "MariadbDatasource: Failed to connect: connection remained unconnected.",
        parameters: {
          "host": host,
          "port": port,
          "userName": username,
          "databaseName": (databaseName).isEmpty ? null : databaseName,
        },
      );
    }
  }

  /// Whether the underlying connection is currently established.
  bool get connected => connection != null ? connection!.connected : false;

  /// The open connection to run [operation] on, re-opening a dropped link
  /// first.
  ///
  /// This is the one place the lifecycle rule stated in the class dartdoc is
  /// implemented, so that every execution entry point observes the same rule
  /// rather than each carrying its own guard.
  ///
  /// A [connection] of `null` means the data source is not open — never opened,
  /// or closed — and that is refused rather than repaired. Neither case is one
  /// a statement should quietly fix. Opening a never-opened data source here
  /// could not even work: [connect] binds [host], [port] and the credentials,
  /// which arrive only from [initialize] or a direct assignment, so before
  /// either it would dial `:-1` — reporting an unreachable database where the
  /// truth is an unconfigured one, and sending the reader to the network for a
  /// configuration bug. Re-opening a *closed* one could work, and that is
  /// precisely why it must not happen by accident: it would resurrect a data
  /// source the application deliberately let go.
  ///
  /// A link that *was* opened and has since dropped is the one case that is
  /// repaired: the settings are known, the caller never asked for the loss, and
  /// reconnecting is exactly what it wants.
  ///
  /// [operation] names the calling entry point and is carried in the thrown
  /// exception's parameters alongside the `state` that refused it, so a log
  /// identifies both which call ran too early and which of the two faults it
  /// met.
  Future<MySQLConnection> _openConnection(String operation) async {
    if (connection == null) {
      throw MariadbDatasourceException(
        "error.datasource.not_opened",
        "MariadbDatasource: $operation needs an open connection, but this data "
            "source ${_wasClosed ? "has been closed" : "has never been opened"}"
            ". Call initialize() with the connection settings, or set them and "
            "call connect().",
        parameters: {
          "operation": operation,
          "state": _wasClosed ? "closed" : "never_opened",
        },
      );
    }
    if (!connection!.connected) {
      await connect();
    }
    return connection!;
  }

  @override
  Future<TomPreparedStatement<T>> prepareStatement<T extends Object>(
    TomQuery query, [
    Type? resultType,
  ]) async {
    final link = await _openConnection("prepareStatement");
    final (q, params) = toPositionalStatement(query.generateQuery(sqlDialect));
    var preparedStmt = await link.prepare(q);
    return MariadbPreparedStatement<T>(
      preparedStmt,
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
  /// `replaceAll(":$p", "?")` — is essential (RCA5): `replaceAll` corrupts a
  /// placeholder that is a *prefix* of another (`:id` vs `:idx` → `?x`) and
  /// collapses a repeated name to a single slot, desynchronising every
  /// following bind value. The scan is also string-literal aware (RCC6), so a
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
        member.set(parseOptionalSqlInstant(row.typedColByName<String>(field)));
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
  /// return `NEWDECIMAL` too, which is how the gap was first found (CSEXD1).
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
          values[alias] = parseOptionalSqlInstant(
            row.typedColByName<String>(alias),
          );
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
    final link = await _openConnection("executeQuery");
    IResultSet qResult = await runChecked<IResultSet>(
      () async {
        return await link.execute(command, _toBindParams(params));
      },
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
    );
    return _processResult<T>(qResult, resultType);
  }

  Future<List<T>> _processResult<T extends Object>(
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
        for (final row in qResult.rows)
          mapGroupedRow(row, groupedProjection) as T,
      ];
    }
    ClassMirror classMirror =
        tomReflector.reflectType(resultType ?? T) as ClassMirror;
    List<T> result = [];
    Object testObject = classMirror.newInstance("", []);
    if (testObject is TomClass &&
        TomAnnotationAnalyzer.findTable(rType) == null) {
      // if this not an annotated TomClass
      for (var row in qResult.rows) {
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
      for (var row in qResult.rows) {
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
        for (var col in TomAnnotationAnalyzer.getPersistentColumns(rType)!) {
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
      for (var row in qResult.rows) {
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
              im.invokeSetter(
                dm.simpleName,
                parseOptionalSqlInstant(row.typedColByName<String>(fieldName)),
              );
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
    } else if (TomAnnotationAnalyzer.getPersistentColumns(rType) != null) {
      for (var row in qResult.rows) {
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
        for (var col in TomAnnotationAnalyzer.getPersistentColumns(rType)!) {
          VariableMirror dm =
              classMirror.declarations[col.declaredName] as VariableMirror;
          if (col.reference != null) {
            // Deferred: the reference query binds values from this row, so it
            // can only run once every other field has been set.
            refStack.add((column: col, owner: classMirror, field: dm, row: im));
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
              im.invokeSetter(
                dm.simpleName,
                parseOptionalSqlInstant(row.typedColByName<String>(col.field)),
              );
            default:
              if (col.column != null) {
                if (col.column!.fromDbConverter != null) {
                  try {
                    Object? value = col.column!.fromDbConverter!(
                      _getColumnValue(
                        row,
                        col.field,
                        col.column!.declaredColumnType(),
                      ),
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
                Type t = col.column!.declaredDartType() ?? dm.reflectedType;
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
    } else {
      throw MariadbDatasourceException(
        "error.result_processing.unsuitable_class",
        "Class ${classMirror.reflectedType} cannot be used for automatic processing of resultsets. It must either be TomClass or have persistence annotation and must be marked @tomReflector.",
        parameters: {"type": classMirror.reflectedType},
      );
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
      return TomDbDateTime.of(row.typedColByName<String>(field));
    } else if (colType == TomDbDate) {
      return TomDbDate.of(row.typedColByName<String>(field));
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
  /// This is the whole implementation of `@TomReference`: [_processResultSet]
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

  @override
  Future<void> initialize(Map<String, dynamic> settings) async {
    tomReflectionInfo.setValues<MariaDbDatasource>(
      this,
      normalizePort(settings),
    );
    await connect();
  }

  /// Returns [settings] with its `port` value normalized to an `int` (G-DB-3).
  ///
  /// The datasource binds `port` to an `int` field, but application config may
  /// express the port either as an int or as a string — e.g. an environment
  /// substitution (`port: ${DB_PORT:3306}`) always yields a string. This folds
  /// a string port to an int before reflection binding so both forms work. When
  /// `port` is absent or already an int the map is returned unchanged; when it
  /// is a string it is parsed via [parsePort].
  static Map<String, dynamic> normalizePort(Map<String, dynamic> settings) {
    final raw = settings['port'];
    if (raw is! String) return settings;
    return <String, dynamic>{...settings, 'port': parsePort(raw)};
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

  @override
  bool isOperational() {
    return connection != null && connection!.connected;
  }

  @override
  Future<BigInt> executeCommand(
    String command, [
    Map<String, dynamic>? params,
  ]) async {
    final link = await _openConnection("executeCommand");
    var qResult = await runChecked<IResultSet>(
      () async => await link.execute(command, _toBindParams(params)),
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
    );
    return qResult.affectedRows;
  }

  /// Closes the connection and lets go of it.
  ///
  /// [connection] is cleared whatever the link's state was, so that a closed
  /// data source reads as closed rather than as one holding a dead connection.
  /// That distinction is load-bearing: [_openConnection] repairs a *dropped*
  /// link, and a closed data source that still carried one would be silently
  /// re-opened by the next statement — resurrecting, on the shutdown path, a
  /// connection nothing would ever close again.
  ///
  /// A data source that was never opened has nothing to release, so closing it
  /// changes nothing and leaves it reading as never opened.
  @override
  Future<void> close() async {
    final link = connection;
    if (link == null) {
      tomLog.warn(
        "MariadbDatasource NOT closing $host:$port/$databaseName: it has no "
        "connection to release.",
      );
      return;
    }
    try {
      if (link.connected) {
        tomLog.info("MariadbDatasource closing $host:$port/$databaseName");
        await link.close();
      } else {
        tomLog.warn(
          "MariadbDatasource $host:$port/$databaseName had already lost its "
          "connection; releasing it without closing.",
        );
      }
    } finally {
      // In a finally because a close that failed still means the caller is done
      // with this link. Keeping the handle would leave the data source claiming
      // a connection that nothing can use.
      connection = null;
      _wasClosed = true;
    }
  }

  @override
  String toString() =>
      "MariadbDatasource $host:$port/$databaseName ${_stateDescription()}";

  /// How this data source describes its connection state: the link's own state
  /// while it holds one, and otherwise which of the two ways it came to hold
  /// none.
  String _stateDescription() {
    if (connection != null) return "connected: ${connection!.connected}";
    return _wasClosed ? "closed" : "never opened";
  }

  @override
  String getParticipantId() => "MariaDb-$databaseName@$host:@$port";

  bool _transactional = false;

  /// Refuses a transaction that would nest inside one already running.
  ///
  /// Shared by both lifecycles so the refusal cannot drift apart again — it is
  /// one programming error, reported one way, whichever data source hits it.
  /// [transactionId] names the branch already open where there is one; the
  /// plain lifecycle tracks a flag rather than an id, so it has nothing to
  /// name and omits the parameter.
  ///
  /// Thrown rather than reported as `false`, and *in front of* the `try` that
  /// turns a failed statement into `false`, because the two are not the same
  /// kind of event. A `START TRANSACTION` the database refuses is a failure
  /// the caller may retry or route around; a second start on a busy data
  /// source is the caller's own mistake, and no retry fixes it. Carrying that
  /// distinction is the whole reason for the module's own exception type: a
  /// caller that catches `Exception` to handle connection trouble would
  /// otherwise swallow this too, and never learn it has a bug.
  Never _refuseNestedTransaction([String? transactionId]) {
    throw MariadbDatasourceException(
      "error.transaction.already_active",
      "MariadbDatasource ${getParticipantId()} already has an active "
          "transaction${transactionId == null ? "" : " $transactionId"}. "
          "Conclude it with commit() or rollback() before starting another.",
      parameters: {
        "participant": getParticipantId(),
        if (transactionId != null) "transactionId": transactionId,
      },
    );
  }

  @override
  Future<bool> startTransaction() async {
    if (_transactional) _refuseNestedTransaction();
    try {
      await executeCommand("START TRANSACTION;");
      _transactional = true;
      return true;
    } catch (error) {
      tomLog.error(
        "Starting database transaction of ${getParticipantId()} failed $error",
      );
      return false;
    }
  }

  /// Ends this participant's part of a plain transaction: a no-op that always
  /// succeeds.
  ///
  /// A one-phase `START TRANSACTION` / `COMMIT` has no prepare step, so there
  /// is no statement to issue — the XA lifecycle's `XA END` + `XA PREPARE` has
  /// no plain equivalent (see [MariaDbXADatasource.endTransaction]). Nor is
  /// there per-transaction state left to release: [commit] and [rollback]
  /// clear the in-transaction flag themselves, and the coordinator always
  /// calls one of them before this.
  ///
  /// Reporting `true` is not a formality. The coordinator ands every
  /// participant's result into the outcome, so a `false` here would fail a
  /// transaction that had in fact completed.
  @override
  Future<bool> endTransaction() async => true;

  @override
  Future<bool> commit() async {
    try {
      await executeCommand("COMMIT;");
      _transactional = false;
      return true;
    } catch (error) {
      tomLog.error(
        "Committing database transaction of ${getParticipantId()} failed $error",
      );
      _transactional = false;
      return false;
    }
  }

  @override
  Future<void> rollback() async {
    try {
      await executeCommand("ROLLBACK;");
    } catch (error) {
      tomLog.error(
        "Rolling back database transaction of ${getParticipantId()} failed $error",
      );
    }
    _transactional = false;
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
/// The branch id doubles as the in-transaction guard: [startTransaction] throws
/// while one is set rather than opening a nested branch. **Every exit therefore
/// clears it except a successful [endTransaction]**, which hands it on to
/// [commit]. An exit that forgets locks this data source out of every later
/// transaction for good — and the caller cannot recover by rolling back,
/// because the branch it would have to name never began.
@tomReflector
@TomDatasourceDriver("mariadb_xa")
class MariaDbXADatasource extends MariaDbDatasource {
  String? _txId;

  @override
  Future<bool> startTransaction() async {
    if (_txId != null) _refuseNestedTransaction(_txId);
    _txId = "'${databaseName}_${host}_${port}_${DateTime.now()}'";
    try {
      await executeCommand("XA START $_txId;");
      return true;
    } catch (error) {
      tomLog.error(
        "Starting XA database transaction of ${getParticipantId()} failed $error",
      );
      // The id is assigned before the command is issued, so a failure here
      // leaves a branch that exists only in this field — the database never
      // opened it. Holding it wedges the data source: the guard above refuses
      // every later transaction, and the caller cannot clear it by rolling
      // back, because it was just told the transaction did not begin.
      _txId = null;
      return false;
    }
  }

  @override
  Future<bool> endTransaction() async {
    try {
      await executeCommand("XA END $_txId; XA PREPARE $_txId;");
      return true;
    } catch (error) {
      tomLog.error(
        "Ending XA database transaction of ${getParticipantId()} failed $error",
      );
      // The branch can no longer be committed after a failed end/prepare; clear
      // it so a new transaction can start instead of wedging the data
      // source. On success `_txId` is kept — `commit` still needs it.
      _txId = null;
      return false;
    }
  }

  @override
  Future<bool> commit() async {
    try {
      await executeCommand("XA COMMIT $_txId;");
      _txId = null;
      return true;
    } catch (error) {
      tomLog.error(
        "Committing XA database transaction $_txId of ${getParticipantId()} failed $error",
      );
      _txId = null;
      return false;
    }
  }

  @override
  Future<void> rollback() async {
    try {
      await executeCommand("XA ROLLBACK $_txId;");
    } catch (error) {
      tomLog.error(
        "Rolling back XA database transaction of ${getParticipantId()} failed $error",
      );
    } finally {
      // Always clear the branch id — even on a failed rollback — so the next
      // startTransaction is allowed. Leaving it set wedges the data source after
      // its first rolled-back transaction.
      _txId = null;
    }
  }
}

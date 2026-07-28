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

/// Thrown when a MariaDB prepared statement fails (e.g. a closed connection),
/// signalling that a single reconnect-and-retry may recover it.
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

  /// The auto-increment key the most recent [execute] generated, taken from the
  /// insert's own result set (`0` from the driver means "no generated key" and
  /// surfaces here as `null`, since a real AUTO_INCREMENT value is never 0).
  @override
  int? get lastGeneratedId => _lastGeneratedId;

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

  /// Records the generated key from an execute's [result].
  void _captureGeneratedId(IResultSet result) {
    _lastGeneratedId = normalizeGeneratedId(result.lastInsertID);
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
  /// `"NULL"` and a string would carry literal quote characters (bug §65).
  ///
  /// A [TomDbType] box is the one value that is *not* bound raw: it is the SQL
  /// representation a column's `toDbConverter` produces (e.g. an enum mapped to
  /// a `TomDbString`), and the driver only understands primitives. Binding the
  /// box directly would marshal it through its `toString()` —
  /// `"TomDbType TomDbString full"` — which the server rejects (an `ENUM`
  /// column truncates it to `''`, error 1265; bug §70). Unwrapping the box to
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

  /// Marshals one bind [value] into a driver primitive: a [TomDbType] box is
  /// unwrapped to the Dart value it holds; a Dart `bool` becomes its MariaDB
  /// integer encoding; every other value is bound as-is.
  ///
  /// MariaDB has no native boolean type — `BOOLEAN` is an alias for
  /// `TINYINT(1)` stored as `1`/`0`. The driver serializes a bound Dart `bool`
  /// as the *string* `'true'`/`'false'`, which the server rejects for an
  /// integer column ("Incorrect integer value: 'false'", error 1366; bug §72).
  /// Translating `bool`→`int` here keeps that kernel→driver mapping at the
  /// single data-source boundary that already owns the [TomDbType] unwrap.
  static Object? _toBindValue(Object? value) {
    final unwrapped = value is TomDbType ? value.get() : value;
    if (unwrapped is bool) return unwrapped ? 1 : 0;
    return unwrapped;
  }

  @override
  Future<List<T>> execute([Map<String, Object?>? params]) async {
    final List<Object?> parameters = buildPositionalParameters(
      parameterList,
      params,
    );
    try {
      IResultSet result = await _execute(parameters, params);
      _captureGeneratedId(result);
      return datasource._processResult<T>(
        result,
        resultType,
        groupedProjection,
      );
    } on MariadbPreparedStatementException {
      // One retry...
      if (!datasource.connected) {
        await datasource.connect();
      }
      preparedStmt = await datasource.connection!.prepare(command);
      IResultSet result = await _execute(parameters, params);
      _captureGeneratedId(result);
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
        if ("$e".contains("connection closed")) {
          return MariadbPreparedStatementException(
            "error.failed-to-execute.connection_closed",
            "MariadbPreparedStatement: connection closed",
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
        );
      },
    );
  }

  @override
  Future<void> deallocate() async {
    await preparedStmt.deallocate();
  }
}

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

  /// The live MySQL connection (`null` until [connect] succeeds).
  MySQLConnection? connection;

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

  @override
  Future<TomPreparedStatement<T>> prepareStatement<T extends Object>(
    TomQuery query, [
    Type? resultType,
  ]) async {
    if (connection == null || !connection!.connected) {
      await connect();
    }
    final (q, params) = toPositionalStatement(query.generateQuery(sqlDialect));
    var preparedStmt = await connection!.prepare(q);
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
          values[alias] = row.typedColByName<int>(alias);
        case double:
          // Read the raw text and parse it here rather than via
          // `typedColByName<double>`: the driver converts to `double` only from
          // a fixed whitelist of column types that does not include
          // `NEWDECIMAL` (246), and `SUM`/`AVG` over an integer column is
          // exactly what MariaDB returns as `NEWDECIMAL`. Asking the driver for
          // a `double` there throws `MySQLProtocolException` instead of
          // widening — which would make `Sum` and `Avg`, whose whole purpose is
          // to absorb that widening, unusable against a real server. The text
          // form ("43.0000") parses losslessly.
          final decimalText = row.colByName(alias);
          values[alias] = decimalText == null
              ? null
              : double.parse(decimalText);
        case String:
          values[alias] = row.typedColByName<String>(alias);
        case bool:
          values[alias] = row.typedColByName<bool>(alias);
        case DateTime:
          final stringForm = row.typedColByName<String>(alias);
          values[alias] = stringForm == null
              ? null
              : DateTime.parse(stringForm);
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
    if (connection != null) {
      if (!connection!.connected) {
        await connect();
      }
      IResultSet qResult = await runChecked<IResultSet>(
        () async {
          return await connection!.execute(command, params);
        },
        (e, StackTrace s) {
          tomLog.warn("Error when executing SQL: $e");
          return MariadbDatasourceException(
            "error.failed-to-execute.exception",
            "MariadbDatasource: execution of $command with $params failed. $e",
            parameters: {...?params, "command": command, "type": resultType},
          );
        },
      );
      return _processResult<T>(qResult, resultType);
    }
    throw MariadbDatasourceException(
      "error.result_processing.executequery_no_connection",
      "Attempt to call executequery before connection has been established",
    );
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
            Type t = entry.value.getType();
            switch (t) {
              case int:
                entry.value.set(row.typedColByName<int>(entry.key));
              case double:
                entry.value.set(row.typedColByName<double>(entry.key));
              case String:
                entry.value.set(row.typedColByName<String>(entry.key));
              case bool:
                entry.value.set(row.typedColByName<bool>(entry.key));
              case DateTime:
                String? stringForm = row.typedColByName<String>(entry.key);
                if (stringForm != null) {
                  entry.value.set(DateTime.parse(stringForm));
                }
              default:
                throw MariadbDatasourceException(
                  "error.result_processing_tcp.unknown_type",
                  "Unexpected and unsupported type for TomObject value: $t for member ${entry.key} in $classMirror",
                  parameters: {
                    "type": classMirror.reflectedType,
                    "fieldType": t,
                    "attribute": entry.key,
                  },
                );
            }
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
            var member = rowResult.getMembers()[col.declaredName];
            var t = member!.getType();
            switch (t) {
              case int:
                member.set(row.typedColByName<int>(col.field));
              case double:
                member.set(row.typedColByName<double>(col.field));
              case String:
                member.set(row.typedColByName<String>(col.field));
              case bool:
                member.set(row.typedColByName<bool>(col.field));
              case DateTime:
                String? stringForm = row.typedColByName<String>(col.field);
                if (stringForm != null) {
                  member.set(DateTime.parse(stringForm));
                }
              default:
                throw MariadbDatasourceException(
                  "error.result_processing_tc.unknown_type",
                  "Unexpected and unsupported type for TomObject value: $t for member ${col.declaredName} in $classMirror",
                  parameters: {
                    "type": classMirror.reflectedType,
                    "fieldType": t,
                    "attribute": col.declaredName,
                  },
                );
            }
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
              im.invokeSetter(dm.simpleName, row.typedColByName<int>(fieldName));
            case double:
              im.invokeSetter(
                dm.simpleName,
                row.typedColByName<double>(fieldName),
              );
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
            case DateTime:
              String? stringForm = row.typedColByName<String>(fieldName);
              if (stringForm != null) {
                im.invokeSetter(dm.simpleName, DateTime.parse(stringForm));
              }
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
      List<
        (
          TomColumnInformation,
          ClassMirror,
          VariableMirror,
          InstanceMirror,
          Type,
        )
      >
      refStack = [];
      for (var row in qResult.rows) {
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
            // we need to dereference after setting all other fields to be able to use the data
            _referenceValueStack(refStack, col, classMirror, dm, im, T);
            continue;
          }
          switch (dm.reflectedType) {
            case int:
              im.invokeSetter(
                dm.simpleName,
                row.typedColByName<int>(col.field),
              );
            case double:
              im.invokeSetter(
                dm.simpleName,
                row.typedColByName<double>(col.field),
              );
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
            case DateTime:
              String? stringForm = row.typedColByName<String>(col.field);
              if (stringForm != null) {
                im.invokeSetter(dm.simpleName, DateTime.parse(stringForm));
              }
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
          await _referenceValuesGet(refStack);
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
      return TomDbInt(row.typedColByName<int>(field));
    } else if (colType == TomDbDouble) {
      return TomDbDouble(row.typedColByName<double>(field));
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

  void _referenceValueStack(
    List<
      (TomColumnInformation, ClassMirror, VariableMirror, InstanceMirror, Type)
    >
    refStack,
    TomColumnInformation column,
    ClassMirror classMirror,
    VariableMirror vm,
    InstanceMirror im,
    Type T,
  ) async {
    refStack.add((column, classMirror, vm, im, T));
  }

  Future<int> _referenceValuesGet<TBLTYPE extends Object>(
    List<
      (TomColumnInformation, ClassMirror, VariableMirror, InstanceMirror, Type)
    >
    refStack,
  ) async {
    for (var (column, classMirror, vm, im, _) in refStack) {
      String query = "";
      Map<String, Object?> referenceQueryParams = {};
      for (var ls in column.reference!.leftSideColumns) {
        var [left, right] = ls.split("=");
        if (left.startsWith("${classMirror.reflectedType}.")) {
          throw MariadbDatasourceException(
            "error.result_processing.ref_leftside_syntax_a",
            "Invalid leftSideColumn-Expression $ls, value from originType must be on the right side.",
            parameters: {"expression": ls, "part": left},
          );
        }
        if (!right.startsWith("${classMirror.reflectedType}.")) {
          throw MariadbDatasourceException(
            "error.result_processing.ref_leftside_syntax_b",
            "Invalid leftSideColumn-Expression $ls, value from originType must be on the right side, is $right. Must start with type name.",
            parameters: {"expression": ls, "part": right},
          );
        }
        String paramName = right.substring(right.indexOf(".") + 1);
        query += "${query.isEmpty ? '' : ' AND '}$left = :$paramName";
        referenceQueryParams[paramName] = im.invokeGetter(paramName);
      }
      for (var rs in column.reference!.rightSideColumns) {
        query += "${query.isEmpty ? '' : ' AND '}$rs";
      }
      for (var cc in column.reference!.contextColumns) {
        var [left, right] = cc.split("=");
        if (left.startsWith(":")) {
          throw MariadbDatasourceException(
            "error.result_processing.ref_contextcolumns_syntax_a",
            "Invalid contextColumn-Expression $cc, context value must be on the right.",
            parameters: {"expression": cc, "part": left},
          );
        }
        if (!right.startsWith(":")) {
          throw MariadbDatasourceException(
            "error.result_processing.ref_contextcolumns_syntax_b",
            "Invalid contextColumn-Expression $cc, context value is not on the right and must stsrt with colon.",
            parameters: {"expression": cc, "part": right},
          );
        }
        query += "${query.isEmpty ? '' : ' AND '}$cc";
        var paramName = right.substring(1);
        var ctx = getFromCurrentZone<TomExecutionContext>();
        if (ctx != null) {
          var ctxEntry = ctx.contextMap[paramName];
          if (ctxEntry != null) {
            referenceQueryParams[paramName] = ctxEntry.contextFunction();
          } else {
            throw MariadbDatasourceException(
              "error.result_processing.ref_context_value_not_found",
              "No context entry for $paramName found. Entries are: ${ctx.contextMap.keys.toList()}",
              parameters: {"expression": cc, "paramName": paramName},
            );
          }
        } else {
          throw MariadbDatasourceException(
            "error.result_processing.ref_context_not_found",
            "No TomExecutionContext for zone found. Not running in context.",
          );
        }
      }
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
        query = "FIND BY $query";
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
        List? value = im.invokeGetter(vm.simpleName) as List?;
        // Unfortunately this doesn't work with reflection
        //List value = (vm.type as ClassMirror).newInstance("empty", [true]) as List;
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
    return 1;
  }

  @override
  Future<void> initialize(Map<String, dynamic> settings) async {
    tomReflectionInfo.setValues<MariaDbDatasource>(this, normalizePort(settings));
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
    if (connection != null) {
      if (!connection!.connected) {
        await connect();
      }
      var qResult = await runChecked<IResultSet>(
        () async => await connection!.execute(command, params),
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
    throw MariadbDatasourceException(
      "error.result_processing.executecommand_no_connection",
      "Attempt to call executeCommand before connection has been established",
    );
  }

  @override
  Future<void> close() async {
    if (connection != null && connection!.connected) {
      tomLog.info("MariadbDatasource closing $host:$port/$databaseName");
      await connection!.close();
    } else {
      tomLog.warn(
        "MariadbDatasource NOT closing $host:$port/$databaseName, either no connection or connection is not connected.",
      );
    }
  }

  @override
  String toString() =>
      "MariadbDatasource $host:$port/$databaseName connected: ${connection != null ? connection!.connected : "no connection"}";

  @override
  String getParticipantId() => "MariaDb-$databaseName@$host:@$port";

  bool _transactional = false;

  @override
  Future<bool> startTransaction() async {
    if (_transactional) {
      throw Exception("There is already an active transaction.");
    }
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

  @override
  Future<bool> endTransaction() async {
    try {
      // await executeCommand("XA END $_txId; XA PREPARE $_txId;");
      return true;
    } catch (error) {
      // very unlikely to happen...
      tomLog.error(
        "Ending database transaction of ${getParticipantId()} failed $error",
      );
      return false;
    }
  }

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
@tomReflector
@TomDatasourceDriver("mariadb_xa")
class MariaDbXADatasource extends MariaDbDatasource {
  String? _txId;

  @override
  Future<bool> startTransaction() async {
    if (_txId != null) {
      throw Exception("There is already an active transaction $_txId");
    }
    _txId = "'${databaseName}_${host}_${port}_${DateTime.now()}'";
    try {
      await executeCommand("XA START $_txId;");
      return true;
    } catch (error) {
      tomLog.error(
        "Starting XA database transaction of ${getParticipantId()} failed $error",
      );
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
      // it so a new transaction can start instead of wedging the data source
      // (bug §66). On success `_txId` is kept — `commit` still needs it.
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
      // its first rolled-back transaction (bug §66).
      _txId = null;
    }
  }
}

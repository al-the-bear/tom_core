// ignore_for_file: type_literal_in_constant_pattern
import 'package:mysql_client/mysql_client.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import '../object_persistence/query_sentence_compiler.dart';
import '../object_persistence/annotation_analyzer.dart';

import 'mariadb_sql_dialect.dart';
import 'sql_dialects.dart';
import 'datasource_initialization.dart';
import 'queries.dart';
import 'types_operator.dart';

class MariadbDatasourceException extends TomServerException {
  MariadbDatasourceException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

class MariadbPreparedStatementException extends TomServerException {
  MariadbPreparedStatementException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

class MariadbPreparedStatement<T extends Object>
    extends TomPreparedStatement<T> {
  final MariaDbDatasource datasource;
  PreparedStmt preparedStmt;
  final List<String> parameterList;
  final Type? resultType;
  final String command;

  MariadbPreparedStatement(
    this.preparedStmt,
    this.parameterList,
    this.datasource,
    this.resultType,
    this.command,
  );

  @override
  Future<List<T>> execute([Map<String, Object?>? params]) async {
    List<Object?> parameters = [];
    if (params != null) {
      for (var p in parameterList) {
        // TODO: escape parameters to prevent SQL injection
        // TODO: need to use converters?
        parameters.add(datasource.sqlDialect.objectOp(params[p]));
      }
    }
    try {
      IResultSet result = await _execute(parameters, params);
      return datasource._processResult<T>(result, resultType);
    } on MariadbPreparedStatementException {
      // One retry...
      if (!datasource.connected) {
        await datasource.connect();
      }
      preparedStmt = await datasource.connection!.prepare(command);
      IResultSet result = await _execute(parameters, params);
      return datasource._processResult<T>(result, resultType);
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

@tomReflector
@TomDatasourceDriver("mariadb")
class MariaDbDatasource implements TomDataSource {
  final MariadbSqlDialect _sqlDialect = MariadbSqlDialect();

  @override
  TomStandardSqlDialect get sqlDialect => _sqlDialect;

  String username = "";
  String password = "";
  String host = "";
  int port = -1;
  String databaseName = "";
  int timeOut = 10000;

  MySQLConnection? connection;

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

  bool get connected => connection != null ? connection!.connected : false;

  @override
  Future<TomPreparedStatement<T>> prepareStatement<T extends Object>(
    TomQuery query, [
    Type? resultType,
  ]) async {
    if (connection == null || !connection!.connected) {
      await connect();
    }
    var q = query.generateQuery(sqlDialect);
    var params = query.getParameters(sqlDialect);
    // TODO: What happens if a parameter is twice in the query?
    for (var p in params) {
      q = q.replaceAll(":$p", "?");
    }
    var preparedStmt = await connection!.prepare(q);
    return MariadbPreparedStatement<T>(
      preparedStmt,
      params,
      this,
      resultType,
      q,
    );
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

  // TODO: include handling of access control, both using default resource keys and annotations
  Future<List<T>> _processResult<T extends Object>(
    IResultSet qResult, [
    Type? resultType,
  ]) async {
    Type rType = resultType ?? T;
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
          // TODO: this must be cached...?
          // TODO: need to use converters?
          // TODO: use name mapping from TomDbColumn annotations
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
    tomReflectionInfo.setValues<MariaDbDatasource>(this, settings);
    await connect();
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
        "Rolling back XX database transaction of ${getParticipantId()} failed $error",
      );
    }
  }
}

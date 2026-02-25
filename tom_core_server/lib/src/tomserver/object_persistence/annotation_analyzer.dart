import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../datasources/queries.dart';
import '../little_things/server_exception.dart';
import 'persistence_annotations.dart';

class TomAnnotationAnalyzerException extends TomServerException {
  TomAnnotationAnalyzerException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

class TomAnnotationAnalyzerSyntaxException extends TomServerException {
  TomAnnotationAnalyzerSyntaxException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

mixin TomAnnotationAnalyzer {
  static final mirrorCache = <Type, ClassMirror?>{};
  static final tableCache = <Type, TomDbTable?>{};
  static final columnInfoCache = <Type, List<TomColumnInformation>?>{};

  static TomTypePersistenceInfo analysePersistentType(Type T) {
    var mirror = findMirror(T);
    if (mirror == null) {
      throw TomAnnotationAnalyzerException(
        "annotation_analyzer.analyse_persistent_type.mirror_not_found",
        "Failed to get ClassMirror for $T, it is not in tomReflector",
      );
    }
    TomDbTable? table;
    try {
      table = findTable(T)!;
    } catch (error) {
      throw TomAnnotationAnalyzerException(
        "annotation_analyzer.analyse_persistent_type.table_not_found",
        "Failed to get table annotation for $T $error",
      );
    }
    List<TomColumnInformation>? columns;
    try {
      columns = getPersistentColumns(T)!;
    } catch (error) {
      throw TomAnnotationAnalyzerException(
        "annotation_analyzer.analyse_persistent_type.columns_not_found",
        "Failed to get persistent columns for $T $error",
      );
    }
    return TomTypePersistenceInfo(mirror, table, columns);
  }

  static ClassMirror? findMirror(Type dbType) {
    if (mirrorCache.containsKey(dbType)) return mirrorCache[dbType];
    try {
      var classMirror = tomReflector.reflectType(dbType) as ClassMirror;
      mirrorCache[dbType] = classMirror;
      return classMirror;
    } catch (error) {
      // do nothing
    }
    mirrorCache[dbType] = null;
    return null;
  }

  static TomDbTable? findTable(Type dbType) {
    if (tableCache.containsKey(dbType)) return tableCache[dbType];
    ClassMirror? mirror = findMirror(dbType);
    if (mirror != null) {
      for (var md in mirror.metadata) {
        if (md is TomDbTable) {
          tableCache[dbType] = md;
          return md;
        }
      }
    }
    tableCache[dbType] = null;
    return null;
  }

  static List<TomColumnInformation>? getPersistentColumns(Type dbType) {
    if (columnInfoCache.containsKey(dbType)) {
      return columnInfoCache[dbType] as List<TomColumnInformation>;
    }
    ClassMirror? mirror = findMirror(dbType);
    if (mirror != null) {
      List<TomColumnInformation> result = [];
      for (var dEntry in mirror.declarations.entries) {
        Object? tbcObject = dEntry.value.metadata.firstWhere(
          (md) => (md is TomDbColumn || md is TomReference),
          orElse: () => Object(),
        );
        if (tbcObject is TomDbColumn) {
          // only look at declarations with TomDbColumn annotations
          if (dEntry.value is VariableMirror) {
            result.add(
              _getColumnInfo(
                dbType,
                dEntry.value as VariableMirror,
                dEntry.key,
                tbcObject.columnName,
              ),
            );
          } else {
            throw TomAnnotationAnalyzerSyntaxException(
              "annotation_analyzer.get_persistent_columns.invalid_declaration_not_variable",
              "Cannot analyse field ${dEntry.key}, declaration is not a variable declaration.",
            );
          }
        } else if (tbcObject is TomReference) {
          Object? tbcObject2 = dEntry.value.metadata.firstWhere(
            (md) => md is TomDbColumn,
            orElse: () => Object(),
          );
          if (dEntry.value is VariableMirror) {
            result.add(
              _getColumnInfo(
                dbType,
                dEntry.value as VariableMirror,
                dEntry.key,
                tbcObject2 is TomDbColumn ? tbcObject2.columnName : dEntry.key,
              ),
            );
          } else {
            throw TomAnnotationAnalyzerSyntaxException(
              "annotation_analyzer.get_persistent_columns.invalid_declaration_not_variable_for_reference",
              "Cannot analyse field ${dEntry.key}, declaration is not a variable declaration.",
            );
          }
        }
      }
      columnInfoCache[dbType] = result;
      return result;
    } else {
      columnInfoCache[dbType] = null;
      return null;
    }
  }

  static TomColumnInformation _getColumnInfo(
    Type dbType,
    VariableMirror decl,
    String declaredName,
    String? field,
  ) {
    TomDbColumn? column;
    TomEntityId? entityId;
    TomReference? reference;
    TomPersistenceEventHandler? eventHandler;
    for (var md in decl.metadata) {
      if (md is TomDbColumn) {
        column = md;
      } else if (md is TomEntityId) {
        entityId = md;
      } else if (md is TomReference) {
        reference = md;
      } else if (md is TomPersistenceEventHandler) {
        eventHandler = md;
      }
    }
    column ??= TomDbColumn(columnName: field);
    TomDbTable? table = findTable(dbType);
    if (table != null) {
      return TomColumnInformation(
        table,
        dbType,
        column,
        entityId,
        reference,
        eventHandler,
        decl.reflectedType,
        declaredName,
        field ?? declaredName,
      );
    } else {
      throw TomAnnotationAnalyzerException(
        "annotation_analyzer.get_persistent_columns.no_table_info",
        "No table info for $dbType when trying to get column info",
      );
    }
  }

  static TomColumnInformation determineColumn(
    String name,
    List<TomTypePersistenceInfo> persistenceInfo,
  ) {
    for (var tci in persistenceInfo) {
      for (var tc in tci.columnInfo) {
        if ("${tc.table.table}.${tc.getQueryFieldName()}" == name) {
          return tc;
        }
      }
    }
    for (var tci in persistenceInfo) {
      for (var tc in tci.columnInfo) {
        if ("${tc.tableType}.${tc.declaredName}" == name) {
          return tc;
        }
      }
    }
    for (var tci in persistenceInfo) {
      for (var tc in tci.columnInfo) {
        if (tc.getQueryFieldName() == name) {
          return tc;
        }
      }
    }
    for (var tci in persistenceInfo) {
      for (var tc in tci.columnInfo) {
        if (tc.declaredName.toUpperCase() == name.toUpperCase()) {
          return tc;
        }
      }
    }
    throw TomAnnotationAnalyzerSyntaxException(
      "annotation_analyzer.determine_column.no_column_match",
      "No column match field [$name] found. Must be a variable and must have @TomDbColumn annotation.'}",
    );
  }
}

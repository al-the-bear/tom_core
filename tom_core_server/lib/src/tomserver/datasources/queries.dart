import "package:tom_core_kernel/tom_core_kernel.dart";
import "../object_persistence/annotation_analyzer.dart";
import "../object_persistence/persistence_annotations.dart";
import "types_operator.dart";
import "sql_dialects.dart";

@tomReflector
class TomTypePersistenceInfo {
  ClassMirror classMirror;
  TomDbTable table;
  List<TomColumnInformation> columnInfo;

  TomTypePersistenceInfo(this.classMirror, this.table, this.columnInfo);
}

abstract class TomTypedPersistenceBase {
  List<Type> types;
  final List<TomTypePersistenceInfo> _persistenceInfo = [];
  List<TomTypePersistenceInfo> get persistenceInfo => _persistenceInfo;
  List<TomColumnInformation> getColumnInformation() {
    List<TomColumnInformation> result = [];
    for (var p in _persistenceInfo) {
      result.addAll(p.columnInfo);
    }
    return result;
  }

  TomColumnInformation determineColumn(String name) {
    return TomAnnotationAnalyzer.determineColumn(name, _persistenceInfo);
  }

  TomTypedPersistenceBase(this.types) {
    for (var type in types) {
      _persistenceInfo.add(TomAnnotationAnalyzer.analysePersistentType(type));
    }
  }
}

abstract class TomQuery extends TomTypedPersistenceBase {
  String generateQuery(TomStandardSqlDialect t);

  List<String> getParameters(TomStandardSqlDialect t) {
    return [];
  }

  Set<String> getFields(TomStandardSqlDialect t) {
    return {};
  }

  TomQuery(super.types);
}

abstract class TomGeneratedQuery extends TomQuery {
  final TomOperator<TomDbBool> query;
  final List<String> ignoreFields;
  final bool distinct;
  final List<String> orderBy;
  final bool ascending;
  final int top;

  TomGeneratedQuery(
    super.types, {
    required this.query,
    this.distinct = false,
    this.orderBy = const [],
    this.ascending = true,
    this.top = 0,
    this.ignoreFields = const [],
  });

  @override
  String generateQuery(TomStandardSqlDialect t) {
    return query.generate(t);
  }

  @override
  List<String> getParameters(TomStandardSqlDialect t) {
    return query.getParameters(t);
  }

  @override
  Set<String> getFields(TomStandardSqlDialect t) {
    return query.getFields(t);
  }

  @override
  String toString() =>
      "TomQuery: $query ignoreFields: $ignoreFields distinct: $distinct top: $top order-by: $orderBy ascending: $ascending";
}

class TomSelect extends TomGeneratedQuery {
  TomSelect(
    super.types, {
    required super.query,
    super.distinct,
    super.orderBy,
    super.ascending,
    super.top,
    super.ignoreFields,
  });

  @override
  String toString() => "TomSelect: ${super.toString()}";

  @override
  String generateQuery(TomStandardSqlDialect t) {
    var columns = getColumnInformation();
    Set<String> tables = {};
    var fieldList = columns.fold<String>("", (current, nextCol) {
      tables.add(nextCol.table.table);
      if (nextCol.reference != null) {
        return current;
      }
      if (current.isEmpty) {
        return "${nextCol.table.table}.${nextCol.getQueryFieldName()}";
      } else {
        return "$current , ${nextCol.table.table}.${nextCol.getQueryFieldName()}";
      }
    });
    List<String> dbOrderBy = [];
    for (var ob in orderBy) {
      var ci = determineColumn(ob);
      dbOrderBy.add("${ci.table.table}.${ci.getQueryFieldName()}");
    }
    String sortOrder = ascending
        ? ''
        : (orderBy.isNotEmpty ? 'DESCENDING' : '');
    // TODO: should be in SqlDialect
    return "SELECT ${distinct ? 'DISTINCT ' : ''}${top > 0 ? 'FIRST $top' : ''} $fieldList FROM ${tables.join(',')} WHERE ${query.generate(t)} ${orderBy.isNotEmpty ? 'ORDER BY ${dbOrderBy.join(',')}' : ''} $sortOrder";
  }
}

class TomLiteralSelect extends TomQuery {
  final String query;
  final List<String> parameters;

  TomLiteralSelect(
    super.types, {
    required this.query,
    this.parameters = const [],
  });

  @override
  String toString() => "TomLiteralSelect: $query";

  @override
  String generateQuery(TomStandardSqlDialect t) {
    return query;
  }

  @override
  List<String> getParameters(TomStandardSqlDialect t) {
    return parameters;
  }
}

class TomCount extends TomGeneratedQuery {
  TomCount(
    super.types, {
    required super.query,
    super.distinct,
    super.orderBy,
    super.ascending,
    super.top,
    super.ignoreFields,
  });
  @override
  String toString() => "TomCount: ${super.toString()}";
  @override
  String generateQuery(TomStandardSqlDialect t) {
    var columns = getColumnInformation();
    Set<String> tables = {};
    for (var nextCol in columns) {
      tables.add(nextCol.table.table);
    }
    // TODO: should be in SqlDialect
    return "SELECT ${distinct ? 'COUNT(DISTINCT(*))' : 'COUNT(*)'} AS count FROM ${tables.join(',')} WHERE ${query.generate(t)}";
  }
}

class TomDelete extends TomGeneratedQuery {
  TomDelete(
    super.types, {
    required super.query,
    super.distinct,
    super.orderBy,
    super.ascending,
    super.top,
    super.ignoreFields,
  });
  @override
  String toString() => "TomDelete: ${super.toString()}";
  @override
  String generateQuery(TomStandardSqlDialect t) {
    var columns = getColumnInformation();
    Set<String> tables = {};
    for (var nextCol in columns) {
      tables.add(nextCol.table.table);
    }
    // TODO: should be in SqlDialect
    // TODO: check SQL. Can I delete in more than one table at a time?
    return "DELETE ${distinct ? 'DISTINCT ' : ''}${top > 0 ? 'FIRST $top' : ''} FROM ${TomAnnotationAnalyzer.findTable(types[0])!.table} WHERE ${query.generate(t)} ${orderBy.isNotEmpty ? 'ORDER BY ${orderBy.join(',')}' : ''} ${ascending && orderBy.isNotEmpty ? 'ASCENDING' : ''}";
  }
}

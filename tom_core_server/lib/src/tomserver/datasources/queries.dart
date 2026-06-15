import "package:tom_core_kernel/tom_core_kernel.dart";
import "../object_persistence/annotation_analyzer.dart";
import "../object_persistence/persistence_annotations.dart";
import "types_operator.dart";
import "sql_dialects.dart";

/// The persistence metadata for one entity type: its [classMirror], the
/// [TomDbTable] it maps to, and the per-field [TomColumnInformation] derived
/// from the type's persistence annotations.
@tomReflector
class TomTypePersistenceInfo {
  /// Reflection mirror of the entity class.
  ClassMirror classMirror;

  /// The table the entity maps to.
  TomDbTable table;

  /// Per-field column metadata for the entity.
  List<TomColumnInformation> columnInfo;

  /// Bundles the entity's [classMirror], [table] and [columnInfo].
  TomTypePersistenceInfo(this.classMirror, this.table, this.columnInfo);
}

/// Base for anything scoped to a set of persistent entity [types]: it analyses
/// each type's annotations once at construction and exposes the resulting
/// [persistenceInfo], the flattened [getColumnInformation], and per-name column
/// lookup via [determineColumn].
abstract class TomTypedPersistenceBase {
  /// The entity types this object operates over.
  List<Type> types;
  final List<TomTypePersistenceInfo> _persistenceInfo = [];

  /// The analysed persistence metadata, one entry per type in [types].
  List<TomTypePersistenceInfo> get persistenceInfo => _persistenceInfo;

  /// All columns across all [types], flattened in type order.
  List<TomColumnInformation> getColumnInformation() {
    List<TomColumnInformation> result = [];
    for (var p in _persistenceInfo) {
      result.addAll(p.columnInfo);
    }
    return result;
  }

  /// Resolves the column metadata for the field [name] across all [types].
  TomColumnInformation determineColumn(String name) {
    return TomAnnotationAnalyzer.determineColumn(name, _persistenceInfo);
  }

  /// Analyses the persistence annotations of each of [types] up front.
  TomTypedPersistenceBase(this.types) {
    for (var type in types) {
      _persistenceInfo.add(TomAnnotationAnalyzer.analysePersistentType(type));
    }
  }
}

/// A query over a set of entity [types] that renders to SQL via
/// [generateQuery], contributing positional [getParameters] and referenced
/// [getFields] for the active dialect.
abstract class TomQuery extends TomTypedPersistenceBase {
  /// Renders the full SQL statement for dialect [t].
  String generateQuery(TomStandardSqlDialect t);

  /// The positional parameters the statement binds (empty by default).
  List<String> getParameters(TomStandardSqlDialect t) {
    return [];
  }

  /// The column/field names the statement references (empty by default).
  Set<String> getFields(TomStandardSqlDialect t) {
    return {};
  }

  /// Creates a query over the given entity [types].
  TomQuery(super.types);
}

/// A [TomQuery] whose WHERE clause is built from a [TomOperator] predicate
/// [query], with shared shaping options ([distinct], [orderBy], [ascending],
/// [top], [ignoreFields]). Concrete subclasses ([TomSelect], [TomCount],
/// [TomDelete]) render the appropriate statement around that predicate.
abstract class TomGeneratedQuery extends TomQuery {
  /// The boolean predicate forming the WHERE clause.
  final TomOperator<TomDbBool> query;

  /// Field names to omit from the generated column list.
  final List<String> ignoreFields;

  /// Whether to request distinct rows.
  final bool distinct;

  /// Field names to sort by (empty = unsorted).
  final List<String> orderBy;

  /// Sort direction when [orderBy] is set.
  final bool ascending;

  /// Row cap (0 = unbounded).
  final int top;

  /// Builds a generated query over [types] from the predicate [query] and the
  /// shaping options.
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

/// A `SELECT` over the entity [types]: emits the (non-reference) columns of all
/// involved tables, the WHERE clause from the predicate, and optional
/// `DISTINCT`, `FIRST n`, and `ORDER BY` clauses.
class TomSelect extends TomGeneratedQuery {
  /// Builds a `SELECT` from the predicate `query` and shaping options.
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
    return "SELECT ${distinct ? 'DISTINCT ' : ''}${top > 0 ? 'FIRST $top' : ''} $fieldList FROM ${tables.join(',')} WHERE ${query.generate(t)} ${orderBy.isNotEmpty ? 'ORDER BY ${dbOrderBy.join(',')}' : ''} $sortOrder";
  }
}

/// A query whose SQL is a raw, hand-written [query] string with explicit
/// positional [parameters] — an escape hatch for statements the generated
/// queries cannot express. The [types] still drive result mapping.
class TomLiteralSelect extends TomQuery {
  /// The verbatim SQL statement.
  final String query;

  /// The positional parameter names bound by the statement.
  final List<String> parameters;

  /// Builds a literal query from the raw SQL [query] and its [parameters].
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

/// A `SELECT COUNT(*)` (or `COUNT(DISTINCT(*))`) over the entity [types],
/// filtered by the predicate. Returns a single `count` column.
class TomCount extends TomGeneratedQuery {
  /// Builds a count query from the predicate `query`.
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
    return "SELECT ${distinct ? 'COUNT(DISTINCT(*))' : 'COUNT(*)'} AS count FROM ${tables.join(',')} WHERE ${query.generate(t)}";
  }
}

/// A `DELETE` from the first of the entity [types], filtered by the predicate.
class TomDelete extends TomGeneratedQuery {
  /// Builds a delete query from the predicate `query`.
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
    return "DELETE ${distinct ? 'DISTINCT ' : ''}${top > 0 ? 'FIRST $top' : ''} FROM ${TomAnnotationAnalyzer.findTable(types[0])!.table} WHERE ${query.generate(t)} ${orderBy.isNotEmpty ? 'ORDER BY ${orderBy.join(',')}' : ''} ${ascending && orderBy.isNotEmpty ? 'ASCENDING' : ''}";
  }
}

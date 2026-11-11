/// Aggregation and grouping for the typed query layer.
///
/// The rest of the query surface describes *rows*: a [TomSelect] projects an
/// entity's columns and a predicate filters them. This module adds the second
/// shape a relational store offers — *groups*: rows collapsed by one or more key
/// columns, with an aggregate value computed per group.
///
/// Three pieces make that expressible:
///
/// - [TomAggregate] and its concrete nodes ([CountAll], [Count], [Sum], [Avg],
///   [Min], [Max]) are ordinary [TomOperator]s, so they compose with the
///   existing predicates and render through the active dialect rather than
///   through any driver-specific string.
/// - [TomGroupedSelect] is the compiled sentence: a `SELECT` that carries the
///   group columns, the aggregate projection, the row predicate (`WHERE`) and
///   the *group* predicate (`HAVING`) as separate, typed parts.
/// - [TomGroupedRow] is the result shape. A grouped query does not return
///   entities — its rows are group-key plus aggregate-value tuples whose shape
///   is decided by the query, not by any entity class — so it gets its own
///   typed holder instead of being forced into the entity type.
///
/// Everything stays inside the typed tree on purpose. A raw-SQL escape hatch
/// (the [TomLiteralSelect] shape) would defeat the point: a generated
/// repository has to emit these queries deterministically from a specification,
/// and raw SQL is neither checkable nor portable across dialects.
library;

import '../datasources/queries.dart';
import '../datasources/sql_dialects.dart';
import '../datasources/sql_instant.dart';
import '../datasources/types_operator.dart';

import 'operators_expressions.dart';
import 'persistence_annotations.dart';
import '../datasources/table_qualification.dart';

/// The identifier shape a projection alias must have.
///
/// An alias is interpolated into the SQL text (it cannot be bound as a
/// parameter — it names a result column), so it is constrained to a plain SQL
/// identifier and rejected otherwise. That is the whole injection surface the
/// grouped query adds, and it is closed at construction.
final RegExp _aliasPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// The Dart types a group key or aggregate value may have — the set the result
/// mappers can materialise from a driver row.
const List<Type> _mappableTypes = [int, double, String, bool, DateTime];

/// An aggregate function applied to a group: `COUNT(*)`, `SUM(t.amount)`,
/// `MAX(t.created)`, …
///
/// [R] is the SQL type of the result (so the node composes with the typed
/// predicates — `Sum` yields a `TomOperator<TomDbDouble>` that `gt` accepts),
/// and [V] is the Dart type the value materialises as, which [read] returns and
/// the result mapper uses to pull the column out of a driver row.
///
/// Every aggregate carries an [alias]: a grouped query's result columns are
/// named, because unlike an entity projection there is no column metadata to
/// map them back by. The alias is how [TomGroupedRow] finds the value again.
abstract class TomAggregate<R, V> extends TomOperator<R> {
  /// The SQL function this node renders.
  final TomAggregateFunction function;

  /// The expression being aggregated, or `null` for the one argument-less
  /// form, `COUNT(*)`.
  final TomOperator? operand;

  /// Whether to aggregate over distinct operand values (`COUNT(DISTINCT c)`).
  final bool distinct;

  /// The result-column name this aggregate is projected under.
  final String alias;

  /// The Dart type [V] the value materialises as, captured at construction so
  /// the result mapper can read the column without a type argument.
  late final Type valueType;

  /// Creates an aggregate of [function] over [operand], projected as [alias].
  ///
  /// Throws [TomQuerySyntaxException] when [alias] is not a plain SQL
  /// identifier, or when [V] is not a type the result mapper can materialise.
  TomAggregate(
    this.function,
    this.operand,
    this.alias, {
    this.distinct = false,
  }) {
    valueType = V;
    if (!_aliasPattern.hasMatch(alias)) {
      throw TomQuerySyntaxException(
        "grouped_query.aggregate.invalid_alias",
        "The aggregate alias '$alias' is not a plain SQL identifier. An alias "
            "names a result column and is written into the statement text, so "
            "it must match ${_aliasPattern.pattern}.",
        parameters: {"alias": alias, "function": function.name},
      );
    }
    if (!_mappableTypes.contains(V)) {
      throw TomQuerySyntaxException(
        "grouped_query.aggregate.unmappable_value_type",
        "The aggregate '$alias' has value type $V, which the result mapper "
            "cannot materialise. Supported types: $_mappableTypes.",
        parameters: {"alias": alias, "valueType": V},
      );
    }
  }

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.aggregate(function, operand?.generate(t), distinct: distinct);

  /// The projected form of this aggregate: `<function>(<operand>) AS <alias>`.
  SqlString generateProjection(TomStandardSqlDialect t) =>
      t.aliased(generate(t), alias);

  @override
  List<TomOperator> get children => operand == null ? const [] : [operand!];

  @override
  List<String> getParameters(TomStandardSqlDialect t) =>
      operand?.getParameters(t) ?? const [];

  @override
  Set<String> getFields(TomStandardSqlDialect t) =>
      operand?.getFields(t) ?? const {};

  /// This aggregate's value in [row], typed as [V], or `null` when the group
  /// produced no value (an aggregate over an all-null column).
  V? read(TomGroupedRow row) => row.typed<V>(alias);

  @override
  String analyze(int l) =>
      "${indent(l)} (${function.sqlName}${distinct ? ' DISTINCT' : ''}"
      " AS $alias${operand == null ? ' *' : ' ${operand!.analyze(l + 1)}'})";

  @override
  String toString() => "TomAggregate ${function.sqlName} AS $alias";
}

/// `COUNT(*)` — the number of rows in the group.
///
/// Distinct from [Count], which counts non-null values of an expression: a row
/// whose counted column is `NULL` is included here and excluded there.
class CountAll extends TomAggregate<TomDbInt, int> {
  /// Counts the rows of each group, projected as [alias].
  CountAll(String alias) : super(TomAggregateFunction.count, null, alias);
}

/// `COUNT(<value>)` — the number of non-null [value]s in the group, or of
/// distinct such values when `distinct` is set.
class Count<T> extends TomAggregate<TomDbInt, int> {
  /// Counts the non-null values of [value] in each group.
  Count(TomOperator<T> value, String alias, {bool distinct = false})
    : super(TomAggregateFunction.count, value, alias, distinct: distinct);
}

/// `SUM(<value>)` — the total of [value] across the group.
///
/// The result is a `double` regardless of the operand's type. SQL widens a sum
/// to an exact-numeric type (MariaDB returns `DECIMAL` for an integer column),
/// which does not round-trip through Dart's `int`; widening once, here, keeps
/// the value type predictable instead of dialect-dependent.
class Sum<T> extends TomAggregate<TomDbDouble, double> {
  /// Sums [value] over each group.
  Sum(TomOperator<T> value, String alias, {bool distinct = false})
    : super(TomAggregateFunction.sum, value, alias, distinct: distinct);
}

/// `AVG(<value>)` — the mean of [value] across the group, always a `double`.
class Avg<T> extends TomAggregate<TomDbDouble, double> {
  /// Averages [value] over each group.
  Avg(TomOperator<T> value, String alias, {bool distinct = false})
    : super(TomAggregateFunction.avg, value, alias, distinct: distinct);
}

/// `MIN(<value>)` — the smallest [value] in the group.
///
/// Unlike [Sum] and [Avg] the extremum is one of the operand's own values, so
/// the node preserves both its SQL type [R] and its Dart type [V]. Use the
/// typed [TomQueryBuilder] factories (`minInt`, `minText`, …) rather than
/// writing the two type arguments out.
class Min<R, V> extends TomAggregate<R, V> {
  /// Takes the smallest [value] in each group.
  Min(TomOperator<R> value, String alias)
    : super(TomAggregateFunction.min, value, alias);
}

/// `MAX(<value>)` — the largest [value] in the group. See [Min].
class Max<R, V> extends TomAggregate<R, V> {
  /// Takes the largest [value] in each group.
  Max(TomOperator<R> value, String alias)
    : super(TomAggregateFunction.max, value, alias);
}

/// One row of a grouped query's result: the group-key values plus the
/// aggregate values, each under the alias the query projected it as.
///
/// This is deliberately *not* an entity. A grouped row's shape is decided by
/// the query — which columns it grouped by and which aggregates it asked for —
/// so there is no entity class it could be mapped onto, and forcing one would
/// mean inventing a holder per query shape.
///
/// Values are read through the typed accessors, which coerce the driver's
/// representation to the declared Dart type: a driver may hand back an exact
/// numeric (`SUM`/`AVG` are `DECIMAL` in MariaDB) or a text form depending on
/// the protocol in use, and the caller should not have to care which.
class TomGroupedRow {
  final Map<String, Object?> _values;

  /// Wraps the already-mapped [values] of one result row, keyed by alias.
  TomGroupedRow(Map<String, Object?> values)
    : _values = Map.unmodifiable(values);

  /// Every value in the row, keyed by its projection alias.
  Map<String, Object?> get values => _values;

  /// Whether the row carries a value (possibly `null`) under [alias].
  bool has(String alias) => _values.containsKey(alias);

  /// The raw value projected under [alias].
  ///
  /// Throws [TomQuerySyntaxException] when the row has no such alias — a typo
  /// in an alias is a query bug, and silently yielding `null` would hide it
  /// behind a plausible "the group had no value" reading.
  Object? value(String alias) {
    if (!_values.containsKey(alias)) {
      throw TomQuerySyntaxException(
        "grouped_query.row.unknown_alias",
        "The grouped result row has no column '$alias'. "
            "Available: ${_values.keys.join(', ')}.",
        parameters: {"alias": alias, "available": _values.keys.toList()},
      );
    }
    return _values[alias];
  }

  /// The value under [alias] as an `int`.
  int? intValue(String alias) => _asInt(value(alias), alias);

  /// The value under [alias] as a `double`.
  double? doubleValue(String alias) => _asDouble(value(alias), alias);

  /// The value under [alias] as a `String`.
  String? stringValue(String alias) {
    final raw = value(alias);
    return raw == null ? null : raw.toString();
  }

  /// The value under [alias] as a `bool` (MariaDB stores booleans as `1`/`0`).
  bool? boolValue(String alias) {
    final raw = value(alias);
    if (raw == null || raw is bool) return raw as bool?;
    if (raw is num) return raw != 0;
    return raw.toString() == '1' || raw.toString().toLowerCase() == 'true';
  }

  /// The value under [alias] as a **UTC** `DateTime`.
  ///
  /// The module has one convention for an instant and this is a read path like
  /// any other: a `DATETIME` column carries no zone, so its text taken at face
  /// value is *this node's* wall clock rather than the moment the writing node
  /// stored. `parseSqlInstant` is the reading half everywhere else — the
  /// reflected entity mapper, [TomDbDateTime.of], and the driver's own grouped
  /// projection, which is what normally fills this map — so it is the reading
  /// half here too. A second answer in the one place a caller builds a row by
  /// hand would be the module disagreeing with itself, silently and by exactly
  /// the machine's UTC offset. See `datasources/sql_instant.dart`.
  ///
  /// A value that is already a `DateTime` is relabelled rather than reparsed:
  /// `toUtc` names the same moment, so a row built by hand from a local value
  /// answers what a row built by the driver would.
  DateTime? dateTimeValue(String alias) {
    final raw = value(alias);
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    return parseSqlInstant(raw.toString());
  }

  /// The value under [alias] coerced to [V] — the accessor the typed nodes use
  /// ([TomAggregate.read], [keyOf]) so a caller never names a type twice.
  V? typed<V>(String alias) {
    switch (V) {
      case const (int):
        return intValue(alias) as V?;
      case const (double):
        return doubleValue(alias) as V?;
      case const (String):
        return stringValue(alias) as V?;
      case const (bool):
        return boolValue(alias) as V?;
      case const (DateTime):
        return dateTimeValue(alias) as V?;
    }
    throw TomQuerySyntaxException(
      "grouped_query.row.unsupported_value_type",
      "Cannot read grouped column '$alias' as $V. Supported: $_mappableTypes.",
      parameters: {"alias": alias, "valueType": V},
    );
  }

  /// The group-key value for [column], which a grouped query projects under the
  /// column's declared field name.
  Object? keyOf(DbCol column) => value(column.columnInformation.declaredName);

  int? _asInt(Object? raw, String alias) {
    if (raw == null || raw is int) return raw as int?;
    if (raw is num) return raw.toInt();
    final parsed = num.tryParse(raw.toString());
    if (parsed != null) return parsed.toInt();
    throw _notA(raw, alias, int);
  }

  double? _asDouble(Object? raw, String alias) {
    if (raw == null || raw is double) return raw as double?;
    if (raw is num) return raw.toDouble();
    final parsed = num.tryParse(raw.toString());
    if (parsed != null) return parsed.toDouble();
    throw _notA(raw, alias, double);
  }

  TomQuerySyntaxException _notA(Object? raw, String alias, Type wanted) =>
      TomQuerySyntaxException(
        "grouped_query.row.value_conversion_failed",
        "The grouped column '$alias' holds '$raw', which is not a $wanted.",
        parameters: {"alias": alias, "value": raw, "wanted": wanted},
      );

  @override
  String toString() => "TomGroupedRow $_values";
}

/// A `SELECT … GROUP BY …` over the entity types: the group-key columns and the
/// aggregate projection, filtered by a row predicate (`WHERE`) and a group
/// predicate (`HAVING`).
///
/// It sits beside [TomSelect] and [TomCount] as a third compiled sentence
/// rather than as an option on the select, because its *result* is a different
/// shape: [TomGroupedRow]s, not entities. The two predicates stay separate all
/// the way down to the dialect for the same reason they are separate in SQL —
/// `WHERE` filters rows before aggregation, `HAVING` filters groups after it,
/// and ANDing them together would change the meaning of both.
///
/// The projection is fully named: each group column is projected as its
/// declared field name and each aggregate as its alias, which is what lets the
/// result mapper build a [TomGroupedRow] without any entity metadata.
class TomGroupedSelect extends TomGeneratedQuery {
  /// The columns the result is grouped by. May be empty, which aggregates over
  /// the whole filtered result set and yields exactly one row.
  final List<DbCol> groupBy;

  /// The aggregates projected alongside the group keys. At least one is
  /// required — a grouped select with none is a `DISTINCT` select, which
  /// [TomSelect] already expresses.
  final List<TomAggregate> aggregates;

  /// The group predicate, evaluated after aggregation, or `null`.
  final TomOperator<TomDbBool>? having;

  /// Builds a grouped select over [types].
  ///
  /// [query] is the row predicate, [groupBy] the key columns, [aggregates] the
  /// projected aggregates, [having] the optional group predicate. The ordering
  /// (`sort`, or the `orderBy`/`ascending` shorthand) names *projection aliases*
  /// (a group column's declared name or an aggregate's alias), not arbitrary
  /// entity fields — ordering a grouped result by an ungrouped column is not
  /// meaningful.
  ///
  /// Throws [TomQuerySyntaxException] when no aggregate is given, when two
  /// projections share an alias, when a group column's type cannot be
  /// materialised, or when a sort term is not a projection alias.
  TomGroupedSelect(
    super.types, {
    required super.query,
    this.groupBy = const [],
    required this.aggregates,
    this.having,
    super.orderBy,
    super.ascending,
    super.sort,
    super.top,
    super.offset,
  }) {
    if (aggregates.isEmpty) {
      throw TomQuerySyntaxException(
        "grouped_query.select.no_aggregates",
        "A grouped select must project at least one aggregate. Without one it "
            "is a DISTINCT select, which TomSelect already expresses.",
      );
    }
    final seen = <String>{};
    for (final alias in projectionAliases) {
      if (!seen.add(alias)) {
        throw TomQuerySyntaxException(
          "grouped_query.select.duplicate_alias",
          "The grouped select projects '$alias' twice. Every group column and "
              "aggregate must have a distinct result-column name.",
          parameters: {"alias": alias},
        );
      }
    }
    for (final column in groupBy) {
      final declaredType = column.columnInformation.declaredType;
      if (!_mappableTypes.contains(declaredType)) {
        throw TomQuerySyntaxException(
          "grouped_query.select.unmappable_group_column",
          "The group column '${column.columnInformation.declaredName}' has "
              "type $declaredType, which the result mapper cannot materialise. "
              "Supported types: $_mappableTypes.",
          parameters: {
            "column": column.columnInformation.declaredName,
            "declaredType": declaredType,
          },
        );
      }
    }
    for (final ordered in sort) {
      if (!seen.contains(ordered.field)) {
        throw TomQuerySyntaxException(
          "grouped_query.select.order_by_not_projected",
          "The grouped select orders by '${ordered.field}', which it does not "
              "project. Order a grouped result by a group column or an "
              "aggregate alias; an ungrouped column has no single value per "
              "group. Projected: ${seen.join(', ')}.",
          parameters: {"orderBy": ordered.field, "projected": seen.toList()},
        );
      }
    }
  }

  /// The result-column names this query projects, group keys first: a group
  /// column under its declared field name, an aggregate under its alias.
  List<String> get projectionAliases => [
    for (final column in groupBy) column.columnInformation.declaredName,
    for (final aggregate in aggregates) aggregate.alias,
  ];

  /// The Dart type each projected column materialises as, keyed by alias — what
  /// the data source reads a driver row with, since a grouped row has no entity
  /// metadata to derive types from.
  Map<String, Type> get projectionTypes => {
    for (final column in groupBy)
      column.columnInformation.declaredName:
          column.columnInformation.declaredType,
    for (final aggregate in aggregates) aggregate.alias: aggregate.valueType,
  };

  @override
  String generateQuery(TomStandardSqlDialect t) {
    _assertHavingIsGrouped(t);
    final tables = <String>{
      for (final column in getColumnInformation())
        TomSqlTableQualification.table(column.table.table),
    };
    final projection = [
      for (final column in groupBy)
        t.aliased(column.generate(t), column.columnInformation.declaredName),
      for (final aggregate in aggregates) aggregate.generateProjection(t),
    ];
    return "SELECT ${projection.join(', ')}"
        " FROM ${tables.join(',')}"
        " WHERE ${query.generate(t)}"
        "${t.groupByClause([for (final column in groupBy) column.generate(t)])}"
        "${t.havingClause(having?.generate(t))}"
        "${TomGeneratedQuery.orderByClause(sort)}"
        "${TomGeneratedQuery.limitClause(top, offset)}";
  }

  /// Parameters in statement-text order — projection, then `WHERE`, then
  /// `HAVING`. The order is load-bearing: placeholders bind positionally, so a
  /// list that does not follow the rendered text binds the wrong values.
  @override
  List<String> getParameters(TomStandardSqlDialect t) => [
    for (final aggregate in aggregates) ...aggregate.getParameters(t),
    ...query.getParameters(t),
    ...?having?.getParameters(t),
  ];

  @override
  Set<String> getFields(TomStandardSqlDialect t) => {
    for (final column in groupBy) ...column.getFields(t),
    for (final aggregate in aggregates) ...aggregate.getFields(t),
    ...query.getFields(t),
    ...?having?.getFields(t),
  };

  /// Every column the query reads outside an aggregate — the group keys plus
  /// the columns the `WHERE` and `HAVING` predicates reference directly.
  ///
  /// The repository uses this to refuse a grouped query that would expose a
  /// column the principal may not read (C-4): masking cannot be applied to a
  /// group key or an aggregate after the fact, because the aggregate has
  /// already been computed from the hidden values.
  Set<TomColumnInformation> get referencedColumns => {
    for (final column in groupBy) column.columnInformation,
    ...columnsOf(query),
    if (having != null) ...columnsOf(having!),
  };

  /// Every [DbCol] reachable from [node], descending through aggregates.
  static Set<TomColumnInformation> columnsOf(TomOperator node) {
    if (node is DbCol) return {node.columnInformation};
    return {for (final child in node.children) ...columnsOf(child)};
  }

  /// Rejects a `HAVING` that filters on a bare column which is neither a group
  /// key nor inside an aggregate.
  ///
  /// Such a predicate is not meaningful — the column has many values within a
  /// group and no rule for picking one — and databases differ on whether they
  /// reject it or silently pick an arbitrary row. Catching it here makes the
  /// behaviour the same on every dialect.
  void _assertHavingIsGrouped(TomStandardSqlDialect t) {
    final predicate = having;
    if (predicate == null) return;
    final grouped = {for (final column in groupBy) column.generate(t)};
    final ungrouped = _ungroupedFields(predicate, t).difference(grouped);
    if (ungrouped.isNotEmpty) {
      throw TomQuerySyntaxException(
        "grouped_query.select.having_on_ungrouped_field",
        "The HAVING clause filters on ${ungrouped.join(', ')}, which is "
            "neither a group column nor inside an aggregate. Filter rows on it "
            "in the WHERE clause, or add it to the grouping.",
        parameters: {"fields": ungrouped.toList()},
      );
    }
  }

  /// The bare column references in [node], treating an aggregate as opaque: an
  /// aggregate collapses the rows its operand spans, so the operand carries no
  /// grouping obligation.
  static Set<String> _ungroupedFields(
    TomOperator node,
    TomStandardSqlDialect t,
  ) {
    if (node is TomAggregate) return const {};
    if (node is DbCol) return {node.generate(t)};
    return {for (final child in node.children) ..._ungroupedFields(child, t)};
  }

  @override
  String toString() =>
      "TomGroupedSelect: group-by ${projectionAliases.join(', ')} "
      "having: $having ${super.toString()}";
}

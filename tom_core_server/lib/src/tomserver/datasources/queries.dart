import "package:tom_core_kernel/tom_core_kernel.dart";
import "../object_persistence/annotation_analyzer.dart";
import "../object_persistence/paging.dart";
import "../object_persistence/persistence_annotations.dart";
import "../object_persistence/query_sentence_compiler.dart";
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
  ///
  /// An empty set does not always mean "references nothing": a statement that
  /// cannot analyse itself reports empty too (see [TomLiteralSelect.getFields]).
  /// Callers that act on this answer must decide what to do when it is empty
  /// for the wrong reason.
  Set<String> getFields(TomStandardSqlDialect t) {
    return {};
  }

  /// Creates a query over the given entity [types].
  TomQuery(super.types);
}

/// A [TomQuery] whose WHERE clause is built from a [TomOperator] predicate
/// [query], with shared shaping options ([distinct], [sort], [top], [offset],
/// [ignoreFields]). Concrete subclasses ([TomSelect], [TomCount], [TomDelete])
/// render the appropriate statement around that predicate.
abstract class TomGeneratedQuery extends TomQuery {
  /// The boolean predicate forming the WHERE clause.
  final TomOperator<TomDbBool> query;

  /// Field names to omit from the generated column list.
  final List<String> ignoreFields;

  /// Whether to request distinct rows.
  final bool distinct;

  /// The ordering, outermost term first (empty = unsorted).
  ///
  /// Each term carries its own direction, so `ORDER BY priority DESC, name ASC`
  /// is expressible; the `orderBy`/`ascending` constructor pair is a shorthand
  /// that maps onto this list with one direction shared by every field.
  final List<TomSortField> sort;

  /// Row cap (`<= 0` = unbounded).
  final int top;

  /// Rows skipped before the first returned row (`0` = start at the beginning).
  ///
  /// A non-zero offset requires a [top]: SQL skips with `LIMIT n OFFSET m` and
  /// has no bare `OFFSET`.
  final int offset;

  /// Builds a generated query over [types] from the predicate [query] and the
  /// shaping options.
  ///
  /// The ordering is given either as [sort] (per-term directions) or as the
  /// [orderBy]/[ascending] shorthand, which maps onto [sort] with one direction
  /// for every field. [sort] wins when both are given.
  ///
  /// Throws [TomQuerySyntaxException] when [offset] is set without a [top], or
  /// when either is negative (see [TomPageRequest.assertWindow]).
  TomGeneratedQuery(
    super.types, {
    required this.query,
    this.distinct = false,
    List<String> orderBy = const [],
    bool ascending = true,
    List<TomSortField>? sort,
    this.top = 0,
    this.offset = 0,
    this.ignoreFields = const [],
  }) : sort =
           sort ??
           TomSortField.allOf(
             orderBy,
             direction: ascending
                 ? TomSortDirection.ascending
                 : TomSortDirection.descending,
           ) {
    // `top` defaults to an unbounded marker that callers spell either 0 or -1
    // (the query-sentence compiler uses -1), so only the offset is range-checked
    // here; the pairing rule is checked with a normalised limit.
    TomPageRequest.assertWindow(limit: top > 0 ? top : 0, offset: offset);
  }

  @override
  String generateQuery(TomStandardSqlDialect t) {
    return query.generate(t);
  }

  /// Renders the `DISTINCT ` projection prefix (empty when not [distinct]).
  static String distinctPrefix(bool distinct) => distinct ? 'DISTINCT ' : '';

  /// Renders the trailing ` LIMIT n [OFFSET m]` row-window clause (empty when
  /// [top] `<= 0` and no [offset] is asked for).
  ///
  /// MariaDB/MySQL cap rows with `LIMIT n` and skip with `LIMIT n OFFSET m`; the
  /// Informix-style `FIRST n` this replaces is not valid MariaDB syntax.
  /// There is no bare `OFFSET`, so an offset without a cap is
  /// rejected rather than silently dropped (see [TomPageRequest.assertWindow]).
  ///
  /// Both bounds are rendered as literal integers rather than bound parameters,
  /// as the row cap always has been: they are Dart `int`s, so they carry no
  /// text that could reach the statement, and MariaDB will not plan a
  /// placeholder window as well as a literal one.
  static String limitClause(int top, [int offset = 0]) {
    TomPageRequest.assertWindow(limit: top > 0 ? top : 0, offset: offset);
    if (top <= 0) return '';
    return offset > 0 ? ' LIMIT $top OFFSET $offset' : ' LIMIT $top';
  }

  /// Renders the trailing ` ORDER BY <col> ASC|DESC, …` clause (empty when
  /// [sort] is empty).
  ///
  /// Every term carries its own direction, so a mixed-direction sort renders as
  /// written. The keywords are `ASC` / `DESC`; the spelled-out
  /// `ASCENDING` / `DESCENDING` forms this replaces are not valid SQL.
  ///
  /// The terms' [TomSortField.field]s are emitted verbatim, so callers pass
  /// *resolved* column expressions — a name that came from outside must have
  /// been through the entity's column metadata first. [resolveSortColumns] is
  /// that step, and lives here so the two are read together.
  static String orderByClause(List<TomSortField> sort) {
    if (sort.isEmpty) return '';
    final terms = [
      for (final term in sort) '${term.field} ${term.direction.sqlKeyword}',
    ];
    return ' ORDER BY ${terms.join(',')}';
  }

  /// Resolves each term of [sort] against [persistenceInfo], returning terms
  /// whose field is the *column* the entity maps it to, with the direction
  /// carried over unchanged.
  ///
  /// A sort term may be written as either name — the lookup matches the column
  /// name and the declared Dart field name alike — but only the column name is
  /// valid SQL, so an unresolved term names a column that does not exist on any
  /// entity whose two spellings differ.
  ///
  /// The lookup is also the guard on the statement text. Sort names routinely
  /// arrive from outside (an HTTP `sort=` parameter, a query sentence), and an
  /// `ORDER BY` cannot bind them as parameters; resolving them means an unknown
  /// name throws here instead of being interpolated verbatim.
  ///
  /// [qualified] chooses the rendering, never the lookup. A statement that may
  /// span tables needs `table.column` to be unambiguous; MariaDB's `DELETE` is
  /// single-table, so it has nothing to disambiguate and names the column bare.
  static List<TomSortField> resolveSortColumns(
    List<TomSortField> sort,
    List<TomTypePersistenceInfo> persistenceInfo, {
    bool qualified = true,
  }) {
    final resolved = <TomSortField>[];
    for (final term in sort) {
      final column = TomQuerySentenceCompiler.comparable(
        TomAnnotationAnalyzer.determineColumn(term.field, persistenceInfo),
        'sorted by ${term.field}',
      );
      final name = column.getQueryFieldName();
      resolved.add(
        term.withField(qualified ? '${column.table.table}.$name' : name),
      );
    }
    return resolved;
  }

  /// Renders the `COUNT(*)` / `COUNT(DISTINCT <cols>)` projection.
  ///
  /// A distinct count is expressed as `COUNT(DISTINCT col1, col2, ...)`; the
  /// previous `COUNT(DISTINCT(*))` is a MariaDB syntax error — `*` cannot follow
  /// `DISTINCT` inside `COUNT`. Falls back to `COUNT(*)` when there are no
  /// columns to distinguish on.
  static String countProjection(bool distinct, List<String> columnExprs) {
    if (!distinct || columnExprs.isEmpty) return 'COUNT(*)';
    return 'COUNT(DISTINCT ${columnExprs.join(', ')})';
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
      "TomQuery: $query ignoreFields: $ignoreFields distinct: $distinct top: $top offset: $offset order-by: $sort";
}

/// A `SELECT` over the entity [types]: emits the (non-reference) columns of all
/// involved tables, the WHERE clause from the predicate, and optional
/// `DISTINCT`, `ORDER BY … ASC|DESC`, and `LIMIT n [OFFSET m]` clauses.
class TomSelect extends TomGeneratedQuery {
  /// Builds a `SELECT` from the predicate `query` and shaping options.
  TomSelect(
    super.types, {
    required super.query,
    super.distinct,
    super.orderBy,
    super.ascending,
    super.sort,
    super.top,
    super.offset,
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
    // Qualified, because a select may span tables.
    final dbSort = TomGeneratedQuery.resolveSortColumns(sort, persistenceInfo);
    return "SELECT ${TomGeneratedQuery.distinctPrefix(distinct)}$fieldList"
        " FROM ${tables.join(',')}"
        " WHERE ${query.generate(t)}"
        "${TomGeneratedQuery.orderByClause(dbSort)}"
        "${TomGeneratedQuery.limitClause(top, offset)}";
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

  /// Always empty: a hand-written statement's field references cannot be
  /// derived.
  ///
  /// Read this as *"this statement cannot say which fields it reads"*, not
  /// *"this statement reads none"* — a literal select usually references
  /// several columns, but they live in SQL text that nothing here parses. The
  /// generated siblings answer from their operator tree; there is no tree here,
  /// and the caller declares only its [parameters], never its fields.
  ///
  /// Written out rather than left to the inherited default, because the two
  /// agree only by coincidence: the base returns `{}` on behalf of statements
  /// that genuinely reference nothing, which is a different claim that happens
  /// to carry the same value. A caller weighing this answer — to decide a
  /// projection, to audit a statement, or to gate access — must treat an empty
  /// set from a literal query as *unknown*, and either read the SQL or work
  /// from a query it can analyse.
  @override
  Set<String> getFields(TomStandardSqlDialect t) {
    return {};
  }
}

/// A `SELECT COUNT(*)` (or `COUNT(DISTINCT <cols>)`) over the entity [types],
/// filtered by the predicate. Returns a single `count` column.
///
/// A count has no row window and no ordering, and so takes neither `top`,
/// `offset`, `sort` nor the `orderBy`/`ascending` shorthand its siblings
/// accept. Both omissions are about the shape of the result rather than SQL
/// syntax: the statement returns exactly one row, so `LIMIT` would cap what is
/// *returned* rather than what is counted (`top: 5` would still count the whole
/// filtered set), and an `ORDER BY` would have a single row to order. The total
/// of a filtered set likewise does not depend on which page of it the caller is
/// looking at, which is why there is no `offset` either.
///
/// The parameters are absent rather than accepted and ignored, so a sentence or
/// call that asks for a window fails where it is written. [TomSelect] is the
/// sibling that takes all of them, and [TomDelete] takes `sort` and `top` —
/// `DELETE … ORDER BY x LIMIT n` picks *which* rows go.
class TomCount extends TomGeneratedQuery {
  /// Builds a count query from the predicate `query`.
  TomCount(
    super.types, {
    required super.query,
    super.distinct,
    super.ignoreFields,
  });
  @override
  String toString() => "TomCount: ${super.toString()}";
  @override
  String generateQuery(TomStandardSqlDialect t) {
    var columns = getColumnInformation();
    Set<String> tables = {};
    List<String> columnExprs = [];
    for (var nextCol in columns) {
      tables.add(nextCol.table.table);
      if (nextCol.reference == null) {
        columnExprs.add(
          "${nextCol.table.table}.${nextCol.getQueryFieldName()}",
        );
      }
    }
    return "SELECT ${TomGeneratedQuery.countProjection(distinct, columnExprs)}"
        " AS count FROM ${tables.join(',')} WHERE ${query.generate(t)}";
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
    super.sort,
    super.top,
    super.ignoreFields,
  });
  @override
  String toString() => "TomDelete: ${super.toString()}";
  @override
  String generateQuery(TomStandardSqlDialect t) {
    // MariaDB `DELETE` is single-table and supports neither `DISTINCT` nor a
    // column projection — only an optional `ORDER BY … ASC|DESC` and
    // `LIMIT n`. There is no `OFFSET`: `DELETE … LIMIT n OFFSET m` is not
    // MariaDB syntax, so a delete takes no offset either.
    //
    // Unqualified, because the statement names exactly one table — but still
    // resolved, so the clause carries the column name rather than the Dart
    // field name it may have been written with.
    final dbSort = TomGeneratedQuery.resolveSortColumns(
      sort,
      persistenceInfo,
      qualified: false,
    );
    // Resolved at construction, like the sort columns above: a type that maps
    // to no table never becomes a query, so by here there is a table to name.
    return "DELETE FROM ${persistenceInfo[0].table.table}"
        " WHERE ${query.generate(t)}"
        "${TomGeneratedQuery.orderByClause(dbSort)}"
        "${TomGeneratedQuery.limitClause(top)}";
  }
}

/// An `UPDATE` of the first of the entity [types]: the columns of [set], by
/// their column names, assigned their operands, for the rows the predicate
/// selects.
///
/// What a repository renders a soft delete and a restore as — the same `WHERE`
/// the matching hard delete would take, and one column moved.
class TomUpdate extends TomGeneratedQuery {
  /// Builds an update of [set] for the rows the predicate `query` selects.
  TomUpdate(super.types, {required super.query, required this.set});

  /// The assignments: column name to its new value.
  final Map<String, TomOperator<Object?>> set;

  @override
  String toString() => "TomUpdate: $set ${super.toString()}";

  @override
  String generateQuery(TomStandardSqlDialect t) {
    final assignments = [
      for (final entry in set.entries)
        '${entry.key} = ${entry.value.generate(t)}',
    ];
    return "UPDATE ${persistenceInfo[0].table.table}"
        " SET ${assignments.join(', ')}"
        " WHERE ${query.generate(t)}";
  }

  /// The assignments' parameters first, then the predicate's — the order
  /// their placeholders appear in.
  @override
  List<String> getParameters(TomStandardSqlDialect t) => [
    for (final value in set.values) ...value.getParameters(t),
    ...query.getParameters(t),
  ];
}

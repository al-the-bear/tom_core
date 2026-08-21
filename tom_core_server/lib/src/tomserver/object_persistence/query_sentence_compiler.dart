// ignore_for_file: type_literal_in_constant_pattern

import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../datasources/types_operator.dart';
import '../datasources/queries.dart';
import '../datasources/sql_dialects.dart';
import 'grouped_query.dart';
import 'operators_expressions.dart';
import 'paging.dart';
import 'persistence_annotations.dart';
import 'query_builder.dart';

/// Compiles a Spring-Data-style *query sentence* into a [TomQuery].
///
/// A query sentence is a whitespace-separated phrase such as
/// `find by name = :name order by age desc`, `count by status IS IN ( :s )`, or
/// `delete by id = $id`. The first word selects the query kind
/// (`find` → [TomSelect], `count` → [TomCount], `delete` → [TomDelete],
/// `group` → [TomGroupedSelect]); the part before `by` carries options
/// (`distinct`, `top`/`first` N, `skip`/`offset` M, and for `group` the
/// projection); the part after `by` is the predicate, optionally followed by a
/// `having <predicate>` clause and an `order by <fields> [asc|desc]` clause. The
/// predicate is parsed against the entity's resolved columns (via
/// [TomQueryBuilder] and [TomAnnotationAnalyzer]) into a [TomOperator] tree.
///
/// **Paging.** `top`/`first` N caps the rows; `skip`/`offset` M skips M of them
/// first, so page P of size N is `first N skip P*N`. A skip needs a cap — SQL
/// has no bare `OFFSET` — and a paged sentence should order by something
/// unique, or successive pages are cut from an order the database is free to
/// change between them.
///
/// **Sort direction.** A direction keyword applies to every field back to the
/// previous direction keyword, so `order by a b desc` sorts both descending
/// (one direction for the whole list, as it always did) while
/// `order by a desc b asc` mixes them.
///
/// **The grouped sentence.** `group` projects aggregates instead of entities:
///
/// ```text
/// group count ( * ) as total , sum ( amount ) as revenue over status
///   by createdAt >= :from having total > :minCount order by total desc
/// ```
///
/// The projection is a comma-separated list of `<fn> ( <arg> ) as <alias>`
/// (`count`/`sum`/`avg`/`min`/`max`; `count ( * )` for the row count, and a
/// leading `distinct` inside the parentheses for `count`/`sum`/`avg`). The
/// optional `over <fields>` names the group key — omit it to aggregate the
/// whole result set. `having` filters *groups* and so addresses the projection
/// **by alias**, where the `by` predicate filters *rows* and addresses columns.
///
/// Throws [TomQuerySyntaxException] for a malformed sentence (unknown kind,
/// both `top` and `first`, both `skip` and `offset`, a skip without a cap,
/// etc.).
///
/// (The select/count/delete branches currently build their option fields
/// independently; unifying them is a tracked follow-up.)
class TomQuerySentenceCompiler extends TomTypedPersistenceBase
    with TomQueryBuilder {
  /// Creates a compiler for the given entity [types] (the first is primary).
  TomQuerySentenceCompiler(super.types);

  /// Parses query sentence [qs] into a [TomSelect], [TomCount], or [TomDelete].
  TomQuery compileQuerySentence(String qs) {
    var parts = _splitQuerySentence(qs);
    var queryOptions = parts.sublist(0, _index(parts, "BY"));
    var whereClause = parts.sublist(_index(parts, "BY") + 1);

    final top = _countOption(
      queryOptions,
      qs,
      "TOP",
      "FIRST",
      "conflicting_top_first",
      "You may specify First or Top, but not both.",
    );
    final skip = _countOption(
      queryOptions,
      qs,
      "SKIP",
      "OFFSET",
      "conflicting_skip_offset",
      "You may specify Skip or Offset, but not both.",
    );
    final offset = skip > 0 ? skip : 0;
    if (offset > 0 && top <= 0) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.compile.skip_without_top",
        "The QuerySentence $qs cannot be compiled. Skip/Offset needs a row cap: "
            "SQL skips rows with LIMIT <n> OFFSET <m> and has no form that skips "
            "without also capping. Add First/Top <n>.",
      );
    }
    final kind = parts[0].toUpperCase();
    if (offset > 0 && kind != "FIND" && kind != "GROUP") {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.compile.skip_unsupported_for_kind",
        "The QuerySentence $qs cannot be compiled. Only Find and Group take a "
            "Skip/Offset: a Count of a filtered set does not depend on which "
            "page of it you are reading, and MariaDB's DELETE has no OFFSET.",
        parameters: {"kind": kind},
      );
    }
    var distinct = _find(queryOptions, "DISTINCT");
    var sort = _analyseOrderByClause(whereClause, qs);

    // The grouped kind splits its `having` clause off the where clause before
    // either predicate is built, so it branches ahead of the common build.
    if (kind == "GROUP") {
      return _compileGrouped(
        queryOptions,
        whereClause,
        qs,
        top: top,
        offset: offset,
        sort: sort,
      );
    }

    var query = _buildQuery(whereClause, qs).$1;

    if (kind == "FIND") {
      return TomSelect(
        types,
        distinct: distinct,
        top: top,
        offset: offset,
        sort: sort,
        query: query,
      );
    } else if (kind == "COUNT") {
      return TomCount(
        types,
        distinct: distinct,
        top: top,
        sort: sort,
        query: query,
      );
    } else if (kind == "DELETE") {
      return TomDelete(
        types,
        distinct: distinct,
        top: top,
        sort: sort,
        query: query,
      );
    } else {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.compile.invalid_query_sentence_start",
        "The QuerySentence $qs cannot be compiled. It must start with find...By, delete...By or count...By",
      );
    }
  }

  /// The aggregates a `having` clause may address, keyed by their projection
  /// alias — non-empty only while that clause is being parsed.
  ///
  /// `HAVING` filters groups, so its operands are the *projected* aggregates
  /// rather than the entity's columns. Publishing them here lets the one
  /// expression parser serve both predicates: [_buildExpression] resolves a
  /// token against this map before falling back to [determineColumn].
  Map<String, TomAggregate> _aliasOperands = const {};

  /// Compiles the `group` sentence kind into a [TomGroupedSelect].
  ///
  /// [queryOptions] is everything before `by` (the kind word, the optional
  /// window options `top`/`first` N and `skip`/`offset` M, the projection, and
  /// an optional `over <fields>`); [whereClause] is everything after it with the
  /// `order by` clause already stripped, so it is the row predicate optionally
  /// followed by `having`.
  TomGroupedSelect _compileGrouped(
    List<String> queryOptions,
    List<String> whereClause,
    String qs, {
    required int top,
    required int offset,
    required List<TomSortField> sort,
  }) {
    // Past the `group` keyword and any window options, whose values were
    // already read by the caller — what remains is the projection.
    int start = 1;
    while (start < queryOptions.length &&
        _windowOptions.contains(queryOptions[start].toUpperCase())) {
      start += 2;
    }
    final overIndex = _index(queryOptions, "OVER", start);
    final projectionTokens = queryOptions.sublist(
      start,
      overIndex == -1 ? queryOptions.length : overIndex,
    );
    final groupTokens = overIndex == -1
        ? const <String>[]
        : queryOptions.sublist(overIndex + 1);

    final aggregates = _parseAggregates(projectionTokens, qs);
    final groupBy = _parseGroupColumns(groupTokens, qs);

    final havingIndex = _index(whereClause, "HAVING");
    final rowTokens = havingIndex == -1
        ? whereClause
        : whereClause.sublist(0, havingIndex);
    final query = _buildQuery(rowTokens, qs).$1;

    TomOperator<TomDbBool>? having;
    if (havingIndex > -1) {
      final havingTokens = whereClause.sublist(havingIndex + 1);
      if (havingTokens.isEmpty) {
        throw TomQuerySyntaxException(
          "query_sentence_compiler.compile_grouped.empty_having",
          "The QuerySentence $qs cannot be compiled. HAVING must be followed by a predicate.",
        );
      }
      _aliasOperands = {for (final a in aggregates) a.alias: a};
      try {
        having = _buildQuery(havingTokens, qs).$1;
      } finally {
        _aliasOperands = const {};
      }
    }

    return TomGroupedSelect(
      types,
      query: query,
      groupBy: groupBy,
      aggregates: aggregates,
      having: having,
      sort: sort,
      top: top,
      offset: offset,
    );
  }

  /// Parses the comma-separated `over` field list into group-key columns.
  List<DbCol> _parseGroupColumns(List<String> tokens, String qs) {
    final columns = <DbCol>[];
    for (final token in tokens) {
      if (token == ",") continue;
      final column = determineColumn(token);
      final operator = _createColumn(column, token);
      columns.add(operator);
    }
    if (tokens.isNotEmpty && columns.isEmpty) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.compile_grouped.empty_over_clause",
        "The QuerySentence $qs cannot be compiled. OVER must be followed by at least one field.",
      );
    }
    return columns;
  }

  /// Parses the projection list — `<fn> ( <arg> ) as <alias>`, comma-separated
  /// — into the aggregate nodes the grouped select projects.
  List<TomAggregate> _parseAggregates(List<String> tokens, String qs) {
    final aggregates = <TomAggregate>[];
    int i = 0;
    while (i < tokens.length) {
      if (tokens[i] == ",") {
        i++;
        continue;
      }
      final function = _aggregateFunction(tokens[i], qs);
      i++;
      _expectToken(tokens, i, "(", qs);
      i++;

      bool distinct = false;
      if (i < tokens.length && tokens[i].toUpperCase() == "DISTINCT") {
        distinct = true;
        i++;
      }
      if (i >= tokens.length) {
        throw TomQuerySyntaxException(
          "query_sentence_compiler.parse_aggregates.missing_argument",
          "The QuerySentence $qs cannot be compiled. ${function.sqlName} is missing its argument.",
        );
      }
      final argument = tokens[i];
      i++;
      _expectToken(tokens, i, ")", qs);
      i++;
      _expectToken(tokens, i, "AS", qs);
      i++;
      if (i >= tokens.length) {
        throw TomQuerySyntaxException(
          "query_sentence_compiler.parse_aggregates.missing_alias",
          "The QuerySentence $qs cannot be compiled. ${function.sqlName} is missing the alias after AS.",
        );
      }
      final alias = tokens[i];
      i++;

      aggregates.add(
        argument == "*"
            ? _createCountAll(function, distinct, alias, qs)
            : _createAggregate(function, argument, distinct, alias, qs),
      );
    }
    return aggregates;
  }

  TomAggregateFunction _aggregateFunction(String token, String qs) {
    for (final function in TomAggregateFunction.values) {
      if (function.sqlName == token.toUpperCase()) return function;
    }
    throw TomQuerySyntaxException(
      "query_sentence_compiler.parse_aggregates.unknown_function",
      "The QuerySentence $qs cannot be compiled. [$token] is not an aggregate function "
          "(${TomAggregateFunction.values.map((f) => f.sqlName).join(', ')}).",
    );
  }

  void _expectToken(List<String> tokens, int at, String expected, String qs) {
    if (at < tokens.length && tokens[at].toUpperCase() == expected) return;
    throw TomQuerySyntaxException(
      "query_sentence_compiler.parse_aggregates.unexpected_token",
      "The QuerySentence $qs cannot be compiled. Expected [$expected] in the aggregate "
          "projection but found [${at < tokens.length ? tokens[at] : '<end of sentence>'}].",
    );
  }

  TomAggregate _createCountAll(
    TomAggregateFunction function,
    bool distinct,
    String alias,
    String qs,
  ) {
    // `*` is not an expression, so there is nothing to sum, average, or order:
    // only COUNT can take it, and DISTINCT has no operand to de-duplicate.
    if (function != TomAggregateFunction.count || distinct) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.parse_aggregates.star_only_for_count",
        "The QuerySentence $qs cannot be compiled. `*` is only valid as the argument of a plain COUNT.",
      );
    }
    return countAll(alias);
  }

  TomAggregate _createAggregate(
    TomAggregateFunction function,
    String field,
    bool distinct,
    String alias,
    String qs,
  ) {
    final operand = _createColumn(determineColumn(field), field);
    switch (function) {
      case TomAggregateFunction.count:
        return countOf(operand, alias, distinct: distinct);
      case TomAggregateFunction.sum:
        return sum(operand, alias, distinct: distinct);
      case TomAggregateFunction.avg:
        return avg(operand, alias, distinct: distinct);
      case TomAggregateFunction.min:
      case TomAggregateFunction.max:
        // MIN/MAX preserve the operand's type on both sides, so the node has to
        // be picked by the column's type rather than by the function alone.
        if (distinct) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.parse_aggregates.distinct_not_supported",
            "The QuerySentence $qs cannot be compiled. DISTINCT is meaningless for "
                "${function.sqlName} — the extreme of a set is the extreme of its distinct values.",
          );
        }
        final isMin = function == TomAggregateFunction.min;
        switch (operand) {
          case IntCol():
            return isMin ? minInt(operand, alias) : maxInt(operand, alias);
          case DoubleCol():
            return isMin
                ? minDouble(operand, alias)
                : maxDouble(operand, alias);
          case StringCol():
            return isMin ? minText(operand, alias) : maxText(operand, alias);
          case DateTimeCol():
            return isMin
                ? minDateTime(operand, alias)
                : maxDateTime(operand, alias);
          case DateCol():
            return isMin
                ? Min<TomDbDate, DateTime>(operand, alias)
                : Max<TomDbDate, DateTime>(operand, alias);
        }
        throw TomQuerySyntaxException(
          "query_sentence_compiler.parse_aggregates.unsupported_min_max_column",
          "The QuerySentence $qs cannot be compiled. ${function.sqlName} is not supported "
              "for column [$field] of type ${operand.runtimeType}.",
        );
    }
  }

  /// The option keywords that take a numeric argument, so the grouped branch
  /// knows how many tokens to skip before the projection starts.
  static const Set<String> _windowOptions = {"TOP", "FIRST", "SKIP", "OFFSET"};

  /// Reads the numeric option spelled either [keyA] or [keyB] out of [options],
  /// returning `-1` when neither appears.
  ///
  /// Naming the same option twice is a contradiction rather than a preference,
  /// so it is rejected with [conflictKey]; a non-numeric argument falls back to
  /// `1`, which is the behaviour `top`/`first` has always had.
  int _countOption(
    List<String> options,
    String qs,
    String keyA,
    String keyB,
    String conflictKey,
    String conflictMessage,
  ) {
    int index = _index(options, keyA);
    final other = _index(options, keyB);
    if (index > -1 && other > -1) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.compile.$conflictKey",
        "The QuerySentence $qs cannot be compiled. $conflictMessage",
      );
    }
    if (index == -1) index = other;
    if (index == -1) return -1;
    try {
      return int.parse(options[index + 1]);
    } catch (error) {
      return 1;
    }
  }

  /// Parses the trailing `order by <field> [asc|desc] …` clause into sort terms
  /// and strips it from [wc].
  ///
  /// A direction keyword applies to every field back to the previous direction
  /// keyword — so `order by a b desc` sorts both descending (the whole-list
  /// reading the clause has always had) and `order by a desc b asc` mixes them.
  /// Fields with no direction of their own default to ascending. Commas are
  /// accepted as separators and ignored.
  List<TomSortField> _analyseOrderByClause(List<String> wc, String qs) {
    final terms = <TomSortField>[];
    int orderIndex = _index(wc, "ORDER");
    if (orderIndex == -1) return const [];
    if (wc.length < orderIndex + 2) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.analyse_order_by.order_clause_missing_fields",
        "The QuerySentence $qs cannot be compiled. If you specify Order you must include the fields for ordering.",
      );
    }
    int partIndex = orderIndex + 1;
    try {
      if (wc[partIndex].toUpperCase() == "BY") {
        partIndex++;
      }
      if (wc.length < partIndex + 1) {
        throw TomQuerySyntaxException(
          "query_sentence_compiler.analyse_order_by.order_clause_missing_fields",
          "The QuerySentence $qs cannot be compiled. If you specify Order-By you must include the fields for ordering.",
        );
      }
      // Fields since the last direction keyword: the ones it will apply to.
      int undirected = 0;
      for (; partIndex < wc.length; partIndex++) {
        final token = wc[partIndex];
        if (token == ",") continue;
        final direction = _sortDirection(token);
        if (direction != null) {
          if (undirected == 0) {
            throw TomQuerySyntaxException(
              "query_sentence_compiler.analyse_order_by.direction_without_field",
              "The QuerySentence $qs cannot be compiled. '$token' must follow "
                  "the field(s) it orders.",
            );
          }
          for (var i = terms.length - undirected; i < terms.length; i++) {
            terms[i] = terms[i].withDirection(direction);
          }
          undirected = 0;
          continue;
        }
        terms.add(TomSortField.asc(token));
        undirected++;
      }
      if (terms.isEmpty) {
        throw TomQuerySyntaxException(
          "query_sentence_compiler.analyse_order_by.order_clause_missing_fields",
          "The QuerySentence $qs cannot be compiled. If you specify Order-By you must include the fields for ordering.",
        );
      }
      wc.removeRange(orderIndex, wc.length);
    } on TomQuerySyntaxException {
      rethrow;
    } catch (error, s) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.analyse_order_by.failed",
        "The QuerySentence $qs cannot be compiled. Failed to analyse order-by clause. $error",
        rootException: error,
        stack: s,
      );
    }
    return terms;
  }

  /// The direction [token] names, or `null` when it is not a direction keyword.
  static TomSortDirection? _sortDirection(String token) =>
      switch (token.toUpperCase()) {
        "ASC" || "ASCENDING" => TomSortDirection.ascending,
        "DESC" || "DESCENDING" => TomSortDirection.descending,
        _ => null,
      };

  bool _find(List<String> list, String key, [int startAt = 0]) {
    for (int i = startAt; i < list.length; i++) {
      if (list[i].toUpperCase() == key.toUpperCase()) return true;
    }
    return false;
  }

  int _index(List<String> list, String key, [int startAt = 0]) {
    for (int i = startAt; i < list.length; i++) {
      if (list[i].toUpperCase() == key.toUpperCase()) return i;
    }
    return -1;
  }

  bool _lookAhead(List<String> list, int start, int ahead, String forWhat) {
    if (list.length < start + ahead) return false;
    return list[start + ahead].toUpperCase() == forWhat.toUpperCase();
  }

  (TomOperator<TomDbBool>, int) _createEq(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) {
    int index;
    switch (current.returnType) {
      case TomDbString:
        TomOperator<TomDbString>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbString>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          eq<TomDbString>(current as TomOperator<TomDbString>, nextOperation),
          index,
        );
      case TomDbInt:
        TomOperator<TomDbInt>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbInt>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          eq<TomDbInt>(current as TomOperator<TomDbInt>, nextOperation),
          index,
        );
      case TomDbBool:
        TomOperator<TomDbBool>? nextOperation;
        (nextOperation, index) = _buildQuery(
          qp,
          qs,
          i,
          column,
          current as TomOperator<TomDbBool>,
        );
        return (eq<TomDbBool>(current, nextOperation), index);
      case TomDbDateTime:
        TomOperator<TomDbDateTime>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbDateTime>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          eq<TomDbDateTime>(
            current as TomOperator<TomDbDateTime>,
            nextOperation,
          ),
          index,
        );
      case TomDbDate:
        TomOperator<TomDbDate>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbDate>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          eq<TomDbDate>(current as TomOperator<TomDbDate>, nextOperation),
          index,
        );
    }
    throw TomQuerySyntaxException(
      "query_sentence_compiler.create_eq.failed",
      "Attempt to _create = operation for unknown type ${current.returnType}",
    );
  }

  (TomOperator<TomDbBool>, int) _createNeq(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) {
    int index;
    switch (current.returnType) {
      case TomDbString:
        TomOperator<TomDbString>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbString>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          neq<TomDbString>(current as TomOperator<TomDbString>, nextOperation),
          index,
        );
      case TomDbInt:
        TomOperator<TomDbInt>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbInt>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          neq<TomDbInt>(current as TomOperator<TomDbInt>, nextOperation),
          index,
        );
      case TomDbBool:
        TomOperator<TomDbBool>? nextOperation;
        (nextOperation, index) = _buildQuery(
          qp,
          qs,
          i,
          column,
          current as TomOperator<TomDbBool>,
        );
        return (neq<TomDbBool>(current, nextOperation), index);
      case TomDbDateTime:
        TomOperator<TomDbDateTime>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbDateTime>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          neq<TomDbDateTime>(
            current as TomOperator<TomDbDateTime>,
            nextOperation,
          ),
          index,
        );
      case TomDbDate:
        TomOperator<TomDbDate>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbDate>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          neq<TomDbDate>(current as TomOperator<TomDbDate>, nextOperation),
          index,
        );
    }
    throw TomQuerySyntaxException(
      "query_sentence_compiler.create_neq.failed",
      "Attempt to _create <> operation for unknown type ${current.returnType}",
    );
  }

  (TomOperator<TomDbBool>, int) _createLt(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) {
    int index;
    switch (current.returnType) {
      case TomDbString:
        TomOperator<TomDbString>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbString>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          lt<TomDbString>(current as TomOperator<TomDbString>, nextOperation),
          index,
        );
      case TomDbInt:
        TomOperator<TomDbInt>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbInt>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          lt<TomDbInt>(current as TomOperator<TomDbInt>, nextOperation),
          index,
        );
      case TomDbBool:
        TomOperator<TomDbBool>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbBool>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          lt<TomDbBool>(current as TomOperator<TomDbBool>, nextOperation),
          index,
        );
      case TomDbDateTime:
        TomOperator<TomDbDateTime>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbDateTime>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          lt<TomDbDateTime>(
            current as TomOperator<TomDbDateTime>,
            nextOperation,
          ),
          index,
        );
      case TomDbDate:
        TomOperator<TomDbDate>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbDate>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          lt<TomDbDate>(current as TomOperator<TomDbDate>, nextOperation),
          index,
        );
    }
    throw TomQuerySyntaxException(
      "query_sentence_compiler.create_lt.failed",
      "Attempt to _create < operation for unknown type ${current.returnType}",
    );
  }

  (TomOperator<TomDbBool>, int) _createLte(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) {
    int index;
    switch (current.returnType) {
      case TomDbString:
        TomOperator<TomDbString>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbString>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          lte<TomDbString>(current as TomOperator<TomDbString>, nextOperation),
          index,
        );
      case TomDbInt:
        TomOperator<TomDbInt>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbInt>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          lte<TomDbInt>(current as TomOperator<TomDbInt>, nextOperation),
          index,
        );
      case TomDbBool:
        TomOperator<TomDbBool>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbBool>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          lte<TomDbBool>(current as TomOperator<TomDbBool>, nextOperation),
          index,
        );
      case TomDbDateTime:
        TomOperator<TomDbDateTime>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbDateTime>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          lte<TomDbDateTime>(
            current as TomOperator<TomDbDateTime>,
            nextOperation,
          ),
          index,
        );
      case TomDbDate:
        TomOperator<TomDbDate>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbDate>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          lte<TomDbDate>(current as TomOperator<TomDbDate>, nextOperation),
          index,
        );
    }
    throw TomQuerySyntaxException(
      "query_sentence_compiler.create_lte.failed",
      "Attempt to _create <= operation for unknown type ${current.returnType}",
    );
  }

  (TomOperator<TomDbBool>, int) _createGt(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) {
    int index;
    switch (current.returnType) {
      case TomDbString:
        TomOperator<TomDbString>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbString>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          gt<TomDbString>(current as TomOperator<TomDbString>, nextOperation),
          index,
        );
      case TomDbInt:
        TomOperator<TomDbInt>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbInt>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          gt<TomDbInt>(current as TomOperator<TomDbInt>, nextOperation),
          index,
        );
      case TomDbBool:
        TomOperator<TomDbBool>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbBool>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          gt<TomDbBool>(current as TomOperator<TomDbBool>, nextOperation),
          index,
        );
      case TomDbDateTime:
        TomOperator<TomDbDateTime>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbDateTime>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          gt<TomDbDateTime>(
            current as TomOperator<TomDbDateTime>,
            nextOperation,
          ),
          index,
        );
      case TomDbDate:
        TomOperator<TomDbDate>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbDate>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          gt<TomDbDate>(current as TomOperator<TomDbDate>, nextOperation),
          index,
        );
    }
    throw TomQuerySyntaxException(
      "query_sentence_compiler.create_gt.failed",
      "Attempt to _create > operation for unknown type ${current.returnType}",
    );
  }

  (TomOperator<TomDbBool>, int) _createGte(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) {
    int index;
    switch (current.returnType) {
      case TomDbString:
        TomOperator<TomDbString>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbString>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          gte<TomDbString>(current as TomOperator<TomDbString>, nextOperation),
          index,
        );
      case TomDbInt:
        TomOperator<TomDbInt>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbInt>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          gte<TomDbInt>(current as TomOperator<TomDbInt>, nextOperation),
          index,
        );
      case TomDbBool:
        TomOperator<TomDbBool>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbBool>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          gte<TomDbBool>(current as TomOperator<TomDbBool>, nextOperation),
          index,
        );
      case TomDbDateTime:
        TomOperator<TomDbDateTime>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbDateTime>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          gte<TomDbDateTime>(
            current as TomOperator<TomDbDateTime>,
            nextOperation,
          ),
          index,
        );
      case TomDbDate:
        TomOperator<TomDbDate>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbDate>(
          qp,
          qs,
          i,
          column,
          current,
        );
        return (
          gte<TomDbDate>(current as TomOperator<TomDbDate>, nextOperation),
          index,
        );
    }
    throw TomQuerySyntaxException(
      "query_sentence_compiler.create_gte.failed",
      "Attempt to _create >= operation for unknown type ${current.returnType}",
    );
  }

  (TomOperator<TomDbBool>, int) _createIsIn(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) {
    switch (current.returnType) {
      case TomDbString:
        var (List<TomOperator<TomDbString>> options, index) = _getInOptions(
          i + 1,
          qp,
          qs,
          column,
          current,
        );
        return (
          isIn<TomDbString>(current as TomOperator<TomDbString>, options),
          index + 1,
        );
      case TomDbInt:
        var (List<TomOperator<TomDbInt>> options, index) = _getInOptions(
          i + 1,
          qp,
          qs,
          column,
          current,
        );
        return (
          isIn<TomDbInt>(current as TomOperator<TomDbInt>, options),
          index + 1,
        );
      case TomDbBool:
        var (List<TomOperator<TomDbBool>> options, index) = _getInOptions(
          i + 1,
          qp,
          qs,
          column,
          current,
        );
        return (
          isIn<TomDbBool>(current as TomOperator<TomDbBool>, options),
          index + 1,
        );
      case TomDbDateTime:
        var (List<TomOperator<TomDbDateTime>> options, index) = _getInOptions(
          i + 1,
          qp,
          qs,
          column,
          current,
        );
        return (
          isIn<TomDbDateTime>(current as TomOperator<TomDbDateTime>, options),
          index + 1,
        );
      case TomDbDate:
        var (List<TomOperator<TomDbDate>> options, index) = _getInOptions(
          i + 1,
          qp,
          qs,
          column,
          current,
        );
        return (
          isIn<TomDbDate>(current as TomOperator<TomDbDate>, options),
          index + 1,
        );
    }
    throw TomQuerySyntaxException(
      "query_sentence_compiler.create_is_in.failed",
      "Attempt to _create >= operation for unknown type ${current.returnType}",
    );
  }

  TomOperator<TomDbBool> _createIsNull(TomOperator current) {
    switch (current.returnType) {
      case TomDbString:
        return isNull<TomDbString>(current as TomOperator<TomDbString>);
      case TomDbInt:
        return isNull<TomDbInt>(current as TomOperator<TomDbInt>);
      case TomDbBool:
        return isNull<TomDbBool>(current as TomOperator<TomDbBool>);
      case TomDbDateTime:
        return isNull<TomDbDateTime>(current as TomOperator<TomDbDateTime>);
      case TomDbDate:
        return isNull<TomDbDate>(current as TomOperator<TomDbDate>);
    }
    throw TomQuerySyntaxException(
      "query_sentence_compiler.create_is_null.failed",
      "Attempt to _create IS NULL operation for unknown type ${current.returnType}",
    );
  }

  TomOperator<TomDbBool> _createIsNotNull(TomOperator current) {
    switch (current.returnType) {
      case TomDbString:
        return isNotNull<TomDbString>(current as TomOperator<TomDbString>);
      case TomDbInt:
        return isNotNull<TomDbInt>(current as TomOperator<TomDbInt>);
      case TomDbBool:
        return isNotNull<TomDbBool>(current as TomOperator<TomDbBool>);
      case TomDbDateTime:
        return isNotNull<TomDbDateTime>(current as TomOperator<TomDbDateTime>);
      case TomDbDate:
        return isNotNull<TomDbDate>(current as TomOperator<TomDbDate>);
    }
    throw TomQuerySyntaxException(
      "query_sentence_compiler.create_is_not_null.failed",
      "Attempt to _create IS NOT NULL operation for unknown type ${current.returnType}",
    );
  }

  (TomOperator<TomDbBool>, int) _buildQuery(
    List<String> qp,
    String qs, [
    int startAt = 0,
    TomColumnInformation? column,
    TomOperator<TomDbBool>? current,
    bool negate = false,
  ]) {
    TomOperator<TomDbBool>? currentOperation;
    bool inNegationMode = negate;
    int index = 0;
    for (int i = startAt; i < qp.length; i++) {
      if (qp[i] == "(") {
        TomOperator<TomDbBool>? nextOperation;
        (nextOperation, index) = _buildQuery(qp, qs, i + 1, column, current);
        currentOperation = nextOperation;
        currentOperation = group<TomDbBool>(currentOperation);
        i = index; // jump over the closing bracket
      } else if (qp[i] == ")") {
        if (currentOperation == null) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_query.unenclosing_closing_bracket",
            "Closing bracket without a valid operation to enclose.",
          );
        }
        if (inNegationMode) {
          currentOperation = not(currentOperation);
          inNegationMode = false;
        }
        return (currentOperation, i);
      } else if (qp[i].toUpperCase() == "AND") {
        if (currentOperation == null) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_query.and_without_current_operation",
            "AND without a current operation/previous expression",
          );
        }
        TomOperator<TomDbBool> nextOperation;
        (nextOperation, index) = _buildQuery(
          qp,
          qs,
          i + 1,
          column,
          currentOperation,
        );
        currentOperation = and([currentOperation, nextOperation]);
        i = index;
        return (currentOperation, i);
      } else if (qp[i].toUpperCase() == "OR") {
        if (currentOperation == null) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_query.or_without_current_operation",
            "OR without a current operation/previous expression",
          );
        }
        TomOperator<TomDbBool> nextOperation;
        (nextOperation, index) = _buildQuery(
          qp,
          qs,
          i + 1,
          column,
          currentOperation,
        );
        currentOperation = or([currentOperation, nextOperation]);
        i = index;
        return (currentOperation, i);
      } else if (qp[i].toUpperCase() == "NOT" &&
          !_lookAhead(qp, i, 1, "NULL") &&
          !_lookAhead(qp, i, 1, "LIKE")) {
        if (inNegationMode) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_query.double_not_usage",
            "NOT must not be used twice.",
          );
        }
        inNegationMode = true;
        index = i;
        continue;
      } else {
        var (nextOperation, indx) = _buildExpression<TomDbBool>(
          qp,
          qs,
          i,
          column,
          currentOperation,
        );
        currentOperation = nextOperation;
        i = indx;
        index = i;
      }
      if (inNegationMode) {
        currentOperation = not(currentOperation);
        inNegationMode = false;
      }
      index = i;
    }
    if (currentOperation == null) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.build_query.empty_invalid_query_nothing_built",
        "Empty/Invalid query. No expression was built to return.",
      );
    }
    return (currentOperation, index);
  }

  /// Returns [current] as the left operand of a comparison, or throws.
  ///
  /// A valid operand is a column reference — or, inside a `having` clause, one
  /// of the projected aggregates: `HAVING COUNT(*) > 3` compares a *group's*
  /// value, so the operand there is an aggregate rather than a column. [key]
  /// and [message] identify the operator so the failure names it.
  TomOperator _requireComparisonOperand(
    TomOperator? current,
    String key,
    String message,
  ) {
    if (current is DbCol || current is TomAggregate) return current!;
    throw TomQuerySyntaxException(key, message);
  }

  (TomOperator<QT>, int) _buildExpression<QT>(
    List<String> qp,
    String qs, [
    int startAt = 0,
    TomColumnInformation? column,
    TomOperator? current,
    bool negate = false,
  ]) {
    TomOperator<QT>? currentOperation;
    bool inNegationMode = negate;
    int index = 0;
    for (int i = startAt; i < qp.length; i++) {
      if (qp[i].startsWith(r"$") ||
          qp[i].startsWith(r":") ||
          qp[i].startsWith(r"@")) {
        if (column == null && current is! TomAggregate) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.parameter_without_column",
            "Reached parameter before a column had been determined.",
          );
        }
        // Against an aggregate there is no column to take the type from — but
        // the caller already dispatched on the aggregate's SQL type, so [QT]
        // *is* the parameter's type (`HAVING n > :minCount` → `TomDbInt`).
        currentOperation = column == null
            ? Parameter<QT>(qp[i].substring(1))
            : _createParameter<QT>(column, qp[i].substring(1));
        //i++;
        index = i;
        break;
      } else if (qp[i].toUpperCase() == "IS" &&
          _lookAhead(qp, i, 1, "NOT") &&
          _lookAhead(qp, i, 2, "NULL")) {
        if (current == null || current is! DbCol) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.is_not_null_test_without_column",
            "IS NOT NULL test without a column",
          );
        }
        if (QT != TomDbBool) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.is_not_null_invalid_type_expected",
            "IS NOT NULL is always of type bool, but the required type is $QT",
          );
        }
        currentOperation = _createIsNotNull(current) as TomOperator<QT>;
        i += 2;
        index = i;
        break;
      } else if (qp[i].toUpperCase() == "IS" && _lookAhead(qp, i, 1, "NULL")) {
        if (current == null || current is! DbCol) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.is_null_test_without_column",
            "IS NULL test without a column",
          );
        }
        if (QT != TomDbBool) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.is_null_invalid_type_expected",
            "IS NULL is always of type bool, but the required type is $QT",
          );
        }
        currentOperation = _createIsNull(current) as TomOperator<QT>;
        i++;
        index = i;
        break;
      } else if (qp[i].toUpperCase() == "IS" &&
          _lookAhead(qp, i, 1, "NOT") &&
          _lookAhead(qp, i, 2, "IN") &&
          _lookAhead(qp, i, 3, "(")) {
        if (current == null || current is! DbCol) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.is_not_in_test_without_column",
            "IS NOT IN test without a column",
          );
        }
        if (QT != TomDbBool) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.is_not_in_invalid_type_expected",
            "IS NOT IN is always of type bool, but the required type is $QT",
          );
        }
        var (operator, indx) = _createIsIn(qp, qs, i + 3, column, current);
        currentOperation = not(operator) as TomOperator<QT>;
        i = indx;
        index = i;
        break;
      } else if (qp[i].toUpperCase() == "IS" &&
          _lookAhead(qp, i, 1, "IN") &&
          _lookAhead(qp, i, 2, "(")) {
        if (current == null || current is! DbCol) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.is_in_test_without_column",
            "IS IN test without a column",
          );
        }
        if (QT != TomDbBool) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.is_in_invalid_type_expected",
            "IS IN is always of type bool, but the required type is $QT",
          );
        }
        var (operator, indx) = _createIsIn(qp, qs, i + 2, column, current);
        currentOperation = operator as TomOperator<QT>;
        i = indx;
        index = i;
        break;
      } else if (qp[i].toUpperCase() == "NOT" && _lookAhead(qp, i, 1, "LIKE")) {
        if (current == null || current is! DbCol) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.not_like_test_without_column",
            "NOT LIKE test without a column",
          );
        }
        if (current is! StringCol) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.not_like_invalid_column_type",
            "NOT LIKE is always for type String, but the column is of type $currentOperation",
          );
        }
        if (QT != TomDbBool) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.not_like_invalid_type_expected",
            "NOT LIKE is always for type bool, but the required type is $QT",
          );
        }
        TomOperator<TomDbString>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbString>(
          qp,
          qs,
          i + 2,
          column,
          current,
        );
        currentOperation =
            notLike(current as TomOperator<TomDbString>, nextOperation)
                as TomOperator<QT>;
        i = index;
        break;
      } else if (qp[i].toUpperCase() == "NOT" &&
          !_lookAhead(qp, i, 1, "NULL") &&
          !_lookAhead(qp, i, 1, "NULL")) {
        if (QT != TomDbBool) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.not_invalid_type_expected",
            "NOT is always for type bool, but the required type is $QT",
          );
        }
        if (inNegationMode) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.double_not_usage",
            "NOT must not be used twice.",
          );
        }
        inNegationMode = true;
        index = i;
        continue;
      } else if (qp[i].toUpperCase() == "LIKE") {
        if (current == null || current is! DbCol) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.like_test_without_column",
            "LIKE test without a column",
          );
        }
        if (current is! StringCol) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.like_invalid_column_type",
            "LIKE is always for type String, but the column is of type $currentOperation",
          );
        }
        if (QT != TomDbBool) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.like_invalid_type_expected",
            "LIKE is always for type bool, but the required type is $QT",
          );
        }
        TomOperator<TomDbString>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbString>(
          qp,
          qs,
          i + 1,
          column,
          current,
        );
        currentOperation =
            like(current as TomOperator<TomDbString>, nextOperation)
                as TomOperator<QT>;
        i = index;
        break;
      } else if (qp[i].toUpperCase() == "REGEXP") {
        if (current == null || current is! DbCol) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.regexp_test_without_column",
            "REGEXP test without a column",
          );
        }
        if (QT != TomDbBool) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.regexp_invalid_type_expected",
            "REGEXP is always for type bool, but the required type is $QT",
          );
        }
        if (current is! StringCol) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.regexp_invalid_column_type",
            "REGEXP is always for type String, but the column is of type $currentOperation",
          );
        }
        TomOperator<TomDbString>? nextOperation;
        (nextOperation, index) = _buildExpression<TomDbString>(
          qp,
          qs,
          i + 1,
          column,
          current,
        );
        currentOperation =
            regexp(current as TomOperator<TomDbString>, nextOperation)
                as TomOperator<QT>;
        i = index;
        break;
      } else if (qp[i].toUpperCase() == "=") {
        final operand = _requireComparisonOperand(
          current,
          "query_sentence_compiler.build_expression.eq_without_column",
          "= without a column",
        );
        if (QT != TomDbBool) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.eq_invalid_type_expected",
            "= is always for type bool, but the required type is $QT",
          );
        }
        var (operator, indx) = _createEq(qp, qs, i + 1, column, operand);
        currentOperation = operator as TomOperator<QT>;
        i = indx;
        index = i;
        break;
      } else if (qp[i].toUpperCase() == "<>") {
        final operand = _requireComparisonOperand(
          current,
          "query_sentence_compiler.build_expression.neq_without_column",
          "<> without a column",
        );
        var (operator, indx) = _createNeq(qp, qs, i + 1, column, operand);
        currentOperation = operator as TomOperator<QT>;
        i = indx;
        index = i;
        break;
      } else if (qp[i].toUpperCase() == "<=") {
        final operand = _requireComparisonOperand(
          current,
          "query_sentence_compiler.build_expression.lte_without_column",
          "<= without a column",
        );
        var (operator, indx) = _createLte(qp, qs, i + 1, column, operand);
        currentOperation = operator as TomOperator<QT>;
        i = indx;
        index = i;
        break;
      } else if (qp[i].toUpperCase() == "<") {
        final operand = _requireComparisonOperand(
          current,
          "query_sentence_compiler.build_expression.lt_without_column",
          "< without a column",
        );
        var (operator, indx) = _createLt(qp, qs, i + 1, column, operand);
        currentOperation = operator as TomOperator<QT>;
        i = indx;
        index = i;
        break;
      } else if (qp[i].toUpperCase() == ">=") {
        final operand = _requireComparisonOperand(
          current,
          "query_sentence_compiler.build_expression.gte_without_column",
          ">= without a column",
        );
        var (operator, indx) = _createGte(qp, qs, i + 1, column, operand);
        currentOperation = operator as TomOperator<QT>;
        i = indx;
        index = i;
        break;
      } else if (qp[i].toUpperCase() == ">") {
        final operand = _requireComparisonOperand(
          current,
          "query_sentence_compiler.build_expression.gt_without_column",
          "> without a column",
        );
        var (operator, indx) = _createGt(qp, qs, i + 1, column, operand);
        currentOperation = operator as TomOperator<QT>;
        i = indx;
        index = i;
        break;
      } else if (qp[i].startsWith("'") && qp[i].endsWith("'")) {
        if (qp[i].length < 2) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.invalid_string_literal",
            "Not a valid string [${qp[i]}]",
          );
        }
        if (QT != TomDbString) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.string_literal_invalid_type_expected",
            "A String literal is always for type String, but the required type is $QT",
          );
        }
        String value = qp[i].substring(1, qp[i].length - 1);
        currentOperation = text(value) as TomOperator<QT>;
        // i++;
        index = i;
        break;
      } else if (qp[i] == "TRUE") {
        if (QT != TomDbBool) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.bool_literal_invalid_type_expected_true",
            "A bool literal is always for type bool, but the required type is $QT",
          );
        }
        currentOperation = boolOp(true) as TomOperator<QT>;
        // i++;
        index = i;
        break;
      } else if (qp[i] == "FALSE") {
        if (QT != TomDbBool) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.bool_literal_invalid_type_expected_false",
            "A bool literal is always for type bool, but the required type is $QT",
          );
        }
        currentOperation = boolOp(false) as TomOperator<QT>;
        // i++;
        index = i;
        break;
      } else if (RegExp(r"[0-9]+").hasMatch(qp[i])) {
        if (QT != TomDbInt) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.int_literal_invalid_type_expected",
            "A integer literal is always for type integer, but the required type is $QT",
          );
        }
        if (inNegationMode) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.int_literal_negation_attempt",
            "You can't negate an integer literal: ${qp[i]}",
          );
        }
        currentOperation = intOp(int.parse(qp[i])) as TomOperator<QT>;
        // i++;
        index = i;
        break;
      } else if (RegExp(r"[0-9]+[.,][0-9]*").hasMatch(qp[i])) {
        if (QT != TomDbDouble) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.double_literal_invalid_type_expected",
            "A double literal is always for type double, but the required type is $QT",
          );
        }
        if (inNegationMode) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.double_literal_negation_attempt",
            "You can't negate an double literal: ${qp[i]}",
          );
        }
        currentOperation = doubleOp(double.parse(qp[i])) as TomOperator<QT>;
        // i++;
        index = i;
        break;
      } else if (RegExp(r"[0-9]{4}-[0-9]{2}-[0-9]{2}").hasMatch(qp[i])) {
        if (QT != TomDbDate) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.date_literal_invalid_type_expected",
            "A date literal is always for type date, but the required type is $QT",
          );
        }
        if (inNegationMode) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.date_literal_negation_attempt",
            "You can't negate an date literal: ${qp[i]}",
          );
        }
        currentOperation = dateOp(DateTime.parse(qp[i])) as TomOperator<QT>;
        // i++;
        index = i;
        break;
      } else if (RegExp(
        r"[0-9]{4}-?[0-9]{2}-?[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}(Z|([+\-][0-9]{2}:[0-9]{2}))",
      ).hasMatch(qp[i])) {
        if (QT != TomDbDateTime) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.datetime_literal_invalid_type_expected",
            "A datetime literal is always for type datetime, but the required type is $QT",
          );
        }
        if (inNegationMode) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.datetime_literal_negation_attempt",
            "You can't negate an datetime literal: ${qp[i]}",
          );
        }
        currentOperation = dateTimeOp(DateTime.parse(qp[i])) as TomOperator<QT>;
        // i++;
        index = i;
        break;
      } else if (_aliasOperands.containsKey(qp[i])) {
        // A `having` operand: the token names one of the projected aggregates,
        // so the comparison that follows is built against that node instead of
        // against a column — and carries no column, because a group's value
        // has none.
        final aggregate = _aliasOperands[qp[i]]!;
        var (operator, indx) = _buildExpression<TomDbBool>(
          qp,
          qs,
          i + 1,
          null,
          aggregate,
        );
        currentOperation = operator as TomOperator<QT>;
        if (inNegationMode) {
          currentOperation =
              not(currentOperation as TomOperator<TomDbBool>)
                  as TomOperator<QT>;
        }
        return (currentOperation, indx);
      } else {
        if (column == null) {
          column = determineColumn(qp[i]);
          var (operator, indx) = _buildExpression<TomDbBool>(
            qp,
            qs,
            i + 1,
            column,
            _createColumn(column, qp[i]),
            inNegationMode,
          );
          try {
            currentOperation = operator as TomOperator<QT>;
            if (inNegationMode) {
              currentOperation =
                  not(currentOperation as TomOperator<TomDbBool>)
                      as TomOperator<QT>;
            }
            return (currentOperation, indx);
          } catch (e, s) {
            throw TomQuerySyntaxException(
              "query_sentence_compiler.build_expression.column-type-mismatch_after_creation_new_column",
              "Casting $operator to $QT failed after creation of column operation for token ${qp[i]}. Type should be TomDbBool",
              rootException: e,
              stack: s,
            );
          }
        } else {
          var argColumn = determineColumn(qp[i]);
          var newColumn = _createColumn(argColumn, qp[i]);

          try {
            currentOperation = newColumn as TomOperator<QT>;
          } catch (e, s) {
            throw TomQuerySyntaxException(
              "query_sentence_compiler.build_expression.column-type-mismatch_after_creation_second_column",
              "Casting $newColumn to $QT failed. Current column $column. Was creating column operation for token ${qp[i]}",
              rootException: e,
              stack: s,
            );
          }
          index = i;
          break;
        }
      }
    }
    if (inNegationMode) {
      if (QT == TomDbBool) {
        currentOperation =
            not(currentOperation as TomOperator<TomDbBool>) as TomOperator<QT>;
        inNegationMode = false;
      } else {
        throw TomQuerySyntaxException(
          "query_sentence_compiler.build_expression.negation_of_non_bool",
          "Attempt to negate a non-bool expression $currentOperation",
        );
      }
    }
    return (currentOperation!, index);
  }

  (List<TomOperator<OT>>, int) _getInOptions<OT>(
    int i,
    List<String> qp,
    String qs,
    TomColumnInformation? column,
    TomOperator? currentOperation,
  ) {
    if (OT == TomDbBool) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.get_in_options.boolean_column_in_not_allowed",
        "Attempt to do IS IN/IS NOT IN with a boolean column.",
      );
    }
    List<TomOperator<OT>> options = [];
    var scanAt = i; // after the bracket
    while (qp[scanAt] != ")") {
      // stop at closing bracket
      if (qp[scanAt] == ",") {
        // jump over commas
        scanAt++;
        continue;
      }
      var (nextExpression, index) = _buildExpression<OT>(
        qp,
        qs,
        scanAt,
        column,
        currentOperation,
      );
      options.add(nextExpression);
      scanAt = index + 1;
    }
    return (options, scanAt);
  }

  Parameter<QT> _createParameter<QT>(
    TomColumnInformation column,
    String field,
  ) {
    // Complete for all types
    switch (column.declaredType) {
      case TomString:
      case String:
      case TomNString:
        return Parameter<TomDbString>(field) as Parameter<QT>;
      case int:
      case TomInt:
      case TomNInt:
        return Parameter<TomDbInt>(field) as Parameter<QT>;
      case bool:
      case TomBool:
      case TomNBool:
        return Parameter<TomDbBool>(field) as Parameter<QT>;
      case DateTime:
      case TomZonedDateTime:
      case TomNDateTime:
        return Parameter<TomDbDateTime>(field) as Parameter<QT>;
      case TomZonedDate:
        return Parameter<TomDbDate>(field) as Parameter<QT>;
    }
    throw TomQuerySyntaxException(
      "query_sentence_compiler.create_parameter.failed",
      "Could not determine type for parameter $field for column $column",
    );
  }

  DbCol _createColumn(TomColumnInformation column, String field) {
    // Complete for all types
    if (column.column?.columnType != null) {
      switch (column.column!.columnType) {
        case String:
        case TomDbString:
        case TomString:
        case TomNString:
          return StringCol(column.tableType, field, column);
        case int:
        case TomDbInt:
        case TomInt:
        case TomNInt:
          return IntCol(column.tableType, field, column);
        case bool:
        case TomDbBool:
        case TomBool:
        case TomNBool:
          return BoolCol(column.tableType, field, column);
        case DateTime:
        case TomDbDateTime:
        case TomZonedDateTime:
        case TomNDateTime:
          return DateTimeCol(column.tableType, field, column);
        case TomZonedDate:
        case TomDbDate:
          return DateCol(column.tableType, field, column);
      }
    }
    switch (column.declaredType) {
      case String:
      case TomString:
      case TomNString:
        return StringCol(column.tableType, field, column);
      case int:
      case TomInt:
      case TomNInt:
        return IntCol(column.tableType, field, column);
      case bool:
      case TomBool:
      case TomNBool:
        return BoolCol(column.tableType, field, column);
      case DateTime:
      case TomZonedDateTime:
      case TomNDateTime:
        // The `return` is load-bearing. Without it the node was
        // constructed and dropped, control fell out of the switch, and a
        // timestamp column with no explicit `columnType:` was reported as
        // untypeable — so no query sentence could carry a date predicate
        // unless the entity spelled the type out by hand.
        return DateTimeCol(column.tableType, field, column);
      case TomZonedDate:
        return DateCol(column.tableType, field, column);
    }
    throw TomQuerySyntaxException(
      "query_sentence_compiler.create_column.failed",
      "Could not determine type for column $field @ $column",
    );
  }

  List<String> _splitQuerySentence(String qs) {
    qs = qs.replaceAllMapped(RegExp("[,()=<>][=>]?"), (m) => " ${m.group(0)} ");
    qs = qs.replaceAll(RegExp(" +"), " ");
    qs = qs.trim();
    var parts = qs.split(" ");
    return parts;
  }
}

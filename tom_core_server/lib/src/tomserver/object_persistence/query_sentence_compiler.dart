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

/// A two-operand comparison node factory: [TomQueryBuilder.eq],
/// [TomQueryBuilder.neq], [TomQueryBuilder.lt], [TomQueryBuilder.lte],
/// [TomQueryBuilder.gt] and [TomQueryBuilder.gte] all have this shape.
///
/// Naming it is what lets a *single* dispatch over the operand's SQL type serve
/// all six operators. Without it each operator needs its own copy of the
/// switch, and a type added to one is silently missing from the other five —
/// which is exactly how `double` came to be unsupported.
typedef _ComparisonFactory =
    TomOperator<TomDbBool> Function<T>(TomOperator<T>, TomOperator<T>);

/// A one-operand predicate factory: [TomQueryBuilder.isNull] and
/// [TomQueryBuilder.isNotNull].
typedef _UnaryPredicateFactory =
    TomOperator<TomDbBool> Function<T>(TomOperator<T>);

/// One kind of scalar value a query sentence can spell **inline**, as opposed
/// to binding it — `find by priority > 3`, `find by due = 2026-07-05`.
///
/// The four kinds are recognised by shape alone, and their shapes nest: every
/// datetime literal contains a date, every date contains digits, and a bare
/// digit test matches any token that merely *contains* one. So two rules keep
/// them all reachable, and both are load-bearing —
///
/// * every [pattern] is **anchored**, so a token matches a kind only by being
///   that kind entirely rather than by containing one somewhere; and
/// * `_scalarLiterals` is ordered **most specific first**, so the datetime is
///   tested before the date it contains and the date before its digits.
///
/// Drop either and the later kinds become unreachable: the token is claimed by
/// a broader rule that then rejects it for having the wrong type.
class _ScalarLiteral {
  const _ScalarLiteral({
    required this.kind,
    required this.noun,
    required this.sqlType,
    required this.pattern,
    required this.build,
  });

  /// Names the kind in the exception key (`<kind>_literal_…`).
  final String kind;

  /// Names the kind, with its article, in the exception message.
  final String noun;

  /// The SQL type a literal of this kind can stand for.
  final Type sqlType;

  /// Anchored — see the class comment.
  final RegExp pattern;

  /// Builds the literal node from the matched token.
  final TomOperator Function(TomQueryBuilder builder, String token) build;
}

/// The scalar literal kinds, **most specific first** — see [_ScalarLiteral].
///
/// A decimal is written with a point. The comma form is not accepted, and
/// cannot be: `_splitQuerySentence` puts spaces around every `,` so that an
/// `IS IN ( a , b )` list separates, which would tear `1,5` into three tokens
/// before any literal rule saw it — and a comma that could be either a decimal
/// point or a list separator is ambiguous in exactly the place `IS IN` needs it
/// not to be.
final _scalarLiterals = <_ScalarLiteral>[
  _ScalarLiteral(
    kind: 'datetime',
    noun: 'a datetime',
    sqlType: TomDbDateTime,
    pattern: RegExp(
      r"^[0-9]{4}-?[0-9]{2}-?[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+\-][0-9]{2}:[0-9]{2})$",
    ),
    build: (builder, token) => builder.dateTimeOp(DateTime.parse(token)),
  ),
  _ScalarLiteral(
    kind: 'date',
    noun: 'a date',
    sqlType: TomDbDate,
    pattern: RegExp(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"),
    build: (builder, token) => builder.dateOp(DateTime.parse(token)),
  ),
  _ScalarLiteral(
    kind: 'double',
    noun: 'a double',
    sqlType: TomDbDouble,
    pattern: RegExp(r"^[-+]?([0-9]+\.[0-9]*|\.[0-9]+)$"),
    build: (builder, token) => builder.doubleOp(double.parse(token)),
  ),
  _ScalarLiteral(
    kind: 'int',
    noun: 'an integer',
    sqlType: TomDbInt,
    pattern: RegExp(r"^[-+]?[0-9]+$"),
    build: (builder, token) => builder.intOp(int.parse(token)),
  ),
];

/// The literal kind [token] spells, or `null` if it spells none — in which case
/// it is an identifier (a column or a `having` alias), not a value.
_ScalarLiteral? _scalarLiteralFor(String token) {
  for (final literal in _scalarLiterals) {
    if (literal.pattern.hasMatch(token)) return literal;
  }
  return null;
}

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
    if (kind == "COUNT" && top > 0) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.compile.top_unsupported_for_count",
        "The QuerySentence $qs cannot be compiled. A Count takes no First/Top: "
            "LIMIT caps the rows returned, and a count returns one row whatever"
            " the cap, so a capped count would count the whole filtered set and"
            " then cap nothing.",
        parameters: {"kind": kind},
      );
    }
    // Reachable for DELETE only: a Skip needs a cap (checked above), and the
    // rule right above denies a Count one, so no Count sentence gets this far.
    if (offset > 0 && kind != "FIND" && kind != "GROUP") {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.compile.skip_unsupported_for_kind",
        "The QuerySentence $qs cannot be compiled. Only Find and Group take a "
            "Skip/Offset: MariaDB's DELETE has no OFFSET.",
        parameters: {"kind": kind},
      );
    }
    var distinct = _find(queryOptions, "DISTINCT");
    var sort = _analyseOrderByClause(whereClause, qs);
    if (kind == "COUNT" && sort.isNotEmpty) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.compile.order_by_unsupported_for_count",
        "The QuerySentence $qs cannot be compiled. A Count takes no Order By: "
            "the statement returns a single row, so an ordering has nothing to "
            "order. Use Group to order aggregates.",
        parameters: {"kind": kind},
      );
    }

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
      // No window and no ordering: both were rejected above, so there is
      // nothing left to forward but the projection options.
      return TomCount(types, distinct: distinct, query: query);
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
  /// so it is rejected with [conflictKey]. The argument itself is rejected —
  /// never guessed at — when it is missing, non-numeric, or negative: a window
  /// the compiler had to invent would return a different result set than the
  /// sentence asked for, without saying so.
  ///
  /// Zero is accepted and means *unpaged*, the reading
  /// [TomPageRequest.assertWindow] gives `limit: 0` for a window built
  /// programmatically. Negative is refused for the same reason it is there, and
  /// for one more here: `-1` is this method's own "absent" sentinel, so an
  /// accepted `first -1` could not be told apart from a sentence with no cap.
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

    // The keyword as the author spelled it: `top` and `first` are one option
    // internally, and quoting the other one sends the reader looking for a
    // word their sentence does not contain.
    final keyword = options[index].toLowerCase();
    if (index + 1 >= options.length) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.compile.${keyword}_missing_argument",
        "The QuerySentence $qs cannot be compiled. [$keyword] takes a row "
            "count, but the sentence reaches [by] with nothing after it.",
        parameters: {"option": keyword},
      );
    }
    final argument = options[index + 1];
    final count = int.tryParse(argument);
    if (count == null) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.compile.${keyword}_not_numeric",
        "The QuerySentence $qs cannot be compiled. [$keyword] takes a whole "
            "row count, but [$argument] is not one.",
        parameters: {"option": keyword, "argument": argument},
      );
    }
    if (count < 0) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.compile.${keyword}_negative",
        "The QuerySentence $qs cannot be compiled. [$keyword] may not be "
            "negative, but was $count. Use 0 for no $keyword at all.",
        parameters: {"option": keyword, "argument": count},
      );
    }
    return count;
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

  /// Whether the token [ahead] positions past [start] is [forWhat].
  ///
  /// Answers `false` when the sentence ends first. The bound is `<=` because
  /// the token being asked about is at index `start + ahead`, so a list of
  /// exactly that length does not contain it — reading it is one past the end.
  /// While the check was `<`, a sentence ending on a keyword that looks ahead
  /// (`… title not`) threw `RangeError` out of the compiler instead of a
  /// [TomQuerySyntaxException], escaping the family callers catch on.
  bool _lookAhead(List<String> list, int start, int ahead, String forWhat) {
    if (list.length <= start + ahead) return false;
    return list[start + ahead].toUpperCase() == forWhat.toUpperCase();
  }

  /// Dispatches a two-operand comparison on the SQL type of its left operand.
  ///
  /// The right-hand side is parsed *as* that type, so the parse and the node
  /// construction have to agree — which is why this is one method taking a
  /// [build] factory rather than a copy of the switch per operator. [key] and
  /// [symbol] name the operator in the failure a type outside the switch
  /// produces, so the six callers stay distinguishable in an error message.
  ///
  /// [groupedBoolOperand] selects how the right-hand side of a comparison
  /// against a *boolean* operand is parsed. `=` and `<>` route it through
  /// [_buildQuery], so `done = ( a > 1 or b > 2 )` compares against a whole
  /// predicate; the four ordering comparisons parse a plain expression instead.
  /// The distinction predates this dispatch and is preserved deliberately —
  /// collapsing it would silently widen what `<` accepts.
  (TomOperator<TomDbBool>, int) _createComparison(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current, {
    required _ComparisonFactory build,
    required String key,
    required String symbol,
    required bool groupedBoolOperand,
  }) {
    (TomOperator<TomDbBool>, int) compareAs<T>() {
      final (nextOperation, index) = _buildExpression<T>(
        qp,
        qs,
        i,
        column,
        current,
      );
      return (build<T>(current as TomOperator<T>, nextOperation), index);
    }

    switch (current.returnType) {
      case TomDbString:
        return compareAs<TomDbString>();
      case TomDbInt:
        return compareAs<TomDbInt>();
      case TomDbDouble:
        return compareAs<TomDbDouble>();
      case TomDbDateTime:
        return compareAs<TomDbDateTime>();
      case TomDbDate:
        return compareAs<TomDbDate>();
      case TomDbBool:
        if (!groupedBoolOperand) return compareAs<TomDbBool>();
        final operand = current as TomOperator<TomDbBool>;
        final (nextOperation, index) = _buildQuery(qp, qs, i, column, operand);
        return (build<TomDbBool>(operand, nextOperation), index);
    }
    throw TomQuerySyntaxException(
      key,
      "Attempt to _create $symbol operation for unknown type ${current.returnType}",
    );
  }

  (TomOperator<TomDbBool>, int) _createEq(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) => _createComparison(
    qp,
    qs,
    i,
    column,
    current,
    build: eq,
    key: "query_sentence_compiler.create_eq.failed",
    symbol: "=",
    groupedBoolOperand: true,
  );

  (TomOperator<TomDbBool>, int) _createNeq(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) => _createComparison(
    qp,
    qs,
    i,
    column,
    current,
    build: neq,
    key: "query_sentence_compiler.create_neq.failed",
    symbol: "<>",
    groupedBoolOperand: true,
  );

  (TomOperator<TomDbBool>, int) _createLt(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) => _createComparison(
    qp,
    qs,
    i,
    column,
    current,
    build: lt,
    key: "query_sentence_compiler.create_lt.failed",
    symbol: "<",
    groupedBoolOperand: false,
  );

  (TomOperator<TomDbBool>, int) _createLte(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) => _createComparison(
    qp,
    qs,
    i,
    column,
    current,
    build: lte,
    key: "query_sentence_compiler.create_lte.failed",
    symbol: "<=",
    groupedBoolOperand: false,
  );

  (TomOperator<TomDbBool>, int) _createGt(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) => _createComparison(
    qp,
    qs,
    i,
    column,
    current,
    build: gt,
    key: "query_sentence_compiler.create_gt.failed",
    symbol: ">",
    groupedBoolOperand: false,
  );

  (TomOperator<TomDbBool>, int) _createGte(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) => _createComparison(
    qp,
    qs,
    i,
    column,
    current,
    build: gte,
    key: "query_sentence_compiler.create_gte.failed",
    symbol: ">=",
    groupedBoolOperand: false,
  );

  /// `<column> IN ( <options...> )`, with the options parsed as the column's
  /// own type so a bind or literal in the list cannot be typed differently
  /// from what it is compared against.
  ///
  /// A boolean column reaches [_getInOptions] and is refused there: `IN` over
  /// two possible values is a predicate written the long way round.
  ///
  /// Returns the index of the **last token consumed**, which is the closing
  /// bracket — the same contract every other branch of [_buildExpression] keeps
  /// (`IS NULL` returns the index of `null`, not the one after it), because the
  /// caller resumes with `i = index` and then increments. Reporting one more
  /// than that skipped whatever followed the list: with `and` there, the
  /// conjunction was never seen and `id is in ( 1 , 2 ) and done = TRUE`
  /// compiled to `done = true` alone, silently dropping the `IN` filter.
  (TomOperator<TomDbBool>, int) _createIsIn(
    List<String> qp,
    String qs,
    int i,
    TomColumnInformation? column,
    TomOperator current,
  ) {
    (TomOperator<TomDbBool>, int) inOptionsAs<T>() {
      final (List<TomOperator<T>> options, index) = _getInOptions<T>(
        i + 1,
        qp,
        qs,
        column,
        current,
      );
      return (isIn<T>(current as TomOperator<T>, options), index);
    }

    switch (current.returnType) {
      case TomDbString:
        return inOptionsAs<TomDbString>();
      case TomDbInt:
        return inOptionsAs<TomDbInt>();
      case TomDbDouble:
        return inOptionsAs<TomDbDouble>();
      case TomDbBool:
        return inOptionsAs<TomDbBool>();
      case TomDbDateTime:
        return inOptionsAs<TomDbDateTime>();
      case TomDbDate:
        return inOptionsAs<TomDbDate>();
    }
    // The only failure message in the `_create*` family still written out by
    // hand — its eight relatives interpolate the operator from the `symbol:` /
    // `name:` their shared helper takes, so they cannot drift from what they
    // build. This one can, and once did: it said `>=`, copied from the builder
    // beside it, sending a reader to the wrong six methods.
    //
    // It has no test because it has no reachable input. `current.returnType` is
    // whatever [_createColumn] or [_createParameter] produced, and both of those
    // narrow to exactly the six cases above before this method is ever entered —
    // an unmapped type is refused there, with their own message. The arm is kept
    // because the switch is over a `Type` and so cannot be proven exhaustive.
    throw TomQuerySyntaxException(
      "query_sentence_compiler.create_is_in.failed",
      "Attempt to _create IS IN operation for unknown type ${current.returnType}",
    );
  }

  /// Dispatches a null test on the operand's SQL type.
  ///
  /// The node is the same shape for every type, but it is *generic* in that
  /// type, so the type still has to be recovered from [TomOperator.returnType]
  /// before the node can be built. [build] is [isNull] or [isNotNull].
  ///
  /// [key] and [name] name the operator in the failure a type outside the
  /// switch produces, so the two callers stay distinguishable in an error
  /// message — the same arrangement [_createComparison] makes for its six.
  TomOperator<TomDbBool> _createNullTest(
    TomOperator current, {
    required _UnaryPredicateFactory build,
    required String key,
    required String name,
  }) {
    switch (current.returnType) {
      case TomDbString:
        return build<TomDbString>(current as TomOperator<TomDbString>);
      case TomDbInt:
        return build<TomDbInt>(current as TomOperator<TomDbInt>);
      case TomDbDouble:
        return build<TomDbDouble>(current as TomOperator<TomDbDouble>);
      case TomDbBool:
        return build<TomDbBool>(current as TomOperator<TomDbBool>);
      case TomDbDateTime:
        return build<TomDbDateTime>(current as TomOperator<TomDbDateTime>);
      case TomDbDate:
        return build<TomDbDate>(current as TomOperator<TomDbDate>);
    }
    throw TomQuerySyntaxException(
      key,
      "Attempt to _create $name operation for unknown type ${current.returnType}",
    );
  }

  TomOperator<TomDbBool> _createIsNull(TomOperator current) => _createNullTest(
    current,
    build: isNull,
    key: "query_sentence_compiler.create_is_null.failed",
    name: "IS NULL",
  );

  TomOperator<TomDbBool> _createIsNotNull(TomOperator current) =>
      _createNullTest(
        current,
        build: isNotNull,
        key: "query_sentence_compiler.create_is_not_null.failed",
        name: "IS NOT NULL",
      );

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
          !_lookAhead(qp, i, 1, "NULL")) {
        // Standalone negation — `NOT` that owns nothing after it.
        //
        // Only `NULL` has to be excluded here. The parallel branch in
        // [_buildQuery] excludes `LIKE` as well, because that parser has no
        // `NOT LIKE` branch of its own and must let the phrase reach this one;
        // here the `NOT LIKE` branch is directly above, so reaching this line
        // already means `LIKE` did not follow. (It was excluded here too, by a
        // conjunct that tested `NULL` a second time — a copy of the query-level
        // guard whose second half never said what it meant.)
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
      } else if (qp[i].startsWith("'")) {
        // Only [_splitQuerySentence] produces a token starting with a quote,
        // and it produces one only for a region it saw closed — so the quotes
        // are known to be balanced here and the length known to be at least
        // two. The malformed cases are refused during tokenising, where the
        // position of the opening quote is still known.
        if (QT != TomDbString) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression.string_literal_invalid_type_expected",
            "A String literal is always for type String, but the required type is $QT",
          );
        }
        currentOperation = text(_decodeStringLiteral(qp[i])) as TomOperator<QT>;
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
      } else if (_scalarLiteralFor(qp[i]) case final literal?) {
        // One branch for all four numeric and temporal literal kinds: they
        // differ only in the shape they match and the node they build, and
        // spelling each out separately is what let the shapes drift into
        // overlapping (see [_ScalarLiteral]).
        if (QT != literal.sqlType) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression."
                "${literal.kind}_literal_invalid_type_expected",
            "[${qp[i]}] is ${literal.noun} literal, so it always stands for "
                "type ${literal.sqlType}, but the required type here is $QT",
          );
        }
        if (inNegationMode) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.build_expression."
                "${literal.kind}_literal_negation_attempt",
            "You can't negate ${literal.noun} literal: ${qp[i]}",
          );
        }
        currentOperation = literal.build(this, qp[i]) as TomOperator<QT>;
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
    // The loop ran out of tokens. Both of the ways that can leave nothing built
    // are sentences that simply stop early — `… title not`, `… title not like`
    // — and both used to leave the failure to a cast: the negation below on a
    // null operand, or the `!` on the return. Those arrive as `TypeError`,
    // which is outside the exception family this library promises and says
    // nothing about the sentence that caused it.
    if (currentOperation == null) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.build_expression.sentence_ended_early",
        inNegationMode
            ? "The sentence ends after NOT, with no expression to negate: $qs"
            : "The sentence ends before the expression is complete: $qs",
      );
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
    return (currentOperation, index);
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
    // Bounded by `qp.length` as well as by the bracket: an unclosed list used
    // to walk off the end and throw `RangeError`, which is outside the
    // exception family this module documents as covering every rejection — and
    // reaches the caller as an internal error rather than a bad request, which
    // matters because a sentence can arrive in a request parameter.
    while (scanAt < qp.length && qp[scanAt] != ")") {
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
    if (scanAt >= qp.length) {
      throw TomQuerySyntaxException(
        "query_sentence_compiler.get_in_options.unterminated_list",
        "The QuerySentence $qs cannot be compiled. The IS IN list opened with "
            "[(] is never closed with [)].",
      );
    }
    if (options.isEmpty) {
      // `IN ()` parses in no SQL dialect, so accepting it here only moved the
      // rejection to the database — one layer too late, and phrased as a
      // complaint about SQL the author never wrote.
      throw TomQuerySyntaxException(
        "query_sentence_compiler.get_in_options.empty_list",
        "The QuerySentence $qs cannot be compiled. The IS IN list is empty, "
            "and SQL has no empty IN list. Give it at least one value.",
      );
    }
    // The index of the closing bracket, which is the last token this scan
    // consumed — see the contract on [_createIsIn].
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
      case double:
      case TomDouble:
      case TomNDouble:
        return Parameter<TomDbDouble>(field) as Parameter<QT>;
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
        case double:
        case TomDbDouble:
        case TomDouble:
        case TomNDouble:
          return DoubleCol(column.tableType, field, column);
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
      case double:
      case TomDouble:
      case TomNDouble:
        return DoubleCol(column.tableType, field, column);
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

  /// The characters that end a token on their own, outside a quoted region.
  static const _separatorCharacters = {',', '(', ')', '=', '<', '>'};

  /// The two-character operators, matched before the single-character ones so
  /// `<=` is one token rather than `<` followed by `=`. This is the whole
  /// vocabulary [_buildExpression] recognises; anything else made of these
  /// characters splits into singles and is refused there by name.
  static const _twoCharacterOperators = {'<=', '<>', '>='};

  /// Splits [qs] into tokens: words, separators, and whole string literals.
  ///
  /// Quoting is why this is a hand-written scan rather than the
  /// regex-and-split it replaced. That version inserted spaces around every
  /// `,()=<>`, collapsed runs of whitespace and split on the result — with no
  /// notion of a quoted region, so a literal was only writable if it contained
  /// none of those characters and no space. `title = 'in progress, phase (2)'`
  /// became eight tokens, the first of them `'in`, and the failure that came
  /// back named a column `['in]`: a fragment the author never wrote, raised by
  /// the annotation analyzer rather than as a query-syntax error.
  ///
  /// A quoted region is returned as **one token with its quotes still on**, so
  /// the literal branch of [_buildExpression] recognises it the same way it
  /// always has, and so a token that merely *looks* like a keyword or a column
  /// name cannot be mistaken for one — `by`, `order` and `and` are all found by
  /// scanning this list.
  ///
  /// An apostrophe inside a literal is written the SQL way, by doubling it.
  /// The doubling is left in the token here and undone by
  /// [_decodeStringLiteral], so a token still reads back as it was written
  /// when it appears in an error message.
  List<String> _splitQuerySentence(String qs) {
    final tokens = <String>[];
    final word = StringBuffer();

    void endWord() {
      if (word.isNotEmpty) {
        tokens.add(word.toString());
        word.clear();
      }
    }

    var i = 0;
    while (i < qs.length) {
      final character = qs[i];

      if (character == "'") {
        endWord();
        final start = i;
        i++;
        while (i < qs.length) {
          if (qs[i] != "'") {
            i++;
            continue;
          }
          // A doubled quote is an escaped apostrophe and continues the
          // literal; a lone one ends it. Telling the two apart is the only
          // reason this scan cannot be a search for the next `'`.
          if (i + 1 < qs.length && qs[i + 1] == "'") {
            i += 2;
            continue;
          }
          break;
        }
        if (i >= qs.length) {
          throw TomQuerySyntaxException(
            "query_sentence_compiler.split_query_sentence."
                "unterminated_string_literal",
            "The QuerySentence $qs cannot be compiled. The string literal "
                "opened at position $start is never closed. An apostrophe "
                "inside a literal is written by doubling it: 'O''Brien'.",
          );
        }
        i++; // the closing quote
        tokens.add(qs.substring(start, i));
        continue;
      }

      if (character.trim().isEmpty) {
        endWord();
        i++;
        continue;
      }

      if (_separatorCharacters.contains(character)) {
        endWord();
        final pair = i + 1 < qs.length ? qs.substring(i, i + 2) : null;
        if (pair != null && _twoCharacterOperators.contains(pair)) {
          tokens.add(pair);
          i += 2;
        } else {
          tokens.add(character);
          i++;
        }
        continue;
      }

      word.write(character);
      i++;
    }
    endWord();
    return tokens;
  }

  /// The value a quoted [token] stands for: the quotes removed and each
  /// doubled apostrophe folded back to one.
  ///
  /// The fold belongs here rather than in the dialect, which does the opposite
  /// job — [TomStandardSqlDialect.text] escapes `'` to `''` on the way out.
  /// Skipping this step left the author's escape in the value, so the dialect
  /// doubled it a second time and `'O''Brien'` reached SQL as `'O''''Brien'`,
  /// an apostrophe richer than what was written.
  static String _decodeStringLiteral(String token) =>
      token.substring(1, token.length - 1).replaceAll("''", "'");
}

import '../datasources/types_operator.dart';
import 'grouped_query.dart';
import 'persistence_annotations.dart';
import 'operators_expressions.dart';
import 'subquery.dart';

/// A fluent factory for the [TomOperator] expression tree.
///
/// Each method constructs one node of a query predicate (or a literal,
/// parameter, or column reference) so callers can assemble a type-safe SQL
/// expression without naming the concrete operator classes. Mixed into the
/// repositories and the query-sentence compiler, which then render the tree
/// through a [TomStandardSqlDialect].
///
/// Predicate builders return `TomOperator<TomDbBool>`; literal/column/parameter
/// builders return the matching SQL-typed operator (`TomOperator<TomDbInt>`,
/// `TomOperator<TomDbString>`, …).
mixin TomQueryBuilder {
  /// `<what> IS NULL`.
  TomOperator<TomDbBool> isNull<T>(TomOperator<T> what) {
    return IsNull<T>(what);
  }

  /// `<what> IS NOT NULL`.
  TomOperator<TomDbBool> isNotNull<T>(TomOperator<T> what) {
    return IsNotNull<T>(what);
  }

  /// `EXISTS (<subquery>)`.
  TomOperator<TomDbBool> exists(TomSubquery subquery) => TomExists(subquery);

  /// `NOT EXISTS (<subquery>)`.
  TomOperator<TomDbBool> notExists(TomSubquery subquery) =>
      Not(TomExists(subquery));

  /// `<what> IN (<subquery>)` — [subquery] selects the one column compared.
  TomOperator<TomDbBool> isInSubquery<T>(
    TomOperator<T> what,
    TomSubquery subquery,
  ) => TomInSubquery<T>(what, subquery);

  /// `NOT <what> IN (<subquery>)`.
  TomOperator<TomDbBool> isNotInSubquery<T>(
    TomOperator<T> what,
    TomSubquery subquery,
  ) => Not(TomInSubquery<T>(what, subquery));

  /// `<what> IN (<choices...>)`.
  TomOperator<TomDbBool> isIn<T>(
    TomOperator<T> what,
    List<TomOperator<T>> choices,
  ) {
    return In<T>(what, choices);
  }

  /// `<what> BETWEEN <lo> AND <hi>` (exactly two [betweenLimits]).
  TomOperator<TomDbBool> between<T>(
    TomOperator<T> what,
    List<TomOperator<T>> betweenLimits,
  ) {
    return Between<T>(what, betweenLimits);
  }

  /// `<text> LIKE <test>`.
  TomOperator<TomDbBool> like(
    TomOperator<TomDbString> text,
    TomOperator<TomDbString> test,
  ) {
    return Like(text, test);
  }

  /// `<text> NOT LIKE <test>`.
  TomOperator<TomDbBool> notLike(
    TomOperator<TomDbString> text,
    TomOperator<TomDbString> test,
  ) {
    return NotLike(text, test);
  }

  /// `<text> REGEXP <test>`.
  TomOperator<TomDbBool> regexp(
    TomOperator<TomDbString> text,
    TomOperator<TomDbString> test,
  ) {
    return Regexp(text, test);
  }

  /// `( <operant> )`.
  TomOperator<T> group<T>(TomOperator<T> operant) {
    return Group<T>(operant);
  }

  /// `<operant1> = <operant2>`.
  TomOperator<TomDbBool> eq<T>(
    TomOperator<T> operant1,
    TomOperator<T> operant2,
  ) {
    return Eq<T>(operant1, operant2);
  }

  /// `<operant1> <> <operant2>`.
  TomOperator<TomDbBool> neq<T>(
    TomOperator<T> operant1,
    TomOperator<T> operant2,
  ) {
    return Neq<T>(operant1, operant2);
  }

  /// `<operant1> < <operant2>`.
  TomOperator<TomDbBool> lt<T>(
    TomOperator<T> operant1,
    TomOperator<T> operant2,
  ) {
    return Lt<T>(operant1, operant2);
  }

  /// `<operant1> <= <operant2>`.
  TomOperator<TomDbBool> lte<T>(
    TomOperator<T> operant1,
    TomOperator<T> operant2,
  ) {
    return Lte<T>(operant1, operant2);
  }

  /// `<operant1> > <operant2>`.
  TomOperator<TomDbBool> gt<T>(
    TomOperator<T> operant1,
    TomOperator<T> operant2,
  ) {
    return Gt<T>(operant1, operant2);
  }

  /// `<operant1> >= <operant2>`.
  TomOperator<TomDbBool> gte<T>(
    TomOperator<T> operant1,
    TomOperator<T> operant2,
  ) {
    return Gte<T>(operant1, operant2);
  }

  /// `NOT <operant1>`.
  TomOperator<TomDbBool> not(TomOperator<TomDbBool> operant1) {
    return Not(operant1);
  }

  /// The [operant1] predicates joined with ` AND `.
  TomOperator<TomDbBool> and(List<TomOperator<TomDbBool>> operant1) {
    return And(operant1);
  }

  /// The [operant1] predicates joined with ` OR `.
  TomOperator<TomDbBool> or(List<TomOperator<TomDbBool>> operant1) {
    return Or(operant1);
  }

  /// A string literal.
  TomOperator<TomDbString> text(String text) {
    return StringLiteral(text);
  }

  /// An integer literal.
  TomOperator<TomDbInt> intOp(int value) {
    return IntegerLiteral(value);
  }

  /// A double literal.
  TomOperator<TomDbDouble> doubleOp(double value) {
    return DoubleLiteral(value);
  }

  /// A boolean literal.
  TomOperator<TomDbBool> boolOp(bool value) {
    return BoolLiteral(value);
  }

  /// A constant predicate: one that admits every row, or none.
  TomOperator<TomDbBool> truthPredicate(bool value) {
    return TruthPredicate(value);
  }

  /// A timestamp literal.
  TomOperator<TomDbDateTime> dateTimeOp(DateTime value) {
    return DateTimeLiteral(value);
  }

  /// A date literal.
  TomOperator<TomDbDate> dateOp(DateTime value) {
    return DateLiteral(value);
  }

  /// A time-of-day literal — only the clock components of [value] are used.
  TomOperator<TomDbTime> timeOp(DateTime value) {
    return TimeLiteral(value);
  }

  /// A named positional parameter placeholder (`:parameterName`).
  TomOperator<T> p<T>(String parameterName) {
    return Parameter<T>(parameterName);
  }

  /// A reference to a `String` column.
  TomOperator<TomDbString> textF(
    String fieldName,
    TomColumnInformation columnInformation,
  ) {
    return StringCol(columnInformation.tableType, fieldName, columnInformation);
  }

  /// A reference to an `int` column.
  TomOperator<TomDbInt> intF(
    String fieldName,
    TomColumnInformation columnInformation,
  ) {
    return IntCol(columnInformation.tableType, fieldName, columnInformation);
  }

  /// A reference to a `double` column.
  TomOperator<TomDbDouble> doubleF(
    String fieldName,
    TomColumnInformation columnInformation,
  ) {
    return DoubleCol(columnInformation.tableType, fieldName, columnInformation);
  }

  /// A reference to a `bool` column.
  TomOperator<TomDbBool> boolF(
    String fieldName,
    TomColumnInformation columnInformation,
  ) {
    return BoolCol(columnInformation.tableType, fieldName, columnInformation);
  }

  /// A reference to a timestamp column.
  TomOperator<TomDbDateTime> dateTimeF(
    String fieldName,
    TomColumnInformation columnInformation,
  ) {
    return DateTimeCol(
      columnInformation.tableType,
      fieldName,
      columnInformation,
    );
  }

  /// A reference to a date column.
  TomOperator<TomDbDate> dateF(
    String fieldName,
    TomColumnInformation columnInformation,
  ) {
    return DateCol(columnInformation.tableType, fieldName, columnInformation);
  }

  /// A reference to a time-of-day column.
  TomOperator<TomDbTime> timeF(
    String fieldName,
    TomColumnInformation columnInformation,
  ) {
    return TimeCol(columnInformation.tableType, fieldName, columnInformation);
  }

  // --- Aggregates -----------------------------------------------------------
  //
  // Each returns a `TomAggregate`, which *is* a `TomOperator`, so an aggregate
  // composes with the predicate builders above: `gt(countAll('n'), intOp(3))`
  // is the `HAVING COUNT(*) > 3` of a grouped select. Every aggregate carries
  // the alias it is projected under, because a grouped result has no entity
  // metadata to map its columns back by.
  //
  // `min`/`max` are split by type rather than left generic because they
  // preserve the operand's type on both sides (SQL and Dart); `sum`/`avg`
  // always widen to `double` and so need no such split.

  /// `COUNT(*) AS <alias>` — the number of rows in each group.
  CountAll countAll(String alias) => CountAll(alias);

  /// `COUNT(<value>) AS <alias>` — the non-null [value]s in each group, or the
  /// distinct such values when [distinct] is set.
  ///
  /// Named `countOf` rather than `count` because the repositories mix this
  /// builder in beside `TomRepository.count()`, the CRUD row count.
  Count<T> countOf<T>(
    TomOperator<T> value,
    String alias, {
    bool distinct = false,
  }) => Count<T>(value, alias, distinct: distinct);

  /// `SUM(<value>) AS <alias>`, always a `double` (see [Sum]).
  Sum<T> sum<T>(TomOperator<T> value, String alias, {bool distinct = false}) =>
      Sum<T>(value, alias, distinct: distinct);

  /// `AVG(<value>) AS <alias>`, always a `double`.
  Avg<T> avg<T>(TomOperator<T> value, String alias, {bool distinct = false}) =>
      Avg<T>(value, alias, distinct: distinct);

  /// `MIN(<value>) AS <alias>` over an `int` expression.
  Min<TomDbInt, int> minInt(TomOperator<TomDbInt> value, String alias) =>
      Min<TomDbInt, int>(value, alias);

  /// `MAX(<value>) AS <alias>` over an `int` expression.
  Max<TomDbInt, int> maxInt(TomOperator<TomDbInt> value, String alias) =>
      Max<TomDbInt, int>(value, alias);

  /// `MIN(<value>) AS <alias>` over a `double` expression.
  Min<TomDbDouble, double> minDouble(
    TomOperator<TomDbDouble> value,
    String alias,
  ) => Min<TomDbDouble, double>(value, alias);

  /// `MAX(<value>) AS <alias>` over a `double` expression.
  Max<TomDbDouble, double> maxDouble(
    TomOperator<TomDbDouble> value,
    String alias,
  ) => Max<TomDbDouble, double>(value, alias);

  /// `MIN(<value>) AS <alias>` over a `String` expression.
  Min<TomDbString, String> minText(
    TomOperator<TomDbString> value,
    String alias,
  ) => Min<TomDbString, String>(value, alias);

  /// `MAX(<value>) AS <alias>` over a `String` expression.
  Max<TomDbString, String> maxText(
    TomOperator<TomDbString> value,
    String alias,
  ) => Max<TomDbString, String>(value, alias);

  /// `MIN(<value>) AS <alias>` over a timestamp expression.
  Min<TomDbDateTime, DateTime> minDateTime(
    TomOperator<TomDbDateTime> value,
    String alias,
  ) => Min<TomDbDateTime, DateTime>(value, alias);

  /// `MAX(<value>) AS <alias>` over a timestamp expression.
  Max<TomDbDateTime, DateTime> maxDateTime(
    TomOperator<TomDbDateTime> value,
    String alias,
  ) => Max<TomDbDateTime, DateTime>(value, alias);

  /// `MIN(<value>) AS <alias>` over a date expression.
  ///
  /// The projected value is read as a plain [DateTime]: it is the widest type
  /// that accepts both the driver's own reading of the column and a
  /// [TomZonedDate], which extends it. The same holds for [minTime].
  Min<TomDbDate, DateTime> minDate(
    TomOperator<TomDbDate> value,
    String alias,
  ) => Min<TomDbDate, DateTime>(value, alias);

  /// `MAX(<value>) AS <alias>` over a date expression.
  Max<TomDbDate, DateTime> maxDate(
    TomOperator<TomDbDate> value,
    String alias,
  ) => Max<TomDbDate, DateTime>(value, alias);

  /// `MIN(<value>) AS <alias>` over a time-of-day expression.
  Min<TomDbTime, DateTime> minTime(
    TomOperator<TomDbTime> value,
    String alias,
  ) => Min<TomDbTime, DateTime>(value, alias);

  /// `MAX(<value>) AS <alias>` over a time-of-day expression.
  Max<TomDbTime, DateTime> maxTime(
    TomOperator<TomDbTime> value,
    String alias,
  ) => Max<TomDbTime, DateTime>(value, alias);
}

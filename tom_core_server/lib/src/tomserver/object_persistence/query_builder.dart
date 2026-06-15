import '../datasources/types_operator.dart';
import 'persistence_annotations.dart';
import 'operators_expressions.dart';

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

  /// A timestamp literal.
  TomOperator<TomDbDateTime> dateTimeOp(DateTime value) {
    return DateTimeLiteral(value);
  }

  /// A date literal.
  TomOperator<TomDbDate> dateOp(DateTime value) {
    return DateLiteral(value);
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
}

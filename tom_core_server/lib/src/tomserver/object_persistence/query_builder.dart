import '../datasources/types_operator.dart';
import 'persistence_annotations.dart';
import 'operators_expressions.dart';

mixin TomQueryBuilder {
  TomOperator<TomDbBool> isNull<T>(TomOperator<T> what) {
    return IsNull<T>(what);
  }

  TomOperator<TomDbBool> isNotNull<T>(TomOperator<T> what) {
    return IsNotNull<T>(what);
  }

  TomOperator<TomDbBool> isIn<T>(
    TomOperator<T> what,
    List<TomOperator<T>> choices,
  ) {
    return In<T>(what, choices);
  }

  TomOperator<TomDbBool> between<T>(
    TomOperator<T> what,
    List<TomOperator<T>> betweenLimits,
  ) {
    return Between<T>(what, betweenLimits);
  }

  TomOperator<TomDbBool> like(
    TomOperator<TomDbString> text,
    TomOperator<TomDbString> test,
  ) {
    return Like(text, test);
  }

  TomOperator<TomDbBool> notLike(
    TomOperator<TomDbString> text,
    TomOperator<TomDbString> test,
  ) {
    return NotLike(text, test);
  }

  TomOperator<TomDbBool> regexp(
    TomOperator<TomDbString> text,
    TomOperator<TomDbString> test,
  ) {
    return Regexp(text, test);
  }

  TomOperator<T> group<T>(TomOperator<T> operant) {
    return Group<T>(operant);
  }

  TomOperator<TomDbBool> eq<T>(
    TomOperator<T> operant1,
    TomOperator<T> operant2,
  ) {
    return Eq<T>(operant1, operant2);
  }

  TomOperator<TomDbBool> neq<T>(
    TomOperator<T> operant1,
    TomOperator<T> operant2,
  ) {
    return Neq<T>(operant1, operant2);
  }

  TomOperator<TomDbBool> lt<T>(
    TomOperator<T> operant1,
    TomOperator<T> operant2,
  ) {
    return Lt<T>(operant1, operant2);
  }

  TomOperator<TomDbBool> lte<T>(
    TomOperator<T> operant1,
    TomOperator<T> operant2,
  ) {
    return Lte<T>(operant1, operant2);
  }

  TomOperator<TomDbBool> gt<T>(
    TomOperator<T> operant1,
    TomOperator<T> operant2,
  ) {
    return Gt<T>(operant1, operant2);
  }

  TomOperator<TomDbBool> gte<T>(
    TomOperator<T> operant1,
    TomOperator<T> operant2,
  ) {
    return Gte<T>(operant1, operant2);
  }

  TomOperator<TomDbBool> not(TomOperator<TomDbBool> operant1) {
    return Not(operant1);
  }

  TomOperator<TomDbBool> and(List<TomOperator<TomDbBool>> operant1) {
    return And(operant1);
  }

  TomOperator<TomDbBool> or(List<TomOperator<TomDbBool>> operant1) {
    return Or(operant1);
  }

  TomOperator<TomDbString> text(String text) {
    return StringLiteral(text);
  }

  TomOperator<TomDbInt> intOp(int value) {
    return IntegerLiteral(value);
  }

  TomOperator<TomDbDouble> doubleOp(double value) {
    return DoubleLiteral(value);
  }

  TomOperator<TomDbBool> boolOp(bool value) {
    return BoolLiteral(value);
  }

  TomOperator<TomDbDateTime> dateTimeOp(DateTime value) {
    return DateTimeLiteral(value);
  }

  TomOperator<TomDbDate> dateOp(DateTime value) {
    return DateLiteral(value);
  }

  TomOperator<T> p<T>(String parameterName) {
    return Parameter<T>(parameterName);
  }

  TomOperator<TomDbString> textF(
    String fieldName,
    TomColumnInformation columnInformation,
  ) {
    return StringCol(columnInformation.tableType, fieldName, columnInformation);
  }

  TomOperator<TomDbInt> intF(
    String fieldName,
    TomColumnInformation columnInformation,
  ) {
    return IntCol(columnInformation.tableType, fieldName, columnInformation);
  }

  TomOperator<TomDbDouble> doubleF(
    String fieldName,
    TomColumnInformation columnInformation,
  ) {
    return DoubleCol(columnInformation.tableType, fieldName, columnInformation);
  }

  TomOperator<TomDbBool> boolF(
    String fieldName,
    TomColumnInformation columnInformation,
  ) {
    return BoolCol(columnInformation.tableType, fieldName, columnInformation);
  }

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

  TomOperator<TomDbDate> dateF(
    String fieldName,
    TomColumnInformation columnInformation,
  ) {
    return DateCol(columnInformation.tableType, fieldName, columnInformation);
  }
}

// TODO: After, Before, Containing, EndsWith, Exists, isEmpty, isNotEmpty, Not Like, Regex, StartsWith, Within

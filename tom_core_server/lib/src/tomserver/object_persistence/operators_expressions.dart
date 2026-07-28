import '../datasources/sql_dialects.dart';
import '../datasources/types_operator.dart';

import '../little_things/server_exception.dart';
import 'persistence_annotations.dart';

/// Thrown when a query expression is malformed (e.g. a `BETWEEN` without
/// exactly two bounds).
class TomQuerySyntaxException extends TomServerException {
  /// Creates a query-syntax exception.
  TomQuerySyntaxException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// A [TomOperator] with a single operand.
///
/// [operant1] may itself be an operator, a `List<TomOperator>`, or a leaf value;
/// the parameter/field/analysis traversals handle each case. Concrete unary
/// operators (literals, columns, `IS NULL`, `NOT`, `AND`/`OR` over a list)
/// override [generate] to render their SQL.
abstract class TomUnaryOperator<T, R> extends TomOperator<R> {
  /// The single operand.
  T operant1;

  /// Creates a unary operator over [operant1].
  TomUnaryOperator(this.operant1);

  @override
  List<TomOperator> get children => TomOperator.operandChildren(operant1);

  @override
  List<String> getParameters(TomStandardSqlDialect t) => [
    for (final child in children) ...child.getParameters(t),
  ];

  @override
  Set<String> getFields(TomStandardSqlDialect t) => {
    for (final child in children) ...child.getFields(t),
  };

  @override
  String analyze(int l) {
    String r = "${indent(l)} ($runtimeType";
    if (operant1 is TomOperator) {
      r += " ${(operant1 as TomOperator).analyze(l + 1)}";
    } else if (operant1 is List<TomOperator>) {
      for (var op in operant1 as List<TomOperator>) {
        r += " ${op.analyze(l + 1)}";
      }
    } else {
      r += " $operant1";
    }
    return r;
  }
}

/// A named positional parameter placeholder (`:name`).
///
/// Renders via [TomStandardSqlDialect.p] and contributes its [name] to the
/// statement's parameter list so the driver binds the value (avoiding SQL
/// injection). References no columns.
class Parameter<T> extends TomOperator<T> {
  /// The parameter name (without the leading `:`).
  String name;

  /// Creates a parameter placeholder for [name].
  Parameter(this.name);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.p(name);
  @override
  List<String> getParameters(TomStandardSqlDialect t) => [name];
  @override
  Set<String> getFields(TomStandardSqlDialect t) => {};
  @override
  String analyze(int l) => "Parameter [$T:\$$name]";
}

/// A reference to a database column, carrying its [columnInformation] and the
/// owning [tableType]. Renders as a qualified `table.column` via the dialect.
abstract class DbCol<R> extends TomUnaryOperator<String, R> {
  /// The resolved metadata for the referenced column.
  TomColumnInformation columnInformation;

  /// The entity type that owns the column.
  late Type tableType;

  /// Creates a column reference to [operant1] on [tableType].
  DbCol(this.tableType, String operant1, this.columnInformation)
    : super(operant1);

  @override
  Set<String> getFields(TomStandardSqlDialect t) => {generate(t)};
  @override
  String toString() => "DbCol $returnType $tableType.$operant1";
}

/// A reference to an `int` column.
class IntCol extends DbCol<TomDbInt> {
  /// Creates an `int` column reference.
  IntCol(super.tableType, super.operant1, super.columnInformation);

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.intF(operant1, this, tableType);
}

/// A reference to a `String` column.
class StringCol extends DbCol<TomDbString> {
  /// Creates a `String` column reference.
  StringCol(super.tableType, super.operant1, super.columnInformation);

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.textF(operant1, this, tableType);
}

/// A reference to a `double` column.
class DoubleCol extends DbCol<TomDbDouble> {
  /// Creates a `double` column reference.
  DoubleCol(super.tableType, super.operant1, super.columnInformation);

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.doubleF(operant1, this, tableType);
}

/// A reference to a `bool` column.
class BoolCol extends DbCol<TomDbBool> {
  /// Creates a `bool` column reference.
  BoolCol(super.tableType, super.operant1, super.columnInformation);

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.boolF(operant1, this, tableType);
}

/// A reference to a timestamp column.
class DateTimeCol extends DbCol<TomDbDateTime> {
  /// Creates a timestamp column reference.
  DateTimeCol(super.tableType, super.operant1, super.columnInformation);

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.dateTimeF(operant1, this, tableType);
}

/// A reference to a date column.
class DateCol extends DbCol<TomDbDate> {
  /// Creates a date column reference.
  DateCol(super.tableType, super.operant1, super.columnInformation);

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.dateF(operant1, this, tableType);
}

/// A single-quoted string literal.
class StringLiteral extends TomUnaryOperator<String, TomDbString> {
  /// Creates a string literal.
  StringLiteral(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.text(operant1);
}

/// An integer literal.
class IntegerLiteral extends TomUnaryOperator<int, TomDbInt> {
  /// Creates an integer literal.
  IntegerLiteral(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.intOp(operant1);
}

/// A double literal.
class DoubleLiteral extends TomUnaryOperator<double, TomDbDouble> {
  /// Creates a double literal.
  DoubleLiteral(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.doubleOp(operant1);
}

/// A boolean literal.
class BoolLiteral extends TomUnaryOperator<bool, TomDbBool> {
  /// Creates a boolean literal.
  BoolLiteral(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.boolOp(operant1);
}

/// A timestamp literal.
class DateTimeLiteral extends TomUnaryOperator<DateTime, TomDbDateTime> {
  /// Creates a timestamp literal.
  DateTimeLiteral(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.dateTimeOp(operant1);
}

/// A date literal.
class DateLiteral extends TomUnaryOperator<DateTime, TomDbDate> {
  /// Creates a date literal.
  DateLiteral(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.dateOp(operant1);
}

/// Logical negation: `NOT <operand>`.
class Not extends TomUnaryOperator<TomOperator<TomDbBool>, TomDbBool> {
  /// Negates [operant1].
  Not(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.not(operant1);
}

/// Null test: `<operand> IS NULL`.
class IsNull<T> extends TomUnaryOperator<TomOperator<T>, TomDbBool> {
  /// Tests whether [operant1] is null.
  IsNull(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.isNull(operant1);
}

/// Non-null test: `<operand> IS NOT NULL`.
class IsNotNull<T> extends TomUnaryOperator<TomOperator<T>, TomDbBool> {
  /// Tests whether [operant1] is not null.
  IsNotNull(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.isNotNull(operant1);
}

/// A [TomOperator] with two operands.
///
/// Used by comparisons (`=`, `<>`, `<`, `>`, …), `LIKE`/`NOT LIKE`/`REGEXP`,
/// `IN`, and `BETWEEN`. Either operand may be an operator or a
/// `List<TomOperator>`; the parameter/field/analysis traversals descend into
/// both.
abstract class TomBinaryOperator<T1, T2, R> extends TomOperator<R> {
  /// The left operand.
  T1 operant1;

  /// The right operand.
  T2 operant2;

  /// Creates a binary operator over [operant1] and [operant2].
  TomBinaryOperator(this.operant1, this.operant2);

  @override
  List<TomOperator> get children => [
    ...TomOperator.operandChildren(operant1),
    ...TomOperator.operandChildren(operant2),
  ];

  @override
  List<String> getParameters(TomStandardSqlDialect t) => [
    for (final child in children) ...child.getParameters(t),
  ];

  @override
  Set<String> getFields(TomStandardSqlDialect t) => {
    for (final child in children) ...child.getFields(t),
  };

  @override
  String analyze(int l) {
    String r = "${indent(l)} ($runtimeType";
    if (operant1 is TomOperator) {
      r += " ${(operant1 as TomOperator).analyze(l + 1)}";
    } else if (operant1 is List<TomOperator>) {
      for (var op in operant1 as List<TomOperator>) {
        r += "${indent(l)}\t${op.analyze(l + 1)}";
      }
    } else {
      r += " $operant1";
    }
    if (operant2 is TomOperator) {
      r += " ${(operant2 as TomOperator).analyze(l + 1)}";
    } else if (operant2 is List<TomOperator>) {
      for (var op in operant2 as List<TomOperator>) {
        r += "${indent(l)}\t${op.analyze(l + 1)}";
      }
    } else {
      r += " $operant2";
    }
    return r;
  }
}

/// Conjunction: joins its operand predicates with ` AND `.
class And extends TomUnaryOperator<List<TomOperator<TomDbBool>>, TomDbBool> {
  /// Conjoins the predicates in [operant1].
  And(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.and(operant1);
}

/// Disjunction: joins its operand predicates with ` OR `.
class Or extends TomUnaryOperator<List<TomOperator<TomDbBool>>, TomDbBool> {
  /// Disjoins the predicates in [operant1].
  Or(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.or(operant1);
}

/// Equality comparison: `<a> = <b>`.
class Eq<T>
    extends TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool> {
  /// Compares [operant1] equal to [operant2].
  Eq(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.eq(operant1, operant2);
}

/// Inequality comparison: `<a> <> <b>`.
class Neq<T>
    extends TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool> {
  /// Compares [operant1] not equal to [operant2].
  Neq(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.neq(operant1, operant2);
}

/// Less-than comparison: `<a> < <b>`.
class Lt<T>
    extends TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool> {
  /// Compares [operant1] less than [operant2].
  Lt(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.lt(operant1, operant2);
}

/// Greater-than comparison: `<a> > <b>`.
class Gt<T>
    extends TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool> {
  /// Compares [operant1] greater than [operant2].
  Gt(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.gt(operant1, operant2);
}

/// Less-than-or-equal comparison: `<a> <= <b>`.
class Lte<T>
    extends TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool> {
  /// Compares [operant1] less than or equal to [operant2].
  Lte(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.lte(operant1, operant2);
}

/// Greater-than-or-equal comparison: `<a> >= <b>`.
class Gte<T>
    extends TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool> {
  /// Compares [operant1] greater than or equal to [operant2].
  Gte(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.gte(operant1, operant2);
}

/// Pattern match: `<text> LIKE <pattern>`.
class Like
    extends
        TomBinaryOperator<
          TomOperator<TomDbString>,
          TomOperator<TomDbString>,
          TomDbBool
        > {
  /// Matches [operant1] against pattern [operant2].
  Like(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.like(operant1, operant2);
}

/// Negated pattern match: `<text> NOT LIKE <pattern>`.
class NotLike
    extends
        TomBinaryOperator<
          TomOperator<TomDbString>,
          TomOperator<TomDbString>,
          TomDbBool
        > {
  /// Negative-matches [operant1] against pattern [operant2].
  NotLike(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.notLike(operant1, operant2);
}

/// Membership test: `<a> IN (<choices...>)`.
class In<T>
    extends TomBinaryOperator<TomOperator<T>, List<TomOperator<T>>, TomDbBool> {
  /// Tests whether [operant1] is in [operant2].
  In(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.isin(operant1, operant2);
}

/// Parenthesised grouping: `( <operand> )`.
class Group<T> extends TomUnaryOperator<TomOperator<T>, T> {
  /// Wraps [operant1] in parentheses.
  Group(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.group(operant1);
}

/// Range test: `<a> BETWEEN <lo> AND <hi>`.
///
/// Throws [TomQuerySyntaxException] if [operant2] does not hold exactly two
/// bounds.
class Between<T>
    extends TomBinaryOperator<TomOperator<T>, List<TomOperator<T>>, TomDbBool> {
  /// Tests whether [operant1] lies within the two bounds in [operant2].
  Between(TomOperator<T> operant1, List<TomOperator<T>> operant2)
    : super(operant1, operant2) {
    if (operant2.length != 2) {
      throw TomQuerySyntaxException(
        "between_expression.must_have_two_values",
        "Between expression must have exactly two values. $this",
      );
    }
  }
  @override
  SqlString generate(TomStandardSqlDialect t) => t.between(operant1, operant2);
}

/// Regular-expression match: `<text> REGEXP <pattern>`.
class Regexp
    extends
        TomBinaryOperator<
          TomOperator<TomDbString>,
          TomOperator<TomDbString>,
          TomDbBool
        > {
  /// Regexp-matches [operant1] against pattern [operant2].
  Regexp(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.regexp(operant1, operant2);
}

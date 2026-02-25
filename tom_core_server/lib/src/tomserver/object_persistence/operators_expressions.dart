import '../datasources/sql_dialects.dart';
import '../datasources/types_operator.dart';

import '../little_things/server_exception.dart';
import 'persistence_annotations.dart';

class TomQuerySyntaxException extends TomServerException {
  TomQuerySyntaxException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

abstract class TomUnaryOperator<T, R> extends TomOperator<R> {
  T operant1;
  TomUnaryOperator(this.operant1);

  @override
  List<String> getParameters(TomStandardSqlDialect t) {
    var r = <String>[];
    if (operant1 is TomOperator && operant1 != null) {
      r.addAll((operant1 as TomOperator).getParameters(t));
    }
    if (operant1 is List<TomOperator>) {
      for (var op in (operant1 as List<TomOperator>)) {
        r.addAll(op.getParameters(t));
      }
    }
    return r;
  }

  @override
  Set<String> getFields(TomStandardSqlDialect t) {
    var r = <String>{};
    if (operant1 is TomOperator && operant1 != null) {
      r.addAll((operant1 as TomOperator).getParameters(t));
    }
    if (operant1 is List<TomOperator>) {
      for (var op in (operant1 as List<TomOperator>)) {
        r.addAll(op.getParameters(t));
      }
    }
    return r;
  }

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

class Parameter<T> extends TomOperator<T> {
  String name;
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

abstract class DbCol<R> extends TomUnaryOperator<String, R> {
  TomColumnInformation columnInformation;

  late Type tableType;

  DbCol(this.tableType, String operant1, this.columnInformation)
    : super(operant1);

  @override
  Set<String> getFields(TomStandardSqlDialect t) => {generate(t)};
  @override
  String toString() => "DbCol $returnType $tableType.$operant1";
}

class IntCol extends DbCol<TomDbInt> {
  IntCol(super.tableType, super.operant1, super.columnInformation);

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.intF(operant1, this, tableType);
}

class StringCol extends DbCol<TomDbString> {
  StringCol(super.tableType, super.operant1, super.columnInformation);

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.textF(operant1, this, tableType);
}

class DoubleCol extends DbCol<TomDbDouble> {
  DoubleCol(super.tableType, super.operant1, super.columnInformation);

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.doubleF(operant1, this, tableType);
}

class BoolCol extends DbCol<TomDbBool> {
  BoolCol(super.tableType, super.operant1, super.columnInformation);

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.boolF(operant1, this, tableType);
}

class DateTimeCol extends DbCol<TomDbDateTime> {
  DateTimeCol(super.tableType, super.operant1, super.columnInformation);

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.dateTimeF(operant1, this, tableType);
}

class DateCol extends DbCol<TomDbDate> {
  DateCol(super.tableType, super.operant1, super.columnInformation);

  @override
  SqlString generate(TomStandardSqlDialect t) =>
      t.dateF(operant1, this, tableType);
}

class StringLiteral extends TomUnaryOperator<String, TomDbString> {
  StringLiteral(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.text(operant1);
}

class IntegerLiteral extends TomUnaryOperator<int, TomDbInt> {
  IntegerLiteral(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.intOp(operant1);
}

class DoubleLiteral extends TomUnaryOperator<double, TomDbDouble> {
  DoubleLiteral(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.doubleOp(operant1);
}

class BoolLiteral extends TomUnaryOperator<bool, TomDbBool> {
  BoolLiteral(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.boolOp(operant1);
}

class DateTimeLiteral extends TomUnaryOperator<DateTime, TomDbDateTime> {
  DateTimeLiteral(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.dateTimeOp(operant1);
}

class DateLiteral extends TomUnaryOperator<DateTime, TomDbDate> {
  DateLiteral(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.dateOp(operant1);
}

class Not extends TomUnaryOperator<TomOperator<TomDbBool>, TomDbBool> {
  Not(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.not(operant1);
}

class IsNull<T> extends TomUnaryOperator<TomOperator<T>, TomDbBool> {
  IsNull(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.isNull(operant1);
}

class IsNotNull<T> extends TomUnaryOperator<TomOperator<T>, TomDbBool> {
  IsNotNull(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.isNotNull(operant1);
}

abstract class TomBinaryOperator<T1, T2, R> extends TomOperator<R> {
  T1 operant1;
  T2 operant2;
  TomBinaryOperator(this.operant1, this.operant2);

  @override
  List<String> getParameters(TomStandardSqlDialect t) {
    List<String> r = [];
    r.addAll(
      operant1 is TomOperator
          ? (operant1 as TomOperator).getParameters(t)
          : <String>[],
    );
    r.addAll(
      operant2 is TomOperator
          ? (operant2 as TomOperator).getParameters(t)
          : <String>[],
    );
    if (operant1 is List<TomOperator>) {
      for (var op in (operant1 as List<TomOperator>)) {
        r.addAll(op.getParameters(t));
      }
    }
    if (operant2 is List<TomOperator>) {
      for (var op in (operant2 as List<TomOperator>)) {
        r.addAll(op.getParameters(t));
      }
    }
    return r;
  }

  @override
  Set<String> getFields(TomStandardSqlDialect t) {
    Set<String> r = {};
    r.addAll(
      operant1 is TomOperator
          ? (operant1 as TomOperator).getFields(t)
          : <String>{},
    );
    r.addAll(
      operant2 is TomOperator
          ? (operant2 as TomOperator).getFields(t)
          : <String>{},
    );
    if (operant1 is List<TomOperator>) {
      for (var op in (operant1 as List<TomOperator>)) {
        r.addAll(op.getFields(t));
      }
    }
    if (operant2 is List<TomOperator>) {
      for (var op in (operant2 as List<TomOperator>)) {
        r.addAll(op.getFields(t));
      }
    }
    return r;
  }

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

class And extends TomUnaryOperator<List<TomOperator<TomDbBool>>, TomDbBool> {
  And(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.and(operant1);
}

class Or extends TomUnaryOperator<List<TomOperator<TomDbBool>>, TomDbBool> {
  Or(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.or(operant1);
}

class Eq<T>
    extends TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool> {
  Eq(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.eq(operant1, operant2);
}

class Neq<T>
    extends TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool> {
  Neq(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.neq(operant1, operant2);
}

class Lt<T>
    extends TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool> {
  Lt(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.lt(operant1, operant2);
}

class Gt<T>
    extends TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool> {
  Gt(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.gt(operant1, operant2);
}

class Lte<T>
    extends TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool> {
  Lte(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.lte(operant1, operant2);
}

class Gte<T>
    extends TomBinaryOperator<TomOperator<T>, TomOperator<T>, TomDbBool> {
  Gte(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.gte(operant1, operant2);
}

class Like
    extends
        TomBinaryOperator<
          TomOperator<TomDbString>,
          TomOperator<TomDbString>,
          TomDbBool
        > {
  Like(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.like(operant1, operant2);
}

class NotLike
    extends
        TomBinaryOperator<
          TomOperator<TomDbString>,
          TomOperator<TomDbString>,
          TomDbBool
        > {
  NotLike(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.notLike(operant1, operant2);
}

class In<T>
    extends TomBinaryOperator<TomOperator<T>, List<TomOperator<T>>, TomDbBool> {
  In(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.isin(operant1, operant2);
}

class Group<T> extends TomUnaryOperator<TomOperator<T>, T> {
  Group(super.operant1);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.group(operant1);
}

class Between<T>
    extends TomBinaryOperator<TomOperator<T>, List<TomOperator<T>>, TomDbBool> {
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

class Regexp
    extends
        TomBinaryOperator<
          TomOperator<TomDbString>,
          TomOperator<TomDbString>,
          TomDbBool
        > {
  Regexp(super.operant1, super.operant2);
  @override
  SqlString generate(TomStandardSqlDialect t) => t.regexp(operant1, operant2);
}

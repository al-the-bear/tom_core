import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../object_persistence/operators_expressions.dart';
import 'types_operator.dart';


typedef SqlString = String;

class TomStandardSqlDialect {
  SqlString isNull<T>(TomOperator<T> what) {
    return "${what.generate(this)} IS NULL";
  }

  SqlString isNotNull<T>(TomOperator<T> what) {
    return "${what.generate(this)} IS NOT NULL";
  }

  SqlString isin<T>(TomOperator<T> what, List<TomOperator<T>> choices) {
    String list = "";
    for (var v in choices) {
      if (list.isNotEmpty) {
        list += ",";
      }
      list += v.generate(this);
    }
    return "${what.generate(this)} IN ($list)";
  }

  SqlString between<T>(
    TomOperator<T> what,
    List<TomOperator<T>> betweenLimits,
  ) {
    return "${what.generate(this)} BETWEEN ${betweenLimits[0].generate(this)} AND ${betweenLimits[1].generate(this)}";
  }

  SqlString like(TomOperator<TomDbString> text, TomOperator<TomDbString> test) {
    return "${text.generate(this)} LIKE ${test.generate(this)}";
  }

  SqlString notLike(
    TomOperator<TomDbString> text,
    TomOperator<TomDbString> test,
  ) {
    var notLike = "${text.generate(this)} NOT LIKE ${test.generate(this)}";
    return notLike;
  }

  SqlString regexp(
    TomOperator<TomDbString> text,
    TomOperator<TomDbString> test,
  ) {
    return "${text.generate(this)} REGEXP ${test.generate(this)}";
  }

  SqlString group<T>(TomOperator<T> operant) {
    return "( ${operant.generate(this)} )";
  }

  SqlString eq<T>(TomOperator<T> operant1, TomOperator<T> operant2) =>
      "${operant1.generate(this)} = ${operant2.generate(this)}";

  SqlString neq<T>(TomOperator<T> operant1, TomOperator<T> operant2) =>
      "${operant1.generate(this)} <> ${operant2.generate(this)}";

  SqlString lt<T>(TomOperator<T> operant1, TomOperator<T> operant2) =>
      "${operant1.generate(this)} < ${operant2.generate(this)}";

  SqlString lte<T>(TomOperator<T> operant1, TomOperator<T> operant2) =>
      "${operant1.generate(this)} <= ${operant2.generate(this)}";

  SqlString gt<T>(TomOperator<T> operant1, TomOperator<T> operant2) =>
      "${operant1.generate(this)} > ${operant2.generate(this)}";

  SqlString gte<T>(TomOperator<T> operant1, TomOperator<T> operant2) =>
      "${operant1.generate(this)} >= ${operant2.generate(this)}";

  SqlString not(TomOperator<TomDbBool> operant1) =>
      "NOT ${operant1.generate(this)}";

  SqlString and(List<TomOperator<TomDbBool>> operant1) {
    String list = "";
    for (var v in operant1) {
      if (list.isNotEmpty) {
        list += " AND ";
      }
      list += v.generate(this);
    }
    return list;
  }

  SqlString or(List<TomOperator<TomDbBool>> operant1) {
    String list = "";
    for (var v in operant1) {
      if (list.isNotEmpty) {
        list += " OR ";
      }
      list += v.generate(this);
    }
    return list;
  }

  SqlString text(String text) {
    return "'$text'";
  }

  SqlString intOp(int value) {
    return "$value";
  }

  SqlString doubleOp(double value) {
    return "$value";
  }

  SqlString boolOp(bool value) {
    return "$value";
  }

  SqlString dateTimeOp(DateTime value) {
    return "'${value.toIso8601String()}'";
  }

  SqlString dateOp(DateTime value) {
    return "'${value.year}-${value.month}-${value.day}'";
  }

  SqlString iterableOp(Iterable values) {
    var result = "";
    for (var v in values) {
      result += objectOp(v) + (result.isEmpty ? "," : "");
    }
    return result;
  }

  SqlString nullOp() {
    return "NULL";
  }

  SqlString objectOp(Object? o) {
    if (o == null) {
      return nullOp();
    } else if (o is String) {
      return text(o);
    } else if (o is int) {
      return intOp(o);
    } else if (o is double) {
      return doubleOp(o);
    } else if (o is bool) {
      return boolOp(o);
    } else if (o is TomZonedDate) {
      return dateOp(o);
    } else if (o is DateTime) {
      return dateTimeOp(o);
    } else if (o is Iterable) {
      return iterableOp(o);
    } else {
      return text(o.toString());
    }
  }

  SqlString p<T>(String parameterName) => ":$parameterName";

  SqlString textF(String fieldName, DbCol column, Type dbType) {
    return "${column.columnInformation.table.table}.${column.columnInformation.getQueryFieldName()}";
  }

  SqlString intF(String fieldName, DbCol column, Type dbType) {
    return "${column.columnInformation.table.table}.${column.columnInformation.getQueryFieldName()}";
  }

  SqlString doubleF(String fieldName, DbCol column, Type dbType) {
    return "${column.columnInformation.table.table}.${column.columnInformation.getQueryFieldName()}";
  }

  SqlString boolF(String fieldName, DbCol column, Type dbType) {
    return "${column.columnInformation.table.table}.${column.columnInformation.getQueryFieldName()}";
  }

  SqlString dateTimeF(String fieldName, DbCol column, Type dbType) {
    return "${column.columnInformation.table.table}.${column.columnInformation.getQueryFieldName()}";
  }

  SqlString dateF(String fieldName, DbCol column, Type dbType) {
    return "${column.columnInformation.table.table}.${column.columnInformation.getQueryFieldName()}";
  }
}

class TomSqlDialect {
  final String dataSourceType;

  const TomSqlDialect(this.dataSourceType);
}

import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../object_persistence/operators_expressions.dart';
import 'types_operator.dart';


/// A SQL fragment. An alias for `String` that documents intent at call sites.
typedef SqlString = String;

/// Generates standard-SQL fragments for the [TomOperator] expression tree.
///
/// Every method renders one piece of SQL — a predicate (`IS NULL`, `LIKE`,
/// `BETWEEN`, comparisons, `AND`/`OR`), a literal (`text`, `intOp`, `dateOp`,
/// `objectOp`), a positional parameter placeholder ([p], rendered `:name`), or
/// a qualified field reference (`textF`/`intF`/… rendered `table.column`). The
/// operators in the object-persistence query builder call back into the active
/// dialect via [TomOperator.generate], so a driver can subclass this dialect to
/// override any fragment for its database (see [MariadbSqlDialect]).
///
/// The literal renderers interpolate values directly into the SQL string;
/// string literals are escaped ([text] doubles single quotes and backslashes)
/// so an embedded quote cannot break out of the literal. For untrusted input
/// still prefer the parameterised form ([p]) so the driver binds the value and
/// nothing is embedded in the SQL text at all.
class TomStandardSqlDialect {
  /// Renders `<what> IS NULL`.
  SqlString isNull<T>(TomOperator<T> what) {
    return "${what.generate(this)} IS NULL";
  }

  /// Renders `<what> IS NOT NULL`.
  SqlString isNotNull<T>(TomOperator<T> what) {
    return "${what.generate(this)} IS NOT NULL";
  }

  /// Renders `<what> IN (<choices...>)` with the choices comma-separated.
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

  /// Renders `<what> BETWEEN <lo> AND <hi>` from a two-element [betweenLimits].
  SqlString between<T>(
    TomOperator<T> what,
    List<TomOperator<T>> betweenLimits,
  ) {
    return "${what.generate(this)} BETWEEN ${betweenLimits[0].generate(this)} AND ${betweenLimits[1].generate(this)}";
  }

  /// Renders `<text> LIKE <test>`.
  SqlString like(TomOperator<TomDbString> text, TomOperator<TomDbString> test) {
    return "${text.generate(this)} LIKE ${test.generate(this)}";
  }

  /// Renders `<text> NOT LIKE <test>`.
  SqlString notLike(
    TomOperator<TomDbString> text,
    TomOperator<TomDbString> test,
  ) {
    var notLike = "${text.generate(this)} NOT LIKE ${test.generate(this)}";
    return notLike;
  }

  /// Renders `<text> REGEXP <test>` (standard form; drivers may override).
  SqlString regexp(
    TomOperator<TomDbString> text,
    TomOperator<TomDbString> test,
  ) {
    return "${text.generate(this)} REGEXP ${test.generate(this)}";
  }

  /// Wraps [operant] in parentheses: `( <operant> )`.
  SqlString group<T>(TomOperator<T> operant) {
    return "( ${operant.generate(this)} )";
  }

  /// Renders `<operant1> = <operant2>`.
  SqlString eq<T>(TomOperator<T> operant1, TomOperator<T> operant2) =>
      "${operant1.generate(this)} = ${operant2.generate(this)}";

  /// Renders `<operant1> <> <operant2>`.
  SqlString neq<T>(TomOperator<T> operant1, TomOperator<T> operant2) =>
      "${operant1.generate(this)} <> ${operant2.generate(this)}";

  /// Renders `<operant1> < <operant2>`.
  SqlString lt<T>(TomOperator<T> operant1, TomOperator<T> operant2) =>
      "${operant1.generate(this)} < ${operant2.generate(this)}";

  /// Renders `<operant1> <= <operant2>`.
  SqlString lte<T>(TomOperator<T> operant1, TomOperator<T> operant2) =>
      "${operant1.generate(this)} <= ${operant2.generate(this)}";

  /// Renders `<operant1> > <operant2>`.
  SqlString gt<T>(TomOperator<T> operant1, TomOperator<T> operant2) =>
      "${operant1.generate(this)} > ${operant2.generate(this)}";

  /// Renders `<operant1> >= <operant2>`.
  SqlString gte<T>(TomOperator<T> operant1, TomOperator<T> operant2) =>
      "${operant1.generate(this)} >= ${operant2.generate(this)}";

  /// Renders `NOT <operant1>`.
  SqlString not(TomOperator<TomDbBool> operant1) =>
      "NOT ${operant1.generate(this)}";

  /// Joins the [operant1] predicates with ` AND `.
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

  /// Joins the [operant1] predicates with ` OR `.
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

  /// Renders a string literal, single-quoted, escaping any embedded backslash
  /// (`\` → `\\`) and single quote (`'` → `''`) so the value cannot terminate
  /// the literal early and inject trailing SQL. For untrusted input still
  /// prefer the parameterised form ([p]), which binds the value out-of-band.
  SqlString text(String text) {
    final escaped = text.replaceAll('\\', r'\\').replaceAll("'", "''");
    return "'$escaped'";
  }

  /// Renders an integer literal.
  SqlString intOp(int value) {
    return "$value";
  }

  /// Renders a double literal.
  SqlString doubleOp(double value) {
    return "$value";
  }

  /// Renders a boolean literal.
  SqlString boolOp(bool value) {
    return "$value";
  }

  /// Renders a timestamp literal as a single-quoted ISO-8601 string.
  SqlString dateTimeOp(DateTime value) {
    return "'${value.toIso8601String()}'";
  }

  /// Renders a date literal as single-quoted `YYYY-M-D`.
  SqlString dateOp(DateTime value) {
    return "'${value.year}-${value.month}-${value.day}'";
  }

  /// Renders [values] as a comma-separated list of literals (each via
  /// [objectOp]).
  SqlString iterableOp(Iterable values) {
    var result = "";
    for (var v in values) {
      result += (result.isEmpty ? "" : ",") + objectOp(v);
    }
    return result;
  }

  /// Renders the SQL `NULL` literal.
  SqlString nullOp() {
    return "NULL";
  }

  /// Renders [o] as the appropriate SQL literal, dispatching on its runtime
  /// type (`null` → `NULL`, `String` → quoted, numbers/bool → bare,
  /// [TomZonedDate] → date, [DateTime] → timestamp, [Iterable] → list, anything
  /// else → its quoted `toString()`).
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

  /// Renders a positional parameter placeholder `:<parameterName>` for a
  /// prepared statement (the driver binds the value, avoiding injection).
  SqlString p<T>(String parameterName) => ":$parameterName";

  /// Renders a qualified reference to a `String` [column] as `table.column`.
  SqlString textF(String fieldName, DbCol column, Type dbType) {
    return "${column.columnInformation.table.table}.${column.columnInformation.getQueryFieldName()}";
  }

  /// Renders a qualified reference to an `int` [column] as `table.column`.
  SqlString intF(String fieldName, DbCol column, Type dbType) {
    return "${column.columnInformation.table.table}.${column.columnInformation.getQueryFieldName()}";
  }

  /// Renders a qualified reference to a `double` [column] as `table.column`.
  SqlString doubleF(String fieldName, DbCol column, Type dbType) {
    return "${column.columnInformation.table.table}.${column.columnInformation.getQueryFieldName()}";
  }

  /// Renders a qualified reference to a `bool` [column] as `table.column`.
  SqlString boolF(String fieldName, DbCol column, Type dbType) {
    return "${column.columnInformation.table.table}.${column.columnInformation.getQueryFieldName()}";
  }

  /// Renders a qualified reference to a timestamp [column] as `table.column`.
  SqlString dateTimeF(String fieldName, DbCol column, Type dbType) {
    return "${column.columnInformation.table.table}.${column.columnInformation.getQueryFieldName()}";
  }

  /// Renders a qualified reference to a date [column] as `table.column`.
  SqlString dateF(String fieldName, DbCol column, Type dbType) {
    return "${column.columnInformation.table.table}.${column.columnInformation.getQueryFieldName()}";
  }
}

/// Annotation marking a [TomStandardSqlDialect] subclass as the dialect for a
/// named [dataSourceType] (e.g. `"mariadb"`). Used by reflection-based dialect
/// discovery to pick the right dialect for a data source.
class TomSqlDialect {
  /// The data-source type this dialect serves (matches a driver's `type`).
  final String dataSourceType;

  /// Binds this dialect to [dataSourceType].
  const TomSqlDialect(this.dataSourceType);
}

import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../object_persistence/operators_expressions.dart';
import 'types_operator.dart';

/// A SQL fragment. An alias for `String` that documents intent at call sites.
typedef SqlString = String;

/// The aggregate functions the typed query layer can express.
///
/// Naming the vocabulary here rather than in the expression tree keeps the set
/// of functions a dialect must be able to render in one place: a driver that
/// needs a different spelling overrides [TomStandardSqlDialect.aggregate] and
/// switches on this enum, and the compiler tells it when a member is added.
enum TomAggregateFunction {
  /// `COUNT` — the number of rows (or of non-null operand values).
  count,

  /// `SUM` — the total of the operand across the group.
  sum,

  /// `AVG` — the mean of the operand across the group.
  avg,

  /// `MIN` — the smallest operand value in the group.
  min,

  /// `MAX` — the largest operand value in the group.
  max;

  /// The SQL function name this member renders as.
  String get sqlName => name.toUpperCase();
}

/// The coarse type classes a stored column can belong to.
///
/// Named here, beside [TomAggregateFunction], for the same reason: it is a SQL
/// vocabulary a dialect switches on ([TomStandardSqlDialect.typeFamily]), so a
/// database whose type names differ overrides one method and the compiler tells
/// it when a member is added.
///
/// Deliberately coarse — it exists so that a Dart type and a SQL type name can
/// be compared at all (the schema-convergence check reduces both sides to it).
/// Widths, precisions, signedness and defaults are not represented, because the
/// Dart side never states them.
enum TomSqlTypeFamily {
  /// Whole numbers — `INT`, `BIGINT`, `SMALLINT`, `SERIAL`, …
  integer,

  /// Approximate and exact fractional numbers — `DOUBLE`, `DECIMAL`, `FLOAT`, …
  decimal,

  /// Character data — `VARCHAR`, `TEXT`, `ENUM`, `JSON`, …
  text,

  /// Truth values — `BOOLEAN`, and on MariaDB `TINYINT(1)`.
  boolean,

  /// A date *and* a time of day — `DATETIME`, `TIMESTAMP`.
  dateTime,

  /// A calendar date with no time — `DATE`.
  date,

  /// A time of day with no date — `TIME`.
  time,

  /// Raw bytes — `BLOB`, `VARBINARY`, …
  binary,

  /// A type the active dialect does not classify.
  unknown,
}

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
  /// Classifies a column type as written in DDL — `VARCHAR(255)`, `BIGINT
  /// UNSIGNED`, `DECIMAL(10,2)` — into the family it stores.
  ///
  /// The base word decides; the parenthesised arguments and any trailing
  /// attributes are ignored, since no width or precision is expressible on the
  /// Dart side and so none can be compared. An unrecognised type yields
  /// [TomSqlTypeFamily.unknown] rather than a guess — the convergence check
  /// treats that as "no opinion" instead of reporting a divergence it cannot
  /// justify.
  ///
  /// A dialect with different type names overrides this and falls back to
  /// `super.typeFamily` for the standard ones (see [MariadbSqlDialect]).
  TomSqlTypeFamily typeFamily(String sqlType) {
    final base = baseTypeName(sqlType);
    return switch (base) {
      'INT' ||
      'INTEGER' ||
      'BIGINT' ||
      'SMALLINT' ||
      'MEDIUMINT' ||
      'TINYINT' ||
      'SERIAL' ||
      'BIT' => TomSqlTypeFamily.integer,
      'DECIMAL' ||
      'DEC' ||
      'NUMERIC' ||
      'FIXED' ||
      'FLOAT' ||
      'DOUBLE' ||
      'REAL' => TomSqlTypeFamily.decimal,
      'CHAR' ||
      'CHARACTER' ||
      'VARCHAR' ||
      'NCHAR' ||
      'NVARCHAR' ||
      'TINYTEXT' ||
      'TEXT' ||
      'MEDIUMTEXT' ||
      'LONGTEXT' ||
      'CLOB' ||
      'ENUM' ||
      'SET' ||
      'JSON' ||
      'UUID' => TomSqlTypeFamily.text,
      'BOOL' || 'BOOLEAN' => TomSqlTypeFamily.boolean,
      'DATETIME' || 'TIMESTAMP' => TomSqlTypeFamily.dateTime,
      'DATE' || 'YEAR' => TomSqlTypeFamily.date,
      'TIME' => TomSqlTypeFamily.time,
      'BINARY' ||
      'VARBINARY' ||
      'TINYBLOB' ||
      'BLOB' ||
      'MEDIUMBLOB' ||
      'LONGBLOB' => TomSqlTypeFamily.binary,
      _ => TomSqlTypeFamily.unknown,
    };
  }

  /// The upper-cased leading word of a DDL type — `VARCHAR(255)` → `VARCHAR`,
  /// `DOUBLE PRECISION` → `DOUBLE`, `` `int` `` → `INT`.
  ///
  /// Exposed so an overriding [typeFamily] can reuse the same normalisation
  /// instead of restating it.
  String baseTypeName(String sqlType) {
    final trimmed = sqlType.trim();
    var end = 0;
    while (end < trimmed.length) {
      final c = trimmed[end];
      if (c == '(' || c == ' ' || c == '\t' || c == '\n') break;
      end++;
    }
    return trimmed.substring(0, end).replaceAll('`', '').toUpperCase();
  }

  /// The comma-separated arguments of a DDL type's parenthesis, or an empty
  /// list when it has none — `VARCHAR(255)` → `['255']`, `DECIMAL(10, 2)` →
  /// `['10', '2']`.
  ///
  /// Exposed for the same reason as [baseTypeName]: a dialect whose type
  /// classification depends on the argument (`TINYINT(1)` is MariaDB's boolean)
  /// should not have to re-tokenise the type itself.
  List<String> typeArguments(String sqlType) {
    final open = sqlType.indexOf('(');
    if (open < 0) return const [];
    final close = sqlType.indexOf(')', open);
    if (close < 0) return const [];
    return [
      for (final argument in sqlType.substring(open + 1, close).split(','))
        argument.trim(),
    ];
  }

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

  /// Renders an aggregate call — `COUNT(*)`, `SUM(t.c)`, `COUNT(DISTINCT t.c)`.
  ///
  /// [operand] is the already-rendered argument, or `null` for the one
  /// argument-less form, `COUNT(*)`. [distinct] inserts the `DISTINCT`
  /// qualifier; it is meaningless for `COUNT(*)` (there is no expression to
  /// de-duplicate) and is ignored there.
  SqlString aggregate(
    TomAggregateFunction function,
    SqlString? operand, {
    bool distinct = false,
  }) {
    if (operand == null) return "${function.sqlName}(*)";
    return "${function.sqlName}(${distinct ? 'DISTINCT ' : ''}$operand)";
  }

  /// Renders `<expression> AS <alias>` — the projection form that names a
  /// grouped query's result column so the row mapper can find it.
  SqlString aliased(SqlString expression, String alias) =>
      "$expression AS $alias";

  /// Renders ` GROUP BY <columns...>`, or the empty string when [columnExprs]
  /// is empty (an aggregate over the whole result set groups by nothing).
  SqlString groupByClause(List<SqlString> columnExprs) =>
      columnExprs.isEmpty ? "" : " GROUP BY ${columnExprs.join(', ')}";

  /// Renders ` HAVING <predicate>`, or the empty string when there is none.
  ///
  /// `HAVING` filters *groups* after aggregation, where `WHERE` filters rows
  /// before it — which is why the two predicates stay separate all the way
  /// down to here rather than being ANDed together upstream.
  SqlString havingClause(SqlString? predicate) =>
      predicate == null ? "" : " HAVING $predicate";

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

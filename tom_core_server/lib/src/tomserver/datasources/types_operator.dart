import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'sql_dialects.dart';

/// A boxed, SQL-typed value: the bridge between a Dart value and the column
/// type it maps to in a data source.
///
/// Each concrete subtype ([TomDbInt], [TomDbDouble], [TomDbString],
/// [TomDbDateTime], [TomDbDate], [TomDbTime], [TomDbBool]) wraps a nullable
/// Dart value and provides a static `of(String?)` factory that parses a string
/// representation (as read from a driver result set or a query parameter) into
/// the boxed type. A `null` string always yields a box holding `null`.
///
/// These types parameterise the [TomOperator] expression tree so that the
/// query builder can keep operands type-safe (`TomOperator<TomDbBool>` is a
/// predicate, `TomOperator<TomDbString>` a text expression, and so on).
abstract class TomDbType<T> extends TomObject<T> {
  /// Wraps [value] as the SQL-typed box.
  TomDbType(super.value);

  @override
  String toString() {
    return "TomDbType $runtimeType ${get()}";
  }
}

/// A SQL-typed box for a nullable `int`.
class TomDbInt extends TomDbType<int?> {
  /// Wraps [value] as a SQL integer.
  TomDbInt(super.value);

  /// Parses [s] as an `int` (or `null` when [s] is `null`).
  static TomDbInt of(String? s) {
    return s == null ? TomDbInt(null) : TomDbInt(int.parse(s));
  }
}

/// A SQL-typed box for a nullable `double`.
class TomDbDouble extends TomDbType<double?> {
  /// Wraps [value] as a SQL double.
  TomDbDouble(super.value);

  /// Parses [s] as a `double` (or `null` when [s] is `null`).
  static TomDbDouble of(String? s) {
    return s == null ? TomDbDouble(null) : TomDbDouble(double.parse(s));
  }
}

/// A SQL-typed box for a nullable `String`.
class TomDbString extends TomDbType<String?> {
  /// Wraps [value] as a SQL string.
  TomDbString(super.value);

  /// Wraps [s] verbatim (a `null` string yields a box holding `null`).
  static TomDbString of(String? s) {
    return TomDbString(s);
  }
}

/// A SQL-typed box for a nullable `DateTime` (a timestamp).
class TomDbDateTime extends TomDbType<DateTime?> {
  /// Wraps [value] as a SQL timestamp.
  TomDbDateTime(super.value);

  /// Parses [s] via [DateTime.parse] (or `null` when [s] is `null`).
  static TomDbDateTime of(String? s) {
    return s == null ? TomDbDateTime(null) : TomDbDateTime(DateTime.parse(s));
  }
}

/// A SQL-typed box for a nullable [TomZonedDate] (a calendar date).
class TomDbDate extends TomDbType<TomZonedDate?> {
  /// Wraps [value] as a SQL date.
  TomDbDate(super.value);

  /// Parses [s] via [TomZonedDate.parseFromString] (or `null` when [s] is
  /// `null`).
  static TomDbDate of(String? s) {
    return s == null ? TomDbDate(null) : TomDbDate(TomZonedDate.parseFromString(s));
  }
}

/// A SQL-typed box for a nullable [TomZonedTime] (a time of day).
class TomDbTime extends TomDbType<TomZonedTime?> {
  /// Wraps [value] as a SQL time.
  TomDbTime(super.value);

  /// Parses [s] via [TomZonedTime.parseFromString] (or `null` when [s] is
  /// `null`).
  static TomDbTime of(String? s) {
    return s == null ? TomDbTime(null) : TomDbTime(TomZonedTime.parseFromString(s));
  }
}

/// A SQL-typed box for a nullable `bool`.
class TomDbBool extends TomDbType<bool?> {
  /// Wraps [value] as a SQL boolean.
  TomDbBool(super.value);

  /// Parses [s] via [bool.parse] (or `null` when [s] is `null`).
  static TomDbBool of(String? s) {
    return s == null ? TomDbBool(null) : TomDbBool(bool.parse(s));
  }
}

/// A node in a SQL expression tree, parameterised by its SQL return type [R].
///
/// An operator knows how to [generate] its SQL fragment against a
/// [TomStandardSqlDialect], which [getFields] it references (for join/column
/// analysis) and which positional [getParameters] it contributes (for prepared
/// statements). The type parameter [R] keeps the tree type-safe: a comparison
/// returns `TomOperator<TomDbBool>`, a literal string `TomOperator<TomDbString>`,
/// etc. — see the query-builder operators in the object-persistence module for
/// the concrete factories.
abstract class TomOperator<R> {
  /// The dialect used when an operator is rendered without an explicit one.
  static TomStandardSqlDialect defaultDialect = TomStandardSqlDialect();

  /// Renders this operator's SQL fragment using dialect [t].
  SqlString generate(TomStandardSqlDialect t);

  /// The runtime SQL return type [R], captured at construction.
  late Type returnType;

  /// The positional parameter placeholders this operator contributes, in
  /// left-to-right order. Leaf literals override this; container operators
  /// concatenate their children's parameters. Empty by default.
  List<String> getParameters(TomStandardSqlDialect t) => [];

  /// The set of column/field names this operator references.
  Set<String> getFields(TomStandardSqlDialect t);

  /// Captures [returnType] from the type parameter [R].
  TomOperator() {
    returnType = R;
  }

  @override
  String toString() => analyze(0);

  /// Returns a newline followed by [i] tab characters — used by [analyze] to
  /// pretty-print a nested operator tree.
  String indent(int i) {
    String indent = "\n";
    for (int j = 0; j < i; j++) {
      indent += "\t";
    }
    return indent;
  }

  /// Returns a human-readable, indented description of this operator at tree
  /// depth [l] (for debugging). Container operators override to recurse.
  String analyze(int l) => "TomOperator $runtimeType $returnType";
}

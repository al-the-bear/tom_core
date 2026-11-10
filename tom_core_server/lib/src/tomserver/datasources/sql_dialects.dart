import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../object_persistence/operators_expressions.dart';
import 'sql_instant.dart';
import 'sql_lexer.dart';
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

  /// The character that turns the next `%` or `_` in a `LIKE` pattern into
  /// itself, named in the `ESCAPE` clause [like] and [notLike] render.
  ///
  /// A dialect whose escape character differs overrides this; nothing else has
  /// to change, because [escapeLikePattern] and the rendered clause both read
  /// it from here.
  String get likeEscapeCharacter => r'\';

  /// Escapes [literal] so a `LIKE` pattern built from it matches those
  /// characters *literally* — `%`, `_` and [likeEscapeCharacter] itself.
  ///
  /// `LIKE` is the one predicate whose right-hand operand is a small language
  /// rather than a value, so a caller who means "contains the text the user
  /// typed" has to say so: `WHERE note LIKE :p` with `p` bound to `%50%%`
  /// matches every note containing `50` followed by anything, not the notes
  /// mentioning `50%`. Neither binding nor [text] can prevent that — both make
  /// the value *safe*, and a wildcard in a pattern is not unsafe, it is the
  /// pattern working as specified.
  ///
  /// So the wildcards stay the caller's to place, and this escapes what is
  /// between them:
  ///
  /// ```dart
  /// params['p'] = '%${dialect.escapeLikePattern(searchBox.text)}%';
  /// ```
  ///
  /// The escape character is doubled first, or a pattern already containing one
  /// would consume the escape this adds.
  String escapeLikePattern(String literal) {
    final e = likeEscapeCharacter;
    return literal
        .replaceAll(e, '$e$e')
        .replaceAll('%', '$e%')
        .replaceAll('_', '${e}_');
  }

  /// Renders `<text> LIKE <test> ESCAPE '<likeEscapeCharacter>'`.
  ///
  /// The `ESCAPE` clause is always written. Standard SQL defines *no* default
  /// escape character for `LIKE`, so without it whether
  /// [escapeLikePattern]'s output works is a property of the driver rather than
  /// of this rendering — and it happens to work on MariaDB, which is the way a
  /// dependency on an undocumented default survives being noticed.
  SqlString like(TomOperator<TomDbString> text, TomOperator<TomDbString> test) {
    return "${text.generate(this)} LIKE ${test.generate(this)}"
        " ESCAPE ${this.text(likeEscapeCharacter)}";
  }

  /// Renders `<text> NOT LIKE <test> ESCAPE '<likeEscapeCharacter>'` — see
  /// [like] for why the clause is always written.
  SqlString notLike(
    TomOperator<TomDbString> text,
    TomOperator<TomDbString> test,
  ) {
    return "${text.generate(this)} NOT LIKE ${test.generate(this)}"
        " ESCAPE ${this.text(likeEscapeCharacter)}";
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

  /// `EXISTS (<subquery>)` over the rendered [subquery].
  SqlString exists(SqlString subquery) => "EXISTS ($subquery)";

  /// `<operand> IN (<subquery>)` over the rendered [operand] and [subquery].
  SqlString inSubquery(SqlString operand, SqlString subquery) =>
      "$operand IN ($subquery)";

  /// A subquery: `SELECT <projection> FROM <tables> WHERE <conditions>`, every
  /// condition parenthesised so an `OR` inside one cannot bind across the
  /// `AND` that joins them.
  SqlString subquery(
    SqlString projection,
    List<String> tables,
    List<SqlString> conditions,
  ) =>
      "SELECT $projection FROM ${tables.join(', ')}"
      "${conditions.isEmpty ? '' : ' WHERE ${conditions.map((c) => '($c)').join(' AND ')}'}";

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

  /// Renders a constant predicate — `WHERE false` for a scope that admits
  /// nothing. The same text as [boolOp] here; a database whose truth columns
  /// are not booleans (PostgreSQL) renders the two differently.
  SqlString truthPredicate(bool value) => boolOp(value);

  /// Renders a timestamp literal as the single-quoted UTC `DATETIME(6)` text
  /// [sqlInstant] defines.
  ///
  /// The same rendering the bind boundary applies, for the same two reasons. An
  /// ISO-8601 string carries a `T` separator and, for a UTC value, a trailing
  /// `Z`; a `DATETIME` column accepts neither ("Incorrect datetime value",
  /// error 1292), so the literal path could not carry a UTC instant at all. And
  /// a local value rendered verbatim writes the *emitting node's* wall clock,
  /// which is not a moment another node can read back.
  SqlString dateTimeOp(DateTime value) {
    return "'${sqlInstant(value)}'";
  }

  /// Renders a date literal as single-quoted, fixed-width `YYYY-MM-DD`.
  ///
  /// Every component is zero-padded, so the literal is the same length whatever
  /// the date. MariaDB accepts a ragged `2026-1-2` too, so padding is not what
  /// makes the value storable — it is what makes generated SQL comparable as
  /// text, and it keeps the module to one date spelling rather than a second
  /// one invented here.
  ///
  /// Unlike [dateTimeOp], the components are taken **as labelled**: no UTC
  /// conversion is applied, so a value naming the 5th renders as the 5th in
  /// every zone. That is the difference between the two renderers, and the
  /// reason this one reaches for [sqlDate] rather than [sqlInstant].
  SqlString dateOp(DateTime value) {
    return "'${sqlDate(value)}'";
  }

  /// Renders a time-of-day literal as single-quoted, fixed-width `HH:MM:SS`.
  ///
  /// The date half of [value] is discarded, which is the whole point: a `TIME`
  /// column stores a position within a day, and MariaDB reads a
  /// datetime-shaped string for one as a truncation error rather than as the
  /// time it contains.
  ///
  /// Like [dateOp] and unlike [dateTimeOp], the components are taken **as
  /// labelled**: no UTC conversion is applied, so a value naming 14:30 renders
  /// as 14:30 in every zone. A [TomZonedTime] therefore renders the reading its
  /// own anchoring carries, exactly as a [TomZonedDate] does through [dateOp] —
  /// the two halves of a split timestamp are treated the same way, which is the
  /// only way a query over both can be reasoned about.
  ///
  /// Sub-second precision is dropped — see [sqlTimeOfDay], which this quotes
  /// rather than restates so that an inlined literal and a bound value cannot
  /// spell the same time differently.
  SqlString timeOp(DateTime value) {
    return "'${sqlTimeOfDay(value)}'";
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
  /// [TomZonedDate] → date, [TomZonedTime] → time, [DateTime] → timestamp,
  /// [Iterable] → list, anything else → its quoted `toString()`).
  ///
  /// Both kernel temporal types are tested before the plain [DateTime] they
  /// extend; either arm placed after it would be unreachable, and the value
  /// would be written as a full instant into a column that holds half of one.
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
    } else if (o is TomZonedTime) {
      return timeOp(o);
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

  /// Renders a qualified reference to a time-of-day [column] as `table.column`.
  SqlString timeF(String fieldName, DbCol column, Type dbType) {
    return "${column.columnInformation.table.table}.${column.columnInformation.getQueryFieldName()}";
  }
  // ---------------------------------------------------------------------------
  // DDL and row writes
  //
  // The framework declares its own tables once, in the canonical type
  // vocabulary below (MariaDB's spelling: `DATETIME(6)`, `TINYINT(1)`,
  // `LONGTEXT`, `AUTO_INCREMENT`), and every database renders that declaration
  // in its own words. The defaults render it unchanged; a dialect whose
  // database spells a type, a key or a conflicting write differently overrides
  // the method that renders it.
  // ---------------------------------------------------------------------------

  /// The type this database stores the canonical [canonicalType] as.
  String columnType(String canonicalType) => canonicalType;

  /// One column's line in a `CREATE TABLE` body, its name and type padded to
  /// [nameWidth] and [typeWidth] so a reader can scan the types in a column.
  SqlString columnDefinition({
    required String name,
    required String type,
    required bool nullable,
    String? defaultValue,
    bool autoIncrement = false,
    int nameWidth = 0,
    int typeWidth = 0,
  }) {
    final buffer = StringBuffer()
      ..write(name.padRight(nameWidth))
      ..write(' ')
      ..write(columnType(type).padRight(typeWidth))
      ..write(' ')
      ..write(nullable ? 'NULL' : 'NOT NULL');
    if (defaultValue != null) buffer.write(' DEFAULT $defaultValue');
    if (autoIncrement) buffer.write(' AUTO_INCREMENT');
    return buffer.toString();
  }

  /// Whether a `CREATE TABLE` body may declare a non-unique index inline
  /// (`KEY name (columns)`). Where it may not, [createIndex] renders one
  /// statement per index after the table.
  bool get declaresIndexesInline => true;

  /// An inline key's line in a `CREATE TABLE` body.
  SqlString keyDefinition(
    String name,
    List<String> columns, {
    required bool unique,
  }) => '${unique ? 'UNIQUE KEY' : 'KEY'} $name (${columns.join(', ')})';

  /// The statement creating index [name] on [table] when the body cannot
  /// declare it ([declaresIndexesInline] is `false`).
  SqlString createIndex(String name, String table, List<String> columns) =>
      'CREATE INDEX IF NOT EXISTS $name ON $table (${columns.join(', ')})';

  /// A row-writing statement into [table]: the columns of [values] with the SQL
  /// text that supplies each — a `:bind` or a literal.
  ///
  /// A row whose key already exists raises the database's duplicate-key error,
  /// unless [ignoreConflict] asks for the stored row to be kept and the write to
  /// change nothing.
  SqlString insertInto(
    String table,
    Map<String, String> values, {
    bool ignoreConflict = false,
  }) =>
      '${ignoreConflict ? 'INSERT IGNORE' : 'INSERT'} INTO $table '
      '(${values.keys.join(', ')}) VALUES (${values.values.join(', ')})';

  /// The statements writing a row into [table] over every row it supersedes —
  /// the one with its [primaryKey], and any that collides with it on one of
  /// [uniqueKeys] — run in order, in one transaction when there is more than
  /// one.
  ///
  /// MariaDB's `REPLACE` is all of that in one statement. A database without it
  /// deletes the superseded rows first: a key freed by a statement is free to
  /// the next statement of the same transaction, and to nothing earlier.
  List<SqlString> replaceInto(
    String table,
    Map<String, String> values, {
    required List<String> primaryKey,
    List<List<String>> uniqueKeys = const [],
  }) => [
    'REPLACE INTO $table (${values.keys.join(', ')}) '
        'VALUES (${values.values.join(', ')})',
  ];

  /// One statement that inserts a row into [table] or, when a row with the same
  /// [conflictKey] values exists, overwrites that row's [updateColumns] with
  /// the values [values] supplies — an insert-or-update with no read before it,
  /// so two writers racing for the same key cannot both insert.
  ///
  /// With [keyColumn] the statement reports that column of the row it wrote —
  /// inserted or updated — as its generated id: MariaDB through
  /// `<key> = LAST_INSERT_ID(<key>)` in the update, PostgreSQL through
  /// `RETURNING`.
  ///
  /// MariaDB's `ON DUPLICATE KEY UPDATE` reacts to a collision on *any* unique
  /// key of the table, where PostgreSQL's `ON CONFLICT` names [conflictKey]; a
  /// table whose only unique keys are its primary key and [conflictKey] —
  /// which is what a caller passes a surrogate-keyed row for — behaves the same
  /// on both.
  SqlString upsert(
    String table,
    Map<String, String> values, {
    required List<String> conflictKey,
    required List<String> updateColumns,
    String? keyColumn,
  }) => [
    'INSERT INTO $table (${values.keys.join(', ')}) '
        'VALUES (${values.values.join(', ')}) ON DUPLICATE KEY UPDATE ',
    [
      for (final column in updateColumns) '$column = VALUES($column)',
      if (keyColumn != null) '$keyColumn = LAST_INSERT_ID($keyColumn)',
      // Nothing to overwrite: MariaDB has no `DO NOTHING`, so the row keeps
      // itself by assigning a conflict column its own value.
      if (updateColumns.isEmpty && keyColumn == null)
        '${conflictKey.first} = ${conflictKey.first}',
    ].join(', '),
  ].join();

  /// One statement that counts one more in [table]'s row whose [conflictKey]
  /// columns hold the values [values] supplies, creating the row with a count
  /// of `1` when there is none — and reports the count it left in [counter] as
  /// the statement's generated id.
  ///
  /// Taken and read in one statement because the alternative is wrong under
  /// concurrency: read with a second statement, every caller of a burst sees
  /// the final total rather than its own place in it. MariaDB reports it
  /// through `LAST_INSERT_ID(expr)`; a database with no last-insert id returns
  /// it with `RETURNING` instead.
  SqlString incrementCounter(
    String table,
    Map<String, String> values,
    String counter, {
    required List<String> conflictKey,
  }) =>
      'INSERT INTO $table (${[...values.keys, counter].join(', ')}) '
      'VALUES (${[...values.values, 'LAST_INSERT_ID(1)'].join(', ')}) '
      'ON DUPLICATE KEY UPDATE $counter = LAST_INSERT_ID($counter + 1)';

  /// [insert] made to report the value of [keyColumn] it generated as the
  /// statement's generated id.
  ///
  /// The default needs nothing: a database with a last-insert id reports the
  /// key on its own. One without (PostgreSQL) appends `RETURNING`, which its
  /// driver reads back as the generated id.
  SqlString returningKey(String insert, String keyColumn) => insert;

  /// Whether a backslash escapes the next character inside a string literal —
  /// MariaDB's default mode. A statement splitter has to know: in a database
  /// that reads it literally, `'C:\'` is a whole literal.
  bool get backslashEscapes => true;

  /// [statement], written in the framework's canonical DDL — MariaDB's
  /// spelling: `AUTO_INCREMENT`, `DATETIME(6)`, inline `KEY`s, table options —
  /// as the statements this database runs to the same effect.
  ///
  /// The default runs it unchanged. A store that keeps a hand-written
  /// `CREATE TABLE`, and a test that builds a fixture table, pass it through
  /// here so one declaration serves every database.
  List<SqlString> translateCanonical(String statement) => [statement];

  /// A whole canonical [script] — a migration file — in this database's
  /// words: each statement through [translateCanonical], comments kept, one
  /// statement per `;`-terminated paragraph.
  String translateCanonicalScript(String script) => [
    // The script is canonical, so it is split by MariaDB's literal rule.
    for (final statement in TomSqlLexer.splitStatements(script))
      for (final translated in translateCanonical(statement)) '$translated;',
  ].join('\n\n');

  /// The statement creating schema [name] if it does not exist — a database,
  /// in MariaDB, where a schema and a database are one thing.
  ///
  /// [name] must be a plain identifier; the caller checks it.
  SqlString createSchema(String name) =>
      'CREATE DATABASE IF NOT EXISTS ${quoteIdentifier(name)}';

  /// The statement dropping schema [name] and everything in it, if it exists
  /// — `DROP DATABASE` in MariaDB. What a purged schema-isolated tenant's
  /// schema is removed with.
  ///
  /// [name] must be a plain identifier; the caller checks it.
  SqlString dropSchema(String name) =>
      'DROP DATABASE IF EXISTS ${quoteIdentifier(name)}';

  /// The statement dropping database [name], if it exists — what a purged
  /// database-isolated tenant's database is removed with.
  ///
  /// [name] must be a plain identifier; the caller checks it.
  SqlString dropDatabase(String name) =>
      'DROP DATABASE IF EXISTS ${quoteIdentifier(name)}';

  /// The data-source setting that points a connection at a schema — the
  /// database name, in MariaDB. A schema-isolated tenant's data source is its
  /// base data source with this one setting changed.
  String get schemaSetting => 'databaseName';

  /// The expression naming the schema the connection works in — MariaDB's
  /// `DATABASE()` — for a query of the catalogue about "this" schema.
  SqlString get currentSchema => 'DATABASE()';

  /// A query answering, for the table bound as `:table` in [currentSchema],
  /// one row per column in declaration order: `column_name`, `column_type`
  /// (with its length — `varchar(191)`, `tinyint(1)`), `is_nullable` (`YES`
  /// or `NO`) and `column_key` (`PRI` for a primary-key column).
  ///
  /// What the live schema check compares a framework table against.
  SqlString get tableColumnsQuery =>
      'SELECT COLUMN_NAME AS column_name, COLUMN_TYPE AS column_type, '
      'IS_NULLABLE AS is_nullable, COLUMN_KEY AS column_key '
      'FROM information_schema.COLUMNS '
      'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :table '
      'ORDER BY ORDINAL_POSITION';

  /// The statements installing trigger [name], which refuses every [event]
  /// (`UPDATE` or `DELETE`) on [table] with [message] — a guard a deployment
  /// installs, not something the framework issues itself.
  List<SqlString> rejectingTrigger({
    required String name,
    required String table,
    required String event,
    required String message,
  }) => [
    '''
CREATE TRIGGER IF NOT EXISTS $name
BEFORE $event ON $table
FOR EACH ROW
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = '$message' ''',
  ];

  /// [identifier] quoted, for a name that may be a reserved word or carry
  /// characters an unquoted identifier may not.
  SqlString quoteIdentifier(String identifier) =>
      '`${identifier.replaceAll('`', '``')}`';
}

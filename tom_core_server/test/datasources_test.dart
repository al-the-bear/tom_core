import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// A leaf [TomOperator] that renders a fixed SQL fragment — used to drive the
/// dialect's container operators without pulling in the reflection-backed query
/// builder.
class _Literal<R> extends TomOperator<R> {
  final String sql;
  final Set<String> fields;
  _Literal(this.sql, {this.fields = const {}});

  @override
  SqlString generate(TomStandardSqlDialect t) => sql;

  @override
  Set<String> getFields(TomStandardSqlDialect t) => fields;
}

/// Scripts a data source's command execution, so a transaction lifecycle can be
/// driven to any outcome without a database.
///
/// The alternative — leaving the data source unconnected so every command
/// throws — cannot express the case that matters. A transaction's state only
/// exists after a start that *succeeded*, and the whole question about the exit
/// paths is what they do with state that is genuinely set. Driving those from a
/// failed start meant asserting against what a failure had left behind, which
/// is precisely the behaviour under repair: once the start path cleans up after
/// itself, such a test still passes and pins nothing.
///
/// Recording the commands is the second half. The XA branch id is private and
/// has no accessor, so the SQL is the only place it is observable — a wrongly
/// cleared one shows itself as the literal `XA COMMIT null;`.
mixin _ScriptedCommands on MariaDbDatasource {
  /// Every command reached, in order, with the branch id as interpolated.
  final commands = <String>[];

  /// Commands starting with any of these prefixes throw instead of running.
  Set<String> failing = const {};

  @override
  Future<BigInt> executeCommand(
    String command, [
    Map<String, dynamic>? params,
  ]) async {
    commands.add(command);
    if (failing.any(command.startsWith)) {
      throw StateError('scripted failure for: $command');
    }
    return BigInt.zero;
  }
}

class _ScriptedXADatasource extends MariaDbXADatasource with _ScriptedCommands {
  _ScriptedXADatasource({Set<String> failing = const {}}) {
    this.failing = failing;
  }
}

class _ScriptedDatasource extends MariaDbDatasource with _ScriptedCommands {
  _ScriptedDatasource({Set<String> failing = const {}}) {
    this.failing = failing;
  }
}

void main() {
  group('TomDbType.of conversions', () {
    test('TomDbInt parses an integer string', () {
      expect(TomDbInt.of('42').get(), 42);
    });

    test('TomDbDouble parses a double string', () {
      expect(TomDbDouble.of('1.5').get(), 1.5);
    });

    test('TomDbBool parses a boolean string', () {
      expect(TomDbBool.of('true').get(), isTrue);
      expect(TomDbBool.of('false').get(), isFalse);
    });

    test('TomDbString wraps the value verbatim', () {
      expect(TomDbString.of('hello').get(), 'hello');
    });

    test('TomDbDateTime reads a stored instant back as UTC', () {
      // The column carries no zone and every instant this server writes is UTC,
      // so the reader supplies the zone the text omits. Parsing it as *local*
      // would make the value mean whatever the reading host's offset happens to
      // be — the same characters naming a different moment on each node.
      final read = TomDbDateTime.of('2026-01-02 03:04:05.000000').get()!;
      expect(read, DateTime.utc(2026, 1, 2, 3, 4, 5));
      expect(read.isUtc, isTrue);
    });

    test('TomDbDateTime treats an empty column as absent', () {
      // The driver reports a NULL instant as either null or '' depending on the
      // row mapper; `DateTime.parse('')` would throw on the second shape.
      expect(TomDbDateTime.of('').get(), isNull);
    });

    test('a null string yields a box holding null', () {
      expect(TomDbInt.of(null).get(), isNull);
      expect(TomDbDouble.of(null).get(), isNull);
      expect(TomDbBool.of(null).get(), isNull);
      expect(TomDbString.of(null).get(), isNull);
      expect(TomDbDateTime.of(null).get(), isNull);
    });
  });

  group('TomStandardSqlDialect literals', () {
    final d = TomStandardSqlDialect();

    test('text is single-quoted', () {
      expect(d.text('abc'), "'abc'");
    });

    test('intOp / doubleOp / boolOp are bare', () {
      expect(d.intOp(7), '7');
      expect(d.doubleOp(1.5), '1.5');
      expect(d.boolOp(true), 'true');
    });

    test('nullOp renders NULL', () {
      expect(d.nullOp(), 'NULL');
    });

    test('p renders a bound-parameter placeholder', () {
      expect(d.p('userId'), ':userId');
    });

    test('dateTimeOp is a quoted UTC DATETIME(6) literal', () {
      // Not ISO-8601: a `T` separator and a trailing `Z` are both rejected by a
      // DATETIME column (error 1292), so the ISO rendering could not carry a
      // UTC instant into generated SQL at all.
      expect(
        d.dateTimeOp(DateTime.utc(2026, 1, 2, 3, 4, 5)),
        "'2026-01-02 03:04:05.000000'",
      );
    });

    test('dateTimeOp renders a local value as the instant it names', () {
      // Whatever zone the emitting node is in, the literal is the moment — not
      // that node's wall-clock reading of it.
      final local = DateTime.utc(2026, 1, 2, 3, 4, 5).toLocal();
      expect(d.dateTimeOp(local), "'2026-01-02 03:04:05.000000'");
    });

    test('dateOp is a fixed-width ISO date', () {
      // Every component is padded, so the literal is the same length whatever
      // the date. MariaDB accepts the ragged form too, which is why this went
      // unnoticed — but a fixed width is what makes generated SQL comparable as
      // text, and it is the one spelling both date renderers now share.
      expect(d.dateOp(DateTime(2026, 1, 2)), "'2026-01-02'");
      expect(d.dateOp(DateTime(2026, 12, 31)), "'2026-12-31'");

      // The year is padded for the same reason, not because such a date is
      // expected: MariaDB's DATE range starts at 1000-01-01, so a three-digit
      // year is unstorable anyway. Padding it is what lets the dartdoc say
      // `YYYY-MM-DD` without qualification.
      expect(d.dateOp(DateTime(7, 1, 2)), "'0007-01-02'");
    });
  });

  group('TomStandardSqlDialect.objectOp dispatch', () {
    final d = TomStandardSqlDialect();

    test('dispatches on runtime type', () {
      expect(d.objectOp(null), 'NULL');
      expect(d.objectOp('x'), "'x'");
      expect(d.objectOp(3), '3');
      expect(d.objectOp(2.5), '2.5');
      expect(d.objectOp(false), 'false');
    });

    test('an iterable becomes a comma-separated list of literals', () {
      // Regression: iterableOp previously appended the separator only on the
      // first element, producing e.g. "1,23" instead of "1,2,3".
      expect(d.objectOp([1, 2, 3]), '1,2,3');
      expect(d.objectOp(['a', 'b']), "'a','b'");
      expect(d.iterableOp([1, 2, 3]), '1,2,3');
    });

    test('a single-element iterable has no trailing separator', () {
      expect(d.iterableOp([1]), '1');
    });

    test('an empty iterable renders empty', () {
      expect(d.iterableOp([]), '');
    });
  });

  group('TomStandardSqlDialect predicates', () {
    final d = TomStandardSqlDialect();
    final a = _Literal<TomDbInt>('a');
    final b = _Literal<TomDbInt>('b');

    test('comparisons render the SQL operator', () {
      expect(d.eq(a, b), 'a = b');
      expect(d.neq(a, b), 'a <> b');
      expect(d.lt(a, b), 'a < b');
      expect(d.lte(a, b), 'a <= b');
      expect(d.gt(a, b), 'a > b');
      expect(d.gte(a, b), 'a >= b');
    });

    test('isNull / isNotNull', () {
      expect(d.isNull(a), 'a IS NULL');
      expect(d.isNotNull(a), 'a IS NOT NULL');
    });

    test('between uses the two limits', () {
      expect(
        d.between(a, [_Literal<TomDbInt>('1'), _Literal<TomDbInt>('9')]),
        'a BETWEEN 1 AND 9',
      );
    });

    test('isin joins the choices with commas', () {
      expect(
        d.isin(a, [_Literal<TomDbInt>('1'), _Literal<TomDbInt>('2')]),
        'a IN (1,2)',
      );
    });

    test('group wraps in parentheses', () {
      expect(d.group(a), '( a )');
    });

    test('not negates', () {
      expect(d.not(_Literal<TomDbBool>('p')), 'NOT p');
    });

    test('and / or join boolean operands', () {
      final p = _Literal<TomDbBool>('p');
      final q = _Literal<TomDbBool>('q');
      expect(d.and([p, q]), 'p AND q');
      expect(d.or([p, q]), 'p OR q');
    });

    test('like / notLike / regexp', () {
      final t = _Literal<TomDbString>('t');
      final pat = _Literal<TomDbString>('pat');
      expect(d.like(t, pat), 't LIKE pat');
      expect(d.notLike(t, pat), 't NOT LIKE pat');
      expect(d.regexp(t, pat), 't REGEXP pat');
    });
  });

  group('TomOperator base behaviour', () {
    test('captures its SQL return type at construction', () {
      expect(_Literal<TomDbBool>('x').returnType, TomDbBool);
      expect(_Literal<TomDbInt>('x').returnType, TomDbInt);
    });

    test('getParameters is empty by default', () {
      expect(
        _Literal<TomDbInt>('x').getParameters(TomStandardSqlDialect()),
        isEmpty,
      );
    });

    test('getFields reports referenced fields', () {
      expect(
        _Literal<TomDbInt>(
          'x',
          fields: {'col'},
        ).getFields(TomStandardSqlDialect()),
        {'col'},
      );
    });
  });

  // The query-generation clause renderers were extracted from
  // TomSelect/TomCount/TomDelete's generateQuery into pure helpers so the
  // keyword logic can be asserted without a reflected entity (this package's
  // test suite does not bootstrap reflection). generateQuery delegates to these,
  // so the integration behaviour is covered transitively.
  group('TomGeneratedQuery SQL clause rendering', () {
    test('distinctPrefix renders "DISTINCT " only when distinct', () {
      expect(TomGeneratedQuery.distinctPrefix(true), 'DISTINCT ');
      expect(TomGeneratedQuery.distinctPrefix(false), '');
    });

    test('limitClause uses MariaDB "LIMIT n", not Informix "FIRST n"', () {
      expect(TomGeneratedQuery.limitClause(5), ' LIMIT 5');
      expect(TomGeneratedQuery.limitClause(0), '');
      expect(TomGeneratedQuery.limitClause(-1), '');
    });

    test('limitClause renders a row window as "LIMIT n OFFSET m"', () {
      expect(TomGeneratedQuery.limitClause(5, 10), ' LIMIT 5 OFFSET 10');
      // Offset 0 is the first page: no OFFSET term at all.
      expect(TomGeneratedQuery.limitClause(5, 0), ' LIMIT 5');
    });

    test('limitClause rejects a window MariaDB cannot express', () {
      // No bare OFFSET in the LIMIT grammar, so a skip without a cap would be
      // silently dropped.
      expect(
        () => TomGeneratedQuery.limitClause(0, 10),
        throwsA(isA<TomQuerySyntaxException>()),
      );
      expect(
        () => TomGeneratedQuery.limitClause(5, -1),
        throwsA(isA<TomQuerySyntaxException>()),
      );
    });

    test('orderByClause uses "ASC"/"DESC", not "ASCENDING"/"DESCENDING"', () {
      expect(
        TomGeneratedQuery.orderByClause(
          TomSortField.allOf(const [
            't.a',
            't.b',
          ], direction: TomSortDirection.descending),
        ),
        ' ORDER BY t.a DESC,t.b DESC',
      );
      expect(
        TomGeneratedQuery.orderByClause(const [TomSortField.asc('t.a')]),
        ' ORDER BY t.a ASC',
      );
      expect(TomGeneratedQuery.orderByClause(const []), '');
    });

    test('orderByClause gives every term its own direction', () {
      expect(
        TomGeneratedQuery.orderByClause(const [
          TomSortField.desc('t.priority'),
          TomSortField.asc('t.due_date'),
        ]),
        ' ORDER BY t.priority DESC,t.due_date ASC',
      );
    });

    test(
      'countProjection emits a valid COUNT(DISTINCT ...), never DISTINCT(*)',
      () {
        expect(TomGeneratedQuery.countProjection(false, []), 'COUNT(*)');
        expect(
          TomGeneratedQuery.countProjection(true, ['u.id', 'u.name']),
          'COUNT(DISTINCT u.id, u.name)',
        );
        // No columns to distinguish on -> falls back to COUNT(*), not the invalid
        // COUNT(DISTINCT(*)).
        expect(TomGeneratedQuery.countProjection(true, []), 'COUNT(*)');
      },
    );
  });

  group('MariadbPreparedStatement.buildPositionalParameters', () {
    test('binds values raw, in placeholder order', () {
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['name', 'age'],
        {'name': 'John', 'age': 42},
      );
      expect(bound, ['John', 42]);
    });

    // MariaDB has no native boolean (`BOOLEAN` = `TINYINT(1)`); the
    // driver serializes a bound Dart `bool` as the string 'true'/'false', which
    // the server rejects for an integer column ("Incorrect integer value:
    // 'false'", error 1366). The bind boundary translates bool -> 1/0.
    test('binds a Dart bool as its MariaDB integer encoding (1/0)', () {
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['active', 'archived'],
        {'active': true, 'archived': false},
      );
      expect(bound, [1, 0]);
    });

    test('binds a TomDbType-boxed bool as 1/0 too', () {
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['flag'],
        {'flag': TomDbBool(false)},
      );
      expect(bound, [0]);
    });

    test('a null param stays null (binds SQL NULL, not the string "NULL")', () {
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['maybe'],
        {'maybe': null},
      );
      expect(bound, [null]);
      expect(bound.first, isNot('NULL'));
    });

    test('a string keeps its exact characters with no surrounding quotes', () {
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['name'],
        {'name': "O'Brien"},
      );
      // Raw, not the objectOp-rendered "'O''Brien'" SQL literal.
      expect(bound, ["O'Brien"]);
    });

    test('null params yields an empty list', () {
      expect(
        MariadbPreparedStatement.buildPositionalParameters(['x'], null),
        isEmpty,
      );
    });

    test('a TomDbType box binds its primitive, not its toString', () {
      // A column's toDbConverter produces a boxed SQL value (e.g. an enum
      // mapped to TomDbString); the driver only accepts primitives. Binding
      // the box raw would marshal "TomDbType TomDbString full" and the server
      // would truncate it against the ENUM column (error 1265).
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['access', 'count'],
        {'access': TomDbString('full'), 'count': TomDbInt(3)},
      );
      expect(bound, ['full', 3]);
      expect(bound.first, isA<String>());
    });

    test('a TomDbType box holding null binds SQL null', () {
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['maybe'],
        {'maybe': TomDbString(null)},
      );
      expect(bound, [null]);
    });

    // The bind boundary is where an entity column meets the instant convention
    // (`datasources/sql_instant.dart`). A reflected `@TomDbColumn<DateTime?,
    // TomDbDateTime>` field names no conversion of its own, so the data source
    // applies the convention on its behalf: what reaches the driver is the UTC
    // `DATETIME(6)` text, identical on every node.
    //
    // Text rather than a converted `DateTime`, for two reasons. The driver
    // serializes a bound `DateTime` through `toString()`, which for a UTC value
    // appends `Z` — a suffix MariaDB rejects outright ("Incorrect datetime
    // value", error 1292). And a `toLocal()` conversion, which does avoid the
    // suffix, stores *the writing node's wall clock*: it round-trips on that
    // node and means a different moment on every other one.
    test('a UTC DateTime binds as its UTC DATETIME(6) text', () {
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['created_at'],
        {'created_at': DateTime.utc(2000, 1, 1, 12)},
      );
      expect(bound.single, '2000-01-01 12:00:00.000000');
    });

    test('a local DateTime binds as the instant it names, not its face', () {
      // The property that makes the column an instant: the characters stored
      // depend on the moment alone, so a node in any zone binding the same
      // moment leaves the same row behind.
      final local = DateTime.utc(2000, 1, 1, 12).toLocal();
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['created_at'],
        {'created_at': local},
      );
      expect(bound.single, '2000-01-01 12:00:00.000000');
    });

    test('a TomDbDateTime box binds the same text as a bare DateTime', () {
      // The path a reflected column actually takes: its toDbConverter hands the
      // datasource a box, which must not change what is stored.
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['created_at'],
        {'created_at': TomDbDateTime(DateTime.utc(2000, 1, 1, 12))},
      );
      expect(bound.single, '2000-01-01 12:00:00.000000');
    });
  });

  group('MariaDbDatasource.toPositionalStatement (RCA5)', () {
    // The MySQL binary protocol binds positional `?` placeholders. The
    // datasource translates the generated `:name` SQL to that form. A naive
    // per-name `replaceAll(":$p", "?")` corrupts a placeholder that is a prefix
    // of another and collapses repeated placeholders into one slot; a
    // whole-identifier scan in occurrence order fixes both.

    test(
      'a placeholder that prefixes another is not corrupted (:id vs :idx)',
      () {
        final (sql, params) = MariaDbDatasource.toPositionalStatement(
          'a = :id AND b = :idx',
        );
        // replaceAll(":id","?") would turn ":idx" into "?x"; the tokeniser keeps
        // each whole identifier, so both become independent `?` slots.
        expect(sql, 'a = ? AND b = ?');
        expect(params, ['id', 'idx']);
      },
    );

    test(
      'a repeated placeholder gets one `?` slot (and entry) per occurrence',
      () {
        final (sql, params) = MariaDbDatasource.toPositionalStatement(
          'x = :v OR y = :v',
        );
        // Two `?` slots need two bind entries; a single collapsed slot would
        // desynchronise every following positional value.
        expect(sql, 'x = ? OR y = ?');
        expect(params, ['v', 'v']);
      },
    );

    test('names are returned in textual `?` order, not declaration order', () {
      final (sql, params) = MariaDbDatasource.toPositionalStatement(
        'b = :second AND a = :first',
      );
      expect(sql, 'b = ? AND a = ?');
      expect(params, ['second', 'first']);
    });

    test('a colon inside a time/date literal is not a placeholder', () {
      // `:` followed by a digit (03:04:05) is not an identifier start, so the
      // scan leaves inlined temporal literals untouched.
      const withTime = "created > '2026-01-02T03:04:05'";
      final (sql, params) = MariaDbDatasource.toPositionalStatement(withTime);
      expect(sql, withTime);
      expect(params, isEmpty);
    });

    test('a statement with no placeholders is returned unchanged', () {
      final (sql, params) = MariaDbDatasource.toPositionalStatement(
        'SELECT * FROM tasks',
      );
      expect(sql, 'SELECT * FROM tasks');
      expect(params, isEmpty);
    });

    test('a `:name`-looking substring inside a string literal is not a slot', () {
      // RCC6: a bound :p ANDed with an inlined 'x:y' literal must yield exactly
      // one `?`; the `:y` inside the quotes is literal text, not a placeholder.
      final (sql, params) = MariaDbDatasource.toPositionalStatement(
        "a = 'x:y' AND b = :p",
      );
      expect(sql, "a = 'x:y' AND b = ?");
      expect(params, ['p']);
    });

    test('a doubled-quote escape keeps the scan inside the literal', () {
      // 'x:y''z:w' is one literal (the '' is an escaped quote), so neither
      // `:y` nor `:w` is a placeholder — only the trailing bound :p is.
      final (sql, params) = MariaDbDatasource.toPositionalStatement(
        "a = 'x:y''z:w' AND b = :p",
      );
      expect(sql, "a = 'x:y''z:w' AND b = ?");
      expect(params, ['p']);
    });

    test('a backslash escape inside a literal is honoured (MariaDB default)', () {
      // The dialect escapes embedded quotes/backslashes; a `\\'` sequence keeps
      // the scan inside the literal so the following `:z` stays literal text.
      final (sql, params) = MariaDbDatasource.toPositionalStatement(
        "a = 'x\\':z' AND b = :p",
      );
      expect(sql, "a = 'x\\':z' AND b = ?");
      expect(params, ['p']);
    });

    test(
      'a `:name`-looking substring inside a double-quoted literal is safe',
      () {
        final (sql, params) = MariaDbDatasource.toPositionalStatement(
          'a = "x:y" AND b = :p',
        );
        expect(sql, 'a = "x:y" AND b = ?');
        expect(params, ['p']);
      },
    );

    test('a `:name`-looking substring inside a backtick identifier is safe '
        '(RCB10)', () {
      // A bound :p next to a `weird:col` backtick identifier must yield exactly
      // one `?`; the `:col` inside the backticks is a quoted identifier, not a
      // placeholder.
      final (sql, params) = MariaDbDatasource.toPositionalStatement(
        'SELECT `weird:col` FROM t WHERE b = :p',
      );
      expect(sql, 'SELECT `weird:col` FROM t WHERE b = ?');
      expect(params, ['p']);
    });

    test('a doubled backtick escapes a literal backtick inside an identifier '
        '(RCB10)', () {
      // ``a`` `:x` `` is one identifier (the `` `` `` is an escaped backtick), so
      // `:x` never leaves the identifier — only the trailing bound :p is a slot.
      final (sql, params) = MariaDbDatasource.toPositionalStatement(
        'SELECT `a``:x` FROM t WHERE b = :p',
      );
      expect(sql, 'SELECT `a``:x` FROM t WHERE b = ?');
      expect(params, ['p']);
    });

    test('a backslash is a literal character inside a backtick identifier, not '
        'an escape (RCB10)', () {
      // Distinguishes the backtick rule from the string-literal rule: under
      // string-literal escaping the `\` before the closing backtick would
      // escape it and swallow the rest of the SQL (zero slots). Backtick
      // identifiers have no backslash escaping, so the backtick still closes and
      // the following bound :p is the sole `?`.
      final (sql, params) = MariaDbDatasource.toPositionalStatement(
        r'SELECT `a\` FROM t WHERE b = :p',
      );
      expect(sql, r'SELECT `a\` FROM t WHERE b = ?');
      expect(params, ['p']);
    });
  });

  group('SqlPlaceholderScan.extractNames (RCC6, shared with crud_repository)', () {
    test('extractNames mirrors toPositional and skips literal content', () {
      // crud_repository._extractPlaceholderNames delegates here, so raw
      // statements prepared by the repository inherit the same quote-aware
      // tokenisation as the datasource's positional rewrite.
      expect(
        SqlPlaceholderScan.extractNames("a = 'x:y' AND b = :p OR c = :q"),
        ['p', 'q'],
      );
    });

    test('extractNames returns repeats in textual order', () {
      expect(SqlPlaceholderScan.extractNames('x = :v OR y = :v'), ['v', 'v']);
    });

    test('extractNames skips a `:name`-looking backtick identifier (RCB10)', () {
      // The repository's raw-bind path inherits the same backtick awareness as
      // the datasource rewrite: `weird:col` is a quoted identifier, so only the
      // real bound :p is extracted.
      expect(SqlPlaceholderScan.extractNames('`weird:col` = :p'), ['p']);
    });
  });

  group('MariadbPreparedStatement.normalizeGeneratedId', () {
    // crud_repository.save reads a freshly inserted row's surrogate key from
    // the insert's own result (lastInsertID), not a follow-up
    // SELECT LAST_INSERT_ID() that can land on a different connection and
    // return 0. The driver reports 0 for "no generated key", which must surface
    // as null so save falls back rather than re-reading row id 0.
    test('a real AUTO_INCREMENT value passes through as an int', () {
      expect(
        MariadbPreparedStatement.normalizeGeneratedId(BigInt.from(61)),
        61,
      );
    });

    test('the 0 sentinel (no generated key) maps to null', () {
      expect(
        MariadbPreparedStatement.normalizeGeneratedId(BigInt.zero),
        isNull,
      );
    });
  });

  group('isLostConnectionFailure (the prepared-statement retry decision)', () {
    // MariadbPreparedStatement.execute retries once, on a fresh connection,
    // when _execute raises MariadbPreparedStatementException. Which failures
    // earn that used to be decided by "$e".contains("connection closed") —
    // the wording of a third-party toString, which no contract holds still.
    //
    // The driver gives nothing better to match on directly: it reports a link
    // it already knows is gone as a bare MySQLClientException with no error
    // code, and raises that same type for a protocol desync, a second BEGIN and
    // a failed handshake. So the type alone is not the answer either — the
    // question is answered by the link state, which every one of those
    // "connection closed" throws sits behind, and which the driver exposes as
    // documented API.
    //
    // The statement itself cannot be built here (PreparedStmt's constructor is
    // private, so it needs a live connection), which is exactly why the
    // decision lives in a predicate and not in the mapper closure.

    test('a link the driver reports as down is retried', () {
      expect(
        isLostConnectionFailure(
          MySQLClientException(
            'Can not execute prepared stmt: '
            'connection closed',
          ),
          connected: false,
        ),
        isTrue,
      );
    });

    test('the wording of the message plays no part', () {
      // The point of the change: a driver that renames its message, or a
      // failure that never mentions a connection at all, is classified the
      // same way — by the link, not by the prose.
      expect(
        isLostConnectionFailure(
          MySQLClientException('socket gone west'),
          connected: false,
        ),
        isTrue,
      );
      expect(
        isLostConnectionFailure(
          MySQLClientException('connection closed'),
          connected: true,
        ),
        isFalse,
      );
    });

    test('a failure on a live link is not retried', () {
      // MySQLClientException is also how the driver reports a protocol desync
      // and a double BEGIN. Reconnecting cannot fix those, and retrying
      // re-runs the statement — so matching the type alone would be a
      // regression, not a repair.
      expect(
        isLostConnectionFailure(
          MySQLProtocolException('bad packet'),
          connected: true,
        ),
        isFalse,
      );
      expect(
        isLostConnectionFailure(
          MySQLClientException('Already in transaction'),
          connected: true,
        ),
        isFalse,
      );
    });

    test('a server answer is never retried, even with the link down', () {
      // The server received the statement and rejected it. That verdict stands
      // however the link looks afterwards, and a retry would re-run a statement
      // the server has already judged.
      expect(
        isLostConnectionFailure(
          MySQLServerException('duplicate key', 1062),
          connected: false,
        ),
        isFalse,
      );
    });

    test('the server answer is found through the wrapping', () {
      // The driver's exception reaches the decision inside this layer's own
      // exception, so a check that only read the top of the chain would retry a
      // rejected statement whenever the link had since dropped.
      expect(
        isLostConnectionFailure(
          MariadbDatasourceException(
            'error.failed-to-execute.exception',
            'wrapped',
            rootException: MySQLServerException('duplicate key', 1062),
          ),
          connected: false,
        ),
        isFalse,
      );
      expect(
        isLostConnectionFailure(
          MariadbDatasourceException(
            'error.failed-to-execute.exception',
            'wrapped',
            rootException: MySQLClientException('connection closed'),
          ),
          connected: false,
        ),
        isTrue,
      );
    });

    test('an unrecognised failure follows the link state', () {
      // Nothing in the chain says the server answered, so the link decides.
      expect(
        isLostConnectionFailure(
          const SocketException('reset by peer'),
          connected: false,
        ),
        isTrue,
      );
      expect(isLostConnectionFailure(null, connected: false), isTrue);
      expect(
        isLostConnectionFailure(
          StateError('nothing to do with it'),
          connected: true,
        ),
        isFalse,
      );
    });
  });

  // Driver discovery (createDatasourceOf resolving mariadb/mariadb_xa,
  // the unknown-type and duplicate-driver guards) is deferred: it scans
  // tomReflector.annotatedClasses, which raises "Reflection has not been
  // initialized" in this suite (no generated reflection is bootstrapped here).
  // That belongs to an integration-level test with reflection wired up.

  group('TomDataSourceInfo.initializeDatasourceInfo config guard', () {
    setUp(() => TomDataSourceInfo.datasources.clear());
    tearDown(() => TomDataSourceInfo.datasources.clear());

    test(
      'a Map<String, Object?> entry is processed, not silently skipped',
      () async {
        // delegateTo aliasing exercises the registration path without opening a
        // real connection.
        final base = TomDataSourceInfo('base', <String, dynamic>{});
        TomDataSourceInfo.datasources['base'] = base;
        final config = <String, dynamic>{
          'alias': <String, Object?>{'delegateTo': 'base'},
        };
        final result = await TomDataSourceInfo.initializeDatasourceInfo(config);
        expect(result, 1);
        // A `Map<String, Object?>` entry is not a `Map<String, Object>`, so the
        // initializer has to match on the nullable-value type or an alias
        // written that way is silently skipped and never registered.
        expect(TomDataSourceInfo.getDataSourceInfo('alias'), same(base));
      },
    );

    test(
      'a YamlMap-style Map<dynamic, dynamic> entry is also processed',
      () async {
        final base = TomDataSourceInfo('base2', <String, dynamic>{});
        TomDataSourceInfo.datasources['base2'] = base;
        final config = <String, dynamic>{
          'alias2': <dynamic, dynamic>{'delegateTo': 'base2'},
        };
        await TomDataSourceInfo.initializeDatasourceInfo(config);
        expect(TomDataSourceInfo.getDataSourceInfo('alias2'), same(base));
      },
    );

    test('a non-map entry is ignored', () async {
      final result = await TomDataSourceInfo.initializeDatasourceInfo(
        <String, dynamic>{'scalar': 'not-a-map'},
      );
      expect(result, 1);
      expect(TomDataSourceInfo.getDataSourceInfo('scalar'), isNull);
    });
  });

  group('MariaDbDatasource.parsePort / normalizePort (G-DB-3)', () {
    // The datasource binds `port` to an int field, but application config may
    // express it either way — an env substitution (`port: ${DB_PORT:3306}`)
    // always yields a string. parsePort folds a string port to an int so both
    // forms work; normalizePort applies it at the config-binding boundary.
    test('an int port passes through verbatim', () {
      expect(MariaDbDatasource.parsePort(3306), 3306);
    });

    test('a string port is parsed to an int', () {
      expect(MariaDbDatasource.parsePort('3308'), 3308);
    });

    test('a whitespace-padded string port is trimmed and parsed', () {
      expect(MariaDbDatasource.parsePort('  3307 '), 3307);
    });

    test('an unparsable string port throws', () {
      expect(
        () => MariaDbDatasource.parsePort('not-a-port'),
        throwsA(isA<MariadbDatasourceException>()),
      );
    });

    test('a non-int/non-string port throws', () {
      expect(
        () => MariaDbDatasource.parsePort(3306.5),
        throwsA(isA<MariadbDatasourceException>()),
      );
    });

    test('a null port throws', () {
      expect(
        () => MariaDbDatasource.parsePort(null),
        throwsA(isA<MariadbDatasourceException>()),
      );
    });

    test('normalizePort folds a string port to an int, leaving other keys', () {
      final normalized = MariaDbDatasource.normalizePort(<String, dynamic>{
        'host': 'localhost',
        'port': '3308',
      });
      expect(normalized['port'], 3308);
      expect(normalized['host'], 'localhost');
    });

    test('normalizePort leaves an int port unchanged', () {
      final settings = <String, dynamic>{'port': 3306};
      final normalized = MariaDbDatasource.normalizePort(settings);
      expect(normalized['port'], 3306);
    });

    test('normalizePort leaves an absent port unchanged', () {
      final settings = <String, dynamic>{'host': 'localhost'};
      final normalized = MariaDbDatasource.normalizePort(settings);
      expect(normalized.containsKey('port'), isFalse);
    });
  });

  // A branch id is set on the way *into* `XA START` and is what the guard in
  // `startTransaction` refuses a second transaction on. So every path that can
  // end a branch has to put it back, and each one that forgets wedges the data
  // source permanently: the next start throws "There is already an active
  // transaction" and there is nothing a caller can do about it, because the
  // branch it would have to roll back never began.
  //
  // Each of the four exits is therefore driven here with a start that actually
  // succeeded, and the assertion is always the same one — a following start is
  // allowed. The one exit that must *not* clear is a successful end, since
  // `commit` still needs the id; that is asserted through the SQL, which is
  // where a cleared id would surface as `XA COMMIT null;`.
  group('MariaDb transaction lifecycle: the state each exit leaves', () {
    test('a failed start clears the branch id it had already set', () async {
      final ds = _ScriptedXADatasource(failing: {'XA START'});
      expect(await ds.startTransaction(), isFalse);
      // The id is assigned before the command is issued, so a failure that
      // leaves it set locks out every later transaction. Recovering by calling
      // `rollback` is not available: there is no branch to roll back, and a
      // caller that got `false` has been told the transaction never began.
      expect(await ds.startTransaction(), isFalse);
      expect(ds.commands, hasLength(2));
      expect(ds.commands.every((c) => c.startsWith('XA START ')), isTrue);
    });

    test('a failed rollback clears the branch id', () async {
      final ds = _ScriptedXADatasource(failing: {'XA ROLLBACK'});
      expect(await ds.startTransaction(), isTrue);
      await ds.rollback();
      expect(await ds.startTransaction(), isTrue);
      expect(ds.commands[1], startsWith('XA ROLLBACK '));
      expect(ds.commands[1], isNot(contains('null')));
    });

    test('a failed endTransaction clears the branch id', () async {
      final ds = _ScriptedXADatasource(failing: {'XA END'});
      expect(await ds.startTransaction(), isTrue);
      expect(await ds.endTransaction(), isFalse);
      // The branch cannot be committed after a failed prepare, so holding the
      // id would strand the data source on a transaction with no future.
      expect(await ds.startTransaction(), isTrue);
    });

    test('a failed commit clears the branch id', () async {
      final ds = _ScriptedXADatasource(failing: {'XA COMMIT'});
      expect(await ds.startTransaction(), isTrue);
      expect(await ds.endTransaction(), isTrue);
      expect(await ds.commit(), isFalse);
      expect(await ds.startTransaction(), isTrue);
    });

    test(
      'a successful end keeps the branch id, because commit needs it',
      () async {
        // The counterweight to the four clears above: end is the only exit that
        // hands the branch on rather than closing it. Read through the SQL,
        // because `_txId` has no accessor -- an id cleared here reaches the
        // driver as the literal `XA COMMIT null;`, which MariaDB rejects and
        // which a test asserting only the return value would not notice.
        final ds = _ScriptedXADatasource();
        expect(await ds.startTransaction(), isTrue);
        final branch = ds.commands.single.substring('XA START '.length);
        expect(branch, isNot(contains('null')));
        expect(await ds.endTransaction(), isTrue);
        expect(await ds.commit(), isTrue);
        expect(ds.commands.last, 'XA COMMIT $branch');
      },
    );

    test('the non-XA sibling is not wedged by a failed start either', () async {
      // The plain data source reaches the same contract by a different route:
      // it raises its in-transaction flag only *after* the command succeeds, so
      // there is nothing to undo on the failure path. Pinned here because the
      // two classes share a guard whose message is the symptom of the XA bug,
      // and a reader of that fix will ask whether the sibling has it too.
      final ds = _ScriptedDatasource(failing: {'START TRANSACTION'});
      expect(await ds.startTransaction(), isFalse);
      expect(await ds.startTransaction(), isFalse);
      expect(ds.commands, hasLength(2));
    });

    test('the plain end sends nothing and reports success', () async {
      // The counterpart to the XA end above, and the reason that method is
      // empty rather than unfinished: a one-phase `COMMIT` has no prepare step,
      // so there is no statement for end to issue, and no per-transaction state
      // left to release either — `commit` and `rollback` clear the
      // in-transaction flag themselves, and the coordinator always calls one of
      // them first.
      //
      // Asserting the command list is the half that matters. The return value
      // alone cannot tell an intentional no-op from a forgotten body, whereas a
      // statement appearing here would show up immediately.
      final ds = _ScriptedDatasource();
      expect(await ds.startTransaction(), isTrue);
      expect(await ds.endTransaction(), isTrue);
      expect(ds.commands, ['START TRANSACTION;']);
      expect(await ds.commit(), isTrue);
      expect(ds.commands, ['START TRANSACTION;', 'COMMIT;']);
    });

    test('the plain end succeeds even with no transaction open', () async {
      // "Always succeeds" is not a formality: the coordinator ands every
      // participant's end result into the outcome, so a `false` here would fail
      // a transaction that had in fact completed. The no-open-transaction case
      // is reachable today — a participant whose start returned `false` is
      // enlisted anyway (tcincb113), and still gets ended.
      final ds = _ScriptedDatasource(failing: {'START TRANSACTION'});
      expect(await ds.startTransaction(), isFalse);
      expect(await ds.endTransaction(), isTrue);
      expect(ds.commands, ['START TRANSACTION;']);
    });
  });
}

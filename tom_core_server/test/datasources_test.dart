import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
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
    // As strict as the real driver, which refuses a multi-statement command
    // (see the 'one statement per call' group): a fake that accepted one would
    // let a lifecycle regress to the shape that desynchronised the connection.
    if (TomSqlLexer.splitStatements(command).length > 1) {
      throw StateError('more than one statement in one call: $command');
    }
    if (failing.any(command.startsWith)) {
      throw StateError('scripted failure for: $command');
    }
    return BigInt.zero;
  }
}

/// The branch id `XA START` named, read back out of the recorded SQL.
///
/// `_txId` is private and has no accessor, which is what makes the SQL the only
/// place a wrongly cleared id is observable — it arrives there as the literal
/// `null`.
/// A [TomLogOutput] that keeps every message instead of printing it, so a test
/// can assert on what a driver actually wrote.
class _CapturingLogOutput extends TomLogOutput {
  final List<String> messages = [];
  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) => messages.add(convertToString(message));
}

/// A transaction to hand a data source that is being driven directly.
///
/// The lifecycle methods take the transaction they are joining rather than
/// looking it up, so a test that calls one outside a coordinator drive still
/// has to produce one — and `TomTransaction`'s constructor is private, so the
/// manager is the only way to get one. Concluded by the caller where the test
/// cares; several of these never conclude, which is what `startTransaction`'s
/// get-or-create makes harmless.
TomTransaction _aTransaction({bool readOnly = false}) =>
    TomTransactionManager.startTransaction(readOnly).$1;

String _branchOf(_ScriptedCommands ds) {
  final start = ds.commands.firstWhere((c) => c.startsWith('XA START '));
  return start.substring('XA START '.length, start.length - 1);
}

class _ScriptedXADatasource extends MariaDbXADatasource with _ScriptedCommands {
  _ScriptedXADatasource({Set<String> failing = const {}}) {
    this.failing = failing;
    _describe(this);
  }
}

class _ScriptedDatasource extends MariaDbDatasource with _ScriptedCommands {
  _ScriptedDatasource({Set<String> failing = const {}}) {
    this.failing = failing;
    _describe(this);
  }
}

/// Gives a scripted data source the coordinates it would have had from
/// `initialize`, so everything derived from them reads as it would in service:
/// the participant id, and the XA branch id interpolated into the SQL.
void _describe(MariaDbDatasource ds) {
  ds.host = 'db';
  ds.port = 3306;
  ds.databaseName = 'app';
}

/// A never-opened data source that records any attempt to dial out.
///
/// The lifecycle rule is about what must *not* happen: an entry point reached
/// before the data source was opened has to refuse, not open a connection of
/// its own. Catching the exception alone cannot tell those two apart, because
/// an implicit open against the unconfigured `:-1` throws as well — so
/// [openConnection] is overridden to count the attempts and fail loudly rather
/// than touch the network.
class _NeverOpenedDatasource extends MariaDbDatasource {
  /// How many times something asked this data source to open a connection.
  int connectCalls = 0;

  @override
  Future<MySQLConnection> openConnection() async {
    connectCalls++;
    throw StateError('the data source dialled out');
  }
}

/// A stand-in [MySQLConnection] that reports a link state and records every
/// statement it is asked to run.
///
/// `MySQLConnection` cannot be constructed without a server — its constructor
/// is private and `createConnection` opens a socket — but it is a plain class,
/// so its interface can be implemented. That is what makes the pool's handling
/// of a dropped link reachable in a unit test: a connection can be told it is
/// down, and what the data source does next observed.
class _FakeConnection implements MySQLConnection {
  @override
  bool connected;

  /// Every query this link was asked to run, in order.
  final List<String> executed = [];

  /// Every statement this link was asked to compile, in order.
  final List<String> prepared = [];

  /// What [execute] reports as the affected-row count.
  final BigInt affectedRows;

  /// How many times this link was asked to close.
  int closeCalls = 0;

  /// Thrown by [close] when set; `null` closes cleanly.
  final Object? closeFailure;

  /// What a statement compiled by [prepare] reports as its affected-row count.
  BigInt preparedAffectedRows = BigInt.zero;

  /// When set, the next prepared statement executed on this link finds the
  /// link gone: it takes the link down and fails the way the driver does.
  bool dropOnNextPreparedExecution = false;

  /// Completes the next [execute] only when this completes, when set — so a
  /// test can hold a statement in flight.
  Completer<void>? hold;

  _FakeConnection({
    required this.connected,
    BigInt? affectedRows,
    this.closeFailure,
  }) : affectedRows = affectedRows ?? BigInt.zero;

  @override
  Future<void> close() async {
    closeCalls++;
    connected = false;
    if (closeFailure != null) throw closeFailure!;
  }

  @override
  Future<IResultSet> execute(
    String query, [
    Map<String, dynamic>? params,
    bool iterable = false,
  ]) async {
    executed.add(query);
    final waitFor = hold;
    if (waitFor != null) {
      hold = null;
      await waitFor.future;
    }
    return _FakeResultSet(affectedRows);
  }

  /// Every statement handle this link handed out, in order.
  final List<_FakePreparedStmt> statements = [];

  @override
  Future<PreparedStmt> prepare(String query, [bool iterable = false]) async {
    prepared.add(query);
    final stmt = _FakePreparedStmt(this, affectedRows: preparedAffectedRows);
    statements.add(stmt);
    return stmt;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A prepared-statement handle that runs on its [link], or fails the way one
/// does when the link beneath it has gone.
class _FakePreparedStmt implements PreparedStmt {
  /// The connection that prepared this handle.
  final _FakeConnection link;

  /// What the result set this handle produces reports as its row count.
  final BigInt affectedRows;

  /// How many times this handle was executed.
  int executions = 0;

  /// How many times this handle was deallocated.
  int deallocations = 0;

  _FakePreparedStmt(this.link, {BigInt? affectedRows})
    : affectedRows = affectedRows ?? BigInt.zero;

  @override
  int get numOfParams => 0;

  @override
  Future<IResultSet> execute(List<dynamic> params) async {
    executions++;
    if (link.dropOnNextPreparedExecution) {
      link.dropOnNextPreparedExecution = false;
      link.connected = false;
      throw MySQLClientException(
        'Can not execute prepared stmt: connection closed',
      );
    }
    return _FakeResultSet(affectedRows);
  }

  @override
  Future<void> deallocate() async {
    deallocations++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The parts of a result set these paths read: the affected-row count, the
/// generated key, and the (empty) rows a grouped projection maps.
class _FakeResultSet implements IResultSet {
  @override
  final BigInt affectedRows;

  _FakeResultSet(this.affectedRows);

  @override
  BigInt get lastInsertID => BigInt.zero;

  @override
  Iterable<ResultSetRow> get rows => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A data source whose pool opens stand-in connections, so which connection a
/// statement ran on is observable.
///
/// Connections are handed out from [queued] first, then made fresh and live.
class _PooledFakeDatasource extends MariaDbDatasource {
  /// Connections the pool receives next, in order.
  final List<_FakeConnection> queued;

  /// Every connection the pool opened, in order.
  final List<_FakeConnection> opened = [];

  _PooledFakeDatasource({List<_FakeConnection>? queued, int maxSize = 10})
    : queued = queued ?? [] {
    host = 'db';
    port = 3306;
    databaseName = 'app';
    poolMaxSize = maxSize;
  }

  @override
  Future<MySQLConnection> openConnection() async {
    final link = queued.isNotEmpty
        ? queued.removeAt(0)
        : _FakeConnection(connected: true, affectedRows: BigInt.two);
    opened.add(link);
    return link;
  }

  /// The connection opened first — the one [connect] opens.
  _FakeConnection get first => opened.first;
}

/// The XA driver over stand-in connections, as [_PooledFakeDatasource] is for
/// the plain one.
class _PooledXADatasource extends MariaDbXADatasource {
  final List<_FakeConnection> opened = [];

  _PooledXADatasource() {
    host = 'db';
    port = 3306;
    databaseName = 'app';
  }

  @override
  Future<MySQLConnection> openConnection() async {
    final link = _FakeConnection(connected: true);
    opened.add(link);
    return link;
  }
}

/// A query that renders fixed SQL, so [MariaDbDatasource.prepareStatement] can
/// be reached without the reflection-backed query builder.
///
/// Constructed over no types on purpose: the base class analyses persistence
/// annotations for each type it is given, and this query never gets far enough
/// to need them.
class _FixedQuery extends TomQuery {
  _FixedQuery() : super(const []);

  @override
  String generateQuery(TomStandardSqlDialect t) => 'SELECT 1';
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

  // The encoding every table that stores an instant shares, and
  // `doc/datasources.md` states it as a rule. Reached only through its callers
  // — the dialect's `dateTimeOp`, `TomDbDateTime.of`, the MariaDB bind
  // boundary, the scheduling stores — the convention itself would be asserted
  // nowhere, and a stated rule with no test of its own is the claim that goes
  // stale silently: every caller can be corrected into agreement with itself,
  // and not one of them is the rule.
  // The convention is only one convention while every read path uses it. Two
  // coexisted for a while -- the instant helpers reading UTC and a grouped-row
  // accessor reading the same text as local -- and the cost of that is the
  // shape a sampling test cannot catch: the same characters naming a moment
  // that differs by the machine's UTC offset, with no error and no type
  // difference. So the rule is read off the source.
  group('one convention: no read path parses column text itself', () {
    /// The files that materialise a **column value**: the data source module,
    /// which reads every row, and the grouped-row accessors, which are the one
    /// other place a stored value becomes a Dart `DateTime`.
    ///
    /// `query_sentence_compiler.dart` is deliberately *not* here, and its
    /// exclusion is checked rather than asserted (below): it parses literals a
    /// caller wrote on the way **into** SQL, which is the opposite direction,
    /// and its datetime literal requires a zone suffix.
    Iterable<File> readers() => [
      ...Directory('lib/src/tomserver/datasources')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
      File('lib/src/tomserver/object_persistence/grouped_query.dart'),
    ];

    test('only sql_instant.dart names DateTime.parse', () {
      final offenders = <String>[];
      for (final file in readers()) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Prose about the trap is the point of several of these files.
          if (line.trimLeft().startsWith('//')) continue;
          if (line.trimLeft().startsWith('///')) continue;
          if (!line.contains('DateTime.parse(')) continue;
          // The one implementation of the rule, which is where the suffix is
          // appended -- and the only place a bare parse is the right answer.
          if (file.path.endsWith('sql_instant.dart')) continue;
          offenders.add('${file.path}:${i + 1}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'a column value parsed outside `parseSqlInstant` is read as this '
            "node's local time, which is a second convention — see "
            '`datasources/sql_instant.dart`',
      );
    });

    // The reason the query-sentence compiler is out of scope above, held to
    // rather than trusted: its datetime literal carries its own zone, so the
    // `DateTime.parse` it performs is not a zone-less one. If the pattern ever
    // accepted a suffix-less token, this fails and the exclusion has to be
    // re-argued rather than silently covering a second convention.
    test('a query-sentence datetime literal must carry its zone', () {
      final source = File(
        'lib/src/tomserver/object_persistence/query_sentence_compiler.dart',
      ).readAsStringSync();
      final datetime = source.substring(
        source.indexOf("kind: 'datetime'"),
        source.indexOf("kind: 'date'"),
      );
      expect(
        datetime,
        contains(r'(Z|[+\-][0-9]{2}:[0-9]{2})$'),
        reason:
            'the datetime literal pattern no longer requires a zone suffix, so '
            'its DateTime.parse became a local read',
      );
    });
  });

  group('sqlInstant / parseSqlInstant (the one encoding of an instant)', () {
    test('renders UTC with six fractional digits', () {
      expect(
        sqlInstant(DateTime.utc(2026, 3, 1, 12, 30, 45, 123, 456)),
        '2026-03-01 12:30:45.123456',
      );
    });

    test('every field is zero-padded to a fixed width', () {
      // Fixed width is what keeps the text comparable in SQL as well as in
      // Dart, and the fractional part is a millisecond field and a microsecond
      // field written adjacently — three digits each, not one six-digit number.
      expect(
        sqlInstant(DateTime.utc(7, 1, 2, 3, 4, 5, 6, 7)),
        '0007-01-02 03:04:05.006007',
      );
    });

    test('a local value renders as the instant it names, not its reading', () {
      // Built from a UTC moment so the expectation holds in any zone: the two
      // denote one instant, so they must produce one string.
      final utc = DateTime.utc(2026, 3, 1, 12, 30, 45, 123, 456);
      expect(sqlInstant(utc.toLocal()), sqlInstant(utc));
    });

    test('the round trip is exact, and lands in UTC', () {
      final written = DateTime.utc(2026, 3, 1, 12, 30, 45, 123, 456);
      final read = parseSqlInstant(sqlInstant(written));
      expect(read, written);
      expect(read.isUtc, isTrue);
      // Microseconds survive — which is why a column holding an instant is
      // DATETIME(6). A plain DATETIME rounds them, moving the stored moment.
      expect(read.microsecond, 456);
    });

    test('a local value round-trips to the same moment, labelled UTC', () {
      final local = DateTime.utc(2026, 3, 1, 12, 30, 45).toLocal();
      final read = parseSqlInstant(sqlInstant(local));
      expect(read.isUtc, isTrue);
      expect(read.isAtSameMomentAs(local), isTrue);
    });

    test('column text alone parses local — appending the zone is the fix', () {
      // The trap this file exists for, pinned. `DateTime.==` compares `isUtc`
      // as well as the moment, so the naive read is unequal to what was written
      // in every zone but UTC; parseSqlInstant is equal in all of them.
      const text = '2026-03-01 12:30:45.123456';
      final written = DateTime.utc(2026, 3, 1, 12, 30, 45, 123, 456);
      expect(DateTime.parse(text).isUtc, isFalse);
      expect(parseSqlInstant(text), written);
    });

    test('a value already carrying the zone marker is not given a second', () {
      expect(
        parseSqlInstant('2026-03-01 12:30:45.123456Z'),
        DateTime.utc(2026, 3, 1, 12, 30, 45, 123, 456),
      );
    });

    test('surrounding whitespace is trimmed', () {
      expect(
        parseSqlInstant('  2026-03-01 12:30:45.123456  '),
        DateTime.utc(2026, 3, 1, 12, 30, 45, 123, 456),
      );
    });

    test('parseOptionalSqlInstant collapses null and empty to absent', () {
      // The driver reports a NULL instant as either shape depending on the row
      // mapper, and every caller has to collapse the two the same way.
      expect(parseOptionalSqlInstant(null), isNull);
      expect(parseOptionalSqlInstant(''), isNull);
      expect(
        parseOptionalSqlInstant('2026-03-01 12:30:45.123456'),
        DateTime.utc(2026, 3, 1, 12, 30, 45, 123, 456),
      );
    });
  });

  group('TomStandardSqlDialect literals', () {
    final d = TomStandardSqlDialect();

    test('text is single-quoted', () {
      expect(d.text('abc'), "'abc'");
    });

    test('a value cannot terminate its own literal', () {
      // `text` was a bare `"'$text'"`, so a value carrying a quote closed the
      // literal early and everything after it was parsed as SQL. This is the
      // shape that mattered: the tail is a second statement, not a fragment.
      expect(
        d.text("it's"),
        "'it''s'",
        reason: 'the doc/datasources.md sample',
      );
      expect(
        d.text("x'; DROP TABLE users; --"),
        "'x''; DROP TABLE users; --'",
        reason: 'the injected quote is doubled, so nothing escapes the literal',
      );
      expect(d.text(r'a\b'), r"'a\\b'");
      // Both replacements fire on the same value without interfering. They can
      // be written in either order — doubling a quote introduces no backslash
      // and escaping a backslash introduces no quote — so neither can re-escape
      // what the other produced. Worth pinning because the usual shape of this
      // pair *is* order-dependent, and a reader will assume this one is too.
      expect(d.text(r"a\'b"), r"'a\\''b'");
    });

    test('objectOp escapes the values it routes through text', () {
      // `objectOp` is the entry point the expression tree reaches by itself,
      // so escaping only `text` would leave the path that actually renders
      // user data unprotected.
      expect(d.objectOp("it's"), "'it''s'");
      expect(d.objectOp(["a'b", 1]), "'a''b',1");
      // Anything unrecognised is quoted via its `toString()`, and is escaped
      // on the way — the fallback is where an unforeseen type arrives.
      expect(d.objectOp(_Quoting()), "'it''s'");
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
      expect(d.like(t, pat), r"t LIKE pat ESCAPE '\\'");
      expect(d.notLike(t, pat), r"t NOT LIKE pat ESCAPE '\\'");
      expect(d.regexp(t, pat), 't REGEXP pat');
    });

    // `LIKE` is the one predicate whose right-hand operand is a small language
    // rather than a value, so a caller who means "contains the text the user
    // typed" has to say so. Binding does not help and is not meant to: it
    // makes the value safe, and a wildcard in a pattern is not unsafe.
    group('escapeLikePattern', () {
      test('escapes both wildcards', () {
        expect(d.escapeLikePattern('50% off'), r'50\% off');
        expect(d.escapeLikePattern('a_b'), r'a\_b');
      });

      test('escapes the escape character first', () {
        // Or a pattern that already contains one would consume the escape
        // this adds, and `a\%b` would still match any run of characters.
        expect(d.escapeLikePattern(r'a\%b'), r'a\\\%b');
      });

      test('leaves text with nothing to escape alone', () {
        expect(d.escapeLikePattern('plain text'), 'plain text');
      });

      test('escapes for the character the ESCAPE clause names', () {
        // The two read the same property, so a dialect that overrides it stays
        // consistent by construction rather than by being remembered.
        expect(
          d.like(_Literal<TomDbString>('col'), _Literal<TomDbString>(':p')),
          endsWith('ESCAPE ${d.text(d.likeEscapeCharacter)}'),
        );
        expect(d.escapeLikePattern('%'), startsWith(d.likeEscapeCharacter));
      });
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

    test('a leaf has no children', () {
      expect(_Literal<TomDbInt>('x').children, isEmpty);
    });
  });

  group('the expression tree can be walked', () {
    /// The column metadata a `DbCol` carries, built directly: the walk is the
    /// only route to it, so a test of the walk needs a node that has some.
    /// Constructing it here rather than resolving it keeps this suite free of
    /// reflection, which it does not bootstrap.
    TomColumnInformation columnInfo(String name, Type type) =>
        TomColumnInformation(
          tableType: Object,
          table: const TomDbTable(
            datasource: 'demo',
            table: 'demo_task',
            primaryKeyFields: ['id'],
          ),
          declaredType: type,
          declaredName: name,
          field: name,
        );

    /// `priority BETWEEN 1 AND 9 AND title = 'release'` — a container whose
    /// operands are themselves containers, which is the shape the walk has to
    /// be described for. `BETWEEN` carries its bounds as a *list*, so one node
    /// exercises both operand shapes at once.
    ({And predicate, IntCol priority, StringCol title}) nested() {
      final priority = IntCol(Object, 'priority', columnInfo('priority', int));
      final title = StringCol(Object, 'title', columnInfo('title', String));
      return (
        predicate: And([
          Between<TomDbInt>(priority, [IntegerLiteral(1), IntegerLiteral(9)]),
          Eq<TomDbString>(title, StringLiteral('release')),
        ]),
        priority: priority,
        title: title,
      );
    }

    /// Every node of [node]'s subtree, depth-first, [node] included.
    List<TomOperator> walk(TomOperator node) => [
      node,
      for (final child in node.children) ...walk(child),
    ];

    test('a container yields its operands, a list flattened into them', () {
      // The question the module had no answer to: what a walk sees at a
      // container whose operand is a `List<TomOperator>`. It sees the
      // elements, not the list as one child — so `AND` over two predicates has
      // two children and not one.
      final tree = nested();
      expect(tree.predicate.children, hasLength(2));
      expect(tree.predicate.children.map((c) => c.runtimeType.toString()), [
        'Between<TomDbInt>',
        'Eq<TomDbString>',
      ]);
    });

    test('a binary operator yields both operands, left to right', () {
      // `BETWEEN` is the node that carries one of each: an operator on the
      // left, a two-element list on the right. Its children are the three
      // nodes, in that order.
      final between = nested().predicate.children.first;
      expect(between.children.map((c) => c.runtimeType.toString()), [
        'IntCol',
        'IntegerLiteral',
        'IntegerLiteral',
      ]);
    });

    test('a column reference is a leaf, because its operand is a name', () {
      // The case that is easy to get wrong when reading the code: `DbCol`
      // extends the unary operator, but its operand is the column *name*, a
      // `String`. So it contributes no children and answers `getFields` for
      // itself instead.
      final tree = nested();
      expect(tree.priority.children, isEmpty);
      expect(tree.priority.getFields(TomStandardSqlDialect()), {
        'demo_task.priority',
      });
    });

    test('the walk reaches every node of the tree', () {
      final tree = nested();
      expect(walk(tree.predicate), hasLength(8));
      expect(walk(tree.predicate).whereType<DbCol>().map((c) => c.operant1), [
        'priority',
        'title',
      ]);
    });

    test('the walk is the way to a column\'s metadata; getFields is not', () {
      // Why the member exists at all. `getFields` answers with the *rendered*
      // fragment, which is what SQL needs and not enough for a layer deciding
      // whether a query touches a column the principal may not read — that
      // decision reads the column's declaration, and only the node holds it.
      final tree = nested();
      expect(tree.predicate.getFields(TomStandardSqlDialect()), {
        'demo_task.priority',
        'demo_task.title',
      });
      expect(
        walk(
          tree.predicate,
        ).whereType<DbCol>().map((c) => c.columnInformation.declaredType),
        [int, String],
      );
    });

    test('operandChildren builds children; it does not read them', () {
      // How the two members differ, which the module documented nowhere. The
      // getter is an instance member reporting a node's sub-expressions; the
      // static is the builder half — a container calls it once per constructor
      // operand to assemble its own `children`, and it never descends.
      final leaf = _Literal<TomDbInt>('1');
      final other = _Literal<TomDbInt>('2');
      expect(TomOperator.operandChildren(leaf), [leaf]);
      expect(TomOperator.operandChildren([leaf, other]), [leaf, other]);
      // A non-operator operand yields nothing, which is what makes a column
      // reference (whose operand is a `String`) and every literal a leaf.
      expect(TomOperator.operandChildren('priority'), isEmpty);
      expect(TomOperator.operandChildren(42), isEmpty);
      expect(TomOperator.operandChildren(null), isEmpty);
      // And it flattens one operand only: a nested container passed to it
      // comes back as itself, its own children untouched.
      final container = And([Eq<TomDbInt>(leaf, other)]);
      expect(TomOperator.operandChildren(container), [container]);
    });

    test('getParameters and getFields are defined in terms of the walk', () {
      // Stated in the dartdoc, and worth pinning: the two members a caller
      // already had are aggregations over `children`, so a container that
      // reported the wrong children would misreport both — and the walk is
      // what a caller uses when neither aggregation is the question.
      final leaf = _Literal<TomDbInt>('x', fields: {'a'});
      final other = _Literal<TomDbInt>('y', fields: {'b'});
      final dialect = TomStandardSqlDialect();
      expect(And([Eq<TomDbInt>(leaf, other)]).getFields(dialect), {'a', 'b'});
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
    // (`datasources/sql_instant.dart`). A reflected `@TomDbColumn` on a
    // `DateTime?` field names no conversion of its own, so the data source
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

    // The two kernel half-instants are `DateTime` subtypes, so the general arm
    // above would claim them and bind a whole instant into a column holding
    // half of one: a `DATE` gaining a time nobody named, and — for a `TIME` — a
    // datetime-shaped string the server refuses outright.
    //
    // Which half a value means is decided by its *type*, exactly as the dialect
    // decides it for an inlined literal, and through the same renderer. That
    // agreement is the property asserted here: the bind and `dateOp` are
    // compared to each other rather than each to a literal string, so a change
    // to the date spelling moves both or fails.
    //
    // Both arms were unpinned until now — deleting either left the whole suite
    // green.

    /// A date anchored fourteen hours east, so the day it names locally and the
    /// day it stores are not the same one. On a UTC-anchored date every rule
    /// agrees by accident, which is exactly what hides a zone defect.
    TomZonedDate crossesTheDateLine() => TomZonedDate(
      year: 2026,
      month: 7,
      day: 5,
      timezone: TomTimezone.fromName('Pacific/Kiritimati'),
    );

    test('a TomZonedDate binds the day, not an instant', () {
      final date = crossesTheDateLine();
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['due_on'],
        {'due_on': date},
      );

      expect(bound.single, sqlDate(date));
      expect(
        bound.single,
        isNot(contains(':')),
        reason:
            'a time here means the value went through sqlInstant, which puts a '
            'clock reading into a column that holds a calendar day',
      );
    });

    test('the bound date and the inlined date literal are the same day', () {
      // The agreement the two paths exist to keep. `objectOp` dispatches a
      // TomZonedDate to `dateOp`; the bind boundary reaches `sqlDate` directly.
      // Quoting is the only difference a caller should ever see.
      final date = crossesTheDateLine();
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['due_on'],
        {'due_on': date},
      );

      expect("'${bound.single}'", MariadbSqlDialect().objectOp(date));
      expect("'${bound.single}'", MariadbSqlDialect().dateOp(date));
    });

    test('a TomDbDate box binds what the bare date binds', () {
      // The path a reflected `@TomDbColumn(columnType: TomDbDate)` takes: unwrapping
      // the box must not change which of the three renderers is chosen.
      final date = crossesTheDateLine();
      expect(
        MariadbPreparedStatement.buildPositionalParameters(
          ['d'],
          {'d': TomDbDate(date)},
        ),
        MariadbPreparedStatement.buildPositionalParameters(['d'], {'d': date}),
      );
    });

    test('a TomZonedTime binds the time of day, not an instant', () {
      // The other half of a split timestamp, and the one the server refuses
      // outright rather than storing wrongly: a `TIME` column reads a
      // datetime-shaped string as a truncation error.
      final time = TomZonedTime(hour: 14, minute: 30, second: 5);
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['at'],
        {'at': time},
      );

      expect(bound.single, sqlTimeOfDay(time));
      expect("'${bound.single}'", MariadbSqlDialect().objectOp(time));
      expect(
        bound.single,
        isNot(contains('-')),
        reason: 'a date here means the value went through sqlInstant',
      );
    });
  });

  // A renderer and a reader are only correct as a pair, and these two were not
  // one. `sqlDate` and `sqlTimeOfDay` write `'2026-07-15'` and `'14:30:05'`;
  // `TomDbDate.of` and `TomDbTime.of` parsed with `TomZonedDate.parseFromString`
  // and `TomZonedTime.parseFromString`, which read Tom's `@D@…` / `@T@…`
  // serialization and nothing else. So every value this module wrote to a
  // `DATE` or `TIME` column threw when it was read back — and nothing noticed,
  // because no test had ever completed the circle. Each direction had its own
  // tests and both passed.
  group('a date and a time survive the round trip they are written for', () {
    final dialect = MariadbSqlDialect();

    /// The text a column holds after [value] is written through the dialect,
    /// with the quotes the driver does not store.
    String stored(Object value) {
      final literal = dialect.objectOp(value);
      return literal.substring(1, literal.length - 1);
    }

    test('a TomZonedDate reads back naming the same day', () {
      final written = TomZonedDate(year: 2026, month: 7, day: 15);
      final read = TomDbDate.of(stored(written)).get()!;
      expect(read.year, 2026);
      expect(read.month, 7);
      expect(read.day, 15);
    });

    test('a TomZonedTime reads back naming the same reading', () {
      final written = TomZonedTime(hour: 14, minute: 30, second: 5);
      final read = TomDbTime.of(stored(written)).get()!;
      expect(read.hour, 14);
      expect(read.minute, 30);
      expect(read.second, 5);
    });

    test('the components are those of the value, not of the reader', () {
      // The renderer takes the components *as labelled* and applies no zone
      // conversion, so the reader must not apply one either — a value written
      // as 14:30 in Tokyo is stored as 14:30 and has to read back as 14:30,
      // whatever zone the process running this test is in.
      final tokyo = TomZonedTime(
        hour: 14,
        minute: 30,
        timezone: TomTimezone.fromName('Asia/Tokyo'),
      );
      expect(stored(tokyo), '14:30:00');
      expect(TomDbTime.of(stored(tokyo)).get()!.hour, 14);
    });

    test('the zone does not survive, and that is the column, not the reader', () {
      // Stated as a test because it is the cost of storing a native `TIME`
      // rather than Tom's serialized form: `'14:30:00'` has nowhere to put a
      // zone, so the value comes back anchored in UTC. A caller that needs the
      // zone stores the `@T@…` text in a text column, which both readers still
      // accept — asserted below so the escape hatch is known to work.
      final tokyo = TomZonedTime(
        hour: 14,
        minute: 30,
        timezone: TomTimezone.fromName('Asia/Tokyo'),
      );
      expect(TomDbTime.of(stored(tokyo)).get()!.timezone, TomTimezone.utc);
      expect(
        TomDbTime.of(tokyo.toString()).get()!.timezone,
        TomTimezone.fromName('Asia/Tokyo'),
      );
      expect(
        TomDbDate.of(
          TomZonedDate(year: 2026, month: 7, day: 15).toString(),
        ).get()!.day,
        15,
      );
    });

    test('a null or empty column is an absent value, not a parse failure', () {
      // The driver reports an absent column as `null` or as the empty string
      // depending on the row mapper — the same pair `parseOptionalSqlInstant`
      // collapses. Reading the empty string as a malformed date would turn a
      // `NULL` column into an exception on every row that has one.
      expect(TomDbDate.of(null).get(), isNull);
      expect(TomDbDate.of('').get(), isNull);
      expect(TomDbTime.of(null).get(), isNull);
      expect(TomDbTime.of('').get(), isNull);
    });

    test('a TIME(6) column keeps whole seconds', () {
      // MariaDB appends the sub-second digits a `TIME(n)` column declares.
      // `sqlTimeOfDay` writes none, so they are dropped rather than rejected:
      // a column declared with precision must not fail every read.
      expect(TomDbTime.of('14:30:05.123456').get()!.second, 5);
    });

    test('an interval past 23 hours is refused, not wrapped', () {
      // A `TIME` column doubles as MariaDB's interval type and spans to
      // 838:59:59. `TomZonedTime` holds a clock reading, which `25:00:00` is
      // not — so it throws rather than silently becoming 01:00 the next day,
      // because a duration stored in a time-of-day column is a modelling
      // mistake and rolling it over would hide it.
      expect(() => TomDbTime.of('25:00:00'), throwsFormatException);
      expect(() => TomDbTime.of('838:59:59'), throwsFormatException);
    });

    test('neither reader guesses at text it does not recognise', () {
      expect(() => TomDbDate.of('15/07/2026'), throwsFormatException);
      expect(() => TomDbTime.of('half past two'), throwsFormatException);
      // A timestamp is the commonest wrong thing to find in either column, and
      // the one a lenient parser would half-accept.
      expect(() => TomDbDate.of('2026-07-15 14:30:00'), throwsFormatException);
      expect(() => TomDbTime.of('2026-07-15 14:30:00'), throwsFormatException);
    });

    test('a DATE column arrives with the midnight the driver appends', () {
      // Not a hypothetical: the MariaDB driver materialises a `DATE` into the
      // same shape it gives a `DATETIME`, so the text a reader is handed is
      // `2026-07-15 00:00:00.0` and not the `2026-07-15` the renderer wrote.
      // Only a live server shows that — which is why the round trip has a
      // `db`-tagged sibling — and it is why the pattern admits a trailing
      // midnight while the assertion above still refuses a real clock reading.
      expect(TomDbDate.of('2026-07-15 00:00:00.0').get()!.day, 15);
      expect(TomDbDate.of('2026-07-15 00:00:00').get()!.day, 15);
      expect(TomDbDate.of('2026-07-15T00:00').get()!.day, 15);
      expect(() => TomDbDate.of('2026-07-15 00:00:01'), throwsFormatException);
    });
  });

  group('MariaDbDatasource.toPositionalStatement', () {
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
      // A bound :p ANDed with an inlined 'x:y' literal must yield exactly
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

    test('a `:name`-looking substring inside a backtick identifier is safe', () {
      // A bound :p next to a `weird:col` backtick identifier must yield exactly
      // one `?`; the `:col` inside the backticks is a quoted identifier, not a
      // placeholder.
      final (sql, params) = MariaDbDatasource.toPositionalStatement(
        'SELECT `weird:col` FROM t WHERE b = :p',
      );
      expect(sql, 'SELECT `weird:col` FROM t WHERE b = ?');
      expect(params, ['p']);
    });

    test('a doubled backtick escapes a literal backtick inside an identifier', () {
      // ``a`` `:x` `` is one identifier (the `` `` `` is an escaped backtick), so
      // `:x` never leaves the identifier — only the trailing bound :p is a slot.
      final (sql, params) = MariaDbDatasource.toPositionalStatement(
        'SELECT `a``:x` FROM t WHERE b = :p',
      );
      expect(sql, 'SELECT `a``:x` FROM t WHERE b = ?');
      expect(params, ['p']);
    });

    test('a backslash is a literal character inside a backtick identifier, not '
        'an escape', () {
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

  group('SqlPlaceholderScan.extractNames (shared with crud_repository)', () {
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

    test('extractNames skips a `:name`-looking backtick identifier', () {
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
    // earn that is not decided by `"$e".contains("connection closed")`: that
    // matches the wording of a third-party toString, which no contract holds
    // still.
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

  // A data source is opened explicitly — by `initialize`, which binds the
  // settings and connects, or by setting the fields and calling `connect`. The
  // three execution entry points do not open one of their own, and used not to
  // agree about it: `prepareStatement` connected on demand while `executeQuery`
  // and `executeCommand` threw, so the same data source was usable or unusable
  // depending on which method a caller reached for first.
  //
  // The rule resolves that towards refusing, because the on-demand connect
  // could never have worked. `connect` binds `host`, `port` and the
  // credentials, and those arrive only from `initialize` or a direct
  // assignment; before either, the fields hold `""` and `-1`. So connecting
  // from an entry point cannot produce a working link — it can only turn "this
  // data source was never opened" into "the database at `:-1` is unreachable",
  // which sends the reader to the network for a configuration bug.
  //
  // Each test therefore asserts both halves: the call throws, *and* nothing
  // dialled out. The second is the one that pins the behaviour — an implicit
  // connect throws too, so an exception on its own proves nothing.
  group('MariaDbDatasource lifecycle: a data source that was never opened', () {
    test('executeQuery refuses instead of connecting', () async {
      final ds = _NeverOpenedDatasource();
      await expectLater(
        ds.executeQuery<Object>('SELECT 1'),
        throwsA(isA<MariadbDatasourceException>()),
      );
      expect(ds.connectCalls, 0);
    });

    test('executeCommand refuses instead of connecting', () async {
      final ds = _NeverOpenedDatasource();
      await expectLater(
        ds.executeCommand('DELETE FROM t'),
        throwsA(isA<MariadbDatasourceException>()),
      );
      expect(ds.connectCalls, 0);
    });

    test('prepareStatement refuses instead of connecting', () async {
      // The entry point that used to differ. It connected on demand, so a
      // caller that prepared before it queried never met the error the other
      // two raised.
      final ds = _NeverOpenedDatasource();
      await expectLater(
        ds.prepareStatement<Object>(_FixedQuery()),
        throwsA(isA<MariadbDatasourceException>()),
      );
      expect(ds.connectCalls, 0);
    });

    test('all three refuse the same way, and name the caller', () async {
      // One rule means one error, not three shapes of "no connection" a caller
      // would have to match separately. The operation is carried in the
      // parameters rather than baked into the key, so a log says which call ran
      // too early without multiplying the keys.
      final keys = <String>{};
      final operations = <Object?>[];
      for (final call
          in <(String, Future<Object?> Function(MariaDbDatasource))>[
            ('executeQuery', (ds) => ds.executeQuery<Object>('SELECT 1')),
            ('executeCommand', (ds) => ds.executeCommand('DELETE FROM t')),
            (
              'prepareStatement',
              (ds) => ds.prepareStatement<Object>(_FixedQuery()),
            ),
          ]) {
        final ds = _NeverOpenedDatasource();
        try {
          await call.$2(ds);
          fail('${call.$1} did not refuse');
        } on MariadbDatasourceException catch (e) {
          keys.add(e.key);
          operations.add(e.parameters?['operation']);
        }
      }
      expect(keys, {'error.datasource.not_opened'});
      expect(operations, [
        'executeQuery',
        'executeCommand',
        'prepareStatement',
      ]);
    });
  });

  // `mysql_client` completes a call on the first OK packet it reads and never
  // looks at the more-results flag, so a two-statement command leaves the
  // second reply on the wire for the *next* call to read. From then on every
  // call on that connection is answered by its predecessor's reply: a query
  // comes back empty, a `XA COMMIT` returns before the server has committed,
  // and an error in any statement after the first is never raised at all.
  // Nothing about that is visible where it goes wrong, so the driver refuses
  // the shape at the boundary instead — before it can reach the connection.
  group('MariaDbDatasource: one statement per call', () {
    Future<MariadbDatasourceException> refusal(
      Future<Object?> Function(MariaDbDatasource) call,
    ) async {
      final ds = _NeverOpenedDatasource();
      try {
        await call(ds);
      } on MariadbDatasourceException catch (e) {
        expect(ds.connectCalls, 0, reason: 'refused before dialling out');
        return e;
      }
      fail('the call did not refuse');
    }

    test('executeCommand refuses two statements', () async {
      final e = await refusal(
        (ds) => ds.executeCommand('XA END x; XA PREPARE x;'),
      );
      expect(e.key, 'error.datasource.multiple_statements');
      expect(e.parameters?['operation'], 'executeCommand');
    });

    test('executeQuery refuses two statements', () async {
      final e = await refusal(
        (ds) => ds.executeQuery<Object>('SELECT 1; SELECT 2'),
      );
      expect(e.key, 'error.datasource.multiple_statements');
      expect(e.parameters?['operation'], 'executeQuery');
    });

    test('a terminating semicolon is still one statement', () async {
      // The refusal is about statements, not characters: `COMMIT;` is the
      // shape the transaction lifecycle issues, and it reaches the connection
      // check rather than being refused.
      final e = await refusal((ds) => ds.executeCommand('COMMIT;'));
      expect(e.key, 'error.datasource.not_opened');
    });

    test(
      'a semicolon inside a literal or a comment is not a separator',
      () async {
        for (final command in const [
          "INSERT INTO t (title) VALUES ('a; b')",
          'SELECT 1 -- ; SELECT 2',
          'SELECT `odd;name` FROM t',
        ]) {
          final e = await refusal((ds) => ds.executeCommand(command));
          expect(e.key, 'error.datasource.not_opened', reason: command);
        }
      },
    );
  });

  // The other half of the rule, and the half that must not be lost while
  // enforcing the first: a connection that *was* opened and has since dropped
  // is replaced, because the settings are known and reconnecting is what the
  // caller wants. Refusing here instead would make every restarted database a
  // permanent outage for the process.
  group('MariaDbDatasource lifecycle: a connection that dropped', () {
    test('is replaced, and the statement runs on the new one', () async {
      final ds = _PooledFakeDatasource();
      await ds.connect();
      ds.first.connected = false;
      expect(await ds.executeCommand('DELETE FROM t'), BigInt.two);
      // Which connection ran it is the assertion that matters: the dead one
      // must not be handed out again.
      expect(ds.opened, hasLength(2));
      expect(ds.opened[1].executed, ['DELETE FROM t']);
      expect(ds.first.executed, isEmpty);
    });

    test('a live connection is used as it stands, with no reconnect', () async {
      final ds = _PooledFakeDatasource();
      await ds.connect();
      await ds.executeCommand('DELETE FROM t');
      expect(ds.opened, hasLength(1));
      expect(ds.first.executed, ['DELETE FROM t']);
    });

    test('the prepared-statement retry re-prepares on a new connection', () async {
      // The path reached *because* the connection went away: a statement whose
      // execute failed on a dead link runs again on another connection, which
      // prepares it for itself.
      //
      // Mapped as a grouped row with an empty projection so the assertion stays
      // on the retry: that route returns the mapped rows without reflecting a
      // result type, which this suite cannot bootstrap.
      final ds = _PooledFakeDatasource();
      await ds.connect();
      final statement = MariadbPreparedStatement<TomGroupedRow>(
        const [],
        ds,
        null,
        'SELECT 1',
        groupedProjection: const {},
      );
      ds.first.dropOnNextPreparedExecution = true;

      expect(await statement.execute(), isEmpty);
      expect(ds.opened, hasLength(2));
      expect(ds.first.prepared, ['SELECT 1']);
      expect(ds.opened[1].prepared, ['SELECT 1']);
    });

    test('the retry refuses when the data source has been torn down', () async {
      // A dropped connection and a data source that no longer exists are
      // different situations: reopening here would resurrect a data source the
      // application let go, on a statement it still happened to hold.
      final ds = _PooledFakeDatasource();
      await ds.connect();
      final statement = MariadbPreparedStatement<TomGroupedRow>(
        const [],
        ds,
        null,
        'SELECT 1',
        groupedProjection: const {},
      );
      await ds.close();

      await expectLater(
        statement.execute(),
        throwsA(
          isA<MariadbDatasourceException>().having(
            (e) => e.key,
            'key',
            'error.datasource.not_opened',
          ),
        ),
      );
      expect(ds.opened, hasLength(1));
    });

    test('inside a transaction a lost connection is not retried', () async {
      // The transaction lived on the connection that was lost; running the
      // statement again on another connection would run it outside the
      // transaction the caller asked for.
      final ds = _PooledFakeDatasource();
      await ds.connect();
      await TomTransactionManager.runInTransactionScope(() async {
        final (txn, _) = TomTransactionManager.startTransaction();
        await txn.registerParticipant(ds);
        final statement = MariadbPreparedStatement<TomGroupedRow>(
          const [],
          ds,
          null,
          'SELECT 1',
          groupedProjection: const {},
        );
        ds.first.dropOnNextPreparedExecution = true;
        await expectLater(
          statement.execute(),
          throwsA(
            isA<MariadbDatasourceException>().having(
              (e) => e.key,
              'key',
              'error.failed-to-execute.transaction_connection_lost',
            ),
          ),
        );
        await txn.rollbackTransaction();
      });
      expect(ds.opened, hasLength(1));
    });
  });

  // The reason the pool exists. With one connection, a transaction held it from
  // its first statement to its conclusion, so a second transaction on the same
  // data source waited — and one slow request stalled every other request on
  // that database. Each transaction now takes a connection of its own.
  group('MariaDbDatasource: concurrent transactions', () {
    /// Runs [body] as its own request: a transaction scope of its own, with a
    /// transaction this data source enlists in on its first statement.
    Future<void> inTransaction(
      Future<void> Function(TomTransaction txn) body,
    ) => TomTransactionManager.runInTransactionScope(() async {
      final (txn, _) = TomTransactionManager.startTransaction();
      await body(txn);
      await txn.commitTransaction();
    });

    test('a slow transaction does not block another', () async {
      final ds = _PooledFakeDatasource();
      await ds.connect();
      final slow = Completer<void>();
      final slowRunning = inTransaction((txn) async {
        // Held inside its transaction until the other has finished.
        ds.first.hold = slow;
        await ds.executeCommand('UPDATE t SET a = 1');
      });
      await Future<void>.delayed(Duration.zero);

      var fastDone = false;
      await inTransaction((txn) async {
        await ds.executeCommand('UPDATE t SET b = 2');
      }).timeout(const Duration(seconds: 5));
      fastDone = true;

      expect(fastDone, isTrue);
      expect(slow.isCompleted, isFalse, reason: 'the slow one is still open');
      slow.complete();
      await slowRunning;

      expect(ds.opened, hasLength(2));
      expect(ds.opened[0].executed, [
        'START TRANSACTION;',
        'UPDATE t SET a = 1',
        'COMMIT;',
      ]);
      expect(ds.opened[1].executed, [
        'START TRANSACTION;',
        'UPDATE t SET b = 2',
        'COMMIT;',
      ]);
      expect(ds.lentConnectionCount, 0, reason: 'both handed back');
    });

    test(
      'every statement of a transaction runs on its one connection',
      () async {
        final ds = _PooledFakeDatasource();
        await ds.connect();
        await inTransaction((txn) async {
          await ds.executeCommand('UPDATE t SET a = 1');
          await ds.executeCommand('UPDATE t SET a = 2');
          expect(ds.lentConnectionCount, 1);
        });
        expect(ds.opened, hasLength(1));
        expect(ds.first.executed, [
          'START TRANSACTION;',
          'UPDATE t SET a = 1',
          'UPDATE t SET a = 2',
          'COMMIT;',
        ]);
      },
    );

    test(
      'a statement outside any transaction borrows another connection',
      () async {
        final ds = _PooledFakeDatasource();
        await ds.connect();
        final held = Completer<void>();
        final txnRunning = inTransaction((txn) async {
          await ds.executeCommand('UPDATE t SET a = 1');
          await held.future;
        });
        await Future<void>.delayed(Duration.zero);
        await ds.executeCommand('SELECT 1');
        expect(ds.opened[1].executed, ['SELECT 1']);
        held.complete();
        await txnRunning;
        expect(ds.first.executed, isNot(contains('SELECT 1')));
      },
    );

    test(
      'with every connection in use, a transaction waits its turn',
      () async {
        final ds = _PooledFakeDatasource(maxSize: 1);
        await ds.connect();
        final held = Completer<void>();
        final order = <String>[];
        final first = inTransaction((txn) async {
          await ds.executeCommand('UPDATE t SET a = 1');
          await held.future;
          order.add('first done');
        });
        await Future<void>.delayed(Duration.zero);
        final second = inTransaction((txn) async {
          await ds.executeCommand('UPDATE t SET b = 2');
          order.add('second ran');
        });
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(order, isEmpty, reason: 'the only connection is taken');
        held.complete();
        await Future.wait([first, second]);
        expect(order, ['first done', 'second ran']);
        expect(ds.opened, hasLength(1));
      },
    );

    test('concurrent statements of one transaction start it once', () async {
      // Both race to enlist the data source; the second has to wait for the
      // first's START rather than start the transaction again.
      final ds = _PooledFakeDatasource();
      await ds.connect();
      await inTransaction((txn) async {
        await Future.wait([
          ds.executeCommand('UPDATE t SET a = 1'),
          ds.executeCommand('UPDATE t SET b = 2'),
        ]);
      });
      expect(
        ds.first.executed.where((c) => c.startsWith('START')),
        hasLength(1),
      );
      expect(ds.opened, hasLength(1));
    });

    test('XA transactions side by side are separate branches', () async {
      final ds = _PooledXADatasource();
      await ds.connect();
      final held = Completer<void>();
      final first = inTransaction((txn) async {
        await ds.executeCommand('UPDATE t SET a = 1');
        await held.future;
      });
      await Future<void>.delayed(Duration.zero);
      await inTransaction((txn) async {
        await ds.executeCommand('UPDATE t SET b = 2');
      });
      held.complete();
      await first;

      String branchOn(_FakeConnection link) => link.executed
          .firstWhere((c) => c.startsWith('XA START '))
          .substring('XA START '.length);
      expect(ds.opened, hasLength(2));
      expect(branchOn(ds.opened[0]), isNot(branchOn(ds.opened[1])));
      for (final link in ds.opened) {
        final branch = branchOn(link);
        expect(link.executed.where((c) => c.startsWith('XA')), [
          'XA START $branch',
          'XA END $branch',
          'XA PREPARE $branch',
          'XA COMMIT $branch',
        ]);
      }
    });
  });

  // A `DELETE` returns no rows, so the only thing an execute of one hands back
  // is metadata on the result set. Both are per-execution state on the handle,
  // and the two are captured together precisely so that the retry branch below
  // cannot pick up one and forget the other.
  group('MariadbPreparedStatement.lastAffectedRows', () {
    MariadbPreparedStatement<TomGroupedRow> statementOn(MariaDbDatasource ds) =>
        MariadbPreparedStatement<TomGroupedRow>(
          const [],
          ds,
          null,
          'DELETE FROM t',
          groupedProjection: const {},
        );

    test('is zero before the statement has run', () {
      expect(statementOn(_PooledFakeDatasource()).lastAffectedRows, 0);
    });

    test('reports the row count the execute returned', () async {
      final link = _FakeConnection(connected: true)
        ..preparedAffectedRows = BigInt.from(3);
      final ds = _PooledFakeDatasource(queued: [link]);
      await ds.connect();
      final statement = statementOn(ds);
      await statement.execute();
      expect(statement.lastAffectedRows, 3);
    });

    test('a delete that matched nothing reports zero', () async {
      final ds = _PooledFakeDatasource(
        queued: [_FakeConnection(connected: true)],
      );
      await ds.connect();
      final statement = statementOn(ds);
      await statement.execute();
      expect(statement.lastAffectedRows, 0);
    });

    test('the retry captures the count too', () async {
      // A retry runs on a different connection, opened after the first attempt
      // found its connection gone. A capture written only into the happy path
      // leaves every retried delete reporting zero rows — silently, since zero
      // is a legal answer.
      final second = _FakeConnection(connected: true)
        ..preparedAffectedRows = BigInt.from(5);
      final ds = _PooledFakeDatasource(
        queued: [_FakeConnection(connected: true), second],
      );
      await ds.connect();
      ds.first.dropOnNextPreparedExecution = true;
      final statement = statementOn(ds);
      await statement.execute();
      expect(ds.opened, hasLength(2));
      expect(statement.lastAffectedRows, 5);
    });
  });

  // A pooled data source prepares a statement on each connection that runs
  // it, so a statement a repository keeps for the life of the process runs on
  // whichever connection it is given — and forgetting it reaches every one.
  group('MariadbPreparedStatement on a pool', () {
    test('a connection prepares a statement once and reuses it', () async {
      final ds = _PooledFakeDatasource();
      await ds.connect();
      final statement = MariadbPreparedStatement<TomGroupedRow>(
        const [],
        ds,
        null,
        'SELECT 1',
        groupedProjection: const {},
      );
      await statement.execute();
      await statement.execute();
      expect(ds.first.prepared, ['SELECT 1']);
    });

    test('deallocate reaches every connection that prepared it, once it is '
        'handed back', () async {
      final ds = _PooledFakeDatasource();
      await ds.connect();
      final prepared = MariadbPreparedStatement<TomGroupedRow>(
        const [],
        ds,
        null,
        'SELECT 1',
        groupedProjection: const {},
      );
      await prepared.execute();
      await prepared.deallocate();
      // The connection is idle, so the deallocation waits for its next use.
      expect(ds.first.statements.single.deallocations, 0);
      await ds.executeCommand('DELETE FROM t');
      expect(ds.first.statements.single.deallocations, 1);
      // Prepared again on demand afterwards.
      await prepared.execute();
      expect(ds.first.prepared, ['SELECT 1', 'SELECT 1']);
    });
  });

  group('the driver contract answers nothing on a driver\'s behalf', () {
    /// The body of `abstract class TomPreparedStatement`, without its header.
    String statementContract() {
      final source = File(
        'lib/src/tomserver/datasources/datasource_initialization.dart',
      ).readAsStringSync();
      const header = 'abstract class TomPreparedStatement<T extends Object> {';
      final start = source.indexOf(header);
      expect(start, isNot(-1), reason: 'the contract was renamed');
      final body = source.substring(start + header.length);
      return body.substring(0, body.indexOf('\n}'));
    }

    /// [contract] without its dartdoc and comment lines.
    Iterable<String> declarations(String contract) => contract
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('//'));

    test('every member is abstract', () {
      // The rule, and the reason it is worth a test rather than a convention:
      // each member of this contract carries a value the layers above act on —
      // `save` returns a row under the key `lastGeneratedId` reports, `delete`
      // returns `lastAffectedRows` as *the* number of rows removed. A default
      // lets a driver that never implemented the member answer anyway, and the
      // answer is indistinguishable from a real one, so nothing at any layer
      // can notice. A member body is exactly what that looks like in source:
      // either `=> …` or a braced block.
      final body = declarations(statementContract());
      expect(
        body.where((line) => line.contains('=>') || line.contains('{')),
        isEmpty,
        reason:
            'a member of TomPreparedStatement gained a default implementation; '
            'a driver can now leave it unanswered and have the silence read as '
            'an answer',
      );
    });

    test('it declares the three members the layers above read', () {
      // Named individually so a member *removed* fails here too: the check
      // above passes trivially on an empty contract.
      final body = declarations(statementContract()).join('\n');
      expect(body, contains('int? get lastGeneratedId;'));
      expect(body, contains('int get lastAffectedRows;'));
      expect(body, contains('Future<List<T>> execute('));
    });

    /// The instance members of `abstract class TomDataSource`: its body up to
    /// the first static declaration, which is the registry machinery and
    /// legitimately has bodies.
    String dataSourceContract() {
      final source = File(
        'lib/src/tomserver/datasources/datasource_initialization.dart',
      ).readAsStringSync();
      const header =
          'abstract class TomDataSource implements TomTransactionParticipant {';
      final start = source.indexOf(header);
      expect(start, isNot(-1), reason: 'the contract was renamed');
      final body = source.substring(start + header.length);
      return body.substring(0, body.indexOf('\n  static '));
    }

    test('every instance member of TomDataSource is abstract', () {
      // The same rule, for the data-source half. Its sharpest case is
      // `isOperational`, which TomDataSourceInfo.isOperational reports and
      // readiness checks trust: a default `true` would let a driver that never
      // implemented it report usable forever.
      final body = declarations(dataSourceContract());
      expect(
        body.where((line) => line.contains('=>') || line.contains('{')),
        isEmpty,
        reason:
            'a member of TomDataSource gained a default implementation; a '
            'driver can now leave it unanswered and have the silence read as '
            'an answer',
      );
      expect(
        body.join('\n'),
        contains('bool isOperational();'),
        reason: 'the check above passes trivially if the member is removed',
      );
    });
  });

  // The third state, and the one close used to leave unrepresentable. Closing
  // released the socket but left `connection` pointing at the dead object, so
  // the data source went on describing itself in terms of a connection that was
  // gone — and, worse, every reconnect path tests that field, so a statement
  // arriving after close found a link there and quietly dialled a new one.
  // Deliberate teardown is not a dropped link: reopening it resurrects a data
  // source the application let go, which on the shutdown path opens a socket
  // nothing will ever close.
  group('MariaDbDatasource lifecycle: a data source that was closed', () {
    test('close closes the pool and lets go of it', () async {
      final ds = _PooledFakeDatasource();
      await ds.connect();
      await ds.close();
      expect(ds.first.closeCalls, 1);
      expect(ds.openConnectionCount, 0);
      expect(ds.connected, isFalse);
      expect(ds.isOperational(), isFalse);
    });

    test('a closed data source refuses statements, and does not '
        're-open one', () async {
      final ds = _PooledFakeDatasource();
      await ds.connect();
      await ds.close();
      await expectLater(
        ds.executeCommand('DELETE FROM t'),
        throwsA(isA<MariadbDatasourceException>()),
      );
      expect(ds.opened, hasLength(1));
    });

    test('the refusal says which of the two states it is', () async {
      // Both refusals share a key, because a caller matching on "this data
      // source is not open" should not have to match twice. Which state it is
      // rides in the parameters, because it points at a different bug: never
      // opened is a configuration or start-up ordering fault, closed is a
      // shutdown ordering one.
      final closed = _PooledFakeDatasource();
      await closed.connect();
      await closed.close();
      final states = <Object?>[];
      final keys = <String>{};
      for (final ds in <MariaDbDatasource>[closed, _NeverOpenedDatasource()]) {
        try {
          await ds.executeCommand('DELETE FROM t');
          fail('$ds did not refuse');
        } on MariadbDatasourceException catch (e) {
          keys.add(e.key);
          states.add(e.parameters?['state']);
        }
      }
      expect(keys, {'error.datasource.not_opened'});
      expect(states, ['closed', 'never_opened']);
    });

    test('toString stops describing a pool that is gone', () async {
      final ds = _PooledFakeDatasource();
      await ds.connect();
      expect(ds.toString(), contains('open (0 lent, 1 idle)'));
      await ds.close();
      expect(ds.toString(), contains('closed'));
      expect(ds.toString(), isNot(contains('open (')));
    });

    test(
      'a connection that had already dropped is let go, not closed',
      () async {
        final ds = _PooledFakeDatasource();
        await ds.connect();
        ds.first.connected = false;
        await ds.close();
        expect(ds.first.closeCalls, 0);
        expect(ds.openConnectionCount, 0);
      },
    );

    test('a connection that fails to close is logged and let go', () async {
      // A close that throws still means the caller is done with the
      // connection, and with several connections one failure must not stop the
      // others being closed.
      final ds = _PooledFakeDatasource(
        queued: [
          _FakeConnection(
            connected: true,
            closeFailure: StateError('the socket was already gone'),
          ),
        ],
      );
      await ds.connect();
      await ds.close();
      expect(ds.first.closeCalls, 1);
      expect(ds.toString(), contains('closed'));
    });

    test('a lent connection is closed when it is handed back', () async {
      final ds = _PooledFakeDatasource();
      await ds.connect();
      final release = Completer<void>();
      final link = ds.first..hold = release;
      final running = ds.executeCommand('SELECT SLEEP(1)');
      await Future<void>.delayed(Duration.zero);
      await ds.close();
      expect(link.closeCalls, 0, reason: 'still running its statement');
      release.complete();
      await running;
      expect(link.closeCalls, 1);
    });

    test('closing one that was never opened leaves it never opened', () async {
      final ds = _NeverOpenedDatasource();
      await ds.close();
      expect(ds.toString(), contains('never opened'));
      try {
        await ds.executeCommand('DELETE FROM t');
        fail('the data source did not refuse');
      } on MariadbDatasourceException catch (e) {
        expect(e.parameters?['state'], 'never_opened');
      }
    });
  });

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

  group('MariaDbDatasource.parsePort / normalizeIntegerSettings (G-DB-3)', () {
    // The datasource binds `port` to an int field, but application config may
    // express it either way — an env substitution (`port: ${DB_PORT:3306}`)
    // always yields a string. parsePort folds a string port to an int so both
    // forms work; normalizeIntegerSettings applies it at the config-binding boundary.
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

    test(
      'normalizeIntegerSettings folds a string port to an int, leaving other keys',
      () {
        final normalized = MariaDbDatasource.normalizeIntegerSettings(
          <String, dynamic>{'host': 'localhost', 'port': '3308'},
        );
        expect(normalized['port'], 3308);
        expect(normalized['host'], 'localhost');
      },
    );

    test('normalizeIntegerSettings leaves an int port unchanged', () {
      final settings = <String, dynamic>{'port': 3306};
      final normalized = MariaDbDatasource.normalizeIntegerSettings(settings);
      expect(normalized['port'], 3306);
    });

    test('normalizeIntegerSettings leaves an absent port unchanged', () {
      final settings = <String, dynamic>{'host': 'localhost'};
      final normalized = MariaDbDatasource.normalizeIntegerSettings(settings);
      expect(normalized.containsKey('port'), isFalse);
    });

    test('normalizeIntegerSettings folds string pool settings too', () {
      // An environment substitution yields a string for every key, so a pool
      // size configured as `\${DB_POOL:20}` must bind like the port does.
      final normalized = MariaDbDatasource.normalizeIntegerSettings({
        'poolMaxSize': '20',
        'poolAcquireTimeoutMs': ' 5000 ',
        'timeOut': '15000',
      });
      expect(normalized['poolMaxSize'], 20);
      expect(normalized['poolAcquireTimeoutMs'], 5000);
      expect(normalized['timeOut'], 15000);
    });

    test('a pool setting that is not an integer is refused by name', () {
      expect(
        () =>
            MariaDbDatasource.normalizeIntegerSettings({'poolMaxSize': 'ten'}),
        throwsA(
          isA<MariadbDatasourceException>()
              .having((e) => e.key, 'key', 'error.initialize.invalid_integer')
              .having(
                (e) => e.parameters?['setting'],
                'setting',
                'poolMaxSize',
              ),
        ),
      );
    });
  });

  // A branch id is set on the way *into* `XA START` and is what the guard in
  // `startTransaction` refuses a second transaction on. So every path that can
  // end a branch has to put it back, and each one that forgets wedges the data
  // source permanently: the next start throws "There is already an active
  // transaction" and there is nothing a caller can do about it, because the
  // branch it would have to roll back never began.
  //
  // Each exit is therefore driven here with a start that actually succeeded,
  // and the assertion is always the same one — a following start is allowed.
  //
  // The exceptions are the failing exits of `prepare`, which keep the id on
  // purpose. A `false` from `prepare()` is the veto, and the coordinator
  // answers a veto by rolling *every* participant back, this one included;
  // `rollback` needs the branch to name, and clears it in its `finally`. So the
  // pair is read together — prepare leaves the id for rollback, rollback closes
  // it — and through the SQL, which is the only place the id is observable: a
  // wrongly cleared one surfaces as the literal `XA ROLLBACK null`.
  //
  // Every other XA test in this file calls the lifecycle methods in an order
  // the test picks, and every test picks the XA-correct one. That is what lets
  // a suite this size agree with a driver the coordinator cannot drive: the
  // statements are right and the order they are *issued* in is the
  // coordinator's, not the test's. So these tests drive the participant through
  // a real `TomTransaction` and read the SQL it produced. The branch id has no
  // accessor, which makes the SQL the only place a mistake about it is visible:
  // a statement issued against a cleared id arrives as the literal
  // `XA PREPARE null`.
  group('MariaDb XA through the coordinator', () {
    tearDown(() async {
      await TomTransactionManager.getCurrentTransaction()
          ?.rollbackTransaction();
    });

    test(
      'a committed transaction issues start, prepare, then commit',
      () async {
        final ds = _ScriptedXADatasource();
        final (txn, _) = TomTransactionManager.startTransaction();
        await txn.registerParticipant(ds);

        expect((await txn.commitTransaction()).isClean, isTrue);

        final branch = _branchOf(ds);
        expect(branch, isNot(contains('null')));
        expect(ds.commands, [
          'XA START $branch;',
          'XA END $branch;',
          'XA PREPARE $branch;',
          'XA COMMIT $branch;',
        ]);
      },
    );

    test('no statement is issued against a cleared branch id', () async {
      // Stated separately from the sequence above because it is the symptom a
      // reader will actually meet in a log, and because it is the one an
      // assertion on the *return value* cannot see: the coordinator reported
      // success while the driver was sending `XA PREPARE null`.
      final ds = _ScriptedXADatasource();
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(ds);
      await txn.commitTransaction();

      expect(
        ds.commands.where((c) => c.contains('null')),
        isEmpty,
        reason: 'every statement must name the branch XA START opened',
      );
    });

    test('a rolled-back transaction issues start then rollback', () async {
      final ds = _ScriptedXADatasource();
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(ds);

      expect((await txn.rollbackTransaction()).isClean, isTrue);

      final branch = _branchOf(ds);
      expect(ds.commands, [
        'XA START $branch;',
        'XA END $branch;',
        'XA ROLLBACK $branch;',
      ]);
      expect(
        ds.commands.any((c) => c.startsWith('XA PREPARE')),
        isFalse,
        reason: 'a branch being abandoned is never prepared',
      );
    });

    test(
      'a commit refused after a prepare is left in doubt, not rolled back',
      () async {
        // The in-doubt path end to end, and the one place the two-phase contract
        // is visible in SQL: the branch prepared, so the server has undertaken to
        // be able to commit it, and a rollback issued now would throw away a
        // resolvable branch on the strength of one failed round trip. The
        // coordinator leaves it — `XA RECOVER` is how it is found — and reports
        // the transaction as partially committed.
        final ds = _ScriptedXADatasource(failing: {'XA COMMIT'});
        final (txn, _) = TomTransactionManager.startTransaction();
        await txn.registerParticipant(ds);

        expect(
          (await txn.commitTransaction()).outcome,
          TomTransactionOutcome.partiallyCommitted,
          reason: 'a broken promise is reported, not repaired',
        );

        final branch = _branchOf(ds);
        expect(ds.commands, [
          'XA START $branch;',
          'XA END $branch;',
          'XA PREPARE $branch;',
          'XA COMMIT $branch;',
        ]);
        expect(
          ds.commands.any((c) => c.contains('XA ROLLBACK')),
          isFalse,
          reason:
              'rolling back a prepared branch whose peers may have committed is '
              'the outcome the prepare phase exists to prevent',
        );
      },
    );

    test('a refused prepare rolls back and does not commit', () async {
      // A prepare that fails is a veto, and the branch must not be committed
      // afterwards — the whole point of preparing before committing.
      final ds = _ScriptedXADatasource(failing: {'XA END'});
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(ds);

      // `rolledBackWithFailures`, not `rolledBack`, and the scripted failure is
      // why: this driver refuses every `XA END`, and rolling back an ACTIVE
      // branch has to end it first. So the branch that would not prepare will
      // not roll back either — it is still there, holding its locks, with
      // nothing but `XA RECOVER` to find it. That is precisely the outcome a
      // boolean built from the `endTransaction` calls reported as success.
      final result = await txn.commitTransaction();
      expect(
        result.outcome,
        TomTransactionOutcome.rolledBackWithFailures,
        reason: 'the branch would not prepare, so nothing committed',
      );
      expect(result.failed, [ds.getParticipantId()]);

      final branch = _branchOf(ds);
      expect(
        ds.commands.any((c) => c.startsWith('XA COMMIT')),
        isFalse,
        reason: 'a branch that would not prepare must not be committed',
      );
      // Named rather than merely present: a failed prepare that cleared the
      // branch id would still end in a statement mentioning `XA ROLLBACK`, and
      // that statement would name `null` — the real branch left behind with
      // nothing to reclaim it. The branch is still ACTIVE here, the prepare
      // having failed at its `XA END`, so the rollback tries to end it first —
      // and this driver refuses that too, which is where the rollback stops.
      expect(ds.commands.last, 'XA END $branch;');
      expect(
        ds.commands.where((c) => c == 'XA END $branch;'),
        hasLength(2),
        reason: 'one from the prepare, one from the rollback',
      );
    });

    test(
      'a prepare refused after XA END rolls back without a second END',
      () async {
        // The case splitting the two statements creates. `XA END` succeeded, so
        // the branch is IDLE rather than ACTIVE; a second `XA END` is refused on
        // an IDLE branch, which would turn a clean veto into a rollback failure
        // and leave the branch behind. `XA ROLLBACK` alone is what IDLE takes.
        final ds = _ScriptedXADatasource(failing: {'XA PREPARE'});
        final (txn, _) = TomTransactionManager.startTransaction();
        await txn.registerParticipant(ds);

        final result = await txn.commitTransaction();
        expect(result.outcome, TomTransactionOutcome.rolledBack);
        expect(result.isClean, isTrue);

        final branch = _branchOf(ds);
        expect(ds.commands, [
          'XA START $branch;',
          'XA END $branch;',
          'XA PREPARE $branch;',
          'XA ROLLBACK $branch;',
        ]);
      },
    );

    test('the plain sibling is unaffected by the same drive', () async {
      // The control. The one-phase driver has no prepare and must not grow one:
      // `endTransaction` on it is the no-op that reports success.
      final ds = _ScriptedDatasource();
      final (txn, _) = TomTransactionManager.startTransaction();
      await txn.registerParticipant(ds);

      expect((await txn.commitTransaction()).isClean, isTrue);
      expect(ds.commands, ['START TRANSACTION;', 'COMMIT;']);
    });
  });

  // The branch id is the `gtrid` of an XA xid, which MariaDB caps at 64 bytes:
  // `XA START` with a longer one is refused as a syntax error. Built naively
  // from the coordinates — database, host, port and a timestamp — it fitted
  // only by luck (62 bytes for the test database on `127.0.0.1`), so any real
  // hostname or a longer database name made every XA transaction fail to
  // start. The id also has to differ between processes that talk to the same
  // database, which a timestamp alone does not guarantee.
  group('MariaDb XA branch id', () {
    String branchOf(MariaDbXADatasource ds) {
      final start = (ds as _ScriptedXADatasource).commands.last;
      expect(start, startsWith("XA START '"));
      return start.substring("XA START '".length, start.length - 2);
    }

    test('fits the 64-byte gtrid whatever the coordinates', () async {
      final ds = _ScriptedXADatasource()
        ..databaseName =
            'a_rather_long_production_database_name_for_the_tenant_ledgers'
        ..host = 'db-primary.eu-central-1.internal.example.com';
      expect(await ds.startTransaction(_aTransaction()), isTrue);
      expect(utf8.encode(branchOf(ds)).length, lessThanOrEqualTo(64));
    });

    test('still names the database it belongs to', () async {
      // An operator reading `XA RECOVER` has to be able to tell whose branch
      // it is; the uniqueness suffix must not crowd the name out entirely.
      final ds = _ScriptedXADatasource();
      expect(await ds.startTransaction(_aTransaction()), isTrue);
      expect(branchOf(ds), startsWith('app@db:3306_'));
    });

    test('is quote-safe and single-byte', () async {
      final ds = _ScriptedXADatasource()..databaseName = "o'brien_dätä";
      expect(await ds.startTransaction(_aTransaction()), isTrue);
      expect(branchOf(ds), matches(RegExp(r'^[A-Za-z0-9_.@:-]+$')));
    });

    test('differs for every branch, even back to back', () async {
      final ds = _ScriptedXADatasource();
      final ids = <String>{};
      for (var i = 0; i < 50; i++) {
        expect(await ds.startTransaction(_aTransaction()), isTrue);
        ids.add(branchOf(ds));
        expect(await ds.rollback(_aTransaction()), isTrue);
      }
      expect(ids, hasLength(50));
    });
  });

  group('MariaDb transaction lifecycle: the state each exit leaves', () {
    test('a failed start clears the branch id it had already set', () async {
      final ds = _ScriptedXADatasource(failing: {'XA START'});
      expect(await ds.startTransaction(_aTransaction()), isFalse);
      // The id is assigned before the command is issued, so a failure that
      // leaves it set locks out every later transaction. Recovering by calling
      // `rollback` is not available: there is no branch to roll back, and a
      // caller that got `false` has been told the transaction never began.
      expect(await ds.startTransaction(_aTransaction()), isFalse);
      expect(ds.commands, hasLength(2));
      expect(ds.commands.every((c) => c.startsWith('XA START ')), isTrue);
    });

    test('a failed rollback clears the branch id', () async {
      final ds = _ScriptedXADatasource(failing: {'XA ROLLBACK'});
      expect(await ds.startTransaction(_aTransaction()), isTrue);
      final branch = _branchOf(ds);
      await ds.rollback(_aTransaction());
      expect(await ds.startTransaction(_aTransaction()), isTrue);
      expect(ds.commands.sublist(1, 3), [
        'XA END $branch;',
        'XA ROLLBACK $branch;',
      ]);
    });

    test('a failed prepare keeps the branch id for the rollback', () async {
      // A branch that will not prepare is not committed — and is not abandoned
      // either. The `false` reaches the coordinator as a veto, the coordinator
      // rolls every participant back, and this one has to be able to name the
      // branch it opened. Clearing here would send `XA ROLLBACK null` and leave
      // the real branch behind, which is the state nothing reclaims.
      final ds = _ScriptedXADatasource(failing: {'XA END'});
      expect(await ds.startTransaction(_aTransaction()), isTrue);
      final branch = _branchOf(ds);
      expect(await ds.prepare(_aTransaction()), isFalse);
      expect(ds.commands.last, 'XA END $branch;');
      await ds.rollback(_aTransaction());
      // The prepare failed at its `XA END`, so the branch is still ACTIVE and
      // the rollback has to end it first — naming the branch, not `null`.
      expect(ds.commands.last, 'XA END $branch;');
      expect(ds.commands.where((c) => c.contains('null')), isEmpty);
      expect(await ds.startTransaction(_aTransaction()), isTrue);
    });

    test('a failed commit keeps the branch id for XA RECOVER', () async {
      // Same contract one step later, and the sharper case: the branch is
      // prepared, so it is holding its locks in the PREPARED state. The
      // coordinator does not roll it back — a prepared branch whose peers may
      // have committed is in doubt, not failed — so what the id is kept *for*
      // is an operator, or an `XA RECOVER`, having something to name. A
      // rollback issued by hand still finds it.
      final ds = _ScriptedXADatasource(failing: {'XA COMMIT'});
      expect(await ds.startTransaction(_aTransaction()), isTrue);
      final branch = _branchOf(ds);
      expect(await ds.prepare(_aTransaction()), isTrue);
      expect(await ds.commit(_aTransaction()), isFalse);
      await ds.rollback(_aTransaction());
      expect(ds.commands.last, 'XA ROLLBACK $branch;');
      expect(await ds.startTransaction(_aTransaction()), isTrue);
    });

    test('prepare ends and prepares, commit commits', () async {
      // The order the branch's own state machine requires, read through the SQL
      // because `_txId` has no accessor. One statement per lifecycle method,
      // each in the phase the coordinator gives it: `XA END` + `XA PREPARE` in
      // `prepare`, where a refusal is still free, and `XA COMMIT` in `commit`,
      // where the decision has been made.
      final ds = _ScriptedXADatasource();
      expect(await ds.startTransaction(_aTransaction()), isTrue);
      final branch = _branchOf(ds);
      expect(branch, isNot(contains('null')));
      expect(await ds.prepare(_aTransaction()), isTrue);
      expect(ds.commands, [
        'XA START $branch;',
        'XA END $branch;',
        'XA PREPARE $branch;',
      ]);
      expect(await ds.commit(_aTransaction()), isTrue);
      expect(ds.commands.last, 'XA COMMIT $branch;');
      expect(await ds.endTransaction(_aTransaction()), isTrue);
    });

    test('the non-XA sibling is not wedged by a failed start either', () async {
      // The plain data source reaches the same contract by a different route:
      // it raises its in-transaction flag only *after* the command succeeds, so
      // there is nothing to undo on the failure path. Pinned here because the
      // two classes share a guard whose message is the symptom of the XA bug,
      // and a reader of that fix will ask whether the sibling has it too.
      final ds = _ScriptedDatasource(failing: {'START TRANSACTION'});
      expect(await ds.startTransaction(_aTransaction()), isFalse);
      expect(await ds.startTransaction(_aTransaction()), isFalse);
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
      expect(await ds.startTransaction(_aTransaction()), isTrue);
      expect(await ds.endTransaction(_aTransaction()), isTrue);
      expect(ds.commands, ['START TRANSACTION;']);
      expect(await ds.commit(_aTransaction()), isTrue);
      expect(ds.commands, ['START TRANSACTION;', 'COMMIT;']);
    });

    test('the plain end succeeds even with no transaction open', () async {
      // "Always succeeds" is not a formality: the coordinator ands every
      // participant's end result into the outcome, so a `false` here would fail
      // a transaction that had in fact completed. The no-open-transaction case
      // is reachable today: `registerParticipant` enlists a participant whose
      // start returned `false`, and that participant still gets ended.
      final ds = _ScriptedDatasource(failing: {'START TRANSACTION'});
      expect(await ds.startTransaction(_aTransaction()), isFalse);
      expect(await ds.endTransaction(_aTransaction()), isTrue);
      expect(ds.commands, ['START TRANSACTION;']);
    });
  });

  // Starting a transaction has two ways of not happening, and they are not the
  // same kind of event. A `START TRANSACTION` the database refuses comes back
  // as `false`: the caller may retry, fall back, or give up. A start on a data
  // source that is *already* in a transaction is the caller's own mistake, and
  // no retry fixes it — so it is thrown rather than reported.
  //
  // That distinction only reaches the caller if the type carries it. A bare
  // `Exception` does not: it is the supertype of every failure there is, so no
  // `catch` narrow enough to act on this one case can be written, and a
  // DB-backed test can assert nothing better than `isA<Exception>()`. The tests
  // below pin the type, the key and the detail that says *which* data source
  // and *which* branch.
  group('MariaDb transaction guard: a second concurrent transaction', () {
    /// Matches the refusal, optionally requiring the named branch in the
    /// parameters — the two lifecycles differ only in whether they have an id.
    Matcher refusesNesting({String? withTransactionId}) {
      var matcher = isA<MariadbDatasourceException>()
          .having((e) => e.key, 'key', 'error.transaction.already_active')
          .having(
            (e) => e.parameters?['participant'],
            'parameters.participant',
            'MariaDb-app@db:@3306',
          );
      if (withTransactionId != null) {
        matcher = matcher.having(
          (e) => e.parameters?['transactionId'],
          'parameters.transactionId',
          withTransactionId,
        );
      }
      return throwsA(matcher);
    }

    test(
      'the plain guard raises the module type, not a bare Exception',
      () async {
        final ds = _ScriptedDatasource();
        expect(await ds.startTransaction(_aTransaction()), isTrue);
        await expectLater(
          () => ds.startTransaction(_aTransaction()),
          refusesNesting(),
        );
      },
    );

    test('the XA guard raises it too, naming the open branch', () async {
      final ds = _ScriptedXADatasource();
      expect(await ds.startTransaction(_aTransaction()), isTrue);
      // The branch id is private, but it was interpolated into the SQL, so the
      // recorded command is where the value the refusal must name is readable.
      // Trimming the statement's trailing `;` leaves the id exactly as held.
      final started = ds.commands.single;
      final branch = started.substring('XA START '.length, started.length - 1);
      await expectLater(
        () => ds.startTransaction(_aTransaction()),
        refusesNesting(withTransactionId: branch),
      );
    });

    test('the refusal issues no statement, on either lifecycle', () async {
      // The guard sits in front of the `try`, which is what keeps it a throw:
      // inside, the catch-all that turns a failed command into `false` would
      // swallow it and hand the caller the very report this case must not be
      // confused with.
      final plain = _ScriptedDatasource();
      expect(await plain.startTransaction(_aTransaction()), isTrue);
      await expectLater(
        () => plain.startTransaction(_aTransaction()),
        refusesNesting(),
      );
      expect(plain.commands, ['START TRANSACTION;']);

      final xa = _ScriptedXADatasource();
      expect(await xa.startTransaction(_aTransaction()), isTrue);
      await expectLater(
        () => xa.startTransaction(_aTransaction()),
        throwsA(isA<Exception>()),
      );
      expect(xa.commands, hasLength(1));
    });

    test(
      'a caller can now catch the mistake without catching failures',
      () async {
        // The point of the whole todo, said as a test. `on
        // MariadbDatasourceException` must select the programming error and
        // nothing else — a database that refuses the start still arrives as
        // `false`, through the same call, uncaught.
        final refused = _ScriptedDatasource(failing: {'START TRANSACTION'});
        var caught = false;
        try {
          expect(await refused.startTransaction(_aTransaction()), isFalse);
        } on MariadbDatasourceException {
          caught = true;
        }
        expect(
          caught,
          isFalse,
          reason: 'a refused start is a report, not a throw',
        );

        final busy = _ScriptedDatasource();
        expect(await busy.startTransaction(_aTransaction()), isTrue);
        try {
          await busy.startTransaction(_aTransaction());
          fail('a second start on a busy data source must throw');
        } on MariadbDatasourceException catch (e) {
          expect(e.key, 'error.transaction.already_active');
        }
      },
    );
  });

  // The flag's whole purpose, in SQL. The coordinator enforces nothing — it has
  // no idea what a write is — so a read-only transaction means whatever the
  // resource makes it mean, and this is the resource that can make it mean
  // something: `START TRANSACTION READ ONLY` has the server refuse every write
  // on the connection until the transaction ends.
  group('a read-only transaction reaches the connection', () {
    test('the plain driver opens the branch read-only', () async {
      await TomTransactionManager.runInTransactionScope(() async {
        final ds = _ScriptedDatasource();
        final (txn, _) = TomTransactionManager.startTransaction(true);
        await txn.registerParticipant(ds);

        expect(ds.commands, ['START TRANSACTION READ ONLY;']);
        await txn.rollbackTransaction();
      });
    });

    test('and read-write otherwise', () async {
      await TomTransactionManager.runInTransactionScope(() async {
        final ds = _ScriptedDatasource();
        final (txn, _) = TomTransactionManager.startTransaction();
        await txn.registerParticipant(ds);

        expect(ds.commands, ['START TRANSACTION;']);
        await txn.rollbackTransaction();
      });
    });

    test(
      'the XA driver says it cannot honour it, and does not pretend',
      () async {
        // `XA START` has no `READ ONLY` form, so this driver can only report.
        // Silence here would leave a deployment that declared the endpoint
        // read-only believing the branch was protected.
        final output = _CapturingLogOutput();
        final previous = tomLog.logOutput;
        addTearDown(() => tomLog.logOutput = previous);
        tomLog.logOutput = output;

        await TomTransactionManager.runInTransactionScope(() async {
          final ds = _ScriptedXADatasource();
          final (txn, _) = TomTransactionManager.startTransaction(true);
          await txn.registerParticipant(ds);

          expect(ds.commands.single, startsWith('XA START '));
          expect(
            output.messages.join('\n'),
            contains('XA has no read-only branch'),
          );
          await txn.rollbackTransaction();
        });
      },
    );
  });

  group('a driver owns its dialect', () {
    test('the MariaDB driver renders through the MariaDB dialect', () {
      expect(MariaDbDatasource().sqlDialect, isA<MariadbSqlDialect>());
    });

    test('the XA driver renders through the same dialect', () {
      expect(MariaDbXADatasource().sqlDialect, isA<MariadbSqlDialect>());
    });

    test('a driver hands out one dialect, not one per call', () {
      final ds = MariaDbDatasource();
      expect(ds.sqlDialect, same(ds.sqlDialect));
    });

    test("MariaDB's TINYINT(1) rule arrives through that route", () {
      // The override that makes `TINYINT(1)` a truth value is the one thing
      // the MariaDB dialect adds, and reaching it is the whole reason a data
      // source exposes a dialect at all. Asserted *through* `sqlDialect`
      // rather than on a hand-built `MariadbSqlDialect`, because a direct
      // construction would pass even if a driver started handing out the
      // standard dialect instead.
      final dialect = MariaDbDatasource().sqlDialect;
      expect(dialect.typeFamily('TINYINT(1)'), TomSqlTypeFamily.boolean);
      expect(dialect.typeFamily('TINYINT(4)'), TomSqlTypeFamily.integer);
    });

    test('no shipped source or guide describes a dialect lookup by type', () {
      // `TomSqlDialect` was an annotation binding a dialect class to a
      // data-source type name, for a reflection scan that was never written.
      // Nothing read it, so a dialect annotated for a second type could not
      // have been found; the MariaDB dialect was reached only because the
      // driver constructs that exact class. Four documents nevertheless
      // described the scan as the mechanism.
      //
      // The name is guarded rather than merely removed because the claim
      // outlived the code by a wide margin, and because the route that does
      // exist — a driver returning its own dialect — needs no registry. A
      // future dialect arrives with its own driver. Re-introducing the lookup
      // is a decision, and this test is where it has to be argued.
      final claims = <String>[];
      for (final directory in [Directory('lib'), Directory('doc')]) {
        for (final entry in directory.listSync(recursive: true)) {
          if (entry is! File) continue;
          if (!entry.path.endsWith('.dart') && !entry.path.endsWith('.md')) {
            continue;
          }
          final lines = entry.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            if (RegExp(r'(?<!Standard)\bTomSqlDialect\b').hasMatch(lines[i])) {
              claims.add('${entry.path}:${i + 1}');
            }
          }
        }
      }
      expect(claims, isEmpty);
    });
  });

  group('The example runs green', () {
    final examplePath = p.join(
      'example',
      'datasources',
      'datasources_example.dart',
    );

    test('under exactly the command its header documents', () async {
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        examplePath,
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'example failed: ${result.stdout}${result.stderr}',
      );
      // The transcript's step numbers, in the order they were printed. The
      // whole list is compared rather than each step being looked for in
      // turn, because only one of the two failures is caught by looking: a
      // step that stopped printing fails either way, but a step *added*
      // without being listed here is a surface nothing checks — and that is
      // the state this example was in for a year, with four steps standing
      // for nine connection-free surfaces and a header claiming the rest
      // needed a database.
      final printed = RegExp(r'^(\d+)\. ', multiLine: true)
          .allMatches(result.stdout as String)
          .map((match) => match.group(1)!)
          .toList();
      expect(printed, [
        for (var step = 1; step <= 10; step++) '$step',
      ], reason: 'the example demonstrates ten surfaces, in order');
    });

    test('with its expectations checked rather than asserted', () async {
      final source = File(examplePath).readAsStringSync();
      expect(
        source,
        isNot(contains('assert(')),
        reason: 'an assert in the example does not run under `dart run`',
      );
      expect(
        source,
        contains("import '../_support/check.dart'"),
        reason: 'the example states its expectations through the shared helper',
      );
    });
  });
}

/// A value of a type `objectOp` does not recognise, whose `toString()` needs
/// escaping.
///
/// The fallback branch is the one an unforeseen type arrives on, which is
/// exactly when nobody has thought about whether its text is safe to embed.
class _Quoting {
  @override
  String toString() => "it's";
}

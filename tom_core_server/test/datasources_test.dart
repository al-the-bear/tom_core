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

    test('TomDbDateTime parses an ISO-8601 string', () {
      expect(TomDbDateTime.of('2026-01-02T03:04:05').get(),
          DateTime.parse('2026-01-02T03:04:05'));
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

    test('dateTimeOp is a quoted ISO-8601 string', () {
      final dt = DateTime.parse('2026-01-02T03:04:05');
      expect(d.dateTimeOp(dt), "'${dt.toIso8601String()}'");
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
      expect(d.between(a, [_Literal<TomDbInt>('1'), _Literal<TomDbInt>('9')]),
          'a BETWEEN 1 AND 9');
    });

    test('isin joins the choices with commas', () {
      expect(
          d.isin(a, [_Literal<TomDbInt>('1'), _Literal<TomDbInt>('2')]),
          'a IN (1,2)');
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
      expect(_Literal<TomDbInt>('x').getParameters(TomStandardSqlDialect()),
          isEmpty);
    });

    test('getFields reports referenced fields', () {
      expect(_Literal<TomDbInt>('x', fields: {'col'}).getFields(
          TomStandardSqlDialect()),
          {'col'});
    });
  });

  // The query-generation clause renderers were extracted from
  // TomSelect/TomCount/TomDelete's generateQuery into pure helpers so the
  // keyword logic can be asserted without a reflected entity (this package's
  // test suite does not bootstrap reflection). generateQuery delegates to these,
  // so the integration behaviour is covered transitively (bug §67).
  group('TomGeneratedQuery SQL clause rendering (bug §67)', () {
    test('distinctPrefix renders "DISTINCT " only when distinct', () {
      expect(TomGeneratedQuery.distinctPrefix(true), 'DISTINCT ');
      expect(TomGeneratedQuery.distinctPrefix(false), '');
    });

    test('limitClause uses MariaDB "LIMIT n", not Informix "FIRST n"', () {
      expect(TomGeneratedQuery.limitClause(5), ' LIMIT 5');
      expect(TomGeneratedQuery.limitClause(0), '');
      expect(TomGeneratedQuery.limitClause(-1), '');
    });

    test('orderByClause uses "ASC"/"DESC", not "ASCENDING"/"DESCENDING"', () {
      expect(TomGeneratedQuery.orderByClause(['t.a', 't.b'], false),
          ' ORDER BY t.a,t.b DESC');
      expect(TomGeneratedQuery.orderByClause(['t.a'], true), ' ORDER BY t.a ASC');
      expect(TomGeneratedQuery.orderByClause([], false), '');
    });

    test('countProjection emits a valid COUNT(DISTINCT ...), never DISTINCT(*)',
        () {
      expect(TomGeneratedQuery.countProjection(false, []), 'COUNT(*)');
      expect(TomGeneratedQuery.countProjection(true, ['u.id', 'u.name']),
          'COUNT(DISTINCT u.id, u.name)');
      // No columns to distinguish on -> falls back to COUNT(*), not the invalid
      // COUNT(DISTINCT(*)).
      expect(TomGeneratedQuery.countProjection(true, []), 'COUNT(*)');
    });
  });

  group('MariadbPreparedStatement.buildPositionalParameters (bug §65)', () {
    test('binds values raw, in placeholder order', () {
      final bound = MariadbPreparedStatement.buildPositionalParameters(
        ['name', 'age'],
        {'name': 'John', 'age': 42},
      );
      expect(bound, ['John', 42]);
    });

    // Bug §72: MariaDB has no native boolean (`BOOLEAN` = `TINYINT(1)`); the
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

    test('a TomDbType box binds its primitive, not its toString (bug §70)', () {
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
  });

  group('MariadbPreparedStatement.normalizeGeneratedId (bug §71)', () {
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

  // §42(c) driver discovery (createDatasourceOf resolving mariadb/mariadb_xa,
  // the unknown-type and duplicate-driver guards) is deferred: it scans
  // tomReflector.annotatedClasses, which raises "Reflection has not been
  // initialized" in this suite (no generated reflection is bootstrapped here).
  // That belongs to an integration-level test with reflection wired up.

  group('TomDataSourceInfo.initializeDatasourceInfo config guard (bug §68)', () {
    setUp(() => TomDataSourceInfo.datasources.clear());
    tearDown(() => TomDataSourceInfo.datasources.clear());

    test('a Map<String, Object?> entry is processed, not silently skipped', () async {
      // delegateTo aliasing exercises the registration path without opening a
      // real connection.
      final base = TomDataSourceInfo('base', <String, dynamic>{});
      TomDataSourceInfo.datasources['base'] = base;
      final config = <String, dynamic>{
        'alias': <String, Object?>{'delegateTo': 'base'},
      };
      final result = await TomDataSourceInfo.initializeDatasourceInfo(config);
      expect(result, 1);
      // Before §68 the Map<String,Object?> entry is not a Map<String,Object>, so
      // it is skipped and 'alias' is never registered.
      expect(TomDataSourceInfo.getDataSourceInfo('alias'), same(base));
    });

    test('a YamlMap-style Map<dynamic, dynamic> entry is also processed', () async {
      final base = TomDataSourceInfo('base2', <String, dynamic>{});
      TomDataSourceInfo.datasources['base2'] = base;
      final config = <String, dynamic>{
        'alias2': <dynamic, dynamic>{'delegateTo': 'base2'},
      };
      await TomDataSourceInfo.initializeDatasourceInfo(config);
      expect(TomDataSourceInfo.getDataSourceInfo('alias2'), same(base));
    });

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

  group('MariaDbXADatasource transaction lifecycle (bug §66)', () {
    test('rollback clears the branch id so the next startTransaction is allowed',
        () async {
      final ds = MariaDbXADatasource();
      // No connection: executeCommand fails, startTransaction returns false, but
      // the branch id is now set.
      await ds.startTransaction();
      // Before §66 rollback leaves the branch id set, so the next
      // startTransaction throws "There is already an active transaction". After
      // the fix it is cleared, so a second start is allowed (still returns false
      // for the missing connection, but must not throw).
      await ds.rollback();
      await expectLater(ds.startTransaction(), completion(isFalse));
    });

    test('a failed endTransaction clears the branch id', () async {
      final ds = MariaDbXADatasource();
      await ds.startTransaction();
      expect(await ds.endTransaction(), isFalse);
      await expectLater(ds.startTransaction(), completion(isFalse));
    });
  });
}

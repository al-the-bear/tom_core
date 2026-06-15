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
}

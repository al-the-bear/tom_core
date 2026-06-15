import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Tests for the connection-free surface of the object-persistence module:
/// the [TomQueryBuilder] DSL and the [TomOperator] tree rendering SQL through a
/// dialect, plus the persistence annotations and `TomColumnInformation`.
///
/// The repositories and the query-sentence compiler need a reflected entity and
/// a live data source, so they are covered by `doc/object_persistence.md` and
/// integration tests, not here.

/// A trivial host for the [TomQueryBuilder] DSL.
class _Builder with TomQueryBuilder {}

TomColumnInformation _column(String table, String column) {
  return TomColumnInformation(
    TomDbTable(datasource: 'main', table: table, primaryKeyField: 'id'),
    Object,
    TomDbColumn(columnName: column),
    null,
    null,
    null,
    Object,
    column,
    column,
  );
}

void main() {
  final b = _Builder();
  final dialect = MariadbSqlDialect();

  group('literals and comparisons', () {
    test('integer literal renders bare', () {
      expect(b.intOp(42).generate(dialect), '42');
    });

    test('string literal is single-quoted', () {
      expect(b.text('hi').generate(dialect), "'hi'");
    });

    test('equality renders a = b', () {
      expect(b.eq(b.intOp(1), b.intOp(2)).generate(dialect), '1 = 2');
    });

    test('greater-or-equal renders a >= b', () {
      expect(b.gte(b.intOp(5), b.intOp(3)).generate(dialect), '5 >= 3');
    });
  });

  group('parameters', () {
    test('render as :name placeholders', () {
      expect(b.p<TomDbInt>('min').generate(dialect), ':min');
    });

    test('contribute their name to getParameters', () {
      final pred = b.gte(b.intOp(1), b.p<TomDbInt>('min'));
      expect(pred.getParameters(dialect), contains('min'));
    });

    test('reference no fields', () {
      expect(b.p<TomDbInt>('min').getFields(dialect), isEmpty);
    });
  });

  group('column references', () {
    test('render as table.column', () {
      final col = _column('users', 'age');
      expect(b.intF('age', col).generate(dialect), 'users.age');
    });

    test('are collected as fields', () {
      final col = _column('users', 'name');
      final pred = b.like(b.textF('name', col), b.text('A%'));
      expect(pred.getFields(dialect), contains('users.name'));
    });
  });

  group('compound predicates', () {
    test('AND joins with the right separator and grouping', () {
      final ageCol = _column('users', 'age');
      final pred = b.and([
        b.group(b.gte(b.intF('age', ageCol), b.p<TomDbInt>('min'))),
        b.group(b.like(b.textF('name', _column('users', 'name')), b.text('A%'))),
      ]);
      expect(
        pred.generate(dialect),
        "( users.age >= :min ) AND ( users.name LIKE 'A%' )",
      );
    });

    test('IN renders a comma-separated choice list', () {
      final col = _column('users', 'age');
      final pred = b.isIn(b.intF('age', col), [b.intOp(18), b.intOp(21)]);
      expect(pred.generate(dialect), 'users.age IN (18,21)');
    });

    test('OR joins predicates with OR', () {
      final pred = b.or([
        b.eq(b.intOp(1), b.intOp(1)),
        b.eq(b.intOp(2), b.intOp(2)),
      ]);
      expect(pred.generate(dialect), '1 = 1 OR 2 = 2');
    });
  });

  group('BETWEEN arity validation', () {
    test('two bounds renders BETWEEN ... AND ...', () {
      final col = _column('users', 'age');
      final pred = b.between(b.intF('age', col), [b.intOp(18), b.intOp(65)]);
      expect(pred.generate(dialect), 'users.age BETWEEN 18 AND 65');
    });

    test('one bound throws TomQuerySyntaxException', () {
      final col = _column('users', 'age');
      expect(
        () => b.between(b.intF('age', col), [b.intOp(18)]),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'between_expression.must_have_two_values',
          ),
        ),
      );
    });

    test('three bounds throws TomQuerySyntaxException', () {
      final col = _column('users', 'age');
      expect(
        () => b.between(b.intF('age', col), [b.intOp(1), b.intOp(2), b.intOp(3)]),
        throwsA(isA<TomQuerySyntaxException>()),
      );
    });
  });

  group('persistence annotations', () {
    test('TomDbColumn.declaredDartType resolves the type argument', () {
      const col = TomDbColumn<String, TomDbString>(columnName: 'name');
      expect(col.declaredDartType(), String);
    });

    test('TomColumnInformation.getQueryFieldName prefers the column name', () {
      final info = _column('users', 'user_name');
      expect(info.getQueryFieldName(), 'user_name');
    });

    test('TomColumnInformation.getQueryFieldName falls back to the field', () {
      final info = TomColumnInformation(
        TomDbTable(datasource: 'main', table: 't', primaryKeyField: 'id'),
        Object,
        null, // no column annotation -> fall back to declaredName
        null,
        null,
        null,
        Object,
        'fieldName',
        'fieldName',
      );
      expect(info.getQueryFieldName(), 'fieldName');
    });

    test('module exceptions are TomServerException subtypes', () {
      expect(
        TomQuerySyntaxException('k', 'm'),
        isA<TomServerException>(),
      );
      expect(
        TomAnnotationAnalyzerException('k', 'm'),
        isA<TomServerException>(),
      );
    });
  });
}

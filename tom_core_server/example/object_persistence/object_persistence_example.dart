/// Executable example for the object-persistence module of `tom_core_server`.
///
/// The repositories ([TomRepository], [MariadbRepository]) and the
/// query-sentence compiler need a reflected entity and a live data source, so
/// they are covered by `doc/object_persistence.md` rather than run here. This
/// example shows the connection-free surface: the [TomQueryBuilder] DSL and the
/// operator tree rendering SQL through a dialect.
///
/// Run with `dart run example/object_persistence/object_persistence_example.dart`.
/// The same behaviour is covered by `test/object_persistence_test.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// A trivial host for the [TomQueryBuilder] DSL.
class _Builder with TomQueryBuilder {}

/// Builds a [TomColumnInformation] for the `<table>.<column>` references.
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

void run() {
  final b = _Builder();
  final dialect = MariadbSqlDialect();

  // 1. Comparison of a column against a bound parameter.
  final ageCol = _column('users', 'age');
  final pred1 = b.gte(b.intF('age', ageCol), b.p<TomDbInt>('min'));
  print('1. ${pred1.generate(dialect)}'); // users.age >= :min
  assert(pred1.generate(dialect) == 'users.age >= :min');

  // 2. The parameter is collected for binding; the column is collected as a field.
  print('2. params=${pred1.getParameters(dialect)} '
      'fields=${pred1.getFields(dialect)}');
  assert(pred1.getParameters(dialect).contains('min'));
  assert(pred1.getFields(dialect).contains('users.age'));

  // 3. A compound predicate: (age >= :min) AND (name LIKE 'A%').
  final nameCol = _column('users', 'name');
  final pred3 = b.and([
    b.group(pred1),
    b.group(b.like(b.textF('name', nameCol), b.text('A%'))),
  ]);
  print('3. ${pred3.generate(dialect)}');
  assert(pred3.generate(dialect) ==
      "( users.age >= :min ) AND ( users.name LIKE 'A%' )");

  // 4. IN membership over integer literals.
  final pred4 = b.isIn(b.intF('age', ageCol), [b.intOp(18), b.intOp(21)]);
  print('4. ${pred4.generate(dialect)}'); // users.age IN (18,21)
  assert(pred4.generate(dialect) == 'users.age IN (18,21)');

  // 5. BETWEEN validates its arity: exactly two bounds, else it throws.
  try {
    b.between(b.intF('age', ageCol), [b.intOp(1)]); // only one bound
    print('5. ERROR: no exception thrown');
  } on TomQuerySyntaxException catch (e) {
    print('5. between with one bound threw ${e.key}');
    assert(e.key == 'between_expression.must_have_two_values');
  }

  // 6. The rest of the comparison family (<>, <, <=, >) alongside eq/gte.
  final pred6 = b.or([
    b.neq(b.intF('age', ageCol), b.intOp(0)),
    b.lt(b.intF('age', ageCol), b.intOp(18)),
    b.gt(b.intF('age', ageCol), b.intOp(65)),
  ]);
  print('6. ${pred6.generate(dialect)}');
  assert(pred6.generate(dialect) ==
      'users.age <> 0 OR users.age < 18 OR users.age > 65');

  // 7. Negated / regex string matching and a non-null test.
  final pred7 = b.and([
    b.isNotNull(b.textF('name', nameCol)),
    b.notLike(b.textF('name', nameCol), b.text('Z%')),
    b.regexp(b.textF('name', nameCol), b.text('^[A-M]')),
  ]);
  print('7. ${pred7.generate(dialect)}');
  assert(pred7.generate(dialect) ==
      "users.name IS NOT NULL AND users.name NOT LIKE 'Z%'"
          " AND users.name REGEXP '^[A-M]'");

  // 8. Typed literals: double/bool render bare, dates single-quoted (unpadded).
  print('8. double=${b.doubleOp(1.5).generate(dialect)} '
      'bool=${b.boolOp(true).generate(dialect)} '
      'date=${b.dateOp(DateTime(2026, 7, 5)).generate(dialect)}');
  assert(b.doubleOp(1.5).generate(dialect) == '1.5');
  assert(b.boolOp(true).generate(dialect) == 'true');
  assert(b.dateOp(DateTime(2026, 7, 5)).generate(dialect) == "'2026-7-5'");

  // 9. The dialect's objectOp turns any Dart value into its SQL literal by
  //    runtime type — the single entry point behind the literal builders.
  print('9. ${dialect.objectOp(null)} / ${dialect.objectOp("O'Brien")} / '
      '${dialect.objectOp([1, 2, 'a'])}');
  assert(dialect.objectOp(null) == 'NULL');
  assert(dialect.objectOp("O'Brien") == "'O''Brien'");
  assert(dialect.objectOp([1, 2, 'a']) == "1,2,'a'");

  print('\nObject-persistence example completed.');
}

void main() {
  run();
}

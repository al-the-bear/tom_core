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

  print('\nObject-persistence example completed.');
}

void main() {
  run();
}

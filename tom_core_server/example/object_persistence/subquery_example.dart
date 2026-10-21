/// Subqueries in a predicate — `EXISTS`, `NOT EXISTS`, `IN (SELECT …)` —
/// step by step, without a database.
///
/// Run with `dart run example/object_persistence/subquery_example.dart`.
///
/// A `TomSubquery` names the entities it reads and a predicate over their
/// columns. A column renders as `table.column`, so the predicate can name a
/// column of the enclosing query's table too — that is a correlated subquery.
/// The builder wraps one in `exists`, `notExists`, `isInSubquery` or
/// `isNotInSubquery`. Here a claim is matched against the patient records; the
/// same nodes run against MariaDB and PostgreSQL in
/// `test/query_associations_db_test.dart`, which also covers the query-sentence
/// form `<association>.<field>`. Every step checks its own result, and the run
/// fails when one does not hold.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';
import '../example_reflection.reflection.dart';
import 'object_persistence_entities.dart';

class _Builder with TomQueryBuilder {}

void main() {
  initializeReflection();
  final b = _Builder();
  final dialect = TomStandardSqlDialect();
  TomColumnInformation column(Type type, String field) =>
      TomAnnotationAnalyzer.determineColumn(field, [
        TomAnnotationAnalyzer.analysePersistentType(type),
      ]);
  final employee = b.textF('employee', column(ExampleClaimRecord, 'employee'));
  final patientName = b.textF('name', column(ExamplePatientRecord, 'name'));

  // 1. A correlated subquery: patients named like the claim's employee.
  final sameName = TomSubquery([
    ExamplePatientRecord,
  ], where: b.eq<TomDbString>(patientName, employee));
  final sub = sameName.generate(dialect);
  print('1. subquery                 : $sub');
  check(
    sub ==
        'SELECT 1 FROM example_patient WHERE '
            '(example_patient.name = example_claim.employee)',
    'the subquery names the enclosing table\'s column as it is',
  );

  // 2. EXISTS over it, as the WHERE of a claim query.
  final select = TomSelect([ExampleClaimRecord], query: b.exists(sameName));
  final sql = select.generateQuery(dialect);
  print('2. claims by a patient      : $sql');
  check(
    sql.contains(
      'FROM example_claim WHERE EXISTS (SELECT 1 FROM example_patient',
    ),
    'EXISTS sits in the claim query\'s WHERE',
  );

  // 3. NOT EXISTS is its negation.
  final none = b.notExists(sameName).generate(dialect);
  print('3. no such patient          : $none');
  check(none.startsWith('NOT EXISTS ('), 'notExists negates the test');

  // 4. IN (SELECT …) compares with the one column the subquery selects, and
  //    its parameters bind in the order they appear.
  final inWard = b.isInSubquery<TomDbString>(
    employee,
    TomSubquery(
      [ExamplePatientRecord],
      projection: patientName,
      where: b.eq<TomDbString>(
        b.textF('ward', column(ExamplePatientRecord, 'ward')),
        b.p<TomDbString>('ward'),
      ),
    ),
  );
  print('4. employee in a ward       : ${inWard.generate(dialect)}');
  check(
    inWard.generate(dialect) ==
            'example_claim.employee IN (SELECT example_patient.name FROM '
                'example_patient WHERE (example_patient.ward = :ward))' &&
        inWard.getParameters(dialect).join(',') == 'ward',
    'the subquery selects its projection and binds :ward',
  );

  // 5. A subquery is opaque to the walks over the enclosing tree: its columns
  //    are its own, so the enclosing query references only the claim column.
  print('5. fields the IN references : ${inWard.getFields(dialect)}');
  check(
    inWard.getFields(dialect).single == 'example_claim.employee' &&
        b.exists(sameName).getFields(dialect).isEmpty,
    'the inner columns do not count as the enclosing query\'s',
  );
}

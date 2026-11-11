/// Tests for [TomSqlTableQualification]: inside `run` the generated statements
/// name their tables qualified at every table position, and leave the columns
/// `table.column`; outside it they are unchanged.
///
/// Connection-free: the statements render through a dialect over the reflected
/// `FixtureTaskRecord`. The statements running on a tenant's connection
/// against a live database are tenant_table_db_test.dart's (TTB-2, TTB-5 …).
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart' show FixtureTaskRecord;
import 'fixtures/reflection_fixture.reflection.dart';

class _Builder with TomQueryBuilder {}

void main() {
  final b = _Builder();
  final dialect = MariadbSqlDialect();
  String qualify(String table) => '`sys`.$table';

  late TomQuerySentenceCompiler compiler;
  late TomOperator<TomDbBool> predicate;

  setUpAll(() {
    initializeReflection();
    compiler = TomQuerySentenceCompiler([FixtureTaskRecord]);
    predicate = b.gte(
      b.intF('priority', compiler.determineColumn('priority')),
      b.p<TomDbInt>('minPriority'),
    );
  });

  String inZone(TomQuery query) =>
      TomSqlTableQualification.run(qualify, () => query.generateQuery(dialect));

  test('TQ-1: outside run a table is its bare name', () {
    expect(TomSqlTableQualification.table('fixture_task'), 'fixture_task');
    expect(TomSqlTableQualification.isActive, isFalse);
    expect(
      TomSelect([FixtureTaskRecord], query: predicate).generateQuery(dialect),
      contains(' FROM fixture_task WHERE '),
    );
  });

  test('TQ-2: a select and a count name the table qualified in FROM and keep '
      'the columns table.column', () {
    final select = inZone(TomSelect([FixtureTaskRecord], query: predicate));
    expect(select, contains(' FROM `sys`.fixture_task WHERE '));
    expect(select, contains('fixture_task.priority'));
    expect(select, isNot(contains('`sys`.fixture_task.')));
    final count = inZone(TomCount([FixtureTaskRecord], query: predicate));
    expect(count, contains('AS count FROM `sys`.fixture_task WHERE '));
  });

  test('TQ-3: a delete and an update name the table qualified', () {
    expect(
      inZone(TomDelete([FixtureTaskRecord], query: predicate)),
      startsWith('DELETE FROM `sys`.fixture_task WHERE '),
    );
    expect(
      inZone(
        TomUpdate(
          [FixtureTaskRecord],
          query: predicate,
          set: {'title': b.p<TomDbString>('title')},
        ),
      ),
      startsWith('UPDATE `sys`.fixture_task SET title = '),
    );
  });

  test('TQ-4: run with null and code after run render unchanged', () {
    expect(
      TomSqlTableQualification.run(
        null,
        () => TomSqlTableQualification.table('fixture_task'),
      ),
      'fixture_task',
    );
    TomSqlTableQualification.run(qualify, () {
      expect(TomSqlTableQualification.isActive, isTrue);
    });
    expect(TomSqlTableQualification.table('fixture_task'), 'fixture_task');
  });
}

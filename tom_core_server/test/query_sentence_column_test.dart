/// Tests for how [TomQuerySentenceCompiler] types the **columns** named in a
/// query sentence.
///
/// A sentence addresses a column by name and the compiler has to decide which
/// `DbCol` node represents it. It decides twice: first from an explicit
/// `@TomDbColumn(columnType: ...)` when one is given, and otherwise from the
/// field's *declared Dart type*. The two paths are separate switches over
/// separate values, so a type can be handled by one and not the other — and
/// a `DateTime` field with no explicit `columnType` must not fall through the
/// declared-type switch and leave the compiler reporting it as untypeable.
///
/// Connection-free: only the entity's annotations are read, so
/// [FixtureExportRecord] needs no table. It is the fixture used here rather
/// than `FixtureTaskRecord` because it declares all five column families — and
/// in particular a `DateTime`, which the task fixture does not have. That
/// absence is why the bug survived the existing suites.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart' show FixtureExportRecord;
import 'fixtures/reflection_fixture.reflection.dart';

void main() {
  late TomQuerySentenceCompiler compiler;
  final dialect = MariadbSqlDialect();

  setUpAll(() {
    initializeReflection();
    compiler = TomQuerySentenceCompiler([FixtureExportRecord]);
  });

  TomSelect select(String sentence) =>
      compiler.compileQuerySentence(sentence) as TomSelect;

  group('column typing from the declared Dart type', () {
    // One test per column family, because the defect was a single missing
    // `return` in one arm of the switch: a test that only proved *some* column
    // compiles would have passed throughout.
    test('a String column compiles', () {
      expect(
        select('find by title = :title').generateQuery(dialect),
        contains('fixture_export.title = :title'),
      );
    });

    test('an int column compiles', () {
      expect(
        select('find by id > :id').generateQuery(dialect),
        contains('fixture_export.id > :id'),
      );
    });

    test('a bool column compiles', () {
      expect(
        select('find by done = :done').generateQuery(dialect),
        contains('fixture_export.done = :done'),
      );
    });

    test('a DateTime column compiles', () {
      // The regression. Before the fix the `DateTime` arm constructed its
      // `DateTimeCol` and discarded it, so control fell out of the switch and
      // into the "could not determine type" throw — making any sentence with a
      // timestamp predicate uncompilable unless the entity spelled out
      // `columnType:` by hand.
      expect(
        select('find by created_at >= :from').generateQuery(dialect),
        contains('fixture_export.created_at >= :from'),
      );
    });

    test('a TomZonedDate column compiles', () {
      expect(
        select('find by tag_day = :day').generateQuery(dialect),
        contains('fixture_export.tag_day = :day'),
      );
    });

    test('a DateTime column orders and ranges in one sentence', () {
      // The shape the ops server's report query actually uses: a half-open
      // window plus an ordering on the same timestamp column. Asserted as a
      // whole because the column node is built once per *mention*, so a
      // sentence naming it three times exercises three call sites.
      final query = select(
        'find by created_at >= :from and created_at < :to order by created_at',
      ).generateQuery(dialect);
      expect(query, contains('fixture_export.created_at >= :from'));
      expect(query, contains('fixture_export.created_at < :to'));
      expect(query, contains('ORDER BY fixture_export.created_at'));
    });

    test('an unknown column is still rejected', () {
      // The throw the fix must not remove: falling through remains an error,
      // it just no longer catches a type the switch was written to handle.
      expect(
        () => compiler.compileQuerySentence('find by nosuch = :x'),
        throwsA(isA<TomServerException>()),
      );
    });
  });
}

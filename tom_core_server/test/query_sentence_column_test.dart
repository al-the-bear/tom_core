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

    test('a double column compiles', () {
      // The second occurrence of the same defect, in a different family: the
      // declared-type switch enumerated String/int/bool/DateTime/TomZonedDate
      // and simply omitted `double`, so a decimal column was untypeable no
      // matter how it was written. `DoubleCol` existed and `_createAggregate`
      // already had an arm for it — nothing could ever produce one.
      expect(
        select('find by amount > :amount').generateQuery(dialect),
        contains('fixture_export.amount > :amount'),
      );
    });

    test('a bool column compiles', () {
      expect(
        select('find by done = :done').generateQuery(dialect),
        contains('fixture_export.done = :done'),
      );
    });

    test('a DateTime column compiles', () {
      // The arm that is easiest to get wrong: construct the `DateTimeCol` and
      // omit the return, and control falls out of the switch into the "could
      // not determine type" throw — making any sentence with a timestamp
      // predicate uncompilable unless the entity spells out `columnType:` by
      // hand. Nothing in the arm itself looks incomplete.
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
      //
      // The refusal comes from the annotation analyzer rather than the
      // compiler: naming a column is the one thing in a sentence the compiler
      // cannot decide alone, so it asks the entity's annotations and reports
      // what they answer.
      expect(
        () => compiler.compileQuerySentence('find by nosuch = :x'),
        throwsA(isA<TomAnnotationAnalyzerSyntaxException>()),
      );
    });
  });

  // Typing a column is only the first of three switches a predicate passes
  // through: the column node, the bind parameter, and the comparison that
  // joins them each dispatch on the type independently. `double` was absent
  // from all three, so proving one arm reachable proves nothing about the
  // next — hence one test per operator rather than one per type.
  group('double columns across the predicate forms', () {
    test('every comparison operator accepts a double column', () {
      for (final (symbol, sentence) in const [
        ('=', 'find by amount = :amount'),
        ('<>', 'find by amount <> :amount'),
        ('<', 'find by amount < :amount'),
        ('<=', 'find by amount <= :amount'),
        ('>', 'find by amount > :amount'),
        ('>=', 'find by amount >= :amount'),
      ]) {
        expect(
          select(sentence).generateQuery(dialect),
          contains('fixture_export.amount $symbol :amount'),
          reason: 'the $symbol comparison should type a double column',
        );
      }
    });

    test('a double column binds its parameter as a decimal', () {
      // The parameter's *type* is what carries the value across the bind
      // boundary; typing it as text or int would round-trip a decimal wrong
      // even where the SQL looks right. Asserted on the node, because the
      // rendered `:amount` is identical for every family.
      final query = select('find by amount >= :floor');
      expect(query.getParameters(dialect), ['floor']);
      expect(query.query, isA<Gte<TomDbDouble>>());
    });

    test('a double column takes IS NULL and IS NOT NULL', () {
      expect(
        select('find by amount is null').generateQuery(dialect),
        contains('fixture_export.amount IS NULL'),
      );
      expect(
        select('find by amount is not null').generateQuery(dialect),
        contains('fixture_export.amount IS NOT NULL'),
      );
    });

    test('a double column takes IS IN', () {
      expect(
        select('find by amount is in ( :a , :b )').generateQuery(dialect),
        contains('fixture_export.amount IN (:a,:b)'),
      );
    });

    test('a double column orders and combines with another predicate', () {
      final query = select(
        'find by amount >= :floor and done = :done order by amount desc',
      ).generateQuery(dialect);
      expect(query, contains('fixture_export.amount >= :floor'));
      expect(query, contains('ORDER BY fixture_export.amount DESC'));
    });
  });

  // The aggregate switch dispatches on the *node* `_createColumn` produced, so
  // its `DoubleCol` arm was unreachable for as long as nothing could build one:
  // dead code that looked handled. These are what make it live.
  group('aggregates over a double column', () {
    test('min over a double column yields a double-typed aggregate', () {
      final query =
          compiler.compileQuerySentence(
                'group min ( amount ) as lo over done by id > 0',
              )
              as TomGroupedSelect;
      expect(query.aggregates.single, isA<Min<TomDbDouble, double>>());
      expect(
        query.generateQuery(dialect),
        contains('MIN(fixture_export.amount) AS lo'),
      );
    });

    test('max over a double column yields a double-typed aggregate', () {
      final query =
          compiler.compileQuerySentence(
                'group max ( amount ) as hi over done by id > 0',
              )
              as TomGroupedSelect;
      expect(query.aggregates.single, isA<Max<TomDbDouble, double>>());
      expect(query.aggregates.single.valueType, double);
    });
  });
}

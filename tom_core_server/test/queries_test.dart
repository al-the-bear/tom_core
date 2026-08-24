/// Tests for what a [TomQuery] reports about itself — the parameters it binds
/// and the fields it references — across the two kinds of statement the module
/// builds: [TomGeneratedQuery], which derives both from its operator tree, and
/// [TomLiteralSelect], which wraps SQL it cannot analyse.
///
/// Connection-free: the statements render through a dialect and are built over
/// the reflected `FixtureTaskRecord`, so no MariaDB is needed. The round-trip
/// through a live server is the DB-tagged suite's job.
library;

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.dart' show FixtureTaskRecord;
import 'fixtures/reflection_fixture.reflection.dart';

/// A trivial host for the [TomQueryBuilder] DSL.
class _Builder with TomQueryBuilder {}

void main() {
  final b = _Builder();
  final dialect = MariadbSqlDialect();

  group('what a statement reports about itself', () {
    late TomQuerySentenceCompiler compiler;

    setUpAll(() {
      initializeReflection();
      compiler = TomQuerySentenceCompiler([FixtureTaskRecord]);
    });

    /// A hand-written statement over the reflected entity, naming real columns
    /// in its text and declaring two parameters.
    ///
    /// Deliberately over-specified: the entity's columns, the declared
    /// parameter names, and the column names appearing in the SQL text are
    /// three *different* non-empty sets, so an implementation that guesses at
    /// any of them is visible rather than accidentally right.
    TomLiteralSelect literal() => TomLiteralSelect(
      [FixtureTaskRecord],
      query:
          'SELECT title FROM fixture_task '
          'WHERE done = :done AND priority > :minPriority',
      parameters: ['done', 'minPriority'],
    );

    test('a literal statement binds the parameters it declares', () {
      expect(literal().getParameters(dialect), ['done', 'minPriority']);
    });

    test('a literal statement reports no fields — they are not derivable', () {
      // Empty means "this statement cannot say", not "this statement reads
      // nothing": the SQL above plainly references `title`, `done` and
      // `priority`. Nothing parses that text, so the honest answer is the
      // empty set — see the override's dartdoc.
      expect(literal().getFields(dialect), isEmpty);
    });

    test('a generated query over the same entity does report its fields', () {
      // The contrast that gives the empty set above its meaning: fields are
      // reported when — and only when — there is an operator tree to read them
      // off. Both statements select from the same table over the same entity.
      final select = TomSelect(
        [FixtureTaskRecord],
        query: b.gte(
          b.intF('priority', compiler.determineColumn('priority')),
          b.p<TomDbInt>('minPriority'),
        ),
      );
      expect(select.getFields(dialect), {'fixture_task.priority'});
      expect(select.getParameters(dialect), ['minPriority']);
    });
  });
}

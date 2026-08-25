/// Tests for the **right-hand side of a comparison against a boolean column** —
/// where it ends, and whether the six comparison operators agree about that.
///
/// The six builders share one dispatch, but the dispatch used to take a flag:
/// `=` and `<>` parsed a boolean operand with `_buildQuery`, the statement-level
/// entry point, while `<`, `<=`, `>` and `>=` parsed it with `_buildExpression`,
/// the operand-level one. The comment on the flag said the difference was
/// deliberate — that `=` accepted `done = ( a > 1 or b > 2 )`, a comparison
/// against a whole predicate, and that collapsing it would widen what `<`
/// accepts.
///
/// Neither half of that was true. The grouped form it named has never compiled
/// (`_buildQuery` threads the boolean column through the bracket, so the first
/// column inside is read as a second operand of that column's type and refused),
/// and what the flag actually bought was a right-hand side that does not stop:
/// `_buildQuery` reads `and`, `or` and `)` as its own, so
///
///   * `done = TRUE and id > 2` was **refused** — the conjunction was pulled
///     into the operand and `id` was then read as a boolean column;
///   * `not ( done = TRUE ) and id > 2` was **mis-compiled** to
///     `NOT ( done = true AND id > 2 )` — the closing bracket was consumed by
///     the `=`, so the group closed one conjunct too late and the negation
///     covered both. `NOT (A AND B)` is not `NOT (A) AND B`; that sentence
///     returned rows it excluded.
///
/// The second is the reason these assertions are on rendered SQL rather than on
/// "it compiles": a swallowed bracket leaves a statement that is still
/// well-formed and still plausible.
///
/// The same sentences with `>` in place of `=` were correct throughout, which
/// is what makes the pairs below the sharpest form of the test: one column, one
/// shape, six operators, one answer.
///
/// Connection-free: only the entity's annotations are read, so
/// [FixtureExportRecord] needs no table.
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

  /// The `WHERE …` tail of the compiled statement, which is the part every
  /// assertion here is about.
  String where(String sentence) {
    final sql = compiler.compileQuerySentence(sentence).generateQuery(dialect);
    return sql.substring(sql.indexOf('WHERE'));
  }

  /// The six comparison operators, as they are written in a sentence and as the
  /// dialect renders them. Every test in the first three groups runs over all
  /// six, because a divergence between them is exactly what is being pinned —
  /// asserting one operator would leave the other five free to differ.
  const operators = <(String, String)>[
    ('=', '='),
    ('<>', '<>'),
    ('<', '<'),
    ('<=', '<='),
    ('>', '>'),
    ('>=', '>='),
  ];

  group('a boolean operand ends at the comparison, for all six operators', () {
    test('a conjunction after it is a conjunction, not part of it', () {
      for (final (written, rendered) in operators) {
        expect(
          where('find by done $written TRUE and id > 2'),
          'WHERE fixture_export.done $rendered true AND fixture_export.id > 2',
          reason: 'the AND after a [$written] comparison should survive',
        );
      }
    });

    test('a disjunction after it is a disjunction', () {
      for (final (written, rendered) in operators) {
        expect(
          where('find by done $written TRUE or id > 2'),
          'WHERE fixture_export.done $rendered true OR fixture_export.id > 2',
          reason: 'the OR after a [$written] comparison should survive',
        );
      }
    });

    test('a bound parameter operand ends at the comparison too', () {
      // The documented style binds rather than inlines, so this is the shape a
      // reader following `doc/object_persistence.md` would write first — and
      // `done = :flag and …` was refused just as `done = TRUE and …` was.
      for (final (written, rendered) in operators) {
        expect(
          where('find by done $written :flag and id > 2'),
          'WHERE fixture_export.done $rendered :flag AND fixture_export.id > 2',
          reason: 'a bound [$written] operand should end at the comparison',
        );
      }
    });

    test('a second boolean comparison is a second predicate', () {
      // This one rendered correctly even with the flag, and is here as a guard
      // rather than as a repair: `=` built `done = (true AND done = false)`,
      // but SQL binds `=` tighter than `AND`, so the wrong tree printed as the
      // right statement. The node was still wrong — which is why the bracketed
      // cases below, where SQL's precedence cannot undo it, are the ones that
      // showed the defect.
      for (final (written, rendered) in operators) {
        expect(
          where('find by done $written TRUE and done = FALSE'),
          'WHERE fixture_export.done $rendered true AND '
          'fixture_export.done = false',
          reason: 'two boolean predicates should not collapse into one',
        );
      }
    });
  });

  group('a group closes where it was written', () {
    test('a bracket closing after a boolean comparison is not consumed', () {
      for (final (written, rendered) in operators) {
        expect(
          where('find by ( done $written TRUE ) and id > 2'),
          'WHERE ( fixture_export.done $rendered true ) AND '
          'fixture_export.id > 2',
          reason: 'the group around a [$written] comparison should close early',
        );
      }
    });

    test('a negated group covers only what it encloses', () {
      // The mis-compilation that changes meaning. With the bracket consumed by
      // the comparison the group closed after `id > 2` instead, and the `NOT`
      // then covered the conjunction: `NOT ( done = true AND id > 2 )` rather
      // than `NOT ( done = true ) AND id > 2`. The two disagree on every row
      // where `done` is true and `id > 2` is false.
      for (final (written, rendered) in operators) {
        expect(
          where('find by not ( done $written TRUE ) and id > 2'),
          'WHERE NOT ( fixture_export.done $rendered true ) AND '
          'fixture_export.id > 2',
          reason: 'the NOT should cover the [$written] comparison alone',
        );
      }
    });

    test('a boolean comparison inside a group keeps the group intact', () {
      for (final (written, rendered) in operators) {
        expect(
          where('find by ( done $written TRUE or id > 2 ) and amount > 1.5'),
          'WHERE ( fixture_export.done $rendered true OR '
          'fixture_export.id > 2 ) AND fixture_export.amount > 1.5',
          reason: 'a [$written] comparison should not swallow its own group',
        );
      }
    });
  });

  group('a boolean column is compared like any other column', () {
    test('the plain comparison is unchanged', () {
      for (final (written, rendered) in operators) {
        expect(
          where('find by done $written TRUE'),
          'WHERE fixture_export.done $rendered true',
        );
      }
    });

    test('an int column in the same shapes renders the same way', () {
      // The control. These sentences were always correct, because an int
      // operand never routed through `_buildQuery` — so they say what the
      // boolean ones above should have said all along.
      expect(
        where('find by not ( id > 2 ) and done = TRUE'),
        'WHERE NOT ( fixture_export.id > 2 ) AND fixture_export.done = true',
      );
      expect(
        where('find by ( id > 2 ) and done = TRUE'),
        'WHERE ( fixture_export.id > 2 ) AND fixture_export.done = true',
      );
    });

    test('the boolean forms that already worked still work', () {
      expect(
        where('find by not done = TRUE'),
        'WHERE NOT fixture_export.done = true',
      );
      expect(
        where('find by done is null and id > 2'),
        'WHERE fixture_export.done IS NULL AND fixture_export.id > 2',
      );
      expect(
        where('find by id > 2 and done = TRUE'),
        'WHERE fixture_export.id > 2 AND fixture_export.done = true',
      );
    });
  });

  group('a bracket is not an operand', () {
    // `done = ( id > 2 )` is the form the removed flag claimed to support. It
    // never compiled; what it did was reach the column resolver with `(` as a
    // field name, which answers from the *annotation analyzer* — outside the
    // exception family this compiler documents — naming a column the author
    // never wrote. It is refused here as a query-syntax error instead, for
    // every column type, since nothing about the failure is boolean-specific.
    for (final sentence in const [
      'find by done = ( id > 2 )',
      'find by done <> ( id > 2 )',
      'find by id = ( 2 )',
      'find by title = ( )',
      'find by amount > ( 1.5 )',
    ]) {
      test('[$sentence]', () {
        expect(
          () => compiler.compileQuerySentence(sentence),
          throwsA(
            isA<TomQuerySyntaxException>().having(
              (e) => e.key,
              'key',
              contains('build_expression.separator_in_operand_position'),
            ),
          ),
        );
      });
    }
  });
}

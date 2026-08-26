/// Tests for `NOT` in a query sentence — both the standalone negation and the
/// two token pairs where `NOT` belongs to the operator that follows it.
///
/// `NOT` is ambiguous on sight: in `not done = TRUE` it negates whatever comes
/// next, but in `title not like :p` it is half of `NOT LIKE`, and in
/// `title is not null` it is the middle of `IS NOT NULL`. The compiler resolves
/// this by ordering — the branches that claim a pair are tried before the one
/// that treats `NOT` as standalone — so the tests below compile each form in
/// several positions and check which node it produced.
///
/// The truncated sentences at the end are the other half of the contract: a
/// keyword with nothing after it is a *syntax error*, and must arrive as one.
/// A `NOT` at the very end of a sentence used to escape as a `RangeError` from
/// the lookahead's bounds check, which no caller of this library is watching
/// for.
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

  String sql(String sentence) =>
      (compiler.compileQuerySentence(sentence) as TomSelect).generateQuery(
        dialect,
      );

  group('NOT LIKE is claimed as one operator wherever it appears', () {
    // The positions differ in *which parser* sees the `NOT`: at the top level
    // and inside parentheses the sentence is walked by the query parser, after
    // a column by the expression parser. Each has its own `NOT` branch, so the
    // same phrase has to be claimed correctly by both.
    test('at the top level', () {
      expect(
        sql('find by title not like :p'),
        contains('fixture_export.title NOT LIKE :p'),
      );
    });

    test('inside a parenthesised expression', () {
      expect(
        sql('find by ( title not like :p )'),
        contains('( fixture_export.title NOT LIKE :p )'),
      );
    });

    test('as the right-hand side of an AND', () {
      expect(
        sql('find by id > 1 and title not like :p'),
        contains('fixture_export.id > 1 AND fixture_export.title NOT LIKE :p'),
      );
    });

    test('inside parentheses on the right-hand side of an AND', () {
      expect(
        sql('find by id > 1 and ( title not like :p )'),
        contains(
          'fixture_export.id > 1 AND ( fixture_export.title NOT LIKE :p )',
        ),
      );
    });

    test(
      'a parenthesised NOT LIKE renders as the unparenthesised one does',
      () {
        // The claim the report made: that the two positions disagree. They do
        // not — asserted as an equality so the two can never drift apart
        // silently, whichever of them a later change touches.
        final bare = sql('find by title not like :p');
        final wrapped = sql('find by ( title not like :p )');
        expect(wrapped.replaceAll('( ', '').replaceAll(' )', ''), bare);
      },
    );
  });

  group('IS NOT NULL is claimed as one operator wherever it appears', () {
    test('at the top level', () {
      expect(
        sql('find by title is not null'),
        contains('fixture_export.title IS NOT NULL'),
      );
    });

    test('inside a parenthesised expression', () {
      expect(
        sql('find by ( title is not null )'),
        contains('( fixture_export.title IS NOT NULL )'),
      );
    });
  });

  group('a standalone NOT negates what follows', () {
    test('at the top level', () {
      expect(
        sql('find by not done = TRUE'),
        contains('NOT fixture_export.done = true'),
      );
    });

    test('inside a parenthesised expression', () {
      expect(
        sql('find by ( not done = TRUE )'),
        contains('( NOT fixture_export.done = true )'),
      );
    });

    test('twice is refused', () {
      expect(
        () => compiler.compileQuerySentence('find by not not done = TRUE'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            contains('double_not_usage'),
          ),
        ),
      );
    });
  });

  group('a sentence that stops at a keyword raises a syntax error', () {
    // Every one of these ends where the parser is about to look at the *next*
    // token. The lookahead's bounds check was off by one, so instead of
    // declining it read past the end and threw `RangeError` — outside the
    // `TomServerException` family every caller of this library catches on, and
    // carrying no indication of which sentence was at fault.
    //
    // The two lists below both satisfy that, and they are split because they
    // satisfy it by different routes — which only became visible once these
    // assertions named a type instead of the base class. The parser refuses the
    // first three itself. It does not refuse the other two at all: it takes the
    // dangling keyword for a column name and hands it to the annotation
    // analyzer, which fails to find a field called `is`. The sentence is
    // rejected either way, so the RangeError guarantee holds — but the second
    // list is rejected by a component that does not know it is parsing.
    for (final sentence in const [
      'find by title not',
      'find by not',
      'find by title not like',
    ]) {
      test('[$sentence]', () {
        expect(
          () => compiler.compileQuerySentence(sentence),
          throwsA(isA<TomQuerySyntaxException>()),
          reason: 'a truncated sentence must not escape as a RangeError',
        );
      });
    }

    for (final sentence in const ['find by title is', 'find by title is not']) {
      test('[$sentence] — via column lookup, not the parser', () {
        expect(
          () => compiler.compileQuerySentence(sentence),
          throwsA(isA<TomAnnotationAnalyzerSyntaxException>()),
          reason: 'the trailing IS is read as a column name and not found',
        );
      });
    }
  });

  group('NOT NULL without IS is refused', () {
    test('the pair is only an operator after IS', () {
      // `NOT` declines to negate when `NULL` follows it, because `NOT NULL` is
      // the tail of `IS NOT NULL` and never a negation of a column called
      // `null`. Without `IS` in front the sentence is simply malformed.
      //
      // Refused, but by the same indirect route as the two truncations above:
      // having declined to negate, the parser reads `not` as the column being
      // compared, and the annotation analyzer reports no field of that name.
      expect(
        () => compiler.compileQuerySentence('find by title not null'),
        throwsA(isA<TomAnnotationAnalyzerSyntaxException>()),
      );
    });
  });
}

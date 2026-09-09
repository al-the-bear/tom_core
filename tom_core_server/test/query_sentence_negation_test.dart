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
    // All of them are refused by the parser, which is a stronger claim than
    // "refused". A keyword the parser declines to read as an operator is not
    // then read as a column name: `find by title is` says the sentence stops
    // one token early, not that the entity is missing a field called `is`.
    for (final sentence in const [
      'find by title not',
      'find by not',
      'find by title not like',
      'find by title is',
      'find by title is not',
    ]) {
      test('[$sentence]', () {
        expect(
          () => compiler.compileQuerySentence(sentence),
          throwsA(isA<TomQuerySyntaxException>()),
          reason: 'a truncated sentence must not escape as a RangeError',
        );
      });
    }

    test('the diagnostic names the keyword, not a missing column', () {
      // The fault this group is really about. Having declined to read `IS` as
      // an operator, the parser used to fall through and treat the dangling
      // keyword as the name of the column being compared — so the developer
      // was told "No column match field [is] found. Must be a variable and
      // must have @TomDbColumn annotation." and went looking for a field they
      // never wrote. The sentence was rejected, which is why nothing caught
      // this for so long; it was rejected with the wrong reason.
      expect(
        () => compiler.compileQuerySentence('find by title is'),
        throwsA(
          isA<TomQuerySyntaxException>()
              .having(
                (e) => e.key,
                'key',
                'query_sentence_compiler.build_expression.'
                    'keyword_in_operand_position',
              )
              .having(
                (e) => e.defaultUserMessage,
                'message',
                allOf(
                  // The author's own spelling, not a canonicalised `IS`: the
                  // reader is scanning the sentence they wrote.
                  contains('[is]'),
                  contains('find by title is'),
                  isNot(contains('@TomDbColumn')),
                ),
              ),
        ),
      );
    });

    test('a keyword mid-sentence is refused the same way', () {
      // Not every one of these is a truncation. `find by title = and` stops
      // nowhere — it has a token after the operator — and that token is still
      // a keyword standing where an operand belongs. One rule covers both,
      // which is why the check is on the token's position rather than on the
      // sentence's length.
      expect(
        () => compiler.compileQuerySentence('find by title = and'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.build_expression.'
                'keyword_in_operand_position',
          ),
        ),
      );
    });

    for (final keyword in const [
      'is',
      'not',
      'null',
      'like',
      'regexp',
      'in',
      'and',
      'or',
    ]) {
      test('[$keyword] is reserved in operand position', () {
        // The whole reserved set, each in a position where the operator
        // branches have already declined it. A keyword missing from the set is
        // one the annotation analyzer answers for, which is the defect this
        // group exists to prevent — so the set is asserted rather than sampled.
        expect(
          () => compiler.compileQuerySentence('find by title = $keyword'),
          throwsA(isA<TomQuerySyntaxException>()),
          reason: '[$keyword] must not reach the column resolver',
        );
      });
    }

    test('a name that is not a keyword still reaches the column resolver', () {
      // The converse, and the boundary that keeps the rule honest. Reserving
      // keywords must not turn every unknown name into a syntax error: an
      // entity that really is missing a field should still be told so, by the
      // component that knows about fields.
      expect(
        () => compiler.compileQuerySentence('find by nosuch = :x'),
        throwsA(isA<TomAnnotationAnalyzerSyntaxException>()),
        reason:
            'an ordinary unknown name is a column question, not a syntax '
            'one',
      );
    });
  });

  group('NOT NULL without IS is refused', () {
    test('the pair is only an operator after IS', () {
      // `NOT` declines to negate when `NULL` follows it, because `NOT NULL` is
      // the tail of `IS NOT NULL` and never a negation of a column called
      // `null`. Without `IS` in front the sentence is simply malformed, and the
      // parser says so rather than asking the entity about a field called
      // `not`.
      expect(
        () => compiler.compileQuerySentence('find by title not null'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.build_expression.'
                'keyword_in_operand_position',
          ),
        ),
      );
    });
  });

  group('an analyzer failure is never surfaced to the client', () {
    // Both analyzer exception types quote the deployment back at whoever
    // reached them: entity type names, `@TomDbColumn` requirements, whether a
    // type is registered with the reflector. All of it is a developer wiring
    // fault, none of it is anything a caller can act on, and a sentence
    // compiled inside a served request would otherwise carry it to that
    // caller.
    //
    // `clientThrow` is not a constructor parameter on either type, so this is
    // an invariant of the type rather than a default a raise site could ask to
    // override — the same construction, and for the same reason, as
    // `TomResourceLocaleException`.
    test('a syntax failure is not client-visible', () {
      expect(
        TomAnnotationAnalyzerSyntaxException('a.b.c', 'm').clientThrow,
        isFalse,
      );
    });

    test('an analyzer failure is not client-visible', () {
      expect(TomAnnotationAnalyzerException('a.b.c', 'm').clientThrow, isFalse);
    });

    test('a query syntax error still is', () {
      // The contrast that makes the pair above a decision rather than a habit.
      // A malformed sentence is the caller's own input when the sentence came
      // from a request, and naming the keyword that broke it tells them what to
      // fix without describing the deployment.
      expect(TomQuerySyntaxException('a.b.c', 'm').clientThrow, isTrue);
    });
  });
}

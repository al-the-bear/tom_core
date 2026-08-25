/// Tests for the `IS IN ( … )` list — how it ends, and what the parser hands
/// back to whatever follows it.
///
/// The list is scanned by `_getInOptions`, which walks forward looking for the
/// closing bracket. Three separate things went wrong at that boundary, and the
/// last of them is the reason this file exists rather than a single test:
///
///  * the scan had no upper bound, so an unclosed list walked off the end of
///    the token list and threw a raw `RangeError` — outside the
///    `TomQuerySyntaxException` family this module documents as covering every
///    rejection, and reaching a caller as an internal error rather than a bad
///    request, which matters because a sentence can come from a request
///    parameter;
///  * an empty list was accepted and rendered as `IN ()`, which no SQL dialect
///    parses — the sentence was refused by the *database*, one layer too late
///    and with a message about SQL the author never wrote;
///  * `_createIsIn` reported one token more than it consumed. The index
///    contract in this parser is "the last token I consumed" (`IS NULL`
///    returns the index of `null`), but the `IN` builder added one to the
///    closing bracket. The token after the list was therefore skipped — and
///    when that token was `and`, the conjunction was never seen and
///    `find by id is in ( 1 , 2 ) and done = TRUE` silently compiled to
///    `WHERE done = true`, dropping the `IN` filter entirely.
///
/// That last one is why the "still compiles" group below asserts the *whole*
/// rendered predicate rather than `contains`: a dropped conjunct is invisible
/// to a containment check on the surviving half.
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

  void expectRefused(String sentence, String keySuffix) {
    expect(
      () => compiler.compileQuerySentence(sentence),
      throwsA(
        isA<TomQuerySyntaxException>().having(
          (e) => e.key,
          'key',
          contains(keySuffix),
        ),
      ),
      reason: 'a malformed IS IN list must not escape as a RangeError',
    );
  }

  group('a well-formed list still compiles', () {
    test('literals', () {
      expect(
        where('find by id is in ( 1 , 2 )'),
        'WHERE fixture_export.id IN (1,2)',
      );
    });

    test('parameters', () {
      expect(
        where('find by title is in ( :a , :b )'),
        'WHERE fixture_export.title IN (:a,:b)',
      );
    });

    test('a single element', () {
      expect(where('find by id is in ( 1 )'), 'WHERE fixture_export.id IN (1)');
    });

    test('negated', () {
      expect(
        where('find by id is not in ( 1 , 2 )'),
        'WHERE NOT fixture_export.id IN (1,2)',
      );
    });
  });

  group('the token after the list is not swallowed', () {
    // Each of these asserts the full predicate. The `IN` used to disappear
    // here, leaving a query that returned rows the sentence excluded — the
    // most consequential of the three defects, because it produced a
    // *plausible* statement rather than an error.
    test('AND after a list keeps both sides', () {
      expect(
        where('find by id is in ( 1 , 2 ) and done = TRUE'),
        'WHERE fixture_export.id IN (1,2) AND fixture_export.done = true',
      );
    });

    test('OR after a list keeps both sides', () {
      expect(
        where('find by id is in ( 1 , 2 ) or done = TRUE'),
        'WHERE fixture_export.id IN (1,2) OR fixture_export.done = true',
      );
    });

    test('AND after a negated list keeps both sides', () {
      expect(
        where('find by id is not in ( 1 , 2 ) and done = TRUE'),
        'WHERE NOT fixture_export.id IN (1,2) AND fixture_export.done = true',
      );
    });

    test('a single-element list is no different', () {
      // The overshoot was one fixed token, so it did not depend on the list's
      // length — pinned here because a length-dependent reading of the bug
      // would be the natural wrong guess.
      expect(
        where('find by id is in ( 1 ) and done = TRUE'),
        'WHERE fixture_export.id IN (1) AND fixture_export.done = true',
      );
    });

    test('a list on the right-hand side of an AND still works', () {
      // This side always worked: with the list last, the overshoot ran off the
      // end of the sentence where the loop stopped anyway. Kept so the two
      // orders are asserted together.
      expect(
        where('find by title = :t and id is in ( 1 , 2 )'),
        'WHERE fixture_export.title = :t AND fixture_export.id IN (1,2)',
      );
    });

    test('a list on both sides of an AND', () {
      expect(
        where('find by id is in ( 1 , 2 ) and title is in ( :a , :b )'),
        'WHERE fixture_export.id IN (1,2) AND fixture_export.title IN (:a,:b)',
      );
    });

    test('order by after a list is still read', () {
      // The clause is stripped before the predicate is parsed, so this is a
      // different path from the AND above — but it is the same question: does
      // what follows the bracket survive?
      final sql = compiler
          .compileQuerySentence(
            'find by id is in ( 1 , 2 ) order by title desc',
          )
          .generateQuery(dialect);
      expect(sql, contains('fixture_export.id IN (1,2)'));
      expect(sql, contains('ORDER BY'));
    });
  });

  group('an unterminated list is refused', () {
    for (final sentence in const [
      'find by id is in ( 1 , 2',
      'find by id is in ( 1',
      'find by id is in (',
      'find by id is not in ( 1 , 2',
      'find by title is in ( :a , :b',
    ]) {
      test('[$sentence]', () {
        expectRefused(sentence, 'get_in_options.unterminated_list');
      });
    }
  });

  group('an empty list is refused', () {
    // `IN ()` is not valid SQL anywhere, so the old rendering could only ever
    // fail — at the database, about a statement the author did not write.
    test('nothing between the brackets', () {
      expectRefused('find by id is in ( )', 'get_in_options.empty_list');
    });

    test('only a comma between the brackets', () {
      expectRefused('find by id is in ( , )', 'get_in_options.empty_list');
    });

    test('negated, which reaches the same scan', () {
      expectRefused('find by id is not in ( )', 'get_in_options.empty_list');
    });
  });

  group('a boolean column is still refused', () {
    test('IN over two possible values is a predicate written the long way', () {
      expectRefused(
        'find by done is in ( TRUE , FALSE )',
        'get_in_options.boolean_column_in_not_allowed',
      );
    });
  });
}

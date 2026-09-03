/// Tests for **quoted string literals** in a query sentence — what a pair of
/// `'…'` may contain, and how an apostrophe is written inside one.
///
/// The tokeniser used to insert spaces around every `,()=<>` and then split the
/// sentence on whitespace, with no notion of a quoted region. A literal was
/// therefore only writable if it happened to contain none of those characters
/// and no space: `title = 'in progress, phase (2)'` became eight tokens, the
/// first of them `'in`, and the failure that came back named a column
/// `['in]` — a fragment the author never wrote, reported by the annotation
/// analyzer rather than as a query-syntax error.
///
/// Two consequences, and the second is the reason this file asserts rendered
/// SQL rather than just "it compiles":
///
///  * a literal containing a space, comma, bracket or comparison sign was
///    unwritable — a loud failure, but about the wrong thing;
///  * `'O''Brien'` *did* compile, because it has no space to split on, and
///    silently produced `'O''''Brien'` — the sentence-level doubling was never
///    decoded, so the dialect escaped it a second time and the value gained an
///    apostrophe it never had. That one is a mis-compilation rather than a
///    rejection, which is the worse shape for a parser defect.
///
/// The escape is the SQL one: an apostrophe inside a literal is written by
/// doubling it. The parser decodes `''` back to `'`, and the *dialect* re-escapes
/// it on the way to SQL — the two layers are separate, which is why the expected
/// SQL below still shows a doubled quote.
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
      reason: 'a malformed literal must be refused as a query-syntax error',
    );
  }

  group('a quoted literal is one token whatever it contains', () {
    test('the sentence from the report compiles with the literal intact', () {
      // Space, comma and both brackets in one literal — the case the old
      // tokeniser turned into eight tokens.
      expect(
        where("find by title = 'in progress, phase (2)'"),
        "WHERE fixture_export.title = 'in progress, phase (2)'",
      );
    });

    test('a space does not split it', () {
      expect(
        where("find by title = 'in progress'"),
        "WHERE fixture_export.title = 'in progress'",
      );
    });

    test('a comma does not split it', () {
      expect(
        where("find by title = 'a,b'"),
        "WHERE fixture_export.title = 'a,b'",
      );
    });

    test('brackets do not split it', () {
      expect(
        where("find by title = 'a (b) c'"),
        "WHERE fixture_export.title = 'a (b) c'",
      );
    });

    test('comparison signs do not split it', () {
      // Each of `=`, `<`, `>` was a separator, and `<=`/`<>`/`>=` were matched
      // as pairs — so all five forms are pinned rather than one standing in
      // for the rest.
      for (final value in const [
        'a = b',
        'a < b',
        'a > b',
        'a <= b',
        'a <> b',
        'a >= b',
      ]) {
        expect(
          where("find by title = '$value'"),
          "WHERE fixture_export.title = '$value'",
          reason: 'the literal [$value] should survive tokenising whole',
        );
      }
    });

    test('a keyword inside a literal is not read as a clause', () {
      // `by` ends the options clause and `order` starts the sort clause, both
      // by scanning the token list. A literal that is one token cannot be
      // mistaken for either — which is the point of quoting.
      expect(
        where("find by title = 'group by phase'"),
        "WHERE fixture_export.title = 'group by phase'",
      );
      expect(
        where("find by title = 'order by title'"),
        "WHERE fixture_export.title = 'order by title'",
      );
      expect(
        where("find by title = 'and'"),
        "WHERE fixture_export.title = 'and'",
      );
    });

    test('leading and trailing spaces are part of the value', () {
      // Whitespace inside the quotes is data, not separation: the old
      // tokeniser collapsed runs of spaces before splitting, so it could not
      // have preserved this even if it had known where the quotes were.
      expect(
        where("find by title = '  padded  '"),
        "WHERE fixture_export.title = '  padded  '",
      );
    });

    test('an empty literal is still a literal', () {
      expect(where("find by title = ''"), "WHERE fixture_export.title = ''");
    });
  });

  group('an apostrophe is written by doubling it', () {
    test("'O''Brien, Ltd' carries exactly one apostrophe", () {
      // `''` is the sentence-level escape; the parser decodes it to a single
      // `'`, and the dialect escapes that back to `''` for SQL. Both steps are
      // needed and each looks redundant beside the other: drop the decode and
      // the dialect escapes the author's two characters into four, so the
      // value silently gains an apostrophe.
      expect(
        where("find by title = 'O''Brien, Ltd'"),
        "WHERE fixture_export.title = 'O''Brien, Ltd'",
      );
    });

    test('a literal that is only an apostrophe', () {
      expect(
        where("find by title = ''''"),
        "WHERE fixture_export.title = ''''",
      );
    });

    test('a doubled apostrophe does not end the literal early', () {
      // The scan has to tell an escape from a terminator, and both are `'`.
      // Reading the first quote of the pair as the close would end the literal
      // here and leave `Brien, x'` as loose tokens.
      expect(
        where("find by title = 'O''Brien' and done = TRUE"),
        "WHERE fixture_export.title = 'O''Brien' AND fixture_export.done = true",
      );
    });
  });

  group('the token after a literal is still read', () {
    // A literal that swallowed the rest of the sentence would be as bad as one
    // that was split, so these assert the whole predicate rather than a
    // containment — a dropped conjunct is invisible to `contains` on the half
    // that survived.
    test('AND after a literal keeps both sides', () {
      expect(
        where("find by title = 'in progress' and done = TRUE"),
        "WHERE fixture_export.title = 'in progress' AND "
        "fixture_export.done = true",
      );
    });

    test('a literal on the right-hand side of an AND', () {
      expect(
        where("find by done = TRUE and title = 'in progress'"),
        "WHERE fixture_export.done = true AND "
        "fixture_export.title = 'in progress'",
      );
      expect(
        where("find by amount > 1.5 and title = 'in progress'"),
        "WHERE fixture_export.amount > 1.5 AND "
        "fixture_export.title = 'in progress'",
      );
    });

    test('literals in an IS IN list separate on the real commas only', () {
      // The comma inside the second value must not end an element, and the
      // ones between values must still separate.
      expect(
        where("find by title is in ( 'a b' , 'c,d' )"),
        "WHERE fixture_export.title IN ('a b','c,d')",
      );
    });

    test('a bracket inside a literal does not close the IS IN list', () {
      expect(
        where("find by title is in ( 'x (y)' , 'z' )"),
        "WHERE fixture_export.title IN ('x (y)','z')",
      );
    });

    test('order by after a literal is still read', () {
      final sql = compiler
          .compileQuerySentence("find by title = 'a b' order by title desc")
          .generateQuery(dialect);
      expect(sql, contains("fixture_export.title = 'a b'"));
      expect(sql, contains('ORDER BY fixture_export.title DESC'));
    });
  });

  group('an unterminated literal is refused', () {
    for (final sentence in const [
      "find by title = 'unterminated",
      "find by title = 'a",
      "find by title = '",
      // Three quotes: an opening one, then a doubled pair that is an escape
      // rather than a close, so the literal never ends.
      "find by title = 'a''",
      "find by title is in ( 'a' , 'b )",
    ]) {
      test('[$sentence]', () {
        expectRefused(
          sentence,
          'split_query_sentence.unterminated_string_literal',
        );
      });
    }
  });

  group('what a literal may stand for is unchanged', () {
    test('a string literal against a non-string column is still refused', () {
      // Quoting decides where the token ends, not what it may be compared
      // against — the type rule is asserted here so the tokeniser change
      // cannot quietly widen it.
      expectRefused(
        "find by id = 'not an int'",
        'string_literal_invalid_type_expected',
      );
    });

    test('a bare word is still a column, not a literal', () {
      expect(
        where('find by title = secret'),
        'WHERE fixture_export.title = fixture_export.secret',
      );
    });
  });
}

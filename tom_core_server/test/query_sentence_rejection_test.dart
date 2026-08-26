/// Tests for the query sentence compiler's **rejections** — the sentences it
/// refuses, and the exception key each refusal carries.
///
/// The compiler is the one place in the persistence module that reads a string
/// a developer wrote by hand, so almost everything it can say is a complaint
/// about that string. Those complaints are an API: a caller distinguishes them
/// by [TomServerException.key], and a key that changes silently — or a branch
/// that turns out to throw a `RangeError` instead — breaks the caller without
/// breaking a single assertion elsewhere.
///
/// The sibling files (`query_sentence_*_test.dart`) each pin one *feature* and
/// its own errors. This one covers what is left: the structural refusals of the
/// query parser (a bracket, an `AND` or an `OR` with nothing to join), the
/// operators that need a column in front of them, and the two pattern operators
/// — `LIKE` and `REGEXP` — including what they render when they are used
/// correctly.
///
/// Connection-free: only [FixtureExportRecord]'s annotations are read.
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

  /// Asserts that [sentence] is refused with an exception whose key ends in
  /// [key] — the discriminating tail, so the test does not restate the whole
  /// dotted path of the branch it is pinning.
  void refuses(String sentence, String key) {
    expect(
      () => compiler.compileQuerySentence(sentence),
      throwsA(
        isA<TomQuerySyntaxException>().having(
          (e) => e.key,
          'key',
          endsWith(key),
        ),
      ),
      reason: 'expected [$sentence] to be refused with .$key',
    );
  }

  group('LIKE', () {
    test('renders as a pattern match against a bound parameter', () {
      expect(
        sql('find by title like :p'),
        contains('fixture_export.title LIKE :p'),
      );
    });

    test('matches against a literal', () {
      expect(sql("find by title like 'a%'"), contains("LIKE 'a%'"));
    });

    test('needs a column in front of it', () {
      refuses('find by like :p', 'like_test_without_column');
    });

    test('is refused on a column that is not text', () {
      // The operand types have to agree before the node is built: `LIKE` takes
      // string operands, so an int column has no form of the operator at all.
      refuses('find by id like :p', 'like_invalid_column_type');
    });
  });

  group('REGEXP', () {
    test('renders as a regular-expression match', () {
      expect(
        sql('find by title regexp :p'),
        contains('fixture_export.title REGEXP :p'),
      );
    });

    test('needs a column in front of it', () {
      refuses('find by regexp :p', 'regexp_test_without_column');
    });

    test('is refused on a column that is not text', () {
      refuses('find by amount regexp :p', 'regexp_invalid_column_type');
    });
  });

  group('operators that need a column in front of them', () {
    // Each of these is the same shape of mistake — the operator opened the
    // expression instead of qualifying one — but each is its own branch with
    // its own key, so a caller can tell which operator was misplaced.
    test('IS NULL', () {
      refuses('find by is null', 'is_null_test_without_column');
    });

    test('IS NOT NULL', () {
      refuses('find by is not null', 'is_not_null_test_without_column');
    });

    test('IS IN', () {
      refuses('find by is in ( 1 , 2 )', 'is_in_test_without_column');
    });

    test('IS NOT IN', () {
      refuses('find by is not in ( 1 , 2 )', 'is_not_in_test_without_column');
    });

    test('NOT LIKE', () {
      refuses('find by not like :p', 'not_like_test_without_column');
    });

    test('NOT LIKE on a column that is not text', () {
      refuses('find by id not like :p', 'not_like_invalid_column_type');
    });

    test('a bound parameter', () {
      // A parameter has no type of its own — it takes the column's. Standing
      // alone it cannot be typed at all, which is why it is refused here and
      // not later, where the failure would name a type instead of the mistake.
      refuses('find by :p', 'parameter_without_column');
    });
  });

  group('the structure of the sentence', () {
    test('a sentence must start with a known verb', () {
      refuses('fetch by id = 1', 'invalid_query_sentence_start');
    });

    test('a closing bracket needs something to enclose', () {
      refuses('find by ( ) ', 'unenclosing_closing_bracket');
    });

    test('AND needs a left-hand side', () {
      refuses('find by and id = 1', 'and_without_current_operation');
    });

    test('OR needs a left-hand side', () {
      refuses('find by or id = 1', 'or_without_current_operation');
    });

    test('an order clause needs at least one field', () {
      refuses('find by id = 1 order by', 'order_clause_missing_fields');
    });

    test('an order clause of nothing but separators names no field either', () {
      refuses('find by id = 1 order by ,', 'order_clause_missing_fields');
    });
  });

  group('a literal has to fit the column it is compared to', () {
    // The compiler types an expression from the column, then checks that what
    // follows can inhabit that type. Getting this wrong is the most ordinary
    // mistake in a hand-written sentence — and the one whose consequence would
    // otherwise be a driver-level bind error with no mention of the sentence.
    test('TRUE against a text column', () {
      refuses(
        'find by title = TRUE',
        'bool_literal_invalid_type_expected_true',
      );
    });

    test('FALSE against a text column', () {
      // The two literals carry *different* keys, so a caller reading the key
      // can tell which one the sentence used without re-parsing it.
      refuses(
        'find by title = FALSE',
        'bool_literal_invalid_type_expected_false',
      );
    });

    test('TRUE against a numeric column', () {
      refuses(
        'find by amount = TRUE',
        'bool_literal_invalid_type_expected_true',
      );
    });

    test('an int literal against a text column', () {
      refuses('find by title = 1', 'int_literal_invalid_type_expected');
    });

    test('NOT where a non-bool value is expected', () {
      // `NOT` produces a truth value, so it can only stand where one is wanted.
      // Against a text column the negation has nowhere to go.
      refuses('find by title = not TRUE', 'not_invalid_type_expected');
    });

    test('a bool column does accept a negated literal', () {
      // The success path the three refusals above are the boundary of.
      expect(sql('find by done = not TRUE'), contains('fixture_export.done'));
    });
  });
}

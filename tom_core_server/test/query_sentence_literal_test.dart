/// Tests for the **inline scalar literals** a query sentence can spell —
/// `find by amount > 1.5`, `find by tag_day = 2026-07-05`.
///
/// A value in a sentence is either *bound* (`:name`) or written out. The
/// written-out form is recognised by shape, and the four shapes nest: every
/// datetime literal contains a date, every date contains digits, and a rule
/// that merely looks for digits matches all of them — plus any identifier that
/// happens to carry one. So each kind stays reachable only if its pattern is
/// anchored *and* the kinds are tried most-specific-first; the tests below hold
/// both properties in place by compiling one sentence per kind and checking it
/// rendered as that kind rather than as the broader one that encloses it.
///
/// Connection-free: only the entity's annotations are read, so
/// [FixtureExportRecord] needs no table. It is the fixture used here because it
/// declares a column of every family a literal can address — an `int`, a
/// `double`, a `DateTime` and a `TomZonedDate`.
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

  group('each literal kind is recognised as itself', () {
    // One test per kind, because the kinds shadow one another in a fixed
    // order: a rule broad enough to swallow the next kind leaves that kind's
    // test failing and its own passing, so only a full set localises the fault.
    test('an integer literal compiles as an integer', () {
      expect(sql('find by id > 5'), contains('fixture_export.id > 5'));
    });

    test('a double literal compiles as a double', () {
      // Shadowed by the integer rule while that rule was unanchored: `1.5`
      // *contains* digits, so it was claimed as an integer and then rejected
      // for not being one — a decimal predicate could not be written at all.
      expect(
        sql('find by amount > 1.5'),
        contains('fixture_export.amount > 1.5'),
      );
    });

    test('a date literal compiles as a date', () {
      expect(
        sql('find by tag_day = 2026-07-05'),
        contains("fixture_export.tag_day = '2026-07-05'"),
      );
    });

    test('a datetime literal compiles as a datetime', () {
      // Rendered as the UTC `DATETIME(6)` text every instant binds as, so the
      // assertion pins the conversion as well as the branch.
      expect(
        sql('find by created_at >= 2026-07-05T10:00:00Z'),
        contains("fixture_export.created_at >= '2026-07-05 10:00:00.000000'"),
      );
    });

    test('a datetime literal with a zone offset is converted to UTC', () {
      // The offset form is the one the date rule would claim first if the
      // ordering were reversed: it opens with a full `YYYY-MM-DD`.
      expect(
        sql('find by created_at >= 2026-07-05T12:00:00+02:00'),
        contains("fixture_export.created_at >= '2026-07-05 10:00:00.000000'"),
      );
    });

    test('all four kinds compile in a single sentence', () {
      // Together rather than separately, because the kinds are tried in one
      // ordered pass: a sentence naming all four proves the ordering resolves
      // each token independently of the ones around it.
      final query = sql(
        'find by id > 5 and amount > 1.5 and tag_day = 2026-07-05 '
        'and created_at >= 2026-07-05T10:00:00Z',
      );
      expect(query, contains('fixture_export.id > 5'));
      expect(query, contains('fixture_export.amount > 1.5'));
      expect(query, contains("fixture_export.tag_day = '2026-07-05'"));
      expect(
        query,
        contains("fixture_export.created_at >= '2026-07-05 10:00:00.000000'"),
      );
    });
  });

  group('signed numeric literals', () {
    // Anchoring a pattern narrows what it accepts, so the signed forms — which
    // work today — are pinned here to keep the narrowing from taking them with
    // it.
    test('a negative integer literal compiles', () {
      expect(sql('find by id > -5'), contains('fixture_export.id > -5'));
    });

    test('a negative double literal compiles', () {
      expect(
        sql('find by amount > -1.5'),
        contains('fixture_export.amount > -1.5'),
      );
    });

    test('an explicitly positive integer literal compiles', () {
      expect(sql('find by id > +5'), contains('fixture_export.id > 5'));
    });
  });

  group('a literal does not shadow an identifier that contains a digit', () {
    test('a having alias whose name carries a digit resolves as an alias', () {
      // The same defect at its most visible: an identifier is only reached
      // after every literal rule has declined it, so while the integer rule
      // matched any token *containing* a digit, naming an alias `total1` made
      // the sentence uncompilable — it was read as the integer literal `1`.
      expect(
        compiler
            .compileQuerySentence(
              'group count ( * ) as total1 over done by id > 0 having total1 > 3',
            )
            .generateQuery(dialect),
        contains('COUNT(*) > 3'),
      );
    });
  });

  group('a literal of the wrong type is still refused', () {
    // The rejection the anchoring must not remove: a literal still stands for
    // exactly one SQL type, and the key must now name the kind the token
    // actually spells rather than whichever rule happened to claim it.
    test('a double literal against a text column names the double rule', () {
      expect(
        () => compiler.compileQuerySentence("find by title = 1.5"),
        throwsA(
          isA<TomServerException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.build_expression.'
                'double_literal_invalid_type_expected',
          ),
        ),
      );
    });

    test('a date literal against an integer column names the date rule', () {
      expect(
        () => compiler.compileQuerySentence('find by id = 2026-07-05'),
        throwsA(
          isA<TomServerException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.build_expression.'
                'date_literal_invalid_type_expected',
          ),
        ),
      );
    });

    test(
      'a datetime literal against a date column names the datetime rule',
      () {
        expect(
          () => compiler.compileQuerySentence(
            'find by tag_day = 2026-07-05T10:00:00Z',
          ),
          throwsA(
            isA<TomServerException>().having(
              (e) => e.key,
              'key',
              'query_sentence_compiler.build_expression.'
                  'datetime_literal_invalid_type_expected',
            ),
          ),
        );
      },
    );

    test('an integer literal against a text column names the integer rule', () {
      expect(
        () => compiler.compileQuerySentence('find by title = 5'),
        throwsA(
          isA<TomServerException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.build_expression.'
                'int_literal_invalid_type_expected',
          ),
        ),
      );
    });
  });
}

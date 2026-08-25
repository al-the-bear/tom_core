/// Tests for the arguments of the window options — `first`/`top` and
/// `skip`/`offset` — in a query sentence.
///
/// Each of these keywords takes exactly one numeric token after it, and the
/// four ways of getting that token wrong all used to be indistinguishable from
/// each other *and* from a correct sentence: one `try`/`catch` around
/// `int.parse` returned `1` for anything it could not read. `find first x by …`
/// capped at one row, and so did `find first by …` with no argument at all —
/// the missing element threw `RangeError` inside the same `try`. A caller who
/// mistyped a page size got a page of one row and no indication that anything
/// had gone wrong, which is the one failure mode a query language cannot
/// afford: quietly returning a different result set than the one asked for.
///
/// Zero is *not* an error here. `TomPageRequest` treats `limit: 0` as "no cap"
/// (`isUnpaged`, and `assertWindow` rejects only negative bounds), so a
/// sentence saying `first 0` means the same thing rather than something new.
/// The tests below pin that agreement in both directions.
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

  // No cast: every kind exercised here — find, delete, group — renders through
  // the one `TomQuery.generateQuery`, which is the point of testing the window
  // options across all three in a single helper.
  String sql(String sentence) =>
      compiler.compileQuerySentence(sentence).generateQuery(dialect);

  /// Expects [sentence] to be refused with a compile key ending in [keySuffix].
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
      reason: 'a window option that cannot be read must not be guessed at',
    );
  }

  group('a well-formed window option still compiles', () {
    test('first caps the rows', () {
      expect(sql('find first 5 by id > 0'), contains('LIMIT 5'));
    });

    test('top is the same option under another name', () {
      expect(sql('find top 5 by id > 0'), contains('LIMIT 5'));
    });

    test('skip offsets into the capped window', () {
      expect(
        sql('find first 5 skip 10 by id > 0'),
        contains('LIMIT 5 OFFSET 10'),
      );
    });

    test('offset is the same option under another name', () {
      expect(
        sql('find first 5 offset 10 by id > 0'),
        contains('LIMIT 5 OFFSET 10'),
      );
    });

    test('a delete takes a cap', () {
      expect(sql('delete first 5 by id > 0'), contains('LIMIT 5'));
    });

    test('a grouped sentence takes the same window', () {
      expect(
        sql('group first 5 count ( * ) as total over done by id > 0'),
        contains('LIMIT 5'),
      );
    });
  });

  group('a non-numeric argument is refused rather than read as 1', () {
    // The reported symptom, in each of the four keywords. `skip`/`offset` were
    // never mentioned in the report but shared the same fallback, so a mistyped
    // skip silently skipped exactly one row.
    test('first', () {
      expectRefused('find first x by id > 0', 'first_not_numeric');
    });

    test('top', () {
      expectRefused('find top x by id > 0', 'top_not_numeric');
    });

    test('skip', () {
      expectRefused('find first 5 skip x by id > 0', 'skip_not_numeric');
    });

    test('offset', () {
      expectRefused('find first 5 offset x by id > 0', 'offset_not_numeric');
    });

    test('a decimal is not a row count either', () {
      // `3.5` parses as a double but not as an `int`, so it took the same
      // fallback. Half a row is not a request the database can serve.
      expectRefused('find first 3.5 by id > 0', 'first_not_numeric');
    });

    test('the key names the keyword that was actually written', () {
      // `top` and `first` are one option internally; the exception still has
      // to quote the word the author used, or it sends them looking at a
      // keyword their sentence does not contain.
      expectRefused('find top x by id > 0', 'top_not_numeric');
      expect(
        () => compiler.compileQuerySentence('find top x by id > 0'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            isNot(contains('first')),
          ),
        ),
      );
    });
  });

  group('a missing argument is refused rather than read as 1', () {
    // `options[index + 1]` on the last token threw `RangeError` *inside* the
    // same `try`, so the keyword with nothing after it was as silent as the
    // mistyped one — and produced the identical `LIMIT 1`.
    test('first at the end of the options', () {
      expectRefused('find first by id > 0', 'first_missing_argument');
    });

    test('top at the end of the options', () {
      expectRefused('find top by id > 0', 'top_missing_argument');
    });

    test('skip at the end of the options', () {
      expectRefused('find first 5 skip by id > 0', 'skip_missing_argument');
    });

    test('offset at the end of the options', () {
      expectRefused('find first 5 offset by id > 0', 'offset_missing_argument');
    });
  });

  group('a negative argument is refused', () {
    // The same rule `TomPageRequest.assertWindow` applies to a window built
    // programmatically. Before, `first -5` disappeared: the compiler's "absent"
    // sentinel is `-1`, and any negative fails the `> 0` test that gates the
    // clause, so the cap was dropped and every row came back.
    test('first', () {
      expectRefused('find first -5 by id > 0', 'first_negative');
    });

    test('skip', () {
      expectRefused('find first 5 skip -1 by id > 0', 'skip_negative');
    });

    test('minus one, which is the internal absent sentinel', () {
      // Worth its own test: `-1` is the value `_countOption` returns for an
      // option that is not there, so an accepted `first -1` would be
      // indistinguishable from an unpaged sentence.
      expectRefused('find first -1 by id > 0', 'first_negative');
    });
  });

  group('zero means unpaged, as it does for TomPageRequest', () {
    test('first 0 compiles and caps nothing', () {
      expect(sql('find first 0 by id > 0'), isNot(contains('LIMIT')));
    });

    test('skip 0 compiles and skips nothing', () {
      expect(sql('find first 5 skip 0 by id > 0'), isNot(contains('OFFSET')));
    });

    test('TomPageRequest agrees that a zero limit is unpaged', () {
      // The sentence and the programmatic request are two doors onto one
      // window. This asserts the agreement rather than assuming it, so the
      // sentence rule cannot drift away from `assertWindow` unnoticed.
      expect(TomPageRequest(limit: 0).isUnpaged, isTrue);
      expect(
        () => TomPageRequest(limit: -5),
        throwsA(isA<TomQuerySyntaxException>()),
      );
    });
  });
}

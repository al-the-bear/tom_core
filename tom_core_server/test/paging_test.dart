/// Connection-free tests for the paging and sorting vocabulary (tfca4).
///
/// Two surfaces, both assertable without a database:
///
///  * [TomPageRequest] / [TomSortField] — the caller-facing request objects,
///    including the window rules that reject a request SQL cannot express; and
///  * the `skip`/`offset` and per-field direction grammar of
///    [TomQuerySentenceCompiler], asserted through the SQL each sentence
///    renders.
///
/// The end-to-end half — that a window under a live row scope returns the right
/// rows and the right *scoped* total — is in `paging_db_test.dart`, because only
/// a real table can show it.
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
      compiler.compileQuerySentence(sentence).generateQuery(dialect);

  group('TomSortField', () {
    test('defaults to ascending and carries its direction into SQL', () {
      expect(const TomSortField('a').isAscending, isTrue);
      expect(const TomSortField('a').direction.sqlKeyword, 'ASC');
      expect(const TomSortField.desc('a').direction.sqlKeyword, 'DESC');
    });

    test('withField keeps the direction when a name is resolved', () {
      // How a declared field name becomes a qualified column expression: the
      // direction must survive the substitution or a DESC sort silently
      // becomes ASC once the query is rendered.
      final resolved = const TomSortField.desc('title').withField('t.title');
      expect(resolved.field, 't.title');
      expect(resolved.direction, TomSortDirection.descending);
    });

    test('allOf maps a field list onto one shared direction', () {
      expect(
        TomSortField.allOf(const [
          'a',
          'b',
        ], direction: TomSortDirection.descending),
        const [TomSortField.desc('a'), TomSortField.desc('b')],
      );
    });

    test('equality is by field and direction', () {
      expect(const TomSortField.asc('a'), const TomSortField('a'));
      expect(const TomSortField.asc('a'), isNot(const TomSortField.desc('a')));
    });
  });

  group('TomPageRequest', () {
    test('page(n, size) is offset n*size, limit size', () {
      final page = TomPageRequest.page(2, 25);
      expect(page.offset, 50);
      expect(page.limit, 25);
    });

    test('an empty request shapes nothing', () {
      expect(TomPageRequest().isUnpaged, isTrue);
      expect(
        TomPageRequest.sorted(const [TomSortField.asc('a')]).isUnpaged,
        isFalse,
      );
      expect(TomPageRequest(limit: 10).isUnpaged, isFalse);
    });

    test('needsStableSort is true exactly when a window is cut', () {
      // A sort-only request reads the whole set, so its order is already total
      // over what it returns; a window is the case that can repeat or skip rows.
      expect(
        TomPageRequest.sorted(const [TomSortField.asc('a')]).needsStableSort,
        isFalse,
      );
      expect(TomPageRequest(limit: 10).needsStableSort, isTrue);
    });

    test('rejects a negative bound', () {
      expect(
        () => TomPageRequest(limit: -1),
        throwsA(isA<TomQuerySyntaxException>()),
      );
      expect(
        () => TomPageRequest(offset: -1, limit: 5),
        throwsA(isA<TomQuerySyntaxException>()),
      );
    });

    test('rejects an offset with no limit', () {
      // MariaDB's grammar is `LIMIT n [OFFSET m]` — there is no bare OFFSET, so
      // this request would render as a statement that silently ignores the skip.
      expect(
        () => TomPageRequest(offset: 20),
        throwsA(isA<TomQuerySyntaxException>()),
      );
    });

    test('withSort keeps the window', () {
      final page = TomPageRequest(
        offset: 10,
        limit: 5,
      ).withSort(const [TomSortField.desc('a')]);
      expect(page.offset, 10);
      expect(page.limit, 5);
      expect(page.sort, const [TomSortField.desc('a')]);
    });
  });

  group('query sentence: row window', () {
    test('first/top alone still renders a bare LIMIT', () {
      expect(sql('find first 5 by title = :t'), endsWith(' LIMIT 5'));
    });

    test('skip adds an OFFSET to the limit', () {
      expect(
        sql('find first 5 skip 10 by title = :t'),
        endsWith(' LIMIT 5 OFFSET 10'),
      );
    });

    test('offset is a synonym for skip, and top for first', () {
      expect(
        sql('find top 5 offset 10 by title = :t'),
        endsWith(' LIMIT 5 OFFSET 10'),
      );
    });

    test('a skip with no cap is rejected', () {
      expect(
        () => compiler.compileQuerySentence('find skip 10 by title = :t'),
        throwsA(isA<TomQuerySyntaxException>()),
      );
    });

    test('naming the same option twice is a contradiction', () {
      expect(
        () => compiler.compileQuerySentence('find first 5 top 6 by title = :t'),
        throwsA(isA<TomQuerySyntaxException>()),
      );
      expect(
        () => compiler.compileQuerySentence(
          'find first 5 skip 1 offset 2 by title = :t',
        ),
        throwsA(isA<TomQuerySyntaxException>()),
      );
    });

    test('a count takes no row window at all', () {
      // Neither half of a window means anything to a count. A cap is the
      // surprising one: LIMIT caps the rows *returned*, and a count returns one
      // row whatever the cap, so `count first 5` would count the whole filtered
      // set and then cap nothing. And the total of a set does not depend on
      // which page of it the caller is reading, so a skip is a mistake rather
      // than a narrower question.
      //
      // Because a skip needs a cap and a count may not have one, the cap rule
      // is what a skipped count now trips — there is no sentence that reaches
      // the skip rule through a count.
      expect(
        () => compiler.compileQuerySentence('count first 5 by title = :t'),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.compile.top_unsupported_for_count',
          ),
        ),
      );
      // The cap rule fires *first*, which is what makes the skip rule
      // unreachable for a count rather than merely redundant. Pinning the key
      // here keeps that ordering from drifting back.
      expect(
        () => compiler.compileQuerySentence(
          'count first 5 skip 10 by title = :t',
        ),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.compile.top_unsupported_for_count',
          ),
        ),
      );
    });

    test('a count without a window still compiles', () {
      // The rejections above are about the *window*, not about counting: the
      // plain sentence must keep working, and must render neither clause.
      final query = sql('count by title = :t');
      expect(query, startsWith('SELECT COUNT(*) AS count FROM '));
      expect(query, isNot(contains('ORDER BY')));
      expect(query, isNot(contains('LIMIT')));
    });

    test('a delete takes no skip', () {
      // `DELETE ... LIMIT n OFFSET m` is not MariaDB syntax.
      expect(
        () => compiler.compileQuerySentence(
          'delete first 5 skip 10 by title = :t',
        ),
        throwsA(isA<TomQuerySyntaxException>()),
      );
    });
  });

  group('query sentence: sort direction', () {
    test('a bare field list orders ascending', () {
      expect(
        sql('find by title = :t order by amount'),
        contains('ORDER BY fixture_export.amount ASC'),
      );
    });

    test('a trailing direction still applies to the whole list', () {
      // The reading every existing sentence in the workspace was written
      // against: `order by a b desc` sorts both descending.
      expect(
        sql('find by title = :t order by amount created_at desc'),
        contains(
          'ORDER BY fixture_export.amount DESC,fixture_export.created_at DESC',
        ),
      );
    });

    test('directions mix, each applying back to the previous one', () {
      expect(
        sql('find by title = :t order by amount desc created_at asc'),
        contains(
          'ORDER BY fixture_export.amount DESC,fixture_export.created_at ASC',
        ),
      );
    });

    test('commas are accepted as separators', () {
      expect(
        sql('find by title = :t order by amount desc , created_at'),
        contains(
          'ORDER BY fixture_export.amount DESC,fixture_export.created_at ASC',
        ),
      );
    });

    test('a direction with no field before it is rejected', () {
      expect(
        () => compiler.compileQuerySentence('find by title = :t order by desc'),
        throwsA(isA<TomQuerySyntaxException>()),
      );
    });

    test('a count takes no order by', () {
      // A count is a single row, so an ordering has nothing to order. A delete
      // is the opposite case and keeps its order by: `DELETE ... ORDER BY x
      // LIMIT n` picks *which* rows go.
      expect(
        () => compiler.compileQuerySentence(
          'count by title = :t order by amount',
        ),
        throwsA(
          isA<TomQuerySyntaxException>().having(
            (e) => e.key,
            'key',
            'query_sentence_compiler.compile.order_by_unsupported_for_count',
          ),
        ),
      );
      expect(
        sql('delete first 5 by title = :t order by amount'),
        endsWith(' ORDER BY amount ASC LIMIT 5'),
      );
    });

    test('a mixed sort composes with a row window', () {
      // The sentence the todo's DONE WHEN clause names: page N of size M with a
      // multi-column mixed-direction sort, in one statement.
      final query = sql(
        'find first 10 skip 20 by title = :t '
        'order by amount desc created_at asc',
      );
      expect(
        query,
        endsWith(
          ' ORDER BY fixture_export.amount DESC,fixture_export.created_at ASC'
          ' LIMIT 10 OFFSET 20',
        ),
      );
    });
  });
}

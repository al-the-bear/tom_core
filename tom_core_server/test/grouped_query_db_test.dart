/// DB-backed tests for the aggregation/grouping query surface (CSEX5).
///
/// The connection-free surface — the [TomAggregate] nodes, the dialect
/// fragments, the compiled [TomGroupedSelect] text and the `group …` sentence
/// grammar — is covered by `grouped_query_test.dart`. That suite asserts the
/// *strings* the query layer emits, which leaves two things it structurally
/// cannot see:
///
///  * **Whether MariaDB accepts them.** A syntactically plausible
///    `GROUP BY … HAVING` that the server rejects passes every string
///    assertion, because no server was ever asked.
///  * **What types come back.** SQL widens `SUM` and `AVG` over an integer
///    column to `DECIMAL`, which the driver hands over in its own
///    representation. [Sum] and [Avg] declare their value type as `double`
///    precisely to absorb that (see their doc comments), and
///    `MariaDbDatasource.mapGroupedRow` reads each alias as the type the
///    projection declared. Until a real driver row goes through that path, the
///    widening is a claim rather than an observation — and a connection-free
///    fake that hands back an `int` where the driver hands back a decimal
///    string would confirm the claim while hiding the bug.
///
/// So this file asserts values *and* runtime Dart types for every aggregate
/// kind, pins down what the driver natively returns for a `SUM` (the fact the
/// widening exists to handle), and covers the two degenerate shapes — a group
/// whose aggregated column is entirely `NULL`, and a `HAVING` that excludes
/// every group.
///
/// The whole group is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring
/// a server up with `tool/run_db_tests.sh` to run it.
@Tags(['db'])
library;

import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureTaskRecord, FixtureTaskRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// A trivial host for the [TomQueryBuilder] DSL.
class _Builder with TomQueryBuilder {}

/// Builds a fixture row; the surrogate key stays `null` so `save` inserts.
FixtureTaskRecord _task(String title, int? priority, {required bool done}) =>
    FixtureTaskRecord()
      ..title = title
      ..priority = priority
      ..done = done;

/// The seed set every test in this file starts from.
///
/// Four `title` groups, chosen so that each assertion below has exactly one
/// group that exercises it:
///
/// | title   | rows | priorities   | notes                                  |
/// | ------- | ---- | ------------ | -------------------------------------- |
/// | `alpha` | 3    | 1, 2, 3      | the ordinary case                      |
/// | `beta`  | 2    | 10, 20       | a second multi-row group               |
/// | `gamma` | 1    | 7            | a single-row group (MIN == MAX == SUM) |
/// | `delta` | 2    | NULL, NULL   | the all-null aggregation case          |
///
/// Over the whole set: 8 rows, 6 with a priority, summing to 43.
const List<(String, int?, bool)> _seedRows = [
  ('alpha', 1, true),
  ('alpha', 2, true),
  ('alpha', 3, false),
  ('beta', 10, false),
  ('beta', 20, true),
  ('gamma', 7, false),
  ('delta', null, false),
  ('delta', null, false),
];

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
          'start one with tool/run_db_tests.sh';

  final b = _Builder();

  group('grouped queries (DB-backed)', () {
    late TomDataSourceInfo dsi;
    late FixtureTaskRepository repo;
    late TomQuerySentenceCompiler compiler;
    // Declared as the concrete column classes rather than as bare `DbCol`:
    // `IntCol` is both a `DbCol` (what `groupBy` takes) and a
    // `TomOperator<TomDbInt>` (what `minInt`/`maxInt` take), so one variable
    // serves the group-key and the aggregate-operand positions. Widening to
    // `DbCol` would erase the SQL type argument and the typed factories would
    // no longer accept it.
    late IntCol idCol;
    late StringCol titleCol;
    late IntCol priorityCol;
    late BoolCol doneCol;

    /// Every row — the `WHERE` a grouped query needs when the point is the
    /// grouping rather than the filtering. `id` is the primary key, so this
    /// excludes nothing (unlike a predicate on the nullable `priority`, which
    /// would silently drop the all-null group that several tests depend on).
    TomOperator<TomDbBool> allRows() => b.gt(idCol, b.intOp(0));

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.ensureFixtureTaskTable(dsi);
      compiler = TomQuerySentenceCompiler([FixtureTaskRecord]);
      idCol = b.intF('id', compiler.determineColumn('id')) as IntCol;
      titleCol =
          b.textF('title', compiler.determineColumn('title')) as StringCol;
      priorityCol =
          b.intF('priority', compiler.determineColumn('priority')) as IntCol;
      doneCol = b.boolF('done', compiler.determineColumn('done')) as BoolCol;
    });

    setUp(() async {
      await TestDatabase.truncateFixtureTask(dsi);
      // A fresh repository per test so no prepared-statement cache leaks the
      // previous test's table state.
      repo = FixtureTaskRepository();
      for (final (title, priority, done) in _seedRows) {
        await repo.save(_task(title, priority, done: done));
      }
    });

    tearDownAll(TestDatabase.reset);

    /// The rows of [query], keyed by their `title` group value, which is what
    /// every by-title assertion below actually wants.
    Future<Map<String, TomGroupedRow>> byTitle(TomGroupedSelect query) async {
      final rows = await repo.findGroupedByQuery(query, const {});
      return {for (final row in rows) row.stringValue('title')!: row};
    }

    group('the round trip through MariaDB', () {
      test('a GROUP BY over a text key returns one row per group', () async {
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [titleCol],
          aggregates: [b.countAll('n')],
          orderBy: ['title'],
        );
        final rows = await repo.findGroupedByQuery(query, const {});
        expect(rows, hasLength(4));
        expect(
          [for (final row in rows) row.stringValue('title')],
          ['alpha', 'beta', 'delta', 'gamma'],
          reason: 'ORDER BY names the projection alias, so the groups come '
              'back in title order — the assertion is that the server honoured '
              'it, not merely that the clause was emitted',
        );
        expect(
          [for (final row in rows) row.intValue('n')],
          [3, 2, 2, 1],
        );
      });

      test('every aggregate kind computes the right value', () async {
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [titleCol],
          aggregates: [
            b.countAll('n'),
            b.countOf(priorityCol, 'rated'),
            b.sum(priorityCol, 'total'),
            b.avg(priorityCol, 'mean'),
            b.minInt(priorityCol, 'lo'),
            b.maxInt(priorityCol, 'hi'),
          ],
          orderBy: ['title'],
        );
        final groups = await byTitle(query);

        final alpha = groups['alpha']!;
        expect(alpha.intValue('n'), 3);
        expect(alpha.intValue('rated'), 3);
        expect(alpha.doubleValue('total'), 6.0);
        expect(alpha.doubleValue('mean'), 2.0);
        expect(alpha.intValue('lo'), 1);
        expect(alpha.intValue('hi'), 3);

        final beta = groups['beta']!;
        expect(beta.doubleValue('total'), 30.0);
        expect(beta.doubleValue('mean'), 15.0);
        expect(beta.intValue('lo'), 10);
        expect(beta.intValue('hi'), 20);

        final gamma = groups['gamma']!;
        expect(gamma.intValue('n'), 1);
        expect(gamma.doubleValue('total'), 7.0);
        expect(gamma.intValue('lo'), 7);
        expect(gamma.intValue('hi'), 7);
      });

      test('COUNT(*) and COUNT(column) differ on a null column', () async {
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [titleCol],
          aggregates: [b.countAll('n'), b.countOf(priorityCol, 'rated')],
        );
        final delta = (await byTitle(query))['delta']!;
        expect(
          delta.intValue('n'),
          2,
          reason: 'COUNT(*) counts rows, including those whose priority is '
              'NULL',
        );
        expect(
          delta.intValue('rated'),
          0,
          reason: 'COUNT(priority) counts non-null values — the distinction '
              'the two node kinds exist to express',
        );
      });

      test('COUNT(DISTINCT column) collapses repeated values', () async {
        // Two extra `alpha` rows repeating priorities already in the group, so
        // COUNT and COUNT DISTINCT are forced apart.
        await repo.save(_task('alpha', 1, done: false));
        await repo.save(_task('alpha', 2, done: false));
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [titleCol],
          aggregates: [
            b.countOf(priorityCol, 'rated'),
            b.countOf(priorityCol, 'kinds', distinct: true),
          ],
        );
        final alpha = (await byTitle(query))['alpha']!;
        expect(alpha.intValue('rated'), 5);
        expect(alpha.intValue('kinds'), 3);
      });

      test('grouping by a bool key materialises the TINYINT as a bool',
          () async {
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [doneCol],
          aggregates: [b.countAll('n'), b.sum(priorityCol, 'total')],
          orderBy: ['done'],
        );
        final rows = await repo.findGroupedByQuery(query, const {});
        expect(rows, hasLength(2));
        expect(
          rows.first.value('done'),
          isA<bool>(),
          reason: 'MariaDB stores the column as TINYINT(1); the projection '
              'declares it bool, so the mapper must hand back a Dart bool '
              'rather than 0/1',
        );
        final byDone = {
          for (final row in rows) row.boolValue('done')!: row,
        };
        expect(byDone[false]!.intValue('n'), 5);
        expect(byDone[true]!.intValue('n'), 3);
        expect(byDone[true]!.doubleValue('total'), 23.0);
      });

      test('an empty groupBy aggregates the whole filtered set into one row',
          () async {
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          aggregates: [
            b.countAll('n'),
            b.sum(priorityCol, 'total'),
            b.minInt(priorityCol, 'lo'),
            b.maxInt(priorityCol, 'hi'),
          ],
        );
        final rows = await repo.findGroupedByQuery(query, const {});
        expect(rows, hasLength(1));
        expect(rows.single.intValue('n'), 8);
        expect(rows.single.doubleValue('total'), 43.0);
        expect(rows.single.intValue('lo'), 1);
        expect(rows.single.intValue('hi'), 20);
      });

      test('the WHERE predicate filters rows before they are aggregated',
          () async {
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: b.gt(priorityCol, b.intOp(2)),
          groupBy: [titleCol],
          aggregates: [b.countAll('n'), b.sum(priorityCol, 'total')],
        );
        final groups = await byTitle(query);
        expect(
          groups.keys,
          unorderedEquals(['alpha', 'beta', 'gamma']),
          reason: 'delta has no row with priority > 2, so it produces no group '
              'at all — WHERE removes rows, and a group with no rows does not '
              'exist',
        );
        expect(groups['alpha']!.intValue('n'), 1);
        expect(groups['alpha']!.doubleValue('total'), 3.0);
      });

      test('a bound parameter binds into the WHERE clause', () async {
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: b.gte(priorityCol, b.p<TomDbInt>('floor')),
          groupBy: [titleCol],
          aggregates: [b.countAll('n')],
        );
        final rows = await repo.findGroupedByQuery(query, {'floor': 10});
        final groups = {for (final row in rows) row.stringValue('title')!: row};
        expect(groups.keys, ['beta']);
        expect(groups['beta']!.intValue('n'), 2);
      });
    });

    group('the value types the driver returns', () {
      test('SUM and AVG over an integer column materialise as double',
          () async {
        final sum = b.sum(priorityCol, 'total');
        final mean = b.avg(priorityCol, 'mean');
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [titleCol],
          aggregates: [sum, mean],
        );
        final alpha = (await byTitle(query))['alpha']!;

        expect(
          alpha.value('total'),
          isA<double>(),
          reason: 'SQL widens SUM over an INT column to DECIMAL. Sum declares '
              'its value type as double so the Dart type is the same on every '
              'dialect; this asserts the mapper actually produced one, which '
              'is the step a connection-free fake cannot exercise',
        );
        expect(alpha.value('mean'), isA<double>());
        expect(
          sum.read(alpha),
          isA<double>(),
          reason: 'the typed accessor on the node itself must agree with the '
              'raw mapped value — it is the API a caller uses',
        );
        expect(sum.read(alpha), 6.0);
        expect(mean.read(alpha), 2.0);
      });

      test('COUNT, MIN and MAX over an integer column materialise as int',
          () async {
        final count = b.countAll('n');
        final lo = b.minInt(priorityCol, 'lo');
        final hi = b.maxInt(priorityCol, 'hi');
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [titleCol],
          aggregates: [count, lo, hi],
        );
        final beta = (await byTitle(query))['beta']!;

        expect(beta.value('n'), isA<int>());
        expect(
          beta.value('lo'),
          isA<int>(),
          reason: 'unlike SUM, an extremum is one of the operand\'s own values, '
              'so Min/Max preserve the column type rather than widening',
        );
        expect(beta.value('hi'), isA<int>());
        expect(count.read(beta), 2);
        expect(lo.read(beta), 10);
        expect(hi.read(beta), 20);
      });

      test('MAX over a text column materialises as String', () async {
        final latest = Max<TomDbString, String>(titleCol, 'last');
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [doneCol],
          aggregates: [latest],
        );
        final rows = await repo.findGroupedByQuery(query, const {});
        expect(rows.first.value('last'), isA<String>());
        final byDone = {for (final row in rows) row.boolValue('done')!: row};
        expect(byDone[true]!.stringValue('last'), 'beta');
        expect(byDone[false]!.stringValue('last'), 'gamma');
      });

      test('the driver refuses to widen a SUM column to double itself',
          () async {
        // The reason `mapGroupedRow` parses the raw text for a `double`-typed
        // alias instead of calling `typedColByName<double>`, pinned against the
        // real driver rather than assumed.
        //
        // MariaDB types `SUM(<int column>)` as NEWDECIMAL (protocol type 246).
        // mysql_client converts to `double` only from a fixed whitelist of
        // column types — TINY/SHORT/LONG/LONGLONG/INT24/FLOAT/DOUBLE — which
        // does not include NEWDECIMAL, so the typed accessor throws rather than
        // widening. Since `Sum` and `Avg` declare their value type as `double`
        // precisely to absorb that widening, going through the typed accessor
        // made every SUM and AVG unusable against a real server.
        //
        // If a future driver adds NEWDECIMAL to that whitelist this test fails,
        // which is the point: the special-case in `mapGroupedRow` then becomes
        // a choice to re-justify rather than a silent no-op.
        final datasource = dsi.datasource as MariaDbDatasource;
        final result = await datasource.connection!.execute(
          'SELECT SUM(priority) AS total FROM fixture_task '
          'WHERE title = "alpha"',
        );
        final driverRow = result.rows.first;

        expect(
          () => driverRow.typedColByName<double>('total'),
          throwsA(isA<Exception>()),
          reason: 'the driver cannot convert NEWDECIMAL to double — this is '
              'the failure mapGroupedRow works around',
        );
        expect(
          double.parse(driverRow.colByName('total')!),
          6.0,
          reason: 'the raw text form carries the value losslessly, which is '
              'why parsing it is a safe workaround rather than a guess',
        );
      });
    });

    group('HAVING filters groups after aggregation', () {
      test('a HAVING on COUNT(*) keeps only the qualifying groups', () async {
        final n = b.countAll('n');
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [titleCol],
          aggregates: [n],
          having: b.gt(n, b.intOp(1)),
        );
        final groups = await byTitle(query);
        expect(
          groups.keys,
          unorderedEquals(['alpha', 'beta', 'delta']),
          reason: 'gamma has one row, so it is aggregated and then discarded — '
              'the difference between HAVING and WHERE',
        );
      });

      test('a HAVING on SUM discriminates on the widened value', () async {
        final total = b.sum(priorityCol, 'total');
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [titleCol],
          aggregates: [total],
          having: b.gt(total, b.intOp(6)),
        );
        final groups = await byTitle(query);
        expect(groups.keys, unorderedEquals(['beta', 'gamma']));
        expect(groups['gamma']!.doubleValue('total'), 7.0);
      });

      test('a HAVING binds its own parameter', () async {
        final n = b.countAll('n');
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: b.gte(priorityCol, b.p<TomDbInt>('floor')),
          groupBy: [titleCol],
          aggregates: [n],
          having: b.gte(n, b.p<TomDbInt>('minRows')),
        );
        final rows = await repo.findGroupedByQuery(
          query,
          {'floor': 1, 'minRows': 2},
        );
        expect(
          {for (final row in rows) row.stringValue('title')},
          unorderedEquals(['alpha', 'beta']),
          reason: 'the two predicates bind separate parameters in statement '
              'order; a WHERE/HAVING mix-up would silently swap them',
        );
      });

      test('a HAVING that excludes every group returns an empty list',
          () async {
        final n = b.countAll('n');
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [titleCol],
          aggregates: [n],
          having: b.gt(n, b.intOp(100)),
        );
        expect(
          await repo.findGroupedByQuery(query, const {}),
          isEmpty,
          reason: 'no group qualifies, which is an empty result and not an '
              'error — a caller iterating the rows must simply see none',
        );
      });
    });

    group('a group whose aggregated column is entirely null', () {
      test('SUM, AVG, MIN and MAX are all null', () async {
        final total = b.sum(priorityCol, 'total');
        final mean = b.avg(priorityCol, 'mean');
        final lo = b.minInt(priorityCol, 'lo');
        final hi = b.maxInt(priorityCol, 'hi');
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [titleCol],
          aggregates: [b.countAll('n'), total, mean, lo, hi],
        );
        final delta = (await byTitle(query))['delta']!;

        expect(delta.intValue('n'), 2, reason: 'the rows exist');
        expect(delta.value('total'), isNull);
        expect(delta.value('mean'), isNull);
        expect(delta.value('lo'), isNull);
        expect(delta.value('hi'), isNull);
      });

      test('the typed accessors return null rather than throwing', () async {
        final total = b.sum(priorityCol, 'total');
        final lo = b.minInt(priorityCol, 'lo');
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [titleCol],
          aggregates: [b.countAll('n'), total, lo],
        );
        final delta = (await byTitle(query))['delta']!;

        expect(
          total.read(delta),
          isNull,
          reason: 'an aggregate over an all-null column has no value, which is '
              'null — distinct from zero, which is what a caller who defaulted '
              'it would get wrong',
        );
        expect(lo.read(delta), isNull);
        expect(delta.doubleValue('total'), isNull);
        expect(delta.intValue('lo'), isNull);
        expect(
          delta.has('total'),
          isTrue,
          reason: 'the alias is present and its value is null; that is not the '
              'same as an unknown alias, which throws',
        );
      });

      test('a null aggregate is excluded by a HAVING on it', () async {
        final total = b.sum(priorityCol, 'total');
        final query = TomGroupedSelect(
          [FixtureTaskRecord],
          query: allRows(),
          groupBy: [titleCol],
          aggregates: [total],
          having: b.gte(total, b.intOp(0)),
        );
        final groups = await byTitle(query);
        expect(
          groups.keys,
          isNot(contains('delta')),
          reason: 'NULL >= 0 is NULL, not true, so SQL drops the group — worth '
              'pinning because a caller reasoning in Dart would expect an '
              'exception or a false',
        );
      });
    });

    group('a sentence-compiled grouped query executes', () {
      /// Compiles [sentence] the way a generated repository would, so the test
      /// covers the path from text to result rather than only the hand-built
      /// tree. The compiler's output is asserted as SQL text by
      /// `grouped_query_test.dart`; what is unproven is that the text it
      /// produces is something the server will run.
      Future<List<TomGroupedRow>> run(
        String sentence, [
        Map<String, Object?> params = const {},
      ]) async {
        final query =
            compiler.compileQuerySentence(sentence) as TomGroupedSelect;
        return repo.findGroupedByQuery(query, params);
      }

      test('a count over a group key', () async {
        final rows = await run(
          'group count ( * ) as total over title by id > 0 order by title asc',
        );
        expect(
          [for (final row in rows) row.stringValue('title')],
          ['alpha', 'beta', 'delta', 'gamma'],
        );
        expect([for (final row in rows) row.intValue('total')], [3, 2, 2, 1]);
      });

      test('several aggregates with a having and a bound parameter', () async {
        final rows = await run(
          'group count ( * ) as total , sum ( priority ) as weight '
          'over title by priority >= :floor having total > 1',
          {'floor': 1},
        );
        final groups = {for (final row in rows) row.stringValue('title')!: row};
        expect(groups.keys, unorderedEquals(['alpha', 'beta']));
        expect(groups['beta']!.doubleValue('weight'), 30.0);
      });

      test('top limits the number of groups returned', () async {
        final rows = await run(
          'group top 2 count ( * ) as total over title by id > 0 '
          'order by total desc',
        );
        expect(rows, hasLength(2));
        expect(rows.first.intValue('total'), 3);
      });
    });
  }, skip: skipReason);
}

/// Association filters and subqueries against a live database.
///
/// Records carry tags through the tag link; a query on a record filters on its
/// tags' columns, and the builder's subquery nodes are run directly.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show FixtureTagLink, FixtureTaggedRecord, FixtureTaggedRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  late TomDataSourceInfo dsi;
  late TomDataSource ds;
  late FixtureTaggedRepository records;
  late Map<String, int> ids;

  setUpAll(() async {
    if (!reachable) return;
    initializeReflection();
    dsi = await TestDatabase.register();
    ds = dsi.datasource;
    await TestDatabase.ensureFixtureAssociationTables(dsi);
    records = FixtureTaggedRepository();
    addTearDown(TestDatabase.reset);
  });

  Future<int> insert(String table, String column, String value) async {
    await ds.executeCommand('INSERT INTO $table ($column) VALUES (:v)', {
      'v': value,
    });
    final rows = await ds.executeQuery<TomCountResult>(
      'SELECT MAX(id) AS count FROM $table',
    );
    return rows.single.count;
  }

  Future<void> link(String record, String tag) => ds.executeCommand(
    'INSERT INTO fixture_tag_link (tagged_id, tag_id) VALUES (:r, :t)',
    {'r': ids[record], 't': ids[tag]},
  );

  // alpha: red, blue — beta: red — gamma: green — delta: none.
  setUp(() async {
    if (!reachable) return;
    await TestDatabase.truncateFixtureAssociationTables(dsi);
    ids = {
      for (final tag in ['red', 'blue', 'green'])
        tag: await insert('fixture_tag', 'name', tag),
      for (final record in ['alpha', 'beta', 'gamma', 'delta'])
        record: await insert('fixture_tagged', 'label', record),
    };
    await link('alpha', 'red');
    await link('alpha', 'blue');
    await link('beta', 'red');
    await link('gamma', 'green');
  });

  Future<List<String>> labels(
    String sentence, [
    Map<String, Object?>? p,
  ]) async => [
    for (final r in await records.findByQuerySentence(sentence, p ?? {}))
      r.label!,
  ]..sort();

  group('a filter on an association\'s columns', () {
    test(
      'answers the owners with a matching associated row, each once',
      () async {
        expect(await labels('find by tags.name = :n', {'n': 'red'}), [
          'alpha',
          'beta',
        ]);
        // Both of alpha's tags match; it is still one row.
        expect(await labels('find by tags.name like :p', {'p': '%e%'}), [
          'alpha',
          'beta',
          'gamma',
        ]);
      },
      skip: skip,
    );

    test('combines with the owner\'s own columns and with OR', () async {
      expect(
        await labels('find by label = :l and tags.name = :n', {
          'l': 'beta',
          'n': 'red',
        }),
        ['beta'],
      );
      expect(
        await labels('find by tags.name = :a or tags.name = :b', {
          'a': 'blue',
          'b': 'green',
        }),
        ['alpha', 'gamma'],
      );
    }, skip: skip);

    test('is empty / is not empty', () async {
      expect(await labels('find by tags is empty'), ['delta']);
      expect(await labels('find by tags is not empty'), [
        'alpha',
        'beta',
        'gamma',
      ]);
    }, skip: skip);

    test('serves the count and the delete sentences too', () async {
      expect(
        (await records.countByQuerySentence('count by tags.name = :n', {
          'n': 'red',
        })).get(),
        2,
      );
      expect(
        await records.deleteByQuerySentence('delete by tags is empty', {}),
        1,
      );
      expect(await labels('find by label is not null'), [
        'alpha',
        'beta',
        'gamma',
      ]);
    }, skip: skip);
  });

  test('a delete that binds nothing runs (MariaDB: no prepare step)', () async {
    expect(
      await records.deleteByQuerySentence('delete by label is null', {}),
      0,
    );
    await ds.executeCommand('INSERT INTO fixture_tagged (label) VALUES (NULL)');
    expect(
      await records.deleteByQuerySentence('delete by label is null', {}),
      1,
    );
  }, skip: skip);

  group('subqueries from the builder', () {
    TomColumnInformation column(Type type, String field) =>
        TomAnnotationAnalyzer.determineColumn(field, [
          TomAnnotationAnalyzer.analysePersistentType(type),
        ]);

    Future<List<String>> run(
      TomOperator<TomDbBool> where,
      Map<String, Object?> p,
    ) async => [
      for (final r in await records.findByQuery(
        TomSelect([FixtureTaggedRecord], query: where),
        p,
      ))
        r.label!,
    ]..sort();

    TomSubquery linksTo(String parameter) => TomSubquery(
      [FixtureTagLink],
      projection: records.intF('taggedId', column(FixtureTagLink, 'taggedId')),
      where: records.eq<TomDbInt>(
        records.intF('tagId', column(FixtureTagLink, 'tagId')),
        records.p<TomDbInt>(parameter),
      ),
    );

    final recordId = () =>
        records.intF('id', column(FixtureTaggedRecord, 'id'));

    test('IN (SELECT …) and NOT IN', () async {
      expect(
        await run(records.isInSubquery<TomDbInt>(recordId(), linksTo('t')), {
          't': ids['red'],
        }),
        ['alpha', 'beta'],
      );
      expect(
        await run(records.isNotInSubquery<TomDbInt>(recordId(), linksTo('t')), {
          't': ids['red'],
        }),
        ['delta', 'gamma'],
      );
    }, skip: skip);

    test('a correlated EXISTS and NOT EXISTS', () async {
      final linked = TomSubquery(
        [FixtureTagLink],
        where: records.eq<TomDbInt>(
          records.intF('taggedId', column(FixtureTagLink, 'taggedId')),
          recordId(),
        ),
      );
      expect(await run(records.exists(linked), {}), ['alpha', 'beta', 'gamma']);
      expect(await run(records.notExists(linked), {}), ['delta']);
    }, skip: skip);
  });
}

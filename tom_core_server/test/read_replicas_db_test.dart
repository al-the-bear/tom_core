/// Read replicas against a live database: a primary and a replica that are two
/// databases on one server, holding different rows, so every read shows which
/// one answered it.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixturePinnedNoteRepository,
        FixtureReplicaNote,
        FixtureReplicaNoteRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const _ddl = '''
CREATE TABLE fixture_replica_note (
  id   BIGINT       NOT NULL AUTO_INCREMENT,
  text VARCHAR(100) NULL,
  PRIMARY KEY (id)
)''';

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  final replicaDatabase = '${TestDatabase.databaseName}_r';
  late TomDataSource primaryDirect;
  late TomDataSource replicaDirect;
  late TomSqlDatasource routed;
  late FixtureReplicaNoteRepository notes;

  Map<String, dynamic> settings({String? database}) => {
    ...TestDatabase.datasourceConfig[TestDatabase.datasourceName]
        as Map<String, dynamic>,
    if (database != null) 'databaseName': database,
  };

  setUpAll(() async {
    if (!reachable) return;
    initializeReflection();
    await TestDatabase.provision();
    // Two data sources the routing does not touch: one on each database, for
    // setting the stage and reading what each one holds.
    await TomDataSourceInfo.initializeDatasourceInfo({
      'replica_test_primary': settings(),
    });
    primaryDirect = TomDataSourceInfo.getDataSourceInfo(
      'replica_test_primary',
    )!.datasource;
    await primaryDirect.executeCommand(
      TestDatabase.isPostgres
          ? 'CREATE DATABASE "$replicaDatabase"'
          : 'CREATE DATABASE `$replicaDatabase`',
    );
    // Registered after provision()'s own teardown, so it runs first: the
    // replica database goes, and every data source closes, while the suite
    // database still exists.
    addTearDown(() async {
      await primaryDirect.executeCommand(
        TestDatabase.isPostgres
            ? 'DROP DATABASE IF EXISTS "$replicaDatabase" WITH (FORCE)'
            : 'DROP DATABASE IF EXISTS `$replicaDatabase`',
      );
      await TestDatabase.reset();
    });
    await TomDataSourceInfo.initializeDatasourceInfo({
      'replica_test_replica': settings(database: replicaDatabase),
    });
    replicaDirect = TomDataSourceInfo.getDataSourceInfo(
      'replica_test_replica',
    )!.datasource;
    for (final ds in [primaryDirect, replicaDirect]) {
      await TestDatabase.execute(ds as TomSqlDatasource, _ddl);
    }
    // The data source the entities use: the primary, with the replica.
    await TomDataSourceInfo.initializeDatasourceInfo({
      TestDatabase.datasourceName: {
        ...settings(),
        'replicas': [
          {'databaseName': replicaDatabase},
        ],
      },
    });
    routed =
        TomDataSourceInfo.getDataSourceInfo(
              TestDatabase.datasourceName,
            )!.datasource
            as TomSqlDatasource;
    notes = FixtureReplicaNoteRepository();
  });

  setUp(() async {
    if (!reachable) return;
    for (final (ds, text) in [
      (primaryDirect, 'primary'),
      (replicaDirect, 'replica'),
    ]) {
      await ds.executeCommand('DELETE FROM fixture_replica_note');
      await ds.executeCommand(
        'INSERT INTO fixture_replica_note (text) VALUES (:t)',
        {'t': text},
      );
    }
  });

  Future<List<String?>> texts() async => [
    for (final n in await notes.findAll()) n.text,
  ];

  Future<T> as<T>(String user, Future<T> Function() body) => runZoned(
    body,
    zoneValues: {
      TomPrincipal: TomPrincipal(
        user: TomUser(id: user, username: user),
        authenticated: true,
      ),
    },
  );

  test('the data source opened its replica', () {
    expect(routed.replicaSources, hasLength(1));
    expect(
      routed.replicaSources.single.registeredName,
      '${TestDatabase.datasourceName}.replica1',
    );
  }, skip: skip);

  test(
    'outside read-only work a repository read is served by the primary',
    () async {
      expect(await texts(), ['primary']);
    },
    skip: skip,
  );

  test(
    'in read-only work a repository read is served by the replica',
    () async {
      expect(await TomReplicaRouting.readOnly(texts), ['replica']);
      expect(
        await TomReplicaRouting.readOnly(
          () =>
              notes.findByQuerySentence('find by text = :t', {'t': 'replica'}),
        ).then((r) => r.map((n) => n.text).toList()),
        ['replica'],
      );
    },
    skip: skip,
  );

  test('a read-only transaction is served by the replica', () async {
    final read = await TomTransactionManager.runInTransaction(
      (_) => texts(),
      isReadOnly: true,
    );
    expect(read, ['replica']);
  }, skip: skip);

  test('everything inside a write transaction runs on the primary', () async {
    final read = await TomReplicaRouting.readOnly(
      () => TomTransactionManager.runInTransaction((_) async {
        await notes.save(FixtureReplicaNote()..text = 'written');
        return texts();
      }),
    );
    expect(read, unorderedEquals(['primary', 'written']));
  }, skip: skip);

  test('a principal that has just written reads its write from the primary; '
      'another still reads the replica', () async {
    await as('ada', () async {
      await TomReplicaRouting.readOnly(
        () => notes.save(FixtureReplicaNote()..text = "ada's"),
      );
      expect(
        await TomReplicaRouting.readOnly(texts),
        unorderedEquals(['primary', "ada's"]),
      );
    });
    expect(await as('bob', () => TomReplicaRouting.readOnly(texts)), [
      'replica',
    ]);
  }, skip: skip);

  test('the stickiness ends with its window', () async {
    routed.replicaStickinessMs = 50;
    addTearDown(() => routed.replicaStickinessMs = 5000);
    await as('cy', () async {
      await notes.save(FixtureReplicaNote()..text = "cy's");
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(await TomReplicaRouting.readOnly(texts), ['replica']);
    });
  }, skip: skip);

  test('primary() sends a read to the primary whatever the context', () async {
    expect(
      await TomReplicaRouting.readOnly(() => TomReplicaRouting.primary(texts)),
      ['primary'],
    );
  }, skip: skip);

  test('an entity marked @TomPrimaryReads is read from the primary', () async {
    final pinned = FixturePinnedNoteRepository();
    final read = await TomReplicaRouting.readOnly(pinned.findAll);
    expect(read.map((n) => n.text), ['primary']);
  }, skip: skip);

  test(
    'a statement that is not a repository read runs on the primary',
    () async {
      final rows = await TomReplicaRouting.readOnly(
        () => routed.executeQuery<FixtureReplicaNote>(
          'SELECT id, text FROM fixture_replica_note',
        ),
      );
      expect(rows.map((n) => n.text), ['primary']);
    },
    skip: skip,
  );

  test(
    'a replica that cannot be reached is left out, and the primary serves',
    () async {
      final ds =
          TomDataSource.createDatasourceOf(
                TestDatabase.isPostgres ? 'postgresql' : 'mariadb',
              )
              as TomSqlDatasource;
      await ds.initialize({
        ...settings(),
        'timeOut': 2000,
        'replicas': [
          {'port': 1},
        ],
      });
      addTearDown(ds.close);
      expect(ds.replicaSources, hasLength(1));
      final rows = await TomReplicaRouting.readOnly(
        () => TomReplicaRouting.repositoryRead(
          FixtureReplicaNote,
          () => ds.executeQuery<FixtureReplicaNote>(
            'SELECT id, text FROM fixture_replica_note',
          ),
        ),
      );
      expect(rows.map((n) => n.text), ['primary']);
    },
    skip: skip,
  );
}

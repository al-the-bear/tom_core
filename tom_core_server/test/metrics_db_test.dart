/// The data source's metrics against a live database: statement timings and
/// failures, and the pool's connections and acquire wait — read from the
/// Prometheus scrape, where an operator reads them.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`. The SQL
/// job store's backlog is covered by the job-store contract
/// `scheduling_db_test.dart` runs against it.
@Tags(['db'])
library;

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

Future<String> _scrape() async {
  final handler = const Pipeline()
      .addMiddleware(tomMetricsEndpointMiddleware())
      .addHandler((_) => Response.notFound(''));
  final response = await handler(
    Request('GET', Uri.parse('http://localhost/metrics')),
  );
  return response.readAsString();
}

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  group('data source series', () {
    late TomDataSourceInfo dsi;
    late TomSqlDatasource ds;
    const name = TestDatabase.datasourceName;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      ds = dsi.datasource as TomSqlDatasource;
    });
    setUp(TomMetrics.registry.reset);

    test('the data source is labelled with its registered name', () {
      expect(ds.registeredName, name);
    });

    test('statements are timed by operation, failures counted', () async {
      await ds.executeQuery<Object>('SELECT 1 AS one');
      await ds.executeCommand('SELECT 1');
      await expectLater(
        ds.executeCommand('SELECT * FROM no_such_table_for_metrics'),
        throwsA(isA<TomSqlDatasourceException>()),
      );

      final text = await _scrape();
      expect(
        text,
        allOf([
          contains(
            'tom_db_statement_duration_seconds_count'
            '{datasource="$name",operation="query"} 1',
          ),
          contains(
            'tom_db_statement_duration_seconds_count'
            '{datasource="$name",operation="command"} 2',
          ),
          contains(
            'tom_db_statement_errors_total'
            '{datasource="$name",operation="command"} 1',
          ),
          contains(
            'tom_db_pool_acquire_duration_seconds_count{datasource="$name"} 3',
          ),
        ]),
      );
    });

    test('the pool reports its connections by state', () async {
      final text = await _scrape();
      expect(
        text,
        allOf([
          contains('tom_db_pool_connections{datasource="$name",state="idle"}'),
          contains(
            'tom_db_pool_connections{datasource="$name",state="in_use"} 0',
          ),
          contains(
            'tom_db_pool_connections{datasource="$name",state="waiting"} 0',
          ),
          contains(
            'tom_db_pool_connections'
            '{datasource="$name",state="max"} ${ds.poolMaxSize}',
          ),
        ]),
      );
    });

    test(
      'a statement inside a transaction is timed on its pinned connection',
      () async {
        await TomTransactionManager.runInTransaction((_) async {
          await ds.executeQuery<Object>('SELECT 1 AS one');
          final text = await _scrape();
          expect(
            text,
            contains(
              'tom_db_pool_connections{datasource="$name",state="in_use"} 1',
            ),
          );
        });
        expect(
          TomMetrics.registry
              .histogram(tomDbStatementDurationMetric, help: '', unit: 's')
              .valueOf({'datasource': name, 'operation': 'query'})!
              .count,
          1,
        );
      },
    );

    test('a closed data source stops reporting its pool', () async {
      final other =
          TomDataSource.createDatasourceOf(dsi.type) as TomSqlDatasource
            ..registerAs('metrics_closing');
      await other.initialize({
        for (final e in (TestDatabase.datasourceConfig[name] as Map).entries)
          if (!TomDataSourceInfo.registryKeys.contains(e.key)) e.key: e.value,
      });
      expect(await _scrape(), contains('datasource="metrics_closing"'));
      await other.close();
      expect(await _scrape(), isNot(contains('datasource="metrics_closing"')));
    });
  }, skip: skip);
}

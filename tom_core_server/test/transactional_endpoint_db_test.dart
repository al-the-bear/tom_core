/// A `@TomTransactional` endpoint's transaction, against a real database.
///
/// The pipeline opens a transaction for such an endpoint and commits or rolls
/// it back, but it cannot know which data sources the endpoint will touch. So a
/// data source enlists itself at the point of use: the first statement it is
/// asked to run inside a running transaction joins it. Before that, nothing in
/// the framework enlisted anything, and the transaction the pipeline concluded
/// was empty -- an endpoint that threw half way through had its rollback
/// called and nothing was undone, because every write had autocommitted.
///
/// These tests go through the router, a repository and MariaDB, because the
/// defect lived in the seam between all three: every part was correct alone.
@Tags(['db'])
library;

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

Request _get(String path) => Request(
  'GET',
  Uri.parse('http://localhost$path'),
  context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
);

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('a @TomTransactional endpoint (DB-backed)', () {
    late Router router;
    late TomSqlDatasource reader;

    setUpAll(() async {
      initializeReflection();
      // The router scans every reflected service, and FixtureAccessApiService
      // resolves through its registered contract.
      registerFixtureAccessApi();
      await TestDatabase.provision();
      await TomDataSourceInfo.initializeDatasourceInfo(
        TestDatabase.datasourceConfig,
      );
      final info = TomDataSourceInfo.getDataSourceInfo(
        TestDatabase.datasourceName,
      )!;
      reader = info.datasource as TomSqlDatasource;
      await TestDatabase.ensureFixtureTaskTable(info);
    });

    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType<FixtureApiServer>(FixtureApiServer());
      TomBean.withType<TomHealthServer>(TomHealthServer());
      router = TomEndpointRouting().initializeRouter();
    });

    tearDown(() async {
      TomBean.resetBeanContext();
      await reader.executeCommand(
        "DELETE FROM fixture_task WHERE title LIKE 'txe-%'",
      );
    });

    Future<List<String?>> storedTitles() async {
      final rows = await reader.executeQuery<FixtureTaskRecord>(
        "SELECT id, title, priority, done FROM fixture_task "
        "WHERE title LIKE 'txe-%' ORDER BY id",
      );
      return rows.map((r) => r.title).toList();
    }

    test('a completed call commits the repository write', () async {
      final response = await router.call(
        _get('/fixture/transactional_write?title=txe-kept&fail=false'),
      );
      expect(response.statusCode, 200);
      expect(await storedTitles(), ['txe-kept']);
    });

    test('a call that throws after writing leaves nothing behind', () async {
      final response = await router.call(
        _get('/fixture/transactional_write?title=txe-undone&fail=true'),
      );
      expect(response.statusCode, isNot(200));
      // The row was written through the repository before the throw. It is
      // absent only because the write ran inside the endpoint's transaction and
      // the rollback undid it -- with the data source outside the transaction,
      // the write had autocommitted and this read found it.
      expect(await storedTitles(), isEmpty);
    });

    test(
      'the data source is released once the transaction concludes',
      () async {
        // A transaction hands its pooled connection back when it concludes. A
        // connection that stayed pinned would leave the pool one short after
        // every transactional request, until no request could run at all.
        await router.call(
          _get('/fixture/transactional_write?title=txe-first&fail=true'),
        );
        await router.call(
          _get('/fixture/transactional_write?title=txe-second&fail=false'),
        );
        expect(await storedTitles().timeout(const Duration(seconds: 5)), [
          'txe-second',
        ]);
      },
    );

    test(
      'a request arriving while a transaction is open runs outside it',
      () async {
        // The first call writes and parks inside its transaction, holding its
        // pooled connection. The second arrives then and runs on a connection
        // of its own. Had it shared the first call's connection, its INSERT
        // would have run inside that transaction and the first call's rollback
        // would have taken it too.
        final parked = Completer<void>();
        final release = Completer<void>();
        FixtureApiServer.transactionalWriteParked = parked;
        FixtureApiServer.transactionalWriteRelease = release;
        addTearDown(() {
          FixtureApiServer.transactionalWriteParked = null;
          FixtureApiServer.transactionalWriteRelease = null;
        });

        final failing = router.call(
          _get('/fixture/transactional_write?title=txe-rolled&fail=true'),
        );
        await parked.future;
        // Only the first call parks.
        FixtureApiServer.transactionalWriteParked = null;
        FixtureApiServer.transactionalWriteRelease = null;
        final passing = router.call(
          _get('/fixture/transactional_write?title=txe-kept-too&fail=false'),
        );
        // Give the second call every chance to run into the open transaction.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        release.complete();

        final responses = await Future.wait([failing, passing]);
        expect(responses.map((r) => r.statusCode), [isNot(200), 200]);
        expect(await storedTitles(), ['txe-kept-too']);
      },
    );
  }, skip: skipReason);
}

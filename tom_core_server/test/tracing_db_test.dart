/// The span tree of a request that queries a live database and calls out over
/// HTTP, as the OpenTelemetry exporter receives it.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'dart:io';

import 'package:opentelemetry/api.dart' as otel;
import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

Object? _attr(otel_sdk.ReadOnlySpan span, String key) =>
    TomInMemorySpanExporter.attributeOf(span, key);

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  group('a traced request', () {
    late TomSqlDatasource ds;
    late TomInMemorySpanExporter exported;
    late HttpServer callee;

    Handler served(Handler handler) => const Pipeline()
        .addMiddleware(tomRequestLogInfoMiddleware())
        .addMiddleware(tomRequestContextMiddleware())
        .addHandler(handler);

    setUpAll(() async {
      initializeReflection();
      ds = (await TestDatabase.register()).datasource as TomSqlDatasource;
      callee = await shelf_io.serve(
        served((_) => Response.ok('pong')),
        InternetAddress.loopbackIPv4,
        0,
      );
    });
    tearDownAll(() => callee.close(force: true));

    setUp(() {
      TomHttpResilience.reset();
      exported = TomInMemorySpanExporter();
      TomTracing.install(
        TomOtelTracer(
          processors: [otel_sdk.SimpleSpanProcessor(exported)],
          resource: {'service.name': 'tracing-db-test'},
        ),
      );
    });
    tearDown(() => TomTracing.install(null));

    test('exports the tree: request, transaction, statement, call', () async {
      final client = TomResilientClient();
      addTearDown(client.close);
      final handler = served((request) async {
        (request.context[TomRequestLogInfo.contextName]! as TomRequestLogInfo)
                .route =
            '/report';
        await TomTransactionManager.runInTransaction((_) async {
          await ds.executeQuery<Object>('SELECT :secret AS v', {
            'secret': 'a-bound-value',
          });
        });
        await client.get(Uri.parse('http://127.0.0.1:${callee.port}/ping'));
        return Response.ok('');
      });

      final response = await handler(
        Request('GET', Uri.parse('http://localhost/report')),
      );
      expect(response.statusCode, 200);

      final request = exported.named('GET /report').single;
      expect(request.kind, otel.SpanKind.server);
      expect(request.parentSpanId.isValid, isFalse);

      final children = exported.childrenOf(request);
      final transaction = children.singleWhere((s) => s.name == 'transaction');
      final call = children.singleWhere((s) => s.kind == otel.SpanKind.client);
      expect(children, hasLength(2));
      expect(_attr(transaction, 'tom.transaction.outcome'), 'committed');

      final statement = exported
          .childrenOf(transaction)
          .singleWhere((s) => s.name == 'SELECT');
      expect(statement.kind, otel.SpanKind.client);
      expect(
        _attr(statement, 'db.system.name'),
        TestDatabase.isPostgres ? 'postgresql' : 'mariadb',
      );
      expect(_attr(statement, 'db.operation.name'), 'SELECT');
      expect(_attr(statement, 'tom.datasource'), TestDatabase.datasourceName);
      final text = _attr(statement, 'db.query.text')! as String;
      expect(text, startsWith('SELECT'));
      expect(text, isNot(contains('a-bound-value')));
      for (final span in exported.spans) {
        expect(
          span.attributes.keys.map((k) => '${span.attributes.get(k)}'),
          isNot(contains(contains('a-bound-value'))),
          reason: 'a bound value is never recorded (${span.name})',
        );
      }

      expect(call.name, 'GET');
      expect(_attr(call, 'http.response.status_code'), 200);
      final calleeSpan = exported.childrenOf(call).single;
      expect(calleeSpan.kind, otel.SpanKind.server);
      expect(
        calleeSpan.spanContext.traceId.toString(),
        request.spanContext.traceId.toString(),
      );
    }, skip: skip);

    test('a statement outside traced work records nothing', () async {
      await ds.executeQuery<Object>('SELECT 1 AS one');
      expect(exported.spans, isEmpty);
    }, skip: skip);

    test('a failing statement is a failed span', () async {
      await expectLater(
        TomTracing.trace(
          'work',
          (_) => ds.executeCommand('SELECT * FROM no_such_table_for_tracing'),
        ),
        throwsA(isA<TomSqlDatasourceException>()),
      );
      final statement = exported.named('SELECT').single;
      expect(statement.status.code, otel.StatusCode.error);
      expect(
        _attr(statement, 'db.query.text'),
        'SELECT * FROM no_such_table_for_tracing',
      );
    }, skip: skip);
  }, skip: skip);
}

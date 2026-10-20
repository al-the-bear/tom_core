/// Structured logs and the framework readiness check, as a server exposes
/// them: the correlation ids every request gets, the fields of a JSON log
/// line, the `logFormat` setting, and what `GET /ready` answers about data
/// sources, migrations and outboxes.
///
/// The data source half of readiness needs a database and lives in
/// `structured_logs_readiness_db_test.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

const String _traceparent =
    '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01';

/// Captures structured log lines instead of printing them.
class _Lines {
  final List<Map<String, Object?>> lines = [];
  late final TomJsonLogOutput output = TomJsonLogOutput(
    writer: (line, _) => lines.add(jsonDecode(line) as Map<String, Object?>),
  );
}

class _BindableConfig extends TomBaseServerConfiguration {
  _BindableConfig() : super([]) {
    noSsl = true;
    host = '127.0.0.1';
    isolateCount = 1;
    port = 0;
  }

  @override
  void setValues(Map<String, Object?> values) {}
}

/// A message router whose transport accepts everything.
TomMessageRouter _router() =>
    TomMessageRouter()..register(TomMemoryMessageTransport());

void main() {
  setUpAll(initializeReflection);

  late TomLogOutput previousOutput;
  late TomLogLevel previousLevel;
  late _Lines captured;

  setUp(() {
    previousOutput = tomLog.logOutput;
    previousLevel = tomLog.logLevel;
    captured = _Lines();
    tomLog.logOutput = captured.output;
    tomLog.setLogLevel(TomLogLevel.all);
  });
  tearDown(() {
    tomLog.logOutput = previousOutput;
    tomLog.setLogLevel(previousLevel);
    TomHealthServer.resetHealthChecks();
    TomDbMigrations.resetLastRun();
  });

  group('request context', () {
    Handler pipeline(void Function() inHandler) => const Pipeline()
        .addMiddleware(tomRequestContextMiddleware())
        .addMiddleware(
          tomDefaultAuthenticationMiddleware('structured-logs-test'),
        )
        .addHandler((_) {
          inHandler();
          return Response.ok('ok');
        });

    test(
      'a request continues the caller trace with a span of its own',
      () async {
        TomTraceContext? seen;
        final response = await pipeline(() => seen = TomTraceContext.current)(
          Request(
            'GET',
            Uri.parse('http://localhost/a'),
            headers: {'traceparent': _traceparent},
          ),
        );
        expect(seen!.traceId, '4bf92f3577b34da6a3ce929d0e0e4736');
        expect(seen!.parentSpanId, '00f067aa0ba902b7');
        expect(seen!.spanId, isNot('00f067aa0ba902b7'));
        expect(response.headers['traceparent'], seen!.traceparent);
      },
    );

    test('a request without a valid traceparent starts a trace', () async {
      TomTraceContext? seen;
      await pipeline(() => seen = TomTraceContext.current)(
        Request(
          'GET',
          Uri.parse('http://localhost/a'),
          headers: {'traceparent': 'not-a-traceparent'},
        ),
      );
      expect(seen, isNotNull);
      expect(seen!.parentSpanId, isNull);
    });

    test(
      'authentication keeps the request id, and the response names it',
      () async {
        String? seen;
        final response = await pipeline(
          () => seen = getFromCurrentZone<TomRequestId>()?.uuid,
        )(Request('GET', Uri.parse('http://localhost/a')));
        expect(seen, isNotNull);
        expect(response.headers[tomRequestIdHeader], seen);
      },
    );

    test('every line logged while serving carries the request ids', () async {
      late TomTraceContext trace;
      late String requestId;
      await TomTenantContext.run(
        'acme',
        () => pipeline(() {
          trace = TomTraceContext.current!;
          requestId = getFromCurrentZone<TomRequestId>()!.uuid;
          tomLog.info('serving');
        })(Request('GET', Uri.parse('http://localhost/a'))),
      );
      final line = captured.lines.lastWhere((l) => l['message'] == 'serving');
      expect(line['trace_id'], trace.traceId);
      expect(line['span_id'], trace.spanId);
      expect(line['request_id'], requestId);
      expect(line['tenant'], 'acme');
      // The fixed fields name the work, never a person.
      expect(
        line.keys.toSet().difference({
          'timestamp',
          'level',
          'message',
          'logger',
          'isolate',
          'trace_id',
          'span_id',
          'request_id',
          'tenant',
        }),
        isEmpty,
      );
    });
  });

  group('logFormat', () {
    test('json replaces the default console output', () {
      tomLog.logOutput = TomConsoleLogOutput();
      expect(TomServer.applyLogFormat('json'), isTrue);
      expect(tomLog.logOutput, isA<TomJsonLogOutput>());
    });

    test('an output the application installed is kept', () {
      final own = captured.output;
      expect(TomServer.applyLogFormat('json'), isTrue);
      expect(tomLog.logOutput, same(own));
    });

    test('text changes nothing; an unknown value is refused', () {
      tomLog.logOutput = TomConsoleLogOutput();
      expect(TomServer.applyLogFormat('text'), isTrue);
      expect(tomLog.logOutput, isA<TomConsoleLogOutput>());
      expect(TomServer.applyLogFormat('yaml'), isFalse);
      expect(tomLog.logOutput, isA<TomConsoleLogOutput>());
    });
  });

  group('framework readiness', () {
    test('with nothing registered the server is ready', () async {
      final status = await TomFrameworkReadinessAnalyzer().analyzeHealth();
      expect(status.isHealthy, isTrue);
      expect(status.message.split('\n').first, 'ready');
      expect(status.message, contains('migrations: not run in this process'));
    });

    test('a failed migration makes the server not ready', () async {
      await expectLater(
        TomDbMigrations.migrateDatabases('does/not/exist'),
        throwsA(isA<TomDbMigrationException>()),
      );
      expect(TomDbMigrations.lastRun.state, TomMigrationRunState.failed);
      final status = await TomFrameworkReadinessAnalyzer().analyzeHealth();
      expect(status.isHealthy, isFalse);
      expect(status.statusCode, 503);
      expect(status.message.split('\n').first, 'not ready');
      expect(status.message, contains('migrations: failed:'));
    });

    test('a started outbox is checked; a stopped one is not ready', () async {
      final outbox = TomMessageOutbox(router: _router())..start();
      addTearDown(outbox.close);
      expect(TomMessageOutbox.started, contains(outbox));

      var status = await TomFrameworkReadinessAnalyzer().analyzeHealth();
      expect(status.isHealthy, isTrue);
      expect(status.message, contains('outbox messaging.outbox: ok'));

      outbox.scheduler.stop();
      status = await TomFrameworkReadinessAnalyzer().analyzeHealth();
      expect(status.isHealthy, isFalse);
      expect(
        status.message,
        contains('outbox messaging.outbox: not delivering'),
      );

      await outbox.close();
      expect(TomMessageOutbox.started, isNot(contains(outbox)));
    });

    test(
      'a message waiting past maxOutboxWait makes the server not ready',
      () async {
        var now = DateTime.utc(2026, 10, 20, 8);
        final outbox = TomMessageOutbox(router: _router(), clock: () => now)
          ..start();
        addTearDown(outbox.close);
        // Let the pass start() runs finish first; the next one is a tick
        // interval away, so the message below stays queued.
        await outbox.scheduler.drain();
        await Future<void>.delayed(Duration.zero);
        await outbox.send(
          TomMessage.email(
            to: [TomRecipient('ops@example.com')],
            subject: 'queued',
            text: 'waiting',
          ),
        );
        final analyzer = TomFrameworkReadinessAnalyzer(
          maxOutboxWait: const Duration(minutes: 10),
          clock: () => now,
        );
        expect((await analyzer.analyzeHealth()).isHealthy, isTrue);
        now = now.add(const Duration(minutes: 11));
        final status = await analyzer.analyzeHealth();
        expect(status.isHealthy, isFalse);
        expect(status.message, contains('the oldest message has waited'));
      },
    );
  });

  group('a started server', () {
    setUp(() {
      TomBean.resetBeanContext();
      TomBean.withType<FixtureApiServer>(FixtureApiServer());
      TomBean.withType<TomHealthServer>(TomHealthServer());
      TomBean.withType<FixtureAccessApiService>(FixtureAccessApiService());
      registerFixtureAccessApi();
    });
    tearDown(TomBean.resetBeanContext);

    Future<HttpClientResponse> get(HttpServer server, String path) async {
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final request = await client.get('127.0.0.1', server.port, path);
      request.headers.set('traceparent', _traceparent);
      return request.close();
    }

    test(
      'answers /ready from the framework checks, /health separately',
      () async {
        final server = await TomServer(_BindableConfig()).start();
        addTearDown(() => server.close(force: true));
        expect(
          TomHealthServer.readinessAnalyzer,
          isA<TomFrameworkReadinessAnalyzer>(),
        );

        var ready = await get(server, '/ready');
        expect(ready.statusCode, 200);
        expect(await utf8.decodeStream(ready), startsWith('ready'));

        TomDbMigrations.resetLastRun();
        await expectLater(
          TomDbMigrations.migrateDatabases('does/not/exist'),
          throwsA(isA<TomDbMigrationException>()),
        );
        ready = await get(server, '/ready');
        expect(ready.statusCode, 503);
        expect(await utf8.decodeStream(ready), startsWith('not ready'));

        // Liveness does not follow a dependency: a failed migration is not a
        // reason to restart the process.
        final live = await get(server, '/health');
        expect(live.statusCode, 200);
        await live.drain<void>();
      },
    );

    test('a request is answered with its request id and server span', () async {
      final server = await TomServer(_BindableConfig()).start();
      addTearDown(() => server.close(force: true));
      final response = await get(server, '/health');
      await response.drain<void>();
      final requestId = response.headers.value(tomRequestIdHeader);
      expect(requestId, isNotNull);
      final trace = TomTraceContext.parse(
        response.headers.value('traceparent'),
      );
      expect(trace!.traceId, '4bf92f3577b34da6a3ce929d0e0e4736');
      expect(trace.spanId, isNot('00f067aa0ba902b7'));
    });

    test('an application readiness analyzer is not replaced', () async {
      TomHealthServer.installReadinessAnalyzer(_Own());
      final server = await TomServer(_BindableConfig()).start();
      addTearDown(() => server.close(force: true));
      expect(TomHealthServer.readinessAnalyzer, isA<_Own>());
    });
  });
}

class _Own extends TomHealthAnalyzer {
  @override
  Future<TomHealthStatus> analyzeHealth() async =>
      const TomHealthStatus.healthy('mine');
}

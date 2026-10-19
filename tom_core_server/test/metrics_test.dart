/// The server's metrics: the request series, the Prometheus scrape endpoint,
/// the cache and rate-limit series, and the OTLP exporter.
///
/// The statement and pool series need a database and live in
/// `metrics_db_test.dart`; the scheduler's series are the kernel's and are
/// tested there. The scrape test below reads a job series too, because the
/// endpoint is where every module's series meet.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

/// A connection seen from [address], as shelf's adapter records it.
class _Connection implements HttpConnectionInfo {
  _Connection(String address) : remoteAddress = InternetAddress(address);

  @override
  final InternetAddress remoteAddress;

  @override
  int get remotePort => 40000;

  @override
  int get localPort => 8080;
}

Request _request(
  String path, {
  String method = 'GET',
  Map<String, String> headers = const {},
  String address = '10.0.0.1',
}) => Request(
  method,
  Uri.parse('http://localhost$path'),
  headers: headers,
  context: {TomClientAddress.connectionInfoKey: _Connection(address)},
);

/// The server's outer pipeline as `TomServer.start` composes it, around a
/// router that serves `/tasks/<id>` and nothing else.
Handler _pipeline({String token = ''}) => const Pipeline()
    .addMiddleware(tomRequestLogInfoMiddleware())
    .addMiddleware(tomMetricsEndpointMiddleware(token: token))
    .addMiddleware(tomRequestMetricsMiddleware())
    .addMiddleware(tomRateLimitMiddleware())
    .addHandler((request) {
      if (!request.url.path.startsWith('tasks/')) {
        return Response.notFound('');
      }
      // What the endpoint pipeline does once an endpoint matched.
      (request.context[TomRequestLogInfo.contextName] as TomRequestLogInfo)
              .route =
          '/tasks/<id>';
      return Response.ok('task');
    });

Future<String> _scrape(Handler handler, {String token = ''}) async {
  final response = await handler(
    _request(
      '/metrics',
      headers: {if (token.isNotEmpty) 'authorization': 'Bearer $token'},
    ),
  );
  expect(response.statusCode, 200);
  expect(response.headers['content-type'], tomPrometheusContentType);
  return response.readAsString();
}

void main() {
  setUpAll(initializeReflection);
  setUp(() {
    TomMetrics.registry.reset();
    TomRateLimits.reset();
  });
  tearDown(TomRateLimits.reset);

  group('request series', () {
    test(
      'a request is counted under its route pattern, not its path',
      () async {
        final handler = _pipeline();
        await handler(_request('/tasks/41'));
        await handler(_request('/tasks/42'));

        final requests = TomMetrics.registry.counter(
          'tom_http_server_requests',
          help: '',
        );
        expect(
          requests.valueOf({
            'method': 'GET',
            'route': '/tasks/<id>',
            'status': '200',
          }),
          2,
        );
        final duration = TomMetrics.registry.histogram(
          'tom_http_server_request_duration_seconds',
          help: '',
        );
        expect(
          duration.valueOf({'method': 'GET', 'route': '/tasks/<id>'})!.count,
          2,
        );
      },
    );

    test(
      'a path no endpoint matched adds one series, whatever the path',
      () async {
        final handler = _pipeline();
        for (final path in ['/wp-admin', '/.env', '/x/y/z']) {
          expect((await handler(_request(path))).statusCode, 404);
        }
        final requests = TomMetrics.registry.counter(
          'tom_http_server_requests',
          help: '',
        );
        expect(
          requests.valueOf({
            'method': 'GET',
            'route': tomUnmatchedRoute,
            'status': '404',
          }),
          3,
        );
      },
    );

    test('an error escaping every layer is counted as a 500', () async {
      final handler = const Pipeline()
          .addMiddleware(tomRequestLogInfoMiddleware())
          .addMiddleware(tomRequestMetricsMiddleware())
          .addHandler((_) => throw StateError('boom'));
      await expectLater(handler(_request('/a')), throwsStateError);
      expect(
        TomMetrics.registry
            .counter('tom_http_server_requests', help: '')
            .valueOf({
              'method': 'GET',
              'route': tomUnmatchedRoute,
              'status': '500',
            }),
        1,
      );
    });
  });

  group('the scrape endpoint', () {
    test('is not itself counted as a request', () async {
      final handler = _pipeline();
      await _scrape(handler);
      await _scrape(handler);
      expect(
        await _scrape(handler),
        isNot(contains('tom_http_server_requests_total{method="GET",route=')),
      );
    });

    test('refuses a scrape without the configured token', () async {
      final handler = _pipeline(token: 's3cret');
      for (final headers in [
        const <String, String>{},
        {'authorization': 'Bearer wrong'},
        {'authorization': 'Bearer s3cret-and-more'},
      ]) {
        final response = await handler(_request('/metrics', headers: headers));
        expect(response.statusCode, 401);
        expect(response.headers['www-authenticate'], 'Bearer');
        expect(await response.readAsString(), isEmpty);
      }
      expect(await _scrape(handler, token: 's3cret'), isNotEmpty);
    });

    test('answers HEAD without a body and passes other methods on', () async {
      final handler = _pipeline();
      final head = await handler(_request('/metrics', method: 'HEAD'));
      expect(head.statusCode, 200);
      expect(await head.readAsString(), isEmpty);
      final post = await handler(_request('/metrics', method: 'POST'));
      expect(post.statusCode, 404);
    });

    test('exposes the request, cache, rate-limit and job series', () async {
      TomRateLimits.install(
        TomRateLimits(
          rules: [
            TomRateLimitRule(
              name: 'per-address',
              scope: TomRateLimitScope.address,
              limit: 1,
              window: const Duration(minutes: 1),
            ),
          ],
        ),
      );
      final handler = _pipeline();
      await TomTenantContext.run('acme', () async {
        expect((await handler(_request('/tasks/1'))).statusCode, 200);
        expect((await handler(_request('/tasks/2'))).statusCode, 429);
      });
      TomRateLimits.reset();

      TomCacheManager.addCache(TomCache('metrics-test'));
      addTearDown(() => TomCacheManager.removeCache('metrics-test'));
      await TomCache.toNameCache('metrics-test', 'k', 'v');
      expect(await TomCache.fromNameCache<String>('metrics-test', 'k'), 'v');
      expect(await TomCache.fromNameCache<String>('metrics-test', 'x'), isNull);

      final scheduler = TomScheduler(
        store: TomMemoryJobStore(),
        dispatcher: const TomInlineJobDispatcher(),
      );
      addTearDown(scheduler.close);
      scheduler.register(
        TomJobDefinition(
          name: 'nightly',
          schedule: const TomEventSchedule(
            Stream<Object?>.empty(),
            sourceName: 'test',
          ),
          body: (_) => _Ok(),
        ),
      );
      await scheduler.start();
      final now = DateTime.now();
      await scheduler.store.enqueue(
        TomJobRun(
          id: 'nightly:1',
          jobName: 'nightly',
          scheduledFor: now,
          runAt: now,
        ),
      );
      await scheduler.tick();
      await scheduler.drain();
      scheduler.stop();

      final text = await _scrape(handler);
      expect(
        text,
        allOf([
          contains(
            'tom_http_server_requests_total'
            '{method="GET",route="/tasks/<id>",status="200"} 1',
          ),
          contains(
            'tom_http_server_requests_total'
            '{method="GET",route="unmatched",status="429"} 1',
          ),
          contains(
            'tom_http_server_request_duration_seconds_bucket'
            '{method="GET",route="/tasks/<id>",le="+Inf"} 1',
          ),
          contains(
            'tom_rate_limit_refusals_total{rule="per-address",tenant="acme"} 1',
          ),
          contains(
            'tom_cache_lookups_total{cache="metrics-test",result="hit"} 1',
          ),
          contains(
            'tom_cache_lookups_total{cache="metrics-test",result="miss"} 1',
          ),
          contains('tom_job_runs_total{job="nightly",outcome="succeeded"} 1'),
          contains('tom_job_start_lag_seconds_count{job="nightly"} 1'),
          contains('tom_job_run_duration_seconds_count{job="nightly"} 1'),
          contains('tom_job_last_success_timestamp_seconds{job="nightly"}'),
          contains('# TYPE tom_job_backlog gauge'),
        ]),
      );
    });
  });

  group('cache series', () {
    test('an expired entry is counted as expired, not as a hit', () async {
      TomCacheManager.addCache(TomCache('expiring'));
      addTearDown(() => TomCacheManager.removeCache('expiring'));
      await TomCache.toNameCache(
        'expiring',
        'k',
        'v',
        DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(await TomCache.fromNameCache<String>('expiring', 'k'), isNull);
      final lookups = TomMetrics.registry.counter(
        tomCacheLookupsMetric,
        help: '',
      );
      expect(lookups.valueOf({'cache': 'expiring', 'result': 'expired'}), 1);
      expect(lookups.valueOf({'cache': 'expiring', 'result': 'hit'}), 0);
    });
  });

  group('OTLP export', () {
    late HttpServer receiver;
    late List<(String, Map<String, String>, Map<String, Object?>)> received;
    var answer = 200;

    setUp(() async {
      received = [];
      answer = 200;
      receiver = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      receiver.listen((request) async {
        final body = await utf8.decodeStream(request);
        received.add((
          request.uri.path,
          {
            for (final name in ['authorization', 'content-type'])
              if (request.headers.value(name) != null)
                name: request.headers.value(name)!,
          },
          jsonDecode(body) as Map<String, Object?>,
        ));
        request.response.statusCode = answer;
        await request.response.close();
      });
    });
    tearDown(() => receiver.close(force: true));

    TomOtlpHttpTransport transport() => TomOtlpHttpTransport(
      endpoint: Uri.parse('http://127.0.0.1:${receiver.port}/otlp'),
      headers: TomOtlpHttpTransport.parseHeaders('Authorization=Bearer%20k1'),
    );

    test(
      'posts the snapshot to v1/metrics with the configured headers',
      () async {
        final registry = TomMetricRegistry();
        registry.counter('orders', help: 'Orders.').add(3, {'kind': 'web'});
        registry.gauge('queue_depth', help: 'Depth.').set(7);
        registry
            .histogram('latency_seconds', help: 'Latency.', unit: 's')
            .record(0.02);
        final exporter = TomOtlpMetricsExporter(
          transport: transport(),
          registry: registry,
          resource: {'service.name': 'orders'},
        );
        await exporter.export();

        expect(received, hasLength(1));
        final (path, headers, body) = received.single;
        expect(path, '/otlp/v1/metrics');
        expect(headers['authorization'], 'Bearer k1');
        expect(headers['content-type'], startsWith('application/json'));
        final resourceMetrics = (body['resourceMetrics'] as List).single as Map;
        expect((resourceMetrics['resource'] as Map)['attributes'], [
          {
            'key': 'service.name',
            'value': {'stringValue': 'orders'},
          },
        ]);
        final metrics = {
          for (final m
              in ((resourceMetrics['scopeMetrics'] as List).single
                      as Map)['metrics']
                  as List)
            (m as Map)['name']: m,
        };
        final orders = metrics['orders']!['sum'] as Map;
        expect(orders['isMonotonic'], isTrue);
        expect(orders['aggregationTemporality'], 2);
        final point = (orders['dataPoints'] as List).single as Map;
        expect(point['asDouble'], 3);
        expect(point['attributes'], [
          {
            'key': 'kind',
            'value': {'stringValue': 'web'},
          },
        ]);
        expect(
          (((metrics['queue_depth']!['gauge'] as Map)['dataPoints'] as List)
                  .single
              as Map)['asDouble'],
          7,
        );
        final histogram =
            (((metrics['latency_seconds']!['histogram'] as Map)['dataPoints']
                        as List)
                    .single
                as Map);
        expect(histogram['count'], '1');
        expect(histogram['explicitBounds'], tomLatencyBuckets);
        expect(
          (histogram['bucketCounts'] as List).length,
          tomLatencyBuckets.length + 1,
        );
      },
    );

    test('a refusing receiver is reported with its status', () async {
      answer = 503;
      final exporter = TomOtlpMetricsExporter(
        transport: transport(),
        registry: TomMetricRegistry(),
      );
      await expectLater(
        exporter.export(),
        throwsA(
          isA<TomOtlpExportException>()
              .having((e) => e.key, 'key', 'otlp.export.failed')
              .having((e) => e.parameters?['status'], 'status', 503),
        ),
      );
    });

    test('close pushes once more, so a shutdown loses nothing', () async {
      final exporter = TomOtlpMetricsExporter(
        transport: transport(),
        registry: TomMetricRegistry()..counter('c', help: 'C.').add(),
        interval: const Duration(hours: 1),
      )..start();
      await exporter.close();
      expect(received, hasLength(1));
      await exporter.close();
      expect(received, hasLength(1));
    });

    test('headers are read in the OTEL_EXPORTER_OTLP_HEADERS form', () {
      expect(TomOtlpHttpTransport.parseHeaders(' API-Key = a%3Db , x=1,, '), {
        'api-key': 'a=b',
        'x': '1',
      });
      expect(
        () => TomOtlpHttpTransport.parseHeaders('novalue'),
        throwsA(
          isA<TomOtlpExportException>().having(
            (e) => e.key,
            'key',
            'otlp.config.invalid_headers',
          ),
        ),
      );
    });
  });
}

class _Ok extends TomCommand {
  @override
  Future<Object?> execute() async => 'ok';
}

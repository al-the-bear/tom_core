// ignore_for_file: avoid_print
/// Executable example for the metrics module of `tom_core_server`.
///
/// Shows what leaves a server's process and how: requests counted by the
/// pattern of the endpoint that served them rather than by their path, the
/// Prometheus scrape answered — with its own bearer token — before anything
/// else in the pipeline sees it, a cache's lookups appearing in the same
/// scrape, and the same registry pushed over OTLP to a receiver.
///
/// No server is started and no database is needed: the pipeline below is the
/// outer edge `TomServer.start` composes, around a stand-in router that
/// records its route the way the endpoint pipeline does, and the OTLP receiver
/// is an `HttpServer` bound in this process. `doc/metrics.md` lists every
/// series the framework records and the configuration that switches the two
/// exports on in a real server.
///
/// Run with `dart run example/metrics/metrics_example.dart`. Every step checks
/// its own result and the run fails when one does not hold, so a green run is
/// a verification and not just a transcript.
///
/// The behaviour shown here is pinned by `test/metrics_test.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// The token the scrape must present.
const _token = 's3cret';

/// The outer edge of a `TomServer` pipeline, around a router that serves
/// `/tasks/<id>` and nothing else.
Handler _pipeline() => const Pipeline()
    .addMiddleware(tomRequestLogInfoMiddleware())
    .addMiddleware(tomMetricsEndpointMiddleware(token: _token))
    .addMiddleware(tomRequestMetricsMiddleware())
    .addHandler((request) {
      if (!request.url.path.startsWith('tasks/')) {
        return Response.notFound('');
      }
      // What the endpoint pipeline does once an endpoint matched: record the
      // endpoint's pattern, which is what the request is labelled with.
      (request.context[TomRequestLogInfo.contextName] as TomRequestLogInfo)
              .route =
          '/tasks/<id>';
      return Response.ok('task ${request.url.pathSegments.last}');
    });

Request _get(String path, {Map<String, String> headers = const {}}) =>
    Request('GET', Uri.parse('http://localhost$path'), headers: headers);

/// The lines of [text] that are samples of [series].
List<String> _samples(String text, String series) => [
  for (final line in const LineSplitter().convert(text))
    if (line.startsWith(series)) line,
];

Future<void> run() async {
  TomMetrics.registry.reset();
  final handler = _pipeline();

  // 1. Three requests for two tasks and one path no endpoint serves. The
  //    counter is labelled with the route pattern, so the two tasks are one
  //    series — and the unknown path is `unmatched`, not itself.
  for (final path in ['/tasks/41', '/tasks/42', '/wp-admin']) {
    await handler(_get(path));
  }
  final requests = TomMetrics.registry.counter(
    'tom_http_server_requests',
    help: '',
  );
  final byPattern = requests.valueOf({
    'method': 'GET',
    'route': '/tasks/<id>',
    'status': '200',
  });
  final unmatched = requests.valueOf({
    'method': 'GET',
    'route': tomUnmatchedRoute,
    'status': '404',
  });
  print(
    '1. /tasks/<id> => ${byPattern.toInt()}, '
    '$tomUnmatchedRoute => ${unmatched.toInt()}',
  );
  check(
    byPattern == 2 && unmatched == 1,
    'two task paths count as one route pattern, an unknown path as unmatched',
  );

  // 2. A scrape without the token is refused, without a body: the endpoint
  //    checks its own credential before anything else runs.
  final refused = await handler(_get('/metrics'));
  print(
    '2. scrape without the token => ${refused.statusCode} '
    '(${refused.headers['www-authenticate']})',
  );
  check(
    refused.statusCode == 401 && (await refused.readAsString()).isEmpty,
    'a scrape without the configured bearer token is answered 401, empty',
  );

  // 3. With the token, the registry in the Prometheus text format. The
  //    scrape itself is not a request the server counts.
  final cache = TomCache('tasks');
  TomCacheManager.addCache(cache);
  await TomCache.toNameCache('tasks', '41', 'write the readme');
  await TomCache.fromNameCache<String>('tasks', '41');
  await TomCache.fromNameCache<String>('tasks', '42');

  final scrape = await handler(
    _get('/metrics', headers: {'authorization': 'Bearer $_token'}),
  );
  final text = await scrape.readAsString();
  final requestLines = _samples(text, 'tom_http_server_requests_total');
  print('3. scrape with the token => ${scrape.statusCode}');
  for (final line in requestLines) {
    print('   $line');
  }
  check(
    scrape.statusCode == 200 &&
        scrape.headers['content-type'] == tomPrometheusContentType &&
        requestLines.length == 2,
    'the scrape answers both request series and is not counted itself',
  );

  // 4. Every module records into the same registry, so the cache's lookups
  //    are in the same scrape: one hit, one miss.
  final lookups = _samples(text, 'tom_cache_lookups_total');
  print('4. cache lookups:');
  for (final line in lookups) {
    print('   $line');
  }
  check(
    lookups.contains('tom_cache_lookups_total{cache="tasks",result="hit"} 1') &&
        lookups.contains(
          'tom_cache_lookups_total{cache="tasks",result="miss"} 1',
        ),
    'a cache read is counted as a hit or a miss in the same registry',
  );
  TomCacheManager.removeCache('tasks');
  cache.stopTimers();

  // 5. The same registry pushed over OTLP. The receiver is in this process;
  //    in a server it is a collector named by `otlpEndpoint`.
  final received = <(String, String?, Map<String, Object?>)>[];
  final receiver = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  receiver.listen((request) async {
    final body = jsonDecode(await utf8.decodeStream(request));
    received.add((
      request.uri.path,
      request.headers.value('authorization'),
      body as Map<String, Object?>,
    ));
    await request.response.close();
  });
  final exporter = TomOtlpMetricsExporter(
    transport: TomOtlpHttpTransport(
      endpoint: Uri.parse('http://127.0.0.1:${receiver.port}'),
      headers: TomOtlpHttpTransport.parseHeaders('Authorization=Bearer%20k1'),
    ),
    resource: {'service.name': 'tasks'},
  );
  await exporter.export();
  final (path, authorization, body) = received.single;
  final metrics = [
    for (final resource in body['resourceMetrics'] as List)
      for (final scope in (resource as Map)['scopeMetrics'] as List)
        for (final metric in (scope as Map)['metrics'] as List) metric as Map,
  ];
  final requestSum =
      metrics.firstWhere((m) => m['name'] == 'tom_http_server_requests')['sum']
          as Map;
  print(
    '5. OTLP push => $path ($authorization), ${metrics.length} metrics, '
    'requests cumulative=${requestSum['aggregationTemporality'] == 2}',
  );
  check(
    path == '/v1/metrics' &&
        authorization == 'Bearer k1' &&
        requestSum['isMonotonic'] == true &&
        requestSum['aggregationTemporality'] == 2,
    'the push reaches v1/metrics with its header, counters as cumulative sums',
  );

  // 6. Closing the exporter pushes once more, so a server shutting down does
  //    not lose what it counted since the last push.
  await exporter.close();
  await receiver.close(force: true);
  print('6. pushes after close => ${received.length}');
  check(received.length == 2, 'close pushes the final snapshot');
}

Future<void> main() => run();

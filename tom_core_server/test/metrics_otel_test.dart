/// The metrics exports checked by the tools that consume them: the Prometheus
/// text by `promtool check metrics`, and the OTLP export by an OpenTelemetry
/// Collector that receives it and writes what it understood to a file.
///
/// `@Tags(['otel'])`, and self-skipping unless `tool/run_otel_tests.sh`
/// started the collector and named it in the environment:
///
/// | Variable | Meaning |
/// | -------- | ------- |
/// | `TOM_OTLP_TEST_ENDPOINT` | the collector's OTLP/HTTP base URL |
/// | `TOM_OTLP_TEST_OUTPUT` | the file its file exporter writes |
/// | `TOM_PROMTOOL_IMAGE` | a Prometheus image carrying `promtool` |
@Tags(['otel'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

final String? _endpoint = Platform.environment['TOM_OTLP_TEST_ENDPOINT'];
final String? _output = Platform.environment['TOM_OTLP_TEST_OUTPUT'];
final String? _promtool = Platform.environment['TOM_PROMTOOL_IMAGE'];

/// A registry holding one series of every shape the framework records, filled
/// the way the framework fills it.
Future<TomMetricRegistry> _recorded() async {
  final registry = TomMetricRegistry();
  registry
      .counter('tom_http_server_requests', help: 'HTTP requests answered.')
      .add(3, {'method': 'GET', 'route': '/tasks/<id>', 'status': '200'});
  registry
      .histogram(
        'tom_http_server_request_duration_seconds',
        help: 'How long an HTTP request took.',
        unit: 's',
      )
      .record(0.042, {'method': 'GET', 'route': '/tasks/<id>'});
  registry
      .gauge(
        'tom_job_last_success_timestamp_seconds',
        help: 'When a run of the job last succeeded.',
        unit: 's',
      )
      .set(1760000000, {'job': 'nightly'});
  registry.observe(
    tomDbPoolConnectionsMetric,
    help: 'Connections of a data source pool, by state.',
    observer: () => [
      const TomObservedValue(2, {'datasource': 'app', 'state': 'idle'}),
      const TomObservedValue(10, {'datasource': 'app', 'state': 'max'}),
    ],
  );
  return registry;
}

void main() {
  setUpAll(initializeReflection);

  group('promtool', () {
    test('accepts the scrape of every series the framework records', () async {
      // The process registry after real work, not a hand-built one: what
      // promtool lints is what a scrape of a running server answers.
      TomMetrics.registry.reset();
      final handler = const Pipeline()
          .addMiddleware(tomRequestLogInfoMiddleware())
          .addMiddleware(tomMetricsEndpointMiddleware())
          .addMiddleware(tomRequestMetricsMiddleware())
          .addHandler((_) => Response.ok('ok'));
      await handler(Request('GET', Uri.parse('http://localhost/a')));
      TomCacheManager.addCache(TomCache('promtool'));
      addTearDown(() => TomCacheManager.removeCache('promtool'));
      await TomCache.fromNameCache<String>('promtool', 'k');
      final scrape = await (await handler(
        Request('GET', Uri.parse('http://localhost/metrics')),
      )).readAsString();
      final recorded = tomPrometheusText(await (await _recorded()).collect());

      for (final text in [scrape, recorded]) {
        final process = await Process.start('docker', [
          'run',
          '--rm',
          '-i',
          '--entrypoint',
          'promtool',
          _promtool!,
          'check',
          'metrics',
        ]);
        process.stdin.write(text);
        await process.stdin.close();
        final out = await process.stdout.transform(utf8.decoder).join();
        final err = await process.stderr.transform(utf8.decoder).join();
        expect(
          await process.exitCode,
          0,
          reason: 'promtool rejected the exposition:\n$out$err\n---\n$text',
        );
      }
    });
  }, skip: _promtool == null ? 'TOM_PROMTOOL_IMAGE is not set' : null);

  group(
    'OTLP collector round trip',
    () {
      test('the collector receives every series with its points', () async {
        final output = File(_output!);
        final before = output.existsSync() ? output.lengthSync() : 0;
        final registry = await _recorded();
        final exporter = TomOtlpMetricsExporter(
          transport: TomOtlpHttpTransport(endpoint: Uri.parse(_endpoint!)),
          registry: registry,
          resource: {'service.name': 'tom_core_server_test'},
        );
        await exporter.close(); // close pushes once, then releases the client

        // The file exporter writes one ExportMetricsServiceRequest per line, in
        // the collector's own JSON — so what is read here is what the collector
        // decoded, not what was sent.
        Map<String, Map<String, Object?>>? metrics;
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (metrics == null && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          if (!output.existsSync() || output.lengthSync() <= before) continue;
          final lines = output
              .readAsStringSync()
              .substring(before)
              .split('\n')
              .where((l) => l.trim().isNotEmpty);
          for (final line in lines) {
            final request = jsonDecode(line) as Map<String, Object?>;
            for (final rm in request['resourceMetrics'] as List) {
              final attributes = ((rm as Map)['resource'] as Map)['attributes'];
              if (!jsonEncode(attributes).contains('tom_core_server_test')) {
                continue;
              }
              metrics = {
                for (final sm in rm['scopeMetrics'] as List)
                  for (final m in (sm as Map)['metrics'] as List)
                    (m as Map)['name'] as String: m.cast<String, Object?>(),
              };
            }
          }
        }

        expect(metrics, isNotNull, reason: 'the collector wrote nothing');
        expect(
          metrics!.keys,
          containsAll([
            'tom_http_server_requests',
            'tom_http_server_request_duration_seconds',
            'tom_job_last_success_timestamp_seconds',
            tomDbPoolConnectionsMetric,
          ]),
        );
        final requests = metrics['tom_http_server_requests']!['sum'] as Map;
        expect(requests['isMonotonic'], isTrue);
        expect(((requests['dataPoints'] as List).single as Map)['asDouble'], 3);
        final histogram =
            ((metrics['tom_http_server_request_duration_seconds']!['histogram']
                            as Map)['dataPoints']
                        as List)
                    .single
                as Map;
        expect(histogram['count'], '1');
        expect(histogram['sum'], 0.042);
        final pool =
            (metrics[tomDbPoolConnectionsMetric]!['gauge'] as Map)['dataPoints']
                as List;
        expect(pool, hasLength(2));
      });
    },
    skip: _endpoint == null || _output == null
        ? 'TOM_OTLP_TEST_ENDPOINT / TOM_OTLP_TEST_OUTPUT are not set'
        : null,
  );
}

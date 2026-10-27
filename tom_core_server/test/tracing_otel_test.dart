/// The span export checked by the tool that consumes it: spans sent by the
/// configured OpenTelemetry tracer to an OpenTelemetry Collector, which writes
/// what it understood to a file.
///
/// `@Tags(['otel'])`, and self-skipping unless `tool/run_otel_tests.sh`
/// started the collector and named it in the environment:
///
/// | Variable | Meaning |
/// | -------- | ------- |
/// | `TOM_OTLP_TEST_ENDPOINT` | the collector's OTLP/HTTP base URL |
/// | `TOM_OTLP_TEST_TRACES_OUTPUT` | the file its traces file exporter writes |
@Tags(['otel'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

final String? _endpoint = Platform.environment['TOM_OTLP_TEST_ENDPOINT'];
final String? _output = Platform.environment['TOM_OTLP_TEST_TRACES_OUTPUT'];

/// The configuration a deployment writes: tracing on, the collector as the
/// OTLP endpoint.
class _Configuration extends TomBaseServerConfiguration {
  _Configuration() : super(const []) {
    tracing = true;
    otlpEndpoint = _endpoint ?? '';
  }

  @override
  void setValues(Map<String, Object?> values) {}
}

void main() {
  tearDown(() => TomTracing.install(null));

  test(
    'the collector receives a request\'s spans with their tree',
    () async {
      final output = File(_output!);
      final before = output.existsSync() ? output.lengthSync() : 0;
      final tracer = TomOtelTracer.fromConfiguration(
        _Configuration(),
        serviceName: 'tom_core_server_trace_test',
      )!;
      TomTracing.install(tracer);

      final handler = const Pipeline()
          .addMiddleware(tomRequestLogInfoMiddleware())
          .addMiddleware(tomRequestContextMiddleware())
          .addHandler((request) async {
            (request.context[TomRequestLogInfo.contextName]!
                        as TomRequestLogInfo)
                    .route =
                '/tasks/<id>';
            await TomTracing.trace(
              'load task',
              attributes: {'tom.task': 42},
              (_) async {},
            );
            return Response.ok('');
          });
      final response = await handler(
        Request('GET', Uri.parse('http://localhost/tasks/42')),
      );
      final trace = TomTraceContext.parse(response.headers['traceparent'])!;
      await tracer.shutdown(); // exports what is batched

      // The file exporter writes one ExportTraceServiceRequest per line in the
      // collector's own JSON: what is read here is what the collector decoded.
      final spans = <String, Map<String, Object?>>{};
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (spans.length < 2 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!output.existsSync() || output.lengthSync() <= before) continue;
        final lines = output
            .readAsStringSync()
            .substring(before)
            .split('\n')
            .where((l) => l.trim().isNotEmpty);
        for (final line in lines) {
          final request = jsonDecode(line) as Map<String, Object?>;
          for (final rs in request['resourceSpans'] as List) {
            final attributes = ((rs as Map)['resource'] as Map)['attributes'];
            if (!jsonEncode(
              attributes,
            ).contains('tom_core_server_trace_test')) {
              continue;
            }
            for (final ss in rs['scopeSpans'] as List) {
              for (final span in (ss as Map)['spans'] as List) {
                final s = (span as Map).cast<String, Object?>();
                spans[s['name']! as String] = s;
              }
            }
          }
        }
      }

      expect(spans.keys, containsAll(['GET /tasks/<id>', 'load task']));
      final server = spans['GET /tasks/<id>']!;
      final child = spans['load task']!;
      expect(server['traceId'], trace.traceId);
      expect(server['spanId'], trace.spanId);
      expect(server['kind'], 2); // SPAN_KIND_SERVER
      expect(child['traceId'], trace.traceId);
      expect(child['parentSpanId'], trace.spanId);
      expect(
        jsonEncode(server['attributes']),
        allOf(contains('http.route'), contains('/tasks/<id>')),
      );
      expect(jsonEncode(child['attributes']), contains('tom.task'));
    },
    skip: _endpoint == null || _output == null
        ? 'TOM_OTLP_TEST_ENDPOINT / TOM_OTLP_TEST_TRACES_OUTPUT are not set'
        : null,
  );
}

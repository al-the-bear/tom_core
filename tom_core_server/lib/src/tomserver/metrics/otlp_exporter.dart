/// OTLP export over HTTP: the transport, and the metrics exporter built on it.
///
/// OTLP is the OpenTelemetry protocol a collector — the OpenTelemetry
/// Collector, Grafana Alloy, a vendor's agent — receives. The transport speaks
/// OTLP/HTTP with JSON bodies, which every receiver accepts, and knows nothing
/// about signals: it posts a body to `<endpoint>/v1/<signal>`. The metrics
/// exporter posts to `v1/metrics`. Spans go to the same endpoint's
/// `v1/traces` ([TomOtlpHttpTransport.urlOf]) with the same headers, sent by the OpenTelemetry
/// SDK's protobuf exporter the tracing module configures, so a deployment
/// configures one endpoint and one set of headers for all its telemetry.
///
/// Metrics are exported **cumulatively**: every export carries each series'
/// total since the registry's start time, the temporality Prometheus also
/// uses. A lost export loses nothing — the next one carries the same totals,
/// grown.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';

/// An OTLP export that did not reach the receiver, or was refused by it.
class TomOtlpExportException extends TomServerException {
  /// Creates the exception; see [TomServerException] for the fields.
  TomOtlpExportException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
  }) : super(clientThrow: false);
}

/// Posts OTLP/HTTP JSON bodies to a receiver.
class TomOtlpHttpTransport {
  /// A transport to the receiver at [endpoint] — its base URL, such as
  /// `http://collector:4318`, to which `/v1/<signal>` is appended — sending
  /// [headers] with every export.
  TomOtlpHttpTransport({
    required this.endpoint,
    this.headers = const {},
    this.timeout = const Duration(seconds: 10),
    http.Client? client,
  }) : _client = client ?? TomResilientClient(http.Client());

  /// The receiver's base URL.
  final Uri endpoint;

  /// Sent with every export — typically an `authorization` or a vendor key.
  final Map<String, String> headers;

  /// How long an export may take before it is abandoned.
  final Duration timeout;

  final http.Client _client;

  /// The headers [text] names, in the `key=value,key=value` form the
  /// `OTEL_EXPORTER_OTLP_HEADERS` variable uses; values are percent-decoded.
  ///
  /// Throws `otlp.config.invalid_headers` for an entry with no `=`.
  static Map<String, String> parseHeaders(String text) {
    final headers = <String, String>{};
    for (final entry in text.split(',')) {
      if (entry.trim().isEmpty) continue;
      final split = entry.indexOf('=');
      if (split <= 0) {
        throw TomOtlpExportException(
          'otlp.config.invalid_headers',
          "The OTLP header entry '${entry.trim()}' is not of the form "
              'key=value.',
        );
      }
      headers[entry.substring(0, split).trim().toLowerCase()] =
          Uri.decodeComponent(entry.substring(split + 1).trim());
    }
    return headers;
  }

  /// The URL a [signal] (`metrics`, `traces`, `logs`) is posted to.
  Uri urlOf(String signal) {
    final base = endpoint.path.endsWith('/')
        ? endpoint.path
        : '${endpoint.path}/';
    return endpoint.replace(path: '${base}v1/$signal');
  }

  /// Posts [body] for [signal].
  ///
  /// Throws `otlp.export.failed` when the receiver cannot be reached, does not
  /// answer within [timeout], or answers anything but a `2xx`.
  Future<void> export(String signal, Map<String, Object?> body) async {
    final url = urlOf(signal);
    final http.Response response;
    try {
      // Untraced: with tracing on, the push would otherwise be a client span
      // of its own, exported in turn.
      response = await TomTracing.untraced(
        () => _client.post(
          url,
          headers: {...headers, 'content-type': 'application/json'},
          body: jsonEncode(body),
        ),
      ).timeout(timeout);
    } catch (error, stack) {
      throw TomOtlpExportException(
        'otlp.export.failed',
        'The OTLP receiver at $url could not be reached: $error',
        parameters: {'signal': signal, 'url': '$url'},
        rootException: error,
        stack: stack,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TomOtlpExportException(
        'otlp.export.failed',
        'The OTLP receiver at $url answered ${response.statusCode}.',
        parameters: {
          'signal': signal,
          'url': '$url',
          'status': response.statusCode,
        },
      );
    }
  }

  /// Closes the HTTP client.
  void close() => _client.close();
}

/// Pushes a [TomMetricRegistry]'s snapshot to an OTLP receiver every
/// [interval].
///
/// [start] begins the pushes; a push that fails is logged and the next one
/// carries the same totals. [close] stops them after one final push, so a
/// server shutting down does not lose what it counted since the last one.
class TomOtlpMetricsExporter implements TomClosable {
  /// An exporter pushing [registry] (the process registry unless given)
  /// through [transport], describing the process with [resource] attributes —
  /// `service.name` at least.
  TomOtlpMetricsExporter({
    required this.transport,
    TomMetricRegistry? registry,
    this.resource = const {},
    this.interval = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : registry = registry ?? TomMetrics.registry,
       _clock = clock ?? DateTime.now;

  /// Where the snapshots go.
  final TomOtlpHttpTransport transport;

  /// What is exported.
  final TomMetricRegistry registry;

  /// The resource attributes describing this process.
  final Map<String, String> resource;

  /// How often [start] pushes.
  final Duration interval;

  final DateTime Function() _clock;
  Timer? _timer;
  bool _closed = false;

  /// Takes a snapshot and pushes it once; throws as [TomOtlpHttpTransport.export]
  /// does.
  Future<void> export() async {
    final body = tomOtlpMetricsJson(
      await registry.collect(),
      resource: resource,
      startTime: registry.startTime,
      time: _clock(),
    );
    await transport.export('metrics', body);
  }

  /// Pushes every [interval] until [close].
  void start() {
    if (_closed || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => unawaited(_exportLogged()));
  }

  Future<void> _exportLogged() async {
    try {
      await export();
    } on TomOtlpExportException catch (error) {
      tomLog.warn(
        'Exporting metrics over OTLP failed: ${error.defaultUserMessage}',
      );
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _timer = null;
    await _exportLogged();
    transport.close();
  }
}

/// [families] as an OTLP `ExportMetricsServiceRequest` in the JSON encoding.
///
/// Counters are cumulative monotonic sums, gauges gauges, histograms
/// cumulative explicit-bucket histograms; every point carries [startTime] and
/// [time]. 64-bit integers are strings, as the protobuf JSON mapping writes
/// them.
Map<String, Object?> tomOtlpMetricsJson(
  List<TomMetricFamily> families, {
  required Map<String, String> resource,
  required DateTime startTime,
  required DateTime time,
}) {
  const cumulative = 2;
  final start = _nanos(startTime);
  final now = _nanos(time);
  Map<String, Object?> point(TomMetricPoint p, {bool withStart = true}) => {
    'attributes': _attributes(p.labels),
    if (withStart) 'startTimeUnixNano': start,
    'timeUnixNano': now,
  };
  return {
    'resourceMetrics': [
      {
        'resource': {'attributes': _attributes(resource)},
        'scopeMetrics': [
          {
            'scope': {'name': 'tom_core'},
            'metrics': [
              for (final f in families)
                {
                  'name': f.name,
                  'description': f.help,
                  'unit': f.unit,
                  ...switch (f.kind) {
                    TomMetricKind.counter => {
                      'sum': {
                        'aggregationTemporality': cumulative,
                        'isMonotonic': true,
                        'dataPoints': [
                          for (final p in f.points)
                            {...point(p), 'asDouble': p.value},
                        ],
                      },
                    },
                    TomMetricKind.gauge => {
                      'gauge': {
                        'dataPoints': [
                          for (final p in f.points)
                            {
                              ...point(p, withStart: false),
                              'asDouble': p.value,
                            },
                        ],
                      },
                    },
                    TomMetricKind.histogram => {
                      'histogram': {
                        'aggregationTemporality': cumulative,
                        'dataPoints': [
                          for (final p in f.points)
                            {
                              ...point(p),
                              'count': '${p.histogram!.count}',
                              'sum': p.histogram!.sum,
                              'bucketCounts': [
                                for (final c in p.histogram!.counts) '$c',
                              ],
                              'explicitBounds': p.histogram!.bounds,
                            },
                        ],
                      },
                    },
                  },
                },
            ],
          },
        ],
      },
    ],
  };
}

String _nanos(DateTime t) => '${t.microsecondsSinceEpoch * 1000}';

List<Map<String, Object?>> _attributes(Map<String, String> values) => [
  for (final e in values.entries)
    {
      'key': e.key,
      'value': {'stringValue': e.value},
    },
];

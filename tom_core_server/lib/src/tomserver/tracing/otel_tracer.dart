/// The OpenTelemetry tracer: the kernel's [TomTracer] over the OpenTelemetry
/// SDK, exporting spans over OTLP/HTTP.
///
/// The framework opens its spans through the kernel's [TomTracing] seam; this
/// library is the one place that knows the SDK (`package:opentelemetry`). It
/// turns each span the framework starts into an SDK span, carries the
/// framework's [TomTraceContext] in and out — so the ids in log lines and in
/// `traceparent` headers are the exported ones — and hands ended spans to the
/// SDK's processors.
///
/// [TomServer.start] installs one when the configuration's `tracing` is on;
/// see [TomOtelTracer.fromConfiguration].
library;

import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:opentelemetry/api.dart' as otel;
import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../configuration/base_server_configuration.dart';
import '../little_things/server_exception.dart';
import '../metrics/otlp_exporter.dart';

/// Tracing cannot be set up as configured.
class TomTracingException extends TomServerException {
  /// Creates the exception; see [TomServerException] for the fields.
  TomTracingException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
  }) : super(clientThrow: false);
}

/// A [TomTracer] recording spans with the OpenTelemetry SDK.
///
/// Spans go to [processors]: a batch processor over an OTLP exporter in a
/// deployment ([TomOtelTracer.otlp]), a simple processor over a
/// [TomInMemorySpanExporter] in a test.
///
/// **Sampling.** A span continuing a parent is sampled as its parent is — the
/// caller's `traceparent` decides for a request from a traced caller. A new
/// trace is sampled with the probability [samplePercent], decided from its
/// trace id, so every process taking the same decision for a trace agrees. An
/// unsampled span is still made — its context is propagated, flagged
/// unsampled — but not exported.
class TomOtelTracer implements TomTracer, TomClosable {
  /// A tracer handing spans to [processors], describing this process with
  /// [resource] attributes (`service.name` at least) and sampling new traces
  /// at [samplePercent] (0 to 100).
  TomOtelTracer({
    required List<otel_sdk.SpanProcessor> processors,
    Map<String, Object> resource = const {'service.name': 'tom_server'},
    this.samplePercent = 100,
    TomUntracedClient? exportClient,
  }) : _exportClient = exportClient,
       _provider = otel_sdk.TracerProviderBase(
         processors: processors,
         resource: otel_sdk.Resource(_attributes(resource)),
         sampler: otel_sdk.ParentBasedSampler(_TomRatioSampler(samplePercent)),
       ) {
    if (samplePercent < 0 || samplePercent > 100) {
      throw TomTracingException(
        'tracing.config.invalid_sample_percent',
        'The tracing sample percentage must be between 0 and 100, not '
            '$samplePercent.',
        parameters: {'samplePercent': samplePercent},
      );
    }
    _tracer = _provider.getTracer('tom_core_server');
  }

  /// A tracer exporting to the OTLP/HTTP receiver at [endpoint] — its base
  /// URL, to which `/v1/traces` is appended — in protobuf, sending [headers]
  /// with every export. Spans are batched and sent every [exportInterval], or
  /// when a batch is full.
  ///
  /// The exporter's own calls are made [TomTracing.untraced], so exporting a
  /// batch does not produce spans of its own.
  factory TomOtelTracer.otlp({
    required Uri endpoint,
    Map<String, String> headers = const {},
    Map<String, Object> resource = const {'service.name': 'tom_server'},
    int samplePercent = 100,
    Duration exportInterval = const Duration(seconds: 5),
    http.Client? client,
  }) {
    final untraced = TomUntracedClient(client ?? TomResilientClient());
    final exporter = otel_sdk.CollectorExporter(
      TomOtlpHttpTransport(endpoint: endpoint).urlOf('traces'),
      httpClient: untraced,
      headers: headers,
    );
    return TomOtelTracer(
      exportClient: untraced,
      processors: [
        otel_sdk.BatchSpanProcessor(
          exporter,
          scheduledDelayMillis: exportInterval.inMilliseconds,
        ),
      ],
      resource: resource,
      samplePercent: samplePercent,
    );
  }

  /// The tracer [configuration] asks for, or `null` when its
  /// [TomBaseServerConfiguration.tracing] is off.
  ///
  /// Spans go to [TomBaseServerConfiguration.otlpEndpoint] with
  /// [TomBaseServerConfiguration.otlpHeaders] — the receiver metrics are
  /// pushed to — sampled at [TomBaseServerConfiguration.tracingSamplePercent].
  /// [serviceName] becomes the `service.name` resource attribute.
  ///
  /// Throws `tracing.config.no_endpoint` when tracing is on and no endpoint is
  /// configured, and `tracing.config.invalid_sample_percent` for a percentage
  /// outside 0 to 100.
  static TomOtelTracer? fromConfiguration(
    TomBaseServerConfiguration configuration, {
    required String serviceName,
  }) {
    if (!configuration.tracing) return null;
    if (configuration.otlpEndpoint.isEmpty) {
      throw TomTracingException(
        'tracing.config.no_endpoint',
        'Tracing is on, but no OTLP endpoint is configured to export the '
            'spans to; set otlpEndpoint (OTLP_ENDPOINT).',
      );
    }
    return TomOtelTracer.otlp(
      endpoint: Uri.parse(configuration.otlpEndpoint),
      headers: TomOtlpHttpTransport.parseHeaders(configuration.otlpHeaders),
      resource: {'service.name': serviceName},
      samplePercent: configuration.tracingSamplePercent,
    );
  }

  final otel_sdk.TracerProviderBase _provider;

  /// The client the exporter sends through, when [TomOtelTracer.otlp] built
  /// it: [flush] and [shutdown] wait for its exports to finish.
  final TomUntracedClient? _exportClient;
  late final otel.Tracer _tracer;

  /// The probability, in percent, that a new trace is sampled.
  final int samplePercent;

  @override
  TomSpan startSpan(
    String name, {
    TomSpanKind kind = TomSpanKind.internal,
    TomTraceContext? parent,
    Map<String, Object> attributes = const {},
  }) {
    final context = parent == null
        ? otel.Context.root
        : otel.contextWithSpanContext(
            otel.Context.root,
            otel.SpanContext.remote(
              otel.TraceId.fromString(parent.traceId),
              otel.SpanId.fromString(parent.spanId),
              parent.sampled ? otel.TraceFlags.sampled : otel.TraceFlags.none,
              _traceState(parent.traceState),
            ),
          );
    final span = _tracer.startSpan(
      name,
      context: context,
      kind: _kinds[kind]!,
      attributes: _attributes(attributes),
    );
    final ids = span.spanContext;
    return _TomOtelSpan(
      span,
      name,
      TomTraceContext(
        traceId: ids.traceId.toString(),
        spanId: ids.spanId.toString(),
        parentSpanId: parent?.spanId,
        sampled:
            ids.traceFlags & otel.TraceFlags.sampled == otel.TraceFlags.sampled,
        traceState: parent?.traceState,
      ),
    );
  }

  static otel.TraceState _traceState(String? value) {
    if (value == null) return otel.TraceState.empty();
    try {
      return otel.TraceState.fromString(value);
    } on Object {
      // The state is the vendors'; one the SDK cannot read is still carried
      // on in the framework's own context, just not inside the SDK's.
      return otel.TraceState.empty();
    }
  }

  static const Map<TomSpanKind, otel.SpanKind> _kinds = {
    TomSpanKind.internal: otel.SpanKind.internal,
    TomSpanKind.server: otel.SpanKind.server,
    TomSpanKind.client: otel.SpanKind.client,
    TomSpanKind.producer: otel.SpanKind.producer,
    TomSpanKind.consumer: otel.SpanKind.consumer,
  };

  static List<otel.Attribute> _attributes(Map<String, Object> values) => [
    for (final entry in values.entries) _attribute(entry.key, entry.value),
  ];

  static otel.Attribute _attribute(String key, Object value) => switch (value) {
    String() => otel.Attribute.fromString(key, value),
    bool() => otel.Attribute.fromBoolean(key, value),
    int() => otel.Attribute.fromInt(key, value),
    double() => otel.Attribute.fromDouble(key, value),
    List<String>() => otel.Attribute.fromStringList(key, value),
    List<bool>() => otel.Attribute.fromBooleanList(key, value),
    List<int>() => otel.Attribute.fromIntList(key, value),
    List<double>() => otel.Attribute.fromDoubleList(key, value),
    _ => otel.Attribute.fromString(key, '$value'),
  };

  /// Exports what the processors hold, and completes when the export has
  /// been answered.
  @override
  Future<void> flush() async {
    _provider.forceFlush();
    await _exportClient?.idle;
  }

  /// Exports what the processors hold and stops them, completing when the
  /// last export has been answered.
  @override
  Future<void> shutdown() async {
    _provider.shutdown();
    await _exportClient?.idle;
  }

  /// Shuts the tracer down — at process shutdown, after a final export.
  @override
  Future<void> close() => shutdown();
}

class _TomOtelSpan implements TomSpan {
  _TomOtelSpan(this._span, this._name, this.context);

  final otel.Span _span;
  String _name;
  bool _ended = false;

  @override
  final TomTraceContext context;

  @override
  String get name => _name;

  @override
  void setName(String name) {
    _name = name;
    _span.setName(name);
  }

  @override
  void setAttribute(String key, Object value) =>
      _span.setAttribute(TomOtelTracer._attribute(key, value));

  @override
  void recordError(Object error, [StackTrace? stack]) {
    _span
      ..recordException(error, stackTrace: stack ?? StackTrace.empty)
      ..setStatus(otel.StatusCode.error, '$error');
  }

  @override
  void setError(String description) =>
      _span.setStatus(otel.StatusCode.error, description);

  @override
  void end() {
    if (_ended) return;
    _ended = true;
    _span.end();
  }
}

/// Samples [percent] of new traces, decided from the trace id's random low
/// bytes, so every process deciding for one trace decides alike.
class _TomRatioSampler implements otel_sdk.Sampler {
  const _TomRatioSampler(this.percent);

  final int percent;

  @override
  String get description => 'TomRatioSampler{$percent%}';

  @override
  otel_sdk.SamplingResult shouldSample(
    otel.Context context,
    otel.TraceId traceId,
    String spanName,
    otel.SpanKind spanKind,
    List<otel.Attribute> spanAttributes,
    List<otel.SpanLink> spanLinks,
  ) {
    final bytes = traceId.get();
    // The last seven bytes: random in every W3C trace id, and small enough
    // to be a non-negative integer on every platform.
    var value = 0;
    for (var i = bytes.length - 7; i < bytes.length; i++) {
      value = value * 256 + bytes[i];
    }
    final sampled = value < percent * (pow(2, 56) as int) ~/ 100;
    return otel_sdk.SamplingResult(
      sampled ? otel_sdk.Decision.recordAndSample : otel_sdk.Decision.drop,
      spanAttributes,
      otel.spanContextFromContext(context).traceState,
    );
  }
}

/// A `package:http` client whose calls are never traced — what a telemetry
/// exporter sends through, so an export does not produce spans to export.
///
/// [close] lets the calls in flight finish first: the SDK's exporter starts
/// its last export and closes its client in the same breath, and a client
/// closed at once would drop that export — the spans of a server's last
/// seconds. [idle] completes when no call is in flight.
class TomUntracedClient extends http.BaseClient {
  /// Sends through [inner].
  TomUntracedClient(this._inner);

  final http.Client _inner;
  int _inFlight = 0;
  bool _closing = false;
  Completer<void>? _idle;

  /// Completes when no call is in flight — at once when none is.
  Future<void> get idle =>
      _inFlight == 0 ? Future.value() : (_idle ??= Completer()).future;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _inFlight++;
    final http.StreamedResponse response;
    try {
      response = await TomTracing.untraced(() => _inner.send(request));
    } catch (_) {
      _settled();
      rethrow;
    }
    // In flight until the body has been read: closing the inner client under
    // a body still arriving would cut it off.
    var settled = false;
    void settle() {
      if (settled) return;
      settled = true;
      _settled();
    }

    return http.StreamedResponse(
      response.stream.transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stack, sink) {
            settle();
            sink.addError(error, stack);
          },
          handleDone: (sink) {
            settle();
            sink.close();
          },
        ),
      ),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  void _settled() {
    _inFlight--;
    if (_inFlight > 0) return;
    final idle = _idle;
    _idle = null;
    idle?.complete();
    if (_closing) _inner.close();
  }

  /// Closes the inner client once the calls in flight have finished.
  @override
  void close() {
    _closing = true;
    if (_inFlight == 0) _inner.close();
  }
}

/// A span exporter keeping every exported span in memory — for tests, with
/// a `SimpleSpanProcessor`.
class TomInMemorySpanExporter implements otel_sdk.SpanExporter {
  /// The exported spans, in the order they ended.
  final List<otel_sdk.ReadOnlySpan> spans = [];

  @override
  void export(List<otel_sdk.ReadOnlySpan> spans) => this.spans.addAll(spans);

  /// The exported spans named [name].
  List<otel_sdk.ReadOnlySpan> named(String name) => [
    for (final span in spans)
      if (span.name == name) span,
  ];

  /// The exported spans whose parent is [span].
  List<otel_sdk.ReadOnlySpan> childrenOf(otel_sdk.ReadOnlySpan span) => [
    for (final s in spans)
      if (s.spanContext.traceId.toString() ==
              span.spanContext.traceId.toString() &&
          s.parentSpanId.toString() == span.spanContext.spanId.toString())
        s,
  ];

  /// The value of attribute [key] of [span], or `null`.
  static Object? attributeOf(otel_sdk.ReadOnlySpan span, String key) =>
      span.attributes.get(key);

  @override
  @Deprecated('Part of the SDK interface; flushing is the processor\'s.')
  void forceFlush() {}

  @override
  void shutdown() {}
}

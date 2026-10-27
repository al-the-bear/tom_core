/// Spans: the timed, named steps of a trace, recorded by a tracer an
/// application installs — and nothing at all when it installs none.
///
/// [TomTraceContext] is the *position* in a trace that every piece of work
/// carries; this library adds the *record* of each step. The framework opens a
/// span around the work worth seeing in a trace — a request, an SQL statement,
/// a transaction, an outgoing HTTP call, a job run, an outbox delivery — and a
/// [TomTracer] decides what becomes of it. `tom_core_server` provides the
/// OpenTelemetry tracer that exports spans over OTLP; [TomRecordingTracer]
/// keeps them in memory for tests.
///
/// ## Off costs nothing
///
/// No tracer is installed by default. Every instrumented call then asks one
/// question — is a tracer installed? — and runs its work exactly as it would
/// without tracing: no span object, no zone, no attribute map. The trace
/// context and the request id are carried all the same, since they do not
/// depend on a tracer.
///
/// ## The span is the trace context
///
/// A span's [TomSpan.context] is the [TomTraceContext] its work runs in, so
/// the `trace_id` and `span_id` a log line carries are those of the span the
/// line was written in, and an outgoing call propagates the span that made
/// it. With a tracer installed its ids are the tracer's; without one the
/// framework mints them as it always has.
library;

import 'dart:async';

import 'trace_context.dart';

/// What a span's work is to the trace — the OpenTelemetry span kinds.
enum TomSpanKind {
  /// Work inside one process.
  internal,

  /// The handling of a request that arrived from a caller.
  server,

  /// A call to another service — an outgoing HTTP call, an SQL statement.
  client,

  /// Handing a message to a queue, for a consumer to process later.
  producer,

  /// The processing of a message taken from a queue.
  consumer,
}

/// One span being recorded.
///
/// Attribute values are strings, booleans, integers, doubles, or lists of one
/// of those; anything else is recorded as its `toString()`.
abstract class TomSpan {
  /// The position this span's work runs at: its trace, its own id, its parent.
  TomTraceContext get context;

  /// The span's name.
  String get name;

  /// Renames the span — for a name that is known only once the work has
  /// started, such as the route an HTTP request matched.
  void setName(String name);

  /// Sets attribute [key] to [value].
  void setAttribute(String key, Object value);

  /// Records [error] as an exception of this span and marks the span failed.
  void recordError(Object error, [StackTrace? stack]);

  /// Marks the span failed with [description], without an exception — an
  /// HTTP request answered with a server error, say.
  void setError(String description);

  /// Ends the span; a second call does nothing.
  void end();
}

/// Makes spans. Installed with [TomTracing.install].
abstract class TomTracer {
  /// Starts a span named [name] continuing [parent], or a new trace when
  /// [parent] is `null`.
  ///
  /// [parent] may be a span of this process or the remote position a caller
  /// sent in its `traceparent`; the tracer decides whether the new span is
  /// sampled — normally as its parent is, and for a new trace by its own rule.
  TomSpan startSpan(
    String name, {
    TomSpanKind kind = TomSpanKind.internal,
    TomTraceContext? parent,
    Map<String, Object> attributes = const {},
  });

  /// Sends what has been recorded so far.
  Future<void> flush();

  /// Flushes and stops; spans started afterwards are not exported.
  Future<void> shutdown();
}

/// The installed tracer, and the ways the framework opens spans with it.
abstract final class TomTracing {
  static TomTracer? _tracer;

  static final Object _spanKey = Object();
  static final Object _suppressedKey = Object();

  /// The installed tracer, or `null` — tracing is off.
  static TomTracer? get tracer => _tracer;

  /// Installs [tracer], or switches tracing off with `null`. The tracer a
  /// previous call installed is not shut down; its owner does that.
  static void install(TomTracer? tracer) => _tracer = tracer;

  /// Whether a span started here would be recorded: a tracer is installed and
  /// the zone is not [untraced].
  static bool get isRecording =>
      _tracer != null && Zone.current[_suppressedKey] != true;

  /// The span whose work the current zone runs, or `null`.
  static TomSpan? get currentSpan => Zone.current[_spanKey] as TomSpan?;

  /// Starts a span, or answers `null` when nothing would record it.
  ///
  /// The span continues [parent], by default the current trace context; with
  /// [root] it starts a new trace whatever the zone carries. With [childOnly]
  /// nothing is started outside a trace: a step that is only worth seeing as
  /// part of a larger piece of work — an SQL statement, a transaction — then
  /// records nothing when it runs on its own, as a scheduler's poll does.
  /// Starting a span does not make it current — run its work with [within].
  static TomSpan? start(
    String name, {
    TomSpanKind kind = TomSpanKind.internal,
    Map<String, Object> attributes = const {},
    TomTraceContext? parent,
    bool root = false,
    bool childOnly = false,
  }) {
    final tracer = _tracer;
    if (tracer == null || Zone.current[_suppressedKey] == true) return null;
    final continued = root ? null : (parent ?? TomTraceContext.current);
    if (childOnly && continued == null) return null;
    return tracer.startSpan(
      name,
      kind: kind,
      parent: continued,
      attributes: attributes,
    );
  }

  /// Runs [body] as [span]'s work: [span] is the [currentSpan], and its
  /// context the current [TomTraceContext]. The span is not ended.
  static R within<R>(TomSpan span, R Function() body) => runZoned(
    () => TomTraceContext.run(span.context, body),
    zoneValues: {_spanKey: span},
  );

  /// Runs [body] and ends [span] when it is done: when it returns, or, for a
  /// future, when that completes. An error is recorded on the span and passed
  /// on. [body] runs in the zone it is called from; see [within].
  static R ending<R>(TomSpan span, R Function() body) {
    final R result;
    try {
      result = body();
    } catch (error, stack) {
      span
        ..recordError(error, stack)
        ..end();
      rethrow;
    }
    if (result is Future) {
      final future = result as Future<Object?>;
      // A listener of its own, so the error is recorded before the span ends
      // and still reaches whoever awaits the result.
      unawaited(
        future.then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) =>
              span.recordError(error, stack),
        ),
      );
      return future.whenComplete(span.end) as R;
    }
    span.end();
    return result;
  }

  /// Runs [body] in a span named [name], continuing the current trace, and
  /// ends it when [body] completes; an error is recorded on the span and
  /// rethrown. [body] receives the span to add attributes to — or `null`
  /// when tracing is off, in which case it simply runs.
  static Future<R> trace<R>(
    String name,
    Future<R> Function(TomSpan? span) body, {
    TomSpanKind kind = TomSpanKind.internal,
    Map<String, Object> attributes = const {},
  }) {
    final span = start(name, kind: kind, attributes: attributes);
    if (span == null) return body(null);
    return within(span, () => ending(span, () => body(span)));
  }

  /// Runs [body] with nothing traced inside it — the tracer's own export
  /// calls, which would otherwise be traced and exported in turn.
  static R untraced<R>(R Function() body) =>
      runZoned(body, zoneValues: {_suppressedKey: true});
}

/// A [TomTracer] keeping every ended span in memory — for tests, and for
/// looking at what the framework traces without a collector.
///
/// Ids are minted as [TomTraceContext] mints them; every span is recorded,
/// sampled or not.
class TomRecordingTracer implements TomTracer {
  /// The ended spans, in the order they ended.
  final List<TomRecordedSpan> spans = [];

  /// The spans started and not ended yet.
  final List<TomRecordedSpan> open = [];

  @override
  TomSpan startSpan(
    String name, {
    TomSpanKind kind = TomSpanKind.internal,
    TomTraceContext? parent,
    Map<String, Object> attributes = const {},
  }) {
    final span = TomRecordedSpan._(
      this,
      name,
      kind,
      parent?.child() ?? TomTraceContext.newRoot(),
      attributes,
    );
    open.add(span);
    return span;
  }

  void _ended(TomRecordedSpan span) {
    open.remove(span);
    spans.add(span);
  }

  /// The ended spans named [name].
  List<TomRecordedSpan> named(String name) => [
    for (final span in spans)
      if (span.name == name) span,
  ];

  /// The ended spans whose parent is [span].
  List<TomRecordedSpan> childrenOf(TomRecordedSpan span) => [
    for (final s in spans)
      if (s.context.traceId == span.context.traceId &&
          s.context.parentSpanId == span.context.spanId)
        s,
  ];

  /// Forgets every recorded span.
  void clear() {
    spans.clear();
    open.clear();
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> shutdown() async {}
}

/// A span [TomRecordingTracer] recorded.
class TomRecordedSpan implements TomSpan {
  TomRecordedSpan._(
    this._tracer,
    this._name,
    this.kind,
    this.context,
    Map<String, Object> attributes,
  ) : attributes = {...attributes};

  final TomRecordingTracer _tracer;
  String _name;

  /// The span's kind.
  final TomSpanKind kind;

  @override
  final TomTraceContext context;

  /// The attributes set on it.
  final Map<String, Object> attributes;

  /// The errors recorded on it.
  final List<Object> errors = [];

  /// Why it failed, or `null` for a span that did not.
  String? errorDescription;

  /// When it started.
  final DateTime started = DateTime.now();

  /// When it ended, or `null` while it runs.
  DateTime? ended;

  @override
  String get name => _name;

  @override
  void setName(String name) => _name = name;

  @override
  void setAttribute(String key, Object value) => attributes[key] = value;

  @override
  void recordError(Object error, [StackTrace? stack]) {
    errors.add(error);
    errorDescription ??= '$error';
  }

  @override
  void setError(String description) => errorDescription = description;

  @override
  void end() {
    if (ended != null) return;
    ended = DateTime.now();
    _tracer._ended(this);
  }

  @override
  String toString() => 'TomRecordedSpan($name, ${context.traceparent})';
}

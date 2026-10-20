/// The trace a piece of work belongs to, carried in the zone, in the W3C
/// Trace Context form.
///
/// A trace is the whole of one operation across every process it touches; a
/// span is one process's part of it. The ids are those of the W3C
/// `traceparent` header — a 16-byte trace id and an 8-byte span id, both lower-case
/// hex — so a request arriving from a traced client, a gateway or a service
/// mesh keeps the caller's trace, and every log line written while serving it
/// names that trace.
///
/// ## Where the context comes from
///
/// `tom_core_server`'s request pipeline reads an incoming `traceparent`,
/// continues its trace with a span of its own ([TomTraceContext.child]), or
/// starts a new trace ([TomTraceContext.newRoot]) when the request carries
/// none, and serves the request inside [TomTraceContext.run]. The structured
/// log output reads [TomTraceContext.current] for its `trace_id` and `span_id`
/// fields.
library;

import 'dart:async';
import 'dart:math';

/// One position in a trace: the trace, this span, the span it continues, and
/// whether the trace is sampled.
class TomTraceContext {
  /// A context for the given ids; see [parse], [newRoot] and [child] for the
  /// ways one is normally made.
  ///
  /// Throws [FormatException] for an id that is not lower-case hex of the
  /// right length, or that is all zeros — the W3C rule for an invalid id.
  TomTraceContext({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    this.sampled = true,
  }) {
    _requireId(traceId, 32, 'trace id');
    _requireId(spanId, 16, 'span id');
    if (parentSpanId != null) _requireId(parentSpanId!, 16, 'parent span id');
  }

  /// A new trace with a new span — for work no caller is tracing.
  factory TomTraceContext.newRoot({bool sampled = true}) => TomTraceContext(
    traceId: _randomHex(16),
    spanId: _randomHex(8),
    sampled: sampled,
  );

  /// The context a `traceparent` header value names, or `null` when [header]
  /// is absent or not a valid version-00 value.
  ///
  /// An invalid header is ignored rather than refused, as the W3C
  /// specification requires: a malformed header from an upstream proxy must
  /// not fail the request, it only fails to continue the trace.
  static TomTraceContext? parse(String? header) {
    if (header == null) return null;
    final match = _traceparent.firstMatch(header.trim());
    if (match == null) return null;
    try {
      return TomTraceContext(
        traceId: match.group(1)!,
        spanId: match.group(2)!,
        sampled: int.parse(match.group(3)!, radix: 16) & 1 == 1,
      );
    } on FormatException {
      return null;
    }
  }

  static final RegExp _traceparent = RegExp(
    r'^00-([0-9a-f]{32})-([0-9a-f]{16})-([0-9a-f]{2})$',
  );

  /// The trace, 32 lower-case hex digits.
  final String traceId;

  /// This span, 16 lower-case hex digits.
  final String spanId;

  /// The span this one continues, or `null` for the first span of a trace.
  final String? parentSpanId;

  /// Whether the trace is recorded — the `sampled` flag of `traceparent`.
  final bool sampled;

  /// A new span in the same trace, continuing this one.
  TomTraceContext child() => TomTraceContext(
    traceId: traceId,
    spanId: _randomHex(8),
    parentSpanId: spanId,
    sampled: sampled,
  );

  /// This context as a `traceparent` header value — the value to send on an
  /// outgoing call so the callee continues this span.
  String get traceparent => '00-$traceId-$spanId-${sampled ? '01' : '00'}';

  /// The context of the current zone, or `null` outside any trace.
  static TomTraceContext? get current =>
      Zone.current[_zoneKey] as TomTraceContext?;

  /// Runs [body] with [context] as the current trace context.
  static R run<R>(TomTraceContext context, R Function() body) =>
      runZoned(body, zoneValues: {_zoneKey: context});

  static final Object _zoneKey = Object();

  static final Random _random = Random.secure();

  static String _randomHex(int bytes) {
    while (true) {
      final buffer = StringBuffer();
      var allZero = true;
      for (var i = 0; i < bytes; i++) {
        final b = _random.nextInt(256);
        if (b != 0) allZero = false;
        buffer.write(b.toRadixString(16).padLeft(2, '0'));
      }
      if (!allZero) return buffer.toString();
    }
  }

  static void _requireId(String id, int length, String what) {
    if (id.length != length ||
        !RegExp(r'^[0-9a-f]+$').hasMatch(id) ||
        RegExp(r'^0+$').hasMatch(id)) {
      throw FormatException(
        'A $what is $length lower-case hex digits, not all zero.',
        id,
      );
    }
  }

  @override
  String toString() => 'TomTraceContext($traceparent)';
}

/// The trace context across the bus: the headers a publish adds, and the
/// trace a delivery runs in. Every bus — the in-memory one and every adapter —
/// goes through these two, so a trace crosses any broker the same way.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'bus.dart';
import 'message.dart';

/// The trace handling of the bus.
abstract final class TomBusTrace {
  /// Runs [publish] with the headers to send: [headers] and, when the current
  /// zone is in a trace, its position. With a tracer installed the publish is
  /// a producer span, `<topic> publish`, and the position sent is the span's.
  static Future<R> publishing<R>(
    String topic,
    Map<String, String> headers,
    Future<R> Function(Map<String, String> headers) publish,
  ) {
    final span = TomTracing.start(
      '$topic publish',
      kind: TomSpanKind.producer,
      attributes: {
        'messaging.operation.type': 'send',
        'messaging.destination.name': topic,
      },
    );
    if (span == null) {
      final trace = TomTraceContext.current?.child();
      return publish({...headers, ...?trace?.headers});
    }
    return TomTracing.within(
      span,
      () => TomTracing.ending(
        span,
        () => publish({...headers, ...span.context.headers}),
      ),
    );
  }

  /// Runs [handle] — the handling of [message] by [group] — in the trace the
  /// message was published in: a new span of it, whose trace id is the
  /// request id, or a trace of its own for a message published in none. With
  /// a tracer installed the handling is a consumer span, `<topic> process`.
  static Future<R> delivering<R>(
    TomBusMessage message,
    String group,
    Future<R> Function() handle,
  ) {
    final published = TomTraceContext.parse(
      message.headers[TomBusHeaders.traceparent],
      traceState: message.headers[TomBusHeaders.tracestate],
    );
    final span = TomTracing.start(
      '${message.topic} process',
      kind: TomSpanKind.consumer,
      parent: published,
      root: published == null,
      attributes: {
        'messaging.operation.type': 'process',
        'messaging.destination.name': message.topic,
        'messaging.consumer.group.name': group,
        'messaging.message.id': message.id,
      },
    );
    final trace =
        span?.context ?? published?.child() ?? TomTraceContext.newRoot();
    Future<R> run() => TomRequestId.run(TomRequestId.of(trace.traceId), handle);
    if (span == null) return TomTraceContext.run(trace, run);
    return TomTracing.within(span, () => TomTracing.ending(span, run));
  }
}

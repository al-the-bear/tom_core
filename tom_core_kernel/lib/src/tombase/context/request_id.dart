/// The id of one unit of work — a request, a job run, a socket message —
/// carried in the zone beside its [TomTraceContext].
///
/// Every log line written while the work runs carries it as `request_id`
/// ([TomLogContext]), every server exception raised during it names it, and
/// an audit entry records it, so one id finds everything one piece of work did.
///
/// ## Where the id comes from
///
/// | Work | Request id |
/// | ---- | ---------- |
/// | An HTTP request with a valid `traceparent` | the caller's trace id — the same id on both sides of the call |
/// | An HTTP request with a request-id header from a trusted proxy | that header's value, when it matches [isValid] |
/// | Any other HTTP request | the trace id of the new trace it starts |
/// | A job run, and so an outbox delivery | the trace id of a new trace ([runRoot]) |
/// | A socket message read through `TomWebSocketConnection.serve` | the connection's trace id and the message's own span id ([runChild]) |
///
/// The HTTP rows are `tom_core_server`'s request pipeline; this type only
/// holds the value and the two ways of starting work under one.
library;

import 'dart:async';
import 'dart:math';

import 'trace_context.dart';

/// The correlation id of the work running in the current zone.
///
/// Published into the zone under its own type, so
/// `getFromCurrentZone<TomRequestId>()` and [current] answer the same.
final class TomRequestId {
  /// A new id: a random version-4 UUID.
  TomRequestId() : value = _uuidV4();

  /// The id [value]; throws [FormatException] unless it [isValid].
  TomRequestId.of(this.value) {
    if (!isValid(value)) {
      throw FormatException(
        'A request id is 8 to 128 characters of letters, digits and '
        "'._:-', starting with a letter or digit.",
        value,
      );
    }
  }

  /// The id [value] names, or `null` when [value] is absent or not [isValid].
  static TomRequestId? tryOf(String? value) =>
      value != null && isValid(value) ? TomRequestId.of(value) : null;

  /// Whether [value] may be a request id: 8 to 128 characters of ASCII
  /// letters, digits and `._:-`, the first a letter or digit.
  ///
  /// Narrow on purpose. The id is written into log lines, response headers and
  /// an audit column (191 characters wide), and a caller may supply it — so
  /// nothing that could break a line, a header or a log parser gets through.
  static bool isValid(String value) => _pattern.hasMatch(value);

  static final RegExp _pattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$');

  /// The id.
  final String value;

  /// The id of the current zone, or `null` outside any unit of work.
  static TomRequestId? get current =>
      Zone.current[TomRequestId] as TomRequestId?;

  /// Runs [body] with [id] as the current request id.
  static R run<R>(TomRequestId id, R Function() body) =>
      runZoned(body, zoneValues: {TomRequestId: id});

  /// Runs [body] as work of its own: in a new trace, whose trace id is the
  /// request id. For work no caller started — a job run, a delivery.
  static R runRoot<R>(R Function() body) {
    final trace = TomTraceContext.newRoot();
    return TomTraceContext.run(
      trace,
      () => run(TomRequestId.of(trace.traceId), body),
    );
  }

  /// Runs [body] as one step of the current work: in a new span of the current
  /// trace (a new trace when there is none), whose id is
  /// `<trace id>-<span id>`. For work that belongs to a longer conversation —
  /// one message of a socket — so each has an id of its own and still names
  /// the trace it belongs to.
  static R runChild<R>(R Function() body) {
    final parent = TomTraceContext.current;
    if (parent == null) return runRoot(body);
    final trace = parent.child();
    return TomTraceContext.run(
      trace,
      () => run(TomRequestId.of('${trace.traceId}-${trace.spanId}'), body),
    );
  }

  static final Random _random = Random.secure();

  static String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')];
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10).join()}';
  }

  @override
  bool operator ==(Object other) =>
      other is TomRequestId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'TomRequestId: $value';
}

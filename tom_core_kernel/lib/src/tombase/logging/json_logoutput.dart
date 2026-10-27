/// Structured log output: one JSON object per line, carrying the trace, span,
/// request and tenant the entry was written for.
///
/// A log collector — Loki, Elasticsearch, CloudWatch, Cloud Logging — indexes
/// a JSON line field by field, so "every line of trace 4bf9…" or "every error
/// of tenant acme" is a query rather than a regular expression over free text.
/// The fields that name the work come from the zone the entry was logged in,
/// through [TomLogContext]; nothing at the call site has to pass them.
///
/// ## The line
///
/// ```json
/// {"timestamp":"2026-10-20T08:15:02.113Z","level":"info","message":"…",
///  "logger":"TomServer.start","isolate":"main",
///  "trace_id":"4bf92f3577b34da6a3ce929d0e0e4736","span_id":"00f067aa0ba902b7",
///  "request_id":"…","tenant":"acme"}
/// ```
///
/// | Field | Present | Value |
/// | ----- | ------- | ----- |
/// | `timestamp` | always | the entry's time, UTC, ISO 8601 |
/// | `level` | always | the level name, lower-case (`info`, `warn`, `error`, …) |
/// | `message` | always | the message, rendered as [TomLogOutput.convertToString] renders it |
/// | `logger` | when the logger determined its caller | the calling `Class.method` |
/// | `isolate` | always | the isolate the entry was logged in |
/// | context fields | when the zone has a value | [TomLogContext.fields]: `trace_id`, `span_id`, `tenant`, and what an application registers |
///
/// **No personal data in a fixed field.** The fixed fields and the framework's
/// context fields are ids — a trace, a span, a request, a tenant — never a user
/// name, an address or a principal. What a message says is the message's
/// business; what every line carries is chosen so every line may be kept.
library;

import 'dart:convert';

import 'package:tom_basics/tom_basics.dart';

import '../context/request_id.dart';
import '../context/tenant_context.dart';
import '../context/trace_context.dart';

/// Computes one context field of a log entry from the current zone, or `null`
/// when the zone has no value for it.
typedef TomLogFieldProvider = String? Function();

/// The context fields every structured log line carries, read from the zone
/// the entry is logged in.
///
/// The kernel registers `trace_id` and `span_id` ([TomTraceContext.current]),
/// `request_id` ([TomRequestId.current]) and `tenant`
/// ([TomTenantContext.currentId]). An application adds its own with [register] — a field must
/// name work, not a person (see the library documentation).
abstract final class TomLogContext {
  static final Map<String, TomLogFieldProvider> _providers = {
    'trace_id': () => TomTraceContext.current?.traceId,
    'span_id': () => TomTraceContext.current?.spanId,
    'request_id': () => TomRequestId.current?.value,
    'tenant': () => TomTenantContext.currentId,
  };

  /// The registered field names, in the order they are written.
  static List<String> get names => List.unmodifiable(_providers.keys);

  /// Registers [provider] for the field [name], replacing an earlier one.
  ///
  /// Throws `ArgumentError` for a name that collides with a fixed field of the
  /// line ([TomJsonLogOutput.fixedFields]).
  static void register(String name, TomLogFieldProvider provider) {
    if (TomJsonLogOutput.fixedFields.contains(name)) {
      // throws-outside-family: programmer error — a field name is chosen in
      // code, once.
      throw ArgumentError.value(
        name,
        'name',
        'is a fixed field of every structured log line',
      );
    }
    _providers[name] = provider;
  }

  /// Removes the field [name]; answers whether it was registered.
  static bool unregister(String name) => _providers.remove(name) != null;

  /// The context fields of the current zone that have a value.
  ///
  /// A provider that throws contributes nothing: a log line must not fail
  /// because the context it would have carried could not be read.
  static Map<String, String> fields() {
    final values = <String, String>{};
    for (final entry in _providers.entries) {
      try {
        final value = entry.value();
        if (value != null && value.isNotEmpty) values[entry.key] = value;
      } catch (_) {
        // A context field is decoration; the entry is written without it.
      }
    }
    return values;
  }
}

/// A [TomLogOutput] writing one JSON object per line — see the library
/// documentation for the fields.
///
/// ```dart
/// tomLog.logOutput = TomJsonLogOutput();
/// ```
///
/// Errors and status entries go to stderr and the rest to stdout, as
/// [TomConsoleLogOutput] routes them, unless a [writer] is given.
class TomJsonLogOutput extends TomLogOutput {
  /// An output writing through [writer] — each line without its newline, and
  /// whether it is an error-stream line — or to stdout/stderr when omitted.
  TomJsonLogOutput({void Function(String line, bool isError)? writer})
    : _writer = writer;

  /// The fields every line has, which a context field may not replace.
  static const Set<String> fixedFields = {
    'timestamp',
    'level',
    'message',
    'logger',
    'isolate',
  };

  final void Function(String line, bool isError)? _writer;

  @override
  void output(
    TomLogLevel loggerLevel,
    TomLogLevel logLevel,
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) {
    if (!logLevel.matches(loggerLevel)) return;
    final line = jsonEncode(
      entry(level, message, isolateName, timeStamp, origin),
    );
    final isError = logLevel.matches(
      TomConsoleLogOutput.globalSettingStderrLogLevel,
    );
    final writer = _writer;
    if (writer != null) {
      writer(line, isError);
    } else if (isError) {
      TomPlatformUtils.current.outError(line);
    } else {
      TomPlatformUtils.current.out(line);
    }
  }

  /// The object one entry is written as — the fixed fields, then the context
  /// fields of the current zone.
  Map<String, Object> entry(
    String level,
    Object message,
    String isolateName,
    DateTime timeStamp, [
    String? origin,
  ]) => {
    'timestamp': timeStamp.toUtc().toIso8601String(),
    'level': level.trim().toLowerCase(),
    'message': convertToString(message),
    if (origin != null && origin.isNotEmpty) 'logger': origin,
    'isolate': isolateName,
    ...TomLogContext.fields(),
  };
}

/// Example: the W3C trace context carried in the zone — [TomTraceContext]
///
/// - `parse` reads a `traceparent` header, and answers `null` for an invalid
///   one rather than failing
/// - `child` continues the caller's trace with a span of its own; `newRoot`
///   starts a trace when there is no caller to continue
/// - `run` makes a context current for a body, across its awaits, and
///   `traceparent` renders the header to send on an outgoing call
/// - the constructor refuses an id that is not lower-case hex of the right
///   length, or that is all zeros
///
/// The structured log output that writes these ids into every line is shown in
/// `samples/logging/07_json_log_output_example.dart`.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/context/05_trace_context_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

/// A `traceparent` header as a traced caller sends it.
const String incomingHeader =
    '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01';

/// Runs the trace-context demonstrations.
Future<void> run() async {
  print('=== 05: Trace Context Example ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: parse a traceparent header, and render it back
  // ---------------------------------------------------------------------------
  print('1. Parsing a traceparent header:');

  final caller = TomTraceContext.parse(incomingHeader)!;
  final unsampled = TomTraceContext.parse(
    '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00',
  )!;

  print('   - trace id:                ${caller.traceId}');
  print('   - the caller\'s span id:    ${caller.spanId}');
  print('   - sampled (flags 01):      ${caller.sampled}');
  print('   - sampled (flags 00):      ${unsampled.sampled}');
  print('   - rendered back:           ${caller.traceparent}\n');

  // ---------------------------------------------------------------------------
  // Example 2: an invalid header is ignored, not refused
  // ---------------------------------------------------------------------------
  print('2. An invalid header parses to null:');

  final invalid = <String?, TomTraceContext?>{
    null: TomTraceContext.parse(null),
    'garbage': TomTraceContext.parse('garbage'),
    'version 01': TomTraceContext.parse(
      '01-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
    ),
    'upper-case hex': TomTraceContext.parse(
      '00-4BF92F3577B34DA6A3CE929D0E0E4736-00f067aa0ba902b7-01',
    ),
    'all-zero trace id': TomTraceContext.parse(
      '00-00000000000000000000000000000000-00f067aa0ba902b7-01',
    ),
  };
  for (final entry in invalid.entries) {
    print('   - ${entry.key}: ${entry.value}');
  }
  print('');

  // ---------------------------------------------------------------------------
  // Example 3: continue the caller's trace, or start one
  // ---------------------------------------------------------------------------
  print('3. Continuing a trace with a span of our own:');

  final server = caller.child();
  final fresh =
      TomTraceContext.parse('garbage')?.child() ?? TomTraceContext.newRoot();

  print('   - same trace:              ${server.traceId == caller.traceId}');
  print('   - parent span:             ${server.parentSpanId}');
  print('   - our span:                ${server.spanId}');
  print('   - no caller, a new root:   ${fresh.traceId}');
  print('   - a root has no parent:    ${fresh.parentSpanId}\n');

  // ---------------------------------------------------------------------------
  // Example 4: run makes a context current, across awaits
  // ---------------------------------------------------------------------------
  print('4. The current context inside and outside run:');

  final before = TomTraceContext.current;
  TomTraceContext? inside;
  TomTraceContext? afterAwait;
  TomTraceContext? nested;
  String? outgoing;
  await TomTraceContext.run(server, () async {
    inside = TomTraceContext.current;
    await Future<void>.delayed(Duration.zero);
    afterAwait = TomTraceContext.current;
    // A nested run replaces the context for its body only.
    nested = TomTraceContext.run(
      TomTraceContext.current!.child(),
      () => TomTraceContext.current,
    );
    // The header an outgoing call carries, so the callee continues our span.
    outgoing = TomTraceContext.current!.traceparent;
  });
  final after = TomTraceContext.current;

  print('   - before run:              $before');
  print('   - inside run:              $inside');
  print('   - after an await:          $afterAwait');
  print('   - nested child\'s parent:   ${nested!.parentSpanId}');
  print('   - outgoing traceparent:    $outgoing');
  print('   - after run:               $after\n');

  // ---------------------------------------------------------------------------
  // Example 5: the constructor refuses an invalid id
  // ---------------------------------------------------------------------------
  print('5. An id chosen in code must be valid:');

  String? refusal(String traceId, String spanId) {
    try {
      TomTraceContext(traceId: traceId, spanId: spanId);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  final shortTrace = refusal('4bf92f35', caller.spanId);
  final zeroSpan = refusal(caller.traceId, '0000000000000000');
  final valid = refusal(caller.traceId, caller.spanId);

  print('   - a short trace id:        $shortTrace');
  print('   - an all-zero span id:     $zeroSpan');
  print('   - valid ids:               $valid\n');

  // ---------------------------------------------------------------------------
  // Verification
  // ---------------------------------------------------------------------------

  // Example 1
  assert(caller.traceId == '4bf92f3577b34da6a3ce929d0e0e4736', 'The trace id');
  assert(caller.spanId == '00f067aa0ba902b7', 'The caller\'s span is spanId');
  assert(caller.parentSpanId == null, 'A parsed context has no parent span');
  assert(caller.sampled && !unsampled.sampled, 'Flags 01 / 00 set sampled');
  assert(caller.traceparent == incomingHeader, 'traceparent renders it back');

  // Example 2
  assert(
    invalid.values.every((context) => context == null),
    'Every invalid header parses to null',
  );

  // Example 3
  assert(server.traceId == caller.traceId, 'A child keeps the trace');
  assert(server.parentSpanId == caller.spanId, 'A child continues the span');
  assert(server.spanId != caller.spanId, 'A child has a span of its own');
  assert(
    RegExp(r'^[0-9a-f]{16}$').hasMatch(server.spanId),
    'A new span id is 16 lower-case hex digits',
  );
  assert(server.sampled == caller.sampled, 'A child keeps the sampled flag');
  assert(
    RegExp(r'^[0-9a-f]{32}$').hasMatch(fresh.traceId) &&
        fresh.traceId != caller.traceId,
    'A new root starts a new trace',
  );
  assert(fresh.parentSpanId == null, 'A new root has no parent span');

  // Example 4
  assert(before == null && after == null, 'No trace outside run');
  assert(identical(inside, server), 'run makes the context current');
  assert(identical(afterAwait, server), 'The context survives an await');
  assert(
    nested!.parentSpanId == server.spanId && nested!.traceId == server.traceId,
    'A nested run sees its own context',
  );
  assert(
    outgoing == '00-${server.traceId}-${server.spanId}-01',
    'The outgoing header names our span, not the caller\'s',
  );

  // Example 5
  assert(shortTrace != null, 'A trace id is 32 hex digits');
  assert(zeroSpan != null, 'An all-zero span id is invalid');
  assert(valid == null, 'Valid ids construct');
}

/// Standalone entry point.
Future<void> main() async {
  prepareSampleProcess();
  await run();
}

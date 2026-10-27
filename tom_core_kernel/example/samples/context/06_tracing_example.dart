/// Example: spans — [TomTracing] and the tracer an application installs
///
/// - with no tracer installed nothing is recorded, and the work runs as it is
/// - `trace` runs work as a span continuing the current trace; the span is the
///   trace context its work runs in, so nested work is its child
/// - an error is recorded on the span and passed on
/// - `TomRequestId.runRoot` with a span name makes the work the first span of
///   a trace of its own — what every job run is
/// - [TomRecordingTracer] keeps the ended spans in memory, for tests
///
/// `tom_core_server`'s `TomOtelTracer` is the tracer a deployment installs; it
/// exports the same spans over OTLP.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/context/06_tracing_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

/// Runs the tracing demonstrations.
Future<void> run() async {
  print('=== 06: Tracing Example ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: off by default — nothing is made
  // ---------------------------------------------------------------------------
  print('1. With no tracer installed:');

  final value = await TomTracing.trace('work', (span) async {
    assert(span == null, 'No span is made without a tracer');
    return 42;
  });
  print('   - recording: ${TomTracing.isRecording}, result: $value\n');
  assert(!TomTracing.isRecording && value == 42, 'The work runs as it is');

  // ---------------------------------------------------------------------------
  // Example 2: spans nest, and each is the trace context of its work
  // ---------------------------------------------------------------------------
  print('2. With a recording tracer installed:');

  final tracer = TomRecordingTracer();
  TomTracing.install(tracer);
  await TomTracing.trace('load report', (outer) async {
    assert(TomTraceContext.current == outer!.context, 'The span is current');
    await TomTracing.trace(
      'SELECT',
      kind: TomSpanKind.client,
      attributes: {'db.operation.name': 'SELECT'},
      (_) async {},
    );
  });
  final outer = tracer.named('load report').single;
  final inner = tracer.named('SELECT').single;
  print('   - ${outer.name}: ${outer.context.traceparent}');
  print('   - ${inner.name}: parent ${inner.context.parentSpanId}\n');
  assert(tracer.childrenOf(outer).single == inner, 'Nested work is a child');
  assert(inner.kind == TomSpanKind.client, 'The kind is kept');

  // ---------------------------------------------------------------------------
  // Example 3: an error is recorded and passed on
  // ---------------------------------------------------------------------------
  print('3. A failing span:');

  try {
    await TomTracing.trace('fails', (_) async => throw StateError('boom'));
  } on StateError catch (error) {
    print('   - caught: ${error.message}');
  }
  final failed = tracer.named('fails').single;
  print('   - recorded: ${failed.errorDescription}\n');
  assert(failed.errors.single is StateError, 'The error is on the span');

  // ---------------------------------------------------------------------------
  // Example 4: a root span — a job run's trace of its own
  // ---------------------------------------------------------------------------
  print('4. A root span:');

  final requestId = await TomRequestId.runRoot(
    spanName: 'job nightly',
    () async => TomRequestId.current!.value,
  );
  final job = tracer.named('job nightly').single;
  print('   - ${job.name}: request id $requestId\n');
  assert(job.context.parentSpanId == null, 'A root span has no parent');
  assert(requestId == job.context.traceId, 'Its trace id is the request id');

  TomTracing.install(null);
}

/// Standalone entry point.
Future<void> main() async {
  prepareSampleProcess();
  await run();
}

// Runnable demo of the isolate_streaming primitives.
//
// No real isolate is spawned: the host/worker handshake is driven with plain
// futures so the example runs as an ordinary script. It walks each of the five
// building blocks in turn — cancellation, the per-stream close signal, the
// backpressure ledger, the request guard, and the exception registry.
//
// Run with:
//   dart run --enable-asserts example/isolate_streaming/isolate_streaming_example.dart

import 'dart:async';

import 'package:tom_core_agentic/tom_core_agentic.dart';

Future<void> main() async {
  await _demoCancellation();
  await _demoCloseSignal();
  await _demoBackpressure();
  await _demoRequestGuard();
  _demoExceptionRegistry();

  print('\nAll isolate_streaming demos completed.');
}

// ---------------------------------------------------------------------------
// Cancellation: the host allocates and registers a token, the worker holds a
// read-only handle and observes the cancellation.
// ---------------------------------------------------------------------------
Future<void> _demoCancellation() async {
  print('== cancellation ==');
  final allocator = IsolateCancellationTokenAllocator();
  final registry = IsolateCancellationRegistry();

  final token = allocator.next();
  final handle = registry.register(token);
  assert(!handle.isCancelled);
  assert(registry.inFlightCount == 1);

  // Worker awaits cancellation in the background.
  final observed = handle.cancelled.then((_) => 'worker saw cancel');

  // Host cancels the in-flight request.
  registry.cancel(token);
  print('  ${await observed}');
  assert(handle.isCancelled);

  // throwIfCancelled raises the typed exception once cancelled.
  try {
    handle.throwIfCancelled();
  } on IsolateCancellationException catch (e) {
    print('  throwIfCancelled -> $e');
  }

  // Late-cancel race: a cancel that arrives before its registration is
  // remembered, so the eventual register returns an already-cancelled handle.
  final lateToken = allocator.next();
  registry.cancel(lateToken); // arrives "early"
  final lateHandle = registry.register(lateToken);
  assert(lateHandle.isCancelled);
  print('  late-cancel handle isCancelled=${lateHandle.isCancelled}');
}

// ---------------------------------------------------------------------------
// Close signal: a host close request both raises a flag and fires a future.
// ---------------------------------------------------------------------------
Future<void> _demoCloseSignal() async {
  print('== close signal ==');
  final signal = IsolateStreamCloseSignal();
  assert(!signal.closeRequested);

  final awaited = signal.closeSignal.future.then((_) => 'producer stopped');
  signal.requestClose();
  signal.requestClose(); // idempotent

  assert(signal.closeRequested);
  print('  ${await awaited}');
}

// ---------------------------------------------------------------------------
// Backpressure: the consumer grants credits, the producer awaits/consumes.
// ---------------------------------------------------------------------------
Future<void> _demoBackpressure() async {
  print('== backpressure ==');
  // Start with no credits so the producer must wait for the consumer.
  final bp = BackpressureTracker(initialCredits: 0);

  // Producer blocks until a credit is granted, then consumes it to emit.
  final firstEmit = bp.awaitCredit().then((_) {
    bp.consume();
    return 'emitted item #1';
  });
  assert(bp.waiterCount == 1);

  bp.grant(1); // consumer signals room
  print('  ${await firstEmit}');
  assert(bp.credits == 0);

  // A waiter parked at close fails with StateError so the producer can unwind.
  final unwind = bp.awaitCredit().then(
    (_) => 'unexpected credit',
    onError: (Object e) => 'producer unwound after close ($e)',
  );
  bp.close();
  print('  ${await unwind}');
  assert(bp.isClosed);
}

// ---------------------------------------------------------------------------
// Request guard: a request fails fast on worker death (or a deadline).
// ---------------------------------------------------------------------------
Future<void> _demoRequestGuard() async {
  print('== request guard ==');
  final guard = IsolateRequestGuard(defaultTimeout: const Duration(seconds: 5));

  // A request the worker never answers.
  final pending = Completer<Never>();
  final guarded = guard.guard(pending.future, operation: 'embed');
  assert(guard.inFlightCount == 1);

  // The worker dies before replying.
  guard.markWorkerDead('isolate exited with code 70');

  try {
    await guarded;
  } on IsolateRequestFailure catch (e) {
    assert(e.reason == IsolateRequestFailureReason.workerDeath);
    print('  guarded request failed: $e');
  }
  assert(guard.isWorkerDead);
}

// ---------------------------------------------------------------------------
// Exception registry: rebuild typed errors from the data that crosses the wire.
// ---------------------------------------------------------------------------
void _demoExceptionRegistry() {
  print('== exception registry ==');
  final registry = IsolateExceptionRegistry()
    ..register(
      'NotFound',
      (message, details) => _NotFoundError(message, id: details['id'] as String?),
    );

  assert(registry.isRegistered('NotFound'));
  final restored = registry.reconstruct('NotFound', 'missing record', {'id': 'x-7'});
  print('  reconstructed: $restored');
  assert(restored is _NotFoundError);

  // An unregistered tag yields null; the caller falls back to a generic error.
  final unknown = registry.reconstruct('Mystery', 'huh', const {});
  assert(unknown == null);
  print('  unregistered tag -> $unknown');
}

class _NotFoundError implements Exception {
  _NotFoundError(this.message, {this.id});
  final String message;
  final String? id;
  @override
  String toString() => 'NotFound($message, id=$id)';
}

/// Demonstrates *executing* shutdown cleanup end-to-end.
///
/// Where `01_shutdown_handler_example.dart` describes the API, this example
/// actually drives it: it registers handlers/closables/disposables, triggers
/// [TomShutdownCleanup.performShutdown], and observes the resulting behaviour.
///
/// Key concepts covered:
/// - Cleanup phase order: signal handlers → closables → disposables
/// - Once-only execution: repeated triggers run cleanup once, and
///   [TomShutdownCleanup.hasShutDown] records that it has
/// - Fault isolation: a throwing entry never aborts the remaining cleanups
/// - [TomShutdownCleanup.paused]: the signal path is skipped while paused,
///   but a manual `performShutdown()` always runs
/// - [TomShutdownCleanup.silent]: suppresses status/diagnostic output
/// - [TomShutdownCleanup.output]: the one sink every line goes to
/// - [TomShutdownCleanup.cancelAll] / [TomShutdownCleanup.dispose]: tear the
///   signal watchers down so a short-lived instance stops leaking
/// - [TomCloseAdaptor]: adapts an object with a `close()`/`dispose()`/custom
///   teardown method (resolved via reflection) into a [TomClosable]
/// - Asynchronous teardown: a `close()` that returns a `Future` has finished
///   before the next entry is called and before `performShutdown()` completes
/// - [TomShutdownCleanup.phaseTimeout]: a phase that overruns its budget is
///   abandoned, and the next phase still runs
/// - Nesting: a coordinator is a [TomDisposable], registered on another and
///   run from its handler
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/shutdown_cleanup/03_shutdown_execution_example.dart
/// ```
library;

import 'dart:async';
import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

// =============================================================================
// Shutdown Execution Example
// =============================================================================

// -----------------------------------------------------------------------------
// Example Support Classes
// -----------------------------------------------------------------------------

/// Records how many times it was disposed, and appends to a shared trace.
class CountingDisposable implements TomDisposable {
  CountingDisposable(this.trace);
  final List<String> trace;
  int disposeCount = 0;

  @override
  void dispose() {
    disposeCount++;
    trace.add('disposable');
  }
}

/// Records how many times it was closed, and appends to a shared trace.
class CountingClosable implements TomClosable {
  CountingClosable(this.trace);
  final List<String> trace;
  int closeCount = 0;

  @override
  void close() {
    closeCount++;
    trace.add('closable');
  }
}

/// A closable whose `close()` throws, to demonstrate fault isolation.
class FailingClosable implements TomClosable {
  @override
  void close() => throw StateError('close boom');
}

/// A journal whose close flushes asynchronously, as a file or socket would.
class FlushingJournal implements TomClosable {
  FlushingJournal(this.trace);
  final List<String> trace;
  bool flushed = false;

  @override
  Future<void> close() async {
    // Stands in for `await sink.flush(); await sink.close();`.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    flushed = true;
    trace.add('journal flushed');
  }
}

/// A connection whose close is never acknowledged by the peer.
class UnresponsivePeer implements TomClosable {
  @override
  Future<void> close() => Completer<void>().future;
}

/// A legacy service with a custom-named teardown method and no Tom interface.
///
/// Registered with the Tom reflector so [TomCloseAdaptor] can resolve and
/// invoke its `shutdown()` method by name.
@tomReflector
class LegacyService {
  bool shutdownCalled = false;
  void shutdown() => shutdownCalled = true;
}

// -----------------------------------------------------------------------------
// Main Example Function
// -----------------------------------------------------------------------------

/// Runs the shutdown-execution demonstrations.
///
/// [TomCloseAdaptor] resolves teardown methods via reflection, so the reflected
/// [LegacyService] target must already be registered before [run] is called.
/// Both entry points do that: the group runner
/// (`00_run_all_examples.dart`) and this file's own `main()` each call
/// `bootstrapSamples()` first.
Future<void> run() async {
  print('=== 03: Shutdown Execution Example ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: Cleanup phase order (handlers → closables → disposables)
  // ---------------------------------------------------------------------------
  print('1. Cleanup phase order:');

  final orderTrace = <String>[];
  final ordered = TomShutdownCleanup();
  // Register out of phase order to prove the runner, not registration, decides.
  ordered.addDisposable(CountingDisposable(orderTrace));
  ordered.addSignalHandler((signal) => orderTrace.add('handler'));
  ordered.addClosable(CountingClosable(orderTrace));

  await ordered.performShutdown();

  print('   - Execution trace: $orderTrace\n');

  // ---------------------------------------------------------------------------
  // Example 2: Once-only execution
  // ---------------------------------------------------------------------------
  print('2. Once-only execution:');

  final onceTrace = <String>[];
  final once = TomShutdownCleanup();
  final onceClosable = CountingClosable(onceTrace);
  once.addClosable(onceClosable);

  await once.performShutdown();
  await once.performShutdown();
  await once.performShutdown();

  // The instance is spent now: a closable registered after the shutdown is
  // kept, but never runs. A second run needs a new instance.
  final lateClosable = CountingClosable(onceTrace);
  once.addClosable(lateClosable);
  await once.performShutdown();

  print(
    '   - close() invocations after 3 triggers: ${onceClosable.closeCount}',
  );
  print('   - hasShutDown:                       ${once.hasShutDown}');
  print(
    '   - late registration closed:          ${lateClosable.closeCount > 0}\n',
  );

  // ---------------------------------------------------------------------------
  // Example 3: Fault isolation (a throwing entry doesn't abort the phase)
  // ---------------------------------------------------------------------------
  print('3. Fault isolation:');

  final isolationTrace = <String>[];
  final isolated = TomShutdownCleanup();
  isolated.silent = true; // suppress the "Failed to call …" diagnostic
  isolated.addSignalHandler((signal) => throw StateError('handler boom'));
  isolated.addClosable(FailingClosable());
  isolated.addClosable(CountingClosable(isolationTrace));
  isolated.addDisposable(CountingDisposable(isolationTrace));

  await isolated.performShutdown();

  print('   - Survivors still ran: $isolationTrace\n');

  // ---------------------------------------------------------------------------
  // Example 4: paused — the signal path is skipped, the manual path is not
  // ---------------------------------------------------------------------------
  print('4. paused behaviour:');

  final pausedTrace = <String>[];
  final paused = TomShutdownCleanup();
  paused.silent = true;
  paused.addClosable(CountingClosable(pausedTrace));
  paused.paused = true;

  // Signal-driven trigger is ignored while paused …
  await paused.performShutdown(fromSignal: true);
  final afterSignalWhilePaused = List<String>.from(pausedTrace);

  // … but a manual call always runs.
  await paused.performShutdown();
  final afterManual = List<String>.from(pausedTrace);

  print('   - After signal while paused: $afterSignalWhilePaused');
  print('   - After manual call:         $afterManual\n');

  // ---------------------------------------------------------------------------
  // Example 5: silent — suppresses status messages on the signal path
  // ---------------------------------------------------------------------------
  print('5. silent behaviour:');

  final silent = TomShutdownCleanup();
  silent.silent = true;
  silent.addClosable(CountingClosable(<String>[]));
  // With silent = true the signal path emits no "Received …"/"Shutdown …" lines.
  await silent.performShutdown(fromSignal: true);

  print('   - Ran signal-path cleanup without emitting status lines');

  // Every line goes to `output`, which is `print` unless the host supplies a
  // sink — here a list, where a server would hand it to its logger.
  final routedLines = <String>[];
  final routed = TomShutdownCleanup()..output = routedLines.add;
  routed.addClosable(FailingClosable());
  await routed.performShutdown(fromSignal: true);

  print('   - Lines routed to the supplied sink: ${routedLines.length}');
  print('     first: ${routedLines.first}\n');

  // ---------------------------------------------------------------------------
  // Example 6: TomCloseAdaptor — adapt a custom teardown method
  // ---------------------------------------------------------------------------
  print('6. TomCloseAdaptor:');

  final legacy = LegacyService();
  final adaptor = TomCloseAdaptor(legacy, 'shutdown');
  final adaptorCleanup = TomShutdownCleanup();
  adaptorCleanup.addClosable(adaptor);

  await adaptorCleanup.performShutdown();

  print(
    '   - LegacyService.shutdown() called via adaptor: '
    '${legacy.shutdownCalled}\n',
  );

  // ---------------------------------------------------------------------------
  // Example 7: cancelAll / dispose — tear the signal watchers down
  // ---------------------------------------------------------------------------
  print('7. Watcher teardown:');

  final disposable1 = TomShutdownCleanup();
  await disposable1.cancelAll();
  // Safe to call again — the subscription list has already been emptied.
  await disposable1.cancelAll();

  final disposable2 = TomShutdownCleanup();
  disposable2.addSignal(ProcessSignal.sigterm);
  await disposable2.dispose();

  print('   - cancelAll() is idempotent and dispose() tears down cleanly\n');

  // ---------------------------------------------------------------------------
  // Example 8: asynchronous teardown is awaited
  // ---------------------------------------------------------------------------
  print('8. Asynchronous teardown:');

  final asyncTrace = <String>[];
  final journal = FlushingJournal(asyncTrace);
  final asyncCleanup = TomShutdownCleanup();
  asyncCleanup.addClosable(journal);
  asyncCleanup.addDisposable(CountingDisposable(asyncTrace));

  // Completes only once the journal has flushed — which is what makes it safe
  // to exit the process straight after awaiting it.
  await asyncCleanup.performShutdown();

  print('   - Execution trace: $asyncTrace\n');

  // ---------------------------------------------------------------------------
  // Example 9: a phase that overruns its budget is abandoned
  // ---------------------------------------------------------------------------
  print('9. Phase timeout:');

  final timeoutTrace = <String>[];
  final bounded = TomShutdownCleanup()
    ..silent = true
    ..phaseTimeout = const Duration(milliseconds: 100);
  bounded.addClosable(UnresponsivePeer());
  bounded.addClosable(CountingClosable(timeoutTrace)); // behind the hang
  bounded.addDisposable(CountingDisposable(timeoutTrace));

  final started = DateTime.now();
  await bounded.performShutdown();
  final took = DateTime.now().difference(started);

  print(
    '   - Default budget per phase: ${TomShutdownCleanup.defaultPhaseTimeout}',
  );
  print(
    '   - Survivors: $timeoutTrace, shutdown took ${took.inMilliseconds} ms\n',
  );

  // ---------------------------------------------------------------------------
  // Example 10: nesting one coordinator inside another
  // ---------------------------------------------------------------------------
  print('10. Nesting coordinators:');

  final nestedTrace = <String>[];
  final session = TomShutdownCleanup();
  session.addClosable(CountingClosable(nestedTrace)); // the session's resource
  final host = TomShutdownCleanup();
  // A coordinator is a TomDisposable. The handler runs the inner shutdown, so
  // its resource is closed; the disposable releases the inner coordinator.
  host
    ..addSignalHandler((signal) => session.performShutdown(signal: signal))
    ..addDisposable(session)
    ..addDisposable(CountingDisposable(nestedTrace));

  await host.performShutdown();

  print('   - Execution trace:  $nestedTrace');
  print('   - Session spent:    ${session.hasShutDown}\n');

  // ---------------------------------------------------------------------------
  // Teardown for the instances the examples above created
  // ---------------------------------------------------------------------------
  // Running a cleanup is not the same as disposing it: `performShutdown()`
  // executes the registered handlers, closables and disposables, but leaves the
  // SIGHUP/SIGINT watchers that the constructor started. Those watchers keep the
  // process alive, so without this block the sample prints everything below and
  // then hangs forever instead of exiting.
  for (final cleanup in [
    ordered,
    once,
    isolated,
    paused,
    silent,
    routed,
    adaptorCleanup,
    asyncCleanup,
    bounded,
    host,
  ]) {
    await cleanup.dispose();
  }

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: phase order is always handler → closable → disposable.
  assert(orderTrace.length == 3);
  assert(orderTrace[0] == 'handler');
  assert(orderTrace[1] == 'closable');
  assert(orderTrace[2] == 'disposable');

  // Example 2: cleanup runs exactly once even across repeated triggers, and a
  // spent instance runs nothing registered after it.
  assert(onceClosable.closeCount == 1);
  assert(once.hasShutDown);
  assert(lateClosable.closeCount == 0);

  // Example 3: the throwing handler and closable are skipped, survivors run.
  assert(isolationTrace.length == 2);
  assert(isolationTrace.contains('closable'));
  assert(isolationTrace.contains('disposable'));

  // Example 4: paused blocks only the signal path.
  assert(afterSignalWhilePaused.isEmpty);
  assert(afterManual.length == 1);
  assert(afterManual.first == 'closable');

  // Example 5: the status lines and the failure report all went to the sink.
  assert(routedLines.length == 3);
  assert(routedLines.first == 'Received SIGINT');
  assert(routedLines[1].contains('close boom'));

  // Example 6: the adaptor resolved and invoked the custom teardown method.
  assert(legacy.shutdownCalled == true);

  // Example 8: the flush finished before the disposables phase began.
  assert(journal.flushed, 'performShutdown() completes after the flush');
  assert(asyncTrace.length == 2);
  assert(asyncTrace[0] == 'journal flushed');
  assert(asyncTrace[1] == 'disposable');

  // Example 9: the closables phase was abandoned at the hang — the closable
  // behind it never ran — and the disposables phase ran in full.
  assert(timeoutTrace.length == 1);
  assert(timeoutTrace.single == 'disposable');
  assert(took < const Duration(seconds: 5), 'the budget bounded the shutdown');

  // Example 10: the inner resource closed in the handlers phase, before the
  // host's own disposable, and the inner coordinator was spent.
  assert(nestedTrace.length == 2);
  assert(nestedTrace[0] == 'closable');
  assert(nestedTrace[1] == 'disposable');
  assert(session.hasShutDown);
}

/// Standalone entry point.
Future<void> main() async {
  bootstrapSamples();
  await run();
}

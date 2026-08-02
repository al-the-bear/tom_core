/// Demonstrates *executing* shutdown cleanup end-to-end.
///
/// Where `01_shutdown_handler_example.dart` describes the API, this example
/// actually drives it: it registers handlers/closables/disposables, triggers
/// [TomShutdownCleanup.performShutdown], and observes the resulting behaviour.
///
/// Key concepts covered:
/// - Cleanup phase order: signal handlers → closables → disposables
/// - Once-only execution (`_executed`): repeated triggers run cleanup once
/// - Fault isolation: a throwing entry never aborts the remaining cleanups
/// - [TomShutdownCleanup.paused]: the signal path is skipped while paused,
///   but a manual `performShutdown()` always runs
/// - [TomShutdownCleanup.silent]: suppresses status/diagnostic output
/// - [TomShutdownCleanup.cancelAll] / [TomShutdownCleanup.dispose]: tear the
///   signal watchers down so a short-lived instance stops leaking (bug §53)
/// - [TomCloseAdaptor]: adapts an object with a `close()`/`dispose()`/custom
///   teardown method (resolved via reflection) into a [TomClosable]
library;

import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';

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
/// [LegacyService] target must already be registered before [run] is called —
/// the runner (`00_run_all_examples.dart`) owns that one-time initialization.
Future<void> run() async {
  print('=== 02: Shutdown Execution Example ===\n');

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

  ordered.performShutdown();

  print('   - Execution trace: $orderTrace\n');

  // ---------------------------------------------------------------------------
  // Example 2: Once-only execution
  // ---------------------------------------------------------------------------
  print('2. Once-only execution:');

  final onceTrace = <String>[];
  final once = TomShutdownCleanup();
  final onceClosable = CountingClosable(onceTrace);
  once.addClosable(onceClosable);

  once.performShutdown();
  once.performShutdown();
  once.performShutdown();

  print('   - close() invocations after 3 triggers: ${onceClosable.closeCount}\n');

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

  isolated.performShutdown();

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
  paused.performShutdown(fromSignal: true);
  final afterSignalWhilePaused = List<String>.from(pausedTrace);

  // … but a manual call always runs.
  paused.performShutdown();
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
  silent.performShutdown(fromSignal: true);

  print('   - Ran signal-path cleanup without emitting status lines\n');

  // ---------------------------------------------------------------------------
  // Example 6: TomCloseAdaptor — adapt a custom teardown method
  // ---------------------------------------------------------------------------
  print('6. TomCloseAdaptor:');

  final legacy = LegacyService();
  final adaptor = TomCloseAdaptor(legacy, 'shutdown');
  final adaptorCleanup = TomShutdownCleanup();
  adaptorCleanup.addClosable(adaptor);

  adaptorCleanup.performShutdown();

  print('   - LegacyService.shutdown() called via adaptor: '
      '${legacy.shutdownCalled}\n');

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

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: phase order is always handler → closable → disposable.
  assert(orderTrace.length == 3);
  assert(orderTrace[0] == 'handler');
  assert(orderTrace[1] == 'closable');
  assert(orderTrace[2] == 'disposable');

  // Example 2: cleanup runs exactly once even across repeated triggers.
  assert(onceClosable.closeCount == 1);

  // Example 3: the throwing handler and closable are skipped, survivors run.
  assert(isolationTrace.length == 2);
  assert(isolationTrace.contains('closable'));
  assert(isolationTrace.contains('disposable'));

  // Example 4: paused blocks only the signal path.
  assert(afterSignalWhilePaused.isEmpty);
  assert(afterManual.length == 1);
  assert(afterManual.first == 'closable');

  // Example 6: the adaptor resolved and invoked the custom teardown method.
  assert(legacy.shutdownCalled == true);
}

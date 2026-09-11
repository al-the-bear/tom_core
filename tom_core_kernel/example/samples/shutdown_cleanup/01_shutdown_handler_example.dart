/// Example: registering resources with TomShutdownCleanup
///
/// This example is the API tour of the shutdown-cleanup module: the three
/// things you can register on a [TomShutdownCleanup], and what each one does
/// when the cleanup runs.
/// - [TomDisposable] — an object with a `dispose()`, registered with
///   [TomShutdownCleanup.addDisposable]
/// - [TomClosable] — an object with a `close()`, registered with
///   [TomShutdownCleanup.addClosable]
/// - [TomSignalHandler] — a function, registered with
///   [TomShutdownCleanup.addSignalHandler], which receives the signal that
///   triggered the shutdown
///
/// Each registration returns a [TomShutdownUnregister] that takes it back.
///
/// It also draws the two distinctions the module is most often misread on:
/// disposing a coordinator is *not* running it, and a custom coordinator is
/// independent of the global [tomShutdownCleanup].
///
/// `03_shutdown_execution_example.dart` owns the execution semantics — phase
/// order, once-only execution, fault isolation, `paused`, `silent` — and
/// `02_advanced_shutdown_example.dart` owns [TomCloseAdaptor].
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/shutdown_cleanup/01_shutdown_handler_example.dart
/// ```
library;

import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// =============================================================================
// Example Support Classes
// =============================================================================

/// A resource with a `dispose()`, of the kind [TomShutdownCleanup] disposes
/// last.
class SampleController implements TomDisposable {
  SampleController(this.name);

  final String name;
  bool isDisposed = false;

  @override
  void dispose() => isDisposed = true;
}

/// A resource with a `close()`, of the kind [TomShutdownCleanup] closes before
/// it disposes anything.
class SampleConnection implements TomClosable {
  SampleConnection(this.name);

  final String name;
  bool isClosed = false;

  @override
  void close() => isClosed = true;
}

// =============================================================================
// Main Example Function
// =============================================================================

/// Runs the registration demonstrations.
Future<void> run() async {
  print('=== 01: Shutdown Handler Example ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: TomDisposable
  // ---------------------------------------------------------------------------
  print('1. Registering a TomDisposable:');

  final controller = SampleController('event-controller');
  final disposableCleanup = TomShutdownCleanup();
  disposableCleanup.addDisposable(controller);

  // Registering does not run anything — the resource is live until the
  // shutdown happens.
  final disposedAfterRegistering = controller.isDisposed;
  await disposableCleanup.performShutdown();
  final disposedAfterShutdown = controller.isDisposed;

  print(
    '   - ${controller.name} disposed after register: '
    '$disposedAfterRegistering',
  );
  print(
    '   - ${controller.name} disposed after shutdown: '
    '$disposedAfterShutdown\n',
  );

  // ---------------------------------------------------------------------------
  // Example 2: TomClosable
  // ---------------------------------------------------------------------------
  print('2. Registering a TomClosable:');

  final connection = SampleConnection('primary-db');
  final closableCleanup = TomShutdownCleanup();
  closableCleanup.addClosable(connection);

  final closedAfterRegistering = connection.isClosed;
  await closableCleanup.performShutdown();
  final closedAfterShutdown = connection.isClosed;

  print(
    '   - ${connection.name} closed after register:  '
    '$closedAfterRegistering',
  );
  print(
    '   - ${connection.name} closed after shutdown:  '
    '$closedAfterShutdown\n',
  );

  // ---------------------------------------------------------------------------
  // Example 3: a signal handler is told which signal fired
  // ---------------------------------------------------------------------------
  print('3. A signal handler receives the triggering signal:');

  ProcessSignal? handlerSawSignal;
  final handlerCleanup = TomShutdownCleanup();
  handlerCleanup.addSignalHandler((signal) => handlerSawSignal = signal);

  final signalBeforeShutdown = handlerSawSignal;
  // The signal is forwarded to every registered handler, so one handler can
  // clean up differently for SIGTERM than for SIGINT.
  await handlerCleanup.performShutdown(signal: ProcessSignal.sigterm);

  print(
    '   - Handler invoked before shutdown: '
    '${signalBeforeShutdown != null}',
  );
  print('   - Signal the handler received:     $handlerSawSignal\n');

  // ---------------------------------------------------------------------------
  // Example 4: disposing a coordinator is not running it
  // ---------------------------------------------------------------------------
  print('4. dispose() releases everything without cleaning anything up:');

  final unrun = SampleConnection('cache');
  final disposedCleanup = TomShutdownCleanup();
  disposedCleanup.addClosable(unrun);

  // dispose() cancels the SIGHUP/SIGINT watchers this instance started in its
  // constructor, and drops every registration. The watchers keep the Dart
  // process alive, so any short-lived coordinator must be disposed — but
  // disposal is a teardown of the *coordinator*, not of the resources
  // registered on it: they are let go, not closed.
  await disposedCleanup.dispose();
  final closedByDispose = unrun.isClosed;

  // Nothing is registered any more, so a later manual shutdown closes nothing.
  // Run the shutdown first when the resources still need it.
  await disposedCleanup.performShutdown();
  final closedByLaterShutdown = unrun.isClosed;

  print('   - ${unrun.name} closed by dispose():      $closedByDispose');
  print(
    '   - ${unrun.name} closed by later shutdown: '
    '$closedByLaterShutdown\n',
  );

  // ---------------------------------------------------------------------------
  // Example 5: a custom coordinator is independent of the global one
  // ---------------------------------------------------------------------------
  print('5. A custom coordinator does not touch the global one:');

  final globalResource = SampleController('global-controller');
  final customResource = SampleController('custom-controller');

  // Reading `tomShutdownCleanup` is what constructs it, and construction
  // starts its SIGHUP/SIGINT watchers.
  tomShutdownCleanup.addDisposable(globalResource);

  final custom = TomShutdownCleanup();
  custom.addDisposable(customResource);
  await custom.performShutdown();

  print('   - ${customResource.name} disposed: ${customResource.isDisposed}');
  print('   - ${globalResource.name} disposed: ${globalResource.isDisposed}\n');

  // ---------------------------------------------------------------------------
  // Example 6: taking a registration back
  // ---------------------------------------------------------------------------
  print('6. Each add* returns the way to take the registration back:');

  final session = SampleConnection('user-session');
  final keeper = SampleConnection('keeper');
  final sessionCleanup = TomShutdownCleanup();
  final unregisterSession = sessionCleanup.addClosable(session);
  sessionCleanup.addClosable(keeper);

  // The application ends the session itself, long before the process exits,
  // and takes it off the list — otherwise the coordinator would hold it for
  // its whole life and close it a second time at exit.
  unregisterSession();
  await sessionCleanup.performShutdown();

  print('   - ${session.name} closed by the shutdown: ${session.isClosed}');
  print(
    '   - ${keeper.name} closed by the shutdown:       ${keeper.isClosed}\n',
  );

  // ---------------------------------------------------------------------------
  // Teardown for the instances the examples above created
  // ---------------------------------------------------------------------------
  // Running a cleanup is not the same as disposing it: `performShutdown()`
  // executes the registrations but leaves the SIGHUP/SIGINT watchers the
  // constructor started, and an active watcher keeps the process alive. The
  // global is included because a sample that merely *reads* it has already
  // started its watchers; a long-running application wants exactly those and
  // never disposes it.
  for (final cleanup in [
    disposableCleanup,
    closableCleanup,
    handlerCleanup,
    custom,
    sessionCleanup,
    tomShutdownCleanup,
  ]) {
    await cleanup.dispose();
  }

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: registering arms the disposal, the shutdown performs it.
  assert(!disposedAfterRegistering, 'Registering must not dispose');
  assert(disposedAfterShutdown, 'The shutdown must dispose the disposable');

  // Example 2: the same contract for closables.
  assert(!closedAfterRegistering, 'Registering must not close');
  assert(closedAfterShutdown, 'The shutdown must close the closable');

  // Example 3: the handler runs only on shutdown, and is told which signal.
  assert(signalBeforeShutdown == null, 'Registering must not invoke a handler');
  assert(
    handlerSawSignal == ProcessSignal.sigterm,
    'The handler must receive the signal the shutdown was given',
  );

  // Example 4: dispose() lets the registrations go without running them.
  assert(!closedByDispose, 'dispose() must not run the registered cleanups');
  assert(!closedByLaterShutdown, 'dispose() drops the registrations');

  // Example 6: an unregistered entry is not run; the others still are.
  assert(!session.isClosed, 'An unregistered closable must not be closed');
  assert(keeper.isClosed, 'The registration left in place still runs');

  // Example 5: the two coordinators keep separate registration lists.
  assert(customResource.isDisposed, 'The custom coordinator ran its own entry');
  assert(
    !globalResource.isDisposed,
    'A custom coordinator must not run the global one\'s entries',
  );
}

/// Standalone entry point.
Future<void> main() async {
  prepareSampleProcess();
  await run();
}

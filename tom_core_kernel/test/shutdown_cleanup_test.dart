import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'shutdown_cleanup_test.reflection.dart';

// =============================================================================
// Test Implementations
// =============================================================================

/// Test implementation of TomDisposable
class TestDisposable implements TomDisposable {
  bool disposed = false;
  int disposeCount = 0;

  @override
  void dispose() {
    disposed = true;
    disposeCount++;
  }
}

/// Test implementation of TomDisposable that throws
class ThrowingDisposable implements TomDisposable {
  @override
  void dispose() {
    throw Exception('Dispose failed');
  }
}

/// Test implementation of TomClosable
class TestClosable implements TomClosable {
  bool closed = false;
  int closeCount = 0;

  @override
  void close() {
    closed = true;
    closeCount++;
  }
}

/// Test implementation of TomClosable that throws
class ThrowingClosable implements TomClosable {
  @override
  void close() {
    throw Exception('Close failed');
  }
}

/// Closable whose teardown is asynchronous: it finishes one turn of the event
/// loop after it is called, so it has finished only if something awaited it.
class AsyncClosable implements TomClosable {
  AsyncClosable([this.log]);
  final List<String>? log;
  bool flushed = false;

  @override
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    flushed = true;
    log?.add('async closable');
  }
}

/// Closable whose asynchronous teardown fails *after* its first suspension, so
/// the throw lands inside the returned future rather than at the call itself.
class AsyncThrowingClosable implements TomClosable {
  @override
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    throw Exception('Async close failed');
  }
}

/// Disposable whose teardown is asynchronous.
class AsyncDisposable implements TomDisposable {
  AsyncDisposable(this.log);
  final List<String> log;

  @override
  Future<void> dispose() async {
    await Future<void>.delayed(Duration.zero);
    log.add('async disposable');
  }
}

/// Closable that runs [onClose] when it is closed.
class _CallbackClosable implements TomClosable {
  _CallbackClosable(this.onClose);
  final void Function() onClose;

  @override
  void close() => onClose();
}

/// Closable whose teardown never finishes — a peer that never acknowledges the
/// close. Only a phase timeout gets a shutdown past it.
class HangingClosable implements TomClosable {
  bool started = false;

  @override
  Future<void> close() {
    started = true;
    return Completer<void>().future;
  }
}

/// Closable that takes [delay] to close and then records [name].
class DelayedClosable implements TomClosable {
  DelayedClosable(this.name, this.delay, this.log);
  final String name;
  final Duration delay;
  final List<String> log;

  @override
  Future<void> close() async {
    await Future<void>.delayed(delay);
    log.add(name);
  }
}

/// Closable that fails [delay] after it is called.
class LateFailingClosable implements TomClosable {
  LateFailingClosable(this.delay);
  final Duration delay;

  @override
  Future<void> close() async {
    await Future<void>.delayed(delay);
    throw Exception('Late close failed');
  }
}

/// Closable that holds the thread for [duration] without ever suspending.
class BusyClosable implements TomClosable {
  BusyClosable(this.duration);
  final Duration duration;

  @override
  void close() {
    final watch = Stopwatch()..start();
    while (watch.elapsed < duration) {}
  }
}

// =============================================================================
// Reflected targets for TomCloseAdaptor (own + inherited members)
// =============================================================================

/// Target whose `close()` is declared on the leaf type itself.
@tomReflector
class OwnCloseTarget {
  bool closed = false;
  void close() => closed = true;
}

/// Target whose `close()` is asynchronous, so the adaptor has a future to
/// hand on.
@tomReflector
class AsyncCloseTarget {
  bool closed = false;
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    closed = true;
  }
}

/// Base declaring `close()`; the leaf [InheritsClose] does not redeclare it,
/// so the adaptor must walk the superclass chain to find it.
@tomReflector
class BaseWithClose {
  bool closed = false;
  void close() => closed = true;
}

@tomReflector
class InheritsClose extends BaseWithClose {}

/// Base declaring `dispose()`; the leaf [InheritsDispose] inherits it.
@tomReflector
class BaseWithDispose {
  bool disposedFlag = false;
  void dispose() => disposedFlag = true;
}

@tomReflector
class InheritsDispose extends BaseWithDispose {}

/// Base declaring a custom-named teardown method `shutdown()`; the leaf
/// [InheritsShutdown] inherits it (exercises the custom-methodName path
/// across the superclass chain).
@tomReflector
class BaseWithShutdown {
  bool shutdownCalled = false;
  void shutdown() => shutdownCalled = true;
}

@tomReflector
class InheritsShutdown extends BaseWithShutdown {}

/// Mixin declaring `close()`; the leaf [MixesInClose] gets it without
/// redeclaring, so resolving it means the walk sees through the mixin
/// application rather than only through named superclasses.
mixin ClosingMixin {
  bool closed = false;
  void close() => closed = true;
}

@tomReflector
class MixesInClose with ClosingMixin {}

/// Mixin declaring `dispose()`; the leaf [MixesInDispose] gets it the same way.
mixin DisposingMixin {
  bool disposedFlag = false;
  void dispose() => disposedFlag = true;
}

@tomReflector
class MixesInDispose with DisposingMixin {}

/// Target whose close method requires a parameter (error path).
@tomReflector
class CloseWithParam {
  void close(int code) {}
}

/// Target whose close takes an optional positional parameter, which the
/// adaptor can leave out.
@tomReflector
class OptionalPositionalClose {
  bool closed = false;
  void close([bool force = false]) => closed = true;
}

/// Target whose close takes an optional named parameter.
@tomReflector
class OptionalNamedClose {
  bool closed = false;
  void close({bool force = false}) => closed = true;
}

/// Target whose close takes a required named parameter, which the adaptor
/// has no way to supply.
@tomReflector
class RequiredNamedClose {
  void close({required bool force}) {}
}

/// Target with neither close nor dispose (not-found error path).
@tomReflector
class NoCloseTarget {
  void doStuff() {}
}

/// Target deliberately **not** annotated with `@tomReflector`.
///
/// This is the situation the adaptor exists for — a third-party class you
/// cannot annotate — so it is the adaptor's most likely failure, not an edge
/// case. The class has a perfectly good `close()`; what it lacks is generated
/// reflection data.
class UnreflectedTarget {
  bool closed = false;
  void close() => closed = true;
}

// =============================================================================
// Order / counting recorders for performShutdown() behaviour tests
// =============================================================================

/// Records the cleanup category into a shared list on close.
class RecordingClosable implements TomClosable {
  RecordingClosable(this.log);
  final List<String> log;
  @override
  void close() => log.add('closable');
}

/// Records the cleanup category into a shared list on dispose.
class RecordingDisposable implements TomDisposable {
  RecordingDisposable(this.log);
  final List<String> log;
  @override
  void dispose() => log.add('disposable');
}

/// Records its own [name] on close, so that several of them in one phase show
/// the order that phase ran in — which [RecordingClosable] cannot, since every
/// instance writes the same word.
class NamedClosable implements TomClosable {
  NamedClosable(this.name, this.log);
  final String name;
  final List<String> log;
  @override
  void close() => log.add(name);
}

/// Records its own [name] on dispose. The disposable counterpart to
/// [NamedClosable].
class NamedDisposable implements TomDisposable {
  NamedDisposable(this.name, this.log);
  final String name;
  final List<String> log;
  @override
  void dispose() => log.add(name);
}

// =============================================================================
// Test Helpers
// =============================================================================

/// Builds a [TomShutdownCleanup] that is torn down when the current test ends.
///
/// The constructor arms SIGHUP and SIGINT watchers, and a live watcher keeps
/// the isolate alive — so a test that builds an instance and walks away leaves
/// two subscriptions behind it. Routing every construction through here means
/// no test has to remember, and none of them can quietly forget.
///
/// Must be called from inside a test body: [addTearDown] registers against the
/// running test, and throws outside one.
TomShutdownCleanup _newCleanup() {
  final cleanup = TomShutdownCleanup();
  // dispose() delegates to cancelAll(), which empties the subscription list —
  // so this is harmless for the tests that dispose deliberately as the thing
  // under test.
  addTearDown(cleanup.dispose);
  return cleanup;
}

/// Reason the tests that send this process a real OS signal cannot run, or
/// `null` when they can. Windows has no SIGUSR1/SIGUSR2 to send.
final String? _signalSendingSkipReason = Platform.isWindows
    ? 'sends SIGUSR1/SIGUSR2, which Windows does not have'
    : null;

/// A cleanup that is safe to drive from a real signal.
///
/// Silent because the signal-driven path prints its status messages, and those
/// belong to the `performShutdown` group rather than to the console of every
/// run.
TomShutdownCleanup _sendableCleanup() => _newCleanup()..silent = true;

/// Sends [signal] to this process and returns once it has been delivered.
///
/// The wait is on delivery, not on a duration: this subscribes to [signal]
/// itself and returns when *that* subscription fires. So the negative case —
/// asserting some cleanup did not react — rests on the signal having actually
/// arrived rather than on a sleep having been long enough.
///
/// That subscription does double duty. SIGUSR1 and SIGUSR2 terminate a process
/// that is not watching them, so the very regression these tests exist to
/// catch — an `addSignal` that installs no watcher — would kill the whole test
/// runner rather than fail one test. Subscribing here takes the default
/// disposition out of play. It subscribes *after* the code under test has, so
/// that where delivery order matters the watcher under test is served first.
Future<void> _sendAndSettle(ProcessSignal signal) async {
  final delivered = Completer<void>();
  final witness = signal.watch().listen((_) {
    if (!delivered.isCompleted) delivered.complete();
  });
  addTearDown(witness.cancel);

  Process.killPid(pid, signal);
  await delivered.future.timeout(const Duration(seconds: 10));
  // One further turn of the event loop, so that any listener notified behind
  // the witness has also run before the caller asserts.
  await Future<void>.delayed(Duration.zero);
}

// =============================================================================
// TomDisposable Tests
// =============================================================================

void main() {
  setUpAll(initializeReflection);

  group('TomDisposable', () {
    group('interface implementation', () {
      test('should allow implementing dispose method', () {
        // Arrange
        final disposable = TestDisposable();

        // Act
        disposable.dispose();

        // Assert
        expect(disposable.disposed, isTrue);
      });

      test('should track dispose calls', () {
        // Arrange
        final disposable = TestDisposable();

        // Act
        disposable.dispose();
        disposable.dispose();
        disposable.dispose();

        // Assert
        expect(disposable.disposeCount, equals(3));
      });

      test('should be usable with type checking', () {
        // Arrange
        final disposable = TestDisposable();

        // Assert
        expect(disposable, isA<TomDisposable>());
      });
    });
  });

  // ===========================================================================
  // TomClosable Tests
  // ===========================================================================

  group('TomClosable', () {
    group('interface implementation', () {
      test('should allow implementing close method', () {
        // Arrange
        final closable = TestClosable();

        // Act
        closable.close();

        // Assert
        expect(closable.closed, isTrue);
      });

      test('should track close calls', () {
        // Arrange
        final closable = TestClosable();

        // Act
        closable.close();
        closable.close();

        // Assert
        expect(closable.closeCount, equals(2));
      });

      test('should be usable with type checking', () {
        // Arrange
        final closable = TestClosable();

        // Assert
        expect(closable, isA<TomClosable>());
      });
    });
  });

  // ===========================================================================
  // TomShutdownCleanup Tests
  // ===========================================================================

  group('TomShutdownCleanup', () {
    group('constructor', () {
      test('each call yields a fresh instance, and never the global', () {
        // Two halves of one mistake. A constructor that handed back a shared
        // instance would make every registration in this file outlive the
        // test that made it; if the shared instance were the process-wide
        // tomShutdownCleanup, it would outlive the run.
        final first = _newCleanup();
        final second = _newCleanup();

        expect(identical(first, second), isFalse);
        expect(identical(first, tomShutdownCleanup), isFalse);
      });
    });

    // Registering something is only observable through the shutdown that runs
    // it, so each of the three groups below registers, calls
    // `performShutdown()`, and asserts what came back. Each asks what is
    // distinctive to its own method: that the entry is reached at all, that
    // entries of one kind run in the order they were registered, and how a
    // repeat registration behaves. What the three phases have in common —
    // their order relative to each other, the once-only guard, failure
    // isolation, the diagnostics, paused and silent — belongs to the
    // `performShutdown` group and is not restated here.

    group('addDisposable', () {
      test('the registered disposable is disposed', () async {
        final cleanup = _newCleanup();
        final disposable = TestDisposable();
        cleanup.addDisposable(disposable);

        await cleanup.performShutdown();

        expect(disposable.disposed, isTrue);
      });

      test('several disposables run in registration order', () async {
        final log = <String>[];
        final cleanup = _newCleanup();
        cleanup.addDisposable(NamedDisposable('first', log));
        cleanup.addDisposable(NamedDisposable('second', log));
        cleanup.addDisposable(NamedDisposable('third', log));

        await cleanup.performShutdown();

        expect(log, equals(['first', 'second', 'third']));
      });

      test('the same disposable registered twice is disposed twice', () async {
        // Registration appends; it does not deduplicate. So the caller owns
        // the arithmetic: a disposable that cannot survive being disposed
        // twice must be registered once.
        final cleanup = _newCleanup();
        final disposable = TestDisposable();
        cleanup.addDisposable(disposable);
        cleanup.addDisposable(disposable);

        await cleanup.performShutdown();

        expect(disposable.disposeCount, equals(2));
      });
    });

    group('addClosable', () {
      test('the registered closable is closed', () async {
        final cleanup = _newCleanup();
        final closable = TestClosable();
        cleanup.addClosable(closable);

        await cleanup.performShutdown();

        expect(closable.closed, isTrue);
      });

      test('several closables run in registration order', () async {
        final log = <String>[];
        final cleanup = _newCleanup();
        cleanup.addClosable(NamedClosable('first', log));
        cleanup.addClosable(NamedClosable('second', log));
        cleanup.addClosable(NamedClosable('third', log));

        await cleanup.performShutdown();

        expect(log, equals(['first', 'second', 'third']));
      });

      test('the same closable registered twice is closed twice', () async {
        final cleanup = _newCleanup();
        final closable = TestClosable();
        cleanup.addClosable(closable);
        cleanup.addClosable(closable);

        await cleanup.performShutdown();

        expect(closable.closeCount, equals(2));
      });
    });

    group('addSignalHandler', () {
      test('the handler runs and receives the signal', () async {
        // The signal is the one thing a handler gets that a closable and a
        // disposable do not, so a handler that runs but is handed the wrong
        // signal is still broken.
        final cleanup = _newCleanup();
        final received = <ProcessSignal>[];
        cleanup.addSignalHandler(received.add);

        await cleanup.performShutdown(signal: ProcessSignal.sigterm);

        expect(received, equals([ProcessSignal.sigterm]));
      });

      test('several handlers run in registration order', () async {
        final log = <String>[];
        final cleanup = _newCleanup();
        cleanup.addSignalHandler((signal) => log.add('first'));
        cleanup.addSignalHandler((signal) => log.add('second'));
        cleanup.addSignalHandler((signal) => log.add('third'));

        await cleanup.performShutdown();

        expect(log, equals(['first', 'second', 'third']));
      });

      test(
        'a handler that does nothing does not stop the ones behind it',
        () async {
          final log = <String>[];
          final cleanup = _newCleanup();
          cleanup.addSignalHandler((signal) {});
          cleanup.addSignalHandler((signal) => log.add('reached'));

          await cleanup.performShutdown();

          expect(log, equals(['reached']));
        },
      );
    });

    // `addSignal` is the one registration whose effect `performShutdown()`
    // cannot show, because its effect is on the OS rather than on a list: the
    // process starts reacting to a signal it previously ignored. The
    // subscription it stores is private, so the only honest way to observe it
    // is to send the signal — which is also the module's entire reason to
    // exist, and is otherwise exercised nowhere.
    group('addSignal', () {
      test('the registered signal drives the cleanup', () async {
        final cleanup = _sendableCleanup();
        final ran = Completer<void>();
        cleanup.addSignalHandler((signal) => ran.complete());
        cleanup.addSignal(ProcessSignal.sigusr1);

        await _sendAndSettle(ProcessSignal.sigusr1);

        expect(ran.isCompleted, isTrue);
      });

      test('the handlers are told which signal arrived', () async {
        // A watcher hard-wired to one signal, or one that forwarded the
        // default instead of the signal it caught, would pass the test above
        // and fail this one.
        final cleanup = _sendableCleanup();
        final received = <ProcessSignal>[];
        cleanup.addSignalHandler(received.add);
        cleanup.addSignal(ProcessSignal.sigusr2);

        await _sendAndSettle(ProcessSignal.sigusr2);

        expect(received, equals([ProcessSignal.sigusr2]));
      });

      test('a signal that was never registered is ignored', () async {
        final cleanup = _sendableCleanup();
        var ran = false;
        cleanup.addSignalHandler((signal) => ran = true);
        cleanup.addSignal(ProcessSignal.sigusr1);

        await _sendAndSettle(ProcessSignal.sigusr2);

        expect(ran, isFalse);
      });

      test('registering the same signal twice reports one shutdown', () async {
        // A second watcher on the same signal does not corrupt the cleanup —
        // it runs once per instance — but it does drive the handler twice, so
        // one Ctrl-C reports itself twice and claims on its own first arrival
        // that shutdown "has already been performed". The operator-visible
        // output is therefore the assertion, rather than a count of how many
        // times the handler ran.
        //
        // The signal is SIGUSR1 rather than the SIGINT the constructor itself
        // registers, because a real SIGINT would reach the whole test runner
        // and the process-wide `tomShutdownCleanup` along with it. The
        // constructor registers through this same method, so the duplicate it
        // could collide with is caught by the same mechanism.
        final lines = <String>[];
        await _capturePrints(lines, () async {
          final cleanup = _newCleanup();
          cleanup.addSignal(ProcessSignal.sigusr1);
          cleanup.addSignal(ProcessSignal.sigusr1);

          await _sendAndSettle(ProcessSignal.sigusr1);
        });

        expect(lines, equals(['Received SIGUSR1', 'Shutdown performed']));
      });
    }, skip: _signalSendingSkipReason);

    group('registration order decides cleanup order', () {
      // What the removed `start()` group was really pinning: cleanup runs in
      // one order regardless of *when* anything else was called on the
      // instance. The constructor registers the SIGHUP/SIGINT listeners, so
      // there is no arming step whose position in the sequence could matter —
      // which is why a method named `start()` had to go: it implied a
      // lifecycle the class does not have, and four documentation sites drifted
      // into describing it as setup.

      /// Registers one cleanup of each kind on [cleanup], recording the
      /// category it belongs to into [log] when it runs.
      void registerRecorders(TomShutdownCleanup cleanup, List<String> log) {
        cleanup.addSignalHandler((signal) => log.add('handler'));
        cleanup.addClosable(RecordingClosable(log));
        cleanup.addDisposable(RecordingDisposable(log));
      }

      const expectedOrder = ['handler', 'closable', 'disposable'];

      test('a freshly constructed instance is already armed', () async {
        // No call of any kind between construction and registration: the
        // watchers are installed by the constructor, so cleanup runs.
        final log = <String>[];
        final cleanup = _newCleanup();
        registerRecorders(cleanup, log);

        await cleanup.performShutdown();

        expect(log, equals(expectedOrder));
      });

      test('two instances registered alike clean up alike', () async {
        final firstLog = <String>[];
        final first = _newCleanup();
        registerRecorders(first, firstLog);
        await first.performShutdown();

        final secondLog = <String>[];
        final second = _newCleanup();
        registerRecorders(second, secondLog);
        await second.performShutdown();

        expect(firstLog, equals(expectedOrder));
        expect(secondLog, equals(expectedOrder));
      });
    });

    group('mixed handlers', () {
      test(
        'phase order wins over the order things were registered in',
        () async {
          // Registering the three kinds interleaved is the realistic case — a
          // module registers whatever it owns as it initialises. Doing so must
          // not reorder the phases, and must not scramble the sequence within a
          // phase either. Both halves of that are in the one expectation below:
          // the two handlers still precede the two closables, and inside each
          // phase the entries keep the order they were registered in.
          final log = <String>[];
          final cleanup = _newCleanup();
          cleanup.addDisposable(NamedDisposable('disposable', log));
          cleanup.addSignalHandler((signal) => log.add('handler 1'));
          cleanup.addClosable(NamedClosable('closable 1', log));
          cleanup.addSignalHandler((signal) => log.add('handler 2'));
          cleanup.addClosable(NamedClosable('closable 2', log));

          await cleanup.performShutdown();

          expect(
            log,
            equals([
              'handler 1',
              'handler 2',
              'closable 1',
              'closable 2',
              'disposable',
            ]),
          );
        },
      );
    });

    // A handler, a close() and a dispose() may each return a Future, and the
    // phase awaits it before calling the next entry. Each test pairs the async
    // entry with something that can only hold if that await happened, so none
    // of them passes on a shutdown that merely called the entry.
    group('asynchronous entries', () {
      test('an async close has finished when the shutdown completes', () async {
        final asynchronous = AsyncClosable();
        final cleanup = _newCleanup();
        cleanup.addClosable(asynchronous);

        final shutdown = cleanup.performShutdown();
        // Called but not finished: the flush is a turn of the event loop away.
        expect(asynchronous.flushed, isFalse);

        await shutdown;
        expect(asynchronous.flushed, isTrue);
      });

      test('the next entry waits for an async one to finish', () async {
        final log = <String>[];
        final cleanup = _newCleanup();
        cleanup.addClosable(AsyncClosable(log));
        cleanup.addClosable(NamedClosable('sync closable', log));

        await cleanup.performShutdown();

        expect(log, equals(['async closable', 'sync closable']));
      });

      test('each phase finishes before the next one starts', () async {
        final log = <String>[];
        final cleanup = _newCleanup();
        cleanup.addSignalHandler((signal) async {
          await Future<void>.delayed(Duration.zero);
          log.add('async handler');
        });
        cleanup.addClosable(NamedClosable('closable', log));
        cleanup.addDisposable(AsyncDisposable(log));
        cleanup.addDisposable(NamedDisposable('last disposable', log));

        await cleanup.performShutdown();

        expect(
          log,
          equals([
            'async handler',
            'closable',
            'async disposable',
            'last disposable',
          ]),
        );
      });

      test('an async failure is reported like a synchronous one', () async {
        // The throw lands inside the returned future, after the call itself
        // has returned. Awaiting the future is what brings it under the
        // per-entry report. The synchronous thrower beside it is the control:
        // it proves the capture is wired, so the async one's report means
        // something.
        final lines = <String>[];
        final errors = <Object>[];
        final survivor = TestClosable();
        final cleanup = _newCleanup();
        cleanup.addClosable(ThrowingClosable());
        cleanup.addClosable(AsyncThrowingClosable());
        cleanup.addClosable(survivor);

        await runZonedGuarded(
          () => cleanup.performShutdown(),
          (error, stackTrace) => errors.add(error),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => lines.add(line),
          ),
        )!;

        expect(lines, hasLength(2));
        expect(lines[0], contains('Close failed'));
        expect(
          lines[1],
          allOf(
            contains('AsyncThrowingClosable'),
            contains('Async close failed'),
          ),
        );
        expect(
          errors,
          isEmpty,
          reason: 'nothing escapes as an unhandled error',
        );
        expect(survivor.closed, isTrue, reason: 'the phase went on after it');
      });

      test('an adaptor hands on the future of an async target', () async {
        final target = AsyncCloseTarget();
        final cleanup = _newCleanup();
        cleanup.addClosable(TomCloseAdaptor(target));

        await cleanup.performShutdown();

        expect(target.closed, isTrue);
      });
    });

    // The budget is per phase: a phase that overruns it is abandoned — the
    // entry it is waiting on and every entry behind it — and the shutdown goes
    // on with the next phase. The budgets are short so the suite stays fast;
    // the margins between them are wide so a loaded machine does not flip a
    // result.
    group('phase timeout', () {
      test('defaults to ten seconds', () {
        expect(
          TomShutdownCleanup.defaultPhaseTimeout,
          equals(const Duration(seconds: 10)),
        );
        expect(
          _newCleanup().phaseTimeout,
          equals(TomShutdownCleanup.defaultPhaseTimeout),
        );
      });

      test('a zero or negative timeout is refused', () {
        // A budget of nothing would abandon every async entry unseen, which
        // is the dropped-teardown behaviour this module exists to prevent.
        final cleanup = _newCleanup();
        expect(() => cleanup.phaseTimeout = Duration.zero, throwsArgumentError);
        expect(
          () => cleanup.phaseTimeout = const Duration(seconds: -1),
          throwsArgumentError,
        );
        expect(cleanup.phaseTimeout, TomShutdownCleanup.defaultPhaseTimeout);
      });

      test('a hanging entry abandons its phase, and only its phase', () async {
        final log = <String>[];
        final hanging = HangingClosable();
        final cleanup = _newCleanup()
          ..silent = true
          ..phaseTimeout = const Duration(milliseconds: 50);
        cleanup.addSignalHandler((signal) => log.add('handler'));
        cleanup.addClosable(hanging);
        cleanup.addClosable(NamedClosable('behind the hang', log));
        cleanup.addDisposable(NamedDisposable('disposable', log));

        await cleanup.performShutdown();

        expect(hanging.started, isTrue);
        expect(log, equals(['handler', 'disposable']));
      });

      test(
        'the abandonment names the phase, the entry and what it skipped',
        () async {
          final lines = <String>[];
          final cleanup = _newCleanup()
            ..phaseTimeout = const Duration(milliseconds: 50);
          cleanup.addClosable(HangingClosable());
          cleanup.addClosable(TestClosable());
          cleanup.addClosable(TestClosable());

          await _capturePrints(lines, cleanup.performShutdown);

          expect(lines, hasLength(1));
          expect(
            lines.single,
            allOf(
              contains('closable'),
              contains('50 ms'),
              contains('HangingClosable'),
              contains('2 entries'),
            ),
          );
        },
      );

      test('silent suppresses the abandonment report', () async {
        final lines = <String>[];
        final cleanup = _newCleanup()
          ..silent = true
          ..phaseTimeout = const Duration(milliseconds: 50);
        cleanup.addClosable(HangingClosable());

        await _capturePrints(lines, cleanup.performShutdown);

        expect(lines, isEmpty);
      });

      test('the budget covers the whole phase, not each entry', () async {
        // Each entry fits the budget alone; together they do not. A budget
        // per entry would let every registration add its own allowance, so
        // the phase could never be bounded.
        final log = <String>[];
        final cleanup = _newCleanup()
          ..silent = true
          ..phaseTimeout = const Duration(milliseconds: 1000);
        const each = Duration(milliseconds: 600);
        cleanup.addClosable(DelayedClosable('first', each, log));
        cleanup.addClosable(DelayedClosable('second', each, log));
        cleanup.addClosable(NamedClosable('third', log));

        await cleanup.performShutdown();

        expect(log, equals(['first']));
      });

      test('a synchronous overrun abandons the entries behind it', () async {
        // A synchronous entry cannot be interrupted, but the time it takes is
        // spent from the same budget.
        final log = <String>[];
        final cleanup = _newCleanup()
          ..silent = true
          ..phaseTimeout = const Duration(milliseconds: 50);
        cleanup.addClosable(BusyClosable(const Duration(milliseconds: 120)));
        cleanup.addClosable(NamedClosable('behind the overrun', log));
        cleanup.addDisposable(NamedDisposable('disposable', log));

        await cleanup.performShutdown();

        expect(log, equals(['disposable']));
      });

      test('an abandoned entry that fails later is still reported', () async {
        // The shutdown has moved on, but the process may well still be there
        // when the entry gives up — and a failure nobody hears of is the one
        // that cannot be diagnosed.
        final lines = <String>[];
        final errors = <Object>[];
        final cleanup = _newCleanup()
          ..phaseTimeout = const Duration(milliseconds: 50);
        cleanup.addClosable(
          LateFailingClosable(const Duration(milliseconds: 150)),
        );

        await runZonedGuarded(
          () async {
            await cleanup.performShutdown();
            await Future<void>.delayed(const Duration(milliseconds: 400));
          },
          (error, stackTrace) => errors.add(error),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => lines.add(line),
          ),
        )!;

        expect(lines, hasLength(2));
        expect(
          lines.last,
          allOf(contains('Late close failed'), contains('abandoned')),
        );
        expect(errors, isEmpty);
      });
    });
  });

  // ===========================================================================
  // Global Instance Tests
  // ===========================================================================

  // The global is shared by the whole process. Its registrations can be taken
  // back, but paused, silent and a spent shutdown cannot, and a test that
  // fails before unregistering leaves its entry behind for every test after
  // it. So its behaviour is not exercised here: the groups above already cover
  // it against instances that get torn down.
  //
  // What remains is what only the global can be asked — that it exists with
  // the right type, and that it ships in the state an application expects to
  // find it in. Both are reads.
  group('tomShutdownCleanup (global instance)', () {
    test('is a TomShutdownCleanup', () {
      expect(tomShutdownCleanup, isA<TomShutdownCleanup>());
    });

    test('ships ready to run: neither paused nor silent', () {
      // These two fields are public and mutable, and the global is the one
      // instance nobody constructs — so its defaults are whatever the field
      // initializers say. A global that shipped paused would skip the
      // signal-driven cleanup in every application that relies on it, and one
      // that shipped silent would skip it without saying so.
      expect(tomShutdownCleanup.paused, isFalse);
      expect(tomShutdownCleanup.silent, isFalse);
    });
  });

  // ===========================================================================
  // Type Definition Tests
  // ===========================================================================

  group('TomSignalHandler', () {
    test('should accept function with ProcessSignal parameter', () {
      // Arrange
      ProcessSignal? receivedSignal;
      void handler(ProcessSignal signal) {
        receivedSignal = signal;
      }

      // Act
      handler(ProcessSignal.sigint);

      // Assert
      expect(receivedSignal, equals(ProcessSignal.sigint));
    });

    test('should work with different signals', () {
      // Arrange
      final signals = <ProcessSignal>[];
      void handler(ProcessSignal signal) {
        signals.add(signal);
      }

      // Act
      handler(ProcessSignal.sigint);
      handler(ProcessSignal.sighup);
      handler(ProcessSignal.sigterm);

      // Assert
      expect(signals, hasLength(3));
      expect(signals[0], equals(ProcessSignal.sigint));
      expect(signals[1], equals(ProcessSignal.sighup));
      expect(signals[2], equals(ProcessSignal.sigterm));
    });

    test('should be usable as variable type', () {
      // Arrange
      void handler(ProcessSignal signal) {}

      // Assert
      expect(handler, isA<TomSignalHandler>());
    });
  });

  // ===========================================================================
  // Edge Cases Tests
  // ===========================================================================

  group('Edge Cases', () {
    group('empty state', () {
      test(
        'a shutdown with nothing registered is quiet, not a no-op',
        () async {
          // Nothing registered is the normal state of an instance that was
          // built and then never used, and every phase iterating an empty list
          // is what has to happen. What makes it worth an assertion is the
          // console: a shutdown with no work to report must report nothing, or
          // every application that never registers anything grows a line of
          // output it cannot explain.
          final lines = <String>[];
          final cleanup = _newCleanup();

          await _capturePrints(lines, cleanup.performShutdown);

          expect(lines, isEmpty);
        },
      );
    });

    group('multiple instances', () {
      test('should allow creating many independent instances', () {
        // Arrange & Act
        final instances = List.generate(10, (_) => _newCleanup());

        // Assert
        expect(instances, hasLength(10));
        for (var i = 0; i < instances.length - 1; i++) {
          expect(identical(instances[i], instances[i + 1]), isFalse);
        }
      });

      test('one instance shutting down does not run the other', () async {
        // The three registration lists are instance fields, and an
        // application that keeps a cleanup per subsystem relies on that:
        // tearing one subsystem down must leave the others running.
        final firstLog = <String>[];
        final secondLog = <String>[];
        final first = _newCleanup();
        final second = _newCleanup();
        first.addClosable(NamedClosable('first', firstLog));
        second.addClosable(NamedClosable('second', secondLog));

        await first.performShutdown();

        expect(firstLog, equals(['first']));
        expect(secondLog, isEmpty);

        // And the second is still able to run afterwards — the once-only
        // guard belongs to the instance that spent it, not to the class.
        await second.performShutdown();

        expect(secondLog, equals(['second']));
      });
    });
  });

  // ===========================================================================
  // Interface Polymorphism Tests
  // ===========================================================================

  group('Interface Polymorphism', () {
    test('should handle TomDisposable through interface reference', () async {
      // Arrange
      TomDisposable disposable = TestDisposable();

      // Act
      await disposable.dispose();

      // Assert
      expect((disposable as TestDisposable).disposed, isTrue);
    });

    test('should handle TomClosable through interface reference', () async {
      // Arrange
      TomClosable closable = TestClosable();

      // Act
      await closable.close();

      // Assert
      expect((closable as TestClosable).closed, isTrue);
    });

    test('should store interfaces in lists', () async {
      // Arrange
      final disposables = <TomDisposable>[
        TestDisposable(),
        TestDisposable(),
        TestDisposable(),
      ];

      // Act
      for (var d in disposables) {
        await d.dispose();
      }

      // Assert
      for (var d in disposables) {
        expect((d as TestDisposable).disposed, isTrue);
      }
    });

    test('should store closables in lists', () async {
      // Arrange
      final closables = <TomClosable>[
        TestClosable(),
        TestClosable(),
        TestClosable(),
      ];

      // Act
      for (var c in closables) {
        await c.close();
      }

      // Assert
      for (var c in closables) {
        expect((c as TestClosable).closed, isTrue);
      }
    });
  });

  // ===========================================================================
  // TomCloseAdaptor Tests — inherited close/dispose resolution
  // ===========================================================================

  group('TomCloseAdaptor', () {
    test('resolves a close() declared on the leaf type itself', () async {
      final target = OwnCloseTarget();
      final adaptor = TomCloseAdaptor(target);

      await adaptor.close();

      expect(target.closed, isTrue);
    });

    // `ClassMirror.declarations` holds only a type's own members, so
    // everything a leaf type inherits has to be found by walking upwards. The
    // four tests below are the four shapes that walk has to cope with.

    test('resolves a close() inherited from a superclass', () async {
      final target = InheritsClose();

      final adaptor = TomCloseAdaptor(target);
      await adaptor.close();

      expect(target.closed, isTrue);
    });

    test('resolves a dispose() inherited from a superclass', () async {
      final target = InheritsDispose();

      final adaptor = TomCloseAdaptor(target);
      await adaptor.close();

      expect(target.disposedFlag, isTrue);
    });

    test(
      'resolves a custom-named method inherited from a superclass',
      () async {
        final target = InheritsShutdown();

        final adaptor = TomCloseAdaptor(target, 'shutdown');
        await adaptor.close();

        expect(target.shutdownCalled, isTrue);
      },
    );

    // The walk follows `ClassMirror.superclass` and nothing else, so it only
    // reaches a mixin's members if the reflector models the mixin application
    // as a class in that chain. That is a property of the generator rather
    // than of this module, which is precisely why it is asserted here: the
    // dartdoc on `_resolveCloseMethod` promises mixin members are resolved,
    // and nothing but a live mixin can keep that promise honest.

    test('resolves a close() mixed in rather than inherited', () async {
      final target = MixesInClose();

      final adaptor = TomCloseAdaptor(target);
      await adaptor.close();

      expect(target.closed, isTrue);
    });

    test('resolves a dispose() mixed in rather than inherited', () async {
      final target = MixesInDispose();

      final adaptor = TomCloseAdaptor(target);
      await adaptor.close();

      expect(target.disposedFlag, isTrue);
    });

    // Both construction failures are one exception type with a key each, so a
    // caller matches on the key rather than on the prose, and each carries
    // what it is about as parameters rather than only inside the message.
    test('a method that needs a parameter is refused with its own key', () {
      expect(
        () => TomCloseAdaptor(CloseWithParam()),
        throwsA(
          isA<TomCloseAdaptorException>()
              .having(
                (e) => e.key,
                'key',
                'shutdown_cleanup.close_adaptor.method_requires_parameters',
              )
              .having((e) => e.parameters, 'parameters', {
                'type': 'CloseWithParam',
                'method': 'close',
                'parameterCount': 1,
              }),
        ),
      );
    });

    test('a required named parameter is refused like a positional one', () {
      expect(
        () => TomCloseAdaptor(RequiredNamedClose()),
        throwsA(
          isA<TomCloseAdaptorException>().having(
            (e) => e.key,
            'key',
            'shutdown_cleanup.close_adaptor.method_requires_parameters',
          ),
        ),
      );
    });

    test('a method whose parameters are all optional is accepted', () async {
      // The adaptor calls with no arguments, which an optional parameter —
      // positional or named — allows.
      final positional = OptionalPositionalClose();
      final named = OptionalNamedClose();

      await TomCloseAdaptor(positional).close();
      await TomCloseAdaptor(named).close();

      expect(positional.closed, isTrue);
      expect(named.closed, isTrue);
    });

    test('no close/dispose method anywhere in the chain has its own key', () {
      expect(
        () => TomCloseAdaptor(NoCloseTarget()),
        throwsA(
          isA<TomCloseAdaptorException>()
              .having(
                (e) => e.key,
                'key',
                'shutdown_cleanup.close_adaptor.no_close_method',
              )
              .having((e) => e.parameters, 'parameters', {
                'type': 'NoCloseTarget',
                'method': null,
              }),
        ),
      );
    });

    test('a named method that does not exist names what was asked for', () {
      expect(
        () => TomCloseAdaptor(OwnCloseTarget(), 'shutdown'),
        throwsA(
          isA<TomCloseAdaptorException>()
              .having(
                (e) => e.key,
                'key',
                'shutdown_cleanup.close_adaptor.no_close_method',
              )
              .having((e) => e.parameters, 'parameters', {
                'type': 'OwnCloseTarget',
                'method': 'shutdown',
              }),
        ),
      );
    });

    test('the construction failures are TomExceptions', () {
      // One base for all three failures, so a caller can catch the kernel's
      // exception type once — the reflector's included.
      for (final target in <Object>[
        CloseWithParam(),
        NoCloseTarget(),
        UnreflectedTarget(),
      ]) {
        expect(() => TomCloseAdaptor(target), throwsA(isA<TomException>()));
      }
    });

    // An unreflectable target is the adaptor's most likely failure, not an
    // exotic one: the class exists to wrap objects you do not own, and an
    // object you do not own cannot be given a `@tomReflector` annotation. The
    // three tests below pin that this failure obeys the same contract as the
    // other two rather than escaping as a bare Error from another package.

    test('throws an Exception, not an Error, for an unreflectable class', () {
      expect(
        () => TomCloseAdaptor(UnreflectedTarget()),
        throwsA(isA<Exception>()),
      );
    });

    test('the unreflectable-class failure names the type and the fix', () {
      expect(
        () => TomCloseAdaptor(UnreflectedTarget()),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('UnreflectedTarget'), contains('@tomReflector')),
          ),
        ),
      );
    });

    test('the unreflectable-class failure is a TomReflectorException', () {
      // Same type the rest of the package raises for this exact condition, so
      // a caller can catch one thing rather than one thing plus an Error. It
      // carries its own key, and the type as a parameter like the other two.
      expect(
        () => TomCloseAdaptor(UnreflectedTarget()),
        throwsA(
          isA<TomReflectorException>()
              .having(
                (e) => e.key,
                'key',
                'shutdown_cleanup.close_adaptor.not_reflectable',
              )
              .having((e) => e.parameters, 'parameters', {
                'type': 'UnreflectedTarget',
              }),
        ),
      );
    });

    // The adaptor is single-target by construction: the constructor binds an
    // instance mirror to the object it was given, and close() invokes through
    // that binding. `closableObject` is therefore `final` — reassigning it
    // used to compile, change nothing, and leave the field disagreeing with
    // the object close() would actually close. The compiler now owns that
    // guarantee, so what remains testable is the invariant itself: the field
    // and the invocation target are the same object.
    test(
      'closableObject names the object that close() actually closes',
      () async {
        final first = OwnCloseTarget();
        final second = OwnCloseTarget();
        final adaptor = TomCloseAdaptor(first);

        expect(adaptor.closableObject, same(first));

        await adaptor.close();

        expect(first.closed, isTrue);
        expect(second.closed, isFalse);
      },
    );

    test('two adaptors over two targets stay independent', () async {
      // The bound-once mirror is per-instance, not shared state on the class.
      final first = OwnCloseTarget();
      final second = OwnCloseTarget();
      final firstAdaptor = TomCloseAdaptor(first);
      final secondAdaptor = TomCloseAdaptor(second);

      await secondAdaptor.close();

      expect(second.closed, isTrue);
      expect(first.closed, isFalse);

      await firstAdaptor.close();

      expect(first.closed, isTrue);
    });
  });

  // ===========================================================================
  // performShutdown() & teardown behaviour
  // ===========================================================================

  group('performShutdown', () {
    group('exitAfterSignalShutdown', () {
      test('a signal-started shutdown exits once every phase ran', () async {
        final log = <String>[];
        final cleanup = _newCleanup()
          ..silent = true
          ..exitAfterSignalShutdown = true
          ..exitProcess = (code) => log.add('exit $code');
        cleanup.addClosable(RecordingClosable(log));
        cleanup.addDisposable(RecordingDisposable(log));

        await cleanup.performShutdown(fromSignal: true);
        await Future<void>.delayed(Duration.zero);

        expect(log, ['closable', 'disposable', 'exit 0']);
      });

      test('a called shutdown never exits', () async {
        final exits = <int>[];
        final cleanup = _newCleanup()
          ..exitAfterSignalShutdown = true
          ..exitProcess = exits.add;
        await cleanup.performShutdown();
        await Future<void>.delayed(Duration.zero);
        expect(exits, isEmpty);
      });

      test('is off by default', () async {
        final exits = <int>[];
        final cleanup = _newCleanup()
          ..silent = true
          ..exitProcess = exits.add;
        expect(cleanup.exitAfterSignalShutdown, isFalse);
        await cleanup.performShutdown(fromSignal: true);
        await Future<void>.delayed(Duration.zero);
        expect(exits, isEmpty);
      });
    });

    test('runs handlers, then closables, then disposables in order', () async {
      final log = <String>[];
      final cleanup = _newCleanup();
      cleanup.addDisposable(RecordingDisposable(log));
      cleanup.addSignalHandler((signal) => log.add('handler'));
      cleanup.addClosable(RecordingClosable(log));

      await cleanup.performShutdown();

      expect(log, equals(['handler', 'closable', 'disposable']));
    });

    // An instance is single-use: one shutdown, then it is spent. These pin the
    // three halves of that — what hasShutDown reports and when, that nothing
    // can run a second shutdown, and that registering on a spent instance
    // keeps the entry without ever running it.
    group('lifecycle', () {
      test('hasShutDown is false until the shutdown has finished', () async {
        final cleanup = _newCleanup();
        cleanup.addClosable(AsyncClosable());
        expect(cleanup.hasShutDown, isFalse);

        final shutdown = cleanup.performShutdown();
        // Started but not finished: the async close is still to come.
        expect(cleanup.hasShutDown, isFalse);

        await shutdown;
        expect(cleanup.hasShutDown, isTrue);
      });

      test('a paused signal does not count as a shutdown', () async {
        final cleanup = _newCleanup()
          ..paused = true
          ..silent = true;

        await cleanup.performShutdown(fromSignal: true);

        expect(cleanup.hasShutDown, isFalse);
      });

      test('an abandoned phase still ends the shutdown', () async {
        final cleanup = _newCleanup()
          ..silent = true
          ..phaseTimeout = const Duration(milliseconds: 50);
        cleanup.addClosable(HangingClosable());

        await cleanup.performShutdown();

        expect(cleanup.hasShutDown, isTrue);
      });

      test('hasShutDown survives dispose, and never turns back', () async {
        final cleanup = _newCleanup();
        await cleanup.performShutdown();
        await cleanup.dispose();
        await cleanup.performShutdown();

        expect(cleanup.hasShutDown, isTrue);
      });

      test('an entry registered after the shutdown never runs', () async {
        // Kept rather than refused: a registration racing a shutdown is
        // ordinary at process exit, and throwing there would fail code that
        // did nothing wrong. It is simply too late to run.
        final cleanup = _newCleanup();
        await cleanup.performShutdown();

        final late = TestClosable();
        final lateDisposable = TestDisposable();
        var lateHandlerRan = false;
        cleanup
          ..addClosable(late)
          ..addDisposable(lateDisposable)
          ..addSignalHandler((signal) => lateHandlerRan = true);
        await cleanup.performShutdown();
        await cleanup.performShutdown(fromSignal: true);

        expect(late.closed, isFalse);
        expect(lateDisposable.disposed, isFalse);
        expect(lateHandlerRan, isFalse);
      });

      test('a restart builds a new instance, which runs its own', () async {
        // The documented way to shut a subsystem down twice.
        final firstRun = TestClosable();
        final first = _newCleanup()..addClosable(firstRun);
        await first.performShutdown();
        await first.dispose();

        final secondRun = TestClosable();
        final second = _newCleanup()..addClosable(secondRun);
        await second.performShutdown();

        expect(firstRun.closeCount, 1);
        expect(secondRun.closeCount, 1);
        expect(second.hasShutDown, isTrue);
      });
    });

    test('executes only once across repeated calls', () async {
      final cleanup = _newCleanup();
      final closable = TestClosable();
      final disposable = TestDisposable();
      cleanup.addClosable(closable);
      cleanup.addDisposable(disposable);

      await cleanup.performShutdown();
      await cleanup.performShutdown();
      await cleanup.performShutdown();

      expect(closable.closeCount, equals(1));
      expect(disposable.disposeCount, equals(1));
    });

    test('a call during a running shutdown joins it', () async {
      // The second caller gets the shutdown already under way rather than a
      // completed no-op, so awaiting it means what it says: the entries have
      // finished, whichever caller started them.
      final asynchronous = AsyncClosable();
      final cleanup = _newCleanup();
      cleanup.addClosable(asynchronous);

      final first = cleanup.performShutdown();
      final second = cleanup.performShutdown();

      expect(identical(first, second), isTrue);
      await second;
      expect(asynchronous.flushed, isTrue);
    });

    test('isolates failures so later cleanups still run', () async {
      final log = <String>[];
      final cleanup = _newCleanup();
      // A throwing handler and a throwing closable must not prevent the
      // remaining closable/disposable from running.
      cleanup.addSignalHandler((signal) => throw Exception('handler boom'));
      cleanup.addClosable(ThrowingClosable());
      cleanup.addClosable(RecordingClosable(log));
      cleanup.addDisposable(RecordingDisposable(log));

      // silent: suppress the "Failed to call …" diagnostics during the test.
      cleanup.silent = true;
      await cleanup.performShutdown();

      expect(log, equals(['closable', 'disposable']));
    });

    // Isolating a failure is only half of fault tolerance; the other half is
    // saying what failed. A shutdown happens once, usually unattended, and
    // cannot be reproduced by re-running it, so whatever the diagnostic omits
    // is lost for good.

    test('the failure diagnostic names the exception', () async {
      final lines = <String>[];
      final cleanup = _newCleanup();
      cleanup.addClosable(ThrowingClosable());

      await _capturePrints(lines, cleanup.performShutdown);

      // ThrowingClosable throws Exception('Close failed').
      expect(lines.join('\n'), contains('Close failed'));
    });

    test('the failure diagnostic names the phase and the entry', () async {
      final lines = <String>[];
      final cleanup = _newCleanup();
      cleanup.addDisposable(ThrowingDisposable());

      await _capturePrints(lines, cleanup.performShutdown);

      final diagnostic = lines.join('\n');
      expect(diagnostic, contains('disposable'));
      expect(diagnostic, contains('ThrowingDisposable'));
    });

    test('the failure diagnostic carries a stack trace', () async {
      final lines = <String>[];
      final cleanup = _newCleanup();
      cleanup.addClosable(ThrowingClosable());

      await _capturePrints(lines, cleanup.performShutdown);

      // The frame that actually threw has to be in there, or the trace is
      // decoration rather than evidence.
      expect(lines.join('\n'), contains('ThrowingClosable.close'));
    });

    test('silent suppresses the failure diagnostic too', () async {
      final lines = <String>[];
      final cleanup = _newCleanup();
      cleanup.addClosable(ThrowingClosable());
      cleanup.silent = true;

      await _capturePrints(lines, cleanup.performShutdown);

      expect(lines, isEmpty);
    });

    test('a manual call that does real work still prints no status', () async {
      // The quiet-when-empty case is covered under `empty state`; this is the
      // one that could regress independently, because a status message gated
      // on the wrong condition would show up only once there was work to
      // announce. Non-silent on purpose: `silent` must not be what is keeping
      // this quiet.
      final lines = <String>[];
      final cleanup = _newCleanup();
      cleanup.addClosable(TestClosable());
      cleanup.addDisposable(RecordingDisposable(<String>[]));

      await _capturePrints(lines, cleanup.performShutdown);

      expect(lines, isEmpty);
    });

    test(
      'manual call ignores paused (only the signal path honours it)',
      () async {
        final cleanup = _newCleanup();
        final closable = TestClosable();
        cleanup.addClosable(closable);
        cleanup.paused = true;

        // The manual path (fromSignal: false) always runs regardless of paused.
        await cleanup.performShutdown();

        expect(closable.closed, isTrue);
      },
    );

    group('signal-driven path (fromSignal)', () {
      test('skips cleanup entirely while paused', () async {
        final cleanup = _newCleanup();
        final closable = TestClosable();
        cleanup.addClosable(closable);
        cleanup.paused = true;

        await cleanup.performShutdown(fromSignal: true);

        expect(closable.closed, isFalse);
      });

      test('runs cleanup when not paused', () async {
        final cleanup = _newCleanup();
        final closable = TestClosable();
        cleanup.addClosable(closable);
        cleanup.silent = true;

        await cleanup.performShutdown(fromSignal: true);

        expect(closable.closed, isTrue);
      });

      test('silent suppresses the status messages', () async {
        final lines = <String>[];
        final cleanup = _newCleanup();
        cleanup.addClosable(TestClosable());
        cleanup.silent = true;

        await _capturePrints(
          lines,
          () => cleanup.performShutdown(fromSignal: true),
        );

        expect(lines, isEmpty);
      });

      test('a signal during a running shutdown says so', () async {
        final lines = <String>[];
        final cleanup = _newCleanup();
        cleanup.addClosable(AsyncClosable());

        await _capturePrints(lines, () async {
          final running = cleanup.performShutdown();
          await cleanup.performShutdown(fromSignal: true);
          await running;
          await cleanup.performShutdown(fromSignal: true);
        });

        expect(
          lines,
          equals([
            'Received SIGINT',
            'Shutdown is already in progress',
            'Received SIGINT',
            'Shutdown has already been performed',
          ]),
        );
      });

      test(
        'reports the shutdown performed once the entries have finished',
        () async {
          // One list takes both the entry's record and the printed status, so
          // their order is the assertion.
          final lines = <String>[];
          final cleanup = _newCleanup();
          cleanup.addClosable(AsyncClosable(lines));

          await _capturePrints(
            lines,
            () => cleanup.performShutdown(fromSignal: true),
          );

          expect(
            lines,
            equals(['Received SIGINT', 'async closable', 'Shutdown performed']),
          );
        },
      );

      test(
        'non-silent emits the received + performed status messages',
        () async {
          final lines = <String>[];
          final cleanup = _newCleanup();
          cleanup.addClosable(TestClosable());

          await _capturePrints(
            lines,
            () => cleanup.performShutdown(fromSignal: true),
          );

          expect(lines, contains('Received SIGINT'));
          expect(lines, contains('Shutdown performed'));
        },
      );
    });
  });

  // Every line the module writes — status, failure reports, phase-timeout
  // reports — goes through one sink, `output`, which defaults to `print` and
  // is silenced as a whole by `silent`.
  group('output', () {
    test('defaults to print', () async {
      final lines = <String>[];
      final cleanup = _newCleanup();
      cleanup.addClosable(ThrowingClosable());

      await _capturePrints(lines, cleanup.performShutdown);

      expect(lines.single, contains('Close failed'));
    });

    test(
      'every kind of line goes to the supplied sink, none to print',
      () async {
        final written = <String>[];
        final printed = <String>[];
        final cleanup = _newCleanup()
          ..output = written.add
          ..phaseTimeout = const Duration(milliseconds: 50);
        cleanup.addClosable(ThrowingClosable());
        cleanup.addClosable(HangingClosable());

        await _capturePrints(printed, () async {
          await cleanup.performShutdown(fromSignal: true);
          await cleanup.performShutdown(fromSignal: true);
        });

        expect(printed, isEmpty);
        expect(written, hasLength(6));
        expect(written[0], 'Received SIGINT');
        expect(written[1], contains('Close failed'));
        expect(written[2], startsWith('Abandoned the closable phase'));
        expect(written[3], 'Shutdown performed');
        expect(written[4], 'Received SIGINT');
        expect(written[5], 'Shutdown has already been performed');
      },
    );

    test('silent silences the supplied sink too', () async {
      final written = <String>[];
      final cleanup = _newCleanup()
        ..output = written.add
        ..silent = true;
      cleanup.addClosable(ThrowingClosable());

      await cleanup.performShutdown(fromSignal: true);

      expect(written, isEmpty);
    });

    test('a sink that fails does not fail the shutdown', () async {
      // A host that routes the lines into its logging system may find that
      // system already torn down. The line then goes to print, with the
      // reason, and the shutdown carries on.
      final printed = <String>[];
      final survivor = TestClosable();
      final cleanup = _newCleanup()
        ..output = (line) => throw StateError('log closed');
      cleanup.addClosable(ThrowingClosable());
      cleanup.addClosable(survivor);

      await _capturePrints(printed, cleanup.performShutdown);

      expect(printed, hasLength(1));
      expect(
        printed.single,
        allOf(contains('Close failed'), contains('log closed')),
      );
      expect(survivor.closed, isTrue);
      expect(cleanup.hasShutDown, isTrue);
    });
  });

  // Each add* returns the way to take that registration back. A released
  // resource would otherwise stay reachable — and be closed again at exit —
  // for the coordinator's whole life, which for the global is the process's.
  group('unregistering', () {
    test('an unregistered entry of each kind is not run', () async {
      final cleanup = _newCleanup();
      var handlerRan = false;
      final closable = TestClosable();
      final disposable = TestDisposable();
      final unregisterHandler = cleanup.addSignalHandler(
        (signal) => handlerRan = true,
      );
      final unregisterClosable = cleanup.addClosable(closable);
      final unregisterDisposable = cleanup.addDisposable(disposable);

      unregisterHandler();
      unregisterClosable();
      unregisterDisposable();
      await cleanup.performShutdown();

      expect(handlerRan, isFalse);
      expect(closable.closed, isFalse);
      expect(disposable.disposed, isFalse);
    });

    test('only the registration it was returned for is removed', () async {
      // Registering the same object twice makes two registrations, and each
      // canceller takes back its own — so the object is still closed once.
      final cleanup = _newCleanup();
      final closable = TestClosable();
      final first = cleanup.addClosable(closable);
      cleanup.addClosable(closable);
      final other = TestClosable();
      cleanup.addClosable(other);

      first();
      await cleanup.performShutdown();

      expect(closable.closeCount, 1);
      expect(other.closed, isTrue);
    });

    test('unregistering twice, or after the shutdown, is harmless', () async {
      final cleanup = _newCleanup();
      final unregister = cleanup.addClosable(TestClosable());

      unregister();
      unregister();
      await cleanup.performShutdown();

      expect(unregister, returnsNormally);
    });

    test('an entry unregistered during the shutdown is not reached', () async {
      // A handler that releases a resource of its own — closing it in the
      // handler and taking it off the list so the closables phase does not
      // close it again.
      final log = <String>[];
      final cleanup = _newCleanup();
      late final TomShutdownUnregister unregisterSecond;
      cleanup.addClosable(NamedClosable('first', log));
      cleanup.addClosable(
        _CallbackClosable(() {
          log.add('releasing');
          unregisterSecond();
        }),
      );
      unregisterSecond = cleanup.addClosable(NamedClosable('second', log));
      cleanup.addClosable(NamedClosable('third', log));

      await cleanup.performShutdown();

      expect(log, equals(['first', 'releasing', 'third']));
    });

    test('an entry that unregisters itself does not cost the next', () async {
      // The common shape: a close() that takes its own registration back, as
      // it would when the same code also runs outside a shutdown. Removing an
      // entry the phase has already reached must not shift it past the next.
      final log = <String>[];
      final cleanup = _newCleanup();
      late final TomShutdownUnregister unregisterSelf;
      unregisterSelf = cleanup.addClosable(
        _CallbackClosable(() {
          log.add('self');
          unregisterSelf();
        }),
      );
      cleanup.addClosable(NamedClosable('next', log));

      await cleanup.performShutdown();

      expect(log, equals(['self', 'next']));
    });

    test('an entry registered during its own phase still runs', () async {
      final log = <String>[];
      final cleanup = _newCleanup();
      cleanup.addClosable(
        _CallbackClosable(() {
          log.add('registering');
          cleanup.addClosable(NamedClosable('registered late', log));
        }),
      );

      await cleanup.performShutdown();

      expect(log, equals(['registering', 'registered late']));
    });
  });

  // A coordinator is itself a TomDisposable, so one can be registered on
  // another — a hosted runtime tearing down the coordinator it keeps per
  // session. Disposing releases the inner one; running its shutdown is a
  // separate registration, which the last test shows.
  group('nesting coordinators', () {
    test('a coordinator can be registered as a disposable', () {
      final inner = _newCleanup();
      final outer = _newCleanup();

      expect(inner, isA<TomDisposable>());
      expect(() => outer.addDisposable(inner), returnsNormally);
    });

    test('the outer shutdown cancels the inner watchers', () async {
      final inner = _sendableCleanup();
      var innerReacted = false;
      inner.addSignalHandler((signal) => innerReacted = true);
      inner.addSignal(ProcessSignal.sigusr1);
      final outer = _newCleanup()..addDisposable(inner);

      await outer.performShutdown();
      await _sendAndSettle(ProcessSignal.sigusr1);

      expect(innerReacted, isFalse);
    }, skip: _signalSendingSkipReason);

    test('disposing the inner coordinator does not run it', () async {
      // The trap this pins: registering a coordinator as a disposable
      // releases it, and its entries with it, without closing them.
      final innerResource = TestClosable();
      final inner = _newCleanup()..addClosable(innerResource);
      final outer = _newCleanup()..addDisposable(inner);

      await outer.performShutdown();
      await inner.performShutdown();

      expect(innerResource.closed, isFalse);
      expect(inner.hasShutDown, isTrue);
    });

    test(
      'running the inner shutdown from a handler, then disposing it',
      () async {
        // The composing shape: the handlers phase runs the inner shutdown and
        // is awaited, the closables phase closes the outer's own resources, and
        // the disposables phase releases the inner coordinator.
        final log = <String>[];
        final inner = _newCleanup()..addClosable(NamedClosable('inner', log));
        final outer = _newCleanup()
          ..addSignalHandler((signal) => inner.performShutdown(signal: signal))
          ..addClosable(NamedClosable('outer', log))
          ..addDisposable(inner)
          ..addDisposable(NamedDisposable('outer disposable', log));

        await outer.performShutdown();

        expect(log, equals(['inner', 'outer', 'outer disposable']));
        expect(inner.hasShutDown, isTrue);
      },
    );
  });

  group('dispose / cancelAll', () {
    test('dispose stops the instance reacting to its signals', () async {
      // The subscription list is private, so "cancelled" is only observable
      // the same way "registered" is: by sending the signal and seeing what
      // does not happen.
      final cleanup = _sendableCleanup();
      var ran = false;
      cleanup.addSignalHandler((signal) => ran = true);
      cleanup.addSignal(ProcessSignal.sigusr1);

      await cleanup.dispose();
      await _sendAndSettle(ProcessSignal.sigusr1);

      expect(ran, isFalse);
    }, skip: _signalSendingSkipReason);

    test('dispose releases the registrations, so nothing is run', () async {
      // Teardown releases everything the instance holds — the watchers and
      // every registered entry — so a manual shutdown afterwards has nothing
      // to close, and nothing registered before the dispose stays reachable.
      final cleanup = _newCleanup();
      var handlerRan = false;
      final closable = TestClosable();
      final disposable = TestDisposable();
      cleanup
        ..addSignalHandler((signal) => handlerRan = true)
        ..addClosable(closable)
        ..addDisposable(disposable);

      await cleanup.dispose();
      await cleanup.performShutdown();

      expect(handlerRan, isFalse);
      expect(closable.closed, isFalse);
      expect(disposable.disposed, isFalse);
    });

    test('cancelAll releases the registrations too', () async {
      final cleanup = _newCleanup();
      final closable = TestClosable();
      cleanup.addClosable(closable);

      await cleanup.cancelAll();
      await cleanup.performShutdown();

      expect(closable.closed, isFalse);
    });

    test('a registration made after dispose is held again', () async {
      // Dispose empties the instance; it does not spend it. What is
      // registered afterwards is held, and a manual shutdown runs it.
      final cleanup = _newCleanup();
      await cleanup.dispose();
      final closable = TestClosable();
      cleanup.addClosable(closable);

      await cleanup.performShutdown();

      expect(closable.closed, isTrue);
    });

    test('cancelAll is safe to call repeatedly', () async {
      // Cancelling an already-cancelled subscription is the failure this
      // guards, and it would surface as a throw rather than as a wrong value
      // — so completing without one is the whole assertion. Every test in
      // this file relies on it: _newCleanup registers dispose as a teardown,
      // which runs even for the tests that already disposed deliberately.
      final cleanup = _newCleanup();
      cleanup.addSignal(ProcessSignal.sigterm);

      await cleanup.cancelAll();
      await expectLater(cleanup.cancelAll(), completes);
    });
  });
}

/// Runs the asynchronous [body] while collecting every `print` line into
/// [sink], completing once [body] has.
///
/// Output arrives on later turns of the event loop — from an awaited entry, a
/// phase timer, or a signal listener — so the registration, the shutdown and
/// everything it prints all have to happen inside the capturing zone.
Future<void> _capturePrints(List<String> sink, Future<void> Function() body) {
  return runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => sink.add(line),
    ),
  );
}

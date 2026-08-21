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

/// Closable whose teardown is asynchronous.
///
/// `Future<void> close()` is a legal override of `void close()` — in return
/// position every type is a subtype of `void` — which is why this mistake
/// compiles and why no analyzer flags it.
class AsyncClosable implements TomClosable {
  bool flushed = false;

  @override
  Future<void> close() async {
    await Future<void>.delayed(Duration.zero);
    flushed = true;
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

// =============================================================================
// Reflected targets for TomCloseAdaptor (own + inherited members)
// =============================================================================

/// Target whose `close()` is declared on the leaf type itself.
@tomReflector
class OwnCloseTarget {
  bool closed = false;
  void close() => closed = true;
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
      test('the registered disposable is disposed', () {
        final cleanup = _newCleanup();
        final disposable = TestDisposable();
        cleanup.addDisposable(disposable);

        cleanup.performShutdown();

        expect(disposable.disposed, isTrue);
      });

      test('several disposables run in registration order', () {
        final log = <String>[];
        final cleanup = _newCleanup();
        cleanup.addDisposable(NamedDisposable('first', log));
        cleanup.addDisposable(NamedDisposable('second', log));
        cleanup.addDisposable(NamedDisposable('third', log));

        cleanup.performShutdown();

        expect(log, equals(['first', 'second', 'third']));
      });

      test('the same disposable registered twice is disposed twice', () {
        // Registration appends; it does not deduplicate. So the caller owns
        // the arithmetic: a disposable that cannot survive being disposed
        // twice must be registered once.
        final cleanup = _newCleanup();
        final disposable = TestDisposable();
        cleanup.addDisposable(disposable);
        cleanup.addDisposable(disposable);

        cleanup.performShutdown();

        expect(disposable.disposeCount, equals(2));
      });
    });

    group('addClosable', () {
      test('the registered closable is closed', () {
        final cleanup = _newCleanup();
        final closable = TestClosable();
        cleanup.addClosable(closable);

        cleanup.performShutdown();

        expect(closable.closed, isTrue);
      });

      test('several closables run in registration order', () {
        final log = <String>[];
        final cleanup = _newCleanup();
        cleanup.addClosable(NamedClosable('first', log));
        cleanup.addClosable(NamedClosable('second', log));
        cleanup.addClosable(NamedClosable('third', log));

        cleanup.performShutdown();

        expect(log, equals(['first', 'second', 'third']));
      });

      test('the same closable registered twice is closed twice', () {
        final cleanup = _newCleanup();
        final closable = TestClosable();
        cleanup.addClosable(closable);
        cleanup.addClosable(closable);

        cleanup.performShutdown();

        expect(closable.closeCount, equals(2));
      });
    });

    group('addSignalHandler', () {
      test('the handler runs and receives the signal', () {
        // The signal is the one thing a handler gets that a closable and a
        // disposable do not, so a handler that runs but is handed the wrong
        // signal is still broken.
        final cleanup = _newCleanup();
        final received = <ProcessSignal>[];
        cleanup.addSignalHandler(received.add);

        cleanup.performShutdown(signal: ProcessSignal.sigterm);

        expect(received, equals([ProcessSignal.sigterm]));
      });

      test('several handlers run in registration order', () {
        final log = <String>[];
        final cleanup = _newCleanup();
        cleanup.addSignalHandler((signal) => log.add('first'));
        cleanup.addSignalHandler((signal) => log.add('second'));
        cleanup.addSignalHandler((signal) => log.add('third'));

        cleanup.performShutdown();

        expect(log, equals(['first', 'second', 'third']));
      });

      test('a handler that does nothing does not stop the ones behind it', () {
        final log = <String>[];
        final cleanup = _newCleanup();
        cleanup.addSignalHandler((signal) {});
        cleanup.addSignalHandler((signal) => log.add('reached'));

        cleanup.performShutdown();

        expect(log, equals(['reached']));
      });
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
        // `_executed` sees to that — but it does drive the handler twice, so
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
        await _capturePrintsAsync(lines, () async {
          final cleanup = _newCleanup();
          cleanup.addSignal(ProcessSignal.sigusr1);
          cleanup.addSignal(ProcessSignal.sigusr1);

          await _sendAndSettle(ProcessSignal.sigusr1);
        });

        expect(lines, equals(['Received SIGUSR1', 'Shutdown performed']));
      });
    }, skip: _signalSendingSkipReason);

    group('start', () {
      // The contract the two tests below pin: start() is a log breadcrumb,
      // not an arming step. The constructor registers the SIGHUP/SIGINT
      // listeners, so cleanup must behave identically whether start() is
      // never called, called before registration, or called after it. Leaving
      // this untested is what let four documentation sites drift into calling
      // start() a setup step and prescribing where in the sequence to put it.

      /// Registers one cleanup of each kind on [cleanup], recording the
      /// category it belongs to into [log] when it runs.
      void registerRecorders(TomShutdownCleanup cleanup, List<String> log) {
        cleanup.addSignalHandler((signal) => log.add('handler'));
        cleanup.addClosable(RecordingClosable(log));
        cleanup.addDisposable(RecordingDisposable(log));
      }

      const expectedOrder = ['handler', 'closable', 'disposable'];

      test('is not required for cleanup to run', () {
        // Arrange
        final log = <String>[];
        final cleanup = _newCleanup();
        registerRecorders(cleanup, log);

        // Act - start() is never called anywhere in this test.
        cleanup.performShutdown();

        // Assert
        expect(log, equals(expectedOrder));
      });

      test('changes nothing wherever it is called in the sequence', () {
        // Arrange & Act - started before any registration.
        final beforeLog = <String>[];
        final before = _newCleanup()..start();
        registerRecorders(before, beforeLog);
        before.performShutdown();

        // Arrange & Act - started after every registration.
        final afterLog = <String>[];
        final after = _newCleanup();
        registerRecorders(after, afterLog);
        after.start();
        after.performShutdown();

        // Assert - both match the no-start() outcome above.
        expect(beforeLog, equals(expectedOrder));
        expect(afterLog, equals(expectedOrder));
      });
    });

    group('mixed handlers', () {
      test('phase order wins over the order things were registered in', () {
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

        cleanup.performShutdown();

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
      });
    });

    // Both interfaces and the handler typedef return `void`, and the phase
    // calls them through a `void Function(T)`. Dart accepts an `async` body
    // there, so the mistake compiles; these two tests pin what it then does.
    // They are the executable form of the claims the module doc and the module
    // readme now make, so if teardown ever becomes awaited both should fail —
    // and both documents have to change with them.
    group('asynchronous entries', () {
      test('a Future returned from close() is not awaited', () async {
        // The synchronous closable is the control. Both are registered on one
        // instance and closed in the same phase, so its flag proves the phase
        // ran — without it, `flushed` being false would be equally consistent
        // with a shutdown that closed nothing at all.
        final synchronous = TestClosable();
        final asynchronous = AsyncClosable();
        final cleanup = _newCleanup();
        cleanup.addClosable(synchronous);
        cleanup.addClosable(asynchronous);

        cleanup.performShutdown();

        expect(synchronous.closed, isTrue);
        expect(
          asynchronous.flushed,
          isFalse,
          reason: 'the phase moved on before the async close resumed',
        );

        // Unawaited is not the same as unrun. The work does finish — one turn
        // of the event loop later, which in a real shutdown is a turn the
        // process may not still be there for.
        await Future<void>.delayed(Duration.zero);
        expect(asynchronous.flushed, isTrue);
      });

      test('a Future that fails escapes the per-entry report', () async {
        // The per-entry try/catch wraps the call, and an async body's throw
        // happens after the call has already returned. So the failure misses
        // the `Failed to call closable ...` diagnostic entirely and surfaces
        // as an unhandled asynchronous error, with nothing left to name the
        // phase or the entry that produced it.
        //
        // The synchronous thrower alongside it is the control: it fails in the
        // same phase of the same shutdown and *is* reported, which is what
        // makes the async one's absence from the report mean something rather
        // than showing only that the capture was not wired up.
        final lines = <String>[];
        final errors = <Object>[];
        final cleanup = _newCleanup();
        cleanup.addClosable(ThrowingClosable());
        cleanup.addClosable(AsyncThrowingClosable());

        await runZonedGuarded(
          () async {
            cleanup.performShutdown();
            await Future<void>.delayed(Duration.zero);
            await Future<void>.delayed(Duration.zero);
          },
          (error, stackTrace) => errors.add(error),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) => lines.add(line),
          ),
        )!;

        expect(lines, hasLength(1), reason: 'only the sync failure reported');
        expect(lines.single, contains('Close failed'));
        expect(lines.single, isNot(contains('Async close failed')));

        expect(errors, hasLength(1));
        expect(errors.single.toString(), contains('Async close failed'));
      });
    });
  });

  // ===========================================================================
  // Global Instance Tests
  // ===========================================================================

  // The global is shared by the whole process and offers no unregister path,
  // so anything registered on it here would still be registered when the last
  // test in this file runs. That rules out exercising its behaviour: the tests
  // would pay a permanent cost for coverage the groups above already provide
  // against instances that get torn down.
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
      test('a shutdown with nothing registered is quiet, not a no-op', () {
        // Nothing registered is the normal state of an instance that was
        // built and then never used, and every phase iterating an empty list
        // is what has to happen. What makes it worth an assertion is the
        // console: a shutdown with no work to report must report nothing, or
        // every application that never registers anything grows a line of
        // output it cannot explain.
        final lines = <String>[];
        final cleanup = _newCleanup();

        _capturePrints(lines, cleanup.performShutdown);

        expect(lines, isEmpty);
      });
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

      test('one instance shutting down does not run the other', () {
        // The three registration lists are instance fields, and an
        // application that keeps a cleanup per subsystem relies on that:
        // tearing one subsystem down must leave the others running.
        final firstLog = <String>[];
        final secondLog = <String>[];
        final first = _newCleanup();
        final second = _newCleanup();
        first.addClosable(NamedClosable('first', firstLog));
        second.addClosable(NamedClosable('second', secondLog));

        first.performShutdown();

        expect(firstLog, equals(['first']));
        expect(secondLog, isEmpty);

        // And the second is still able to run afterwards — the once-only
        // guard belongs to the instance that spent it, not to the class.
        second.performShutdown();

        expect(secondLog, equals(['second']));
      });
    });
  });

  // ===========================================================================
  // Interface Polymorphism Tests
  // ===========================================================================

  group('Interface Polymorphism', () {
    test('should handle TomDisposable through interface reference', () {
      // Arrange
      TomDisposable disposable = TestDisposable();

      // Act
      disposable.dispose();

      // Assert
      expect((disposable as TestDisposable).disposed, isTrue);
    });

    test('should handle TomClosable through interface reference', () {
      // Arrange
      TomClosable closable = TestClosable();

      // Act
      closable.close();

      // Assert
      expect((closable as TestClosable).closed, isTrue);
    });

    test('should store interfaces in lists', () {
      // Arrange
      final disposables = <TomDisposable>[
        TestDisposable(),
        TestDisposable(),
        TestDisposable(),
      ];

      // Act
      for (var d in disposables) {
        d.dispose();
      }

      // Assert
      for (var d in disposables) {
        expect((d as TestDisposable).disposed, isTrue);
      }
    });

    test('should store closables in lists', () {
      // Arrange
      final closables = <TomClosable>[
        TestClosable(),
        TestClosable(),
        TestClosable(),
      ];

      // Act
      for (var c in closables) {
        c.close();
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
    test('resolves a close() declared on the leaf type itself', () {
      final target = OwnCloseTarget();
      final adaptor = TomCloseAdaptor(target);

      adaptor.close();

      expect(target.closed, isTrue);
    });

    // `ClassMirror.declarations` holds only a type's own members, so
    // everything a leaf type inherits has to be found by walking upwards. The
    // four tests below are the four shapes that walk has to cope with.

    test('resolves a close() inherited from a superclass', () {
      final target = InheritsClose();

      final adaptor = TomCloseAdaptor(target);
      adaptor.close();

      expect(target.closed, isTrue);
    });

    test('resolves a dispose() inherited from a superclass', () {
      final target = InheritsDispose();

      final adaptor = TomCloseAdaptor(target);
      adaptor.close();

      expect(target.disposedFlag, isTrue);
    });

    test('resolves a custom-named method inherited from a superclass', () {
      final target = InheritsShutdown();

      final adaptor = TomCloseAdaptor(target, 'shutdown');
      adaptor.close();

      expect(target.shutdownCalled, isTrue);
    });

    // The walk follows `ClassMirror.superclass` and nothing else, so it only
    // reaches a mixin's members if the reflector models the mixin application
    // as a class in that chain. That is a property of the generator rather
    // than of this module, which is precisely why it is asserted here: the
    // dartdoc on `_resolveCloseMethod` promises mixin members are resolved,
    // and nothing but a live mixin can keep that promise honest.

    test('resolves a close() mixed in rather than inherited', () {
      final target = MixesInClose();

      final adaptor = TomCloseAdaptor(target);
      adaptor.close();

      expect(target.closed, isTrue);
    });

    test('resolves a dispose() mixed in rather than inherited', () {
      final target = MixesInDispose();

      final adaptor = TomCloseAdaptor(target);
      adaptor.close();

      expect(target.disposedFlag, isTrue);
    });

    test('throws when the resolved method requires a parameter', () {
      expect(
        () => TomCloseAdaptor(CloseWithParam()),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('needs parameter'),
          ),
        ),
      );
    });

    test(
      'throws when no close/dispose method exists anywhere in the chain',
      () {
        expect(
          () => TomCloseAdaptor(NoCloseTarget()),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains("didn't find a close method"),
            ),
          ),
        );
      },
    );

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
      // a caller can catch one thing rather than one thing plus an Error.
      expect(
        () => TomCloseAdaptor(UnreflectedTarget()),
        throwsA(isA<TomReflectorException>()),
      );
    });

    // The adaptor is single-target by construction: the constructor binds an
    // instance mirror to the object it was given, and close() invokes through
    // that binding. `closableObject` is therefore `final` — reassigning it
    // used to compile, change nothing, and leave the field disagreeing with
    // the object close() would actually close. The compiler now owns that
    // guarantee, so what remains testable is the invariant itself: the field
    // and the invocation target are the same object.
    test('closableObject names the object that close() actually closes', () {
      final first = OwnCloseTarget();
      final second = OwnCloseTarget();
      final adaptor = TomCloseAdaptor(first);

      expect(adaptor.closableObject, same(first));

      adaptor.close();

      expect(first.closed, isTrue);
      expect(second.closed, isFalse);
    });

    test('two adaptors over two targets stay independent', () {
      // The bound-once mirror is per-instance, not shared state on the class.
      final first = OwnCloseTarget();
      final second = OwnCloseTarget();
      final firstAdaptor = TomCloseAdaptor(first);
      final secondAdaptor = TomCloseAdaptor(second);

      secondAdaptor.close();

      expect(second.closed, isTrue);
      expect(first.closed, isFalse);

      firstAdaptor.close();

      expect(first.closed, isTrue);
    });
  });

  // ===========================================================================
  // performShutdown() & teardown behaviour
  // ===========================================================================

  group('performShutdown', () {
    test('runs handlers, then closables, then disposables in order', () {
      final log = <String>[];
      final cleanup = _newCleanup();
      cleanup.addDisposable(RecordingDisposable(log));
      cleanup.addSignalHandler((signal) => log.add('handler'));
      cleanup.addClosable(RecordingClosable(log));

      cleanup.performShutdown();

      expect(log, equals(['handler', 'closable', 'disposable']));
    });

    test('executes only once across repeated calls (_executed)', () {
      final cleanup = _newCleanup();
      final closable = TestClosable();
      final disposable = TestDisposable();
      cleanup.addClosable(closable);
      cleanup.addDisposable(disposable);

      cleanup.performShutdown();
      cleanup.performShutdown();
      cleanup.performShutdown();

      expect(closable.closeCount, equals(1));
      expect(disposable.disposeCount, equals(1));
    });

    test('isolates failures so later cleanups still run', () {
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
      cleanup.performShutdown();

      expect(log, equals(['closable', 'disposable']));
    });

    // Isolating a failure is only half of fault tolerance; the other half is
    // saying what failed. A shutdown happens once, usually unattended, and
    // cannot be reproduced by re-running it, so whatever the diagnostic omits
    // is lost for good.

    test('the failure diagnostic names the exception', () {
      final lines = <String>[];
      final cleanup = _newCleanup();
      cleanup.addClosable(ThrowingClosable());

      _capturePrints(lines, cleanup.performShutdown);

      // ThrowingClosable throws Exception('Close failed').
      expect(lines.join('\n'), contains('Close failed'));
    });

    test('the failure diagnostic names the phase and the entry', () {
      final lines = <String>[];
      final cleanup = _newCleanup();
      cleanup.addDisposable(ThrowingDisposable());

      _capturePrints(lines, cleanup.performShutdown);

      final diagnostic = lines.join('\n');
      expect(diagnostic, contains('disposable'));
      expect(diagnostic, contains('ThrowingDisposable'));
    });

    test('the failure diagnostic carries a stack trace', () {
      final lines = <String>[];
      final cleanup = _newCleanup();
      cleanup.addClosable(ThrowingClosable());

      _capturePrints(lines, cleanup.performShutdown);

      // The frame that actually threw has to be in there, or the trace is
      // decoration rather than evidence.
      expect(lines.join('\n'), contains('ThrowingClosable.close'));
    });

    test('silent suppresses the failure diagnostic too', () {
      final lines = <String>[];
      final cleanup = _newCleanup();
      cleanup.addClosable(ThrowingClosable());
      cleanup.silent = true;

      _capturePrints(lines, cleanup.performShutdown);

      expect(lines, isEmpty);
    });

    test('a manual call that does real work still prints no status', () {
      // The quiet-when-empty case is covered under `empty state`; this is the
      // one that could regress independently, because a status message gated
      // on the wrong condition would show up only once there was work to
      // announce. Non-silent on purpose: `silent` must not be what is keeping
      // this quiet.
      final lines = <String>[];
      final cleanup = _newCleanup();
      cleanup.addClosable(TestClosable());
      cleanup.addDisposable(RecordingDisposable(<String>[]));

      _capturePrints(lines, cleanup.performShutdown);

      expect(lines, isEmpty);
    });

    test('manual call ignores paused (only the signal path honours it)', () {
      final cleanup = _newCleanup();
      final closable = TestClosable();
      cleanup.addClosable(closable);
      cleanup.paused = true;

      // The manual path (fromSignal: false) always runs regardless of paused.
      cleanup.performShutdown();

      expect(closable.closed, isTrue);
    });

    group('signal-driven path (fromSignal)', () {
      test('skips cleanup entirely while paused', () {
        final cleanup = _newCleanup();
        final closable = TestClosable();
        cleanup.addClosable(closable);
        cleanup.paused = true;

        cleanup.performShutdown(fromSignal: true);

        expect(closable.closed, isFalse);
      });

      test('runs cleanup when not paused', () {
        final cleanup = _newCleanup();
        final closable = TestClosable();
        cleanup.addClosable(closable);
        cleanup.silent = true;

        cleanup.performShutdown(fromSignal: true);

        expect(closable.closed, isTrue);
      });

      test('silent suppresses the status messages', () {
        final lines = <String>[];
        final cleanup = _newCleanup();
        cleanup.addClosable(TestClosable());
        cleanup.silent = true;

        _capturePrints(lines, () => cleanup.performShutdown(fromSignal: true));

        expect(lines, isEmpty);
      });

      test('non-silent emits the received + performed status messages', () {
        final lines = <String>[];
        final cleanup = _newCleanup();
        cleanup.addClosable(TestClosable());

        _capturePrints(lines, () => cleanup.performShutdown(fromSignal: true));

        expect(lines, contains('Received SIGINT'));
        expect(lines, contains('Shutdown performed'));
      });
    });
  });

  group('dispose / cancelAll', () {
    test(
      'dispose stops the instance reacting to its signals',
      () async {
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
      },
      skip: _signalSendingSkipReason,
    );

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

/// Runs [body] while collecting every `print` line into [sink].
void _capturePrints(List<String> sink, void Function() body) {
  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => sink.add(line),
    ),
  );
}

/// Runs the asynchronous [body] while collecting every `print` line into
/// [sink], completing once [body] has.
///
/// The signal-driven tests need this rather than [_capturePrints] because
/// their output arrives from a stream listener: the registration, the send and
/// the delivery all have to happen inside the capturing zone.
Future<void> _capturePrintsAsync(
  List<String> sink,
  Future<void> Function() body,
) {
  return runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => sink.add(line),
    ),
  );
}

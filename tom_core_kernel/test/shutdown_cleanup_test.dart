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
      test('should create instance without errors', () {
        // Act & Assert - should not throw
        expect(() => _newCleanup(), returnsNormally);
      });

      test('should create distinct instances', () {
        // Act
        final cleanup1 = _newCleanup();
        final cleanup2 = _newCleanup();

        // Assert
        expect(identical(cleanup1, cleanup2), isFalse);
      });
    });

    group('addDisposable', () {
      test('should add disposable to cleanup list', () {
        // Arrange
        final cleanup = _newCleanup();
        final disposable = TestDisposable();

        // Act & Assert - should not throw
        expect(() => cleanup.addDisposable(disposable), returnsNormally);
      });

      test('should accept multiple disposables', () {
        // Arrange
        final cleanup = _newCleanup();
        final disposable1 = TestDisposable();
        final disposable2 = TestDisposable();
        final disposable3 = TestDisposable();

        // Act & Assert - should not throw
        expect(() {
          cleanup.addDisposable(disposable1);
          cleanup.addDisposable(disposable2);
          cleanup.addDisposable(disposable3);
        }, returnsNormally);
      });

      test('should accept same disposable multiple times', () {
        // Arrange
        final cleanup = _newCleanup();
        final disposable = TestDisposable();

        // Act & Assert - should not throw
        expect(() {
          cleanup.addDisposable(disposable);
          cleanup.addDisposable(disposable);
        }, returnsNormally);
      });
    });

    group('addClosable', () {
      test('should add closable to cleanup list', () {
        // Arrange
        final cleanup = _newCleanup();
        final closable = TestClosable();

        // Act & Assert - should not throw
        expect(() => cleanup.addClosable(closable), returnsNormally);
      });

      test('should accept multiple closables', () {
        // Arrange
        final cleanup = _newCleanup();
        final closable1 = TestClosable();
        final closable2 = TestClosable();
        final closable3 = TestClosable();

        // Act & Assert - should not throw
        expect(() {
          cleanup.addClosable(closable1);
          cleanup.addClosable(closable2);
          cleanup.addClosable(closable3);
        }, returnsNormally);
      });

      test('should accept same closable multiple times', () {
        // Arrange
        final cleanup = _newCleanup();
        final closable = TestClosable();

        // Act & Assert - should not throw
        expect(() {
          cleanup.addClosable(closable);
          cleanup.addClosable(closable);
        }, returnsNormally);
      });
    });

    group('addSignalHandler', () {
      test('should add signal handler to cleanup list', () {
        // Arrange
        final cleanup = _newCleanup();
        // ignore: unused_local_variable
        var handlerCalled = false;

        // Act & Assert - should not throw
        expect(() {
          cleanup.addSignalHandler((signal) {
            handlerCalled = true;
          });
        }, returnsNormally);
      });

      test('should accept multiple signal handlers', () {
        // Arrange
        final cleanup = _newCleanup();
        var count = 0;

        // Act & Assert - should not throw
        expect(() {
          cleanup.addSignalHandler((signal) => count++);
          cleanup.addSignalHandler((signal) => count++);
          cleanup.addSignalHandler((signal) => count++);
        }, returnsNormally);
      });

      test('should accept empty handler', () {
        // Arrange
        final cleanup = _newCleanup();

        // Act & Assert - should not throw
        expect(() {
          cleanup.addSignalHandler((signal) {});
        }, returnsNormally);
      });
    });

    group('addSignal', () {
      test('should accept ProcessSignal.sigterm', () {
        // Arrange
        final cleanup = _newCleanup();

        // Act & Assert - should not throw
        expect(() => cleanup.addSignal(ProcessSignal.sigterm), returnsNormally);
      });

      test('should accept ProcessSignal.sigusr1', () {
        // Arrange
        final cleanup = _newCleanup();

        // Act & Assert - should not throw
        expect(() => cleanup.addSignal(ProcessSignal.sigusr1), returnsNormally);
      });

      test('should accept ProcessSignal.sigusr2', () {
        // Arrange
        final cleanup = _newCleanup();

        // Act & Assert - should not throw
        expect(() => cleanup.addSignal(ProcessSignal.sigusr2), returnsNormally);
      });
    });

    group('start', () {
      test('should execute without errors', () {
        // Arrange
        final cleanup = _newCleanup();

        // Act & Assert - should not throw
        expect(() => cleanup.start(), returnsNormally);
      });

      test('should be callable multiple times', () {
        // Arrange
        final cleanup = _newCleanup();

        // Act & Assert - should not throw
        expect(() {
          cleanup.start();
          cleanup.start();
          cleanup.start();
        }, returnsNormally);
      });

      test('should work after adding handlers', () {
        // Arrange
        final cleanup = _newCleanup();
        cleanup.addClosable(TestClosable());
        cleanup.addDisposable(TestDisposable());
        cleanup.addSignalHandler((signal) {});

        // Act & Assert - should not throw
        expect(() => cleanup.start(), returnsNormally);
      });

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
      test('should accept all handler types together', () {
        // Arrange
        final cleanup = _newCleanup();
        final closable = TestClosable();
        final disposable = TestDisposable();

        // Act & Assert - should not throw
        expect(() {
          cleanup.addSignalHandler((signal) {});
          cleanup.addClosable(closable);
          cleanup.addDisposable(disposable);
          cleanup.start();
        }, returnsNormally);
      });

      test('should accept handlers in any order', () {
        // Arrange
        final cleanup = _newCleanup();
        final closable = TestClosable();
        final disposable = TestDisposable();

        // Act & Assert - should not throw
        expect(() {
          cleanup.addDisposable(disposable);
          cleanup.addSignalHandler((signal) {});
          cleanup.addClosable(closable);
          cleanup.addSignalHandler((signal) {});
          cleanup.addClosable(TestClosable());
        }, returnsNormally);
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
      test('should handle cleanup with no registered handlers', () {
        // Arrange
        final cleanup = _newCleanup();

        // Act & Assert - should not throw
        expect(() => cleanup.start(), returnsNormally);
      });
    });

    group('error handling', () {
      test('should create throwing disposable without error', () {
        // Arrange & Act
        final disposable = ThrowingDisposable();

        // Assert
        expect(disposable, isA<TomDisposable>());
      });

      test('should create throwing closable without error', () {
        // Arrange & Act
        final closable = ThrowingClosable();

        // Assert
        expect(closable, isA<TomClosable>());
      });

      test('should add throwing disposable to cleanup', () {
        // Arrange
        final cleanup = _newCleanup();
        final disposable = ThrowingDisposable();

        // Act & Assert - should not throw
        expect(() => cleanup.addDisposable(disposable), returnsNormally);
      });

      test('should add throwing closable to cleanup', () {
        // Arrange
        final cleanup = _newCleanup();
        final closable = ThrowingClosable();

        // Act & Assert - should not throw
        expect(() => cleanup.addClosable(closable), returnsNormally);
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

      test('should maintain independent state per instance', () {
        // Arrange
        final cleanup1 = _newCleanup();
        final cleanup2 = _newCleanup();
        final closable = TestClosable();

        // Act
        cleanup1.addClosable(closable);

        // Assert - adding to one shouldn't affect the other
        // Both should work independently
        expect(() => cleanup1.start(), returnsNormally);
        expect(() => cleanup2.start(), returnsNormally);
      });
    });

    group('chaining operations', () {
      test('should support method chaining pattern', () {
        // Arrange
        final cleanup = _newCleanup();
        final closable = TestClosable();
        final disposable = TestDisposable();

        // Act & Assert - should complete without errors
        cleanup.addClosable(closable);
        cleanup.addDisposable(disposable);
        cleanup.addSignalHandler((signal) {});
        cleanup.addSignal(ProcessSignal.sigterm);
        cleanup.start();

        expect(true, isTrue); // Reached here without errors
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

    test('resolves a close() inherited from a superclass', () {
      final target = InheritsClose();

      // Pre-fix: the constructor threw because `declarations` holds only the
      // leaf type's own members, so the inherited close() was not found.
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
    test('dispose cancels signal subscriptions without throwing', () async {
      final cleanup = _newCleanup();

      await expectLater(cleanup.dispose(), completes);
    });

    test('cancelAll is safe to call repeatedly', () async {
      final cleanup = _newCleanup();
      cleanup.addSignal(ProcessSignal.sigterm);

      await cleanup.cancelAll();
      await expectLater(cleanup.cancelAll(), completes);
    });

    test('many instances can each be disposed', () async {
      final instances = List.generate(10, (_) => _newCleanup());

      for (final instance in instances) {
        await expectLater(instance.dispose(), completes);
      }
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

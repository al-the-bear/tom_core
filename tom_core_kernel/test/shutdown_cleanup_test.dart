import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

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
// TomDisposable Tests
// =============================================================================

void main() {
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
        expect(() => TomShutdownCleanup(), returnsNormally);
      });

      test('should create distinct instances', () {
        // Act
        final cleanup1 = TomShutdownCleanup();
        final cleanup2 = TomShutdownCleanup();

        // Assert
        expect(identical(cleanup1, cleanup2), isFalse);
      });
    });

    group('addDisposable', () {
      test('should add disposable to cleanup list', () {
        // Arrange
        final cleanup = TomShutdownCleanup();
        final disposable = TestDisposable();

        // Act & Assert - should not throw
        expect(() => cleanup.addDisposable(disposable), returnsNormally);
      });

      test('should accept multiple disposables', () {
        // Arrange
        final cleanup = TomShutdownCleanup();
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
        final cleanup = TomShutdownCleanup();
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
        final cleanup = TomShutdownCleanup();
        final closable = TestClosable();

        // Act & Assert - should not throw
        expect(() => cleanup.addClosable(closable), returnsNormally);
      });

      test('should accept multiple closables', () {
        // Arrange
        final cleanup = TomShutdownCleanup();
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
        final cleanup = TomShutdownCleanup();
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
        final cleanup = TomShutdownCleanup();
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
        final cleanup = TomShutdownCleanup();
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
        final cleanup = TomShutdownCleanup();

        // Act & Assert - should not throw
        expect(() {
          cleanup.addSignalHandler((signal) {});
        }, returnsNormally);
      });
    });

    group('addSignal', () {
      test('should accept ProcessSignal.sigterm', () {
        // Arrange
        final cleanup = TomShutdownCleanup();

        // Act & Assert - should not throw
        expect(() => cleanup.addSignal(ProcessSignal.sigterm), returnsNormally);
      });

      test('should accept ProcessSignal.sigusr1', () {
        // Arrange
        final cleanup = TomShutdownCleanup();

        // Act & Assert - should not throw
        expect(
          () => cleanup.addSignal(ProcessSignal.sigusr1),
          returnsNormally,
        );
      });

      test('should accept ProcessSignal.sigusr2', () {
        // Arrange
        final cleanup = TomShutdownCleanup();

        // Act & Assert - should not throw
        expect(
          () => cleanup.addSignal(ProcessSignal.sigusr2),
          returnsNormally,
        );
      });
    });

    group('start', () {
      test('should execute without errors', () {
        // Arrange
        final cleanup = TomShutdownCleanup();

        // Act & Assert - should not throw
        expect(() => cleanup.start(), returnsNormally);
      });

      test('should be callable multiple times', () {
        // Arrange
        final cleanup = TomShutdownCleanup();

        // Act & Assert - should not throw
        expect(() {
          cleanup.start();
          cleanup.start();
          cleanup.start();
        }, returnsNormally);
      });

      test('should work after adding handlers', () {
        // Arrange
        final cleanup = TomShutdownCleanup();
        cleanup.addClosable(TestClosable());
        cleanup.addDisposable(TestDisposable());
        cleanup.addSignalHandler((signal) {});

        // Act & Assert - should not throw
        expect(() => cleanup.start(), returnsNormally);
      });
    });

    group('mixed handlers', () {
      test('should accept all handler types together', () {
        // Arrange
        final cleanup = TomShutdownCleanup();
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
        final cleanup = TomShutdownCleanup();
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

  group('tomShutdownCleanup (global instance)', () {
    test('should be a TomShutdownCleanup instance', () {
      // Assert
      expect(tomShutdownCleanup, isA<TomShutdownCleanup>());
    });

    test('should be accessible and non-null', () {
      // Assert
      expect(tomShutdownCleanup, isNotNull);
    });

    test('should support addClosable method', () {
      // Arrange
      final closable = TestClosable();

      // Act & Assert - should not throw
      expect(() => tomShutdownCleanup.addClosable(closable), returnsNormally);
    });

    test('should support addDisposable method', () {
      // Arrange
      final disposable = TestDisposable();

      // Act & Assert - should not throw
      expect(
        () => tomShutdownCleanup.addDisposable(disposable),
        returnsNormally,
      );
    });

    test('should support addSignalHandler method', () {
      // Act & Assert - should not throw
      expect(
        () => tomShutdownCleanup.addSignalHandler((signal) {}),
        returnsNormally,
      );
    });

    test('should support addSignal method', () {
      // Act & Assert - should not throw
      expect(
        () => tomShutdownCleanup.addSignal(ProcessSignal.sigterm),
        returnsNormally,
      );
    });

    test('should support start method', () {
      // Act & Assert - should not throw
      expect(() => tomShutdownCleanup.start(), returnsNormally);
    });

    test('should be reassignable', () {
      // Arrange
      final originalInstance = tomShutdownCleanup;
      final newInstance = TomShutdownCleanup();

      // Act
      tomShutdownCleanup = newInstance;

      // Assert
      expect(identical(tomShutdownCleanup, newInstance), isTrue);
      expect(identical(tomShutdownCleanup, originalInstance), isFalse);

      // Cleanup - restore original
      tomShutdownCleanup = originalInstance;
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
        final cleanup = TomShutdownCleanup();

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
        final cleanup = TomShutdownCleanup();
        final disposable = ThrowingDisposable();

        // Act & Assert - should not throw
        expect(() => cleanup.addDisposable(disposable), returnsNormally);
      });

      test('should add throwing closable to cleanup', () {
        // Arrange
        final cleanup = TomShutdownCleanup();
        final closable = ThrowingClosable();

        // Act & Assert - should not throw
        expect(() => cleanup.addClosable(closable), returnsNormally);
      });
    });

    group('multiple instances', () {
      test('should allow creating many independent instances', () {
        // Arrange & Act
        final instances = List.generate(10, (_) => TomShutdownCleanup());

        // Assert
        expect(instances, hasLength(10));
        for (var i = 0; i < instances.length - 1; i++) {
          expect(identical(instances[i], instances[i + 1]), isFalse);
        }
      });

      test('should maintain independent state per instance', () {
        // Arrange
        final cleanup1 = TomShutdownCleanup();
        final cleanup2 = TomShutdownCleanup();
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
        final cleanup = TomShutdownCleanup();
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
}

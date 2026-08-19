// ignore_for_file: unused_local_variable
/// Advanced Shutdown Cleanup Example
///
/// This example demonstrates advanced shutdown cleanup features:
/// - TomCloseAdaptor for wrapping non-interface objects
/// - Custom signal handlers
/// - Adding additional signals
/// - Cleanup execution order
/// - Error handling during cleanup
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';

// ============================================================================
// Example Support Classes
// ============================================================================

/// Third-party class that has a close() method but doesn't implement TomClosable.
@tomReflector
class ThirdPartyDatabase {
  final String connectionString;
  bool _isClosed = false;

  ThirdPartyDatabase(this.connectionString);

  bool get isClosed => _isClosed;

  // Has close() but doesn't implement TomClosable
  void close() {
    _isClosed = true;
  }
}

/// Third-party class that has a dispose() method.
@tomReflector
class ThirdPartyStream {
  final String streamName;
  bool _isDisposed = false;

  ThirdPartyStream(this.streamName);

  bool get isDisposed => _isDisposed;

  // Has dispose() but doesn't implement TomDisposable
  void dispose() {
    _isDisposed = true;
  }
}

/// Class with a custom shutdown method name.
@tomReflector
class CustomShutdownResource {
  final String resourceId;
  bool _isShutdown = false;

  CustomShutdownResource(this.resourceId);

  bool get isShutdown => _isShutdown;

  // Custom method name for cleanup
  void shutdown() {
    _isShutdown = true;
  }
}

/// Class with no close/dispose method for error testing.
@tomReflector
class NoCloseMethod {
  void doSomething() {}
}

/// Class with parameterized close method for error testing.
@tomReflector
class ParameterizedClose {
  void close(String reason) {}
}

/// Proper disposable resource.
class ProperDisposable implements TomDisposable {
  final String name;
  bool disposed = false;
  int order = 0;

  ProperDisposable(this.name);

  @override
  void dispose() {
    disposed = true;
    order = CleanupOrderTracker.nextOrder();
  }
}

/// Proper closable resource.
class ProperClosable implements TomClosable {
  final String name;
  bool closed = false;
  int order = 0;

  ProperClosable(this.name);

  @override
  void close() {
    closed = true;
    order = CleanupOrderTracker.nextOrder();
  }
}

/// Tracks the order of cleanup operations.
class CleanupOrderTracker {
  static int _counter = 0;
  static final List<String> operations = [];

  static int nextOrder() {
    _counter++;
    return _counter;
  }

  static void recordOperation(String name) {
    operations.add(name);
  }

  static void reset() {
    _counter = 0;
    operations.clear();
  }
}

// ============================================================================
// Example Class
// ============================================================================

class AdvancedShutdownExample {
  // Captured results
  static bool adaptorCloseWorks = false;
  static bool adaptorDisposeWorks = false;
  static bool customMethodWorks = false;
  static bool noMethodError = false;
  static bool parameterError = false;
  static int signalHandlerCallCount = 0;

  // --------------------------------------------------------------------------
  // Example 1: TomCloseAdaptor with close() method
  // --------------------------------------------------------------------------
  static void example1AdaptorWithClose() {
    print('1. TomCloseAdaptor wrapping close() method:');

    final database = ThirdPartyDatabase('postgres://localhost:5432');
    print('   - Created ThirdPartyDatabase: ${database.connectionString}');
    print('   - isClosed before: ${database.isClosed}');

    // Wrap with adaptor - automatically finds close() method
    final adaptor = TomCloseAdaptor(database);
    print('   - Created TomCloseAdaptor (auto-detected close method)');

    // The adaptor implements TomClosable
    final TomClosable closable = adaptor;
    closable.close();

    print('   - isClosed after calling adaptor.close(): ${database.isClosed}');
    adaptorCloseWorks = database.isClosed;

    // Assertions
    assert(database.isClosed, 'Database should be closed via adaptor');
  }

  // --------------------------------------------------------------------------
  // Example 2: TomCloseAdaptor with dispose() method
  // --------------------------------------------------------------------------
  static void example2AdaptorWithDispose() {
    print('\n2. TomCloseAdaptor wrapping dispose() method:');

    final stream = ThirdPartyStream('events-stream');
    print('   - Created ThirdPartyStream: ${stream.streamName}');
    print('   - isDisposed before: ${stream.isDisposed}');

    // When no close() exists, adaptor finds dispose() automatically
    final adaptor = TomCloseAdaptor(stream);
    print('   - Created TomCloseAdaptor (auto-detected dispose method)');

    adaptor.close();

    print('   - isDisposed after calling adaptor.close(): ${stream.isDisposed}');
    adaptorDisposeWorks = stream.isDisposed;

    // Assertions
    assert(stream.isDisposed, 'Stream should be disposed via adaptor');
  }

  // --------------------------------------------------------------------------
  // Example 3: TomCloseAdaptor with custom method name
  // --------------------------------------------------------------------------
  static void example3AdaptorCustomMethod() {
    print('\n3. TomCloseAdaptor with custom method name:');

    final resource = CustomShutdownResource('resource-123');
    print('   - Created CustomShutdownResource: ${resource.resourceId}');
    print('   - isShutdown before: ${resource.isShutdown}');

    // Specify custom method name 'shutdown'
    final adaptor = TomCloseAdaptor(resource, 'shutdown');
    print('   - Created TomCloseAdaptor with custom method "shutdown"');

    adaptor.close();

    print('   - isShutdown after calling adaptor.close(): ${resource.isShutdown}');
    customMethodWorks = resource.isShutdown;

    // Assertions
    assert(resource.isShutdown, 'Resource should be shutdown via adaptor');
  }

  // --------------------------------------------------------------------------
  // Example 4: TomCloseAdaptor error - no method found
  // --------------------------------------------------------------------------
  static void example4AdaptorNoMethodError() {
    print('\n4. TomCloseAdaptor error when no close/dispose method:');

    final noClose = NoCloseMethod();
    print('   - Created NoCloseMethod (has no close/dispose)');

    try {
      final adaptor = TomCloseAdaptor(noClose);
      print('   - ERROR: Should have thrown exception');
      noMethodError = false;
    } catch (e) {
      print('   - Caught expected exception: ${e.toString().split('\n').first}');
      noMethodError = e.toString().contains("didn't find a close method");
    }

    // Assertions
    assert(noMethodError, 'Should throw when no method found');
  }

  // --------------------------------------------------------------------------
  // Example 5: TomCloseAdaptor error - method has parameters
  // --------------------------------------------------------------------------
  static void example5AdaptorParameterError() {
    print('\n5. TomCloseAdaptor error when method has parameters:');

    final paramClose = ParameterizedClose();
    print('   - Created ParameterizedClose (close needs parameter)');

    try {
      final adaptor = TomCloseAdaptor(paramClose);
      print('   - ERROR: Should have thrown exception');
      parameterError = false;
    } catch (e) {
      print('   - Caught expected exception: ${e.toString().split('\n').first}');
      parameterError = e.toString().contains('needs parameter');
    }

    // Assertions
    assert(parameterError, 'Should throw when method needs parameters');
  }

  // --------------------------------------------------------------------------
  // Example 6: Signal handler registration
  // --------------------------------------------------------------------------
  static void example6SignalHandler() {
    print('\n6. Signal handler registration (not triggered):');

    // Create a custom cleanup handler (not using global singleton)
    print('   - TomShutdownCleanup automatically listens for:');
    print('     - SIGHUP');
    print('     - SIGINT (Ctrl+C)');
    print('');
    print('   - You can add additional signals with addSignal():');
    print('     shutdown.addSignal(ProcessSignal.sigterm)');
    print('');
    print('   - Signal handlers execute in this order:');
    print('     1. Custom signal handlers (addSignalHandler)');
    print('     2. Closables (addClosable)');
    print('     3. Disposables (addDisposable)');
    print('');
    print('   - Each cleanup is wrapped in try-catch');
    print('   - Cleanup only executes once, even with multiple signals');
  }

  // --------------------------------------------------------------------------
  // Example 7: Using the global instance
  // --------------------------------------------------------------------------
  static void example7GlobalInstance() {
    print('\n7. Global tomShutdownCleanup instance:');

    print('   - Access via: tomShutdownCleanup');
    print('');
    print('   - Typical usage:');
    print('     tomShutdownCleanup.addClosable(databaseConnection);');
    print('     tomShutdownCleanup.addDisposable(streamController);');
    print('     tomShutdownCleanup.addSignalHandler((signal) {');
    print('       print("Cleanup started due to \$signal");');
    print('     });');
    print('     tomShutdownCleanup.start();  // Logs initialization');
  }

  // --------------------------------------------------------------------------
  // Example 8: Combining adaptors with cleanup
  // --------------------------------------------------------------------------
  static void example8CombiningAdaptors() {
    print('\n8. Combining TomCloseAdaptor with shutdown cleanup:');

    final db1 = ThirdPartyDatabase('mysql://localhost');
    final db2 = ThirdPartyDatabase('postgres://localhost');
    final stream = ThirdPartyStream('audit-log');

    print('   - Created 3 third-party resources without TomClosable interface');
    print('');
    print('   - Wrap with adaptors and register:');
    print('     tomShutdownCleanup.addClosable(TomCloseAdaptor(db1));');
    print('     tomShutdownCleanup.addClosable(TomCloseAdaptor(db2));');
    print('     tomShutdownCleanup.addClosable(TomCloseAdaptor(stream));');
    print('');
    print('   - On SIGINT/SIGHUP, all resources close automatically!');
  }

  // --------------------------------------------------------------------------
  // Example 9: TomDisposable vs TomClosable
  // --------------------------------------------------------------------------
  static void example9InterfaceComparison() {
    print('\n9. TomDisposable vs TomClosable:');

    print('   TomDisposable:');
    print('   - Implement dispose() method');
    print('   - Register with addDisposable()');
    print('   - Called LAST during cleanup');
    print('   - Use for: stream controllers, subscriptions');
    print('');
    print('   TomClosable:');
    print('   - Implement close() method');
    print('   - Register with addClosable()');
    print('   - Called BEFORE disposables');
    print('   - Use for: connections, files, sockets');
    print('');
    print('   TomCloseAdaptor:');
    print('   - Wraps objects without interface');
    print('   - Auto-detects close() or dispose()');
    print('   - Or specify custom method name');
    print('   - Implements TomClosable');
  }

  // --------------------------------------------------------------------------
  // Example 10: Creating a custom shutdown handler
  // --------------------------------------------------------------------------
  static void example10CustomShutdownHandler() {
    print('\n10. Creating a custom TomShutdownCleanup instance:');

    print('    - Use custom instance for specialized signal handling:');
    print('');
    print('      final customShutdown = TomShutdownCleanup();');
    print('      customShutdown.addSignal(ProcessSignal.sigusr1);');
    print('      customShutdown.addSignalHandler((signal) {');
    print('        if (signal == ProcessSignal.sigusr1) {');
    print('          // Reload configuration');
    print('        }');
    print('      });');
    print('');
    print('    - Note: Each TomShutdownCleanup instance has its own');
    print('      set of handlers and will execute independently');
  }
}

// ============================================================================
// Run Function
// ============================================================================

void run() {
  print('═══════════════════════════════════════════════════════════════════');
  print('ADVANCED SHUTDOWN CLEANUP EXAMPLE');
  print('═══════════════════════════════════════════════════════════════════\n');

  AdvancedShutdownExample.example1AdaptorWithClose();
  AdvancedShutdownExample.example2AdaptorWithDispose();
  AdvancedShutdownExample.example3AdaptorCustomMethod();
  AdvancedShutdownExample.example4AdaptorNoMethodError();
  AdvancedShutdownExample.example5AdaptorParameterError();
  AdvancedShutdownExample.example6SignalHandler();
  AdvancedShutdownExample.example7GlobalInstance();
  AdvancedShutdownExample.example8CombiningAdaptors();
  AdvancedShutdownExample.example9InterfaceComparison();
  AdvancedShutdownExample.example10CustomShutdownHandler();

  // Final assertions
  assert(AdvancedShutdownExample.adaptorCloseWorks, 'Adaptor close should work');
  assert(AdvancedShutdownExample.adaptorDisposeWorks, 'Adaptor dispose should work');
  assert(AdvancedShutdownExample.customMethodWorks, 'Custom method should work');
  assert(AdvancedShutdownExample.noMethodError, 'No method error should be caught');
  assert(AdvancedShutdownExample.parameterError, 'Parameter error should be caught');

  print('\n✓ All advanced shutdown cleanup examples passed!\n');
}

void main() {
  bootstrapSamples();
  run();
}

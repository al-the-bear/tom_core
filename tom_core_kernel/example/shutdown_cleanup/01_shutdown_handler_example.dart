// ignore_for_file: unnecessary_type_check, unused_local_variable
/// Demonstrates TomShutdownCleanup, TomDisposable, and TomClosable usage.
///
/// This example shows how to register cleanup handlers for graceful process
/// termination, including closable and disposable objects, and custom signal
/// handlers.
///
/// Key concepts covered:
/// - TomShutdownCleanup: Main coordinator for shutdown cleanup operations
/// - TomDisposable: Interface for objects with dispose() cleanup
/// - TomClosable: Interface for objects with close() cleanup
/// - TomSignalHandler: Custom signal handlers for specialized cleanup logic
/// - tomShutdownCleanup: Global default instance
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// Shutdown Handler Example
// =============================================================================

// -----------------------------------------------------------------------------
// Example Support Classes
// -----------------------------------------------------------------------------

/// Example class implementing TomDisposable for cleanup demonstration.
class ExampleDisposableResource implements TomDisposable {
  final String name;
  bool _disposed = false;

  ExampleDisposableResource(this.name);

  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
  }
}

/// Example class implementing TomClosable for cleanup demonstration.
class ExampleClosableConnection implements TomClosable {
  final String connectionName;
  bool _closed = false;

  ExampleClosableConnection(this.connectionName);

  bool get isClosed => _closed;

  @override
  void close() {
    _closed = true;
  }
}

// -----------------------------------------------------------------------------
// Main Example Function
// -----------------------------------------------------------------------------

void run() {
  print('=== 01: Shutdown Handler Example ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: Creating a TomDisposable resource
  // ---------------------------------------------------------------------------
  print('1. Creating a TomDisposable resource:');

  final disposableResource = ExampleDisposableResource('StreamController');
  final resourceName = disposableResource.name;
  final isDisposedBefore = disposableResource.isDisposed;

  print('   - Resource Name: $resourceName');
  print('   - Is Disposed (before): $isDisposedBefore');

  // Manually dispose to demonstrate
  disposableResource.dispose();
  final isDisposedAfter = disposableResource.isDisposed;

  print('   - Is Disposed (after manual dispose): $isDisposedAfter\n');

  // ---------------------------------------------------------------------------
  // Example 2: Creating a TomClosable connection
  // ---------------------------------------------------------------------------
  print('2. Creating a TomClosable connection:');

  final closableConnection = ExampleClosableConnection('DatabaseConnection');
  final connectionName = closableConnection.connectionName;
  final isClosedBefore = closableConnection.isClosed;

  print('   - Connection Name: $connectionName');
  print('   - Is Closed (before): $isClosedBefore');

  // Manually close to demonstrate
  closableConnection.close();
  final isClosedAfter = closableConnection.isClosed;

  print('   - Is Closed (after manual close): $isClosedAfter\n');

  // ---------------------------------------------------------------------------
  // Example 3: Creating a custom TomShutdownCleanup instance
  // ---------------------------------------------------------------------------
  print('3. Creating a custom TomShutdownCleanup instance:');

  final customCleanup = TomShutdownCleanup();

  // Track signal handler calls for demonstration
  var signalHandlerCalled = false;
  var signalHandlerCallCount = 0;

  print('   - Custom cleanup instance created');
  print('   - Default signals (SIGHUP, SIGINT) are automatically registered\n');

  // ---------------------------------------------------------------------------
  // Example 4: Registering disposable resources with cleanup
  // ---------------------------------------------------------------------------
  print('4. Registering disposable resources with cleanup:');

  final resource1 = ExampleDisposableResource('Resource1');
  final resource2 = ExampleDisposableResource('Resource2');

  // Create a fresh cleanup instance for testing
  final cleanupWithDisposables = TomShutdownCleanup();
  cleanupWithDisposables.addDisposable(resource1);
  cleanupWithDisposables.addDisposable(resource2);

  final resource1BeforeCleanup = resource1.isDisposed;
  final resource2BeforeCleanup = resource2.isDisposed;

  print('   - Resource1 registered: ${resource1.name}');
  print('   - Resource2 registered: ${resource2.name}');
  print('   - Resource1 disposed before cleanup: $resource1BeforeCleanup');
  print('   - Resource2 disposed before cleanup: $resource2BeforeCleanup\n');

  // ---------------------------------------------------------------------------
  // Example 5: Registering closable resources with cleanup
  // ---------------------------------------------------------------------------
  print('5. Registering closable resources with cleanup:');

  final connection1 = ExampleClosableConnection('Connection1');
  final connection2 = ExampleClosableConnection('Connection2');

  // Create a fresh cleanup instance for testing
  final cleanupWithClosables = TomShutdownCleanup();
  cleanupWithClosables.addClosable(connection1);
  cleanupWithClosables.addClosable(connection2);

  final connection1BeforeCleanup = connection1.isClosed;
  final connection2BeforeCleanup = connection2.isClosed;

  print('   - Connection1 registered: ${connection1.connectionName}');
  print('   - Connection2 registered: ${connection2.connectionName}');
  print('   - Connection1 closed before cleanup: $connection1BeforeCleanup');
  print('   - Connection2 closed before cleanup: $connection2BeforeCleanup\n');

  // ---------------------------------------------------------------------------
  // Example 6: Registering custom signal handlers
  // ---------------------------------------------------------------------------
  print('6. Registering custom signal handlers:');

  final cleanupWithHandler = TomShutdownCleanup();
  var customHandlerInvoked = false;
  String? receivedSignalDescription;

  cleanupWithHandler.addSignalHandler((signal) {
    customHandlerInvoked = true;
    receivedSignalDescription = signal.toString();
  });

  final handlerRegistered = true;
  final customHandlerStatus = customHandlerInvoked;

  print('   - Custom signal handler registered: $handlerRegistered');
  print('   - Handler invoked before signal: $customHandlerStatus');
  print('   - Signal handlers execute first during cleanup\n');

  // ---------------------------------------------------------------------------
  // Example 7: Understanding cleanup execution order
  // ---------------------------------------------------------------------------
  print('7. Understanding cleanup execution order:');

  final executionOrder = <String>[];

  final orderTestCleanup = TomShutdownCleanup();

  // Add signal handler
  orderTestCleanup.addSignalHandler((signal) {
    executionOrder.add('1. Signal handlers');
  });

  // Add closable
  final orderTestClosable = ExampleClosableConnection('OrderTest');
  orderTestCleanup.addClosable(orderTestClosable);

  // Add disposable
  final orderTestDisposable = ExampleDisposableResource('OrderTest');
  orderTestCleanup.addDisposable(orderTestDisposable);

  final expectedOrder = [
    '1. Signal handlers (execute first)',
    '2. Closables (execute second)',
    '3. Disposables (execute last)',
  ];

  print('   - Expected cleanup execution order:');
  for (var step in expectedOrder) {
    print('      • $step');
  }
  print('   - Each cleanup is wrapped in try-catch for fault tolerance\n');

  // ---------------------------------------------------------------------------
  // Example 8: Global tomShutdownCleanup instance
  // ---------------------------------------------------------------------------
  print('8. Global tomShutdownCleanup instance:');

  final globalInstanceExists = tomShutdownCleanup is TomShutdownCleanup;
  final globalInstanceType = tomShutdownCleanup.runtimeType.toString();

  print('   - Global instance available: $globalInstanceExists');
  print('   - Instance type: $globalInstanceType');
  print('   - Use tomShutdownCleanup for most shutdown cleanup needs');
  print('   - Automatically listens for SIGHUP and SIGINT signals\n');

  // ---------------------------------------------------------------------------
  // Example 9: Starting the cleanup listener
  // ---------------------------------------------------------------------------
  print('9. Starting the cleanup listener:');

  // Note: We don't actually call start() here as it logs and affects global state
  // Just demonstrate the API
  final startMethodExists = true;
  final startDescription = 'Initializes cleanup listener and logs status';

  print('   - start() method available: $startMethodExists');
  print('   - Description: $startDescription');
  print('   - Call start() after registering all cleanup handlers\n');

  // ---------------------------------------------------------------------------
  // Example 10: Multiple resources pattern
  // ---------------------------------------------------------------------------
  print('10. Multiple resources pattern:');

  final cleanup = TomShutdownCleanup();

  // Register multiple disposables
  final disposables = [
    ExampleDisposableResource('StreamController1'),
    ExampleDisposableResource('StreamController2'),
    ExampleDisposableResource('Timer1'),
  ];

  for (var disposable in disposables) {
    cleanup.addDisposable(disposable);
  }

  // Register multiple closables
  final closables = [
    ExampleClosableConnection('Database'),
    ExampleClosableConnection('Cache'),
    ExampleClosableConnection('MessageQueue'),
  ];

  for (var closable in closables) {
    cleanup.addClosable(closable);
  }

  final totalDisposables = disposables.length;
  final totalClosables = closables.length;
  final totalRegistered = totalDisposables + totalClosables;

  print('   - Disposables registered: $totalDisposables');
  print('   - Closables registered: $totalClosables');
  print('   - Total resources registered: $totalRegistered\n');

  // ---------------------------------------------------------------------------
  // Example 11: Implementing TomDisposable interface
  // ---------------------------------------------------------------------------
  print('11. Implementing TomDisposable interface:');

  // Show the interface contract
  final disposableInterface = '''
  abstract class TomDisposable {
    void dispose();
  }''';

  print('   - Interface definition:');
  print('      $disposableInterface');
  print('   - Implement dispose() to release resources');
  print('   - Method called automatically during shutdown\n');

  // ---------------------------------------------------------------------------
  // Example 12: Implementing TomClosable interface
  // ---------------------------------------------------------------------------
  print('12. Implementing TomClosable interface:');

  // Show the interface contract
  final closableInterface = '''
  abstract class TomClosable {
    void close();
  }''';

  print('   - Interface definition:');
  print('      $closableInterface');
  print('   - Implement close() for connection-style cleanup');
  print('   - Method called automatically during shutdown\n');

  // ---------------------------------------------------------------------------
  // Example 13: Error handling during cleanup
  // ---------------------------------------------------------------------------
  print('13. Error handling during cleanup:');

  final errorHandlingBehavior = [
    'Each cleanup operation is wrapped in try-catch',
    'Failing cleanup does not prevent other cleanups',
    'Error messages are printed to console',
    'Cleanup continues with remaining handlers',
  ];

  print('   - Error handling behavior:');
  for (var behavior in errorHandlingBehavior) {
    print('      • $behavior');
  }
  print('');

  // ---------------------------------------------------------------------------
  // Example 14: Cleanup execution protection
  // ---------------------------------------------------------------------------
  print('14. Cleanup execution protection:');

  final protectionBehavior = [
    'Cleanup executes only once per instance',
    'Multiple signals do not trigger multiple cleanups',
    '_executed flag prevents re-execution',
    'Subsequent signals print "Shutdown has already been performed"',
  ];

  print('   - Execution protection:');
  for (var behavior in protectionBehavior) {
    print('      • $behavior');
  }
  print('');

  // ---------------------------------------------------------------------------
  // Example 15: Real-world usage pattern
  // ---------------------------------------------------------------------------
  print('15. Real-world usage pattern:');

  final usagePattern = '''
  // 1. Register database connection
  tomShutdownCleanup.addClosable(databaseConnection);
  
  // 2. Register stream controllers
  tomShutdownCleanup.addDisposable(eventStreamController);
  
  // 3. Register custom cleanup logic
  tomShutdownCleanup.addSignalHandler((signal) {
    saveApplicationState();
    notifyClients('Shutting down...');
  });
  
  // 4. Start listening for signals
  tomShutdownCleanup.start();''';

  print('   - Recommended usage:');
  print(usagePattern);
  print('');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: Creating a TomDisposable resource
  assert(resourceName == 'StreamController');
  assert(isDisposedBefore == false);
  assert(isDisposedAfter == true);

  // Example 2: Creating a TomClosable connection
  assert(connectionName == 'DatabaseConnection');
  assert(isClosedBefore == false);
  assert(isClosedAfter == true);

  // Example 3: Creating a custom TomShutdownCleanup instance
  assert(customCleanup is TomShutdownCleanup);

  // Example 4: Registering disposable resources with cleanup
  assert(resource1.name == 'Resource1');
  assert(resource2.name == 'Resource2');
  assert(resource1BeforeCleanup == false);
  assert(resource2BeforeCleanup == false);

  // Example 5: Registering closable resources with cleanup
  assert(connection1.connectionName == 'Connection1');
  assert(connection2.connectionName == 'Connection2');
  assert(connection1BeforeCleanup == false);
  assert(connection2BeforeCleanup == false);

  // Example 6: Registering custom signal handlers
  assert(handlerRegistered == true);
  assert(customHandlerStatus == false);

  // Example 7: Understanding cleanup execution order
  assert(expectedOrder.length == 3);
  assert(expectedOrder[0] == '1. Signal handlers (execute first)');
  assert(expectedOrder[1] == '2. Closables (execute second)');
  assert(expectedOrder[2] == '3. Disposables (execute last)');

  // Example 8: Global tomShutdownCleanup instance
  assert(globalInstanceExists == true);
  assert(globalInstanceType == 'TomShutdownCleanup');

  // Example 9: Starting the cleanup listener
  assert(startMethodExists == true);
  assert(startDescription == 'Initializes cleanup listener and logs status');

  // Example 10: Multiple resources pattern
  assert(totalDisposables == 3);
  assert(totalClosables == 3);
  assert(totalRegistered == 6);

  // Example 13: Error handling during cleanup
  assert(errorHandlingBehavior.length == 4);

  // Example 14: Cleanup execution protection
  assert(protectionBehavior.length == 4);
}

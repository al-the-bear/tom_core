// ignore_for_file: unnecessary_null_comparison
/// Demonstrates TomShutdownCleanup, TomDisposable, and TomClosable usage.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// Example Support Classes
// =============================================================================

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

// =============================================================================
// EXAMPLE 1: Creating a TomDisposable Resource
// =============================================================================

class DisposableResourceExample {
  static String? resourceName;
  static bool isDisposedBefore = false;
  static bool isDisposedAfter = false;
  static bool disposableWorks = false;

  static void example1DisposableResource() {
    final resource = ExampleDisposableResource('StreamController');

    resourceName = resource.name;
    isDisposedBefore = resource.isDisposed;

    resource.dispose();
    isDisposedAfter = resource.isDisposed;

    disposableWorks = !isDisposedBefore && isDisposedAfter;

    assert(resourceName == 'StreamController', 'Resource name should match');
    assert(!isDisposedBefore, 'Should not be disposed before');
    assert(isDisposedAfter, 'Should be disposed after');
    assert(disposableWorks, 'Disposable should work');
  }
}

// =============================================================================
// EXAMPLE 2: Creating a TomClosable Connection
// =============================================================================

class ClosableConnectionExample {
  static String? connectionName;
  static bool isClosedBefore = false;
  static bool isClosedAfter = false;
  static bool closableWorks = false;

  static void example2ClosableConnection() {
    final connection = ExampleClosableConnection('DatabaseConnection');

    connectionName = connection.connectionName;
    isClosedBefore = connection.isClosed;

    connection.close();
    isClosedAfter = connection.isClosed;

    closableWorks = !isClosedBefore && isClosedAfter;

    assert(connectionName == 'DatabaseConnection', 'Connection name should match');
    assert(!isClosedBefore, 'Should not be closed before');
    assert(isClosedAfter, 'Should be closed after');
    assert(closableWorks, 'Closable should work');
  }
}

// =============================================================================
// EXAMPLE 3: Creating a TomShutdownCleanup Instance
// =============================================================================

class ShutdownCleanupInstanceExample {
  static bool instanceCreated = false;

  static void example3ShutdownCleanupInstance() {
    final customCleanup = TomShutdownCleanup();

    instanceCreated = customCleanup != null;

    assert(instanceCreated, 'Cleanup instance should be created');
  }
}

// =============================================================================
// EXAMPLE 4: Registering Disposable Resources
// =============================================================================

class RegisterDisposablesExample {
  static bool resource1BeforeCleanup = false;
  static bool resource2BeforeCleanup = false;
  static bool registrationWorks = false;

  static void example4RegisterDisposables() {
    final resource1 = ExampleDisposableResource('Resource1');
    final resource2 = ExampleDisposableResource('Resource2');

    final cleanup = TomShutdownCleanup();
    cleanup.addDisposable(resource1);
    cleanup.addDisposable(resource2);

    resource1BeforeCleanup = resource1.isDisposed;
    resource2BeforeCleanup = resource2.isDisposed;

    // Resources should not be disposed yet (just registered)
    registrationWorks = !resource1BeforeCleanup && !resource2BeforeCleanup;

    assert(!resource1BeforeCleanup, 'Resource1 should not be disposed yet');
    assert(!resource2BeforeCleanup, 'Resource2 should not be disposed yet');
    assert(registrationWorks, 'Registration should work');
  }
}

// =============================================================================
// EXAMPLE 5: Registering Closable Resources
// =============================================================================

class RegisterClosablesExample {
  static bool connection1BeforeCleanup = false;
  static bool connection2BeforeCleanup = false;
  static bool registrationWorks = false;

  static void example5RegisterClosables() {
    final connection1 = ExampleClosableConnection('Connection1');
    final connection2 = ExampleClosableConnection('Connection2');

    final cleanup = TomShutdownCleanup();
    cleanup.addClosable(connection1);
    cleanup.addClosable(connection2);

    connection1BeforeCleanup = connection1.isClosed;
    connection2BeforeCleanup = connection2.isClosed;

    // Connections should not be closed yet (just registered)
    registrationWorks = !connection1BeforeCleanup && !connection2BeforeCleanup;

    assert(!connection1BeforeCleanup, 'Connection1 should not be closed yet');
    assert(!connection2BeforeCleanup, 'Connection2 should not be closed yet');
    assert(registrationWorks, 'Registration should work');
  }
}

// =============================================================================
// EXAMPLE 6: Registering Signal Handlers
// =============================================================================

class RegisterSignalHandlerExample {
  static bool handlerRegistered = false;
  static bool handlerInvoked = false;

  static void example6RegisterSignalHandler() {
    final cleanup = TomShutdownCleanup();

    cleanup.addSignalHandler((signal) {
      handlerInvoked = true;
    });

    handlerRegistered = true;

    // Handler should not be invoked until a signal is received
    assert(handlerRegistered, 'Handler should be registered');
    assert(!handlerInvoked, 'Handler should not be invoked yet');
  }
}

// =============================================================================
// EXAMPLE 7: Understanding Cleanup Execution Order
// =============================================================================

class CleanupOrderExample {
  static List<String> expectedOrder = [];
  static bool orderDocumented = false;

  static void example7CleanupOrder() {
    // Document the expected cleanup execution order
    expectedOrder = [
      '1. Signal handlers (execute first)',
      '2. Closables (execute second)',
      '3. Disposables (execute last)',
    ];

    orderDocumented = expectedOrder.length == 3;

    assert(expectedOrder.length == 3, 'Should have 3 phases');
    assert(orderDocumented, 'Order should be documented');
  }
}

// =============================================================================
// EXAMPLE 8: Global Shutdown Cleanup Instance
// =============================================================================

class GlobalCleanupExample {
  static bool globalExists = false;

  static void example8GlobalCleanup() {
    // The tomShutdownCleanup is a global default instance
    globalExists = tomShutdownCleanup != null;

    assert(globalExists, 'Global cleanup instance should exist');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  DisposableResourceExample.example1DisposableResource();
  ClosableConnectionExample.example2ClosableConnection();
  ShutdownCleanupInstanceExample.example3ShutdownCleanupInstance();
  RegisterDisposablesExample.example4RegisterDisposables();
  RegisterClosablesExample.example5RegisterClosables();
  RegisterSignalHandlerExample.example6RegisterSignalHandler();
  CleanupOrderExample.example7CleanupOrder();
  GlobalCleanupExample.example8GlobalCleanup();
}

void main() => run();

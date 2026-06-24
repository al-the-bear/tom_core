# Shutdown Cleanup Module

The shutdown cleanup module provides a comprehensive system for managing graceful process termination in Tom applications. It ensures that resources are properly released and cleanup handlers are executed in an orderly fashion before the process exits.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Best Practices](#best-practices)
- [Limitations](#limitations)
- [Dependencies](#dependencies)

---

## Overview

When a process receives termination signals (like SIGHUP or SIGINT from Ctrl+C), the shutdown cleanup system:

1. Intercepts the signal
2. Executes all registered signal handlers
3. Closes all registered closable objects
4. Disposes all registered disposable objects
5. Marks the cleanup as complete to prevent duplicate execution

The system is designed to be fault-tolerant—if one cleanup operation fails, it logs the error and continues with the remaining operations.

## Quick Start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  // Register resources for cleanup
  final database = DatabaseConnection();
  final cache = CacheManager();
  
  tomShutdownCleanup.addClosable(database);
  tomShutdownCleanup.addDisposable(cache);
  
  // Start the cleanup listener
  tomShutdownCleanup.start();
  
  // Your application logic here...
}
```

## Core Components

### Interfaces

#### TomDisposable

Interface for objects that need cleanup via a `dispose()` method.

```dart
class MyStreamManager implements TomDisposable {
  final StreamController _controller = StreamController();
  
  @override
  void dispose() {
    _controller.close();
    print('StreamManager disposed');
  }
}
```

#### TomClosable

Interface for objects that need cleanup via a `close()` method.

```dart
class MyConnection implements TomClosable {
  Socket? _socket;
  
  @override
  void close() {
    _socket?.close();
    print('Connection closed');
  }
}
```

### TomCloseAdaptor

Wraps third-party objects that have close/dispose methods but don't implement the Tom interfaces.

```dart
// Wrap an object with a standard close() method
final httpClient = HttpClient();
final adaptor = TomCloseAdaptor(httpClient);
tomShutdownCleanup.addClosable(adaptor);

// Specify a custom method name
final customObject = MyObject();
final customAdaptor = TomCloseAdaptor(customObject, 'shutdown');
tomShutdownCleanup.addClosable(customAdaptor);
```

### TomShutdownCleanup

The main coordinator class that manages all cleanup operations.

#### Default Signals

By default, `TomShutdownCleanup` listens for:
- `SIGHUP` - Hangup signal
- `SIGINT` - Interrupt signal (Ctrl+C)

#### Adding Additional Signals

```dart
// Also handle SIGTERM
tomShutdownCleanup.addSignal(ProcessSignal.sigterm);
```

## Usage Examples

### Basic Resource Cleanup

```dart
void main() {
  final db = DatabaseConnection.connect();
  final redis = RedisClient.connect();
  
  tomShutdownCleanup.addClosable(db);
  tomShutdownCleanup.addClosable(redis);
  tomShutdownCleanup.start();
  
  // Application runs...
  // On Ctrl+C: db.close() and redis.close() are called automatically
}
```

### Custom Signal Handlers

```dart
tomShutdownCleanup.addSignalHandler((signal) {
  print('Shutting down due to $signal');
  
  // Custom cleanup logic
  saveApplicationState();
  notifyConnectedClients();
  flushLogs();
});
```

### Multiple Cleanup Instances

For specialized handling of different signals:

```dart
// Main cleanup for standard signals
tomShutdownCleanup.addClosable(mainDatabase);
tomShutdownCleanup.start();

// Separate handler for user-defined signals
final debugCleanup = TomShutdownCleanup();
debugCleanup.addSignal(ProcessSignal.sigusr1);
debugCleanup.addSignalHandler((signal) {
  print('Debug info requested');
  dumpDebugState();
});
```

### Server Application Pattern

```dart
class MyServer {
  late HttpServer _server;
  
  Future<void> start() async {
    _server = await HttpServer.bind('localhost', 8080);
    
    // Register server for graceful shutdown
    tomShutdownCleanup.addSignalHandler((signal) async {
      print('Shutting down server...');
      await _server.close(force: false);
    });
    
    tomShutdownCleanup.start();
    
    await for (final request in _server) {
      handleRequest(request);
    }
  }
}
```

## Execution Order

When a signal is received, cleanup operations execute in this order:

1. **Signal Handlers** - Custom functions added via `addSignalHandler()`
2. **Closables** - Objects added via `addClosable()`
3. **Disposables** - Objects added via `addDisposable()`

Within each category, items are processed in the order they were registered.

## Best Practices

### 1. Register Early

Register cleanup handlers as soon as resources are created:

```dart
final connection = await Database.connect();
tomShutdownCleanup.addClosable(connection); // Register immediately
```

### 2. Use Appropriate Interfaces

- Use `TomClosable` for resources that need to be closed (connections, files, sockets)
- Use `TomDisposable` for resources that need disposal (controllers, subscriptions)
- Use signal handlers for complex cleanup logic

### 3. Handle Errors in Custom Handlers

The system catches exceptions, but it's good practice to handle errors in your handlers:

```dart
tomShutdownCleanup.addSignalHandler((signal) {
  try {
    riskyCleanupOperation();
  } catch (e) {
    print('Cleanup warning: $e');
    // Continue with other cleanup
  }
});
```

### 4. Call start() Last

Call `start()` after registering all handlers to get accurate logging:

```dart
tomShutdownCleanup.addClosable(db);
tomShutdownCleanup.addDisposable(cache);
tomShutdownCleanup.addSignalHandler(customHandler);
tomShutdownCleanup.start(); // Call last
```

### 5. Don't Block Indefinitely

Cleanup operations should complete quickly. For async operations, consider timeouts:

```dart
tomShutdownCleanup.addSignalHandler((signal) async {
  await Future.any([
    slowCleanupOperation(),
    Future.delayed(Duration(seconds: 5)),
  ]);
});
```

### 6. Use TomCloseAdaptor for Third-Party Objects

When working with objects you don't control:

```dart
final externalClient = ThirdPartyClient();
tomShutdownCleanup.addClosable(TomCloseAdaptor(externalClient));
```

## Limitations

- The cleanup system uses `print()` for logging during shutdown (not the full logging system) to ensure output even if logging is affected
- Cleanup executes only once—subsequent signals are ignored after the first cleanup completes
- On some platforms, certain signals may not be available
- `TomCloseAdaptor` requires the object's class to be registered with the Tom reflector

---

## Dependencies

This module depends on:

- **Logging Module**: For logging during shutdown
- **Observable Module**: Provides the reflector used by `TomCloseAdaptor`

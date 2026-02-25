# Isolate Pooling Module

The isolate pooling module provides a robust framework for managing Dart isolates, enabling parallel processing and concurrent task execution in Dart and Flutter applications.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

---

## Overview

Dart isolates are independent execution contexts with their own memory space. While this provides true parallelism, managing isolate lifecycle and communication can be complex. This module abstracts away the complexity while providing:

- **Worker Isolates**: Spawn and manage isolated execution contexts
- **Bidirectional Communication**: Send commands to workers and receive responses
- **Command Pattern**: Execute commands as self-contained objects
- **Executor Pattern**: Register handlers to process incoming messages
- **Worker Pools**: Manage multiple workers with automatic load distribution

## Quick Start

### 1. Create a Worker Context

```dart
final context = TomWorkerContext(
  TomEnvironment.development,
  TomPlatform.mobile,
  [],
  'Worker', // Name prefix for isolates
);
```

### 2. Spawn a Worker

```dart
final worker = await TomWorker.spawn(
  TomWorker.startRemoteIsolate,
  context,
);
```

### 3. Execute Commands

```dart
// Using TomCommand
class ComputeCommand extends TomCommand {
  final int value;
  ComputeCommand(this.value);

  @override
  Future<Object?> execute() async {
    return computeIntensive(value);
  }
}

final result = await worker.executeCommand(ComputeCommand(42));
```

### 4. Clean Up

```dart
worker.close();
```

## Core Components

### TomWorker

The main class for managing worker isolates. Handles spawning, communication, and lifecycle management.

| Property/Method | Description |
|-----------------|-------------|
| `spawn()` | Factory method to create a new worker |
| `executeCommand()` | Send a command and await the result |
| `sendExecutorToIsolate()` | Add an executor to the worker |
| `close()` | Shutdown the worker |
| `isReady` | Whether the worker is ready for commands |
| `isBusy()` | Whether the worker has pending requests |
| `isClosed` | Whether the worker has been closed |

#### Static Methods (for use in worker isolates)

| Method | Description |
|--------|-------------|
| `sendToCreator()` | Send a message to the creator (fire-and-forget) |
| `executeInCreator()` | Execute a command in the creator and await result |
| `canSendToCreator()` | Check if backchannel is available |
| `isMainIsolate` | Whether running in the main isolate |

### TomWorkerContext

Configuration context for initializing worker isolates.

```dart
class MyWorkerContext extends TomWorkerContext {
  MyWorkerContext() : super(
    TomEnvironment.development,
    TomPlatform.mobile,
    [],
    'MyWorker',
  );

  @override
  Future<bool> initializeIsolate() async {
    // Called in the new isolate (static context)
    await setupResources();
    return true;
  }

  @override
  Future<bool> initializeWorker(TomWorker worker) async {
    // Called on the TomWorker instance
    worker.sendExecutorToIsolate(MyExecutor());
    return true;
  }
}
```

### TomExecutor

Base class for command handlers. Register multiple executors to handle different command types.

```dart
class DataProcessorExecutor extends TomExecutor {
  @override
  Object execute(Object command) {
    if (command is ProcessDataCommand) {
      return processData(command.data);
    }
    return TomExecutor.noResult; // Let next executor handle it
  }
}

// Register executor
TomWorker.executors.add(DataProcessorExecutor());
```

### TomCommand

Base class for self-executing commands that encapsulate both data and behavior.

```dart
class CalculateHashCommand extends TomCommand {
  final String input;
  CalculateHashCommand(this.input);

  @override
  Future<Object?> execute() async {
    return sha256.convert(utf8.encode(input)).toString();
  }
}
```

### TomWorkerPool

Manages a pool of workers for automatic load distribution.

```dart
// Create pool
final pool = await TomWorkerPool.withSize(4, context);

// Execute commands (automatically distributed)
final results = await Future.wait([
  pool.execute(command1),
  pool.execute(command2),
  pool.execute(command3),
  pool.execute(command4),
]);
```

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                       Main Isolate                           │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  │
│  │   TomWorker    │  │   TomWorker    │  │   TomWorker    │  │
│  │   (instance)   │  │   (instance)   │  │   (instance)   │  │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘  │
└──────────┼───────────────────┼───────────────────┼───────────┘
           │ SendPort          │ SendPort          │ SendPort
           ▼                   ▼                   ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  Worker Isolate  │  │  Worker Isolate  │  │  Worker Isolate  │
│  ┌────────────┐  │  │  ┌────────────┐  │  │  ┌────────────┐  │
│  │ Executors  │  │  │  │ Executors  │  │  │  │ Executors  │  │
│  └────────────┘  │  │  └────────────┘  │  │  └────────────┘  │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

## Usage Examples

### Example 1: CPU-Intensive Computation

```dart
class FibonacciCommand extends TomCommand {
  final int n;
  FibonacciCommand(this.n);

  @override
  Future<Object?> execute() async {
    return _fibonacci(n);
  }

  int _fibonacci(int n) {
    if (n <= 1) return n;
    return _fibonacci(n - 1) + _fibonacci(n - 2);
  }
}

// Execute in worker to avoid blocking UI
final result = await worker.executeCommand(FibonacciCommand(40));
```

### Example 2: Parallel Image Processing

```dart
final pool = await TomWorkerPool.withSize(4, context);

final images = ['image1.png', 'image2.png', 'image3.png', 'image4.png'];

final processedImages = await Future.wait(
  images.map((path) => pool.execute(ProcessImageCommand(path))),
);
```

### Example 3: Bidirectional Communication

```dart
// In worker isolate - request data from main isolate
class FetchConfigExecutor extends TomExecutor {
  @override
  Object execute(Object command) {
    if (command is NeedsConfigCommand) {
      // Request config from main isolate
      return TomWorker.executeInCreator(GetConfigCommand());
    }
    return TomExecutor.noResult;
  }
}
```

### Example 4: Custom Worker Context

```dart
class DatabaseWorkerContext extends TomWorkerContext {
  final String connectionString;

  DatabaseWorkerContext(this.connectionString) : super(
    TomEnvironment.production,
    TomPlatform.server,
    [],
    'DB',
  );

  @override
  Future<bool> initializeIsolate() async {
    // Initialize database connection in the isolate
    await Database.connect(connectionString);
    return true;
  }
}
```

## Best Practices

### 1. Choose the Right Pattern

| Scenario | Recommended Pattern |
|----------|---------------------|
| Self-contained operations | `TomCommand` |
| Multiple related operations | `TomExecutor` |
| Many similar parallel tasks | `TomWorkerPool` |
| Single long-running worker | `TomWorker` |

### 2. Pool Sizing

- For CPU-bound tasks: `Platform.numberOfProcessors` workers
- For I/O-bound tasks: More workers may be beneficial
- Consider memory overhead per isolate

### 3. Error Handling

```dart
try {
  final result = await worker.executeCommand(command);
} on RemoteError catch (e) {
  // Handle errors from the worker isolate
  print('Worker error: $e');
}
```

### 4. Avoid Common Pitfalls

- **Don't share mutable state**: Isolates have separate memory
- **Keep messages serializable**: Objects must be sendable across isolate boundaries
- **Clean up resources**: Always call `close()` when done with workers
- **Handle worker failures**: Implement health checks for long-running pools

### 5. Logging Considerations

When using logging in workers that delegate to a logging isolate, avoid logging within `sendToCreator()` to prevent stack overflow. Use `print()` for debugging in such cases.

## API Reference

See the source code documentation in [tom_worker.dart](tom_worker.dart) for detailed API reference.

---

## Dependencies

This module depends on:

- **Runtime Module**: `TomEnvironment` and `TomPlatform` for worker context configuration
- **Logging Module**: For logging within worker isolates

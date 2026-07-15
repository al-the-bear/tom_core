# Tom Core Kernel API Reference: Isolate Pooling Module

A framework for spawning and managing worker isolates for concurrent task
execution, with bidirectional communication, self-executing commands, pluggable
executors, and load-balancing worker pools.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomWorkerException](#tomworkerexception)
  - [TomExecutor](#tomexecutor)
  - [TomCommand](#tomcommand)
  - [TomWorkerContext](#tomworkercontext)
  - [TomWorker](#tomworker)
  - [TomWorkerPool](#tomworkerpool)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tombase/isolate_pooling/tom_worker.dart`.

The Isolate Pooling module manages Dart isolates for parallel processing.
`TomWorker` spawns a worker isolate and manages bidirectional communication with
it, letting the creator send commands (`executeCommand`) and the worker call
back into the creator (`sendToCreator` / `executeInCreator`). Work is expressed
either as a self-executing `TomCommand` (data plus behavior, its `execute` run
automatically) or as an arbitrary object handled by registered `TomExecutor`
instances, which are tried in order until one returns something other than
`TomExecutor.noResult`. `TomWorkerContext` carries the environment/platform
configuration and initialization hooks used when spawning. `TomWorkerPool`
manages several workers, distributing commands across them and queuing when all
are busy. `TomWorkerException` signals worker communication and state errors.

## Class Hierarchy

```
TomException  (kernel)
    └── TomWorkerException

TomExecutor

TomCommand

TomWorkerContext

TomWorker

TomWorkerPool
```

## Classes

### TomWorkerException

Exception thrown when worker-related operations fail, e.g. starting an isolate
without a configured SendPort, sending to the creator from the creator isolate,
or general worker communication failures.

- **Extends:** `TomException`

#### Constructors

```dart
TomWorkerException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  StackTrace? stack,
  Object? rootException,
  bool? autoLog,
  String? uuid,
  bool? serverCallError,
})
```

### TomExecutor

Abstract base class for command executors that handle messages in worker
isolates. Executors are called in order until one produces a result other than
`noResult`.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `noResult` | `Object` | Sentinel returned from `execute` to indicate the command was not handled, letting the next executor in the chain try it. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Object execute(Object command)` | Executes `command` and returns its result, or `noResult` if this executor cannot handle it. Called in both creator and worker isolates. |

### TomCommand

Abstract base class for self-executing commands sent to worker isolates. When a
command is received, its `execute` method is called automatically.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Future<Object?> execute()` | Executes this command and returns the result; override to implement the command's logic. The default returns the string `"null"`. |

### TomWorkerContext

Configuration context for initializing worker isolates, holding environment
configuration and providing hooks for custom isolate- and worker-level
initialization.

#### Constructors

```dart
TomWorkerContext(
  TomEnvironment tomEnvironment,
  TomPlatform tomPlatform,
  List<String> args,
  String namePrefix,
)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `tomEnvironment` | `TomEnvironment` | The environment configuration (development, staging, production). |
| `tomPlatform` | `TomPlatform` | The platform this worker is running on. |
| `args` | `List<String>` | Command-line arguments passed to the worker. |
| `namePrefix` | `String` | Prefix for naming worker isolates (e.g. `"W"` produces `"W001"`); defaults to `"W"`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `initializeIsolate` | `Future<bool> initializeIsolate()` | Called in a static context inside the newly created isolate; override for isolate-level setup. Returns `true` on success (default). |
| `initializeWorker` | `Future<bool> initializeWorker(TomWorker worker)` | Called on the newly created `TomWorker`; override to configure the worker (e.g. register executors). Returns `true` on success (default). |

### TomWorker

Manages communication with a worker isolate: spawning it and handling
bidirectional command/response messaging with the main isolate.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `workerCount` | `int` | Counter used to generate unique worker names. |
| `isMainIsolate` | `bool` | Whether the current code runs in the main isolate; set to `false` inside a worker isolate. |
| `readyMessage` | `String` | Message a worker sends when it is ready to accept commands (`"--- ready ---"`). |
| `executors` | `List<TomExecutor>` | Executors registered to handle incoming commands, tried in order. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isReady` | `bool` | Whether this worker is ready to accept commands. |
| `isClosed` | `bool` | Whether this worker has been closed (getter). |
| `isolate` | `Isolate` | The underlying Dart `Isolate` instance (final). |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `spawn` | `static Future<TomWorker> spawn(void Function(TomWorkerContext) initializer, TomWorkerContext workerContext)` | Primary factory: spawns a worker isolate, sets up ports, runs initialization, and completes when the worker is ready. |
| `startRemoteIsolate` | `static void startRemoteIsolate(TomWorkerContext context)` | Isolate entry point passed to `spawn`; wires up communication channels and runs the context's isolate initialization. Throws `TomWorkerException` if the context's SendPort is null. |
| `canSendToCreator` | `static bool canSendToCreator()` | Returns `true` only inside a worker isolate, where a backchannel to the creator exists. |
| `sendToCreator` | `static void sendToCreator(Object o)` | Fire-and-forget send of `o` to the creator isolate. Throws `TomWorkerException` if called from the main isolate. |
| `executeInCreator` | `static Future<Object?> executeInCreator(Object command)` | Executes `command` in the creator isolate and awaits its result. Throws `TomWorkerException` if called from the main isolate. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isBusy` | `bool isBusy()` | Returns `true` if this worker has pending requests. |
| `executeCommand` | `Future<Object?> executeCommand(Object command)` | Sends `command` to the worker isolate and awaits its result. |
| `sendExecutorToIsolate` | `void sendExecutorToIsolate(TomExecutor te)` | Sends an executor to the worker isolate, adding it to the worker's executor list. |
| `close` | `void close()` | Closes this worker, sends the isolate a shutdown signal, and releases resources. |

### TomWorkerPool

Manages a pool of worker isolates for parallel task execution, distributing
commands across workers and queuing requests when all are busy.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `withSize` | `static Future<TomWorkerPool> withSize(int size, TomWorkerContext context)` | Creates a pool of `size` workers, each spawned with `context`, completing when all workers are ready. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Future<Object?> execute(Object command)` | Executes `command` on an available worker, waiting (polling every 1ms) if all are busy, then returns the worker to the pool. |
| `close` | `void close()` | Shuts down every worker in the pool via `TomWorker.close` and empties the pool; the pool must not be reused. |

## Global Functions and Constants

None — this module exposes no top-level functions or constants.

# Tom Core Kernel API Reference: Isolate Pooling Module

A framework for spawning and managing worker isolates for concurrent task
execution, with bidirectional communication, self-executing commands, pluggable
executors, and load-balancing worker pools.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomWorkerException](#tomworkerexception)
  - [TomWorkerDiedException](#tomworkerdiedexception)
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
`TomExecutor.noResult`. Should the whole chain decline — or should the worker
have no executor registered at all — the command is still answered, with
`noResult` itself, so `executeCommand` always resolves. No response payload is
ever `null`: a result of `null` is substituted before it is sent, with the
string `"null"` in the worker-bound direction and with `noResult` in the
creator-bound one, so neither `executeCommand` nor `executeInCreator` can
resolve to `null` despite their `Future<Object?>` signatures.
`TomWorkerContext` carries the environment/platform
configuration and initialization hooks used when spawning. `TomWorkerPool`
manages several workers, distributing commands across them and queuing when all
are busy — and, when a `healthCheckInterval` is supplied, supervises their
liveness so a dead worker fails its in-flight command and is replaced.
`TomWorkerException` signals worker communication and state errors;
`TomWorkerDiedException` signals that a supervised worker's isolate terminated
unexpectedly.

## Class Hierarchy

```
TomException  (kernel)
    ├── TomWorkerException
    └── TomWorkerDiedException

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
executing on a closed `TomWorkerPool`, a startup that never reaches ready, or
general worker communication failures.

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

### TomWorkerDiedException

Exception completing every request that was still in flight when a supervised
worker's isolate terminated unexpectedly — an uncaught error, `Isolate.kill`, or
an out-of-memory kill. Without supervision such requests hang on their completer
forever.

The failed command is **not** re-dispatched: re-running work that may already
have produced side effects risks executing non-idempotent work twice. Recovery
restores capacity (the pool respawns a replacement worker) while the caller
observes the failure and decides how to react.

- **Extends:** `TomException`
- **Key:** `isolate.worker_died.in_flight_request`
- **Parameters:** `isolateName` — the `name` of the worker that died

#### Constructors

```dart
TomWorkerDiedException(
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
| `noResult` | `Object` | Sentinel returned from `execute` to indicate the command was not handled, letting the next executor in the chain try it. Also the value the dispatch answers with once the chain is exhausted, so it reaches the caller of `executeCommand` meaning "nothing handled this". Identity-compared — it has no value equality. |

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
| `execute` | `Future<Object?> execute()` | Executes this command and returns the result; override to implement the command's logic. The default returns the string `"null"` — the same value the worker-bound dispatch substitutes for a `null` result, so an unoverridden command is indistinguishable from one that legitimately resolved to `null`. |

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
| `tomEnvironment` | `TomEnvironment` | The environment configuration (development, staging, production) (final). |
| `tomPlatform` | `TomPlatform` | The platform this worker is running on (final). |
| `args` | `List<String>` | Command-line arguments passed to the worker (final). |
| `namePrefix` | `String` | Prefix for naming worker isolates; `spawn` appends a zero-based three-digit counter, so `"W"` names the first worker `W000` and the second `W001`. Required, with no default (final). |

All four are fixed at construction: a context is read when a worker is spawned,
so a later change could not reach a worker that is already running.

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `initializeIsolate` | `Future<void> initializeIsolate()` | Called in a static context inside the newly created isolate; override for isolate-level setup. Signal failure by throwing: the refusal reaches the caller of `spawn` as a `TomWorkerException` keyed `isolate.initialize_isolate_failed.spawn`, and the half-started isolate is torn down. |
| `initializeWorker` | `Future<void> initializeWorker(TomWorker worker)` | Called on the newly created `TomWorker`; override to configure the worker (e.g. register executors). Signal failure by throwing: the throw propagates out of `spawn` and the isolate is torn down. |

### TomWorker

Manages communication with a worker isolate: spawning it and handling
bidirectional command/response messaging with the main isolate.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `workerCount` | `int` (getter) | Read-only count of workers created in this isolate; used to generate unique worker names. |
| `isMainIsolate` | `bool` (getter) | Read-only: whether the current code runs in the main isolate; flips to `false` inside a worker isolate. The flag is load-bearing — the back-channel and the server-side caches branch on it — so it cannot be assigned; tests use `simulateWorkerIsolate` / `resetIsMainIsolate`. |
| `readyMessage` | `String` | Message a worker sends when it is ready to accept commands (`"--- ready ---"`). |
| `executors` | `List<TomExecutor>` (getter) | Read-only, live view of the executors registered to handle incoming commands, tried in order. Register through `addExecutor` / `removeExecutor` / `clearExecutors`; the view itself throws `UnsupportedError` on mutation. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isReady` | `bool` | Whether this worker is ready to accept commands. |
| `isClosed` | `bool` | Whether this worker has been closed (getter). |
| `isolate` | `Isolate` | The underlying Dart `Isolate` instance (final). |
| `name` | `String` | The debug name the isolate was spawned with, e.g. `"W000"` (final). Use this rather than `isolate.debugName`, which is only populated inside the isolate and reads `null` on this side. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `spawn` | `static Future<TomWorker> spawn(void Function(TomWorkerContext) initializer, TomWorkerContext workerContext, {Duration readyTimeout = const Duration(seconds: 30)})` | Primary factory: spawns a worker isolate, sets up ports, runs initialization, and completes when the worker is ready. The startup is supervised, so a worker that cannot become ready fails the future instead of stalling it: an isolate that dies first is reported as soon as its exit is seen (`isolate.died_before_ready.spawn`), and one that stays alive but silent is given up on when `readyTimeout` expires (`isolate.ready_timeout.spawn`). Either way the isolate is killed, since a failed spawn hands back no `TomWorker` to close it with. `readyTimeout` bounds the whole startup — the isolate's first message plus both initialization hooks — and must be positive (`isolate.invalid_ready_timeout.spawn`). |
| `resetWorkerCount` | `@visibleForTesting static void resetWorkerCount()` | Rewinds the worker-name counter. Test-only — rewinding it in production hands two live workers the same name. |
| `addExecutor` | `static void addExecutor(TomExecutor executor)` | Registers `executor` at the end of the dispatch chain. |
| `removeExecutor` | `static bool removeExecutor(TomExecutor executor)` | Removes the first registration of `executor`; returns `false` if it was not registered. |
| `clearExecutors` | `static void clearExecutors()` | Removes every registered executor. |
| `simulateWorkerIsolate` | `@visibleForTesting static void simulateWorkerIsolate()` | Marks the current isolate as a worker. Test-only seam for code that branches on `isMainIsolate` without spawning a real isolate; production reaches this state through `startRemoteIsolate`. |
| `resetIsMainIsolate` | `@visibleForTesting static void resetIsMainIsolate()` | Restores the creator-side marking after `simulateWorkerIsolate`. Test-only — the real transition is one-way. |
| `startRemoteIsolate` | `static void startRemoteIsolate(TomWorkerContext context)` | Isolate entry point passed to `spawn`; wires up communication channels and runs the context's isolate initialization. Throws `TomWorkerException` if the context's SendPort is null. |
| `canSendToCreator` | `static bool canSendToCreator()` | Returns `true` only inside a worker isolate, where a backchannel to the creator exists. |
| `sendToCreator` | `static void sendToCreator(Object o)` | Fire-and-forget send of `o` to the creator isolate. Throws `TomWorkerException` if called from the main isolate. |
| `executeInCreator` | `static Future<Object?> executeInCreator(Object command)` | Executes `command` in the creator isolate and awaits its result, or `TomExecutor.noResult` when nothing there handled it — no creator-side executor is registered, or all of them declined. Every command is answered, so the future always resolves; compare with `identical(result, TomExecutor.noResult)` to recognise the case. A creator result of `null` is substituted with that *same* sentinel — *not* with the string `"null"` the worker-bound direction uses — so this never resolves to `null` either, the two directions are not interchangeable, and the two meanings of the sentinel cannot be told apart here. Throws `TomWorkerException` if called from the main isolate. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isBusy` | `bool isBusy()` | Returns `true` if this worker has pending requests. |
| `executeCommand` | `Future<Object?> executeCommand(Object command)` | Sends `command` to the worker isolate and awaits its result, or `TomExecutor.noResult` when nothing there handled it. Every command is answered, so the future always resolves. It never resolves to `null`: a result of `null` — from a `TomCommand.execute` or from an executor — is delivered as the four-character *string* `"null"`, so a caller writing `await worker.executeCommand(c) as String?` against a nullable-returning command gets `"null"` rather than an error. Throws `TomWorkerException` (`isolate.worker_closed.execute_after_close`) if the worker is closed — the same fail-fast `TomWorkerPool.execute` gives one layer up, rather than a dispatch nothing will answer. |
| `sendExecutorToIsolate` | `void sendExecutorToIsolate(TomExecutor te)` | Sends an executor to the worker isolate, adding it to the worker's executor list. One-way — there is no acknowledgement. Throws `TomWorkerException` (`isolate.worker_closed.send_executor_after_close`) if the worker is closed, rather than dropping the executor on a shutting-down port. |
| `superviseExit` | `void superviseExit(void Function() onDeath)` | Registers a one-shot death callback via `Isolate.addOnExitListener`. On an unexpected exit, every in-flight request is failed with `TomWorkerDiedException` before `onDeath` runs. Idempotent; a no-op once closed. An orderly `close` does not trigger it. |
| `ping` | `Future<bool> ping(Duration timeout)` | Liveness probe; `true` if the worker answered within `timeout`, `false` otherwise. Answered before any command or executor dispatch, so asynchronous in-flight work does not delay it — but a command occupying the isolate *synchronously* does, and this returns `false` for a healthy worker that is merely busy computing. No `isBusy` check is made; pool supervision probes only idle workers for exactly that reason. A timed-out probe abandons its request slot so a late answer is discarded. Never kills the isolate. |
| `killUnresponsive` | `void killUnresponsive()` | Force-kills the isolate at `Isolate.immediate` priority, routing it through the same death/respawn path as a crash. |
| `close` | `void close()` | Closes this worker: tears down exit supervision first (so the shutdown is not read as a death), sends the isolate a shutdown signal, and closes the response port once the last in-flight request resolves. Afterwards `executeCommand` and `sendExecutorToIsolate` throw; commands accepted *before* the close still resolve. Idempotent. |

### TomWorkerPool

Manages a pool of worker isolates for parallel task execution, distributing
commands across workers and queuing requests when all are busy. Liveness
supervision is available but **off by default**.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isSupervised` | `bool` (getter) | Whether liveness supervision is enabled (i.e. a `healthCheckInterval` was supplied). |
| `workerCount` | `int` (getter) | Number of live workers currently registered. Drops when one dies and returns to the pool size once the replacement is ready. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `withSize` | `static Future<TomWorkerPool> withSize(int size, TomWorkerContext context, {Duration? healthCheckInterval, Duration healthCheckTimeout = const Duration(seconds: 5), Duration readyTimeout = const Duration(seconds: 30)})` | Creates a pool of `size` workers, each spawned with `context`, completing when all workers are ready. The context is retained so dead workers can be respawned. A non-null `healthCheckInterval` enables liveness supervision; `healthCheckTimeout` bounds how long a probed idle worker has to answer. `readyTimeout` is forwarded to `TomWorker.spawn` for every worker the pool creates, replacements included — the pool performs all of its callers' spawns, so a bound it did not forward would be one nobody could set. Throws `TomWorkerException` for arguments that would produce a pool unable to do useful work: `size` below 1 (`isolate.invalid_pool_size.with_size`, and the exception carries the rejected `size`), or — when supervision is enabled — a non-positive `healthCheckInterval` (`isolate.invalid_health_check_interval.with_size`) or `healthCheckTimeout` (`isolate.invalid_health_check_timeout.with_size`). The two durations are validated only when `healthCheckInterval` is non-null, since an unsupervised caller never chose them. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `execute` | `Future<Object?> execute(Object command)` | Executes `command` on an available worker, waiting (polling every 1ms) if all are busy, then returns the worker to the pool in a `finally` — a throwing command does not leak its worker, and a worker closed meanwhile is not re-added. Throws `TomWorkerException` if the pool is closed. |
| `close` | `void close()` | Cancels the supervision timer, shuts down every worker via `TomWorker.close`, and empties the pool; the pool must not be reused. |

#### Liveness supervision

Supervision is opt-in — it costs a timer, a raw port per worker, and a periodic
round trip per idle worker, so a pool running trusted, short-lived work does not
pay for it. When `healthCheckInterval` is supplied, two independent mechanisms
run:

1. **Exit detection** per worker, via `TomWorker.superviseExit`. This is the
   primary signal: it fires for every way an isolate can terminate, including
   the cases a request/response probe cannot observe once a command is hung.
   Each in-flight command is failed with `TomWorkerDiedException` and the pool
   respawns a replacement.
2. **Periodic pings of idle workers only**, to catch hangs that emit no exit
   signal. The ping is answered at the top of the worker's message handler,
   before any command or executor dispatch, so it does *not* queue behind
   in-flight work — a worker running asynchronous work answers it immediately.
   Busy workers are skipped because **synchronous** work blocks the isolate's
   event loop: a tight compute loop, the workload this module exists for, would
   leave the probe unread past `healthCheckTimeout` and force-kill a worker
   that is healthy and computing. A busy worker that genuinely crashes is
   covered by mechanism 1 regardless. Each probed worker is reserved out of the
   free list for the duration of its ping, and `execute` returns a worker to
   that list only after its command resolves, so a probe never races a running
   command — `healthCheckTimeout` bounds a round trip to an idle isolate, not
   the runtime of any command. A worker that misses it is force-killed, routing
   it through mechanism 1.

A failed in-flight command is deliberately **not** re-dispatched.

## Global Functions and Constants

None — this module exposes no top-level functions or constants.

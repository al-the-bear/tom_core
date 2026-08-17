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
- **Liveness Supervision**: Opt-in detection and recovery from worker deaths

## Quick Start

### 1. Create a Worker Context

```dart
final context = TomWorkerContext(
  defaultTomEnvironment, // or your own TomEnvironment("staging")
  platformLinux,         // platformMacos, platformWindows, platformWeb, …
  [],
  'Worker',              // Name prefix for isolates
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
| `executeCommand()` | Send a command and await the result; throws `TomWorkerException` once the worker is closed |
| `sendExecutorToIsolate()` | Add an executor to the worker; throws `TomWorkerException` once the worker is closed |
| `close()` | Shutdown the worker; in-flight commands still resolve, new ones are refused |
| `superviseExit()` | Register a death callback; in-flight requests fail instead of hanging |
| `ping()` | Liveness probe with a timeout; never kills the isolate |
| `killUnresponsive()` | Force-kill a hung isolate, routing it through the death path |
| `isReady` | Whether the worker is ready for commands |
| `isBusy()` | Whether the worker has pending requests |
| `isClosed` | Whether the worker has been closed |

#### Static Methods (for use in worker isolates)

| Method | Description |
|--------|-------------|
| `sendToCreator()` | Send a message to the creator (fire-and-forget) |
| `executeInCreator()` | Execute a command in the creator and await result, or `TomExecutor.noResult` if nothing there handled it |
| `canSendToCreator()` | Check if backchannel is available |
| `isMainIsolate` | Whether running in the main isolate (read-only) |

### TomWorkerContext

Configuration context for initializing worker isolates.

```dart
class MyWorkerContext extends TomWorkerContext {
  MyWorkerContext() : super(
    defaultTomEnvironment,
    platformLinux,
    [],
    'MyWorker',
  );

  @override
  Future<void> initializeIsolate() async {
    // Called in the new isolate (static context)
    await setupResources();
  }

  @override
  Future<void> initializeWorker(TomWorker worker) async {
    // Called on the TomWorker instance
    worker.sendExecutorToIsolate(MyExecutor());
  }
}
```

All four constructor arguments are required and fixed at construction; the
context is read at spawn time, so changing one later could not reach a worker
that is already running. The fourth, `namePrefix`, is the stem of every worker
name: `spawn` appends a zero-based, three-digit counter, so the `'MyWorker'`
above names the first worker `MyWorker000` and the second `MyWorker001`. Read
that name back from `worker.name` — `worker.isolate.debugName` is only populated
inside the isolate and reads `null` on the creator side.

Both hooks report failure by throwing. A throw out of either one — directly or
out of the setup it awaits — aborts `TomWorker.spawn` and tears the half-started
isolate down, so a worker whose setup did not complete never joins a pool and
never takes work. An isolate-side refusal reaches the caller as a
`TomWorkerException` with key `isolate.initialize_isolate_failed.spawn`, carrying
the isolate's error and stack in its parameters.

A hook that fails *silently* is bounded too — see
[Bounding the startup](#bounding-the-startup) below.

### Bounding the startup

`spawn` never waits indefinitely for a worker to become ready. Until the ready
signal arrives, the isolate is live but unreachable — no `TomWorker` has been
returned, so the caller has nothing to `close()` — and a startup that quietly
fails to finish would strand the caller on a future that will never complete.
Two watchers cover it, because the ways it can fail are not alike:

- an isolate that **dies** before signalling readiness emits an exit signal but
  no message. An exit listener catches it and fails the spawn at once, with
  `isolate.died_before_ready.spawn`.
- an isolate that **hangs** — an `initializeIsolate` awaiting a resource that
  never arrives — emits nothing at all, and stays perfectly alive. Only a
  deadline ends that wait: `isolate.ready_timeout.spawn`, after `readyTimeout`.

```dart
final worker = await TomWorker.spawn(
  TomWorker.startRemoteIsolate,
  context,
  readyTimeout: const Duration(seconds: 10), // default: 30 seconds
);
```

`readyTimeout` bounds the whole startup rather than each step of it — the first
message from the isolate, `initializeWorker`, and `initializeIsolate` share one
budget, because what a caller can state is how long `spawn` may take, not how
that time ought to be divided. It must be positive; a zero or negative bound
expires before any isolate could answer, so it is rejected up front with
`isolate.invalid_ready_timeout.spawn` rather than failing every spawn made under
it.

Whichever watcher fires, the isolate is killed before the error is thrown. The
two overlap on purpose: exit detection is prompt but has a blind spot in the
first instants after `Isolate.spawn`, where a death can precede the exit
listener's registration, and the deadline is the backstop that covers it.

`TomWorkerPool.withSize` takes the same `readyTimeout` and forwards it to every
worker it spawns, including the replacements supervision creates.

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
TomWorker.addExecutor(DataProcessorExecutor());
```

Register with `TomWorker.addExecutor`, withdraw with `TomWorker.removeExecutor`
or `TomWorker.clearExecutors`. `TomWorker.executors` reads the registry back as
an unmodifiable view — the message handlers dispatch through the one backing
list, so a caller that could replace or edit it directly would silently detach
dispatch from every later registration.

Executors are tried in order and the first to return anything other than
`noResult` wins. If the chain is exhausted — or the receiving side has no
executor registered at all — the command is nonetheless answered, with
`noResult` itself. **This holds in both directions**, and a caller that must
distinguish "nobody handled this" from a real result has to test for the
sentinel:

```dart
// creator → worker
final result = await worker.executeCommand('nothing handles this');
if (identical(result, TomExecutor.noResult)) {
  // The worker received the message but no executor claimed it.
}

// worker → creator, from inside a worker isolate
final answer = await TomWorker.executeInCreator('nothing handles this');
if (identical(answer, TomExecutor.noResult)) {
  // The creator received the message but no executor claimed it.
}
```

`identical` rather than `==`: the sentinel is a `const` instance with no value
equality of its own, and it stays canonical across the isolate hop — that
canonicality is exactly what makes it recognisable. Both sides also log a
warning naming the unclaimed command, so a forgotten `addExecutor` shows up in
the log rather than only as a puzzling sentinel at the call site.

Answering matters more than it looks. A command left unanswered leaves the
caller's completer pending forever, and liveness supervision cannot rescue it:
the isolate is healthy and still answers pings, so nothing observes the hang.
Every message therefore gets a reply, even if the reply is "nobody took this".

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

#### A result of `null` never reaches the caller as `null`

`execute` is declared `Future<Object?>`, but a `null` result is substituted
before the response is sent — and the two directions substitute *different*
values:

| Direction | Call | A `null` result arrives as |
| --------- | ---- | -------------------------- |
| creator → worker | `worker.executeCommand(cmd)` | the string `"null"` |
| worker → creator | `TomWorker.executeInCreator(cmd)` | `TomExecutor.noResult` |

The creator-bound row reuses the same sentinel the unhandled answer uses, so
`noResult` from `executeInCreator` is ambiguous: it means *either* "no executor
claimed the message" *or* "a handler ran and returned `null`". Nothing in the
response distinguishes them — only the creator's warning log does. A command
whose caller must tell the two apart should return a sentinel of its own rather
than `null`. The worker-bound direction has no such ambiguity, because its
`null` becomes the string `"null"` instead.

So `executeCommand` can never resolve to `null` despite its signature. The same
substitution applies to a `null` returned by a `TomExecutor`, not just by a
`TomCommand`. The consequence worth remembering is that a nullable-returning
command is not distinguishable from one that returned the literal text:

```dart
// Suppose lookup() returned null inside the worker.
final name = await worker.executeCommand(LookupCommand(id)) as String?;
// name is "null" — four characters, not null. No error is raised here; it
// fails somewhere later, wherever the value is finally used.
```

To carry "absent" across the boundary, send an explicit value you can test for
— `TomExecutor.noResult`, an empty collection, or a sentinel of your own —
rather than relying on `null` surviving the trip.

`TomCommand.execute`'s base implementation returns the string `"null"` for the
same reason: it guarantees a sendable, non-null response from a subclass that
forgot to override it. That means an unoverridden command and a command that
legitimately resolved to `null` produce identical results.

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

// Tear down when done; the pool must not be reused afterwards.
pool.close();
```

A pool needs at least one worker, so `withSize` rejects a size below 1 with a
`TomWorkerException` naming the value:

```dart
try {
  // A single-core container makes this 0.
  final pool = await TomWorkerPool.withSize(
    Platform.numberOfProcessors - 1,
    context,
  );
} on TomWorkerException catch (e) {
  print('bad pool size: ${e.parameters?['size']}');
}
```

An empty pool could never acquire a worker — workers are added at construction
and on respawn-after-death only — so every `execute` would wait forever on a
free list that stays empty. Failing at construction puts the error where the
mistake is, instead of at a dispatch somewhere else in the program.

### Liveness Supervision

By default the pool performs no supervision. Pass a `healthCheckInterval` to
turn it on:

```dart
final pool = await TomWorkerPool.withSize(
  4,
  context,
  healthCheckInterval: const Duration(seconds: 5),
  healthCheckTimeout: const Duration(seconds: 30), // default: 5s
);

print(pool.isSupervised); // true
print(pool.workerCount);  // 4
```

Both durations must be positive, and both are checked only when supervision is
switched on — `healthCheckTimeout` has a default, so an unsupervised caller
never chose it. A zero interval would run a health pass on every event-loop
turn; a zero timeout would expire before any healthy worker could answer,
force-killing and respawning the pool on every pass while `workerCount` still
read healthy.

Two mechanisms then run. **Exit detection** watches every worker: if an isolate
dies for any reason — an uncaught error, `Isolate.kill`, an out-of-memory kill —
each in-flight command on it is failed with a `TomWorkerDiedException` instead
of hanging its caller forever, and the pool respawns a replacement.
**Periodic pings** probe *idle* workers only, catching hangs that never emit an
exit signal; a worker that misses `healthCheckTimeout` is force-killed and
routed through the same death/respawn path.

Only idle workers are pinged. The reason is not that a probe would queue behind
the in-flight command: the worker answers a ping at the top of its message
handler, before any command or executor dispatch, so a worker running
*asynchronous* work answers immediately and the probe would be perfectly
meaningful.

The reason is **synchronous** work. A command that occupies its isolate without
yielding — a tight compute loop, precisely the workload this module exists for
— stops the event loop from reading the ping at all. The probe would then time
out against a worker that is not merely healthy but actively productive, and
force-kill it mid-computation. A busy worker that genuinely crashes is covered
by exit detection anyway, so skipping it costs nothing.

Skipping busy workers is what keeps `healthCheckTimeout` easy to choose. A
probed worker is pulled out of the free list first, and `execute` only returns a
worker to that list once its command has resolved, so a probe never races a
running command: the timeout bounds a round trip to an idle isolate, not the
runtime of any command. Sub-second values are therefore reasonable regardless of
how long the work itself takes.

The synchronous-blocking caveat still reaches you through `TomWorker.ping`,
which is public and does not check whether the worker is busy. Pinging a worker
that is mid-computation reports `false` for a perfectly healthy isolate.

```dart
try {
  await pool.execute(SomeCommand());
} on TomWorkerDiedException catch (e) {
  // The request failed rather than hanging — and was NOT retried.
  print('worker died: ${e.parameters?['isolateName']}');
}

// Capacity is restored asynchronously.
while (pool.workerCount < 4) {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}
```

A failed in-flight command is deliberately **not** re-dispatched: re-running
work that may already have produced side effects risks doing non-idempotent work
twice. Only the caller knows whether a retry is safe.

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
    defaultTomEnvironment,
    platformLinux,
    [],
    'DB',
  );

  @override
  Future<void> initializeIsolate() async {
    // Initialize database connection in the isolate. A connection failure
    // throws, which aborts the spawn rather than yielding a connectionless
    // worker.
    await Database.connect(connectionString);
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
- Clamp any computed size to at least 1 — an expression like
  `numberOfProcessors - 1` yields 0 on a single-core container, which
  `withSize` rejects

### 3. Error Handling

A command that throws inside the worker surfaces as a `RemoteError`. A worker
that *dies* while a command is in flight surfaces as a `TomWorkerDiedException`
— but only on a supervised pool; without supervision the future never
completes.

```dart
try {
  final result = await worker.executeCommand(command);
} on RemoteError catch (e) {
  // The command failed, but the worker is still healthy.
  print('Worker error: $e');
} on TomWorkerDiedException catch (e) {
  // The worker is gone; the command's fate is unknown, so decide whether
  // re-running it is safe before retrying.
  print('Worker died: $e');
}
```

### 4. Avoid Common Pitfalls

- **Don't share mutable state**: Isolates have separate memory
- **Keep messages serializable**: Objects must be sendable across isolate boundaries
- **Clean up resources**: Always call `close()` when done with workers or pools.
  Dispatching afterwards is refused with a `TomWorkerException` at both levels —
  `TomWorker.executeCommand` and `TomWorkerPool.execute` alike — so a
  use-after-close surfaces as a catchable error rather than a silent deadlock
- **Handle worker failures**: Enable supervision (`healthCheckInterval`) on
  long-running pools rather than writing your own health checks — an
  unsupervised pool hangs the caller forever when a worker dies
- **Don't return `null` from a command**: it is substituted before it is sent
  (with the string `"null"` towards the worker, with `TomExecutor.noResult`
  towards the creator), so a `null`-checking caller never sees the case it is
  checking for. Send an explicit sentinel instead — see
  [TomCommand](#tomcommand)
- **Don't cast a dispatch result unchecked**: both `executeCommand` and
  `executeInCreator` may resolve with `TomExecutor.noResult` when nothing
  handled the message, so `await worker.executeCommand(c) as Report` throws a
  `TypeError` naming a private type, far from the `addExecutor` that was
  forgotten. Test with `identical(result, TomExecutor.noResult)` first — see
  [TomExecutor](#tomexecutor)

### 5. Logging Considerations

When using logging in workers that delegate to a logging isolate, avoid logging within `sendToCreator()` to prevent stack overflow. Use `print()` for debugging in such cases.

## API Reference

See `doc/api_reference/api_summary_isolate_pooling.md` for the full public
surface, or the dartdoc in `lib/src/tombase/isolate_pooling/tom_worker.dart`.

---

## Dependencies

This module depends on:

- **Runtime Module**: `TomEnvironment` and `TomPlatform` for worker context configuration
- **Logging Module**: For logging within worker isolates

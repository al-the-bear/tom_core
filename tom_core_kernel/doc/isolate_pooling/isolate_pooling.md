# Isolate Pooling Module

The isolate pooling module provides a robust framework for managing Dart isolates, enabling parallel processing and concurrent task execution in Dart and Flutter applications.

## Table of Contents

- [Overview](#overview)
  - [Platform support](#platform-support)
- [Quick Start](#quick-start)
  - [1. Create a Worker Context](#1-create-a-worker-context)
  - [2. Spawn a Worker](#2-spawn-a-worker)
  - [3. Execute Commands](#3-execute-commands)
  - [4. Clean Up](#4-clean-up)
- [Core Components](#core-components)
  - [TomWorker](#tomworker)
  - [TomWorkerContext](#tomworkercontext)
  - [Bounding the startup](#bounding-the-startup)
  - [TomExecutor](#tomexecutor)
  - [TomCommand](#tomcommand)
  - [TomWorkerPool](#tomworkerpool)
  - [Liveness Supervision](#liveness-supervision)
    - [Supervising a bare worker](#supervising-a-bare-worker)
  - [When the pool stops replacing](#when-the-pool-stops-replacing)
- [Architecture](#architecture)
- [Usage Examples](#usage-examples)
  - [Example 1: CPU-Intensive Computation](#example-1-cpu-intensive-computation)
  - [Example 2: Parallel Image Processing](#example-2-parallel-image-processing)
  - [Example 3: Bidirectional Communication](#example-3-bidirectional-communication)
  - [Example 4: Custom Worker Context](#example-4-custom-worker-context)
- [Best Practices](#best-practices)
  - [1. Choose the Right Pattern](#1-choose-the-right-pattern)
  - [2. Pool Sizing](#2-pool-sizing)
  - [3. Error Handling](#3-error-handling)
  - [4. Avoid Common Pitfalls](#4-avoid-common-pitfalls)
  - [5. Logging Considerations](#5-logging-considerations)
- [API Reference](#api-reference)
- [Dependencies](#dependencies)
  - [The logging module is a dependent, not a dependency](#the-logging-module-is-a-dependent-not-a-dependency)
  - [What the pool logs](#what-the-pool-logs)

---

## Overview

Dart isolates are independent execution contexts with their own memory space. While this provides true parallelism, managing isolate lifecycle and communication can be complex. This module abstracts away the complexity while providing:

- **Worker Isolates**: Spawn and manage isolated execution contexts
- **Bidirectional Communication**: Send commands to workers and receive responses
- **Command Pattern**: Execute commands as self-contained objects
- **Executor Pattern**: Register handlers to process incoming messages
- **Worker Pools**: Manage multiple workers with automatic load distribution
- **Liveness Supervision**: Opt-in detection and recovery from worker deaths

### Platform support

**Native only.** The module is built on `dart:isolate`, which both web
compilers mark as unsupported, so none of it runs in a browser. There is no
web-facing subset: `TomWorker`, `TomWorkerPool` and the back-channel all
require a real isolate.

`TomWorkerContext.tomPlatform` is therefore *not* a target switch, and the
module never reads it. It is application data copied across the isolate
boundary, because a spawned isolate starts with fresh memory and none of the
creator's `TomRuntime` configuration — your `initializeIsolate` override is
what reads it back. The `TomPlatform` constants come from the runtime module
and are the framework's vocabulary for the whole workspace, not this module's
list of supported targets. `platformWeb` is accepted and stored faithfully; it
simply names a platform on which no worker can be spawned.

**A worker establishes its own platform.** Statics are per isolate, and
`TomPlatformUtils.current` is one, so the platform an application installs at
start-up is not there in a worker: the isolate begins on
`TomFallbackPlatformUtils`, whose `getIsolateName()` is empty. The framework's
log header is built from that name, so every line a worker logs reads `- INFO`
where its main-isolate lines read `main-main INFO` — and a worker's own name,
`PoolWorker001`, is exactly what a reader tracing pooled work needs. The
framework does not carry the platform across (a `TomPlatformUtils` instance is
generally not sendable, and the kernel cannot name a concrete implementation).
Installing it is the application's start-up work, as it is in `main`, and the
place is `initializeIsolate`, the one hook that runs inside the new isolate
before its message loop:

```dart
abstract class AppWorkerContext extends TomWorkerContext {
  AppWorkerContext(super.env, super.platform, super.args, super.namePrefix);

  /// The application's platform, built inside the worker: on a console or
  /// server `TomStandalonePlatformUtils()` from `tom_basics_console`, on
  /// Flutter the Flutter binding's.
  TomPlatformUtils createPlatform();

  @override
  Future<void> initializeIsolate() async {
    TomPlatformUtils.setCurrentPlatform(createPlatform());
  }
}
```

A context that extends another — `TomLoggingWorkerContext`, which registers
the logging executor — installs the platform and then calls
`super.initializeIsolate()`.

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

The tables below name the members this guide goes on to use, not the whole
class. For the complete surface with full signatures see
[`api_summary_isolate_pooling.md`](../api_reference/api_summary_isolate_pooling.md).

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
| `sendToCreator()` | Send a message to the creator (fire-and-forget); throws in the creator |
| `executeInCreator()` | Execute a command in the creator and await result, or `TomExecutor.notHandled` if nothing there claimed it; rethrows a creator-side failure; throws in the creator |
| `canSendToCreator()` | Whether a backchannel is available — answers on either side rather than throwing |

#### Static Properties

| Property | Description |
|----------|-------------|
| `isMainIsolate` | Whether the current code runs in the main isolate; `false` inside a worker isolate. Read-only — the flag is load-bearing, and tests reach the other side with `simulateWorkerIsolate` / `resetIsMainIsolate` |

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

**Two sentinels, and they point opposite ways.** `noResult` travels *inward*:
an executor returns it to decline, and executors are tried in order until one
returns something else. `notHandled` travels *outward*: if the chain is
exhausted — or the receiving side has no executor registered at all — the
command is nonetheless answered, with `notHandled`. **This holds in both
directions**, and a caller that must distinguish "nobody handled this" from a
real result tests for it:

```dart
// creator → worker
final result = await worker.executeCommand('nothing handles this');
if (identical(result, TomExecutor.notHandled)) {
  // The worker received the message but no executor claimed it.
}

// worker → creator, from inside a worker isolate
final answer = await TomWorker.executeInCreator('nothing handles this');
if (identical(answer, TomExecutor.notHandled)) {
  // The creator received the message but no executor claimed it.
}
```

For most callers that case is worth testing, because it says almost nothing
about the command and almost everything about start-up: a `notHandled` answer
means a missing `addExecutor`, and it will keep meaning that until one is
added.

`identical` rather than `==`: both are `const` instances with no value equality
of their own, and they stay canonical across the isolate hop — that
canonicality is exactly what makes them recognisable. They are also distinct
*types*, so the pair cannot converge by an equality route either. Both sides
log a warning naming the unclaimed command, so a forgotten `addExecutor` shows
up in the log rather than only as a puzzling sentinel at the call site.

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

The creator-bound row is `noResult` and the unhandled answer is `notHandled`,
so the two conditions the sentinel would otherwise conflate stay apart: "a
handler ran and returned `null`" against "no executor claimed the message".
They are opposites — the answer is nothing, against there was no answer — and
one value for both means a process that forgot an `addExecutor` reports
plausible answers rather than a fault. That is not hypothetical: read as a
miss, it made `TomAuthorizationCache.getPrincipal` re-resolve every principal
for ever, and made `storePrincipal` report a lost write as a success.

The two directions still spell a *`null` answer* differently — the string
`"null"` one way, `noResult` the other — so only the unclaimed case is
interchangeable between them.

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

`withSize` spawns its workers **together** and returns once every one is ready,
so construction costs about one spawn rather than `size` of them. That is worth
saying because a spawn is not just an isolate start: it also awaits the
context's `initializeWorker`, the documented place to open a database handle or
warm a cache. A context with a 200 ms hook builds an eight-worker pool in about
200 ms rather than 1.6 seconds.

Worker names are unaffected by that. The counter behind them is incremented on
one event loop, so two spawns cannot read the same value however they
interleave: a pool of four still gets `<prefix>000` through `<prefix>003`.

If any spawn fails, the workers that did come up are closed before the error is
rethrown. The caller receives no pool, so nothing else would ever close them,
and their isolates would otherwise stay in their message loops for the life of
the process.

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

Supervision is a property of a **worker**, not of a pool. `TomWorker` owns the
mechanism: `superviseExit` registers an exit listener, and `TomWorker` itself
fails the in-flight requests with a `TomWorkerDiedException`. `TomWorkerPool` is
one *client* of that mechanism — it calls `superviseExit` on each worker it
spawns and uses the callback to respawn a replacement. Read this section for
what a pool adds; see [Supervising a bare worker](#supervising-a-bare-worker)
for the primitive underneath, which is the answer if you are not using a pool.

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

`respawnLimit` and `respawnWindow` bound how hard supervision tries, defaulting
to ten replacements a minute. They are validated the same way and for the same
reason — `isolate.invalid_respawn_limit.with_size` rejects a limit below one,
which would give up on the first death and leave a caller who asked for
supervision with none; `isolate.invalid_respawn_window.with_size` rejects a
window of zero, in which every recorded respawn falls outside the window the
moment it is recorded, so the budget never fills and respawn is unbounded again.

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

// Capacity is restored asynchronously. Wait for it against a deadline — never
// open-ended — and check the outcome, because the respawn can fail.
final deadline = DateTime.now().add(const Duration(seconds: 30));
while (pool.workerCount < 4 && DateTime.now().isBefore(deadline)) {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}
if (pool.workerCount < 4) {
  // The replacement never arrived. The pool still works, just smaller; decide
  // whether to carry on degraded or to close it and build a new one.
}
```

The deadline is not defensive padding. A replacement is attempted **exactly
once** per death: the exit listener drops the dead worker and starts one
respawn. If that spawn throws — an `initializeIsolate` that cannot reach the very
resource whose loss killed the first worker, say — the pool logs the failure and
does not retry, so `workerCount` stays down for the rest of the pool's life. An
unbounded `while (pool.workerCount < 4)` would therefore not merely risk
spinning forever in theory; it would spin forever in exactly the case the caller
is waiting for news about.

Size the deadline against `readyTimeout`, not against intuition: the respawn is
a full `TomWorker.spawn` running on the pool's `readyTimeout` budget, 30 seconds
by default. A deadline shorter than that can expire while a legitimate spawn is
still in flight, reporting a failure that has not happened.

A failed in-flight command is deliberately **not** re-dispatched: re-running
work that may already have produced side effects risks doing non-idempotent work
twice. Only the caller knows whether a retry is safe.

Note that the loop above polls rather than reading `workerCount` once. That is
not stylistic — see [the ordering
note](#the-caller-resumes-before-the-supervisor) below.

#### Supervising a bare worker

A single long-lived worker gets the same protection without a pool. Register
`superviseExit` and the worker fails its own in-flight requests:

```dart
final worker = await TomWorker.spawn(TomWorker.startRemoteIsolate, context);

worker.superviseExit(() {
  // The isolate died unexpectedly. The worker is already closed and its
  // in-flight requests already failed; this is where you decide what next —
  // respawn, escalate, or give up. Nothing respawns it for you.
  print('worker ${worker.name} died');
});

try {
  await worker.executeCommand(SomeCommand());
} on TomWorkerDiedException catch (e) {
  // Without the superviseExit above, this await would hang forever instead.
  print('worker died: ${e.parameters?['isolateName']}');
}
```

Three properties are worth knowing:

- **An orderly `close()` is not a death.** `close` tears the exit port down
  before the isolate terminates, so `onDeath` does not fire for a clean
  shutdown. A supervisor therefore never mistakes your own shutdown for a crash.
- **It is one-shot and idempotent.** The callback runs at most once, and calling
  `superviseExit` again while already supervised is a no-op — so you cannot
  accidentally stack two respawn handlers on one worker.
- **Nothing is respawned for you.** That is the whole of what `TomWorkerPool`
  adds on top: it registers this same callback and uses it to spawn a
  replacement. On a bare worker, restoring capacity is your callback's job.

##### The caller resumes before the supervisor

When the isolate dies, the awaiting caller is resumed **before** the `onDeath`
callback runs. The request completers are `Completer.sync()`, so completing them
with the error hands control straight back to whoever was awaiting, and the
supervisor callback is invoked only afterwards.

The consequence is practical: state that the callback maintains is still stale
at the moment you catch the exception. On a pool, `_handleWorkerDeath` *is* that
callback, so reading `pool.workerCount` immediately inside the `catch` still
counts the worker that just died. This is why the recovery snippet above polls
towards the expected count instead of asserting it once.

### When the pool stops replacing

Replacing is bounded, because replacing unconditionally is its own failure. A
command that reliably kills its worker — an allocation the isolate cannot
satisfy, a native crash, a stray `Isolate.kill` in library code — otherwise
produces an endless kill-and-replace cycle: each replacement takes the next such
command, dies, and is replaced, while `workerCount` reports healthy capacity
throughout and the only outward sign is isolate churn.

The pool spawns at most `respawnLimit` replacements per `respawnWindow` and then
stops. `isRespawnExhausted` reports that it has, and the reason is logged once.
It is also raised when a replacement spawn *fails* and leaves the pool empty:
a respawn is only ever triggered by a death, and a pool with no workers can have
none, so nothing would ever try again.

A pool that has given up keeps serving on whatever workers remain — giving up
on replacement is not giving up on work. Once none remain, `execute` refuses
with `isolate.respawn_exhausted.execute_without_workers` instead of parking a
caller for a worker that cannot arrive, and any caller already parked is failed
with the same error.

```dart
if (pool.isRespawnExhausted) {
  // The pool stopped replacing. Decide whether to carry on with what is left
  // or to close it and build a new one; nothing will restore capacity now.
}
```

The budget is a **rate**, not a total: a pool that loses one worker a week to an
ordinary cause must not exhaust a counter that never resets, and a pool losing
one per command must not be let through because its deaths are spread over a
long enough run.

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

- For CPU-bound tasks: one worker per core, e.g. `Platform.numberOfProcessors`.
  `Platform` is `dart:io` — an import *you* add, not one this module carries.
  Reaching for it costs you no portability you had, because the module is
  [native-only](#platform-support) anyway: wherever `dart:isolate` runs,
  `dart:io` runs too
- For I/O-bound tasks: More workers may be beneficial
- Consider memory overhead per isolate
- Clamp any computed size to at least 1 — an expression like
  `numberOfProcessors - 1` yields 0 on a single-core container, which
  `withSize` rejects

### 3. Error Handling

A command that throws rethrows on the caller's side, carrying the original
exception object — so `on MyDomainException` matches exactly as it would had the
command run locally. This holds in **both** directions: `executeCommand` towards
the worker and `executeInCreator` back towards the creator behave the same, so a
caller never has to know which isolate it is running in before it can tell a
failure from an answer.

A worker that *dies* while a command is in flight surfaces as a
`TomWorkerDiedException` — on any worker that is supervised, whether you
registered [`superviseExit`](#supervising-a-bare-worker) yourself or let a
supervised pool do it for you. Only an *un*supervised worker leaves the future
hanging forever.

```dart
try {
  final result = await worker.executeCommand(command);
} on InventoryUnavailable catch (e) {
  // The command failed with a failure of its own; the worker is still healthy.
  print('No stock for ${e.sku}');
} on TomWorkerDiedException catch (e) {
  // The worker is gone; the command's fate is unknown, so decide whether
  // re-running it is safe before retrying.
  print('Worker died: $e');
}
```

**One exception to the type guarantee.** Not everything can cross an isolate
port — an exception holding a closure or a `ReceivePort` is rejected by `send`.
Such a failure arrives as a `RemoteError` built from the original's
`toString()`: still a throw, still naming what went wrong, but not matched by
an `on` clause for its own type. The substitution exists because the `send`
that discovers the problem runs inside a port handler, where a throw would be
caught by nobody and would leave the request unanswered forever. Keep failure
types plain data if their type has to survive the trip.

### 4. Avoid Common Pitfalls

- **Don't share mutable state**: Isolates have separate memory
- **Keep messages serializable**: Objects must be sendable across isolate boundaries
- **Clean up resources**: Always call `close()` when done with workers or pools.
  Dispatching afterwards is refused with a `TomWorkerException` at both levels —
  `TomWorker.executeCommand` and `TomWorkerPool.execute` alike — so a
  use-after-close surfaces as a catchable error rather than a silent deadlock
- **Handle worker failures**: any unsupervised worker hangs its caller forever
  when the isolate dies, pool or not. On a pool, enable supervision with
  `healthCheckInterval`; on a standalone worker, register
  [`superviseExit`](#supervising-a-bare-worker). Either way, prefer the built-in
  mechanism to writing your own health checks
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

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | every file | `Completer`, `Future`, `Timer`, `unawaited` |
| `dart:collection` | dart | every file | `UnmodifiableListView` |
| `dart:isolate` | dart | every file | directly, which is what makes the module native-only |
| `meta` | package | every file | `@visibleForTesting` only; no runtime behaviour |
| `tom_basics` | package | every file | `tomLog`, at `trace` for the dispatch loop and `warn` / `error` for a worker that died |
| [little_things](../little_things/little_things.md) | module | every file | `TomException`, the base of `TomWorkerException` and `TomWorkerDiedException`, and `tomPrintStackTrace` for reporting a failure raised inside a worker isolate |

- **Runtime Module**: `TomEnvironment` and `TomPlatform`, carried in a
  `TomWorkerContext` for the application's own isolate-side setup to read — see
  [Platform support](#platform-support)

### The logging module is a dependent, not a dependency

The kernel's [logging module](../logging/logging.md) does not appear above, and
the omission is deliberate: the edge runs the *other* way. `logging_isolate.dart`
imports this module to run its file writer on a worker, so logging depends on
isolate pooling. Adding the reverse edge would close a cycle.

What the pool reports, it reports through **`tomLog`** — a live global from
`tom_basics` with a working default, so nothing has to be wired up first. That
is also what makes the pool usable *inside* a worker isolate, where the kernel's
logging module may not be initialized at all.

### What the pool logs

Every report is a `tomLog` entry and nothing else — none of these are raised,
returned, or otherwise visible to a caller that discards log output:

| Level | Reported when |
| ----- | ------------- |
| `trace` | An isolate begins or finishes its initialization; a receive port closes |
| `info` | An isolate finishes initializing (with the elapsed milliseconds), becomes ready for messages, or a pool worker is created |
| `warn` | A command completed with `NO_RESULT` — the work ran but produced nothing to send back |
| `error` | A command threw inside the isolate; a message arrived with no executor set; a respawn failed after an isolate death |

The `warn` row is the one worth knowing about: a `NO_RESULT` is *not* an error
and does not fail the call, so a caller seeing an empty result and no exception
will find the explanation only in the log.

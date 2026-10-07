# isolate_pooling

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Worker isolates and pooling for CPU-bound work. A `TomCommand` encapsulates a
unit of work; a `TomWorker` runs it on a dedicated isolate, and a
`TomWorkerPool` load-balances commands across a fixed set of workers.

**Native only.** The module is built on `dart:isolate`, which both web
compilers mark as unsupported, so none of it runs in a browser. The
`TomPlatform` in a `TomWorkerContext` is not a target switch — the module never
reads it, and `platformWeb` is a framework-wide constant rather than a claim by
this module. See
[Platform support](../../../../doc/isolate_pooling/isolate_pooling.md#platform-support).

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomCommand` | An encapsulated unit of work with an async `execute()`. A result of `null` is sent as `null`, in both directions; the default `execute()` answers `null`. |
| `TomExecutor` | Custom command handler chain (returns a value or passes to the next executor). Register with `TomWorker.addExecutor`, withdraw with `removeExecutor` / `clearExecutors`; `TomWorker.executors` reads the chain back as an unmodifiable view, since dispatch runs off the one backing list. When the whole chain declines — or none is registered — the dispatch answers `TomExecutor.notHandled` rather than staying silent, so a caller is never left awaiting an answer that will not come. This holds in both directions: `executeCommand` and `executeInCreator` alike may resolve with it, recognised by `identical(result, TomExecutor.notHandled)`, and it means a missing `addExecutor` rather than anything about the command. `TomExecutor.noResult` is the *other* sentinel: an executor returns it to decline, and the dispatch consumes it — a caller never receives it. A handler's `null` answer arrives as `null`. |
| `TomWorker` | A single worker isolate; `spawn(...)` creates one, `executeCommand(cmd)` runs work on it, `close()` shuts it down. Dispatching after the close — `executeCommand` or `sendExecutorToIsolate` — throws `TomWorkerException` instead of waiting on an isolate that will never answer. |
| `TomWorkerPool` | Fixed pool of workers; `withSize(n, context)` builds it (rejecting an `n` below 1, and non-positive supervision durations, rather than returning a pool that cannot work), `execute(cmd)` dispatches to a free worker, `close()` tears it down. |
| `TomCommandDispatcher` | The dispatch-only view of a pool — `execute(cmd)` and `close()` — which `TomWorkerPool` implements. A consumer that only sends commands depends on this, so a test can hand it a recorder. |
| `TomCreatorChannel` | The worker-to-creator back-channel as a value: `isOpen` and `send(message)`. `TomCreatorChannel.current` is the running isolate's channel (open only in a worker); a consumer taking a channel can be handed an open one by a test. |
| `TomWorkerContext` | The state handed to a worker isolate at spawn time, plus the two setup hooks (`initializeIsolate` inside the isolate, `initializeWorker` on the creator side). Both refuse by throwing — see below. |
| `TomWorkerException` | Thrown on worker spawn / communication failures, on a startup that never reaches ready, on dispatch to a closed worker or pool, and on pool arguments that cannot yield a working pool. |
| `TomWorkerDiedException` | Fails an in-flight command whose worker isolate died, on any worker supervised via `TomWorker.superviseExit` — with or without a pool. |

## Quick start

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

class FactorialCommand extends TomCommand {
  final int n;
  FactorialCommand(this.n);

  @override
  Future<Object?> execute() async {
    var result = 1;
    for (var i = 2; i <= n; i++) result *= i;
    return result;
  }
}

Future<void> main() async {
  final context = TomWorkerContext(
      defaultTomEnvironment, platformLinux, [], 'PoolWorker');

  // Build a pool and run the command on a worker isolate.
  final pool = await TomWorkerPool.withSize(2, context);
  print(await pool.execute(FactorialCommand(5))); // 120

  pool.close();
}
```

## Commands, executors and the back-channel

A message sent with `worker.executeCommand(...)` is dispatched one of two ways.
A `TomCommand` carries its own `execute()` and runs it in the worker; anything
else cannot execute itself, so the worker offers it to its executor chain
instead. Use a command when the logic belongs to the message, an executor when
one handler serves many message shapes. Seed a worker's own chain with
`worker.sendExecutorToIsolate(...)` — that send is one-way and unacknowledged,
so it is ordering on the shared port, not an acknowledgement, that makes the
next command see it.

Code running inside a worker can call back the other way:

| Call | Shape | Answered by |
| ---- | ----- | ----------- |
| `TomWorker.sendToCreator(obj)` | fire-and-forget; nothing is awaited | the creator's executor chain |
| `TomWorker.executeInCreator(cmd)` | request/response; the worker awaits the answer | the creator, which runs a `TomCommand` itself and offers anything else to its executor chain |

Both exist only where there *is* a creator to reach. Called in the creator they
throw `TomWorkerException`, keyed
`isolate.state_error.attempt_to_send_to_creator_in_creator` and
`isolate.state_error.attempt_to_execute_in_creator_in_creator`;
`TomWorker.canSendToCreator()` answers the same question without the throw.

The split between the static and the instance API follows that boundary. A
member is static when it concerns *the isolate* rather than one particular
worker: the process-global executor registry, the isolate's own identity, the
back-channel to whoever created this isolate, and the factory that makes
workers in the first place. A member is an instance member when it acts on one
`TomWorker` the creator holds — dispatching to it, supervising it, closing it.

This readme states the rule and does not repeat the members one by one. The
complete surface, with signatures, is in
[`api_summary_isolate_pooling.md`](../../../../doc/api_reference/api_summary_isolate_pooling.md),
which is maintained alongside `tom_worker.dart`; a second hand-written
inventory could only drift away from it.

## Failing initialization

`TomWorkerContext.initializeIsolate` and `initializeWorker` return `Future<void>`
and report a failure by **throwing**. `TomWorker.spawn` then aborts instead of
handing back a worker whose setup did not complete, and it kills the isolate it
had already started — a refused spawn leaves nothing running.

The two hooks live on opposite sides of the isolate boundary, so their throws
reach the caller by different routes:

- `initializeWorker` runs on the creator side; its exception propagates out of
  `spawn` unchanged.
- `initializeIsolate` runs *inside* the new isolate, where a throw cannot unwind
  to the creator. The isolate reports the refusal over its message channel and
  stops, and `spawn` fails with a `TomWorkerException` keyed
  `isolate.initialize_isolate_failed.spawn`, carrying the isolate's `error` and
  `isolateStack` in `parameters`.

```dart
class DatabaseContext extends TomWorkerContext {
  DatabaseContext(
    super.tomEnvironment,
    super.tomPlatform,
    super.args,
    super.namePrefix,
  );

  @override
  Future<void> initializeIsolate() async {
    await Database.connect(url); // a connection failure aborts the spawn
  }
}
```

`initializeIsolate` is also where a worker installs its **platform**: statics
are per isolate, so a worker starts on `TomFallbackPlatformUtils` and its log
lines carry no isolate name until the application's context calls
`TomPlatformUtils.setCurrentPlatform` there. See the module guide.

Identify a worker in messages with `worker.name`, not
`worker.isolate.debugName` — the latter is only populated inside the isolate and
reads `null` on the creator side.

The name is the context's `namePrefix` followed by a zero-based, three-digit
counter, so a prefix of `"W"` names the first worker `W000` and the second
`W001`. `namePrefix` is required — there is no default — and, like the rest of
`TomWorkerContext`, it is fixed at construction: the context is read at spawn
time, so a later change could not reach a worker that is already running.

## Bounding the startup

Until the ready signal arrives the isolate is live but unreachable — `spawn` has
returned no `TomWorker` to `close()` — so a startup that fails silently would
leave the caller waiting forever. `spawn` watches for both shapes of that:

| The isolate… | Emits | Caught by | Key |
| ------------ | ----- | --------- | --- |
| dies before signalling ready | an exit signal, no message | an exit listener, at once | `isolate.died_before_ready.spawn` |
| stays alive but never answers | nothing at all | the `readyTimeout` deadline | `isolate.ready_timeout.spawn` |

Neither watcher would do on its own, which is why both are armed. In each case
the isolate is killed before the error is thrown.

```dart
final worker = await TomWorker.spawn(
  TomWorker.startRemoteIsolate,
  context,
  readyTimeout: const Duration(seconds: 10), // default: 30 seconds
);
```

`readyTimeout` is one budget for the whole startup — the isolate's first
message and both initialization hooks — and must be positive
(`isolate.invalid_ready_timeout.spawn`). `TomWorkerPool.withSize` accepts it too
and forwards it to every worker it spawns, replacements included.

## Liveness supervision (opt-in)

Supervision belongs to `TomWorker`, not to the pool. `superviseExit` registers
an exit listener, and the worker fails its own in-flight commands with a
`TomWorkerDiedException` instead of hanging the caller forever:

```dart
worker.superviseExit(() => print('worker ${worker.name} died'));
```

`TomWorkerPool` is a client of that mechanism: pass a `healthCheckInterval` to
`withSize` and the pool registers the callback on every worker and uses it to
spawn a replacement. Idle workers are additionally pinged to catch hangs that
emit no exit signal.

```dart
final pool = await TomWorkerPool.withSize(
  4,
  context,
  healthCheckInterval: const Duration(seconds: 5),
);
```

So the difference is the respawn, not the exception: a bare supervised worker
reports the death just as a pooled one does, but restoring capacity is left to
its `onDeath` callback.

A failed command is deliberately **not** re-dispatched — only the caller knows
whether the work is idempotent.

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

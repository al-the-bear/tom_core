# isolate_pooling

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Worker isolates and pooling for CPU-bound work. A `TomCommand` encapsulates a
unit of work; a `TomWorker` runs it on a dedicated isolate, and a
`TomWorkerPool` load-balances commands across a fixed set of workers.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomCommand` | An encapsulated unit of work with an async `execute()`. |
| `TomExecutor` | Custom command handler chain (returns a value or passes to the next executor). When the whole chain declines — or none is registered — the dispatch answers `TomExecutor.noResult` rather than staying silent, so a caller is never left awaiting an answer that will not come. |
| `TomWorker` | A single worker isolate; `spawn(...)` creates one, `executeCommand(cmd)` runs work on it, `close()` shuts it down. Dispatching after the close — `executeCommand` or `sendExecutorToIsolate` — throws `TomWorkerException` instead of waiting on an isolate that will never answer. |
| `TomWorkerPool` | Fixed pool of workers; `withSize(n, context)` builds it (rejecting an `n` below 1, and non-positive supervision durations, rather than returning a pool that cannot work), `execute(cmd)` dispatches to a free worker, `close()` tears it down. |
| `TomWorkerContext` | The state handed to a worker isolate at spawn time, plus the two setup hooks (`initializeIsolate` inside the isolate, `initializeWorker` on the creator side). Both refuse by throwing — see below. |
| `TomWorkerException` | Thrown on worker spawn / communication failures, on dispatch to a closed worker or pool, and on pool arguments that cannot yield a working pool. |
| `TomWorkerDiedException` | Fails an in-flight command whose worker isolate died, when liveness supervision is enabled. |

## Quick start

```dart
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
  @override
  Future<void> initializeIsolate() async {
    await Database.connect(url); // a connection failure aborts the spawn
  }
}
```

Identify a worker in messages with `worker.name` (e.g. `"W001"`), not
`worker.isolate.debugName` — the latter is only populated inside the isolate and
reads `null` on the creator side.

## Liveness supervision (opt-in)

Pass a `healthCheckInterval` to `withSize` and the pool watches its workers: an
isolate that dies fails its in-flight command with a `TomWorkerDiedException`
instead of hanging the caller forever, and a replacement is spawned. Idle
workers are additionally pinged to catch hangs that emit no exit signal.

```dart
final pool = await TomWorkerPool.withSize(
  4,
  context,
  healthCheckInterval: const Duration(seconds: 5),
);
```

A failed command is deliberately **not** re-dispatched — only the caller knows
whether the work is idempotent.

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

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
| `TomExecutor` | Custom command handler chain (returns a value or passes to the next executor). |
| `TomWorker` | A single worker isolate; `spawn(...)` creates one, `executeCommand(cmd)` runs work on it. |
| `TomWorkerPool` | Fixed pool of workers; `withSize(n)` builds it, `execute(cmd)` dispatches to a free worker. |
| `TomWorkerContext` | The state handed to a worker isolate at spawn time. |
| `TomWorkerException` | Thrown on worker spawn / communication failures. |

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
  // Build a pool and run the command on a worker isolate.
  final pool = await TomWorkerPool.withSize(2);
  print(await pool.execute(FactorialCommand(5))); // 120
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

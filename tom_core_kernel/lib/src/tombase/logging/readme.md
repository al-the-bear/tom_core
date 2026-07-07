# logging

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Cross-isolate and remote logging. Worker isolates funnel their log output back
to the creator isolate (or to a remote log server) so a multi-isolate / server
deployment produces one coherent log stream rather than scattered per-isolate
output.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomIsolateLogging` | Entry point: `startIsolatedLogging(...)` wires creator-side collection; `startLoggingToCreator()` routes a worker's logs to the creator. |
| `TomIsolateLogOutput` / `TomCreatorLogOutput` | Log sinks for the worker and creator sides. |
| `TomLoggingExecutor` / `TomLoggingWorkerContext` | Worker-side logging plumbing ([`isolate_pooling`](../isolate_pooling/readme.md)). |
| `TomInterIsolateLogMessage` | A log record passed between isolates. |
| `TomRemoteLogOutput` / `TomRemoteLogServer` | Ship logs to / receive logs at a remote endpoint. |
| `TomRemoteLogMessage` / `TomRemoteLogResult` / `TomLoggingContext` | Remote-logging payloads and context. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

Future<void> main(List<String> args) async {
  // On the creator isolate: collect logs emitted by worker isolates.
  await TomIsolateLogging.startIsolatedLogging(args);

  // Inside a spawned worker: route its log output back to the creator.
  // TomIsolateLogging.startLoggingToCreator();
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

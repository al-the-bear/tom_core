# logging

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Cross-isolate and remote logging. Worker isolates funnel their log output back
to the creator isolate (or to a remote log server) so a multi-isolate / server
deployment produces one coherent log stream rather than scattered per-isolate
output.

Remote delivery is resilient by opt-in: a record that cannot be delivered can be
retried, written to a fallback sink, and buffered in a replay queue whose
storage is pluggable — in memory by default, or mirrored to disk so the buffer
survives a restart during an endpoint outage.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomIsolateLogging` | Entry point: `startIsolatedLogging(...)` wires creator-side collection; `startLoggingToCreator()` routes a worker's logs to the creator. |
| `TomIsolateLogOutput` / `TomCreatorLogOutput` | Log sinks for the worker and creator sides. |
| `TomLoggingExecutor` / `TomLoggingWorkerContext` | Worker-side logging plumbing ([`isolate_pooling`](../isolate_pooling/readme.md)). |
| `TomInterIsolateLogMessage` | A log record passed between isolates. |
| `TomRemoteLogOutput` / `TomRemoteLogServer` | Ship logs to / receive logs at a remote endpoint. |
| `TomRemoteLogMessage` / `TomRemoteLogResult` / `TomLoggingContext` | Remote-logging payloads and context. |
| `TomLogReplayStore` | Storage contract behind `TomRemoteLogOutput`'s replay queue: FIFO append, snapshot, and overflow that drops from the head. |
| `TomInMemoryLogReplayStore` | The zero-config default — buffered records live in a list and are lost if the process exits with the queue non-empty. |
| `TomFileLogReplayStore` | Durable alternative: every mutation is mirrored to a JSON file (written to a temp file and renamed into place), and construction reloads it, so the buffer survives a restart mid-outage. Requires `dart:io`, so it is not available on the web. |

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

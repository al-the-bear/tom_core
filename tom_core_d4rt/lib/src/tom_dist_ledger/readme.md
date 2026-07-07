# tom_dist_ledger

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Generated D4rt bridge for **[`tom_dist_ledger`](../../../../../distributed/tom_dist_ledger/README.md)**.
Registering `tom_core_d4rt` exposes the distributed-ledger primitives to
sandboxed DartScript, so REPL sessions and `.d4rt` scripts can
`import 'package:tom_dist_ledger/tom_dist_ledger.dart'` and use them directly.
The bridge forwards the API unchanged.

## What it bridges

The `TomDistLedgerBridge` container registers the public surface of
`tom_dist_ledger`, including `Ledger`, `LocalLedger`, `LedgerServer`,
`RemoteLedgerClient`, `Operation`/`LocalOperation`/`RemoteOperation`,
`ServerDiscovery`, `Call`/`CallFrame` and the retry/heartbeat helpers, plus the
`FrameState`, `OperationState`, `HeartbeatErrorType` and `DLLogLevel` enums. For
the authoritative API, read the upstream package README; this bridge mirrors it.

## Use it from a script

```dart
// d4rt REPL or a .d4rt script — the bridge is pre-registered.
import 'package:tom_dist_ledger/tom_dist_ledger.dart';

// Ledger, operation and discovery types are now in scope.
```

Inside the REPL, `info tom_dist_ledger` lists every bridged class and `classes`
lists them across all packages.

---

Bridges **[`tom_dist_ledger`](../../../../../distributed/tom_dist_ledger/README.md)**
· see [`doc/tom_dist_ledger.md`](../../../doc/tom_dist_ledger.md) for generation
notes. Part of [`tom_core_d4rt`](../../../README.md) — see the package README for
the REPL, the full bridge list, and build instructions.

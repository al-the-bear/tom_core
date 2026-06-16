# tom_process_monitor

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Generated D4rt bridge for **[`tom_process_monitor`](../../../../../distributed/tom_process_monitor/README.md)**.
Registering `tom_core_d4rt` exposes the process-monitoring toolkit to sandboxed
DartScript, so REPL sessions and `.d4rt` scripts can
`import 'package:tom_process_monitor/tom_process_monitor.dart'` and supervise
processes directly. The bridge forwards the API unchanged.

## What it bridges

The `TomProcessMonitorBridge` container registers the public surface of
`tom_process_monitor`, including `ProcessMonitor`, `ProcessMonitorClient`/
`LocalProcessMonitorClient`/`RemoteProcessMonitorClient`, `ProcessConfig`,
`ProcessControl`, `ProcessRegistry`/`RegistryService`, the aliveness checker
(`AlivenessChecker`, `AlivenessServer`), `ServerDiscovery` and the retry/restart
helpers, plus the `ProcessState` enum. For the authoritative API, read the
upstream package README; this bridge mirrors it.

## Use it from a script

```dart
// d4rt REPL or a .d4rt script — the bridge is pre-registered.
import 'package:tom_process_monitor/tom_process_monitor.dart';

// Monitor, client, registry and aliveness types are now in scope.
```

Inside the REPL, `info tom_process_monitor` lists every bridged class and
`classes` lists them across all packages.

---

Bridges **[`tom_process_monitor`](../../../../../distributed/tom_process_monitor/README.md)**
· see [`doc/tom_process_monitor.md`](../../../doc/tom_process_monitor.md) for
generation notes. Part of [`tom_core_d4rt`](../../../README.md) — see the package
README for the REPL, the full bridge list, and build instructions.

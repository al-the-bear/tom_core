# tom_basics

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Generated D4rt bridge for **[`tom_basics`](../../../../../basics/tom_basics/README.md)**.
Registering `tom_core_d4rt` exposes this package's public types to sandboxed
DartScript, so REPL sessions and `.d4rt` scripts can
`import 'package:tom_basics/tom_basics.dart'` and use them directly. The bridge
forwards the API unchanged — it does not redefine it.

## What it bridges

The `TomBasicsBridge` container registers the public surface of `tom_basics` —
core utilities, logging, platform/runtime detection and base exceptions —
including `TomLogger`, `TomLogLevel`, `TomLogOutput`, `TomPlatform`,
`TomRuntime`, `TomEnvironment` and `TomBaseException`. The sibling
`relaxers.b.dart` carries the generic-constructor relaxers. For the
authoritative API, read the upstream package README; this bridge mirrors it.

## Use it from a script

```dart
// d4rt REPL or a .d4rt script — the bridge is pre-registered.
import 'package:tom_basics/tom_basics.dart';

// All tom_basics public types are now in scope.
```

Inside the REPL, `info tom_basics` lists every bridged class and `classes` lists
them across all packages.

---

Bridges **[`tom_basics`](../../../../../basics/tom_basics/README.md)** · see
[`doc/tom_basics.md`](../../../doc/tom_basics.md) for generation notes. Part of
[`tom_core_d4rt`](../../../README.md) — see the package README for the REPL, the
full bridge list, and build instructions.

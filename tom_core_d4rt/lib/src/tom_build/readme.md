# tom_build

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Generated D4rt bridge for **[`tom_build`](../../../../../devops/tom_build/README.md)**.
Registering `tom_core_d4rt` exposes the build-system and workspace toolkit to
sandboxed DartScript, so REPL sessions and `.d4rt`/`.dcli` build scripts can
`import 'package:tom_build/tom_build.dart'` and drive the workspace directly.
The bridge forwards the API unchanged.

## What it bridges

The `TomBuildBridge` container registers the public surface of `tom_build` —
workspace/project modelling, shell and filesystem helpers, and the reflection-
generator runner — including `TomWorkspace`, `TomProject`, `WorkspaceAnalyzer`,
`WorkspaceParser`, `TomShell`, `TomFs`, `TomGlob`, `TomContext` and
`ReflectionGeneratorRunner`, plus the `CpuArchitecture` and `OperatingSystem`
enums. For the authoritative API, read the upstream package README; this bridge
mirrors it.

## Use it from a script

```dart
// d4rt REPL or a .d4rt script — the bridge is pre-registered.
import 'package:tom_build/tom_build.dart';

// Workspace/project types and shell helpers are now in scope.
```

Inside the REPL, `info tom_build` lists every bridged class and `classes` lists
them across all packages.

---

Bridges **[`tom_build`](../../../../../devops/tom_build/README.md)** · see
[`doc/tom_build.md`](../../../doc/tom_build.md) for generation notes. Part of
[`tom_core_d4rt`](../../../README.md) — see the package README for the REPL, the
full bridge list, and build instructions.

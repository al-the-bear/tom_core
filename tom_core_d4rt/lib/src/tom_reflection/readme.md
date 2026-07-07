# tom_reflection

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).
>
> `tom_reflection` is derived from the open-source
> [`reflectable`](https://pub.dev/packages/reflectable) package; that lineage and
> its mirror/capability vocabulary are credited in the upstream README.

Generated D4rt bridge for **[`tom_reflection`](../../../../../reflection/tom_reflection/README.md)**.
Registering `tom_core_d4rt` exposes the runtime-reflection toolkit to sandboxed
DartScript, so REPL sessions and `.d4rt` scripts can
`import 'package:tom_reflection/tom_reflection.dart'` and introspect reflected
types directly. The bridge forwards the API unchanged.

## What it bridges

The `TomReflectionBridge` container registers the public surface of
`tom_reflection`, including `Reflection`/`ReflectionInterface`, the mirror
hierarchy (`ClassMirror`, `InstanceMirror`, `MethodMirror`, `LibraryMirror`,
`VariableMirror`, `TypeMirror`) and the `*Capability` family
(`InstanceInvokeCapability`, `NewInstanceCapability`, `MetadataCapability`, …),
plus the `StringInvocationKind` enum. For the authoritative API, read the
upstream package README; this bridge mirrors it.

## Use it from a script

```dart
// d4rt REPL or a .d4rt script — the bridge is pre-registered.
import 'package:tom_reflection/tom_reflection.dart';

// Reflection, mirror and capability types are now in scope.
```

Inside the REPL, `info tom_reflection` lists every bridged class and `classes`
lists them across all packages.

---

Bridges **[`tom_reflection`](../../../../../reflection/tom_reflection/README.md)**
· see [`doc/tom_reflection.md`](../../../doc/tom_reflection.md) for generation
notes. Part of [`tom_core_d4rt`](../../../README.md) — see the package README for
the REPL, the full bridge list, and build instructions.

# reflection

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).
>
> The reflection layer derives from the **`reflectable`** package; see the
> [`tom_reflection`](../../../../../../reflection/tom_reflection/README.md)
> lineage for the full attribution and the derivation notes.

Build-time reflection for the kernel. `TomReflector` is the capability used to
mark types as reflectable; the generated mirrors let the observable, forms, and
persistence layers read declarations, members, and element types without
`dart:mirrors`.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomReflector` | The reflection capability; annotate types with it (commonly via `@tomReflector`) to make them reflectable. |
| `TomReflectionInfo` | Resolved metadata about a reflected type. |
| `TomReflectorException` | Thrown when a type is not reflectable or a mirror lookup fails. |

> Reflection metadata is produced by the
> [`tom_reflection_generator`](../../../../../../reflection/tom_reflection_generator/README.md)
> build step — annotate, run the generator, then reflect.

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Mark a domain type as reflectable; the generator emits its mirror.
@tomReflector
class TodoItem {
  String title = '';
  bool done = false;
}

// After generation, the kernel's observable/persistence layers can
// introspect TodoItem's declarations without `dart:mirrors`.
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

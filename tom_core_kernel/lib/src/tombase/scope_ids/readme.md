# scope_ids

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Hierarchical, zone-backed scope identity. `withScope` runs a body under a named
scope; nested calls build a parent/child chain, and `TomScope.current` reports
the active scope from anywhere inside the body. Forms and beans use scope ids to
namespace instances (e.g. one form per detail row).

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomScope` | Scope contract; `withScope`, `current`, `defaultScope`, `buildScopePath`. |
| `TomScopeBase` / `TomScopeMixin` | Default implementation and the mixin behind it. |
| `InScopeBuilder` | Fluent helper for running work inside a scope. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  TomScope.withScope('checkout', () {
    print(TomScope.current.id); // checkout

    TomScope.withScope('row-1', () {
      // The root 'default' scope is elided; segments join with '.'.
      print(TomScope.buildScopePath(TomScope.current)); // checkout.row-1
    });
  });
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

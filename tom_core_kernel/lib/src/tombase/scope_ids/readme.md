# scope_ids

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Hierarchical, zone-backed scope identity. `withScope` runs a body under a named
scope; nested calls build a parent/child chain, and `TomScope.current` reports
the active scope from anywhere inside the body. Forms and beans use scope ids to
namespace instances (e.g. one form per detail row).

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomScope` | Scope contract; `withScope`, `current`, `defaultScope`, `buildScopePath`. |
| `TomScopeBase` / `TomScopeMixin` | Default implementation and the mixin behind it. |
| `InScopeBuilder` | Captures the active scope and wraps callbacks so they run in it when invoked later. |
| `TomScopeException` | Raised when a scope is used before `initScope` gave it an identity (`scope_ids.use_scope.no_identity`). It fails at the point of use, because a half-built scope otherwise surfaces later on a stack mentioning neither scopes nor the constructor that skipped the call. |

## Quick start

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  TomScope.withScope('checkout', () {
    print(TomScope.current.id); // checkout

    TomScope.withScope('row-1', () {
      // The root scope is elided; segments join with '.'.
      print(TomScope.buildScopePath(TomScope.current)); // checkout.row-1
    });
  });
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

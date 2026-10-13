# context

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Zone-scoped ambient context. Lets a request, tenant, or user identity flow down
a call tree without threading it through every function signature, by storing
lazily-evaluated entries in the current Dart `Zone`.

The **tenant** — the isolation boundary whose data, caches and jobs these are —
has a slot of its own, `TomTenantContext`, set once at the edge (a request, a
job run). It is not the **organization**, a business unit inside a tenant; the
framework never infers one from the other. The `'tenant'` entry in the quick
start below is an ordinary named value.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomExecutionContext` | Holds a map of named context entries and runs a body inside a zone that exposes them; supports parent-context inheritance. |
| `TomContextEntry<T>` | A single named entry wrapping a lazy value provider. |
| `TomContextProviders` | Built-in providers for common context values. |
| `TomZoneValues` | Backing store keyed into the zone alongside the context. |
| `TomTenantContext` | The current tenant in the zone: `currentId`, `run`, `require`, `validate`, `qualify`. |
| `TomTenantException` | `tenancy.id.invalid` / `tenancy.context.missing`. |
| `TomTenantScopedCommand` | Runs a `TomCommand` inside a tenant wherever it executes, a worker isolate included. |
| `TomTenantEvent` | An event-triggered job's event, naming the tenant the run belongs to. |

## Quick start

```dart complete
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  final ctx = TomExecutionContext({
    // Always write the type parameter: the constructor takes a
    // Map<String, TomContextEntry>, so a raw TomContextEntry(() => 'acme')
    // here infers TomContextEntry<dynamic> and the typed read below would
    // silently return null.
    'tenant': TomContextEntry<String>(() => 'acme'),
  });

  ctx.runInContext(() {
    final tenant =
        TomExecutionContext.getValueFromCurrentZone<String>('tenant');
    print(tenant); // acme
  });
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

# resources

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Typed, eagerly-resolved configuration values. A `TomProperty<T>` reads its value
from the kernel `TomConfigResourceProvider` **once at construction** and caches
it; read it back with `get()` or the `~` operator.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomProperty<T>` | Generic config-value holder; resolves `key` from the app config at construction (or a `withDefault` fallback), caches it, exposes `get()` / `~`. Use a typed subclass rather than the generic directly. |
| `TomStringProperty` | `TomProperty<String>`. |
| `TomIntProperty` | `TomProperty<int>`. |
| `TomDoubleProperty` | `TomProperty<double>`. |
| `TomBoolProperty` | `TomProperty<bool>`. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

void main() {
  // Properties read config at construction, so populate the config provider first.
  TomConfigResourceProvider.setAppConfigProvider(
    TomConfigResourceProvider.from({'app.title': 'Todo'}),
  );

  final title = TomStringProperty('app.title');
  print(~title); // prints: Todo

  // Absent key + default → uses the default:
  final retries = TomIntProperty.withDefault('app.retries', 3);
  print(retries.get()); // prints: 3
}
```

> **Eager and immutable:** the value is captured at construction and never
> re-read, so later config changes are not reflected.

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

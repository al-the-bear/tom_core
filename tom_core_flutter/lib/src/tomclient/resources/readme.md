# resources

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Typed, eagerly-resolved configuration values. A `TomProperty<T>` reads its value
from the kernel `TomConfigResourceProvider` **once at construction** and caches
it; read it back with `get()` or the `~` operator.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomProperty<T>` | Generic config-value holder; resolves `key` from the app config at construction (or a `withDefault` fallback), caches it, exposes `get()` / `~`. Use a typed subclass for the four non-nullable value types below; the generic is the intended form when `T` is nullable. |
| `TomStringProperty` | `TomProperty<String>`. |
| `TomIntProperty` | `TomProperty<int>`. |
| `TomDoubleProperty` | `TomProperty<double>`. A configured whole number widens, since no config file can say "double"; it does not narrow and does not parse. |
| `TomBoolProperty` | `TomProperty<bool>`. |
| `TomPropertyException` | Raised from the constructor when resolution fails. One type, two `key` codes: `resources.property.not_configured` (absent, no default) and `resources.property.type_mismatch` (present, uncastable — `rootException` holds the `TypeError`). |

## Quick start

```dart complete
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

  // An optional value: `TomStringProperty` is `TomProperty<String>`, and a
  // non-nullable `String` cannot express "absent" — so use the generic:
  final region = TomProperty<String?>.withDefault('app.region', null);
  print(region.get()); // prints: null
}
```

> **Eager and immutable:** the value is captured at construction and never
> re-read, so later config changes are not reflected.

## Key resolution

The key goes to the provider unchanged, so a property inherits **dot notation
over nested maps**: `'app.db.host'` finds a `host` inside a `db` inside an
`app`, or a flat entry literally named `'app.db.host'`. The nested walk runs
first and the flat lookup is its fallback, so a config carrying both spellings
answers with the nested one. Descent stops at the last segment, which makes an
interior node a value in its own right — `TomProperty<Map<String, dynamic>>`
holds a subtree, and no typed subclass can.

A key configured with **no value** counts as absent: the lookup cannot tell
`app.region:` from a key that was never written, so an obligatory property
fails and a default wins. A configured `null` therefore never overrides a
non-null default. Where that distinction matters, ask the provider's public
`resources` map directly — a property cannot express it.

---

Part of [`tom_core_flutter`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

# resources

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Text- and config-resource lookup. A `TomTextResourceProvider` resolves keys
(flat `'title'` or dotted `'screens.home.title'`) against a nested resource map,
falling back to the key itself so missing strings are visible during
development. The provider feeds the labels/hints used by the forms and UI layers.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomTextResourceProvider` | Resolves text resources; `from(map)` / `load(loader)` construct it, `getText` / `getTextOrNull` look up. |
| `TomConfigResourceProvider` | Same resolution model applied to configuration values. |

The app-wide provider is installed once via
`TomTextResourceProvider.setAppResourceProvider(...)`.

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  final provider = TomTextResourceProvider.from({
    'screens': {
      'home': {'title': 'Welcome'},
    },
  });

  print(provider.getText('screens.home.title')); // Welcome
  print(provider.getText('missing.key'));        // missing.key  (fallback)
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

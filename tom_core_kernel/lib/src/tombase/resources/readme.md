# resources

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Text- and config-resource lookup. A `TomTextResourceProvider` resolves keys
(flat `'title'` or dotted `'screens.home.title'`) against a nested resource map,
falling back to the key itself so missing strings are visible during
development. The provider feeds the labels/hints used by the forms and UI layers.

## Key types

| Type | Responsibility |
| ---- | -------------- |
| `TomTextResourceProvider` | Resolves text resources; `from(map)` / `load(loader)` construct it, `getText` / `getTextOrNull` look up. |
| `TomConfigResourceProvider` | Same resolution model applied to configuration values. |
| `TomResourceException` | Raised when a provider is read before one is installed (`resources.text_provider.not_installed`) — a bootstrap bug reported at the first read rather than by rendering the whole UI in raw keys. |

The app-wide provider is installed once via
`TomTextResourceProvider.setAppResourceProvider(...)`.

## Announcing bundle changes

Installing a provider — or assigning a new map to the installed provider's
`resources` — bumps the observable `TomTextResourceProvider.appResourcesRevision`
(a `TomInt`). Mutating the installed map *in place* cannot be detected, so call
`TomTextResourceProvider.notifyAppResourcesChanged()` after doing so.

This is what makes a locale switch visible to derived observables: an
[`observable`](../observable/readme.md) `TomObservableEnum` observes the
revision and re-notifies, so bound widgets re-render their labels without the
caller rebuilding them.

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

# json

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are proprietary and internal (`publish_to: none`).

Map/JSON utilities used across the kernel: deep merging, dotted-path lookup,
recursive tree traversal/transformation, environment-variable substitution, and
pretty-printing. These are plain top-level functions — no types to instantiate.

## Key functions

| Function | Responsibility |
| -------- | -------------- |
| `mergeMapsOneSided(base, override)` | Deep-merge `override` into `base` in place. |
| `getObjectFromTree(tree, path)` | Resolve a dotted path (`a.b.c`) to a value. |
| `getPathFromTree(tree, path)` | Resolve a dotted path to its containing map. |
| `traverseAndProcess(tree, test, processor)` | Visit every node, processing matches. |
| `traverseAndCreate(tree, nameTest, creator)` | Visit every node, inserting derived nodes. |
| `substituteEnvVars(tree, env)` | Replace `${VAR}` placeholders from an env map. |
| `makeCleanJsonMap(map)` | Produce a JSON-safe `Map<String, Object>`. |
| `prettyJson(json)` / `prettyJsonLine(json)` | Indented / single-line formatting. |

## Quick start

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

void main() {
  final tree = {
    'screens': {
      'home': {'title': 'Welcome'},
    },
  };

  print(getObjectFromTree(tree, 'screens.home.title')); // Welcome
}
```

---

Part of [`tom_core_kernel`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.

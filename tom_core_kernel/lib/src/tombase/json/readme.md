# json

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Map/JSON utilities used across the kernel: deep merging, dotted-path lookup,
recursive tree traversal/transformation, environment-variable substitution, and
pretty-printing. These are plain top-level functions — no types to instantiate.

## Key functions

| Function | Responsibility |
| -------- | -------------- |
| `mergeMapsOneSided(base, override)` | Deep-merge `override` into `base` in place, leaving `override` untouched and unshared. |
| `deepCopyJsonTree(source)` | Deep-copy a tree so an in-place merge cannot reach the original. |
| `getObjectFromTree(tree, path)` | Resolve a dotted path (`a.b.c`) to a value, returning `null` for a key that is present and null, and throwing only for one that is absent. |
| `getPathFromTree(tree, path)` | Resolve a dotted path to its containing map, wrapping a non-map terminal (`null` included) under the supplied name. |
| `traverseAndProcess(tree, test, processor)` | Visit every node, processing matches. |
| `traverseAndCreate(tree, nameTest, creator)` | Visit every node, handing each matching key's containing map to a creator that may insert into, remove from, or overwrite it. |
| `substituteEnvVars(tree, env)` | Replace `${VAR}` placeholders from an env map. |
| `makeCleanJsonMap(map)` | Produce a JSON-safe `Map<String, Object?>`, keeping deliberate nulls and converting any `TomJsonSerializable` it meets. |
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

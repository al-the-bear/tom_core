# json

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Map/JSON utilities used across the kernel: deep merging, dotted-path lookup,
recursive tree traversal/transformation, profile-based injection,
environment-variable substitution, and pretty-printing. These are mostly plain
top-level functions; the one type, `TomJsonSerializable`, is an interface a
value object implements rather than a class to instantiate.

## Key types & functions

| Symbol | Responsibility |
| ------ | -------------- |
| `TomJsonSerializable` | Interface declaring that a value object renders itself to a JSON-encodable map. The escape hatch for a type that must match a wire shape it does not own — reflection is the default path. |
| `mergeMapsOneSided(base, override)` | Deep-merge `override` into `base` in place, leaving `override` untouched and unshared. |
| `deepCopyJsonTree(source)` | Deep-copy a tree so an in-place merge cannot reach the original. |
| `getObjectFromTree(tree, path)` | Resolve a dotted path (`a.b.c`) to a value, returning `null` for a key that is present and null, and throwing only for one that is absent. |
| `getPathFromTree(tree, path, name)` | Resolve a dotted path to the map at that path, wrapping a non-map terminal (`null` included) under `name`. |
| `traverseAndProcess(tree, test, processor)` | Visit every string in the tree — through nested maps, lists, and lists inside lists — processing matches. |
| `traverseAndCreate(tree, nameTest, creator)` | Visit every node, handing each matching *string-valued* key's containing map to a creator that may insert into, remove from, or overwrite it. Only strings reach the creator: a map- or list-valued key is handled by the recursion instead, whatever its name. |
| `processTree(tree, provider)` | Resolve `keyName@path@profileName` keys in place, injecting what the provider returns per the value directive (`"..."` spread, `"@"` replace-key, else replace). Every directive resolves before any is applied, so a failure leaves the tree untouched. |
| `substituteEnvVars(tree, env)` | Replace `${VAR}` placeholders from an env map; an empty value counts as unset, so use `${VAR:}` to resolve to empty. |
| `makeCleanJsonMap(map)` | Produce a JSON-safe `Map<String, Object?>`, keeping deliberate nulls and converting any `TomJsonSerializable` it meets. |
| `prettyJson(json)` / `prettyJsonLine(json)` | Indented / single-line formatting. |
| `indentEncoder` | The shared 2-space `JsonEncoder` behind both formatters, exported for callers that encode directly. |

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

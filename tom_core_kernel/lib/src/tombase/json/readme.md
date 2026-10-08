# json

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Map/JSON utilities used across the kernel: deep merging, dotted-path lookup,
recursive tree traversal/transformation, profile-based injection,
environment-variable substitution, and pretty-printing. These are mostly plain
top-level functions; `TomJsonSerializable` is an interface a value object
implements rather than a class to instantiate, and the two exception types are
what the module raises.

## Key types & functions

| Symbol | Responsibility |
| ------ | -------------- |
| `TomJsonSerializable` | Interface declaring that a value object renders itself to a JSON-encodable map. The escape hatch for a type that must match a wire shape it does not own — reflection is the default path. |
| `mergeMapsOneSided(base, override)` | Deep-merge `override` into `base` in place, leaving `override` untouched and unshared. |
| `deepCopyJsonTree(source)` | Deep-copy a tree so an in-place merge cannot reach the original. |
| `getObjectFromTree(tree, path)` | Resolve a dotted path (`a.b.c`) to a value, returning `null` for a key that is present and null, and throwing only for one that is absent. |
| `lookupObjectInTree(tree, path)` | The same lookup without the throw: `(found: false, value: null)` for a path that does not resolve, for a caller to whom a miss is an answer rather than a fault. |
| `getPathFromTree(tree, path, name)` | Resolve a dotted path to the map at that path, wrapping a non-map terminal (`null` included) under `name`. |
| `traverseAndProcess(tree, test, processor)` | Visit every string in the tree — through nested maps, lists, and lists inside lists — processing matches. |
| `traverseAndCreate(tree, nameTest, creator)` | Visit every node, handing each matching *string-valued* key's containing map to a creator that may insert into, remove from, or overwrite it. Only strings reach the creator: a map- or list-valued key is handled by the recursion instead, whatever its name. |
| `processTree(tree, provider)` | Resolve `keyName@path@profileName` keys in place, injecting what the provider returns per the value directive (`"..."` spread, `"@"` replace-key, else replace). Every directive resolves before any is applied, so a failure leaves the tree untouched. Whatever the provider throws propagates unaltered — type, message and stack trace — so callers catch the provider's own failure type. |
| `substituteEnvVars(tree, env)` | Replace `${VAR}` placeholders from an env map; an empty value counts as unset, so use `${VAR:}` to resolve to empty. |
| `makeCleanJsonMap(map)` | Produce a JSON-safe `Map<String, Object?>`, keeping deliberate nulls and converting any `TomJsonSerializable` it meets. |
| `prettyJson(json)` / `prettyJsonLine(json)` | Indented / single-line formatting. |
| `indentEncoder` | The shared 2-space `JsonEncoder` behind both formatters, exported for callers that encode directly. |
| `TomJsonPathException` | Raised when a dotted path cannot be resolved: `json.path.missing_key` for an absent key, `json.path.not_a_subtree` for an interior segment with nothing to descend into. |
| `TomJsonDirectiveException` | Raised when `processTree` cannot resolve a directive: `json.directive.malformed_key` for a key that carries three or more `@`, `json.directive.unresolved_key` when a `"@"` directive's provider returned no entry under its key. |
| `TomJsonCycleException` | Raised (`json.tree.cycle`) when a tree walk meets a value that refers back to one of its own ancestors. Every walker raises it except `makeCleanJsonMap`, which drops the back-reference instead. |

## What counts as a subtree

Every function that walks a tree treats **any map whose keys are all `String`**
as a subtree, whatever its reified type — `Map<dynamic, dynamic>` from
`TomYaml`, `Map<String, String>` from a literal and `Map<String, dynamic>` from
`jsonDecode` are descended into alike. A map with a non-`String` key is not a
subtree and is skipped whole: it cannot be a JSON object, and every callback
here takes a `String key`.

## Quick start

```dart complete
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

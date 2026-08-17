# Tom Core Kernel API Reference: JSON Module

A small set of JSON helpers: an explicit, reflection-free serialization contract
for immutable value objects, deep-merge / traversal / path-access / profile
injection utilities for nested map trees, and pretty-printing formatters.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomJsonSerializable](#tomjsonserializable)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Sources:
- `lib/src/tombase/json/json_serializable.dart`
- `lib/src/tombase/json/map_merge_and_process.dart`
- `lib/src/tombase/json/pretty_json.dart`

`TomJsonSerializable` is the declaration that a value object serializes itself.
Reflection is the default path for wire types, so this interface is the escape
hatch for the remainder — a type that must match an external wire shape it does
not own. Its value is that the declaration is a **cheap type test**: consumers
resolve it with an `is` check before the reflected field walk, rather than
probing for a speculative member. (`final` members are discouraged on wire types:
a `final` field is unassignable after construction, so reflection can never
populate it.)

`map_merge_and_process.dart` exposes top-level functions for working with nested
`Map<String, dynamic>` trees: one-sided deep merge (`mergeMapsOneSided`),
value/key traversal with callbacks (`traverseAndProcess`, `traverseAndCreate`),
dot-path access (`getPathFromTree`, `getObjectFromTree`), profile-based injection
(`processTree`), JSON sanitization (`makeCleanJsonMap`), and environment-variable
substitution (`substituteEnvVars`). `pretty_json.dart` provides `prettyJson` /
`prettyJsonLine` formatters and a reusable `indentEncoder`.

## Class Hierarchy

```
Object
└── (interfaces)
    └── TomJsonSerializable  (abstract interface)
```

## Classes

### TomJsonSerializable

Marks a value object that renders itself to a JSON-encodable map. Consumers that
render a value to JSON resolve this interface with an `is` check — the cheap type
test — before the reflected field walk. It is an escape hatch for types that must
match a wire shape they do not own, not the design default.

- **Extends:** none (abstract interface class)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | The JSON-encodable representation of this object — a map whose values are themselves `jsonEncode`-able. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `indentEncoder` | `JsonEncoder` | A reusable `JsonEncoder.withIndent("  ")` (2-space indentation) used by the pretty-printing formatters. Declared `final`, not `const` — `JsonEncoder.withIndent` is a run-time constructor call, so the encoder is built once on first use rather than canonicalised at compile time, and it cannot appear in a const context. |

### Functions

**What counts as a subtree.** Every function below that walks a tree —
`mergeMapsOneSided`, `traverseAndProcess`, `traverseAndCreate`,
`substituteEnvVars`, `getPathFromTree`, `getObjectFromTree` — treats any map
whose keys are all `String` as a subtree, whatever its reified type. A
`Map<dynamic, dynamic>` (from `TomYaml` or a round trip through an untyped
container) and a `Map<String, String>` (from a literal) are descended into just
like the `Map<String, dynamic>` that `jsonDecode` produces. The traversals still
edit in place: the string-keyed view they walk writes through to the caller's
map. A map with a non-`String` key is *not* a subtree — it cannot be a JSON
object and every callback here takes a `String key`, so it is skipped whole
rather than walked halfway.

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `mergeMapsOneSided` | `void mergeMapsOneSided(Map<String, dynamic> base, Map<String, dynamic> override)` | Recursively merges `override` into `base` in-place: nested maps merge recursively, and primitives/new keys from `override` are applied. Arrays merge element-by-element over the overlapping prefix and then take `override`'s tail, with base elements past `override`'s length kept; each element pair follows the same rules as a key/value pair, so a non-map, non-list override element replaces the base element. The merged array is a new `List<dynamic>` rather than the base array mutated in place. An `override` map or list landing on a base value of another shape — at a key or at an array index — is refused with a logged error and the base value kept. `override` is deep-copied before the merge, so it is never modified and the merged tree shares no map or list with it; use `deepCopyJsonTree` on `base` if the original must survive. |
| `deepCopyJsonTree` | `Map<String, dynamic> deepCopyJsonTree(Map<String, dynamic> source)` | Returns a deep copy of `source` sharing no map or list with it — unlike `Map<String, dynamic>.from`, which copies only the top level. Nested maps are normalised to `Map<String, dynamic>` and lists to `List<dynamic>` so the copy accepts values of any type; scalar leaves are shared, which is correct because JSON scalars are immutable. |
| `traverseAndProcess` | `void traverseAndProcess(Map<String, dynamic> tree, bool Function(String) test, String Function(String) processor)` | Walks `tree` in-place, applying `processor` to each String value where `test` returns `true`. Reaches every string whatever holds it: nested maps recurse, lists are walked per element, and a list element that is itself a list recurses too, so a map inside a list and a list inside a list are both descended into at any depth. Dispatch is on each value's runtime shape rather than a container's declared type, so a document straight out of `jsonDecode` behaves like one built in Dart code. |
| `traverseAndCreate` | `void traverseAndCreate(Map<String, dynamic> tree, bool Function(String) nameTest, void Function(String key, String value, Map<String, dynamic> location) creator)` | Walks `tree` and invokes `creator` for each *string-valued* key matching `nameTest`, handing it the key, that string, and the containing map. The value's shape is part of the match, not just the name: a matching key whose value is a map is recursed into instead of being reported, one whose value is a list is taken by the list branch and likewise never reported (its elements are walked only where the list is statically `List<Map<String, dynamic>>`), and one whose value is an `int`, `bool` or `null` is skipped outright. The creator takes a `String value`, so a non-string could not be delivered to it in any case. The creator may insert into, remove from, or overwrite that map directly — every recursion level iterates a snapshot of its map's keys, so mutating during the callback is safe at any depth, including a map an outer level is still walking. Keys the creator adds are not themselves traversed (the snapshot predates the visit), which is what keeps a creator that inserts a matching key from recursing forever; an entry it removes is skipped, because values are read through the map rather than from the snapshot. |
| `getPathFromTree` | `Map<String, dynamic> getPathFromTree(Map<String, dynamic> baseTree, String path, String name)` | Returns the subtree at a dot-separated `path`; wraps a non-map terminal value in a map keyed by `name`. A terminal `null` is such a value and yields `{name: null}`, which keeps it distinguishable from an absent path. The wrapping is reported through `tomLog.warn` and nowhere else — the return value does not distinguish it from a genuine subtree. Throws `Exception` if the path cannot be resolved. |
| `getObjectFromTree` | `Object? getObjectFromTree(Map<String, dynamic> baseTree, String path)` | Returns the raw value at a dot-separated `path` (map, list, primitive, or `null`). Presence is decided by `containsKey`, matching `makeCleanJsonMap`: a key present with a `null` value is a value and is returned as `null`, while a key that is absent throws. Throws `Exception` if a segment names a key that is not there, or if an interior segment holds something with no subtree to descend into — the message distinguishes a `null` from another non-map value. |
| `processTree` | `void processTree(Map<String, dynamic> tree, Map<String, dynamic> Function(String keyName, String path, String profileName) provider)` | Resolves `keyName@path@profileName` keys in-place, injecting data from `provider` per the value directive (`"..."` spread, `"@"` replace-key, else replace). The key pattern is anchored, so a key must be *entirely* three non-empty parts: a fourth part is not resolved against the first three. A key that does not match is an ordinary key and is left untouched (`user@example.com`, `@scope/pkg@1.0.0`), except that a key carrying three or more `@` — which a directive never does — throws `Exception` naming it and restating the expected form. The `"@"` directive takes the provider result's entry under the *same* key; an entry present with a `null` value is assigned like any other, while an absent one throws `Exception` naming the directive key, the resolved path, the profile and the keys the provider did return. Anything the provider throws propagates **unaltered** — same type, same message, same stack trace — so a caller catches the provider's own failure type instead of recovering it from a string; nothing is wrapped around it, because the only context a wrapper could add is the directive key, and that is just the three arguments the provider was called with. Every directive is resolved before any is applied, so any of these failures leaves `tree` exactly as it was passed. |
| `makeCleanJsonMap` | `Map<String, Object?> makeCleanJsonMap(Map map)` | Returns a new map containing only JSON-compatible values (String, int, double, bool, `null`, Map, List), recursively filtering out non-String keys and unsupported values. `null` is a JSON value and is kept, so an absent field stays distinguishable from one that is present and null. A `TomJsonSerializable` value is the one exception to the type filter: it is converted through its `toJson()` and the result cleaned in turn, wherever it appears in the tree. |
| `substituteEnvVars` | `void substituteEnvVars(Map<String, dynamic> tree, Map<String, String> environment)` | Substitutes `${VAR}` / `${VAR:default}` placeholders in all string values of `tree` in-place using `environment`. A variable present with an **empty** value counts as unset — `{'VAR': ''}` behaves as `{}` — following the shell's `${VAR:-default}` convention that the `:` mirrors. An empty *default* still resolves, so `${VAR:}` is how a caller asks for an empty string; a `${VAR}` whose value is empty keeps its placeholder. |
| `prettyJson` | `String prettyJson(String json)` | Parses `json` and re-encodes it with 2-space indentation and line breaks. Throws `FormatException` on invalid JSON. |
| `prettyJsonLine` | `String prettyJsonLine(String json)` | Like `prettyJson`, but collapses the output onto a single line (newlines replaced by spaces). |

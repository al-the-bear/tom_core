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
| `indentEncoder` | `JsonEncoder` | A reusable `JsonEncoder.withIndent("  ")` (2-space indentation) used by the pretty-printing formatters. |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `mergeMapsOneSided` | `void mergeMapsOneSided(Map<String, dynamic> base, Map<String, dynamic> override)` | Recursively merges `override` into `base` in-place: nested maps merge recursively, arrays merge element-by-element, and primitives/new keys from `override` are applied. |
| `traverseAndProcess` | `void traverseAndProcess(Map<String, dynamic> tree, bool Function(String) test, String Function(String) processor)` | Walks `tree` in-place, applying `processor` to each String value where `test` returns `true` (recurses into nested maps and list elements). |
| `traverseAndCreate` | `void traverseAndCreate(Map<String, dynamic> tree, bool Function(String) nameTest, void Function(String key, String value, Map<String, dynamic> location) creator)` | Walks `tree` and invokes `creator` for each key matching `nameTest`, allowing insertion of new nodes into the parent map. |
| `getPathFromTree` | `Map<String, dynamic> getPathFromTree(Map<String, dynamic> baseTree, String path, String name)` | Returns the subtree at a dot-separated `path`; wraps a non-map terminal value in a map keyed by `name`. Throws `Exception` if the path cannot be resolved. |
| `getObjectFromTree` | `Object getObjectFromTree(Map<String, dynamic> baseTree, String path)` | Returns the raw value at a dot-separated `path` (map, list, primitive). Throws `Exception` if the path cannot be resolved. |
| `processTree` | `void processTree(Map<String, dynamic> tree, Map<String, dynamic> Function(String keyName, String path, String profileName) provider)` | Resolves `keyName@path@profileName` keys in-place, injecting data from `provider` per the value directive (`"..."` spread, `"@"` replace-key, else replace). |
| `makeCleanJsonMap` | `Map<String, Object?> makeCleanJsonMap(Map map)` | Returns a new map containing only JSON-compatible values (String, int, double, bool, `null`, Map, List), recursively filtering out non-String keys and unsupported values. `null` is a JSON value and is kept, so an absent field stays distinguishable from one that is present and null. A `TomJsonSerializable` value is the one exception to the type filter: it is converted through its `toJson()` and the result cleaned in turn, wherever it appears in the tree. |
| `substituteEnvVars` | `void substituteEnvVars(Map<String, dynamic> tree, Map<String, String> environment)` | Substitutes `${VAR}` / `${VAR:default}` placeholders in all string values of `tree` in-place using `environment`. |
| `prettyJson` | `String prettyJson(String json)` | Parses `json` and re-encodes it with 2-space indentation and line breaks. Throws `FormatException` on invalid JSON. |
| `prettyJsonLine` | `String prettyJsonLine(String json)` | Like `prettyJson`, but collapses the output onto a single line (newlines replaced by spaces). |

# JSON Utilities Module

This module provides utilities for working with JSON data structures in Dart, including deep merging of maps, tree traversal with processing, path-based access, and pretty printing.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Core Components](#core-components)
- [Best Practices](#best-practices)
- [Dependencies](#dependencies)

---

## Overview

The JSON utilities module consists of three files:

| File | Purpose |
|------|---------|
| `json_serializable.dart` | The `TomJsonSerializable` contract — the cheap type test declaring a hand-written `toJson` |
| `map_merge_and_process.dart` | Deep merging, tree traversal, path access, environment substitution, and sanitization |
| `pretty_json.dart` | JSON formatting for human readability |

### TomJsonSerializable

**Reflection is the default path.** Wire types — requests, responses, DTOs, and
the framework's own value objects — serialize through the reflection path, and a
type should need nothing beyond `@tomReflectable` plain mutable fields to cross
the wire. Note the consequence for `final`: a `final` field cannot be assigned
after construction, so a reflective deserializer can never populate it. An
immutable all-`final` value object is un-deserializable by construction, which is
why **`final` members in request and response classes are discouraged**
throughout Tom Core.

`TomJsonSerializable` is for the remainder — a type that genuinely must control
its own JSON, typically to match an external wire shape it does not own. Its
value is that the declaration is **cheap to detect**: an `is` check, not a
speculative member invocation with the failure caught to decide whether the
member existed.

```dart
class Money implements TomJsonSerializable {
  Money(this.amount, this.currency);
  int amount;
  String currency;

  // The upstream price feed spells these `value` and `ccy`.
  @override
  Map<String, dynamic> toJson() => {'value': amount, 'ccy': currency};

  static Money fromJson(Map<String, dynamic> json) =>
      Money(json['value'] as int, json['ccy'] as String);
}
```

It is an escape hatch, not the design default. A type implementing it should be
a shape adapter carrying no business or security logic; if the only reason for
the manual path is a member name that does not match the wire name, rename the
member or the field instead.

A value implementing the interface may be left in place inside a map tree:
`makeCleanJsonMap` recognises it and converts it through `toJson()`, wherever it
sits — at the top level, nested in a sub-map, or inside a list. The result is
cleaned in turn, so a `toJson()` that itself nests a serializable is converted
too, and one that returns a genuinely non-JSON value still has it filtered out.

The rest of the module does not know the interface exists, and deliberately so.
`traverseAndProcess` and `substituteEnvVars` rewrite strings *in place* inside
mutable maps and lists, and `traverseAndCreate` edits those maps in place
through its callback; all three operate on decoded JSON — which never holds a
Dart object. Sanitization is the one point where a live object tree
meets JSON, so it is the one place the interface belongs.

## Quick Start

### Pretty Printing JSON

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Format JSON for readability
final compact = '{"name":"MyApp","config":{"port":8080,"debug":true}}';
print(prettyJson(compact));
// Output:
// {
//   "name": "MyApp",
//   "config": {
//     "port": 8080,
//     "debug": true
//   }
// }

// Single-line formatted (for logging)
print(prettyJsonLine(compact));
// Output: { "name": "MyApp", "config": { "port": 8080, "debug": true } }
```

### Merging Configuration Maps

```dart
import 'package:tom_core_kernel/tom_core_kernel.dart';

// Base configuration
final base = {
  'database': {
    'host': 'localhost',
    'port': 5432,
    'pool': {'min': 5, 'max': 20}
  },
  'features': ['auth', 'logging']
};

// Environment-specific overrides
final production = {
  'database': {
    'host': 'db.production.com',
    'pool': {'max': 100}
  },
  'features': ['oauth', 'logging', 'metrics', 'tracing']
};

// Merge production overrides into base
mergeMapsOneSided(base, production);

// Result:
// {
//   'database': {
//     'host': 'db.production.com',  // overridden
//     'port': 5432,                  // preserved
//     'pool': {'min': 5, 'max': 100} // nested merge
//   },
//   'features': ['oauth', 'logging', 'metrics', 'tracing']
//     // index 0 replaced, index 1 unchanged, indices 2-3 appended
// }
```

## Core Components

### Map Merge and Process (`map_merge_and_process.dart`)

#### `mergeMapsOneSided(base, override)`

Performs a deep merge of two maps, modifying `base` in-place.

**Merge Behavior:**
- **Nested maps**: Merged recursively
- **Arrays**: Elements merged by index over the overlapping prefix; a longer
  override appends its extra elements, and base elements beyond the override's
  length are kept. Each element pair follows the same rules as a key/value
  pair: maps merge recursively, lists merge by index in turn, and any other
  override element replaces the base element. The merged array is a new
  `List<dynamic>`, not the base array mutated in place.
- **Primitives**: Override values replace base values
- **New keys**: Added to base
- **Structural mismatch**: An override map or list landing on a base value of
  another shape — at a key or at an array index — is refused with a logged
  error, and the base value is kept.
- **Ownership**: `override` is deep-copied before the merge, so the merged tree
  shares no map or list with it. Editing either document afterwards cannot
  affect the other, and `override` itself is never modified.

#### `deepCopyJsonTree(source)`

Returns a deep copy of `source` that shares no map or list with it — every
nested container is rebuilt. Use it to keep a document intact across a merge,
which mutates its first argument. Nested maps are normalised to
`Map<String, dynamic>` and lists to `List<dynamic>`, so the copy accepts values
of any type; scalar leaves are shared, which is correct because JSON scalars
are immutable.

#### `traverseAndProcess(tree, test, processor)`

Recursively walks a tree and transforms string values matching a condition.

```dart
final config = {
  'apiUrl': '${BASE_URL}/api',
  'wsUrl': '${BASE_URL}/ws',
  'name': 'MyApp'  // Won't match, left unchanged
};

traverseAndProcess(
  config,
  (s) => s.contains(r'${BASE_URL}'),
  (s) => s.replaceAll(r'${BASE_URL}', 'https://api.example.com'),
);
// config['apiUrl'] == 'https://api.example.com/api'
```

##### Every string is reached, whatever holds it

Nested maps recurse, lists are walked per element, and a list element that is
itself a list recurses too — so a map inside a list, a list inside a list, and
any deeper combination are all descended into:

```dart
final tree = jsonDecode(r'{"m":[["${A}"],"${A}"]}') as Map<String, dynamic>;

substituteEnvVars(tree, {'A': 'ok'});
// tree['m'] == [['ok'], 'ok']
```

Dispatch is on each value's runtime shape rather than on a container's declared
type. That is what makes a document straight out of `jsonDecode` — where every
map is `Map<String, dynamic>` and every list is `List<dynamic>` — behave the
same as one built in Dart code.

#### `traverseAndCreate(tree, nameTest, creator)`

Traverses a tree and invokes a callback for each key matching `nameTest`,
handing it the key, its string value, and the map that contains it.

```dart
final config = {'ref@profiles@dev': 'value'};

traverseAndCreate(
  config,
  (name) => name.contains('@'),
  (key, value, location) {
    location['resolved'] = value.toUpperCase();
  },
);
// config == {'ref@profiles@dev': 'value', 'resolved': 'VALUE'}
```

##### The creator may edit the map it is given

Inserting into `location`, removing from it, and overwriting it are all
supported, at every depth — including a map that an outer recursion level is
still walking. The traversal iterates a *snapshot* of each map's keys rather
than the map itself, which is what makes this safe; walking the map directly
would throw `ConcurrentModificationError` on the first insert, leaving the
callback's one useful parameter unusable.

Two consequences follow from the snapshot:

- **Keys the creator adds are not traversed.** The snapshot for a map is taken
  before its entries are visited. That is deliberate — a creator that inserts a
  key its own `nameTest` matches would otherwise call itself forever. Run the
  traversal again if newly created nodes must themselves be expanded.
- **An entry the creator removes is skipped** when the walk reaches it. Values
  are read through the map, not from the snapshot, so a key that has since gone
  reads back as `null` and matches no branch.

#### `getPathFromTree(baseTree, path, name)`

Navigates to a nested location using dot-separated paths.

```dart
final config = {
  'services': {
    'database': {
      'primary': {'host': 'db1.local', 'port': 5432}
    }
  }
};

final primary = getPathFromTree(config, 'services.database.primary', 'result');
// Returns: {'host': 'db1.local', 'port': 5432}
```

#### `getObjectFromTree(baseTree, path)`

Similar to `getPathFromTree` but returns the raw value (not wrapped).

```dart
final port = getObjectFromTree(config, 'services.database.primary.port');
// Returns: 5432
```

##### Present-and-null vs absent

The return type is `Object?`, and a `null` return means the terminal key **is
there and holds null**. A path that does not resolve throws instead, so the two
never look alike:

```dart
final config = {'db': {'port': 5432, 'replica': null}};

getObjectFromTree(config, 'db.replica');  // null — deliberately cleared
getObjectFromTree(config, 'db.absent');   // throws
```

Absence is decided by `containsKey`, which is the same position
`makeCleanJsonMap` takes when it keeps a present `null` rather than dropping it:
an absent field and a field that is present and null mean different things, and
only the absent one may fall back to a default.

`null` is a fine terminal value but cannot be *walked through* — `db.replica.x`
throws, with a message saying it stopped at a null rather than that the key was
missing.

`getPathFromTree` inherits all of this, and wraps a terminal `null` like any
other non-map value, giving `{name: null}`.

#### `processTree(tree, provider)`

Processes profile-based references in configuration trees.

Keys matching the pattern `keyName@path@profileName` are resolved using the provider function.

##### A directive key is the whole key

The match is anchored: the key must be *entirely* three non-empty
`@`-separated parts. A key with a fourth part is not resolved against its first
three — the shape is either the documented one or it is not a directive at all.

A key that does not match is an ordinary key and is left untouched.
`user@example.com` is a map key, and so are `@scope/package@1.0.0` and the
timezoned module's own `@D@2024-06-14T15:00:00.000Z_+09:00_Asia/Tokyo`; all
carry `@` without meaning a directive.

The one exception is a key carrying **three or more** `@`. A directive uses
exactly two, so a third can only be a separator too many — no ordinary string in
this framework reaches three. Such a key throws an `Exception` naming it and
restating the expected form, rather than being silently skipped, because a
skipped directive is an injection the caller believes happened and did not.

**Value Directives:**
- `"..."` - Spread resolved data into current map
- `"@"` - Replace with value at same key from resolved data
- Other - Replace with entire resolved structure

##### The `"@"` directive needs the key it names

`"@"` takes the value the provider returned *under the same key*, so
`wanted@path@profile: "@"` needs a provider result containing `wanted`. When it
is absent, `processTree` throws an `Exception` naming the directive key, the
resolved path, the profile, and the keys the provider did return — enough to see
whether the provider looked in the wrong place or the profile is simply missing
the entry.

A provider result containing the key with a `null` value is a value like any
other and is assigned; only an **absent** key is a failure. This is the same
present-vs-absent distinction `getObjectFromTree` and `makeCleanJsonMap` draw.

Every directive in the tree is resolved before any is applied, so a failure
leaves the tree exactly as it was passed — the operation does not half-complete,
and a caller that catches can retry with a corrected provider on the same tree.

#### `makeCleanJsonMap(map)`

Creates a sanitized copy containing only JSON-compatible values (String, int,
double, bool, `null`, Map, List).

`null` is a JSON value and is **kept**. An absent field and a field that is
present and null mean different things — to a PATCH-style partial update, to a
settings map where null means "explicitly cleared", to a DTO whose schema
declares the field nullable — so the sanitizer preserves the distinction instead
of collapsing it.

A `TomJsonSerializable` is the one exception to the type filter: it is converted
through its `toJson()` rather than dropped, and the result cleaned in turn.
Everything else is filtered out **silently** — a `DateTime` disappears with no
error and no log line, so give a type a `toJson()` when its value must survive.

```dart
final dirty = {
  'name': 'App',
  'created': DateTime.now(),      // Not JSON-compatible — dropped
  'discount': null,               // A JSON value — kept
  'price': Money(12, 'EUR'),      // TomJsonSerializable — converted
  'port': 8080
};

final clean = makeCleanJsonMap(dirty);
// clean == {
//   'name': 'App',
//   'discount': null,
//   'price': {'amount': 12, 'currency': 'EUR'},
//   'port': 8080,
// }
```

### Pretty JSON (`pretty_json.dart`)

#### `prettyJson(json)`

Formats a compact JSON string with indentation (2 spaces).

#### `prettyJsonLine(json)`

Formats JSON but collapses to a single line (useful for logging).

## Usage Examples

### Configuration Layering

A common pattern is to layer configurations from multiple sources:

```dart
// Load base configuration
final baseConfig = loadJsonFile('config/base.json');

// Load environment-specific overrides
final envConfig = loadJsonFile('config/${environment}.json');

// Load local developer overrides (if exists)
final localConfig = loadJsonFile('config/local.json');

// Merge in order of precedence
mergeMapsOneSided(baseConfig, envConfig);
mergeMapsOneSided(baseConfig, localConfig);

// baseConfig now contains fully merged configuration.
// envConfig and localConfig are untouched and stay independent of it: the
// merge copies what it takes from them, so the second merge cannot write
// back into the document the first one merged.
```

### Environment Variable Substitution

Use `substituteEnvVars` — it walks every string in the tree and rewrites
`${VAR}` placeholders in place:

```dart
final config = <String, dynamic>{
  'host': r'${DB_HOST:localhost}',
  'port': r'${DB_PORT}',
};

substituteEnvVars(config, Platform.environment);
// {'host': 'production.db.com', 'port': '5432'}
```

`${VAR:default}` supplies a fallback; a `${VAR}` with no default and no matching
entry is left in the tree unchanged, so an unresolved placeholder is visible
rather than silently blank. Multiple placeholders in one string are all
replaced.

#### An empty value counts as unset

A variable present in the environment map with an empty value is treated exactly
as an absent one — `{'VAR': ''}` and `{}` give the same result. This follows the
shell's `${VAR:-default}` convention, which the `:` in `${VAR:default}` mirrors:
the colon form is the one that folds empty into unset.

```dart
substituteEnvVars({'a': r'${V:fallback}'}, {'V': ''});  // 'fallback'
substituteEnvVars({'a': r'${V}'},          {'V': ''});  // '${V}' survives
substituteEnvVars({'a': r'${V:}'},         {});         // '' — empty default
```

The third line is the one to hold on to. An empty *default* is a default that
happens to be empty, and resolves; an empty *value* does not. So a caller
passing `Platform.environment` cannot express "this variable is deliberately
empty" — a `VAR=` in the environment leaves a literal `${VAR}` in the config.
Write `${VAR:}` when empty is the intended resolution.

### Debugging API Responses

```dart
try {
  final response = await http.get(apiUrl);
  logger.debug('Response: ${prettyJson(response.body)}');
} catch (e) {
  logger.error('Failed to fetch: $e');
}
```

## Best Practices

### 1. Immutability Consideration

`mergeMapsOneSided` modifies the base map in-place. If you need to preserve the
original, copy it with `deepCopyJsonTree`:

```dart
final merged = deepCopyJsonTree(baseConfig);
mergeMapsOneSided(merged, overrides);
// baseConfig is untouched
```

**Do not use `Map<String, dynamic>.from` for this.** It copies only the top
level, so `merged` still shares every nested subtree with `baseConfig` and the
merge writes straight through into the original you meant to protect — the
deeper the config, the more of it is unprotected.

The *second* argument needs no such care: `mergeMapsOneSided` deep-copies the
override before merging, so the merged tree shares no map or list with it and
the two documents stay independent afterwards.

### 2. Error Handling for Paths

Path-based access throws exceptions for paths that do not resolve. Handle
appropriately:

```dart
final Object? value;
try {
  value = getObjectFromTree(config, 'path.to.value');
} catch (e) {
  // The path doesn't exist — nobody configured it, so a default applies.
  value = defaultValue;
}
```

**A `null` result is not an error and must not reach that fallback.** It means
the key is present and was deliberately set to null; substituting the default
would discard the setting. The `catch` above is already correct on this point —
a present null returns normally rather than throwing — but code that tests
`value == null` to decide whether to apply a default has the bug.

### 3. Type Safety

When working with dynamic maps, validate types before use:

```dart
final port = getObjectFromTree(config, 'database.port');
if (port is int) {
  connectToDatabase(port);
} else {
  throw ConfigurationError('database.port must be an integer');
}
```

### 4. JSON Sanitization

Always sanitize maps before JSON encoding if they may contain non-JSON types:

```dart
final safeData = makeCleanJsonMap(possiblyDirtyMap);
final jsonString = jsonEncode(safeData);
```

---

## Dependencies

This module has no internal Tom dependencies. It uses:

- **dart:convert**: Built-in JSON encoding/decoding

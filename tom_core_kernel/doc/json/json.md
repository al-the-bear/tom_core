# JSON Utilities Module

This module provides utilities for working with JSON data structures in Dart, including deep merging of maps, tree traversal with processing, path-based access, and pretty printing.

## Table of Contents

- [Overview](#overview)
  - [TomJsonSerializable](#tomjsonserializable)
- [Quick Start](#quick-start)
  - [Pretty Printing JSON](#pretty-printing-json)
  - [Merging Configuration Maps](#merging-configuration-maps)
- [Core Components](#core-components)
  - [JSON Serializable (`json_serializable.dart`)](#json-serializable-json_serializabledart)
  - [Map Merge and Process (`map_merge_and_process.dart`)](#map-merge-and-process-map_merge_and_processdart)
  - [Pretty JSON (`pretty_json.dart`)](#pretty-json-pretty_jsondart)
- [Usage Examples](#usage-examples)
  - [Configuration Layering](#configuration-layering)
  - [Environment Variable Substitution](#environment-variable-substitution)
  - [Debugging API Responses](#debugging-api-responses)
- [Best Practices](#best-practices)
  - [1. Immutability Consideration](#1-immutability-consideration)
  - [2. Error Handling for Paths](#2-error-handling-for-paths)
  - [3. Type Safety](#3-type-safety)
  - [4. JSON Sanitization](#4-json-sanitization)
- [Dependencies](#dependencies)
  - [What the module logs](#what-the-module-logs)

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
throughout Tom Core. The reflection module refuses such a class in both
directions rather than degrading quietly: inbound, a payload key naming a
`final` member raises
`reflection.set.unexpected_condition_final_static_private`; outbound, a class
whose every wire member was skipped for being `final` raises
`reflector.type.all_final` instead of returning `{}`.

Implementing `TomJsonSerializable` is *not* the way to keep an all-`final` DTO —
that trades a diagnosable refusal for a hand-written codec the guidelines
discourage (G-DTO-2, G-DTO-3). It is for the remainder — a type that genuinely must control
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
  Map<String, Object?> toJson() => {'value': amount, 'ccy': currency};

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

One subsection per file the module exports, in the order the
[Overview](#overview) table lists them. The first is a pointer rather than a
description: `TomJsonSerializable` is a contract whose interesting part is
*when not to implement it*, and that argument is made once, above, rather than
twice.

### JSON Serializable (`json_serializable.dart`)

One type, `TomJsonSerializable`, declaring one member, `Map<String, Object?>
toJson()`.

It is documented under [Overview → TomJsonSerializable](#tomjsonserializable),
because the reason to reach for it cannot be stated without the reason not to:
reflection is the default path, an all-`final` DTO is un-deserializable by
construction, and implementing this contract to keep one trades a diagnosable
refusal for a hand-written codec the guidelines discourage. That section says
so; repeating it here would be a second copy of an argument that has to stay in
step with the reflection module.

### Map Merge and Process (`map_merge_and_process.dart`)

#### What counts as a subtree

Every function in this module that walks a tree — `mergeMapsOneSided`,
`traverseAndProcess`, `traverseAndCreate`, `substituteEnvVars`,
`getObjectFromTree`, `getPathFromTree` — treats **any map whose keys are all
`String`** as a subtree, whatever its reified type. A `Map<dynamic, dynamic>`,
a `Map<String, String>` and a `Map<String, dynamic>` are all descended into
alike.

This matters because the reified type is not under the caller's control as
often as it looks. `jsonDecode` always produces `Map<String, dynamic>`, but
`TomYaml.loadYamlFile`, a hand-written map literal and anything round-tripped
through an untyped container do not. A reified `is Map<String, dynamic>` test
would walk those maps past without an error or a log line, leaving their
contents untransformed — which is why the test is on the keys instead.

The one map that is *not* a subtree is one with a non-`String` key. It cannot
be a JSON object, and every callback in this module takes a `String key`, so
there is nothing meaningful to hand them; it is skipped whole rather than
walked halfway. A merge that lands an override subtree on such a map reports
the structural mismatch like any other.

The traversals still edit in place: the string-keyed view they walk writes
through to the map the caller passed in, so a caller holding a reference to an
untyped child sees the substitutions through it.

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

Traverses a tree and invokes a callback for each *string-valued* key matching
`nameTest`, handing it the key, that string, and the map that contains it.

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

##### The value's shape is part of the match

`nameTest` sees only the key, but the name is not the whole condition: the
value has to be a `String` as well. The branches are mutually exclusive, so a
matching key whose value is a map is recursed into instead of being reported,
and one whose value is a list is taken by the list branch and likewise never
reported. A matching key whose value is an `int`, `bool` or `null` is skipped
outright.

This is not an incidental restriction to be relaxed later — the callback's
signature is `void Function(String key, String value, Map location)`, so there
is no shape other than `String` it could be handed. A directive vocabulary
designed around map- or list-valued keys is therefore one this function cannot
deliver, however well the names match; express such a directive as a string
value, the way `processTree` does.

##### Lists are walked per element

Dispatch is on each value's runtime shape, not on a container's declared type,
so a decoded `List<dynamic>` is descended into like any other and a list nested
inside a list is reached at any depth. A typed check on the list itself would
match only an array a Dart literal built, and would skip a decoded one in
silence.

There is no string branch, unlike `traverseAndProcess`'s list walk. That is the
point rather than an omission: this traversal selects on key *names*, and an
element of a list has no key. A string reaches the creator only as the value of
a matching key — `{'tags': ['a@b']}` reports nothing.

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

##### A provider's failure is the caller's failure

Whatever the provider throws propagates **unaltered** — same type, same message,
same stack trace. A provider that resolves through `getObjectFromTree` throws a
path exception; the caller catches *that*, on its own type, rather than
recovering it by substring-matching a wrapper's message. An `Error` stays an
`Error` too, so a bug in the provider is still distinguishable from a
resolution failure.

Nothing is wrapped around it, and that is deliberate rather than an omission.
The only context a wrapper could add is the directive key and its value — but
the key is exactly the concatenation of the three arguments the provider was
just called with, and the value is the directive, which the provider never sees
and which plays no part in the call that failed. So the wrapper had nothing to
contribute and two things to lose. A provider whose own errors need to name the
profile being resolved should say so itself; `processTree` will not paraphrase
it.

Every directive in the tree is resolved before any is applied, so a failure
leaves the tree exactly as it was passed — the operation does not half-complete,
and a caller that catches can retry with a corrected provider on the same tree.
That holds for a provider failure too: a directive resolved earlier in the same
call is discarded rather than written.

##### A resolved directive's key is consumed

The key that asked for a value is removed from its map once the value is
written. A directive is an *instruction*; one that has been carried out is not
part of the configuration it produced. Left in place it would travel with the
resolved tree into everything downstream — an encode, a diff against the
unresolved document, a re-merge — each of which would see the instruction beside
its own result.

```dart
final tree = {'database@services.db@production': '@'};
processTree(tree, provider);
// tree == {'database': {...}}   — not {'database@services.db@production': '@', 'database': {...}}
```

The consequence worth naming is **idempotence**: resolving an already-resolved
tree calls the provider for nothing, because there is no directive left to
resolve. A provider is typically a vault read, a file load or a token mint, so
running one a second time is at best wasted work and at worst a repeated side
effect.

Removal happens with the write rather than with the resolution, so the
collect-before-apply guarantee above covers it too: a failure leaves every
directive key exactly where it was. It also settles the one case where the order
shows: a spread whose provider echoes the directive key back cannot resurrect
it, which would otherwise leave a key the next resolution would act on again.

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

Formats JSON but collapses to a single line (useful for logging). It runs
`prettyJson` and joins the result's lines with a space, so the indentation
becomes runs of spaces rather than being removed — this is a one-line
*rendering*, not a compact encoding.

#### `indentEncoder`

The `JsonEncoder.withIndent("  ")` both formatters ultimately run through:
`prettyJson` converts with it, and `prettyJsonLine` flattens what `prettyJson`
returned. It is exported because the two functions above take a **`String`** and
decode it first, so a caller who already holds a decoded object would otherwise
have to encode it only to have it parsed straight back:

```dart
// Already holding a Map — encode it directly rather than round-tripping.
print(indentEncoder.convert(config));

// Holding wire text — prettyJson decodes it for you.
print(prettyJson(responseBody));
```

It is `final`, so the two-space width is fixed. A caller wanting a different
indent builds their own `JsonEncoder.withIndent`; nothing here reads this one
as a setting.

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

That limit is the shell's too, and stands deliberately. A script written with
`${VAR:-default}` cannot be handed an empty value either; the shell's escape is
a *second* form, `${VAR-default}`, which this module has no counterpart to.
Adding one would not reach the operator the limit is about — either form lives
in the config file, not in the environment they set, so the choice would remain
the config author's exactly as it is now.

And the author already has it. The gap bites in one combination only: the
placeholder is `${VAR}` with no default **and** the operator wants empty.
Writing no default is how an author says the value is mandatory, so the
surviving placeholder there is the loud failure it is meant to be. Where empty
is legitimate the author writes `${VAR:}`, and then `VAR=` and an unset `VAR`
both resolve to empty — which is what the operator wanted.

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
  throw TomException(
    'config.validate.type_mismatch',
    'database.port must be an integer',
    parameters: {'key': 'database.port', 'value': port},
  );
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

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:convert` | dart | `pretty_json.dart` | The `JsonEncoder` behind the formatters |
| `tom_basics` | package | `map_merge_and_process.dart` | `tomLog`, for the reports listed below |

`json_serializable.dart` imports nothing — the interface is plain Dart. Note
that `map_merge_and_process.dart` does *not* use `dart:convert`:
`makeCleanJsonMap` prepares a map for `jsonEncode` but leaves the encoding to
the caller.

`tomLog` is a live global with a working default, so nothing has to be wired up
before calling into this module. The package dependency is nonetheless real —
the module does not compile without `tom_basics`.

### What the module logs

Two functions report through `tomLog`, and both report *only* there. Neither
throws, and neither returns anything that indicates the report happened:

| Function | Level | Reported when |
| -------- | ----- | ------------- |
| `mergeMapsOneSided` | `error` | A structured override lands on a base value of another shape and is refused: a map onto a non-map, a list onto a non-list, or either onto a differently-shaped element at an array index. The base value is kept and the merge continues. |
| `getPathFromTree` | `warn` | The path resolves to a terminal non-map value, which is then wrapped as `{name: value}`. |

The consequence is worth stating plainly: a caller that discards log output has
no way to learn that a merge silently kept the base value instead of applying
part of its override. If that matters, capture `tomLog` output around the call
rather than inspecting the merged tree, which looks the same either way.

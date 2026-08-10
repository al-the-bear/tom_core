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
| `json_serializable.dart` | The `TomJsonSerializable` contract for hand-written `toJson` |
| `map_merge_and_process.dart` | Deep merging, tree traversal, path access, environment substitution, and sanitization |
| `pretty_json.dart` | JSON formatting for human readability |

### TomJsonSerializable

For types that cannot be reflected — an immutable value object with `final`
fields and no zero-argument constructor — `TomJsonSerializable` names the
hand-written serialization contract:

```dart
class Money implements TomJsonSerializable {
  const Money(this.amount, this.currency);
  final int amount;
  final String currency;

  @override
  Map<String, dynamic> toJson() => {'amount': amount, 'currency': currency};

  static Money fromJson(Map<String, dynamic> json) =>
      Money(json['amount'] as int, json['currency'] as String);
}
```

A value implementing the interface may be left in place inside a map tree:
`makeCleanJsonMap` recognises it and converts it through `toJson()`, wherever it
sits — at the top level, nested in a sub-map, or inside a list. The result is
cleaned in turn, so a `toJson()` that itself nests a serializable is converted
too, and one that returns a genuinely non-JSON value still has it filtered out.

The rest of the module does not know the interface exists, and deliberately so.
`traverseAndProcess`, `traverseAndCreate` and `substituteEnvVars` rewrite strings
*in place* inside mutable maps and lists, and operate on decoded JSON — which
never holds a Dart object. Sanitization is the one point where a live object tree
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
  'features': ['auth', 'logging', 'metrics', 'tracing']
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
//   'features': ['auth', 'logging', 'metrics', 'tracing']  // extended
// }
```

## Core Components

### Map Merge and Process (`map_merge_and_process.dart`)

#### `mergeMapsOneSided(base, override)`

Performs a deep merge of two maps, modifying `base` in-place.

**Merge Behavior:**
- **Nested maps**: Merged recursively
- **Arrays**: Elements merged by index; longer arrays append extra elements
- **Primitives**: Override values replace base values
- **New keys**: Added to base

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

#### `traverseAndCreate(tree, nameTest, creator)`

Traverses a tree and invokes a callback for keys matching a pattern, allowing insertion of new nodes.

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

#### `processTree(tree, provider)`

Processes profile-based references in configuration trees.

Keys matching the pattern `keyName@path@profileName` are resolved using the provider function.

**Value Directives:**
- `"..."` - Spread resolved data into current map
- `"@"` - Replace with value at same key from resolved data
- Other - Replace with entire resolved structure

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

// baseConfig now contains fully merged configuration
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

`mergeMapsOneSided` modifies the base map in-place. If you need to preserve the original:

```dart
final merged = Map<String, dynamic>.from(baseConfig);
mergeMapsOneSided(merged, overrides);
```

### 2. Error Handling for Paths

Path-based access throws exceptions for invalid paths. Handle appropriately:

```dart
try {
  final value = getObjectFromTree(config, 'path.to.value');
} catch (e) {
  // Path doesn't exist, use default
  final value = defaultValue;
}
```

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

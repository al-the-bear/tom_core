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

The JSON utilities module consists of two main files:

| File | Purpose |
|------|---------|
| `map_merge_and_process.dart` | Deep merging, tree traversal, path access, and sanitization |
| `pretty_json.dart` | JSON formatting for human readability |

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

Creates a sanitized copy containing only JSON-compatible types (String, int, double, bool, Map, List).

```dart
final dirty = {
  'name': 'App',
  'created': DateTime.now(),  // Not JSON-compatible
  'port': 8080
};

final clean = makeCleanJsonMap(dirty);
// clean == {'name': 'App', 'port': 8080}
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

Replace placeholders with environment variables:

```dart
traverseAndProcess(
  config,
  (value) => value.startsWith(r'${') && value.endsWith('}'),
  (value) {
    final varName = value.substring(2, value.length - 1);
    return Platform.environment[varName] ?? value;
  },
);
```

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

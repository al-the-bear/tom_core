/// Utilities for merging and processing nested JSON map structures.
///
/// This module provides functions for:
/// - **Deep merging** of nested `Map<String, dynamic>` structures
/// - **Tree traversal** with custom processing callbacks
/// - **Path-based access** to nested map values
/// - **Tree modification** with profile-based injection patterns
///
/// These utilities are particularly useful for configuration management,
/// where base configurations need to be merged with environment-specific
/// overrides while preserving nested structure.
///
/// ## Example: Merging configurations
/// ```dart
/// final base = {'database': {'host': 'localhost', 'port': 5432}};
/// final override = {'database': {'host': 'production.db.com'}};
/// mergeMapsOneSided(base, override);
/// // base is now {'database': {'host': 'production.db.com', 'port': 5432}}
/// ```
library;

// =============================================================================
// Imports
// =============================================================================

import 'package:tom_basics/tom_basics.dart';

import 'json_serializable.dart';

// =============================================================================
// Private Helpers
// =============================================================================

/// Merges [override] into [base] positionally and returns the merged list.
///
/// Each overlapping element pair is combined by the same rules
/// [mergeMapsOneSided] applies to a key/value pair, so "merged element-by-
/// element" means the same thing at every depth:
///
/// - two maps merge recursively;
/// - two lists merge positionally, through this function;
/// - a map or list override landing on a base element of another shape is a
///   structural mismatch: it is refused with an error and the base element
///   stays, exactly as a subtree override onto a scalar key does;
/// - anything else — every scalar — is replaced by the override element.
///
/// Base elements past the override's length are kept; override elements past
/// the base's length are appended. [name] only labels error messages.
///
/// The result is always a fresh `List<dynamic>` rather than [base] mutated in
/// place. [base] may be reified narrowly — a literal like
/// `[<String, Object>{'a': 1}]` is a `List<Map<String, Object>>` at runtime,
/// and writing a scalar override element into it would throw — so a list that
/// accepts every element type has to be allocated for the result.
List<dynamic> _mergeListsOneSided(
  List<dynamic> base,
  List<dynamic> override,
  String name,
) {
  final List<dynamic> result = List<dynamic>.of(base);

  // Only the overlapping prefix has two elements to combine. Iterating to
  // base.length unconditionally caused a RangeError when the override array
  // was shorter (bug §44).
  final int overlap =
      base.length < override.length ? base.length : override.length;
  for (int i = 0; i < overlap; i++) {
    final Object? baseElement = base[i];
    final Object? overrideElement = override[i];
    if (baseElement is Map<String, dynamic> &&
        overrideElement is Map<String, dynamic>) {
      mergeMapsOneSided(baseElement, overrideElement);
    } else if (baseElement is List && overrideElement is List) {
      result[i] =
          _mergeListsOneSided(baseElement, overrideElement, '$name[$i]');
    } else if (overrideElement is Map || overrideElement is List) {
      tomLog.error(
        "Attempt to merge a structured value into $name[$i] = $baseElement, "
        "which has another shape. Keeping the base element.",
      );
    } else {
      result[i] = overrideElement;
    }
  }

  if (override.length > base.length) {
    result.addAll(override.sublist(base.length));
  }
  return result;
}

// =============================================================================
// Map Merging
// =============================================================================

/// Recursively merges [override] map into [base] map (one-sided deep merge).
///
/// This function performs a deep merge where:
/// - Nested maps are merged recursively
/// - Arrays are merged element-by-element over the overlapping prefix, then
///   take [override]'s tail; base elements past [override]'s length are kept.
///   Each element pair follows the same rules as a key/value pair: maps merge
///   recursively, lists merge positionally, and any other override element
///   replaces the base element.
/// - Primitive values from [override] replace values in [base]
/// - Keys in [override] that don't exist in [base] are added
///
/// A structural mismatch — an [override] map or list landing on a base value
/// of another shape, at a key or at a list index — is refused with a logged
/// error, and the base value is kept.
///
/// **Important**: This modifies [base] in-place.
///
/// ## Parameters
/// - [base]: The target map that will be modified with merged values
/// - [override]: The source map whose values will be merged into [base]
///
/// ## Example
/// ```dart
/// final base = {
///   'server': {'host': 'localhost', 'port': 8080},
///   'features': ['auth', 'logging']
/// };
/// final override = {
///   'server': {'host': 'api.example.com'},
///   'features': ['oauth', 'logging', 'metrics']
/// };
/// mergeMapsOneSided(base, override);
/// // Result: base['server']['host'] == 'api.example.com'
/// // Result: base['server']['port'] == 8080 (preserved)
/// // Result: base['features'] == ['oauth', 'logging', 'metrics']
/// //   index 0 replaced, index 1 unchanged, index 2 appended
/// ```
void mergeMapsOneSided(
  Map<String, dynamic> base,
  Map<String, dynamic> override,
) {
  override.forEach((String oKey, dynamic oValue) {
    Object? baseObject = base[oKey];
    if (oValue is Map<String, dynamic>) {
      if (base.containsKey(oKey)) {
        if (baseObject is Map<String, dynamic>) {
          mergeMapsOneSided(baseObject, oValue);
        } else {
          tomLog.error(
            "Attempt to merge subtree named $oKey into non-subtree = $baseObject",
          );
        }
      } else {
        base[oKey] = oValue;
      }
    } else if (oValue is List) {
      if (baseObject is List) {
        base[oKey] = _mergeListsOneSided(baseObject, oValue, oKey);
      } else {
        if (baseObject == null) {
          base[oKey] = oValue;
        } else {
          tomLog.error(
            "Attempt to merge array named $oKey into non-array = $baseObject",
          );
        }
      }
    } else {
      base[oKey] = oValue;
    }
  });
}

// =============================================================================
// Tree Traversal and Processing
// =============================================================================

/// Traverses a nested map tree and processes all String values matching a condition.
///
/// Recursively walks through the [tree] structure, applying [processor] to any
/// String value where [test] returns `true`. This modifies the tree in-place.
///
/// ## Parameters
/// - [tree]: The nested map structure to traverse
/// - [test]: Predicate function that determines which strings to process
/// - [processor]: Transform function applied to matching strings
///
/// ## Example
/// ```dart
/// final config = {'url': '${BASE_URL}/api', 'name': 'MyApp'};
/// traverseAndProcess(
///   config,
///   (s) => s.contains(r'${'),
///   (s) => s.replaceAll(r'${BASE_URL}', 'https://api.example.com'),
/// );
/// // config['url'] is now 'https://api.example.com/api'
/// ```
void traverseAndProcess(
  Map<String, dynamic> tree,
  bool Function(String) test,
  String Function(String) processor,
) {
  tree.forEach((String oKey, dynamic oValue) {
    if (oValue is Map<String, dynamic>) {
      traverseAndProcess(oValue, test, processor);
    } else if (oValue is List) {
      // Dispatch per element so mixed lists from jsonDecode (List<dynamic>
      // holding both maps and strings) are handled. The previous typed checks
      // (List<Map<String,Object>> / List<String>) never matched decoded JSON
      // lists, silently skipping their contents (bug §45).
      for (int i = 0; i < oValue.length; i++) {
        final element = oValue[i];
        if (element is Map<String, dynamic>) {
          traverseAndProcess(element, test, processor);
        } else if (element is String && test(element)) {
          oValue[i] = processor(element);
        }
      }
    } else if (oValue is String) {
      if (test(oValue)) {
        tree[oKey] = processor(oValue);
      }
    }
  });
}

/// Traverses a nested map tree and creates new entries based on key names.
///
/// Similar to [traverseAndProcess], but focuses on key names rather than values.
/// When a key name matches [nameTest], the [creator] callback is invoked with
/// the key, value, and parent map location, allowing insertion of new nodes.
///
/// This is particularly useful for expanding shorthand notations or creating
/// links/references in configuration trees.
///
/// ## Parameters
/// - [tree]: The nested map structure to traverse
/// - [nameTest]: Predicate function that tests key names
/// - [creator]: Callback invoked for matching keys; can modify [location] map
///
/// ## Example
/// ```dart
/// final config = {'ref@profiles@dev': '...'};
/// traverseAndCreate(
///   config,
///   (name) => name.contains('@'),
///   (key, value, location) {
///     // Process the reference pattern and insert resolved values
///   },
/// );
/// ```
void traverseAndCreate(
  Map<String, dynamic> tree,
  bool Function(String) nameTest,
  void Function(String key, String value, Map<String, dynamic> location)
  creator,
) {
  tree.forEach((String oKey, dynamic oValue) {
    if (oValue is Map<String, dynamic>) {
      traverseAndCreate(oValue, nameTest, creator);
    } else if (oValue is List) {
      if (oValue is List<Map<String, dynamic>>) {
        List<Map<String, dynamic>> mapArray = oValue;
        for (int i = 0; i < mapArray.length; i++) {
          traverseAndCreate(mapArray[i], nameTest, creator);
        }
      }
    } else if (nameTest(oKey) && oValue is String) {
      creator(oKey, oValue, tree); // inserts new nodes
    }
  });
}

// =============================================================================
// Path-Based Tree Access
// =============================================================================

/// Retrieves a subtree from a nested map using a dot-separated path.
///
/// Navigates through [baseTree] following the [path] (e.g., "database.connection.pool")
/// and returns the map at that location. If the path leads to a non-map value,
/// wraps it in a map with [name] as the key.
///
/// ## Parameters
/// - [baseTree]: The root map to navigate from
/// - [path]: Dot-separated path string (e.g., "level1.level2.level3")
/// - [name]: Key name to use when wrapping non-map terminal values
///
/// ## Throws
/// - [Exception] if the path cannot be resolved or contains invalid segments
///
/// ## Example
/// ```dart
/// final config = {'db': {'host': 'localhost', 'settings': {'pool': 10}}};
/// final settings = getPathFromTree(config, 'db.settings', 'result');
/// // Returns {'pool': 10}
/// ```
Map<String, dynamic> getPathFromTree(
  Map<String, dynamic> baseTree,
  String path,
  String name,
) {
  // Share the path walk (and its identical resolution/throw behaviour) with
  // [getObjectFromTree]; the only difference is what happens at a terminal
  // *non-map* value, which the two functions handle after the walk.
  final Object value = getObjectFromTree(baseTree, path);
  if (value is Map<String, dynamic>) {
    return value;
  }
  // A terminal non-map value only surfaces at the last path segment (an
  // interior non-map throws inside [getObjectFromTree]), so the reporting
  // context is always that final segment.
  final List<String> pathParts = path.split(".");
  tomLog.warn(
    "Path not found: $path at ${pathParts.last} position ${pathParts.length - 1}",
  );
  return <String, dynamic>{name: value};
}

/// Retrieves any object from a nested map using a dot-separated path.
///
/// Similar to [getPathFromTree], but returns the raw value at the path
/// rather than wrapping non-map values.
///
/// ## Parameters
/// - [baseTree]: The root map to navigate from
/// - [path]: Dot-separated path string (e.g., "database.port")
///
/// ## Returns
/// The object found at the specified path (may be a Map, List, String, int, etc.)
///
/// ## Throws
/// - [Exception] if the path cannot be resolved
///
/// ## Example
/// ```dart
/// final config = {'db': {'port': 5432}};
/// final port = getObjectFromTree(config, 'db.port');
/// // Returns 5432
/// ```
Object getObjectFromTree(Map<String, dynamic> baseTree, String path) {
  Map<String, dynamic> tree = baseTree;
  Object? value;
  List<String> pathParts = path.split(".");
  for (int i = 0; i < pathParts.length; i++) {
    String nextKey = pathParts[i];
    value = tree[nextKey];
    if (value is Map<String, dynamic>) {
      tree = value;
      if (i == pathParts.length - 1) {
        return tree;
      }
    } else {
      if (i < pathParts.length - 1) {
        throw Exception(
          "Path $path cannot be resolved. Ends at $nextKey at position $i",
        );
      }
      if (value == null) {
        throw Exception(
          "Path $path cannot be resolved. Elements $nextKey at position $i not found.",
        );
      }
      return value;
    }
  }
  throw Exception(
    "Path $path cannot be resolved. IllegalState detected. This is an anomaly.",
  );
}

// =============================================================================
// Tree Modification (Profile-Based Injection)
// =============================================================================

/// Internal class representing a pending tree modification.
///
/// Encapsulates a deferred modification to be applied to a tree structure.
/// Modifications are collected during traversal and applied afterward to
/// avoid modifying the tree while iterating.
class _TreeModification {
  /// Creates an empty (no-op) modification.
  _TreeModification();

  /// Creates a modification with the specified parameters.
  ///
  /// - [value]: The directive value ("...", "@", or other)
  /// - [tree]: The parent map where modification will be applied
  /// - [keyName]: The key to modify or insert
  /// - [insertTree]: The data to insert
  _TreeModification.of(this.value, this.tree, this.keyName, this.insertTree) {
    empty = false;
  }

  /// Singleton empty modification for no-op cases.
  static _TreeModification emptyModification = _TreeModification();

  /// Whether this modification is a no-op.
  bool empty = true;

  /// The directive value determining how to apply the modification.
  String? value;

  /// The parent map to modify.
  Map<String, dynamic>? tree;

  /// The key name for the modification.
  String? keyName;

  /// The data to insert into the tree.
  Map<String, dynamic>? insertTree;

  /// Applies this modification to the tree.
  ///
  /// Behavior depends on [value]:
  /// - `"..."`: Spreads [insertTree] entries into [tree] (non-overwriting)
  /// - `"@"`: Replaces the value at [keyName] with the corresponding value from [insertTree]
  /// - Other: Sets [keyName] to the entire [insertTree]
  void apply() {
    if (empty) return;
    if (tree == null) {
      throw Exception(
        "Modification already applied or tree was null for key $keyName value $value",
      );
    }
    if ("..." == value) {
      insertTree!.forEach((key, val) {
        if (!tree!.containsKey(key)) tree![key] = val;
      });
    } else if ("@" == value) {
      tree![keyName!] = insertTree![keyName!]!;
    } else {
      tree![keyName!] = insertTree!;
    }
    value = null;
    tree = null;
    insertTree = null;
    keyName = null;
  }
}

/// Pattern for matching profile-based key references: `keyName@path@profileName`
RegExp _namePattern = RegExp("([^@]+)@([^@]+)@([^@]+)");

/// Creates a tree modification from a profile-based key pattern.
///
/// Parses keys matching the pattern `keyName@path@profileName` and creates
/// a modification that will inject data from the specified profile.
_TreeModification _modifyTree(
  String name,
  String value,
  Map<String, dynamic> tree,
  Map<String, dynamic> Function(String keyName, String path, String profileName)
  provider,
) {
  RegExpMatch? m = _namePattern.firstMatch(name);
  if (m != null) {
    try {
      String keyName = m.group(1)!;
      String path = m.group(2)!;
      String profileName = m.group(3)!;
      Map<String, dynamic> insertTree = provider(keyName, path, profileName);
      return _TreeModification.of(value, tree, keyName, insertTree);
    } catch (exception, stacktrace) {
      throw Exception(
        "Failed to get tree modification for $name with value $value, exception $exception stacktrace $stacktrace",
      );
    }
  }
  return _TreeModification.emptyModification;
}

/// Processes a tree by resolving profile-based references.
///
/// Scans the [tree] for keys containing "@" patterns (e.g., `database@profiles@production`)
/// and resolves them using the [provider] function to inject configuration data.
///
/// ## Parameters
/// - [tree]: The configuration tree to process (modified in-place)
/// - [provider]: Function that resolves profile references to configuration data.
///   Takes (keyName, path, profileName) and returns the data to inject.
///
/// ## Key Pattern Format
/// Keys should match: `keyName@path@profileName`
/// - `keyName`: The resulting key name after resolution
/// - `path`: The path within the profile to extract
/// - `profileName`: The name of the profile to use
///
/// ## Value Directives
/// - `"..."`: Spread the resolved data into the current map
/// - `"@"`: Replace with the value at the same key from resolved data
/// - Other: Replace with the entire resolved data structure
void processTree(
  Map<String, dynamic> tree,
  Map<String, dynamic> Function(String keyName, String path, String profileName)
  provider,
) {
  var modifications = <_TreeModification>[];
  traverseAndCreate(tree, (String s) => s.contains("@"), (
    String name,
    String value,
    Map<String, dynamic> tree,
  ) {
    modifications.add(_modifyTree(name, value, tree, provider));
  });
  for (var m in modifications) {
    m.apply();
  }
}

// =============================================================================
// JSON Sanitization
// =============================================================================

/// Recursively cleans a map to ensure it contains only JSON-compatible types.
///
/// Creates a new map containing valid JSON values (String, int, double, bool,
/// `null`, Map, List). Entries with non-String keys, and values of any other
/// type, are filtered out.
///
/// `null` is a JSON value and is **kept**. An absent field and a field that is
/// present and null mean different things — to a PATCH-style partial update, to
/// a settings map where null means "explicitly cleared", to a DTO whose schema
/// declares the field nullable — and the sanitiser preserves that distinction
/// rather than collapsing it.
///
/// The one exception to the type filter is [TomJsonSerializable]: a value
/// implementing it is converted through its `toJson()` and the result cleaned
/// in turn, wherever it appears in the tree — at the top level, nested in a
/// sub-map, or inside a list. That is the interface's whole purpose, and
/// dropping such a value would discard state the object was explicitly written
/// to expose.
///
/// This is useful when working with maps that may contain non-serializable
/// types (e.g. `DateTime`, custom objects) and need to be converted to pure
/// JSON. Note that filtering is silent: a `DateTime` disappears without an
/// error, so give a type a `toJson()` via [TomJsonSerializable] when its value
/// must survive.
///
/// ## Parameters
/// - [map]: The source map to clean (not modified)
///
/// ## Returns
/// A new `Map<String, Object?>` containing only JSON-compatible entries.
///
/// ## Example
/// ```dart
/// final dirty = {'name': 'App', 'created': DateTime.now(), 'port': 8080};
/// final clean = makeCleanJsonMap(dirty);
/// // clean = {'name': 'App', 'port': 8080}  (DateTime filtered out)
///
/// // A deliberate null survives; only what cannot be encoded is dropped.
/// final patch = {'discount': null, 'when': DateTime.now()};
/// makeCleanJsonMap(patch);
/// // {'discount': null}
///
/// // A TomJsonSerializable is converted rather than dropped.
/// final withValue = {'name': 'App', 'price': Money(12, 'EUR')};
/// final cleaned = makeCleanJsonMap(withValue);
/// // cleaned = {'name': 'App', 'price': {'amount': 12, 'currency': 'EUR'}}
/// ```
Map<String, Object?> makeCleanJsonMap(Map map) {
  var result = <String, Object?>{};
  for (var entry in map.entries) {
    if (entry.key is String) {
      final cleaned = _cleanJsonValue(entry.value);
      if (!identical(cleaned, _notJsonEncodable)) {
        result[entry.key] = cleaned;
      }
    }
  }
  return result;
}

/// Recursively cleans a list to ensure it contains only JSON-compatible types.
///
/// Internal helper for [makeCleanJsonMap]. `null` elements are kept — a JSON
/// array may hold them, and dropping them would silently shift every later
/// element's index.
List<Object?> _cleanList(List list) {
  var result = <Object?>[];
  for (var listEntry in list) {
    final cleaned = _cleanJsonValue(listEntry);
    if (!identical(cleaned, _notJsonEncodable)) {
      result.add(cleaned);
    }
  }
  return result;
}

/// Marker returned by [_cleanJsonValue] for a value that has no JSON form.
///
/// The helper cannot signal "drop this" with `null`, because `null` is itself a
/// value it must be able to return: conflating the two made a deliberate null
/// indistinguishable from a `DateTime`, and both were filtered out. A private
/// sentinel separates the two answers, so the callers test identity against
/// this object rather than nullness.
const Object _notJsonEncodable = _NotJsonEncodable();

/// The type of [_notJsonEncodable]. Private, and never instantiated elsewhere,
/// so no caller-supplied value can be mistaken for the sentinel.
class _NotJsonEncodable {
  const _NotJsonEncodable();
}

/// Returns a JSON-clean copy of [value], or [_notJsonEncodable] when it is not
/// a JSON-compatible type (in which case the caller filters it out).
///
/// A `null` [value] returns `null` — it is a JSON value, not a failure — which
/// is why the "no JSON form" answer needs its own sentinel.
///
/// Shared by [makeCleanJsonMap] and [_cleanList] so the type dispatch —
/// scalars and `null` pass through, [TomJsonSerializable] converts, maps and
/// lists recurse, everything else is dropped — is defined in exactly one place.
///
/// This is the only function in the module that knows [TomJsonSerializable]
/// exists, and deliberately so. The tree functions ([traverseAndProcess],
/// [traverseAndCreate], [substituteEnvVars]) rewrite strings *in place* inside
/// mutable maps and lists; a value object is immutable and opaque, so there is
/// nothing for them to step into. They also operate on decoded JSON, which
/// never contains a Dart object in the first place. Sanitisation is the one
/// point where a live object tree meets JSON, so it is the one place the
/// interface belongs.
Object? _cleanJsonValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String || value is int || value is double || value is bool) {
    return value;
  }
  // Ahead of the Map check so a type that implements both is still given the
  // chance to describe itself, rather than being read as a raw map.
  if (value is TomJsonSerializable) {
    // Recurse through [makeCleanJsonMap] rather than returning `toJson()` as
    // it stands: a `toJson` that nests a non-JSON value of its own would
    // otherwise smuggle it past the sanitiser and fail at `jsonEncode`.
    return makeCleanJsonMap(value.toJson());
  }
  if (value is Map) {
    return makeCleanJsonMap(value);
  }
  if (value is List) {
    return _cleanList(value);
  }
  return _notJsonEncodable;
}

// =============================================================================
// Environment Variable Substitution
// =============================================================================

/// Regular expression matching environment variable placeholders.
///
/// Matches patterns like `${VAR_NAME}` or `${VAR_NAME:default_value}`.
/// - Group 1: The variable name
/// - Group 2: The default value (if provided after `:`)
final RegExp _envVarPattern = RegExp(r'\$\{([^:}]+)(?::([^}]*))?\}');

/// Substitutes environment variable placeholders in all string values of a map tree.
///
/// Processes the entire [tree] in-place, replacing placeholders like `${VAR_NAME}`
/// with values from the provided [environment] map. Supports default values
/// using the syntax `${VAR_NAME:default}`.
///
/// ## Parameters
/// - [tree]: The nested map structure to process (modified in-place)
/// - [environment]: Map of environment variable names to values
///
/// ## Placeholder Syntax
/// - `${VAR_NAME}` - Replaced with environment value, or left unchanged if not found
/// - `${VAR_NAME:default}` - Replaced with environment value, or `default` if not found
///
/// ## Example
/// ```dart
/// final config = {'host': '${DB_HOST:localhost}', 'port': '${DB_PORT}'};
/// final env = {'DB_HOST': 'production.db.com', 'DB_PORT': '5432'};
/// substituteEnvVars(config, env);
/// // config is now {'host': 'production.db.com', 'port': '5432'}
/// ```
void substituteEnvVars(
  Map<String, dynamic> tree,
  Map<String, String> environment,
) {
  traverseAndProcess(
    tree,
    (s) => _envVarPattern.hasMatch(s),
    (s) => _substituteEnvVarsInString(s, environment),
  );
}

/// Substitutes environment variable placeholders in a single string.
///
/// Internal helper for [substituteEnvVars].
String _substituteEnvVarsInString(String input, Map<String, String> environment) {
  return input.replaceAllMapped(_envVarPattern, (match) {
    final varName = match.group(1)!;
    final defaultValue = match.group(2);
    final envValue = environment[varName];
    
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }
    if (defaultValue != null) {
      return defaultValue;
    }
    // Leave unchanged if no value and no default
    return match.group(0)!;
  });
}

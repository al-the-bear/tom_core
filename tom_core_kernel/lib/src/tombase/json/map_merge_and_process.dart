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
/// ## What counts as a subtree
/// Every function here that walks a tree treats **any map whose keys are all
/// `String`** as a subtree, whatever its reified type: `Map<dynamic, dynamic>`,
/// `Map<String, String>` and `Map<String, dynamic>` are descended into alike.
/// The reified type is not under the caller's control as often as it looks —
/// `jsonDecode` always yields `Map<String, dynamic>`, but `TomYaml`, a
/// hand-written literal and anything round-tripped through an untyped container
/// do not, and such maps used to be walked past silently (bug §84).
///
/// A map with a non-`String` key is *not* a subtree: it cannot be a JSON object
/// and every callback here takes a `String key`, so it is skipped whole rather
/// than walked halfway. The in-place traversals still edit in place — the
/// string-keyed view they walk writes through to the caller's map.
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

/// A `Map<String, dynamic>` view of [value], or `null` if it is not a map this
/// module can walk.
///
/// The tree functions used to test children with `is Map<String, dynamic>`
/// directly. That is a *reified* test: a `Map<dynamic, dynamic>` fails it and
/// was walked past without an error or a log line, so its contents were
/// silently left untransformed (bug §84 — the same defect as §45, which fixed
/// the list guards and the top-level signature but left the nested-map ones).
/// `jsonDecode` never produces such a map, so the common path was safe, but
/// `TomYaml.loadYamlFile`, hand-built maps and anything round-tripped through
/// an untyped container all do.
///
/// The returned view **writes through** to [value], which is what lets the
/// in-place traversals keep their contract: a caller holding the original map
/// sees the edits. Callers that need to store the result in a tree should
/// prefer a real copy, because a `cast` view revalidates on every write.
///
/// A map with a non-String key returns `null` and is skipped. It cannot be a
/// JSON object, and every callback here takes a `String key`, so there is
/// nothing meaningful to hand them; walking it halfway would be worse than not
/// walking it. The scan that establishes this is O(keys), paid only for a map
/// that is not already `Map<String, dynamic>`.
Map<String, dynamic>? _asStringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is! Map) {
    return null;
  }
  for (final Object? key in value.keys) {
    if (key is! String) {
      return null;
    }
  }
  return value.cast<String, dynamic>();
}

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
    final Map<String, dynamic>? baseElementMap = _asStringKeyedMap(baseElement);
    if (baseElementMap != null && overrideElement is Map<String, dynamic>) {
      // Merge into a widened copy and write it back rather than mutating the
      // base element in place, exactly as the map branch of _mergeMapsOneSided
      // does: a narrowly reified element (`Map<String, String>`) passes the
      // test by covariance and then throws on the first entry of another type
      // the merge adds. Nothing observes the element identity — the result
      // list replaces the base list wholesale anyway.
      final Map<String, dynamic> merged = Map<String, dynamic>.of(
        baseElementMap,
      );
      _mergeMapsOneSided(merged, overrideElement);
      result[i] = merged;
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

/// Returns a deep copy of [source] that shares no map or list with it.
///
/// Every nested map and list is rebuilt, so writing anywhere in the copy —
/// including deep inside it — cannot reach [source]. This is what
/// `Map<String, dynamic>.from` does *not* give you: that copies only the top
/// level, leaving every nested subtree shared, so an in-place merge into the
/// "copy" writes straight through into the original.
///
/// Use it to keep a document intact across a [mergeMapsOneSided], which
/// mutates its first argument:
///
/// ```dart
/// final merged = deepCopyJsonTree(baseConfig);
/// mergeMapsOneSided(merged, overrides);
/// // baseConfig is untouched
/// ```
///
/// Maps are normalised to `Map<String, dynamic>` and lists to `List<dynamic>`,
/// because a copy exists to be written into and a narrowly reified container
/// would throw on the first value of another type. Non-String keys are
/// converted with `toString()`; a JSON object's keys are strings by
/// definition.
///
/// Scalar leaves are shared rather than copied. That is correct for the JSON
/// scalars — `String`, `num`, `bool`, `null` are immutable — and is the only
/// option for any other object a tree happens to carry, which cannot be
/// cloned generically.
Map<String, dynamic> deepCopyJsonTree(Map<String, dynamic> source) {
  final Map<String, dynamic> copy = <String, dynamic>{};
  source.forEach((String key, dynamic value) {
    copy[key] = _deepCopyJsonValue(value);
  });
  return copy;
}

/// Deep-copies one value of a JSON tree. See [deepCopyJsonTree].
dynamic _deepCopyJsonValue(dynamic value) {
  if (value is Map) {
    final Map<String, dynamic> copy = <String, dynamic>{};
    value.forEach((dynamic k, dynamic v) => copy['$k'] = _deepCopyJsonValue(v));
    return copy;
  }
  if (value is List) {
    return value.map<dynamic>(_deepCopyJsonValue).toList();
  }
  return value;
}

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
/// **Important**: This modifies [base] in-place. To keep the original intact,
/// copy it with [deepCopyJsonTree] first — `Map<String, dynamic>.from` is
/// shallow and leaves every nested subtree shared, so the merge would write
/// through into the map you meant to protect.
///
/// [override] is deep-copied before the merge, so it is never modified and the
/// merged tree shares no map or list with it. The two documents therefore stay
/// independent: a later edit to either cannot reach the other. This matters in
/// the layered-config flow the function exists for — without it,
/// `mergeMapsOneSided(base, env); mergeMapsOneSided(base, local);` would leave
/// `base` holding live references into both documents, and the second merge
/// would write back into the first. Scalar leaves are shared rather than
/// copied, which is safe because JSON scalars are immutable.
///
/// A base subtree counts whatever its reified type, as long as its keys are all
/// `String`; see the library doc's *What counts as a subtree*.
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
  // Copy once, here, rather than at each point where a value is stored into
  // [base]. After this line nothing else holds a reference into the tree being
  // merged, so every reference the merge stores is owned by [base] — the
  // invariant holds by construction, and cannot be broken by a later edit that
  // adds another assignment site.
  _mergeMapsOneSided(base, deepCopyJsonTree(override));
}

/// The recursive body of [mergeMapsOneSided].
///
/// Separate so the deep copy happens exactly once, at the outermost call:
/// recursing through [mergeMapsOneSided] would re-copy every subtree at every
/// level.
void _mergeMapsOneSided(
  Map<String, dynamic> base,
  Map<String, dynamic> override,
) {
  override.forEach((String oKey, dynamic oValue) {
    Object? baseObject = base[oKey];
    if (oValue is Map<String, dynamic>) {
      if (base.containsKey(oKey)) {
        final Map<String, dynamic>? baseMap = _asStringKeyedMap(baseObject);
        if (baseMap != null) {
          // Merge into a widened copy and write it back, exactly as the list
          // branch below does. A narrowly reified map reaches here too — Dart
          // generics are covariant, so the literal `{'host': 'h'}` is a
          // `Map<String, String>` that would throw on the first entry of
          // another type the merge adds to it.
          final Map<String, dynamic> merged = Map<String, dynamic>.of(baseMap);
          _mergeMapsOneSided(merged, oValue);
          base[oKey] = merged;
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
/// Every string in the tree is reached, whatever holds it: nested maps recurse,
/// and lists are walked per element, so a map inside a list, a list inside a
/// list, and any deeper combination are all descended into. Dispatch is on each
/// value's runtime shape rather than on a container's declared type, which is
/// what makes a document straight out of `jsonDecode` — `Map<String, dynamic>`
/// and `List<dynamic>` throughout — behave the same as one built in Dart code.
/// A map child counts whatever its reified type, as long as its keys are all
/// `String`; see the library doc's *What counts as a subtree*.
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
    final Map<String, dynamic>? childMap = _asStringKeyedMap(oValue);
    if (childMap != null) {
      traverseAndProcess(childMap, test, processor);
    } else if (oValue is List) {
      _processList(oValue, test, processor);
    } else if (oValue is String) {
      if (test(oValue)) {
        tree[oKey] = processor(oValue);
      }
    }
  });
}

/// Applies [traverseAndProcess]'s rules to the elements of [list], in place.
///
/// Dispatch is per element rather than on the list's own type, so mixed lists
/// from `jsonDecode` — `List<dynamic>` holding maps, strings and further lists
/// side by side — are handled. The typed checks this replaced
/// (`List<Map<String, Object>>` / `List<String>`) never matched a decoded JSON
/// list at all, silently skipping its contents (bug §45).
///
/// A list element recurses through this same function, so a list nested inside
/// a list is reached at any depth. Handling only the outermost array left every
/// ordinary nested shape — a matrix, a list of coordinate pairs, a list of tag
/// groups — untransformed and unreported (bug §81).
void _processList(
  List<dynamic> list,
  bool Function(String) test,
  String Function(String) processor,
) {
  for (int i = 0; i < list.length; i++) {
    final element = list[i];
    final Map<String, dynamic>? elementMap = _asStringKeyedMap(element);
    if (elementMap != null) {
      traverseAndProcess(elementMap, test, processor);
    } else if (element is List) {
      _processList(element, test, processor);
    } else if (element is String && test(element)) {
      list[i] = processor(element);
    }
  }
}

/// Traverses a nested map tree and creates new entries based on key names.
///
/// Similar to [traverseAndProcess], but selects on key names rather than value
/// contents. When a key name matches [nameTest] *and its value is a `String`*,
/// the [creator] callback is invoked with the key, that string, and the parent
/// map location, allowing insertion of new nodes.
///
/// ## Which keys reach the creator
/// The value's shape is part of the match, not just the name. A matching key
/// whose value is a map is recursed into instead of being reported, and one
/// whose value is a list is taken by the list branch and likewise never
/// reported — the branches are mutually exclusive. A matching key whose value
/// is an `int`, `bool` or `null` is skipped outright. This is not incidental:
/// [creator] takes a `String value`, so no other shape could be handed to it.
///
/// This is particularly useful for expanding shorthand notations or creating
/// links/references in configuration trees.
///
/// ## Parameters
/// - [tree]: The nested map structure to traverse
/// - [nameTest]: Predicate function that tests key names
/// - [creator]: Callback invoked for each matching key, receiving the key, its
///   string value, and the map that contains it. It may insert into, remove
///   from, or overwrite that map directly — the walk iterates a snapshot of
///   each map's keys, so mutating during the callback is safe at every depth,
///   including a map an outer recursion level is still walking.
///
/// ## What a creator's edits are visited by
/// Keys the creator adds are **not** traversed: the snapshot for a map is taken
/// before its entries are visited. That is deliberate — a creator that inserts
/// a key its own [nameTest] matches would otherwise call itself forever. Run
/// the traversal again if newly created nodes must themselves be expanded.
///
/// An entry the creator removes is simply skipped when the walk reaches it.
///
/// A map child counts whatever its reified type, as long as its keys are all
/// `String`; see the library doc's *What counts as a subtree*.
///
/// ## Example
/// ```dart
/// final config = {'ref@profiles@dev': 'value'};
/// traverseAndCreate(
///   config,
///   (name) => name.contains('@'),
///   (key, value, location) {
///     location['resolved'] = value.toUpperCase(); // inserting is supported
///   },
/// );
/// // config = {'ref@profiles@dev': 'value', 'resolved': 'VALUE'}
/// ```
void traverseAndCreate(
  Map<String, dynamic> tree,
  bool Function(String) nameTest,
  void Function(String key, String value, Map<String, dynamic> location)
  creator,
) {
  // Iterate a snapshot of the keys rather than the map itself, so the creator
  // can insert into [tree] — which is the whole point of handing it the
  // location. `forEach` would throw `ConcurrentModificationError` on the first
  // insert, making the callback's one useful parameter unusable.
  //
  // Every recursion level snapshots, not just the outermost, because a creator
  // reached deep in the tree may hold a reference to an ancestor map that an
  // outer level is still walking.
  for (final String oKey in tree.keys.toList(growable: false)) {
    // Read through the map rather than from the snapshot: an earlier creator
    // may have removed this entry, which reads back as null and matches no
    // branch below. That makes removal as safe as insertion, at no cost.
    final Object? oValue = tree[oKey];
    final Map<String, dynamic>? childMap = _asStringKeyedMap(oValue);
    if (childMap != null) {
      traverseAndCreate(childMap, nameTest, creator);
    } else if (oValue is List) {
      if (oValue is List<Map<String, dynamic>>) {
        List<Map<String, dynamic>> mapArray = oValue;
        for (int i = 0; i < mapArray.length; i++) {
          traverseAndCreate(mapArray[i], nameTest, creator);
        }
      }
    } else if (nameTest(oKey) && oValue is String) {
      creator(oKey, oValue, tree);
    }
  }
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
/// A terminal `null` is a non-map value and is wrapped like any other, giving
/// `{name: null}`. That keeps it distinguishable from an absent path, which
/// throws — see [getObjectFromTree] for why the two are not collapsed.
///
/// A map at the path is a subtree, and so returned rather than wrapped,
/// whatever its reified type, as long as its keys are all `String`; see the
/// library doc's *What counts as a subtree*.
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
  final Object? value = getObjectFromTree(baseTree, path);
  final Map<String, dynamic>? subtree = _asStringKeyedMap(value);
  if (subtree != null) {
    return subtree;
  }
  // A terminal non-map value only surfaces at the last path segment (an
  // interior non-map throws inside [getObjectFromTree]), so the reporting
  // context is always that final segment. `null` is one such value and is
  // wrapped like any other: the caller can then tell it apart from an absent
  // path, which threw above.
  final List<String> pathParts = path.split(".");
  tomLog.warn(
    "Path $path resolves to a non-map value at ${pathParts.last} position "
    "${pathParts.length - 1}; wrapping it as {$name: ...}.",
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
/// The value found at the specified path — a Map, List, String, int, or
/// `null`. A `null` return means the terminal key is **present and holds
/// null**, which is a value; a path that cannot be resolved throws instead.
/// Absence is decided by `containsKey`, matching [makeCleanJsonMap], which
/// keeps a present `null` for the same reason: an absent field and a field
/// that is present and null mean different things.
///
/// ## Throws
/// - [Exception] if a segment names a key that is not there.
/// - [Exception] if an interior segment resolves to something with no subtree
///   to descend into — including `null`, which is a fine terminal value but
///   cannot be walked through. The message distinguishes the two cases. An
///   interior map is walked through whatever its reified type, as long as its
///   keys are all `String`; see the library doc's *What counts as a subtree*.
///
/// ## Example
/// ```dart
/// final config = {'db': {'port': 5432, 'replica': null}};
/// getObjectFromTree(config, 'db.port');     // 5432
/// getObjectFromTree(config, 'db.replica');  // null — present, deliberately
/// getObjectFromTree(config, 'db.absent');   // throws
/// ```
Object? getObjectFromTree(Map<String, dynamic> baseTree, String path) {
  final List<String> pathParts = path.split(".");
  Map<String, dynamic> tree = baseTree;

  // Interior segments must each resolve to a map, because there is a further
  // segment to descend into. The terminal segment is read after the loop and
  // is returned whatever it holds — which is where a present `null` differs
  // from an absent key, and why the two are split apart here.
  for (int i = 0; i < pathParts.length - 1; i++) {
    final Object? value = _readSegment(tree, pathParts[i], path, i);
    final Map<String, dynamic>? subtree = _asStringKeyedMap(value);
    if (subtree == null) {
      throw Exception(
        "Path $path cannot be resolved. Key ${pathParts[i]} at position $i "
        "holds ${value == null ? "null" : "a non-map value"}, which has no "
        "subtree to descend into.",
      );
    }
    tree = subtree;
  }

  // `split` never yields an empty list, so there is always a terminal segment
  // and no unreachable tail to guard.
  final int last = pathParts.length - 1;
  return _readSegment(tree, pathParts[last], path, last);
}

/// Reads [key] from [tree], throwing when the key is genuinely absent.
///
/// Absence is decided by `containsKey`, not by the value being `null`: a key
/// present with a `null` value is a value, and is returned as one. Collapsing
/// the two would contradict [makeCleanJsonMap], which deliberately keeps a
/// present `null` so that an absent field stays distinguishable from a field
/// that is present and null.
///
/// [path] and [position] are carried only to report where in the original
/// dotted path the failure happened.
Object? _readSegment(
  Map<String, dynamic> tree,
  String key,
  String path,
  int position,
) {
  if (!tree.containsKey(key)) {
    throw Exception(
      "Path $path cannot be resolved. There is no key $key at position "
      "$position.",
    );
  }
  return tree[key];
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
  ///
  /// The `"@"` directive assumes [insertTree] contains [keyName]; that is
  /// checked in [_modifyTree], before any modification is applied.
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
      // Not null-asserted: a key present with a null value is a value here, as
      // everywhere else in this file, and assigning it is the honest result.
      tree![keyName!] = insertTree![keyName!];
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
///
/// Anchored, so the key must be *entirely* three non-empty parts. Unanchored,
/// `firstMatch` accepted any key that merely contained the shape: `a@b@c@d`
/// matched its first three parts and the `@d` was discarded, and `@a@b@c`
/// matched from the second character with the leading `@` discarded — both
/// resolved against a truncated path and injected under a truncated key,
/// silently.
final RegExp _namePattern = RegExp(r"^([^@]+)@([^@]+)@([^@]+)$");

/// The number of `@` in a key above which it can only be a broken directive.
///
/// A directive uses exactly two, so three or more means a separator too many.
/// Two is deliberately *not* enough to accuse a key: the timezoned module
/// serializes zoned values as `@D@<iso>_<offset>_<zone>` and npm-style
/// identifiers read `@scope/name@version`, both of which are ordinary strings
/// carrying two `@`. One is likewise ordinary — an email address.
const int _malformedDirectiveAtCount = 3;

/// Names a provider result's keys for an error message.
///
/// An empty map is spelled out rather than rendered as an empty list, so the
/// message reads as a sentence in both cases.
String _describeProviderKeys(Map<String, dynamic> insertTree) =>
    insertTree.isEmpty ? "no keys" : "the keys ${insertTree.keys.join(", ")}";

/// Creates a tree modification from a profile-based key pattern.
///
/// Parses keys matching the pattern `keyName@path@profileName` and creates
/// a modification that will inject data from the specified profile.
///
/// A key that does not match is an ordinary key and yields no modification —
/// an email address is not a directive.
///
/// Throws [Exception] if the key carries enough `@` to be a directive but is
/// not a well-formed one, if the provider itself fails, or if the `"@"`
/// directive is used and the provider's result has no entry named `keyName` —
/// the value that directive exists to take.
_TreeModification _modifyTree(
  String name,
  String value,
  Map<String, dynamic> tree,
  Map<String, dynamic> Function(String keyName, String path, String profileName)
  provider,
) {
  final RegExpMatch? m = _namePattern.firstMatch(name);
  if (m == null) {
    // Why report rather than ignore: a key this far past the directive shape
    // cannot be anything else, and ignoring it would trade the old silent
    // truncation for an equally silent no-op — the caller's injection would
    // simply not happen. Below the threshold the key is ordinary and is left
    // alone, so no working tree starts failing.
    if ("@".allMatches(name).length >= _malformedDirectiveAtCount) {
      throw Exception(
        "Malformed profile directive key $name: a directive is exactly three "
        "non-empty parts, keyName@path@profileName. Rename the key if it was "
        "not meant as a directive.",
      );
    }
    return _TreeModification.emptyModification;
  }

  // All three groups are required parts of the pattern, so a match guarantees
  // them; reading them cannot fail and so does not belong inside the try.
  final String keyName = m.group(1)!;
  final String path = m.group(2)!;
  final String profileName = m.group(3)!;

  final Map<String, dynamic> insertTree;
  try {
    insertTree = provider(keyName, path, profileName);
  } catch (exception, stacktrace) {
    throw Exception(
      "Failed to get tree modification for $name with value $value, exception $exception stacktrace $stacktrace",
    );
  }

  // Why here and not in apply(): processTree collects every modification before
  // applying any, so a failure raised now leaves the tree exactly as the caller
  // passed it, while the same failure raised at apply time would leave earlier
  // directives already written. The provider has already returned, so
  // insertTree cannot change between the two points — the check is equally
  // valid here and strictly safer. It also sits outside the catch above, so the
  // context it carries is not swallowed and re-wrapped.
  if ("@" == value && !insertTree.containsKey(keyName)) {
    throw Exception(
      'Cannot resolve the "@" directive of key $name: the provider for path '
      "$path and profile $profileName returned "
      "${_describeProviderKeys(insertTree)}, so there is no $keyName to take a "
      "value from",
    );
  }

  return _TreeModification.of(value, tree, keyName, insertTree);
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
/// Keys must match `keyName@path@profileName` *in full*:
/// - `keyName`: The resulting key name after resolution
/// - `path`: The path within the profile to extract
/// - `profileName`: The name of the profile to use
///
/// All three parts are non-empty and the match covers the whole key, so a key
/// with a fourth part is not resolved against its first three. A key that does
/// not match is an ordinary key and is left untouched — `user@example.com` and
/// `@scope/package@1.0.0` are keys, not directives. Only a key carrying three
/// or more `@`, which no ordinary string in this framework does, is reported as
/// a malformed directive rather than ignored.
///
/// ## Value Directives
/// - `"..."`: Spread the resolved data into the current map
/// - `"@"`: Replace with the value at the same key from resolved data
/// - Other: Replace with the entire resolved data structure
///
/// The `"@"` directive takes the value the provider returned *under the same
/// key*, so `wanted@path@profile: "@"` needs a provider result containing
/// `wanted`. A result containing the key with a `null` value is a value like
/// any other and is assigned; only an absent key is a failure.
///
/// ## Failures
/// Throws [Exception] if:
/// - a key carries three or more `@` but is not a well-formed directive — the
///   message names the key and restates the expected form;
/// - the [provider] itself throws — the original error and its stack trace are
///   carried in the message;
/// - a `"@"` directive's provider result has no entry under the directive's key
///   — the message names the key, the resolved path, the profile and the keys
///   the provider did return.
///
/// Every directive is resolved before any is applied, so a failure leaves
/// [tree] exactly as it was passed: the operation does not half-complete.
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
/// - `${VAR_NAME}` — replaced with the environment value, or left unchanged if
///   there is none
/// - `${VAR_NAME:default}` — replaced with the environment value, or `default`
///   if there is none
///
/// ## An empty value counts as unset
/// A variable present in [environment] with an empty value is treated exactly
/// as an absent one: `{'VAR': ''}` and `{}` produce the same result. This
/// follows the shell's `${VAR:-default}` convention, which the `:` in
/// `${VAR:default}` mirrors — the colon form is precisely the one that folds
/// empty into unset.
///
/// The consequence is worth stating plainly, because it looks asymmetric until
/// the convention is named:
///
/// ```dart
/// substituteEnvVars({'a': r'${V:fallback}'}, {'V': ''});  // 'fallback'
/// substituteEnvVars({'a': r'${V}'},          {'V': ''});  // '${V}' survives
/// substituteEnvVars({'a': r'${V:}'},         {});         // '' — empty default
/// ```
///
/// An empty *default* is a default that happens to be empty, and resolves; an
/// empty *value* does not. So a caller passing `Platform.environment` cannot
/// express "this variable is deliberately empty" — a `VAR=` in the environment
/// leaves a literal `${VAR}` in the tree unless a default is supplied. Give the
/// placeholder an explicit empty default, `${VAR:}`, when empty is the intended
/// resolution.
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
String _substituteEnvVarsInString(
  String input,
  Map<String, String> environment,
) {
  return input.replaceAllMapped(_envVarPattern, (match) {
    final varName = match.group(1)!;
    final defaultValue = match.group(2);
    final envValue = environment[varName];

    // `isNotEmpty`, not just a null check: an empty value counts as unset,
    // following the shell's `${VAR:-default}` convention that the `:` in
    // `${VAR:default}` mirrors. `defaultValue` is tested for null rather than
    // emptiness, so `${VAR:}` still resolves to the empty string — an empty
    // default is a default, an empty value is not a value.
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

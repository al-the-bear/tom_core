/// Item permission levels: an application's own, ordered vocabulary of what a
/// principal may do with one item — "view < comment < edit < manage" on a
/// document — beside the four grades every other check speaks.
///
/// The four grades (`none < disabled < read < full`) say how a resource is
/// *shown*; they cannot say that a user may comment on a document but not edit
/// it. An application declares its item types — usually from its manifest —
/// each with ordered levels and, for every level, the grade it stands for:
///
/// ```dart
/// TomItemTypeRegistry.register(TomItemType.standard('document'));
/// // view, comment → read; edit, manage → full
/// ```
///
/// **Items are parameters, not declarations.** Only the *types* are
/// registered; an item is named at run time by its id — a UUID, a path, a
/// category — and its resource key is `<type>:<id>`
/// ([TomItemType.keyFor]). A level held on a key ending in `*` covers every
/// item whose id starts with what comes before it ([TomItemType.patternFor]):
/// `document:*` is every document, `document:finance/*` every document whose
/// id the application files under `finance/`. So a level on a category, a
/// folder or a whole type is held without knowing its items in advance.
///
/// The levels a principal holds ride in the same `resourceKey → role` map as
/// every other resource role ([TomAccessControlInformation.resourceRoles]): the
/// role of an item key is a level name of its type. Two answers come out of it:
///
/// - [TomItemPermissions.allows] — "may this user *comment* on this document?",
///   in the application's own vocabulary;
/// - [TomItemPermissions.gradeOn], and through it
///   [TomResourceRoleAdapter.resolveAuth] — the level's grade, for code that only
///   knows grades: widgets dim or hide by it, and the grant-driven row scope
///   reads at `read` and writes at `full`.
///
/// The strongest level wins: an exact key and every matching pattern are
/// compared by the type's order, so a `comment` on the item and an `edit` on its
/// category resolve to `edit`. A level name the type does not declare grants
/// nothing.
library;

import 'tom_authorization.dart';

// =============================================================================
// TomItemType — a named type with ordered levels
// =============================================================================

/// One item type: its [name], its [levels] from weakest to strongest, and the
/// grade each level stands for.
class TomItemType {
  /// Creates a type named [name] with [levels] (weakest first) and the
  /// [grades] every level maps onto.
  ///
  /// Throws [ArgumentError] for a [name] that is not a lower-case identifier
  /// (`[a-z][a-z0-9_.-]*`), for no levels, a repeated level, a level
  /// [grades] does not map, or a level whose grade is below the grade of a
  /// weaker one — a stronger level never grants less.
  TomItemType(this.name, List<String> levels, Map<String, TomAuthState> grades)
    : levels = List.unmodifiable(levels),
      _grades = Map.unmodifiable(grades) {
    // throws-outside-family: programmer error — a malformed declaration is a
    // bug in the application's manifest or code, not a request to refuse.
    if (!namePattern.hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'is not an item type name');
    }
    if (levels.isEmpty) {
      throw ArgumentError.value(levels, 'levels', 'must not be empty');
    }
    if (levels.toSet().length != levels.length) {
      throw ArgumentError.value(levels, 'levels', 'must not repeat a level');
    }
    TomAuthState? previous;
    for (final level in levels) {
      final grade = grades[level];
      if (grade == null) {
        throw ArgumentError.value(level, 'grades', 'maps no grade for level');
      }
      if (previous != null && grade.index < previous.index) {
        throw ArgumentError.value(
          level,
          'grades',
          'grants less than a weaker level',
        );
      }
      previous = grade;
    }
  }

  /// The four standard levels — `view`, `comment` (both `read`), `edit` and
  /// `manage` (both `full`) — for a type named [name].
  factory TomItemType.standard(String name) =>
      TomItemType(name, standardLevels, {
        'view': TomAuthState.read,
        'comment': TomAuthState.read,
        'edit': TomAuthState.full,
        'manage': TomAuthState.full,
      });

  /// A type as an application manifest declares it:
  /// `{"name": "document", "levels": [{"name": "view", "grade": "read"}, …]}`,
  /// the levels weakest first; a grade is a [TomAuthState] name.
  factory TomItemType.fromJson(Map<String, Object?> json) {
    final rawLevels = json['levels'];
    if (rawLevels is! List) {
      throw ArgumentError.value(json, 'json', 'declares no list of levels');
    }
    final levels = <String>[];
    final grades = <String, TomAuthState>{};
    for (final raw in rawLevels) {
      if (raw is! Map) {
        throw ArgumentError.value(raw, 'levels', 'is not a level declaration');
      }
      final level = '${raw['name']}';
      levels.add(level);
      grades[level] = TomAuthState.values.firstWhere(
        (state) => state.name == raw['grade'],
        orElse: () => throw ArgumentError.value(
          raw['grade'],
          'grade',
          'is not one of ${TomAuthState.values.map((s) => s.name).join(', ')}',
        ),
      );
    }
    return TomItemType('${json['name']}', levels, grades);
  }

  /// The standard levels, weakest first.
  static const List<String> standardLevels = [
    'view',
    'comment',
    'edit',
    'manage',
  ];

  /// What an item type name may be.
  static final RegExp namePattern = RegExp(r'^[a-z][a-z0-9_.-]*$');

  /// The type's name, the first part of its items' resource keys.
  final String name;

  /// The levels, weakest first.
  final List<String> levels;

  final Map<String, TomAuthState> _grades;

  /// The resource key of the item [itemId] of this type: `<name>:<itemId>`.
  String keyFor(String itemId) => '$name:$itemId';

  /// The pattern covering every item whose id starts with [idPrefix] —
  /// `<name>:<idPrefix>*`; with no prefix, every item of the type.
  String patternFor([String idPrefix = '']) => '$name:$idPrefix*';

  /// The position of [level], weakest 0, or `-1` when the type does not
  /// declare it.
  int rankOf(String level) => levels.indexOf(level);

  /// The grade [level] stands for, or `null` when the type does not declare
  /// it.
  TomAuthState? gradeOf(String level) => _grades[level];

  /// The weakest level whose grade is [grade] or above, or `null` when no
  /// level reaches it — the minimum level a query for "every item this
  /// principal may read" (or write) asks for.
  String? lowestLevelGranting(TomAuthState grade) {
    for (final level in levels) {
      if (_grades[level]!.index >= grade.index) return level;
    }
    return null;
  }

  /// The stronger of two levels; a level the type does not declare is the
  /// weakest.
  String stronger(String a, String b) => rankOf(a) >= rankOf(b) ? a : b;

  /// The type as a manifest declares it ([TomItemType.fromJson]).
  Map<String, Object?> toJson() => {
    'name': name,
    'levels': [
      for (final level in levels)
        {'name': level, 'grade': _grades[level]!.name},
    ],
  };

  @override
  String toString() => 'TomItemType($name: ${levels.join(' < ')})';
}

// =============================================================================
// TomItemTypeRegistry — the declared types
// =============================================================================

/// The process-wide registry of item types, populated at start-up on client and
/// server alike so both read the same vocabulary.
class TomItemTypeRegistry {
  TomItemTypeRegistry._();

  static final Map<String, TomItemType> _types = {};

  /// Declares [type], replacing a type of the same name.
  static void register(TomItemType type) => _types[type.name] = type;

  /// Declares [types].
  static void registerAll(Iterable<TomItemType> types) {
    for (final type in types) {
      register(type);
    }
  }

  /// The type named [name], or `null`.
  static TomItemType? lookup(String name) => _types[name];

  /// Every declared type.
  static List<TomItemType> get types => List.unmodifiable(_types.values);

  /// The declared type [resourceKey] is an item key or pattern of, or `null`
  /// when it names no declared type.
  static TomItemType? typeOfKey(String resourceKey) {
    final colon = resourceKey.indexOf(':');
    if (colon <= 0) return null;
    return _types[resourceKey.substring(0, colon)];
  }

  /// Removes every declared type. Intended for testing.
  static void reset() => _types.clear();
}

// =============================================================================
// TomItemPermissions — what a principal may do with one item
// =============================================================================

/// Resolves the level a principal holds on an item from its
/// `resourceKey → role` map ([TomAccessControlInformation.resourceRoles]).
abstract final class TomItemPermissions {
  /// The strongest level [resourceRoles] holds on item [itemId] of [type] —
  /// on its key or on a pattern covering it — or `null` when none.
  static String? levelOn(
    Map<String, String> resourceRoles,
    TomItemType type,
    String itemId,
  ) {
    final key = type.keyFor(itemId);
    final prefix = '${type.name}:';
    String? best;
    for (final entry in resourceRoles.entries) {
      final held = entry.key;
      final matches =
          held == key ||
          (held.startsWith(prefix) &&
              held.endsWith('*') &&
              key.startsWith(held.substring(0, held.length - 1)));
      if (!matches || type.rankOf(entry.value) < 0) continue;
      best = best == null ? entry.value : type.stronger(best, entry.value);
    }
    return best;
  }

  /// Whether [resourceRoles] holds [level] or a stronger one on item [itemId]
  /// of [type].
  ///
  /// Throws [ArgumentError] when [type] does not declare [level]: asking for a
  /// level the vocabulary does not have is a bug, not a denial.
  static bool allows(
    Map<String, String> resourceRoles,
    TomItemType type,
    String itemId,
    String level,
  ) {
    final wanted = type.rankOf(level);
    // throws-outside-family: programmer error — see the dartdoc.
    if (wanted < 0) {
      throw ArgumentError.value(
        level,
        'level',
        'is not a level of ${type.name}',
      );
    }
    final held = levelOn(resourceRoles, type, itemId);
    return held != null && type.rankOf(held) >= wanted;
  }

  /// The grade of the level [resourceRoles] holds on item [itemId] of [type] —
  /// [TomAuthState.none] when it holds none.
  static TomAuthState gradeOn(
    Map<String, String> resourceRoles,
    TomItemType type,
    String itemId,
  ) {
    final held = levelOn(resourceRoles, type, itemId);
    return held == null ? TomAuthState.none : type.gradeOf(held)!;
  }
}

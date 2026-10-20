/// The keys a running session will try, by file.
library;

import 'key_material.dart';

/// The keys a running session will try, by container.
///
/// Every encrypted container may use a different key: a default covers
/// ordinary files and a per-file override is registered when the default is
/// rejected. The surface is stated in [TomKeyMaterial], so nothing above a
/// composition root has to name a container library's types. A binding turns
/// the material into that library's credentials and opens containers with it;
/// [TomMemoryKeyRegistry] is the one for a build that opens none.
abstract interface class TomKeyRegistry {
  /// Whether a default key is registered.
  bool get hasDefault;

  /// Registers [material] as the default key, or clears it when null.
  ///
  /// Throws [StateError] for material that is not resolvable.
  void registerDefault(TomKeyMaterial? material);

  /// Registers [material] as the key for [locator], ahead of the default.
  ///
  /// Throws [StateError] for material that is not resolvable.
  void registerKeyFor(String locator, TomKeyMaterial material);

  /// Drops the per-file key for [locator], falling back to the default.
  void removeKeyFor(String locator);

  bool hasOverrideFor(String locator);

  /// Every locator with a per-file key — session-only ones included, which no
  /// key store knows about. What forgetting a location walks.
  Iterable<String> get overriddenLocators;

  /// A second, empty registry of the same binding.
  ///
  /// An application may hold separate defaults for separate kinds of file, so
  /// a session holds several registries; asking one for another builds them
  /// without naming a binding.
  TomKeyRegistry newScope();
}

/// A [TomKeyRegistry] that holds key material and opens nothing.
///
/// For a build with no container codec — a browser build, for instance. A key
/// prompt still works and the material is held for the session; there is
/// simply no container for it to open.
class TomMemoryKeyRegistry implements TomKeyRegistry {
  TomKeyMaterial? _default;
  final Map<String, TomKeyMaterial> _overrides = {};

  @override
  bool get hasDefault => _default != null;

  @override
  void registerDefault(TomKeyMaterial? material) {
    material?.requireResolvable();
    _default = material;
  }

  @override
  void registerKeyFor(String locator, TomKeyMaterial material) {
    material.requireResolvable();
    _overrides[locator] = material;
  }

  @override
  void removeKeyFor(String locator) => _overrides.remove(locator);

  @override
  bool hasOverrideFor(String locator) => _overrides.containsKey(locator);

  @override
  Iterable<String> get overriddenLocators => List.unmodifiable(_overrides.keys);

  @override
  TomKeyRegistry newScope() => TomMemoryKeyRegistry();
}

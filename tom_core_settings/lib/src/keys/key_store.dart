/// Where keys are kept between sessions.
library;

import 'key_material.dart';

/// Persists container keys across sessions.
///
/// Holds two default keys and the per-file overrides, so a start-up can
/// re-hydrate a `TomKeyRegistry` without prompting for
/// anything the user has already answered.
///
/// Two defaults rather than one because documents and shared collaboration
/// files are routinely opened by different sets of people: someone who may
/// open a folder's collaboration file need not be able to open every document
/// in it.
abstract class TomKeyStore {
  /// The persisted default **document** key, or null when none was saved.
  Future<TomKeyMaterial?> loadDefaultKey();

  /// Persists (or clears, when [material] is null) the default document key.
  Future<void> saveDefaultKey(TomKeyMaterial? material);

  /// The persisted default **collaboration-file** key, or null.
  Future<TomKeyMaterial?> loadCollaborationDefaultKey();

  /// Persists (or clears) the default collaboration-file key.
  Future<void> saveCollaborationDefaultKey(TomKeyMaterial? material);

  /// Every persisted per-file override, keyed by locator.
  Future<Map<String, TomKeyMaterial>> loadOverrides();

  /// Persists a per-file override for [locator].
  Future<void> saveOverride(String locator, TomKeyMaterial material);

  /// Removes the persisted override for [locator].
  Future<void> removeOverride(String locator);
}

/// Volatile [TomKeyStore] — keys live only for the session.
///
/// For tests and for any build with nowhere durable to put them. A run against
/// it prompts for every key on every launch, which is exactly what "the keys
/// were not persisted" means.
class TomInMemoryKeyStore implements TomKeyStore {
  TomKeyMaterial? _defaultKey;
  TomKeyMaterial? _collaborationDefaultKey;
  final Map<String, TomKeyMaterial> _overrides = {};

  @override
  Future<TomKeyMaterial?> loadDefaultKey() async => _defaultKey;

  @override
  Future<void> saveDefaultKey(TomKeyMaterial? material) async =>
      _defaultKey = material;

  @override
  Future<TomKeyMaterial?> loadCollaborationDefaultKey() async =>
      _collaborationDefaultKey;

  @override
  Future<void> saveCollaborationDefaultKey(TomKeyMaterial? material) async =>
      _collaborationDefaultKey = material;

  @override
  Future<Map<String, TomKeyMaterial>> loadOverrides() async =>
      Map.of(_overrides);

  @override
  Future<void> saveOverride(String locator, TomKeyMaterial material) async =>
      _overrides[locator] = material;

  @override
  Future<void> removeOverride(String locator) async =>
      _overrides.remove(locator);
}

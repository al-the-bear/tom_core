/// Forgetting a storage location: removing it and every trace this device
/// holds for it.
///
/// Removing the `locations` entry alone ([TomLocationRegistry.forget]) is the
/// convenience half — the place stops being offered. The security half is
/// everything else this device kept *because* of that location, all of it
/// keyed by the locators inside it:
///
/// | Trace | Where | Removed by |
/// | ----- | ----- | ---------- |
/// | per-file key overrides | the persisted key store and the session's key registries | [TomKeyStore.removeOverride], [TomKeyRegistry.removeKeyFor] |
/// | blobs reachable only from it | the storage cache's `blobs/` | [TomStorageCache.scrubLocation] |
/// | its `meta/` | the storage cache's `meta/` | the same, under the backend's [TomStorage.cacheMetaScope] |
/// | its journal entries | the offline commit journal | [TomCommitJournal.scrubLocation] |
///
/// Journal entries are **unpushed work**, so the action is two steps:
/// [TomLocationForgetting.survey] says what forgetting would remove — the
/// caller asks for confirmation, and says plainly that the pending changes go
/// with it — and [TomLocationForgetting.forget] removes it.
///
/// Nothing *at* the location is touched. A repository or folder that is
/// forgotten still holds every document it held; only this device's memory of
/// it goes.
library;

import 'package:tom_core_storage/tom_core_storage.dart';
import 'keys/key_registry.dart';
import 'keys/key_store.dart';
import 'location_registry.dart';

/// What forgetting a location would remove, gathered before anything is.
class TomLocationTraces {
  final String location;

  /// Journal entries for containers inside the location — unpushed work that
  /// forgetting discards.
  final List<TomPendingCommit> unpushed;

  /// Locators inside the location with a per-file key override, persisted or
  /// session-only.
  final List<String> keyOverrides;

  const TomLocationTraces({
    required this.location,
    this.unpushed = const [],
    this.keyOverrides = const [],
  });

  /// The distinct documents [unpushed] is for.
  List<String> get unpushedLocators =>
      {for (final entry in unpushed) entry.locator}.toList()..sort();
}

/// What [TomLocationForgetting.forget] removed.
class TomForgottenLocation {
  final String location;

  /// Whether the `locations` entry's removal was persisted (see
  /// [TomLocationRegistry.forget]).
  final bool persisted;
  final int journalEntriesRemoved;
  final int keyOverridesRemoved;
  final TomCacheScrub cache;

  const TomForgottenLocation({
    required this.location,
    required this.persisted,
    this.journalEntriesRemoved = 0,
    this.keyOverridesRemoved = 0,
    this.cache = const TomCacheScrub(),
  });

  @override
  String toString() =>
      'TomForgottenLocation($location: '
      '$journalEntriesRemoved journal, $keyOverridesRemoved keys, $cache)';
}

/// Forgets a storage location and scrubs its traces.
///
/// Built **per action**, over whatever the composition root holds at that
/// moment: the key store is late-bound (it lives inside the settings
/// container), and a build without a cache or a journal passes null and has
/// nothing of that kind to scrub.
class TomLocationForgetting {
  final TomLocationRegistry locations;

  /// The persisted key store, or null on a build that persists none.
  final TomKeyStore? keyStore;

  /// The session's key registries, which also hold overrides that were never
  /// persisted.
  final List<TomKeyRegistry> keyRegistries;
  final TomStorageCache? cache;
  final TomCommitJournal? journal;

  /// The backends this build offers, asked for the location's `meta/` scope.
  final List<TomStorage> backends;

  const TomLocationForgetting({
    required this.locations,
    this.keyStore,
    this.keyRegistries = const [],
    this.cache,
    this.journal,
    this.backends = const [],
  });

  /// What [forget] would remove for [location]. Changes nothing.
  Future<TomLocationTraces> survey(String location) async {
    final unpushed = [
      for (final entry
          in await journal?.pending() ?? const <TomPendingCommit>[])
        if (tomLocationCovers(location, entry.locator)) entry,
    ];
    return TomLocationTraces(
      location: location,
      unpushed: unpushed,
      keyOverrides: (await _overridesUnder(location)).toList()..sort(),
    );
  }

  /// Forgets [location] and removes every trace of it this device holds.
  ///
  /// Call only after the user has confirmed what [survey] reported: the
  /// journal entries it removes are changes that never reached the remote.
  Future<TomForgottenLocation> forget(String location) async {
    // The meta scope is decided against the *other* locations before this one
    // is removed from the list it is compared with.
    final metaScope = _exclusiveMetaScope(location);

    final overrides = await _overridesUnder(location);
    for (final locator in overrides) {
      for (final registry in keyRegistries) {
        registry.removeKeyFor(locator);
      }
      await keyStore?.removeOverride(locator);
    }
    final dropped =
        await journal?.scrubLocation(location) ?? const <TomPendingCommit>[];
    final scrub =
        await cache?.scrubLocation(location, metaScope: metaScope) ??
        const TomCacheScrub();
    final persisted = await locations.forget(location);
    return TomForgottenLocation(
      location: location,
      persisted: persisted,
      journalEntriesRemoved: dropped.length,
      keyOverridesRemoved: overrides.length,
      cache: scrub,
    );
  }

  Future<Set<String>> _overridesUnder(String location) async => {
    for (final locator
        in (await keyStore?.loadOverrides())?.keys ?? const <String>[])
      if (tomLocationCovers(location, locator)) locator,
    for (final registry in keyRegistries)
      for (final locator in registry.overriddenLocators)
        if (tomLocationCovers(location, locator)) locator,
  };

  /// The backend's `meta/` scope for [location], or null when it keeps none
  /// or another registered location shares it — records another location
  /// reaches are not this one's to remove.
  List<String>? _exclusiveMetaScope(String location) {
    List<String>? scopeOf(String locator) {
      for (final backend in backends) {
        if (!backend.handles(locator)) continue;
        return backend.cacheMetaScope(locator);
      }
      return null;
    }

    final scope = scopeOf(location);
    if (scope == null) return null;
    final key = scope.join('/');
    for (final other in locations.locations) {
      if (other.locator == location) continue;
      if (scopeOf(other.locator)?.join('/') == key) return null;
    }
    return scope;
  }
}

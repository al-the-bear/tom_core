/// Reading and writing the registered storage locations.
library;

import 'storage_location.dart';

/// Where the registered storage locations live.
///
/// A port rather than the encrypted settings store itself: registering a
/// location has to work on a build that persists nothing, and a port with an
/// in-memory implementation says "remembered for this session" truthfully
/// rather than through a null check at every call site.
abstract interface class TomLocationRegistry {
  /// Every registered location. Empty is the ordinary first-run answer.
  List<TomStorageLocation> get locations;

  /// Registers [location], replacing whatever was held for its locator.
  ///
  /// Returns whether it was **persisted**. False is not an error the caller
  /// must handle — the location is registered for this session either way —
  /// but "in effect now, gone at restart" is a different promise from "saved",
  /// and only the caller that has somewhere to say so should say it.
  Future<bool> register(TomStorageLocation location);

  /// Forgets the location at [locator], if any.
  ///
  /// **Forgetting a location does not touch anything stored at it.** The list
  /// is of places the application offers, not of places the user may open.
  Future<bool> forget(String locator);
}

/// A registry that remembers for the session and no longer.
///
/// What a build with no settings container gets: opening a second document
/// from the same repository in one sitting is the case it serves.
class TomInMemoryLocationRegistry implements TomLocationRegistry {
  /// Insertion-ordered, keyed by locator — never by display name.
  final Map<String, TomStorageLocation> _byLocator = {};

  @override
  List<TomStorageLocation> get locations =>
      List.unmodifiable(_byLocator.values);

  @override
  Future<bool> register(TomStorageLocation location) async {
    _byLocator[location.locator] = location;
    // Never persisted, and that is the answer rather than a failure: the
    // caller renders it as "not saved", which is what happened.
    return false;
  }

  @override
  Future<bool> forget(String locator) async {
    _byLocator.remove(locator);
    return false;
  }
}

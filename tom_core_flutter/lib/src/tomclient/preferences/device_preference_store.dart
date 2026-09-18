import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'device_preferences.dart';

/// Where a device's preferences are persisted.
///
/// Deliberately the narrowest interface [TomStoredDevicePreferences] needs:
/// read the stored preferences back, write them. There is no per-key accessor,
/// no `exists` and no `clear` — writing an empty list *is* clearing, so a third
/// method would be a second way to say the same thing, and a per-key method
/// would double the surface every new backend has to implement. Two methods is
/// the whole cost of adapting one: `shared_preferences`, a platform keychain,
/// an encrypted file.
///
/// This is the **only** part of the module that is platform-specific. The typed
/// API, the codec and the precedence rule above it are the same everywhere,
/// which is what makes the call site platform-independent.
///
/// The unit is [TomUserPreferenceDto] — the kernel's wire DTO — rather than a
/// device-local shape of its own. A device preference and a server preference
/// are the same thing stored in two places, and giving the device its own
/// record type would mean a second `valueType` convention that agreed with the
/// server's only by inspection.
abstract class TomDevicePreferenceStore {
  /// Allows `const` implementations.
  const TomDevicePreferenceStore();

  /// Reads every persisted preference.
  ///
  /// Returns an empty list when nothing has been persisted yet — absence is not
  /// an error. Implementations that find unreadable content throw
  /// `device_preferences.store.invalid_content` rather than silently returning
  /// empty, because a corrupt store that looks empty would be overwritten by
  /// the next [write] and lose everything the device had chosen.
  ///
  /// **The returned list belongs to the store.** A caller must not modify it,
  /// and an implementation is free to return its own list, an unmodifiable view
  /// of one, or the same instance on every call. So a store may be written as a
  /// cache over `shared_preferences` or a keychain without a defensive copy per
  /// read; the three backends shipped here copy or decode a fresh list only
  /// because that is what their storage makes cheapest, and nothing may depend
  /// on it. A caller that needs to change the set reads it, copies, and hands
  /// the copy to [write].
  Future<List<TomUserPreferenceDto>> read();

  /// Replaces the persisted preferences with [values].
  ///
  /// A write must be **all-or-nothing**: a failure part-way through must leave
  /// the previously readable content intact rather than a truncated set. An
  /// empty [values] clears the store.
  ///
  /// **[values] belongs to the caller** — the other half of the same rule. An
  /// implementation must not modify it, and must not retain it beyond the call
  /// without copying, because the caller may still hold it and may pass a list
  /// that cannot be modified at all: `TomStoredDevicePreferences.clear()`
  /// passes `const []`.
  Future<void> write(List<TomUserPreferenceDto> values);
}

/// Detects a [TomDevicePreferenceStore.write] over a document other than the
/// one this store last saw.
///
/// Every write in this module is a read-modify-write over the **whole**
/// document — there is no per-key storage to update in place — so two writers
/// over one location each read the same document and each write their own
/// version of it. The io backend's write-then-rename makes a *single* write
/// all-or-nothing against a torn file; it does not make two writes ordered, and
/// the web backend has no atomicity at all. Without this, the second write won
/// entirely and the first change was gone with nothing raised anywhere.
///
/// **Compare-and-swap over the document's identity, not a version counter.** A
/// counter would have to live in the stored JSON, and a header in every document
/// would retire the property `TomDevicePreferenceJson` is built around: that an
/// unowned document is exactly the array the server's `/preferences` list
/// endpoint answers, so the same text moves between the two stores without a
/// reshaping step. Comparing what is there against what was read answers the
/// same question — "is this still the document I read?" — inside the two
/// methods the backend contract already has, and needs no format at all.
///
/// The identity is whatever the backend can compare cheaply: the stored text for
/// the two persistent backends, a revision counter for the in-memory one. It is
/// opaque here on purpose — this mixin decides *when* to compare, and the
/// backend decides *what*.
mixin TomDevicePreferenceStoreConflictDetection on TomDevicePreferenceStore {
  bool _hasSeen = false;
  Object? _lastSeen;

  /// Records the document identity a read or a completed write observed.
  ///
  /// Called after a write as well as after a read, so a second write with no
  /// read between them compares against what this store itself put there rather
  /// than against a document two writes old.
  void rememberDocument(Object? identity) {
    _hasSeen = true;
    _lastSeen = identity;
  }

  /// Throws `device_preferences.store.conflict` when [identity] is not what
  /// this store last saw.
  ///
  /// A store that has never read anything makes no claim about what is there,
  /// so it does not conflict: a caller writing without reading is replacing the
  /// document wholesale, which is what they asked for.
  void requireUnchanged(Object? identity, {required String source}) {
    if (!_hasSeen || identity == _lastSeen) return;
    throw TomDevicePreferenceException(
      'device_preferences.store.conflict',
      'The device preference store $source changed since it was read, so '
          'writing now would discard what the other writer stored. Read it '
          'again and re-apply the change.',
      parameters: {'source': source},
    );
  }
}

/// An in-memory [TomDevicePreferenceStore].
///
/// Works on every platform and persists nothing beyond the process, which makes
/// it the right store for tests, for examples, and for a client that
/// deliberately keeps no machine-local state.
///
/// Because it forgets on exit it is *not* a fallback to reach for when a
/// platform has no real backend — a store that silently forgets is worse than a
/// loud one, which is why [TomPlatformDevicePreferenceStore] throws on such a
/// platform instead of degrading to this.
class TomMemoryDevicePreferenceStore extends TomDevicePreferenceStore
    with TomDevicePreferenceStoreConflictDetection {
  /// Creates an empty store, optionally pre-seeded with [initialValues].
  TomMemoryDevicePreferenceStore([List<TomUserPreferenceDto>? initialValues])
    : _values = [...?initialValues];

  List<TomUserPreferenceDto> _values;

  /// Bumped by every write. The document identity this backend compares.
  ///
  /// A counter rather than the content, because nothing here serialises: two
  /// writes of equal content are still two writes, and an in-memory store is
  /// where a test stages the interleave the persistent ones meet in the field.
  int _revision = 0;

  @override
  Future<List<TomUserPreferenceDto>> read() async {
    rememberDocument(_revision);
    return [..._values];
  }

  @override
  Future<void> write(List<TomUserPreferenceDto> values) async {
    requireUnchanged(_revision, source: 'in memory');
    _values = [...values];
    _revision++;
    rememberDocument(_revision);
  }
}

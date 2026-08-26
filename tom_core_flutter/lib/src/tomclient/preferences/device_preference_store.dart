import 'package:tom_core_kernel/tom_core_kernel.dart';

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
class TomMemoryDevicePreferenceStore extends TomDevicePreferenceStore {
  /// Creates an empty store, optionally pre-seeded with [initialValues].
  TomMemoryDevicePreferenceStore([List<TomUserPreferenceDto>? initialValues])
    : _values = [...?initialValues];

  List<TomUserPreferenceDto> _values;

  @override
  Future<List<TomUserPreferenceDto>> read() async => [..._values];

  @override
  Future<void> write(List<TomUserPreferenceDto> values) async {
    _values = [...values];
  }
}

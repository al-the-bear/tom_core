import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'device_preference_store.dart';
import 'device_preferences.dart';

/// The [TomDevicePreferences] the framework ships: the typed API over a
/// [TomDevicePreferenceStore].
///
/// Everything platform-specific is in the store; everything *typed* is here.
/// That split is what makes the promise of this module true — the encode /
/// decode decision is made once, so a `DateTime` written on a phone and read on
/// the desktop build of the same app means the same instant, and a preference
/// read as the wrong type fails on every backend rather than on some of them.
///
/// ```dart
/// final preferences = TomStoredDevicePreferences(
///   TomPlatformDevicePreferenceStore('/path/to/device_preferences.json'),
/// );
/// await preferences.set('device.lastAccount', 'alex@example.com');
/// ```
///
/// ## Every operation goes to the store
///
/// There is no in-memory cache. A device preference is read when a screen opens
/// and written when a user changes a switch — human-paced, a handful of entries
/// — so a cache would buy nothing measurable and cost the one thing that
/// matters: a second browser tab, a background isolate or a platform settings
/// panel writing the same store would leave the cache holding a value the user
/// no longer has.
///
/// It is also what makes an account switch a one-line affair: an application
/// that keeps its accounts apart by giving each its own store location (see
/// [TomDevicePreferences]) only has to install the new store — there is no
/// retained state to invalidate, so the next read already answers from the new
/// account's document.
class TomStoredDevicePreferences extends TomDevicePreferences {
  /// The backend preferences are persisted in.
  final TomDevicePreferenceStore store;

  /// Creates the typed API over [store].
  const TomStoredDevicePreferences(this.store);

  @override
  Future<List<TomUserPreferenceDto>> all() async =>
      List.unmodifiable(await store.read());

  @override
  Future<TomUserPreferenceDto?> read(String key) async {
    TomUserPreferenceKeys.validate(key);
    for (final stored in await store.read()) {
      if (stored.key == key) return stored;
    }
    return null;
  }

  @override
  Future<T?> get<T extends Object>(String key) async {
    final dto = await read(key);
    return dto == null ? null : TomUserPreferenceCodec.decode<T>(dto);
  }

  @override
  Future<T> getOr<T extends Object>(String key, T fallback) async =>
      await get<T>(key) ?? fallback;

  @override
  Future<TomUserPreferenceDto> set<T extends Object>(
    String key,
    T value,
  ) async {
    // Encode before reading the store: neither an illegal key nor an
    // unencodable value must cause a read-modify-write cycle that ends in a
    // rewrite of unchanged content. `encode` is also what checks the key, so
    // this store holds the same vocabulary as the server one — which is what
    // lets a preference move between them.
    final written = TomUserPreferenceCodec.encode(
      key,
      value,
      // The device's own clock. Unlike the server store, nothing here can
      // supply a more authoritative timestamp — but it is still normalised to
      // UTC, so a preference that later moves to the server carries an instant
      // the server can store unchanged.
      updatedAt: DateTime.now().toUtc(),
    );

    // Copy before modifying: the list belongs to the store, not to this method
    // (see [TomDevicePreferenceStore.read]). Every shipped backend happens to
    // hand out a list nobody else holds, but that is their choice and not the
    // contract — a cache-backed store returning its own list, or an
    // unmodifiable view of one, is a correct implementation, and mutating it
    // here would either corrupt the cache or throw an `UnsupportedError` no
    // caller could map to a preference failure.
    final values = [...await store.read()];
    final existing = values.indexWhere((stored) => stored.key == key);
    if (existing >= 0) {
      values[existing] = written;
    } else {
      values.add(written);
    }
    await store.write(values);
    return written;
  }

  @override
  Future<bool> remove(String key) async {
    TomUserPreferenceKeys.validate(key);
    final persisted = await store.read();
    final existing = persisted.indexWhere((stored) => stored.key == key);
    if (existing < 0) return false;
    // Copied for the same reason as in [set], but only on the path that
    // actually modifies it: removing a key that is not there writes nothing, so
    // it should not copy anything either.
    final values = [...persisted]..removeAt(existing);
    await store.write(values);
    return true;
  }

  @override
  Future<void> clear() => store.write(const []);
}

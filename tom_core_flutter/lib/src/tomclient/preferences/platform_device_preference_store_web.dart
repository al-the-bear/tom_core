import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:web/web.dart';

import 'device_preference_json.dart';
import 'device_preference_store.dart';

/// A [TomDevicePreferenceStore] backed by the browser's `localStorage` — the
/// web (`dart:js`) variant.
///
/// Reach for it through `platform_device_preference_store.dart`, which selects
/// this implementation in the browser and a different one elsewhere.
///
/// `localStorage` rather than `sessionStorage` or a cookie: a device preference
/// must survive the tab being closed (which `sessionStorage` does not), and it
/// is machine-local state that has no business being attached to every request
/// (which a cookie is).
///
/// The whole document is stored under **one** entry, holding the JSON described
/// by [TomDevicePreferenceJson] — the same text the file backend writes. One
/// entry rather than one per preference so that a write is atomic in the only
/// sense `localStorage` offers: a single `setItem` either happened or did not,
/// while a loop over keys can be interrupted by the tab closing and leave a
/// half-written set.
class TomPlatformDevicePreferenceStore extends TomDevicePreferenceStore {
  /// Creates a store over the `localStorage` entry named [location].
  ///
  /// The name is the caller's choice because a browser origin is shared by
  /// everything the app serves from it, and only the app knows which name is
  /// free.
  ///
  /// The parameter is named `location` rather than `entryName` because it is
  /// the *same* parameter on every platform: a `localStorage` entry name here,
  /// a filesystem path on desktop and mobile. One name is what lets an
  /// application construct the store in one place without knowing which variant
  /// it got.
  const TomPlatformDevicePreferenceStore(this.location);

  /// Name of the `localStorage` entry holding this device's preferences.
  final String location;

  @override
  Future<List<TomUserPreferenceDto>> read() async {
    final content = window.localStorage.getItem(location);
    if (content == null) return [];
    return TomDevicePreferenceJson.decode(content, source: location);
  }

  @override
  Future<void> write(List<TomUserPreferenceDto> values) async {
    if (values.isEmpty) {
      // Removed rather than set to `[]`, so that "never written" and "cleared"
      // are one state here exactly as they are in the file backend.
      window.localStorage.removeItem(location);
      return;
    }
    window.localStorage.setItem(
      location,
      TomDevicePreferenceJson.encode(values),
    );
  }
}

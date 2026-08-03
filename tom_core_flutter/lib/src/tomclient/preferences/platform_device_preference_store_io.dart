import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'device_preference_json.dart';
import 'device_preference_store.dart';

/// A [TomDevicePreferenceStore] backed by a JSON file on the local filesystem —
/// the native (`dart:io`) variant, used on desktop and mobile.
///
/// Reach for it through `platform_device_preference_store.dart`, which selects
/// this implementation where `dart:io` exists and a different one elsewhere.
///
/// The file holds the JSON document described by [TomDevicePreferenceJson]. It
/// is written whole, never appended to, and **deleted** when the last
/// preference is removed — a device that has been reset should leave no file
/// behind, and "no file" and "empty array" must not be two ways to say the same
/// thing.
class TomPlatformDevicePreferenceStore extends TomDevicePreferenceStore {
  /// Creates a store over the file at [location].
  ///
  /// The path is the caller's choice because only the app knows where its
  /// machine-local state belongs — `path_provider`'s application-support
  /// directory on a Flutter client, a temporary directory in a test. Missing
  /// parent directories are created on the first [write].
  ///
  /// It is also what scopes the store: two locations are two independent key
  /// spaces, which is how an application with more than one account on one
  /// machine keeps their preferences apart. See [TomDevicePreferences].
  ///
  /// The parameter is named `location` rather than `path` because it is the
  /// *same* parameter on every platform: a filesystem path here, a
  /// `localStorage` entry name on the web. One name is what lets an application
  /// construct the store in one place without knowing which variant it got.
  const TomPlatformDevicePreferenceStore(this.location);

  /// Absolute path of the JSON file holding this device's preferences.
  final String location;

  @override
  Future<List<TomUserPreferenceDto>> read() async {
    final file = File(location);
    if (!await file.exists()) return [];
    return TomDevicePreferenceJson.decode(
      await file.readAsString(),
      source: location,
    );
  }

  @override
  Future<void> write(List<TomUserPreferenceDto> values) async {
    final file = File(location);
    if (values.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    // Write-then-rename: a rename within a directory is atomic, so a failure
    // part-way through leaves the previous content readable instead of a
    // truncated file — which the store contract requires, and which matters
    // here because a truncated document silently discards everything the user
    // chose on this device.
    final temporary = File('$location.part');
    await temporary.writeAsString(
      TomDevicePreferenceJson.encode(values),
      flush: true,
    );
    await temporary.rename(location);
  }
}

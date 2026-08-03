/// Executable example for the preferences module of `tom_core_flutter`.
///
/// Demonstrates the full life of a device-stored preference: register the store
/// once, write and read typed values through the platform-independent API,
/// survive a restart, apply the documented device-over-server precedence, and
/// clear the device.
///
/// The store used here is the JSON-file backend, reached through
/// `TomPlatformDevicePreferenceStore` — the same construction a real client
/// writes, with the path coming from `path_provider` instead of a temporary
/// directory. Nothing below branches on the platform, which is the point of the
/// module.
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so run
/// this under the Flutter toolchain, e.g.
/// `flutter test example/preferences/preferences_example.dart`, not bare
/// `dart run`. The same behaviour is covered by `test/preferences_test.dart`.
library;

import 'dart:io';

import 'package:tom_core_flutter/tom_core_flutter.dart';

Future<void> run() async {
  final directory = Directory.systemTemp.createTempSync('tom_preferences_');
  final location = '${directory.path}/device_preferences.json';

  try {
    // Example 1: registration. The one line in an application that knows where
    // machine-local state lives — every call site below resolves the interface.
    TomBean.withType(
      TomDevicePreferences,
      TomStoredDevicePreferences(TomPlatformDevicePreferenceStore(location)),
    );
    final preferences = TomDevicePreferences.resolve()!;

    // Example 2: typed writes and reads. The value carries its own type, so a
    // read says what it expects and the store says what it is.
    await preferences.set('device.lastAccount', 'alex@example.com');
    await preferences.set('device.biometricUnlock', true);
    await preferences.set('device.launchCount', 12);

    print('account=${await preferences.get<String>('device.lastAccount')}');
    print('biometric=${await preferences.get<bool>('device.biometricUnlock')}');
    assert(await preferences.get<int>('device.launchCount') == 12);

    // Example 3: an unwritten preference answers its default; a *mismatched*
    // one throws rather than coercing, because a value read as the wrong type
    // is one the caller will act on believing it is the user's.
    print('theme=${await preferences.getOr('device.theme', 'system')}');
    assert(await preferences.getOr('device.theme', 'system') == 'system');
    try {
      await preferences.get<String>('device.launchCount');
      throw StateError('a mismatched read must not succeed');
    } on TomUserPreferenceCodecException catch (error) {
      print('mismatch rejected: ${error.key}');
      assert(error.key == 'preferences.decode.type_mismatch');
    }

    // Example 4: persistence. A second store over the same location is the next
    // launch of the app — nothing is shared but what reached the device.
    final afterRestart = TomStoredDevicePreferences(
      TomPlatformDevicePreferenceStore(location),
    );
    print(
      'after restart=${await afterRestart.get<String>('device.lastAccount')}',
    );
    assert(await afterRestart.get<int>('device.launchCount') == 12);

    // Example 5: precedence. The device value wins while it exists; the server
    // store answers only a key this device has never written. The callback
    // stands in for a client of `/preferences/*`.
    await preferences.set(TomUserPreferenceKeys.theme, 'dark');
    final theme = await preferences.getPreferred<String>(
      TomUserPreferenceKeys.theme,
      () async => 'light', // what the account says
    );
    print('resolved theme=$theme');
    assert(theme == 'dark');

    final language = await preferences.getPreferred<String>(
      TomUserPreferenceKeys.language,
      () async => 'de', // never written on this device
    );
    print('resolved language=$language');
    assert(language == 'de');

    // Example 6: clearing the device. One atomic operation, not a loop — a loop
    // that failed half way would leave a state no user asked for.
    await preferences.clear();
    print('after clear=${await preferences.all()}');
    assert((await preferences.all()).isEmpty);
    assert(!File(location).existsSync()); // no file left behind
  } finally {
    TomBean.resetBeanContext();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}

Future<void> main() => run();

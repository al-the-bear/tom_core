// Conditional export: the right `TomPlatformDevicePreferenceStore` is chosen at
// compile time — the JSON-file implementation when `dart:io` is available, the
// `localStorage` implementation when `dart:js` is, and a variant that fails
// loudly on construction when neither is. Same shape as
// `platform_detection_client.dart` in the runtime module.
//
// This is the compile-time half of "one backend per platform". The runtime half
// is the bean: an application registers the `TomDevicePreferences` its platform
// needs (optionally with a `@platform*`-annotated `@TomComponent`, which the
// bean locator selects against the active `TomRuntime` platform), and the call
// site resolves the interface. Neither half is a branch at the call site, which
// is the point.
export 'platform_device_preference_store_neutral.dart'
    if (dart.library.io) 'platform_device_preference_store_io.dart'
    if (dart.library.js) 'platform_device_preference_store_web.dart';

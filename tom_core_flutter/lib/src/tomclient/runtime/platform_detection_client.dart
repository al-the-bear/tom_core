// Conditional import: the right `TomFlutterPlatformUtils` is chosen at compile
// time — the native IO implementation when `dart:io` is available, the web
// implementation when `dart:js` is, and the neutral fallback otherwise.
import 'platform_detection_neutral.dart'
    if (dart.library.io) 'platform_detection_flutter_io.dart'
    if (dart.library.js) 'platform_detection_web.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The platform utilities for the current Flutter target.
///
/// Returns a fresh [TomPlatformUtils] whose concrete type is selected at
/// compile time by the conditional import above: the native IO variant on
/// desktop/mobile, the web variant in the browser, or a neutral fallback. The
/// instance answers platform predicates (`isDesktop`, `isWeb`, `isAndroid`, …)
/// and provides a platform-appropriate HTTP [Client].
///
/// Typically registered as the process-wide platform at startup:
///
/// ```dart
/// TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);
/// ```
TomPlatformUtils get clientPlatformUtils => TomFlutterPlatformUtils();

// Conditional import: the right `TomFlutterPlatformUtils` is chosen at compile
// time — the native IO implementation when `dart:io` is available, the web
// implementation when `dart:js` is, and the neutral fallback otherwise.
import 'platform_detection_neutral.dart'
    if (dart.library.io) 'platform_detection_flutter_io.dart'
    if (dart.library.js) 'platform_detection_web.dart';

import 'package:flutter/foundation.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// The one instance [clientPlatformUtils] hands out, built on first read.
///
/// Nullable rather than `late final` so that [resetClientPlatformUtils] can
/// exist — see it for why a test needs to get back to "nothing built yet".
TomFlutterPlatformUtils? _clientPlatformUtils;

/// The platform utilities for the current Flutter target.
///
/// A [TomPlatformUtils] whose concrete type is selected at compile time by the
/// conditional import above: the native IO variant on desktop/mobile, the web
/// variant in the browser, or a neutral fallback. The instance answers platform
/// predicates (`isDesktop`, `isWeb`, `isAndroid`, …) and provides a
/// platform-appropriate HTTP [Client].
///
/// Typically registered as the process-wide platform at startup:
///
/// ```dart
/// TomPlatformUtils.setCurrentPlatform(clientPlatformUtils);
/// ```
///
/// **One instance, built on first read.** Every read answers the same object,
/// so a caller that reads the getter again instead of going through
/// `TomPlatformUtils.current` holds what the process registered rather than a
/// second, equal-looking one. That matters twice over. Comparing platform-utils
/// identities is meaningful rather than silently always false; and on the native
/// variant construction copies the whole process environment into the kernel's
/// env-var map, which a getter that constructed per read paid for on every
/// read, on a call that looks like a property access.
///
/// It is a cache rather than a constant because the target is only known at
/// run time on the web branch and the constructor does real work on the native
/// one — so the instance is built when something first asks for it, and not
/// during library load in a process that never uses it.
TomPlatformUtils get clientPlatformUtils =>
    _clientPlatformUtils ??= TomFlutterPlatformUtils();

/// Discards the built instance, so the next read constructs a new one.
///
/// Tests need this because the construction is otherwise one-way: what a
/// constructor does — on the native variant, importing the process environment
/// — can only be observed by a test that can get back to "nothing built yet".
/// The same reason `TomConfigResourceProvider.clearAppConfigProvider` exists,
/// and the same annotation.
///
/// It does not unregister anything: an instance already handed to
/// `TomPlatformUtils.setCurrentPlatform` stays registered, and a test that
/// cares re-registers what the next read returns.
@visibleForTesting
void resetClientPlatformUtils() {
  _clientPlatformUtils = null;
}

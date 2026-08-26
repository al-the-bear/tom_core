import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Neutral fallback [TomPlatformUtils] for targets that expose neither
/// `dart:io` nor `dart:js`.
///
/// Reports platform predicates from Flutter's [defaultTargetPlatform]/[kIsWeb]
/// but cannot create an HTTP [Client] — [httpClient] throws [UnsupportedError],
/// since a concrete platform variant must be selected for networking. Selected
/// by the conditional import in `platform_detection_client.dart`.
class TomFlutterPlatformUtils extends TomFallbackPlatformUtils {
  @override
  bool isDesktop() =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  bool isMobile() =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool isWeb() => kIsWeb;

  @override
  bool isFuchsia() => defaultTargetPlatform == TargetPlatform.fuchsia;
  @override
  bool isWindows() => defaultTargetPlatform == TargetPlatform.windows;
  @override
  bool isLinux() => defaultTargetPlatform == TargetPlatform.linux;
  @override
  bool isMacOs() => defaultTargetPlatform == TargetPlatform.macOS;
  @override
  bool isAndroid() => defaultTargetPlatform == TargetPlatform.android;
  @override
  bool isIos() => defaultTargetPlatform == TargetPlatform.iOS;

  // UnsupportedError, not UnimplementedError: nothing here is waiting to be
  // written. A target that exposes neither `dart:io` nor `dart:js` has no HTTP
  // client implementation to construct at all, so the refusal is permanent.
  @override
  Client httpClient() {
    throw UnsupportedError(
      'The neutral platform fallback has no HTTP client: this target exposes '
      'neither dart:io nor dart:js, so there is no Client implementation to '
      'construct. Select a concrete TomPlatformUtils variant for the target '
      'before making network calls.',
    );
  }

  @override
  String? getBrowserLocation() {
    return null;
  }

  @override
  String getIsolateName() => "ntrl";

  @override
  String toString() => "TomFlutterPlatformUtils: neutral";
}

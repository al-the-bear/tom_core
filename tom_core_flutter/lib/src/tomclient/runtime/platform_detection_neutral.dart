import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Neutral fallback [TomPlatformUtils] for targets that expose neither
/// `dart:io` nor `dart:js`.
///
/// Reports platform predicates from Flutter's [defaultTargetPlatform]/[kIsWeb]
/// but cannot create an HTTP [Client] — [httpClient] throws, since a concrete
/// platform variant must be selected for networking. Selected by the
/// conditional import in `platform_detection_client.dart`.
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

  @override
  void out(String s) => print(s);
  @override
  void outError(String s) => print(s);
  @override
  Client httpClient() {
    throw UnimplementedError(
      "You need initialize a platform specific TomPlatformUtils instance to create HttpClients",
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

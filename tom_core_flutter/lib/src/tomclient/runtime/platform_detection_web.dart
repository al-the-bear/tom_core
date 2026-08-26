import 'package:flutter/foundation.dart';
import 'package:web/web.dart' hide RequestMode, Client;
import 'package:fetch_client/fetch_client.dart';
import 'package:http/http.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Web (`dart:js`) [TomPlatformUtils] for the browser target.
///
/// Reports platform predicates from Flutter's [defaultTargetPlatform]/[kIsWeb],
/// exposes the browser location via [getBrowserLocation], and provides a
/// CORS-enabled [FetchClient]. Selected by the conditional import in
/// `platform_detection_client.dart`.
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
  Client httpClient() => FetchClient(mode: RequestMode.cors);

  @override
  String? getBrowserLocation() {
    return window.location.href;
  }

  @override
  String getIsolateName() => "web";

  @override
  String toString() => "TomFlutterPlatformUtils: web";
}

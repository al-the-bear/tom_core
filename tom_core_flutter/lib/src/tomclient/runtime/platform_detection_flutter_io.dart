import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Whether a TLS handshake with a bad certificate is tolerated for [host].
///
/// Only loopback hosts (`0.0.0.0`, `localhost`, `127.0.0.1`) are allowed; every
/// other host is rejected. Exposed at the top level so the decision can be
/// unit-tested directly — the [HttpClient.badCertificateCallback] receives an
/// [X509Certificate] (which has no public constructor) and is not readable back
/// off the client, so the logic is otherwise unreachable from a test.
bool allowsBadCertificateForHost(String host) =>
    host == "0.0.0.0" || host == "localhost" || host == "127.0.0.1";

/// Native (`dart:io`) [TomPlatformUtils] for desktop and mobile targets.
///
/// Imports the process environment into [getTomEnvVars] at construction,
/// reports platform predicates from Flutter's [defaultTargetPlatform]/[kIsWeb],
/// and provides an [IOClient] (permissive certificate handling for localhost
/// only). Selected by the conditional import in
/// `platform_detection_client.dart`.
class TomFlutterPlatformUtils extends TomFallbackPlatformUtils {
  TomFlutterPlatformUtils() {
    getTomEnvVars().addAll(Platform.environment);
  }

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

  // Note: iOS/macOS could use a native CupertinoClient (cupertino_http) for
  // better platform integration; for now all native targets share this
  // IOClient.
  @override
  Client httpClient() {
    return IOClient(
      HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) =>
                allowsBadCertificateForHost(host),
    );
  }

  @override
  String? getBrowserLocation() {
    return null;
  }

  @override
  String getIsolateName() => Isolate.current.debugName ?? "main";

  @override
  String toString() => "TomFlutterPlatformUtils: io";
}

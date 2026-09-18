import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'bad_certificate_policy.dart';

/// Native (`dart:io`) [TomPlatformUtils] for desktop and mobile targets.
///
/// Imports the process environment into [getTomEnvVars] at construction,
/// reports platform predicates from Flutter's [defaultTargetPlatform]/[kIsWeb],
/// and provides an [IOClient] whose certificate handling is
/// [TomBadCertificatePolicy] — permissive for the loopback hosts it names and
/// refusing for everything else. Selected by the conditional import in
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
        // Read per handshake, not captured: a policy narrowed after a client
        // was built has to take effect on that client too, or hardening an
        // application would depend on the order its clients happened to be
        // created in.
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) =>
                TomBadCertificatePolicy.allows(host),
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

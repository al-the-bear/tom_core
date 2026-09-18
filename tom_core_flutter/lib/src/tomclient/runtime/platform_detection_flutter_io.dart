import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'bad_certificate_policy.dart';
import 'platform_detection_base.dart';

/// Native (`dart:io`) [TomPlatformUtils] for desktop and mobile targets.
///
/// Imports the process environment into [getTomEnvVars] at construction, and
/// provides an [IOClient] whose certificate handling is
/// [TomBadCertificatePolicy] — permissive for the loopback hosts it names and
/// refusing for everything else. Selected by the conditional import in
/// `platform_detection_client.dart`.
///
/// The platform predicates are [TomFlutterPlatformUtilsBase]'s — all three
/// variants answer them identically, from the same two Flutter symbols.
class TomFlutterPlatformUtils extends TomFlutterPlatformUtilsBase {
  TomFlutterPlatformUtils() {
    getTomEnvVars().addAll(Platform.environment);
  }

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
  String getIsolateName() => Isolate.current.debugName ?? "main";

  @override
  String toString() => "TomFlutterPlatformUtils: io";
}

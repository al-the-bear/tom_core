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

  /// An [IOClient] over `dart:io`'s [HttpClient], on **every** native target.
  ///
  /// **One client for all of them, deliberately.** Apple targets could have
  /// `cupertino_http`'s `CupertinoClient`, which is backed by `URLSession` and
  /// brings the system proxy configuration, the platform certificate store and
  /// background transfers with it. That was considered and declined: it is a
  /// dependency carrying a native plugin, and a second HTTP path that no Linux
  /// or Windows host can exercise — bought for a benefit no consumer of this
  /// framework currently needs, since none ships to iOS or macOS.
  ///
  /// If an Apple target appears, the shape to add is a runtime branch on
  /// [defaultTargetPlatform] *here*, inside this variant. Not a fourth
  /// compile-time variant: `dart:io` is available on iOS and macOS, so the
  /// conditional import that selects between native, web and neutral cannot
  /// separate an Apple target from any other native one.
  ///
  /// The certificate policy is [TomBadCertificatePolicy], read per handshake.
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

  /// This isolate's `debugName`, or `"main"` when it reports none.
  ///
  /// **A label, not an identifier.** Nothing makes it unique, and whether it
  /// discriminates depends on who spawned the isolate and how:
  ///
  /// - The root isolate's `debugName` is already `"main"`, so the fallback
  ///   coincides with it rather than colliding with it. The `??` is for a
  ///   runtime that reports none.
  /// - `Isolate.spawn` defaults `debugName` to the **entry point's function
  ///   name**, so several isolates spawned from *one* entry point all answer
  ///   the same thing — which is exactly the worker-pool shape, and exactly
  ///   when a reader most wants to tell two lines apart.
  /// - An explicit `debugName` is the remedy, and the framework's own
  ///   `TomWorkerPool` passes one — every worker it spawns gets a numbered
  ///   name, so framework concurrency is already distinguishable.
  ///
  /// The other two variants answer a constant, so on those targets the name
  /// never discriminates at all.
  @override
  String getIsolateName() => Isolate.current.debugName ?? "main";

  @override
  String toString() => "TomFlutterPlatformUtils: io";
}

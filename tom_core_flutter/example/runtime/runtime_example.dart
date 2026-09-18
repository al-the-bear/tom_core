/// Executable example for the runtime module of `tom_core_flutter`.
///
/// Demonstrates obtaining the platform-appropriate `TomPlatformUtils` for the
/// current target, querying its platform predicates, taking an HTTP client from
/// it, and reading and replacing the certificate policy that client consults.
/// The concrete variant is chosen at compile time (native IO / web / neutral).
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so this
/// runs under the Flutter toolchain, not bare `dart run`. Run it with
/// `flutter test test/runtime_test.dart`: that suite calls [run], so the
/// command executes everything below and its exit code says whether the
/// assertions held. Pointing `flutter test` at *this* file also runs it, but
/// then exits 79 ("No tests were found") whether it succeeded or not — an
/// example declares no `test()` of its own.
library;

// `defaultTargetPlatform` is what every predicate below reads, and the example
// prints it, so it is imported here rather than hidden behind the predicates.
// The barrel does not re-export it.
import 'package:flutter/foundation.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

void run() {
  // Example 1: obtain the platform utilities for the current target. The getter
  // answers one instance per process, built on this first read, so reading it
  // again is free and gives back the same object — which is why registering it
  // and reading it later both work.
  final utils = clientPlatformUtils;
  print('platform utils: $utils');
  assert(identical(utils, clientPlatformUtils));

  // Example 2: register them process-wide (as an app would at startup).
  TomPlatformUtils.setCurrentPlatform(utils);

  // Example 3: query platform predicates.
  //
  // Every predicate reads Flutter's `defaultTargetPlatform`, so what they
  // answer is "which platform is this build targeting", not "which machine is
  // this running on". Those coincide on a device and part company under
  // `flutter test`, where the target is android whatever the host is — which
  // is why running this on a Mac reports `isDesktop=false isMobile=true`. That
  // is the module working, not failing, so the target is printed next to the
  // answer and the reason stays visible.
  print('flutterTarget=$defaultTargetPlatform');
  print(
    'isWeb=${utils.isWeb()} '
    'isDesktop=${utils.isDesktop()} '
    'isMobile=${utils.isMobile()}',
  );
  print('isolate=${utils.getIsolateName()}');

  // Example 4: the browser location is web-only; on native it is null. The
  // variant's toString names which implementation was selected.
  print('browserLocation=${utils.getBrowserLocation()}');
  print('variant=$utils');

  // Example 5: take an HTTP client from the platform. This is one of the few
  // members that genuinely differ per variant — an `IOClient` natively, a
  // CORS `FetchClient` on web, and a refusal on the neutral fallback — so it
  // is where the compile-time choice becomes visible in behaviour rather than
  // just in a name. Close it when finished; it owns a connection pool.
  final client = utils.httpClient();
  print('httpClient=${client.runtimeType}');
  client.close();

  // Example 6: the certificate policy. The native client accepts an unverified
  // TLS certificate only for the hosts this names — a loopback address is not
  // reachable from another machine, so a certificate presented on one came from
  // this machine whatever it claims. Both loopback families are in the shipped
  // list, because which one `localhost` resolves to differs between machines
  // and naming only one makes the same code succeed here and fail there.
  print('badCertificateHosts=${TomBadCertificatePolicy.hosts.join(", ")}');
  assert(TomBadCertificatePolicy.allows('127.0.0.1'));
  assert(TomBadCertificatePolicy.allows('::1'));
  assert(!TomBadCertificatePolicy.allows('example.com'));

  // An application may replace the list — to add a development host, or to
  // narrow it to nothing for a hardened build. A replacement is logged, because
  // from then on the policy in force is no longer the policy in the source.
  TomBadCertificatePolicy.allowOnly(const []);
  assert(!TomBadCertificatePolicy.allows('localhost'));
  TomBadCertificatePolicy.reset();
  assert(TomBadCertificatePolicy.allows('localhost'));

  // Assertions. The first two follow from running on the VM, where the native
  // IO variant is selected: there is no browser, so there is no location and
  // `isWeb()` is false.
  assert(!utils.isWeb());
  assert(utils.getBrowserLocation() == null);
  assert(utils.getIsolateName().isNotEmpty);

  // The desktop/mobile answer is a different kind of claim, and asserting it
  // against the host would be wrong: it follows from the target printed above.
  // Stating that as an assertion rather than only in a comment is what makes
  // the explanation checkable — if the predicates were ever rewired to read
  // the machine instead, this fails here rather than quietly making the
  // narration false. Note there is no `isDesktop() || isMobile()` to assert:
  // Fuchsia is in neither family, so that would hold only by luck of target.
  assert(
    utils.isMobile() ==
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS),
  );
}

void main() => run();

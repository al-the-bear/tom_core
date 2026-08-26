/// Executable example for the runtime module of `tom_core_flutter`.
///
/// Demonstrates obtaining the platform-appropriate `TomPlatformUtils` for the
/// current target, querying its platform predicates, and taking an HTTP client
/// from it. The concrete variant is chosen at compile time (native IO / web /
/// neutral).
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
  // Example 1: obtain the platform utilities for the current target.
  final utils = clientPlatformUtils;
  print('platform utils: $utils');

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
  print('isWeb=${utils.isWeb()} '
      'isDesktop=${utils.isDesktop()} '
      'isMobile=${utils.isMobile()}');
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

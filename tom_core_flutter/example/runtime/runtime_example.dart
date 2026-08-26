/// Executable example for the runtime module of `tom_core_flutter`.
///
/// Demonstrates obtaining the platform-appropriate `TomPlatformUtils` for the
/// current target and querying its platform predicates. The concrete variant is
/// chosen at compile time (native IO / web / neutral).
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so this
/// runs under the Flutter toolchain, not bare `dart run`. Run it with
/// `flutter test test/runtime_test.dart`: that suite calls [run], so the
/// command executes everything below and its exit code says whether the
/// assertions held. Pointing `flutter test` at *this* file also runs it, but
/// then exits 79 ("No tests were found") whether it succeeded or not — an
/// example declares no `test()` of its own.
library;

import 'package:tom_core_flutter/tom_core_flutter.dart';

void run() {
  // Example 1: obtain the platform utilities for the current target.
  final utils = clientPlatformUtils;
  print('platform utils: $utils');

  // Example 2: register them process-wide (as an app would at startup).
  TomPlatformUtils.setCurrentPlatform(utils);

  // Example 3: query platform predicates.
  print('isWeb=${utils.isWeb()} '
      'isDesktop=${utils.isDesktop()} '
      'isMobile=${utils.isMobile()}');
  print('isolate=${utils.getIsolateName()}');

  // Example 4: the browser location is web-only; on native it is null. The
  // variant's toString names which implementation was selected.
  print('browserLocation=${utils.getBrowserLocation()}');
  print('variant=$utils');

  // Assertions — running under the VM (native IO branch): not web, and exactly
  // one of desktop/mobile families applies.
  assert(!utils.isWeb());
  assert(utils.isDesktop() || utils.isMobile());
  assert(utils.getIsolateName().isNotEmpty);
  assert(utils.getBrowserLocation() == null);
}

void main() => run();

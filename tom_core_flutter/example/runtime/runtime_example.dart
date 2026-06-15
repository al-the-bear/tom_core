/// Executable example for the runtime module of `tom_core_flutter`.
///
/// Demonstrates obtaining the platform-appropriate `TomPlatformUtils` for the
/// current target and querying its platform predicates. The concrete variant is
/// chosen at compile time (native IO / web / neutral).
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so run
/// this under the Flutter toolchain, e.g.
/// `flutter test example/runtime/runtime_example.dart`, not bare `dart run`.
/// The same behaviour is covered by `test/runtime_test.dart`.
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

  // Assertions — running under the VM (native IO branch): not web, and exactly
  // one of desktop/mobile families applies.
  assert(!utils.isWeb());
  assert(utils.isDesktop() || utils.isMobile());
  assert(utils.getIsolateName().isNotEmpty);
}

void main() => run();

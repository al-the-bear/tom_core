/// Executable example for the little_things module of `tom_core_flutter`.
///
/// Demonstrates the two client exception types and the type-based
/// discrimination pattern UI layers rely on. The barrel import pulls in
/// `flutter/material` (and thus `dart:ui`), so run this under the Flutter
/// toolchain, e.g. `flutter test example/little_things/little_things_example.dart`,
/// not bare `dart run`. The same behaviour is covered by
/// `test/little_things_test.dart`.
library;

import 'package:tom_core_flutter/tom_core_flutter.dart';

void run() {
  // Example 1: a user-facing error carries a presentable message.
  final uiError = TomClientUIException('login.failed', 'Could not sign you in.');
  print('ui error: ${uiError.key} -> ${uiError.defaultUserMessage}');

  // Example 2: an internal client error that should not be shown verbatim.
  final internal = TomClientException('cache.miss', 'No cached profile');
  print('internal: ${internal.key} -> ${internal.defaultUserMessage}');

  // Example 3: surface presentable errors, wrap the rest.
  TomClientUIException surface(TomException e) {
    if (e is TomClientUIException) return e;
    return TomClientUIException('app.error', 'Unexpected error', rootException: e);
  }

  final surfacedUi = surface(uiError);
  final surfacedInternal = surface(internal);
  print('surfaced ui identical: ${identical(surfacedUi, uiError)}');
  print('surfaced internal wraps root: ${surfacedInternal.rootException == internal}');

  // Assertions
  assert(internal is! TomClientUIException);
  assert(identical(surfacedUi, uiError));
  assert(surfacedInternal.rootException == internal);
}

void main() => run();

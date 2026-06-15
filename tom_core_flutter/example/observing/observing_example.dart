/// Executable example for the observing module of `tom_core_flutter`.
///
/// Demonstrates how `ValueListenableObserver` bridges a kernel `TomObservable`
/// to a Flutter listener, and how observable mutation (`|`) propagates a
/// notification. `TomObservingWidget` is exercised in the widget tests
/// (`test/observing_test.dart`) because it needs a `WidgetTester` pump loop.
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so run
/// this under the Flutter toolchain, e.g.
/// `flutter test example/observing/observing_example.dart`, not bare
/// `dart run`. The same behaviour is covered by `test/observing_test.dart`.
library;

import 'package:tom_core_flutter/tom_core_flutter.dart';

void run() {
  // Example 1: adapt a TomObservable to Flutter's ValueListenable contract.
  final flag = TomBool(false);
  final adaptor = ValueListenableObserver<TomBool>(flag);

  // `value` returns the observed observable itself; read it with `~`.
  print('initial value: ${~adaptor.value}');

  // Example 2: register a listener and observe notifications on mutation.
  var notifications = 0;
  adaptor.addListener(() => notifications++);

  flag | true; // mutate → onNotify → listener fires
  print('after first mutation: notifications=$notifications value=${~flag}');

  flag | false;
  print('after second mutation: notifications=$notifications');

  // Example 3: removeListener stops further notifications.
  adaptor.removeListener(() {});
  flag | true;
  print('after removeListener: notifications=$notifications (unchanged)');

  // Assertions
  assert(identical(adaptor.value, flag));
  assert(notifications == 2);
}

void main() => run();

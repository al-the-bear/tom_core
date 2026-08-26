/// Executable example for the observing module of `tom_core_flutter`.
///
/// Demonstrates how `ValueListenableObserver` bridges a kernel `TomObservable`
/// to a Flutter listener, and how observable mutation (`|`) propagates a
/// notification. `TomObservingWidget` is exercised in the widget tests
/// (`test/observing_test.dart`) because it needs a `WidgetTester` pump loop.
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so this
/// runs under the Flutter toolchain, not bare `dart run`. Run it with
/// `flutter test test/observing_test.dart`: that suite calls [run], so the
/// command executes everything below and its exit code says whether the
/// assertions held. Pointing `flutter test` at *this* file also runs it, but
/// then exits 79 ("No tests were found") whether it succeeded or not — an
/// example declares no `test()` of its own.
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

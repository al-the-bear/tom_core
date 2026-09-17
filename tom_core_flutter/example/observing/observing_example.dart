/// Executable example for the observing module of `tom_core_flutter`.
///
/// Demonstrates how `ValueListenableObserver` bridges a kernel `TomObservable`
/// to a Flutter listener, how observable mutation (`|`) propagates a
/// notification, and both ways the adaptor's single listener slot departs from
/// the `ValueListenable` contract — `removeListener` ignoring its argument and
/// `addListener` replacing rather than appending, and the teardown that
/// distinguishes `dispose` from `removeListener`. `TomObservingWidget` is
/// exercised in the widget tests (`test/observing_test.dart`) because it needs
/// a `WidgetTester` pump loop.
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

  // Example 3: removeListener stops further notifications — and ignores its
  // argument while doing it. The closure below was never registered; there is
  // one listener slot rather than a list, so there is nothing to match the
  // argument against and any argument clears it. Passing the original listener
  // would do exactly the same thing.
  adaptor.removeListener(() {});
  flag | true;
  print('after removeListener: notifications=$notifications (unchanged)');

  // Example 4: the other end of the same single-slot design — addListener
  // replaces rather than appends, so a second registration silently discards
  // the first. Two ValueListenableBuilders over one adaptor lose one of them.
  final second = ValueListenableObserver<TomBool>(flag);
  var first = 0;
  var latest = 0;
  second.addListener(() => first++);
  second.addListener(() => latest++);

  flag | false;
  print('after replacing the listener: first=$first latest=$latest');

  // Example 5: ending the subscription. Construction is the subscription, so
  // `dispose` is what ends it — and `removeListener` in Example 3 did not. The
  // adaptor silenced there is still on the observable's observer list, so
  // giving it a listener again resumes forwarding.
  //
  // `second` is finished with, so it is disposed first, and that is itself the
  // point: every adaptor here is subscribed to the same `flag`, and one that is
  // never disposed keeps running on every mutation made long after the code
  // that created it has moved on.
  second.dispose();

  adaptor.addListener(() => notifications++);
  flag | true;
  print('after re-arming the silenced adaptor: notifications=$notifications');

  // Disposing is not reversible. The adaptor comes off the observer list, so
  // nothing reaches it again — and `addListener` on it would now fail an
  // assert rather than leave a caller waiting for notifications that cannot
  // arrive. That is why this line is the last thing done with `adaptor`.
  adaptor.dispose();
  flag | false;
  print('after dispose: notifications=$notifications (unchanged)');

  // An adaptor held beyond one build — in a `State` field — must be disposed
  // in that `State`'s `dispose`, the same way `TomObservingWidget` deregisters
  // itself. Disposing twice is harmless.
  second.dispose();

  // Assertions
  assert(identical(adaptor.value, flag));
  assert(first == 0); // replaced before it ever fired
  assert(latest == 1);
  assert(
    notifications == 3,
    'two before removeListener, one after re-arming, none after dispose',
  );
}

void main() => run();

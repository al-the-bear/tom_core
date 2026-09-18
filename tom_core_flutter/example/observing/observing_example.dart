/// Executable example for the observing module of `tom_core_flutter`.
///
/// Demonstrates how `ValueListenableObserver` bridges a kernel `TomObservable`
/// to a Flutter listener, how observable mutation (`|`) propagates a
/// notification, that the adaptor is a real multicast `Listenable` —
/// `addListener` appends and `removeListener` takes the listener it is given —
/// and the teardown that distinguishes `dispose` from `removeListener`.
/// `TomObservingWidget` is
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
  void counter() => notifications++;
  adaptor.addListener(counter);

  flag | true; // mutate → onNotify → listener fires
  print('after first mutation: notifications=$notifications value=${~flag}');

  flag | false;
  print('after second mutation: notifications=$notifications');

  // Example 3: removeListener takes the listener it is given, and only that
  // one. A closure that was never registered removes nothing — it does not
  // silence the adaptor, which is what a consumer removing its own listener
  // would otherwise do to every other consumer.
  adaptor.removeListener(() {}); // never registered: no effect
  flag | true;
  print(
    'after removing an unregistered closure: '
    'notifications=$notifications (still counting)',
  );

  adaptor.removeListener(counter);
  flag | false;
  print(
    'after removing the registered one: '
    'notifications=$notifications (unchanged)',
  );

  // Example 4: one adaptor, several listeners. `addListener` appends, so every
  // consumer of the adaptor is notified — two ValueListenableBuilders over one
  // adaptor both rebuild, which is what the `Listenable` contract promises and
  // what any Flutter API handed this type assumes.
  final second = ValueListenableObserver<TomBool>(flag);
  var first = 0;
  var latest = 0;
  second.addListener(() => first++);
  second.addListener(() => latest++);

  // `flag` is currently false, so this is a real change — a `TomObservable`
  // notifies on change, not on assignment.
  flag | true;
  print('after two registrations: first=$first latest=$latest');

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

  adaptor.addListener(counter);
  flag | false;
  print('after re-arming the silenced adaptor: notifications=$notifications');

  // Disposing is not reversible. The adaptor comes off the observer list, so
  // nothing reaches it again — and `addListener` on it would now fail an
  // assert rather than leave a caller waiting for notifications that cannot
  // arrive. That is why this line is the last thing done with `adaptor`.
  adaptor.dispose();
  flag | true;
  print('after dispose: notifications=$notifications (unchanged)');

  // An adaptor held beyond one build — in a `State` field — must be disposed
  // in that `State`'s `dispose`, the same way `TomObservingWidget` deregisters
  // itself. Disposing twice is harmless.
  second.dispose();

  // Assertions
  assert(identical(adaptor.value, flag));
  assert(first == 1, 'addListener appends rather than replacing');
  assert(latest == 1);
  assert(
    notifications == 4,
    'two while registered, one more after an unregistered closure was '
    'removed, one after re-arming — and none after dispose',
  );
}

void main() => run();

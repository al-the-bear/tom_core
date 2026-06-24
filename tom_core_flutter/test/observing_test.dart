import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

/// Tests for the observing module (`TomObservingWidget`,
/// `ValueListenableObserver`).
///
/// Both adapt the kernel observation model: a `TomObservable` is read with `~`
/// and mutated with `|`, and notifies its observers on change.
void main() {
  group('TomObservingWidget', () {
    testWidgets('renders from the initial observable value', (tester) async {
      final flag = TomBool(false);
      await tester.pumpWidget(
        MaterialApp(
          home: TomObservingWidget<TomBool>(
            subState: flag,
            child: (state) => Text(~state ? 'ON' : 'OFF',
                textDirection: TextDirection.ltr),
          ),
        ),
      );
      expect(find.text('OFF'), findsOneWidget);
      expect(find.text('ON'), findsNothing);
    });

    testWidgets('rebuilds when the observable notifies', (tester) async {
      final flag = TomBool(false);
      await tester.pumpWidget(
        MaterialApp(
          home: TomObservingWidget<TomBool>(
            subState: flag,
            child: (state) => Text(~state ? 'ON' : 'OFF',
                textDirection: TextDirection.ltr),
          ),
        ),
      );
      expect(find.text('OFF'), findsOneWidget);

      flag | true; // mutate the observable → triggers onNotify → setState
      await tester.pump();

      expect(find.text('ON'), findsOneWidget);
      expect(find.text('OFF'), findsNothing);
    });

    // tests §8(a) — disposal: once the widget leaves the tree it must
    // deregister, so a later mutation neither calls setState on a dead State
    // ("setState() called after dispose()") nor keeps the State alive. There
    // is no public observer-count getter on TomObservable, so the still-
    // registered dead observer surfaces only as the framework throw on the
    // post-unmount notification — asserting no exception is the deregistration
    // check. RED against the current (no-dispose) implementation.
    testWidgets('deregisters on unmount — no setState after dispose',
        (tester) async {
      final flag = TomBool(false);
      await tester.pumpWidget(
        MaterialApp(
          home: TomObservingWidget<TomBool>(
            subState: flag,
            child: (state) => Text(~state ? 'ON' : 'OFF',
                textDirection: TextDirection.ltr),
          ),
        ),
      );
      expect(find.text('OFF'), findsOneWidget);

      // Remove the observing widget from the tree → State.dispose() runs.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Mutating the (now unobserved) observable must not reach the disposed
      // State. A surviving registration would throw "setState() called after
      // dispose()" on this notification.
      flag | true;
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    // tests §8(b) — observable swap: a parent rebuild with a different
    // subState must make the widget observe and render from the NEW observable
    // and ignore the OLD one. RED against the current implementation, which
    // seeds its observer/`subState` once in the constructor and never migrates
    // on didUpdateWidget.
    testWidgets('swaps to a new subState — observes/renders new, ignores old',
        (tester) async {
      final first = TomBool(false);
      final second = TomBool(false);
      var current = first;
      late void Function(void Function()) rebuildParent;
      var builds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return TomObservingWidget<TomBool>(
                subState: current,
                child: (state) {
                  builds++;
                  return Text(~state ? 'ON' : 'OFF',
                      textDirection: TextDirection.ltr);
                },
              );
            },
          ),
        ),
      );
      expect(find.text('OFF'), findsOneWidget);

      // Swap the parent to observe `second` (still false).
      rebuildParent(() => current = second);
      await tester.pump();

      // It now renders from `second`.
      second | true;
      await tester.pump();
      expect(find.text('ON'), findsOneWidget);

      // The OLD observable must be ignored: mutating it triggers no rebuild.
      final buildsBefore = builds;
      first | true;
      await tester.pump();
      expect(builds, buildsBefore);
      expect(find.text('ON'), findsOneWidget);
    });
  });

  group('ValueListenableObserver', () {
    test('value returns the observed observable', () {
      final source = TomBool(true);
      final adaptor = ValueListenableObserver<TomBool>(source);
      expect(identical(adaptor.value, source), isTrue);
    });

    test('invokes the registered listener once per notification', () {
      final source = TomBool(false);
      final adaptor = ValueListenableObserver<TomBool>(source);

      var calls = 0;
      adaptor.addListener(() => calls++);

      source | true;
      expect(calls, 1);

      source | false;
      expect(calls, 2);
    });

    test('stops notifying after removeListener', () {
      final source = TomBool(false);
      final adaptor = ValueListenableObserver<TomBool>(source);

      var calls = 0;
      void listener() => calls++;
      adaptor.addListener(listener);
      source | true;
      expect(calls, 1);

      adaptor.removeListener(listener);
      source | false;
      expect(calls, 1); // unchanged
    });

    test('addListener replaces the previous listener (single-listener)', () {
      final source = TomBool(false);
      final adaptor = ValueListenableObserver<TomBool>(source);

      var first = 0;
      var second = 0;
      adaptor.addListener(() => first++);
      adaptor.addListener(() => second++);

      source | true;
      expect(first, 0); // replaced, never called
      expect(second, 1);
    });
  });

  testWidgets('ValueListenableObserver drives a ValueListenableBuilder',
      (tester) async {
    final source = TomBool(false);
    final adaptor = ValueListenableObserver<TomBool>(source);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<TomBool>(
          valueListenable: adaptor,
          builder: (context, value, _) => Text(~value ? 'ON' : 'OFF',
              textDirection: TextDirection.ltr),
        ),
      ),
    );
    expect(find.text('OFF'), findsOneWidget);

    source | true;
    await tester.pump();
    expect(find.text('ON'), findsOneWidget);
  });
}

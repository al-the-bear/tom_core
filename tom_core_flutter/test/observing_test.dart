import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import '../example/observing/observing_example.dart' as example;

/// A [TomObserver] that does nothing but count, so a test can hold one
/// deliberately and ask how many notifications reached it.
class _CountingObserver implements TomObserver<TomBool> {
  int calls = 0;

  @override
  void onNotify(TomBool observable) => calls++;
}

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
    // deregister, so a later mutation does not call setState on a dead State
    // ("setState() called after dispose()"). That is the whole benefit, and it
    // is a benefit about *timing*: TomObservable holds observers weakly, so a
    // surviving registration would not have kept the State alive either way —
    // it would just have gone on notifying a disposed element until the
    // collector happened to run. There is no public observer-count getter on
    // TomObservable, so the still-registered dead observer surfaces only as the
    // framework throw on the post-unmount notification — asserting no exception
    // is the deregistration check. RED against the current (no-dispose)
    // implementation.
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

  group('observer lifetime', () {
    // The documented corollary of the weak-observer contract, and the half of
    // it that is easy to get backwards: collection is not a substitute for
    // removal. Nothing here depends on the garbage collector — the observer is
    // held by a local for the whole test — which is the point. What ends the
    // notifications is `removeObserver`, and that is deterministic.
    test('an observer that is still held keeps firing until it is removed', () {
      final flag = TomBool(false);
      final observer = _CountingObserver();
      flag.addObserver(observer);

      flag | true;
      expect(observer.calls, 1);

      flag | false;
      expect(observer.calls, 2);

      flag.removeObserver(observer);

      flag | true;
      expect(observer.calls, 2, reason: 'removal is what stops notifications');
    });

    testWidgets('the widget holds its observable, not the other way round',
        (tester) async {
      // The strong reference runs widget → observable, through the plain
      // `final T subState` field. Reading it back off the mounted widget is
      // the observable part of "the widget keeps the observable alive": the
      // element has a live, strong handle on the very instance the caller
      // passed, so nothing can collect it while the widget is in the tree.
      final flag = TomBool(false);
      await tester.pumpWidget(
        MaterialApp(
          home: TomObservingWidget<TomBool>(
            subState: flag,
            child: (state) =>
                Text(~state ? 'ON' : 'OFF', textDirection: TextDirection.ltr),
          ),
        ),
      );

      final mounted = tester.widget<TomObservingWidget<TomBool>>(
        find.byType(TomObservingWidget<TomBool>),
      );
      expect(identical(mounted.subState, flag), isTrue);
    });
  });

  group('the weak-reference contract is documented consistently', () {
    // tcinc661 — `doc/observing.md` used to close its lifecycle section with
    // "a long-lived observable that outlives the widget is therefore not
    // retained", which inverts the contract in both directions it could be
    // read: the observable holds observers *weakly* (so deregistration is not
    // what releases the `State`), and the widget holds the observable
    // *strongly* (so deregistration does nothing about that reference either).
    // The claim had been copied into the widget's dartdoc and the API summary,
    // which is why the guard checks every file that discusses the lifecycle
    // rather than only the one the finding named.

    /// Every file in this module that tells a reader what `dispose` does.
    const lifecycleFiles = <String>[
      'doc/observing.md',
      'doc/api_reference/api_summary_observing.md',
      'lib/src/tomclient/observing/tom_observing_widget.dart',
    ];

    final deregisters = RegExp(r'deregister|removeObserver', caseSensitive: false);

    test('every documented file exists and describes the deregistration', () {
      // Without this the two tests below are satisfiable by deleting the
      // prose they check: a file that says nothing about `dispose` states
      // nothing wrong about it either.
      for (final path in lifecycleFiles) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path is missing');
        final text = file.readAsStringSync();
        expect(text, contains('dispose'), reason: '$path never mentions dispose');
        expect(deregisters.hasMatch(text), isTrue,
            reason: '$path no longer says that dispose deregisters');
      }
    });

    test('each one says which side holds which', () {
      // Saying "dispose deregisters" without saying which way the references
      // point is how the inversion got in: a reader supplies the missing
      // direction themselves, and supplies it wrongly.
      final offenders = <String>[
        for (final path in lifecycleFiles)
          ...() {
            final text = File(path).readAsStringSync().toLowerCase();
            return <String>[
              if (!text.contains('weak'))
                '$path describes the deregistration without saying the '
                    'observers are held weakly',
              if (!text.contains('strong'))
                '$path describes the deregistration without saying the widget '
                    'holds subState strongly',
            ];
          }(),
      ];
      expect(offenders, isEmpty);
    });

    test('the retired claim has not come back', () {
      final retired = RegExp(r'not retained|neither leaks', caseSensitive: false);
      final offenders = <String>[
        for (final path in lifecycleFiles)
          if (retired.hasMatch(File(path).readAsStringSync()))
            '$path claims again that deregistration prevents retention',
      ];
      expect(offenders, isEmpty);
    });
  });

  group('the shipped example runs', () {
    test('observing_example.run() completes its assertions', () {
      // The example is quoted as documentation, so it has to be executable
      // documentation. Running it here is what stops a snippet that no longer
      // compiles — or an assert that no longer holds — from being shown to a
      // reader as the way to use the module. It is also what makes the command
      // the example's header names a real one: that command is this suite.
      example.run();
    });
  });
}

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

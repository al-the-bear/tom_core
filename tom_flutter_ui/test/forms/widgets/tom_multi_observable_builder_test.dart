import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/src/forms/widgets/tom_multi_observable_builder.dart';

// §60(c): starter coverage for TomMultiObservableBuilder — verifies it rebuilds
// when any watched observable changes and that it cleanly (de)registers
// listeners across construction, list changes, and disposal.

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('TomMultiObservableBuilder', () {
    testWidgets('rebuilds when any observed value changes', (tester) async {
      final a = TomObject<int>(1);
      final b = TomObject<int>(10);
      var buildCount = 0;

      await tester.pumpWidget(_wrap(TomMultiObservableBuilder(
        observables: [a, b],
        builder: (context) {
          buildCount++;
          return Text('${a.get()}+${b.get()}');
        },
      )));

      expect(find.text('1+10'), findsOneWidget);
      final initialBuilds = buildCount;

      a.set(2);
      await tester.pump();
      expect(find.text('2+10'), findsOneWidget);

      b.set(20);
      await tester.pump();
      expect(find.text('2+20'), findsOneWidget);

      expect(buildCount, greaterThan(initialBuilds));
    });

    testWidgets('does not rebuild for an unchanged set() (no notify)',
        (tester) async {
      final a = TomObject<int>(1);
      var buildCount = 0;

      await tester.pumpWidget(_wrap(TomMultiObservableBuilder(
        observables: [a],
        builder: (context) {
          buildCount++;
          return Text('${a.get()}');
        },
      )));

      final builds = buildCount;
      a.set(1); // same value → TomObject does not notify
      await tester.pump();
      expect(buildCount, builds);
    });

    testWidgets('deregisters listeners on dispose', (tester) async {
      final a = TomObject<int>(0);

      await tester.pumpWidget(_wrap(TomMultiObservableBuilder(
        observables: [a],
        builder: (context) => Text('${a.get()}'),
      )));

      // Replacing the widget disposes the builder; a later notify must not
      // throw (the listener was removed).
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(() => a.set(99), returnsNormally);
    });

    testWidgets('re-subscribes when the observable list changes',
        (tester) async {
      final a = TomObject<int>(1);
      final b = TomObject<int>(2);

      late StateSetter setOuter;
      var watchB = false;

      await tester.pumpWidget(_wrap(StatefulBuilder(
        builder: (context, setState) {
          setOuter = setState;
          return TomMultiObservableBuilder(
            observables: watchB ? [b] : [a],
            builder: (context) => Text(watchB ? 'b=${b.get()}' : 'a=${a.get()}'),
          );
        },
      )));

      expect(find.text('a=1'), findsOneWidget);

      // Switch the watched observable from a → b.
      setOuter(() => watchB = true);
      await tester.pump();
      expect(find.text('b=2'), findsOneWidget);

      // Now b drives rebuilds…
      b.set(3);
      await tester.pump();
      expect(find.text('b=3'), findsOneWidget);

      // …and a (deregistered) no longer does.
      a.set(100);
      await tester.pump();
      expect(find.text('b=3'), findsOneWidget);
    });
  });
}

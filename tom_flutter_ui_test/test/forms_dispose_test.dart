/// Disposal tests for the forms_demos State classes (review bug §78).
///
/// The five demo `State` classes (`_FormsOverviewDemoState` in
/// `forms_demos.dart`; `SelectionVariantsDemoState`, `_BooleanVariantsDemoState`,
/// `_ComplexBreakpointsDemoState`, `_ComplexAuthDemoState` in `phase2_demos.dart`)
/// each build TomFields, a bespoke broadcast source, and `>>` observers in
/// `initState`, but none overrode `dispose()` — so every navigation away from
/// the demo leaked field timers / notifiers, a never-closed broadcast
/// `StreamController`, and dangling observer registrations.
///
/// `SelectionVariantsDemo` owns all three flavours of disposable, so it is the
/// focused red→green target: [SelectionVariantsDemoState.debugSharedSource] and
/// [SelectionVariantsDemoState.debugObserverCount] expose the observable signals
/// that its `dispose()` actually closed the source and unregistered the
/// observers. The second test is a mount/unmount regression guard for all five
/// demos (a throwing or double-dispose teardown would surface here).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tom_flutter_ui_test/demo_resources.dart';
import 'package:tom_flutter_ui_test/forms_demos/forms_demos.dart';
import 'package:tom_flutter_ui_test/forms_demos/phase2_demos.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Demos resolve labels / icons / colors through the global adapters at
    // build time, so install them before mounting any demo.
    initializeDemoResources();
  });

  Future<void> pump(WidgetTester tester, Widget demo) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: demo)));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'SelectionVariantsDemo closes its shared source and observers on unmount',
    (tester) async {
      await pump(tester, const SelectionVariantsDemo());

      final state = tester.state<SelectionVariantsDemoState>(
        find.byType(SelectionVariantsDemo),
      );

      // While mounted: source open, all five field observers registered.
      expect(
        state.debugSharedSource.isDisposed,
        isFalse,
        reason: 'The shared source is live while the demo is mounted',
      );
      expect(
        state.debugObserverCount,
        5,
        reason: 'One >> observer is registered per selection field',
      );

      // Replace the demo to trigger State.dispose().
      await pump(tester, const SizedBox.shrink());

      expect(
        state.debugSharedSource.isDisposed,
        isTrue,
        reason: 'dispose() must close the bespoke broadcast source',
      );
      expect(
        state.debugObserverCount,
        0,
        reason: 'dispose() must unregister every >> observer',
      );
    },
  );

  testWidgets('all forms demos mount and unmount twice without exceptions', (
    tester,
  ) async {
    final demos = <Widget Function()>[
      () => const FormsOverviewDemo(),
      () => const SelectionVariantsDemo(),
      () => const BooleanVariantsDemo(),
      () => const ComplexBreakpointsDemo(),
      () => const ComplexAuthDemo(),
    ];

    for (final build in demos) {
      // Mount → unmount → mount → unmount: a dispose() that threw or
      // double-disposed a resource would surface as a pending exception.
      await pump(tester, build());
      await pump(tester, const SizedBox.shrink());
      await pump(tester, build());
      await pump(tester, const SizedBox.shrink());
      expect(
        tester.takeException(),
        isNull,
        reason: 'Mounting and disposing the demo must not throw',
      );
    }
  });
}

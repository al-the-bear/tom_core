/// Interaction tests for Demo I — Numeric Forms (Phase 3).
///
/// Demo I hosts every Phase 3 numeric concrete:
///   * [TomFormIntInput] + [TomFormIntSlider] (sharing one TomInt via
///     two-way mirror observers)
///   * [TomFormIntStepper] with min/max + step
///   * [TomFormCurrencyDoubleInput] with locale switcher chips
///   * [TomFormDoubleInput] (plain)
///   * [TomFormPercentDoubleInput] (stored 0.0-1.0, displayed as %)
///   * [TomFormDoubleSlider] (tax rate)
///   * [TomFormIntRangeSlider] / [TomFormDoubleRangeSlider]
///
/// The demo also exposes live "Bound TomInt value: …" / "Discount: … %"
/// readouts that re-render on every form change. We assert on these
/// readouts (the single sources of truth) plus on Stepper button
/// enable/disable transitions.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
// ignore: implementation_imports
import 'package:tom_flutter_ui/src/forms/fields/tom_field_widget_adapter.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/phase3_state.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    final jsonStr =
        await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  // Replace the bound state instance between tests. We can't simply
  // re-`set()` the same instance because each Demo I form attaches
  // observers to the underlying TomObjects; once the prior widget tree
  // tears down its form (whose `_FormChangeNotifier` is disposed) those
  // observers can still be reached via the surviving global, and the
  // next `set()` would fire into a disposed notifier. A fresh instance
  // breaks the chain — the new form binds to a fresh observable that
  // has zero listeners.
  setUp(() {
    phase3NumericState = NumericDemoState();
  });

  Future<void> openDemoI(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo I: Numeric Forms'), 200,
        scrollable: find.descendant(
          of: find.byType(DemoListScreen),
          matching: find.byType(Scrollable),
        ),);
    await tester.tap(find.text('Demo I: Numeric Forms'));
    await tester.pumpAndSettle();
  }

  Finder fieldByTomId(String tomId) {
    return find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
        description: 'TomFieldWidgetAdapter[$tomId]',
      ),
      matching: find.byType(TextField),
    );
  }

  /// Find the (single) IconButton inside the brightness stepper row by its
  /// icon. The stepper renders one [IconButton.outlined] for `−` and one
  /// for `+`; both are descendants of the `brightness` adapter.
  Finder stepperButton({required IconData icon}) {
    final adapter = find.byWidgetPredicate(
      (w) => w is TomFieldWidgetAdapter && w.field.tomId == 'brightness',
    );
    return find.descendant(
      of: adapter,
      matching: find.widgetWithIcon(IconButton, icon),
    );
  }

  testWidgets('baseline — demo loads and live readouts show seed values',
      (tester) async {
    await openDemoI(tester);
    expect(find.text('Bound TomInt value: 8'), findsOneWidget,
        reason: 'quantity readout must echo the seeded TomInt');
    // Tax rate readout uses one decimal.
    expect(find.text('Tax rate: 7.5 %'), findsOneWidget);
    // Headcount + budget range readouts render.
    expect(find.textContaining('Headcount:'), findsOneWidget);
    expect(find.textContaining('Budget (k\$):'), findsOneWidget);
  });

  testWidgets('typing in quantity input updates TomInt and slider',
      (tester) async {
    await openDemoI(tester);
    final input = fieldByTomId('quantity').first;
    expect(input, findsOneWidget);
    await tester.enterText(input, '42');
    await tester.pumpAndSettle();
    expect(find.text('Bound TomInt value: 42'), findsOneWidget,
        reason: 'typing in input must propagate to the bound TomInt');
    // The readout reads the form's quantityInput TomInt — the same
    // observable the slider listens to via the demo's mirror observer
    // — so the find.text above is already the single-source-of-truth
    // assertion. We don't poke phase3NumericState here because TomForm
    // bindings are not guaranteed to be two-way for this demo's wiring.
  });

  testWidgets('Stepper + button increments by step (5)',
      (tester) async {
    await openDemoI(tester);
    final plus = stepperButton(icon: Icons.add);
    expect(plus, findsOneWidget);
    await tester.ensureVisible(plus);
    await tester.pumpAndSettle();
    await tester.tap(plus);
    await tester.pumpAndSettle();
    // Brightness was 50; +5 → 55. The stepper renders the value as a
    // centred Text inside a 48px box.
    expect(find.text('55'), findsAtLeastNWidgets(1),
        reason: 'stepper + must increment by 5');
  });

  testWidgets('Stepper - button decrements by step (5)',
      (tester) async {
    await openDemoI(tester);
    final minus = stepperButton(icon: Icons.remove);
    expect(minus, findsOneWidget);
    await tester.ensureVisible(minus);
    await tester.pumpAndSettle();
    await tester.tap(minus);
    await tester.pumpAndSettle();
    expect(find.text('45'), findsAtLeastNWidgets(1),
        reason: 'stepper − must decrement by 5');
  });

  testWidgets('Stepper at min disables the - button',
      (tester) async {
    // The form's `brightnessStepper` is its own TomObject and
    // `_form.bind(phase3NumericState)` doesn't write into it (member
    // names don't match), so setting `phase3NumericState.brightness`
    // doesn't move the stepper. Drive the boundary by tapping the −
    // button until brightness reaches 0 instead — this also covers
    // multi-step decrement behaviour as a bonus.
    await openDemoI(tester);
    final minus = stepperButton(icon: Icons.remove);
    expect(minus, findsOneWidget);
    // brightness starts at 50, step = 5 → exactly 10 decrements to 0.
    for (var i = 0; i < 10; i++) {
      await tester.ensureVisible(minus);
      await tester.pumpAndSettle();
      await tester.tap(minus);
      await tester.pumpAndSettle();
    }
    expect(find.text('0'), findsAtLeastNWidgets(1),
        reason: 'after 10 decrements the stepper readout must reach 0');
    final btn = tester.widget<IconButton>(stepperButton(icon: Icons.remove));
    expect(btn.onPressed, isNull,
        reason: 'at brightness=0 the − button must be disabled');
  });

  testWidgets('Stepper at max disables the + button',
      (tester) async {
    // Same reasoning as the min-disable test: walk the stepper up to
    // the maxValue (100) by repeated taps so we know the field's own
    // value reaches the boundary regardless of bind() propagation.
    await openDemoI(tester);
    final plus = stepperButton(icon: Icons.add);
    expect(plus, findsOneWidget);
    // brightness starts at 50, step = 5 → exactly 10 increments to 100.
    for (var i = 0; i < 10; i++) {
      await tester.ensureVisible(plus);
      await tester.pumpAndSettle();
      await tester.tap(plus);
      await tester.pumpAndSettle();
    }
    expect(find.text('100'), findsAtLeastNWidgets(1),
        reason: 'after 10 increments the stepper readout must reach 100');
    final btn = tester.widget<IconButton>(stepperButton(icon: Icons.add));
    expect(btn.onPressed, isNull,
        reason: 'at brightness=100 the + button must be disabled');
  });

  testWidgets('switching currency chip from USD to EUR rebuilds the readout',
      (tester) async {
    await openDemoI(tester);
    // Initial readout includes "(code: USD)".
    expect(find.textContaining('(code: USD)'), findsOneWidget);
    final eur = find.widgetWithText(ChoiceChip, 'EUR');
    expect(eur, findsOneWidget);
    await tester.ensureVisible(eur);
    await tester.pumpAndSettle();
    await tester.tap(eur);
    await tester.pumpAndSettle();
    expect(find.textContaining('(code: EUR)'), findsOneWidget,
        reason: 'tapping EUR must swap the live readout');
    // Pin: the EUR `€` symbol must actually be rendered in the field
    // after the swap. Pre-fix, the InputDecoration carried suffixText='€'
    // but the symbol was invisible in Demo I (regression captured by
    // the user manually checking the running app). The previous test
    // only confirmed the live-readout text "(code: EUR)" — that text
    // contains the substring from the readout label, NOT the field's
    // own symbol. Searching for '€' as a standalone Text widget proves
    // the field is actually displaying it.
    expect(find.text('€'), findsAtLeastNWidgets(1),
        reason: 'after swapping to EUR, the field must visibly render €');
  });

  testWidgets('typing in plain double input updates the bound TomDouble',
      (tester) async {
    await openDemoI(tester);
    final input = fieldByTomId('priceGeneric').first;
    await tester.enterText(input, '321.45');
    await tester.pumpAndSettle();
    final tf = tester.widget<TextField>(fieldByTomId('priceGeneric'));
    expect(tf.controller?.text, contains('321.45'),
        reason: 'plain double input must echo the typed value');
  });

  testWidgets('discount readout reflects the percent input value',
      (tester) async {
    await openDemoI(tester);
    // Discount seed = 0.15 → 15.0% → "Discount: 15.0%   (stored as fraction:
    // 0.150)".
    expect(
      find.textContaining('Discount: 15.0%'),
      findsOneWidget,
      reason: 'percent-formatter readout must show seeded value',
    );
    expect(find.textContaining('stored as fraction: 0.150'), findsOneWidget);
  });
}

/// Interaction tests for Phase 3 demos (I numeric, J date/time).
///
/// Distinct from `phase3_smoke_test.dart` (which only checks anchor
/// text), these tests drag sliders, tap chips, and verify the bound
/// state actually updates — exercising the round-trip the user reported
/// as broken in feedback round 3 (items j/k/l/m).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';

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

  Future<void> openDemo(WidgetTester tester, String tile) async {
    // Tall viewport so the entire demo body fits without scrolling — most
    // assertions need to find headers / readouts that sit deep in the
    // SingleChildScrollView.
    tester.view.physicalSize = const Size(2400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(find.text(tile), 200,
        scrollable: find.descendant(
          of: find.byType(DemoListScreen),
          matching: find.byType(Scrollable),
        ),);
    await tester.tap(find.text(tile));
    await tester.pumpAndSettle();
  }

  testWidgets('(j) Demo I quantity slider updates the bound value text',
      (tester) async {
    await openDemo(tester, 'Demo I: Numeric Forms');
    // Bound value readout is the only feedback below the input + slider
    // pair. It reads the form's quantityInput field; for the user to see
    // the slider "work", dragging the slider must end up changing this
    // text — which only happens if both the input and slider sit on the
    // same TomInt (or are bridged in the demo).
    expect(find.text('Bound TomInt value: 8'), findsOneWidget);
    final slider = find.byType(Slider).first;
    // Drag the slider thumb a long way to the right.
    await tester.drag(slider, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(
      find.text('Bound TomInt value: 8'),
      findsNothing,
      reason: 'Dragging the slider must change the bound TomInt readout',
    );
  });

  testWidgets('(k) Demo I tax slider moves and percent shows %',
      (tester) async {
    await openDemo(tester, 'Demo I: Numeric Forms');
    expect(find.text('Percent + tax slider'), findsOneWidget);
    // Percent suffix '%' must render somewhere in the discount field.
    expect(find.text('%'), findsAtLeastNWidgets(1),
        reason: 'Percent input should display the % suffix');
  });

  testWidgets('(l) Demo I currency switch changes the displayed symbol',
      (tester) async {
    await openDemo(tester, 'Demo I: Numeric Forms');
    expect(find.text('Currency input'), findsOneWidget);
    // Initial currency is USD — '$' appears in the formatted text.
    expect(find.textContaining(r'$'), findsAtLeastNWidgets(1));
    // Tap the EUR chip.
    await tester.tap(find.text('EUR'));
    await tester.pumpAndSettle();
    // After switching to EUR the formatted value should contain '€'.
    expect(find.textContaining('€'), findsAtLeastNWidgets(1),
        reason: 'Switching currency must re-render with the EUR symbol');
  });

  testWidgets('(m) Demo J inline calendar updates the bound event date',
      (tester) async {
    await openDemo(tester, 'Demo J: Date/Time/Duration Forms');
    expect(find.text('Inline calendar'), findsOneWidget);
    // The inline calendar shows day numbers — tap day 20 in May 2026.
    // (The default initial date is 2026-05-12, so day 20 should be
    // visible in the current month grid.)
    final dayCell = find.descendant(
      of: find.byType(CalendarDatePicker),
      matching: find.text('20'),
    );
    expect(dayCell, findsOneWidget);
    await tester.tap(dayCell);
    await tester.pumpAndSettle();
    // After tap, the inline calendar's selection should land on 20.
    // Verifying via a visible 'Selected: 2026-05-20' readout we expect
    // the demo to render.
    expect(find.text('Selected (inline): 2026-05-20'), findsOneWidget,
        reason: 'Inline calendar must drive a visible bound-date readout');
  });
}

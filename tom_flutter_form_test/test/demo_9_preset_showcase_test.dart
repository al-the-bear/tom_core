/// Interaction tests for Demo 9 — Preset Showcase (legacy demo).
///
/// Demo 9 lays out a 2x3 grid: rows = field types (string input, dropdown);
/// columns = the three TomFormStyle presets (material3, compact, bordered).
/// All cells share one [CompanyBasicInfoForm] instance, each cell wrapping
/// in its own [TomFormStyleScope].
///
/// A [Switch] toggles whether [TomFormStyle.withTheme] bakes the picked
/// theme into each preset; a `SegmentedButton<int>` picks one of four
/// distinct themes.
///
/// We assert that:
///   * baseline — three preset header texts and two field row labels
///     render; six TomFormStyleScopes exist (3 cols × 2 rows)
///   * the withTheme switch toggles between OFF and ON descriptions
///   * picking each theme updates the `SegmentedButton<int>` selection
///   * editing one TomFormStringInput cell propagates to the bound state
///     (single source of truth proves the shared form binding)
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';
// ignore: implementation_imports
import 'package:tom_flutter_ui/src/forms/fields/tom_field_widget_adapter.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/application_state.dart';

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

  setUp(() {
    demoState.companyProfile.name | 'Acme Corporation';
    demoState.companyProfile.industry | 'tech';
  });

  Future<void> openDemo9(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo 9: Preset Showcase'), 200);
    await tester.tap(find.text('Demo 9: Preset Showcase'));
    await tester.pumpAndSettle();
  }

  testWidgets('baseline — preset headers, row labels, and 6 style scopes',
      (tester) async {
    await openDemo9(tester);
    // Header columns.
    expect(find.text('material3'), findsAtLeastNWidgets(1));
    expect(find.text('compact'), findsAtLeastNWidgets(1));
    expect(find.text('bordered'), findsAtLeastNWidgets(1));
    // Row labels.
    expect(find.text('TomFormStringInput'), findsAtLeastNWidgets(1));
    expect(find.text('TomFormStringDropdown'), findsAtLeastNWidgets(1));
    // Three columns × two rows = six style scopes (one per cell).
    expect(find.byType(TomFormStyleScope), findsNWidgets(6),
        reason: 'each cell must own its own TomFormStyleScope');
    // Each row renders the same field 3× (one per preset column).
    expect(
      find.byWidgetPredicate(
        (w) => w is TomFieldWidgetAdapter && w.field.tomId == 'name',
      ),
      findsNWidgets(3),
      reason: 'name input renders once per preset column',
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is TomFieldWidgetAdapter && w.field.tomId == 'industry',
      ),
      findsNWidgets(3),
      reason: 'industry dropdown renders once per preset column',
    );
  });

  testWidgets('withTheme switch toggles between OFF and ON descriptions',
      (tester) async {
    await openDemo9(tester);
    // Default state: OFF. The description text starts with "withTheme is OFF".
    expect(find.textContaining('withTheme is OFF'), findsOneWidget);
    final sw = find.byType(Switch);
    expect(sw, findsOneWidget);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    // After tap: ON. Description starts with "withTheme(picked) is ON".
    expect(find.textContaining('withTheme(picked) is ON'), findsOneWidget,
        reason: 'flipping the switch must swap the description copy');
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(find.textContaining('withTheme is OFF'), findsOneWidget,
        reason: 'flipping the switch back must restore the OFF description');
  });

  testWidgets('picking the second local theme updates the segment selection',
      (tester) async {
    await openDemo9(tester);
    final segmented = find.byType(SegmentedButton<int>);
    expect(segmented, findsOneWidget);
    final initial = segmented.evaluate().first.widget as SegmentedButton<int>;
    expect(initial.selected, {0}, reason: 'starts at theme index 0');
    final tealLabel = find.descendant(
      of: segmented,
      matching: find.text('Teal / Mono / small'),
    );
    expect(tealLabel, findsOneWidget);
    await tester.ensureVisible(tealLabel);
    await tester.pumpAndSettle();
    await tester.tap(tealLabel);
    await tester.pumpAndSettle();
    final updated = (find.byType(SegmentedButton<int>).evaluate().first.widget
        as SegmentedButton<int>);
    expect(updated.selected, {1},
        reason: 'tapping the Teal segment must shift selection to index 1');
  });

  testWidgets('editing the name in one cell shows up in the others',
      (tester) async {
    await openDemo9(tester);
    // Find the three name TextFields (one per preset column).
    final nameInputs = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is TomFieldWidgetAdapter && w.field.tomId == 'name',
      ),
      matching: find.byType(TextField),
    );
    expect(nameInputs, findsNWidgets(3));
    // All three controllers should show the seeded value.
    for (final el in nameInputs.evaluate()) {
      final tf = el.widget as TextField;
      expect(tf.controller?.text, 'Acme Corporation');
    }
    // Edit the first cell.
    await tester.enterText(nameInputs.first, 'Globex Industries');
    await tester.pumpAndSettle();
    // All three cells must reflect the new value (single shared form).
    for (final el in nameInputs.evaluate()) {
      final tf = el.widget as TextField;
      expect(tf.controller?.text, 'Globex Industries',
          reason: 'editing one cell must propagate via the shared form');
    }
  });
}

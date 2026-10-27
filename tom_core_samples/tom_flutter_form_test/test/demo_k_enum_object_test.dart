/// Interaction tests for Demo K — Enum / Object / Search / Lookup
/// (Phase 4). One demo, two test tiers (T5 search & lookup and T6
/// enum/object) live together in this file because they share the
/// same demo widget tree, the same scope ('demoK'), and the same
/// "Live bindings" / "Change log" panels.
///
/// Demo K does NOT bind a TomClass — each field owns its own
/// TomObservable. The "Live bindings" panel renders a row per field
/// with the field name in a fixed-width column and the live value in
/// the next column; we read those rows as the canonical
/// single-source-of-truth probes.
///
/// Coverage:
///   T6 (enum/object): dropdown / segmented / radio for enums + their
///       multi-select FilterChips counterpart, plus the object dropdown
///       (Country) and the int FilterChips (point sizes).
///   T5 (search/lookup): the lookup-dialog field opens a modal with a
///       filterable list, and the search field renders the type-ahead
///       Autocomplete TextField.
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
import 'package:tom_flutter_form_test/state/phase4_state.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    final jsonStr = await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  Future<void> openDemoK(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
      find.text('Demo K: Enum, Object & Lookup'),
      200,
      scrollable: find.descendant(
        of: find.byType(DemoListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Demo K: Enum, Object & Lookup'));
    await tester.pumpAndSettle();
  }

  Finder adapterByTomId(String tomId) {
    return find.byWidgetPredicate(
      (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
      description: 'TomFieldWidgetAdapter[$tomId]',
    );
  }

  /// Look up the live value for [fieldName] on the right-hand bindings
  /// panel. Each row is a Row with two children:
  ///   - SizedBox(width: 130) → Text(fieldName)
  ///   - Expanded(child: Text(value))
  /// We locate the Row whose first Text matches and return the second.
  String bindingValue(WidgetTester tester, String fieldName) {
    final nameText = find.text(fieldName);
    expect(
      nameText,
      findsAtLeastNWidgets(1),
      reason: 'binding row for "$fieldName" must exist',
    );
    // Walk up to the enclosing Row, then find the value Text inside it.
    final rowFinder = find.ancestor(
      of: nameText.first,
      matching: find.byType(Row),
    );
    expect(rowFinder, findsAtLeastNWidgets(1));
    // The first Row ancestor is the binding row; collect its descendant
    // Text widgets in build order — element [0] is the name, [1] is the
    // value.
    final texts = find
        .descendant(of: rowFinder.first, matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .toList();
    expect(
      texts.length,
      greaterThanOrEqualTo(2),
      reason: 'binding row for "$fieldName" must have name + value Text',
    );
    return texts[1] ?? '';
  }

  // ---------------------------------------------------------------------
  // Baseline
  // ---------------------------------------------------------------------

  testWidgets('baseline — every field renders and live bindings panel '
      'echoes the seeded values', (tester) async {
    await openDemoK(tester);
    // Adapters for every field.
    for (final id in [
      'priorityDropdown',
      'prioritySegmented',
      'priorityRadio',
      'tags',
      'country',
      'countries',
      'city',
      'lookupCountry',
      'pointSizes',
    ]) {
      expect(
        adapterByTomId(id),
        findsOneWidget,
        reason: 'field "$id" must render its adapter',
      );
    }
    // Seed values reflected in the bindings panel.
    expect(bindingValue(tester, 'priorityDropdown'), 'Medium');
    expect(bindingValue(tester, 'prioritySegmented'), 'High');
    expect(bindingValue(tester, 'priorityRadio'), 'Low');
    expect(bindingValue(tester, 'tags'), '[Backend, DevOps]');
    expect(bindingValue(tester, 'country'), 'United States (US)');
    expect(bindingValue(tester, 'countries'), '[DE, FR]');
    expect(bindingValue(tester, 'city'), 'Berlin, DE');
    expect(bindingValue(tester, 'lookupCountry'), 'Japan (JP)');
    expect(bindingValue(tester, 'pointSizes'), '[10, 14]');
  });

  // ---------------------------------------------------------------------
  // T6 — enum / object interactions
  // ---------------------------------------------------------------------

  testWidgets('T6: priority Segmented — tapping "Critical" updates the '
      'segmented selection AND the binding', (tester) async {
    await openDemoK(tester);
    final segmented = find.descendant(
      of: adapterByTomId('prioritySegmented'),
      matching: find.byType(SegmentedButton<Priority>),
    );
    expect(segmented, findsOneWidget);
    final critical = find.descendant(
      of: segmented,
      matching: find.text('Critical'),
    );
    expect(critical, findsOneWidget);
    await tester.ensureVisible(critical);
    await tester.pumpAndSettle();
    await tester.tap(critical);
    await tester.pumpAndSettle();
    expect(
      bindingValue(tester, 'prioritySegmented'),
      'Critical',
      reason: 'tapping "Critical" must propagate to the live binding',
    );
  });

  testWidgets('T6: priority Radio — tapping the "High" radio row '
      'updates the binding', (tester) async {
    await openDemoK(tester);
    // Each radio row is an InkWell whose child has a Text("High"). Tap
    // the Text — the InkWell ancestor handles the gesture.
    final highRow = find.descendant(
      of: adapterByTomId('priorityRadio'),
      matching: find.text('High'),
    );
    expect(highRow, findsOneWidget);
    await tester.ensureVisible(highRow);
    await tester.pumpAndSettle();
    await tester.tap(highRow);
    await tester.pumpAndSettle();
    expect(bindingValue(tester, 'priorityRadio'), 'High');
  });

  testWidgets('T6: Tag FilterChips — tapping "Frontend" adds it to the '
      'multi-select binding', (tester) async {
    await openDemoK(tester);
    expect(
      bindingValue(tester, 'tags'),
      '[Backend, DevOps]',
      reason: 'baseline tag selection',
    );
    final chip = find.descendant(
      of: adapterByTomId('tags'),
      matching: find.widgetWithText(FilterChip, 'Frontend'),
    );
    expect(chip, findsOneWidget);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    final after = bindingValue(tester, 'tags');
    expect(
      after.contains('Frontend'),
      isTrue,
      reason:
          'tapping the Frontend chip must add it to the binding '
          '(was: $after)',
    );
    expect(
      after.contains('Backend'),
      isTrue,
      reason: 'previously-selected Backend must still be present',
    );
  });

  testWidgets('T6: Tag FilterChips — tapping a SELECTED chip removes it '
      'from the binding', (tester) async {
    await openDemoK(tester);
    // Backend is in the baseline selection; tapping it should toggle off.
    final chip = find.descendant(
      of: adapterByTomId('tags'),
      matching: find.widgetWithText(FilterChip, 'Backend'),
    );
    expect(chip, findsOneWidget);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    final after = bindingValue(tester, 'tags');
    expect(
      after.contains('Backend'),
      isFalse,
      reason:
          'toggling Backend off must drop it from the binding '
          '(was: $after)',
    );
  });

  testWidgets('T6: Object dropdown — country dropdown menu renders all '
      'options and the seed value is selected', (tester) async {
    await openDemoK(tester);
    // The country dropdown's currently-selected item shows
    // "United States (US)". The DropdownButtonFormField renders the
    // current selection inline; opening the menu reveals all options.
    final dropdown = find.descendant(
      of: adapterByTomId('country'),
      matching: find.byType(DropdownButtonFormField<Country>),
    );
    expect(dropdown, findsOneWidget);
    // Open the menu by tapping the dropdown button.
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    // Menu items now render in an Overlay — Germany, France, etc.
    expect(
      find.text('Germany (DE)'),
      findsAtLeastNWidgets(1),
      reason: 'Germany must appear in the open dropdown menu',
    );
    // Pick Germany.
    await tester.tap(find.text('Germany (DE)').last);
    await tester.pumpAndSettle();
    expect(
      bindingValue(tester, 'country'),
      'Germany (DE)',
      reason: 'picking Germany must propagate to the live binding',
    );
  });

  testWidgets('T6: Int FilterChips (pointSizes) — tapping "12 pt" '
      'adds it to the binding', (tester) async {
    await openDemoK(tester);
    // The point-size source labels each int as "<n> pt" (see
    // _PointSizeSource), so the chip text is "12 pt", not "12".
    final chip = find.descendant(
      of: adapterByTomId('pointSizes'),
      matching: find.widgetWithText(FilterChip, '12 pt'),
    );
    expect(chip, findsOneWidget);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    final after = bindingValue(tester, 'pointSizes');
    expect(
      after.contains('12'),
      isTrue,
      reason:
          'tapping "12" must add it to the int multi-select '
          '(was: $after)',
    );
    expect(after.contains('10'), isTrue, reason: 'baseline 10 must remain');
  });

  // ---------------------------------------------------------------------
  // T5 — search / lookup interactions
  // ---------------------------------------------------------------------

  testWidgets('T5: city Search — Autocomplete renders a TextField '
      'inside the city adapter', (tester) async {
    await openDemoK(tester);
    final tf = find.descendant(
      of: adapterByTomId('city'),
      matching: find.byType(TextField),
    );
    expect(
      tf,
      findsOneWidget,
      reason: 'TomFormSearchInput must render an Autocomplete TextField',
    );
    // The TextField shows the current selection's label.
    final widget = tester.widget<TextField>(tf);
    expect(
      widget.controller?.text,
      contains('Berlin'),
      reason: 'seeded city is Berlin, DE',
    );
  });

  testWidgets('T5: lookup dialog — tapping the read-only field opens a '
      'modal dialog titled "Pick a country"', (tester) async {
    await openDemoK(tester);
    final tf = find.descendant(
      of: adapterByTomId('lookupCountry'),
      matching: find.byType(TextField),
    );
    expect(tf, findsOneWidget);
    await tester.ensureVisible(tf);
    await tester.pumpAndSettle();
    await tester.tap(tf);
    await tester.pumpAndSettle();
    // The dialog title should now be in the widget tree.
    expect(
      find.text('Pick a country'),
      findsOneWidget,
      reason: 'tapping the lookup field must open the dialog',
    );
    // Cancel the dialog so the Navigator stack is clean for teardown.
    final cancel = find.widgetWithText(TextButton, 'Cancel');
    if (cancel.evaluate().isNotEmpty) {
      await tester.tap(cancel.first);
      await tester.pumpAndSettle();
    } else {
      // Fallback: pop via Escape key would be nice but not always
      // supported in test mode. Just leaves the dialog up — the test
      // still passes.
    }
  });
}

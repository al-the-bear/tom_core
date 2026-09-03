/// Interaction tests for Demo E — Selection Variants.
///
/// Demo E renders eight selection-style variants (FilterChips,
/// MultiCheckbox, Segmented, RadioGroup, ChoiceChips, three boolean
/// flavours) bound to one shared `TomSelectableSource`. The right-hand
/// "Live bindings" panel echoes each binding so the side-effect of a
/// tap is visible.
///
/// These tests drive each variant once and assert the binding row in the
/// inspector updates accordingly. They also flip the "Filtered source"
/// switch and verify that the smaller catalogue is reflected in the UI.
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
    final jsonStr = await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  Future<void> openDemoE(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
      find.text('Demo E: Selection Variants'),
      200,
      scrollable: find.descendant(
        of: find.byType(DemoListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Demo E: Selection Variants'));
    await tester.pumpAndSettle();
  }

  /// Find a widget of [W] with [label] inside the variant card whose
  /// title contains [variantTitle]. Used to disambiguate "Technology"
  /// (which appears in five variant cards).
  Finder inVariant<W extends Widget>(String variantTitle, String label) {
    final card = find.ancestor(
      of: find.textContaining(variantTitle),
      matching: find.byType(Card),
    );
    return find.descendant(
      of: card.first,
      matching: find.widgetWithText(W, label),
    );
  }

  /// Tap a chip / radio / checkbox inside the named variant card.
  Future<void> tapInVariant<W extends Widget>(
    WidgetTester tester,
    String variantTitle,
    String label,
  ) async {
    final finder = inVariant<W>(variantTitle, label);
    expect(
      finder,
      findsAtLeastNWidgets(1),
      reason: 'No $W with label "$label" inside "$variantTitle" card',
    );
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  // Note: a single binding value (e.g. 'retail') appears in BOTH the
  // bindings panel AND the change-log panel after a tap, so all
  // post-tap assertions use `findsAtLeastNWidgets(1)`.

  testWidgets('baseline — every variant card and binding row renders', (
    tester,
  ) async {
    await openDemoE(tester);
    expect(find.textContaining('TomFormStringFilterChips'), findsOneWidget);
    expect(find.textContaining('TomFormStringMultiCheckbox'), findsOneWidget);
    expect(find.textContaining('TomFormStringSegmented'), findsOneWidget);
    expect(find.textContaining('TomFormStringRadioGroup'), findsOneWidget);
    expect(find.textContaining('TomFormStringChoiceChips'), findsOneWidget);
    expect(find.textContaining('TomFormBoolCheckbox'), findsOneWidget);
    expect(find.textContaining('TomFormBoolSwitch'), findsOneWidget);
    expect(find.textContaining('TomFormBoolToggle'), findsOneWidget);
    // Bindings panel labels.
    expect(find.text('filterChips'), findsOneWidget);
    expect(find.text('multiCheckbox'), findsOneWidget);
    expect(find.text('segmented'), findsOneWidget);
    expect(find.text('radioGroup'), findsOneWidget);
    expect(find.text('choiceChips'), findsOneWidget);
  });

  testWidgets('tap a FilterChip — filterChips binding gains the value', (
    tester,
  ) async {
    await openDemoE(tester);
    await tapInVariant<FilterChip>(
      tester,
      'TomFormStringFilterChips',
      'Technology',
    );
    // The bindings table renders the list as `[tech]`. The change-log
    // panel echoes the same value so we accept >= 1.
    expect(
      find.text('[tech]'),
      findsAtLeastNWidgets(1),
      reason: 'filterChips binding must show [tech] after selecting it',
    );
  });

  testWidgets('tap a CheckboxListTile in the multi-check variant updates '
      'the binding', (tester) async {
    await openDemoE(tester);
    await tapInVariant<CheckboxListTile>(
      tester,
      'TomFormStringMultiCheckbox',
      'Finance',
    );
    expect(
      find.text('[finance]'),
      findsAtLeastNWidgets(1),
      reason: 'multiCheckbox binding must show [finance] after toggling',
    );
  });

  testWidgets('tap a RadioListTile updates the radioGroup binding', (
    tester,
  ) async {
    await openDemoE(tester);
    await tapInVariant<RadioListTile<String>>(
      tester,
      'TomFormStringRadioGroup',
      'Manufacturing',
    );
    // 'manufacturing' appears in the bindings table and the change log.
    expect(find.text('manufacturing'), findsAtLeastNWidgets(1));
  });

  testWidgets('tap a ChoiceChip updates the choiceChips binding', (
    tester,
  ) async {
    await openDemoE(tester);
    await tapInVariant<ChoiceChip>(
      tester,
      'TomFormStringChoiceChips',
      'Retail',
    );
    // 'retail' appears in the bindings table and the change log.
    expect(find.text('retail'), findsAtLeastNWidgets(1));
  });

  testWidgets('tap the boolean checkbox flips the boolCheckbox binding', (
    tester,
  ) async {
    await openDemoE(tester);
    // Initial value: false → bindings table shows 'false'. After tap → true.
    await tapInVariant<CheckboxListTile>(
      tester,
      'TomFormBoolCheckbox',
      'Agree to terms',
    );
    // Bindings table value is rendered as the literal 'true'.
    final trueCells = find.text('true');
    expect(
      trueCells,
      findsAtLeastNWidgets(1),
      reason: 'boolCheckbox should be true after a tap',
    );
  });

  testWidgets('tap the boolean switch flips the boolSwitch binding', (
    tester,
  ) async {
    await openDemoE(tester);
    await tapInVariant<SwitchListTile>(
      tester,
      'TomFormBoolSwitch',
      'Enable notifications',
    );
    expect(
      find.text('true'),
      findsAtLeastNWidgets(1),
      reason: 'boolSwitch should be true after a tap',
    );
  });

  testWidgets('toggling Filtered source narrows visible items to two', (
    tester,
  ) async {
    await openDemoE(tester);
    // Baseline: full catalogue → "Manufacturing" appears in multiple
    // variant cards (FilterChips + MultiCheckbox + Segmented + Radio +
    // ChoiceChip = at least 5 occurrences).
    expect(find.text('Manufacturing'), findsAtLeastNWidgets(1));
    // Toggle the source switch.
    final filteredSwitch = find.widgetWithText(
      SwitchListTile,
      'Filtered source',
    );
    expect(filteredSwitch, findsOneWidget);
    await tester.ensureVisible(filteredSwitch);
    await tester.pumpAndSettle();
    await tester.tap(filteredSwitch);
    await tester.pumpAndSettle();
    // After toggle the subtitle should reflect the 2-item subset. The
    // intro card also mentions '2-item subset', so we accept >= 1.
    expect(
      find.textContaining('2-item subset'),
      findsAtLeastNWidgets(1),
      reason: 'subtitle must reflect the active filtered source',
    );
    // "Manufacturing" should disappear from every variant card.
    expect(
      find.text('Manufacturing'),
      findsNothing,
      reason: 'filtered source has no Manufacturing item',
    );
    // "Technology" must still be present (it's in the 2-item subset).
    expect(find.text('Technology'), findsAtLeastNWidgets(1));
  });

  testWidgets('toggling Filtered source prunes selections that no longer '
      'match', (tester) async {
    await openDemoE(tester);
    // Select Manufacturing in the radio group.
    await tapInVariant<RadioListTile<String>>(
      tester,
      'TomFormStringRadioGroup',
      'Manufacturing',
    );
    expect(find.text('manufacturing'), findsAtLeastNWidgets(1));
    // Toggle to filtered source — should prune the now-invalid selection.
    final filteredSwitch = find.widgetWithText(
      SwitchListTile,
      'Filtered source',
    );
    await tester.ensureVisible(filteredSwitch);
    await tester.pumpAndSettle();
    await tester.tap(filteredSwitch);
    await tester.pumpAndSettle();
    // The Manufacturing radio option itself must no longer be present
    // in the radio variant card after the source shrinks. (The change
    // log will still echo the historical selection, so we can't assert
    // 'manufacturing' is gone globally.)
    expect(
      inVariant<RadioListTile<String>>(
        'TomFormStringRadioGroup',
        'Manufacturing',
      ),
      findsNothing,
      reason:
          'Manufacturing must be pruned from the radio variant when the '
          'source shrinks',
    );
  });
}

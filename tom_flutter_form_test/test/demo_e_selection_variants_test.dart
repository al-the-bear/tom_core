/// Interaction tests for Demo E — Selection Variants.
///
/// Demo E renders the five concrete selection fields —
/// [TomFormStringFilterChips], [TomFormStringMultiCheckbox],
/// [TomFormStringSegmented], [TomFormStringRadioGroup],
/// [TomFormStringChoiceChips] — plus the three boolean renderings, all five
/// selection fields sharing one [TomMutableSelectableSource]. The right-hand
/// "Live bindings" panel echoes every binding.
///
/// These tests drive each field in turn and assert the matching binding row
/// updates. The two that carry the demo's real weight are the last pair: they
/// shrink the shared catalogue at runtime and assert that the two arities
/// reconcile *differently* — multi-select drops the vanished value, while
/// single-select falls back to the first enabled item rather than to empty.
/// Nothing in the demo implements that; each field does it for itself off the
/// source's `itemsStream`, so these tests are what pins the framework
/// behaviour rather than the demo's own bookkeeping.
///
/// Finders are scoped by the per-field `ValueKey('field-<tomId>')` the demo
/// attaches to each row: five fields repeat the same option labels (and two
/// repeat `SegmentedButton`), so an unscoped finder would be ambiguous.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/panels/info_panel.dart';
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

  /// Every binding the demo exposes, in render order.
  const multiSelect = ['filterChips', 'multiCheckbox'];
  const singleSelect = ['segmented', 'radioGroup', 'choiceChips'];
  const booleans = ['boolCheckbox', 'boolSwitch', 'boolToggle'];

  Future<void> openDemoE(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2400);
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

  /// The row the demo keys with [tomId].
  Finder row(String tomId) => find.byKey(ValueKey('field-$tomId'));

  /// The "Live bindings" panel, as distinct from the change log — both
  /// render the same `tomId` strings, so every binding read is scoped here.
  Finder bindingsPanel() => find.ancestor(
    of: find.text('Live bindings'),
    matching: find.byType(InfoPanel),
  );

  /// The value the bindings panel currently shows for [tomId].
  ///
  /// The panel renders each binding as `Row[Text(tomId), Text(value)]`.
  String bindingOf(WidgetTester tester, String tomId) {
    final label = find.descendant(
      of: bindingsPanel(),
      matching: find.text(tomId),
    );
    expect(label, findsOneWidget, reason: '$tomId must have a binding row');
    final bindingRow = find.ancestor(of: label, matching: find.byType(Row));
    final texts = tester
        .widgetList<Text>(
          find.descendant(of: bindingRow.first, matching: find.byType(Text)),
        )
        .toList();
    expect(
      texts,
      hasLength(2),
      reason: '$tomId row must be exactly label + value',
    );
    return texts[1].data ?? '';
  }

  void expectBinding(WidgetTester tester, String tomId, String value) {
    expect(bindingOf(tester, tomId), value, reason: '$tomId must be "$value"');
  }

  /// Tap the descendant of type [W] carrying [label] inside field row [tomId].
  Future<void> tapOption<W extends Widget>(
    WidgetTester tester,
    String tomId,
    String label,
  ) async {
    final finder = find.descendant(
      of: row(tomId),
      matching: find.widgetWithText(W, label),
    );
    expect(
      finder,
      findsOneWidget,
      reason: 'No $W labelled "$label" inside field row "$tomId"',
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Tap the segment captioned [label] inside field row [tomId].
  ///
  /// A `SegmentedButton` is one widget containing all its segments, so
  /// `widgetWithText` would resolve to the button and `tap` would hit
  /// whichever segment happens to sit at its centre. The caption is the only
  /// finder that addresses one segment.
  Future<void> tapSegment(
    WidgetTester tester,
    String tomId,
    String label,
  ) async {
    final finder = find.descendant(of: row(tomId), matching: find.text(label));
    expect(
      finder,
      findsOneWidget,
      reason: 'No segment "$label" inside field row "$tomId"',
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Tap the sole widget of type [W] inside field row [tomId] — used for the
  /// boolean renderings, whose control carries no text of its own.
  Future<void> tapControl<W extends Widget>(
    WidgetTester tester,
    String tomId,
  ) async {
    final finder = find.descendant(of: row(tomId), matching: find.byType(W));
    expect(finder, findsOneWidget, reason: 'No $W inside field row "$tomId"');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Flip the shared source between the full catalogue and the 2-item subset.
  Future<void> toggleFilteredSource(WidgetTester tester) async {
    final sourceSwitch = find.widgetWithText(SwitchListTile, 'Filtered source');
    expect(sourceSwitch, findsOneWidget);
    await tester.ensureVisible(sourceSwitch);
    await tester.pumpAndSettle();
    await tester.tap(sourceSwitch);
    await tester.pumpAndSettle();
  }

  testWidgets('the demo binds the real selection fields, not Material '
      'stand-ins', (tester) async {
    // Rendering bare FilterChips and RadioListTiles captioned with the
    // framework widget names would tell a viewer they are looking at
    // TomFormStringRadioGroup while they look at Material. Assert on what is
    // actually in the tree: eight real fields (each field wraps its rendering
    // in a TomFieldWidgetAdapter) and none of the stand-ins.
    await openDemoE(tester);
    expect(
      find.byType(TomFieldWidgetAdapter),
      findsNWidgets(8),
      reason: 'eight real Tom form fields must render',
    );
    expect(
      find.byType(CheckboxListTile),
      findsNothing,
      reason: 'the Material stand-ins must be gone',
    );
    expect(
      find.byType(RadioListTile<String>),
      findsNothing,
      reason: 'the Material stand-ins must be gone',
    );
    // The one SwitchListTile left is the demo's own source toggle — it is a
    // demo control, not a bound field.
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.widgetWithText(SwitchListTile, 'Filtered source'), findsOne);
    // Labels come from the fields, so each row is individually anchored.
    expect(find.text('TomFormStringFilterChips (filterChips)'), findsOneWidget);
    expect(
      find.text('TomFormStringMultiCheckbox (multiCheckbox)'),
      findsOneWidget,
    );
    expect(find.text('TomFormStringSegmented (segmented)'), findsOneWidget);
    expect(find.text('TomFormStringRadioGroup (radioGroup)'), findsOneWidget);
    expect(find.text('TomFormStringChoiceChips (choiceChips)'), findsOneWidget);
  });

  testWidgets('all five selection fields share one source', (tester) async {
    await openDemoE(tester);
    // Every field renders all six catalogue items, so a label from the
    // shared source appears once per selection field.
    for (final tomId in [...multiSelect, ...singleSelect]) {
      expect(
        find.descendant(of: row(tomId), matching: find.text('Manufacturing')),
        findsOneWidget,
        reason: '$tomId must render the shared catalogue',
      );
    }
  });

  testWidgets('baseline — multi-select starts empty, single-select on tech', (
    tester,
  ) async {
    await openDemoE(tester);
    for (final tomId in multiSelect) {
      expectBinding(tester, tomId, '—');
    }
    for (final tomId in singleSelect) {
      expectBinding(tester, tomId, 'tech');
    }
    for (final tomId in booleans) {
      expectBinding(tester, tomId, 'false');
    }
  });

  testWidgets('tap a FilterChip — filterChips gains the value as a list', (
    tester,
  ) async {
    await openDemoE(tester);
    await tapOption<FilterChip>(tester, 'filterChips', 'Technology');
    expectBinding(tester, 'filterChips', '[tech]');
    // Multi-select accumulates rather than replacing.
    await tapOption<FilterChip>(tester, 'filterChips', 'Retail');
    expectBinding(tester, 'filterChips', '[tech, retail]');
    // Tapping a selected chip removes it.
    await tapOption<FilterChip>(tester, 'filterChips', 'Technology');
    expectBinding(tester, 'filterChips', '[retail]');
    // The peer multi-select field is independent.
    expectBinding(tester, 'multiCheckbox', '—');
  });

  testWidgets('tap a multi-checkbox row — multiCheckbox gains the value', (
    tester,
  ) async {
    await openDemoE(tester);
    // The field renders a bare Checkbox beside a label inside a tappable
    // InkWell — there is no ListTile to address, so the row is the target.
    await tapOption<InkWell>(tester, 'multiCheckbox', 'Finance');
    expectBinding(tester, 'multiCheckbox', '[finance]');
    expectBinding(tester, 'filterChips', '—');
  });

  testWidgets('tap a segment — segmented replaces its single value', (
    tester,
  ) async {
    await openDemoE(tester);
    await tapSegment(tester, 'segmented', 'Retail');
    expectBinding(tester, 'segmented', 'retail');
    // Single-select replaces rather than accumulating.
    await tapSegment(tester, 'segmented', 'Finance');
    expectBinding(tester, 'segmented', 'finance');
  });

  testWidgets('tap a radio row — radioGroup replaces its single value', (
    tester,
  ) async {
    await openDemoE(tester);
    await tapOption<InkWell>(tester, 'radioGroup', 'Manufacturing');
    expectBinding(tester, 'radioGroup', 'manufacturing');
    // The radio itself is a bare Radio<String> under an ancestor RadioGroup.
    expect(
      find.descendant(
        of: row('radioGroup'),
        matching: find.byType(Radio<String>),
      ),
      findsNWidgets(6),
    );
  });

  testWidgets('tap a ChoiceChip — choiceChips replaces its single value', (
    tester,
  ) async {
    await openDemoE(tester);
    await tapOption<ChoiceChip>(tester, 'choiceChips', 'Retail');
    expectBinding(tester, 'choiceChips', 'retail');
    expectBinding(tester, 'segmented', 'tech');
  });

  testWidgets('the three boolean fields flip independently', (tester) async {
    await openDemoE(tester);
    await tapControl<Checkbox>(tester, 'boolCheckbox');
    expectBinding(tester, 'boolCheckbox', 'true');
    expectBinding(tester, 'boolSwitch', 'false');

    await tapControl<Switch>(tester, 'boolSwitch');
    expectBinding(tester, 'boolSwitch', 'true');

    await tapSegment(tester, 'boolToggle', 'On');
    expectBinding(tester, 'boolToggle', 'true');
  });

  testWidgets('shrinking the shared source narrows every field at once', (
    tester,
  ) async {
    await openDemoE(tester);
    expect(find.text('Manufacturing'), findsNWidgets(5));

    await toggleFilteredSource(tester);

    expect(
      find.textContaining('2-item subset'),
      findsAtLeastNWidgets(1),
      reason: 'the subtitle must reflect the active filtered source',
    );
    expect(
      find.text('Manufacturing'),
      findsNothing,
      reason: 'no field may keep an option the shared source dropped',
    );
    // Technology survives — it is in the 2-item subset.
    expect(find.text('Technology'), findsNWidgets(5));
  });

  testWidgets('on shrink, multi-select drops the vanished value', (
    tester,
  ) async {
    await openDemoE(tester);
    // Select one value that survives the shrink and one that does not.
    await tapOption<FilterChip>(tester, 'filterChips', 'Technology');
    await tapOption<FilterChip>(tester, 'filterChips', 'Manufacturing');
    expectBinding(tester, 'filterChips', '[tech, manufacturing]');

    await toggleFilteredSource(tester);

    expectBinding(tester, 'filterChips', '[tech]');
    expect(
      find.descendant(
        of: row('filterChips'),
        matching: find.byType(FilterChip),
      ),
      findsNWidgets(2),
      reason: 'the field must re-render against the smaller catalogue',
    );
  });

  testWidgets('on shrink, single-select falls back to the first enabled item, '
      'not to empty', (tester) async {
    // This is the semantic that separates the two arities: a single-select
    // field cannot represent "nothing chosen" the way a list can, so it
    // adopts the first item still on offer.
    await openDemoE(tester);
    await tapOption<InkWell>(tester, 'radioGroup', 'Manufacturing');
    await tapOption<ChoiceChip>(tester, 'choiceChips', 'Retail');
    expectBinding(tester, 'radioGroup', 'manufacturing');
    expectBinding(tester, 'choiceChips', 'retail');

    await toggleFilteredSource(tester);

    // 'tech' is the first item of the filtered catalogue — not ''.
    expectBinding(tester, 'radioGroup', 'tech');
    expectBinding(tester, 'choiceChips', 'tech');
    expect(
      find.descendant(
        of: row('radioGroup'),
        matching: find.text('Manufacturing'),
      ),
      findsNothing,
    );
  });

  testWidgets('a value that survives the shrink is left alone', (tester) async {
    // The reconciliation only fires for values the new catalogue lost — a
    // still-valid selection must not be reset to the first item.
    await openDemoE(tester);
    await tapOption<ChoiceChip>(tester, 'choiceChips', 'Healthcare');
    expectBinding(tester, 'choiceChips', 'healthcare');

    await toggleFilteredSource(tester);

    expectBinding(tester, 'choiceChips', 'healthcare');
  });
}

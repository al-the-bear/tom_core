/// Interaction tests for Demo F — Boolean Variants.
///
/// Demo F renders three boolean widgets (Checkbox, Switch, Toggle)
/// twice: once each bound to its own [TomBool], once each bound to a
/// single shared [TomBool] so flipping any of the three flips all.
/// The right-hand "Bound values" panel echoes each binding live.
///
/// These tests drive each variant in turn and assert the matching
/// binding row updates. Critically, they assert that flipping any
/// member of the shared row updates *every* member of that row.
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

  Future<void> openDemoF(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo F: Boolean Variants'), 200,
        scrollable: find.descendant(
          of: find.byType(DemoListScreen),
          matching: find.byType(Scrollable),
        ),);
    await tester.tap(find.text('Demo F: Boolean Variants'));
    await tester.pumpAndSettle();
  }

  /// Tap a boolean widget identified by its label text. Each row is
  /// uniquely labelled so this finder is collision-free.
  Future<void> tapByLabel<W extends Widget>(
    WidgetTester tester,
    String label,
  ) async {
    final finder = find.widgetWithText(W, label);
    expect(finder, findsOneWidget,
        reason: 'No $W with label "$label"');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Tap the 'on' or 'off' segment of the SegmentedButton inside the
  /// toggle row whose label matches. Walk up to the surrounding Padding
  /// (the Row level) to scope, then find the segment ButtonSegment.
  Future<void> tapToggleSegment(
    WidgetTester tester,
    String label,
    String segment, // 'on' or 'off'
  ) async {
    final row = find.ancestor(
      of: find.text(label),
      matching: find.byType(Row),
    );
    expect(row, findsAtLeastNWidgets(1), reason: 'Toggle row "$label" missing');
    final segmentText = find.descendant(
      of: row.first,
      matching: find.text(segment),
    );
    expect(segmentText, findsOneWidget,
        reason: 'Segment "$segment" must exist inside row "$label"');
    await tester.ensureVisible(segmentText);
    await tester.pumpAndSettle();
    await tester.tap(segmentText);
    await tester.pumpAndSettle();
  }

  /// The bindings panel renders as `Row[Text(name), Text(value)]`.
  /// Locate the value cell adjacent to a given binding name.
  Finder valueOf(String bindingName) {
    final row = find.ancestor(
      of: find.text(bindingName),
      matching: find.byType(Row),
    );
    return find.descendant(
      of: row.first,
      matching: find.byWidgetPredicate(
        (w) => w is Text && (w.data == 'true' || w.data == 'false'),
      ),
    );
  }

  void expectBinding(String bindingName, bool value) {
    final candidates = valueOf(bindingName).evaluate();
    expect(candidates, isNotEmpty,
        reason: '$bindingName binding row not found');
    final text = candidates.first.widget as Text;
    expect(text.data, '$value',
        reason: '$bindingName must be $value');
  }

  testWidgets('baseline — all four bindings start at false',
      (tester) async {
    await openDemoF(tester);
    expect(find.text('checkboxFlag'), findsOneWidget);
    expect(find.text('switchFlag'), findsOneWidget);
    expect(find.text('toggleFlag'), findsOneWidget);
    expect(find.text('shared'), findsOneWidget);
    expectBinding('checkboxFlag', false);
    expectBinding('switchFlag', false);
    expectBinding('toggleFlag', false);
    expectBinding('shared', false);
  });

  testWidgets('tap the independent checkbox — only checkboxFlag flips',
      (tester) async {
    await openDemoF(tester);
    await tapByLabel<CheckboxListTile>(
      tester,
      'TomFormBoolCheckbox (checkboxFlag)',
    );
    expectBinding('checkboxFlag', true);
    expectBinding('switchFlag', false);
    expectBinding('toggleFlag', false);
    expectBinding('shared', false);
  });

  testWidgets('tap the independent switch — only switchFlag flips',
      (tester) async {
    await openDemoF(tester);
    await tapByLabel<SwitchListTile>(
      tester,
      'TomFormBoolSwitch (switchFlag)',
    );
    expectBinding('checkboxFlag', false);
    expectBinding('switchFlag', true);
    expectBinding('toggleFlag', false);
    expectBinding('shared', false);
  });

  testWidgets('tap the independent toggle — only toggleFlag flips',
      (tester) async {
    await openDemoF(tester);
    await tapToggleSegment(
      tester,
      'TomFormBoolToggle (toggleFlag)',
      'on',
    );
    expectBinding('checkboxFlag', false);
    expectBinding('switchFlag', false);
    expectBinding('toggleFlag', true);
    expectBinding('shared', false);
  });

  testWidgets('shared row — flipping the checkbox flips the shared value',
      (tester) async {
    await openDemoF(tester);
    await tapByLabel<CheckboxListTile>(tester, 'Checkbox ↔ shared');
    expectBinding('shared', true);
    // Independents must NOT have flipped.
    expectBinding('checkboxFlag', false);
    expectBinding('switchFlag', false);
    expectBinding('toggleFlag', false);
  });

  testWidgets('shared row — flipping the switch flips the shared value',
      (tester) async {
    await openDemoF(tester);
    await tapByLabel<SwitchListTile>(tester, 'Switch ↔ shared');
    expectBinding('shared', true);
  });

  testWidgets('shared row — flipping the toggle on flips the shared value',
      (tester) async {
    await openDemoF(tester);
    await tapToggleSegment(tester, 'Toggle ↔ shared', 'on');
    expectBinding('shared', true);
  });

  testWidgets('shared row — flipping any one widget reflects in the others',
      (tester) async {
    // The structural promise of the demo: the three shared widgets show
    // the same value because they read from the same TomBool. After
    // flipping the checkbox to true, the switch must also display "ON"
    // (i.e. its value is true) and the toggle's "on" segment must be
    // selected. We assert on the binding (single source of truth) plus
    // a structural sanity check on the SegmentedButton selection.
    await openDemoF(tester);
    await tapByLabel<CheckboxListTile>(tester, 'Checkbox ↔ shared');
    expectBinding('shared', true);
    // Locate the Toggle ↔ shared row's SegmentedButton<bool> and
    // confirm its `selected` set contains true.
    final row = find.ancestor(
      of: find.text('Toggle ↔ shared'),
      matching: find.byType(Row),
    );
    final segmented = find
        .descendant(
          of: row.first,
          matching: find.byType(SegmentedButton<bool>),
        )
        .evaluate()
        .first
        .widget as SegmentedButton<bool>;
    expect(segmented.selected, contains(true),
        reason: 'Shared toggle must reflect the new value (true)');
  });

  testWidgets('toggling shared off after on returns shared to false',
      (tester) async {
    await openDemoF(tester);
    await tapByLabel<CheckboxListTile>(tester, 'Checkbox ↔ shared');
    expectBinding('shared', true);
    // Use the toggle's 'off' segment to flip it back.
    await tapToggleSegment(tester, 'Toggle ↔ shared', 'off');
    expectBinding('shared', false);
  });
}

/// Interaction tests for Demo F — Boolean Variants.
///
/// Demo F renders the three concrete boolean fields — [TomFormBoolCheckbox],
/// [TomFormBoolSwitch], [TomFormBoolToggle] — twice: once each holding its
/// own value, once each kept in lock-step so flipping one flips all three.
/// The right-hand "Bound values" panel echoes every binding live.
///
/// These tests drive each rendering in turn and assert the matching binding
/// row updates. Critically, they assert that flipping any member of the
/// lock-step row moves *every* member of that row — both in the bindings
/// panel and in the peer widgets' own rendered state.
///
/// Finders are scoped by the per-field `ValueKey('field-<tomId>')` the demo
/// attaches to each row: the six rows repeat the same inner Material widgets
/// (and both toggles repeat the segment captions "On"/"Off"), so an unscoped
/// finder would be ambiguous.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

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

  /// Every binding the demo exposes, in render order.
  const independent = ['checkboxFlag', 'switchFlag', 'toggleFlag'];
  const shared = ['sharedCheckbox', 'sharedSwitch', 'sharedToggle'];

  Future<void> openDemoF(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
      find.text('Demo F: Boolean Variants'),
      200,
      scrollable: find.descendant(
        of: find.byType(DemoListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Demo F: Boolean Variants'));
    await tester.pumpAndSettle();
  }

  /// The row the demo keys with [tomId].
  Finder row(String tomId) => find.byKey(ValueKey('field-$tomId'));

  /// Tap the inner widget of type [W] inside the field row [tomId].
  Future<void> tapField<W extends Widget>(
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

  /// Tap the 'On' or 'Off' segment of the toggle in field row [tomId].
  Future<void> tapSegment(
    WidgetTester tester,
    String tomId,
    String segment,
  ) async {
    final finder = find.descendant(
      of: row(tomId),
      matching: find.text(segment),
    );
    expect(finder, findsOneWidget,
        reason: 'Segment "$segment" must exist inside field row "$tomId"');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// The bindings panel renders as `Row[Text(tomId), Text(value)]`.
  void expectBinding(String tomId, bool value) {
    final labelRow = find.ancestor(
      of: find.text(tomId),
      matching: find.byType(Row),
    );
    final candidates = find
        .descendant(
          of: labelRow.first,
          matching: find.byWidgetPredicate(
            (w) => w is Text && (w.data == 'true' || w.data == 'false'),
          ),
        )
        .evaluate();
    expect(candidates, isNotEmpty, reason: '$tomId binding row not found');
    expect((candidates.first.widget as Text).data, '$value',
        reason: '$tomId must be $value');
  }

  void expectAll(Iterable<String> tomIds, bool value) {
    for (final id in tomIds) {
      expectBinding(id, value);
    }
  }

  /// Whether the toggle in field row [tomId] currently shows `true` selected.
  bool toggleSelection(WidgetTester tester, String tomId) {
    final segmented = tester.widget<SegmentedButton<bool>>(
      find.descendant(
        of: row(tomId),
        matching: find.byType(SegmentedButton<bool>),
      ),
    );
    return segmented.selected.contains(true);
  }

  testWidgets('the demo binds the real TomFormBool* fields, not Material '
      'stand-ins', (tester) async {
    // The regression guard for tcinc1096. Demo F used to render bare
    // CheckboxListTile / SwitchListTile captioned with the framework widget
    // names, so a viewer was told they were looking at TomFormBoolCheckbox
    // while looking at Material. Assert on what is actually in the tree:
    // six real fields (each field wraps its rendering in a
    // TomFieldWidgetAdapter) and none of the old stand-ins.
    await openDemoF(tester);
    expect(find.byType(TomFieldWidgetAdapter), findsNWidgets(6),
        reason: 'six real TomFormBool* fields must render');
    expect(find.byType(CheckboxListTile), findsNothing,
        reason: 'the Material stand-ins must be gone');
    expect(find.byType(SwitchListTile), findsNothing,
        reason: 'the Material stand-ins must be gone');
    // Each rendering appears twice: once independent, once lock-step.
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.byType(Switch), findsNWidgets(2));
    expect(find.byType(SegmentedButton<bool>), findsNWidgets(2));
    // Labels come from the fields, so each row is individually anchored.
    expect(find.text('TomFormBoolCheckbox (checkboxFlag)'), findsOneWidget);
    expect(find.text('TomFormBoolSwitch (switchFlag)'), findsOneWidget);
    expect(find.text('TomFormBoolToggle (toggleFlag)'), findsOneWidget);
  });

  testWidgets('baseline — all six bindings start at false', (tester) async {
    await openDemoF(tester);
    expectAll([...independent, ...shared], false);
  });

  testWidgets('tap the independent checkbox — only checkboxFlag flips',
      (tester) async {
    await openDemoF(tester);
    await tapField<Checkbox>(tester, 'checkboxFlag');
    expectBinding('checkboxFlag', true);
    expectAll(['switchFlag', 'toggleFlag', ...shared], false);
  });

  testWidgets('tap the independent switch — only switchFlag flips',
      (tester) async {
    await openDemoF(tester);
    await tapField<Switch>(tester, 'switchFlag');
    expectBinding('switchFlag', true);
    expectAll(['checkboxFlag', 'toggleFlag', ...shared], false);
  });

  testWidgets('tap the independent toggle — only toggleFlag flips',
      (tester) async {
    await openDemoF(tester);
    await tapSegment(tester, 'toggleFlag', 'On');
    expectBinding('toggleFlag', true);
    expectAll(['checkboxFlag', 'switchFlag', ...shared], false);
  });

  testWidgets('lock-step — flipping the checkbox moves all three',
      (tester) async {
    await openDemoF(tester);
    await tapField<Checkbox>(tester, 'sharedCheckbox');
    expectAll(shared, true);
    // The independent row must not have moved.
    expectAll(independent, false);
  });

  testWidgets('lock-step — flipping the switch moves all three',
      (tester) async {
    await openDemoF(tester);
    await tapField<Switch>(tester, 'sharedSwitch');
    expectAll(shared, true);
    expectAll(independent, false);
  });

  testWidgets('lock-step — flipping the toggle moves all three',
      (tester) async {
    await openDemoF(tester);
    await tapSegment(tester, 'sharedToggle', 'On');
    expectAll(shared, true);
    expectAll(independent, false);
  });

  testWidgets('lock-step — the peer widgets rerender, not just the bindings',
      (tester) async {
    // The structural promise: propagation reaches the peers' own rendered
    // state, not merely the inspector panel that reads the values back.
    await openDemoF(tester);
    expect(toggleSelection(tester, 'sharedToggle'), isFalse);

    await tapField<Checkbox>(tester, 'sharedCheckbox');

    expect(toggleSelection(tester, 'sharedToggle'), isTrue,
        reason: 'shared toggle must follow the checkbox');
    final peerSwitch = tester.widget<Switch>(
      find.descendant(
        of: row('sharedSwitch'),
        matching: find.byType(Switch),
      ),
    );
    expect(peerSwitch.value, isTrue,
        reason: 'shared switch must follow the checkbox');
    // The independent toggle is untouched — propagation is scoped to the trio.
    expect(toggleSelection(tester, 'toggleFlag'), isFalse);
  });

  testWidgets('lock-step — flipping back off returns the whole trio to false',
      (tester) async {
    await openDemoF(tester);
    await tapField<Checkbox>(tester, 'sharedCheckbox');
    expectAll(shared, true);
    // Flip back via a *different* rendering than the one that set it.
    await tapSegment(tester, 'sharedToggle', 'Off');
    expectAll(shared, false);
  });
}

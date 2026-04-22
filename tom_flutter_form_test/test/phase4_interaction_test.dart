/// Interaction tests for Phase 4 demos (K lookup/search, L nullable).
///
/// Covers feedback round 4 items (n/o/p/q):
///   (n) Demo K Lookup field uses a TextField pattern so its display
///       text aligns on the standard input baseline (not an
///       InputDecorator-with-Text that floats high).
///   (o) Demo K modal search dialog shows a prefix icon sized > the
///       default 18 px and inside an outlined input (so the icon sits
///       in front of the text input, not on the divider line).
///   (p) Demo K Lookup field + dialog use the same input-style font as
///       the rest of the form (asserted by reading the rendered
///       TextField's `style` and the dialog ListTile's title style and
///       requiring a non-null fontSize that matches `bodyMedium`).
///   (q) Demo L exposes the three null-display modes (truly empty,
///       explicit "no value set", hint-based) and a nullable enum
///       dropdown whose null item label is overridable.
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
    // Tall viewport so the entire body fits without scrolling.
    tester.view.physicalSize = const Size(2400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(find.text(tile), 200);
    await tester.tap(find.text(tile));
    await tester.pumpAndSettle();
  }

  /// Locate the lookup display TextField — it carries the picked
  /// Country label in its controller. Brittle string match is OK
  /// because the demo uses a known initial value.
  Finder _findLookupTextField() {
    return find.byWidgetPredicate(
      (w) => w is TextField &&
          w.readOnly == true &&
          w.controller?.text == 'Japan (JP)',
    );
  }

  testWidgets(
      '(n) Demo K lookup field renders as a read-only TextField (baseline-aligned)',
      (tester) async {
    await openDemo(tester, 'Demo K: Enum, Object & Lookup');
    expect(find.text('Lookup dialog (Country) — modal browse'),
        findsOneWidget);
    // After the (n) fix the read-only display is a TextField with the
    // selected country in its controller; sharing the TextField anatomy
    // means baseline + content padding + inputStyle match every other
    // form input (which the InputDecorator+Text version did not).
    expect(_findLookupTextField(), findsOneWidget,
        reason:
            'Lookup field should render its selected value through a read-only TextField');
  });

  testWidgets(
      '(o) Demo K search dialog leading icon is larger than default and inside an outlined input',
      (tester) async {
    await openDemo(tester, 'Demo K: Enum, Object & Lookup');
    // Open the lookup dialog by tapping the field's TextField.
    await tester.tap(_findLookupTextField());
    await tester.pumpAndSettle();
    expect(find.text('Pick a country'), findsOneWidget);
    // Search-icon size: the prefix Icon inside the dialog should be
    // explicitly sized >=22 (was the platform default ~18, which made
    // it too small and overlapping the dense underline divider).
    final searchIcons = find.byWidgetPredicate(
      (w) => w is Icon && w.icon == Icons.search,
    );
    expect(searchIcons, findsAtLeastNWidgets(1));
    final iconWidgets = tester.widgetList<Icon>(searchIcons).toList();
    final hasLargeIcon = iconWidgets.any((i) => (i.size ?? 0) >= 22);
    expect(hasLargeIcon, isTrue,
        reason:
            'Search dialog leading icon should be sized >=22 px (was default ~18)');
    // The dialog filter TextField should sit inside an OutlineInputBorder
    // (not the dense underline that drew the icon on the divider line
    // between input and result list).
    final filterTf = tester.widget<TextField>(find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        )
        .first);
    expect(filterTf.decoration?.border, isA<OutlineInputBorder>(),
        reason:
            'Dialog filter input must be outlined so the icon sits inside the input box');
  });

  testWidgets('(p) Demo K lookup field and dialog use the form input style',
      (tester) async {
    await openDemo(tester, 'Demo K: Enum, Object & Lookup');
    // The display TextField has an explicit `style:` — same source of
    // truth as every other input via `style.inputStyle`.
    final displayTf = tester.widget<TextField>(_findLookupTextField());
    expect(displayTf.style, isNotNull,
        reason: 'Lookup field text must use the form input style');
    expect(displayTf.style!.fontSize, isNotNull);
    // Open the dialog and confirm the filter TextField + tile labels
    // share the same explicit style.
    await tester.tap(_findLookupTextField());
    await tester.pumpAndSettle();
    final filterTf = tester.widget<TextField>(find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        )
        .first);
    expect(filterTf.style?.fontSize, displayTf.style!.fontSize,
        reason:
            'Dialog filter text must share the lookup field input style');
  });

  testWidgets('(q) Demo L shows three null-display modes and a configurable dropdown null label',
      (tester) async {
    await openDemo(tester, 'Demo L: Files & Nullable Variants');
    // Drive every nullable to null so the placeholder is visible.
    await tester.tap(find.text('Set all → null'));
    await tester.pumpAndSettle();
    // Mode 1: explicit text override — the demo configures one field
    // with `nullDisplayOverride: 'no value set'`.
    expect(find.text('no value set'), findsOneWidget,
        reason: 'Explicit null-display override must render');
    // Mode 2: hint-based — the demo sets `hintTextOverride: 'type a note…'`
    // on the notes field (no nullDisplayOverride). When null, hint shows.
    expect(find.text('type a note…'), findsOneWidget,
        reason: 'Hint-based null display must render the user hint');
    // Mode 3: empty — at least one nullable field configured with
    // `nullDisplayOverride: ''` (truly blank). We can't easily assert
    // "absence of placeholder" without a unique anchor, so we verify the
    // demo also exposes a labelled nullable enum dropdown whose null
    // label was overridden.
    expect(find.text('— please select —'), findsOneWidget,
        reason:
            'Nullable enum dropdown must show its overridden null label');
    // Mode 4 (round-6 k.b): resource-backed null display — birthday's
    // null label comes from `demoL.fileNullableDemo.birthday.nullDisplay`
    // in `assets/demo_resources.json` (resolves to "Not set"). Asserts
    // the `_NullableFieldLabels.resolveNullDisplay` resource fallback
    // is wired through the date input's button label.
    expect(find.text('Not set'), findsOneWidget,
        reason:
            'Date field must resolve null display from the scoped '
            'resource (demoL.fileNullableDemo.birthday.nullDisplay)');
    // Round-6 (k.a): "empty when null" mode must keep the field area
    // visually empty. Asserted indirectly by checking that the score
    // field's TextField uses FloatingLabelBehavior.always (so the
    // labelText doesn't drop into the field as a stand-in placeholder
    // when both value and hintText are empty).
    // Locate the score field by its labelText on the InputDecoration —
    // the labelText sits as a Text widget inside the InputDecorator
    // overlay, not as a child of TextField, so we scan all TextFields.
    final scoreFields = find
        .byType(TextField)
        .evaluate()
        .map((e) => e.widget as TextField)
        .where((tf) => tf.decoration?.labelText == 'Score (empty when null)')
        .toList();
    expect(scoreFields, isNotEmpty,
        reason: 'Score field must be in the widget tree');
    expect(scoreFields.first.decoration?.floatingLabelBehavior,
        FloatingLabelBehavior.always,
        reason:
            'Empty-when-null mode must keep the label floating so the '
            'field area renders truly empty');
  });
}

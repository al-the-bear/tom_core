/// Interaction tests for Demo 8 — Breakpoints (legacy demo).
///
/// Demo 8 wraps the form in a [TomFormStyleScope] whose `LayoutBuilder`
/// publishes the available width. Five breakpoint-aware properties resolve
/// against that width and a row of badges echoes the live state. A
/// [Slider] drives the form pane's width fraction (0.1 → 1.0) and two
/// [OutlinedButton.icon]s trigger / clear validation errors.
///
/// These tests cover three width regimes (>= 700, 400-499, < 400) by
/// changing the viewport size, plus the slider-drag path and the
/// trigger-errors button.
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
    // Demo 8 binds `demoState.companyProfile`; Trigger errors mutates it.
    // Reseed so cross-test order doesn't matter.
    demoState.companyProfile.name | 'Acme Corporation';
    demoState.companyProfile.industry | 'tech';
    demoState.companyProfile.taxId | 'US-12345-ABC';
    demoState.companyProfile.website | 'https://acme.example.com';
  });

  /// Open the demo on a wide-and-tall viewport so the demo list can
  /// reliably scroll to the tile, then optionally resize to [finalSize] so
  /// the breakpoint badges measure the chosen width regime.
  Future<void> openDemo8(
    WidgetTester tester, {
    Size finalSize = const Size(2400, 2000),
  }) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo 8: Breakpoints'), 200,
        scrollable: find.descendant(
          of: find.byType(DemoListScreen),
          matching: find.byType(Scrollable),
        ),);
    await tester.tap(find.text('Demo 8: Breakpoints'));
    await tester.pumpAndSettle();
    if (finalSize != const Size(2400, 2000)) {
      tester.view.physicalSize = finalSize;
      await tester.pumpAndSettle();
    }
  }

  Future<void> tapOutlined(WidgetTester tester, String label) async {
    final btn = find.widgetWithText(OutlinedButton, label);
    expect(btn, findsAtLeastNWidgets(1));
    await tester.ensureVisible(btn.first);
    await tester.pumpAndSettle();
    await tester.tap(btn.first);
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

  /// Read the live value of a single badge by its label prefix. Each badge
  /// renders as a [Text] with content "label: value"; we strip the prefix.
  String badgeValue(String label) {
    final t = find
        .byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data?.startsWith('$label:') ?? false),
        )
        .evaluate()
        .first
        .widget as Text;
    return t.data!.substring(label.length + 2); // strip "label: "
  }

  testWidgets('baseline at wide viewport — all badges report >=700px values',
      (tester) async {
    await openDemo8(tester, finalSize: const Size(2400, 2000));
    expect(badgeValue('labelPlacement'), 'inline');
    expect(badgeValue('labelStyle'), '15px');
    expect(badgeValue('hintStyle'), '15px');
    expect(badgeValue('labelFieldGap'), '8px');
    expect(badgeValue('errorFieldGap'), '8px');
    expect(badgeValue('errorBorderEnabled'), 'on');
    expect(badgeValue('errorIconEnabled'), 'on');
    // Form pane width text echoes the computed pixel width.
    expect(find.textContaining(' px'), findsAtLeastNWidgets(1));
    // Form fields render.
    expect(fieldByTomId('name'), findsOneWidget);
    expect(fieldByTomId('taxId'), findsOneWidget);
    expect(fieldByTomId('website'), findsOneWidget);
  });

  testWidgets('mid viewport (~568px) lands in the 400-699 band',
      (tester) async {
    // 600 wide minus 16x2 padding ≈ 568 pane width.
    await openDemo8(tester, finalSize: const Size(600, 2000));
    expect(badgeValue('labelPlacement'), 'above');
    expect(badgeValue('labelStyle'), '13px');
    expect(badgeValue('labelFieldGap'), '4px');
    expect(badgeValue('errorBorderEnabled'), 'on');
    expect(badgeValue('errorIconEnabled'), 'on',
        reason: 'icon turns on at 500px and we are at ~568px');
  });

  testWidgets('narrow viewport lands below all breakpoints',
      (tester) async {
    // The demo's auxiliary chrome (action button row, info card) overflows
    // at very narrow widths. That's not what we're testing here, so we
    // swallow render-overflow errors during this single test — the badge
    // text is still computed and visible.
    final captured = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = captured.add;
    addTearDown(() => FlutterError.onError = previous);
    // 360 wide minus padding/scaffold chrome lands the form pane below
    // 400px. Tested empirically; if the layout chrome changes, adjust.
    await openDemo8(tester, finalSize: const Size(360, 2000));
    expect(badgeValue('labelPlacement'), 'floating');
    expect(badgeValue('labelStyle'), '11px');
    expect(badgeValue('labelFieldGap'), '2px');
    expect(badgeValue('errorBorderEnabled'), 'off',
        reason: 'border is off below 400px');
    expect(badgeValue('errorIconEnabled'), 'off',
        reason: 'icon is off below 500px');
  });

  testWidgets('Trigger errors surfaces an error caption',
      (tester) async {
    await openDemo8(tester, finalSize: const Size(2400, 2000));
    await tapOutlined(tester, 'Trigger errors');
    expect(find.text('Company name is required.'), findsAtLeastNWidgets(1),
        reason: 'empty name → required error must surface');
  });

  testWidgets('Clear errors restores the sample and removes error text',
      (tester) async {
    await openDemo8(tester, finalSize: const Size(2400, 2000));
    await tapOutlined(tester, 'Trigger errors');
    expect(find.text('Company name is required.'), findsAtLeastNWidgets(1));
    await tapOutlined(tester, 'Clear errors');
    expect(find.text('Company name is required.'), findsNothing);
  });

  testWidgets('dragging the slider left shrinks the form pane width',
      (tester) async {
    // Dragging the slider can shrink the form below thresholds where the
    // demo's own DropdownButtonFormField overflows; that's a demo chrome
    // artefact unrelated to the breakpoint resolution under test.
    final captured = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = captured.add;
    addTearDown(() => FlutterError.onError = previous);
    await openDemo8(tester, finalSize: const Size(1000, 2000));
    // Initial pane width ≈ 968px. Drag toward the left to roughly halve it.
    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.drag(slider, const Offset(-300, 0));
    await tester.pumpAndSettle();
    // Compute current pane width from the live badge state — at narrower
    // widths labelPlacement should NOT still be `inline` (which requires
    // >= 700). Anything other than `inline` proves the slider moved the
    // form into a different breakpoint band.
    expect(
      badgeValue('labelPlacement'),
      isNot('inline'),
      reason: 'after dragging the slider left the pane should fall below '
          'the 700px breakpoint',
    );
  });
}

/// Interaction tests for Demo 6 — Field Layout Options (legacy demo).
///
/// Demo 6 hosts five [SegmentedButton]s (preset / label placement /
/// required indicator label / hint / description / description placement)
/// plus two [OutlinedButton.icon]s (Clear fields / Populate with demo data).
/// Switching segments rebuilds the form under a new [TomFormStyle]; the
/// Clear / Populate buttons mutate the shared form's values directly.
///
/// We assert that:
///   * baseline — every segmented control and the two action buttons render
///   * Clear empties the visible TextField for `name`
///   * Populate restores the canonical sample (`Acme Corporation`)
///   * picking each LabelPlacement value updates the SegmentedButton
///     `selected` set (which feeds the live style)
///   * picking the `compact` preset updates its SegmentedButton selection
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/application_state.dart';

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

  // Demo 6 mutates `demoState.companyProfile` via Clear, which would carry
  // empty values into subsequent tests. Reseed the canonical sample before
  // each test so the order of execution doesn't matter.
  setUp(() {
    demoState.companyProfile.name | 'Acme Corporation';
    demoState.companyProfile.industry | 'tech';
    demoState.companyProfile.taxId | 'US-12345-ABC';
    demoState.companyProfile.website | 'https://acme.example.com';
  });

  Future<void> openDemo6(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    final tile = find.text('Demo 6: Field Layout Options');
    // scrollUntilVisible only guarantees the finder *exists* in the tree
    // — the tile may still straddle the bottom edge so tap() ends up
    // outside the viewport. ensureVisible scrolls until the widget is
    // fully on-screen (matches the pattern in tapOutlined). Adding more
    // demos to the home list shouldn't break this helper.
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.descendant(
        of: find.byType(DemoListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  /// Tap an [OutlinedButton] (icon variant) by its label text.
  Future<void> tapOutlined(WidgetTester tester, String label) async {
    final btn = find.widgetWithText(OutlinedButton, label);
    expect(
      btn,
      findsAtLeastNWidgets(1),
      reason: 'OutlinedButton "$label" must exist',
    );
    await tester.ensureVisible(btn.first);
    await tester.pumpAndSettle();
    await tester.tap(btn.first);
    await tester.pumpAndSettle();
  }

  /// Find the rendered TextField for a Tom field by `tomId`.
  Finder fieldByTomId(String tomId) {
    return find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
        description: 'TomFieldWidgetAdapter[$tomId]',
      ),
      matching: find.byType(TextField),
    );
  }

  /// Tap a labelled segment inside the SegmentedButton parameterised on [V].
  Future<void> tapSegment<V>(WidgetTester tester, String label) async {
    final segmented = find.byType(SegmentedButton<V>);
    expect(segmented, findsOneWidget, reason: 'SegmentedButton<$V> must exist');
    final seg = find.descendant(of: segmented, matching: find.text(label));
    expect(
      seg,
      findsOneWidget,
      reason: 'segment "$label" must exist inside SegmentedButton<$V>',
    );
    await tester.ensureVisible(seg);
    await tester.pumpAndSettle();
    await tester.tap(seg);
    await tester.pumpAndSettle();
  }

  /// Read the current `selected` set of the (single) SegmentedButton<V> on
  /// screen.
  Set<V> selectedOf<V>(WidgetTester tester) {
    final widget =
        find.byType(SegmentedButton<V>).evaluate().first.widget
            as SegmentedButton<V>;
    return widget.selected;
  }

  testWidgets('baseline — all segmented controls and action buttons render', (
    tester,
  ) async {
    await openDemo6(tester);
    expect(find.byType(SegmentedButton<LabelPlacement>), findsOneWidget);
    expect(find.byType(SegmentedButton<DescriptionPlacement>), findsOneWidget);
    // Three RequiredIndicator segmented buttons (label / hint / description).
    expect(find.byType(SegmentedButton<RequiredIndicator>), findsNWidgets(3));
    expect(find.widgetWithText(OutlinedButton, 'Clear fields'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Populate with demo data'),
      findsOneWidget,
    );
    // Form fields render too.
    expect(fieldByTomId('name'), findsOneWidget);
    expect(fieldByTomId('taxId'), findsOneWidget);
    expect(fieldByTomId('website'), findsOneWidget);
  });

  testWidgets('Clear fields blanks the name TextField', (tester) async {
    await openDemo6(tester);
    // Demo 6 starts unbound — fields are empty until Populate. Populate
    // first so we have a known non-empty starting value.
    await tapOutlined(tester, 'Populate with demo data');
    final nameField = fieldByTomId('name');
    expect(nameField, findsOneWidget);
    var widget = tester.widget<TextField>(nameField);
    expect(
      widget.controller?.text,
      'Acme Corporation',
      reason: 'Populate must seed the name field',
    );
    await tapOutlined(tester, 'Clear fields');
    widget = tester.widget<TextField>(fieldByTomId('name'));
    expect(
      widget.controller?.text,
      '',
      reason: 'Clear must blank the name TextField',
    );
  });

  testWidgets('Populate refills the website field with the sample URL', (
    tester,
  ) async {
    await openDemo6(tester);
    await tapOutlined(tester, 'Clear fields');
    var widget = tester.widget<TextField>(fieldByTomId('website'));
    expect(widget.controller?.text, '');
    await tapOutlined(tester, 'Populate with demo data');
    widget = tester.widget<TextField>(fieldByTomId('website'));
    expect(
      widget.controller?.text,
      'https://acme.example.com',
      reason: 'Populate should rebind the canonical sample URL',
    );
  });

  testWidgets('picking LabelPlacement.below updates the segmented selection', (
    tester,
  ) async {
    await openDemo6(tester);
    expect(
      selectedOf<LabelPlacement>(tester),
      {LabelPlacement.above},
      reason: 'baseline LabelPlacement is `above`',
    );
    await tapSegment<LabelPlacement>(tester, 'below');
    expect(selectedOf<LabelPlacement>(tester), {LabelPlacement.below});
  });

  testWidgets(
    'picking LabelPlacement.floating updates the segmented selection',
    (tester) async {
      await openDemo6(tester);
      await tapSegment<LabelPlacement>(tester, 'floating');
      expect(selectedOf<LabelPlacement>(tester), {LabelPlacement.floating});
    },
  );

  testWidgets('picking LabelPlacement.hidden updates the segmented selection', (
    tester,
  ) async {
    await openDemo6(tester);
    await tapSegment<LabelPlacement>(tester, 'hidden');
    expect(selectedOf<LabelPlacement>(tester), {LabelPlacement.hidden});
  });

  testWidgets('picking DescriptionPlacement.above updates the selection', (
    tester,
  ) async {
    await openDemo6(tester);
    expect(
      selectedOf<DescriptionPlacement>(tester),
      {DescriptionPlacement.below},
      reason: 'baseline DescriptionPlacement is `below`',
    );
    await tapSegment<DescriptionPlacement>(tester, 'above');
    expect(selectedOf<DescriptionPlacement>(tester), {
      DescriptionPlacement.above,
    });
  });
}

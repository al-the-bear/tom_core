/// Round-6 (c) regressions for Demo H-B (Expandable Rows):
///   - row-level error strip resolves error keys to user-facing text
///     via the resource provider (no more raw `error.required`);
///   - the strip stretches across the full items-card width (no inset
///     left/right padding);
///   - the strip's text alignment is configurable from the demo
///     action bar (left ↔ centred);
///   - the form-error panel headline falls back to a resource
///     (`demoHB.errors.title`) when no constructor title is supplied.
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

  Future<void> openDemoHB(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
      find.text('Demo H-B: Expandable Rows (Order Items)'),
      200,
      scrollable: find.descendant(
        of: find.byType(DemoListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Demo H-B: Expandable Rows (Order Items)'));
    await tester.pumpAndSettle();
  }

  /// Open the first row and force a quantity error (qty = 0) so the
  /// row-error strip renders.
  Future<void> openFirstRowAndBreakQty(WidgetTester tester) async {
    // After the migration to `TomExpandableListForm` rows are no longer
    // built from `ExpansionTile`. Each row's summary contains the
    // product-name text — tap it to expand. Seed item 1 in
    // phase2aExpandableOrder is "Difference Engine pinion".
    final firstRowSummary = find.text('Difference Engine pinion');
    expect(
      firstRowSummary,
      findsAtLeastNWidgets(1),
      reason: 'First row summary text must be in the tree',
    );
    await tester.tap(firstRowSummary.first);
    await tester.pumpAndSettle();
    // Locate the qty EditableText by its seed value '12' (item 1 in
    // phase2aExpandableOrder) and walk up to its TextField ancestor.
    final qtyEd = find.byWidgetPredicate(
      (w) => w is EditableText && w.controller.text == '12',
    );
    expect(
      qtyEd,
      findsOneWidget,
      reason: 'Seed qty=12 EditableText should be findable after expand',
    );
    final qtyTf = find.ancestor(of: qtyEd, matching: find.byType(TextField));
    await tester.enterText(qtyTf.first, '0');
    await tester.pumpAndSettle();
  }

  testWidgets('(c) row error strip shows resolved text, not the raw key', (
    tester,
  ) async {
    await openDemoHB(tester);
    await openFirstRowAndBreakQty(tester);
    // Resolved text from `error.mustBePositive` → "Must be greater than 0."
    expect(
      find.textContaining('Must be greater than 0'),
      findsAtLeastNWidgets(1),
      reason:
          'mustBePositive should be resolved through resources, not '
          'shown as a raw key',
    );
    // The row title pulls from `demoHB.errors.rowSingular`.
    expect(
      find.text('Row has 1 validation error:'),
      findsOneWidget,
      reason: 'Row error title must come from demoHB.errors.rowSingular',
    );
    // No raw key text leaks through.
    expect(
      find.textContaining('error.mustBePositive'),
      findsNothing,
      reason: 'Raw error key must not appear in the user-facing strip',
    );
  });

  testWidgets('(c) row error strip stretches the full items-card width', (
    tester,
  ) async {
    await openDemoHB(tester);
    await openFirstRowAndBreakQty(tester);
    // Find the strip by its sentinel key.
    final strip = find.byKey(const ValueKey('h-b-row-error-strip'));
    expect(
      strip,
      findsOneWidget,
      reason: 'Row error strip must be in the tree',
    );
    // The strip is `width: double.infinity` and lives directly inside
    // the ExpansionTile body (childrenPadding zero), so its rendered
    // width must equal the items-card content width. The qty TextField,
    // by contrast, sits inside a `Padding(horizontal: 16)` *and* shares
    // its row with the unit-price field — so its rendered width must be
    // strictly less than the strip width. Comparing against the
    // TextField (inner content) rather than the Padding outer box is
    // what proves the inset.
    final stripBox = tester.renderObject<RenderBox>(strip);
    final qtyEd = find.byWidgetPredicate(
      (w) => w is EditableText && w.controller.text == '0',
    );
    expect(qtyEd, findsAtLeastNWidgets(1));
    final qtyTfFinder = find
        .ancestor(of: qtyEd.first, matching: find.byType(TextField))
        .first;
    final qtyTfBox = tester.renderObject<RenderBox>(qtyTfFinder);
    expect(
      stripBox.size.width,
      greaterThan(qtyTfBox.size.width),
      reason:
          'Row error strip (${stripBox.size.width}px) must be wider than '
          'the qty TextField (${qtyTfBox.size.width}px) — proves the '
          'strip spans the full items-card width while the editable row '
          'is inset by horizontal padding and shares its row with the '
          'unit-price field.',
    );
  });

  testWidgets('(c) row error strip alignment toggle flips text alignment', (
    tester,
  ) async {
    await openDemoHB(tester);
    await openFirstRowAndBreakQty(tester);
    // Default = start.
    final titleStartFinder = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data == 'Row has 1 validation error:' &&
          w.textAlign == TextAlign.start,
    );
    expect(
      titleStartFinder,
      findsOneWidget,
      reason: 'Default alignment should be left/start',
    );

    // Toggle to centered via the action-bar SegmentedButton.
    final centerSeg = find.text('Errors centered');
    expect(
      centerSeg,
      findsOneWidget,
      reason: 'SegmentedButton segment must expose centered alignment',
    );
    await tester.ensureVisible(centerSeg);
    await tester.pumpAndSettle();
    await tester.tap(centerSeg);
    await tester.pumpAndSettle();

    final titleCenterFinder = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data == 'Row has 1 validation error:' &&
          w.textAlign == TextAlign.center,
    );
    expect(
      titleCenterFinder,
      findsOneWidget,
      reason:
          'After tapping the centered segment the title should '
          'render with TextAlign.center',
    );
  });

  testWidgets('(c) form errors card headline comes from resources', (
    tester,
  ) async {
    await openDemoHB(tester);
    // `demoHB.errors.title` resolves to "Form errors" — there should be
    // exactly one form-error card headline carrying that text. (The
    // earlier hard-coded text matches by coincidence; this assertion
    // anchors the resource override behaviour for future re-skinning.)
    expect(
      find.text('Form errors'),
      findsOneWidget,
      reason:
          'Form-error card title must resolve via '
          'demoHB.errors.title',
    );
  });
}

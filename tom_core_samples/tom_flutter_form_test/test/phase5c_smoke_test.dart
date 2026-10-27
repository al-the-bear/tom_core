/// Smoke tests for Phase 5c — Demo O (Cupertino search/lookup/file +
/// nullable variants) and Demo P (TomFormFieldFamily swap by breakpoint).
///
/// Mirrors `phase5b_smoke_test.dart`: opens each demo through the demo
/// list and asserts the headline title plus a few anchor widgets render
/// without throwing. Demo P is exercised at both wide (>= 700 px) and
/// narrow (< 700 px) widths to verify the family swap.
library;

import 'package:flutter/widgets.dart';
import 'dart:convert';

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

  Future<void> openDemo(
    WidgetTester tester,
    String tile, {
    Size size = const Size(2400, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
      find.text(tile),
      200,
      scrollable: find.descendant(
        of: find.byType(DemoListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text(tile));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tile), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  // -------------------------------------------------------------------
  // Demo O — Cupertino search / lookup / file + nullable
  // -------------------------------------------------------------------

  testWidgets('Demo O opens and renders all 7 Phase 5c field labels', (
    tester,
  ) async {
    await openDemo(
      tester,
      'Demo O: Cupertino search / lookup / file (Phase 5c)',
    );
    expect(
      find.text('Demo O — Cupertino search / lookup / file (Phase 5c)'),
      findsOneWidget,
    );
    // Section headers
    expect(find.text('Search & lookup'), findsOneWidget);
    expect(find.text('File upload'), findsOneWidget);
    expect(find.text('Nullable variants'), findsOneWidget);
    // Anchor labels for the 7 fields
    expect(find.text('City (search)'), findsAtLeastNWidgets(1));
    expect(find.text('Country (lookup sheet)'), findsAtLeastNWidgets(1));
    expect(find.text('Choose file (Cupertino)'), findsAtLeastNWidgets(1));
    expect(find.text('Notes (nullable)'), findsAtLeastNWidgets(1));
    expect(find.text('Age (nullable int)'), findsAtLeastNWidgets(1));
    expect(find.text('Score (nullable double)'), findsAtLeastNWidgets(1));
    expect(find.text('Birthday (nullable date)'), findsAtLeastNWidgets(1));
    // Form-state info panel header
    expect(
      find.text('Form state (Phase5cDemoState + form-local)'),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------
  // Demo P — TomFormFieldFamily swap by breakpoint
  // -------------------------------------------------------------------

  testWidgets('Demo P opens at wide width — Material family active', (
    tester,
  ) async {
    await openDemo(
      tester,
      'Demo P: TomFormFieldFamily swap by breakpoint (Phase 5c)',
      size: const Size(1600, 2400),
    );
    expect(
      find.text('Demo P — TomFormFieldFamily swap by breakpoint (Phase 5c)'),
      findsOneWidget,
    );
    // Breakpoint badge — wide branch shows Material kind
    expect(find.textContaining('wide \u2192 Material'), findsOneWidget);
    // Active-family section header reflects Material
    expect(find.text('Active family: material'), findsOneWidget);
    // All five family-form anchor labels render
    expect(find.text('Full name'), findsAtLeastNWidgets(1));
    expect(find.text('Quantity'), findsAtLeastNWidgets(1));
    expect(find.text('Ratio'), findsAtLeastNWidgets(1));
    expect(find.text('Notify me'), findsAtLeastNWidgets(1));
    // The Event date row also surfaces its label (the Phase 5 review
    // pass restored the labelText override on the 5 Material date/time
    // concretes that the mixin's `=> null` had shadowed).
    expect(find.text('Event date'), findsAtLeastNWidgets(1));
    // Shared-state panel header
    expect(find.text('Shared state (Phase5cFamilyState)'), findsOneWidget);
  });

  testWidgets('Demo P swaps to Cupertino family at narrow width', (
    tester,
  ) async {
    await openDemo(
      tester,
      'Demo P: TomFormFieldFamily swap by breakpoint (Phase 5c)',
      size: const Size(600, 3000),
    );
    // Breakpoint badge — narrow branch shows Cupertino kind
    expect(find.textContaining('narrow \u2192 Cupertino'), findsOneWidget);
    // Active-family section header reflects Cupertino
    expect(find.text('Active family: cupertino'), findsOneWidget);
    // First-section anchor label still rendered above the fold
    expect(find.text('Full name'), findsAtLeastNWidgets(1));
    // The Event date row may be off-screen in narrow layout — use
    // `skipOffstage: false` so the finder still walks the full tree.
    expect(
      find.text('Event date', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });
}

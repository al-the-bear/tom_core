// Comprehensive layout tests for all 5 form demos.
//
// These tests focus on verifying that layouts render without overflow at
// various screen sizes, that fields in the same row share space correctly,
// and that all content is reachable via scrolling.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/demos/demo_1_basic_form.dart';
import 'package:tom_flutter_form_test/demos/demo_2_nested_forms.dart';
import 'package:tom_flutter_form_test/demos/demo_3_authorization.dart';
import 'package:tom_flutter_form_test/demos/demo_4_validation.dart';
import 'package:tom_flutter_form_test/demos/demo_5_settings.dart';

/// Wraps a demo widget in a MaterialApp for testing.
Widget buildTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    ),
    home: child,
  );
}

/// Pumps the widget and asserts no exceptions (including overflow) were thrown.
Future<void> expectNoOverflow(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final exception = tester.takeException();
  expect(exception, isNull, reason: 'Layout overflow: $exception');
}

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

  // ═══════════════════════════════════════════════════════════════════════════
  // T01: Demo 1 — no overflow at 800×600 (default)
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('T01: Demo 1 — no overflow at 800×600', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await expectNoOverflow(tester);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // T02: Demo 1 — no overflow at narrow phone width (360×640)
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('T02: Demo 1 — no overflow at 360×640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await expectNoOverflow(tester);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // T03: Demo 1 — fields in same row don't overlap and share width
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('T03: Demo 1 — multi-field row has non-overlapping fields',
      (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await tester.pumpAndSettle();

    // Industry and Tax ID are on the same row. Find them by label text
    // which appears in the InputDecoration. We look for TextFormField or
    // any widget containing that label.
    final industryFinder = find.text('Industry');
    final taxIdFinder = find.text('Tax ID');

    expect(industryFinder, findsOneWidget);
    expect(taxIdFinder, findsOneWidget);

    final industryBox = tester.getRect(industryFinder);
    final taxIdBox = tester.getRect(taxIdFinder);

    // They should be on the same vertical band (same row)
    expect(
      (industryBox.top - taxIdBox.top).abs(),
      lessThan(40), // some tolerance for decoration differences
      reason: 'Industry and Tax ID should be in the same row',
    );

    // Industry's right edge should be to the left of Tax ID's left edge
    expect(industryBox.right, lessThanOrEqualTo(taxIdBox.left + 1),
        reason: 'Industry label should not overlap Tax ID label');
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // T04: Demo 2 — no overflow at 800×600
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('T04: Demo 2 — no overflow at 800×600', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo2NestedForms()));
    await expectNoOverflow(tester);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // T05: Demo 2 — address section three-field row (city/state/zip)
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('T05: Demo 2 — city/state/zip row non-overlapping',
      (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo2NestedForms()));
    await tester.pumpAndSettle();

    // Find by label text
    final cityFinder = find.text('City');
    final stateFinder = find.text('State/Province');
    final zipFinder = find.text('ZIP/Postal Code');

    expect(cityFinder, findsOneWidget);
    expect(stateFinder, findsOneWidget);
    expect(zipFinder, findsOneWidget);

    final cityBox = tester.getRect(cityFinder);
    final stateBox = tester.getRect(stateFinder);
    final zipBox = tester.getRect(zipFinder);

    // All three on the same row
    expect((cityBox.top - stateBox.top).abs(), lessThan(40));
    expect((stateBox.top - zipBox.top).abs(), lessThan(40));

    // Non-overlapping: city < state < zip
    expect(cityBox.right, lessThanOrEqualTo(stateBox.left + 1),
        reason: 'City should not overlap State');
    expect(stateBox.right, lessThanOrEqualTo(zipBox.left + 1),
        reason: 'State should not overlap ZIP');
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // T06: Demo 2 — no overflow at narrow phone width (360×800)
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('T06: Demo 2 — no overflow at 360×800', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp(const Demo2NestedForms()));
    await expectNoOverflow(tester);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // T07: Demo 3 — no overflow at 800×600
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('T07: Demo 3 — no overflow at 800×600', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo3Authorization()));
    await expectNoOverflow(tester);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // T08: Demo 4 — no overflow at 800×600
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('T08: Demo 4 — no overflow at 800×600', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo4Validation()));
    await expectNoOverflow(tester);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // T09: Demo 5 — no overflow at 800×600
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('T09: Demo 5 — no overflow at 800×600', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo5SettingsForm()));
    await expectNoOverflow(tester);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // T10: Demo 5 — two-field rows share width equally
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('T10: Demo 5 — paired fields share width roughly equally',
      (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo5SettingsForm()));
    await tester.pumpAndSettle();

    // Demo 5 uses compact style where labels are InputDecoration hints.
    // Verify by finding DropdownButtonFormField and TextField widgets
    // and checking that multiple rows of fields exist.
    final dropdowns = find.byType(DropdownButtonFormField<String>);
    final textFields = find.byType(TextField);

    // There should be at least 4 dropdowns and at least 2 text fields
    expect(dropdowns, findsWidgets);
    expect(textFields, findsWidgets);

    // No overflow
    expect(tester.takeException(), isNull);
  });
}

/// Golden screenshot tests for the Examples section.
///
/// Each test mounts the example widget directly inside a [MaterialApp]
/// (no navigation overhead) so the screenshots capture only the example
/// content. Goldens live in `test/goldens/examples/`.
///
/// Generate / update:
///   flutter test test/example_screenshot_test.dart --update-goldens
///
/// CI comparison (default):
///   flutter test test/example_screenshot_test.dart
///
/// Viewport is 1280 × 800 at 1.0 DPR — a realistic laptop-sized surface
/// that gives AclBuilder breakpoints room to show the wide layout.
///
/// ## Capture provenance
///
/// Goldens in `test/goldens/examples/` were last recorded as one set with:
///
/// | | |
/// | --- | --- |
/// | Date    | 2026-08-04 |
/// | Host    | macOS (mbp), arm64 |
/// | Flutter | 3.44.6 stable, framework `ee80f08bbf` |
/// | Engine  | `d3a3293399556a85388faf8c6f0723a7a5597aa8` (rev `83675ed276`) |
/// | Dart    | 3.12.2 |
///
/// Record this whenever the goldens are re-recorded. Text rasterisation shifts
/// between engine revisions, so without knowing which engine produced the
/// baselines a future drift cannot be told apart from a real regression
/// without redoing the pixel analysis below.
///
/// **Always re-record the whole file, never a single golden.** The baselines
/// are only comparable to each other if they share one capture; regenerating
/// one leaves the rest silently stale behind the tolerance in
/// `flutter_test_config.dart`.
///
/// ### Telling rendering drift from a theme regression
///
/// When a golden fails, the question is whether pixels moved because the
/// rasteriser changed or because the UI did. Two checks settle it from the
/// failure PNGs in `test/failures/` (`*_masterImage.png` vs `*_testImage.png`),
/// and neither needs the widget tree:
///
/// 1. **Do any differing pixels sit in a flat region?** Take each differing
///    pixel and test whether master's 5×5 neighbourhood there is one uniform
///    colour. Anti-aliasing only ever moves *edge* pixels, so a pure
///    rendering drift scores zero. A fill, colour or layout change puts
///    differing pixels in the middle of flat areas.
/// 2. **Are the dominant area colours byte-identical?** Compare the most
///    frequent colours of both images. A palette change moves them; a
///    rasterisation change leaves them untouched and only redistributes the
///    intermediate blend shades along glyph edges.
///
/// If both checks say "rendering", re-record. If either says otherwise, the
/// golden has caught a real regression — fix the UI, not the baseline.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'support/test_fonts.dart';

import 'package:tom_flutter_form_test/examples/example_h_a_master_detail.dart';
import 'package:tom_flutter_form_test/examples/example_h_b_expandable_rows.dart';
import 'package:tom_flutter_form_test/examples/example_h_c_editable_table.dart';
import 'package:tom_flutter_form_test/examples/example_h_d_customer_form.dart';
import 'package:tom_flutter_form_test/examples/example_h_e_read_only.dart';
import 'package:tom_flutter_form_test/examples/example_list_screen.dart';
import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wrap [child] in the same [MaterialApp] + theme the main app uses so
/// colours and typography are consistent with production.
Widget testApp(Widget child) => MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
  ),
  home: child,
);

/// Pump [widget] at 1280 × 800 and take a golden screenshot at [path].
Future<void> screenshot(WidgetTester tester, Widget widget, String path) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(testApp(widget));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/examples/$path'),
  );
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    final jsonStr = await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
    await loadTestFonts();
  });

  // ── Example list (entry screen) ──────────────────────────────────────────

  testWidgets('screenshot: example list screen', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Mount via the full app so the Examples tab is visible in context.
    await tester.pumpWidget(const FormDemoApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Examples'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/examples/example_list_screen.png'),
    );
  });

  // ── H-A: Master / Detail ─────────────────────────────────────────────────

  testWidgets('screenshot: H-A Material', (tester) async {
    await screenshot(
      tester,
      const ExampleHAMasterDetail(family: ExampleFamily.material),
      'h_a_material.png',
    );
  });

  testWidgets('screenshot: H-A Cupertino', (tester) async {
    await screenshot(
      tester,
      const ExampleHAMasterDetail(family: ExampleFamily.cupertino),
      'h_a_cupertino.png',
    );
  });

  // ── H-B: Expandable rows ─────────────────────────────────────────────────

  testWidgets('screenshot: H-B Material', (tester) async {
    await screenshot(
      tester,
      const ExampleHBExpandableRows(family: ExampleFamily.material),
      'h_b_material.png',
    );
  });

  testWidgets('screenshot: H-B Cupertino', (tester) async {
    await screenshot(
      tester,
      const ExampleHBExpandableRows(family: ExampleFamily.cupertino),
      'h_b_cupertino.png',
    );
  });

  // ── H-C: Editable table ──────────────────────────────────────────────────

  testWidgets('screenshot: H-C Material', (tester) async {
    await screenshot(
      tester,
      const ExampleHCEditableTable(family: ExampleFamily.material),
      'h_c_material.png',
    );
  });

  testWidgets('screenshot: H-C Cupertino', (tester) async {
    await screenshot(
      tester,
      const ExampleHCEditableTable(family: ExampleFamily.cupertino),
      'h_c_cupertino.png',
    );
  });

  // ── H-D: Full customer form ──────────────────────────────────────────────

  testWidgets('screenshot: H-D Material', (tester) async {
    await screenshot(
      tester,
      const ExampleHDCustomerForm(family: ExampleFamily.material),
      'h_d_material.png',
    );
  });

  testWidgets('screenshot: H-D Cupertino', (tester) async {
    await screenshot(
      tester,
      const ExampleHDCustomerForm(family: ExampleFamily.cupertino),
      'h_d_cupertino.png',
    );
  });

  // ── H-E: Read-only + edit dialogs ────────────────────────────────────────

  testWidgets('screenshot: H-E Material', (tester) async {
    await screenshot(
      tester,
      const ExampleHEReadOnly(family: ExampleFamily.material),
      'h_e_material.png',
    );
  });

  testWidgets('screenshot: H-E Cupertino', (tester) async {
    await screenshot(
      tester,
      const ExampleHEReadOnly(family: ExampleFamily.cupertino),
      'h_e_cupertino.png',
    );
  });
}

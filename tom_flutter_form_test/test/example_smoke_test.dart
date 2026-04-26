/// Smoke tests for all 10 example screens (H-A through H-E × Material /
/// Cupertino).
///
/// Each test mounts the example widget directly (no navigation overhead) so
/// exceptions surface clearly.  Tests pass when the widget pumps without any
/// unhandled FlutterError — overflow, binding errors, or LateInitialization
/// failures all cause test failure.
///
/// Viewport: 1280 × 800 at 1.0 DPR.  Wide enough to show master-detail side-
/// by-side and activates the "wide" layout paths in AclBuilder.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'package:tom_flutter_form_test/examples/example_h_a_master_detail.dart';
import 'package:tom_flutter_form_test/examples/example_h_b_expandable_rows.dart';
import 'package:tom_flutter_form_test/examples/example_h_c_editable_table.dart';
import 'package:tom_flutter_form_test/examples/example_h_d_customer_form.dart';
import 'package:tom_flutter_form_test/examples/example_h_e_read_only.dart';
import 'package:tom_flutter_form_test/examples/example_list_screen.dart';
import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: child,
    );

Future<void> _pump(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_wrap(widget));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Font loading — mirrors screenshot_tests.dart so text metrics are
// identical between smoke and golden tests. Without this, the Ahem test
// font causes taller text, which shrinks Expanded children and produces
// spurious overflow errors.
// ---------------------------------------------------------------------------

Future<void> _loadRealFonts() async {
  const robotoDir =
      '/srv/flutter/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto';
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final file = File('$robotoDir/$name');
    if (file.existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
      await loader.load();
    }
  }
  final iconsFile = File(
      '/srv/flutter/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (iconsFile.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(
          Future.value(ByteData.view(iconsFile.readAsBytesSync().buffer)));
    await loader.load();
  }
}

// ---------------------------------------------------------------------------
// Shared setup
// ---------------------------------------------------------------------------

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
    await _loadRealFonts();
  });

  // ── Example list screen ─────────────────────────────────────────────────

  testWidgets('Example list screen renders all section headers', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Mount via FormDemoApp so the full tab navigation is present.
    await tester.pumpWidget(const FormDemoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Examples'));
    await tester.pumpAndSettle();

    expect(find.text('Examples'), findsAtLeastNWidgets(1));
    expect(find.text('H-A — Master / Detail'), findsOneWidget);
    expect(find.text('H-B — Expandable rows'), findsOneWidget);
  });

  // ── H-A: Master / Detail ─────────────────────────────────────────────────

  testWidgets('H-A Material — mounts without exceptions', (tester) async {
    await _pump(
        tester, const ExampleHAMasterDetail(family: ExampleFamily.material));
    // Seed data: Ada Lovelace should appear in the master pane and detail pane.
    expect(find.textContaining('Ada Lovelace'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Full name'), findsAtLeastNWidgets(1));
  });

  testWidgets('H-A Cupertino — mounts without exceptions', (tester) async {
    await _pump(
        tester, const ExampleHAMasterDetail(family: ExampleFamily.cupertino));
    expect(find.textContaining('Ada Lovelace'), findsAtLeastNWidgets(1));
  });

  // ── H-B: Expandable rows ─────────────────────────────────────────────────

  testWidgets('H-B Material — mounts without exceptions', (tester) async {
    await _pump(
        tester, const ExampleHBExpandableRows(family: ExampleFamily.material));
    // Header shows the customer name; row summary shows order id.
    expect(find.textContaining('Ada Lovelace'), findsAtLeastNWidgets(1));
    expect(find.textContaining('ORD-'), findsAtLeastNWidgets(1));
  });

  testWidgets('H-B Cupertino — mounts without exceptions', (tester) async {
    await _pump(
        tester, const ExampleHBExpandableRows(family: ExampleFamily.cupertino));
    expect(find.textContaining('Ada Lovelace'), findsAtLeastNWidgets(1));
  });

  // ── H-C: Editable table ──────────────────────────────────────────────────

  testWidgets('H-C Material — mounts without exceptions', (tester) async {
    await _pump(
        tester, const ExampleHCEditableTable(family: ExampleFamily.material));
    // Wide viewport: table header columns should be visible.
    expect(find.text('Items'), findsOneWidget);
    expect(find.textContaining('Difference Engine'), findsAtLeastNWidgets(1));
  });

  testWidgets('H-C Cupertino — mounts without exceptions', (tester) async {
    await _pump(
        tester, const ExampleHCEditableTable(family: ExampleFamily.cupertino));
    expect(find.text('Items'), findsOneWidget);
  });

  // ── H-D: Full customer form ──────────────────────────────────────────────

  testWidgets('H-D Material — mounts without exceptions', (tester) async {
    await _pump(
        tester, const ExampleHDCustomerForm(family: ExampleFamily.material));
    expect(find.textContaining('Ada Lovelace'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Full name'), findsAtLeastNWidgets(1));
  });

  testWidgets('H-D Cupertino — mounts without exceptions', (tester) async {
    await _pump(
        tester, const ExampleHDCustomerForm(family: ExampleFamily.cupertino));
    expect(find.textContaining('Ada Lovelace'), findsAtLeastNWidgets(1));
  });

  // ── H-E: Read-only + edit dialogs ────────────────────────────────────────

  testWidgets('H-E Material — mounts without exceptions', (tester) async {
    await _pump(
        tester, const ExampleHEReadOnly(family: ExampleFamily.material));
    expect(find.textContaining('Ada Lovelace'), findsAtLeastNWidgets(1));
    expect(find.textContaining('ada@analytical'), findsAtLeastNWidgets(1));
  });

  testWidgets('H-E Cupertino — mounts without exceptions', (tester) async {
    await _pump(
        tester, const ExampleHEReadOnly(family: ExampleFamily.cupertino));
    expect(find.textContaining('Ada Lovelace'), findsAtLeastNWidgets(1));
  });
}

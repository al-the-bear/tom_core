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
// Helpers
// ---------------------------------------------------------------------------

/// Load Roboto + MaterialIcons from the local Flutter SDK so that golden
/// screenshots render readable text instead of Ahem blocks.
Future<void> loadRealFonts() async {
  const robotoDir =
      '/srv/flutter/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto';
  const variants = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
  ];
  for (final name in variants) {
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
Future<void> screenshot(
  WidgetTester tester,
  Widget widget,
  String path,
) async {
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
    final jsonStr =
        await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
    await loadRealFonts();
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

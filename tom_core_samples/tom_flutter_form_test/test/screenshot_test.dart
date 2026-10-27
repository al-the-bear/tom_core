// Golden screenshot tests for all 5 form demos.
//
// Rebaseline with: flutter test test/screenshot_test.dart --update-goldens
// Generated PNGs go to: test/goldens/

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

import 'support/test_fonts.dart';

Widget buildTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    ),
    home: child,
  );
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
    await loadTestFonts();
  });

  // ── Demo 1: Basic Form ─────────────────────────────────────────────────

  testWidgets('Screenshot: Demo 1 Basic Form (800×600)', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/demo1_basic_form.png'),
    );
  });

  // ── Demo 2: Nested Forms ───────────────────────────────────────────────

  testWidgets('Screenshot: Demo 2 Nested Forms (800×600)', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo2NestedForms()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/demo2_nested_forms.png'),
    );
  });

  // ── Demo 3: Authorization ──────────────────────────────────────────────

  testWidgets('Screenshot: Demo 3 Authorization (800×600)', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo3Authorization()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/demo3_authorization.png'),
    );
  });

  // ── Demo 4: Validation ─────────────────────────────────────────────────

  testWidgets('Screenshot: Demo 4 Validation (800×600)', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo4Validation()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/demo4_validation.png'),
    );
  });

  // ── Demo 5: Settings Form ─────────────────────────────────────────────

  testWidgets('Screenshot: Demo 5 Settings Form (800×600)', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo5SettingsForm()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/demo5_settings_form.png'),
    );
  });
}

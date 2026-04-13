// Golden screenshot tests for all 5 form demos.
//
// Run with: flutter test test/screenshot_tests.dart --update-goldens
// Generated PNGs go to: test/goldens/

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/demos/demo_1_basic_form.dart';
import 'package:tom_flutter_form_test/demos/demo_2_nested_forms.dart';
import 'package:tom_flutter_form_test/demos/demo_3_authorization.dart';
import 'package:tom_flutter_form_test/demos/demo_4_validation.dart';
import 'package:tom_flutter_form_test/demos/demo_5_settings.dart';

/// Load real fonts so golden screenshots render readable text instead of
/// black Ahem blocks.
Future<void> loadRealFonts() async {
  const fontDir =
      '/srv/flutter/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto';
  final variants = <(String, int)>[
    ('Roboto-Regular.ttf', 400),
    ('Roboto-Medium.ttf', 500),
    ('Roboto-Bold.ttf', 700),
    ('Roboto-Light.ttf', 300),
    ('Roboto-Thin.ttf', 100),
    ('Roboto-Black.ttf', 900),
  ];
  for (final (fileName, weight) in variants) {
    final file = File('$fontDir/$fileName');
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      final fontLoader = FontLoader('Roboto');
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await fontLoader.load();
    }
  }
  // Also load MaterialIcons so icons render properly.
  final iconsFile =
      File('/srv/flutter/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (iconsFile.existsSync()) {
    final bytes = iconsFile.readAsBytesSync();
    final fontLoader = FontLoader('MaterialIcons');
    fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await fontLoader.load();
  }
}

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
    initializeReflection();
    await loadRealFonts();
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

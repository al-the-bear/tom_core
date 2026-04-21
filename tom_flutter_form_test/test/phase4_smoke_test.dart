/// Smoke tests for Phase 4 demos (K enum/object/lookup, L file/nullable).
/// Mirrors phase3_smoke_test.dart — opens each demo through the demo
/// list and asserts the headline title plus one or two anchor widgets
/// render without throwing.
library;

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
    final jsonStr =
        await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  Future<void> openDemo(WidgetTester tester, String tile) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(find.text(tile), 200);
    await tester.tap(find.text(tile));
    await tester.pumpAndSettle();
  }

  testWidgets('Demo K opens with enum/object/lookup sections', (tester) async {
    await openDemo(tester, 'Demo K: Enum, Object & Lookup');
    expect(find.text('Demo K — Enum, Object & Lookup'), findsOneWidget);
    // Section headers from _section() titles.
    expect(find.text('Enum (Priority) — single-select variants'),
        findsOneWidget);
    expect(find.text('Search (City) — ~5 000-item source'), findsOneWidget);
    expect(find.text('Lookup dialog (Country) — modal browse'),
        findsOneWidget);
  });

  testWidgets('Demo L opens with file fields + nullable subform',
      (tester) async {
    await openDemo(tester, 'Demo L: Files & Nullable Variants');
    expect(find.text('Demo L — File + Nullable Variants'), findsOneWidget);
    expect(find.text('File fields — upload + dropzone'), findsOneWidget);
    expect(find.text('Nullable input variants'), findsOneWidget);
    // State-action affordances exposed in the bottom card.
    expect(find.text('Reset (pristine)'), findsOneWidget);
    expect(find.text('Set all (non-null)'), findsOneWidget);
    expect(find.text('Set all → null'), findsOneWidget);
  });
}

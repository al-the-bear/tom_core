/// Smoke tests for Phase 3 demos (I numeric, J date/time/duration).
/// Mirrors phase1_smoke_test.dart — opens each demo through the demo
/// list and asserts the headline title plus one or two anchor widgets
/// render without throwing.
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

  Future<void> openDemo(WidgetTester tester, String tile) async {
    tester.view.physicalSize = const Size(2400, 1600);
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
    // scrollUntilVisible only guarantees the tile is in the tree; tiles
    // near the list's end can straddle the viewport bottom. ensureVisible
    // nudges it on-screen, and we tap the ListTile ancestor (full-row hit
    // target) rather than the Text node — the Text box can stay clipped by
    // the card padding so a tap on it silently misses.
    await tester.ensureVisible(find.text(tile));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: find.text(tile), matching: find.byType(ListTile)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Demo I opens with numeric inputs + sliders', (tester) async {
    await openDemo(tester, 'Demo I: Numeric Forms');
    expect(find.text('Demo I — Numeric Forms'), findsOneWidget);
    // Section headers
    expect(find.text('Shared TomInt — input ↔ slider'), findsOneWidget);
    expect(find.text('Currency input'), findsOneWidget);
    expect(find.text('Range sliders'), findsOneWidget);
  });

  testWidgets('Demo J opens with date/time pickers + duration row', (
    tester,
  ) async {
    await openDemo(tester, 'Demo J: Date/Time/Duration Forms');
    expect(find.text('Demo J — Date/Time/Duration Forms'), findsOneWidget);
    expect(find.text('Dialog pickers'), findsOneWidget);
    expect(find.text('Duration vs. minute slider'), findsOneWidget);
  });
}

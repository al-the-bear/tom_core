/// Smoke tests for Phase 5b — Demo N (Cupertino numeric + date/time).
///
/// Mirrors `phase5_smoke_test.dart`: opens Demo N through the demo list
/// and asserts the headline title plus a few anchor widgets render
/// without throwing.
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
    final jsonStr =
        await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  Future<void> openDemo(WidgetTester tester, String tile,
      {Size size = const Size(2400, 2400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(find.text(tile), 200);
    await tester.ensureVisible(find.text(tile));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tile), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets('Demo N opens and renders all 9 Phase 5b field labels',
      (tester) async {
    await openDemo(
        tester, 'Demo N: Cupertino numeric + date/time (Phase 5b)');
    expect(
      find.text('Demo N — Cupertino numeric + date/time (Phase 5b)'),
      findsOneWidget,
    );
    // Section headers
    expect(find.text('Numeric'), findsOneWidget);
    expect(find.text('Date / Time / Duration'), findsOneWidget);
    expect(find.text('Range'), findsOneWidget);
    // Anchor labels for each of the 9 concretes
    expect(find.text('Quantity (int input)'), findsAtLeastNWidgets(1));
    expect(find.text('Brightness (int picker)'), findsAtLeastNWidgets(1));
    expect(find.text('Ratio (double input)'), findsAtLeastNWidgets(1));
    expect(find.text('Price (currency)'), findsAtLeastNWidgets(1));
    expect(find.text('Event date'), findsAtLeastNWidgets(1));
    expect(find.text('Event time'), findsAtLeastNWidgets(1));
    expect(find.text('Event date+time'), findsAtLeastNWidgets(1));
    expect(find.text('Planned downtime'), findsAtLeastNWidgets(1));
    expect(find.text('Billing period'), findsAtLeastNWidgets(1));
    // Form-state info panel header
    expect(
      find.text('Form state (Phase5bDemoState + form-local)'),
      findsOneWidget,
    );
  });

  testWidgets('Demo N breakpoint badge reflects wide vs narrow widths',
      (tester) async {
    // Wide layout — width >= 700px → "wide (light/airy)" themeSpec
    await openDemo(
        tester, 'Demo N: Cupertino numeric + date/time (Phase 5b)',
        size: const Size(1600, 2400));
    expect(
      find.textContaining('wide (light/airy)'),
      findsOneWidget,
    );
  });

  testWidgets('Demo N narrow layout swaps inner themeSpec', (tester) async {
    // Narrow layout — width < 700px → "narrow (dense/dark)" themeSpec.
    // Use a tall viewport so the tile in the demo list is reachable.
    await openDemo(
        tester, 'Demo N: Cupertino numeric + date/time (Phase 5b)',
        size: const Size(600, 3000));
    expect(
      find.textContaining('narrow (dense/dark)'),
      findsOneWidget,
    );
    // First-section anchor label still rendered above the fold.
    expect(find.text('Quantity (int input)'), findsAtLeastNWidgets(1));
    // The Billing period row may be off-screen in narrow layout — use
    // `skipOffstage: false` so the finder still walks the full tree.
    expect(
      find.text('Billing period', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });
}

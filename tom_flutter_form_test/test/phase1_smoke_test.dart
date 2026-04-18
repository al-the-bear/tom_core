/// Smoke tests for the Phase 1 demos (A, B, C) — opens each demo through
/// normal navigation and verifies it renders without throwing.
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
    // A wide logical viewport keeps the two-column layout active and
    // removes the need to scroll nested panels.
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(find.text(tile), 200);
    await tester.tap(find.text(tile));
    await tester.pumpAndSettle();
  }

  testWidgets('Demo A opens and renders the form', (tester) async {
    await openDemo(tester, 'Demo A: Lifecycle & Validation');
    expect(find.text('Demo A — Lifecycle & Validation'), findsOneWidget);
    // Field-state table exposes the username row.
    expect(find.text('username'), findsWidgets);
  });

  testWidgets('Demo B opens with nested billing/shipping', (tester) async {
    await openDemo(tester, 'Demo B: Authorization & Events');
    expect(find.text('Demo B — Authorization & Events'), findsOneWidget);
    expect(find.text('Billing address'), findsOneWidget);
    expect(find.text('Shipping address'), findsOneWidget);
  });

  testWidgets('Demo C opens and shows the theming panel', (tester) async {
    await openDemo(tester, 'Demo C: Nested Forms & Theming');
    expect(find.text('Demo C — Nested Forms & Theming'), findsOneWidget);
    expect(find.text('Theming controls'), findsOneWidget);
    expect(find.text('Form inspection'), findsOneWidget);
    // Resources should supply descriptions on at least one field — this
    // check guards against future accidental removal of demoC resource
    // entries that would make the theming toggles a no-op.
    expect(find.text('Primary contact for order updates.'), findsOneWidget,
        reason: 'demoC.customer.email.description must resolve to text.');
  });
}

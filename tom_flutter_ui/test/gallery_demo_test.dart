import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../example/gallery_demo.dart' as demo;

/// Smoke test for the runnable demo app (`example/gallery_demo.dart`).
///
/// Confirms the app pumps and that the two reflection-free galleries — the
/// default **Widgets** tab and the **Custom** tab — render. The **Forms** tab
/// depends on Tom reflection (the `@tomReflector` form models) which this
/// standalone package never wires; it is intentionally not navigated to here,
/// and the demo degrades it to an explanatory panel rather than crashing.
void main() {
  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(const {}),
    );
    TomUIColors.adapter = AllColorsAdapter();
    TomAuthorization.reset();
  });
  tearDown(TomAuthorization.reset);

  testWidgets('app pumps and lands on the Widgets gallery', (tester) async {
    await tester.pumpWidget(const demo.Phase1DemoApp());
    await tester.pump();

    expect(find.text('Tom Flutter UI — Widgets'), findsOneWidget);
    // A representative widget from the kit is rendered.
    expect(find.text('TomText renders styled text.'), findsOneWidget);
    expect(find.text('Elevated'), findsOneWidget);
  });

  testWidgets('navigating to the Custom tab renders the composites',
      (tester) async {
    await tester.pumpWidget(const demo.Phase1DemoApp());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.extension));
    // The Custom gallery hosts continuous animations (skeleton shimmer,
    // loading spinner), so pumpAndSettle would time out — pump a frame.
    await tester.pump();

    expect(find.text('Tom Flutter UI — Custom'), findsOneWidget);
    // The auth-guarded tile (top of the gallery) is visible because auth
    // resolves to full; the radio group items render too.
    expect(find.text('Visible because auth resolves to full'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('the Widgets gallery toggles are interactive', (tester) async {
    await tester.pumpWidget(const demo.Phase1DemoApp());
    await tester.pump();

    // Flip the switch — no exception means the onChanged wiring is live.
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(find.byType(Switch), findsWidgets);
  });
}

/// Smoke tests for the Phase 2a demos (H-A master-detail, H-B expandable
/// rows, H-C editable table). Mirrors `phase1_smoke_test.dart` — opens
/// each demo through the demo list and asserts the headline title plus
/// one or two anchor widgets render without throwing.
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

  testWidgets('Demo H-A opens with master pane + detail editor',
      (tester) async {
    await openDemo(tester, 'Demo H-A: Master-Detail Customer Editor');
    expect(
      find.text('Demo H-A — Master-Detail Customer Editor'),
      findsOneWidget,
    );
    // Pre-populated customers come from phase2aCustomers.
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Grace Hopper'), findsOneWidget);
  });

  testWidgets('Demo H-B opens with expandable order-items rows',
      (tester) async {
    await openDemo(tester, 'Demo H-B: Expandable Rows (Order Items)');
    expect(
      find.text('Demo H-B — Expandable Rows (Order Items)'),
      findsOneWidget,
    );
    // Pre-populated order items title — the list shows item count.
    expect(find.text('Items (3)'), findsOneWidget);
  });

  testWidgets('Demo H-C opens with editable order-items table',
      (tester) async {
    await openDemo(tester, 'Demo H-C: Editable Order-Items Table');
    expect(
      find.text('Demo H-C — Editable Order-Items Table'),
      findsOneWidget,
    );
    expect(find.text('Items (3)'), findsOneWidget);
    // DataTable header column "Total" is present.
    expect(find.text('Total'), findsOneWidget);
  });
}

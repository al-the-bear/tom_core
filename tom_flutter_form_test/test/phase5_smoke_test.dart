/// Smoke tests for Phase 5 demos. Mirrors `phase4_smoke_test.dart` —
/// opens each Phase 5 demo through the demo list and asserts the
/// headline title plus a few anchor widgets render without throwing.
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

  testWidgets('Demo M opens with both Material and Cupertino panels',
      (tester) async {
    await openDemo(tester, 'Demo M: Material vs Cupertino (Phase 5a)');
    expect(find.text('Demo M — Material vs Cupertino (Phase 5a)'),
        findsOneWidget);
    expect(find.text('Material concretes'), findsOneWidget);
    expect(find.text('Cupertino concretes'), findsOneWidget);
    // Header bar lets the user swap the page-root style.
    expect(find.text('TomFormStyle.material3'), findsOneWidget);
    expect(find.text('TomCupertinoFormStyle.cupertino'), findsOneWidget);
    // The shared state column lists every paired property.
    expect(find.text('Shared state (Phase5DemoState)'), findsOneWidget);
  });

  testWidgets('Demo M cupertino style chip swaps the active scope style',
      (tester) async {
    await openDemo(tester, 'Demo M: Material vs Cupertino (Phase 5a)');
    // Tapping the cupertino chip should not throw and should leave both
    // panels still rendered (anatomy reflows but widgets persist).
    await tester.tap(find.text('TomCupertinoFormStyle.cupertino'));
    await tester.pumpAndSettle();
    expect(find.text('Material concretes'), findsOneWidget);
    expect(find.text('Cupertino concretes'), findsOneWidget);
  });
}

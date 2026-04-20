// Basic widget test for Form Demo App

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
    final jsonStr = await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  testWidgets('Demo list screen shows all demos', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FormDemoApp());

    // All tiles are present — scroll each into view before asserting so
    // the test works regardless of default viewport height. Phase 1 demos
    // (A/B/C) sit above the legacy numbered ones.
    for (final label in const [
      'Demo A: Lifecycle & Validation',
      'Demo B: Authorization & Events',
      'Demo C: Nested Forms & Theming',
      'Demo D: Hide on Authorization',
      'Demo 1: Basic Form',
      'Demo 2: Nested Forms',
      'Demo 3: Authorization',
      'Demo 4: Validation',
      'Demo 5: Settings Form',
      'Demo 6: Field Layout Options',
      'Demo 7: Error Placement',
      'Demo 8: Breakpoints',
      'Demo 9: Preset Showcase',
      'Demo 10: Central JSON-Driven Style',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 200);
      expect(find.text(label), findsOneWidget);
    }
  });
}

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

    // Verify demo tiles are present
    expect(find.text('Demo 1: Basic Form'), findsOneWidget);
    expect(find.text('Demo 2: Nested Forms'), findsOneWidget);
    expect(find.text('Demo 3: Authorization'), findsOneWidget);
    expect(find.text('Demo 4: Validation'), findsOneWidget);
    expect(find.text('Demo 5: Settings Form'), findsOneWidget);

    for (final label in const [
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

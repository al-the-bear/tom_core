// Basic widget test for Form Demo App

import 'package:flutter_test/flutter_test.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/reflection_init.dart';

void main() {
  setUpAll(() {
    initializeReflection();
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
  });
}

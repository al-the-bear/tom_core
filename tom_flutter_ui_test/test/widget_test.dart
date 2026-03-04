// Widget tests for the ACL Demo application.

import 'package:flutter_test/flutter_test.dart';

import 'package:tom_flutter_ui_test/main.dart';

void main() {
  testWidgets('App loads and shows demo list', (WidgetTester tester) async {
    await tester.pumpWidget(const AclDemoApp());

    // Verify the home page title is displayed
    expect(find.text('ACL Layout Demos'), findsOneWidget);

    // Verify some demo tiles are shown
    expect(find.text('Basic Row Layout'), findsOneWidget);
    expect(find.text('Multiple Rows'), findsOneWidget);
    expect(find.text('Row Alignment'), findsOneWidget);
  });

  testWidgets('Can navigate to Basic Row demo', (WidgetTester tester) async {
    await tester.pumpWidget(const AclDemoApp());

    // Tap on the Basic Row Layout tile
    await tester.tap(find.text('Basic Row Layout'));
    await tester.pumpAndSettle();

    // Verify we're on the demo page
    expect(find.text('Basic row with three components:'), findsOneWidget);
  });
}

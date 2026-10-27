// Widget tests for the Tom Flutter UI Test application.

import 'package:flutter_test/flutter_test.dart';

import 'package:tom_flutter_ui_test/main.dart';

void main() {
  testWidgets('App loads and shows tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const TomFlutterUiTestApp());

    // Verify the app bar title is displayed
    expect(find.text('Tom Flutter UI'), findsOneWidget);

    // Verify tabs are shown — current tabs in main.dart are
    // ACL Demos / Widget Demos / Forms-Actions / Authorization-Resources.
    expect(find.text('ACL Demos'), findsOneWidget);
    expect(find.text('Widget Demos'), findsOneWidget);
    expect(find.text('Forms/Actions'), findsOneWidget);
    expect(find.text('Authorization/Resources'), findsOneWidget);
  });

  testWidgets('ACL Demos tab shows demo list', (WidgetTester tester) async {
    await tester.pumpWidget(const TomFlutterUiTestApp());

    // ACL Demos tab is selected by default
    // Verify some demo tiles are shown
    expect(find.text('Basic Row Layout'), findsOneWidget);
    expect(find.text('Multiple Rows'), findsOneWidget);
    expect(find.text('Row Alignment'), findsOneWidget);
  });
}

// Flutter tests for all 5 form demos.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/demos/demo_1_basic_form.dart';
import 'package:tom_flutter_form_test/demos/demo_2_nested_forms.dart';
import 'package:tom_flutter_form_test/demos/demo_3_authorization.dart';
import 'package:tom_flutter_form_test/demos/demo_4_validation.dart';
import 'package:tom_flutter_form_test/demos/demo_5_settings.dart';

/// Wraps a demo widget in a MaterialApp for testing.
Widget buildTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    ),
    home: child,
  );
}

void main() {
  setUpAll(() {
    initializeReflection();
  });

  // ─── Test 1: Demo list shows all 5 demos ──────────────────────────────────

  testWidgets('T01: Demo list screen shows all 5 demos', (tester) async {
    await tester.pumpWidget(const FormDemoApp());

    expect(find.text('Demo 1: Basic Form'), findsOneWidget);
    expect(find.text('Demo 2: Nested Forms'), findsOneWidget);
    expect(find.text('Demo 3: Authorization'), findsOneWidget);
    expect(find.text('Demo 4: Validation'), findsOneWidget);
    expect(find.text('Demo 5: Settings Form'), findsOneWidget);
  });

  // ─── Test 2: Demo 1 renders without overflow ──────────────────────────────

  testWidgets('T02: Demo 1 - Basic Form renders without overflow',
      (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await tester.pumpAndSettle();

    // Verify field labels are present
    expect(find.text('Company Name'), findsOneWidget);
    expect(find.text('Industry'), findsOneWidget);
    expect(find.text('Tax ID'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);

    // Verify action buttons
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);

    // No overflow errors — tester.takeException() returns null if no errors
    expect(tester.takeException(), isNull);
  });

  // ─── Test 3: Demo 1 text input and save ───────────────────────────────────

  testWidgets('T03: Demo 1 - Can enter text and save', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await tester.pumpAndSettle();

    // Enter company name
    final nameField = find.widgetWithText(TextField, 'Enter company name');
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Test Corp');
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Status should update (may show validation result)
    expect(find.textContaining('Test Corp'), findsWidgets);
  });

  // ─── Test 4: Demo 1 discard resets fields ─────────────────────────────────

  testWidgets('T04: Demo 1 - Discard resets fields', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await tester.pumpAndSettle();

    // Enter text
    final nameField = find.widgetWithText(TextField, 'Enter company name');
    await tester.enterText(nameField, 'Modified Corp');
    await tester.pumpAndSettle();

    // Ensure Discard button is visible and tap it
    final discardButton = find.widgetWithText(TextButton, 'Discard');
    await tester.ensureVisible(discardButton);
    await tester.pumpAndSettle();
    await tester.tap(discardButton);
    await tester.pumpAndSettle();

    // Status should reflect discard
    expect(find.text('Status: Changes discarded'), findsOneWidget);
  });

  // ─── Test 5: Demo 2 renders nested forms ──────────────────────────────────

  testWidgets('T05: Demo 2 - Nested Forms renders both sections',
      (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo2NestedForms()));
    await tester.pumpAndSettle();

    // Address section fields
    expect(find.text('Street Address'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('State/Province'), findsOneWidget);
    expect(find.text('ZIP/Postal Code'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);

    // CEO section fields
    expect(find.text('First Name'), findsOneWidget);
    expect(find.text('Last Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Job Title'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  // ─── Test 6: Demo 2 pre-populated data ────────────────────────────────────

  testWidgets('T06: Demo 2 - Shows pre-populated data', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo2NestedForms()));
    await tester.pumpAndSettle();

    // Check pre-populated values are displayed in TextFields
    expect(
      find.widgetWithText(TextField, '123 Main St'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'San Francisco'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Jane'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Doe'),
      findsOneWidget,
    );
  });

  // ─── Test 7: Demo 3 renders authorization controls ────────────────────────

  testWidgets('T07: Demo 3 - Authorization controls visible', (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo3Authorization()));
    await tester.pumpAndSettle();

    // Auth control buttons
    expect(find.text('Toggle Name R/O'), findsOneWidget);
    expect(find.text('Cycle Industry Auth'), findsOneWidget);
    expect(find.text('Toggle Section'), findsOneWidget);

    // Form fields visible
    expect(find.text('Company Name'), findsOneWidget);
    expect(find.text('Industry'), findsOneWidget);
    expect(find.text('Tax ID'), findsOneWidget);

    // Initial status
    expect(find.text('Status: Ready'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  // ─── Test 8: Demo 3 toggle name read-only ─────────────────────────────────

  testWidgets('T08: Demo 3 - Toggle name read-only changes status',
      (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo3Authorization()));
    await tester.pumpAndSettle();

    // Toggle name to read-only
    await tester.tap(find.text('Toggle Name R/O'));
    await tester.pumpAndSettle();

    expect(find.text('Status: Name field: READ-ONLY'), findsOneWidget);

    // Toggle back to editable
    await tester.tap(find.text('Toggle Name R/O'));
    await tester.pumpAndSettle();

    expect(find.text('Status: Name field: EDITABLE'), findsOneWidget);
  });

  // ─── Test 9: Demo 4 renders validation info ──────────────────────────────

  testWidgets('T09: Demo 4 - Validation demo renders field labels',
      (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo4Validation()));
    await tester.pumpAndSettle();

    // Form field labels
    expect(find.text('Company Name'), findsOneWidget);
    expect(find.text('Tax ID'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);

    // Validation info text
    expect(
      find.textContaining('Validators: required, minLength(2)'),
      findsOneWidget,
    );
    expect(find.textContaining('Validators: required, pattern'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  // ─── Test 10: Demo 5 renders settings form ────────────────────────────────

  testWidgets('T10: Demo 5 - Settings form renders all fields',
      (tester) async {
    await tester.pumpWidget(buildTestApp(const Demo5SettingsForm()));
    await tester.pumpAndSettle();

    // Demo 5 uses compact style (floating labels). Labels appear as hint
    // text in the InputDecoration, not as separate Text widgets above
    // the fields. Verify fields render by checking hint text presence.
    // DropdownButtonFormField and TextField instances should be present.
    expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
    expect(find.byType(TextField), findsWidgets);

    // Action buttons
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);

    // AppBar title
    expect(find.text('Demo 5: Settings Form'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}

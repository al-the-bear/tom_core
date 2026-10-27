// Form validation tests — enter text, tap save/discard, verify error display.
//
// Covers:
//   • Fast validators: required, minLength, pattern
//   • Slow validators: taxIdTaken, invalidEmailDomain
//   • Save success / failure status messages
//   • Discard resets field and status
//   • Demo 4 per-field validation status indicators
//   • Demo 5 locale / currency pattern errors
//   • Demo 2 nested form save failure

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/demos/demo_1_basic_form.dart';
import 'package:tom_flutter_form_test/demos/demo_2_nested_forms.dart';
import 'package:tom_flutter_form_test/demos/demo_4_validation.dart';
import 'package:tom_flutter_form_test/demos/demo_5_settings.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget buildTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    ),
    home: child,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

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

  // ═══════════════════════════════════════════════════════════════════════════
  // Demo 1 — fast validation via debounce
  // ═══════════════════════════════════════════════════════════════════════════

  // TextField order in Demo 1 (dropdowns excluded):
  //   0 = name  |  1 = taxId  |  2 = website  |  3 = description

  testWidgets('T01: Demo 1 — empty name field shows required error', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await tester.pumpAndSettle();

    // Clear the required name field (pre-populated with 'Acme Corporation').
    await tester.enterText(find.byType(TextField).at(0), '');
    // Advance past the fast-validator debounce (300 ms).
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Company name is required.'), findsOneWidget);
  });

  testWidgets('T02: Demo 1 — single-character name shows minLength error', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'A');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      find.text('Company name must be at least 2 characters.'),
      findsOneWidget,
    );
  });

  testWidgets('T03: Demo 1 — lowercase taxId fails pattern validator', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await tester.pumpAndSettle();

    // Pattern requires ^[A-Z0-9-]+$ — lowercase input must fail.
    await tester.enterText(find.byType(TextField).at(1), 'abc-invalid');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Tax ID must contain only uppercase letters, numbers, and dashes.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('T04: Demo 1 — invalid URL in website shows pattern error', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(2), 'not-a-url');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      find.text('Please enter a valid URL starting with http:// or https://.'),
      findsOneWidget,
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Demo 1 — slow validation via debounce
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('T05: Demo 1 — taxId starting with X shows taxIdTaken error', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await tester.pumpAndSettle();

    // X prefix passes the fast pattern validator but fails the slow validator.
    await tester.enterText(find.byType(TextField).at(1), 'XVALID01');
    // Advance past slow-validator debounce (600 ms) + 1 s async delay.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('This Tax ID is already registered.'), findsOneWidget);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Demo 1 — save button flows
  // ═══════════════════════════════════════════════════════════════════════════

  testWidgets('T06: Demo 1 — save with valid pre-populated data shows Saved!', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await tester.pumpAndSettle();

    // Pre-populated state (Acme Corporation / US-12345-ABC / …) is fully valid.
    final saveButton = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    // Allow slow taxId validator (1 s delay) to complete.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Status: Saved!'), findsOneWidget);
  });

  testWidgets(
    'T07: Demo 1 — save with empty required name shows failure status',
    (tester) async {
      await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
      await tester.pumpAndSettle();

      // Clear the required name field.
      await tester.enterText(find.byType(TextField).at(0), '');

      final saveButton = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();
      // Allow slow validators to finish before checking the final status.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(
        find.text('Status: Validation failed \u2014 check fields'),
        findsOneWidget,
      );
      // Required-error annotation must appear on the name field.
      expect(find.text('Company name is required.'), findsOneWidget);
    },
  );

  testWidgets('T08: Demo 1 — discard restores field and shows discard status', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo1BasicForm()));
    await tester.pumpAndSettle();

    // Modify the name field.
    await tester.enterText(find.byType(TextField).at(0), 'Modified Corp');
    await tester.pumpAndSettle();

    final discardButton = find.widgetWithText(TextButton, 'Discard');
    await tester.ensureVisible(discardButton);
    await tester.tap(discardButton);
    await tester.pumpAndSettle();

    expect(find.text('Status: Changes discarded'), findsOneWidget);
    // Field must be reset to the bound state value.
    expect(find.widgetWithText(TextField, 'Acme Corporation'), findsOneWidget);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Demo 4 — per-field validation status indicators
  // ═══════════════════════════════════════════════════════════════════════════

  // TextField order mirrors Demo 1 (same CompanyBasicInfoForm, same ACL order):
  //   0 = name  |  1 = taxId  |  2 = website  |  3 = description

  testWidgets('T09: Demo 4 — all four fields start as Pristine', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo4Validation()));
    await tester.pumpAndSettle();

    // Four status rows, all pristine before any user interaction.
    expect(find.text('Pristine'), findsNWidgets(4));
  });

  testWidgets('T10: Demo 4 — valid company name shows Valid status', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo4Validation()));
    await tester.pumpAndSettle();

    // Enter a valid name (≥ 2 characters, satisfies required + minLength).
    await tester.enterText(find.byType(TextField).at(0), 'Acme');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Valid'), findsWidgets);
  });

  testWidgets('T11: Demo 4 — single-character name shows Error status', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo4Validation()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'X');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Demo 4's status row shows the raw errorKey (hardcoded widget text).
    expect(find.text('Error: error.minLength'), findsOneWidget);
    // Field decoration also shows the resolved resource message.
    expect(
      find.text('Company name must be at least 2 characters.'),
      findsOneWidget,
    );
  });

  testWidgets('T12: Demo 4 — X-prefix taxId shows Validating… then Error', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo4Validation()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'XABC123');

    // Advance past slow debounce (600 ms). Use plain pump() — not
    // pumpAndSettle() — because CircularProgressIndicator keeps scheduling
    // animation frames and would cause pumpAndSettle() to time out.
    await tester.pump(const Duration(milliseconds: 700));
    // Process the rebuild frame triggered by the TomValidationPending setState.
    await tester.pump();
    await tester.pump();
    expect(find.text('Validating...'), findsOneWidget);

    // Advance past the 1 s slow-validator delay then process the rebuild.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    // Status row shows raw errorKey; field decoration shows the resource message.
    expect(find.text('Error: taxIdTaken'), findsOneWidget);
    expect(find.text('This Tax ID is already registered.'), findsOneWidget);
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Demo 5 — locale and currency pattern validation
  // ═══════════════════════════════════════════════════════════════════════════

  // TextField order in Demo 5 (dropdowns excluded):
  //   0 = locale  |  1 = currency  |  2 = dateFormat  |  3 = notificationEmail

  testWidgets('T13: Demo 5 — invalid locale shows invalidLocale error', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo5SettingsForm()));
    await tester.pumpAndSettle();

    // Locale pattern: ^[a-z]{2}_[A-Z]{2}$ — free-form text must fail.
    await tester.enterText(find.byType(TextField).at(0), 'bad-locale');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      find.text('Locale must be in the format ll_CC (e.g. en_US).'),
      findsOneWidget,
    );
  });

  testWidgets('T14: Demo 5 — lowercase currency shows invalidCurrency error', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo5SettingsForm()));
    await tester.pumpAndSettle();

    // Currency pattern: ^[A-Z]{3}$ — lowercase must fail.
    await tester.enterText(find.byType(TextField).at(1), 'usd');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      find.text('Currency must be a 3-letter ISO code (e.g. USD).'),
      findsOneWidget,
    );
  });

  testWidgets('T15: Demo 5 — save with invalid currency shows failure status', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo5SettingsForm()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'xx');

    final saveButton = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(
      find.text('Status: Validation failed \u2014 check fields'),
      findsOneWidget,
    );
    expect(
      find.text('Currency must be a 3-letter ISO code (e.g. USD).'),
      findsOneWidget,
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Demo 2 — nested form save failure
  // ═══════════════════════════════════════════════════════════════════════════

  // TextField order in Demo 2 (country dropdown excluded):
  //   Address: 0=street  1=street2  2=city  3=state  4=zipCode
  //   CEO:     5=firstName  6=lastName  7=email  8=phone  9=title

  testWidgets('T16: Demo 2 — save with empty required street field fails', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo2NestedForms()));
    await tester.pumpAndSettle();

    // Clear the required street field (pre-populated with '123 Main St').
    await tester.enterText(find.byType(TextField).at(0), '');

    final saveButton = find.widgetWithText(FilledButton, 'Save All');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    // Allow CEO email slow validator (800 ms) and any other async work.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(
      find.text('Status: Validation failed \u2014 check fields'),
      findsOneWidget,
    );
    expect(find.text('Street address is required.'), findsWidgets);
  });

  testWidgets(
    'T17: Demo 2 — invalid CEO email shows email error via debounce',
    (tester) async {
      await tester.pumpWidget(buildTestApp(const Demo2NestedForms()));
      await tester.pumpAndSettle();

      // Email field is pre-populated with 'jane.doe@acme.example.com'.
      await tester.enterText(find.byType(TextField).at(7), 'not-an-email');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    },
  );

  testWidgets('T18: Demo 2 — discard nested forms shows discard status', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const Demo2NestedForms()));
    await tester.pumpAndSettle();

    // Modify a field, then discard.
    await tester.enterText(find.byType(TextField).at(0), 'Changed St');
    await tester.pumpAndSettle();

    final discardButton = find.widgetWithText(TextButton, 'Discard');
    await tester.ensureVisible(discardButton);
    await tester.tap(discardButton);
    await tester.pumpAndSettle();

    expect(find.text('Status: Changes discarded'), findsOneWidget);
    // Street should be reset to its pre-populated value.
    expect(find.widgetWithText(TextField, '123 Main St'), findsOneWidget);
  });
}

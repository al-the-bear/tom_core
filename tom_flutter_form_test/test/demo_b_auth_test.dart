/// Tight-loop reproduction of the Demo B UI-state-controller toggle.
/// Opens Demo B, flips the switch, and verifies that auth state on the
/// email field follows the `phone`-is-empty rule documented in §24b.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
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

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.tap(find.text('Demo B: Authorization & Events'));
    await tester.pumpAndSettle();
  }

  TextField findByText(WidgetTester tester, String text) => tester
      .widgetList<TextField>(find.byType(TextField))
      .firstWhere((t) => t.controller?.text == text);

  testWidgets(
      'UIStateController: clearing phone disables email; refilling it re-enables',
      (tester) async {
    await open(tester);

    // Toggle the UI-state-controller switch ON.
    const subtitle =
        'When on, disables the email field while "phone" is empty.';
    await tester.tap(find.text(subtitle));
    await tester.pumpAndSettle();

    // Email is enabled while phone has its pre-bound value.
    expect(findByText(tester, 'jane.doe@example.com').enabled, isTrue,
        reason: 'Non-empty phone must leave email enabled.');

    // Clear the phone field. `enterText` on a spec-aligned TomFormStringInput
    // drives field.setValue(), which reliably notifies observers and flips
    // email's UIStateController result.
    final phoneField = findByText(tester, '+1 555 0100');
    await tester.enterText(find.byWidget(phoneField), '');
    await tester.pumpAndSettle();

    // Email should now be disabled — resolve returns disabled when phone
    // is empty, which then narrows currentAuth.
    expect(findByText(tester, 'jane.doe@example.com').enabled, isFalse,
        reason: 'Empty phone must disable email via the UIStateController.');

    // Refill the phone and email re-enables.
    final blankPhoneField = findByText(tester, '');
    await tester.enterText(find.byWidget(blankPhoneField), '+1 555 0200');
    await tester.pumpAndSettle();

    expect(findByText(tester, 'jane.doe@example.com').enabled, isTrue,
        reason: 'Refilling phone must re-enable email.');
  });

  testWidgets(
      'Authorizer: setting customerTier to "platinum" narrows billing to read',
      (tester) async {
    await open(tester);

    // Toggle the authorizer switch ON.
    const subtitle =
        'When on, billing & shipping narrow to read if the customer tier is platinum.';
    await tester.tap(find.text(subtitle));
    await tester.pumpAndSettle();

    // Billing street should be editable under the default tier 'gold'.
    expect(findByText(tester, '100 Market Street').enabled, isTrue);

    // Switch customerTier to platinum via the dropdown item.
    await tester.tap(find.text('Gold').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Platinum').last);
    await tester.pumpAndSettle();

    // Billing street should now be read-only (TextField.enabled = false).
    expect(findByText(tester, '100 Market Street').enabled, isFalse,
        reason: 'Platinum tier + authorizer ON must narrow billing to read.');
  });
}

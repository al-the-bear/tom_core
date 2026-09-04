/// T11 — Validation matrix.
///
/// Demo A's `ValidationForm` exercises every validator flavour:
///   * required (every field)
///   * email (email)
///   * minLength (username: 3, password: 8)
///   * pattern (username: `[a-zA-Z0-9_]+`, website: http(s) URL)
///   * SlowValidator async (username starts with "admin")
///   * cross-field `validateForm()` (password == confirmPassword)
///
/// `demo_a_lifecycle_test.dart` already covers pristine, Clear,
/// Populate, Save, Discard, the cross-field banner happy path, and the
/// async admin* validator. This file fills in the per-validator matrix
/// that hadn't been individually probed:
///   * email — invalid input shows the email error, fixing it clears
///   * username minLength — short input shows the minLength error
///   * username pattern — invalid characters show the pattern error
///   * password minLength — short password shows the minLength error
///   * website pattern — malformed URL shows the URL error, valid clears
///   * cross-field banner clears once the mismatch is repaired
///
/// All assertions read the *resolved* user-facing strings from
/// `demo_resources.json` (validation_form scope under demoA), so each
/// test also doubles as a resource-resolution check for that errorKey.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
// ignore: implementation_imports
import 'package:tom_flutter_ui/src/forms/fields/tom_field_widget_adapter.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/phase1_state.dart';

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

  // Same disposed-listener-leak guard as demo_a_lifecycle_test: replace
  // the global state with a fresh ValidationProfile each time so the
  // newly-bound form doesn't share observers with a previously-disposed
  // form's notifier.
  setUp(() {
    final s = ValidationProfile();
    s.username | 'janedoe';
    s.email | 'jane.doe@example.com';
    s.password | 'strongpass1';
    s.confirmPassword | 'strongpass1';
    s.website | 'https://example.com';
    phase1ValidationState = s;
  });

  Future<void> openDemoA(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
      find.text('Demo A: Lifecycle & Validation'),
      200,
      scrollable: find.descendant(
        of: find.byType(DemoListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Demo A: Lifecycle & Validation'));
    await tester.pumpAndSettle();
  }

  Finder fieldByTomId(String tomId) {
    return find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
        description: 'TomFieldWidgetAdapter[$tomId]',
      ),
      matching: find.byType(TextField),
    );
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    Finder finder = find.widgetWithText(FilledButton, label);
    if (finder.evaluate().isEmpty) {
      finder = find.widgetWithText(TextButton, label);
    }
    expect(finder, findsAtLeastNWidgets(1));
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  // -------------------------------------------------------------------
  // email validator
  // -------------------------------------------------------------------

  testWidgets('email — invalid input surfaces "Enter a valid email '
      'address.", typing a valid address clears it', (tester) async {
    await openDemoA(tester);
    final emailField = fieldByTomId('email');
    expect(emailField, findsOneWidget);
    await tester.enterText(emailField, 'not-an-email');
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid email address.'),
      findsAtLeastNWidgets(1),
      reason:
          'invalid email must surface the validation_form.email '
          'errorKey resolved string',
    );
    // Now type a valid email.
    await tester.enterText(emailField, 'someone@example.com');
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid email address.'),
      findsNothing,
      reason: 'fixing the email must clear the inline error',
    );
  });

  // -------------------------------------------------------------------
  // username — minLength + pattern validators
  // -------------------------------------------------------------------

  testWidgets('username minLength — typing fewer than 3 chars surfaces '
      'the minLength error', (tester) async {
    await openDemoA(tester);
    final f = fieldByTomId('username');
    await tester.enterText(f, 'ab');
    await tester.pumpAndSettle();
    // Resource template is "Username must be at least {min} characters." —
    // accept either the substituted ("3") or the raw ("{min}") form.
    expect(
      find.textContaining('Username must be at least'),
      findsAtLeastNWidgets(1),
      reason: 'minLength(3) must resolve the username.minLength resource',
    );
  });

  testWidgets('username pattern — invalid characters surface the '
      'usernamePattern error', (tester) async {
    await openDemoA(tester);
    final f = fieldByTomId('username');
    // 4 chars satisfies minLength(3); the special char "!" trips the
    // [a-zA-Z0-9_]+ pattern.
    await tester.enterText(f, 'jane!');
    await tester.pumpAndSettle();
    expect(
      find.text('Only letters, digits, and underscores are allowed.'),
      findsAtLeastNWidgets(1),
      reason: 'pattern violation must surface the usernamePattern errorKey',
    );
  });

  // -------------------------------------------------------------------
  // password minLength
  // -------------------------------------------------------------------

  testWidgets('password minLength — typing fewer than 8 chars surfaces '
      'the minLength error', (tester) async {
    await openDemoA(tester);
    final f = fieldByTomId('password');
    await tester.enterText(f, 'short');
    await tester.pumpAndSettle();
    // Same resource-template tolerance as the username minLength test.
    expect(
      find.textContaining('Password must be at least'),
      findsAtLeastNWidgets(1),
      reason: 'minLength(8) must surface the password.minLength errorKey',
    );
  });

  // -------------------------------------------------------------------
  // website pattern
  // -------------------------------------------------------------------

  testWidgets('website pattern — malformed URL surfaces the invalidUrl '
      'error, a valid http(s) URL clears it', (tester) async {
    await openDemoA(tester);
    final f = fieldByTomId('website');
    await tester.enterText(f, 'not a url');
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid http(s) URL.'),
      findsAtLeastNWidgets(1),
      reason: 'malformed URL must surface the website.invalidUrl errorKey',
    );
    // Fix it.
    await tester.enterText(f, 'https://example.org');
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid http(s) URL.'),
      findsNothing,
      reason: 'a valid http(s) URL must clear the inline error',
    );
  });

  // -------------------------------------------------------------------
  // cross-field banner clears once the rule is satisfied
  // -------------------------------------------------------------------

  testWidgets('cross-field — repairing the password mismatch clears the '
      '"Form Errors" banner on the next Save', (tester) async {
    await openDemoA(tester);
    // Mismatch first: strongpass1 vs strongpass2 → Save → banner appears.
    await tester.enterText(fieldByTomId('confirmPassword'), 'strongpass2');
    await tester.pumpAndSettle();
    await tapButton(tester, 'Save');
    await tester.pumpAndSettle(const Duration(milliseconds: 1200));
    expect(
      find.text('Form Errors'),
      findsOneWidget,
      reason: 'mismatched passwords must surface the cross-field banner',
    );
    // Repair: confirm matches password again, save, banner must clear.
    await tester.enterText(fieldByTomId('confirmPassword'), 'strongpass1');
    await tester.pumpAndSettle();
    await tapButton(tester, 'Save');
    await tester.pumpAndSettle(const Duration(milliseconds: 1200));
    expect(
      find.text('Form Errors'),
      findsNothing,
      reason: 'fixing the mismatch must remove the cross-field banner',
    );
  });
}

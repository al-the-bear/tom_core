/// Interaction tests for Demo A — Lifecycle & Validation.
///
/// Distinct from `phase1_smoke_test.dart` (anchor-text only) and
/// `all_demos_no_exceptions_test.dart` (no FlutterError). These tests
/// drive the demo through its real lifecycle:
///   * pristine on first bind (no error text leaks before user input)
///   * Clear → required errors surface
///   * Populate → sample values reach the bound state
///   * Save with mismatched passwords → cross-field banner fires
///   * Save valid → status reports success and form returns to pristine
///   * Discard → reverts dirty edits to the bound snapshot
///   * Async validator (`admin*` username) fires after its delay
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
// TomFieldWidgetAdapter is not exported from the public barrel — we need it
// here to locate field widgets by their `tomId` (label text isn't an
// ancestor of the rendered TextField so the usual `find.ancestor` recipe
// finds nothing). See `tom_field_widget_adapter.dart` for the rationale.
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

  // Each test gets a fresh `phase1ValidationState` instance. The form
  // currently does not detach its binding observer on dispose, so any
  // `setValues(...)` against the *previous* test's state instance would
  // notify the disposed form's `_FormChangeNotifier` — which throws.
  // Replacing the global reference here means new forms bind to a fresh
  // instance and we never touch the orphaned one again, so no
  // notifications reach the disposed observer.
  setUp(() {
    final s = ValidationProfile();
    s.username | 'janedoe';
    s.email | 'jane.doe@example.com';
    s.password | '';
    s.confirmPassword | '';
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

  /// Tap a button by visible label. Demo A's action row uses
  /// [TextButton.icon] (Clear, Populate), [TextButton] (Discard) and
  /// [FilledButton] (Save). `widgetWithText` resolves to an ancestor
  /// finder, so we try the concrete button types in turn.
  Future<void> tapButton(WidgetTester tester, String label) async {
    Finder finder = find.widgetWithText(FilledButton, label);
    if (finder.evaluate().isEmpty) {
      finder = find.widgetWithText(TextButton, label);
    }
    expect(
      finder,
      findsAtLeastNWidgets(1),
      reason:
          'No FilledButton/TextButton labelled "$label" in the '
          'action row',
    );
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  /// Locate a Tom field's underlying [TextField] by the field's [tomId].
  /// The visible label is rendered as a sibling of the TextField (not an
  /// ancestor), so `find.ancestor(of: find.text('Username'), matching:
  /// find.byType(TextField))` returns nothing. Walking down from the
  /// [TomFieldWidgetAdapter] is the reliable path.
  Finder fieldByTomId(String tomId) {
    return find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
        description: 'TomFieldWidgetAdapter[$tomId]',
      ),
      matching: find.byType(TextField),
    );
  }

  testWidgets('pristine on first bind — no required-error text visible', (
    tester,
  ) async {
    await openDemoA(tester);
    // Seed values for password / confirmPassword are empty in
    // phase1ValidationState. Required validators run, but ValidationPristine
    // suppresses error display until the user types or attempts Save.
    expect(
      find.text('Password is required.'),
      findsNothing,
      reason: 'Pristine bind must not surface required-error text',
    );
    expect(
      find.text('Please confirm your password.'),
      findsNothing,
      reason: 'Pristine bind must not surface required-error text',
    );
    // Initial status set in initState.
    expect(find.textContaining('Bound — pristine'), findsOneWidget);
  });

  testWidgets('Clear blanks every string field and surfaces required errors', (
    tester,
  ) async {
    await openDemoA(tester);
    await tapButton(tester, 'Clear');
    // After Clear the username (which had 'janedoe') is blank, triggering
    // the required validator. Pristine is broken because setValue fired,
    // so the error becomes visible.
    expect(
      find.text('Username is required.'),
      findsAtLeastNWidgets(1),
      reason: 'Clear should reveal username required error',
    );
    expect(
      find.text('Email is required.'),
      findsAtLeastNWidgets(1),
      reason: 'Clear should reveal email required error',
    );
  });

  testWidgets('Populate fills sample values and clears required errors', (
    tester,
  ) async {
    await openDemoA(tester);
    // First Clear so we have visible required errors to assert against.
    await tapButton(tester, 'Clear');
    expect(find.text('Email is required.'), findsAtLeastNWidgets(1));
    // Then Populate sets the canonical valid sample.
    await tapButton(tester, 'Populate');
    await tester.pumpAndSettle();
    expect(
      find.text('Email is required.'),
      findsNothing,
      reason: 'Populate filled email so the required error must clear',
    );
    expect(
      find.text('Password is required.'),
      findsNothing,
      reason: 'Populate filled password so required error must clear',
    );
    expect(find.textContaining('Populated with sample'), findsOneWidget);
  });

  testWidgets('Save with mismatched passwords surfaces cross-field banner', (
    tester,
  ) async {
    await openDemoA(tester);
    // Populate fills password=confirmPassword=strongpass1. Mutate just one
    // to break the cross-field rule.
    await tapButton(tester, 'Populate');
    await tester.pumpAndSettle();
    // Locate confirmPassword by its tomId (label text isn't an ancestor of
    // the TextField in TomField widgets — see `fieldByTomId`).
    final confirmField = fieldByTomId('confirmPassword');
    expect(
      confirmField,
      findsOneWidget,
      reason: 'Confirm password TextField must be in the tree',
    );
    await tester.enterText(confirmField, 'different-value');
    await tester.pumpAndSettle();
    await tapButton(tester, 'Save');
    // SaveFormAction is async — let any pending validations settle.
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    // TomFormErrorBanner shows a "Form Errors" header when it has any
    // cross-field errors to display.
    expect(
      find.text('Form Errors'),
      findsOneWidget,
      reason: 'TomFormErrorBanner must surface cross-field validation errors',
    );
    // KNOWN GAP: TomFormErrorBanner currently renders the raw `errorKey`
    // (`error.passwordsMismatch`) instead of resolving it through
    // `TomCtr.text(...)` like TomErrorView does. Once that's fixed (the
    // banner needs the form's basePath as a scoping context), update this
    // expectation to `find.text('Passwords do not match.')`.
    expect(
      find.text('error.passwordsMismatch'),
      findsOneWidget,
      reason:
          'TomFormErrorBanner currently shows the raw error key — '
          'see resolution gap noted above',
    );
  });

  testWidgets('Save with valid populated state reports success status', (
    tester,
  ) async {
    await openDemoA(tester);
    await tapButton(tester, 'Populate');
    await tester.pumpAndSettle();
    await tapButton(tester, 'Save');
    // SaveFormAction does Future.wait — give async validators a beat to
    // resolve before checking status.
    await tester.pumpAndSettle(const Duration(milliseconds: 1200));
    expect(
      find.textContaining('Saved'),
      findsAtLeastNWidgets(1),
      reason: 'After valid save the status card should report success',
    );
    // Dirty must be false after a successful commit.
    expect(
      find.textContaining('Dirty: false'),
      findsAtLeastNWidgets(1),
      reason: 'Successful save commits and returns the form to pristine',
    );
  });

  testWidgets('Discard reverts an edited field to the bound value', (
    tester,
  ) async {
    await openDemoA(tester);
    // Edit username so the form becomes dirty.
    final usernameField = fieldByTomId('username');
    expect(usernameField, findsOneWidget);
    await tester.enterText(usernameField, 'someoneelse');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Dirty: true'),
      findsAtLeastNWidgets(1),
      reason: 'Editing a field should mark the form dirty',
    );
    await tapButton(tester, 'Discard');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Dirty: false'),
      findsAtLeastNWidgets(1),
      reason: 'Discard should clear the dirty state',
    );
    // Status text should reflect the discard message.
    expect(find.textContaining('discarded'), findsAtLeastNWidgets(1));
  });

  testWidgets('async validator fires for admin* username after its delay', (
    tester,
  ) async {
    await openDemoA(tester);
    final usernameField = fieldByTomId('username');
    expect(usernameField, findsOneWidget);
    await tester.enterText(usernameField, 'admin42');
    // SlowValidator delays ~800 ms.
    await tester.pumpAndSettle(const Duration(milliseconds: 1200));
    expect(
      find.text('That username is already taken.'),
      findsAtLeastNWidgets(1),
      reason: 'admin* triggers the async SlowValidator after ~800ms',
    );
  });
}

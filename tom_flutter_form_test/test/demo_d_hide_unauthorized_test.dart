/// Interaction tests for Demo D — Hide on Authorization.
///
/// Distinct from `phase1_smoke_test.dart` (anchor-text only) and
/// `all_demos_no_exceptions_test.dart` (no FlutterError). These tests
/// drive the right-hand auth-control panel and assert that the left-hand
/// form / widget gallery actually re-lays-out:
///   * baseline — every form field renders, gallery widgets render
///   * toggling a single field's auth to `none` removes that field but
///     keeps every other field present
///   * toggling every field in a row to `none` elides the whole row,
///     while the surrounding rows remain
///   * toggling a non-form Tom widget (button/chip/icon) hides it
///     without affecting any form fields
///   * the Reset button restores every field that had been hidden
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
// TomFieldWidgetAdapter is not exported from the public barrel — we need
// it here to locate field widgets by their `tomId` (label text isn't an
// ancestor of the rendered TextField so the usual `find.ancestor` recipe
// finds nothing). See `tom_field_widget_adapter.dart` for the rationale.
// ignore: implementation_imports
import 'package:tom_flutter_ui/src/forms/fields/tom_field_widget_adapter.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    final jsonStr =
        await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  // Demo D installs its own concrete adapter into the global
  // [TomAuthorization.adapter] in its initState, which means each
  // subsequent test reinstalls a fresh adapter when the demo opens.
  // No tearDown is required — but if a future test orders matter, we
  // could reinstall a permissive adapter here.

  Future<void> openDemoD(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo D: Hide on Authorization'), 200,
        scrollable: find.descendant(
          of: find.byType(DemoListScreen),
          matching: find.byType(Scrollable),
        ),);
    await tester.tap(find.text('Demo D: Hide on Authorization'));
    await tester.pumpAndSettle();
  }

  /// Locate the underlying [TextField] of a Tom field by its [tomId].
  Finder fieldByTomId(String tomId) {
    return find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
        description: 'TomFieldWidgetAdapter[$tomId]',
      ),
      matching: find.byType(TextField),
    );
  }

  /// The right-hand auth panel renders one [DropdownButton<TomAuthState>]
  /// per controlled element, in this exact order:
  ///   form fields  : username, email, password, confirmPassword, website
  ///   gallery      : saveBtn, cancelBtn, detailsBtn, submitBtn,
  ///                  refreshBtn, featuredChip, statusIcon, hairline,
  ///                  badge, infoCard
  /// Index in that flat list; we drive the dropdown by ordinal because the
  /// label is rendered inside a [SelectableText], which `find.text` does
  /// NOT match.
  Future<void> setAuthAt(
    WidgetTester tester,
    int index,
    String optionName,
  ) async {
    final dropdown =
        find.byType(DropdownButton<TomAuthState>).at(index);
    expect(dropdown, findsOneWidget,
        reason: 'auth dropdown #$index must exist');
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    // Two text instances will exist after the menu opens — one in the
    // dropdown items overlay, one as the closed-button child if it
    // matches `current`. `.last` reliably grabs the menu item.
    await tester.tap(find.text(optionName).last);
    await tester.pumpAndSettle();
  }

  // Field-dropdown ordinals.
  const usernameDD = 0;
  const emailDD = 1;
  const passwordDD = 2;
  const confirmPasswordDD = 3;
  // Gallery-dropdown ordinals (offset by 5 form fields).
  const saveBtnDD = 5;
  const featuredChipDD = 10;

  testWidgets('baseline — every field and gallery anchor widget renders',
      (tester) async {
    await openDemoD(tester);
    // Both form sections share the same field set, so every tomId
    // appears at least twice (Form A + Form B).
    expect(fieldByTomId('username'), findsNWidgets(2));
    expect(fieldByTomId('email'), findsNWidgets(2));
    expect(fieldByTomId('password'), findsNWidgets(2));
    expect(fieldByTomId('confirmPassword'), findsNWidgets(2));
    expect(fieldByTomId('website'), findsNWidgets(2));
    // Gallery anchors (one each).
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Featured'), findsOneWidget);
  });

  testWidgets('hide a single field — that field disappears, others stay',
      (tester) async {
    await openDemoD(tester);
    expect(fieldByTomId('username'), findsNWidgets(2));
    await setAuthAt(tester, usernameDD, 'none');
    // Username is hidden in BOTH forms (single auth path drives both).
    expect(fieldByTomId('username'), findsNothing,
        reason: 'username should be elided when auth = none');
    // Sibling fields untouched.
    expect(fieldByTomId('email'), findsNWidgets(2));
    expect(fieldByTomId('password'), findsNWidgets(2));
  });

  testWidgets('hide every field in row 2 — entire row is elided',
      (tester) async {
    await openDemoD(tester);
    expect(fieldByTomId('password'), findsNWidgets(2));
    expect(fieldByTomId('confirmPassword'), findsNWidgets(2));
    await setAuthAt(tester, passwordDD, 'none');
    await setAuthAt(tester, confirmPasswordDD, 'none');
    expect(fieldByTomId('password'), findsNothing);
    expect(fieldByTomId('confirmPassword'), findsNothing);
    // Other rows must still be present.
    expect(fieldByTomId('username'), findsNWidgets(2));
    expect(fieldByTomId('email'), findsNWidgets(2));
    expect(fieldByTomId('website'), findsNWidgets(2));
  });

  testWidgets('hide a gallery widget — only that widget disappears',
      (tester) async {
    await openDemoD(tester);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Featured'), findsOneWidget);
    await setAuthAt(tester, saveBtnDD, 'none');
    expect(find.text('Save'), findsNothing,
        reason: 'TomElevatedButton "Save" should be elided');
    // Sibling gallery widgets unaffected.
    expect(find.text('Featured'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    // Form fields unaffected.
    expect(fieldByTomId('username'), findsNWidgets(2));
  });

  testWidgets('readonly state keeps the field present (not hidden)',
      (tester) async {
    await openDemoD(tester);
    await setAuthAt(tester, emailDD, 'read');
    // `read` is a visual treatment, NOT a hide — the field stays in the
    // tree.
    expect(fieldByTomId('email'), findsNWidgets(2),
        reason: 'read auth should keep the field in the tree');
  });

  testWidgets('disabled state keeps the field present (not hidden)',
      (tester) async {
    await openDemoD(tester);
    await setAuthAt(tester, emailDD, 'disabled');
    expect(fieldByTomId('email'), findsNWidgets(2),
        reason: 'disabled auth should keep the field in the tree');
  });

  testWidgets('Reset form fields restores everything that was hidden',
      (tester) async {
    await openDemoD(tester);
    await setAuthAt(tester, usernameDD, 'none');
    await setAuthAt(tester, emailDD, 'none');
    expect(fieldByTomId('username'), findsNothing);
    expect(fieldByTomId('email'), findsNothing);
    final reset = find.widgetWithText(TextButton, 'Reset form fields');
    expect(reset, findsOneWidget);
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(fieldByTomId('username'), findsNWidgets(2),
        reason: 'Reset must restore the username field');
    expect(fieldByTomId('email'), findsNWidgets(2),
        reason: 'Reset must restore the email field');
  });

  testWidgets('hiding a chip leaves form fields unaffected',
      (tester) async {
    await openDemoD(tester);
    expect(find.text('Featured'), findsOneWidget);
    await setAuthAt(tester, featuredChipDD, 'none');
    expect(find.text('Featured'), findsNothing);
    // Form rows must still be intact.
    expect(fieldByTomId('username'), findsNWidgets(2));
    expect(fieldByTomId('confirmPassword'), findsNWidgets(2));
  });
}

/// Interaction tests for Demo 3 — Authorization (legacy numbered demo).
///
/// Demo 3 demonstrates per-resource auth via [DemoAuthAdapter]. The amber
/// "Authorization Controls" card hosts three [OutlinedButton]s that mutate
/// the adapter rules and rebuild the form. The info card below echoes the
/// outcome via a "Status:" line.
///
/// We assert on:
///   * baseline — controls present, status reads "Ready", visible fields
///     match the adapter's initial rules (description = none → hidden)
///   * Toggle Name R/O — status flips between EDITABLE and READ-ONLY
///     across two presses
///   * Cycle Industry Auth — status text walks the four-state cycle
///   * Toggle Section — status flips between ENABLED and DISABLED
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
// TomFieldWidgetAdapter is not exported from the public barrel — we need it
// here to locate Tom field widgets by their `tomId`. See
// `tom_field_widget_adapter.dart` for the rationale.
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

  Future<void> openDemo3(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo 3: Authorization'), 200);
    await tester.tap(find.text('Demo 3: Authorization'));
    await tester.pumpAndSettle();
  }

  /// Tap an [OutlinedButton] in the auth-controls card by its label.
  Future<void> tapOutlined(WidgetTester tester, String label) async {
    final btn = find.widgetWithText(OutlinedButton, label);
    expect(btn, findsOneWidget,
        reason: 'OutlinedButton "$label" must exist');
    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pumpAndSettle();
  }

  /// Find the Tom field by its [tomId]. Tom field labels render as siblings
  /// (not ancestors) of the underlying input, so the canonical
  /// `find.ancestor(of: find.text('Name'), …)` recipe returns nothing. The
  /// adapter walk is the reliable path.
  Finder fieldByTomId(String tomId) {
    return find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
        description: 'TomFieldWidgetAdapter[$tomId]',
      ),
      matching: find.byType(TextField),
    );
  }

  testWidgets('baseline — controls render and Status reads "Ready"',
      (tester) async {
    await openDemo3(tester);
    expect(find.text('Authorization Controls'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Toggle Name R/O'),
        findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Cycle Industry Auth'),
        findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Toggle Section'),
        findsOneWidget);
    expect(find.text('Status: Ready'), findsOneWidget);
    // String inputs (TextField underneath the adapter).
    expect(fieldByTomId('name'), findsOneWidget);
    // Tax ID is read-only — its TextField is still present (read just
    // disables editing, doesn't elide the widget).
    expect(fieldByTomId('taxId'), findsOneWidget);
    expect(fieldByTomId('website'), findsOneWidget);
    // Industry is a dropdown (no TextField inside) — assert the adapter
    // exists rather than walking down to a TextField.
    expect(
      find.byWidgetPredicate(
        (w) => w is TomFieldWidgetAdapter && w.field.tomId == 'industry',
        description: 'TomFieldWidgetAdapter[industry]',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Toggle Name R/O cycles status between EDITABLE and READ-ONLY',
      (tester) async {
    await openDemo3(tester);
    // First press: full → read.
    await tapOutlined(tester, 'Toggle Name R/O');
    expect(find.text('Status: Name field: READ-ONLY'), findsOneWidget,
        reason: 'first press must mark name READ-ONLY');
    // Second press: read → full again.
    await tapOutlined(tester, 'Toggle Name R/O');
    expect(find.text('Status: Name field: EDITABLE'), findsOneWidget,
        reason: 'second press must restore EDITABLE');
  });

  testWidgets('Cycle Industry Auth walks the four-state cycle',
      (tester) async {
    await openDemo3(tester);
    // Initial industry auth = full → first press → READ.
    await tapOutlined(tester, 'Cycle Industry Auth');
    expect(find.text('Status: Industry field: READ'), findsOneWidget);
    // READ → DISABLED.
    await tapOutlined(tester, 'Cycle Industry Auth');
    expect(find.text('Status: Industry field: DISABLED'), findsOneWidget);
    // DISABLED → HIDDEN. Demo 3's ACL builder does NOT enable
    // `setAclDefaultHideUnauthorized`, so auth=none here only changes the
    // field's `effectiveAuthState` — the adapter stays in the tree. Demo D
    // tests cover the ACL elision path. Here we assert via the field's
    // effectiveAuthState reported by the adapter.
    await tapOutlined(tester, 'Cycle Industry Auth');
    expect(find.text('Status: Industry field: HIDDEN'), findsOneWidget);
    final hiddenAdapter = find
        .byWidgetPredicate(
          (w) => w is TomFieldWidgetAdapter && w.field.tomId == 'industry',
        )
        .evaluate()
        .first
        .widget as TomFieldWidgetAdapter;
    expect(hiddenAdapter.effectiveAuthState, TomAuthState.none,
        reason: 'industry field must report none auth after HIDDEN');
    // HIDDEN → FULL.
    await tapOutlined(tester, 'Cycle Industry Auth');
    expect(find.text('Status: Industry field: FULL'), findsOneWidget);
    final fullAdapter = find
        .byWidgetPredicate(
          (w) => w is TomFieldWidgetAdapter && w.field.tomId == 'industry',
        )
        .evaluate()
        .first
        .widget as TomFieldWidgetAdapter;
    expect(fullAdapter.effectiveAuthState, TomAuthState.full,
        reason: 'industry field must report full auth after FULL');
  });

  testWidgets('Toggle Section flips between ENABLED and DISABLED',
      (tester) async {
    await openDemo3(tester);
    // First press: full → disabled.
    await tapOutlined(tester, 'Toggle Section');
    expect(find.text('Status: Section: DISABLED (grayed out)'),
        findsOneWidget);
    // Second press: disabled → enabled.
    await tapOutlined(tester, 'Toggle Section');
    expect(find.text('Status: Section: ENABLED'), findsOneWidget);
  });

  testWidgets('description field reports none auth in baseline',
      (tester) async {
    await openDemo3(tester);
    // The description field has auth = none seeded by the adapter. Demo 3
    // does NOT use `setAclDefaultHideUnauthorized`, so the adapter remains
    // in the tree but reports `effectiveAuthState == none`. (Demo D
    // exercises the elision path.)
    final adapter = find
        .byWidgetPredicate(
          (w) => w is TomFieldWidgetAdapter && w.field.tomId == 'description',
        )
        .evaluate()
        .first
        .widget as TomFieldWidgetAdapter;
    expect(adapter.effectiveAuthState, TomAuthState.none,
        reason: 'description must report none auth from the seeded rule');
  });
}

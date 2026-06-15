/// Interaction tests for Demo L — File Upload + Nullable Variants
/// (Phase 4). T7 (file) and T9 (nullable variants) live in one file
/// because they share the demo widget tree, the 'demoL' scope, and the
/// same right-side info panels.
///
/// Demo L's "Nullable values + state" panel renders one row per
/// nullable field with three columns:
///   [field name] [state label] [formatted value]
/// where the state label is one of "pristine" / "set" / "explicit-null".
/// We use the state label as the canonical probe for the
/// pristine / set / explicitly-null distinction.
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
import 'package:tom_flutter_form_test/state/phase4_state.dart';

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

  // The form mutates `phase4FileNullableState` via the action buttons
  // (Set / Reset / null). Replace the bound instance between tests so
  // observers from a disposed previous form don't fire into a disposed
  // _FormChangeNotifier — same pattern as Demo I / J / K.
  setUp(() {
    phase4FileNullableState = FileNullableDemoState();
  });

  Future<void> openDemoL(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo L: Files & Nullable Variants'), 200,
        scrollable: find.descendant(
          of: find.byType(DemoListScreen),
          matching: find.byType(Scrollable),
        ),);
    await tester.tap(find.text('Demo L: Files & Nullable Variants'));
    await tester.pumpAndSettle();
  }

  Finder adapterByTomId(String tomId) {
    return find.byWidgetPredicate(
      (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
      description: 'TomFieldWidgetAdapter[$tomId]',
    );
  }

  Future<void> tapOutlined(WidgetTester tester, String label) async {
    final btn = find.widgetWithText(OutlinedButton, label);
    expect(btn, findsAtLeastNWidgets(1),
        reason: 'OutlinedButton "$label" must exist');
    await tester.ensureVisible(btn.first);
    await tester.pumpAndSettle();
    await tester.tap(btn.first);
    await tester.pumpAndSettle();
  }

  /// Read the three-column row for a nullable field on the bindings
  /// panel and return (stateLabel, valueText). The row has three Text
  /// descendants: [name, state, value].
  ({String state, String value}) nullableRow(
      WidgetTester tester, String name) {
    final nameFinder = find.text(name);
    expect(nameFinder, findsAtLeastNWidgets(1));
    final row = find.ancestor(of: nameFinder.first, matching: find.byType(Row));
    expect(row, findsAtLeastNWidgets(1));
    final texts = find
        .descendant(of: row.first, matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .toList();
    expect(texts.length, greaterThanOrEqualTo(3),
        reason: 'nullable row "$name" must have name + state + value Text');
    return (state: texts[1], value: texts[2]);
  }

  // ---------------------------------------------------------------------
  // Baseline
  // ---------------------------------------------------------------------

  testWidgets('baseline — file + nullable adapters render, all rows '
      'start in the pristine state', (tester) async {
    await openDemoL(tester);
    // File fields.
    expect(adapterByTomId('upload'), findsOneWidget);
    expect(adapterByTomId('dropzone'), findsOneWidget);
    // Nullable fields.
    for (final id in ['notes', 'age', 'score', 'birthday', 'priority']) {
      expect(adapterByTomId(id), findsOneWidget,
          reason: 'nullable adapter "$id" must render');
    }
    // The "Choose file…" button + "Tap to choose a file" dropzone copy.
    expect(find.text('Choose file…'), findsOneWidget);
    expect(find.text('Tap to choose a file'), findsOneWidget);
    // Every nullable row starts pristine and reads 'null'.
    for (final name in ['notes', 'age', 'score', 'birthday', 'priority']) {
      final row = nullableRow(tester, name);
      expect(row.state, 'pristine',
          reason: 'row "$name" must start pristine');
      expect(row.value, 'null',
          reason: 'row "$name" must read "null" before any edit');
    }
    // form.isDirty starts false.
    expect(find.text('form.isDirty = false'), findsOneWidget);
  });

  // ---------------------------------------------------------------------
  // T7 — file fields
  // ---------------------------------------------------------------------

  testWidgets('T7: tapping "Choose file…" populates the upload field via '
      'the in-memory demo picker', (tester) async {
    await openDemoL(tester);
    final btn = find.descendant(
      of: adapterByTomId('upload'),
      matching: find.widgetWithText(OutlinedButton, 'Choose file…'),
    );
    expect(btn, findsOneWidget);
    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pumpAndSettle();
    // The picker returns "demo_picked_file.txt" — the upload row's text
    // should now include that filename.
    expect(
      find.descendant(
        of: adapterByTomId('upload'),
        matching: find.textContaining('demo_picked_file.txt'),
      ),
      findsOneWidget,
      reason: 'upload field text must show the picked filename',
    );
  });

  testWidgets('T7: tapping the dropzone surface populates the dropzone '
      'field via the in-memory demo picker', (tester) async {
    await openDemoL(tester);
    // The dropzone wraps an InkWell — tap the "Tap to choose a file" text
    // (a descendant of the InkWell), which routes through the InkWell.
    final dropTarget = find.descendant(
      of: adapterByTomId('dropzone'),
      matching: find.text('Tap to choose a file'),
    );
    expect(dropTarget, findsOneWidget);
    await tester.ensureVisible(dropTarget);
    await tester.pumpAndSettle();
    await tester.tap(dropTarget);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: adapterByTomId('dropzone'),
        matching: find.textContaining('demo_picked_file.txt'),
      ),
      findsOneWidget,
      reason: 'dropzone must now show the picked filename',
    );
  });

  // ---------------------------------------------------------------------
  // T9 — nullable variants
  // ---------------------------------------------------------------------

  testWidgets('T9: "Set all (non-null)" drives every nullable row to the '
      '"set" state with its assigned value', (tester) async {
    await openDemoL(tester);
    await tapOutlined(tester, 'Set all (non-null)');
    // notes → "Hello world", age → 42, score → 7.5, birthday → 1990-01-01,
    // priority → Priority.high.
    final notes = nullableRow(tester, 'notes');
    expect(notes.state, 'set');
    expect(notes.value, 'Hello world');
    final age = nullableRow(tester, 'age');
    expect(age.state, 'set');
    expect(age.value, '42');
    final score = nullableRow(tester, 'score');
    expect(score.state, 'set');
    expect(score.value, '7.5');
    final birthday = nullableRow(tester, 'birthday');
    expect(birthday.state, 'set');
    expect(birthday.value, '1990-01-01');
    final priority = nullableRow(tester, 'priority');
    expect(priority.state, 'set');
    expect(priority.value, 'Priority.high');
    // form.isDirty must be true after any edit.
    expect(find.text('form.isDirty = true'), findsOneWidget);
  });

  testWidgets('T9: "Set all → null" drives every nullable row to the '
      '"explicit-null" state when the initial values were NON-null',
      (tester) async {
    // The "explicit-null" state requires the form to be dirty AND the
    // value to be null. With the default all-null initial, tapping
    // "Set all → null" after "Set all (non-null)" returns the form to
    // the initial state — so it reads as "pristine", not
    // "explicit-null". To reach explicit-null we have to seed the
    // bound state with NON-null initial values; the form will then
    // bind to those, and tapping "Set all → null" produces a true
    // explicit-null transition for every nullable row except `priority`
    // (which lives outside the bound state — its initial is hard-coded
    // null in `makeDemoLPriorityField`).
    phase4FileNullableState = FileNullableDemoState();
    phase4FileNullableState.notes.set('initial');
    phase4FileNullableState.age.set(20);
    phase4FileNullableState.score.set(1.5);
    phase4FileNullableState.birthday.set(DateTime(2000, 1, 1));
    await openDemoL(tester);
    // Sanity check: the bound rows start at "pristine" (matching the
    // freshly-bound initial) and the priority row also reads pristine
    // (initial value null, never touched).
    expect(nullableRow(tester, 'notes').state, 'pristine');
    await tapOutlined(tester, 'Set all → null');
    // Bound rows are now dirty + null → explicit-null.
    for (final name in ['notes', 'age', 'score', 'birthday']) {
      final row = nullableRow(tester, name);
      expect(row.state, 'explicit-null',
          reason: 'row "$name" must report explicit-null after clearing '
              'a previously non-null initial');
      expect(row.value, 'null');
    }
    expect(find.text('form.isDirty = true'), findsOneWidget);
  });

  testWidgets('T9: "Reset (pristine)" returns every nullable row to '
      'pristine + null', (tester) async {
    await openDemoL(tester);
    await tapOutlined(tester, 'Set all (non-null)');
    await tapOutlined(tester, 'Reset (pristine)');
    for (final name in ['notes', 'age', 'score', 'birthday', 'priority']) {
      final row = nullableRow(tester, name);
      expect(row.state, 'pristine',
          reason: 'row "$name" must reset to pristine');
      expect(row.value, 'null');
    }
    expect(find.text('form.isDirty = false'), findsOneWidget);
  });

  testWidgets('T9: typing into the notes nullable input flips notes to '
      '"set" state', (tester) async {
    await openDemoL(tester);
    final notesField = find.descendant(
      of: adapterByTomId('notes'),
      matching: find.byType(TextField),
    );
    expect(notesField, findsOneWidget);
    await tester.enterText(notesField, 'a typed note');
    await tester.pumpAndSettle();
    final row = nullableRow(tester, 'notes');
    expect(row.state, 'set',
        reason: 'typing into the nullable string input must flip notes to set');
    expect(row.value, 'a typed note');
  });
}

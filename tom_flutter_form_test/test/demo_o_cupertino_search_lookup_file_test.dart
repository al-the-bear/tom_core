/// Interaction tests for Demo O — Cupertino search / lookup / file +
/// nullable variants (Phase 5c).
///
/// Demo O renders the seven Phase 5c Cupertino concretes against
/// [Phase5cDemoState] (4 nullable rows bind into the kernel; search /
/// lookup / file rows stay form-local). The right-side state panel
/// echoes every row in a 110-px name column + monospace value column.
///
/// Coverage:
///   * baseline at wide viewport — every adapter renders, state panel
///     shows seeded values (city + lookup + null nullables)
///   * tapping the in-memory file picker populates the upload row to
///     "cupertino_demo_file.txt"
///   * typing into the nullable string input flips notes from null to
///     the typed value in the state panel
library;

import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoButton, CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
// ignore: implementation_imports
import 'package:tom_flutter_ui/src/forms/fields/tom_field_widget_adapter.dart';

import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/phase5_state.dart';

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

  setUp(() {
    phase5cDemoState = Phase5cDemoState();
  });

  Future<void> openDemoO(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo O: Cupertino search / lookup / file (Phase 5c)'),
        200,
        scrollable: find.descendant(
          of: find.byType(DemoListScreen),
          matching: find.byType(Scrollable),
        ),);
    await tester.tap(
        find.text('Demo O: Cupertino search / lookup / file (Phase 5c)'));
    await tester.pumpAndSettle();
  }

  Finder adapterByTomId(String tomId) {
    return find.byWidgetPredicate(
      (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
      description: 'TomFieldWidgetAdapter[$tomId]',
    );
  }

  String stateValue(WidgetTester tester, String name) {
    final nameFinder = find.text(name);
    expect(nameFinder, findsAtLeastNWidgets(1));
    final row =
        find.ancestor(of: nameFinder.first, matching: find.byType(Row));
    expect(row, findsAtLeastNWidgets(1));
    final texts = find
        .descendant(of: row.first, matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .toList();
    expect(texts.length, greaterThanOrEqualTo(2));
    return texts[1];
  }

  testWidgets('baseline at wide viewport — every Phase 5c Cupertino adapter '
      'renders, state panel echoes seeds (incl. null nullables)',
      (tester) async {
    await openDemoO(tester);
    for (final id in [
      'citySearch',
      'countryLookup',
      'upload',
      'notes',
      'age',
      'score',
      'birthday',
    ]) {
      expect(adapterByTomId(id), findsOneWidget,
          reason: 'field "$id" must render');
    }
    // Upload + nullable seeds.
    expect(stateValue(tester, 'upload'), '— null —');
    expect(stateValue(tester, 'notes'), '— null —');
    expect(stateValue(tester, 'age'), '— null —');
    expect(stateValue(tester, 'score'), '— null —');
    expect(stateValue(tester, 'birthday'), '— null —');
  });

  testWidgets('tapping the Cupertino file-upload trigger populates the '
      'upload row via the in-memory phase5cFilePicker', (tester) async {
    await openDemoO(tester);
    // The Cupertino file upload uses CupertinoButton.filled as its
    // trigger. Find the (single) CupertinoButton inside the upload
    // adapter — tapping it routes through the picker stub.
    final btn = find.descendant(
      of: adapterByTomId('upload'),
      matching: find.byType(CupertinoButton),
    );
    expect(btn, findsAtLeastNWidgets(1),
        reason: 'TomCupertinoFormFileUpload must render a CupertinoButton');
    await tester.ensureVisible(btn.first);
    await tester.pumpAndSettle();
    await tester.tap(btn.first);
    await tester.pumpAndSettle();
    // phase5cFilePicker returns "cupertino_demo_file.txt".
    final v = stateValue(tester, 'upload');
    expect(v.contains('cupertino_demo_file.txt'), isTrue,
        reason: 'state panel upload row must show the picked filename '
            '(was: $v)');
  });

  testWidgets('typing into the Cupertino nullable string input flips notes '
      'from null to the typed value', (tester) async {
    await openDemoO(tester);
    final notesField = find.descendant(
      of: adapterByTomId('notes'),
      matching: find.byType(CupertinoTextField),
    );
    expect(notesField, findsOneWidget);
    await tester.enterText(notesField, 'a cupertino note');
    await tester.pumpAndSettle();
    expect(stateValue(tester, 'notes'), 'a cupertino note',
        reason: 'typing must propagate to the bound TomNString → state panel');
  });
}

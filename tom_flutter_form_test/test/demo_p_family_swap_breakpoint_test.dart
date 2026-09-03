/// Interaction tests for Demo P — `FormFieldFamily` swap by breakpoint
/// (Phase 5c).
///
/// Demo P pre-builds two `Phase5cFamilyForm` instances (one Material,
/// one Cupertino) bound to the same [Phase5cFamilyState], then renders
/// the one matching the current 700-px breakpoint. The page-root
/// `TomFormStyleScope` flips form style at the same threshold via
/// `styleBpOverrides`. The header badge reads
/// "width: NNN px → family: `<kind>` (wide → Material | narrow → Cupertino)".
///
/// Coverage:
///   * baseline at wide viewport (>=700) — Material family rendered,
///     state-panel echoes Phase5cFamilyState seeds, badge reads
///     "wide → Material"
///   * narrow viewport (<700) — Cupertino family rendered, badge reads
///     "narrow → Cupertino"
///   * editing fullName in the active form propagates to the shared
///     state panel
///   * state survives the swap — edits made at wide width are still
///     visible in the state panel after a narrow-width rebuild
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
import 'package:tom_flutter_form_test/state/phase5_state.dart';

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

  setUp(() {
    phase5cFamilyState = Phase5cFamilyState();
  });

  Future<void> openDemoP(
    WidgetTester tester, {
    Size finalSize = const Size(2400, 2400),
  }) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
      find.text('Demo P: FormFieldFamily swap by breakpoint (Phase 5c)'),
      200,
      scrollable: find.descendant(
        of: find.byType(DemoListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(
      find.text('Demo P: FormFieldFamily swap by breakpoint (Phase 5c)'),
    );
    await tester.pumpAndSettle();
    if (finalSize != const Size(2400, 2400)) {
      tester.view.physicalSize = finalSize;
      await tester.pumpAndSettle();
    }
  }

  Finder adaptersByTomId(String tomId) {
    return find.byWidgetPredicate(
      (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
      description: 'TomFieldWidgetAdapter[$tomId]',
    );
  }

  /// Read the value cell from the shared-state panel. The shared-state
  /// panel sits last in the tree on the wide branch (right column) and
  /// last in the stacked column on narrow.
  String stateValue(WidgetTester tester, String name) {
    final nameFinder = find.text(name);
    expect(nameFinder, findsAtLeastNWidgets(1));
    // Last instance of the name — in the state panel on wide layout
    // (active form column doesn't render fixed name labels).
    final row = find.ancestor(of: nameFinder.last, matching: find.byType(Row));
    expect(row, findsAtLeastNWidgets(1));
    final texts = find
        .descendant(of: row.first, matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .toList();
    expect(texts.length, greaterThanOrEqualTo(2));
    return texts[1];
  }

  testWidgets('baseline at wide viewport — Material family renders, badge '
      'reads "wide → Material", state-panel echoes seeds', (tester) async {
    await openDemoP(tester);
    // Active-family section header.
    expect(
      find.text('Active family: material'),
      findsOneWidget,
      reason: 'wide branch must render the Material family form',
    );
    // Family + breakpoint badge.
    expect(find.textContaining('wide → Material'), findsOneWidget);
    // All five fields render exactly once (only the active form is in
    // the tree on the visible side, but the state panel observes the
    // Material form's observables — those are the same TomObjects bound
    // by both forms via _materialForm/_cupertinoForm.bind(state)).
    for (final id in [
      'fullName',
      'quantity',
      'ratio',
      'notifyMe',
      'eventDate',
    ]) {
      expect(
        adaptersByTomId(id),
        findsOneWidget,
        reason: 'field "$id" must render in the active family',
      );
    }
    // Phase5cFamilyState seeds.
    expect(stateValue(tester, 'fullName'), 'Ada Lovelace');
    expect(stateValue(tester, 'quantity'), '3');
    expect(stateValue(tester, 'ratio'), '0.75');
    expect(stateValue(tester, 'notifyMe'), 'true');
    expect(stateValue(tester, 'eventDate'), '2026-06-15');
  });

  testWidgets('narrow viewport (<700 px) flips the active family to '
      'Cupertino', (tester) async {
    await openDemoP(tester, finalSize: const Size(600, 2400));
    expect(
      find.text('Active family: cupertino'),
      findsOneWidget,
      reason: 'narrow branch must render the Cupertino family form',
    );
    expect(find.textContaining('narrow → Cupertino'), findsOneWidget);
    // Each field still renders exactly once in the active family.
    for (final id in [
      'fullName',
      'quantity',
      'ratio',
      'notifyMe',
      'eventDate',
    ]) {
      expect(adaptersByTomId(id), findsOneWidget);
    }
  });

  testWidgets('editing fullName in the active (Material) form propagates '
      'to the shared state panel', (tester) async {
    await openDemoP(tester);
    final input = find.descendant(
      of: adaptersByTomId('fullName'),
      matching: find.byType(TextField),
    );
    expect(input, findsOneWidget);
    await tester.enterText(input, 'Grace Hopper');
    await tester.pumpAndSettle();
    expect(
      stateValue(tester, 'fullName'),
      'Grace Hopper',
      reason:
          'edit in the active Material family must reach the shared '
          'TomString → state panel',
    );
  });

  testWidgets('state survives the family swap — wide-side edits are still '
      'visible in the state panel after re-sizing to narrow', (tester) async {
    await openDemoP(tester);
    final input = find.descendant(
      of: adaptersByTomId('fullName'),
      matching: find.byType(TextField),
    );
    await tester.enterText(input, 'Linus Torvalds');
    await tester.pumpAndSettle();
    expect(stateValue(tester, 'fullName'), 'Linus Torvalds');
    // Now flip to narrow — Cupertino form takes over but state survives
    // because both forms share the same Phase5cFamilyState.
    tester.view.physicalSize = const Size(600, 2400);
    await tester.pumpAndSettle();
    expect(
      find.text('Active family: cupertino'),
      findsOneWidget,
      reason: 'narrow branch must now render',
    );
    expect(
      stateValue(tester, 'fullName'),
      'Linus Torvalds',
      reason: 'wide-side edit must survive into the Cupertino form',
    );
  });
}

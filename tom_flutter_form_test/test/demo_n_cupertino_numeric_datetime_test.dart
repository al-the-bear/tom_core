/// Interaction tests for Demo N — Cupertino numeric + date/time
/// (Phase 5b).
///
/// Demo N renders the nine Phase 5b Cupertino concretes against
/// `phase5bDemoState` plus three form-local fields (eventTime,
/// downtime, billingPeriod). The right-side state panel echoes every
/// row in a fixed-width 110-px name column + monospace value column.
/// The page header shows a live "width: NNN px → inner themeSpec:
/// (wide|narrow) (…)" badge that flips at the 700-px breakpoint.
///
/// Coverage:
///   * baseline at wide viewport — every adapter renders, state-panel
///     rows show seeded values, breakpoint badge reads "wide"
///   * narrow viewport (<700) — adapters still render, badge reads
///     "narrow" branch
///   * typing in the quantity int input updates the state panel
///   * typing in the ratio double input updates the state panel
library;

import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoTextField;
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
    phase5bDemoState = Phase5bDemoState();
  });

  Future<void> openDemoN(
    WidgetTester tester, {
    Size finalSize = const Size(2400, 2400),
  }) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo N: Cupertino numeric + date/time (Phase 5b)'),
        200);
    await tester.tap(
        find.text('Demo N: Cupertino numeric + date/time (Phase 5b)'));
    await tester.pumpAndSettle();
    if (finalSize != const Size(2400, 2400)) {
      tester.view.physicalSize = finalSize;
      await tester.pumpAndSettle();
    }
  }

  Finder adapterByTomId(String tomId) {
    return find.byWidgetPredicate(
      (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
      description: 'TomFieldWidgetAdapter[$tomId]',
    );
  }

  /// Read a row from the form-state panel (110-px name SizedBox +
  /// Expanded value Text).
  String stateValue(WidgetTester tester, String name) {
    final nameFinder = find.text(name);
    expect(nameFinder, findsAtLeastNWidgets(1),
        reason: 'state row "$name" must exist');
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

  testWidgets('baseline at wide viewport — every Phase 5b adapter renders, '
      'state panel echoes seeds, breakpoint badge reads "wide"',
      (tester) async {
    await openDemoN(tester);
    for (final id in [
      'quantity',
      'brightness',
      'ratio',
      'price',
      'eventDate',
      'eventTime',
      'eventDateTime',
      'downtime',
      'billingPeriod',
    ]) {
      expect(adapterByTomId(id), findsOneWidget,
          reason: 'field "$id" must render');
    }
    // Seeds.
    expect(stateValue(tester, 'quantity'), '8');
    expect(stateValue(tester, 'brightness'), '50');
    expect(stateValue(tester, 'ratio'), '1.50');
    expect(stateValue(tester, 'price (USD)'), '199.99');
    expect(stateValue(tester, 'eventDate'), '2026-05-12');
    expect(stateValue(tester, 'eventTime'), '09:30');
    expect(stateValue(tester, 'eventDateTime'), '2026-05-12 09:30');
    expect(stateValue(tester, 'downtime'), '1h 30m');
    expect(stateValue(tester, 'billingPeriod'), '2026-05-01 → 2026-05-31');
    // Wide-branch breakpoint badge text.
    expect(find.textContaining('inner themeSpec: wide'), findsOneWidget,
        reason: 'wide viewport must produce the "wide" badge branch');
  });

  testWidgets('narrow viewport (<700 px) flips the breakpoint badge to '
      '"narrow" while keeping every field rendered', (tester) async {
    await openDemoN(tester, finalSize: const Size(600, 2400));
    expect(find.textContaining('inner themeSpec: narrow'), findsOneWidget,
        reason: 'narrow viewport must produce the "narrow" badge branch');
    // Adapters still all present in the narrow stacked layout.
    for (final id in [
      'quantity',
      'brightness',
      'ratio',
      'price',
      'eventDate',
      'eventTime',
      'eventDateTime',
      'downtime',
      'billingPeriod',
    ]) {
      expect(adapterByTomId(id), findsOneWidget,
          reason: 'field "$id" must still render in the narrow branch');
    }
  });

  testWidgets('typing in the quantity Cupertino int input updates the '
      'state panel', (tester) async {
    await openDemoN(tester);
    final qtyInput = find.descendant(
      of: adapterByTomId('quantity'),
      matching: find.byType(CupertinoTextField),
    );
    expect(qtyInput, findsOneWidget,
        reason: 'TomCupertinoFormIntInput must render a CupertinoTextField');
    await tester.enterText(qtyInput, '17');
    await tester.pumpAndSettle();
    expect(stateValue(tester, 'quantity'), '17',
        reason: 'typing must propagate to the bound TomInt → state panel');
  });

  testWidgets('typing in the ratio Cupertino double input updates the '
      'state panel', (tester) async {
    await openDemoN(tester);
    final ratioInput = find.descendant(
      of: adapterByTomId('ratio'),
      matching: find.byType(CupertinoTextField),
    );
    expect(ratioInput, findsOneWidget);
    await tester.enterText(ratioInput, '3.25');
    await tester.pumpAndSettle();
    expect(stateValue(tester, 'ratio'), '3.25',
        reason: 'typing must propagate to the bound TomDouble → state panel');
  });
}

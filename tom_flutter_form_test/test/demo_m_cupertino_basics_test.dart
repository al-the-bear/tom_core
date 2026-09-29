/// Interaction tests for Demo M — Material vs Cupertino (Phase 5a).
///
/// Demo M renders two side-by-side panels that bind to the SAME
/// [Phase5DemoState]. A page-root [TomFormStyleScope] flips between
/// Material and Cupertino on a ChoiceChip; pair-wise observers keep
/// every field in lockstep across the two panels.
///
/// We probe both:
///   * the shared "Shared state (Phase5DemoState)" panel rows — the
///     single source of truth for the Material side's bound TomClass
///   * the actual Material and Cupertino field controllers / value
///     widgets — proving the pair-wise sync runs end-to-end.
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
    final jsonStr = await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  // Same disposal-listener-leak pattern as Demos I/J/K/L. The shared
  // phase5DemoState gets rebound by every Demo M instance; reassigning
  // breaks the chain to listeners on a previously-disposed form.
  setUp(() {
    phase5DemoState = Phase5DemoState();
  });

  Future<void> openDemoM(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
      find.text('Demo M: Material vs Cupertino (Phase 5a)'),
      200,
      scrollable: find.descendant(
        of: find.byType(DemoListScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Demo M: Material vs Cupertino (Phase 5a)'));
    await tester.pumpAndSettle();
  }

  /// Find adapters by tomId. Demo M renders TWO adapters per id (one
  /// per panel) — callers that need just one side scope through the
  /// panel header card.
  Finder adaptersByTomId(String tomId) {
    return find.byWidgetPredicate(
      (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
      description: 'TomFieldWidgetAdapter[$tomId]',
    );
  }

  /// The Material panel is the first card containing a child with the
  /// "Material concretes" title text; the Cupertino panel is the
  /// second. Resolve them via ancestor lookup from the title Text.
  Finder panelByTitle(String title) {
    return find.ancestor(of: find.text(title), matching: find.byType(Card));
  }

  /// Read the value cell from the shared-state panel. Each row is a
  /// Row with a fixed 110-px name SizedBox and an Expanded value Text.
  /// We locate the row by its name Text and return the value Text data.
  String sharedStateValue(WidgetTester tester, String name) {
    final nameFinder = find.text(name);
    expect(
      nameFinder,
      findsAtLeastNWidgets(1),
      reason: 'shared-state row "$name" must exist',
    );
    final row = find.ancestor(
      of: nameFinder.last, // shared-state panel sits last in tree
      matching: find.byType(Row),
    );
    expect(row, findsAtLeastNWidgets(1));
    final texts = find
        .descendant(of: row.first, matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .toList();
    expect(
      texts.length,
      greaterThanOrEqualTo(2),
      reason: 'shared-state row "$name" must have name + value Text',
    );
    return texts[1];
  }

  // ---------------------------------------------------------------------
  // Baseline
  // ---------------------------------------------------------------------

  testWidgets('baseline — both panels render every field, shared-state '
      'panel echoes the seeded values', (tester) async {
    await openDemoM(tester);
    // Style ChoiceChips.
    expect(
      find.widgetWithText(ChoiceChip, 'TomFormStyle.material3'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ChoiceChip, 'TomCupertinoFormStyle.cupertino'),
      findsOneWidget,
    );
    // Panel headers.
    expect(panelByTitle('Material concretes'), findsOneWidget);
    expect(panelByTitle('Cupertino concretes'), findsOneWidget);
    // Each shared-binding field renders TWICE (one per panel).
    for (final id in [
      'name',
      'color',
      'size',
      'tags',
      'search',
      'notifications',
      'darkMode',
    ]) {
      expect(
        adaptersByTomId(id),
        findsNWidgets(2),
        reason: 'field "$id" must render in both panels',
      );
    }
    // Shared-state panel reflects the seeds.
    expect(sharedStateValue(tester, 'name'), 'Apollo 11');
    expect(sharedStateValue(tester, 'color'), 'blue');
    expect(sharedStateValue(tester, 'size'), 'M');
    expect(
      sharedStateValue(tester, 'search'),
      '—',
      reason: 'empty search renders as em-dash placeholder',
    );
    expect(sharedStateValue(tester, 'notifications'), 'true');
    expect(sharedStateValue(tester, 'darkMode'), 'false');
  });

  // ---------------------------------------------------------------------
  // Pair-wise sync
  // ---------------------------------------------------------------------

  testWidgets('pair-wise sync — typing in the Material name input '
      'propagates to the Cupertino name input AND the shared state', (
    tester,
  ) async {
    await openDemoM(tester);
    // The Material name input lives inside the "Material concretes" Card.
    final matNameInput = find.descendant(
      of: panelByTitle('Material concretes'),
      matching: find.descendant(
        of: adaptersByTomId('name'),
        matching: find.byType(TextField),
      ),
    );
    expect(matNameInput, findsOneWidget);
    await tester.enterText(matNameInput, 'Voyager 2');
    await tester.pumpAndSettle();
    // Cupertino side's name CupertinoTextField must now show "Voyager 2".
    final cupNameInput = find.descendant(
      of: panelByTitle('Cupertino concretes'),
      matching: find.descendant(
        of: adaptersByTomId('name'),
        matching: find.byType(CupertinoTextField),
      ),
    );
    expect(cupNameInput, findsOneWidget);
    final cupTf = tester.widget<CupertinoTextField>(cupNameInput);
    expect(
      cupTf.controller?.text,
      'Voyager 2',
      reason:
          'pair-wise sync must mirror the Material edit to the '
          'Cupertino name field',
    );
    // Shared-state panel echoes the new value.
    expect(sharedStateValue(tester, 'name'), 'Voyager 2');
  });

  testWidgets('pair-wise sync — toggling the Material notifications '
      'switch also flips the Cupertino switch', (tester) async {
    await openDemoM(tester);
    // Find the Switch inside the Material notifications adapter.
    final matSwitch = find.descendant(
      of: panelByTitle('Material concretes'),
      matching: find.descendant(
        of: adaptersByTomId('notifications'),
        matching: find.byType(Switch),
      ),
    );
    expect(matSwitch, findsOneWidget);
    final initial = tester.widget<Switch>(matSwitch).value;
    expect(initial, isTrue, reason: 'seed notifications=true');
    await tester.tap(matSwitch);
    await tester.pumpAndSettle();
    // Material side now off.
    expect(
      tester.widget<Switch>(matSwitch).value,
      isFalse,
      reason: 'tapping the Material switch must flip it',
    );
    // Shared state mirrors the change.
    expect(sharedStateValue(tester, 'notifications'), 'false');
  });

  testWidgets('pair-wise sync — selecting a Material tag chip propagates '
      'to the Cupertino tags field', (tester) async {
    // `tags` is the only pair routed through `_pairList`, and the only
    // multi-select the shared `TomClass` carries: a `TomList<TomString>`
    // bound into both panels' `List<String>` fields, so the seed below
    // proves the bind and the tap proves the pair-wise sync.
    await openDemoM(tester);

    List<String> tagsOf(String panel) {
      final adapter = tester.widget<TomFieldWidgetAdapter>(
        find.descendant(
          of: panelByTitle(panel),
          matching: adaptersByTomId('tags'),
        ),
      );
      return (adapter.field.get() as List).cast<String>();
    }

    expect(tagsOf('Material concretes'), [
      'alpha',
    ], reason: 'bound from Phase5DemoState.tags');
    expect(tagsOf('Cupertino concretes'), ['alpha']);

    final betaChip = find.descendant(
      of: panelByTitle('Material concretes'),
      matching: find.descendant(
        of: adaptersByTomId('tags'),
        matching: find.widgetWithText(FilterChip, 'Beta'),
      ),
    );
    expect(betaChip, findsOneWidget);
    await tester.ensureVisible(betaChip);
    await tester.pumpAndSettle();
    await tester.tap(betaChip);
    await tester.pumpAndSettle();

    expect(tagsOf('Material concretes'), ['alpha', 'beta']);
    expect(
      tagsOf('Cupertino concretes'),
      ['alpha', 'beta'],
      reason: '_pairList must propagate the list edit across the panels',
    );
    expect(sharedStateValue(tester, 'tags'), 'alpha, beta');
  });

  // ---------------------------------------------------------------------
  // Style switch
  // ---------------------------------------------------------------------

  testWidgets('style switch — selecting "TomCupertinoFormStyle.cupertino" '
      'updates the ChoiceChip selection state', (tester) async {
    await openDemoM(tester);
    final matChip = find.widgetWithText(ChoiceChip, 'TomFormStyle.material3');
    final cupChip = find.widgetWithText(
      ChoiceChip,
      'TomCupertinoFormStyle.cupertino',
    );
    // Initial: material is selected.
    expect((tester.widget<ChoiceChip>(matChip)).selected, isTrue);
    expect((tester.widget<ChoiceChip>(cupChip)).selected, isFalse);
    await tester.ensureVisible(cupChip);
    await tester.pumpAndSettle();
    await tester.tap(cupChip);
    await tester.pumpAndSettle();
    expect((tester.widget<ChoiceChip>(matChip)).selected, isFalse);
    expect(
      (tester.widget<ChoiceChip>(cupChip)).selected,
      isTrue,
      reason: 'tapping the cupertino chip must select it',
    );
    // Both panels still render after the style swap.
    expect(panelByTitle('Material concretes'), findsOneWidget);
    expect(panelByTitle('Cupertino concretes'), findsOneWidget);
  });
}

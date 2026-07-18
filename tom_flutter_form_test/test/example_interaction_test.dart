/// Interaction tests for the H-series *example* screens (review finding
/// tests §63).
///
/// The example screens (`lib/examples/example_h_*.dart`) were covered only
/// by `example_smoke_test.dart` (mount + static-text assertions) and the
/// mount-only `example_screenshot_test.dart`. Neither drives any
/// interaction, so a broken Save/Discard wire, a mis-bound master-detail
/// selection, or a list mutation that never reaches the bound observable
/// would pass every existing example test.
///
/// These `testWidgets` cases exercise the genuinely-interactive paths §63
/// names, against the real example widgets (not the demo variants):
///   * master-detail selection rebinds the detail pane (H-A);
///   * editing a detail field marks the form dirty and Discard reverts it;
///   * Save with an invalid field surfaces the detail error view;
///   * Add appends a row the bound observable list reflects;
///   * Move-down reorders the bound observable list.
///
/// The screenshot suite stays mount-only by design (review §63: "Mount-
/// without-exception is the right coverage for screenshots").
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
// TomFieldWidgetAdapter is not exported from the public barrel; it is the
// reliable handle for locating a field's TextField by its `tomId` (the
// label text is rendered as a sibling, not an ancestor, of the TextField,
// so the usual `find.ancestor` recipe finds nothing). Mirrors the approach
// used by `demo_a_lifecycle_test.dart`.
// ignore: implementation_imports
import 'package:tom_flutter_ui/src/forms/fields/tom_field_widget_adapter.dart';

import 'package:tom_flutter_form_test/examples/example_h_a_master_detail.dart';
import 'package:tom_flutter_form_test/examples/example_list_screen.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/phase2a_state.dart';

import 'support/test_fonts.dart';

// ---------------------------------------------------------------------------
// Fixture — a fresh 3-customer directory per test. H-A binds the shared
// `phase2aCustomers` global in initState, and the add / reorder cases
// mutate it, so each test reseeds the global to stay isolated.
// ---------------------------------------------------------------------------

CustomerDirectory _seedCustomers() {
  final dir = CustomerDirectory();
  void add(String name, String email, String phone, String company,
      String tier) {
    final c = Customer();
    c.fullName | name;
    c.email | email;
    c.phone | phone;
    c.company | company;
    c.tier | tier;
    dir.customers.add(c);
  }

  add('Ada Lovelace', 'ada@analytical.example', '+44 20 7946 0958',
      'Analytical Engines Ltd.', 'gold');
  add('Grace Hopper', 'grace@navy.example', '+1 202 555 0140',
      'COBOL Systems Inc.', 'platinum');
  add('Linus Torvalds', 'torvalds@kernel.example', '+1 503 555 0177',
      'Linux Foundation', 'silver');
  return dir;
}


void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    final jsonStr = await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
    await loadTestFonts();
  });

  setUp(() {
    phase2aCustomers = _seedCustomers();
  });

  Future<void> pump(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: widget,
    ));
    await tester.pumpAndSettle();
  }

  /// Locate a Tom field's underlying [TextField] by the field's [tomId].
  Finder fieldByTomId(String tomId) => find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is TomFieldWidgetAdapter && w.field.tomId == tomId,
          description: 'TomFieldWidgetAdapter[$tomId]',
        ),
        matching: find.byType(TextField),
      );

  /// Current text in the (single) detail-pane field with [tomId].
  String fieldText(WidgetTester tester, String tomId) =>
      tester.widget<TextField>(fieldByTomId(tomId)).controller?.text ?? '';

  /// Tap a button by visible label, trying the concrete button types the
  /// detail pane uses (FilledButton for Save, OutlinedButton for Discard).
  Future<void> tapLabeled(WidgetTester tester, String label) async {
    Finder finder = find.widgetWithText(FilledButton, label);
    if (finder.evaluate().isEmpty) {
      finder = find.widgetWithText(OutlinedButton, label);
    }
    expect(finder, findsAtLeastNWidgets(1),
        reason: 'No FilledButton/OutlinedButton labelled "$label"');
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  group('Example H-A — master/detail interaction', () {
    testWidgets('selecting a master row rebinds the detail pane',
        (tester) async {
      await pump(tester,
          const ExampleHAMasterDetail(family: ExampleFamily.material));

      // initialSelectedIndex: 0 → the detail pane shows Ada to start.
      expect(fieldText(tester, 'fullName'), 'Ada Lovelace');

      // Tap the second customer in the master list.
      await tester.tap(find.text('Grace Hopper'));
      await tester.pumpAndSettle();

      // The detail pane is now bound to Grace's customer record.
      expect(fieldText(tester, 'fullName'), 'Grace Hopper');
      expect(fieldText(tester, 'email'), 'grace@navy.example');
    });

    testWidgets('editing a detail field marks dirty; Discard reverts it',
        (tester) async {
      await pump(tester,
          const ExampleHAMasterDetail(family: ExampleFamily.material));

      expect(find.widgetWithText(Chip, 'Dirty'), findsNothing,
          reason: 'A freshly-bound detail form is pristine');

      await tester.enterText(fieldByTomId('fullName'), 'Ada Lovelace (edited)');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Chip, 'Dirty'), findsOneWidget,
          reason: 'Editing a field marks the detail form dirty');

      await tapLabeled(tester, 'Discard');
      expect(find.widgetWithText(Chip, 'Dirty'), findsNothing,
          reason: 'Discard clears the dirty state');
      expect(fieldText(tester, 'fullName'), 'Ada Lovelace',
          reason: 'Discard reverts the edited field to the bound value');
    });

    testWidgets('Save with an invalid email surfaces the detail error view',
        (tester) async {
      await pump(tester,
          const ExampleHAMasterDetail(family: ExampleFamily.material));

      await tester.enterText(fieldByTomId('email'), 'not-an-email');
      await tester.pumpAndSettle();

      await tapLabeled(tester, 'Save');
      // save() validates asynchronously and fires a FormValidatedEvent that
      // the TomErrorView listens for; give it a beat to resolve.
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // TomErrorView collapses to SizedBox.shrink() when there are no
      // errors, so its title only renders once validation fails.
      expect(find.text('Detail form errors'), findsOneWidget,
          reason: 'An invalid Save must surface the detail error view');
      // The error key must be resolved through the resource provider, not
      // leaked raw into the UI.
      expect(find.textContaining('error.email'), findsNothing,
          reason: 'The raw validator key must not reach the user');
    });

    testWidgets('Add appends a customer the bound observable list reflects',
        (tester) async {
      await pump(tester,
          const ExampleHAMasterDetail(family: ExampleFamily.material));

      expect(phase2aCustomers.customers.length, 3);
      expect(find.text('Customers (3)'), findsOneWidget);

      // The master toolbar's Add button uses the default 'Add' label.
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(phase2aCustomers.customers.length, 4,
          reason: 'Add must append a row to the bound observable list');
      expect(find.text('Customers (4)'), findsOneWidget,
          reason: 'The master header reflects the new list length');
    });

    testWidgets('Move-down reorders the bound observable list',
        (tester) async {
      await pump(tester,
          const ExampleHAMasterDetail(family: ExampleFamily.material));

      // Row 0 (Ada) is selected initially, so Move-down is enabled.
      expect(phase2aCustomers.customers[0].fullName.get(), 'Ada Lovelace');
      expect(phase2aCustomers.customers[1].fullName.get(), 'Grace Hopper');

      final moveDown = find.byTooltip('Move down');
      expect(moveDown, findsOneWidget);
      await tester.ensureVisible(moveDown);
      await tester.pumpAndSettle();
      await tester.tap(moveDown);
      await tester.pumpAndSettle();

      // The reorder lands on the bound observable list, not just the view.
      expect(phase2aCustomers.customers[0].fullName.get(), 'Grace Hopper',
          reason: 'Move-down swaps the selected row past its successor');
      expect(phase2aCustomers.customers[1].fullName.get(), 'Ada Lovelace');
    });
  });
}

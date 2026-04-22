/// Round-6 (a) regression: Demo H-A renders two master-detail scaffolds
/// bound to the same customer list. When scaffold A's detail form saves
/// changes to the selected customer, scaffold B's detail (bound to the
/// same `Customer`) must reflect those changes immediately — without the
/// user re-selecting the row.
///
/// The fix lives in `TomForm.bind()`: every bound form now registers an
/// observer on its binding so external mutations re-snapshot the form's
/// fields. The framework test below exercises the propagation directly;
/// the UI scenario test then exercises the fix end-to-end through the
/// Demo H-A tile.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'package:tom_flutter_form_test/forms/customer_detail_form.dart';
import 'package:tom_flutter_form_test/main.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/phase2a_state.dart';

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

  test(
      '(a) two TomForms bound to the same Customer share saves via binding observer',
      () async {
    final customer = Customer();
    customer.fullName.set('Ada Lovelace');
    customer.email.set('ada@example.com');

    final formA = CustomerDetailForm();
    final formB = CustomerDetailForm();
    formA.bind(customer);
    formB.bind(customer);

    expect(formA.fullName.get(), 'Ada Lovelace');
    expect(formB.fullName.get(), 'Ada Lovelace');

    // Edit scaffold A's form, then save → write-through to the customer.
    formA.fullName.set('Ada EDITED-A');
    final ok = await formA.save();
    expect(ok, isTrue, reason: 'save should succeed for valid data');

    // Customer now holds the new value (writeback).
    expect(customer.fullName.get(), 'Ada EDITED-A');

    // Form B is bound to the SAME customer — the binding observer
    // installed by `bind()` must have re-snapshotted form B from the
    // customer so its fields show the new value too.
    expect(formB.fullName.get(), 'Ada EDITED-A',
        reason:
            'Form B must reflect external mutation via the binding observer');
  });

  testWidgets(
      '(a) Demo H-A: editing in scaffold A and saving updates scaffold B detail',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo H-A: Master-Detail Customer Editor'), 200);
    await tester.tap(find.text('Demo H-A: Master-Detail Customer Editor'));
    await tester.pumpAndSettle();

    // Scaffold B preselects row 0 (Ada). Tap row 0 in scaffold A's master
    // pane so both details bind to the same customer.
    final adaTiles = find.text('Ada Lovelace');
    expect(adaTiles, findsAtLeastNWidgets(1));
    await tester.tap(adaTiles.first);
    await tester.pumpAndSettle();

    // Find the two name fields (controllers start with 'Ada').
    EditableText nameForController(String prefix) =>
        find.byType(EditableText).evaluate()
            .map((e) => e.widget as EditableText)
            .firstWhere((w) => w.controller.text.startsWith(prefix));
    final firstAda = nameForController('Ada');
    expect(firstAda.controller.text, 'Ada Lovelace');

    // Locate scaffold A's name TextField, give it a unique name + valid
    // email (the seed email "ada@analytical.example" trips the email
    // validator). Then save.
    final tfFinder = find.ancestor(
      of: find.byWidget(firstAda),
      matching: find.byType(TextField),
    );
    expect(tfFinder, findsAtLeastNWidgets(1));
    await tester.enterText(tfFinder.first, 'Ada Lovelace EDITED-A');
    await tester.pumpAndSettle();

    // Same trick for the email — find the scaffold A's email field.
    final emailEd = find.byType(EditableText).evaluate()
        .map((e) => e.widget as EditableText)
        .firstWhere((w) => w.controller.text.contains('@'));
    final emailTf = find.ancestor(
      of: find.byWidget(emailEd),
      matching: find.byType(TextField),
    );
    await tester.enterText(emailTf.first, 'ada@example.com');
    await tester.pumpAndSettle();

    final saveButtons = find.widgetWithText(FilledButton, 'Save');
    expect(saveButtons, findsAtLeastNWidgets(1));
    await tester.ensureVisible(saveButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(saveButtons.first, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Both scaffold A's and scaffold B's name fields must now show the
    // edited value — B picked it up via the binding observer.
    final adaEditedControllers = find.byType(EditableText).evaluate()
        .map((e) => e.widget as EditableText)
        .map((w) => w.controller.text)
        .where((t) => t.contains('EDITED-A'))
        .toList();
    expect(adaEditedControllers.length, greaterThanOrEqualTo(2),
        reason:
            'Both scaffolds A and B should display the edited name after save '
            '(binding observer propagation).');
  });

  testWidgets(
      '(a2) Demo H-A detail pane shows the full form including the Save button',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FormDemoApp());
    await tester.scrollUntilVisible(
        find.text('Demo H-A: Master-Detail Customer Editor'), 200);
    await tester.tap(find.text('Demo H-A: Master-Detail Customer Editor'));
    await tester.pumpAndSettle();

    // Both scaffold detail panes are bound to row 0 (Ada); both Save
    // buttons should be present AND fully painted within the viewport
    // (no need to scroll the detail pane to reveal them).
    final saveButtons = find.widgetWithText(FilledButton, 'Save');
    expect(saveButtons, findsAtLeastNWidgets(1),
        reason: 'Detail pane Save button should be in the tree');

    final viewportSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    for (final el in saveButtons.evaluate()) {
      final box = el.renderObject as RenderBox?;
      expect(box, isNotNull);
      expect(box!.hasSize, isTrue);
      final topLeft = box.localToGlobal(Offset.zero);
      final bottomRight = topLeft + Offset(box.size.width, box.size.height);
      expect(bottomRight.dy, lessThanOrEqualTo(viewportSize.height),
          reason:
              'Save button bottom (${bottomRight.dy}) must fit inside the '
              'viewport (${viewportSize.height}); container should be tall '
              'enough to render the full detail form.');
    }
  });
}

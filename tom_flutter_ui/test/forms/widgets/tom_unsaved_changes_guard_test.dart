/// Behavioural coverage for `guardUnsavedChanges` and `TomUnsavedChangesGuard`.
///
/// This is the one place in the library that stands between a user's edits and
/// losing them, so the assertions below are about *consequences*, not about
/// which dialog appears:
///
///   * **Cancel must leave everything exactly as it was** — the pending action
///     un-run *and* the edit still in the form. A "Cancel" that quietly
///     discarded would be the worst possible failure mode here.
///
///   * **A failed Save behaves like Cancel.** Save is the only branch whose
///     outcome is not decided by the user: `form.save()` can refuse. Sending
///     the user onwards anyway strands them away from a row they cannot see
///     the errors on.
///
///   * **A clean form must not prompt at all.** The fast path is what makes it
///     safe to route every navigation through the guard; if it prompted on a
///     pristine form, hosts would start guarding conditionally and the
///     guarantee would erode.
///
/// The widget half adds one thing on top: `canPop` has to track the form's
/// dirtiness *live*, which is why the state subscribes to `form.changes`
/// rather than reading `isDirty` once.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../support/list_form_fixtures.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// A row form bound to a real item, so `isDirty` and `discard()` have a
/// baseline to work against.
OrderItemForm _form({String product = 'A'}) {
  final item = OrderItem();
  item.product | product;
  item.quantity | '1';
  return OrderItemForm()..bind(item);
}

/// A form whose `quantity` is required too — blanking it makes `save()` fail
/// while leaving `product` alone, which is how the "Save refuses" branch is
/// reached without also destroying the value under assertion.
TwoRequiredFieldsForm _strictForm() {
  final item = OrderItem();
  item.product | 'A';
  item.quantity | '1';
  return TwoRequiredFieldsForm()..bind(item);
}

/// Edits a field and drains the validation debounce `setValue` arms, so no
/// timer outlives the test.
Future<void> _edit(
  WidgetTester tester,
  TomField<String> field,
  String value,
) async {
  field.setValue(value);
  await tester.pump(const Duration(milliseconds: 400));
}

/// Pumps a host with a single button that runs the guard over [form],
/// recording the action's execution and the returned choice.
Future<void> _pumpGuardHost(
  WidgetTester tester, {
  required TomForm form,
  required List<String> log,
  String? title,
  String? message,
  String? saveLabel,
  String? discardLabel,
  String? cancelLabel,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final choice = await guardUnsavedChanges(
              context: context,
              form: form,
              action: () async => log.add('action'),
              title: title ?? 'Unsaved changes',
              message: message ??
                  'You have unsaved edits. What would you like to do?',
              saveLabel: saveLabel ?? 'Save',
              discardLabel: discardLabel ?? 'Discard',
              cancelLabel: cancelLabel ?? 'Cancel',
            );
            log.add('choice:${choice.name}');
          },
          child: const Text('go'),
        ),
      ),
    ),
  ));
}

/// Pushes a second route whose body is wrapped in a [TomUnsavedChangesGuard],
/// then returns with that route on top. Tapping `leave` calls `maybePop`.
Future<void> _pumpGuardedRoute(
  WidgetTester tester, {
  required TomForm form,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: TomUnsavedChangesGuard(
                  form: form,
                  child: Builder(
                    builder: (inner) => TextButton(
                      onPressed: () => Navigator.of(inner).maybePop(),
                      child: const Text('leave'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

bool _canPop(WidgetTester tester) => tester
    .widgetList(find.descendant(
      of: find.byType(TomUnsavedChangesGuard),
      matching: find.byWidgetPredicate((w) => w is PopScope),
    ))
    .whereType<PopScope>()
    .first
    .canPop;

void main() {
  setUpAll(initializeReflection);

  // -------------------------------------------------------------------------
  group('guardUnsavedChanges on a clean form', () {
    testWidgets('runs the action without prompting', (tester) async {
      final log = <String>[];
      await _pumpGuardHost(tester, form: _form(), log: log);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved changes'), findsNothing);
      expect(log, ['action', 'choice:discard']);
    });

    testWidgets('reports discard — there was nothing to save', (tester) async {
      final log = <String>[];
      await _pumpGuardHost(tester, form: _form(), log: log);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(log.last, 'choice:discard');
    });
  });

  // -------------------------------------------------------------------------
  group('guardUnsavedChanges dialog', () {
    testWidgets('a dirty form gets the three-way prompt', (tester) async {
      final form = _form();
      final log = <String>[];
      await _pumpGuardHost(tester, form: form, log: log);
      await _edit(tester, form.product, 'X');

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(
        find.text('You have unsaved edits. What would you like to do?'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Discard'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget,
          reason: 'Save is the affirmative action and carries the emphasis');
      expect(log, isEmpty, reason: 'nothing happens until the user answers');
    });

    testWidgets('the barrier does not dismiss it', (tester) async {
      // An accidental tap outside must not resolve a question about data loss.
      final form = _form();
      await _pumpGuardHost(tester, form: form, log: <String>[]);
      await _edit(tester, form.product, 'X');
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved changes'), findsOneWidget);
    });

    testWidgets('honours custom labels and copy', (tester) async {
      final form = _form();
      await _pumpGuardHost(
        tester,
        form: form,
        log: <String>[],
        title: 'Leave the row?',
        message: 'Your changes are not stored yet.',
        saveLabel: 'Keep',
        discardLabel: 'Drop',
        cancelLabel: 'Stay',
      );
      await _edit(tester, form.product, 'X');

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Leave the row?'), findsOneWidget);
      expect(find.text('Your changes are not stored yet.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Keep'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Drop'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Stay'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('guardUnsavedChanges choices', () {
    testWidgets('Cancel leaves both the action and the edit untouched',
        (tester) async {
      final form = _form();
      final log = <String>[];
      await _pumpGuardHost(tester, form: form, log: log);
      await _edit(tester, form.product, 'X');

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(log, ['choice:cancel']);
      expect(form.product.get(), 'X');
      expect(form.isDirty, isTrue);
    });

    testWidgets('Discard rolls the form back, then proceeds', (tester) async {
      final form = _form();
      final log = <String>[];
      await _pumpGuardHost(tester, form: form, log: log);
      await _edit(tester, form.product, 'X');

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(form.product.get(), 'A');
      expect(form.isDirty, isFalse);
      expect(log, ['action', 'choice:discard'],
          reason: 'the rollback happens before the action runs');
    });

    testWidgets('Save commits to the binding, then proceeds', (tester) async {
      final form = _form();
      final log = <String>[];
      await _pumpGuardHost(tester, form: form, log: log);
      await _edit(tester, form.product, 'X');

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(form.currentBinding?.product.get(), 'X');
      expect(form.isDirty, isFalse);
      expect(log, ['action', 'choice:save']);
    });

    testWidgets('a Save the form refuses does not run the action',
        (tester) async {
      final form = _strictForm();
      final log = <String>[];
      await _pumpGuardHost(tester, form: form, log: log);
      await _edit(tester, form.quantity, ''); // required — save will refuse

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(log, ['choice:save'], reason: 'no action — the save failed');
      expect(form.isDirty, isTrue);
      expect(form.currentBinding?.quantity.get(), '1',
          reason: 'a refused save writes nothing back');
    });
  });

  // -------------------------------------------------------------------------
  group('TomUnsavedChangesGuard', () {
    testWidgets('a clean form pops straight through', (tester) async {
      await _pumpGuardedRoute(tester, form: _form());

      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved changes'), findsNothing);
      expect(find.text('open'), findsOneWidget, reason: 'back on the first route');
    });

    testWidgets('canPop tracks the form becoming dirty', (tester) async {
      // Read live rather than at build time: the edit arrives long after the
      // host's build returned.
      final form = _form();
      await _pumpGuardedRoute(tester, form: form);
      expect(_canPop(tester), isTrue);

      await _edit(tester, form.product, 'X');

      expect(_canPop(tester), isFalse);
    });

    testWidgets('canPop returns to true once the edit is rolled back',
        (tester) async {
      final form = _form();
      await _pumpGuardedRoute(tester, form: form);
      await _edit(tester, form.product, 'X');
      expect(_canPop(tester), isFalse);

      form.discard();
      await tester.pump();

      expect(_canPop(tester), isTrue);
    });

    testWidgets('a dirty form is prompted instead of popped', (tester) async {
      final form = _form();
      await _pumpGuardedRoute(tester, form: form);
      await _edit(tester, form.product, 'X');

      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(find.text('leave'), findsOneWidget, reason: 'still on the route');
    });

    testWidgets('Cancel keeps the route', (tester) async {
      final form = _form();
      await _pumpGuardedRoute(tester, form: form);
      await _edit(tester, form.product, 'X');
      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('leave'), findsOneWidget);
      expect(form.product.get(), 'X');
    });

    testWidgets('Discard rolls back and pops', (tester) async {
      final form = _form();
      await _pumpGuardedRoute(tester, form: form);
      await _edit(tester, form.product, 'X');
      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(form.product.get(), 'A');
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('Save commits and pops', (tester) async {
      final form = _form();
      await _pumpGuardedRoute(tester, form: form);
      await _edit(tester, form.product, 'X');
      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(form.currentBinding?.product.get(), 'X');
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a refused Save keeps the route', (tester) async {
      final form = _strictForm();
      await _pumpGuardedRoute(tester, form: form);
      await _edit(tester, form.quantity, '');
      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('leave'), findsOneWidget);
      expect(form.isDirty, isTrue);
    });

    testWidgets('the subscription follows a swapped-in form', (tester) async {
      final first = _form();
      final second = _form();
      Widget host(TomForm form) => MaterialApp(
            home: Scaffold(
              body: TomUnsavedChangesGuard(
                form: form,
                child: const Text('body'),
              ),
            ),
          );

      await tester.pumpWidget(host(first));
      await tester.pumpWidget(host(second));
      await _edit(tester, second.product, 'X');

      expect(_canPop(tester), isFalse,
          reason: 'the new form drives canPop after the swap');
    });

    testWidgets('the old form stops driving the guard after a swap',
        (tester) async {
      final first = _form();
      final second = _form();
      Widget host(TomForm form) => MaterialApp(
            home: Scaffold(
              body: TomUnsavedChangesGuard(
                form: form,
                child: const Text('body'),
              ),
            ),
          );

      await tester.pumpWidget(host(first));
      await tester.pumpWidget(host(second));
      await _edit(tester, first.product, 'X');

      expect(_canPop(tester), isTrue);
    });

    testWidgets('a form outliving the guard fires without throwing',
        (tester) async {
      final form = _form();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TomUnsavedChangesGuard(form: form, child: const Text('body')),
        ),
      ));

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      expect(() => form.product.setValue('X'), returnsNormally);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}

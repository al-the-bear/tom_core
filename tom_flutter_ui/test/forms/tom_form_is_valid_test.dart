/// `TomForm.isValid` answers "has validation run and passed", not "is the data
/// acceptable" — and the difference is invisible from the call site.
///
/// A form bound to entirely valid data reports `isValid == false`, because
/// every field is still `ValidationPristine` and pristine is deliberately not
/// success. The rule is stated in the source (`TomForm.isValid`,
/// `ValidationPristine`, `TomListForm.isValid`) but it is the kind of thing a
/// caller discovers by shipping a Save button that never enables, so it is
/// pinned here rather than left to prose.
///
/// The tests are ordered as the misunderstanding unfolds: pristine is not
/// valid, one edit is not enough, `validate()` is what flips it, a successful
/// save flips it back — and `save()` is safe to call regardless, which is why
/// the documented pattern gates a Save button on `isDirty` and lets `save()`
/// decide.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../support/list_form_fixtures.dart';

/// An order item whose every field already holds an acceptable value.
OrderItem _validItem() => orderWith(const ['Bolt']).items.toList().single;

void main() {
  setUpAll(initializeReflection);

  group('a never-validated form', () {
    test('reports isValid false even when its data is entirely valid', () {
      final form = OrderItemForm()..bind(_validItem());

      expect(form.product.get(), 'Bolt');
      expect(form.isValid, isFalse);
    });

    test('is false because every field is still pristine, not because a '
        'validator failed', () {
      final form = OrderItemForm()..bind(_validItem());

      expect(form.product.validationState, const ValidationPristine());
      expect(form.quantity.validationState, const ValidationPristine());
      expect(form.fieldsWithErrors, isEmpty);
    });

    test('flips to valid after validate(), with the data untouched', () async {
      final form = OrderItemForm()..bind(_validItem());

      await form.validate();

      expect(form.isValid, isTrue);
      expect(form.product.get(), 'Bolt');
      expect(form.isDirty, isFalse);
    });
  });

  group('editing one field', () {
    // The trap behind a Save button gated on isValid: touching a field clears
    // *that* field's pristine state and nothing else's, so a multi-field form
    // stays invalid until every field has been touched or validate() has run.
    test('leaves the untouched fields pristine, so isValid stays false', () {
      final form = OrderItemForm()..bind(_validItem());

      form.product.setValue('Washer');

      expect(form.product.validationState, const ValidationSuccess());
      expect(form.quantity.validationState, const ValidationPristine());
      expect(form.isValid, isFalse);
    });

    test('touching every field is what a piecemeal edit needs', () {
      final form = OrderItemForm()..bind(_validItem());

      form.product.setValue('Washer');
      form.quantity.setValue('2');

      expect(form.isValid, isTrue);
    });
  });

  group('save', () {
    // Why gating on isDirty rather than isValid is safe: save() runs a full
    // validate() of its own before committing anything, so it neither needs a
    // prior validate() nor trusts a stale isValid.
    test(
      'succeeds on a never-validated form, because it validates first',
      () async {
        final form = OrderItemForm()..bind(_validItem());

        expect(form.isValid, isFalse);
        expect(await form.save(), isTrue);
      },
    );

    test('still refuses a never-validated form whose data is bad', () async {
      final item = OrderItem();
      item.product | '';
      item.quantity | '1';
      final form = OrderItemForm()..bind(item);

      expect(await form.save(), isFalse);
      expect(form.isValid, isFalse);
    });

    test('returns the form to pristine, so isValid goes false again', () async {
      // commit() clears validation state so no errors linger after a save —
      // which means isValid is false again the moment the save succeeds. A
      // Save button reading isValid would flicker; one reading isDirty does
      // not, because the save cleared that too.
      final form = OrderItemForm()..bind(_validItem());
      await form.validate();
      expect(form.isValid, isTrue);

      expect(await form.save(), isTrue);

      expect(form.isValid, isFalse);
      expect(form.isDirty, isFalse);
    });
  });

  group('the aggregate', () {
    test(
      'a pristine parent is invalid even though its child list is bound',
      () {
        final form = OrderForm()..bind(orderWith(const ['Bolt']));

        expect(form.isValid, isFalse);
        expect(form.items.isValid, isFalse);
      },
    );

    test(
      'validate() reaches the parent, the fields and the child list',
      () async {
        final form = OrderForm()..bind(orderWith(const ['Bolt']));

        await form.validate();

        expect(form.isValid, isTrue);
        expect(form.items.isValid, isTrue);
      },
    );
  });
}

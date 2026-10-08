/// How a field's activity reaches the form it belongs to.
///
/// `TomField` never dispatches to listeners itself — it calls
/// `form?._fireEvent(...)`, so the form is both the router and the null guard.
/// That indirection is the subject here, and it is not covered elsewhere:
/// `events/tom_form_event_test.dart`, `events/tom_form_inspector_test.dart` and
/// `events/tom_form_event_listener_test.dart` all construct events by hand and
/// hand them to a listener, which proves the event types and the listener work
/// but says nothing about whether a live field ever emits one. `tom_field_test.dart`
/// covers the field's own state — value, dirty, validation — with no form attached.
///
/// So the gap this file fills is the seam: edit a real field on a real form and
/// assert what the form heard.
///
/// Three things worth knowing before reading the assertions:
///
///   * **`setValue` is guarded on equality.** Re-setting the value a field
///     already holds emits nothing. A UI that rebuilds on every keystroke leans
///     on this, and losing it turns one edit into an event storm.
///
///   * **`setValue` does not validate; it schedules validation.** The
///     `TomFieldValidatedEvent` arrives after `validationDebounce`, not on the same
///     turn — which is why a test that reads validation state immediately after
///     an edit sees `TomValidationSuccess` (the optimistic transition out of
///     pristine) rather than a validator's verdict.
///
///   * **A field with no form is silent, not broken.** The `form?.` guard is
///     what lets a field be constructed standalone, which every widget test in
///     `fields/` relies on.
///
/// The suite runs on the reflection seed in `test/support/list_form_fixtures.dart`
/// — a `TomForm` is a `TomClass` and needs a generated mirror to exist at all.
/// `TomForm`'s own lifecycle lives in `tom_form_lifecycle_test.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../support/list_form_fixtures.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// A line item carrying [product] and a quantity of `1`.
OrderItem _item(String product) {
  final item = OrderItem();
  item.product | product;
  item.quantity | '1';
  return item;
}

/// A form bound to [product], with every bind-time event already discarded so
/// the inspector only sees what the test does next.
({OrderItemForm form, TomFormInspector heard}) _bound(String product) {
  final form = OrderItemForm()..bind(_item(product));
  final inspector = TomFormInspector();
  form.addListener(inspector);
  return (form: form, heard: inspector);
}

void main() {
  setUpAll(initializeReflection);

  // -------------------------------------------------------------------------
  // Value changes
  // -------------------------------------------------------------------------

  group('setValue', () {
    test('announces the change to the form, carrying both values', () {
      final (:form, :heard) = _bound('Bolt');

      form.product.setValue('Washer');

      final event = heard.ofType<TomFieldValueChangedEvent>().single;
      expect(event.source, 'product');
      expect(event.oldValue, 'Bolt');
      expect(event.newValue, 'Washer');
    });

    test('says nothing when the value has not actually moved', () {
      // The equality guard. Without it a keystroke-driven UI that writes the
      // current value back on every rebuild would emit an event per frame.
      final (:form, :heard) = _bound('Bolt');

      form.product.setValue('Bolt');

      expect(heard.events, isEmpty);
    });

    test('tags each event with the field that produced it', () {
      final (:form, :heard) = _bound('Bolt');

      form.product.setValue('Washer');
      form.quantity.setValue('9');

      expect(heard.fromSource('product'), hasLength(1));
      expect(heard.fromSource('quantity'), hasLength(1));
    });

    test(
      'does not report a verdict on the same turn — it only schedules one',
      () {
        // The optimistic transition: the field leaves pristine for success
        // immediately so the UI stops showing a stale error, and the real
        // validation lands after the debounce.
        final (:form, :heard) = _bound('Bolt');

        form.product.setValue('');

        expect(heard.ofType<TomFieldValidatedEvent>(), isEmpty);
        expect(form.product.validationState, const TomValidationSuccess());
      },
    );

    test('reports the scheduled verdict once the debounce elapses', () async {
      final (:form, :heard) = _bound('Bolt');

      form.product.setValue('');
      await Future<void>.delayed(
        form.product.validationDebounce + const Duration(milliseconds: 100),
      );

      final event = heard.ofType<TomFieldValidatedEvent>().single;
      expect(event.source, 'product');
      expect(event.result, isA<TomValidationError>());
      expect(form.product.validationState, isA<TomValidationError>());
    });
  });

  // -------------------------------------------------------------------------
  // Explicit validation
  // -------------------------------------------------------------------------

  group('validate', () {
    test('announces a failure', () async {
      final (:form, :heard) = _bound('');

      final result = await form.product.validate();

      expect(result, isA<TomValidationError>());
      expect(
        heard.ofType<TomFieldValidatedEvent>().single.result,
        isA<TomValidationError>(),
      );
    });

    test('announces a success too, not only failures', () async {
      final (:form, :heard) = _bound('Bolt');

      final result = await form.product.validate();

      expect(result, isA<TomValidationSuccess>());
      expect(
        heard.ofType<TomFieldValidatedEvent>().single.result,
        isA<TomValidationSuccess>(),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Commit
  // -------------------------------------------------------------------------

  group('commit', () {
    test('announces itself, which is how a form-level save is observed '
        'field by field', () {
      final (:form, :heard) = _bound('Bolt');

      form.product.setValue('Washer');
      form.product.commit();

      expect(heard.ofType<TomFieldCommittedEvent>().single.source, 'product');
    });

    test(
      'clears validation back to pristine, so no error survives a save',
      () async {
        final (:form, heard: _) = _bound('Bolt');

        await form.product.validate();
        expect(form.product.validationState, const TomValidationSuccess());

        form.product.commit();

        expect(form.product.validationState, const TomValidationPristine());
      },
    );
  });

  // -------------------------------------------------------------------------
  // The null guard
  // -------------------------------------------------------------------------

  group('a field with no form', () {
    // Every widget test under fields/ builds fields this way. If the guard
    // were dropped the failure would be a null dereference in dozens of
    // unrelated suites, so it is pinned at the source instead.
    TomFormStringInput loose() => TomFormStringInput(
      'loose',
      'Bolt',
      validators: [TomValidators.required()],
    );

    test('changes value without a listener to tell', () {
      final field = loose();

      expect(() => field.setValue('Washer'), returnsNormally);
      expect(field.get(), 'Washer');
    });

    test('validates without a listener to tell', () async {
      final field = loose();

      expect(await field.validate(), isA<TomValidationSuccess>());
    });

    test('commits without a listener to tell', () {
      final field = loose();

      field.setValue('Washer');
      expect(() => field.commit(), returnsNormally);
      expect(field.isDirty, isFalse);
    });
  });
}

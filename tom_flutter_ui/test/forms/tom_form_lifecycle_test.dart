/// `TomForm`'s own lifecycle — bind, save, discard, unbind — exercised on a
/// live form rather than inferred from its fields.
///
/// The three things here that a reader cannot get from the field tests:
///
///   * **The binding is a two-way relationship, not a one-time copy.** `bind`
///     pushes values in *and* records a snapshot *and* subscribes to the bound
///     object. `save` pushes back, `discard` pushes the snapshot back, and
///     `unbind` tears the subscription down. Each half is easy to get right
///     alone and easy to get wrong together.
///
///   * **Discard writes to the binding.** It is not merely "reset the fields":
///     the bound object may have been edited by someone else since bind, and
///     the documented contract is that discard rolls that back too. Nothing
///     about the field API suggests this.
///
///   * **Two forms over one object stay in step.** That is what the binding
///     observer is for, and its rule is asymmetric — a clean form re-snapshots,
///     a dirty form keeps the user's in-flight edit. Getting this backwards
///     silently eats typing.
///
/// The suite runs on the reflection seed in `test/support/list_form_fixtures.dart`
/// — a `TomForm` is a `TomClass` and needs a generated mirror to exist at all.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../support/list_form_fixtures.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// A single line item carrying [product] and a quantity of `1`.
OrderItem _item(String product) {
  final item = OrderItem();
  item.product | product;
  item.quantity | '1';
  return item;
}

/// A form already bound to a line item holding [product].
OrderItemForm _boundTo(OrderItem item) => OrderItemForm()..bind(item);

/// Records every event a form dispatches, in order.
TomFormInspector _watch(OrderItemForm form) {
  final inspector = TomFormInspector();
  form.addListener(inspector);
  return inspector;
}

void main() {
  setUpAll(initializeReflection);

  // -------------------------------------------------------------------------
  // bind
  // -------------------------------------------------------------------------

  group('bind', () {
    test('pushes the bound object\'s values into the fields', () {
      final form = _boundTo(_item('Bolt'));

      expect(form.product.get(), 'Bolt');
      expect(form.quantity.get(), '1');
    });

    test('records the bound object as the current binding', () {
      final item = _item('Bolt');
      final form = _boundTo(item);

      expect(form.currentBinding, same(item));
    });

    test('snapshots the bound values, which is what discard restores from', () {
      final form = _boundTo(_item('Bolt'));

      expect(form.initialSnapshot, isNotNull);
      expect(form.initialSnapshot!['product'], 'Bolt');
    });

    test('leaves the form clean and pristine', () {
      final form = _boundTo(_item('Bolt'));

      expect(form.isDirty, isFalse);
      expect(form.dirtyFields, isEmpty);
      expect(form.product.validationState, const ValidationPristine());
    });

    test('fires one FieldBoundEvent per field, then FormBoundEvent', () {
      // The order matters to a listener that rebuilds on FormBoundEvent: by
      // the time it arrives, every field has already been announced.
      final form = OrderItemForm();
      final inspector = _watch(form);

      form.bind(_item('Bolt'));

      expect(inspector.ofType<FieldBoundEvent>(), hasLength(2));
      expect(inspector.ofType<FormBoundEvent>(), hasLength(1));
      expect(inspector.events.last, isA<FormBoundEvent>());
    });

    test('names the form, not a field, as the FormBoundEvent source', () {
      final form = OrderItemForm();
      final inspector = _watch(form);

      form.bind(_item('Bolt'));

      expect(inspector.ofType<FormBoundEvent>().single.source, 'items');
    });

    test('rebinding replaces both the values and the snapshot', () {
      final form = _boundTo(_item('Bolt'));

      form.bind(_item('Washer'));

      expect(form.product.get(), 'Washer');
      expect(form.initialSnapshot!['product'], 'Washer');
      expect(form.isDirty, isFalse);
    });

    test('runs onBound, which is how a form binds its child containers', () {
      // OrderForm.onBound is the only place the nested list is bound; if the
      // hook did not run, the list would come up empty over a populated order.
      final form = OrderForm()..bind(orderWith(const ['Bolt', 'Nut']));

      expect(form.items.length, 2);
    });
  });

  // -------------------------------------------------------------------------
  // dirty tracking
  // -------------------------------------------------------------------------

  group('isDirty', () {
    test('flips when a field moves off its bound value', () {
      final form = _boundTo(_item('Bolt'));

      form.product.setValue('Washer');

      expect(form.isDirty, isTrue);
      expect(form.dirtyFields.single, same(form.product));
    });

    test(
      'is a comparison, not a flag — typing the old value back clears it',
      () {
        final form = _boundTo(_item('Bolt'));

        form.product.setValue('Washer');
        form.product.setValue('Bolt');

        expect(form.isDirty, isFalse);
      },
    );
  });

  // -------------------------------------------------------------------------
  // save
  // -------------------------------------------------------------------------

  group('save', () {
    test('writes the edited values back into the bound object', () async {
      final item = _item('Bolt');
      final form = _boundTo(item);

      form.product.setValue('Washer');
      expect(await form.save(), isTrue);

      expect(item.product.get(), 'Washer');
    });

    test(
      'moves the baseline, so a later discard keeps the saved value',
      () async {
        final form = _boundTo(_item('Bolt'));

        form.product.setValue('Washer');
        await form.save();
        form.discard();

        expect(form.product.get(), 'Washer');
        expect(form.initialSnapshot!['product'], 'Washer');
      },
    );

    test('leaves the bound object untouched when validation fails', () async {
      // save() validates before it writes, so a rejected save is not a
      // partial one — the object never sees the invalid value.
      final item = _item('Bolt');
      final form = _boundTo(item);

      form.product.setValue('');
      expect(await form.save(), isFalse);

      expect(item.product.get(), 'Bolt');
    });

    test('fires FormSavedEvent only on the successful save', () async {
      final item = _item('Bolt');
      final form = _boundTo(item);
      final inspector = _watch(form);

      form.product.setValue('');
      await form.save();
      expect(inspector.ofType<FormSavedEvent>(), isEmpty);

      form.product.setValue('Washer');
      await form.save();
      expect(inspector.ofType<FormSavedEvent>(), hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // discard
  // -------------------------------------------------------------------------

  group('discard', () {
    test('returns every field to its bound value', () {
      final form = _boundTo(_item('Bolt'));

      form.product.setValue('Washer');
      form.quantity.setValue('9');
      form.discard();

      expect(form.product.get(), 'Bolt');
      expect(form.quantity.get(), '1');
      expect(form.isDirty, isFalse);
    });

    test('rolls the bound object back too, not just the fields', () {
      // The write-back is the non-obvious half: something else — a detail
      // pane over the same object — may have moved the data since bind, and
      // "Discard" is expected to undo that as well.
      final item = _item('Bolt');
      final form = _boundTo(item);

      item.product | 'edited elsewhere';
      form.discard();

      expect(item.product.get(), 'Bolt');
    });

    test('fires FormDiscardedEvent', () {
      final form = _boundTo(_item('Bolt'));
      final inspector = _watch(form);

      form.discard();

      expect(inspector.ofType<FormDiscardedEvent>(), hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // unbind
  // -------------------------------------------------------------------------

  group('unbind', () {
    test('drops the binding and the snapshot', () {
      final form = _boundTo(_item('Bolt'));

      form.unbind();

      expect(form.currentBinding, isNull);
      expect(form.initialSnapshot, isNull);
    });

    test('drops in-flight edits — it is not detach-and-keep-editing', () {
      final form = _boundTo(_item('Bolt'));

      form.product.setValue('Washer');
      form.unbind();

      expect(form.product.get(), 'Bolt');
      expect(form.isDirty, isFalse);
    });

    // `unbind` also detaches the observer it installed on the bound object.
    // That has no assertable consequence here: the handler bails out on a
    // null binding, and the kernel registers observers behind a
    // `WeakReference` with no count to read, so any test of it would be
    // asserting on garbage-collection timing rather than on behaviour.
  });

  // -------------------------------------------------------------------------
  // Two forms over one object
  // -------------------------------------------------------------------------

  group('a second form bound to the same object', () {
    test('picks up the first form\'s save while it is clean', () async {
      final item = _item('Bolt');
      final editor = _boundTo(item);
      final viewer = _boundTo(item);

      editor.product.setValue('Washer');
      await editor.save();

      expect(viewer.product.get(), 'Washer');
    });

    test('keeps its own in-flight edit while it is dirty', () async {
      // The asymmetry is deliberate: re-snapshotting a dirty form would
      // overwrite whatever the user is part-way through typing.
      final item = _item('Bolt');
      final editor = _boundTo(item);
      final viewer = _boundTo(item);

      viewer.quantity.setValue('9');
      editor.product.setValue('Washer');
      await editor.save();

      expect(viewer.quantity.get(), '9');
      expect(viewer.product.get(), 'Bolt');
    });
  });

  // -------------------------------------------------------------------------
  // Inspection
  // -------------------------------------------------------------------------

  group('inspection', () {
    test('getField addresses a field by its id', () {
      final form = _boundTo(_item('Bolt'));

      expect(form.getField('product'), same(form.product));
      expect(form.getField('nothing'), isNull);
    });

    test('fieldsWithErrors lists what validate() rejected', () async {
      final form = _boundTo(_item(''));

      await form.validate();

      expect(form.fieldsWithErrors.single, same(form.product));
    });
  });

  // -------------------------------------------------------------------------
  // The change notifier
  // -------------------------------------------------------------------------

  group('changes', () {
    test(
      'fires on form events, which is what aggregate-state UI rebuilds on',
      () {
        // isValid and fieldsWithErrors move on validation transitions that the
        // observable value channel never carries, so a Save button needs this
        // notifier rather than a per-field listener.
        final form = _boundTo(_item('Bolt'));
        var notifications = 0;
        form.changes.addListener(() => notifications++);

        form.discard();

        expect(notifications, greaterThan(0));
      },
    );
  });
}

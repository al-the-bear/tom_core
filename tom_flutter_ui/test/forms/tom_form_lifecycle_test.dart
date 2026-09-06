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

/// An [OrderForm] bound to a populated order — the fixture for the nested-form
/// group below. The address is what makes it interesting: nothing in this
/// helper mentions it, and it is still bound.
OrderForm _boundOrder() => OrderForm()..bind(orderWith(const ['Bolt']));

/// An action that does nothing but exist, so the path it reports can be read.
class _NoopFormAction extends TomSimpleAction<TomActionContext> {
  _NoopFormAction({required super.controller}) : super(actionId: 'wipe');

  @override
  void executeSimple(TomActionContext context, TomActionTransaction tx) {}
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
  // Nested forms
  // -------------------------------------------------------------------------

  group('nested forms', () {
    // `OrderForm.address` is an `AddressForm` held as a plain member. Unlike
    // `OrderForm.items`, nothing registers it and `onBound` does not bind it:
    // every operation below reaches it through `nestedForms`, which is
    // reflection over the form's members.
    //
    // That is the failure mode worth testing. A hand-registered child is
    // either in the list or it is not, and a mistake shows up as a crash; a
    // reflected one can simply go undiscovered, and then all six fan-outs
    // become silent no-ops that no assertion about the *parent* would catch.
    // So each test below asserts on the nested form's own state.

    test('are discovered by reflection over the form\'s members', () {
      final form = OrderForm();

      expect(form.nestedForms, contains(same(form.address)));
    });

    test('do not include child containers, which fan out separately', () {
      // `TomListForm` extends `TomObservable`, not `TomObject`, so it is
      // invisible to the member registry — the two collections are disjoint
      // by construction, and a change that merged them would double-apply
      // every operation to the list.
      final form = OrderForm();

      expect(form.nestedForms, hasLength(1));
      expect(form.childContainers, hasLength(1));
    });

    group('bind', () {
      test('pushes the nested object\'s values into the nested fields', () {
        // This half is *not* the fan-out: `bind` calls `setValues` once on the
        // root, and TomClass recurses through the whole subtree on its own.
        // The fan-out's job is the bookkeeping the next three tests assert.
        // Keeping the two apart matters — a reader who assumes the recursion
        // moves the values would look in the wrong place when one goes wrong.
        final form = _boundOrder();

        expect(form.address.street.get(), 'Main Street 1');
        expect(form.address.city.get(), 'Springfield');
      });

      test('records the nested object as the nested form\'s binding', () {
        // The parent pairs the two by member name; without that, the nested
        // form would hold values it could never write back.
        final order = orderWith(const ['Bolt']);
        final form = OrderForm()..bind(order);

        expect(form.address.currentBinding, same(order.address));
      });

      test('snapshots at the nested level too, not just the root', () {
        final form = _boundOrder();

        expect(form.address.initialSnapshot, isNotNull);
        expect(form.address.initialSnapshot!['street'], 'Main Street 1');
      });

      test('leaves the nested form clean and pristine', () {
        final form = _boundOrder();

        expect(form.address.isDirty, isFalse);
        expect(form.address.street.validationState, const ValidationPristine());
      });
    });

    group('folds', () {
      test('isDirty reports an edit made only in the nested form', () {
        final form = _boundOrder();

        form.address.city.setValue('Shelbyville');

        expect(form.address.isDirty, isTrue);
        expect(form.isDirty, isTrue);
      });

      test(
        'isValid reports a failure that exists only in the nested form',
        () async {
          final form = _boundOrder();
          await form.validate();
          expect(form.isValid, isTrue);

          form.address.street.setValue('');
          await form.validate();

          expect(form.isValid, isFalse);
        },
      );
    });

    group('validate', () {
      test('merges the nested form\'s errors into the parent\'s', () async {
        final form = _boundOrder();

        form.address.street.setValue('');
        final errors = await form.validate();

        expect(
          errors.map((e) => e.fields.single.tomId),
          contains(form.address.street.tomId),
        );
      });
    });

    group('save', () {
      test('writes the nested edits back into the nested object', () async {
        // As with bind, the write-back itself rides on the root's
        // `setValues(getValues())` rather than on the recursion; what the
        // recursion adds is the baseline move asserted two tests below.
        final order = orderWith(const ['Bolt']);
        final form = OrderForm()..bind(order);

        form.address.city.setValue('Shelbyville');
        expect(await form.save(), isTrue);

        expect(order.address.city.get(), 'Shelbyville');
      });

      test(
        'refuses the whole save when only the nested form is invalid',
        () async {
          // The parent's own fields are fine here; the veto comes from below.
          final order = orderWith(const ['Bolt']);
          final form = OrderForm()..bind(order);

          form.address.street.setValue('');
          expect(await form.save(), isFalse);

          expect(order.address.street.get(), 'Main Street 1');
        },
      );

      test('moves the nested baseline, so a later discard keeps it', () async {
        final form = _boundOrder();

        form.address.city.setValue('Shelbyville');
        await form.save();
        form.discard();

        expect(form.address.city.get(), 'Shelbyville');
      });
    });

    group('discard', () {
      test('returns the nested fields to their bound values', () {
        final form = _boundOrder();

        form.address.street.setValue('Elsewhere');
        form.address.city.setValue('Shelbyville');
        form.discard();

        expect(form.address.street.get(), 'Main Street 1');
        expect(form.address.city.get(), 'Springfield');
        expect(form.isDirty, isFalse);
      });
    });

    group('unbind', () {
      test('drops the nested binding and the nested snapshot', () {
        final form = _boundOrder();

        form.unbind();

        expect(form.address.currentBinding, isNull);
        expect(form.address.initialSnapshot, isNull);
      });

      test('drops in-flight nested edits', () {
        final form = _boundOrder();

        form.address.city.setValue('Shelbyville');
        form.unbind();

        expect(form.address.city.get(), 'Springfield');
        expect(form.isDirty, isFalse);
      });
    });

    group('dispose', () {
      test('tears down the nested form\'s fields too', () {
        // The leak this prevents is quiet: an undisposed nested field keeps a
        // live notifier, and a later write to the still-shared business object
        // drives a widget that is no longer on screen. Nothing fails loudly,
        // so only a direct assertion catches it.
        final form = _boundOrder();
        final nested = form.address.street;

        form.dispose();

        expect(
          () => nested.validationListenable.addListener(() {}),
          throwsFlutterError,
        );
      });
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
  // The form as a TomActionController
  // -------------------------------------------------------------------------

  // A form *implements* `TomActionController`, so an action declared on one
  // takes its frame from the form. The form already has a frame — `scope`, and
  // the `basePath` its fields and its own `authState` resolve against — so the
  // controller surface has to hand that same one over, or a policy rule that
  // reaches the form would miss the actions its buttons are bound to.
  group('a form frames the actions it owns', () {
    test('its controller prefix is its basePath, not the bare formId', () {
      final form = OrderItemForm();

      expect(form.controllerId, 'items');
      expect(form.canonicalPrefix, form.basePath);
      expect(form.constructionScope, same(form.scope));
    });

    test('an action it owns resolves under that prefix', () {
      final form = OrderItemForm();
      final action = _NoopFormAction(controller: form);

      expect(action.canonicalPath, 'items.wipe');
      expect(form.findAction('wipe'), same(action));
    });

    test('a scope the form was built in reaches its actions', () {
      final form = TomScope.withScope('checkout', OrderItemForm.new);
      final action = _NoopFormAction(controller: form);

      // The form's tree and the action's are one: basePath 'checkout.items',
      // and the action exactly one segment below it — not 'items.wipe' beside
      // it, and not 'checkout.items.items.wipe' below itself.
      expect(form.basePath, 'checkout.items');
      expect(form.canonicalPrefix, 'checkout.items');
      expect(action.canonicalPath, 'checkout.items.wipe');
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

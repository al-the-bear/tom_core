/// `TomListForm`, the controller behind every list-shaped form.
///
/// This is the largest surface in the package that had no coverage at all, and
/// the one whose behaviour is least inferable from reading: a list form keeps
/// *two* collections in step — its own sub-forms and the bound `TomList` of
/// domain objects — and almost every method has to mutate both. Whether it
/// does is invisible from the call site, because the caller only ever touches
/// the list form.
///
/// So the assertions here are deliberately paired: after every structural
/// operation the test checks the sub-forms *and* the binding. A regression that
/// updates only one of the two is exactly the kind that survives a code review.
///
/// The other axis is the baseline. `_initialOrder` is an identity snapshot
/// taken at `bind` and (conditionally) at `save`, and it is what makes
/// `discard()` able to undo an add. Its subtleties — that `save` only refreshes
/// it when it is allowed to commit, and that `commitBaselines` is auto-detected
/// from the form-tree topology rather than passed in — are pinned individually.
///
/// The fixtures live in `test/support/list_form_fixtures.dart`; see the header
/// there for why a generated reflection mirror is a precondition for
/// constructing any of this.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../../support/list_form_fixtures.dart';

/// Collects every event that reaches a bus, in order.
class _Recorder with TomFormEventListener {
  final List<TomFormEvent> events = [];

  @override
  void handleEvent(TomFormEvent event) => events.add(event);

  List<T> ofType<T>() => events.whereType<T>().toList();
}

/// The product strings currently held by the *bound* list, which is the half
/// of the state a caller never touches directly.
List<String> _boundProducts(Order order) =>
    order.items.toList().map((i) => i.product.get()).toList();

/// The product strings currently held by the *sub-forms*.
List<String> _formProducts(OrderItemListForm list) =>
    list.forms.map((f) => f.product.get()).toList();

void main() {
  setUpAll(initializeReflection);

  // =========================================================================
  // Binding
  // =========================================================================

  group('bind', () {
    test('materialises one sub-form per bound element', () {
      final order = orderWith(['Bolt', 'Nut', 'Washer']);
      final form = OrderForm()..bind(order);

      expect(form.items.length, 3);
      expect(_formProducts(form.items), ['Bolt', 'Nut', 'Washer']);
    });

    test('a sub-form seeds its fields from its own element', () {
      final order = orderWith(['Bolt', 'Nut']);
      final list = OrderItemListForm()..bind(order.items);

      // Row n reads element n — the pairing is positional, and getting it
      // wrong would show every row the same data.
      expect(list[0].product.get(), 'Bolt');
      expect(list[1].product.get(), 'Nut');
    });

    test(
      'a row edit stages in the sub-form and reaches the item on save',
      () async {
        // The form is a staging buffer, not a live proxy: `setValue` moves the
        // field, and only `save()` writes back through `setValues`. Everything
        // about discard() depends on this — it restores by *not* having
        // written, so a write-through model would make rollback impossible.
        final order = orderWith(['Bolt']);
        final list = OrderItemListForm()..bind(order.items);

        list[0].product.setValue('Screw');
        expect(order.items[0].product.get(), 'Bolt');

        expect(await list.save(), isTrue);
        expect(order.items[0].product.get(), 'Screw');
      },
    );

    test('re-binding discards the sub-forms of the previous binding', () {
      final list = OrderItemListForm();
      list.bind(orderWith(['Bolt', 'Nut']).items);
      final firstRound = list.forms;

      list.bind(orderWith(['Cog']).items);

      expect(list.length, 1);
      expect(_formProducts(list), ['Cog']);
      // The old sub-forms are gone from the list, not merely appended past.
      expect(list.forms, isNot(contains(firstRound.first)));
    });

    test('binding an empty list leaves the form empty but usable', () {
      final list = OrderItemListForm()..bind(orderWith(const []).items);

      expect(list.isEmpty, isTrue);
      expect(list.isNotEmpty, isFalse);
      expect(list.length, 0);
    });

    test('unbind tears the sub-forms down and forgets the binding', () {
      final order = orderWith(['Bolt', 'Nut']);
      final list = OrderItemListForm()..bind(order.items);

      list.unbind();

      expect(list.length, 0);
      // The domain list itself is untouched — unbinding is a view operation.
      expect(order.items.length, 2);
      // And with no binding there is nothing to compare a baseline against.
      expect(list.hasStructuralChanges, isFalse);
    });

    test('an unmodifiable view is handed out rather than the live list', () {
      final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);

      expect(() => list.forms.add(OrderItemForm()), throwsUnsupportedError);
    });
  });

  // =========================================================================
  // Structural mutation
  // =========================================================================

  group('add', () {
    test('appends a sub-form and a domain item together', () async {
      final order = orderWith(['Bolt']);
      final list = OrderItemListForm()..bind(order.items);

      final added = list.add();

      expect(list.length, 2);
      expect(order.items.length, 2);
      expect(list.forms.last, same(added));

      // The new row is bound, not merely appended: its staged value has an
      // element to land on when the list saves.
      added.product.setValue('Nut');
      expect(await list.save(), isTrue);
      expect(_boundProducts(order), ['Bolt', 'Nut']);
    });

    test('uses createItem to build the domain element', () {
      final order = orderWith(const []);
      final list = OrderItemListForm()..bind(order.items);

      list.add();

      // The fixture's createItem seeds quantity to '1'; a default-constructed
      // OrderItem would too, so assert on the identity of the path instead:
      // the item exists in the binding and carries the seeded quantity.
      expect(order.items[0].quantity.get(), '1');
    });

    test('without createItem, adding against a binding fails loudly', () {
      // The base class deliberately throws rather than silently skipping the
      // domain side, because a list form whose two halves have drifted apart
      // is far harder to diagnose than a missing override.
      final list = BareItemListForm()..bind(orderWith(const []).items);

      expect(list.add, throwsUnsupportedError);
    });

    test('adding without a binding creates a sub-form only', () {
      // An unbound list form is still a usable UI scaffold — this is what a
      // "new record" screen looks like before its aggregate exists.
      final list = BareItemListForm();

      expect(list.add, returnsNormally);
      expect(list.length, 1);
    });
  });

  group('insert', () {
    test('places the sub-form and the item at the same index', () async {
      final order = orderWith(['Bolt', 'Washer']);
      final list = OrderItemListForm()..bind(order.items);

      list.insert(1).product.setValue('Nut');

      expect(_formProducts(list), ['Bolt', 'Nut', 'Washer']);
      // The blank element went in at 1 as well, so saving lands the staged
      // value in the middle rather than at the end.
      expect(await list.save(), isTrue);
      expect(_boundProducts(order), ['Bolt', 'Nut', 'Washer']);
    });

    test('inserting at the end behaves like add', () {
      final order = orderWith(['Bolt']);
      final list = OrderItemListForm()..bind(order.items);

      list.insert(1);

      expect(list.length, 2);
      expect(order.items.length, 2);
    });
  });

  group('removeAt / remove', () {
    test('drops the sub-form and the item at the same index', () {
      final order = orderWith(['Bolt', 'Nut', 'Washer']);
      final list = OrderItemListForm()..bind(order.items);

      list.removeAt(1);

      expect(_formProducts(list), ['Bolt', 'Washer']);
      expect(_boundProducts(order), ['Bolt', 'Washer']);
    });

    test('remove(form) resolves the index and reports whether it hit', () {
      final order = orderWith(['Bolt', 'Nut']);
      final list = OrderItemListForm()..bind(order.items);
      final second = list[1];

      expect(list.remove(second), isTrue);
      expect(_formProducts(list), ['Bolt']);

      // A second attempt finds nothing and says so rather than throwing.
      expect(list.remove(second), isFalse);
    });

    test('removing a foreign form is a no-op, not a range error', () {
      final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);

      expect(list.remove(OrderItemForm()), isFalse);
      expect(list.length, 1);
    });
  });

  group('move / reorder', () {
    test('reorders both the sub-forms and the bound items', () {
      final order = orderWith(['Bolt', 'Nut', 'Washer']);
      final list = OrderItemListForm()..bind(order.items);

      list.move(0, 2);

      expect(_formProducts(list), ['Nut', 'Washer', 'Bolt']);
      expect(_boundProducts(order), ['Nut', 'Washer', 'Bolt']);
    });

    test('moving backwards works the same way', () {
      final order = orderWith(['Bolt', 'Nut', 'Washer']);
      final list = OrderItemListForm()..bind(order.items);

      list.move(2, 0);

      expect(_formProducts(list), ['Washer', 'Bolt', 'Nut']);
      expect(_boundProducts(order), ['Washer', 'Bolt', 'Nut']);
    });

    test('moving an index onto itself changes nothing and fires nothing', () {
      final list = OrderItemListForm()..bind(orderWith(['Bolt', 'Nut']).items);
      final recorder = _Recorder();
      list.addListener(recorder);

      list.move(1, 1);

      expect(_formProducts(list), ['Bolt', 'Nut']);
      expect(recorder.ofType<ListItemReorderedEvent>(), isEmpty);
    });

    test('reorder is an alias of move, not a second implementation', () {
      final order = orderWith(['Bolt', 'Nut']);
      final list = OrderItemListForm()..bind(order.items);
      final recorder = _Recorder();
      list.addListener(recorder);

      list.reorder(0, 1);

      expect(_boundProducts(order), ['Nut', 'Bolt']);
      // Same event type as move — the alias must not invent its own.
      expect(recorder.ofType<ListItemReorderedEvent>(), hasLength(1));
    });
  });

  // =========================================================================
  // Events
  // =========================================================================

  group('events', () {
    test('add fires ListItemAdded carrying the index and the sub-form id', () {
      final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);
      final recorder = _Recorder();
      list.addListener(recorder);

      list.add();

      final events = recorder.ofType<ListItemAddedEvent>();
      expect(events, hasLength(1));
      expect(events.single.index, 1);
      expect(events.single.source, 'items');
      expect(events.single.itemFormId, 'items');
    });

    test('remove fires ListItemRemoved for the vacated index', () {
      final list = OrderItemListForm()..bind(orderWith(['Bolt', 'Nut']).items);
      final recorder = _Recorder();
      list.addListener(recorder);

      list.removeAt(0);

      final events = recorder.ofType<ListItemRemovedEvent>();
      expect(events, hasLength(1));
      expect(events.single.index, 0);
    });

    test('move fires ListItemReordered with both endpoints', () {
      final list = OrderItemListForm()
        ..bind(orderWith(['Bolt', 'Nut', 'Washer']).items);
      final recorder = _Recorder();
      list.addListener(recorder);

      list.move(2, 0);

      final event = recorder.ofType<ListItemReorderedEvent>().single;
      expect(event.fromIndex, 2);
      expect(event.toIndex, 0);
    });

    test(
      'events bubble to the parent form rather than staying local',
      () async {
        // The whole point of the parent wiring: one listener on the enclosing
        // form sees the field events *and* the structural list events, so an
        // inspector does not have to walk the tree looking for buses.
        final form = OrderForm()..bind(orderWith(['Bolt']));
        final recorder = _Recorder();
        form.addListener(recorder);

        form.items.add();

        expect(recorder.ofType<ListItemAddedEvent>(), hasLength(1));
      },
    );

    test(
      'a listener registered on a parented list lands on the parent bus',
      () {
        final form = OrderForm()..bind(orderWith(['Bolt']));
        final recorder = _Recorder();
        // Registering through the list must reach the same bus the list fires
        // into — otherwise the listener is silently attached to nothing.
        form.items.addListener(recorder);

        form.items.add();

        expect(recorder.ofType<ListItemAddedEvent>(), hasLength(1));
      },
    );

    test('removeListener detaches from whichever bus was used', () {
      final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);
      final recorder = _Recorder();
      list.addListener(recorder);
      list.removeListener(recorder);

      list.add();

      expect(recorder.events, isEmpty);
    });

    test('fireEvent lets callers publish through the same bus', () {
      final list = OrderItemListForm()..bind(orderWith(const []).items);
      final recorder = _Recorder();
      list.addListener(recorder);

      list.fireEvent(FormSavedEvent(source: 'items'));

      expect(recorder.ofType<FormSavedEvent>(), hasLength(1));
    });
  });

  // =========================================================================
  // Observation
  // =========================================================================

  group('observation', () {
    test('a structural change wakes this list-form up', () {
      final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);
      var notifications = 0;
      list >> (_) => notifications++;

      list.add();

      expect(notifications, greaterThan(0));
    });

    test('a row-level field edit wakes this list-form up too', () {
      // This is what lets a Save button observing only the list re-render
      // when a cell inside a row changes — without the forwarder installed
      // in the constructor, the notification would stop at the sub-form.
      final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);
      var notifications = 0;
      list >> (_) => notifications++;

      list[0].product.setValue('Screw');

      expect(notifications, greaterThan(0));
    });

    test('a structural reset notifies exactly once, at the restored '
        'length', () {
      // `TomList.resetWith` is documented as atomic, and observers of the
      // list form are entitled to the same guarantee: the sub-forms are torn
      // down and rebuilt between `onBeforeClear` and `onAfterReset`, and the
      // half-built states in between are not states the list is ever *in*.
      //
      // This is not academic. `TomMasterDetailListForm` clamps its selection
      // when it hears the list has shrunk past the selected row — correct
      // behaviour, given a truthful notification. A forwarded notification
      // from the empty moment inside a reset tells it the list has zero rows,
      // it drops the selection, and the detail pane goes blank and stays
      // blank: the rebuilt rows arrive, but nothing restores the selection.
      // That is what "Discard all" on a root form looked like from the UI.
      //
      // The assertion is the exact sequence, not merely the absence of a
      // zero, because both halves can fail and only one of them is about a
      // wrong value. Withholding the transient notifications and then never
      // sending the real one leaves the detail pane just as blank — and an
      // `isNot(contains(0))` on the resulting empty list passes.
      final order = orderWith(['Bolt', 'Nut', 'Washer']);
      final list = OrderItemListForm()..bind(order.items);
      list.removeAt(0);

      final observedLengths = <int>[];
      list >> (_) => observedLengths.add(list.length);

      list.discard();

      expect(
        observedLengths,
        [3],
        reason:
            'the reset restores all three rows, so an observer is owed one '
            'notification reporting three. More than one means the '
            'half-built states escaped; none means the rebuild was silent '
            'and nothing downstream will re-read the list.',
      );
    });
  });

  // =========================================================================
  // Dirty tracking
  // =========================================================================

  group('isDirty / hasStructuralChanges', () {
    test('a freshly bound list is clean', () {
      final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);

      expect(list.isDirty, isFalse);
      expect(list.hasStructuralChanges, isFalse);
    });

    test('editing a row makes the list dirty without a structural change', () {
      final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);

      list[0].product.setValue('Screw');

      expect(list.isDirty, isTrue);
      expect(list.hasStructuralChanges, isFalse);
    });

    test('adding a row is a structural change', () {
      final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);

      list.add();

      expect(list.hasStructuralChanges, isTrue);
      expect(list.isDirty, isTrue);
    });

    test('removing a row is a structural change', () {
      final list = OrderItemListForm()..bind(orderWith(['Bolt', 'Nut']).items);

      list.removeAt(0);

      expect(list.hasStructuralChanges, isTrue);
    });

    test('reordering is a structural change even at unchanged length', () {
      // Length-only comparison would miss this; the baseline is an identity
      // snapshot precisely so a permutation is detectable.
      final list = OrderItemListForm()..bind(orderWith(['Bolt', 'Nut']).items);

      list.move(0, 1);

      expect(list.hasStructuralChanges, isTrue);
    });

    test('an add-then-remove of the same row returns to clean', () {
      final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);

      list.add();
      list.removeAt(1);

      expect(list.hasStructuralChanges, isFalse);
      expect(list.isDirty, isFalse);
    });

    test('the baseline compares identity, not equality', () {
      // Two OrderItems with identical field values are still different rows;
      // swapping one for the other is a real structural change even though a
      // value-wise diff would report none.
      final order = orderWith(['Bolt']);
      final list = OrderItemListForm()..bind(order.items);

      final replacement = OrderItem();
      replacement.product | 'Bolt';
      replacement.quantity | '1';
      order.items.removeAt(0);
      order.items.add(replacement);

      expect(list.hasStructuralChanges, isTrue);
    });

    test('the enclosing form reports the list dirtiness as its own', () {
      // The list registers itself as a child container from its constructor,
      // so the parent picks it up without enumerating anything.
      final form = OrderForm()..bind(orderWith(['Bolt']));

      expect(form.isDirty, isFalse);
      form.items[0].product.setValue('Screw');
      expect(form.isDirty, isTrue);
    });
  });

  // =========================================================================
  // Validation
  // =========================================================================

  group('validate', () {
    test('collects the errors of every row', () async {
      // Both rows are blank and `product` is required, so both must report.
      final list = OrderItemListForm()..bind(orderWith(['', '']).items);

      final errors = await list.validate();

      expect(errors, hasLength(2));
    });

    test('a valid row contributes nothing', () async {
      final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);

      expect(await list.validate(), isEmpty);
    });

    test(
      'validateList adds list-level errors alongside the row errors',
      () async {
        final list = OrderItemListForm()
          ..minRows = 3
          ..bind(orderWith(['', 'Nut']).items);

        final errors = await list.validate();

        expect(errors.map((e) => e.errorKey), contains('error.tooFewRows'));
        // One blank product plus the list-level rule.
        expect(errors, hasLength(2));
      },
    );

    test('a list-level error carries no field references', () async {
      final list = OrderItemListForm()
        ..minRows = 1
        ..bind(orderWith(const []).items);

      final errors = await list.validate();

      expect(errors.single.fields, isEmpty);
    });

    test('validation fires a FormValidatedEvent carrying the errors', () async {
      final list = OrderItemListForm()..bind(orderWith(['']).items);
      final recorder = _Recorder();
      list.addListener(recorder);

      await list.validate();

      final event = recorder.ofType<FormValidatedEvent>().last;
      expect(event.source, 'items');
      expect(event.errors, hasLength(1));
    });

    test('isValid is false until every row has actually validated', () async {
      // Pristine counts as not-valid: a form that has never been checked is
      // not the same as a form that has been checked and passed.
      final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);
      expect(list.isValid, isFalse);

      await list.validate();

      expect(list.isValid, isTrue);
    });

    test('isValid stays false while any row fails', () async {
      final list = OrderItemListForm()..bind(orderWith(['Bolt', '']).items);

      await list.validate();

      expect(list.isValid, isFalse);
    });

    test('the enclosing form fans validation into the list', () async {
      final form = OrderForm()..bind(orderWith(['']));

      final errors = await form.validate();

      expect(errors, isNotEmpty);
      expect(form.isValid, isFalse);
    });
  });

  // =========================================================================
  // Save
  // =========================================================================

  group('save', () {
    test('refuses when a row is invalid', () async {
      final list = OrderItemListForm()..bind(orderWith(['']).items);

      expect(await list.save(), isFalse);
    });

    test('refuses when the list-level rule fails', () async {
      final list = OrderItemListForm()
        ..minRows = 2
        ..bind(orderWith(['Bolt']).items);

      expect(await list.save(), isFalse);
    });

    test(
      'succeeds and re-baselines the structure when it may commit',
      () async {
        final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);
        list.add().product.setValue('Nut');
        expect(list.hasStructuralChanges, isTrue);

        expect(await list.save(), isTrue);

        // The added row is now part of the baseline, so a later discard must
        // not remove it.
        expect(list.hasStructuralChanges, isFalse);
      },
    );

    test(
      'commitBaselines: false leaves the structural baseline alone',
      () async {
        // The explicit form of the nested-save policy: an outer transaction is
        // still in flight, so the list must stay rollback-able.
        final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);
        list.add().product.setValue('Nut');

        expect(await list.save(commitBaselines: false), isTrue);

        expect(list.hasStructuralChanges, isTrue);
      },
    );

    test('a root-level list auto-detects that it may commit', () async {
      // OrderForm is standalone, so its list is the outermost transaction
      // boundary and a bare save() is allowed to re-baseline.
      final form = OrderForm()..bind(orderWith(['Bolt']));
      form.items.add().product.setValue('Nut');

      expect(await form.items.save(), isTrue);

      expect(form.items.hasStructuralChanges, isFalse);
    });

    test('a nested list auto-detects that it must not commit', () async {
      // Same call, different topology: the parent form now has an ancestor,
      // so the list is inside someone else's transaction and defers the
      // baseline update to them.
      final form = OrderForm()..bind(orderWith(['Bolt']));
      form.attachToEnclosingForm(OrderForm());
      form.items.add().product.setValue('Nut');

      expect(await form.items.save(), isTrue);

      expect(form.items.hasStructuralChanges, isTrue);
    });
  });

  // =========================================================================
  // Discard
  // =========================================================================

  group('discard', () {
    test('rolls a row edit back to the bound value', () {
      final order = orderWith(['Bolt']);
      final list = OrderItemListForm()..bind(order.items);
      list[0].product.setValue('Screw');

      list.discard();

      // The staged edit is gone from the field, not merely absent from the
      // binding — the field is what the user is looking at.
      expect(_formProducts(list), ['Bolt']);
      expect(_boundProducts(order), ['Bolt']);
      expect(list.isDirty, isFalse);
    });

    test('rolls an added row back out of both halves', () {
      final order = orderWith(['Bolt']);
      final list = OrderItemListForm()..bind(order.items);
      list.add().product.setValue('Nut');

      list.discard();

      expect(list.length, 1);
      expect(order.items.length, 1);
      expect(_formProducts(list), ['Bolt']);
    });

    test('restores a removed row', () {
      final order = orderWith(['Bolt', 'Nut']);
      final list = OrderItemListForm()..bind(order.items);
      list.removeAt(0);

      list.discard();

      expect(_boundProducts(order), ['Bolt', 'Nut']);
      expect(_formProducts(list), ['Bolt', 'Nut']);
    });

    test('restores the original order after a reorder', () {
      final order = orderWith(['Bolt', 'Nut', 'Washer']);
      final list = OrderItemListForm()..bind(order.items);
      list.move(0, 2);

      list.discard();

      expect(_boundProducts(order), ['Bolt', 'Nut', 'Washer']);
    });

    test('the rebuilt sub-forms are live, not orphaned', () async {
      // resetWith tears the old sub-forms down and builds new ones; if the
      // rebuild forgot to bind them, edits made after a discard would have
      // nowhere to land and would silently vanish at the next save.
      final order = orderWith(['Bolt']);
      final list = OrderItemListForm()..bind(order.items);
      list.add();
      list.discard();

      list[0].product.setValue('Screw');
      expect(await list.save(), isTrue);

      expect(order.items[0].product.get(), 'Screw');
    });

    test(
      'discarding after a save rolls back only to the saved state',
      () async {
        final order = orderWith(['Bolt']);
        final list = OrderItemListForm()..bind(order.items);
        list.add().product.setValue('Nut');
        await list.save();

        list.add().product.setValue('Washer');
        list.discard();

        expect(_boundProducts(order), ['Bolt', 'Nut']);
      },
    );

    test('an unbound list still settles into a clean state', () {
      final list = BareItemListForm()..add();

      expect(list.discard, returnsNormally);
    });

    test('the enclosing form fans discard into the list', () {
      final order = orderWith(['Bolt']);
      final form = OrderForm()..bind(order);
      form.items[0].product.setValue('Screw');
      expect(form.isDirty, isTrue);

      form.discard();

      expect(_formProducts(form.items), ['Bolt']);
      expect(order.items[0].product.get(), 'Bolt');
      expect(form.isDirty, isFalse);
    });
  });

  // =========================================================================
  // Externally-driven resets
  // =========================================================================

  group('list lifecycle hooks', () {
    test('an external resetWith rebuilds the sub-forms', () {
      // Nothing here touches the list form: the bound TomList is replaced
      // wholesale, as an outer form's discard would do, and the list form
      // has to notice through the lifecycle listener it registered at bind.
      final order = orderWith(['Bolt']);
      final list = OrderItemListForm()..bind(order.items);

      final replacement = OrderItem();
      replacement.product | 'Cog';
      replacement.quantity | '2';
      order.items.resetWith([replacement]);

      expect(list.length, 1);
      expect(_formProducts(list), ['Cog']);
    });

    test('a reset re-baselines so the new contents count as clean', () {
      final order = orderWith(['Bolt']);
      final list = OrderItemListForm()..bind(order.items);

      order.items.resetWith(<OrderItem>[]);

      expect(list.hasStructuralChanges, isFalse);
      expect(list.isDirty, isFalse);
    });

    test('re-binding detaches the lifecycle listener from the old list', () {
      // Otherwise a later reset of the *previous* binding would still drive
      // this list form and blow its contents away.
      final first = orderWith(['Bolt']);
      final second = orderWith(['Cog']);
      final list = OrderItemListForm()..bind(first.items);
      list.bind(second.items);

      first.items.resetWith(<OrderItem>[]);

      expect(_formProducts(list), ['Cog']);
    });
  });

  // =========================================================================
  // Disposal
  // =========================================================================

  group('dispose', () {
    test('clears the sub-forms and the local listeners', () {
      final list = OrderItemListForm()..bind(orderWith(['Bolt']).items);
      final recorder = _Recorder();
      list.addListener(recorder);

      list.dispose();

      expect(list.length, 0);
      list.fireEvent(FormSavedEvent(source: 'items'));
      expect(recorder.events, isEmpty);
    });

    test('a disposed list no longer reacts to its old binding', () {
      final order = orderWith(['Bolt']);
      final list = OrderItemListForm()..bind(order.items);

      list.dispose();
      order.items.resetWith(<OrderItem>[]);

      expect(list.length, 0);
    });
  });
}

/// Unit tests for `TomListForm` (Phase 2a / §13).
///
/// Lives in `tom_flutter_form_test` because constructing `TomForm`
/// subclasses requires reflectable to be initialised — easiest done
/// through this project's generated `main.reflection.dart`.
///
/// Covered:
/// - add / insert / removeAt / move propagate to the bound `TomList`
/// - List events bubble through the parent form's bus
/// - bind rebuilds the sub-form set; unbind tears it down
/// - validate aggregates per-row + validateList errors
/// - save updates the snapshot so isDirty / hasStructuralChanges reset
/// - discard restores the original list order + content
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import 'package:tom_flutter_form_test/forms/order_form.dart';
import 'package:tom_flutter_form_test/forms/order_item_form.dart';
import 'package:tom_flutter_form_test/main.reflection.dart';
import 'package:tom_flutter_form_test/state/phase2a_state.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    initializeReflection();
    // Resources are needed because TomFormStringInput resolves labels
    // via TomCtr at construction-time-ish. Loading the demo resources
    // keeps that path quiet; the tests never check labels themselves.
    final jsonStr =
        await rootBundle.loadString('assets/demo_resources.json');
    final resources = json.decode(jsonStr) as Map<String, dynamic>;
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(resources),
    );
  });

  Order makeOrder() {
    final o = Order();
    o.orderNumber | 'TEST-1';
    o.customer | 'Test Customer';
    final i1 = OrderItem();
    i1.productName | 'Widget A';
    i1.quantity | '2';
    i1.unitPrice | '5.00';
    final i2 = OrderItem();
    i2.productName | 'Widget B';
    i2.quantity | '3';
    i2.unitPrice | '4.50';
    o.items.add(i1);
    o.items.add(i2);
    return o;
  }

  OrderForm makeBoundForm() {
    final form = TomScope.withScope('listFormTest', () => OrderForm());
    form.bind(makeOrder());
    return form;
  }

  group('TomListForm — bind / structure', () {
    test('bind instantiates one sub-form per element', () {
      final form = makeBoundForm();
      expect(form.items.length, 2);
      expect(form.items.forms.length, 2);
      expect(form.items[0], isA<OrderItemForm>());
      form.dispose();
    });

    test('add appends a sub-form and grows the bound list', () {
      final form = makeBoundForm();
      final order = form.currentBinding!;
      final created = form.items.add();
      expect(form.items.length, 3);
      expect(order.items.length, 3);
      expect(form.items[2], same(created));
      form.dispose();
    });

    test('insert at index reorders both sides', () {
      final form = makeBoundForm();
      final order = form.currentBinding!;
      form.items.insert(1);
      expect(form.items.length, 3);
      expect(order.items.length, 3);
      form.dispose();
    });

    test('removeAt drops the sub-form and the bound element', () {
      final form = makeBoundForm();
      final order = form.currentBinding!;
      form.items.removeAt(0);
      expect(form.items.length, 1);
      expect(order.items.length, 1);
      form.dispose();
    });

    test('move reorders both sides identically', () {
      final form = makeBoundForm();
      final order = form.currentBinding!;
      final firstItem = order.items[0];
      form.items.move(0, 1);
      expect(order.items[1], same(firstItem));
      expect(form.items.forms[1].currentBinding, same(firstItem));
      form.dispose();
    });

    test('reorder alias matches move semantics', () {
      final form = makeBoundForm();
      final order = form.currentBinding!;
      final firstItem = order.items[0];
      form.items.reorder(0, 1);
      expect(order.items[1], same(firstItem));
      expect(form.items.forms[1].currentBinding, same(firstItem));
      form.dispose();
    });

    test('unbind disposes sub-forms and resets state', () {
      final form = makeBoundForm();
      form.items.unbind();
      expect(form.items.length, 0);
      expect(form.items.isDirty, isFalse);
      form.dispose();
    });
  });

  group('TomListForm — events', () {
    test('add fires ListItemAddedEvent through the parent bus', () {
      final form = makeBoundForm();
      final inspector = TomFormInspector();
      form.addListener(inspector);
      form.items.add();
      final added = inspector.events.whereType<ListItemAddedEvent>();
      expect(added, hasLength(1));
      expect(added.first.itemFormId, 'items');
      form.removeListener(inspector);
      form.dispose();
    });

    test('removeAt fires ListItemRemovedEvent', () {
      final form = makeBoundForm();
      final inspector = TomFormInspector();
      form.addListener(inspector);
      form.items.removeAt(0);
      final removed = inspector.events.whereType<ListItemRemovedEvent>();
      expect(removed, hasLength(1));
      expect(removed.first.index, 0);
      form.removeListener(inspector);
      form.dispose();
    });

    test('move fires ListItemReorderedEvent with from/to', () {
      final form = makeBoundForm();
      final inspector = TomFormInspector();
      form.addListener(inspector);
      form.items.move(0, 1);
      final reordered =
          inspector.events.whereType<ListItemReorderedEvent>();
      expect(reordered, hasLength(1));
      expect(reordered.first.fromIndex, 0);
      expect(reordered.first.toIndex, 1);
      form.removeListener(inspector);
      form.dispose();
    });

    test('validate fires FormValidatedEvent through the parent bus', () async {
      final form = makeBoundForm();
      final inspector = TomFormInspector();
      form.addListener(inspector);
      await form.items.validate();
      final validated = inspector.events.whereType<FormValidatedEvent>();
      // One FormValidatedEvent per sub-form + one from TomListForm itself.
      expect(validated, isNotEmpty);
      // The list-level event is the last one fired (after all sub-forms).
      expect(validated.last.source, 'items');
      form.removeListener(inspector);
      form.dispose();
    });

    test('validate fires FormValidatedEvent with list error when empty',
        () async {
      final form = makeBoundForm();
      form.items.removeAt(0);
      form.items.removeAt(0);
      final inspector = TomFormInspector();
      form.addListener(inspector);
      await form.items.validate();
      final listEvent = inspector.events
          .whereType<FormValidatedEvent>()
          .lastWhere((e) => e.source == 'items');
      expect(listEvent.errors, hasLength(1));
      form.removeListener(inspector);
      form.dispose();
    });
  });

  group('TomListForm — validation & save lifecycle', () {
    test('validateList rule trips when list is empty', () async {
      final form = makeBoundForm();
      form.items.removeAt(0);
      form.items.removeAt(0);
      final errors = await form.items.validate();
      expect(errors, hasLength(1));
      expect(errors.first.errorKey, 'error.items.minRequired');
      form.dispose();
    });

    test('save returns true when all rows are valid', () async {
      final form = makeBoundForm();
      final ok = await form.items.save();
      expect(ok, isTrue);
      form.dispose();
    });

    test('save returns false when a row fails validation', () async {
      final form = makeBoundForm();
      // Force an invalid quantity on row 0 (positive integer rule).
      form.items[0].quantity.set('not-a-number');
      final ok = await form.items.save();
      expect(ok, isFalse);
      form.dispose();
    });

    test('hasStructuralChanges flips after add and resets after save',
        () async {
      final form = makeBoundForm();
      expect(form.items.hasStructuralChanges, isFalse);
      form.items.add();
      expect(form.items.hasStructuralChanges, isTrue);
      // The freshly-added sub-form has empty productName which fails the
      // required-validator, so save will reject. Fill it before saving.
      form.items[2].productName.set('Widget C');
      form.items[2].quantity.set('1');
      form.items[2].unitPrice.set('1.00');
      final ok = await form.items.save();
      expect(ok, isTrue);
      expect(form.items.hasStructuralChanges, isFalse);
      form.dispose();
    });
  });

  group('TomListForm — discard', () {
    test('discard restores the original membership after add/remove',
        () {
      final form = makeBoundForm();
      final order = form.currentBinding!;
      final originalLength = order.items.length;
      form.items.add();
      form.items.removeAt(0);
      expect(form.items.hasStructuralChanges, isTrue);
      form.items.discard();
      expect(order.items.length, originalLength);
      expect(form.items.hasStructuralChanges, isFalse);
      form.dispose();
    });
  });

  group('TomForm — child-container fan-out', () {
    test('parent isDirty includes structural changes in TomListForm', () {
      final form = makeBoundForm();
      expect(form.isDirty, isFalse);
      form.items.add();
      // Newly added row is a structural change → parent should be dirty
      // even though no header field was touched.
      expect(form.isDirty, isTrue);
      form.dispose();
    });

    test('parent validate aggregates list-level errors into one event',
        () async {
      final form = makeBoundForm();
      form.items.removeAt(0);
      form.items.removeAt(0);
      final inspector = TomFormInspector();
      form.addListener(inspector);
      final errors = await form.validate();
      expect(errors.any((e) => e.errorKey == 'error.items.minRequired'),
          isTrue);
      // The parent's FormValidatedEvent (last with source == formId)
      // must carry the list error too — that's what TomErrorView
      // subscribed to the parent will see.
      final parentEvent = inspector.events
          .whereType<FormValidatedEvent>()
          .lastWhere((e) => e.source == 'order');
      expect(
          parentEvent.errors
              .whereType<FormValidationError>()
              .any((e) => e.errorKey == 'error.items.minRequired'),
          isTrue);
      form.removeListener(inspector);
      form.dispose();
    });

    test('parent discard rolls back list structural changes', () {
      final form = makeBoundForm();
      final order = form.currentBinding!;
      final originalLen = order.items.length;
      form.items.add();
      form.items.removeAt(0);
      expect(form.items.hasStructuralChanges, isTrue);
      form.discard();
      expect(form.items.hasStructuralChanges, isFalse);
      expect(order.items.length, originalLen);
      form.dispose();
    });

    test('parent save fans out into TomListForm save', () async {
      final form = makeBoundForm();
      form.items.add();
      form.items[2].productName.set('Widget C');
      form.items[2].quantity.set('1');
      form.items[2].unitPrice.set('1.00');
      final ok = await form.save();
      expect(ok, isTrue);
      expect(form.items.hasStructuralChanges, isFalse);
      expect(form.isDirty, isFalse);
      form.dispose();
    });
  });

  group('TomForm — sibling form change propagation', () {
    // Regression: when a sibling TomForm bound to the SAME TomClass
    // mutates a nested list (e.g. a master-detail detail pane removes an
    // item from order.items), the outer form's `changes` listenable must
    // fire so dirty-driven UI (Save / Discard buttons) can re-evaluate.
    //
    // Before the fix, `_onBindingExternallyChanged` short-circuited at
    // `if (isDirty) return;` without firing `_changes`, leaving the outer
    // discard button permanently disabled even though the form had become
    // dirty via the sibling's edit.
    test(
        'outer form.changes fires when sibling list-form removes an element '
        'and outer becomes dirty', () {
      final order = makeOrder();
      final outer = TomScope.withScope('listFormTest', () => OrderForm());
      final sibling = TomScope.withScope('listFormTest', () => OrderForm());
      outer.bind(order);
      sibling.bind(order);

      var outerNotifications = 0;
      void onChange() => outerNotifications++;
      outer.changes.addListener(onChange);

      // Sibling removes an item from the shared order.items list.
      sibling.items.removeAt(0);

      // Outer's changes channel must fire so isDirty-bound UI re-renders.
      expect(outerNotifications, greaterThan(0),
          reason:
              'outer.changes should fire after sibling structural mutation');
      // And the outer form must actually report dirty.
      expect(outer.isDirty, isTrue,
          reason: 'outer.items.hasStructuralChanges should propagate '
              'into outer.isDirty');

      outer.changes.removeListener(onChange);
      outer.dispose();
      sibling.dispose();
    });
  });
}

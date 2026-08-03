/// Reflection seed and shared domain for the `forms/list/` test suite.
///
/// Why this file exists at all: `TomForm` is a `TomClass`, and `TomClass`
/// discovers its members through kernel reflection — constructing one without a
/// generated mirror throws *"Reflection has not been initialized"*. So a list
/// form cannot be exercised from a plain unit test; it needs a reflected graph.
///
/// `tom_flutter_ui` had none, which is the mechanical reason the whole
/// `forms/list/` submodule went untested. This file is the seed: the generator
/// reads it (see `build.yaml`) and emits `list_form_fixtures.reflection.dart`,
/// which every list test initialises from.
///
/// The domain is deliberately tiny — an order of line items — because the seed
/// size is the cost of the suite: reflecting a form also reflects its field
/// types, so each extra field kind widens the generated graph.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

export 'list_form_fixtures.reflection.dart';

// ---------------------------------------------------------------------------
// Domain
// ---------------------------------------------------------------------------

/// One line of an order — the element type of the bound `TomList`.
@tomReflector
class OrderItem extends TomClass {
  /// Product name. Required, so a blank row is an invalid row.
  late final product = TomString('');

  /// Quantity as text, matching the string-backed field widgets.
  late final quantity = TomString('1');
}

/// The aggregate an [OrderForm] binds: a header field plus the item list.
@tomReflector
class Order extends TomClass {
  late final reference = TomString('');
  late final items = TomList<OrderItem>();
}

// ---------------------------------------------------------------------------
// Forms
// ---------------------------------------------------------------------------

/// The per-row sub-form. Its `formId` is `items` — the list's id — because the
/// framework shares one resource path across every row rather than indexing it.
@tomReflector
class OrderItemForm extends TomForm<OrderItem> {
  OrderItemForm() : super(formId: 'items');

  late final product = TomFormStringInput(
    'product',
    '',
    form: this,
    validators: [Validators.required()],
  );

  late final quantity = TomFormStringInput(
    'quantity',
    '1',
    form: this,
  );

  @override
  void createFormElements() {}
}

/// The list controller under test. [createItem] is what `add()` / `insert()`
/// call to materialise a new element in the bound list.
@tomReflector
class OrderItemListForm extends TomListForm<OrderItem, OrderItemForm> {
  OrderItemListForm({super.parentForm})
      : super(listId: 'items', formFactory: (_) => OrderItemForm());

  /// Minimum number of rows the list must hold; `0` disables the check.
  int minRows = 0;

  @override
  OrderItem createItem() {
    final item = OrderItem();
    item.product | '';
    item.quantity | '1';
    return item;
  }

  @override
  Future<List<String>> validateList() async =>
      length < minRows ? const ['error.tooFewRows'] : const [];
}

/// A row form whose *both* fields are required.
///
/// [OrderItemForm] can only ever hold one validation error, which is not enough
/// to pin the plural wording and the one-line-per-field layout of
/// `TomRowErrorStrip`. This form binds the same [OrderItem] and differs only in
/// that `quantity` is required too.
@tomReflector
class TwoRequiredFieldsForm extends TomForm<OrderItem> {
  TwoRequiredFieldsForm() : super(formId: 'items');

  late final product = TomFormStringInput(
    'product',
    '',
    form: this,
    validators: [Validators.required()],
  );

  late final quantity = TomFormStringInput(
    'quantity',
    '',
    form: this,
    validators: [Validators.required()],
  );

  @override
  void createFormElements() {}
}

/// A list form that never overrides [TomListForm.createItem] — used to pin the
/// diagnostic the base class throws when `add()` runs against a bound list.
@tomReflector
class BareItemListForm extends TomListForm<OrderItem, OrderItemForm> {
  BareItemListForm()
      : super(listId: 'items', formFactory: (_) => OrderItemForm());
}

/// The enclosing form. The list registers itself as a child container from its
/// constructor, so `validate` / `save` / `discard` / `isDirty` fan into it
/// without the parent enumerating anything.
@tomReflector
class OrderForm extends TomForm<Order> {
  OrderForm() : super(formId: 'order');

  late final reference = TomFormStringInput('reference', '', form: this);

  late final OrderItemListForm items = OrderItemListForm(parentForm: this);

  @override
  void createFormElements() {}

  @override
  void onBound() {
    items.bind(currentBinding!.items);
  }
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Builds an [Order] whose items carry the given product names.
Order orderWith(List<String> products) {
  final order = Order();
  order.reference | 'ORD-1';
  for (final p in products) {
    final item = OrderItem();
    item.product | p;
    item.quantity | '1';
    order.items.add(item);
  }
  return order;
}

/// The generator treats a seed as a runnable program and requires a `main`.
/// Nothing executes it.
void main() {}

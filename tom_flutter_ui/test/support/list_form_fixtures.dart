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
/// The domain is deliberately tiny — an order of line items, shipping to an
/// address — because the seed size is the cost of the suite: reflecting a form
/// also reflects its field types, so each extra **field kind** widens the
/// generated graph.
///
/// Extra *classes* are cheap by comparison, which is worth knowing before
/// declining a test for fear of the cost. Adding [Address] and [AddressForm]
/// over the existing `TomString` / `TomFormStringInput` kinds grew the
/// generated file by well under a percent, because the bulk of it is the field
/// types' own transitive graph and those were already reflected. Reuse a kind
/// the seed already has and the marginal cost is close to nothing; introduce a
/// new one and it is not.
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

/// Where an order ships. Exists to give [Order] a nested [TomClass] member, so
/// [OrderForm] can hold a nested *form* over it — the only shape that populates
/// `TomForm.nestedForms`.
///
/// Both fields are [TomString] on purpose. `nestedForms` is discovered by type,
/// not by field kind, so nesting is provable without introducing a field kind
/// the seed does not already reflect — which is what keeps the generated graph
/// from growing to pay for it.
@tomReflector
class Address extends TomClass {
  /// Required, so an [AddressForm] can be made invalid on its own.
  late final street = TomString('');

  late final city = TomString('');
}

/// The aggregate an [OrderForm] binds: a header field, a nested address, and
/// the item list.
@tomReflector
class Order extends TomClass {
  late final reference = TomString('');
  late final address = Address();
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
    validators: [TomValidators.required()],
  );

  late final quantity = TomFormStringInput('quantity', '1', form: this);

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
    validators: [TomValidators.required()],
  );

  late final quantity = TomFormStringInput(
    'quantity',
    '',
    form: this,
    validators: [TomValidators.required()],
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

/// The nested sub-form. Nothing registers it and nothing binds it by hand:
/// [OrderForm] holds it as a member, and `TomForm.nestedForms` finds it by
/// reflecting over those members. Its `formId` matches the `address` member on
/// [Order], which is how `_applyBindLifecycle` pairs the two.
@tomReflector
class AddressForm extends TomForm<Address> {
  AddressForm() : super(formId: 'address');

  late final street = TomFormStringInput(
    'street',
    '',
    form: this,
    validators: [TomValidators.required()],
  );

  late final city = TomFormStringInput('city', '', form: this);

  @override
  void createFormElements() {}
}

/// The enclosing form. The list registers itself as a child container from its
/// constructor, so `validate` / `save` / `discard` / `isDirty` fan into it
/// without the parent enumerating anything.
///
/// [address] is the other half of the same story, reached the other way: it is
/// never registered, and the parent never enumerates it either — reflection
/// discovers it. That difference is the point of having both here.
@tomReflector
class OrderForm extends TomForm<Order> {
  OrderForm() : super(formId: 'order');

  late final reference = TomFormStringInput('reference', '', form: this);

  late final AddressForm address = AddressForm();

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
///
/// The address is populated too, so a test of the nested-form fan-out starts
/// from a bound value it can watch move rather than from a blank one.
Order orderWith(List<String> products) {
  final order = Order();
  order.reference | 'ORD-1';
  order.address.street | 'Main Street 1';
  order.address.city | 'Springfield';
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

import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/phase_hd_state.dart';
import '../state/phase2a_state.dart'; // for phase2aProductSource
import 'form_validators.dart';

// ---------------------------------------------------------------------------
// Form classes for Demos H-D and H-E.
//
// Hierarchy:
//   CustomerHDForm (TomForm<CustomerHD>)
//     - flat billing-address fields
//     - ShippingAddressHDListForm  (owns ShippingAddressHDForm per row)
//     - OrderHDListForm            (owns OrderHDForm per row)
//       - each OrderHDForm owns OrderItemHDListForm
//         - each OrderItemHDForm per item row
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// 1. Order item form
// ---------------------------------------------------------------------------

/// One line item inside an [OrderHDForm] (Demos H-D / H-E).
///
/// Exercises `tom_flutter_ui`'s `TomFormSearchInput<String>` product picker
/// plus auto-validating `TomFormStringInput` quantity / unit-price fields.
@tomReflector
class OrderItemHDForm extends TomForm<OrderItemHD> {
  OrderItemHDForm() : super(formId: 'orderItemHD');

  late final productName = TomFormSearchInput<String>(
    'productName',
    '',
    form: this,
    source: phase2aProductSource(),
    labelTextOverride: 'Product',
    validators: [Validators.required()],
    autoValidate: true,
  );

  late final quantity = TomFormStringInput(
    'quantity',
    '1',
    form: this,
    labelTextOverride: 'Qty',
    keyboardType: const TextInputType.numberWithOptions(),
    validators: [Validators.required(), integerValidator],
    autoValidate: true,
  );

  late final unitPrice = TomFormStringInput(
    'unitPrice',
    '0.00',
    form: this,
    labelTextOverride: 'Unit price',
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    validators: [Validators.required(), decimalValidator],
    autoValidate: true,
  );

  late final notes = TomFormStringInput(
    'notes',
    '',
    form: this,
    labelTextOverride: 'Notes',
  );

  @override
  void createFormElements() {}

  double get computedTotal {
    final q = int.tryParse(quantity.get()) ?? 0;
    final p = double.tryParse(unitPrice.get()) ?? 0.0;
    return q * p;
  }
}

// ---------------------------------------------------------------------------
// 2. Order items list form
// ---------------------------------------------------------------------------

class OrderItemHDListForm extends TomListForm<OrderItemHD, OrderItemHDForm> {
  OrderItemHDListForm({required super.parentForm})
    : super(listId: 'orderItemHD', formFactory: (_) => OrderItemHDForm());

  @override
  OrderItemHD createItem() {
    final i = OrderItemHD();
    i.productName | '';
    i.quantity | '1';
    i.unitPrice | '0.00';
    i.notes | '';
    return i;
  }
}

// ---------------------------------------------------------------------------
// 3. Order form
// ---------------------------------------------------------------------------

/// One order (Demos H-D / H-E) — header fields plus a nested
/// [OrderItemHDListForm].
///
/// Exercises `tom_flutter_ui`'s nested `TomListForm` ownership and a
/// `TomFormSearchInput<String>` "Ship to" picker driven by a live
/// shipping-label source.
@tomReflector
class OrderHDForm extends TomForm<OrderHD> {
  /// [shippingLabelSource] — when provided, the "Ship to" field renders as a
  /// search picker over the customer's current shipping address labels.
  /// Falls back to a plain text input when null (e.g. in stand-alone tests).
  OrderHDForm({TomSelectableSource<String>? shippingLabelSource})
    : _shippingLabelSource =
          shippingLabelSource ?? StaticSelectableSource<String>([]),
      super(formId: 'orderHD');

  final TomSelectableSource<String> _shippingLabelSource;

  late final orderId = TomFormStringInput(
    'orderId',
    '',
    form: this,
    labelTextOverride: 'Order ID',
    validators: [Validators.required()],
  );

  late final orderDate = TomFormStringInput(
    'orderDate',
    '',
    form: this,
    labelTextOverride: 'Order date (YYYY-MM-DD)',
    validators: [Validators.required()],
  );

  /// Search picker over the customer's shipping address labels.
  /// Stores the selected label string in the underlying TomString.
  late final shippingLabel = TomFormSearchInput<String>(
    'shippingLabel',
    '',
    form: this,
    source: _shippingLabelSource,
    labelTextOverride: 'Ship to (address label)',
    hintTextOverride: 'Select or type an address label…',
  );

  late final OrderItemHDListForm items = OrderItemHDListForm(parentForm: this);

  double get totalAmount {
    double total = 0;
    for (var i = 0; i < items.length; i++) {
      total += items[i].computedTotal;
    }
    return total;
  }

  @override
  void createFormElements() {}

  @override
  void onBound() {
    items.bind(currentBinding!.items);
  }

  @override
  void onUnbinding() {
    items.unbind();
  }
}

// ---------------------------------------------------------------------------
// 4. Order list form
// ---------------------------------------------------------------------------

class OrderHDListForm extends TomListForm<OrderHD, OrderHDForm> {
  /// [shippingLabelSource] is threaded into each child [OrderHDForm] so that
  /// the "Ship to" picker always shows the customer's current addresses.
  OrderHDListForm({
    required super.parentForm,
    TomSelectableSource<String>? shippingLabelSource,
  }) : super(
         listId: 'orderHD',
         formFactory: (_) =>
             OrderHDForm(shippingLabelSource: shippingLabelSource),
       );

  @override
  OrderHD createItem() {
    final o = OrderHD();
    final now = DateTime.now();
    o.orderId | 'ORD-${now.millisecondsSinceEpoch % 10000}'.padLeft(7, '0');
    o.orderDate |
        '${now.year}-${now.month.toString().padLeft(2, '0')}'
            '-${now.day.toString().padLeft(2, '0')}';
    o.shippingLabel | '';
    return o;
  }
}

// ---------------------------------------------------------------------------
// 5. Shipping address form
// ---------------------------------------------------------------------------

/// One shipping address (Demos H-D / H-E).
///
/// Exercises a flat block of `tom_flutter_ui` `TomFormStringInput` fields
/// rendered as the detail pane of a `TomMasterDetailListForm`.
@tomReflector
class ShippingAddressHDForm extends TomForm<ShippingAddressHD> {
  ShippingAddressHDForm() : super(formId: 'shippingAddressHD');

  late final label = TomFormStringInput(
    'label',
    '',
    form: this,
    labelTextOverride: 'Label',
    hintTextOverride: 'e.g. Warehouse, Main Office',
    validators: [Validators.required()],
  );

  late final line1 = TomFormStringInput(
    'line1',
    '',
    form: this,
    labelTextOverride: 'Address line 1',
    validators: [Validators.required()],
  );

  late final line2 = TomFormStringInput(
    'line2',
    '',
    form: this,
    labelTextOverride: 'Address line 2',
  );

  late final city = TomFormStringInput(
    'city',
    '',
    form: this,
    labelTextOverride: 'City',
    validators: [Validators.required()],
  );

  late final stateRegion = TomFormStringInput(
    'stateRegion',
    '',
    form: this,
    labelTextOverride: 'State / Province',
  );

  late final zipCode = TomFormStringInput(
    'zipCode',
    '',
    form: this,
    labelTextOverride: 'ZIP / Postal code',
    validators: [Validators.required()],
  );

  late final country = TomFormStringInput(
    'country',
    '',
    form: this,
    labelTextOverride: 'Country',
    validators: [Validators.required()],
  );

  @override
  void createFormElements() {}
}

// ---------------------------------------------------------------------------
// 6. Shipping address list form
// ---------------------------------------------------------------------------

class ShippingAddressHDListForm
    extends TomListForm<ShippingAddressHD, ShippingAddressHDForm> {
  ShippingAddressHDListForm({required super.parentForm})
    : super(
        listId: 'shippingAddressHD',
        formFactory: (_) => ShippingAddressHDForm(),
      );

  @override
  ShippingAddressHD createItem() {
    final a = ShippingAddressHD();
    a.label | '';
    a.line1 | '';
    a.line2 | '';
    a.city | '';
    a.stateRegion | '';
    a.zipCode | '';
    a.country | '';
    return a;
  }
}

// ---------------------------------------------------------------------------
// 7. Customer HD form — the root form for Demos H-D and H-E
// ---------------------------------------------------------------------------

/// Root form for Demos H-D and H-E.
///
/// Exercises a deep `tom_flutter_ui` form: flat contact + billing fields plus
/// two nested list forms ([ShippingAddressHDListForm] and [OrderHDListForm])
/// whose dirty state aggregates into this one parent. The orders list's
/// "Ship to" picker reads the customer's current shipping-address labels
/// live via [shippingAddressLabelSource].
@tomReflector
class CustomerHDForm extends TomForm<CustomerHD> {
  CustomerHDForm() : super(formId: 'customerHD');

  // Contact fields
  late final fullName = TomFormStringInput(
    'fullName',
    '',
    form: this,
    labelTextOverride: 'Full name',
    validators: [Validators.required(), Validators.minLength(2)],
  );

  late final email = TomFormStringInput(
    'email',
    '',
    form: this,
    labelTextOverride: 'Email',
    keyboardType: TextInputType.emailAddress,
    validators: [Validators.required(), Validators.email()],
  );

  late final phone = TomFormStringInput(
    'phone',
    '',
    form: this,
    labelTextOverride: 'Phone',
    keyboardType: TextInputType.phone,
  );

  // Billing address — flat fields bound directly to CustomerHD's strings
  late final billLine1 = TomFormStringInput(
    'billLine1',
    '',
    form: this,
    labelTextOverride: 'Address line 1',
  );

  late final billLine2 = TomFormStringInput(
    'billLine2',
    '',
    form: this,
    labelTextOverride: 'Address line 2',
  );

  late final billCity = TomFormStringInput(
    'billCity',
    '',
    form: this,
    labelTextOverride: 'City',
  );

  late final billState = TomFormStringInput(
    'billState',
    '',
    form: this,
    labelTextOverride: 'State / Province',
  );

  late final billZip = TomFormStringInput(
    'billZip',
    '',
    form: this,
    labelTextOverride: 'ZIP / Postal code',
  );

  late final billCountry = TomFormStringInput(
    'billCountry',
    '',
    form: this,
    labelTextOverride: 'Country',
  );

  // Sub-list forms
  late final ShippingAddressHDListForm shippingAddresses =
      ShippingAddressHDListForm(parentForm: this);

  // The orders list form receives a live source that reads the customer's
  // current shipping address labels each time the picker is opened.
  late final OrderHDListForm orders = OrderHDListForm(
    parentForm: this,
    shippingLabelSource: _ShippingLabelSource(() => shippingAddresses),
  );

  /// A live [TomSelectableSource<String>] that reads this customer's current
  /// shipping address labels on every [getItems] call.
  ///
  /// Pass this to standalone [OrderHDForm] instances when the picker
  /// should track the customer's current addresses live (e.g. an
  /// embedded "create order" form).
  TomSelectableSource<String> get shippingAddressLabelSource =>
      _ShippingLabelSource(() => shippingAddresses);

  @override
  void createFormElements() {}

  @override
  void onBound() {
    shippingAddresses.bind(currentBinding!.shippingAddresses);
    orders.bind(currentBinding!.orders);
  }

  @override
  void onUnbinding() {
    shippingAddresses.unbind();
    orders.unbind();
  }
}

// ---------------------------------------------------------------------------
// Dynamic shipping-label source — reads current address labels on demand
// ---------------------------------------------------------------------------

/// A [TomSelectableSource<String>] that builds its item list from the
/// customer's shipping address list form each time [getItems] is called.
///
/// By using a provider callback instead of capturing the list form at
/// construction time, the source stays correct even if the field is
/// accessed before the parent form fully initialises its late fields.
class _ShippingLabelSource extends TomSelectableSource<String> {
  final ShippingAddressHDListForm Function() _listProvider;

  _ShippingLabelSource(this._listProvider);

  @override
  Future<List<SelectableItem<String>>> getItems() async {
    final list = _listProvider();
    final items = <SelectableItem<String>>[];
    for (var i = 0; i < list.length; i++) {
      final label = list[i].currentBinding?.label.get() ?? '';
      if (label.isNotEmpty) {
        items.add(SelectableItem<String>(value: label, label: label));
      }
    }
    return items;
  }
}

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/example_state.dart';

// ---------------------------------------------------------------------------
// Family-agnostic forms for the rich `ExampleCustomerRich` graph.
//
// Hierarchy mirrors the data:
//
//   ExampleCustomerRichForm  (TomForm<ExampleCustomerRich>)
//     - flat fields for every primitive field type the form layer ships
//     - addresses → ExampleAddressListForm  (each row → ExampleAddressForm)
//     - orders    → ExampleOrderListForm    (each row → ExampleOrderForm)
//                                             which owns its own items list
//
// Every field is created through a [TomFormFieldFamily] factory so the same
// form classes render natively in both Material and Cupertino — only the
// `family` parameter passed at construction time changes between the two
// example screens.
//
// Form and list ids are single camelCase segments — `exampleCustomer`, not
// `example.customer`. A form id is used directly as a scope id, and a scope
// id may not contain the '.' that scope paths are joined with: an id that
// forged a path segment would let a form address another scope's resources.
// The `example` prefix therefore lives inside the id, and the resource keys
// in `shared/example_resources.dart` are prefixed to match.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Order item — string / int / double / nullable string
// ---------------------------------------------------------------------------
@tomReflector
class ExampleOrderItemForm extends TomForm<ExampleOrderItem> {
  ExampleOrderItemForm({required TomFormFieldFamily family})
    : _f = family,
      super(formId: 'exampleOrderItem');

  final TomFormFieldFamily _f;

  late final productName = _f.stringInput(
    'productName',
    '',
    form: this,
    labelTextOverride: 'Product',
    validators: [TomValidators.required()],
  );

  late final quantity = _f.intInput(
    'quantity',
    1,
    form: this,
    labelTextOverride: 'Qty',
    validators: [TomValidators.required()],
  );

  late final unitPrice = _f.doubleInput(
    'unitPrice',
    0,
    form: this,
    labelTextOverride: 'Unit price',
    decimals: 2,
    validators: [TomValidators.required()],
  );

  late final notes = _f.nStringInput(
    'notes',
    null,
    form: this,
    labelTextOverride: 'Notes',
  );

  /// Cheap derived value used by the H-C totals row.
  double get lineTotal => quantity.get() * unitPrice.get();

  @override
  void createFormElements() {}
}

@tomReflector
class ExampleOrderItemListForm
    extends TomListForm<ExampleOrderItem, ExampleOrderItemForm> {
  ExampleOrderItemListForm({
    required TomFormFieldFamily family,
    super.parentForm,
  }) : super(
         listId: 'exampleOrderItem',
         formFactory: (_) => ExampleOrderItemForm(family: family),
       );

  @override
  ExampleOrderItem createItem() {
    final i = ExampleOrderItem();
    i.productName | 'New product';
    i.quantity | 1;
    i.unitPrice | 0;
    return i;
  }
}

// ---------------------------------------------------------------------------
// Order — string / date / enum-like string / bool + items list
// ---------------------------------------------------------------------------
@tomReflector
class ExampleOrderForm extends TomForm<ExampleOrder> {
  ExampleOrderForm({required TomFormFieldFamily family})
    : _f = family,
      super(formId: 'exampleOrder');

  final TomFormFieldFamily _f;

  late final orderId = _f.stringInput(
    'orderId',
    '',
    form: this,
    labelTextOverride: 'Order ID',
    validators: [TomValidators.required()],
  );

  late final orderDate = _f.datePicker(
    'orderDate',
    DateTime(2026, 1, 1),
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    form: this,
    labelTextOverride: 'Order date',
  );

  /// Priority is modelled as a small selectable string source — same data
  /// shape as the customer's `tier` field in the simpler H-A example.
  late final priority = _f.searchInput<String>(
    'priority',
    'standard',
    form: this,
    source: _priorityOptions,
    labelTextOverride: 'Priority',
  );

  late final paid = _f.boolSwitch(
    'paid',
    false,
    form: this,
    labelTextOverride: 'Paid',
  );

  late final ExampleOrderItemListForm items = ExampleOrderItemListForm(
    family: _f,
    parentForm: this,
  );

  /// Sum of every item's line total — purely derived, but useful for the
  /// summary row in the H-B and H-C examples.
  double get total {
    var sum = 0.0;
    for (var i = 0; i < items.length; i++) {
      sum += items[i].lineTotal;
    }
    return sum;
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

@tomReflector
class ExampleOrderListForm extends TomListForm<ExampleOrder, ExampleOrderForm> {
  ExampleOrderListForm({required TomFormFieldFamily family, super.parentForm})
    : super(
        listId: 'exampleOrder',
        formFactory: (_) => ExampleOrderForm(family: family),
      );

  @override
  ExampleOrder createItem() {
    final o = ExampleOrder();
    final now = DateTime.now();
    o.orderId | 'ORD-${now.millisecondsSinceEpoch % 10000}';
    o.orderDate | now;
    o.priority | 'standard';
    o.paid | false;
    return o;
  }
}

// ---------------------------------------------------------------------------
// Address — pure string input form
// ---------------------------------------------------------------------------
@tomReflector
class ExampleAddressForm extends TomForm<ExampleAddress> {
  ExampleAddressForm({required TomFormFieldFamily family})
    : _f = family,
      super(formId: 'exampleAddress');

  final TomFormFieldFamily _f;

  late final label = _f.stringInput(
    'label',
    '',
    form: this,
    labelTextOverride: 'Label',
    validators: [TomValidators.required()],
  );

  late final line1 = _f.stringInput(
    'line1',
    '',
    form: this,
    labelTextOverride: 'Address line 1',
    validators: [TomValidators.required()],
  );

  late final city = _f.stringInput(
    'city',
    '',
    form: this,
    labelTextOverride: 'City',
    validators: [TomValidators.required()],
  );

  late final country = _f.stringInput(
    'country',
    '',
    form: this,
    labelTextOverride: 'Country',
    validators: [TomValidators.required()],
  );

  @override
  void createFormElements() {}
}

@tomReflector
class ExampleAddressListForm
    extends TomListForm<ExampleAddress, ExampleAddressForm> {
  ExampleAddressListForm({required TomFormFieldFamily family, super.parentForm})
    : super(
        listId: 'exampleAddress',
        formFactory: (_) => ExampleAddressForm(family: family),
      );

  @override
  ExampleAddress createItem() {
    final a = ExampleAddress();
    a.label | 'New location';
    a.line1 | '';
    a.city | '';
    a.country | '';
    return a;
  }
}

// ---------------------------------------------------------------------------
// Customer — covers every field family the form layer ships
//
//   string  → fullName, email, phone, company
//   search  → tier
//   bool    → vip
//   int     → loyaltyPoints
//   double  → creditLimit
//   date    → memberSince
//   list    → addresses, orders
// ---------------------------------------------------------------------------
@tomReflector
class ExampleCustomerRichForm extends TomForm<ExampleCustomerRich> {
  ExampleCustomerRichForm({required TomFormFieldFamily family})
    : _f = family,
      super(formId: 'exampleCustomer');

  final TomFormFieldFamily _f;

  // --- Strings -----------------------------------------------------------
  late final fullName = _f.stringInput(
    'fullName',
    '',
    form: this,
    labelTextOverride: 'Full name',
    validators: [TomValidators.required(), TomValidators.minLength(2)],
  );

  late final email = _f.stringInput(
    'email',
    '',
    form: this,
    labelTextOverride: 'Email',
    validators: [TomValidators.required(), TomValidators.email()],
  );

  late final phone = _f.stringInput(
    'phone',
    '',
    form: this,
    labelTextOverride: 'Phone',
  );

  late final company = _f.stringInput(
    'company',
    '',
    form: this,
    labelTextOverride: 'Company',
  );

  // --- Selectable string ------------------------------------------------
  late final tier = _f.searchInput<String>(
    'tier',
    'standard',
    form: this,
    source: _tierOptions,
    labelTextOverride: 'Tier',
    validators: [TomValidators.required()],
  );

  // --- Bool / int / double / date ---------------------------------------
  late final vip = _f.boolSwitch(
    'vip',
    false,
    form: this,
    labelTextOverride: 'VIP customer',
  );

  late final loyaltyPoints = _f.intInput(
    'loyaltyPoints',
    0,
    form: this,
    labelTextOverride: 'Loyalty points',
  );

  late final creditLimit = _f.doubleInput(
    'creditLimit',
    0,
    form: this,
    labelTextOverride: 'Credit limit',
    decimals: 2,
  );

  late final memberSince = _f.datePicker(
    'memberSince',
    DateTime(2026, 1, 1),
    firstDate: DateTime(2000),
    lastDate: DateTime(2030),
    form: this,
    labelTextOverride: 'Member since',
  );

  // --- Nested lists -----------------------------------------------------
  late final ExampleAddressListForm addresses = ExampleAddressListForm(
    family: _f,
    parentForm: this,
  );
  late final ExampleOrderListForm orders = ExampleOrderListForm(
    family: _f,
    parentForm: this,
  );

  @override
  void createFormElements() {}

  @override
  void onBound() {
    addresses.bind(currentBinding!.addresses);
    orders.bind(currentBinding!.orders);
  }

  @override
  void onUnbinding() {
    addresses.unbind();
    orders.unbind();
  }
}

// ---------------------------------------------------------------------------
// Static selectable sources — referenced by the form fields above
// ---------------------------------------------------------------------------
final _tierOptions = TomStaticSelectableSource<String>(const [
  TomSelectableItem(value: 'standard', label: 'Standard'),
  TomSelectableItem(value: 'silver', label: 'Silver'),
  TomSelectableItem(value: 'gold', label: 'Gold'),
  TomSelectableItem(value: 'platinum', label: 'Platinum'),
]);

final _priorityOptions = TomStaticSelectableSource<String>(const [
  TomSelectableItem(value: 'standard', label: 'Standard'),
  TomSelectableItem(value: 'priority', label: 'Priority'),
  TomSelectableItem(value: 'overnight', label: 'Overnight'),
]);

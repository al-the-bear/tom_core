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
// Every field is created through a [FormFieldFamily] factory so the same
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
  ExampleOrderItemForm({required FormFieldFamily family})
    : _f = family,
      super(formId: 'exampleOrderItem');

  final FormFieldFamily _f;

  late final productName = _f.stringInput(
    'productName',
    '',
    form: this,
    labelTextOverride: 'Product',
    validators: [Validators.required()],
  );

  late final quantity = _f.intInput(
    'quantity',
    1,
    form: this,
    labelTextOverride: 'Qty',
    validators: [Validators.required()],
  );

  late final unitPrice = _f.doubleInput(
    'unitPrice',
    0,
    form: this,
    labelTextOverride: 'Unit price',
    decimals: 2,
    validators: [Validators.required()],
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
  ExampleOrderItemListForm({required FormFieldFamily family, super.parentForm})
    : super(
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
  ExampleOrderForm({required FormFieldFamily family})
    : _f = family,
      super(formId: 'exampleOrder');

  final FormFieldFamily _f;

  late final orderId = _f.stringInput(
    'orderId',
    '',
    form: this,
    labelTextOverride: 'Order ID',
    validators: [Validators.required()],
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
  ExampleOrderListForm({required FormFieldFamily family, super.parentForm})
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
  ExampleAddressForm({required FormFieldFamily family})
    : _f = family,
      super(formId: 'exampleAddress');

  final FormFieldFamily _f;

  late final label = _f.stringInput(
    'label',
    '',
    form: this,
    labelTextOverride: 'Label',
    validators: [Validators.required()],
  );

  late final line1 = _f.stringInput(
    'line1',
    '',
    form: this,
    labelTextOverride: 'Address line 1',
    validators: [Validators.required()],
  );

  late final city = _f.stringInput(
    'city',
    '',
    form: this,
    labelTextOverride: 'City',
    validators: [Validators.required()],
  );

  late final country = _f.stringInput(
    'country',
    '',
    form: this,
    labelTextOverride: 'Country',
    validators: [Validators.required()],
  );

  @override
  void createFormElements() {}
}

@tomReflector
class ExampleAddressListForm
    extends TomListForm<ExampleAddress, ExampleAddressForm> {
  ExampleAddressListForm({required FormFieldFamily family, super.parentForm})
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
  ExampleCustomerRichForm({required FormFieldFamily family})
    : _f = family,
      super(formId: 'exampleCustomer');

  final FormFieldFamily _f;

  // --- Strings -----------------------------------------------------------
  late final fullName = _f.stringInput(
    'fullName',
    '',
    form: this,
    labelTextOverride: 'Full name',
    validators: [Validators.required(), Validators.minLength(2)],
  );

  late final email = _f.stringInput(
    'email',
    '',
    form: this,
    labelTextOverride: 'Email',
    validators: [Validators.required(), Validators.email()],
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
    validators: [Validators.required()],
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
final _tierOptions = StaticSelectableSource<String>(const [
  SelectableItem(value: 'standard', label: 'Standard'),
  SelectableItem(value: 'silver', label: 'Silver'),
  SelectableItem(value: 'gold', label: 'Gold'),
  SelectableItem(value: 'platinum', label: 'Platinum'),
]);

final _priorityOptions = StaticSelectableSource<String>(const [
  SelectableItem(value: 'standard', label: 'Standard'),
  SelectableItem(value: 'priority', label: 'Priority'),
  SelectableItem(value: 'overnight', label: 'Overnight'),
]);

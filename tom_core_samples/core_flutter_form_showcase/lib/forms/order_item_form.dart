/// `TomForm` subclass bound to [OrderItem] — the single row of an order's
/// items list, used by the list cells.
///
/// Mirrors the verified `tom_flutter_form_test` `OrderItemForm`: a type-ahead
/// `TomFormSearchInput<String>` over a product catalogue beside auto-validating
/// `TomFormStringInput` quantity / price fields. Flat, so binding a reflected
/// [OrderItem] needs only kernel-level reflection.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../domain/showcase_entities.dart';

/// A small product catalogue (name → price). Selecting a known entry auto-fills
/// the unit price; free-form entries leave it untouched.
const Map<String, double> productCatalogue = {
  'Difference Engine pinion': 34.50,
  'Punched-card deck (1000 pk)': 49.00,
  'Lubricating oil (1L)': 6.75,
  'Patch review token': 12.00,
  'Maintainer T-shirt': 24.50,
  'Conference badge': 0.00,
  'Brass gear (medium)': 7.80,
  'Crank handle': 22.00,
  'Mainspring assembly': 58.50,
  'Drive belt 24"': 16.45,
};

/// Look up a catalogue price by exact name, or `null` for a free-form entry.
double? lookupProductPrice(String name) => productCatalogue[name];

/// Build a labelled selectable source over the catalogue (label embeds price).
TomSelectableSource<String> productSource() {
  final items = productCatalogue.entries
      .map(
        (e) => SelectableItem<String>(
          value: e.key,
          label: '${e.key}  —  \$${e.value.toStringAsFixed(2)}',
        ),
      )
      .toList();
  return StaticSelectableSource<String>(items);
}

/// A single editable order-item row.
@tomReflector
class OrderItemForm extends TomForm<OrderItem> {
  /// Creates the row form; `formId` matches a parent list's `items` id so
  /// resources resolve uniformly across rows.
  OrderItemForm() : super(formId: 'items');

  /// Type-ahead product picker over [productSource].
  late final productName = TomFormSearchInput<String>(
    'productName',
    '',
    source: productSource(),
    form: this,
    labelTextOverride: 'Product',
    hintTextOverride: 'Type to search the catalogue…',
    validators: [Validators.required()],
  );

  /// Quantity — required positive integer, validated as the user types.
  late final quantity = TomFormStringInput(
    'quantity',
    '1',
    form: this,
    labelTextOverride: 'Qty',
    autoValidate: true,
    validators: [Validators.required(), _positiveIntegerValidator],
  );

  /// Unit price — required non-negative decimal, validated as the user types.
  late final unitPrice = TomFormStringInput(
    'unitPrice',
    '0.00',
    form: this,
    labelTextOverride: 'Unit price',
    autoValidate: true,
    validators: [Validators.required(), _decimalValidator],
  );

  /// Free-text notes.
  late final notes = TomFormStringInput(
    'notes',
    '',
    form: this,
    labelTextOverride: 'Notes',
  );

  TomFunctionObserver<TomObservable>? _priceSync;

  @override
  void createFormElements() {
    // When the product changes to a known catalogue entry, mirror its price
    // into unitPrice. Free-form entries leave the price untouched.
    _priceSync =
        productName >>
        (_) {
          final price = lookupProductPrice(productName.get());
          if (price != null) {
            final next = price.toStringAsFixed(2);
            if (unitPrice.get() != next) unitPrice.setValue(next);
          }
        };
  }

  @override
  void dispose() {
    final obs = _priceSync;
    if (obs != null) productName.removeObserver(obs);
    super.dispose();
  }
}

/// A `TomListForm` over [OrderItem] rows, each edited by an [OrderItemForm].
///
/// Drives the master-detail and list cells: the toolbar's *add* calls
/// [createItem] to append a fresh, seeded row, while [OrderItemForm] supplies
/// the per-row editor through `formFactory`.
class OrderItemListForm extends TomListForm<OrderItem, OrderItemForm> {
  /// Creates the list form; `listId` matches the row form's `formId` so
  /// resources resolve uniformly between the list and its rows.
  OrderItemListForm()
    : super(listId: 'items', formFactory: (_) => OrderItemForm());

  @override
  OrderItem createItem() {
    final item = OrderItem();
    item.productName | '';
    item.quantity | '1';
    item.unitPrice | '0.00';
    item.notes | '';
    return item;
  }
}

/// Builds a small, pre-populated [TomList] of order items so the list and
/// master-detail cells show real rows on first open.
TomList<OrderItem> seededOrderItems() {
  final items = TomList<OrderItem>();
  void add(String product, String qty, String price, String notes) {
    final item = OrderItem();
    item.productName | product;
    item.quantity | qty;
    item.unitPrice | price;
    item.notes | notes;
    items.add(item);
  }

  add('Difference Engine pinion', '12', '34.50', 'Brass; lot #B-117');
  add('Punched-card deck (1000 pk)', '3', '49.00', 'Standard perforation');
  add('Lubricating oil (1L)', '5', '6.75', '');
  return items;
}

ValidationResult _positiveIntegerValidator(String value) {
  final n = int.tryParse(value);
  if (n == null) return const ValidationError('error.invalidInteger');
  if (n <= 0) return const ValidationError('error.mustBePositive');
  return const ValidationSuccess();
}

ValidationResult _decimalValidator(String value) {
  final n = double.tryParse(value);
  if (n == null) return const ValidationError('error.invalidDecimal');
  if (n < 0) return const ValidationError('error.mustBeNonNegative');
  return const ValidationSuccess();
}

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/phase2a_state.dart';
import 'form_validators.dart';

// ---------------------------------------------------------------------------
// OrderItemForm — single row of the order's items list.
// ---------------------------------------------------------------------------

/// Single row of the order's items list (used by Demos H-B / H-C).
///
/// Exercises `tom_flutter_ui`'s `TomFormSearchInput<String>` type-ahead
/// picker (over `phase2aProductCatalog`) alongside auto-validating
/// `TomFormStringInput` fields.
///
/// `formId` matches the parent's listId ('items') so resources resolve
/// uniformly for every row (spec §13: "Resources and authorization apply
/// uniformly to all list items").
///
/// Selecting a known catalog entry auto-fills `unitPrice` via the observer
/// attached in `createFormElements`. `quantity` and `unitPrice` use
/// `autoValidate: true` so Demos H-B and H-C surface inline errors as the
/// user types — e.g. quantity = 0 trips `error.mustBePositive` immediately,
/// which the row-switch guard in H-B uses to refuse switching away from an
/// invalid row.
@tomReflector
class OrderItemForm extends TomForm<OrderItem> {
  OrderItemForm() : super(formId: 'items');

  late final productName = TomFormSearchInput<String>(
    'productName',
    '',
    source: phase2aProductSource(),
    form: this,
    labelTextOverride: 'Product',
    hintTextOverride: 'Type to search the catalog…',
    validators: [Validators.required()],
  );

  late final quantity = TomFormStringInput(
    'quantity',
    '1',
    form: this,
    labelTextOverride: 'Qty',
    autoValidate: true,
    validators: [Validators.required(), positiveIntegerValidator],
  );

  late final unitPrice = TomFormStringInput(
    'unitPrice',
    '0.00',
    form: this,
    labelTextOverride: 'Unit price',
    autoValidate: true,
    validators: [Validators.required(), decimalValidator],
  );

  late final notes = TomFormStringInput(
    'notes',
    '',
    form: this,
    labelTextOverride: 'Notes',
  );

  TomFunctionObserver<TomObservable>? _priceSync;

  @override
  void createFormElements() {
    // When the product changes to a known catalog entry, mirror its
    // price into `unitPrice`. Free-form entries (anything not in the
    // catalog) leave the price untouched.
    _priceSync =
        productName >>
        (_) {
          final price = phase2aLookupProductPrice(productName.get());
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

  /// Computed total = quantity × unitPrice. Returns 0 when either side
  /// can't be parsed (rendered cells just show 0.00 in that case).
  double get computedTotal {
    final q = int.tryParse(~quantity) ?? 0;
    final p = double.tryParse(~unitPrice) ?? 0.0;
    return q * p;
  }
}

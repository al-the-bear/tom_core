import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

import '../state/phase2a_state.dart';

// ---------------------------------------------------------------------------
// OrderItemForm — single row of the order's items list.
// ---------------------------------------------------------------------------
//
// `formId` matches the parent's listId ('items') so resources resolve
// uniformly for every row (spec §13: "Resources and authorization apply
// uniformly to all list items").
@tomReflector
class OrderItemForm extends TomForm<OrderItem> {
  OrderItemForm() : super(formId: 'items');

  late final productName = TomFormStringInput(
    'productName',
    '',
    form: this,
    labelTextOverride: 'Product',
    validators: [Validators.required()],
  );

  late final quantity = TomFormStringInput(
    'quantity',
    '1',
    form: this,
    labelTextOverride: 'Qty',
    validators: [Validators.required(), _positiveIntegerValidator],
  );

  late final unitPrice = TomFormStringInput(
    'unitPrice',
    '0.00',
    form: this,
    labelTextOverride: 'Unit price',
    validators: [Validators.required(), _decimalValidator],
  );

  late final notes = TomFormStringInput(
    'notes',
    '',
    form: this,
    labelTextOverride: 'Notes',
  );

  @override
  void createFormElements() {}

  /// Computed total = quantity × unitPrice. Returns 0 when either side
  /// can't be parsed (rendered cells just show 0.00 in that case).
  double get computedTotal {
    final q = int.tryParse(~quantity) ?? 0;
    final p = double.tryParse(~unitPrice) ?? 0.0;
    return q * p;
  }
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

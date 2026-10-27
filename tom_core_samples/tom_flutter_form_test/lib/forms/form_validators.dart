import 'package:tom_flutter_ui/tom_flutter_ui.dart';

// ---------------------------------------------------------------------------
// Numeric field validators shared across the demo forms.
//
// Shared by `customer_hd_form.dart` and `order_item_form.dart`, and kept
// here rather than file-private in each: the decimal validator is the same
// rule in both, and the integer and positive-integer validators differ only
// by the positivity guard. A private copy apiece is two places for one rule
// to drift.
// ---------------------------------------------------------------------------

/// Accepts any parseable `int`; rejects non-integer text.
TomValidationResult integerValidator(String value) {
  final n = int.tryParse(value);
  if (n == null) return const TomValidationError('error.invalidInteger');
  return const TomValidationSuccess();
}

/// Accepts a strictly positive `int`; rejects non-integers and `n <= 0`.
TomValidationResult positiveIntegerValidator(String value) {
  final n = int.tryParse(value);
  if (n == null) return const TomValidationError('error.invalidInteger');
  if (n <= 0) return const TomValidationError('error.mustBePositive');
  return const TomValidationSuccess();
}

/// Accepts a non-negative `double`; rejects non-numbers and `n < 0`.
TomValidationResult decimalValidator(String value) {
  final n = double.tryParse(value);
  if (n == null) return const TomValidationError('error.invalidDecimal');
  if (n < 0) return const TomValidationError('error.mustBeNonNegative');
  return const TomValidationSuccess();
}

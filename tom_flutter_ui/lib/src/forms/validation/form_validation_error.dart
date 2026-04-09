import 'validation_result.dart';

/// A cross-field validation error produced by [TomForm.validateForm].
///
/// Unlike [ValidationError] which applies to a single field, this
/// represents an error spanning multiple fields (e.g., "end date must
/// be after start date").
class FormValidationError {
  /// The primary error key (for the form-level error message).
  final String errorKey;

  /// Optional parameters for message interpolation.
  final Map<String, dynamic>? params;

  /// Field IDs involved in this cross-field error.
  final List<String> fields;

  /// Per-field error keys (optional; use different resource keys per field).
  /// Keys are field IDs. If null, all fields show the same [errorKey].
  final Map<String, String>? fieldErrorKeys;

  const FormValidationError({
    required this.errorKey,
    this.params,
    required this.fields,
    this.fieldErrorKeys,
  });

  @override
  String toString() =>
      'FormValidationError($errorKey, fields: $fields${fieldErrorKeys != null ? ', fieldErrorKeys: $fieldErrorKeys' : ''})';
}

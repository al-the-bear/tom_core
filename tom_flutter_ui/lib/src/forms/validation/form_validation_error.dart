import '../tom_form.dart';
import 'validation_result.dart';

/// A cross-field validation error produced by [TomForm.validateForm].
///
/// Unlike [ValidationError] which applies to a single field, this
/// represents an error spanning multiple fields (e.g., "end date must
/// be after start date").
///
/// Carries both field references ([fields]) for programmatic access
/// and field IDs ([fieldIds]) for display in error messages.
class FormValidationError {
  /// The primary error key (for the form-level error message).
  final String errorKey;

  /// Optional parameters for message interpolation.
  final Map<String, dynamic>? params;

  /// Field references involved in this cross-field error.
  final List<TomField> fields;

  /// Per-field error keys (optional; use different resource keys per field).
  /// Keys are fields. If null, all fields show the same [errorKey].
  final Map<TomField, String>? fieldErrorKeys;

  FormValidationError({
    required this.errorKey,
    this.params,
    required this.fields,
    this.fieldErrorKeys,
  });

  /// Field IDs involved in this error (convenience getter).
  List<String> get fieldIds => fields.map((f) => f.fieldId).toList();

  @override
  String toString() =>
      'FormValidationError($errorKey, fields: $fieldIds${fieldErrorKeys != null ? ', fieldErrorKeys: $fieldErrorKeys' : ''})';
}

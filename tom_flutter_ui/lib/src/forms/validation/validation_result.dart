import 'dart:async';

/// Result of validating a field value.
///
/// This is a sealed class with four variants:
/// - [ValidationPristine] — field has not yet been validated (initial state)
/// - [ValidationSuccess] — validation passed
/// - [ValidationError] — validation failed with an error key
/// - [ValidationPending] — async validation is in progress
sealed class ValidationResult {
  const ValidationResult();
}

/// Initial state of every field before the user has interacted with it.
///
/// While pristine:
/// - The field does **not** display validation errors (even if technically invalid)
/// - The form's `isValid` returns `false` (pristine ≠ valid) but no errors are shown
///
/// A field transitions out of pristine when:
/// - The user modifies the field value (triggers debounced validation)
/// - The user attempts to save the form (`validate()` forces all pristine fields)
/// - `autoValidate` is `true` on the field (validates immediately on bind)
///
/// After `commit()`, `reset()`, `discard()`, or `bind()` the field returns
/// to pristine state.
class ValidationPristine extends ValidationResult {
  const ValidationPristine();

  @override
  bool operator ==(Object other) => other is ValidationPristine;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ValidationPristine()';
}

/// Indicates the field value is valid.
class ValidationSuccess extends ValidationResult {
  const ValidationSuccess();

  @override
  bool operator ==(Object other) => other is ValidationSuccess;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ValidationSuccess()';
}

/// Indicates the field value is invalid.
///
/// [errorKey] is a resource key relative to the field's basePath.
/// [params] provides values for message interpolation (e.g., `{'min': 5}`).
class ValidationError extends ValidationResult {
  final String errorKey;
  final Map<String, dynamic>? params;

  const ValidationError(this.errorKey, {this.params});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationError &&
          other.errorKey == errorKey;

  @override
  int get hashCode => errorKey.hashCode;

  @override
  String toString() => 'ValidationError($errorKey${params != null ? ', params: $params' : ''})';
}

/// Indicates that an async validation is in progress.
class ValidationPending extends ValidationResult {
  const ValidationPending();

  @override
  bool operator ==(Object other) => other is ValidationPending;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ValidationPending()';
}

/// A function that validates a value of type [T].
///
/// Returns a [ValidationResult] synchronously or asynchronously.
/// Sync validators return the result directly; async validators
/// return a `Future<ValidationResult>`.
typedef Validator<T> = FutureOr<ValidationResult> Function(T value);

/// Wraps a validator to mark it as "slow" (e.g., remote API call).
///
/// Slow validators differ from fast validators in two ways:
/// 1. They trigger after a longer debounce (`slowValidationDebounce`)
/// 2. They show a pending spinner (`ValidationPending`) during execution
///
/// Fast validators run immediately after the standard debounce and
/// do NOT transition through `ValidationPending`.
///
/// Usage:
/// ```dart
/// TomFormStringInput('email', '',
///   validators: [
///     Validators.required(),        // fast — no spinner
///     Validators.email(),           // fast — no spinner
///     SlowValidator(checkEmailAvailable), // slow — spinner shown
///   ],
/// )
/// ```
class SlowValidator<T> {
  final Validator<T> validate;
  const SlowValidator(this.validate);
}

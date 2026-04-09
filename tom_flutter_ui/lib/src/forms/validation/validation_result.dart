import 'dart:async';

/// Result of validating a field value.
///
/// This is a sealed class with three variants:
/// - [ValidationSuccess] — validation passed
/// - [ValidationError] — validation failed with an error key
/// - [ValidationPending] — async validation is in progress
sealed class ValidationResult {
  const ValidationResult();
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

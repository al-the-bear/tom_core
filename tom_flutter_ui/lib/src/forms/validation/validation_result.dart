import 'dart:async';

/// Result of validating a field value.
///
/// This is a sealed class with four variants:
/// - [TomValidationPristine] — field has not yet been validated (initial state)
/// - [TomValidationSuccess] — validation passed
/// - [TomValidationError] — validation failed with an error key
/// - [TomValidationPending] — async validation is in progress
sealed class TomValidationResult {
  const TomValidationResult();
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
class TomValidationPristine extends TomValidationResult {
  const TomValidationPristine();

  @override
  bool operator ==(Object other) => other is TomValidationPristine;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'TomValidationPristine()';
}

/// Indicates the field value is valid.
class TomValidationSuccess extends TomValidationResult {
  const TomValidationSuccess();

  @override
  bool operator ==(Object other) => other is TomValidationSuccess;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'TomValidationSuccess()';
}

/// Indicates the field value is invalid.
///
/// [errorKey] is a resource key relative to the field's basePath.
/// [params] provides values for message interpolation (e.g., `{'min': 5}`).
class TomValidationError extends TomValidationResult {
  final String errorKey;
  final Map<String, dynamic>? params;

  const TomValidationError(this.errorKey, {this.params});

  /// Substitutes this error's [params] into a resolved message [template],
  /// replacing each `{name}` placeholder with its value.
  ///
  /// This lives on the error rather than inside a resolver because *two*
  /// resolvers need it — [TomField.resolvedErrorMessage] and the decoration
  /// layer's `resolveFieldValidationMessage`, which is the one that actually
  /// paints the message. While only the former interpolated, every
  /// parameterised built-in (`minLength`, `maxLength`, `min`, `max`,
  /// `minItems`, `maxItems`) rendered its template verbatim on screen — a
  /// field would say "Use at least {min} characters." Keeping the substitution
  /// with the data it substitutes is what stops the two paths drifting apart
  /// again.
  String interpolate(String template) {
    final values = params;
    if (values == null || values.isEmpty) return template;
    var out = template;
    values.forEach((key, value) => out = out.replaceAll('{$key}', '$value'));
    return out;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TomValidationError && other.errorKey == errorKey;

  @override
  int get hashCode => errorKey.hashCode;

  @override
  String toString() =>
      'TomValidationError($errorKey${params != null ? ', params: $params' : ''})';
}

/// Indicates that an async validation is in progress.
class TomValidationPending extends TomValidationResult {
  const TomValidationPending();

  @override
  bool operator ==(Object other) => other is TomValidationPending;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'TomValidationPending()';
}

/// A function that validates a value of type [T].
///
/// Returns a [TomValidationResult] synchronously or asynchronously.
/// Sync validators return the result directly; async validators
/// return a `Future<TomValidationResult>`.
typedef TomValidator<T> = FutureOr<TomValidationResult> Function(T value);

/// Wraps a validator to mark it as "slow" (e.g., remote API call).
///
/// Slow validators differ from fast validators in two ways:
/// 1. They trigger after a longer debounce (`slowValidationDebounce`)
/// 2. They show a pending spinner (`TomValidationPending`) during execution
///
/// Fast validators run immediately after the standard debounce and
/// do NOT transition through `TomValidationPending`.
///
/// Usage:
/// ```dart
/// TomFormStringInput('email', '',
///   validators: [
///     TomValidators.required(),        // fast — no spinner
///     TomValidators.email(),           // fast — no spinner
///     TomSlowValidator(checkEmailAvailable), // slow — spinner shown
///   ],
/// )
/// ```
class TomSlowValidator<T> {
  final TomValidator<T> validate;
  const TomSlowValidator(this.validate);
}

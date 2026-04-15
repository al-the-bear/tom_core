import 'validation_result.dart';

/// Built-in validators for common field validation scenarios.
///
/// Each method returns a [Validator<T>] that can be added to a field's
/// validator list. Error keys follow the `error.*` convention and are
/// resolved relative to the field's basePath.
class Validators {
  Validators._();

  /// Singleton required validator (for identity-based detection).
  /// Accepts [dynamic] so it can be stored in validators lists of any field
  /// type. Dart's contravariance allows `Validator<dynamic>` to also serve
  /// as `Validator<String>`.
  static ValidationResult _requiredValidator(dynamic value) =>
      (value is String && value.isEmpty) || value == null
          ? const ValidationError('error.required')
          : const ValidationSuccess();

  /// The required validator instance (for identity comparison by
  /// [TomFieldDecorationMixinLegacy.hasRequiredValidator]).
  static final Validator<dynamic> requiredInstance = _requiredValidator;

  /// Validates that a string is not empty.
  static Validator<String> required() => requiredInstance;

  /// Validates that a string matches the given email pattern.
  static Validator<String> email() => pattern(
        RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$'),
        errorKey: 'error.email',
      );

  /// Validates that a string has at least [min] characters.
  static Validator<String> minLength(int min) => (String value) =>
      value.length < min
          ? ValidationError('error.minLength', params: {'min': min})
          : const ValidationSuccess();

  /// Validates that a string has at most [max] characters.
  static Validator<String> maxLength(int max) => (String value) =>
      value.length > max
          ? ValidationError('error.maxLength', params: {'max': max})
          : const ValidationSuccess();

  /// Validates that a string matches the given [regex].
  static Validator<String> pattern(
    RegExp regex, {
    String errorKey = 'error.format',
  }) =>
      (String value) => !regex.hasMatch(value)
          ? ValidationError(errorKey)
          : const ValidationSuccess();

  /// Validates that a numeric value is at least [minValue].
  static Validator<num> min(num minValue) => (num value) =>
      value < minValue
          ? ValidationError('error.min', params: {'min': minValue})
          : const ValidationSuccess();

  /// Validates that a numeric value is at most [maxValue].
  static Validator<num> max(num maxValue) => (num value) =>
      value > maxValue
          ? ValidationError('error.max', params: {'max': maxValue})
          : const ValidationSuccess();

  /// Composes multiple validators into one.
  ///
  /// Runs validators sequentially, stopping on the first non-success result.
  static Validator<T> compose<T>(List<Validator<T>> validators) =>
      (T value) async {
        for (final validator in validators) {
          final result = await validator(value);
          if (result is! ValidationSuccess) return result;
        }
        return const ValidationSuccess();
      };
}

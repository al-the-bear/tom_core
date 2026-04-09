import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/src/forms/validation/validation_result.dart';

void main() {
  group('ValidationResult sealed class', () {
    group('ValidationSuccess', () {
      test('is a ValidationResult', () {
        const result = ValidationSuccess();
        expect(result, isA<ValidationResult>());
      });

      test('two instances are equal', () {
        expect(const ValidationSuccess(), equals(const ValidationSuccess()));
      });

      test('has consistent hashCode', () {
        expect(
          const ValidationSuccess().hashCode,
          equals(const ValidationSuccess().hashCode),
        );
      });

      test('toString returns readable representation', () {
        expect(const ValidationSuccess().toString(), 'ValidationSuccess()');
      });
    });

    group('ValidationError', () {
      test('is a ValidationResult', () {
        const result = ValidationError('error.required');
        expect(result, isA<ValidationResult>());
      });

      test('stores errorKey', () {
        const result = ValidationError('error.required');
        expect(result.errorKey, 'error.required');
      });

      test('stores params', () {
        const result = ValidationError(
          'error.minLength',
          params: {'min': 5},
        );
        expect(result.params, {'min': 5});
      });

      test('params defaults to null', () {
        const result = ValidationError('error.required');
        expect(result.params, isNull);
      });

      test('two errors with same errorKey are equal', () {
        expect(
          const ValidationError('error.required'),
          equals(const ValidationError('error.required')),
        );
      });

      test('two errors with different errorKeys are not equal', () {
        expect(
          const ValidationError('error.required'),
          isNot(equals(const ValidationError('error.email'))),
        );
      });

      test('toString without params', () {
        expect(
          const ValidationError('error.required').toString(),
          'ValidationError(error.required)',
        );
      });

      test('toString with params', () {
        expect(
          const ValidationError('error.min', params: {'min': 5}).toString(),
          'ValidationError(error.min, params: {min: 5})',
        );
      });
    });

    group('ValidationPending', () {
      test('is a ValidationResult', () {
        const result = ValidationPending();
        expect(result, isA<ValidationResult>());
      });

      test('two instances are equal', () {
        expect(const ValidationPending(), equals(const ValidationPending()));
      });

      test('toString returns readable representation', () {
        expect(const ValidationPending().toString(), 'ValidationPending()');
      });
    });

    group('pattern matching', () {
      test('can switch on all variants', () {
        ValidationResult result = const ValidationSuccess();

        final description = switch (result) {
          ValidationSuccess() => 'success',
          ValidationError(errorKey: final key) => 'error: $key',
          ValidationPending() => 'pending',
        };

        expect(description, 'success');
      });

      test('matches ValidationError with destructuring', () {
        const ValidationResult result = ValidationError(
          'error.min',
          params: {'min': 10},
        );

        final message = switch (result) {
          ValidationSuccess() => 'ok',
          ValidationError(errorKey: final key, params: final p) =>
            '$key (${p?['min']})',
          ValidationPending() => 'pending',
        };

        expect(message, 'error.min (10)');
      });
    });

    group('type relationships', () {
      test('ValidationSuccess is not ValidationError', () {
        expect(const ValidationSuccess(), isNot(isA<ValidationError>()));
      });

      test('ValidationError is not ValidationPending', () {
        expect(
          const ValidationError('e'),
          isNot(isA<ValidationPending>()),
        );
      });

      test('ValidationPending is not ValidationSuccess', () {
        expect(const ValidationPending(), isNot(isA<ValidationSuccess>()));
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  group('TomValidationResult sealed class', () {
    group('TomValidationSuccess', () {
      test('is a TomValidationResult', () {
        const result = TomValidationSuccess();
        expect(result, isA<TomValidationResult>());
      });

      test('two instances are equal', () {
        expect(
          const TomValidationSuccess(),
          equals(const TomValidationSuccess()),
        );
      });

      test('has consistent hashCode', () {
        expect(
          const TomValidationSuccess().hashCode,
          equals(const TomValidationSuccess().hashCode),
        );
      });

      test('toString returns readable representation', () {
        expect(
          const TomValidationSuccess().toString(),
          'TomValidationSuccess()',
        );
      });
    });

    group('TomValidationError', () {
      test('is a TomValidationResult', () {
        const result = TomValidationError('error.required');
        expect(result, isA<TomValidationResult>());
      });

      test('stores errorKey', () {
        const result = TomValidationError('error.required');
        expect(result.errorKey, 'error.required');
      });

      test('stores params', () {
        const result = TomValidationError(
          'error.minLength',
          params: {'min': 5},
        );
        expect(result.params, {'min': 5});
      });

      test('params defaults to null', () {
        const result = TomValidationError('error.required');
        expect(result.params, isNull);
      });

      test('two errors with same errorKey are equal', () {
        expect(
          const TomValidationError('error.required'),
          equals(const TomValidationError('error.required')),
        );
      });

      test('two errors with different errorKeys are not equal', () {
        expect(
          const TomValidationError('error.required'),
          isNot(equals(const TomValidationError('error.email'))),
        );
      });

      test('toString without params', () {
        expect(
          const TomValidationError('error.required').toString(),
          'TomValidationError(error.required)',
        );
      });

      test('toString with params', () {
        expect(
          const TomValidationError('error.min', params: {'min': 5}).toString(),
          'TomValidationError(error.min, params: {min: 5})',
        );
      });
    });

    group('TomValidationPending', () {
      test('is a TomValidationResult', () {
        const result = TomValidationPending();
        expect(result, isA<TomValidationResult>());
      });

      test('two instances are equal', () {
        expect(
          const TomValidationPending(),
          equals(const TomValidationPending()),
        );
      });

      test('toString returns readable representation', () {
        expect(
          const TomValidationPending().toString(),
          'TomValidationPending()',
        );
      });
    });

    group('pattern matching', () {
      test('can switch on all variants', () {
        TomValidationResult result = const TomValidationSuccess();

        final description = switch (result) {
          TomValidationPristine() => 'pristine',
          TomValidationSuccess() => 'success',
          TomValidationError(errorKey: final key) => 'error: $key',
          TomValidationPending() => 'pending',
        };

        expect(description, 'success');
      });

      test('matches TomValidationError with destructuring', () {
        const TomValidationResult result = TomValidationError(
          'error.min',
          params: {'min': 10},
        );

        final message = switch (result) {
          TomValidationPristine() => 'pristine',
          TomValidationSuccess() => 'ok',
          TomValidationError(errorKey: final key, params: final p) =>
            '$key (${p?['min']})',
          TomValidationPending() => 'pending',
        };

        expect(message, 'error.min (10)');
      });
    });

    group('type relationships', () {
      test('TomValidationSuccess is not TomValidationError', () {
        expect(const TomValidationSuccess(), isNot(isA<TomValidationError>()));
      });

      test('TomValidationError is not TomValidationPending', () {
        expect(
          const TomValidationError('e'),
          isNot(isA<TomValidationPending>()),
        );
      });

      test('TomValidationPending is not TomValidationSuccess', () {
        expect(
          const TomValidationPending(),
          isNot(isA<TomValidationSuccess>()),
        );
      });
    });
  });
}

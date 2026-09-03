import 'package:flutter_test/flutter_test.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart';

void main() {
  group('Validators', () {
    group('required()', () {
      final validator = Validators.required();

      test('returns error for empty string', () async {
        final result = await validator('');
        expect(result, isA<ValidationError>());
        expect((result as ValidationError).errorKey, 'error.required');
      });

      test('returns success for non-empty string', () async {
        final result = await validator('hello');
        expect(result, isA<ValidationSuccess>());
      });
    });

    group('email()', () {
      final validator = Validators.email();

      test('returns success for valid email', () async {
        final result = await validator('user@example.com');
        expect(result, isA<ValidationSuccess>());
      });

      test('returns error for invalid email', () async {
        final result = await validator('not-an-email');
        expect(result, isA<ValidationError>());
        expect((result as ValidationError).errorKey, 'error.email');
      });

      test('returns error for empty string', () async {
        final result = await validator('');
        expect(result, isA<ValidationError>());
      });

      // The TLD must not be capped at 4 characters. Modern TLDs such as
      // `.travel`, `.museum`, `.online`, `.technology` are valid and must pass.
      test('returns success for long (>4 char) TLDs', () async {
        for (final email in const [
          'user@example.travel',
          'user@example.museum',
          'user@example.online',
          'user@example.technology',
        ]) {
          final result = await validator(email);
          expect(
            result,
            isA<ValidationSuccess>(),
            reason: '$email should be a valid email (TLD > 4 chars)',
          );
        }
      });
    });

    group('minLength()', () {
      final validator = Validators.minLength(3);

      test('returns success when length meets minimum', () async {
        final result = await validator('abc');
        expect(result, isA<ValidationSuccess>());
      });

      test('returns success when length exceeds minimum', () async {
        final result = await validator('abcdef');
        expect(result, isA<ValidationSuccess>());
      });

      test('returns error when length is below minimum', () async {
        final result = await validator('ab');
        expect(result, isA<ValidationError>());
        final error = result as ValidationError;
        expect(error.errorKey, 'error.minLength');
        expect(error.params, {'min': 3});
      });

      test('returns error for empty string', () async {
        final result = await validator('');
        expect(result, isA<ValidationError>());
      });
    });

    group('maxLength()', () {
      final validator = Validators.maxLength(5);

      test('returns success when length is within maximum', () async {
        final result = await validator('abc');
        expect(result, isA<ValidationSuccess>());
      });

      test('returns success when length equals maximum', () async {
        final result = await validator('abcde');
        expect(result, isA<ValidationSuccess>());
      });

      test('returns error when length exceeds maximum', () async {
        final result = await validator('abcdef');
        expect(result, isA<ValidationError>());
        final error = result as ValidationError;
        expect(error.errorKey, 'error.maxLength');
        expect(error.params, {'max': 5});
      });
    });

    group('pattern()', () {
      final validator = Validators.pattern(RegExp(r'^\d+$'));

      test('returns success when string matches pattern', () async {
        final result = await validator('12345');
        expect(result, isA<ValidationSuccess>());
      });

      test('returns error when string does not match', () async {
        final result = await validator('abc');
        expect(result, isA<ValidationError>());
        expect((result as ValidationError).errorKey, 'error.format');
      });

      test('uses custom errorKey', () async {
        final customValidator = Validators.pattern(
          RegExp(r'^\d+$'),
          errorKey: 'error.numbersOnly',
        );
        final result = await customValidator('abc');
        expect(result, isA<ValidationError>());
        expect((result as ValidationError).errorKey, 'error.numbersOnly');
      });
    });

    group('min()', () {
      final validator = Validators.min(10);

      test('returns success when value meets minimum', () async {
        final result = await validator(10);
        expect(result, isA<ValidationSuccess>());
      });

      test('returns success when value exceeds minimum', () async {
        final result = await validator(15);
        expect(result, isA<ValidationSuccess>());
      });

      test('returns error when value is below minimum', () async {
        final result = await validator(5);
        expect(result, isA<ValidationError>());
        final error = result as ValidationError;
        expect(error.errorKey, 'error.min');
        expect(error.params, {'min': 10});
      });

      test('works with double values', () async {
        final result = await validator(9.99);
        expect(result, isA<ValidationError>());
      });
    });

    group('max()', () {
      final validator = Validators.max(100);

      test('returns success when value is within maximum', () async {
        final result = await validator(50);
        expect(result, isA<ValidationSuccess>());
      });

      test('returns success when value equals maximum', () async {
        final result = await validator(100);
        expect(result, isA<ValidationSuccess>());
      });

      test('returns error when value exceeds maximum', () async {
        final result = await validator(101);
        expect(result, isA<ValidationError>());
        final error = result as ValidationError;
        expect(error.errorKey, 'error.max');
        expect(error.params, {'max': 100});
      });
    });

    // -----------------------------------------------------------------
    // Selection bounds for a multi-select field. A field description that
    // states a minimum or maximum number of selections desugars to these two
    // rules, exactly as a numeric field's minimum desugars to min().
    // -----------------------------------------------------------------

    group('minItems()', () {
      final validator = Validators.minItems(2);

      test('returns success when the selection meets the minimum', () async {
        expect(await validator(['a', 'b']), isA<ValidationSuccess>());
        expect(await validator(['a', 'b', 'c']), isA<ValidationSuccess>());
      });

      test('returns error when too few items are selected', () async {
        final result = await validator(['a']);
        expect(result, isA<ValidationError>());
        final error = result as ValidationError;
        expect(error.errorKey, 'error.minItems');
        expect(error.params, {'min': 2});
      });

      test('returns error for an empty selection', () async {
        expect(await validator(const <String>[]), isA<ValidationError>());
      });

      test('minItems(0) accepts an empty selection', () async {
        expect(
          await Validators.minItems(0)(const <String>[]),
          isA<ValidationSuccess>(),
        );
      });

      test('is assignable to a typed list field validator', () async {
        // Function contravariance: a Validator<Iterable<Object?>> stands in
        // wherever a Validator<List<String>> is expected, which is what lets
        // a list field declare it directly.
        final Validator<List<String>> typed = Validators.minItems(2);
        expect(await typed(['only-one']), isA<ValidationError>());
        expect(await typed(['a', 'b']), isA<ValidationSuccess>());

        final Validator<List<int>> typedInts = Validators.minItems(2);
        expect(await typedInts([1]), isA<ValidationError>());
      });
    });

    group('maxItems()', () {
      final validator = Validators.maxItems(2);

      test('returns success when the selection is within the maximum',
          () async {
        expect(await validator(const <String>[]), isA<ValidationSuccess>());
        expect(await validator(['a']), isA<ValidationSuccess>());
        expect(await validator(['a', 'b']), isA<ValidationSuccess>());
      });

      test('returns error when too many items are selected', () async {
        final result = await validator(['a', 'b', 'c']);
        expect(result, isA<ValidationError>());
        final error = result as ValidationError;
        expect(error.errorKey, 'error.maxItems');
        expect(error.params, {'max': 2});
      });
    });

    group('minItems() + maxItems() together', () {
      test('compose into a closed selection range', () async {
        final validator = Validators.compose<List<String>>([
          Validators.minItems(2),
          Validators.maxItems(3),
        ]);

        expect(await validator(['a']), isA<ValidationError>());
        expect(await validator(['a', 'b']), isA<ValidationSuccess>());
        expect(await validator(['a', 'b', 'c']), isA<ValidationSuccess>());
        expect(await validator(['a', 'b', 'c', 'd']), isA<ValidationError>());
      });
    });

    group('compose()', () {
      test('returns success when all validators pass', () async {
        final validator = Validators.compose<String>([
          Validators.required(),
          Validators.minLength(3),
          Validators.maxLength(10),
        ]);

        final result = await validator('hello');
        expect(result, isA<ValidationSuccess>());
      });

      test('stops on first error', () async {
        final validator = Validators.compose<String>([
          Validators.required(),
          Validators.minLength(10),
          Validators.maxLength(5),
        ]);

        final result = await validator('abc');
        expect(result, isA<ValidationError>());
        expect(
          (result as ValidationError).errorKey,
          'error.minLength',
        );
      });

      test('returns success for empty validator list', () async {
        final validator = Validators.compose<String>([]);
        final result = await validator('anything');
        expect(result, isA<ValidationSuccess>());
      });

      test('handles async validators', () async {
        Future<ValidationResult> asyncValidator(String value) async {
          // Simulate async work
          await Future.delayed(Duration.zero);
          return value.contains('@')
              ? const ValidationSuccess()
              : const ValidationError('error.needsAt');
        }

        final validator = Validators.compose<String>([
          Validators.required(),
          asyncValidator,
        ]);

        final successResult = await validator('test@example');
        expect(successResult, isA<ValidationSuccess>());

        final errorResult = await validator('noatsign');
        expect(errorResult, isA<ValidationError>());
        expect(
          (errorResult as ValidationError).errorKey,
          'error.needsAt',
        );
      });

      // The short-circuit is on "not success", which is wider than "error" —
      // and wider than a field's own validator loop, which walks past
      // anything that is not a ValidationError.
      test('stops on any non-success result, not only on an error', () async {
        var afterPendingRan = false;
        final validator = Validators.compose<String>([
          (value) => const ValidationPending(),
          (value) {
            afterPendingRan = true;
            return const ValidationSuccess();
          },
        ]);

        expect(await validator('anything'), isA<ValidationPending>());
        expect(afterPendingRan, isFalse);
      });

      // A composite is built from an async closure, so it reports as a Future
      // whatever it holds. That is why it never satisfies a caller who needs a
      // synchronously readable result.
      test('is asynchronous even when every member rule is sync', () {
        final validator = Validators.compose<String>([Validators.required()]);
        expect(validator('ok'), isA<Future<ValidationResult>>());
      });
    });
  });
}

import 'dart:convert';

import 'package:test/test.dart';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A minimal DTO used to prove the envelope expands a [TomJsonSerializable]
/// success value via its own `toJson`.
class _UserView implements TomJsonSerializable {
  final String id;
  final String name;
  const _UserView(this.id, this.name);

  @override
  Map<String, Object?> toJson() => {'id': id, 'name': name};
}

void main() {
  group('TomResult (CE-ER §7 envelope)', () {
    group('success arm', () {
      test('carries a value and reports isSuccess', () {
        const result = TomResult<int>.success(42);

        expect(result.isSuccess, isTrue);
        expect(result.isError, isFalse);
        expect(result.value, equals(42));
        expect(result.error, isNull);
      });

      test('allows a null payload (operations returning nothing)', () {
        const result = TomResult<Object?>.success();

        expect(result.isSuccess, isTrue);
        expect(result.value, isNull);
      });

      test('toJson carries the success discriminator and raw value', () {
        const result = TomResult<int>.success(42);

        expect(result.toJson(), equals({'success': true, 'value': 42}));
      });

      test('toJson expands a TomJsonSerializable value via its toJson', () {
        const result = TomResult<_UserView>.success(_UserView('u1', 'Ada'));

        expect(
          result.toJson(),
          equals({
            'success': true,
            'value': {'id': 'u1', 'name': 'Ada'},
          }),
        );
      });

      test('is jsonEncode-able end to end', () {
        const result = TomResult<_UserView>.success(_UserView('u1', 'Ada'));

        final decoded = jsonDecode(jsonEncode(result)) as Map<String, Object?>;
        expect(decoded['success'], isTrue);
        expect((decoded['value'] as Map)['name'], equals('Ada'));
      });
    });

    group('error arm', () {
      test('carries a structured error and reports isError', () {
        const result = TomResult<int>.failure(
          TomErrorResult('USER_NOT_FOUND', message: 'No such user'),
        );

        expect(result.isError, isTrue);
        expect(result.isSuccess, isFalse);
        expect(result.value, isNull);
        expect(result.error!.code, equals('USER_NOT_FOUND'));
      });

      test('toJson carries the failure discriminator and error map', () {
        const result = TomResult<int>.failure(
          TomErrorResult(
            'VALIDATION_FAILED',
            message: 'Check your input',
            retryable: false,
            severity: TomErrorSeverity.warning,
            fieldErrors: [
              TomFieldError('email', 'INVALID_FORMAT', message: 'bad email'),
            ],
          ),
        );

        expect(
          result.toJson(),
          equals({
            'success': false,
            'error': {
              'code': 'VALIDATION_FAILED',
              'message': 'Check your input',
              'fieldErrors': [
                {
                  'field': 'email',
                  'code': 'INVALID_FORMAT',
                  'message': 'bad email',
                },
              ],
              'retryable': false,
              'severity': 'warning',
            },
          }),
        );
      });

      test('defaults: not retryable, error severity, no field errors', () {
        const err = TomErrorResult('BOOM');

        expect(err.retryable, isFalse);
        expect(err.severity, equals(TomErrorSeverity.error));
        expect(err.fieldErrors, isEmpty);
        // fieldErrors omitted from the wire form when empty.
        expect(err.toJson().containsKey('fieldErrors'), isFalse);
      });
    });

    group('round-trip via fromJson', () {
      test('success value survives as the raw decoded payload', () {
        const result = TomResult<_UserView>.success(_UserView('u1', 'Ada'));
        final wire = jsonDecode(jsonEncode(result)) as Map<String, Object?>;

        final back = TomResult<Map<String, Object?>>.fromJson(wire);
        expect(back.isSuccess, isTrue);
        expect(back.value, equals({'id': 'u1', 'name': 'Ada'}));
      });

      test('error arm fully reconstructs', () {
        const result = TomResult<int>.failure(
          TomErrorResult(
            'VALIDATION_FAILED',
            message: 'Check your input',
            retryable: true,
            severity: TomErrorSeverity.fatal,
            fieldErrors: [TomFieldError('email', 'INVALID_FORMAT')],
          ),
        );
        final wire = jsonDecode(jsonEncode(result)) as Map<String, Object?>;

        final back = TomResult<int>.fromJson(wire);
        expect(back.isError, isTrue);
        final err = back.error!;
        expect(err.code, equals('VALIDATION_FAILED'));
        expect(err.message, equals('Check your input'));
        expect(err.retryable, isTrue);
        expect(err.severity, equals(TomErrorSeverity.fatal));
        expect(err.fieldErrors.single.field, equals('email'));
        expect(err.fieldErrors.single.code, equals('INVALID_FORMAT'));
      });

      test('missing success key is inferred from absence of error', () {
        final back =
            TomResult<int>.fromJson(const {'value': 7});
        expect(back.isSuccess, isTrue);
        expect(back.value, equals(7));
      });
    });

    group('TomErrorSeverity.fromWire', () {
      test('parses known tokens', () {
        expect(TomErrorSeverity.fromWire('info'), TomErrorSeverity.info);
        expect(TomErrorSeverity.fromWire('warning'), TomErrorSeverity.warning);
        expect(TomErrorSeverity.fromWire('fatal'), TomErrorSeverity.fatal);
      });

      test('falls back to error for null/unknown (forward-compat)', () {
        expect(TomErrorSeverity.fromWire(null), TomErrorSeverity.error);
        expect(TomErrorSeverity.fromWire('nope'), TomErrorSeverity.error);
        expect(TomErrorSeverity.fromWire(123), TomErrorSeverity.error);
      });
    });
  });
}

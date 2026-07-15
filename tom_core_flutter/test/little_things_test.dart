import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

/// Tests for the little_things module (`TomClientException`,
/// `TomClientUIException`).
void main() {
  group('TomClientException', () {
    test('carries the key, message and parameters', () {
      final ex = TomClientException(
        'client.error',
        'Something went wrong',
        parameters: {'field': 'email'},
      );
      expect(ex.key, 'client.error');
      expect(ex.defaultUserMessage, 'Something went wrong');
      expect(ex.parameters, {'field': 'email'});
    });

    test('is a kernel TomException', () {
      final ex = TomClientException('client.error', 'msg');
      expect(ex, isA<TomException>());
    });

    test('is not a TomClientUIException', () {
      final ex = TomClientException('client.error', 'msg');
      expect(ex, isNot(isA<TomClientUIException>()));
    });

    // Full-surface: the constructor forwards every optional argument to the
    // kernel TomException. `parameters`/`rootException` are covered above; these
    // pin the remaining two — `stack` (the raw trace object) and `autoLog`.
    test('forwards the stack trace object to the kernel exception', () {
      final trace = StackTrace.current;
      final ex = TomClientException('client.error', 'msg', stack: trace);
      expect(identical(ex.stack, trace), isTrue);
      // The formatted representation is derived from the forwarded trace.
      expect(ex.stackTrace, isNotEmpty);
    });

    test('forwards the autoLog flag (default false, honours true)', () {
      expect(TomClientException('client.error', 'msg').autoLog, isFalse);
      expect(
        TomClientException('client.error', 'msg', autoLog: true).autoLog,
        isTrue,
      );
    });
  });

  group('TomClientUIException', () {
    test('is both a TomClientException and a TomException', () {
      final ex = TomClientUIException('ui.error', 'Please try again');
      expect(ex, isA<TomClientException>());
      expect(ex, isA<TomException>());
      expect(ex.key, 'ui.error');
      expect(ex.defaultUserMessage, 'Please try again');
    });

    test('forwards stack, parameters and autoLog through both super calls', () {
      final trace = StackTrace.current;
      final ex = TomClientUIException(
        'ui.error',
        'Please try again',
        parameters: {'retryable': true},
        stack: trace,
        autoLog: true,
      );
      expect(ex.parameters, {'retryable': true});
      expect(identical(ex.stack, trace), isTrue);
      expect(ex.autoLog, isTrue);
    });

    test('type discriminates user-facing from internal client errors', () {
      // A presentable error rethrows; a non-presentable one is wrapped.
      TomException surface(TomException e) {
        if (e is TomClientUIException) return e;
        return TomClientUIException('wrapped', 'Unexpected error', rootException: e);
      }

      final presentable = TomClientUIException('ui.error', 'Shown to user');
      final internal = TomClientException('internal', 'Do not show');

      expect(identical(surface(presentable), presentable), isTrue);
      final wrapped = surface(internal);
      expect(wrapped, isA<TomClientUIException>());
      expect(wrapped.rootException, internal);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

/// Tests for the security module (`TomClient2FAAdaptor`).
///
/// The annotation is a simple `const` value object; the tests confirm it
/// carries its `type` and is usable as a compile-time constant (as required to
/// annotate a class).
@TomClient2FAAdaptor('totp')
class _AnnotatedAdaptor {}

void main() {
  group('TomClient2FAAdaptor', () {
    test('exposes the type it was constructed with', () {
      const adaptor = TomClient2FAAdaptor('sms');
      expect(adaptor.type, 'sms');
    });

    test('is a compile-time constant (canonicalized)', () {
      const a = TomClient2FAAdaptor('totp');
      const b = TomClient2FAAdaptor('totp');
      expect(identical(a, b), isTrue);
    });

    test('can be applied as a class annotation', () {
      // _AnnotatedAdaptor is annotated with @TomClient2FAAdaptor('totp') above;
      // its mere existence proves the annotation compiles and applies.
      expect(_AnnotatedAdaptor(), isA<_AnnotatedAdaptor>());
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import 'security_test.reflection.dart';

/// Tests for the security module (`TomClient2FAAdaptor`).
///
/// The annotation is a simple `const` value object; the tests confirm it
/// carries its `type`, is usable as a compile-time constant (as required to
/// annotate a class), and — the central documented capability — is
/// reflection-discoverable on an annotated class via the `@tomReflector`
/// registration.
///
/// `AnnotatedAdaptor` is also annotated `@tomReflector` so the generator emits
/// a mirror for it; its `metadata` then carries the `TomClient2FAAdaptor('totp')`
/// instance, which a runtime enumerates to dispatch by `type`.
@tomReflector
@TomClient2FAAdaptor('totp')
class AnnotatedAdaptor {}

void main() {
  setUpAll(initializeReflection);

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
      // AnnotatedAdaptor is annotated with @TomClient2FAAdaptor('totp') above;
      // its mere existence proves the annotation compiles and applies.
      expect(AnnotatedAdaptor(), isA<AnnotatedAdaptor>());
    });

    test('is reflection-discoverable on an annotated class', () {
      // The documented capability: a runtime enumerates 2FA adaptors by reading
      // the @TomClient2FAAdaptor metadata off annotated classes. A regression in
      // the @tomReflector registration would make this metadata vanish.
      final mirror =
          tomReflector.reflectType(AnnotatedAdaptor) as ClassMirror;
      final adaptors = mirror.metadata.whereType<TomClient2FAAdaptor>();
      expect(adaptors, isNotEmpty);
      expect(adaptors.first.type, 'totp');
    });
  });
}

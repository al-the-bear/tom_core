import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_flutter/tom_core_flutter.dart';

import '../example/security/security_example.dart' as example;
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
      final mirror = tomReflector.reflectType(AnnotatedAdaptor) as ClassMirror;
      final adaptors = mirror.metadata.whereType<TomClient2FAAdaptor>();
      expect(adaptors, isNotEmpty);
      expect(adaptors.first.type, 'totp');
    });
  });

  group('the shipped example runs', () {
    test('security_example.run() completes its assertions', () async {
      // The example is quoted as documentation, so it has to be executable
      // documentation. Running it here is what stops a snippet that no longer
      // compiles — or an assert that no longer holds — from being shown to a
      // reader as the way to use the module. It is also what makes the command
      // the example's header names a real one: that command is this suite.
      //
      // Awaited rather than fired and forgotten: the example walks a
      // controller through the flow, and every move it makes is a `Future`.
      // Dropping the await would let this test pass before a single assertion
      // downstream of the first move had been evaluated.
      await example.run();
    });
  });
}

/// Executable example for the security module of `tom_core_flutter`.
///
/// Demonstrates the `TomClient2FAAdaptor` marker annotation: applying it to a
/// client adaptor class and reading back its `type`.
///
/// The barrel import pulls in `flutter/material` (and thus `dart:ui`), so this
/// runs under the Flutter toolchain, not bare `dart run`. Run it with
/// `flutter test test/security_test.dart`: that suite calls [run], so the
/// command executes everything below and its exit code says whether the
/// assertions held. Pointing `flutter test` at *this* file also runs it, but
/// then exits 79 ("No tests were found") whether it succeeded or not — an
/// example declares no `test()` of its own.
library;

import 'package:tom_core_flutter/tom_core_flutter.dart';

// A client 2FA adaptor tagged with its mechanism. A runtime can discover this
// class by reflection and route TOTP authentication to it.
@TomClient2FAAdaptor('totp')
class TotpAdaptor {}

void run() {
  // Example 1: the annotation is a const value object carrying its type.
  const totp = TomClient2FAAdaptor('totp');
  const sms = TomClient2FAAdaptor('sms');
  print('adaptor types: ${totp.type}, ${sms.type}');

  // Example 2: equal-typed annotations are canonicalized to one instance.
  const totpAgain = TomClient2FAAdaptor('totp');
  print('totp canonicalized: ${identical(totp, totpAgain)}');

  // Example 3: the annotation compiles and applies to a real class.
  print('annotated adaptor: ${TotpAdaptor().runtimeType}');

  // Assertions
  assert(totp.type == 'totp');
  assert(sms.type == 'sms');
  assert(identical(totp, totpAgain));
}

void main() => run();

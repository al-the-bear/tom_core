/// Executable example for the legacy forms module of `tom_core_flutter`.
///
/// Demonstrates building fields and a form, the two validation passes, and
/// reading values back with `save()`. Because it imports `flutter/material`
/// (which pulls in `dart:ui`), run it under the Flutter toolchain, e.g.
/// `flutter test example/forms/forms_example.dart`, not bare `dart run`. The
/// same scenarios are covered by `test/forms_test.dart`.
library;

import 'package:tom_core_flutter/tom_core_flutter.dart';

void run() {
  // Empty resource providers: missing keys resolve to the key itself, so error
  // messages below appear as their resource keys.
  TomTextResourceProvider.setAppResourceProvider(
    TomTextResourceProvider.from({}),
  );
  TomConfigResourceProvider.setAppConfigProvider(
    TomConfigResourceProvider.from({}),
  );

  // Example 1: an email field rejects a malformed address.
  final email = TomEmailField<String>('login', 'email', '');
  email.set('not-an-email');
  final invalidEmailValid = email.validate();
  final invalidEmailError = email.errorText;
  print('invalid email -> valid=$invalidEmailValid error=$invalidEmailError');

  // Example 2: the same field accepts a well-formed address.
  email.set('user@example.com');
  final validEmailValid = email.validate();
  print('valid email   -> valid=$validEmailValid error=${email.errorText}');

  // Example 3: a password field enforces a minimum length.
  final password = TomPasswordField<String>('login', 'password', '');
  password.set('abc');
  final shortPwValid = password.validate();
  final shortPwError = password.errorText;
  print('short password -> valid=$shortPwValid error=$shortPwError');

  // Example 4: a whole form validates and saves its values atomically.
  final form = TomFormOld({
    'email': TomEmailField<String>('login', 'email', 'user@example.com'),
    'password': TomPasswordField<String>('login', 'password', 'secret'),
  });
  final formValid = form.validate();
  final saved = form.save();
  print('form valid=$formValid saved=$saved');

  // Assertions
  assert(invalidEmailValid == false);
  assert(invalidEmailError == 'login.email.errors.validEmail');
  assert(validEmailValid == true);
  assert(email.errorText == null);
  assert(shortPwValid == false);
  assert(shortPwError == 'login.password.errors.minimumLength');
  assert(formValid == true);
  assert(saved['email'] == 'user@example.com');
  assert(saved['password'] == 'secret');
}

void main() => run();

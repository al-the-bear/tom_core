/// Executable example for the authentication module of `tom_core_server`.
///
/// Demonstrates the [TomAuthenticationService] contract end to end without a
/// running HTTP server or database: building [TomAuthenticationData], resolving
/// it through a service into a [TomAuthenticationInfo], rejecting a login with a
/// [LoginException], and reading the adaptor-annotation configuration.
///
/// Run with `dart run example/authentication/authentication_example.dart`.
/// The same behaviour is covered by `test/authentication_test.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// Builds the data for one login attempt with sensible example defaults.
TomAuthenticationData _login(String username, {Object? password}) =>
    TomAuthenticationData(
      username: username,
      key: password,
      organization: 'acme',
      application: 'console',
      process: 'login',
      language: 'en',
      country: 'US',
      timezone: 'UTC',
      client: 'web',
    );

/// A minimal service: one known user, everything else rejected.
class DemoAuthService implements TomAuthenticationService {
  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData authData,
  ) async {
    if (authData.username != 'alice' || authData.key != 's3cret') {
      throw LoginException(
        'error.invalid-user-or-password',
        'Invalid user or password',
        parameters: {'username': authData.username},
      );
    }
    // Reuse the dummy service to assemble a principal for the accepted user.
    final dummy = TomDummyAuthenticationService()..showErrorMessage = false;
    return dummy.authenticateUser(authData);
  }
}

Future<void> run() async {
  // Example 1: the scaffolding service authenticates any non-GUEST user.
  final dummy = TomDummyAuthenticationService()..showErrorMessage = false;
  final guest = await dummy.authenticateUser(_login('GUEST'));
  final user = await dummy.authenticateUser(_login('bob'));
  print('dummy GUEST authenticated: ${guest.principal.authenticated}');
  print('dummy bob authenticated:   ${user.principal.authenticated}');

  // Example 2: a real service accepts the correct credential.
  final service = DemoAuthService();
  final ok = await service.authenticateUser(_login('alice', password: 's3cret'));
  print('alice authenticated as:    ${ok.principal.user.username}');

  // Example 3: a wrong credential is rejected with a LoginException.
  try {
    await service.authenticateUser(_login('alice', password: 'wrong'));
  } on LoginException catch (e) {
    print('rejected with key:         ${e.key}');
  }

  // Example 4: adaptor annotations carry their routing configuration.
  final guestAdaptor = TomAuthenticationAdaptor(guestOnly: true);
  const totp = Tom2FAAdaptor('totp');
  print('guest-only adaptor:        ${guestAdaptor.guestOnly}');
  print('2FA adaptor type:          ${totp.type}');

  // Assertions
  assert(guest.principal.authenticated == false);
  assert(user.principal.authenticated == true);
  assert(ok.principal.user.username == 'alice');
  assert(guestAdaptor.guestOnly && !guestAdaptor.userOnly);
  assert(totp.type == 'totp');
}

void main() => run();

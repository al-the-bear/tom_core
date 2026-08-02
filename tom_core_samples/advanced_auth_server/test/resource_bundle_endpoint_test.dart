/// Tests for the auth server's two resource endpoints (todo 7).
///
/// Per D-A9/D-A10 the auth server serves the **public** login texts
/// (`/auth/resources/login`) and the **admin-gated** console texts
/// (`/admin/resources`). The done-when: the login bundle is reachable
/// unauthenticated and returns the login keys; the admin bundle returns the
/// console keys and is rejected for anyone but an `admin`. The bundles are pure
/// text, so this verifies directly against [AuthResourceBundles] and the
/// contract's access policy, with no server or MariaDB.
library;

import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:test/test.dart';

TomPrincipal _principal({required List<String> roles}) => TomPrincipal(
      authenticated: true,
      aci: TomAccessControlInformation(roles: roles),
    );

void main() {
  group('login resource bundle (public, todo 7)', () {
    test('loginBundle carries the public login + adminLogin texts', () {
      final texts = AuthResourceBundles.loginBundle().texts;
      expect(texts['login.username.label'], 'Username');
      expect(texts['login.username.hint'], 'alice, bob, carol or dave');
      expect(texts['login.password.label'], 'Password');
      expect(texts['adminLogin.username.hint'], 'admin');
      expect(texts['adminLogin.password.label'], 'Password');
    });

    test('loginBundle carries the second-factor texts for both clients', () {
      // The code phase is reached *mid-login*, when the only bundle in hand is
      // this public one — the authenticated bundle needs a session the interim
      // token does not provide. So the second-factor chrome ships here, as a
      // sibling scope of `login`/`adminLogin`, not in the console bundle.
      final texts = AuthResourceBundles.loginBundle().texts;
      expect(texts['twoFactor.code.label'], 'Verification code');
      expect(texts['twoFactor.submit'], 'Verify');
      // The two parameterised texts the screens substitute into (G-RES: the
      // bundle owns the wording, the screen owns the value).
      expect(texts['twoFactor.intro'], contains('{digits}'));
      expect(texts['twoFactor.attemptsRemaining'], contains('{count}'));
      expect(texts['adminTwoFactor.code.label'], 'Verification code');
      expect(texts['adminTwoFactor.intro'], contains('{digits}'));
      expect(texts['adminTwoFactor.attemptsRemaining'], contains('{count}'));
    });

    test('the loginResources handler returns the login bundle', () async {
      final dto = await AdvancedAuthApiService().loginResources();
      // Reflection-first DTOs carry no value `==`; compare the wire payload.
      expect(dto.texts, AuthResourceBundles.loginBundle().texts);
    });

    test('login resources are reachable unauthenticated', () {
      expect(
          authApi.endpoints['authLoginResources']!.access!
              .checkAccessibility(null),
          isTrue);
    });
  });

  group('admin console resource bundle (admin-gated, todo 7)', () {
    test('adminConsoleBundle carries the editor + grants texts', () {
      final texts = AuthResourceBundles.adminConsoleBundle().texts;
      expect(texts['adminConsole.title'], 'Advanced Todo — Admin console');
      expect(texts['user.username.label'], 'Username');
      expect(texts['user.displayName.label'], 'Display name');
      expect(texts['role.key.label'], 'Key');
      expect(texts['group.name.label'], 'Name');
      expect(texts['grants.title'], isNotNull);
    });

    test('the adminResources handler returns the console bundle', () async {
      final dto = await AdvancedAdminApiService().resources();
      // Reflection-first DTOs carry no value `==`; compare the wire payload.
      expect(dto.texts, AuthResourceBundles.adminConsoleBundle().texts);
    });

    test('admin resources require the admin role (reject anon + non-admin)', () {
      final access = adminApi.endpoints['adminResources']!.access!;
      expect(access.checkAccessibility(null), isFalse);
      expect(access.checkAccessibility(_principal(roles: ['editor'])), isFalse);
      expect(access.checkAccessibility(_principal(roles: ['admin'])), isTrue);
    });
  });
}

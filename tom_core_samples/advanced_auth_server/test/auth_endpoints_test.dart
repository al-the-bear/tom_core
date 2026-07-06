/// Unit tests for the auth server's `/auth/*` token logic (step 11).
///
/// The HTTP-routed [AdvancedAuthApiService] is a thin adapter whose production
/// wiring needs a database (the repository-backed store) and a live request zone
/// (the bearer principal), so it is exercised end-to-end at boot (step 13). The
/// behaviour the plan's "Done" bar calls out — login returns a signed token
/// pair, `/auth/me` echoes the principal that token decodes to, and bad
/// credentials are rejected (→ HTTP 401) — is proven here against the pure
/// [AuthTokenService] seeded with the step-10 [InMemoryAuthUserStore] and the
/// [LoginUnauthorizedErrorHandler], with no server.
library;

import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Builds a login request for [username]/[password] (tenant fields fixed; the
/// single-tenant server ignores them for the credential check).
LoginRequest _login(String username, String password) =>
    LoginRequest(username: username, password: password, app: 'todo', org: 'acme');

/// A store seeded with one active user (`ada`, id 1, password `s3cret`, role
/// `editor`, group `Engineering`) plus any [extraUsers].
InMemoryAuthUserStore _storeWith({List<UserRecord> extraUsers = const []}) {
  final ada = applyPassword(
    UserRecord()
      ..id = 1
      ..username = 'ada'
      ..displayName = 'Ada Lovelace'
      ..email = 'ada@example.com'
      ..status = UserStatus.active.name,
    's3cret',
  );
  return InMemoryAuthUserStore(
    users: [ada, ...extraUsers],
    roleKeysByUserId: const {
      1: ['editor'],
    },
    groupNamesByUserId: const {
      1: ['Engineering'],
    },
  );
}

/// A token service over a freshly seeded store, signing with a fixed issuer.
AuthTokenService _service({List<UserRecord> extraUsers = const []}) =>
    AuthTokenService(
      AdvancedAuthenticationService(_storeWith(extraUsers: extraUsers)),
      issuer: 'tom',
    );

void main() {
  group('AuthTokenService.login', () {
    test('accepts the right password and issues the signed token pair',
        () async {
      final result = await _service().login(_login('ada', 's3cret'));

      expect(result.authToken, isNotEmpty);
      expect(result.authzToken, isNotEmpty);
      // The two tokens differ: the authz token carries the encrypted ACI.
      expect(result.authToken, isNot(result.authzToken));
      expect(result.user.username, 'ada');
      expect(result.user.id, '1');
      expect(result.user.email, 'ada@example.com');
      expect(result.user.displayName, 'Ada Lovelace');
      expect(result.user.statusValue, UserStatus.active);
      expect(result.expiresAt.isAfter(DateTime.now().toUtc()), isTrue);
    });

    test('rejects the wrong password with a LoginException', () {
      expect(
        _service().login(_login('ada', 'wrong')),
        throwsA(isA<LoginException>()),
      );
    });

    test('rejects an unknown user with a LoginException', () {
      expect(
        _service().login(_login('nobody', 's3cret')),
        throwsA(isA<LoginException>()),
      );
    });

    test('rejects a suspended account even with the right password', () {
      final suspended = applyPassword(
        UserRecord()
          ..id = 2
          ..username = 'bob'
          ..status = UserStatus.suspended.name,
        'hunter2',
      );
      expect(
        _service(extraUsers: [suspended]).login(_login('bob', 'hunter2')),
        throwsA(isA<LoginException>()),
      );
    });
  });

  group('AuthTokenService — /auth/me echoes the issued principal', () {
    test('the auth token decodes back to the login user (the /auth/me path)',
        () async {
      final service = _service();
      final result = await service.login(_login('ada', 's3cret'));

      // `/auth/me` resolves the principal from the bearer token and projects it
      // with the same `userDtoOf`; replay that exact path over the issued pair.
      TomBearerAuthentication.setTokens(result.authToken, result.authzToken);
      final echoed = service.userDtoOf(TomBearerAuthentication.getPrincipal());

      // Reflection-first DTOs carry no value `==`; compare the projected fields.
      expect(echoed.id, result.user.id);
      expect(echoed.username, result.user.username);
      expect(echoed.displayName, result.user.displayName);
      expect(echoed.email, result.user.email);
      expect(echoed.statusValue, result.user.statusValue);
      expect(echoed.username, 'ada');
      expect(echoed.id, '1');
    });
  });

  group('AuthTokenService.refresh', () {
    test('re-issues a fresh token pair for an authenticated principal',
        () async {
      final service = _service();
      final logged = await service.login(_login('ada', 's3cret'));
      TomBearerAuthentication.setTokens(logged.authToken, logged.authzToken);

      final refreshed = service.refresh(TomBearerAuthentication.getPrincipal());

      expect(refreshed.authToken, isNotEmpty);
      expect(refreshed.authzToken, isNotEmpty);
      expect(refreshed.user.username, 'ada');
    });
  });

  group('LoginUnauthorizedErrorHandler', () {
    final handler = const LoginUnauthorizedErrorHandler();
    final request = Request('POST', Uri.parse('http://localhost/auth/login'));

    test('maps a LoginException to HTTP 401 carrying the stable error key',
        () async {
      final response = handler.handleInvocationError(
        LoginException('error.invalid-user-or-password', 'Invalid user'),
        StackTrace.current,
        request,
      );

      expect(response.statusCode, 401);
      expect(await response.readAsString(),
          contains('error.invalid-user-or-password'));
    });

    test('masks any other error behind the opaque 500', () {
      final response = handler.handleInvocationError(
        StateError('boom'),
        StackTrace.current,
        request,
      );

      expect(response.statusCode, 500);
    });
  });
}

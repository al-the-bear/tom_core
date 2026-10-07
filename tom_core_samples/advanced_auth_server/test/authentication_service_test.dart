/// Unit tests for the auth server's [AdvancedAuthenticationService].
///
/// The DB reads sit behind the [AuthUserStore] seam, so these tests run the real
/// login logic against a seeded [InMemoryAuthUserStore] — no database and no
/// reflection. They assert both directions: the **accept** path
/// returns an authenticated [TomPrincipal] carrying the user's expected roles and
/// groups, and the **reject** paths (wrong password, unknown user, suspended
/// account, credential-less row) each throw a [TomLoginException] rather than
/// returning a principal.
library;

import 'package:advanced_auth_server/advanced_auth_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:test/test.dart';

/// Builds the login data for [username]/[password]; the locale/tenant fields are
/// fixed since the single-tenant service ignores them for the credential check.
TomAuthenticationData _login(String username, String password) =>
    TomAuthenticationData(
      username: username,
      key: password,
      organization: 'acme',
      application: 'todo',
      process: 'default',
      language: 'en',
      country: 'US',
      timezone: 'UTC',
      client: 'web',
    );

/// A store seeded with one active user (`ada`, id 1, password `s3cret`, role
/// `editor`, group `Engineering`) plus the optional [extraUsers] / assignments.
InMemoryAuthUserStore _storeWith({
  List<UserRecord> extraUsers = const [],
  Map<int, List<String>> roleKeysByUserId = const {
    1: ['editor'],
  },
  Map<int, List<String>> groupNamesByUserId = const {
    1: ['Engineering'],
  },
}) {
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
    roleKeysByUserId: roleKeysByUserId,
    groupNamesByUserId: groupNamesByUserId,
  );
}

void main() {
  group('AdvancedAuthenticationService.authenticateUser', () {
    test(
      'accepts the right password and builds the authenticated principal',
      () async {
        final service = AdvancedAuthenticationService(_storeWith());

        final info = await service.authenticateUser(_login('ada', 's3cret'));

        expect(info.principal.authenticated, isTrue);
        expect(info.principal.username, 'ada');
        expect(info.principal.user.id, 1);
        expect(info.principal.user.email, 'ada@example.com');
      },
    );

    test(
      'the principal carries the user\'s expected roles and groups',
      () async {
        final service = AdvancedAuthenticationService(
          _storeWith(
            roleKeysByUserId: const {
              1: ['editor', 'viewer'],
            },
            groupNamesByUserId: const {
              1: ['Engineering'],
            },
          ),
        );

        final info = await service.authenticateUser(_login('ada', 's3cret'));

        expect(info.principal.aci.roles, containsAll(['editor', 'viewer']));
        expect(info.principal.aci.groups, contains('Engineering'));
        // The access-control definition mirrors the assigned roles/groups.
        expect(info.acd.toString(), contains('2 roles'));
      },
    );

    test(
      'the login does not fold effective per-resource roles into the token',
      () async {
        // The bearer token is opaque and never read for enforcement; the app
        // server re-resolves grants/shares live from auth_db and the client reads
        // its roles from /resource-roles. So the login leaves aci.resourceRoles
        // empty rather than baking a claim that could only go stale.
        final service = AdvancedAuthenticationService(_storeWith());

        final info = await service.authenticateUser(_login('ada', 's3cret'));

        expect(info.principal.aci.resourceRoles, isEmpty);
      },
    );

    test('rejects the wrong password with a TomLoginException', () async {
      final service = AdvancedAuthenticationService(_storeWith());

      await expectLater(
        service.authenticateUser(_login('ada', 'wrong')),
        throwsA(isA<TomLoginException>()),
      );
    });

    test('rejects an unknown user with a TomLoginException', () async {
      final service = AdvancedAuthenticationService(_storeWith());

      await expectLater(
        service.authenticateUser(_login('nobody', 's3cret')),
        throwsA(isA<TomLoginException>()),
      );
    });

    test('rejects a suspended account even with the right password', () async {
      final suspended = applyPassword(
        UserRecord()
          ..id = 2
          ..username = 'bob'
          ..status = UserStatus.suspended.name,
        'hunter2',
      );
      final service = AdvancedAuthenticationService(
        _storeWith(extraUsers: [suspended]),
      );

      await expectLater(
        service.authenticateUser(_login('bob', 'hunter2')),
        throwsA(
          isA<TomLoginException>().having(
            (e) => e.key,
            'key',
            'error.user.suspended',
          ),
        ),
      );
    });

    test(
      'rejects a credential-less row (freshly seeded, no password)',
      () async {
        // The migrations leave password_hash NULL until a password is set.
        final seeded = UserRecord()
          ..id = 3
          ..username = 'carol'
          ..status = UserStatus.active.name;
        final service = AdvancedAuthenticationService(
          _storeWith(extraUsers: [seeded]),
        );

        await expectLater(
          service.authenticateUser(_login('carol', 'anything')),
          throwsA(isA<TomLoginException>()),
        );
      },
    );

    test(
      'unknown user and wrong password share the same generic key',
      () async {
        final service = AdvancedAuthenticationService(_storeWith());

        Future<String> keyFor(String user, String password) async {
          try {
            await service.authenticateUser(_login(user, password));
            fail('expected a TomLoginException');
          } on TomLoginException catch (e) {
            return e.key;
          }
        }

        expect(
          await keyFor('nobody', 's3cret'),
          await keyFor('ada', 'definitely-wrong'),
        );
      },
    );
  });

  group('the principal\'s two locale pairs', () {
    // `language`/`country` are the account's stored preference and
    // `clientLanguage`/`clientCountry` what the device sent. The login request
    // supplies only the second; the first comes from `auth_users`. The request
    // in [_login] says en/US throughout, so a value other than that can only
    // have come from the row.
    UserRecord withLocale(String? language, String? country) => applyPassword(
      UserRecord()
        ..id = 2
        ..username = 'grace'
        ..status = UserStatus.active.name
        ..language = language
        ..country = country,
      'pw',
    );

    Future<TomPrincipal> loginAs(UserRecord record) async {
      final service = AdvancedAuthenticationService(
        _storeWith(extraUsers: [record]),
      );
      final info = await service.authenticateUser(_login('grace', 'pw'));
      return info.principal;
    }

    test('the stored pair comes from the account, the client pair from the '
        'request', () async {
      final principal = await loginAs(withLocale('de', 'AT'));

      expect(principal.language, 'de');
      expect(principal.country, 'AT');
      expect(principal.clientLanguage, 'en');
      expect(principal.clientCountry, 'US');
    });

    test('a request-time text renders in the account\'s language, not the '
        'device\'s', () async {
      final principal = await loginAs(withLocale('de', 'AT'));

      expect(TomTextLocale.fromPrincipal(principal)?.tag, 'de_AT');
    });

    test('an account with no preference leaves the stored pair empty, so the '
        'device\'s language answers', () async {
      for (final blank in [null, '', '  ']) {
        final principal = await loginAs(withLocale(blank, 'AT'));

        expect(
          principal.language,
          isNull,
          reason: 'language ${blank == null ? 'null' : "'$blank'"}',
        );
        // A country with no language is no preference either: it would narrow
        // a language the account never named.
        expect(principal.country, isNull);
        expect(principal.clientLanguage, 'en');
        expect(TomTextLocale.fromPrincipal(principal)?.tag, 'en_US');
      }
    });

    test('a stored language without a country carries no country', () async {
      final principal = await loginAs(withLocale('de', null));

      expect(principal.language, 'de');
      expect(principal.country, isNull);
      expect(TomTextLocale.fromPrincipal(principal)?.tag, 'de');
    });
  });
}

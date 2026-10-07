/// Pins for limitations the guides state that no other suite asserts.
///
/// Each guide's `## Not Yet Implemented` section is paired with tests by
/// `api_reference_coverage_test.dart`: a bullet describing behaviour names the
/// test that asserts it, so lifting the limitation turns that test red and the
/// bullet is reconsidered in the same change. Most bullets are pinned by a test
/// in their module's own suite. These are the ones whose limiting behaviour
/// nothing else exercised — each test asserts the limitation as it stands, and
/// says which bullet goes when it fails.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A client token carrying [payload], unsigned: the cache reads `exp` and never
/// inspects the signature, as `authorization_test.dart` explains.
TomClientJwtToken _tokenWithPayload(Map<String, Object?> payload) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return TomClientJwtToken(
    '${segment({'alg': 'HS256', 'typ': 'JWT'})}.${segment(payload)}.signature',
    decrypt: false,
  );
}

void main() {
  group('doc/authorization.md', () {
    tearDown(TomAuthorizationCache.stopEviction);

    test(
      'a token good for less than a second cannot be cached as live',
      () async {
        // `exp` is whole epoch seconds. A token minted to last 300 ms has an
        // `exp` of the current second — the most it can say — so the entry is
        // already expired when it is written. When this passes no longer, the
        // cache has gained sub-second lifetimes and the bullet goes.
        final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final token = _tokenWithPayload({'userId': 'sub-second', 'exp': now});
        await TomAuthorizationCache.storePrincipal(
          token,
          TomPrincipal(
            user: TomUser(username: 'sub-second'),
            authenticated: true,
          ),
        );
        await expectLater(
          () => TomAuthorizationCache.getPrincipal(token),
          throwsA(
            isA<TomAuthorizationCacheException>().having(
              (e) => e.key,
              'key',
              'authorization.cache.expired_principal',
            ),
          ),
        );
      },
    );

    test('the graded model has exactly four states', () {
      expect(TomAuthState.values, [
        TomAuthState.none,
        TomAuthState.disabled,
        TomAuthState.read,
        TomAuthState.full,
      ]);
    });
  });

  group('doc/authentication.md', () {
    tearDown(TomBean.resetBeanContext);

    test('no identity store is installed by default', () {
      TomBean.resetBeanContext();
      expect(TomExternalIdentityStore.resolve(), isNull);
    });
  });

  group('doc/datasources.md', () {
    test('a DATE read back keeps its components and is anchored in UTC', () {
      final date = parseSqlDate('2026-07-05');
      expect((date.year, date.month, date.day), (2026, 7, 5));
      expect(date.timezone.timezone, TomTimezone.utc.timezone);
    });
  });

  group('doc/little_things.md', () {
    test('the error envelope carries no message', () {
      final envelope = tomErrorEnvelope(
        TomServerException('some.key', 'A sentence a user would read'),
      );
      expect(envelope.values, isNot(contains('A sentence a user would read')));
      expect(
        envelope.keys,
        isNot(anyOf(contains('defaultUserMessage'), contains('message'))),
      );
    });
  });

  group('doc/resources.md', () {
    test('substitution interpolates through toString, the same everywhere', () {
      // No locale-aware rendering: a DateTime and a double come out in Dart's
      // own `toString` shape whatever language the template is in.
      final at = DateTime.utc(2026, 7, 5, 14, 30);
      expect(
        TomLocalizedTextResources.substitute('Am {at}: {n}', {
          'at': at,
          'n': 1.5,
        }),
        'Am $at: 1.5',
      );
    });
  });
}

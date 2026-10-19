/// DB-backed tests for the relational pending-authorization store.
///
/// What only a real server can substantiate, and what the whole store exists
/// for: **the two halves of an authorization-code flow are two separate HTTP
/// requests, and the second is a redirect the provider issues** — it lands on
/// whichever node the load balancer picks. So almost every test here uses *two
/// store instances over one table*, never one, because a store that can only
/// complete what it itself began is exactly the store this replaces.
///
/// Two instances are the closest a single process gets to two nodes, and they
/// are close enough for what is being proved: each holds its own `_schemaReady`
/// flag, its own sweep clock and its own configured TTL, and — this is the part
/// that matters — the arbitration under contention is done by the *database*, in
/// one statement, not by anything the two instances share.
///
/// The whole file is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring a
/// server up with `tool/run_db_tests.sh`.
@Tags(['db'])
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

// =============================================================================
// FIXTURES
// =============================================================================

/// A provider that mints an `id_token`, matching `oauth_test.dart`'s stub.
TomOAuthProviderConfig _provider() => TomOAuthProviderConfig(
  id: 'stub',
  issuer: 'https://idp.example.test',
  authorizationEndpoint: 'https://idp.example.test/authorize',
  tokenEndpoint: 'https://idp.example.test/token',
  clientId: 'tom-core-server-test',
  clientSecret: 'sh-sh-secret',
  redirectUri: 'https://app.example.test/oauth/callback',
  scopes: const ['openid', 'email'],
);

/// An unsigned JWT carrying the claims a well-behaved provider returns.
///
/// Unsigned because the flow deliberately does not check the signature — see the
/// `oauth_flow.dart` library documentation — so a signature here would assert
/// something no production code reads.
///
/// `exp` is present and in the future because the flow refuses a token without
/// it (`oauth.flow.missing_expiry`): OIDC Core §2 makes the claim required, so
/// its absence is a non-conformant provider rather than a token that never
/// expires. A fixture that omits it is not modelling "a well-behaved provider"
/// at all, and the tests below are about the *state store*, not about freshness
/// — they should reach it.
String _idToken(String? nonce) {
  String segment(Map<String, Object?> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expires =
      DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch ~/
      1000;
  return '${segment({'alg': 'none', 'typ': 'JWT'})}'
      '.${segment({'iss': 'https://idp.example.test', 'aud': 'tom-core-server-test', 'sub': 'sub-1', 'email': 'alice@example.test', 'exp': expires, 'nonce': ?nonce})}'
      '.';
}

/// The one HTTP seam, answering the token call from a script and recording the
/// form it was posted — the PKCE verifier's arrival at the *second* node is one
/// of the things being proved.
class _StubTransport implements TomOAuthTokenTransport {
  /// The form the last code exchange posted.
  Map<String, String>? postedForm;

  /// The nonce of the authorization request the user followed, which a
  /// provider returns in the `id_token`.
  String? nonce;

  @override
  Future<String> postForm(
    Uri uri,
    Map<String, String> form,
    Map<String, String> headers,
  ) async {
    postedForm = form;
    return jsonEncode({
      'access_token': 'at-1',
      'token_type': 'Bearer',
      'id_token': _idToken(nonce),
    });
  }

  @override
  Future<String> getJson(Uri uri, Map<String, String> headers) async =>
      jsonEncode(const <String, Object?>{});
}

/// The request a client posts to start a login, with every login-context field
/// set, because carrying that context across the redirect is half of what the
/// row is for.
TomOAuthAuthorizationRequest _authorizationRequest() =>
    TomOAuthAuthorizationRequest(
      providerId: 'stub',
      client: 'web',
      application: 'console',
      process: 'login',
      organization: 'acme',
      clientLanguage: 'de',
      clientCountry: 'DE',
      clientTimezone: 'Europe/Berlin',
    );

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('the relational pending-authorization store', () {
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      // Dropped, not truncated: the store creates the table on first use, so a
      // previous run with different DDL would otherwise persist.
      await TestDatabase.dropOAuthStateTable(dsi);
    });

    tearDownAll(TestDatabase.reset);

    setUp(() async {
      await TomSqlOAuthStateStore(dsi.datasource).deleteAll();
    });

    /// A store instance over the shared table — one per simulated node.
    TomSqlOAuthStateStore node({Duration? timeToLive}) => TomSqlOAuthStateStore(
      dsi.datasource,
      timeToLive: timeToLive ?? const Duration(minutes: 10),
    );

    /// A pending record created [age] ago.
    TomOAuthAuthorizationState pending(
      String state, {
      Duration age = Duration.zero,
      TomOAuthPkce? pkce,
    }) => TomOAuthAuthorizationState(
      state: state,
      providerId: 'stub',
      createdAt: DateTime.now().toUtc().subtract(age),
      pkce: pkce,
      client: 'web',
      application: 'console',
      process: 'login',
      organization: 'acme',
      clientLanguage: 'de',
      clientCountry: 'DE',
      clientTimezone: 'Europe/Berlin',
    );

    test('a record stored on one node is read on another', () async {
      await node().store(pending('s-cross'));
      // A second instance, with its own schema flag and its own sweep clock.
      expect((await node().peek('s-cross'))?.providerId, 'stub');
    });

    test('the login context and the PKCE pair survive the round trip', () async {
      // The callback is a bare browser navigation carrying none of this, which
      // is why the row holds it. A field lost here is a session issued in the
      // wrong organization or a code exchange the provider rejects.
      final pkce = TomOAuthPkce.generate();
      await node().store(pending('s-context', pkce: pkce));

      final read = await node().peek('s-context');
      expect(read, isNotNull);
      expect(read!.client, 'web');
      expect(read.application, 'console');
      expect(read.process, 'login');
      expect(read.organization, 'acme');
      expect(read.clientLanguage, 'de');
      expect(read.clientCountry, 'DE');
      expect(read.clientTimezone, 'Europe/Berlin');
      expect(read.pkce?.verifier, pkce.verifier);
      expect(read.pkce?.challenge, pkce.challenge);
      // Written UTC and read back UTC — the `DATETIME(6)`-as-text convention.
      expect(read.createdAt.isUtc, isTrue);
    });

    test(
      'the nonce and a verified SAML identity survive the round trip',
      () async {
        // The SAML handoff: the assertion consumer service stores the verified
        // identity, and the application's completion may land on another node.
        const identity = TomExternalIdentity(
          issuer: 'https://idp.example.test/saml',
          subject: 'alice',
          username: 'alice@example.test',
          displayName: 'Alice',
          claims: {
            'email': 'alice@example.test',
            'groups': ['admins', 'staff'],
          },
          groups: ['admins', 'staff'],
          roles: ['tom.admin'],
        );
        await node().store(
          TomOAuthAuthorizationState(
            state: 's-saml',
            providerId: 'corporate',
            createdAt: DateTime.now().toUtc(),
            nonce: 'digest-of-the-code',
            assertedIdentity: identity,
          ),
        );
        final read = await node().consume('s-saml');
        expect(read!.nonce, 'digest-of-the-code');
        expect(read.assertedIdentity!.toJson(), identity.toJson());
        await node().store(pending('s-plain'));
        final plain = await node().peek('s-plain');
        expect(plain!.nonce, isEmpty);
        expect(plain.assertedIdentity, isNull);
      },
    );

    test('a provider configured without PKCE stores neither half', () async {
      await node().store(pending('s-nopkce'));
      expect((await node().peek('s-nopkce'))?.pkce, isNull);
    });

    test('peek reads without spending; consume spends exactly once', () async {
      await node().store(pending('s-once'));

      expect((await node().peek('s-once'))?.providerId, 'stub');
      expect((await node().peek('s-once'))?.providerId, 'stub');
      expect((await node().consume('s-once'))?.providerId, 'stub');
      // This is what makes a code replay fail — and it holds across instances,
      // which is the half the in-process store could not offer.
      expect(await node().consume('s-once'), isNull);
      expect(await node().peek('s-once'), isNull);
    });

    test('two concurrent completions yield exactly one winner', () async {
      // The reason completion is one `DELETE ... RETURNING` and not a read
      // followed by a delete: between the read and the delete there is a window
      // in which a second callback reads the same live row, and both logins
      // succeed. Here both racing statements go to the database, which can
      // delete the row once.
      await node().store(pending('s-race'));

      final results = await Future.wait([
        node().consume('s-race'),
        node().consume('s-race'),
      ]);
      expect(results.where((r) => r != null), hasLength(1));
    });

    test('an expired record is refused exactly as an unknown one is', () async {
      // Not merely "refused": refused *identically*. Telling an attacker that a
      // handle was once valid tells them the handle was guessed correctly.
      final store = node(timeToLive: const Duration(minutes: 1));
      await store.store(pending('s-expired', age: const Duration(minutes: 5)));

      expect(await node().peek('s-expired'), isNull);
      expect(await node().consume('s-expired'), isNull);
      expect(await node().peek('s-never-existed'), isNull);
      expect(await node().consume('s-never-existed'), isNull);
    });

    test('a peer with a longer TTL cannot revive an expired record', () async {
      // Why the deadline is *stored* rather than derived from `created_at` plus
      // whatever TTL the reading node happens to be configured with. In a
      // rolling deployment two nodes disagree about the TTL, and a flow begun
      // under a one-minute TTL must not become completable because the node the
      // redirect landed on was configured for an hour.
      await node(
        timeToLive: const Duration(minutes: 1),
      ).store(pending('s-ttl', age: const Duration(minutes: 5)));

      expect(
        await node(timeToLive: const Duration(hours: 1)).peek('s-ttl'),
        isNull,
      );
    });

    test(
      'a duplicate handle fails rather than overwriting a live flow',
      () async {
        // A `state` is a fresh 32-byte token from `Random.secure`, so a second
        // store under the same handle is either a collision that cannot happen or
        // a caller reusing a handle. Silently replacing would strand the first
        // flow with no diagnosis.
        await node().store(pending('s-dup'));
        await expectLater(node().store(pending('s-dup')), throwsA(anything));
      },
    );

    test('purgeExpired removes only what has expired', () async {
      final store = node(timeToLive: const Duration(minutes: 10));
      await store.store(pending('s-live'));
      await store.store(pending('s-dead', age: const Duration(minutes: 30)));

      expect(await store.purgeExpired(), 1);
      expect(await node().peek('s-live'), isNotNull);
      // Idempotent: nothing left to purge.
      expect(await store.purgeExpired(), 0);
    });

    test('a flow begun on one node completes on another', () async {
      // The end-to-end case, and the one the todo's DONE WHEN names: two
      // `TomOAuthFlow` instances, each with its own store instance, sharing only
      // the table. This is the failing scenario — "external login works, but
      // intermittently, and the log says replay attack" — asserted to succeed.
      final provider = _provider();
      final transport = _StubTransport();
      TomOAuthFlow flowOn(TomSqlOAuthStateStore store) => TomOAuthFlow(
        providers: TomOAuthProviders({provider.id: provider}),
        stateStore: store,
        transport: transport,
      );

      final begun = await flowOn(
        node(),
      ).beginAuthorization(_authorizationRequest());
      // The user signs in at the provider, which keeps the request's nonce.
      transport.nonce = Uri.parse(
        begun.authorizationUri,
      ).queryParameters['nonce'];
      final exchange = await flowOn(
        node(),
      ).completeAuthorization(code: 'code-1', state: begun.state);

      expect(exchange.identity.subject, 'sub-1');
      expect(exchange.identity.username, 'alice@example.test');
      // The login context the callback did not carry, recovered from the row.
      expect(exchange.pending.organization, 'acme');
      expect(exchange.pending.clientTimezone, 'Europe/Berlin');
      // The PKCE verifier reached the second node and was presented.
      expect(transport.postedForm?['code_verifier'], isNotEmpty);

      // And the handle is spent everywhere, not just on the node that spent it.
      await expectLater(
        flowOn(
          node(),
        ).completeAuthorization(code: 'code-1', state: begun.state),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.flow.unknown_state',
          ),
        ),
      );
    });

    test('a store that may not create its table does not try', () async {
      // A deployment whose database credential cannot run DDL applies the
      // shipped migration instead. Its store must not issue a `CREATE TABLE` it
      // would only fail on.
      await TestDatabase.dropOAuthStateTable(dsi);
      final store = TomSqlOAuthStateStore(dsi.datasource, createSchema: false);
      await expectLater(store.peek('s-any'), throwsA(anything));
      // Restored for whatever runs next.
      await TomSqlOAuthStateStore(dsi.datasource).ensureSchema();
    });
  }, skip: skipReason);
}

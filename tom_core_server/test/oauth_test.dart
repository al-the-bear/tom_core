/// Tests for external-identity login (C-9): provider configuration, the
/// authorization-code + PKCE handshake, the linking table, and the
/// authentication service that joins them to the ordinary login path.
///
/// Everything runs against a **stub provider** — a [TomOAuthTokenTransport] that
/// answers the token and user-info calls from a map. That is the whole reason
/// the transport is a seam: with it stubbed, every other line of the flow (the
/// state check, the PKCE verifier, the claim verification, the account linking,
/// the 2FA decision, the token issuance) executes exactly as it does against a
/// real provider, so these tests exercise the production path rather than a
/// parallel one.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

// =============================================================================
// FIXTURES
// =============================================================================

/// The stub provider's issuer — a URL shape, like every real one.
const String _issuer = 'https://idp.example.test';

/// The client id the stub provider is registered under, and therefore the `aud`
/// every accepted token must carry.
const String _clientId = 'tom-core-server-test';

/// A provider that mints an `id_token`, which is the OIDC case.
TomOAuthProviderConfig _oidcProvider({
  TomOAuthProvisioning provisioning = TomOAuthProvisioning.refuse,
  bool usePkce = true,
}) => TomOAuthProviderConfig(
  id: 'stub',
  issuer: _issuer,
  authorizationEndpoint: '$_issuer/authorize',
  tokenEndpoint: '$_issuer/token',
  clientId: _clientId,
  clientSecret: 'sh-sh-secret',
  redirectUri: 'https://app.example.test/oauth/callback',
  scopes: const ['openid', 'email', 'profile'],
  usePkce: usePkce,
  provisioning: provisioning,
  displayNameKey: 'oauth.stub.name',
  iconKey: 'oauth.stub.icon',
);

/// A provider that returns only an access token, which is the plain OAuth 2.0
/// case — GitHub and everything that predates OIDC.
TomOAuthProviderConfig _userInfoProvider() => TomOAuthProviderConfig(
  id: 'legacy',
  issuer: 'https://legacy.example.test',
  authorizationEndpoint: 'https://legacy.example.test/authorize',
  tokenEndpoint: 'https://legacy.example.test/token',
  userInfoEndpoint: 'https://legacy.example.test/user',
  clientId: _clientId,
  redirectUri: 'https://app.example.test/oauth/callback',
  subjectClaim: 'id',
  usernameClaim: 'login',
  provisioning: TomOAuthProvisioning.autoProvision,
);

/// An unsigned JWT carrying [claims].
///
/// Unsigned because the flow deliberately does not check the signature — see
/// the `oauth_flow.dart` library documentation — so a signature here would be
/// asserting something no production code reads.
String _idToken(Map<String, Object?> claims) {
  String segment(Map<String, Object?> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({'alg': 'none', 'typ': 'JWT'})}'
      '.${segment(claims)}'
      '.';
}

/// The claim set a well-behaved provider returns.
Map<String, Object?> _claims({
  String subject = 'sub-1',
  String email = 'alice@example.test',
  String? issuer,
  Object? audience,
}) => <String, Object?>{
  'iss': issuer ?? _issuer,
  'aud': audience ?? _clientId,
  'sub': subject,
  'email': email,
  'name': 'Alice Example',
};

/// The stub provider: the one HTTP seam, answering from a script.
///
/// Records what it was asked, because half of what these tests prove is about
/// the *request* — that the verifier travels, that the redirect URI is the
/// configured one, that the secret is presented as `client_secret_basic`.
class _StubTransport implements TomOAuthTokenTransport {
  _StubTransport({Map<String, Object?>? tokenResponse, this.userInfo})
    : tokenResponse =
          tokenResponse ??
          <String, Object?>{
            'access_token': 'at-1',
            'token_type': 'Bearer',
            'id_token': _idToken(_claims()),
          };

  /// What the token endpoint answers.
  final Map<String, Object?> tokenResponse;

  /// What the user-info endpoint answers, when one is called.
  final Map<String, Object?>? userInfo;

  /// The form the last code exchange posted.
  Map<String, String>? postedForm;

  /// The headers the last code exchange sent.
  Map<String, String>? postedHeaders;

  /// The URI the last user-info call fetched.
  Uri? fetchedUri;

  @override
  Future<String> postForm(
    Uri uri,
    Map<String, String> form,
    Map<String, String> headers,
  ) async {
    postedForm = form;
    postedHeaders = headers;
    return jsonEncode(tokenResponse);
  }

  @override
  Future<String> getJson(Uri uri, Map<String, String> headers) async {
    fetchedUri = uri;
    return jsonEncode(userInfo ?? const <String, Object?>{});
  }
}

/// A flow over the stub, with everything else real.
TomOAuthFlow _flow(
  TomOAuthProviderConfig provider,
  TomOAuthTokenTransport transport, {
  TomOAuthStateStore? stateStore,
}) => TomOAuthFlow(
  providers: TomOAuthProviders({provider.id: provider}),
  stateStore: stateStore ?? TomOAuthMemoryStateStore(),
  transport: transport,
);

/// The request a client posts to start a login.
TomOAuthAuthorizationRequest _authorizationRequest({
  String providerId = 'stub',
}) => TomOAuthAuthorizationRequest(
  providerId: providerId,
  client: 'web',
  application: 'console',
  process: 'login',
  organization: 'acme',
  clientLanguage: 'de',
  clientCountry: 'DE',
  clientTimezone: 'Europe/Berlin',
);

/// The JWT registered claims, the validity window and the encrypted blob — all
/// of which differ between two tokens minted a moment apart for reasons that
/// have nothing to do with how the login was authenticated.
const _volatileClaims = {
  'iat',
  'exp',
  'nbf',
  'iss',
  'jti',
  'aud',
  'sub',
  'validFrom',
  'validUntil',
  'encrypted',
};

/// The claims of [jwt].
///
/// An empty map for an absent payload rather than a null check at each call
/// site: a token these tests issue always has one, and `{}` fails the assertion
/// that follows just as loudly as a null would have.
Map<String, dynamic> _claimsOf(String jwt) =>
    TomClientJwtToken(jwt).payload ?? const <String, dynamic>{};

/// One authentication attempt, with every field the constructor requires.
///
/// The defaults are deliberately *wrong* for the login context — an empty
/// organization and `en`/`XX`/`utc` — so a test that asserts the context came
/// from the flow rather than from the message cannot pass by coincidence.
TomAuthenticationData _authData({
  String username = TomUser.guestUsername,
  Object? key,
  String organization = '',
  String application = '',
  String process = '',
  String language = 'en',
  String country = 'XX',
  String timezone = 'utc',
  String client = '',
}) => TomAuthenticationData(
  username: username,
  key: key,
  organization: organization,
  application: application,
  process: process,
  language: language,
  country: country,
  timezone: timezone,
  client: client,
);

/// A principal for [username], shaped like one a real directory would return.
TomPrincipal _principal(
  String username,
  TomAuthenticationData a, {
  bool requires2FA = false,
  String? twoFactorType,
}) => TomPrincipal(
  authenticated: true,
  context: {},
  requires2FA: requires2FA,
  twoFactorType: twoFactorType,
  clientId: 0,
  organization: a.organization,
  organizationId: 0,
  application: a.application,
  applicationId: 0,
  process: a.process,
  processId: 0,
  language: a.language,
  country: a.country,
  clientCountry: a.country,
  clientLanguage: a.language,
  clientTimezone: a.timezone,
  user: TomUser(
    id: 7,
    username: username,
    firstname: 'Alice',
    lastname: 'Example',
    attributes: {},
    timeZone: 'utc',
  ),
  aci: TomAccessControlInformation(roles: const ['user']),
);

/// A deployment's account lookup, over a map.
///
/// This is the half of external login the framework deliberately does not own:
/// the framework has no user table, so a test must supply one just as a
/// deployment does.
class _StubDirectory implements TomExternalIdentityDirectory {
  _StubDirectory({
    Set<String>? accounts,
    this.canProvision = false,
    this.requires2FA = false,
    this.twoFactorType,
    this.provisionedUsername,
  }) : accounts = accounts ?? <String>{};

  /// The local accounts that exist.
  final Set<String> accounts;

  /// Whether [provisionFromExternalIdentity] is implemented at all.
  final bool canProvision;

  /// What the resolved principal claims about its second factor.
  final bool requires2FA;
  final String? twoFactorType;

  /// The username the directory settles on when provisioning, when it differs
  /// from the asserted one — a deployment that normalises or prefixes.
  final String? provisionedUsername;

  /// Every username the directory was asked about, in order.
  final List<String> lookups = [];

  /// Every identity it was asked to provision.
  final List<TomExternalIdentity> provisioned = [];

  @override
  Future<TomAuthenticationInfo?> authenticatedPrincipalFor(
    String username,
    TomAuthenticationData authData,
  ) async {
    lookups.add(username);
    if (!accounts.contains(username)) return null;
    return TomAuthenticationInfo(
      _principal(
        username,
        authData,
        requires2FA: requires2FA,
        twoFactorType: twoFactorType,
      ),
      TomAccessControlDefinition(),
    );
  }

  @override
  Future<TomAuthenticationInfo> provisionFromExternalIdentity(
    TomExternalIdentity identity,
    TomAuthenticationData authData,
  ) async {
    if (!canProvision) {
      throw LoginException(
        'login.error.oauth.provisioning-unsupported',
        'This directory does not provision.',
      );
    }
    provisioned.add(identity);
    final username = provisionedUsername ?? identity.username;
    accounts.add(username);
    return TomAuthenticationInfo(
      _principal(
        username,
        authData,
        requires2FA: requires2FA,
        twoFactorType: twoFactorType,
      ),
      TomAccessControlDefinition(),
    );
  }
}

/// A password service, so the pass-through and the token-parity comparison have
/// something real to compare against.
class _PasswordService implements TomAuthenticationService {
  int calls = 0;

  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData a,
  ) async {
    calls++;
    return TomAuthenticationInfo(
      _principal(a.username, a),
      TomAccessControlDefinition(),
    );
  }
}

/// A second factor whose code is a constant, so the 2FA assertions do not need
/// the clock.
class _FakeAdaptor implements Tom2FAService {
  /// The submission this mechanism accepts.
  static const String expected = '424242';

  int issued = 0;

  @override
  Tom2FAMethodDescriptor get descriptor =>
      Tom2FAMethodDescriptor.scoped('fake');

  @override
  Future<Tom2FAChallengeSpec> issueChallenge(Tom2FAContext context) async {
    issued++;
    return const Tom2FAChallengeSpec(
      hint: '***-**-4711',
      attemptsAllowed: 3,
      validity: Duration(minutes: 5),
    );
  }

  @override
  Future<bool> verifySubmission(
    Tom2FAContext context,
    Tom2FASubmission submission,
  ) async => submission.submitted == expected;
}

/// A shelf request for [uri], with the route captures [params].
Request _request(String uri, {Map<String, String> params = const {}}) =>
    Request('GET', Uri.parse(uri), context: {'shelf_router/params': params});

// =============================================================================
// TESTS
// =============================================================================

void main() {
  // Process-global and irreversible, so it is done once for the whole file
  // rather than per group: the DTO shape assertions, the endpoint router and the
  // token issuance all construct mirrors.
  setUpAll(initializeReflection);

  // ===========================================================================
  // CONFIGURATION AS DATA
  // ===========================================================================

  group('TomOAuthProviders configuration', () {
    test('reads a provider from the ordinary configuration tree', () {
      final providers = TomOAuthProviders.fromConfiguration(
        TomServerConfigResourceProvider.from({
          'oauth': {
            'providers': {
              'google': {
                'issuer': 'https://accounts.google.com',
                'authorizationEndpoint': 'https://accounts.google.com/o/auth',
                'tokenEndpoint': 'https://oauth2.googleapis.com/token',
                'clientId': 'client-1',
                'clientSecret': 'secret-1',
                'redirectUri': 'https://app.example.test/oauth/callback',
                'scopes': ['openid', 'email'],
                'provisioning': 'auto_provision',
              },
            },
          },
        }),
      );

      final google = providers['google'];
      expect(google.issuer, 'https://accounts.google.com');
      expect(google.clientSecret, 'secret-1');
      expect(google.scopes, ['openid', 'email']);
      // Separator-insensitive: hand-written YAML uses both spellings.
      expect(google.provisioning, TomOAuthProvisioning.autoProvision);
      // PKCE is on unless it is switched off, not off unless switched on.
      expect(google.usePkce, isTrue);
      // Resource keys are derived, so the ordinary provider configures none.
      expect(google.displayNameKey, 'oauth.google.name');
      expect(google.iconKey, 'oauth.google.icon');
    });

    test('accepts scopes written the way providers document them', () {
      final config = TomOAuthProviderConfig.fromMap('p', {
        'issuer': _issuer,
        'authorizationEndpoint': '$_issuer/authorize',
        'tokenEndpoint': '$_issuer/token',
        'clientId': _clientId,
        'redirectUri': 'https://app.example.test/oauth/callback',
        'scopes': 'openid email  profile',
      });
      expect(config.scopes, ['openid', 'email', 'profile']);
    });

    test(
      'a deployment with no oauth block gets an empty set, not a failure',
      () {
        final providers = TomOAuthProviders.fromConfiguration(
          TomServerConfigResourceProvider.from({'server': {}}),
        );
        expect(providers.isEmpty, isTrue);
        expect(providers.descriptors, isEmpty);
      },
    );

    // Absent and wrong are different states: the first is the common case, the
    // second is an operator error that must not degrade into the first.
    test('a malformed oauth block fails rather than reading as absent', () {
      expect(
        () => TomOAuthProviders.fromConfiguration(
          TomServerConfigResourceProvider.from({
            'oauth': {'providers': 'google'},
          }),
        ),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.not_a_map',
          ),
        ),
      );
    });

    test('the state store defaults to memory when nothing selects one', () {
      // The whole point of the default: a single-node deployment that has never
      // heard of the SQL store keeps the behaviour it always had, and needs to
      // configure nothing to keep it.
      final settings = TomOAuthStateStoreSettings.fromConfiguration(
        TomServerConfigResourceProvider.from({
          'oauth': {'providers': <String, Object>{}},
        }),
      );
      expect(settings.type, TomOAuthStateStoreType.memory);
      expect(settings.createStore(), isA<TomOAuthMemoryStateStore>());
    });

    test('the state store is selected alongside the provider set', () {
      final settings = TomOAuthStateStoreSettings.fromConfiguration(
        TomServerConfigResourceProvider.from({
          'oauth': {
            'stateStore': {
              'type': 'sql',
              'datasource': 'main',
              'table': 'pending_auth',
              'timeToLiveSeconds': '900',
              'createSchema': 'false',
            },
          },
        }),
      );
      expect(settings.type, TomOAuthStateStoreType.sql);
      expect(settings.datasourceName, 'main');
      expect(settings.table, 'pending_auth');
      expect(settings.timeToLive, const Duration(minutes: 15));
      expect(settings.createSchema, isFalse);
    });

    // A typo that quietly selected the per-process store would reintroduce
    // exactly the intermittent failure the SQL store exists to remove, on a
    // cluster whose operator believes it is configured for one.
    test('an unknown state store type is refused, not defaulted away', () {
      expect(
        () => TomOAuthStateStoreSettings.fromConfiguration(
          TomServerConfigResourceProvider.from({
            'oauth': {
              'stateStore': {'type': 'redis'},
            },
          }),
        ),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.unknown_state_store',
          ),
        ),
      );
    });

    test('selecting the sql store without a datasource fails at startup', () {
      expect(
        () => TomOAuthStateStoreSettings.fromConfiguration(
          TomServerConfigResourceProvider.from({
            'oauth': {
              'stateStore': {'type': 'sql'},
            },
          }),
        ),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.missing_state_store_datasource',
          ),
        ),
      );
    });

    test('a time-to-live that is not a positive number of seconds fails', () {
      expect(
        () => TomOAuthStateStoreSettings.fromConfiguration(
          TomServerConfigResourceProvider.from({
            'oauth': {
              'stateStore': {'timeToLiveSeconds': '0'},
            },
          }),
        ),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.invalid_state_store_ttl',
          ),
        ),
      );
    });

    test(
      'a provider missing a required setting fails at load, not at login',
      () {
        expect(
          () => TomOAuthProviderConfig.fromMap('p', {
            'issuer': _issuer,
            'authorizationEndpoint': '$_issuer/authorize',
            // no tokenEndpoint
            'clientId': _clientId,
            'redirectUri': 'https://app.example.test/oauth/callback',
          }),
          throwsA(
            isA<TomOAuthException>().having(
              (e) => e.key,
              'key',
              'oauth.config.missing_value',
            ),
          ),
        );
      },
    );

    // A typo in a security setting must not resolve to *any* behaviour.
    test('an unrecognised provisioning mode throws', () {
      expect(
        () => TomOAuthProvisioning.parse('autoprovison'),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.unknown_provisioning',
          ),
        ),
      );
    });

    test('the client-facing descriptor carries no endpoint, id or secret', () {
      final dto = _oidcProvider().toDto();
      expect(dto.id, 'stub');
      expect(dto.displayNameKey, 'oauth.stub.name');
      expect(dto.iconKey, 'oauth.stub.icon');
      // The DTO's whole field set is those three — asserted through its JSON
      // shape, which is what actually reaches a client.
      expect(tomReflectionInfo.getValues(dto).keys.toSet(), {
        'id',
        'displayNameKey',
        'iconKey',
      });
    });

    test('an unknown provider id is refused, not silently substituted', () {
      final providers = TomOAuthProviders({'stub': _oidcProvider()});
      expect(
        () => providers['other'],
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.unknown_provider',
          ),
        ),
      );
    });
  });

  // ===========================================================================
  // PKCE AND THE PENDING-AUTHORIZATION STORE
  // ===========================================================================

  group('TomOAuthPkce', () {
    test('the challenge is a digest of the verifier, not the verifier', () {
      final pkce = TomOAuthPkce.generate();
      expect(pkce.challenge, isNot(pkce.verifier));
      expect(pkce.challenge, TomOAuthPkce.challengeFor(pkce.verifier));
      // base64url without padding: it travels in a query string.
      expect(pkce.challenge, isNot(contains('=')));
      expect(pkce.verifier.length, greaterThanOrEqualTo(43));
    });

    test('two generated pairs differ', () {
      expect(
        TomOAuthPkce.generate().verifier,
        isNot(TomOAuthPkce.generate().verifier),
      );
    });
  });

  group('TomOAuthMemoryStateStore', () {
    TomOAuthAuthorizationState pending(String state) =>
        TomOAuthAuthorizationState(
          state: state,
          providerId: 'stub',
          createdAt: DateTime.now().toUtc(),
        );

    test('peek reads without spending; consume spends exactly once', () async {
      final store = TomOAuthMemoryStateStore();
      await store.store(pending('s-1'));

      expect((await store.peek('s-1'))?.providerId, 'stub');
      expect((await store.peek('s-1'))?.providerId, 'stub');
      expect((await store.consume('s-1'))?.providerId, 'stub');
      // This is what makes a code replay fail.
      expect(await store.consume('s-1'), isNull);
      expect(await store.peek('s-1'), isNull);
    });

    test(
      'an expired record is indistinguishable from an unknown one',
      () async {
        final store = TomOAuthMemoryStateStore(timeToLive: Duration.zero);
        await store.store(
          TomOAuthAuthorizationState(
            state: 's-2',
            providerId: 'stub',
            createdAt: DateTime.now().toUtc().subtract(
              const Duration(minutes: 1),
            ),
          ),
        );
        expect(await store.peek('s-2'), isNull);
        expect(await store.consume('s-2'), isNull);
      },
    );
  });

  // ===========================================================================
  // THE HANDSHAKE
  // ===========================================================================

  group('TomOAuthFlow.beginAuthorization', () {
    test('sends the user to the provider with the flow parameters', () async {
      final store = TomOAuthMemoryStateStore();
      final flow = _flow(_oidcProvider(), _StubTransport(), stateStore: store);

      final dto = await flow.beginAuthorization(_authorizationRequest());
      final uri = Uri.parse(dto.authorizationUri);

      expect(uri.origin + uri.path, '$_issuer/authorize');
      expect(uri.queryParameters['response_type'], 'code');
      expect(uri.queryParameters['client_id'], _clientId);
      expect(
        uri.queryParameters['redirect_uri'],
        'https://app.example.test/oauth/callback',
      );
      expect(uri.queryParameters['scope'], 'openid email profile');
      expect(uri.queryParameters['state'], dto.state);
      expect(uri.queryParameters['code_challenge_method'], 'S256');

      // The verifier stays server-side; only its digest travels.
      final stored = await store.peek(dto.state);
      expect(stored, isNotNull);
      expect(uri.queryParameters['code_challenge'], stored!.pkce!.challenge);
      expect(dto.authorizationUri, isNot(contains(stored.pkce!.verifier)));
    });

    // The callback is a bare browser navigation, so this is the only place the
    // login's real context can be captured.
    test('remembers the login context the flow started in', () async {
      final store = TomOAuthMemoryStateStore();
      final flow = _flow(_oidcProvider(), _StubTransport(), stateStore: store);

      final dto = await flow.beginAuthorization(_authorizationRequest());
      final stored = (await store.peek(dto.state))!;

      expect(stored.client, 'web');
      expect(stored.application, 'console');
      expect(stored.process, 'login');
      expect(stored.organization, 'acme');
      expect(stored.clientLanguage, 'de');
      expect(stored.clientCountry, 'DE');
      expect(stored.clientTimezone, 'Europe/Berlin');
    });

    test(
      'omits the PKCE parameters for a provider configured without it',
      () async {
        final flow = _flow(_oidcProvider(usePkce: false), _StubTransport());
        final dto = await flow.beginAuthorization(_authorizationRequest());
        final uri = Uri.parse(dto.authorizationUri);
        expect(uri.queryParameters, isNot(contains('code_challenge')));
        expect(uri.queryParameters, isNot(contains('code_challenge_method')));
      },
    );

    test('refuses a provider the deployment has not configured', () async {
      final flow = _flow(_oidcProvider(), _StubTransport());
      await expectLater(
        flow.beginAuthorization(_authorizationRequest(providerId: 'facebook')),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.unknown_provider',
          ),
        ),
      );
    });
  });

  group('TomOAuthFlow.completeAuthorization', () {
    test(
      'exchanges the code and answers who the provider says this is',
      () async {
        final store = TomOAuthMemoryStateStore();
        final transport = _StubTransport();
        final flow = _flow(_oidcProvider(), transport, stateStore: store);

        final begun = await flow.beginAuthorization(_authorizationRequest());
        final verifier = (await store.peek(begun.state))!.pkce!.verifier;

        final exchange = await flow.completeAuthorization(
          code: 'the-code',
          state: begun.state,
        );

        expect(exchange.identity.issuer, _issuer);
        expect(exchange.identity.subject, 'sub-1');
        expect(exchange.identity.username, 'alice@example.test');
        expect(exchange.identity.displayName, 'Alice Example');
        expect(exchange.pending.organization, 'acme');

        // The exchange presents the verifier, the configured redirect URI and the
        // secret as client_secret_basic.
        expect(transport.postedForm!['grant_type'], 'authorization_code');
        expect(transport.postedForm!['code'], 'the-code');
        expect(transport.postedForm!['code_verifier'], verifier);
        expect(
          transport.postedForm!['redirect_uri'],
          'https://app.example.test/oauth/callback',
        );
        expect(transport.postedHeaders!['Authorization'], startsWith('Basic '));
        expect(
          utf8.decode(
            base64.decode(
              transport.postedHeaders!['Authorization']!.substring(6),
            ),
          ),
          '$_clientId:sh-sh-secret',
        );
      },
    );

    // The single-use guarantee, which is what a stolen code runs into.
    test('a replayed state cannot complete a second time', () async {
      final flow = _flow(_oidcProvider(), _StubTransport());
      final begun = await flow.beginAuthorization(_authorizationRequest());
      await flow.completeAuthorization(code: 'c', state: begun.state);

      await expectLater(
        flow.completeAuthorization(code: 'c', state: begun.state),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.flow.unknown_state',
          ),
        ),
      );
    });

    test('a state the server never issued is rejected', () async {
      final flow = _flow(_oidcProvider(), _StubTransport());
      await flow.beginAuthorization(_authorizationRequest());

      await expectLater(
        flow.completeAuthorization(code: 'c', state: 'forged-state'),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.flow.unknown_state',
          ),
        ),
      );
    });

    // A verifier that does not match its challenge is rejected by the
    // *provider*, and what the framework must get right is that the pair it
    // sends is the pair it stored — asserted here by mismatching them.
    test(
      'the verifier presented is the one the challenge was made from',
      () async {
        final store = TomOAuthMemoryStateStore();
        final transport = _StubTransport();
        final flow = _flow(_oidcProvider(), transport, stateStore: store);

        final begun = await flow.beginAuthorization(_authorizationRequest());
        final challenge = (await store.peek(begun.state))!.pkce!.challenge;
        await flow.completeAuthorization(code: 'c', state: begun.state);

        expect(
          TomOAuthPkce.challengeFor(transport.postedForm!['code_verifier']!),
          challenge,
        );
      },
    );

    test('an id_token minted by another issuer is refused', () async {
      final flow = _flow(
        _oidcProvider(),
        _StubTransport(
          tokenResponse: {
            'id_token': _idToken(_claims(issuer: 'https://evil.example.test')),
          },
        ),
      );
      final begun = await flow.beginAuthorization(_authorizationRequest());

      await expectLater(
        flow.completeAuthorization(code: 'c', state: begun.state),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.flow.issuer_mismatch',
          ),
        ),
      );
    });

    // A shared identity provider issues to many relying parties; a token minted
    // for another one must not be accepted here even though `iss` matches.
    test('an id_token minted for another audience is refused', () async {
      final flow = _flow(
        _oidcProvider(),
        _StubTransport(
          tokenResponse: {
            'id_token': _idToken(_claims(audience: 'some-other-client')),
          },
        ),
      );
      final begun = await flow.beginAuthorization(_authorizationRequest());

      await expectLater(
        flow.completeAuthorization(code: 'c', state: begun.state),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.flow.audience_mismatch',
          ),
        ),
      );
    });

    test('an aud array containing the client id is accepted', () async {
      final flow = _flow(
        _oidcProvider(),
        _StubTransport(
          tokenResponse: {
            'id_token': _idToken(
              _claims(audience: ['other-client', _clientId]),
            ),
          },
        ),
      );
      final begun = await flow.beginAuthorization(_authorizationRequest());
      final exchange = await flow.completeAuthorization(
        code: 'c',
        state: begun.state,
      );
      expect(exchange.identity.subject, 'sub-1');
    });

    test('a token response with no subject claim is refused', () async {
      final flow = _flow(
        _oidcProvider(),
        _StubTransport(
          tokenResponse: {
            'id_token': _idToken({'iss': _issuer, 'aud': _clientId}),
          },
        ),
      );
      final begun = await flow.beginAuthorization(_authorizationRequest());

      await expectLater(
        flow.completeAuthorization(code: 'c', state: begun.state),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.flow.missing_subject',
          ),
        ),
      );
    });

    test('an error the provider reports is surfaced, not ignored', () async {
      final flow = _flow(
        _oidcProvider(),
        _StubTransport(
          tokenResponse: {
            'error': 'invalid_grant',
            'error_description': 'code already redeemed',
          },
        ),
      );
      final begun = await flow.beginAuthorization(_authorizationRequest());

      await expectLater(
        flow.completeAuthorization(code: 'c', state: begun.state),
        throwsA(
          isA<TomOAuthException>()
              .having((e) => e.key, 'key', 'oauth.flow.token_exchange_rejected')
              .having(
                (e) => e.toString(),
                'message',
                contains('invalid_grant'),
              ),
        ),
      );
    });

    // The non-OIDC family: an access token and a second call.
    test(
      'falls back to the user-info endpoint when there is no id_token',
      () async {
        final transport = _StubTransport(
          tokenResponse: {'access_token': 'at-9'},
          userInfo: {'id': 4711, 'login': 'octocat', 'name': 'The Octocat'},
        );
        final provider = _userInfoProvider();
        final flow = _flow(provider, transport);
        final begun = await flow.beginAuthorization(
          _authorizationRequest(providerId: provider.id),
        );

        final exchange = await flow.completeAuthorization(
          code: 'c',
          state: begun.state,
        );

        expect(transport.fetchedUri.toString(), provider.userInfoEndpoint);
        expect(exchange.identity.subject, '4711');
        expect(exchange.identity.username, 'octocat');
        expect(exchange.identity.displayName, 'The Octocat');
      },
    );

    test('a provider that returns neither an id_token nor a user-info endpoint '
        'fails clearly', () async {
      final flow = _flow(
        _oidcProvider(),
        _StubTransport(tokenResponse: {'access_token': 'at-1'}),
      );
      final begun = await flow.beginAuthorization(_authorizationRequest());

      await expectLater(
        flow.completeAuthorization(code: 'c', state: begun.state),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.flow.no_claims_source',
          ),
        ),
      );
    });
  });

  // ===========================================================================
  // THE LINKING TABLE
  // ===========================================================================

  group('TomExternalIdentityStore', () {
    const alice = TomExternalIdentity(
      issuer: _issuer,
      subject: 'sub-1',
      username: 'alice@example.test',
      displayName: 'Alice',
    );

    test('links, resolves and records a login', () async {
      final store = TomMemoryExternalIdentityStore();
      expect(await store.localUsernameFor(alice), isNull);

      await store.link(alice, 'alice');
      expect(await store.localUsernameFor(alice), 'alice');

      final beforeLogin = (await store.identitiesOf('alice')).single;
      expect(beforeLogin.lastLoginAt, isNull);
      expect(beforeLogin.linkedAt, isNotNull);

      await store.recordLogin(alice);
      expect((await store.identitiesOf('alice')).single.lastLoginAt, isNotNull);
    });

    // The subject is only unique within its issuer: the same subject from a
    // different provider is a different person.
    test('the key is the (issuer, subject) pair, not the subject', () async {
      final store = TomMemoryExternalIdentityStore();
      await store.link(alice, 'alice');
      const impostor = TomExternalIdentity(
        issuer: 'https://other.example.test',
        subject: 'sub-1',
      );
      expect(await store.localUsernameFor(impostor), isNull);
    });

    // People sign up one way and later sign in another; a table that modelled
    // one identity per account would force them to pick.
    test('one account may hold several external identities', () async {
      final store = TomMemoryExternalIdentityStore();
      await store.link(alice, 'alice');
      await store.link(
        const TomExternalIdentity(
          issuer: 'https://corp.example.test',
          subject: 'employee-9',
        ),
        'alice',
      );
      expect((await store.identitiesOf('alice')).length, 2);
    });

    test(
      'relinking the same identity updates rather than duplicates',
      () async {
        final store = TomMemoryExternalIdentityStore();
        await store.link(alice, 'alice');
        await store.link(alice, 'alice.renamed');
        final rows = await store.identitiesOf('alice.renamed');
        expect(rows.length, 1);
        expect(await store.identitiesOf('alice'), isEmpty);
      },
    );

    test('the entity DDL keys the pair uniquely and indexes the account', () {
      final sql = TomExternalIdentityLink.createTableSql;
      expect(
        sql,
        contains(
          'UNIQUE KEY uq_tom_external_identity (issuer, '
          'subject)',
        ),
      );
      expect(
        sql,
        contains(
          'KEY idx_tom_external_identity_local '
          '(local_username)',
        ),
      );
    });
  });

  // ===========================================================================
  // THE AUTHENTICATION SERVICE
  // ===========================================================================

  group('TomOAuthAuthenticationService', () {
    /// Runs a whole external login through the service and answers the
    /// principal it resolved.
    Future<TomAuthenticationInfo> login({
      required _StubDirectory directory,
      required TomExternalIdentityStore store,
      TomOAuthProvisioning provisioning = TomOAuthProvisioning.refuse,
      TomAuthenticationService? delegate,
      TomAuthenticationData? authData,
    }) async {
      final flow = _flow(
        _oidcProvider(provisioning: provisioning),
        _StubTransport(),
      );
      final begun = await flow.beginAuthorization(_authorizationRequest());
      final service = TomOAuthAuthenticationService(
        directory: directory,
        delegate: delegate,
        flow: flow,
        identityStore: store,
      );
      final data = authData ?? _authData();
      data.key = TomOAuthCredential(code: 'c', state: begun.state);
      return service.authenticateUser(data);
    }

    test('a linked identity resolves through the deployment directory', () async {
      final store = TomMemoryExternalIdentityStore();
      await store.link(
        const TomExternalIdentity(issuer: _issuer, subject: 'sub-1'),
        'alice',
      );
      final directory = _StubDirectory(accounts: {'alice'});

      final info = await login(directory: directory, store: store);

      expect(info.principal.user.username, 'alice');
      expect(directory.lookups, ['alice']);
      // The link is not passed a credential — the provider already authenticated
      // the user, so a second challenge would be asking them to log in twice.
      expect(directory.provisioned, isEmpty);
      expect((await store.identitiesOf('alice')).single.lastLoginAt, isNotNull);
    });

    // Provisioning is a decision, and the default must not make it.
    test('an unlinked identity is refused when the provider refuses', () async {
      await expectLater(
        login(
          directory: _StubDirectory(),
          store: TomMemoryExternalIdentityStore(),
        ),
        throwsA(
          isA<LoginException>().having(
            (e) => e.key,
            'key',
            'login.error.oauth.no-local-account',
          ),
        ),
      );
    });

    test('an unlinked identity is provisioned when the provider is configured '
        'to', () async {
      final store = TomMemoryExternalIdentityStore();
      final directory = _StubDirectory(canProvision: true);

      final info = await login(
        directory: directory,
        store: store,
        provisioning: TomOAuthProvisioning.autoProvision,
      );

      expect(info.principal.user.username, 'alice@example.test');
      expect(directory.provisioned.single.subject, 'sub-1');
      expect(
        await store.localUsernameFor(
          const TomExternalIdentity(issuer: _issuer, subject: 'sub-1'),
        ),
        'alice@example.test',
      );
    });

    // A deployment may normalise, prefix or de-duplicate the asserted name;
    // linking to the claim would leave the row pointing at nothing.
    test(
      'links to the username the directory settled on, not the claim',
      () async {
        final store = TomMemoryExternalIdentityStore();
        final directory = _StubDirectory(
          canProvision: true,
          provisionedUsername: 'ext_alice',
        );

        await login(
          directory: directory,
          store: store,
          provisioning: TomOAuthProvisioning.autoProvision,
        );

        expect(
          await store.localUsernameFor(
            const TomExternalIdentity(issuer: _issuer, subject: 'sub-1'),
          ),
          'ext_alice',
        );
      },
    );

    // How a user who signed up with a password later adds "Sign in with …".
    test('an existing local account under the asserted name is linked, not '
        'duplicated', () async {
      final store = TomMemoryExternalIdentityStore();
      final directory = _StubDirectory(accounts: {'alice@example.test'});

      final info = await login(
        directory: directory,
        store: store,
        provisioning: TomOAuthProvisioning.autoProvision,
      );

      expect(info.principal.user.username, 'alice@example.test');
      expect(directory.provisioned, isEmpty);
      expect(
        await store.localUsernameFor(
          const TomExternalIdentity(issuer: _issuer, subject: 'sub-1'),
        ),
        'alice@example.test',
      );
    });

    // The account-takeover case: an attacker who can make *any* provider assert
    // an address must not thereby acquire the local account that already uses
    // it. A provider configured to refuse never claims one.
    test('a refusing provider does not claim an existing account by its '
        'asserted name', () async {
      final directory = _StubDirectory(accounts: {'alice@example.test'});

      await expectLater(
        login(directory: directory, store: TomMemoryExternalIdentityStore()),
        throwsA(
          isA<LoginException>().having(
            (e) => e.key,
            'key',
            'login.error.oauth.no-local-account',
          ),
        ),
      );
      expect(directory.lookups, isEmpty);
    });

    // Recreating a deleted account from a stale row is exactly the state the
    // administrator who deleted it was trying to reach.
    test('a link pointing at a deleted account refuses rather than recreating '
        'it', () async {
      final store = TomMemoryExternalIdentityStore();
      await store.link(
        const TomExternalIdentity(issuer: _issuer, subject: 'sub-1'),
        'ghost',
      );

      await expectLater(
        login(
          directory: _StubDirectory(canProvision: true),
          store: store,
          provisioning: TomOAuthProvisioning.autoProvision,
        ),
        throwsA(
          isA<LoginException>().having(
            (e) => e.key,
            'key',
            'login.error.oauth.linked-account-missing',
          ),
        ),
      );
    });

    test(
      'auto-provisioning without a directory that provisions fails clearly',
      () async {
        await expectLater(
          login(
            directory: _StubDirectory(),
            store: TomMemoryExternalIdentityStore(),
            provisioning: TomOAuthProvisioning.autoProvision,
          ),
          throwsA(
            isA<LoginException>().having(
              (e) => e.key,
              'key',
              'login.error.oauth.provisioning-unsupported',
            ),
          ),
        );
      },
    );

    // Enabling external login must not mean disabling passwords.
    test('a password credential is handed to the delegate untouched', () async {
      final password = _PasswordService();
      final service = TomOAuthAuthenticationService(
        directory: _StubDirectory(accounts: {'bob'}),
        delegate: password,
        flow: _flow(_oidcProvider(), _StubTransport()),
        identityStore: TomMemoryExternalIdentityStore(),
      );

      final info = await service.authenticateUser(
        _authData(username: 'bob', key: 'pa55word'),
      );

      expect(password.calls, 1);
      expect(info.principal.user.username, 'bob');
    });

    test('external-only is a legitimate choice and says so when a password '
        'arrives', () async {
      final service = TomOAuthAuthenticationService(
        directory: _StubDirectory(),
        flow: _flow(_oidcProvider(), _StubTransport()),
        identityStore: TomMemoryExternalIdentityStore(),
      );

      await expectLater(
        service.authenticateUser(_authData(username: 'bob', key: 'pa55word')),
        throwsA(
          isA<LoginException>().having(
            (e) => e.key,
            'key',
            'login.error.oauth.credential-not-supported',
          ),
        ),
      );
    });

    // A link that vanishes on restart sends a returning user through
    // provisioning again, so there is no safe in-memory default.
    test(
      'a deployment with no identity store is told what is missing',
      () async {
        TomBean.resetBeanContext();
        final flow = _flow(_oidcProvider(), _StubTransport());
        final begun = await flow.beginAuthorization(_authorizationRequest());
        final service = TomOAuthAuthenticationService(
          directory: _StubDirectory(),
          flow: flow,
        );

        await expectLater(
          service.authenticateUser(
            _authData()
              ..key = TomOAuthCredential(code: 'c', state: begun.state),
          ),
          throwsA(
            isA<LoginException>().having(
              (e) => e.key,
              'key',
              'login.error.oauth.no-identity-store',
            ),
          ),
        );
      },
    );

    // The callback carries no context of its own, so trusting the message would
    // issue the session in whatever the endpoint defaulted to.
    test(
      'the login context comes from the flow, not from the message',
      () async {
        final store = TomMemoryExternalIdentityStore();
        await store.link(
          const TomExternalIdentity(issuer: _issuer, subject: 'sub-1'),
          'alice',
        );
        final authData = _authData(organization: 'wrong-org', language: 'xx');

        final info = await login(
          directory: _StubDirectory(accounts: {'alice'}),
          store: store,
          authData: authData,
        );

        expect(authData.organization, 'acme');
        expect(authData.language, 'de');
        expect(info.principal.organization, 'acme');
      },
    );
  });

  // ===========================================================================
  // THE SHARED LOGIN PATH — the point of the whole design
  // ===========================================================================

  group('TomAuthenticationServer.authenticateExternal', () {
    late TomAuthenticationService savedUserService;
    late bool savedProtectionDefault;
    final server = TomAuthenticationServer();

    setUp(() {
      savedUserService =
          TomAuthenticationServer.globalSettingUserAuthenticationService;
      savedProtectionDefault =
          TomResourceKeyProtection.globalSettingProtectionDefault;
      // Deterministic token payloads: no resource-key redaction of claims.
      TomResourceKeyProtection.globalSettingProtectionDefault = false;
      Tom2FARegistry.reset();
    });

    tearDown(() {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          savedUserService;
      TomResourceKeyProtection.globalSettingProtectionDefault =
          savedProtectionDefault;
      Tom2FARegistry.reset();
      TomBean.resetBeanContext();
    });

    /// Installs an OAuth service over [directory] and returns the credential a
    /// completed provider redirect would carry.
    Future<TomOAuthCredential> installExternalLogin({
      required _StubDirectory directory,
      TomExternalIdentityStore? store,
      TomOAuthProvisioning provisioning = TomOAuthProvisioning.autoProvision,
      TomAuthenticationService? delegate,
    }) async {
      final flow = _flow(
        _oidcProvider(provisioning: provisioning),
        _StubTransport(),
      );
      final begun = await flow.beginAuthorization(_authorizationRequest());
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          TomOAuthAuthenticationService(
            directory: directory,
            delegate: delegate,
            flow: flow,
            identityStore: store ?? TomMemoryExternalIdentityStore(),
          );
      return TomOAuthCredential(code: 'c', state: begun.state);
    }

    /// The message the callback endpoint would build from the pending record.
    TomAuthenticationMessage message() => TomAuthenticationMessage()
      ..client = 'web'
      ..application = 'console'
      ..process = 'login'
      ..organization = 'acme'
      ..clientLanguage = 'de'
      ..clientCountry = 'DE'
      ..clientTimezone = 'Europe/Berlin';

    // The claim the module readme makes, asserted rather than described: an
    // external login is issued the *same* token pair a password login is.
    test('issues the token pair a password login would have issued', () async {
      final credential = await installExternalLogin(
        directory: _StubDirectory(canProvision: true),
      );
      final external = await server.authenticateExternal(message(), credential);

      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _PasswordService();
      final password = await server.authenticateUser(
        message()
          ..userName = 'alice@example.test'
          ..password = 'pa55word',
        false,
      );

      expect(external.error, isEmpty);
      expect(password.error, isEmpty);
      expect(external.requires2FA, isFalse);

      final externalClaims = _claimsOf(external.authorizationToken);
      final passwordClaims = _claimsOf(password.authorizationToken);

      // Every claim that is not volatile agrees. If the external path ever
      // grows a token issuance of its own, this is the assertion that fails.
      // The excluded set is `two_factor_test.dart`'s `_volatileClaims`
      // verbatim — the registered claims, the validity window and the
      // encrypted blob, which differ between any two tokens minted a moment
      // apart. What they carry is asserted below instead, from the decrypted
      // principal.
      for (final key in passwordClaims.keys.where(
        (k) => !_volatileClaims.contains(k),
      )) {
        expect(
          externalClaims[key],
          passwordClaims[key],
          reason:
              "claim '$key' differs between an external and a password "
              'login',
        );
      }

      // The access-control payload the authorization token exists to carry.
      final externalPrincipal =
          TomBearerAuthentication.convertTokenPayloadToPrincipal(
            TomClientJwtToken(external.authorizationToken),
          );
      final passwordPrincipal =
          TomBearerAuthentication.convertTokenPayloadToPrincipal(
            TomClientJwtToken(password.authorizationToken),
          );
      expect(externalPrincipal.authenticated, isTrue);
      expect(externalPrincipal.username, passwordPrincipal.username);
      expect(externalPrincipal.aci.roles, passwordPrincipal.aci.roles);
      expect(externalPrincipal.aci.groups, passwordPrincipal.aci.groups);

      expect(
        _claimsOf(external.authenticationToken)['username'],
        _claimsOf(password.authenticationToken)['username'],
      );
    });

    // The whole reason this todo landed after the 2FA chain: the policy must
    // apply to an externally-authenticated principal too, and it does because
    // nothing on the external path knows there is a policy.
    test('the 2FA policy still applies to an externally-authenticated '
        'principal', () async {
      final adaptor = _FakeAdaptor();
      Tom2FARegistry.register('fake', adaptor);
      final credential = await installExternalLogin(
        directory: _StubDirectory(
          canProvision: true,
          requires2FA: true,
          twoFactorType: 'fake',
        ),
      );

      final result = await server.authenticateExternal(message(), credential);

      expect(result.error, isEmpty);
      expect(result.requires2FA, isTrue);
      expect(result.twoFactorType, 'fake');
      expect(adaptor.issued, 1);

      // What came back is a challenge, not a session.
      final token = TomClientJwtToken(result.authorizationToken);
      final principal = TomBearerAuthentication.convertTokenPayloadToPrincipal(
        token,
      );
      expect(principal.authenticated, isFalse);
      expect(principal.username, 'alice@example.test');

      // And the ordinary second pass finishes it — the same call a password
      // login's second pass makes.
      final second = await server.authenticatePass2(
        message()..password = _FakeAdaptor.expected,
        challengeToken: token,
      );
      expect(second.error, isEmpty);
      expect(second.requires2FA, isFalse);
      expect(
        TomBearerAuthentication.convertTokenPayloadToPrincipal(
          TomClientJwtToken(second.authorizationToken),
        ).authenticated,
        isTrue,
      );
    });

    test(
      'a refused external login comes back as a failed result, not a throw',
      () async {
        final credential = await installExternalLogin(
          directory: _StubDirectory(),
          provisioning: TomOAuthProvisioning.refuse,
        );

        final result = await server.authenticateExternal(message(), credential);

        expect(result.error, isNotEmpty);
        expect(result.authorizationToken, isEmpty);
      },
    );
  });

  // ===========================================================================
  // THE ENDPOINTS
  // ===========================================================================

  group('TomOAuthServer endpoints', () {
    late TomAuthenticationService savedUserService;
    const endpoints = TomOAuthServer();

    setUp(() {
      savedUserService =
          TomAuthenticationServer.globalSettingUserAuthenticationService;
      TomBean.resetBeanContext();
    });

    tearDown(() {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          savedUserService;
      TomBean.resetBeanContext();
    });

    test('lists the configured providers as resource keys only', () async {
      TomBean.withType(
        TomOAuthProviders,
        TomOAuthProviders({'stub': _oidcProvider()}),
      );
      final providers = await endpoints.listOAuthProviders();
      expect(providers.single.id, 'stub');
      expect(providers.single.displayNameKey, 'oauth.stub.name');
    });

    // "This deployment offers no external login" is the common state, and the
    // endpoint answers it rather than failing.
    test('answers an empty list when no provider is configured', () async {
      TomServerConfigResourceProvider.setServerConfigProvider(
        TomServerConfigResourceProvider.from({}),
      );
      expect(await endpoints.listOAuthProviders(), isEmpty);
    });

    test(
      'begins an authorization through the installed provider set',
      () async {
        final store = TomOAuthMemoryStateStore();
        TomBean.withType(
          TomOAuthProviders,
          TomOAuthProviders({'stub': _oidcProvider()}),
        );
        TomBean.withType(TomOAuthStateStore, store);
        TomBean.withType(TomOAuthTokenTransport, _StubTransport());

        final dto = await endpoints.beginOAuthAuthorization(
          _authorizationRequest(),
        );

        expect(dto.authorizationUri, startsWith('$_issuer/authorize?'));
        expect((await store.peek(dto.state))!.organization, 'acme');
      },
    );

    test('the callback completes the login the flow started', () async {
      final store = TomOAuthMemoryStateStore();
      TomBean.withType(
        TomOAuthProviders,
        TomOAuthProviders({
          'stub': _oidcProvider(
            provisioning: TomOAuthProvisioning.autoProvision,
          ),
        }),
      );
      TomBean.withType(TomOAuthStateStore, store);
      TomBean.withType(TomOAuthTokenTransport, _StubTransport());
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          TomOAuthAuthenticationService(
            directory: _StubDirectory(canProvision: true),
            identityStore: TomMemoryExternalIdentityStore(),
          );

      final dto = await endpoints.beginOAuthAuthorization(
        _authorizationRequest(),
      );
      final result = await endpoints.completeOAuthAuthorization(
        TomOAuthCallbackRequest(code: 'the-code', state: dto.state),
      );

      expect(result.error, isEmpty);
      expect(result.authorizationToken, isNotEmpty);
      // The login came out in the context the *flow* captured, which the
      // callback itself carries none of.
      expect(_claimsOf(result.authorizationToken)['organization'], 'acme');
    });

    test(
      'a provider that reports an error never reaches the code exchange',
      () async {
        await expectLater(
          endpoints.completeOAuthAuthorization(
            TomOAuthCallbackRequest(
              state: 's',
              error: 'access_denied',
              errorDescription: 'the user pressed cancel',
            ),
          ),
          throwsA(
            isA<TomEndpointHandlerException>().having(
              (e) => e.key,
              'key',
              'oauth.callback.provider_error',
            ),
          ),
        );
      },
    );

    test('a callback for a state nobody started is refused', () async {
      await expectLater(
        endpoints.completeOAuthAuthorization(
          TomOAuthCallbackRequest(code: 'c', state: 'forged'),
        ),
        throwsA(
          isA<TomEndpointHandlerException>().having(
            (e) => e.key,
            'key',
            'oauth.callback.unknown_state',
          ),
        ),
      );
    });
  });

  // ===========================================================================
  // THE PIPELINE BINDING THE CALLBACK NEEDS
  // ===========================================================================

  group('TomEndpointHandler.injectQueryParameters', () {
    TomEndpoint endpoint(Map<String, String> mapping) =>
        TomEndpoint(uri: '/callback', urlParameterMapping: mapping);

    test('folds mapped query parameters under their DTO field names', () {
      final data = <String, dynamic>{};
      TomEndpointHandler.injectQueryParameters(
        data,
        _request('https://s/callback?code=abc&error_description=nope'),
        endpoint({'code': 'code', 'error_description': 'errorDescription'}),
      );
      expect(data, {'code': 'abc', 'errorDescription': 'nope'});
    });

    // No identity fallback: a query string is whatever a caller chose to
    // append, so an unmapped parameter must not reach a DTO field.
    test('ignores query parameters the contract does not name', () {
      final data = <String, dynamic>{};
      TomEndpointHandler.injectQueryParameters(
        data,
        _request('https://s/callback?code=abc&isAdmin=true'),
        endpoint({'code': 'code'}),
      );
      expect(data, {'code': 'abc'});
    });

    test(
      'an endpoint that declares no mapping binds nothing from the query',
      () {
        final data = <String, dynamic>{};
        TomEndpointHandler.injectQueryParameters(
          data,
          _request('https://s/callback?code=abc'),
          endpoint({}),
        );
        expect(data, isEmpty);
      },
    );

    // The route is the stronger statement, so a path capture wins — which is
    // what the call order in the pipeline guarantees.
    test('a path capture of the same name wins over a query parameter', () {
      final data = <String, dynamic>{};
      final req = _request('https://s/items/7?id=99', params: {'id': '7'});
      final ep = endpoint({'id': 'id'});
      TomEndpointHandler.injectQueryParameters(data, req, ep);
      TomEndpointHandler.injectPathParameters(data, req, ep);
      expect(data['id'], '7');
    });
  });
}

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
///
/// The one exception is [TomHttpOAuthTokenTransport], the live seam itself,
/// which is pinned against a loopback [HttpServer] — a stub cannot prove what
/// the code that speaks HTTP does with a non-2xx.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  Duration clockSkew = const Duration(seconds: 60),
  String? revocationEndpoint,
  String id = 'stub',
}) => TomOAuthProviderConfig(
  id: id,
  issuer: _issuer,
  authorizationEndpoint: '$_issuer/authorize',
  tokenEndpoint: '$_issuer/token',
  revocationEndpoint: revocationEndpoint,
  clientId: _clientId,
  clientSecret: 'sh-sh-secret',
  redirectUri: 'https://app.example.test/oauth/callback',
  scopes: const ['openid', 'email', 'profile'],
  usePkce: usePkce,
  provisioning: provisioning,
  displayNameKey: 'oauth.stub.name',
  iconKey: 'oauth.stub.icon',
  clockSkew: clockSkew,
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

/// A NumericDate (RFC 7519 §2): whole seconds since the epoch, UTC.
int _numericDate(Duration fromNow) =>
    DateTime.now().toUtc().add(fromNow).millisecondsSinceEpoch ~/ 1000;

/// The claim set a well-behaved provider returns.
///
/// `exp` is always present, because OIDC Core §2 makes it required and a
/// fixture that omitted it would describe a provider no deployment should
/// accept. Move it with [expires]; the tests that need it absent or malformed
/// write their claim map out by hand.
Map<String, Object?> _claims({
  String subject = 'sub-1',
  String email = 'alice@example.test',
  String? issuer,
  Object? audience,
  Duration expires = const Duration(minutes: 5),
  Object? notBefore,
  Object? issuedAt,
}) => <String, Object?>{
  'iss': issuer ?? _issuer,
  'aud': audience ?? _clientId,
  'sub': subject,
  'email': email,
  'name': 'Alice Example',
  'exp': _numericDate(expires),
  if (notBefore != null) 'nbf': notBefore,
  if (issuedAt != null) 'iat': issuedAt,
};

/// The stub provider: the one HTTP seam, answering from a script.
///
/// Records what it was asked, because half of what these tests prove is about
/// the *request* — that the verifier travels, that the redirect URI is the
/// configured one, that the secret is presented as `client_secret_basic`.
class _StubTransport implements TomOAuthTokenTransport {
  _StubTransport({
    Map<String, Object?>? tokenResponse,
    this.userInfo,
    this.rawTokenBody,
    this.rawUserInfoBody,
  }) : tokenResponse =
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

  /// The token response as a literal body, bypassing [tokenResponse].
  ///
  /// The scripted responses are encoded from a map, which can only ever produce
  /// well-formed JSON — so the provider that answers `200` with an HTML error
  /// page, the one the decoder's diagnostics were written for, is unreachable
  /// through them. These two say the body verbatim instead.
  final String? rawTokenBody;

  /// The user-info response as a literal body, bypassing [userInfo].
  final String? rawUserInfoBody;

  /// How many code exchanges were asked for.
  int calls = 0;

  /// The URI the last form post went to.
  Uri? postedUri;

  /// The body answered to a post, when it should not be [tokenResponse] —
  /// a revocation answers an empty body, not a token.
  String? formResponse;

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
    calls++;
    postedUri = uri;
    postedForm = form;
    postedHeaders = headers;
    if (formResponse != null) return formResponse!;
    return rawTokenBody ?? jsonEncode(tokenResponse);
  }

  @override
  Future<String> getJson(Uri uri, Map<String, String> headers) async {
    fetchedUri = uri;
    return rawUserInfoBody ?? jsonEncode(userInfo ?? const <String, Object?>{});
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

/// A flow over several providers, configured **in the order given**.
///
/// The order is load-bearing rather than incidental: what these tests guard
/// against is a resolution that walks the configured providers and takes the
/// first plausible match, so a fixture that could not place the *wrong*
/// provider first could not fail when one does.
TomOAuthFlow _multiProviderFlow(
  List<TomOAuthProviderConfig> providers,
  TomOAuthTokenTransport transport, {
  TomOAuthStateStore? stateStore,
}) => TomOAuthFlow(
  providers: TomOAuthProviders({
    for (final provider in providers) provider.id: provider,
  }),
  stateStore: stateStore ?? TomOAuthMemoryStateStore(),
  transport: transport,
);

/// A second registration against the *same* issuer as [_oidcProvider].
///
/// Not a contrived configuration: a provider is keyed by its own id and nothing
/// makes the issuer unique, which is exactly how a deployment offers one IdP
/// twice — two scope sets, or two client registrations, one restricted and one
/// not. The two then differ in everything that matters to a login while
/// asserting identical identities.
TomOAuthProviderConfig _twinProvider({
  required String id,
  required TomOAuthProvisioning provisioning,
  bool storeTokens = false,
}) => TomOAuthProviderConfig(
  id: id,
  issuer: _issuer,
  authorizationEndpoint: '$_issuer/authorize',
  tokenEndpoint: '$_issuer/token',
  clientId: _clientId,
  redirectUri: 'https://app.example.test/oauth/callback',
  provisioning: provisioning,
  storeTokens: storeTokens,
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
    timezone: 'utc',
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
      throw TomLoginException(
        'login.error.oauth.provisioning-unsupported',
        'This directory does not provision.',
        reason: TomLoginFailure.providerError,
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

/// A directory that implements only the lookup, so the *framework's* default
/// `provisionFromExternalIdentity` is the one under test.
///
/// [_StubDirectory] cannot serve here: it `implements` the interface and so
/// carries its own refusal, which is not the one a deployment meets.
class _LookupOnlyDirectory extends TomExternalIdentityDirectory {
  @override
  Future<TomAuthenticationInfo?> authenticatedPrincipalFor(
    String username,
    TomAuthenticationData authData,
  ) async => null;
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

    test('the clock-skew tolerance is a per-provider setting', () {
      TomOAuthProviderConfig read(Map<Object?, Object?> extra) =>
          TomOAuthProviderConfig.fromMap('p', {
            'issuer': _issuer,
            'authorizationEndpoint': '$_issuer/authorize',
            'tokenEndpoint': '$_issuer/token',
            'clientId': _clientId,
            'redirectUri': 'https://app.example.test/oauth/callback',
            ...extra,
          });

      // A minute is the customary tolerance, and it is a default rather than a
      // constant because one badly-synced provider must not force every other
      // one wider.
      expect(read({}).clockSkew, const Duration(seconds: 60));
      expect(
        read({'clockSkewSeconds': 5}).clockSkew,
        const Duration(seconds: 5),
      );
      // Nought is a real answer -- "my clocks are NTP-synced, refuse anything
      // stale" -- so it must not read as "unset, use the default".
      expect(read({'clockSkewSeconds': 0}).clockSkew, Duration.zero);
      // Negative would tighten expiry past the token's own claim, which is
      // never what an operator meant to type.
      expect(
        () => read({'clockSkewSeconds': -1}),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.invalid_clock_skew',
          ),
        ),
      );
      expect(
        () => read({'clockSkewSeconds': 'a minute'}),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.invalid_clock_skew',
          ),
        ),
      );
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

    // The provider *set* is a map of maps, and one entry being a scalar is the
    // shape a mis-indented YAML block takes. It has to fail on the entry rather
    // than on the whole block: `oauth.config.not_a_map` names the wrong level
    // and would send an operator looking at the wrong four lines.
    test('a provider entry that is not a map names the provider that is', () {
      expect(
        () => TomOAuthProviders.fromConfiguration(
          TomServerConfigResourceProvider.from({
            'oauth': {
              'providers': {'google': 'https://accounts.google.com'},
            },
          }),
        ),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.provider_not_a_map',
          ),
        ),
      );
    });

    test('authorization parameters that are not a map fail at load', () {
      expect(
        () => TomOAuthProviderConfig.fromMap('p', {
          'issuer': _issuer,
          'authorizationEndpoint': '$_issuer/authorize',
          'tokenEndpoint': '$_issuer/token',
          'clientId': _clientId,
          'redirectUri': 'https://app.example.test/oauth/callback',
          'authorizationParameters': 'prompt=consent',
        }),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.parameters_not_a_map',
          ),
        ),
      );
    });

    // Stringifying a nested map into the redirect would not fail here: it would
    // fail at the provider, as a rejected authorization request whose message
    // says nothing about the YAML. Refusing at load is what keeps the
    // diagnostic next to the mistake.
    test('a nested authorization parameter value fails at load', () {
      expect(
        () => TomOAuthProviderConfig.fromMap('p', {
          'issuer': _issuer,
          'authorizationEndpoint': '$_issuer/authorize',
          'tokenEndpoint': '$_issuer/token',
          'clientId': _clientId,
          'redirectUri': 'https://app.example.test/oauth/callback',
          'authorizationParameters': {
            'tenant': {'id': 'contoso'},
          },
        }),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.parameter_not_a_scalar',
          ),
        ),
      );
    });

    test(
      'a state-store block that is not a map fails rather than defaulting',
      () {
        expect(
          () => TomOAuthStateStoreSettings.fromConfiguration(
            TomServerConfigResourceProvider.from({
              'oauth': {'stateStore': 'sql'},
            }),
          ),
          throwsA(
            isA<TomOAuthException>().having(
              (e) => e.key,
              'key',
              'oauth.config.state_store_not_a_map',
            ),
          ),
        );
      },
    );
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

    test(
      'an id_token is accepted on its claims, whatever its signature',
      () async {
        // Pinned for doc/authentication.md: the signature is not verified, only
        // the claims are checked. A token signed with nothing (`alg: none`) and
        // one carrying a signature no key could produce are both accepted. When
        // JWKS verification lands this fails, and the bullet goes.
        for (final signature in ['', 'not-a-signature-any-key-produced']) {
          final unsigned = _idToken(_claims());
          final token =
              '${unsigned.substring(0, unsigned.length - 1)}.'
              '$signature';
          final flow = _flow(
            _oidcProvider(),
            _StubTransport(
              tokenResponse: {
                'access_token': 'at-1',
                'token_type': 'Bearer',
                'id_token': token,
              },
            ),
          );
          final begun = await flow.beginAuthorization(_authorizationRequest());
          final exchange = await flow.completeAuthorization(
            code: 'c',
            state: begun.state,
          );
          expect(exchange.identity.subject, 'sub-1');
        }
      },
    );

    // The exchange names its own provider, so that every decision downstream
    // can be taken from one resolution rather than each finding its own. The
    // issuer cannot serve as that name: it identifies the IdP, and two
    // registrations may share one.
    test('names the provider it was completed against', () async {
      final flow = _multiProviderFlow([
        _twinProvider(
          id: 'restricted',
          provisioning: TomOAuthProvisioning.refuse,
        ),
        _twinProvider(
          id: 'full',
          provisioning: TomOAuthProvisioning.autoProvision,
          storeTokens: true,
        ),
      ], _StubTransport());
      final begun = await flow.beginAuthorization(
        _authorizationRequest(providerId: 'full'),
      );

      final exchange = await flow.completeAuthorization(
        code: 'c',
        state: begun.state,
      );

      expect(exchange.provider.id, 'full');
      expect(
        exchange.provider.provisioning,
        TomOAuthProvisioning.autoProvision,
      );
      expect(exchange.provider.storeTokens, isTrue);
      // The twin it is not, asserting identically.
      expect(exchange.identity.issuer, _issuer);
    });

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
            'id_token': _idToken({
              'iss': _issuer,
              'aud': _clientId,
              'exp': _numericDate(const Duration(minutes: 5)),
            }),
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

    // Freshness is a separate question from authenticity. The signature is not
    // verified because TLS already answers "did this come from the issuer"; no
    // part of that argument answers "is it still valid", so `exp` is checked.
    group('id_token freshness', () {
      /// Completes one exchange over a token carrying [claims].
      Future<TomOAuthExchange> complete(
        Map<String, Object?> claims, {
        Duration clockSkew = const Duration(seconds: 60),
      }) async {
        final flow = _flow(
          _oidcProvider(clockSkew: clockSkew),
          _StubTransport(tokenResponse: {'id_token': _idToken(claims)}),
        );
        final begun = await flow.beginAuthorization(_authorizationRequest());
        return flow.completeAuthorization(code: 'c', state: begun.state);
      }

      Matcher throwsKey(String key) =>
          throwsA(isA<TomOAuthException>().having((e) => e.key, 'key', key));

      test('an expired id_token is refused', () async {
        await expectLater(
          complete(_claims(expires: const Duration(minutes: -5))),
          throwsKey('oauth.flow.id_token_expired'),
        );
      });

      // The skew tolerance exists for exactly this: the provider's clock and
      // ours disagree by seconds, and a login must not fail for it.
      test(
        'an id_token just past expiry is accepted within the skew',
        () async {
          final exchange = await complete(
            _claims(expires: const Duration(seconds: -30)),
          );
          expect(exchange.identity.subject, 'sub-1');
        },
      );

      test('a tightened skew refuses what the default would accept', () async {
        await expectLater(
          complete(
            _claims(expires: const Duration(seconds: -30)),
            clockSkew: Duration.zero,
          ),
          throwsKey('oauth.flow.id_token_expired'),
        );
      });

      test('a widened skew accepts what the default would refuse', () async {
        final exchange = await complete(
          _claims(expires: const Duration(minutes: -4)),
          clockSkew: const Duration(minutes: 5),
        );
        expect(exchange.identity.subject, 'sub-1');
      });

      // Not "accepted because unbounded": a token with no `exp` cannot be
      // checked at all, and OIDC Core §2 requires the claim, so its absence is
      // a non-conformant provider rather than a token that never expires.
      test('an id_token with no expiry is refused', () async {
        await expectLater(
          complete({'iss': _issuer, 'aud': _clientId, 'sub': 'sub-1'}),
          throwsKey('oauth.flow.missing_expiry'),
        );
      });

      test('an exp that is not a NumericDate is refused', () async {
        await expectLater(
          complete({
            'iss': _issuer,
            'aud': _clientId,
            'sub': 'sub-1',
            'exp': 'tomorrow',
          }),
          throwsKey('oauth.flow.malformed_id_token'),
        );
      });

      // Providers stringify NumericDates often enough that rejecting the
      // spelling rather than the value would be a false refusal.
      test('an exp written as a numeric string is read, not refused', () async {
        final exchange = await complete({
          'iss': _issuer,
          'aud': _clientId,
          'sub': 'sub-1',
          'exp': '${_numericDate(const Duration(minutes: 5))}',
        });
        expect(exchange.identity.subject, 'sub-1');
      });

      test('an id_token that is not yet valid is refused', () async {
        await expectLater(
          complete(
            _claims(notBefore: _numericDate(const Duration(minutes: 5))),
          ),
          throwsKey('oauth.flow.id_token_not_yet_valid'),
        );
      });

      test('an nbf inside the skew is accepted', () async {
        final exchange = await complete(
          _claims(notBefore: _numericDate(const Duration(seconds: 30))),
        );
        expect(exchange.identity.subject, 'sub-1');
      });

      // `iat` is deliberately not a rejection: how old is too old is a
      // max-age policy this module does not take, and `exp` is the claim the
      // provider used to express its own answer.
      test('an old iat does not refuse a token that has not expired', () async {
        final exchange = await complete(
          _claims(issuedAt: _numericDate(const Duration(days: -1))),
        );
        expect(exchange.identity.subject, 'sub-1');
      });
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

    // The callback arriving with a *known* state but no code is what a provider
    // sends when the user declined at the consent screen and the provider is
    // sloppy enough to redirect anyway. It has to be distinguished from an
    // unknown state, which is a replay: the state is checked first, and the
    // empty code is only reached once it has passed.
    test('a callback with a known state but no code is refused', () async {
      final flow = _flow(_oidcProvider(), _StubTransport());
      final begun = await flow.beginAuthorization(_authorizationRequest());

      await expectLater(
        flow.completeAuthorization(code: '', state: begun.state),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.flow.missing_code',
          ),
        ),
      );
    });

    // Distinct from `no_claims_source`: the provider *has* a user-info
    // endpoint, so the fallback path is entered — and then has no bearer token
    // to present. Calling the endpoint unauthenticated would answer 401 and
    // report the provider's wording for a defect that is in the token response.
    test('a user-info provider that returns no access token fails before the '
        'second call', () async {
      final provider = _userInfoProvider();
      final transport = _StubTransport(
        tokenResponse: {'token_type': 'Bearer'},
        userInfo: {'id': 4711, 'login': 'octocat'},
      );
      final flow = _flow(provider, transport);
      final begun = await flow.beginAuthorization(
        _authorizationRequest(providerId: provider.id),
      );

      await expectLater(
        flow.completeAuthorization(code: 'c', state: begun.state),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.flow.no_access_token',
          ),
        ),
      );
      // The endpoint was never reached, which is the point of failing here.
      expect(transport.fetchedUri, isNull);
    });

    // A `200` carrying an HTML error page is the shape a proxy or a maintenance
    // window takes, and it is the one the decoder's diagnostics were written
    // for: a JSON parse failure ten frames down says nothing about which
    // provider call produced it.
    test(
      'a token response that is not JSON names the call that failed',
      () async {
        final flow = _flow(
          _oidcProvider(),
          _StubTransport(
            rawTokenBody: '<html><body>502 Bad Gateway</body></html>',
          ),
        );
        final begun = await flow.beginAuthorization(_authorizationRequest());

        await expectLater(
          flow.completeAuthorization(code: 'c', state: begun.state),
          throwsA(
            isA<TomOAuthException>()
                .having((e) => e.key, 'key', 'oauth.provider.malformed_json')
                .having(
                  (e) => e.toString(),
                  'message',
                  contains('code exchange response'),
                ),
          ),
        );
      },
    );

    // Well-formed JSON that is not an object: the second branch of the same
    // key. `jsonDecode` succeeds here, so nothing but the explicit type check
    // stands between a list and a cast failure further in.
    test('a token response that is a JSON array is refused', () async {
      final flow = _flow(_oidcProvider(), _StubTransport(rawTokenBody: '[]'));
      final begun = await flow.beginAuthorization(_authorizationRequest());

      await expectLater(
        flow.completeAuthorization(code: 'c', state: begun.state),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.provider.malformed_json',
          ),
        ),
      );
    });

    // Two calls can fail identically, and the key does not distinguish them.
    // Naming the call is the entire reason the decoder takes a `what`, so the
    // second call has to be shown saying something different from the first.
    test(
      'a malformed user-info response names that call, not the exchange',
      () async {
        final provider = _userInfoProvider();
        final flow = _flow(
          provider,
          _StubTransport(
            tokenResponse: {'access_token': 'at-9'},
            rawUserInfoBody: 'Service Unavailable',
          ),
        );
        final begun = await flow.beginAuthorization(
          _authorizationRequest(providerId: provider.id),
        );

        await expectLater(
          flow.completeAuthorization(code: 'c', state: begun.state),
          throwsA(
            isA<TomOAuthException>()
                .having((e) => e.key, 'key', 'oauth.provider.malformed_json')
                .having(
                  (e) => e.toString(),
                  'message',
                  contains('user-info response'),
                ),
          ),
        );
      },
    );
  });

  // ===========================================================================
  // THE LIVE TRANSPORT
  // ===========================================================================

  // Every other test in this file installs a stub, which is what makes the flow
  // testable at all — but it also means the one seam that actually speaks HTTP
  // is the one seam none of them exercise. Its whole contract is that a non-2xx
  // becomes a keyed exception carrying the provider's own body, and getting
  // that wrong turns every provider misconfiguration into an unhandled
  // `ClientException` with no key to branch on. A loopback server is enough to
  // pin it, and keeps the test hermetic.
  group('TomHttpOAuthTokenTransport', () {
    late HttpServer server;
    late Uri endpoint;
    late int status;
    late String body;

    setUp(() async {
      status = 500;
      body = '{"error":"invalid_client"}';
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      endpoint = Uri.parse('http://127.0.0.1:${server.port}/token');
      unawaited(
        server.forEach((request) async {
          await request.drain<void>();
          request.response.statusCode = status;
          request.response.write(body);
          await request.response.close();
        }),
      );
    });

    tearDown(() => server.close(force: true));

    test(
      'a non-2xx POST is a keyed failure carrying the provider body',
      () async {
        await expectLater(
          const TomHttpOAuthTokenTransport().postForm(endpoint, const {
            'grant_type': 'authorization_code',
          }, const {}),
          throwsA(
            isA<TomOAuthException>()
                .having((e) => e.key, 'key', 'oauth.provider.http_error')
                // The body is the only thing that says *why*, so its absence
                // would leave a misconfigured client id undiagnosable.
                .having(
                  (e) => e.toString(),
                  'message',
                  allOf(contains('500'), contains('invalid_client')),
                ),
          ),
        );
      },
    );

    test('a non-2xx GET fails the same way', () async {
      status = 403;
      await expectLater(
        const TomHttpOAuthTokenTransport().getJson(endpoint, const {}),
        throwsA(
          isA<TomOAuthException>()
              .having((e) => e.key, 'key', 'oauth.provider.http_error')
              .having((e) => e.toString(), 'message', contains('403')),
        ),
      );
    });

    // The failure is server-side by construction: the body it carries is the
    // provider's, and forwarding a provider's error text to a browser is how a
    // client id leaks into a bug report.
    test('the failure does not travel to the client', () async {
      try {
        await const TomHttpOAuthTokenTransport().getJson(endpoint, const {});
        fail('expected a TomOAuthException');
      } on TomOAuthException catch (ex) {
        expect(ex.clientThrow, isFalse);
      }
    });

    test('a 2xx answers the body verbatim', () async {
      status = 200;
      body = '{"access_token":"at-live"}';
      expect(
        await const TomHttpOAuthTokenTransport().getJson(endpoint, const {}),
        '{"access_token":"at-live"}',
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

    // Nothing a caller got back is a way into the store: not the list, and not
    // the entities in it. The persistent store cannot alias its rows even if it
    // wanted to -- every read materialises fresh entities out of the database --
    // so a memory store that handed out what it holds would differ from it on
    // exactly the point a test cannot see, and the test would pass for a reason
    // that does not hold in production.
    test('identitiesOf hands out snapshots, not the stored rows', () async {
      final store = TomMemoryExternalIdentityStore();
      await store.link(alice, 'alice');

      final rows = await store.identitiesOf('alice');
      expect(() => rows.add(TomExternalIdentityLink()), throwsUnsupportedError);

      rows.single
        ..localUsername = 'mallory'
        ..displayName = 'Someone Else'
        ..lastLoginAt = DateTime.utc(2020);

      expect(await store.localUsernameFor(alice), 'alice');
      expect(await store.identitiesOf('mallory'), isEmpty);
      final stored = (await store.identitiesOf('alice')).single;
      expect(stored.localUsername, 'alice');
      expect(stored.displayName, 'Alice');
      expect(stored.lastLoginAt, isNull);
    });

    // A snapshot per call, not one snapshot cached and shared: two callers
    // holding the same instance is the same aliasing bug one level out.
    test('every identitiesOf call answers fresh instances', () async {
      final store = TomMemoryExternalIdentityStore();
      await store.link(alice, 'alice');
      final first = (await store.identitiesOf('alice')).single;
      final second = (await store.identitiesOf('alice')).single;
      expect(identical(first, second), isFalse);
      expect(second.subject, first.subject);
      expect(second.linkedAt, first.linkedAt);
    });

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
  // PROVIDER TOKEN RETENTION
  // ===========================================================================
  //
  // Delegated authorization, not authentication: what the framework may *do* as
  // the user at a third party, rather than who the user is. The framework's
  // position is that it holds nothing unless a provider opts in — so the tests
  // that matter most here are the ones asserting the *absence* of a stored
  // credential, and the one asserting a stored credential dies with its link.

  group('TomOAuthTokenGrant', () {
    test('turns the provider expires_in into an instant', () {
      final at = DateTime.utc(2026, 5, 6, 7, 8, 9);
      final grant = TomOAuthTokenGrant.fromTokenResponse(const {
        'access_token': 'at-1',
        'refresh_token': 'rt-1',
        'token_type': 'Bearer',
        'scope': 'calendar.read',
        'expires_in': 3600,
      }, now: at);

      expect(grant.accessToken, 'at-1');
      expect(grant.refreshToken, 'rt-1');
      expect(grant.scope, 'calendar.read');
      expect(grant.obtainedAt, at);
      expect(grant.expiresAt, at.add(const Duration(hours: 1)));
    });

    // A few providers send the lifetime as a string; a lifetime nobody can
    // parse is treated as unstated rather than as already expired.
    test(
      'accepts a numeric-string lifetime and ignores an unparseable one',
      () {
        final at = DateTime.utc(2026, 5, 6);
        expect(
          TomOAuthTokenGrant.fromTokenResponse(const {
            'access_token': 'at-1',
            'expires_in': '900',
          }, now: at).expiresAt,
          at.add(const Duration(minutes: 15)),
        );
        expect(
          TomOAuthTokenGrant.fromTokenResponse(const {
            'access_token': 'at-1',
            'expires_in': 'soon',
          }, now: at).expiresAt,
          isNull,
        );
      },
    );

    // RFC 6749 §6: omitting `refresh_token` from a refresh response means "keep
    // the one you have". Taking the omission literally would discard the
    // long-lived credential on the first refresh and work perfectly until the
    // access token expired.
    test('a refresh response that omits the refresh token keeps it', () {
      final previous = TomOAuthTokenGrant(
        accessToken: 'at-1',
        refreshToken: 'rt-1',
        scope: 'calendar.read',
      );
      final refreshed = TomOAuthTokenGrant.fromTokenResponse(const {
        'access_token': 'at-2',
      }, previous: previous);

      expect(refreshed.accessToken, 'at-2');
      expect(refreshed.refreshToken, 'rt-1');
      expect(refreshed.scope, 'calendar.read');
    });

    // The question a caller has is not "is it valid now?" but "will it still be
    // valid when the request arrives?".
    test('expiresWithin answers for the moment the token will be used', () {
      final now = DateTime.utc(2026, 5, 6, 12);
      final grant = TomOAuthTokenGrant(
        accessToken: 'at-1',
        expiresAt: now.add(const Duration(seconds: 20)),
      );

      expect(grant.isExpired(now), isFalse);
      expect(grant.expiresWithin(const Duration(seconds: 10), now), isFalse);
      expect(grant.expiresWithin(const Duration(seconds: 30), now), isTrue);
    });

    // The provider said nothing about a lifetime; guessing one throws away a
    // working token.
    test('a grant with no declared lifetime never expires', () {
      final grant = TomOAuthTokenGrant(accessToken: 'at-1');
      expect(grant.isExpired(), isFalse);
      expect(grant.expiresWithin(const Duration(days: 365)), isFalse);
    });

    // This value reaches log lines, and both fields are bearer credentials.
    test('toString names the grant without printing either token', () {
      final text = TomOAuthTokenGrant(
        accessToken: 'at-secret',
        refreshToken: 'rt-secret',
        scope: 'calendar.read',
      ).toString();

      expect(text, isNot(contains('at-secret')));
      expect(text, isNot(contains('rt-secret')));
      expect(text, contains('refreshable'));
      expect(text, contains('calendar.read'));
    });

    test('survives the JSON round trip that storage uses', () {
      final grant = TomOAuthTokenGrant(
        accessToken: 'at-1',
        refreshToken: 'rt-1',
        tokenType: 'Bearer',
        scope: 'calendar.read mail.send',
        expiresAt: DateTime.utc(2026, 5, 6, 8),
        obtainedAt: DateTime.utc(2026, 5, 6, 7),
      );

      final read = TomOAuthTokenGrant.fromJson(
        jsonDecode(jsonEncode(grant.toJson())),
      )!;

      expect(read.accessToken, grant.accessToken);
      expect(read.refreshToken, grant.refreshToken);
      expect(read.tokenType, grant.tokenType);
      expect(read.scope, grant.scope);
      expect(read.expiresAt, grant.expiresAt);
      expect(read.obtainedAt, grant.obtainedAt);
    });

    // A row written under a key that has since been rotated away decodes to
    // rubbish, and "the user granted nothing" is the only sane reading of it.
    test('fromJson refuses a payload that carries no access token', () {
      expect(TomOAuthTokenGrant.fromJson(null), isNull);
      expect(TomOAuthTokenGrant.fromJson('not json'), isNull);
      expect(
        TomOAuthTokenGrant.fromJson(const {'tokenType': 'Bearer'}),
        isNull,
      );
      expect(TomOAuthTokenGrant.fromJson(const {'accessToken': ''}), isNull);
    });
  });

  group('TomOAuthTokenStore', () {
    test('stores, reads back and deletes a grant', () async {
      final store = TomMemoryOAuthTokenStore();
      expect(await store.read(_issuer, 'sub-1'), isNull);

      await store.store(
        _issuer,
        'sub-1',
        TomOAuthTokenGrant(accessToken: 'at-1', refreshToken: 'rt-1'),
      );
      expect((await store.read(_issuer, 'sub-1'))!.accessToken, 'at-1');

      await store.delete(_issuer, 'sub-1');
      expect(await store.read(_issuer, 'sub-1'), isNull);
    });

    // The subject is unique only within its issuer, exactly as for the link.
    test('the key is the (issuer, subject) pair, not the subject', () async {
      final store = TomMemoryOAuthTokenStore();
      await store.store(_issuer, 'sub-1', TomOAuthTokenGrant(accessToken: 'a'));
      expect(await store.read('https://other.example.test', 'sub-1'), isNull);
    });

    // A second grant for the same identity would make which credential an
    // application presents depend on row order — and the older row is by
    // definition the one whose refresh token may already have been rotated away.
    test('the entity DDL keys the pair uniquely', () {
      expect(
        TomExternalIdentityToken.createTableSql,
        contains(
          'UNIQUE KEY uq_tom_external_identity_token (issuer, '
          'subject)',
        ),
      );
    });

    // No store installed is the ordinary state, and the safe one: nothing can
    // be written where there is nowhere to write it.
    test('resolves to null when no store bean is installed', () {
      expect(TomOAuthTokenStore.resolve(), isNull);
    });
  });

  group('TomOAuthFlow provider tokens', () {
    /// A provider that opts in to retention, optionally with extra
    /// authorization parameters.
    TomOAuthProviderConfig delegating({
      Map<String, String> authorizationParameters = const {},
    }) => TomOAuthProviderConfig(
      id: 'stub',
      issuer: _issuer,
      authorizationEndpoint: '$_issuer/authorize',
      tokenEndpoint: '$_issuer/token',
      clientId: _clientId,
      clientSecret: 'sh-sh-secret',
      redirectUri: 'https://app.example.test/oauth/callback',
      scopes: const ['openid', 'email'],
      storeTokens: true,
      authorizationParameters: authorizationParameters,
    );

    /// The token response of a provider that also delegated something.
    Map<String, Object?> delegatingResponse({
      String accessToken = 'at-1',
      String? refreshToken = 'rt-1',
      Object? expiresIn = 3600,
    }) => <String, Object?>{
      'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      'token_type': 'Bearer',
      'scope': 'openid email',
      if (expiresIn != null) 'expires_in': expiresIn,
      'id_token': _idToken(_claims()),
    };

    /// Runs the handshake to the point where the exchange is available.
    Future<TomOAuthExchange> complete(
      TomOAuthProviderConfig provider,
      _StubTransport transport,
    ) async {
      final flow = _flow(provider, transport);
      final begun = await flow.beginAuthorization(_authorizationRequest());
      return flow.completeAuthorization(code: 'c', state: begun.state);
    }

    // Always surfaced, so "keeps nothing" is a retention decision rather than a
    // capability the framework withholds: a caller that wants to use the grant
    // for the duration of this request may, without any store at all.
    test('completeAuthorization surfaces the provider grant', () async {
      final exchange = await complete(
        _oidcProvider(),
        _StubTransport(tokenResponse: delegatingResponse()),
      );

      expect(exchange.tokens, isNotNull);
      expect(exchange.tokens!.accessToken, 'at-1');
      expect(exchange.tokens!.refreshToken, 'rt-1');
      expect(exchange.tokens!.scope, 'openid email');
    });

    // An OIDC provider that answered with an `id_token` alone authenticated the
    // user and delegated nothing; an empty bearer token is not a grant.
    test('an id_token-only response surfaces no grant', () async {
      final exchange = await complete(
        _oidcProvider(),
        _StubTransport(
          tokenResponse: <String, Object?>{'id_token': _idToken(_claims())},
        ),
      );
      expect(exchange.tokens, isNull);
    });

    // Opting in on Google without `access_type=offline` yields no refresh token
    // at all, so the opt-in needs a way to say what the provider requires.
    test('configured authorization parameters reach the redirect', () async {
      final flow = _flow(
        delegating(
          authorizationParameters: const {
            'access_type': 'offline',
            'prompt': 'consent',
          },
        ),
        _StubTransport(),
      );

      final uri = Uri.parse(
        (await flow.beginAuthorization(
          _authorizationRequest(),
        )).authorizationUri,
      );

      expect(uri.queryParameters['access_type'], 'offline');
      expect(uri.queryParameters['prompt'], 'consent');
    });

    // Configured extras are applied before the flow's own parameters, so a typo
    // in deployment configuration cannot unpick the CSRF handle or send the
    // provider's redirect somewhere else.
    test(
      'a configured parameter cannot override the flow parameters',
      () async {
        final flow = _flow(
          delegating(
            authorizationParameters: const {
              'state': 'attacker-chosen',
              'redirect_uri': 'https://evil.example.test/collect',
            },
          ),
          _StubTransport(),
        );

        final dto = await flow.beginAuthorization(_authorizationRequest());
        final uri = Uri.parse(dto.authorizationUri);

        expect(uri.queryParameters['state'], dto.state);
        expect(uri.queryParameters['state'], isNot('attacker-chosen'));
        expect(
          uri.queryParameters['redirect_uri'],
          'https://app.example.test/oauth/callback',
        );
      },
    );

    // Refreshing is not a login. The proof is that it works with no
    // authorization state, no code, no PKCE verifier and no directory — none of
    // which a login can do without — and answers a grant rather than a
    // principal.
    test('refreshGrant renews a token without running a login', () async {
      final transport = _StubTransport(
        tokenResponse: <String, Object?>{
          'access_token': 'at-2',
          'token_type': 'Bearer',
          'expires_in': 3600,
        },
      );
      final flow = _flow(delegating(), transport);

      final refreshed = await flow.refreshGrant(
        providerId: 'stub',
        grant: TomOAuthTokenGrant(
          accessToken: 'at-1',
          refreshToken: 'rt-1',
          scope: 'openid email',
        ),
      );

      expect(refreshed, isA<TomOAuthTokenGrant>());
      expect(refreshed.accessToken, 'at-2');
      // Kept, because the provider omitted it.
      expect(refreshed.refreshToken, 'rt-1');

      expect(transport.postedForm!['grant_type'], 'refresh_token');
      expect(transport.postedForm!['refresh_token'], 'rt-1');
      expect(transport.postedForm!['scope'], 'openid email');
      expect(transport.postedForm, isNot(contains('code')));
      expect(transport.postedForm, isNot(contains('code_verifier')));
    });

    // The caller cannot recover by retrying; it has to send the user through
    // consent again, which is a different action rather than a slower one.
    test('refreshGrant refuses a grant with no refresh token', () async {
      final flow = _flow(delegating(), _StubTransport());
      await expectLater(
        flow.refreshGrant(
          providerId: 'stub',
          grant: TomOAuthTokenGrant(accessToken: 'at-1'),
        ),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.flow.no_refresh_token',
          ),
        ),
      );
    });

    test('accessTokenFor answers the held token while it is live', () async {
      final transport = _StubTransport();
      final flow = _flow(delegating(), transport);
      final store = TomMemoryOAuthTokenStore();
      await store.store(
        _issuer,
        'sub-1',
        TomOAuthTokenGrant(
          accessToken: 'at-1',
          refreshToken: 'rt-1',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );

      final live = await flow.accessTokenFor(
        providerId: 'stub',
        subject: 'sub-1',
        store: store,
      );

      expect(live!.accessToken, 'at-1');
      // A live token must not cost a round trip; a caller that refreshed on
      // every call would meet the provider's rate limiter.
      expect(transport.postedForm, isNull);
    });

    test(
      'accessTokenFor refreshes near expiry and writes the result back',
      () async {
        final transport = _StubTransport(
          tokenResponse: <String, Object?>{
            'access_token': 'at-2',
            'token_type': 'Bearer',
            'expires_in': 3600,
          },
        );
        final flow = _flow(delegating(), transport);
        final store = TomMemoryOAuthTokenStore();
        await store.store(
          _issuer,
          'sub-1',
          TomOAuthTokenGrant(
            accessToken: 'at-1',
            refreshToken: 'rt-1',
            expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 5)),
          ),
        );

        final live = await flow.accessTokenFor(
          providerId: 'stub',
          subject: 'sub-1',
          store: store,
        );

        expect(live!.accessToken, 'at-2');
        expect(transport.postedForm!['grant_type'], 'refresh_token');
        // Written back, or the next call refreshes again and the one after that.
        expect((await store.read(_issuer, 'sub-1'))!.accessToken, 'at-2');
      },
    );

    test('accessTokenFor answers null when nothing is held', () async {
      final flow = _flow(delegating(), _StubTransport());
      expect(
        await flow.accessTokenFor(
          providerId: 'stub',
          subject: 'sub-1',
          store: TomMemoryOAuthTokenStore(),
        ),
        isNull,
      );
    });

    // The deployment's cue to send the user through consent again — and the
    // dead row goes with the answer, because a grant that can never mint a
    // token again is not a credential this deployment holds.
    test('accessTokenFor answers null for an unrefreshable expired grant, and '
        'purges it', () async {
      final flow = _flow(delegating(), _StubTransport());
      final store = TomMemoryOAuthTokenStore();
      await store.store(
        _issuer,
        'sub-1',
        TomOAuthTokenGrant(
          accessToken: 'at-1',
          expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        ),
      );

      expect(
        await flow.accessTokenFor(
          providerId: 'stub',
          subject: 'sub-1',
          store: store,
        ),
        isNull,
      );
      expect(await store.read(_issuer, 'sub-1'), isNull);
    });

    // A grant the provider gave no lifetime for is not dead — it is unknown,
    // and guessing would throw away a token that still works.
    test('accessTokenFor keeps a grant that declares no expiry', () async {
      final flow = _flow(delegating(), _StubTransport());
      final store = TomMemoryOAuthTokenStore();
      await store.store(
        _issuer,
        'sub-1',
        TomOAuthTokenGrant(accessToken: 'at-forever'),
      );

      final live = await flow.accessTokenFor(
        providerId: 'stub',
        subject: 'sub-1',
        store: store,
      );
      expect(live?.accessToken, 'at-forever');
      expect(await store.read(_issuer, 'sub-1'), isNotNull);
    });

    // The contrast that makes the purge safe to reason about: a *rejected*
    // refresh is not proof the grant is dead. A provider outage answering
    // `invalid_grant` must not destroy a credential a retry would have used, so
    // that path throws and leaves the row alone.
    test('a rejected refresh throws and keeps the grant', () async {
      final flow = _flow(
        delegating(),
        _StubTransport(tokenResponse: {'error': 'temporarily_unavailable'}),
      );
      final store = TomMemoryOAuthTokenStore();
      await store.store(
        _issuer,
        'sub-1',
        TomOAuthTokenGrant(
          accessToken: 'at-1',
          refreshToken: 'rt-1',
          expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        ),
      );

      await expectLater(
        flow.accessTokenFor(providerId: 'stub', subject: 'sub-1', store: store),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.flow.token_exchange_rejected',
          ),
        ),
      );
      expect(await store.read(_issuer, 'sub-1'), isNotNull);
    });

    // Idempotent: the second caller to find the same dead grant must not fail
    // because the first already removed it.
    test('a dead grant purged twice is not an error', () async {
      final flow = _flow(delegating(), _StubTransport());
      final store = TomMemoryOAuthTokenStore();
      await store.store(
        _issuer,
        'sub-1',
        TomOAuthTokenGrant(
          accessToken: 'at-1',
          expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        ),
      );

      Future<TomOAuthTokenGrant?> ask() => flow.accessTokenFor(
        providerId: 'stub',
        subject: 'sub-1',
        store: store,
      );
      expect(await ask(), isNull);
      expect(await ask(), isNull);
    });
  });

  group('provider token retention', () {
    /// Runs a whole external login, answering the token store it ran against.
    Future<TomMemoryOAuthTokenStore> login({
      required bool storeTokens,
      required TomExternalIdentityStore identityStore,
      TomMemoryOAuthTokenStore? tokenStore,
    }) async {
      final flow = _flow(
        TomOAuthProviderConfig(
          id: 'stub',
          issuer: _issuer,
          authorizationEndpoint: '$_issuer/authorize',
          tokenEndpoint: '$_issuer/token',
          clientId: _clientId,
          redirectUri: 'https://app.example.test/oauth/callback',
          storeTokens: storeTokens,
        ),
        _StubTransport(
          tokenResponse: <String, Object?>{
            'access_token': 'at-1',
            'refresh_token': 'rt-1',
            'token_type': 'Bearer',
            'expires_in': 3600,
            'id_token': _idToken(_claims()),
          },
        ),
      );
      final tokens = tokenStore ?? TomMemoryOAuthTokenStore();
      final begun = await flow.beginAuthorization(_authorizationRequest());
      final service = TomOAuthAuthenticationService(
        directory: _StubDirectory(accounts: {'alice'}),
        flow: flow,
        identityStore: identityStore,
        tokenStore: tokens,
      );
      final data = _authData()
        ..key = TomOAuthCredential(code: 'c', state: begun.state);
      await service.authenticateUser(data);
      return tokens;
    }

    Future<TomMemoryExternalIdentityStore> linkedStore(
      TomOAuthTokenStore tokens,
    ) async {
      final store = TomMemoryExternalIdentityStore(tokenStore: tokens);
      await store.link(
        const TomExternalIdentity(issuer: _issuer, subject: 'sub-1'),
        'alice',
      );
      return store;
    }

    // The framework's position, asserted rather than merely written down: a
    // deployment that only wants "Sign in with …" never acquires a third-party
    // credential it did not ask for, even with a store installed.
    test('a provider that did not opt in has nothing retained', () async {
      final tokens = TomMemoryOAuthTokenStore();
      await login(
        storeTokens: false,
        identityStore: await linkedStore(tokens),
        tokenStore: tokens,
      );
      expect(await tokens.read(_issuer, 'sub-1'), isNull);
    });

    test('a provider that opts in has its grant retained', () async {
      final tokens = TomMemoryOAuthTokenStore();
      await login(
        storeTokens: true,
        identityStore: await linkedStore(tokens),
        tokenStore: tokens,
      );

      final held = await tokens.read(_issuer, 'sub-1');
      expect(held, isNotNull);
      expect(held!.accessToken, 'at-1');
      expect(held.refreshToken, 'rt-1');
      expect(held.expiresAt, isNotNull);
    });

    // The retention bound: a third-party credential must never outlive the link
    // it was granted through, and this is the method that makes that true.
    test('unlinking an identity deletes the grant with it', () async {
      final tokens = TomMemoryOAuthTokenStore();
      final identities = await linkedStore(tokens);
      await login(
        storeTokens: true,
        identityStore: identities,
        tokenStore: tokens,
      );
      expect(await tokens.read(_issuer, 'sub-1'), isNotNull);

      await identities.unlink(_issuer, 'sub-1');

      expect(await tokens.read(_issuer, 'sub-1'), isNull);
      expect(
        await identities.localUsernameFor(
          const TomExternalIdentity(issuer: _issuer, subject: 'sub-1'),
        ),
        isNull,
      );
    });

    // Unlinking an identity nobody linked is a no-op, not an error: a cascade
    // that threw would make deleting an account depend on the order it was
    // taken apart in.
    test('unlinking an identity that was never linked is a no-op', () async {
      final tokens = TomMemoryOAuthTokenStore();
      final identities = TomMemoryExternalIdentityStore(tokenStore: tokens);
      await identities.unlink(_issuer, 'nobody');
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
          isA<TomLoginException>().having(
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
          isA<TomLoginException>().having(
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
          isA<TomLoginException>().having(
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
            isA<TomLoginException>().having(
              (e) => e.key,
              'key',
              'login.error.oauth.provisioning-unsupported',
            ),
          ),
        );
      },
    );

    // The test above refuses through the stub's own override. This one calls
    // the framework's default -- what a deployment actually meets when it turns
    // auto-provisioning on and implements only the lookup -- and asserts *how*
    // it refuses. Declaring a `Future` and throwing out of the call are
    // different contracts: a caller that only ever awaits would never see the
    // second, and would take the throw past every handler it had installed.
    test('the default provisioning refusal is the future, not the call', () {
      final directory = _LookupOnlyDirectory();

      late final Future<TomAuthenticationInfo> pending;
      expect(
        () => pending = directory.provisionFromExternalIdentity(
          const TomExternalIdentity(issuer: _issuer, subject: 'sub-1'),
          _authData(),
        ),
        returnsNormally,
        reason: 'a Future-returning method must not throw synchronously',
      );
      expect(
        pending,
        throwsA(
          isA<TomLoginException>().having(
            (e) => e.key,
            'key',
            'login.error.oauth.provisioning-unsupported',
          ),
        ),
      );
    });

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
          isA<TomLoginException>().having(
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
            isA<TomLoginException>().having(
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

    // -------------------------------------------------------------------
    // ONE LOGIN, ONE PROVIDER
    // -------------------------------------------------------------------

    // A login makes two separate decisions out of provider configuration --
    // whether to provision, and whether to keep the grant -- at two points far
    // enough apart that they could be taken from *different* providers. With
    // two registrations sharing an issuer they once were: the provisioning
    // decision followed whichever the configuration listed first, while the
    // retention decision followed the one the user actually authorized
    // against. These tests hold both to the second.
    group('two providers sharing an issuer', () {
      /// Runs a whole login begun against [providerId], with [providers]
      /// configured in the order given.
      Future<TomAuthenticationInfo> loginAgainst({
        required List<TomOAuthProviderConfig> providers,
        required String providerId,
        required _StubDirectory directory,
        required TomExternalIdentityStore store,
        TomOAuthTokenStore? tokenStore,
      }) async {
        final flow = _multiProviderFlow(
          providers,
          _StubTransport(
            tokenResponse: <String, Object?>{
              'access_token': 'at-1',
              'refresh_token': 'rt-1',
              'token_type': 'Bearer',
              'expires_in': 3600,
              'id_token': _idToken(_claims()),
            },
          ),
        );
        final begun = await flow.beginAuthorization(
          _authorizationRequest(providerId: providerId),
        );
        final service = TomOAuthAuthenticationService(
          directory: directory,
          flow: flow,
          identityStore: store,
          tokenStore: tokenStore,
        );
        return service.authenticateUser(
          _authData()..key = TomOAuthCredential(code: 'c', state: begun.state),
        );
      }

      test('provisioning and retention are both taken from the provider the '
          'user authorized against', () async {
        final tokens = TomMemoryOAuthTokenStore();
        final store = TomMemoryExternalIdentityStore(tokenStore: tokens);
        final directory = _StubDirectory(canProvision: true);

        final info = await loginAgainst(
          providers: [
            _twinProvider(
              id: 'restricted',
              provisioning: TomOAuthProvisioning.refuse,
            ),
            _twinProvider(
              id: 'full',
              provisioning: TomOAuthProvisioning.autoProvision,
              storeTokens: true,
            ),
          ],
          providerId: 'full',
          directory: directory,
          store: store,
          tokenStore: tokens,
        );

        // Provisioning: `full` allows it, and it is not the first configured.
        expect(info.principal.user.username, 'alice@example.test');
        expect(directory.provisioned.single.subject, 'sub-1');
        // Retention: `full` asks for it, and the same login kept the grant.
        expect((await tokens.read(_issuer, 'sub-1'))?.accessToken, 'at-1');
      });

      // The mirror, and the half that a first-match resolution gets wrong in
      // the more dangerous direction: it would admit -- and provision -- a user
      // the authorized-against provider was configured to refuse.
      test('the restricted twin still refuses, though a permissive one is '
          'configured against the same issuer', () async {
        final tokens = TomMemoryOAuthTokenStore();
        final store = TomMemoryExternalIdentityStore(tokenStore: tokens);
        final directory = _StubDirectory(canProvision: true);

        await expectLater(
          loginAgainst(
            providers: [
              _twinProvider(
                id: 'full',
                provisioning: TomOAuthProvisioning.autoProvision,
                storeTokens: true,
              ),
              _twinProvider(
                id: 'restricted',
                provisioning: TomOAuthProvisioning.refuse,
              ),
            ],
            providerId: 'restricted',
            directory: directory,
            store: store,
            tokenStore: tokens,
          ),
          throwsA(
            isA<TomLoginException>().having(
              (e) => e.key,
              'key',
              'login.error.oauth.no-local-account',
            ),
          ),
        );
        expect(directory.provisioned, isEmpty);
        expect(await tokens.read(_issuer, 'sub-1'), isNull);
      });

      // Retention is opt-in per registration, so the twin that did not ask for
      // it must not inherit the opt-in of the one beside it.
      test('a twin that did not opt into retention keeps nothing', () async {
        final tokens = TomMemoryOAuthTokenStore();
        final store = TomMemoryExternalIdentityStore(tokenStore: tokens);

        await loginAgainst(
          providers: [
            _twinProvider(
              id: 'delegating',
              provisioning: TomOAuthProvisioning.autoProvision,
              storeTokens: true,
            ),
            _twinProvider(
              id: 'sign-in-only',
              provisioning: TomOAuthProvisioning.autoProvision,
            ),
          ],
          providerId: 'sign-in-only',
          directory: _StubDirectory(canProvision: true),
          store: store,
          tokenStore: tokens,
        );

        expect(await tokens.read(_issuer, 'sub-1'), isNull);
      });
    });
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

    // The policy has to apply to an externally-authenticated principal too,
    // and it does for a reason worth stating: nothing on the external path
    // knows there is a policy. An external path that reimplemented the
    // decision would be free to reach a different one.
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
  // REVOCATION
  // ===========================================================================

  group('revoking a grant at the provider', () {
    // Unlinking deleted the framework's copy of the credential and told the
    // provider nothing, so a user who pressed disconnect had the deployment
    // forget a token that went on working — for a refresh token, possibly for
    // months, in every copy taken before the unlink.
    TomOAuthTokenGrant grant({String? refreshToken = 'rt-1'}) =>
        TomOAuthTokenGrant(
          accessToken: 'at-1',
          refreshToken: refreshToken,
          obtainedAt: DateTime.now().toUtc(),
        );

    TomOAuthFlow flowOver(
      TomOAuthProviderConfig provider,
      _StubTransport transport,
    ) => TomOAuthFlow(
      providers: TomOAuthProviders({provider.id: provider}),
      stateStore: TomOAuthMemoryStateStore(),
      transport: transport,
    );

    test('the endpoint is read from the provider configuration', () {
      final configured = TomOAuthProviders.fromConfiguration(
        TomServerConfigResourceProvider.from({
          'oauth': {
            'providers': {
              'idp': {
                'issuer': _issuer,
                'authorizationEndpoint': '$_issuer/authorize',
                'tokenEndpoint': '$_issuer/token',
                'revocationEndpoint': '$_issuer/revoke',
                'clientId': _clientId,
                'redirectUri': 'https://app.example.test/oauth/callback',
              },
            },
          },
        }),
      );

      expect(configured['idp'].revocationEndpoint, '$_issuer/revoke');
    });

    test('a provider that configures none reads null, not empty', () {
      // Absent is the majority case and has to stay distinguishable from
      // configured-but-blank, which is a configuration error rather than a
      // provider without revocation.
      expect(_oidcProvider().revocationEndpoint, isNull);
    });

    test('the refresh token is what is revoked, by RFC 7009', () async {
      // Revoking the refresh token revokes the chain: an access token outlives
      // it by minutes, where a refresh token outlives the unlink by months.
      final transport = _StubTransport()..formResponse = '';
      final flow = flowOver(
        _oidcProvider(revocationEndpoint: '$_issuer/revoke'),
        transport,
      );

      final revoked = await flow.revokeGrant(
        providerId: 'stub',
        grant: grant(),
      );

      expect(revoked, isTrue);
      expect(transport.postedUri.toString(), '$_issuer/revoke');
      expect(transport.postedForm!['token'], 'rt-1');
      expect(transport.postedForm!['token_type_hint'], 'refresh_token');
      expect(
        transport.postedHeaders!['Authorization'],
        startsWith('Basic '),
        reason:
            'a revocation is a client-authenticated call like the exchange — '
            'without it a provider cannot tell who is asking',
      );
    });

    test('a grant with no refresh token revokes the access token', () async {
      final transport = _StubTransport()..formResponse = '';
      final flow = flowOver(
        _oidcProvider(revocationEndpoint: '$_issuer/revoke'),
        transport,
      );

      await flow.revokeGrant(
        providerId: 'stub',
        grant: grant(refreshToken: null),
      );

      expect(transport.postedForm!['token'], 'at-1');
      expect(transport.postedForm!['token_type_hint'], 'access_token');
    });

    test('a provider with no revocation endpoint is not called', () async {
      final transport = _StubTransport();
      final flow = flowOver(_oidcProvider(), transport);

      expect(
        await flow.revokeGrant(providerId: 'stub', grant: grant()),
        isFalse,
        reason:
            'false says nothing was asked, which is different from asked and '
            'refused — the caller logs one and worries about the other',
      );
      expect(transport.calls, isZero);
    });

    test('a provider that refuses says so', () async {
      final transport = _StubTransport()
        ..formResponse = '{"error":"unsupported_token_type"}';
      final flow = flowOver(
        _oidcProvider(revocationEndpoint: '$_issuer/revoke'),
        transport,
      );

      await expectLater(
        flow.revokeGrant(providerId: 'stub', grant: grant()),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.flow.revocation_rejected',
          ),
        ),
      );
    });

    test('an empty answer is the success RFC 7009 specifies', () async {
      final transport = _StubTransport()..formResponse = '   ';
      final flow = flowOver(
        _oidcProvider(revocationEndpoint: '$_issuer/revoke'),
        transport,
      );

      expect(
        await flow.revokeGrant(providerId: 'stub', grant: grant()),
        isTrue,
      );
    });

    group('unlinking revokes first, and unlinks regardless', () {
      late _StubTransport transport;
      late TomMemoryOAuthTokenStore tokens;
      late TomMemoryExternalIdentityStore identities;

      setUp(() async {
        TomBean.resetBeanContext();
        transport = _StubTransport()..formResponse = '';
        tokens = TomMemoryOAuthTokenStore();
        identities = TomMemoryExternalIdentityStore(tokenStore: tokens);
        await identities.link(
          const TomExternalIdentity(issuer: _issuer, subject: 'sub-1'),
          'alice',
        );
        await tokens.store(
          _issuer,
          'sub-1',
          TomOAuthTokenGrant(
            accessToken: 'at-1',
            refreshToken: 'rt-1',
            obtainedAt: DateTime.now().toUtc(),
          ),
        );
      });

      tearDown(TomBean.resetBeanContext);

      test('the provider is told before the grant is forgotten', () async {
        TomBean.withType(
          TomOAuthProviders,
          TomOAuthProviders({
            'stub': _oidcProvider(revocationEndpoint: '$_issuer/revoke'),
          }),
        );
        TomBean.withType(TomOAuthTokenTransport, transport);

        await identities.unlink(_issuer, 'sub-1');

        expect(
          transport.postedForm!['token'],
          'rt-1',
          reason:
              'the grant has to still be readable when the provider is asked, '
              'so the revocation precedes the deletion',
        );
        expect(await tokens.read(_issuer, 'sub-1'), isNull);
        expect(
          await identities.localUsernameFor(
            const TomExternalIdentity(issuer: _issuer, subject: 'sub-1'),
          ),
          isNull,
        );
      });

      test('a provider that cannot be reached does not keep the link', () async {
        // The safety property. Refusing to unlink because the provider is down
        // would leave the deployment holding the credential it was told to
        // drop — the opposite of what the user asked for.
        TomBean.withType(
          TomOAuthProviders,
          TomOAuthProviders({
            'stub': _oidcProvider(revocationEndpoint: '$_issuer/revoke'),
          }),
        );
        TomBean.withType(
          TomOAuthTokenTransport,
          _ThrowingTransport(StateError('provider unreachable')),
        );

        await identities.unlink(_issuer, 'sub-1');

        expect(await tokens.read(_issuer, 'sub-1'), isNull);
        expect(
          await identities.localUsernameFor(
            const TomExternalIdentity(issuer: _issuer, subject: 'sub-1'),
          ),
          isNull,
        );
      });

      test('every registration sharing the issuer is asked', () async {
        // Two registrations against one IdP is a shape the module already
        // supports, and the token store is keyed by issuer rather than by
        // registration — so which client credentials minted this grant is not
        // recorded. Asking both is what makes the revocation reliable; RFC
        // 7009 makes an unknown token a success, so the extra call is free.
        TomBean.withType(
          TomOAuthProviders,
          TomOAuthProviders({
            'stub': _oidcProvider(revocationEndpoint: '$_issuer/revoke'),
            'second': _oidcProvider(
              id: 'second',
              revocationEndpoint: '$_issuer/revoke-2',
            ),
          }),
        );
        TomBean.withType(TomOAuthTokenTransport, transport);

        await identities.unlink(_issuer, 'sub-1');

        expect(transport.calls, 2);
      });

      test('no configured revocation endpoint is not a failure', () async {
        TomBean.withType(
          TomOAuthProviders,
          TomOAuthProviders({'stub': _oidcProvider()}),
        );
        TomBean.withType(TomOAuthTokenTransport, transport);

        await identities.unlink(_issuer, 'sub-1');

        expect(transport.calls, isZero);
        expect(await tokens.read(_issuer, 'sub-1'), isNull);
      });
    });
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

    group('the completion endpoint is the application\'s call', () {
      // The provider redirects the *browser* to the application's own page —
      // that is what every `redirectUri` in the configuration points at — and
      // the application forwards what it received here. The endpoint is
      // therefore an ordinary typed call, and its contract has to say so: a
      // `GET` at `/callback` reads as the provider's redirect target, and one
      // that answers a token pair in a browser's address bar puts the tokens
      // in history, in the access log and in the `Referer` of whatever the
      // page loads next.

      TomApiEndpoint completion() =>
          tomOAuthApi.endpoints[tomOAuthCompleteEndpointId]!;

      test('it is a POST at /complete', () {
        expect(completion().uri, '/complete');
        expect(completion().method, TomHttpMethod.post);
      });

      test('its parameters travel in the body, not the query string', () {
        expect(
          completion().urlParameterMapping,
          isEmpty,
          reason:
              'a mapping from query parameters is what a browser redirect '
              'needs. Keeping it would leave `code` and `state` in every log '
              'and proxy between the app and this server.',
        );
      });

      test('a provider refusal is refused by key, before any exchange', () async {
        final store = TomOAuthMemoryStateStore();
        TomBean.withType(TomOAuthStateStore, store);
        final transport = _StubTransport();
        TomBean.withType(TomOAuthTokenTransport, transport);

        await expectLater(
          endpoints.completeOAuthAuthorization(
            TomOAuthCallbackRequest(
              state: 'whatever',
              error: 'access_denied',
              errorDescription: 'The user pressed cancel',
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
        expect(
          transport.calls,
          isZero,
          reason:
              'there is no code to exchange — a refusal that reached the token '
              'endpoint would be asking the provider about an authorization it '
              'just declined to grant',
        );
      });

      test('an unknown state is refused by key', () async {
        TomBean.withType(TomOAuthStateStore, TomOAuthMemoryStateStore());

        await expectLater(
          endpoints.completeOAuthAuthorization(
            TomOAuthCallbackRequest(code: 'the-code', state: 'never-issued'),
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
  //
  // `injectQueryParameters` — the fold that makes `?code=…&state=…` reach the
  // callback's typed DTO — is pinned in `endpoints_test.dart`, beside the two
  // sibling folds it is applied with. Its group lived here for a while because
  // the callback was the first endpoint to need it, but every one of its cases
  // was about the helper rather than about OAuth, built on a synthetic
  // `/callback` endpoint rather than on `tomOAuthApi`'s own contract. Keeping
  // a copy here would have duplicated the helper's group into a suite that
  // cannot own it.
  //
  // The OAuth-specific half of the same guarantee — that the contract declares
  // the mapping at all, `error_description` rename included — is the kernel's:
  // `tomOAuthApi` is declared in `oauth_contract.dart`.
}

/// A transport whose every call fails, for the unreachable-provider case.
class _ThrowingTransport implements TomOAuthTokenTransport {
  _ThrowingTransport(this.error);

  final Object error;

  @override
  Future<String> postForm(
    Uri uri,
    Map<String, String> form,
    Map<String, String> headers,
  ) async => throw error;

  @override
  Future<String> getJson(Uri uri, Map<String, String> headers) async =>
      throw error;
}

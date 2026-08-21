/// Executable example for the **OAuth 2.0 / OIDC handshake** of the
/// `tom_core_server` authentication module: signing a user in through an
/// external identity provider.
///
/// The handshake is two round trips with a browser redirect between them.
/// [TomOAuthFlow.beginAuthorization] mints the state and the PKCE pair and
/// builds the URI the user is sent to; the provider redirects back to the
/// deployment with a code, and [TomOAuthFlow.completeAuthorization] trades that
/// code for an identity. `POST /oauth/authorize` and `GET /oauth/callback` are
/// those two calls behind an HTTP route — running them directly, as here, is
/// the same flow with the transport taken out.
///
/// **Everything runs against a scripted provider.** [_ScriptedProvider] is a
/// [TomOAuthTokenTransport] that answers the token and user-info calls from a
/// map, and it is the *only* seam replaced: the state check, the PKCE verifier,
/// the ID-token claim verification, the account linking and the session
/// issuance all execute exactly as they do against a real IdP. That is what
/// makes the transport a seam rather than a test hook, and it is why this
/// example needs no network and no registered client.
///
/// The other two seams are the deployment's, not the framework's. The framework
/// has no user table, so a deployment supplies a
/// [TomExternalIdentityDirectory] — "which local account is this person?" — and
/// a [TomExternalIdentityStore], the table that remembers the answer. Both are
/// in memory below.
///
/// Read it alongside `authentication_example.dart`, which covers provider
/// configuration and token retention as data, and
/// `two_factor_login_example.dart`, which covers the second factor an external
/// login is subject to just like a password one.
///
/// The framework's key-configuration warning is expected in the output: the
/// sessions issued here are genuinely signed, and this program configures no
/// keys of its own.
///
/// Run with `dart run example/authentication/oauth_login_example.dart`.
/// The same behaviour is covered by `test/oauth_test.dart`.
library;

import 'dart:convert';

import 'package:tom_core_server/tom_core_server.dart';

/// The scripted provider's issuer and the client id it registered us under.
const String _issuer = 'https://idp.example.test';
const String _clientId = 'acme-console';

/// The configuration a deployment writes for the provider, as data.
///
/// `provisioning` is the one line that decides what happens to a person the IdP
/// vouches for but the deployment has never seen — see Examples 5 and 6, which
/// differ in nothing else.
Map<String, Object> _providerConfig({required String provisioning}) => {
  'issuer': _issuer,
  'authorizationEndpoint': '$_issuer/authorize',
  'tokenEndpoint': '$_issuer/token',
  'clientId': _clientId,
  'clientSecret': 'sh-sh-secret',
  'redirectUri': 'https://console.example.test/oauth/callback',
  'scopes': ['openid', 'email', 'profile'],
  'provisioning': provisioning,
};

/// Builds the providers a deployment has configured, keyed by id.
TomOAuthProviders _providers({String provisioning = 'refuse'}) =>
    TomOAuthProviders.fromConfiguration(
      TomServerConfigResourceProvider.from({
        'oauth': {
          'providers': {'idp': _providerConfig(provisioning: provisioning)},
        },
      }),
    );

/// An unsigned JWT carrying [claims].
///
/// Unsigned on purpose. The flow deliberately does not verify the ID token's
/// signature: it did not arrive from the browser, it came back down the
/// server's own TLS channel to the token endpoint, so there was nobody in a
/// position to substitute it. A signature here would be asserting something no
/// production code reads. What *is* checked is the issuer, the audience and the
/// expiry — authenticity and freshness are different questions.
String _idToken(Map<String, Object?> claims) {
  String segment(Map<String, Object?> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${segment({'alg': 'none', 'typ': 'JWT'})}.${segment(claims)}.';
}

/// The claim set a well-behaved OIDC provider returns.
///
/// `iss`, `aud` and `exp` are the three the flow checks, and they are why a
/// fixture cannot simply be the interesting claims: a token missing any of them
/// describes a provider no deployment should accept.
Map<String, Object?> _claims() => {
  'iss': _issuer,
  'aud': _clientId,
  'sub': 'sub-1',
  'email': 'alice@example.test',
  'name': 'Alice Example',
  'exp':
      DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch ~/
      1000,
};

/// The one HTTP seam, answering from a script.
///
/// It records what it was asked, because half of what a handshake has to get
/// right is about the *request* — that the PKCE verifier travels, that the
/// redirect URI is the configured one, that the client secret is presented as
/// HTTP Basic rather than in the form.
class _ScriptedProvider implements TomOAuthTokenTransport {
  /// What the token endpoint answers.
  ///
  /// An OIDC response: an `id_token` carrying the identity, plus the grant that
  /// would let the deployment call the provider's own API on the user's behalf
  /// — retained only if the provider is configured to (see
  /// `authentication_example.dart`).
  final Map<String, Object?> tokenResponse = {
    'access_token': 'at-1',
    'refresh_token': 'rt-1',
    'token_type': 'Bearer',
    'expires_in': 3600,
    'id_token': _idToken(_claims()),
  };

  /// The form and headers the last code exchange sent.
  Map<String, String>? postedForm;
  Map<String, String>? postedHeaders;

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
  Future<String> getJson(Uri uri, Map<String, String> headers) async =>
      jsonEncode(const <String, Object?>{});
}

/// The deployment's own account lookup, over a set of usernames.
///
/// This is the half of external login the framework deliberately does not own.
/// A real one queries the user table; what matters is the shape — answer `null`
/// for somebody who has no account here, and let
/// [provisionFromExternalIdentity] decide whether to create one.
class _AccountDirectory implements TomExternalIdentityDirectory {
  _AccountDirectory({Set<String>? accounts, this.canProvision = false})
    : accounts = accounts ?? <String>{};

  /// The local accounts that exist.
  final Set<String> accounts;

  /// Whether this directory is willing to create one.
  final bool canProvision;

  /// Every username it was asked about, and every identity it created.
  final List<String> lookups = [];
  final List<TomExternalIdentity> provisioned = [];

  @override
  Future<TomAuthenticationInfo?> authenticatedPrincipalFor(
    String username,
    TomAuthenticationData authData,
  ) async {
    lookups.add(username);
    if (!accounts.contains(username)) return null;
    return _infoFor(username, authData);
  }

  @override
  Future<TomAuthenticationInfo> provisionFromExternalIdentity(
    TomExternalIdentity identity,
    TomAuthenticationData authData,
  ) async {
    if (!canProvision) {
      throw LoginException(
        'login.error.oauth.provisioning-unsupported',
        'This directory does not create accounts',
      );
    }
    provisioned.add(identity);
    // A deployment may normalise the asserted name; the link follows whatever
    // it settles on, not the claim.
    final username = 'ext_${identity.username}';
    accounts.add(username);
    return _infoFor(username, authData);
  }

  TomAuthenticationInfo _infoFor(String username, TomAuthenticationData a) =>
      TomAuthenticationInfo(
        TomPrincipal(
          authenticated: true,
          context: {},
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
        ),
        TomAccessControlDefinition(),
      );
}

/// The request a client posts to start a login.
///
/// The seven context fields are captured here and nowhere else: the callback is
/// a bare browser navigation carrying a code and a state, so this is the only
/// moment at which the deployment knows which organization, application and
/// locale the login belongs to.
TomOAuthAuthorizationRequest _authorizationRequest() =>
    TomOAuthAuthorizationRequest(
      providerId: 'idp',
      client: 'web',
      application: 'console',
      process: 'login',
      organization: 'acme',
      clientLanguage: 'de',
      clientCountry: 'DE',
      clientTimezone: 'Europe/Berlin',
    );

/// One authentication attempt.
///
/// The context fields are deliberately *empty* so that what the session ends up
/// carrying can only have come from the flow, not from this message.
TomAuthenticationData _authData() => TomAuthenticationData(
  username: TomUser.guestUsername,
  organization: '',
  application: '',
  process: '',
  language: 'en',
  country: 'XX',
  timezone: 'utc',
  client: '',
);

Future<void> run() async {
  // Example 1: where the user is sent. The URI is built from configuration plus
  // two generated values -- `state`, which ties the callback back to this
  // pending login, and the PKCE challenge.
  final stateStore = TomOAuthMemoryStateStore();
  final provider = _ScriptedProvider();
  final flow = TomOAuthFlow(
    providers: _providers(),
    stateStore: stateStore,
    transport: provider,
  );

  final started = await flow.beginAuthorization(_authorizationRequest());
  final uri = Uri.parse(started.authorizationUri);
  print('sent to:                   ${uri.origin}${uri.path}');
  print('response_type:             ${uri.queryParameters['response_type']}');
  print('scope:                     ${uri.queryParameters['scope']}');
  print('redirect_uri:              ${uri.queryParameters['redirect_uri']}');
  print(
    'challenge method:          '
    '${uri.queryParameters['code_challenge_method']}',
  );

  // Only the *digest* of the PKCE verifier travels. The verifier stays here and
  // is presented at the token exchange, which is what stops an attacker who
  // intercepts the redirect from redeeming the code.
  final pending = (await stateStore.peek(started.state))!;
  print(
    'verifier travels:          '
    '${started.authorizationUri.contains(pending.pkce!.verifier)}',
  );
  print(
    'digest travels:            '
    '${uri.queryParameters['code_challenge'] == pending.pkce!.challenge}',
  );

  // Example 2: the login context is remembered here, because the callback
  // cannot carry it. A browser coming back from the IdP knows a code and a
  // state and nothing else about who was logging in to what.
  print('pending organization:      ${pending.organization}');
  print('pending application:       ${pending.application}');
  print(
    'pending locale:            '
    '${pending.clientLanguage}/${pending.clientCountry} '
    '${pending.clientTimezone}',
  );

  // Example 3: the provider redirects back, and the code is exchanged. What the
  // deployment presents at the token endpoint is worth reading: the verifier,
  // the configured redirect URI, and the client secret as HTTP Basic.
  final exchange = await flow.completeAuthorization(
    code: 'the-code',
    state: started.state,
  );
  final basic = utf8.decode(
    base64.decode(provider.postedHeaders!['Authorization']!.substring(6)),
  );
  print('grant_type posted:         ${provider.postedForm!['grant_type']}');
  print(
    'verifier presented:        '
    '${provider.postedForm!['code_verifier'] == pending.pkce!.verifier}',
  );
  print('secret presented as:       Basic $basic');
  print(
    'identity asserted:         '
    '${exchange.identity.subject} @ ${exchange.identity.issuer}',
  );
  print('username claim:            ${exchange.identity.username}');
  print('display name:              ${exchange.identity.displayName}');
  // The exchange names the *registration* it completed against, not merely the
  // issuer -- a deployment may register one IdP twice, and the two would be
  // indistinguishable by issuer alone.
  print('provider registration:     ${exchange.provider.id}');
  print('grant surfaced:            ${exchange.tokens?.accessToken != null}');

  // Example 4: a state is single-use. Replaying the callback -- which is what a
  // stolen code arrives as -- finds nothing pending and is refused.
  var replayKey = '';
  try {
    await flow.completeAuthorization(code: 'the-code', state: started.state);
  } on TomOAuthException catch (e) {
    replayKey = e.key;
  }
  print('replayed state:            $replayKey');

  // Example 5: the whole login, through the ordinary service contract. The IdP
  // vouches for somebody the deployment has never seen, and a provider
  // configured to refuse says so by key rather than inventing an account.
  // Provisioning is a decision, and the default must not make it.
  final refusedKey = await _loginKey(_providers());
  print('unknown, refuse:           $refusedKey');

  // Example 6: the same login against a provider configured to auto-provision.
  // The directory creates the account, settles on its own username, and the
  // link is written to *that* -- linking to the claim would leave the row
  // pointing at an account that does not exist.
  final directory = _AccountDirectory(canProvision: true);
  final identities = TomMemoryExternalIdentityStore();
  final provisioningFlow = TomOAuthFlow(
    providers: _providers(provisioning: 'autoProvision'),
    stateStore: TomOAuthMemoryStateStore(),
    transport: _ScriptedProvider(),
  );
  final service = TomOAuthAuthenticationService(
    directory: directory,
    identityStore: identities,
    flow: provisioningFlow,
  );

  final begun = await provisioningFlow.beginAuthorization(
    _authorizationRequest(),
  );
  final info = await service.authenticateUser(
    _authData()..key = TomOAuthCredential(code: 'c', state: begun.state),
  );
  print('provisioned as:            ${info.principal.user.username}');
  print('provisioned from subject:  ${directory.provisioned.single.subject}');
  print(
    'linked to:                 '
    '${await identities.localUsernameFor(exchange.identity)}',
  );

  // The session is issued in the organization the *flow* began in -- 'acme',
  // captured at Example 1 -- and not in whatever the callback happened to
  // carry, which here was deliberately blank.
  print('session organization:      ${info.principal.organization}');
  print(
    'session locale:            '
    '${info.principal.clientLanguage}/${info.principal.clientCountry}',
  );

  // Example 7: the second time, there is nothing to provision. The link written
  // above answers, the directory is asked about the local account rather than
  // the claim, and the login is not challenged for a credential -- the provider
  // already authenticated this person, so asking again would be asking twice.
  final again = await provisioningFlow.beginAuthorization(
    _authorizationRequest(),
  );
  final returning = await service.authenticateUser(
    _authData()..key = TomOAuthCredential(code: 'c', state: again.state),
  );
  final link = (await identities.identitiesOf('ext_alice@example.test')).single;
  print('returning user:            ${returning.principal.user.username}');
  print('provisioned again:         ${directory.provisioned.length > 1}');
  print('directory asked for:       ${directory.lookups}');
  print('login recorded:            ${link.lastLoginAt != null}');

  // Assertions
  assert(uri.queryParameters['response_type'] == 'code');
  assert(uri.queryParameters['scope'] == 'openid email profile');
  assert(uri.queryParameters['code_challenge_method'] == 'S256');
  assert(!started.authorizationUri.contains(pending.pkce!.verifier));
  assert(uri.queryParameters['code_challenge'] == pending.pkce!.challenge);
  assert(pending.organization == 'acme');
  assert(pending.clientTimezone == 'Europe/Berlin');
  assert(provider.postedForm!['grant_type'] == 'authorization_code');
  assert(provider.postedForm!['code_verifier'] == pending.pkce!.verifier);
  assert(
    provider.postedForm!['redirect_uri'] ==
        'https://console.example.test/oauth/callback',
  );
  assert(basic == '$_clientId:sh-sh-secret');
  assert(exchange.identity.subject == 'sub-1');
  assert(exchange.identity.username == 'alice@example.test');
  assert(exchange.provider.id == 'idp');
  assert(exchange.tokens!.accessToken == 'at-1');
  assert(replayKey.isNotEmpty, 'a replayed state must not complete');
  assert(refusedKey == 'login.error.oauth.no-local-account');
  assert(info.principal.user.username == 'ext_alice@example.test');
  assert(directory.provisioned.single.subject == 'sub-1');
  assert(
    await identities.localUsernameFor(exchange.identity) ==
        'ext_alice@example.test',
  );
  assert(info.principal.organization == 'acme');
  assert(info.principal.clientLanguage == 'de');
  assert(returning.principal.user.username == 'ext_alice@example.test');
  assert(directory.provisioned.length == 1, 'provisioned once, not twice');
}

/// Runs one external login for a person with no local account, and answers the
/// error key it failed with.
///
/// A helper rather than a `try` at the call site: what Example 5 is about is the
/// *key*, and a login that unexpectedly succeeded should fail the example
/// rather than quietly print an empty string.
Future<String> _loginKey(TomOAuthProviders providers) async {
  final flow = TomOAuthFlow(
    providers: providers,
    stateStore: TomOAuthMemoryStateStore(),
    transport: _ScriptedProvider(),
  );
  final service = TomOAuthAuthenticationService(
    directory: _AccountDirectory(),
    identityStore: TomMemoryExternalIdentityStore(),
    flow: flow,
  );
  final begun = await flow.beginAuthorization(_authorizationRequest());
  try {
    await service.authenticateUser(
      _authData()..key = TomOAuthCredential(code: 'c', state: begun.state),
    );
    throw StateError('the login was expected to fail');
  } on LoginException catch (e) {
    return e.key;
  }
}

void main() => run();

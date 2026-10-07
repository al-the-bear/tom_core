/// Executable example for the **OAuth 2.0 / OIDC handshake** of the
/// `tom_core_server` authentication module: signing a user in through an
/// external identity provider.
///
/// The handshake is two round trips with a browser redirect between them.
/// [TomOAuthFlow.beginAuthorization] mints the state and the PKCE pair and
/// builds the URI the user is sent to; the provider redirects back to the
/// deployment with a code, and [TomOAuthFlow.completeAuthorization] trades that
/// code for an identity. `POST /oauth/authorize` and `POST /oauth/complete` are
/// those two calls behind an HTTP route — running the flow directly, as the
/// first seven examples do, is the same thing with the transport taken out,
/// and Example 8 runs the endpoints themselves, including the hop the
/// framework deliberately does not make: the provider redirects a *browser* to
/// the application's own page, and that page posts what it received.
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
/// Run with `dart run example/authentication/oauth_login_example.dart`. Every
/// step checks its own result and the run fails when one does not hold, so a
/// green run is a verification and not just a transcript. The same behaviour is
/// covered by `test/oauth_test.dart`.
library;

import 'dart:convert';

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

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
      throw TomLoginException(
        'login.error.oauth.provisioning-unsupported',
        'This directory does not create accounts',
        reason: TomLoginFailure.providerError,
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

  // Example 8: the same login through the HTTP endpoints, including the hop
  // the framework deliberately does not make. The provider redirects a
  // *browser* to the application's own `redirectUri` page; that page reads
  // `code` and `state` off its own query string and posts them to
  // `/oauth/complete`, so the token pair comes back in a response body the
  // front end controls instead of in an address bar.
  TomBean.resetBeanContext();
  final endpointIdentities = TomMemoryExternalIdentityStore();
  TomBean.withType<TomOAuthProviders>(
    _providers(provisioning: 'autoProvision'),
  );
  TomBean.withType<TomOAuthStateStore>(TomOAuthMemoryStateStore());
  TomBean.withType<TomOAuthTokenTransport>(_ScriptedProvider());
  final savedService =
      TomAuthenticationServer.globalSettingUserAuthenticationService;
  TomAuthenticationServer.globalSettingUserAuthenticationService =
      TomOAuthAuthenticationService(
        directory: _AccountDirectory(canProvision: true),
        identityStore: endpointIdentities,
      );

  const endpoints = TomOAuthServer();
  final authorization = await endpoints.beginOAuthAuthorization(
    _authorizationRequest(),
  );

  // What the provider sends the browser to. Parsing it here is exactly what
  // the application's page does with its own location.
  final redirected = Uri.parse(
    'https://console.example.test/oauth/callback'
    '?code=the-code&state=${authorization.state}',
  );
  final completed = await endpoints.completeOAuthAuthorization(
    TomOAuthCallbackRequest(
      code: redirected.queryParameters['code']!,
      state: redirected.queryParameters['state']!,
    ),
  );
  print(
    'completion error:          ${completed.error.isEmpty ? '(none)' : completed.error}',
  );
  print(
    'completion token issued:   ${completed.authorizationToken.isNotEmpty}',
  );

  // The user pressed Cancel. The page has no code to forward; posting the
  // refusal here only names it.
  var cancelledKey = '';
  try {
    await endpoints.completeOAuthAuthorization(
      TomOAuthCallbackRequest(
        state: authorization.state,
        error: 'access_denied',
        errorDescription: 'The user declined',
      ),
    );
  } on TomEndpointHandlerException catch (e) {
    cancelledKey = e.key;
  }
  print('cancelled by user:         $cancelledKey');

  // A state this server never issued -- or one already spent, or lapsed.
  var unknownStateKey = '';
  try {
    await endpoints.completeOAuthAuthorization(
      TomOAuthCallbackRequest(code: 'the-code', state: 'never-issued'),
    );
  } on TomEndpointHandlerException catch (e) {
    unknownStateKey = e.key;
  }
  print('unknown state:             $unknownStateKey');

  TomAuthenticationServer.globalSettingUserAuthenticationService = savedService;
  TomBean.resetBeanContext();

  // What the eight examples above had to be true for.
  check(
    completed.error.isEmpty && completed.authorizationToken.isNotEmpty,
    'the completion endpoint answers the same authentication result a password '
    'login answers, in a body the front end holds',
  );
  check(
    cancelledKey == 'oauth.callback.provider_error',
    'a refusal the application chooses to forward is named rather than guessed '
    'at',
  );
  check(
    unknownStateKey == 'oauth.callback.unknown_state',
    'a state this server never issued completes nothing',
  );
  check(
    uri.queryParameters['response_type'] == 'code',
    'the user is sent on the authorization-code flow',
  );
  check(
    uri.queryParameters['scope'] == 'openid email profile',
    'the scopes the deployment configured are the scopes requested',
  );
  check(
    uri.queryParameters['code_challenge_method'] == 'S256',
    'the challenge is a digest of the verifier and not the verifier itself',
  );
  check(
    !started.authorizationUri.contains(pending.pkce!.verifier),
    'the PKCE verifier never travels through the browser',
  );
  check(
    uri.queryParameters['code_challenge'] == pending.pkce!.challenge,
    'the digest the provider is given is the one held against this pending '
    'login',
  );
  check(
    pending.organization == 'acme',
    'the organization the login began in is remembered, because the callback '
    'cannot carry it',
  );
  check(
    pending.clientTimezone == 'Europe/Berlin',
    'the caller locale is remembered with it',
  );
  check(
    provider.postedForm!['grant_type'] == 'authorization_code',
    'the code is redeemed as an authorization-code grant',
  );
  check(
    provider.postedForm!['code_verifier'] == pending.pkce!.verifier,
    'the verifier is presented at the token endpoint, which an interceptor of '
    'the redirect could not do',
  );
  check(
    provider.postedForm!['redirect_uri'] ==
        'https://console.example.test/oauth/callback',
    'the redirect URI presented is the configured one',
  );
  check(
    basic == '$_clientId:sh-sh-secret',
    'the client secret is presented as HTTP Basic rather than in the form',
  );
  check(
    exchange.identity.subject == 'sub-1',
    'the identity is the subject the ID token asserted',
  );
  check(
    exchange.identity.username == 'alice@example.test',
    'the asserted username comes from the claims and not from the request',
  );
  check(
    exchange.provider.id == 'idp',
    'the exchange names the registration it completed against, not merely the '
    'issuer',
  );
  check(
    exchange.tokens!.accessToken == 'at-1',
    'the grant that lets the deployment call the provider is surfaced',
  );
  check(replayKey.isNotEmpty, 'a replayed state must not complete');
  check(
    refusedKey == 'login.error.oauth.no-local-account',
    'a provider configured to refuse says so by key instead of inventing an '
    'account',
  );
  check(
    info.principal.user.username == 'ext_alice@example.test',
    'the auto-provisioned login lands on the username the directory settled on',
  );
  check(
    directory.provisioned.single.subject == 'sub-1',
    'the account was created from the identity the provider vouched for',
  );
  check(
    await identities.localUsernameFor(exchange.identity) ==
        'ext_alice@example.test',
    'the link points at the account that exists rather than at the claim',
  );
  check(
    info.principal.organization == 'acme',
    'the session is issued in the organization the flow began in, not the '
    'blank one the callback carried',
  );
  check(
    info.principal.clientLanguage == 'de',
    'the session carries the locale captured when the login started',
  );
  check(
    returning.principal.user.username == 'ext_alice@example.test',
    'a returning user is resolved through the stored link',
  );
  check(directory.provisioned.length == 1, 'provisioned once, not twice');
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
  } on TomLoginException catch (e) {
    return e.key;
  }
}

void main() => run();

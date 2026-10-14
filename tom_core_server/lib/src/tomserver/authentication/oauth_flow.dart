/// The authorization-code + PKCE handshake (C-9): everything between "the user
/// pressed *Sign in with …*" and "here is who they are".
///
/// This library knows about OAuth and nothing about logging in. It produces a
/// [TomExternalIdentity] — an issuer, a subject and some claims — and stops.
/// Turning that into a session is [TomOAuthAuthenticationService]'s job, and
/// issuing tokens for it is [TomAuthenticationServer]'s; the separation is the
/// module's central decision (see `readme.md`).
///
/// ## What actually protects the flow
///
/// Three things, and it is worth being precise about which does what, because
/// they are often described as if they were one:
///
/// * **`state`** ties the redirect to the browser that started the flow. It is
///   server-issued, single-use ([TomOAuthStateStore.consume]) and TTL-bounded,
///   so a code replayed into a *different* pending flow finds nothing to
///   complete. This is the CSRF defence.
/// * **PKCE** ties the *code exchange* to the client that started the flow. The
///   verifier never leaves the server, and an attacker holding a stolen code
///   cannot exchange it without one. This is the code-interception defence.
/// * **The registered `redirect_uri`** keeps the code from being delivered to
///   the attacker in the first place — which is why it is configuration and not
///   a request parameter ([TomOAuthProviderConfig.redirectUri]).
///
/// Each covers a case the others do not, which is why all three are present and
/// none is optional-by-default.
///
/// ## Why the ID token's signature is not verified
///
/// [TomOAuthFlow] reads the claims out of an `id_token` without checking its
/// signature, and this is deliberate rather than pending. The token arrives as
/// the response body of a TLS-authenticated, server-to-server POST that *this
/// server* made to the provider's configured token endpoint, using its client
/// credentials. OIDC Core §3.1.3.7 explicitly allows TLS server validation in
/// place of signature checking for exactly that case: there is no untrusted
/// party between the issuer and the reader, so the signature would be verifying
/// a channel that is already authenticated.
///
/// The claims that *are* checked are the ones TLS does not cover: `iss` must be
/// the configured issuer and `aud` must contain the configured client id, so a
/// token minted for some other relying party cannot be presented here.
///
/// This reasoning stops holding the moment an ID token is accepted from
/// anywhere else — a front-channel redirect, a client-supplied parameter, a
/// cached copy. Nothing in this module does that, and nothing added to it may.
///
/// ## Freshness is checked, and is a separate question
///
/// The argument above is about **authenticity**: who minted this token, and
/// could anyone have substituted it in transit. It says nothing about
/// **freshness**, and the two do not follow from one another — a token can be
/// unquestionably the issuer's and hours out of date. So `exp` is verified, and
/// `nbf` when the provider sends one, against
/// [TomOAuthProviderConfig.clockSkew] (one minute by default).
///
/// It is checked even though, on this back channel, a stale token would mean
/// the provider is misbehaving rather than that anyone is attacking. Two
/// reasons. `exp` is the one claim that costs nothing to verify and is the
/// standard's own requirement of a relying party; and the moment an ID token
/// reaches this code from a second source — which the section above forbids but
/// cannot enforce — an unchecked expiry stops being a shortcut and becomes a
/// replay hole. The skew tolerance is what keeps the check from turning
/// ordinary clock drift into a failed login.
///
/// A token with no `exp` at all is refused rather than treated as unbounded:
/// OIDC Core §2 requires the claim, so its absence is a non-conformant provider,
/// and reading "cannot check" as "check passed" would make the verification true
/// only of providers that chose to cooperate.
///
/// `iat` is deliberately **not** turned into a rejection. It answers "how long
/// ago was this minted", which is only a refusal once a deployment states a
/// maximum age — a policy this module does not hold, and one the provider has
/// already expressed on its own terms as `exp`. An OIDC `max_age` /
/// `auth_time` policy is the natural place for that decision, and it is a
/// different decision from this one.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'external_provider.dart';
import 'oauth_provider.dart';
import 'oauth_tokens.dart';
import 'saml_flow.dart';
import 'saml_provider.dart';

/// A PKCE verifier / challenge pair (RFC 7636).
///
/// The verifier is the secret the server keeps; the challenge is its SHA-256
/// digest, which is what travels to the provider. Only `S256` is produced —
/// `plain` is in the RFC for clients that cannot hash, which a Dart server on
/// the back channel is not.
class TomOAuthPkce {
  /// The high-entropy secret, kept server-side and replayed at the exchange.
  final String verifier;

  /// `S256(verifier)`, base64url-encoded without padding — what the provider
  /// records and later checks the verifier against.
  final String challenge;

  /// The challenge method sent alongside [challenge].
  static const String method = 'S256';

  /// Pairs an existing [verifier] with its [challenge]. For restoring a stored
  /// pair; use [TomOAuthPkce.generate] to make a new one.
  const TomOAuthPkce(this.verifier, this.challenge);

  /// Generates a fresh pair from [Random.secure].
  ///
  /// 32 bytes, which is the RFC's recommendation and lands inside the mandated
  /// 43–128 character range once base64url-encoded.
  factory TomOAuthPkce.generate() {
    final verifier = TomOAuthFlow.randomHandle(32);
    return TomOAuthPkce(verifier, challengeFor(verifier));
  }

  /// The `S256` challenge for [verifier].
  ///
  /// Exposed because verifying the pair is how a test proves the challenge is a
  /// real digest and not an echo of the verifier.
  static String challengeFor(String verifier) =>
      _base64Url(sha256.convert(utf8.encode(verifier)).bytes);
}

/// A pending authorization: everything the server must remember between sending
/// a user to a provider and the provider sending them back.
///
/// The login *context* is here rather than reconstructed at the callback
/// because the callback is a plain browser navigation and carries none of it:
/// no client id, no locale, no organization, no timezone. Capturing it when the
/// flow starts is what makes an externally-authenticated session come out in
/// exactly the organization and locale the login began in.
class TomOAuthAuthorizationState {
  /// The opaque handle the provider echoes back.
  final String state;

  /// Which provider this flow is against.
  final String providerId;

  /// The PKCE pair, or `null` when the provider is configured without PKCE.
  final TomOAuthPkce? pkce;

  /// When the record was created — the TTL is measured from here.
  final DateTime createdAt;

  /// The client the login was started from.
  final String client;

  /// The application the login is for.
  final String application;

  /// The process the login is for.
  final String process;

  /// The organization the login is for.
  final String organization;

  /// The client's language code.
  final String clientLanguage;

  /// The client's country code.
  final String clientCountry;

  /// The client's IANA timezone name.
  final String clientTimezone;

  /// The value the next leg of the flow must echo, or `''`.
  ///
  /// For an OpenID Connect flow, the `nonce` sent in the authorization request,
  /// which the `id_token` must carry back (OIDC Core §3.1.2.1): it binds the
  /// token to this flow. For a SAML flow, the `ID` of the `AuthnRequest`, which
  /// the response must name in `InResponseTo` — and, once the response has
  /// been verified, the digest of the handoff code the application posts back.
  final String nonce;

  /// The identity a SAML response asserted, once the assertion consumer service
  /// has verified it; `null` for every other record.
  ///
  /// A SAML response reaches the server as a browser form post, not as the
  /// application's call, so the verified identity waits here until the
  /// application completes the login with the handoff code.
  final TomExternalIdentity? assertedIdentity;

  /// The tenant the flow began in, or `''` for a flow of no tenant.
  ///
  /// A flow completes only in the tenant it began in: every
  /// [TomOAuthStateStore] answers [TomOAuthStateStore.peek] and
  /// [TomOAuthStateStore.consume] with records of the tenant in context only,
  /// so a callback that reaches another tenant — by its host, its path or a
  /// header — finds no pending flow (`oauth.flow.unknown_state`) and cannot
  /// spend the one it names either.
  final String tenant;

  /// Creates a pending-authorization record.
  ///
  /// [tenant] defaults to the tenant in context ([TomTenantContext.currentId],
  /// `''` for none), which is the tenant of the request that begins the flow.
  TomOAuthAuthorizationState({
    required this.state,
    required this.providerId,
    required this.createdAt,
    String? tenant,
    this.pkce,
    this.nonce = '',
    this.assertedIdentity,
    this.client = '',
    this.application = '',
    this.process = '',
    this.organization = '',
    this.clientLanguage = '',
    this.clientCountry = '',
    this.clientTimezone = '',
  }) : tenant = tenant ?? TomTenantContext.currentId ?? '';

  /// The tenant in context as a record names it — `''` for none.
  static String get currentTenant => TomTenantContext.currentId ?? '';

  @override
  String toString() => 'TomOAuthAuthorizationState($state -> $providerId)';
}

/// Where pending authorizations live between the redirect out and the redirect
/// back.
///
/// An interface because the right store depends on the deployment: a single
/// process is served by [TomOAuthMemoryStateStore], while a load-balanced pair
/// needs a shared one (the redirect can land on either node) and would back
/// this with the cache or a table.
///
/// [peek] and [consume] are separate operations on purpose. The endpoint needs
/// the login context to build its authentication message, and the
/// authentication service needs the PKCE verifier and must spend the record —
/// so the record is read twice and consumed exactly once, and the single-use
/// guarantee lives in one method rather than in each caller's discipline.
abstract class TomOAuthStateStore {
  /// Remembers [pending] under its own [TomOAuthAuthorizationState.state].
  Future<void> store(TomOAuthAuthorizationState pending);

  /// The record for [state] without spending it, or `null` when it is
  /// unknown, expired, or of another tenant than the one in context
  /// ([TomOAuthAuthorizationState.tenant]).
  Future<TomOAuthAuthorizationState?> peek(String state);

  /// The record for [state], removing it, or `null` when it is unknown,
  /// expired, or of another tenant than the one in context — a record of
  /// another tenant is left where it is. A second call with the same [state]
  /// always answers `null` — that is what makes a code replay fail.
  Future<TomOAuthAuthorizationState?> consume(String state);

  /// The installed [TomOAuthStateStore] bean, or a process-wide
  /// [TomOAuthMemoryStateStore] when none is registered.
  ///
  /// A working default rather than `null`, because a store is not optional the
  /// way a preference table is: without one, no flow can complete at all. The
  /// default is correct for the single-process case and wrong only for a
  /// multi-node deployment, which is a deployment that installs beans anyway.
  static TomOAuthStateStore resolve() {
    final installed = TomBean.getBeanByType(TomOAuthStateStore);
    if (installed is TomOAuthStateStore) return installed;
    return _fallback;
  }

  static final TomOAuthStateStore _fallback = TomOAuthMemoryStateStore();
}

/// An in-process [TomOAuthStateStore] with a time-to-live.
///
/// Expiry is enforced on read rather than by a timer: a record that is never
/// read never needs to be evicted correctly, and a background timer in a
/// library is a thing every embedding process then has to shut down. Expired
/// records are swept on each write, so the map cannot grow without bound in a
/// process that keeps starting flows nobody finishes.
class TomOAuthMemoryStateStore implements TomOAuthStateStore {
  /// How long a pending authorization stays completable.
  ///
  /// Ten minutes: long enough for a user to read a consent screen and log in to
  /// the provider, short enough that an abandoned flow stops being a live
  /// credential quickly.
  final Duration timeToLive;

  /// The clock expiry is judged against.
  ///
  /// The same clock the flow stamps `createdAt` with must be passed here: a
  /// flow on an injected clock with a store on the wall clock measures a
  /// record's age between two different timelines, and a test pinned to a
  /// fixed instant then starts failing the day that instant is ten minutes
  /// old.
  final DateTime Function() clock;

  final Map<String, TomOAuthAuthorizationState> _pending = {};

  /// Creates a store; [timeToLive] defaults to ten minutes and [clock] to the
  /// wall clock.
  TomOAuthMemoryStateStore({
    this.timeToLive = const Duration(minutes: 10),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  @override
  Future<void> store(TomOAuthAuthorizationState pending) async {
    _sweep();
    _pending[pending.state] = pending;
  }

  @override
  Future<TomOAuthAuthorizationState?> peek(String state) async =>
      _liveOrNull(state);

  @override
  Future<TomOAuthAuthorizationState?> consume(String state) async {
    final found = _liveOrNull(state);
    if (found != null) _pending.remove(state);
    return found;
  }

  /// The record under [state] when it is still within [timeToLive] and of the
  /// tenant in context.
  ///
  /// Removes an expired record as it is found, so an expired handle behaves
  /// identically to an unknown one on the next call too. A record of another
  /// tenant is answered as unknown and kept: a callback reaching the wrong
  /// tenant must not be able to spend the flow either.
  TomOAuthAuthorizationState? _liveOrNull(String state) {
    final found = _pending[state];
    if (found == null) return null;
    if (found.tenant != TomOAuthAuthorizationState.currentTenant) return null;
    if (_isExpired(found)) {
      _pending.remove(state);
      return null;
    }
    return found;
  }

  bool _isExpired(TomOAuthAuthorizationState pending) =>
      clock().toUtc().difference(pending.createdAt) > timeToLive;

  void _sweep() => _pending.removeWhere((_, pending) => _isExpired(pending));
}

/// The one place this module speaks HTTP to a provider.
///
/// A seam, and the reason the whole flow is testable: a stub provider
/// implements these two calls and every other line — the PKCE check, the state
/// check, the claim mapping, the account linking, the token issuance — runs
/// exactly as it does in production. A flow that called `http.post` inline
/// could only be tested against a real provider, which means it would be tested
/// by hand, once.
abstract class TomOAuthTokenTransport {
  /// POSTs [form] as `application/x-www-form-urlencoded` and answers the body.
  Future<String> postForm(
    Uri uri,
    Map<String, String> form,
    Map<String, String> headers,
  );

  /// GETs [uri] and answers the body — the user-info call, when a provider
  /// needs one.
  Future<String> getJson(Uri uri, Map<String, String> headers);

  /// The installed [TomOAuthTokenTransport] bean, or a live HTTP one.
  ///
  /// A working default for the same reason [TomOAuthStateStore.resolve] has
  /// one: talking to the provider is not optional. Tests install a stub.
  static TomOAuthTokenTransport resolve() {
    final installed = TomBean.getBeanByType(TomOAuthTokenTransport);
    if (installed is TomOAuthTokenTransport) return installed;
    return const TomHttpOAuthTokenTransport();
  }
}

/// The live [TomOAuthTokenTransport], over `package:http`.
class TomHttpOAuthTokenTransport implements TomOAuthTokenTransport {
  /// Creates the transport.
  const TomHttpOAuthTokenTransport();

  @override
  Future<String> postForm(
    Uri uri,
    Map<String, String> form,
    Map<String, String> headers,
  ) async {
    final response = await http.post(uri, body: form, headers: headers);
    _requireSuccess(uri, response.statusCode, response.body);
    return response.body;
  }

  @override
  Future<String> getJson(Uri uri, Map<String, String> headers) async {
    final response = await http.get(uri, headers: headers);
    _requireSuccess(uri, response.statusCode, response.body);
    return response.body;
  }

  /// Turns a non-2xx provider response into a [TomOAuthException].
  ///
  /// The body is included because a provider's error body is the only thing
  /// that says *why* (`invalid_grant`, `redirect_uri_mismatch`), and diagnosing
  /// a misconfigured provider without it is guesswork. It stays server-side:
  /// [TomOAuthException] defaults to `clientThrow: false`.
  void _requireSuccess(Uri uri, int statusCode, String body) {
    if (statusCode >= 200 && statusCode < 300) return;
    throw TomOAuthException(
      'oauth.provider.http_error',
      'The provider endpoint $uri answered $statusCode: $body',
    );
  }
}

/// What a provider told us about the user.
///
/// The output of this library and the input of the linking table: an issuer, a
/// stable subject within that issuer, and whatever else the provider sent.
class TomExternalIdentity {
  /// The identity provider's issuer identifier.
  final String issuer;

  /// The provider's stable identifier for this user, within [issuer].
  final String subject;

  /// The username the local account would be named after, when provisioning —
  /// typically the email address.
  final String username;

  /// A human-readable name, when the provider sent one.
  final String displayName;

  /// Every claim the provider returned, for a deployment's own mapping. For a
  /// SAML identity, the assertion's attributes: a single value as a string,
  /// several as a list.
  final Map<String, Object?> claims;

  /// The groups the provider asserted, read through the provider's
  /// [TomExternalRoleMapping.groupsClaim].
  final List<String> groups;

  /// The Tom roles the provider's [TomExternalRoleMapping] grants for
  /// [groups]. Applied to the session's principal on every login.
  final List<String> roles;

  /// Creates an external identity.
  const TomExternalIdentity({
    required this.issuer,
    required this.subject,
    this.username = '',
    this.displayName = '',
    this.claims = const {},
    this.groups = const [],
    this.roles = const [],
  });

  /// The identity as JSON, for a store that holds a verified identity between
  /// two requests.
  Map<String, Object?> toJson() => {
    'issuer': issuer,
    'subject': subject,
    'username': username,
    'displayName': displayName,
    'claims': claims,
    'groups': groups,
    'roles': roles,
  };

  /// The identity [json] describes — the inverse of [toJson].
  factory TomExternalIdentity.fromJson(Map<String, Object?> json) {
    List<String> strings(Object? raw) =>
        raw is List ? List.unmodifiable(raw.map((e) => '$e')) : const [];
    final claims = json['claims'];
    return TomExternalIdentity(
      issuer: '${json['issuer'] ?? ''}',
      subject: '${json['subject'] ?? ''}',
      username: '${json['username'] ?? ''}',
      displayName: '${json['displayName'] ?? ''}',
      claims: claims is Map
          ? Map.unmodifiable(claims.map((k, v) => MapEntry('$k', v)))
          : const {},
      groups: strings(json['groups']),
      roles: strings(json['roles']),
    );
  }

  @override
  String toString() => 'TomExternalIdentity($issuer/$subject)';
}

/// A completed code exchange: which provider it was against, who that provider
/// says this is, and which pending flow it completes.
class TomOAuthExchange {
  /// The identity the provider asserted.
  final TomExternalIdentity identity;

  /// The pending record this exchange consumed — the login context the session
  /// must be issued in.
  final TomOAuthAuthorizationState pending;

  /// The provider this exchange was completed against.
  ///
  /// Carried rather than re-derived, because a login makes several decisions
  /// out of provider configuration — whether to provision, whether to retain
  /// the grant — at points far enough apart that two of them could resolve to
  /// *different* providers and disagree about which login this was. Resolution
  /// happens once, here, at the only moment the answer is not in question: the
  /// pending record names the provider the flow began with, and this exchange
  /// is that flow's conclusion.
  ///
  /// Deriving it again downstream from [identity] would not be equivalent.
  /// [TomExternalIdentity.issuer] is copied *from this provider's*
  /// configuration, so it identifies the IdP and not the registration — and two
  /// registrations may share an issuer, which is how a deployment offers one
  /// IdP under two scope sets or two client registrations.
  ///
  /// An OAuth 2.0 / OIDC provider or a SAML identity provider; everything the
  /// login decides from it is on [TomExternalProvider].
  final TomExternalProvider provider;

  /// What the provider's token endpoint returned, or `null` when it returned no
  /// usable access token.
  ///
  /// Surfaced **always**, and retained only on request. The grant is already in
  /// memory for the duration of this request — the flow needed it to reach the
  /// claims — so handing it over costs nothing and lengthens nothing, and it is
  /// what makes the framework's "keeps nothing by default" position usable
  /// rather than merely restrictive: a deployment with its own credential vault
  /// can take the grant here and never touch [TomOAuthTokenStore]. What it must
  /// not do is start a *second* authorization flow to obtain what this one
  /// already had.
  ///
  /// Whether the framework itself keeps a copy is
  /// [TomOAuthProviderConfig.storeTokens], and that decision is made after the
  /// login succeeds — not here.
  final TomOAuthTokenGrant? tokens;

  /// Pairs an identity with the flow it completes and the provider it came
  /// from.
  const TomOAuthExchange(
    this.identity,
    this.pending, {
    required this.provider,
    this.tokens,
  });
}

/// Drives the authorization-code + PKCE handshake.
///
/// Stateless apart from its collaborators, so one instance serves every
/// request: the per-flow state lives in the [TomOAuthStateStore], which is where
/// a multi-node deployment can share it.
class TomOAuthFlow {
  /// The configured providers.
  final TomOAuthProviders providers;

  /// Where pending authorizations are kept.
  final TomOAuthStateStore stateStore;

  /// The one HTTP seam.
  final TomOAuthTokenTransport transport;

  /// The SAML 2.0 identity providers, or `null` when the deployment has none.
  ///
  /// A SAML provider is begun and completed through the same two calls as an
  /// OAuth one — [beginAuthorization] and [completeAuthorization] dispatch on
  /// the provider id — so an application's login page treats every provider
  /// alike. Provider ids are one namespace across both protocols.
  final TomSamlFlow? saml;

  /// Creates a flow over explicit collaborators.
  TomOAuthFlow({
    required this.providers,
    required this.stateStore,
    required this.transport,
    this.saml,
  }) {
    final shared = saml?.providers.providers.keys
        .where(providers.providers.containsKey)
        .toList();
    if (shared != null && shared.isNotEmpty) {
      throw TomOAuthException(
        'oauth.config.duplicate_provider_id',
        'The provider ids $shared are configured both as OAuth and as SAML '
            'providers; a login names its provider by id, so the ids must be '
            'unique across both.',
        parameters: {'providers': shared.join(', ')},
      );
    }
  }

  /// Creates a flow from the installed beans, falling back to configuration for
  /// the provider set.
  ///
  /// The convenience the endpoints use, so the ordinary case is wiring-free:
  /// install nothing and external login reads its providers from the config
  /// tree, keeps state in memory and talks real HTTP.
  factory TomOAuthFlow.fromBeans() {
    final stateStore = TomOAuthStateStore.resolve();
    final samlProviders =
        TomSamlProviders.resolve() ?? TomSamlProviders.fromConfiguration();
    return TomOAuthFlow(
      providers:
          TomOAuthProviders.resolve() ?? TomOAuthProviders.fromConfiguration(),
      stateStore: stateStore,
      transport: TomOAuthTokenTransport.resolve(),
      saml: samlProviders.isEmpty
          ? null
          : TomSamlFlow(providers: samlProviders, stateStore: stateStore),
    );
  }

  /// Every provider a login page offers — the OAuth providers, then the SAML
  /// ones — as client-facing descriptors.
  List<TomOAuthProviderDto> get descriptors => List.unmodifiable([
    ...providers.descriptors,
    ...?saml?.providers.descriptors,
  ]);

  /// Starts a flow: remembers the pending authorization and answers where to
  /// send the user.
  Future<TomOAuthAuthorizationDto> beginAuthorization(
    TomOAuthAuthorizationRequest request,
  ) async {
    final samlFlow = saml;
    if (samlFlow != null &&
        samlFlow.providers.lookup(request.providerId) != null) {
      return samlFlow.beginAuthorization(request);
    }
    final provider = providers[request.providerId];
    final pkce = provider.usePkce ? TomOAuthPkce.generate() : null;
    final state = TomOAuthFlow.randomHandle(32);
    // A nonce whenever an `id_token` can come back. It is what ties the token
    // to this flow rather than to any flow at this client, which `state` alone
    // does not: `state` protects the redirect, the nonce protects the token.
    final nonce = provider.scopes.contains('openid')
        ? TomOAuthFlow.randomHandle(24)
        : '';

    await stateStore.store(
      TomOAuthAuthorizationState(
        state: state,
        providerId: provider.id,
        pkce: pkce,
        nonce: nonce,
        createdAt: DateTime.now().toUtc(),
        client: request.client,
        application: request.application,
        process: request.process,
        organization: request.organization,
        clientLanguage: request.clientLanguage,
        clientCountry: request.clientCountry,
        clientTimezone: request.clientTimezone,
      ),
    );

    final authorizationUri = Uri.parse(provider.authorizationEndpoint).replace(
      queryParameters: <String, String>{
        // The provider's authorization endpoint may already carry parameters of
        // its own (some tenanted providers encode the tenant there), so the
        // existing query is preserved and the flow's parameters are added to it
        // rather than replacing it.
        ...Uri.parse(provider.authorizationEndpoint).queryParameters,
        // Configured extras next — `access_type=offline`, `prompt=consent`, a
        // tenant — and deliberately *before* the flow's own, so a typo in
        // configuration cannot replace the state handle or the redirect URI.
        ...provider.authorizationParameters,
        'response_type': 'code',
        'client_id': provider.clientId,
        'redirect_uri': provider.redirectUri,
        'scope': provider.scopes.join(' '),
        'state': state,
        if (nonce.isNotEmpty) 'nonce': nonce,
        if (pkce != null) 'code_challenge': pkce.challenge,
        if (pkce != null) 'code_challenge_method': TomOAuthPkce.method,
      },
    );

    return TomOAuthAuthorizationDto(
      authorizationUri: authorizationUri.toString(),
      state: state,
    );
  }

  /// Completes a flow: spends the pending record, exchanges [code] and answers
  /// who the provider says this is.
  ///
  /// Throws when [state] is unknown, expired or already spent — the three cases
  /// are deliberately indistinguishable to a caller, because telling them apart
  /// tells an attacker whether a handle was ever valid.
  Future<TomOAuthExchange> completeAuthorization({
    required String code,
    required String state,
  }) async {
    final pending = await stateStore.consume(state);
    if (pending == null) {
      throw TomOAuthException(
        'oauth.flow.unknown_state',
        'The authorization could not be completed because its state handle is '
            'unknown, expired or already used.',
        clientThrow: true,
      );
    }
    if (code.isEmpty) {
      throw TomOAuthException(
        'oauth.flow.missing_code',
        'The provider redirect carried no authorization code.',
        clientThrow: true,
      );
    }
    final samlFlow = saml;
    if (samlFlow != null &&
        samlFlow.providers.lookup(pending.providerId) != null) {
      return samlFlow.completeAuthorization(pending, code);
    }
    final provider = providers[pending.providerId];
    final tokens = await _exchangeCode(provider, pending, code);
    final claims = await _claimsFor(provider, tokens, pending);
    final grant = TomOAuthTokenGrant.fromTokenResponse(tokens);
    return TomOAuthExchange(
      _identityFor(provider, claims),
      pending,
      provider: provider,
      // A grant with no access token is not a grant: an OIDC provider that
      // answered with an `id_token` alone has authenticated the user and
      // delegated nothing, and handing back an empty bearer token would let a
      // caller present `Authorization: Bearer ` to an API.
      tokens: grant.accessToken.isEmpty ? null : grant,
    );
  }

  /// Exchanges [grant]'s refresh token for a fresh one at [providerId].
  ///
  /// **This is not a login.** It consults no [TomAuthenticationService], asks no
  /// 2FA policy, touches no session and produces no principal — it is one HTTP
  /// call to a token endpoint on behalf of a user who consented some time ago.
  /// Reusing the login path here is the drift the C-9 seam exists to prevent:
  /// the login path's job is to decide *who someone is*, and a background job
  /// refreshing a calendar token has already had that decided for it.
  ///
  /// Throws when the grant carries no refresh token — the caller cannot recover
  /// by retrying and must send the user through consent again, which is a
  /// different action, not a slower one.
  Future<TomOAuthTokenGrant> refreshGrant({
    required String providerId,
    required TomOAuthTokenGrant grant,
  }) async {
    final provider = providers[providerId];
    final refreshToken = grant.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw TomOAuthException(
        'oauth.flow.no_refresh_token',
        "The grant for provider '$providerId' carries no refresh token, so a "
            'new access token can only be obtained by asking the user to '
            'authorize again.',
      );
    }
    final response = await _postTokenRequest(provider, <String, String>{
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': provider.clientId,
      // The scope is echoed so a provider that narrows an unrequested refresh
      // cannot silently hand back less than the application already relies on.
      if (grant.scope.isNotEmpty) 'scope': grant.scope,
    }, 'token refresh');
    // `previous` is what keeps the long-lived credential alive: RFC 6749 §6
    // permits omitting `refresh_token` from the response, and taking that
    // omission literally would work perfectly until the access token expired.
    return TomOAuthTokenGrant.fromTokenResponse(response, previous: grant);
  }

  /// Revokes [grant] at [providerId]'s revocation endpoint (RFC 7009).
  ///
  /// Answers `true` when the provider was asked and did not refuse, and
  /// `false` when there was nothing to ask — the provider configures no
  /// `revocationEndpoint`, or the grant carries no token. The two are different
  /// facts and a caller acts on them differently: nothing-to-ask is the
  /// ordinary shape of a deployment whose provider publishes no such endpoint,
  /// while a refusal is worth an operator's attention.
  ///
  /// **The refresh token is what is revoked when there is one.** Revoking it
  /// ends the chain: an access token outlives it by minutes, where a refresh
  /// token outlives a disconnect by months. The access token is the fallback
  /// for a grant that never carried a refresh token at all.
  ///
  /// RFC 7009 specifies an empty `200` for success *and* for a token the
  /// provider does not recognise, which is what makes revoking a grant this
  /// deployment may not have minted harmless. This transport sees bodies rather
  /// than statuses, so an empty body is read as that success, and a body that
  /// decodes to an object carrying `error` is read as the refusal it is.
  ///
  /// Throws [TomOAuthException] (`oauth.flow.revocation_rejected`) on a
  /// refusal, and lets a transport failure out as it comes. Callers that must
  /// not fail for either — [TomExternalIdentityStore.unlink] is the one in this
  /// module — catch around it; see [revokeGrantsFor].
  Future<bool> revokeGrant({
    required String providerId,
    required TomOAuthTokenGrant grant,
  }) async {
    final provider = providers[providerId];
    final endpoint = provider.revocationEndpoint;
    if (endpoint == null || endpoint.isEmpty) return false;

    final refreshToken = grant.refreshToken;
    final revoking = refreshToken != null && refreshToken.isNotEmpty
        ? (token: refreshToken, hint: 'refresh_token')
        : (token: grant.accessToken, hint: 'access_token');
    if (revoking.token.isEmpty) return false;

    final headers = <String, String>{'Accept': 'application/json'};
    final secret = provider.clientSecret;
    if (secret != null) {
      headers['Authorization'] =
          'Basic ${base64.encode(utf8.encode('${Uri.encodeComponent(provider.clientId)}:${Uri.encodeComponent(secret)}'))}';
    }

    final body = await transport.postForm(Uri.parse(endpoint), {
      'token': revoking.token,
      'token_type_hint': revoking.hint,
      'client_id': provider.clientId,
    }, headers);

    if (body.trim().isEmpty) return true;
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      // Not JSON, and not empty. Nothing in RFC 7009 puts a failure here, and
      // a provider that answers prose to a successful revocation is common
      // enough that reading it as a refusal would report failures that are not.
      return true;
    }
    if (decoded is Map && decoded['error'] != null) {
      throw TomOAuthException(
        'oauth.flow.revocation_rejected',
        "The provider refused to revoke the grant for '$providerId': "
            "${decoded['error']} ${decoded['error_description'] ?? ''}",
      );
    }
    return true;
  }

  /// Revokes whatever is held for `(issuer, subject)` at every configured
  /// registration of that issuer, and never throws.
  ///
  /// What [TomExternalIdentityStore.unlink] calls, which is why it cannot fail:
  /// refusing to unlink because a provider is unreachable would leave the
  /// deployment holding the credential it was just told to drop — the opposite
  /// of what pressing disconnect asked for. So every failure is logged and the
  /// deletion proceeds, and the honest reading of the result is *best effort*.
  ///
  /// **Every registration sharing the issuer is asked.** Two registrations
  /// against one IdP is a shape this module supports, and the token store is
  /// keyed by issuer rather than by registration — so which client credentials
  /// minted a grant is not recorded. Asking all of them is what makes the
  /// revocation reliable, and costs nothing: RFC 7009 makes a token the
  /// provider does not recognise a success.
  ///
  /// Answers how many registrations accepted the revocation.
  static Future<int> revokeGrantsFor({
    required String issuer,
    required String subject,
    TomOAuthProviders? providers,
    TomOAuthTokenStore? tokenStore,
    TomOAuthTokenTransport? transport,
  }) async {
    final installedProviders = providers ?? TomOAuthProviders.resolve();
    if (installedProviders == null) return 0;

    final store = tokenStore ?? TomOAuthTokenStore.resolve();
    if (store == null) return 0;

    final TomOAuthTokenGrant? grant;
    try {
      grant = await store.read(issuer, subject);
    } catch (e) {
      tomLog.warn(
        'Could not read the grant for $subject at $issuer before unlinking, '
        'so nothing was revoked at the provider: $e',
      );
      return 0;
    }
    if (grant == null) return 0;

    final flow = TomOAuthFlow(
      providers: installedProviders,
      stateStore: TomOAuthMemoryStateStore(),
      transport: transport ?? TomOAuthTokenTransport.resolve(),
    );

    var revoked = 0;
    for (final provider in installedProviders.providers.values) {
      if (provider.issuer != issuer) continue;
      try {
        if (await flow.revokeGrant(providerId: provider.id, grant: grant)) {
          revoked++;
        }
      } catch (e) {
        tomLog.warn(
          'Revoking the grant for $subject at provider "${provider.id}" '
          'failed: $e. The link and the local copy of the credential are being '
          'deleted anyway — the credential remains valid at the provider until '
          'it expires or the user withdraws consent there.',
        );
      }
    }
    return revoked;
  }

  /// A live access token for `(issuer, subject)` at [providerId], refreshing it
  /// when it is within [minimumValidity] of expiry.
  ///
  /// The method an application actually calls before reaching a provider's API,
  /// and the reason [refreshGrant] alone would not have been enough: "is this
  /// still valid, and if not, renew it and remember the renewal" is three steps
  /// that every caller would otherwise write, and the caller that writes them
  /// wrong writes back nothing — so every call refreshes, and the provider's
  /// rate limiter eventually says so.
  ///
  /// Answers `null` when nothing is held for the identity, when the held grant
  /// has expired and cannot be refreshed, or when no [TomOAuthTokenStore] is
  /// installed at all — the deployment's cue to send the user through consent.
  ///
  /// **A grant found expired and unrefreshable is deleted, not merely reported
  /// as `null`.** It can never mint another token, so it is not a credential
  /// this deployment holds — it is a fact about the past, and a credential store
  /// is the wrong home for one. Leaving it would make the store grow without
  /// bound, make every later call repeat the same read for the same answer, and
  /// leave an operator unable to tell a dead row from a live but idle one. The
  /// module already takes this position where it is most visible:
  /// [TomExternalIdentityStore.unlink] deletes the grant with the link. Nothing
  /// is lost that is wanted — the identity link still records that this user
  /// once consented, and a deployment that wants a history of consent wants the
  /// audit module, not a table of unusable secrets.
  ///
  /// A **rejected refresh is deliberately not purged**, and the contrast is the
  /// point: a provider answering `invalid_grant` during an outage is not proof
  /// the grant is dead, and destroying a credential a retry would have used is
  /// worse than keeping one that is stale. That path throws instead, because a
  /// provider rejecting a refresh token it issued is an event an operator needs
  /// to see rather than an empty answer a job retries forever.
  ///
  /// A grant that declares **no** expiry is never expired and so is never
  /// purged: the provider said nothing about a lifetime, and guessing one would
  /// throw away a working token.
  Future<TomOAuthTokenGrant?> accessTokenFor({
    required String providerId,
    required String subject,
    Duration minimumValidity = const Duration(seconds: 30),
    TomOAuthTokenStore? store,
  }) async {
    final provider = providers[providerId];
    final tokenStore = store ?? TomOAuthTokenStore.resolve();
    if (tokenStore == null) return null;

    final held = await tokenStore.read(provider.issuer, subject);
    if (held == null) return null;
    if (!held.expiresWithin(minimumValidity)) return held;
    if (!held.hasRefreshToken) {
      // Dead: expired with nothing to renew it. The delete is not swallowed if
      // it fails -- a store that cannot delete is broken, and the caller that
      // just read from it is entitled to hear so.
      await tokenStore.delete(provider.issuer, subject);
      return null;
    }

    final refreshed = await refreshGrant(providerId: providerId, grant: held);
    await tokenStore.store(provider.issuer, subject, refreshed);
    return refreshed;
  }

  /// The authorization-code exchange.
  Future<Map<String, Object?>> _exchangeCode(
    TomOAuthProviderConfig provider,
    TomOAuthAuthorizationState pending,
    String code,
  ) => _postTokenRequest(provider, <String, String>{
    'grant_type': 'authorization_code',
    'code': code,
    'redirect_uri': provider.redirectUri,
    'client_id': provider.clientId,
    if (pending.pkce != null) 'code_verifier': pending.pkce!.verifier,
  }, 'code exchange');

  /// One call to the provider's token endpoint, with client authentication.
  ///
  /// Shared by the code exchange and the refresh because the two differ only in
  /// their form: the endpoint, the `client_secret_basic` header and the
  /// error-shaped-200 handling are identical, and a second copy of them is a
  /// second place for the client secret to be presented differently. [what]
  /// names the grant this call performs, and appears in both failures — which
  /// is the difference between a five-minute and a one-hour investigation when a
  /// provider answers `200` with an HTML error page, or rejects a refresh and
  /// the log says "code exchange".
  Future<Map<String, Object?>> _postTokenRequest(
    TomOAuthProviderConfig provider,
    Map<String, String> form,
    String what,
  ) async {
    final headers = <String, String>{'Accept': 'application/json'};
    final secret = provider.clientSecret;
    if (secret != null) {
      // `client_secret_basic` — the authentication method the OIDC spec makes
      // mandatory for a confidential client, and the one every provider
      // supports. `client_secret_post` is optional and provider-dependent, so
      // the secret is not put in the form body.
      headers['Authorization'] =
          'Basic ${base64.encode(utf8.encode('${Uri.encodeComponent(provider.clientId)}:${Uri.encodeComponent(secret)}'))}';
    }

    final body = await transport.postForm(
      Uri.parse(provider.tokenEndpoint),
      form,
      headers,
    );
    final decoded = _decodeJsonObject(body, '$what response');
    if (decoded['error'] != null) {
      throw TomOAuthException(
        'oauth.flow.token_exchange_rejected',
        "The provider rejected the $what: ${decoded['error']} "
            "${decoded['error_description'] ?? ''}",
      );
    }
    return decoded;
  }

  /// The user's claims: from the `id_token` when the provider is OIDC,
  /// otherwise from the configured user-info endpoint.
  Future<Map<String, Object?>> _claimsFor(
    TomOAuthProviderConfig provider,
    Map<String, Object?> tokens,
    TomOAuthAuthorizationState pending,
  ) async {
    final idToken = tokens['id_token'];
    if (idToken is String && idToken.isNotEmpty) {
      final claims = decodeIdTokenClaims(idToken);
      _verifyIdTokenClaims(provider, claims);
      _verifyNonce(provider, claims, pending);
      return claims;
    }
    final userInfoEndpoint = provider.userInfoEndpoint;
    if (userInfoEndpoint == null) {
      throw TomOAuthException(
        'oauth.flow.no_claims_source',
        "Provider '${provider.id}' returned no id_token and configures no "
            'userInfoEndpoint, so the user cannot be identified.',
      );
    }
    final accessToken = tokens['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw TomOAuthException(
        'oauth.flow.no_access_token',
        "Provider '${provider.id}' returned no access token to call its "
            'userInfoEndpoint with.',
      );
    }
    final body = await transport.getJson(Uri.parse(userInfoEndpoint), {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
    });
    return _decodeJsonObject(body, 'user-info response');
  }

  /// Checks the claims TLS does not cover — see the library documentation for
  /// why these and not the signature.
  ///
  /// Two independent questions. *Who minted this* is answered by `iss` and
  /// `aud`; *is it still valid* is answered by `exp` and `nbf`, both read
  /// against [TomOAuthProviderConfig.clockSkew]. The argument that lets the
  /// signature go unchecked is about authenticity over an already-authenticated
  /// channel and says nothing whatever about freshness, so freshness is checked
  /// on its own terms.
  ///
  /// `iat` is read by nobody here, deliberately. It answers "how long ago was
  /// this minted", which becomes a rejection only once a deployment states a
  /// maximum age — a policy this module does not hold, and one the provider has
  /// already expressed in its own terms as `exp`.
  void _verifyIdTokenClaims(
    TomOAuthProviderConfig provider,
    Map<String, Object?> claims,
  ) {
    final issuer = claims['iss'];
    if ('$issuer' != provider.issuer) {
      throw TomOAuthException(
        'oauth.flow.issuer_mismatch',
        "The id_token was issued by '$issuer' but provider '${provider.id}' is "
            "configured for '${provider.issuer}'.",
      );
    }
    // `aud` is a string or an array of strings (OIDC Core §2), and a token
    // minted for another relying party must not be accepted here even when the
    // issuer matches — a shared identity provider issues to many audiences.
    final audience = claims['aud'];
    final audiences = audience is List
        ? audience.map((a) => '$a').toList()
        : ['$audience'];
    if (!audiences.contains(provider.clientId)) {
      throw TomOAuthException(
        'oauth.flow.audience_mismatch',
        "The id_token's audience $audiences does not include the configured "
            "client id for provider '${provider.id}'.",
      );
    }
    _verifyIdTokenFreshness(provider, claims);
  }

  /// Checks that the `id_token` carries the nonce this flow sent.
  ///
  /// OIDC Core §3.1.3.7 makes the check the relying party's whenever it sent a
  /// nonce: a token minted for another flow at the same client — one the user
  /// never started — names a different nonce, or none.
  void _verifyNonce(
    TomOAuthProviderConfig provider,
    Map<String, Object?> claims,
    TomOAuthAuthorizationState pending,
  ) {
    if (pending.nonce.isEmpty) return;
    if (claims['nonce'] != pending.nonce) {
      throw TomOAuthException(
        'oauth.flow.nonce_mismatch',
        "The id_token from provider '${provider.id}' does not carry the nonce "
            'its authorization request sent.',
      );
    }
  }

  /// Checks that the token is inside its own validity window.
  ///
  /// A missing `exp` refuses rather than passing: OIDC Core §2 makes the claim
  /// required, so its absence is a non-conformant provider and not a token that
  /// never expires. Treating "cannot check" as "check passed" would leave the
  /// verification true only of providers that happened to cooperate.
  void _verifyIdTokenFreshness(
    TomOAuthProviderConfig provider,
    Map<String, Object?> claims,
  ) {
    final now = DateTime.now().toUtc();
    final skew = provider.clockSkew;

    final expiresAt = _numericDate(provider, claims, 'exp');
    if (expiresAt == null) {
      throw TomOAuthException(
        'oauth.flow.missing_expiry',
        "The id_token from provider '${provider.id}' carries no 'exp' claim, "
            'so its freshness cannot be established. OIDC Core §2 requires it.',
      );
    }
    if (now.isAfter(expiresAt.add(skew))) {
      throw TomOAuthException(
        'oauth.flow.id_token_expired',
        "The id_token from provider '${provider.id}' expired at "
            '${expiresAt.toIso8601String()}, more than ${skew.inSeconds}s ago.',
      );
    }

    // `nbf` is optional (OIDC Core §2), so absence is ordinary. Present and in
    // the future is not: the provider is saying this token is not yet usable.
    final notBefore = _numericDate(provider, claims, 'nbf');
    if (notBefore != null && now.isBefore(notBefore.subtract(skew))) {
      throw TomOAuthException(
        'oauth.flow.id_token_not_yet_valid',
        "The id_token from provider '${provider.id}' is not valid before "
            '${notBefore.toIso8601String()}, more than ${skew.inSeconds}s away.',
      );
    }
  }

  /// The claim [name] as a NumericDate (RFC 7519 §2), or `null` when absent.
  ///
  /// A numeric string is accepted as well as a number, because providers
  /// stringify these often enough that refusing the spelling would be refusing
  /// a perfectly good token. Anything else throws: a `exp` of `"tomorrow"`
  /// cannot be compared, and silently ignoring it would skip the check.
  DateTime? _numericDate(
    TomOAuthProviderConfig provider,
    Map<String, Object?> claims,
    String name,
  ) {
    final raw = claims[name];
    if (raw == null) return null;
    final seconds = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (seconds == null) {
      throw TomOAuthException(
        'oauth.flow.malformed_id_token',
        "The id_token from provider '${provider.id}' carries a '$name' claim "
            "of '$raw', which is not a NumericDate.",
      );
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// Projects the provider's claims onto a [TomExternalIdentity] through the
  /// provider's configured claim names.
  TomExternalIdentity _identityFor(
    TomOAuthProviderConfig provider,
    Map<String, Object?> claims,
  ) {
    final subject = claims[provider.subjectClaim];
    if (subject == null || '$subject'.isEmpty) {
      throw TomOAuthException(
        'oauth.flow.missing_subject',
        "Provider '${provider.id}' returned no '${provider.subjectClaim}' "
            'claim, so the user has no stable identifier to link an account to.',
      );
    }
    return TomExternalIdentity(
      issuer: provider.issuer,
      subject: '$subject',
      username: '${claims[provider.usernameClaim] ?? ''}',
      displayName: '${claims[provider.displayNameClaim] ?? ''}',
      claims: Map.unmodifiable(claims),
      groups: provider.roleMapping.groupsIn(claims),
      roles: provider.roleMapping.rolesFor(claims),
    );
  }

  /// [byteCount] cryptographically secure bytes, base64url-encoded without
  /// padding — the shape a PKCE verifier, a `state` handle, a nonce and a SAML
  /// handoff code all need, and what keeps each safe to put in a query string.
  static String randomHandle(int byteCount) {
    final random = Random.secure();
    return base64Url
        .encode(List<int>.generate(byteCount, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  /// The claims of a JWT, **without** verifying its signature.
  ///
  /// Public because a test asserting the flow's behaviour needs to build the
  /// same shape the provider sends, and because the reasoning for not verifying
  /// (see the library documentation) is a property of *where the token came
  /// from*, which only the caller knows. Never call it on a token that did not
  /// arrive over an authenticated back channel.
  static Map<String, Object?> decodeIdTokenClaims(String idToken) {
    final segments = idToken.split('.');
    if (segments.length < 2) {
      throw TomOAuthException(
        'oauth.flow.malformed_id_token',
        'The id_token is not a JWT: expected at least a header and a payload.',
      );
    }
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(segments[1])),
      );
      return _decodeJsonObject(payload, 'id_token payload');
    } on TomOAuthException {
      rethrow;
    } catch (ex) {
      throw TomOAuthException(
        'oauth.flow.malformed_id_token',
        'The id_token payload could not be decoded: $ex',
      );
    }
  }

  /// Decodes [body] as a JSON object, naming [what] in the failure.
  ///
  /// A provider that answers `200` with an HTML error page is common enough
  /// that "unexpected character" from `jsonDecode` is a real diagnosis problem;
  /// naming which response failed is the difference between a five-minute and a
  /// one-hour investigation.
  static Map<String, Object?> _decodeJsonObject(String body, String what) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (ex) {
      throw TomOAuthException(
        'oauth.provider.malformed_json',
        'The provider $what was not valid JSON: $ex',
      );
    }
    if (decoded is! Map) {
      throw TomOAuthException(
        'oauth.provider.malformed_json',
        'The provider $what was a ${decoded.runtimeType}, not a JSON object.',
      );
    }
    return decoded.map((key, value) => MapEntry('$key', value));
  }
}

/// base64url without padding, which is what RFC 7636 specifies for the
/// challenge.
String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

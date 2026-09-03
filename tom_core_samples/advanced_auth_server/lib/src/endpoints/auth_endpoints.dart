/// The auth server's `/auth/*` HTTP surface — credential login and the token
/// lifecycle.
///
/// Two collaborators, split by responsibility:
///
/// - [AuthTokenService] is the pure, database- and request-free logic: it turns
///   a [LoginRequest] (or an already-authenticated [TomPrincipal]) into the
///   signed JWT pair and the wire [LoginResult]/[UserDto]. It takes its
///   collaborators by constructor, so the accept/reject/echo behaviour is
///   unit-tested directly against a seeded [AdvancedAuthenticationService] — no
///   server, no zone, no reflection.
/// - [AdvancedAuthApiService] is the thin `@tomComponent` adapter the endpoint
///   pipeline routes to. It binds each [AuthApiService] method to its registry
///   endpoint (`tomRemoteApis['auth'][...]`), sources the caller's principal
///   from the bearer token in the request zone, and maps a rejected login to
///   HTTP 401. It carries the production wiring (the repository-backed store,
///   the configured JWT issuer) and is exercised end-to-end by
///   `bin/auth_server_start.dart`.
///
/// The split keeps the token logic testable while the component stays a
/// boundary adapter — the same seam philosophy as `AuthUserStore` in
/// `auth/authentication_service.dart`.
library;

import 'dart:convert';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../auth/authentication_service.dart';
import '../resources/auth_resource_bundles.dart';

/// Builds the signed token pair and the wire DTOs from a verified login,
/// including the two-pass second-factor flow.
///
/// Pure over its two inputs — the [AdvancedAuthenticationService] that verifies
/// credentials and the JWT [issuer] — so it runs in a unit test with a seeded
/// in-memory store and no live server.
///
/// [login] and [submitSecondFactor] delegate to the framework's
/// [TomAuthenticationServer] rather than minting tokens themselves. That is what
/// buys the sample the second pass for free: challenge issuance, the attempt
/// counter, expiry, adaptor dispatch and — crucially — the guarantee that a
/// completed pass 2 yields exactly the token a 2FA-free login would have, all
/// live in the framework's single issuance point. [refresh] still encodes
/// directly, because re-issuing for an already-authenticated principal is not a
/// login and must not re-run the credential check.
class AuthTokenService {
  /// How long an issued token pair stays valid; also the [LoginResult.expiresAt]
  /// horizon. Matches `TomServerJwtToken`'s own default expiry, which is what
  /// the framework's issuance path uses.
  static const Duration tokenLifetime = Duration(hours: 2);

  final AdvancedAuthenticationService _authentication;
  final String _issuer;
  final TomAuthenticationServer _server = TomAuthenticationServer();

  /// Builds the token service over the credential-checking [authentication]
  /// service. [issuer] defaults to the server-wide JWT organization
  /// (`TomAuthenticationServer.globalSettingJwtOrganization`).
  ///
  /// The framework selects both the credential service and the issuer through
  /// statics, so the constructor installs them. Doing it here rather than
  /// leaving it to each caller is deliberate: the default
  /// `TomDummyAuthenticationService` *accepts every login*, so forgetting the
  /// wiring would not fail loudly — it would authenticate everyone.
  AuthTokenService(this._authentication, {String? issuer})
    : _issuer = issuer ?? TomAuthenticationServer.globalSettingJwtOrganization {
    TomAuthenticationServer.globalSettingUserAuthenticationService =
        _authentication;
    TomAuthenticationServer.globalSettingJwtOrganization = _issuer;
    installTotpSecretResolver(_authentication.store);
  }

  /// Verifies [request] and issues the signed token pair, or throws
  /// [TomLoginException] when the login is rejected (unknown user, wrong
  /// password, suspended account).
  ///
  /// When the account is enrolled in a second factor the login is only half
  /// done: the returned [LoginResult] carries `requires2FA`, the mechanism key,
  /// and the *interim* token pair holding the challenge. That pair authenticates
  /// nothing; complete the login with [submitSecondFactor].
  Future<LoginResult> login(LoginRequest request) async =>
      _resultFor(await _server.authenticatePass1(_messageFor(request)));

  /// Answers a pending challenge and, on success, returns the completed token
  /// pair — the same one a 2FA-free login for this user would have produced.
  ///
  /// Throws [TomLoginException] carrying the framework's stable key when the
  /// submission is refused: `login.error.2fa.invalid-code` (retryable — the
  /// client re-submits against the token from the *failed* attempt, whose
  /// counter has advanced), `login.error.2fa.attempts-exhausted`,
  /// `login.error.2fa.expired`, or `login.error.2fa.no-challenge`.
  Future<LoginResult> submitSecondFactor(SecondFactorRequest request) async {
    if (request.challengeToken.isEmpty) {
      throw TomLoginException(
        'login.error.2fa.no-challenge',
        'No pending two-factor challenge was presented',
      );
    }
    // The interim *authorization* token: decrypting it is what recovers the
    // access-control payload pass 1 resolved and the adaptor's private
    // verification blob, so pass 2 needs no second trip to the user store and
    // the principal cannot be swapped between the passes.
    final challengeToken = TomClientJwtToken(request.challengeToken);
    final message = _messageFor(
      LoginRequest(username: '', password: request.code),
    );
    return _resultFor(
      await _server.authenticatePass2(message, challengeToken: challengeToken),
    );
  }

  /// Starts enrolling the mechanism the user chose from
  /// [LoginResult.availableTwoFactorMethods].
  ///
  /// Returns a fresh interim result whose token claims carry what the client
  /// has to render — for TOTP the `otpauth://` URI and the base32 secret. The
  /// server refuses a mechanism it did not itself offer on the presented token,
  /// so [TwoFactorEnrolmentRequest.type] is a selection, never an assertion.
  Future<LoginResult> beginEnrolment(TwoFactorEnrolmentRequest request) =>
      _enrolmentPass(
        request,
        request.type,
        (message, token) =>
            _server.beginTwoFactorEnrolment(message, enrolmentToken: token),
      );

  /// Confirms the offer with the code the user derived from it and, on success,
  /// completes the login with the final token pair.
  ///
  /// A wrong code throws [SecondFactorRetryException] carrying the re-issued
  /// interim token with one attempt spent — the same retry contract
  /// [submitSecondFactor] has, and for the same reason: the counter lives in
  /// the token, so retrying against a stale copy would never spend anything.
  Future<LoginResult> confirmEnrolment(TwoFactorEnrolmentRequest request) =>
      _enrolmentPass(
        request,
        request.code,
        (message, token) =>
            _server.completeTwoFactorEnrolment(message, enrolmentToken: token),
      );

  /// Declines a skippable offer and completes the login with no factor.
  ///
  /// Carries no payload: the token alone says both who is declining and whether
  /// declining was permitted, and the server re-checks the latter from its own
  /// signature rather than trusting the client's decision to call this at all.
  Future<LoginResult> skipEnrolment(TwoFactorEnrolmentRequest request) =>
      _enrolmentPass(
        request,
        '',
        (message, token) =>
            _server.skipTwoFactorEnrolment(message, enrolmentToken: token),
      );

  /// The shape every enrolment pass shares: require the interim token, put the
  /// pass's one user-supplied [payload] in the message's payload slot, run
  /// [pass], and project the framework's answer onto the wire.
  ///
  /// Factored out because the three passes differ only in which framework
  /// method they call and what goes in that slot — writing the token check, the
  /// message build and the projection three times would make three places to
  /// forget the check.
  Future<LoginResult> _enrolmentPass(
    TwoFactorEnrolmentRequest request,
    String payload,
    Future<TomAuthenticationResult> Function(
      TomAuthenticationMessage message,
      TomClientJwtToken token,
    )
    pass,
  ) async {
    if (request.enrolmentToken.isEmpty) {
      throw TomLoginException(
        'login.error.2fa.no-enrolment',
        'No pending two-factor enrolment was presented',
      );
    }
    final message = _messageFor(LoginRequest(username: '', password: payload));
    return _resultFor(
      await pass(message, TomClientJwtToken(request.enrolmentToken)),
    );
  }

  /// Re-issues a fresh token pair for an already-authenticated [principal]
  /// (the `/auth/refresh` path). The principal's existing access-control
  /// information is re-encoded; no definition-based inheritance resolution is
  /// applied (the sample has none).
  LoginResult refresh(TomPrincipal principal) => _issueFor(
    principal,
    null,
    clientCountry: principal.clientCountry,
    clientLanguage: principal.clientLanguage,
  );

  /// Projects an authenticated [principal] onto the password-free wire DTO.
  ///
  /// Only an `active` account can hold an authenticated principal (login rejects
  /// suspended accounts), so the projected status is always [UserStatus.active].
  UserDto userDtoOf(TomPrincipal principal) => UserDto(
    id: principal.user.id.toString(),
    username: principal.username,
    displayName: principal.user.firstname ?? '',
    email: principal.user.email ?? '',
    status: UserStatus.active.name,
  );

  /// Encodes [principal] (+ optional [acd]) into the authentication and
  /// authorization JWTs and assembles the [LoginResult].
  LoginResult _issueFor(
    TomPrincipal principal,
    TomAccessControlDefinition? acd, {
    String? clientCountry,
    String? clientLanguage,
  }) {
    final (
      publicInfo,
      privateInfo,
    ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
      principal,
      acd,
      clientCountry,
      clientLanguage,
    );
    final authToken = TomServerJwtToken(
      publicInfo,
      expiresIn: tokenLifetime,
    ).getJWT(_issuer);
    final authzToken = TomServerJwtToken(
      publicInfo,
      encryptedData: privateInfo,
      expiresIn: tokenLifetime,
    ).getJWT(_issuer);
    return LoginResult(
      user: userDtoOf(principal),
      authToken: authToken,
      authzToken: authzToken,
      expiresAt: DateTime.now().toUtc().add(tokenLifetime),
    );
  }

  /// Maps a [LoginRequest] onto the framework's wire message. The single-tenant
  /// sample fixes the locale/client fields the multi-tenant UAM server resolves
  /// per request — the same single-tenant choice
  /// [AdvancedAuthenticationService] makes.
  TomAuthenticationMessage _messageFor(LoginRequest request) =>
      TomAuthenticationMessage()
        ..userName = request.username
        ..password = request.password
        ..organization = request.org
        ..application = request.app
        ..process = 'default'
        ..clientLanguage = 'en'
        ..clientCountry = 'US'
        ..clientTimezone = 'UTC'
        ..client = 'web';

  /// Projects a framework [result] onto the wire [LoginResult], or throws the
  /// [TomLoginException] its stable error key describes.
  ///
  /// The principal is read back out of the issued token rather than kept aside
  /// from the credential check, so both passes project from the same place —
  /// and the DTO can only ever describe what the token actually says.
  LoginResult _resultFor(TomAuthenticationResult result) {
    if (result.error.isNotEmpty) throw _failureFor(result);

    final principal = TomBearerAuthentication.convertTokenPayloadToPrincipal(
      TomClientJwtToken(result.authenticationToken, decrypt: false),
    );
    return LoginResult(
      user: userDtoOf(principal),
      authToken: result.authenticationToken,
      authzToken: result.authorizationToken,
      expiresAt: DateTime.now().toUtc().add(tokenLifetime),
      requires2FA: result.requires2FA,
      twoFactorType: result.twoFactorType,
      requires2FAEnrolment: result.requires2FAEnrolment,
      availableTwoFactorMethods: result.availableTwoFactorMethods,
      twoFactorEnrolmentSkippable: result.twoFactorEnrolmentSkippable,
    );
  }

  /// Turns a failed framework [result] into the exception the endpoint answers
  /// with — preserving the re-issued challenge token when the framework offered
  /// a retry.
  TomLoginException _failureFor(TomAuthenticationResult result) {
    if (result.authorizationToken.isNotEmpty) {
      return SecondFactorRetryException(
        result.error,
        'The submitted second factor was not accepted',
        challengeToken: result.authorizationToken,
      );
    }
    return TomLoginException(result.error, 'Login failed (${result.error})');
  }
}

/// A refused second factor that the framework is still willing to be asked
/// about — carrying the *re-issued* interim token.
///
/// The distinction matters for more than convenience. The attempt counter lives
/// in the token, so a client that kept retrying against the copy it already held
/// would never advance it and would see "3 tries left" forever. Handing the
/// re-issued token back with the refusal is what lets an honest client — and the
/// UI counting down for the user — actually spend the challenge.
///
/// It is not, and cannot be, a brute-force defence: a stateless server keeps no
/// record of the tokens it has answered, so nothing stops a *hostile* client
/// replaying the pass-1 token for a fresh attempt. What bounds that is the
/// challenge's short expiry — see `TomAuthenticationServer.authenticatePass2`,
/// which documents the trade-off and what a deployment needing a hard cap has to
/// add.
class SecondFactorRetryException extends TomLoginException {
  /// The re-issued interim authorization token, with the spent attempt recorded.
  final String challengeToken;

  /// Creates a retryable second-factor refusal.
  SecondFactorRetryException(
    super.key,
    super.defaultUserMessage, {
    required this.challengeToken,
  });
}

/// Returns HTTP 401 for a rejected login and falls back to the opaque 500 for
/// anything else.
///
/// A [TomLoginException] is the expected outcome of bad credentials, so the
/// login endpoint answers it with `401 Unauthorized` carrying only the stable
/// error key — never which of username/password failed (no account-existence
/// leak). Any other error is a genuine fault and is
/// masked behind the default handler's generic 500.
///
/// A [SecondFactorRetryException] additionally carries the re-issued challenge
/// token in the body: the refusal is still a 401, but the client needs that
/// token to make its next attempt count (see the exception's own note).
class LoginUnauthorizedErrorHandler extends TomErrorHandler {
  /// Const so it can be referenced from the endpoint annotation.
  const LoginUnauthorizedErrorHandler();

  @override
  Response handleErrorDefault(
    Object error,
    Object stacktrace,
    Request r,
    Object? result,
  ) {
    if (error is TomLoginException) {
      return Response.unauthorized(
        jsonEncode({
          'error': error.key,
          if (error is SecondFactorRetryException)
            'challengeToken': error.challengeToken,
        }),
        headers: {TomHeader.contentType: TomMimeType.json.toHeaderValue()},
        encoding: Encoding.getByName('UTF-8'),
      );
    }
    return const TomDefaultErrorHandler().handleErrorDefault(
      error,
      stacktrace,
      r,
      result,
    );
  }
}

/// The shared 401-mapping handler instance the login endpoint declares.
const LoginUnauthorizedErrorHandler _loginErrorHandler =
    LoginUnauthorizedErrorHandler();

/// The `@tomComponent` implementing the registry's `auth` API.
///
/// Bound to every endpoint of the registry's `auth` API
/// (`tomRemoteApis['auth']`); the bean container instantiates it through the
/// no-argument constructor, which wires the production [AuthTokenService] over
/// the repository-backed user store. The per-endpoint access policy is
/// **declared on the contract** (each `authApi` endpoint's
/// `TomApiEndpoint.access`, G-API-3) and extracted by the pipeline on first
/// call, so these handlers carry no inline access annotation: everything a
/// caller needs *before* it holds a session token is public — credential
/// exchange, the second factor, the enrolment passes and the pre-login
/// resource bundle — while the session endpoints (`authRefresh`, `authLogout`,
/// `authMe`) require an authenticated principal, which the pipeline reads from
/// the bearer token.
@tomReflector
@tomComponent
@TomApiImplementation(apiId: 'auth')
class AdvancedAuthApiService implements AuthApiService {
  /// Production token logic: verifies credentials through the repository-backed
  /// store and signs with the server-wide JWT issuer.
  ///
  /// The login does not fold effective per-resource roles into the token: the
  /// token is an opaque bearer, enforcement re-resolves the
  /// `tom_principal_resource_grant` and `tom_principal_delegation` rows live from
  /// `auth_db` on every request, and the client reads its current roles from the
  /// app server's `/resource-roles` endpoint — so no grant/delegation repository
  /// is wired here. See [AdvancedAuthenticationService] for the full reasoning.
  final AuthTokenService _tokens = AuthTokenService(
    AdvancedAuthenticationService(const RepositoryAuthUserStore()),
  );

  @TomApiEndpointImplementation(
    apiId: 'auth',
    endpointId: 'authLogin',
    errorHandler: _loginErrorHandler,
  )
  @override
  Future<LoginResult> login(LoginRequest request) => _tokens.login(request);

  // Public like `authLogin`, and for the same reason: the caller has no usable
  // token yet. The interim token it presents in the body is by construction
  // unauthenticated, so a bearer gate would reject the very request this
  // endpoint exists to serve.
  @TomApiEndpointImplementation(
    apiId: 'auth',
    endpointId: 'authSecondFactor',
    errorHandler: _loginErrorHandler,
  )
  @override
  Future<LoginResult> submitSecondFactor(SecondFactorRequest request) =>
      _tokens.submitSecondFactor(request);

  // The three enrolment passes, public for the same reason `authSecondFactor`
  // is and answering refusals through the same 401 handler — a refused
  // confirmation is a retryable second-factor failure and needs the re-issued
  // token in the body to stay retryable.
  @TomApiEndpointImplementation(
    apiId: 'auth',
    endpointId: 'authBeginEnrolment',
    errorHandler: _loginErrorHandler,
  )
  @override
  Future<LoginResult> beginEnrolment(TwoFactorEnrolmentRequest request) =>
      _tokens.beginEnrolment(request);

  @TomApiEndpointImplementation(
    apiId: 'auth',
    endpointId: 'authConfirmEnrolment',
    errorHandler: _loginErrorHandler,
  )
  @override
  Future<LoginResult> confirmEnrolment(TwoFactorEnrolmentRequest request) =>
      _tokens.confirmEnrolment(request);

  @TomApiEndpointImplementation(
    apiId: 'auth',
    endpointId: 'authSkipEnrolment',
    errorHandler: _loginErrorHandler,
  )
  @override
  Future<LoginResult> skipEnrolment(TwoFactorEnrolmentRequest request) =>
      _tokens.skipEnrolment(request);

  @TomApiEndpointImplementation(apiId: 'auth', endpointId: 'authRefresh')
  @override
  Future<LoginResult> refresh() async =>
      _tokens.refresh(getFromCurrentZone<TomPrincipal>()!);

  @TomApiEndpointImplementation(apiId: 'auth', endpointId: 'authLogout')
  @override
  Future<void> logout() async {
    // Stateless bearer JWTs carry their own expiry, so there is no server-side
    // session to destroy on logout; the client discards the token pair and it
    // lapses on its own. Kept as an explicit endpoint so the contract's clients
    // have a logout to call (and a future deny-list can hook in here).
  }

  @TomApiEndpointImplementation(apiId: 'auth', endpointId: 'authMe')
  @override
  // The per-request principal is recovered from the Dart zone the server's
  // authentication middleware populates (`getFromCurrentZone`), not from the
  // `TomBearerAuthentication` static singleton (a client-side token store the
  // server never fills). The contract's `authMe` endpoint declares
  // `TomAuthenticatedAccess`, so the pipeline rejected the request before
  // invocation if no principal was present — the zone value is non-null here.
  Future<UserDto> me() async =>
      _tokens.userDtoOf(getFromCurrentZone<TomPrincipal>()!);

  // `loginResources` (`authLoginResources`, public `GET /auth/resources/login`)
  // serves the genuinely-public login-screen texts a client installs *before*
  // sign-in (`login.*` for the app client, `adminLogin.*` for the admin
  // console). Public — no bearer — because the login form needs its strings to
  // render the very screen on which a user obtains a token.
  @TomApiEndpointImplementation(apiId: 'auth', endpointId: 'authLoginResources')
  @override
  Future<ResourceBundleDto> loginResources() async =>
      AuthResourceBundles.loginBundle();
}

/// The auth server's `/auth/*` HTTP surface — credential login and the token
/// lifecycle (step 11).
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
///   the configured JWT issuer) and is exercised end-to-end at boot (step 13).
///
/// The split keeps the token logic testable while the component stays a
/// boundary adapter — the same seam philosophy as the step-10 `AuthUserStore`.
library;

import 'dart:convert';

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../auth/authentication_service.dart';

/// Builds the signed token pair and the wire DTOs from a verified login.
///
/// Pure over its two inputs — the [AdvancedAuthenticationService] that verifies
/// credentials and the JWT [issuer] — so it runs in a unit test with a seeded
/// in-memory store and no live server. Mirrors the issuance
/// `TomAuthenticationServer.authenticateUser` performs (a public
/// authentication token plus an authorization token carrying the encrypted
/// access-control payload), but returns the principal-derived [LoginResult] the
/// contract's clients consume.
class AuthTokenService {
  /// How long an issued token pair stays valid; also the [LoginResult.expiresAt]
  /// horizon. Matches `TomServerJwtToken`'s own default expiry.
  static const Duration tokenLifetime = Duration(hours: 2);

  final AdvancedAuthenticationService _authentication;
  final String _issuer;

  /// Builds the token service over the credential-checking [authentication]
  /// service. [issuer] defaults to the server-wide JWT organization
  /// (`TomAuthenticationServer.globalSettingJwtOrganization`).
  AuthTokenService(this._authentication, {String? issuer})
      : _issuer = issuer ?? TomAuthenticationServer.globalSettingJwtOrganization;

  /// Verifies [request] and issues the signed token pair, or throws
  /// [LoginException] when the login is rejected (unknown user, wrong password,
  /// suspended account).
  Future<LoginResult> login(LoginRequest request) async {
    final authData = _authDataFor(request);
    final info = await _authentication.authenticateUser(authData);
    return _issueFor(
      info.principal,
      info.acd,
      clientCountry: authData.country,
      clientLanguage: authData.language,
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
    final (publicInfo, privateInfo) =
        TomBearerAuthentication.convertPrincipalToTokenPayload(
      principal,
      acd,
      clientCountry,
      clientLanguage,
    );
    final authToken =
        TomServerJwtToken(publicInfo, expiresIn: tokenLifetime).getJWT(_issuer);
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

  /// Maps a [LoginRequest] onto the framework's [TomAuthenticationData]. The
  /// single-tenant sample fixes the locale/client fields the multi-tenant UAM
  /// server resolves per request (see step-10 decision 2).
  TomAuthenticationData _authDataFor(LoginRequest request) =>
      TomAuthenticationData(
        username: request.username,
        key: request.password,
        organization: request.org,
        application: request.app,
        process: 'default',
        language: 'en',
        country: 'US',
        timezone: 'UTC',
        client: 'web',
      );
}

/// Returns HTTP 401 for a rejected login and falls back to the opaque 500 for
/// anything else.
///
/// A [LoginException] is the expected outcome of bad credentials, so the login
/// endpoint answers it with `401 Unauthorized` carrying only the stable error
/// key — never which of username/password failed (no account-existence leak,
/// per step-10 decision 3). Any other error is a genuine fault and is masked
/// behind the default handler's generic 500.
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
    if (error is LoginException) {
      return Response.unauthorized(
        jsonEncode({'error': error.key}),
        headers: {TomHeader.contentType: TomMimeType.json.toHeaderValue()},
        encoding: Encoding.getByName('UTF-8'),
      );
    }
    return const TomDefaultErrorHandler()
        .handleErrorDefault(error, stacktrace, r, result);
  }
}

/// The shared 401-mapping handler instance the login endpoint declares.
const LoginUnauthorizedErrorHandler _loginErrorHandler =
    LoginUnauthorizedErrorHandler();

/// The `@tomComponent` implementing the registry's `auth` API.
///
/// Bound to the four `authApi` endpoints (`tomRemoteApis['auth']`); the bean
/// container instantiates it through the no-argument constructor, which wires
/// the production [AuthTokenService] over the repository-backed user store. The
/// access annotations are declared explicitly (the registry's `authApiAccess`
/// map is informational, not auto-applied): `login` is public, the rest require
/// an authenticated principal, which the pipeline reads from the bearer token.
@tomReflector
@tomComponent
@TomApiImplementation(apiId: 'auth')
class AdvancedAuthApiService implements AuthApiService {
  /// Production token logic: verifies credentials through the repository-backed
  /// store and signs with the server-wide JWT issuer.
  final AuthTokenService _tokens = AuthTokenService(
    AdvancedAuthenticationService(const RepositoryAuthUserStore()),
  );

  @TomPublicAccess()
  @TomApiEndpointImplementation(
    apiId: 'auth',
    endpointId: 'authLogin',
    errorHandler: _loginErrorHandler,
  )
  @override
  Future<LoginResult> login(LoginRequest request) => _tokens.login(request);

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'auth', endpointId: 'authRefresh')
  @override
  Future<LoginResult> refresh() async =>
      _tokens.refresh(getFromCurrentZone<TomPrincipal>()!);

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'auth', endpointId: 'authLogout')
  @override
  Future<void> logout() async {
    // Stateless bearer JWTs carry their own expiry, so there is no server-side
    // session to destroy on logout; the client discards the token pair and it
    // lapses on its own. Kept as an explicit endpoint so the contract's clients
    // have a logout to call (and a future deny-list can hook in here).
  }

  @TomAuthenticatedAccess()
  @TomApiEndpointImplementation(apiId: 'auth', endpointId: 'authMe')
  @override
  // The per-request principal is recovered from the Dart zone the server's
  // authentication middleware populates (`getFromCurrentZone`), not from the
  // `TomBearerAuthentication` static singleton (a client-side token store the
  // server never fills). `@TomAuthenticatedAccess` guarantees the pipeline
  // rejected the request before invocation if no principal was present, so the
  // zone value is non-null here.
  Future<UserDto> me() async =>
      _tokens.userDtoOf(getFromCurrentZone<TomPrincipal>()!);
}

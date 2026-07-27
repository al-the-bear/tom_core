/// The auth server's `/auth/*` client: credential login, token refresh, and
/// logout, with token storage through [TomBearerAuthentication] (step 22).
///
/// Pure JSON↔DTO mapping lives in the contract DTOs ([LoginRequest]/
/// [LoginResult]); this client only sequences the HTTP call, maps a non-success
/// status to a typed [AuthClientException], and on success stores the returned
/// token pair so every following request can attach the bearer. Talking through
/// the [JsonTransport] seam keeps it testable against a fake — the integration
/// test points it at the live auth server, the unit tests at a canned transport.
library;

import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../http/json_transport.dart';

/// Raised when an auth request fails: rejected credentials (the server's 401) or
/// any other non-success status.
///
/// Carries the HTTP [statusCode] and, when the server sent one, its stable
/// error [key] (so a UI can branch on `auth.login.failed` etc. without parsing a
/// message). A rejected login deliberately never says *which* of username or
/// password was wrong — the server returns only the opaque key.
class AuthClientException extends TomException {
  /// The HTTP status that triggered this (0 when the failure was client-side,
  /// e.g. refresh without a stored token).
  final int statusCode;

  /// Whether the server is still willing to accept another attempt at the same
  /// pending second-factor challenge.
  ///
  /// When true, [AuthClient] has already stored the re-issued interim token, so
  /// the caller simply asks the user for another code and calls
  /// [AuthClient.submitSecondFactor] again — and
  /// `TomBearerAuthentication.pendingTwoFactorChallenge` reports how many
  /// attempts are left. When false the challenge is spent (wrong too often,
  /// lapsed, or never existed) and the caller must start again at [
  /// AuthClient.login].
  final bool canRetrySecondFactor;

  /// Builds the exception from the stable [key], a human [defaultUserMessage]
  /// and the originating [statusCode].
  AuthClientException(
    super.key,
    super.defaultUserMessage, {
    required this.statusCode,
    this.canRetrySecondFactor = false,
  });
}

/// Logs in, refreshes and logs out against the auth server, storing the token
/// pair in [TomBearerAuthentication] on success.
class AuthClient {
  /// Base URL of the auth server, e.g. `http://localhost:8081` (no `/auth`
  /// suffix — the endpoint paths add it).
  final Uri baseUri;

  final JsonTransport _transport;
  final bool _decryptTokens;

  /// Builds the client against [baseUri].
  ///
  /// [transport] defaults to the live [IoJsonTransport]; tests pass a fake.
  /// [decryptTokens] controls whether the stored authorization token's encrypted
  /// payload is decrypted locally — `false` for this Flutter-free sample, which
  /// treats the authorization token as an opaque bearer and reads identity from
  /// [LoginResult.user] and field grades from the app API, so no RSA key needs
  /// to be configured client-side.
  AuthClient(
    this.baseUri, {
    JsonTransport? transport,
    bool decryptTokens = false,
  })  : _transport = transport ?? IoJsonTransport(),
        _decryptTokens = decryptTokens;

  /// Exchanges [request] credentials for the token pair, stores it, and returns
  /// the resolved [LoginResult]. Throws [AuthClientException] on a rejected
  /// login (401) or any other non-success status.
  ///
  /// When the account owes a second factor the returned result carries
  /// [LoginResult.requires2FA] and the stored pair is the *interim* one: it
  /// authenticates nothing, and [pendingChallenge] then describes what to ask
  /// the user for. Complete the login with [submitSecondFactor].
  Future<LoginResult> login(LoginRequest request) async {
    final response = await _transport.send(
      method: 'POST',
      uri: _uri('/auth/login'),
      body: dtoToJsonString(request),
    );
    final result = _requireLogin(response, 'auth.login.failed');
    _store(result);
    return result;
  }

  /// The challenge the stored interim token is waiting on, or `null` when there
  /// is no half-finished login.
  ///
  /// Read straight out of the token's public claims by the kernel, so the
  /// mechanism key, the displayable hint, the remaining attempts, the expiry and
  /// the mechanism's own `clientData` all come from one place — the client never
  /// tracks challenge state of its own that could drift from the server's.
  Tom2FAChallenge? get pendingChallenge =>
      TomBearerAuthentication.pendingTwoFactorChallenge;

  /// Answers [pendingChallenge] with [code] and, on success, stores and returns
  /// the completed token pair — the same one a 2FA-free login would have given.
  ///
  /// A refused code throws [AuthClientException]; when
  /// [AuthClientException.canRetrySecondFactor] is set, the re-issued interim
  /// token has *already been stored*, so retrying is just another call to this
  /// method with a new code.
  Future<LoginResult> submitSecondFactor(String code) async {
    final challengeToken = TomBearerAuthentication.authorizationToken;
    if (challengeToken == null) {
      throw AuthClientException(
        'auth.no_token',
        'No pending two-factor challenge — log in first.',
        statusCode: 0,
      );
    }
    final response = await _transport.send(
      method: 'POST',
      uri: _uri('/auth/second-factor'),
      body: dtoToJsonString(
        SecondFactorRequest(code: code, challengeToken: challengeToken),
      ),
    );
    if (!response.isSuccess) throw _secondFactorFailure(response);
    final result = dtoFromJson<LoginResult>(response.jsonObject);
    _store(result);
    return result;
  }

  /// Builds the exception for a refused second factor, first storing the
  /// re-issued interim token when the server offered one.
  ///
  /// Storing it is not a nicety: the attempt counter lives inside the token, so
  /// a client that kept retrying against its previous copy would never exhaust
  /// the challenge and would show the user the same "3 tries left" forever.
  /// Overwriting the stored token is how an honest client spends its attempts.
  /// (It is not a brute-force defence — a stateless server cannot detect the
  /// replay; the challenge expiry is what bounds that.)
  AuthClientException _secondFactorFailure(HttpJsonResponse response) {
    final retryToken = _stringField(response, 'challengeToken');
    if (retryToken != null && retryToken.isNotEmpty) {
      TomBearerAuthentication.setTokens(retryToken, retryToken, _decryptTokens);
    }
    return AuthClientException(
      _errorKey(response) ?? 'auth.second_factor.failed',
      'Second factor rejected (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
      canRetrySecondFactor: retryToken != null && retryToken.isNotEmpty,
    );
  }

  /// Fetches the public login resource bundle (`GET /auth/resources/login`),
  /// the screen texts both clients install before the sign-in screen builds.
  ///
  /// Public endpoint — no bearer is attached and no prior [login] is needed.
  /// Throws [AuthClientException] on any non-success status.
  Future<ResourceBundleDto> loginResources() async {
    final response = await _transport.send(
      method: 'GET',
      uri: _uri('/auth/resources/login'),
    );
    if (!response.isSuccess) {
      throw AuthClientException(
        _errorKey(response) ?? 'auth.resources.failed',
        'Login resources request failed (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return dtoFromJson<ResourceBundleDto>(response.jsonObject);
  }

  /// Re-issues a fresh token pair for the currently stored session and stores
  /// it. Requires a prior [login] (an authorization token must be present), else
  /// throws `auth.no_token`.
  Future<LoginResult> refresh() async {
    final response = await _transport.send(
      method: 'POST',
      uri: _uri('/auth/refresh'),
      headers: _bearerHeader(),
    );
    final result = _requireLogin(response, 'auth.refresh.failed');
    _store(result);
    return result;
  }

  /// Logs out: tells the server (best-effort — stateless JWTs have no session to
  /// destroy) and then discards the local token pair so no later request carries
  /// it. The local discard happens even if the server call fails.
  Future<void> logout() async {
    try {
      if (TomBearerAuthentication.authorizationToken != null) {
        await _transport.send(
          method: 'POST',
          uri: _uri('/auth/logout'),
          headers: _bearerHeader(),
        );
      }
    } finally {
      // Drops the token pair *and* the cached principal — including a
      // half-finished 2FA login, so an abandoned challenge is not left lying
      // around for the next attempt to pick up.
      TomBearerAuthentication.clearTokens();
    }
  }

  /// Parses a successful login/refresh response or throws [AuthClientException]
  /// (using the server's error key when present, else [fallbackKey]).
  LoginResult _requireLogin(HttpJsonResponse response, String fallbackKey) {
    if (!response.isSuccess) {
      throw AuthClientException(
        _errorKey(response) ?? fallbackKey,
        'Auth request failed (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return dtoFromJson<LoginResult>(response.jsonObject);
  }

  /// Stores the token pair so subsequent requests can attach the bearer.
  void _store(LoginResult result) => TomBearerAuthentication.setTokens(
        result.authToken,
        result.authzToken,
        _decryptTokens,
      );

  /// The `Authorization: Bearer <authzToken>` header for an authenticated call,
  /// or throws when no session is stored.
  Map<String, String> _bearerHeader() {
    final token = TomBearerAuthentication.authorizationToken;
    if (token == null) {
      throw AuthClientException(
        'auth.no_token',
        'No stored authorization token — log in first.',
        statusCode: 0,
      );
    }
    return {'Authorization': 'Bearer $token'};
  }

  /// The server's stable error key from a `{"error": "..."}` body, or null.
  String? _errorKey(HttpJsonResponse response) =>
      _stringField(response, 'error');

  /// Reads a string [field] from the response body, or null when the body is not
  /// JSON or the field is absent or not a string.
  String? _stringField(HttpJsonResponse response, String field) {
    try {
      final value = response.jsonObject[field];
      return value is String ? value : null;
    } on FormatException {
      return null;
    }
  }

  /// Resolves [path] (a leading-slash absolute path) against [baseUri].
  Uri _uri(String path) {
    final base = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri.replace(path: '$base$path');
  }
}

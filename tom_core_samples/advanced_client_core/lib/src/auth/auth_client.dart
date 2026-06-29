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

import 'dart:convert';

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

  /// Builds the exception from the stable [key], a human [defaultUserMessage]
  /// and the originating [statusCode].
  AuthClientException(
    super.key,
    super.defaultUserMessage, {
    required this.statusCode,
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
  Future<LoginResult> login(LoginRequest request) async {
    final response = await _transport.send(
      method: 'POST',
      uri: _uri('/auth/login'),
      body: jsonEncode(request.toJson()),
    );
    final result = _requireLogin(response, 'auth.login.failed');
    _store(result);
    return result;
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
    return ResourceBundleDto.fromJson(response.jsonObject);
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
      // Replace the singleton to clear the cached principal + token pair.
      TomBearerAuthentication.bearerAuthentication = TomBearerAuthentication();
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
    return LoginResult.fromJson(response.jsonObject);
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
  String? _errorKey(HttpJsonResponse response) {
    try {
      final key = response.jsonObject['error'];
      return key is String ? key : null;
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

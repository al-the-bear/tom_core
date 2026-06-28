/// The authenticated request decorator the app and admin API clients (steps
/// 24–25) send through: it attaches the stored bearer to every call and, when a
/// token has gone stale, transparently refreshes **once** and retries — so a
/// single expiry is invisible to the caller, but a genuinely dead session
/// surfaces as a typed error instead of looping.
///
/// It composes the two step-22 pieces rather than reimplementing them: the
/// [JsonTransport] seam carries the call (so this is unit-testable against a
/// fake), and [AuthClient.refresh] re-mints the token pair on a 401. The bearer
/// is read from [TomBearerAuthentication] *fresh on every attempt*, so the retry
/// automatically picks up the token the refresh just stored.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'json_transport.dart';
import '../auth/auth_client.dart';

/// Raised when an authenticated request cannot be recovered: the server still
/// answered 401 *after* a successful token refresh and retry, so the session is
/// genuinely dead and the user must re-authenticate.
///
/// Carries the failing [statusCode] (always 401 here) and, when the server sent
/// one, its stable error [key].
class AuthorizedHttpException extends TomException {
  /// The HTTP status that triggered this (401 — the post-refresh rejection).
  final int statusCode;

  /// Builds the exception from the stable [key], a human [defaultUserMessage]
  /// and the originating [statusCode].
  AuthorizedHttpException(
    super.key,
    super.defaultUserMessage, {
    required this.statusCode,
  });
}

/// Sends authenticated requests with bearer injection and refresh-once-on-401.
class AuthorizedHttp {
  final JsonTransport _transport;
  final AuthClient _authClient;

  /// Builds the decorator over the [transport] that carries the calls and the
  /// [authClient] used to refresh a stale token. The two may share one
  /// transport instance (the live wiring) or hold separate ones (tests).
  AuthorizedHttp(this._transport, this._authClient);

  /// Sends [method] to [uri] with [body] and [headers], injecting
  /// `Authorization: Bearer <authzToken>` from the stored session.
  ///
  /// On a 401 it refreshes the token pair once (via [AuthClient.refresh]) and
  /// retries the request exactly once. A 2xx — or any non-401 status (403/404/…)
  /// the API client must interpret itself — is returned as-is. A 401 that
  /// persists *after* the refresh+retry throws [AuthorizedHttpException]; a
  /// refresh that itself fails surfaces its own [AuthClientException].
  Future<HttpJsonResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final first = await _sendWithBearer(method, uri, headers, body);
    if (first.statusCode != 401) return first;

    // One stale-token recovery: refresh (may throw AuthClientException), then
    // retry exactly once with the freshly stored bearer.
    await _authClient.refresh();
    final retry = await _sendWithBearer(method, uri, headers, body);
    if (retry.statusCode == 401) {
      throw AuthorizedHttpException(
        _errorKey(retry) ?? 'auth.session_expired',
        'Session expired — re-authentication required.',
        statusCode: 401,
      );
    }
    return retry;
  }

  /// Sends one request with the current stored bearer merged into [headers]
  /// (re-read each call so a post-refresh retry uses the new token). When no
  /// session is stored the call goes out unauthenticated and the server decides.
  Future<HttpJsonResponse> _sendWithBearer(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    final token = TomBearerAuthentication.authorizationToken;
    final merged = <String, String>{
      ...headers,
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return _transport.send(
      method: method,
      uri: uri,
      headers: merged,
      body: body,
    );
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
}

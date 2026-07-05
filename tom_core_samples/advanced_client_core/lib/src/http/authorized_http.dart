/// The authenticated request decorator the app and admin API clients (steps
/// 24–25) send through: it attaches the stored bearer to every call and, when a
/// token has gone stale, transparently refreshes **once** and retries — so a
/// single expiry is invisible to the caller, but a genuinely dead session
/// surfaces as a typed error instead of looping.
///
/// The refresh/retry *decision* is not hand-coded here: it is the framework's
/// pluggable policy ([tomRunWithAuthRetry] in `tom_core_kernel`, G-AUTH-3). This
/// decorator only supplies the two client-specific seams the coordinator needs —
/// the [JsonTransport] that carries the call (so this stays unit-testable
/// against a fake) and a [TomAuthRefresher] backed by [AuthClient.refresh] that
/// re-mints the token pair. The bearer is read from [TomBearerAuthentication]
/// *fresh on every attempt*, so the retry automatically picks up the token the
/// refresh just stored, and a persistent expiry surfaces as the kernel's
/// [TomAuthExpiredException].
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'json_transport.dart';
import '../auth/auth_client.dart';

/// Adapts [AuthClient.refresh] to the kernel's [TomAuthRefresher] contract.
///
/// A successful refresh stored a fresh token pair, so the request is worth
/// retrying (`true`). A refresh that cannot proceed (no stored session) throws
/// [AuthClientException] from [AuthClient.refresh]; that error propagates
/// unchanged through [tomRunWithAuthRetry].
class _AuthClientRefresher implements TomAuthRefresher {
  _AuthClientRefresher(this._authClient);

  final AuthClient _authClient;

  @override
  Future<bool> refresh() async {
    await _authClient.refresh();
    return true;
  }
}

/// Sends authenticated requests with bearer injection and the kernel's
/// refresh-once-on-expiry policy.
class AuthorizedHttp {
  final JsonTransport _transport;
  final TomAuthRefresher _refresher;

  /// Builds the decorator over the [transport] that carries the calls and the
  /// [authClient] used to refresh a stale token. The two may share one
  /// transport instance (the live wiring) or hold separate ones (tests).
  AuthorizedHttp(this._transport, AuthClient authClient)
      : _refresher = _AuthClientRefresher(authClient);

  /// Sends [method] to [uri] with [body] and [headers], injecting
  /// `Authorization: Bearer <authzToken>` from the stored session.
  ///
  /// Delegates the recovery decision to the kernel policy: on an expiry status
  /// (a `401` by default) it refreshes the token pair once (via
  /// [AuthClient.refresh]) and retries exactly once with the freshly stored
  /// bearer. A 2xx — or any non-expiry status (403/404/…) the API client must
  /// interpret itself — is returned as-is. An expiry that persists *after* the
  /// refresh+retry throws [TomAuthExpiredException]; a refresh that itself fails
  /// surfaces its own [AuthClientException].
  Future<HttpJsonResponse> send({
    required String method,
    required Uri uri,
    Map<String, String> headers = const {},
    String? body,
  }) {
    return tomRunWithAuthRetry<HttpJsonResponse>(
      send: () => _sendWithBearer(method, uri, headers, body),
      statusOf: (response) => response.statusCode,
      errorKeyOf: _errorKey,
      refresher: _refresher,
    );
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

/// Pluggable "expired-token → refresh → retry-once" policy for authenticated
/// HTTP clients.
///
/// This is the framework home of a concern that every authenticated client
/// otherwise re-implements by hand: when a bearer token has gone stale the
/// server answers `401`, and the client should transparently refresh the token
/// **once** and replay the request — but a *second* consecutive rejection is a
/// genuinely dead session that must surface as an error rather than loop.
///
/// Application code never writes that sequence. It supplies a [TomAuthRefresher]
/// (how to re-mint the token) and sends its requests through
/// [tomRunWithAuthRetry]; the *decision* logic — which status counts as an
/// expiry, how many times to retry, when to give up — lives here and is
/// selected via a [TomAuthRetryPolicy] bean (so an environment can tune or
/// replace it without touching call sites).
///
/// The coordinator is transport-agnostic on purpose: it works over any
/// `send()`-shaped callback returning any response type `R`, given a way to read
/// the status code out of `R`. That lets both a Flutter client and a
/// Flutter-free client core (which use different HTTP seams) inherit the exact
/// same mechanism from `tom_core_kernel`.
library;

import '../beanlocator/bean_locator.dart';
import '../little_things/exception_base.dart';

// =============================================================================
// REFRESHER
// =============================================================================

/// How to re-mint the authentication token pair when the current one expired.
///
/// A client implements this over whatever auth mechanism it uses (typically a
/// call to its auth server's `/refresh` endpoint that stores a fresh token
/// pair). [tomRunWithAuthRetry] invokes it at most once per request.
abstract class TomAuthRefresher {
  /// Attempts to obtain a fresh token so a retried request can succeed.
  ///
  /// Returns `true` when a new token was stored and the request is worth
  /// retrying, `false` when no refresh was possible (e.g. there is no session
  /// to refresh) so the original failure should stand. May throw its own typed
  /// error if the refresh call itself fails — that error propagates unchanged.
  Future<bool> refresh();
}

// =============================================================================
// POLICY
// =============================================================================

/// The decision knobs for [tomRunWithAuthRetry]: which HTTP statuses mean
/// "token expired" and how many refresh-and-retry attempts to make.
///
/// The default ([tomDefaultAuthRetryPolicy]) treats a single `401` as an expiry
/// and retries exactly once. Register a different instance as a bean
/// (`TomBean.withType<TomAuthRetryPolicy>(...)`) to tune it per environment; the
/// coordinator resolves the active policy through [active].
class TomAuthRetryPolicy {
  /// The HTTP status codes that mean "the bearer token has expired" and should
  /// trigger a refresh. Defaults to `{401}`.
  final Set<int> expiryStatusCodes;

  /// How many times to refresh-and-retry before surfacing the failure.
  /// Defaults to `1` (a single transparent recovery, never a loop).
  final int maxRefreshRetries;

  /// Builds a policy from its [expiryStatusCodes] and [maxRefreshRetries].
  const TomAuthRetryPolicy({
    this.expiryStatusCodes = const {401},
    this.maxRefreshRetries = 1,
  });

  /// Whether [statusCode] should trigger a token refresh under this policy.
  bool isAuthExpiry(int statusCode) => expiryStatusCodes.contains(statusCode);

  /// The policy in force: a [TomAuthRetryPolicy] bean if one is registered,
  /// else [tomDefaultAuthRetryPolicy]. Resolved fresh each call so a test or a
  /// late environment registration is honoured.
  static TomAuthRetryPolicy get active {
    final bean = TomBean.getBeanByType(TomAuthRetryPolicy);
    return bean is TomAuthRetryPolicy ? bean : tomDefaultAuthRetryPolicy;
  }
}

/// The zero-config default: a single `401` refreshes once and retries once.
const TomAuthRetryPolicy tomDefaultAuthRetryPolicy = TomAuthRetryPolicy();

// =============================================================================
// EXPIRED-SESSION SIGNAL
// =============================================================================

/// Raised when an authenticated request cannot be recovered: the server still
/// answered an expiry status *after* a successful refresh and retry, so the
/// session is genuinely dead and the user must re-authenticate.
///
/// Carries the failing [statusCode] and, when the caller supplied one, the
/// server's stable error [key].
class TomAuthExpiredException extends TomException {
  /// The HTTP status that persisted after the refresh+retry (an expiry status).
  final int statusCode;

  /// Builds the exception from the stable [key], a human [defaultUserMessage]
  /// and the persisting [statusCode].
  TomAuthExpiredException(
    super.key,
    super.defaultUserMessage, {
    required this.statusCode,
  });
}

// =============================================================================
// COORDINATOR
// =============================================================================

/// Runs [send] under the active refresh/retry policy and returns its response.
///
/// The sequence, transparent to the caller:
/// 1. Call [send]. If [statusOf] of the result is not an expiry status
///    ([TomAuthRetryPolicy.isAuthExpiry]), return it unchanged — including
///    non-expiry error statuses (`403`/`404`/…) the caller interprets itself.
/// 2. On an expiry status, invoke [refresher]. If it returns `false` (no
///    refresh possible) the original response is returned as-is. If it throws,
///    that error propagates. Otherwise replay [send] with the freshly stored
///    token.
/// 3. Repeat up to `policy.maxRefreshRetries` times. If an expiry status
///    persists after the retries, throw [TomAuthExpiredException] (using
///    [errorKeyOf] of the last response for its key, when provided).
///
/// [send] must re-read the current bearer on each call so the retry picks up
/// the refreshed token. [statusOf] extracts the HTTP status from a response of
/// type `R`; [errorKeyOf] optionally extracts the server's stable error key for
/// the thrown [TomAuthExpiredException].
Future<R> tomRunWithAuthRetry<R>({
  required Future<R> Function() send,
  required int Function(R response) statusOf,
  required TomAuthRefresher refresher,
  TomAuthRetryPolicy? policy,
  String? Function(R response)? errorKeyOf,
}) async {
  final activePolicy = policy ?? TomAuthRetryPolicy.active;

  R response = await send();
  var retries = 0;
  while (activePolicy.isAuthExpiry(statusOf(response)) &&
      retries < activePolicy.maxRefreshRetries) {
    final refreshed = await refresher.refresh();
    if (!refreshed) return response;
    retries++;
    response = await send();
  }

  if (retries > 0 && activePolicy.isAuthExpiry(statusOf(response))) {
    throw TomAuthExpiredException(
      errorKeyOf?.call(response) ?? 'auth.session_expired',
      'Session expired — re-authentication required.',
      statusCode: statusOf(response),
    );
  }
  return response;
}

/// What a GitHub rate-limit refusal means as a wait, for every client of
/// GitHub that waits it out.
///
/// Two paths meet these refusals — the storage, which the sync loop
/// drives, and the Issues annotation store — and they meet different
/// ones: a content-creation block refuses issue and comment writes and was
/// measured to let git-data writes through. What a refusal *means* is the same
/// on both, though, and so is the wait chosen for it, so it is decided here
/// once rather than twice.
library;

import 'package:tom_github_api/tom_github_api.dart';

import '../backoff_policy.dart';
import '../storage.dart';

/// A rate-limit refusal read as a wait: which limit, and until when.
typedef TomGitHubWait = ({TomRateLimitKind kind, DateTime until});

/// The wait [error] calls for, or null when it is not a rate limit.
///
/// A primary-quota refusal waits for the reset GitHub stated. A secondary
/// limit waits for GitHub's `Retry-After` when it stated one, and otherwise
/// for [backoff]'s fallback for its kind — a throttle and a content-creation
/// block clear on different scales. A secondary wait is spread by the backoff
/// jitter, additively, so clients refused together do not return together;
/// a quota reset is not, being an instant after which quota genuinely exists.
///
/// The distinction between an instruction and a choice is kept where it
/// belongs: `GitHubSecondaryRateLimitException.retryAfter` is null when GitHub
/// said nothing, and it is here — in the layer that owns the cadence — that a
/// wait is chosen. The API package invents none.
TomGitHubWait? tomGitHubWaitOf(
  Object error, {
  required TomBackoffPolicy backoff,
  required DateTime now,
  required double jitterSample,
}) {
  if (error is GitHubRateLimitException) {
    return (kind: TomRateLimitKind.quota, until: error.rateLimit.resetAt);
  }
  if (error is! GitHubSecondaryRateLimitException) return null;
  // The one place the two secondary shapes are told apart. They arrive as the
  // same status with the same headers; `blockedFromContentCreation` is the
  // body's own word for it.
  final blocked = error.blockedFromContentCreation;
  final base =
      error.retryAfter ??
      (blocked ? backoff.blockFallback : backoff.throttleFallback);
  return (
    kind: blocked ? TomRateLimitKind.blocked : TomRateLimitKind.throttle,
    until: now.add(
      GitHubRetryPolicy.jittered(
        base,
        fraction: backoff.jitterFraction,
        sample: jitterSample,
      ),
    ),
  );
}

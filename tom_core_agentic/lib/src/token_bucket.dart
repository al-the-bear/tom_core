// Continuous-refill token bucket — a domain-free throttle primitive.
//
// A textbook fractional token bucket keyed by an arbitrary string. Each
// key owns a bucket of [TokenBucketPolicy.capacity] tokens (the burst
// allowance); one [TokenBucket.tryTake] consumes one token. Tokens refill
// continuously at [TokenBucketPolicy.refillTokens] per
// [TokenBucketPolicy.refillPeriod], capped at [capacity]. The refill is
// computed lazily from wall-clock elapsed since the bucket was last
// touched — there is no background timer, so an idle key costs nothing and
// a long-unseen bucket is simply full again on its next use.
//
// This is the mechanism only. It returns *how long* a rejected caller must
// wait rather than throwing a domain exception, so a rate limiter, a quota,
// or any other throttle can wrap it and map the wait onto its own failure
// shape. Time is read through an injectable clock for deterministic tests.

import 'argument_guards.dart';
import 'system_clock.dart';

/// Immutable configuration of a [TokenBucket].
///
/// A bucket holds at most [capacity] tokens (the burst allowance) and
/// refills [refillTokens] tokens every [refillPeriod]. One take costs one
/// token, so the sustained rate is `refillTokens / refillPeriod` takes and
/// the instantaneous burst is [capacity] takes.
final class TokenBucketPolicy {
  /// Maximum number of tokens a bucket can hold — the burst allowance. A
  /// fresh bucket starts full at [capacity]. Must be `>= 1`.
  final int capacity;

  /// Number of tokens added to a bucket every [refillPeriod]. Must be `> 0`
  /// so a bucket always eventually refills (a non-refilling bucket would
  /// make the wait until a token undefined).
  final double refillTokens;

  /// The wall-clock window over which [refillTokens] are added. Must be a
  /// strictly positive duration.
  final Duration refillPeriod;

  /// Builds a policy. [capacity] must be `>= 1`, [refillTokens] must be
  /// `> 0`, and [refillPeriod] must be strictly positive.
  TokenBucketPolicy({
    required this.capacity,
    required this.refillTokens,
    required this.refillPeriod,
  }) {
    if (capacity < 1) {
      throw ArgumentError.value(capacity, 'capacity', 'must be >= 1');
    }
    if (refillTokens <= 0) {
      throw ArgumentError.value(refillTokens, 'refillTokens', 'must be > 0');
    }
    if (refillPeriod <= Duration.zero) {
      throw ArgumentError.value(
        refillPeriod,
        'refillPeriod',
        'must be a strictly positive duration',
      );
    }
  }

  /// Tokens replenished per microsecond — the continuous refill rate used
  /// by the lazy refill computation. Derived once from [refillTokens] and
  /// [refillPeriod].
  double get tokensPerMicrosecond => refillTokens / refillPeriod.inMicroseconds;
}

/// Mutable per-key bucket state: the current (fractional) token count and
/// the wall-clock instant it was last refilled.
class _BucketState {
  double tokens;
  DateTime lastRefill;

  _BucketState(this.tokens, this.lastRefill);
}

/// A keyed continuous-refill token bucket.
///
/// One bucket per key, created full on first sight and held for the
/// instance's lifetime. Call [tryTake] once per event: it returns `null`
/// when the bucket could afford the token (and consumes it), or the
/// [Duration] until one token will have refilled when it could not (and
/// charges nothing, so a rejected caller does not push its own retry
/// window further out).
///
/// Stateful (it owns the bucket map) but otherwise self-contained: no
/// timer, no I/O. Buckets are created lazily and not evicted; a caller
/// that needs idle eviction can read [keyCount] and call [clear] (or evict
/// externally). The key space is the caller's responsibility — key on a
/// bounded, non-secret identifier.
final class TokenBucket {
  /// The policy applied to every key.
  final TokenBucketPolicy policy;

  /// Time source. Defaults to [systemClock]; tests pass a controllable
  /// clock for deterministic refill.
  final DateTime Function() clock;

  final Map<String, _BucketState> _buckets = {};

  /// Builds a bucket set over [policy]. [clock] defaults to [systemClock].
  TokenBucket({
    required this.policy,
    DateTime Function()? clock,
  }) : clock = clock ?? systemClock;

  /// Number of keys with live bucket state — for observability and as the
  /// seam an external eviction policy reads.
  int get keyCount => _buckets.length;

  /// Drops all bucket state. Every key is full again on its next [tryTake].
  void clear() => _buckets.clear();

  /// Attempts to take one token for [key].
  ///
  /// Refills [key]'s bucket from the elapsed wall-clock time, then either
  /// consumes one token and returns `null` (success), or — when fewer than
  /// one token is available — returns the [Duration] until one token will
  /// have refilled without charging the bucket. [key] must be non-empty
  /// (an empty key would collapse every caller into one shared bucket).
  Duration? tryTake(String key) {
    requireNonEmpty(key, 'key');

    final now = clock();
    final bucket = _buckets.putIfAbsent(
      key,
      () => _BucketState(policy.capacity.toDouble(), now),
    );

    _refill(bucket, now);

    if (bucket.tokens >= 1.0) {
      bucket.tokens -= 1.0;
      return null;
    }

    // Not enough for a whole token: compute the wait until the deficit
    // (1 - tokens) has refilled. refillTokens > 0 guarantees this is finite.
    final deficit = 1.0 - bucket.tokens;
    final microseconds = (deficit / policy.tokensPerMicrosecond).ceil();
    return Duration(microseconds: microseconds);
  }

  /// Refills [bucket] for the time elapsed since its last refill, capped at
  /// [TokenBucketPolicy.capacity]. A backwards or stalled clock pins
  /// `lastRefill` forward without draining or crediting the bucket.
  void _refill(_BucketState bucket, DateTime now) {
    final elapsedMicros = now.difference(bucket.lastRefill).inMicroseconds;
    if (elapsedMicros <= 0) {
      bucket.lastRefill = now;
      return;
    }
    final refilled = elapsedMicros * policy.tokensPerMicrosecond;
    bucket.tokens =
        (bucket.tokens + refilled).clamp(0.0, policy.capacity.toDouble());
    bucket.lastRefill = now;
  }
}

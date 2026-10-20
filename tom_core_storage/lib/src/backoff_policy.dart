/// How long a backend holds off after a rate limit that stated no instant.
///
/// A value in the storage layer rather than the settings layer so a backend
/// can hold one without importing the application's settings; the application
/// owns the persisted form and hands it over ([TomStorage.adoptBackoff]).
///
/// These are the numbers that decide how long a workspace sits paused after a
/// burst, and the defaults are calibrated against one account's measured
/// behaviour. An account on a different plan, or a fleet of a different size,
/// earns and sheds these limits on a different rhythm — which is why they are
/// settings rather than constants.
library;

class TomBackoffPolicy {
  /// How long to hold off after a secondary rate limit GitHub stated no
  /// `Retry-After` on.
  ///
  /// GitHub's own guidance for a secondary limit is "wait at least one
  /// minute", and that is the whole justification for the default. What the
  /// value is really for is the *distinction* it makes possible: the sync loop
  /// only defers a backend it was given a wait for, so without a fallback a
  /// secondary limit — the one a polling loop actually earns, since it is about
  /// bursts — produces a refusal that defers nothing, and the loop returns at
  /// the poll interval to be refused again.
  final Duration throttleFallback;

  /// The same, for the abuse-detection block rather than the ordinary
  /// throttle.
  ///
  /// Five minutes by default. A client that **stops** at the refusal — which
  /// a sync loop does by deferring and an issue-backed store by pausing — was
  /// measured to see a block clear in 70 to 113 seconds; one that **kept
  /// sending** saw it hold for fifteen to
  /// twenty-four minutes. Five minutes covers the first with room and is what
  /// a paused annotation store waits before it tries again; an attempt that
  /// still meets the block pauses for another five, so a long one costs a
  /// request every five minutes rather than a burst.
  ///
  /// It is the Issues annotation store that meets blocks: git-data writes,
  /// which are all the sync loop makes, were not refused while one was in
  /// force.
  final Duration blockFallback;

  /// Spread added to a secondary-limit wait, as a whole percentage of it.
  ///
  /// The in-request retry de-synchronises the attempts inside one call; this
  /// de-synchronises the *next poll* of every client refused together.
  /// Without it a fleet sharing an account converges on one instant and
  /// re-earns the limit at it. Additive only: these waits are floors, and a
  /// client moved earlier is a client guaranteed a second refusal. A whole
  /// percentage rather than a fraction so the persisted value is exact.
  final int jitterPercent;

  static const defaultThrottleFallback = Duration(minutes: 1);
  static const defaultBlockFallback = Duration(minutes: 5);
  static const defaultJitterPercent = 25;

  const TomBackoffPolicy({
    this.throttleFallback = defaultThrottleFallback,
    this.blockFallback = defaultBlockFallback,
    this.jitterPercent = defaultJitterPercent,
  });

  static const defaults = TomBackoffPolicy();

  double get jitterFraction => jitterPercent / 100;

  bool get isDefault => this == defaults;

  /// Why this policy is not usable, or null when it is.
  ///
  /// A block shorter than a throttle is refused rather than accepted: the two
  /// exist to be told apart, and inverting them makes the harsher refusal the
  /// one the loop returns to sooner.
  String? get problem {
    if (throttleFallback <= Duration.zero) {
      return 'the throttle fallback must be longer than zero';
    }
    if (blockFallback < throttleFallback) {
      return 'the block fallback must not be shorter than the throttle '
          'fallback';
    }
    if (jitterPercent < 0 || jitterPercent > 100) {
      return 'the jitter must be a whole percentage from 0 to 100';
    }
    return null;
  }

  TomBackoffPolicy copyWith({
    Duration? throttleFallback,
    Duration? blockFallback,
    int? jitterPercent,
  }) => TomBackoffPolicy(
    throttleFallback: throttleFallback ?? this.throttleFallback,
    blockFallback: blockFallback ?? this.blockFallback,
    jitterPercent: jitterPercent ?? this.jitterPercent,
  );

  @override
  bool operator ==(Object other) =>
      other is TomBackoffPolicy &&
      other.throttleFallback == throttleFallback &&
      other.blockFallback == blockFallback &&
      other.jitterPercent == jitterPercent;

  @override
  int get hashCode =>
      Object.hash(throttleFallback, blockFallback, jitterPercent);

  @override
  String toString() =>
      'TomBackoffPolicy(throttle: '
      '${throttleFallback.inSeconds}s, block: ${blockFallback.inSeconds}s, '
      'jitter: $jitterPercent%)';
}

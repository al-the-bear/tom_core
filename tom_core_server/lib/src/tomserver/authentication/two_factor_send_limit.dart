/// Paces the one-time codes a delivered second factor sends to one address.
///
/// ## What the attempt bound does not cover
///
/// Guessing a delivered code is bounded: each challenge admits a fixed number
/// of answers, and [Tom2FAAttemptStore] refuses a replayed interim token. Asking
/// for codes is a different act. Every login that passes the first factor
/// issues a fresh challenge, and a fresh challenge is a fresh email or a fresh
/// paid text. Someone holding one password can therefore make the server send
/// message after message — flooding one inbox or phone, and spending the
/// deployment's money on every SMS.
///
/// ## The pace
///
/// The first code to an address goes out at once. Each further one must wait
/// longer than the last: the gap after the *n*-th send in a run is
/// `baseInterval × 2^(n−1)`, never more than `maxInterval`. With the defaults —
/// 30 seconds, doubling, up to 30 days — a user who lost a text can ask again
/// half a minute later, while a script asking without pause reaches a one-hour
/// wait after eight sends and the thirty-day ceiling after eighteen.
///
/// A run is ended by **proof**: a code sent to the address coming back
/// correctly, at login or at enrolment. A legitimate user's next login then
/// starts afresh rather than inheriting the wait their earlier logins built up.
/// A run also **lapses** once the address has been sent nothing for twice
/// `maxInterval`, which is what keeps an in-memory record bounded. Twice, not
/// once: a run at the cap has its next send due after exactly `maxInterval`,
/// and a run that lapsed at that same moment would hand whoever drove it there
/// a fresh run of short waits every thirty days instead of one send.
///
/// ## Where the record lives
///
/// [Tom2FASendLimiter] is a seam for the reason [Tom2FAAttemptStore] is: a
/// single process is served by the in-memory default, a load-balanced cluster
/// needs a limiter its nodes share. The default is installed rather than opt-in,
/// because a pace that must be asked for is a pace most deployments would not
/// have.
library;

import 'dart:math';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// One request to send a code, offered to a [Tom2FASendLimiter].
class Tom2FASend {
  /// Describes one request to send a code to [destination] over [channel].
  const Tom2FASend({
    required this.channel,
    required this.destination,
    required this.baseInterval,
    required this.maxInterval,
  });

  /// The mechanism doing the sending (`'email'`, `'sms'`, …).
  ///
  /// Part of the key, so a user's email and phone are paced separately: an
  /// address belongs to one channel, and a flood of texts says nothing about
  /// whether the next email is welcome.
  final String channel;

  /// The address the code would go to, exactly as the channel would use it.
  final String destination;

  /// The gap required after the first send of a run, doubled for each send
  /// after it.
  final Duration baseInterval;

  /// The longest gap a run can require. A run lapses after twice this long
  /// with no send.
  final Duration maxInterval;

  /// How long an address must go unsent to before its run lapses: twice
  /// [maxInterval], so a run at the cap stays at the cap.
  Duration get lapse => maxInterval * 2;

  /// The gap required after a run of [sends] sends.
  ///
  /// `baseInterval × 2^(sends−1)`, capped at [maxInterval]; nothing before the
  /// first send.
  Duration intervalAfter(int sends) {
    if (sends <= 0) return Duration.zero;
    // The exponent is clamped before it is used, so a long run cannot overflow
    // into a negative or infinite gap: 2^40 base intervals is past any cap.
    final factor = pow(2, min(sends - 1, 40)).toInt();
    final micros = baseInterval.inMicroseconds * factor;
    return micros >= maxInterval.inMicroseconds || micros < 0
        ? maxInterval
        : Duration(microseconds: micros);
  }

  @override
  String toString() => 'Tom2FASend($channel)';
}

/// Records the codes sent to each address and refuses one sent too soon.
///
/// Resolved through [resolve], so a deployment installs one as a bean the way
/// it installs a [Tom2FAAttemptStore]. A missing installation means the
/// in-process default, never "no pace".
abstract class Tom2FASendLimiter {
  /// Records [send] if it is allowed now and answers `null`; otherwise records
  /// nothing and answers how long until the next send to that address is
  /// allowed.
  ///
  /// A wait rather than a moment, so the answer does not depend on the caller
  /// and the limiter agreeing about what time it is.
  ///
  /// One call rather than a check and a record, so that two logins racing for
  /// one address cannot both be told they are early enough — an implementation
  /// over shared storage makes this atomic.
  Future<Duration?> claim(Tom2FASend send);

  /// Ends the run for [destination] on [channel]: the next send to it goes out
  /// at once.
  ///
  /// Called when a code sent there came back correctly, which proves the person
  /// asking is the one reading the address.
  Future<void> reset(String channel, String destination);

  /// The installed limiter, or the process-wide default.
  static Tom2FASendLimiter resolve() {
    final installed = TomBean.getBeanByType(Tom2FASendLimiter);
    return installed is Tom2FASendLimiter
        ? installed
        : Tom2FAMemorySendLimiter.shared;
  }
}

/// The default limiter: a map in this process.
///
/// **Per process, and says so.** On a cluster each node paces only the sends
/// that pass through it, so an address can receive one run per node. Finite,
/// which is the property that matters; a deployment that wants one pace across
/// nodes installs a limiter they share.
///
/// A run is dropped once its address has gone unsent to for its
/// [Tom2FASend.lapse], pruned as runs are written, so the map holds only
/// addresses sent to within the last such period.
class Tom2FAMemorySendLimiter implements Tom2FASendLimiter {
  /// Creates an empty limiter whose idea of the present is [clock].
  ///
  /// The clock is injectable because the pace is measured in seconds to days,
  /// and a test that slept through a thirty-day ceiling would not be a test.
  Tom2FAMemorySendLimiter({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// The process-wide instance [Tom2FASendLimiter.resolve] falls back to.
  static final Tom2FAMemorySendLimiter shared = Tom2FAMemorySendLimiter();

  final DateTime Function() _clock;
  final Map<String, _Run> _runs = {};

  /// How many addresses have a run. Test-support, and a size to assert on.
  int get size => _runs.length;

  @override
  Future<Duration?> claim(Tom2FASend send) async {
    final now = _clock();
    _pruneLapsed(now);
    final key = _key(send.channel, send.destination);
    final run = _runs[key];
    if (run == null) {
      _runs[key] = _Run(1, now, send.lapse);
      return null;
    }
    final allowedAt = run.lastSent.add(send.intervalAfter(run.sends));
    if (now.isBefore(allowedAt)) return allowedAt.difference(now);
    _runs[key] = _Run(run.sends + 1, now, send.lapse);
    return null;
  }

  @override
  Future<void> reset(String channel, String destination) async {
    _runs.remove(_key(channel, destination));
  }

  /// Discards every run. Test-support only.
  void clear() => _runs.clear();

  void _pruneLapsed(DateTime now) {
    _runs.removeWhere((_, run) => !now.isBefore(run.lastSent.add(run.lapse)));
  }

  /// Addresses compare without surrounding whitespace and case, so `A@x.org`
  /// and ` a@x.org` are one address and cannot be paced as two.
  static String _key(String channel, String destination) =>
      '$channel\u0000${destination.trim().toLowerCase()}';
}

/// One address's run: how many sends, the last one, and when it lapses.
class _Run {
  _Run(this.sends, this.lastSent, this.lapse);

  final int sends;
  final DateTime lastSent;
  final Duration lapse;
}

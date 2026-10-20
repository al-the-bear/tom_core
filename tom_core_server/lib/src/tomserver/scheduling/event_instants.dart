/// The instants of runs a component enqueues itself, rather than a schedule.
///
/// A job store keeps one run per `(job, tenant, scheduled instant)`: that is
/// what makes a clock-driven window idempotent, and the SQL store enforces it
/// with a unique key and writes a run with `REPLACE`. A component that enqueues
/// runs of its own — the message outbox, the saga orchestrator — gives each run
/// its own id, but two runs of one job enqueued in the same microsecond would
/// still share an instant, and the second would replace the first.
///
/// [TomEventInstants.next] gives every such run an instant of its own: the
/// clock's reading, or one microsecond past the last instant it gave out when
/// the clock has not moved on. It holds within one isolate. Two nodes, or two
/// isolates, enqueueing runs of one job for one tenant in the same microsecond
/// can still meet.
library;

/// Strictly increasing instants for runs enqueued outside a schedule — see the
/// library documentation.
abstract final class TomEventInstants {
  static DateTime? _last;

  /// [now], or one microsecond past the last instant answered when that is
  /// not before [now]; always in UTC.
  static DateTime next(DateTime now) {
    final utc = now.toUtc();
    final last = _last;
    final instant = last != null && !utc.isAfter(last)
        ? last.add(const Duration(microseconds: 1))
        : utc;
    _last = instant;
    return instant;
  }
}

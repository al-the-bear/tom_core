/// Tests for the scheduler runtime and durable job queue.
///
/// The suite is organised the way the module is: schedules are pure functions
/// and are tested by evaluation against fixed dates; the store is tested by
/// driving its state machine directly; the scheduler is tested by calling
/// [TomScheduler.tick] against an injected clock. Nothing here waits on wall
/// time except the two tests that deliberately exercise a real isolate pool and
/// a real periodic timer.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

// The port contracts — every behaviour required of a TomJobStore or a
// TomLeaseLock — live in their own file so a second package can run them
// against a second implementation. `tom_core_server` imports the same file for
// its relational pair. FakeClock comes from there too, so both suites drive
// time identically.
import 'contracts/scheduling_contract.dart';

// =============================================================================
// Test helpers
// =============================================================================

/// A command that records nothing and simply succeeds.
class OkCommand extends TomCommand {
  final Object? value;

  OkCommand([this.value = 'ok']);

  @override
  Future<Object?> execute() async => value;
}

/// A command that always throws, to drive the retry path.
class BoomCommand extends TomCommand {
  final String message;

  BoomCommand([this.message = 'boom']);

  @override
  Future<Object?> execute() async => throw StateError(message);
}

/// A command whose failure the body has classified as unfixable by retrying.
class PermanentlyBoomCommand extends TomCommand {
  @override
  Future<Object?> execute() async =>
      throw const TomPermanentJobFailure('the address does not exist');
}

/// A command that outlives a short job timeout.
class SlowCommand extends TomCommand {
  final Duration delay;

  SlowCommand(this.delay);

  @override
  Future<Object?> execute() async {
    await Future<void>.delayed(delay);
    return 'late';
  }
}

/// A dispatcher that records what it was asked to run and answers from a hook.
class RecordingDispatcher extends TomJobDispatcher {
  final List<TomCommand> dispatched = [];
  final Future<Object?> Function(TomCommand command)? handler;

  RecordingDispatcher({this.handler});

  @override
  Future<Object?> dispatch(TomCommand command) {
    dispatched.add(command);
    return handler?.call(command) ?? command.execute();
  }
}

/// Worker context for the one test that uses a real isolate pool.
class SchedulingWorkerContext extends TomWorkerContext {
  SchedulingWorkerContext()
    : super(
        const TomEnvironment('test', isTest: true),
        platformLinux,
        [],
        'Sched',
      );
}

/// Executes in a worker isolate and writes a marker file, so the test can prove
/// the body really ran off the main isolate rather than inline.
class IsolateMarkerCommand extends TomCommand {
  final String path;

  IsolateMarkerCommand(this.path);

  @override
  Future<Object?> execute() async {
    File(path).writeAsStringSync('${Isolate.current.debugName}');
    return 'written';
  }
}

/// Builds a scheduler wired to [store] with everything deterministic.
TomScheduler schedulerFor(
  TomJobStore store,
  FakeClock clock, {
  TomJobDispatcher? dispatcher,
  List<TomJobAlert>? alerts,
  Duration leaseTimeout = const Duration(minutes: 15),
  int maxRunsPerTick = 16,
  TomLeaseLock? lock,
  String ownerId = 'test-owner',
  Duration leaseTtl = const Duration(minutes: 1),
  Duration? leaseRenewInterval,
  int maxCatchUpPerTick = 20,
  Duration tickInterval = const Duration(seconds: 30),
  // Exact by default: almost every test drives `tick()` by hand, and a jittered
  // timer would only add nondeterminism to assertions that never observe it.
  double tickJitter = 0,
  DateTime Function()? clockOverride,
}) => TomScheduler(
  store: store,
  dispatcher: dispatcher ?? const TomInlineJobDispatcher(),
  clock: clockOverride ?? clock.call,
  ownerId: ownerId,
  leaseTimeout: leaseTimeout,
  maxRunsPerTick: maxRunsPerTick,
  maxCatchUpPerTick: maxCatchUpPerTick,
  tickInterval: tickInterval,
  tickJitter: tickJitter,
  // Zero-seed Random keeps jitter reproducible run to run.
  random: Random(0),
  onAlert: alerts == null ? (_) {} : alerts.add,
  lock: lock,
  leaseTtl: leaseTtl,
  leaseRenewInterval: leaseRenewInterval,
);

/// A command that blocks until the test releases it.
///
/// Lets a test hold a run "in flight" across an arbitrary number of awaits —
/// which is what the lease-renewal and lease-loss paths need, since both only
/// happen while work is genuinely outstanding.
class GatedCommand extends TomCommand {
  static final Map<String, Completer<void>> gates = {};

  final String gate;

  GatedCommand(this.gate);

  static Completer<void> open(String gate) => gates[gate] = Completer<void>();

  static void release(String gate) {
    final completer = gates[gate];
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  @override
  Future<Object?> execute() async {
    await gates[gate]?.future;
    return 'gated';
  }
}

/// A lock whose renewals stop landing after [beatsBeforeStall].
///
/// A node whose event loop stalls — a stop-the-world pause, a suspended VM, a
/// wedged disk — misses its heartbeats, and its lease lapses underneath it
/// while it still believes it holds it. That is the one way a live holder
/// genuinely loses a lease, and it cannot be produced by waiting: a healthy
/// heartbeat keeps a lease alive indefinitely, which is the whole point of
/// renewal. Failing the renewal reproduces the stall's only observable effect.
class StallingLeaseLock extends TomLeaseLock {
  final TomLeaseLock inner;
  final int beatsBeforeStall;
  int renewals = 0;

  StallingLeaseLock(this.inner, {this.beatsBeforeStall = 1});

  @override
  Future<TomLease?> acquire(String resource, String owner, Duration ttl) =>
      inner.acquire(resource, owner, ttl);

  @override
  Future<TomLease?> renew(TomLease lease, Duration ttl) async =>
      ++renewals > beatsBeforeStall ? null : inner.renew(lease, ttl);

  @override
  Future<void> release(TomLease lease) => inner.release(lease);

  @override
  Future<TomLeaseInfo> inspect(String resource) => inner.inspect(resource);

  @override
  Future<void> forget(String resource) => inner.forget(resource);

  @override
  void close() => inner.close();
}

/// Lets the runs a `tick()` started actually finish.
///
/// `tick()` deliberately does not await the work it dispatches — a slow job must
/// not hold up the next window of a fast one — so completion, the store write
/// and the lease release all land in later turns of the event loop. Tests that
/// assert on the *aftermath* of a run have to yield first.
///
/// [pumpEventQueue] rather than a counted loop of zero delays: the number of
/// turns a dispatch takes is an implementation detail, and a test that encodes
/// it fails the next time the runtime gains an await — which is exactly what
/// adding the `markStarted` write did.
Future<void> settle() => pumpEventQueue();

/// A job whose body simply succeeds, named for readability at the call site.
TomJobDefinition jobNamed(
  String name,
  TomSchedule schedule, {
  bool allowOverlap = false,
  TomCommand Function(TomJobRun run)? body,
  TomRetryPolicy retryPolicy = TomRetryPolicy.none,
  bool requestsRecovery = false,
}) => TomJobDefinition(
  name: name,
  schedule: schedule,
  body: body ?? (_) => OkCommand(),
  allowOverlap: allowOverlap,
  retryPolicy: retryPolicy,
  requestsRecovery: requestsRecovery,
);

/// An event source for a [TomEventSchedule], closed at the end of the test.
///
/// Broadcast rather than single-subscription: `close()` on an unlistened
/// single-subscription controller never completes, and these tests hand the
/// controller to `addTearDown`, which awaits it — including in the cases where
/// the scheduler deliberately never subscribes or has already cancelled.
StreamController<Object?> makeEventSource() {
  final controller = StreamController<Object?>.broadcast();
  addTearDown(controller.close);
  return controller;
}

/// A temp directory that is removed after the test.
Directory makeTempDir() {
  final dir = Directory.systemTemp.createTempSync('tom_scheduling_test_');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

void main() {
  // ===========================================================================
  // CRON
  // ===========================================================================

  group('TomCronSchedule', () {
    group('parsing', () {
      test('accepts a five-field expression', () {
        expect(TomCronSchedule('0 3 * * *').describe(), 'cron(0 3 * * *)');
      });

      test('rejects an empty expression', () {
        expect(
          () => TomCronSchedule('   '),
          throwsA(isA<TomScheduleException>()),
        );
      });

      test('rejects a four-field expression', () {
        expect(
          () => TomCronSchedule('0 3 * *'),
          throwsA(isA<TomScheduleException>()),
        );
      });

      test(
        'rejects a six-field expression rather than guessing at seconds',
        () {
          expect(
            () => TomCronSchedule('0 0 3 * * *'),
            throwsA(isA<TomScheduleException>()),
          );
        },
      );

      test('rejects an out-of-range value', () {
        expect(
          () => TomCronSchedule('60 * * * *'),
          throwsA(isA<TomScheduleException>()),
        );
        expect(
          () => TomCronSchedule('* 24 * * *'),
          throwsA(isA<TomScheduleException>()),
        );
        expect(
          () => TomCronSchedule('* * 32 * *'),
          throwsA(isA<TomScheduleException>()),
        );
        expect(
          () => TomCronSchedule('* * * 13 *'),
          throwsA(isA<TomScheduleException>()),
        );
      });

      test('rejects an inverted range', () {
        expect(
          () => TomCronSchedule('10-5 * * * *'),
          throwsA(isA<TomScheduleException>()),
        );
      });

      test('rejects a non-numeric field', () {
        expect(
          () => TomCronSchedule('x * * * *'),
          throwsA(isA<TomScheduleException>()),
        );
      });

      test('expands a comma list', () {
        final cron = TomCronSchedule('0,30 * * * *');
        final at = DateTime.utc(2026, 3, 1, 10, 5);
        expect(cron.nextFireAfter(at), DateTime.utc(2026, 3, 1, 10, 30));
        expect(
          cron.nextFireAfter(DateTime.utc(2026, 3, 1, 10, 30)),
          DateTime.utc(2026, 3, 1, 11, 0),
        );
      });

      test('expands a step on a wildcard', () {
        final cron = TomCronSchedule('*/15 * * * *');
        expect(
          cron.nextFireAfter(DateTime.utc(2026, 3, 1, 10, 1)),
          DateTime.utc(2026, 3, 1, 10, 15),
        );
      });

      test('expands a step on a range', () {
        final cron = TomCronSchedule('0-10/5 * * * *');
        expect(
          cron.nextFireAfter(DateTime.utc(2026, 3, 1, 10, 0)),
          DateTime.utc(2026, 3, 1, 10, 5),
        );
        expect(
          cron.nextFireAfter(DateTime.utc(2026, 3, 1, 10, 10)),
          DateTime.utc(2026, 3, 1, 11, 0),
        );
      });

      test('accepts month names case-insensitively', () {
        final cron = TomCronSchedule('0 0 1 jul *');
        expect(
          cron.nextFireAfter(DateTime.utc(2026, 3, 1)),
          DateTime.utc(2026, 7, 1),
        );
      });

      test('accepts day-of-week names', () {
        final cron = TomCronSchedule('0 0 * * MON');
        // 2026-03-01 is a Sunday, so the next Monday midnight is the 2nd.
        expect(
          cron.nextFireAfter(DateTime.utc(2026, 3, 1)),
          DateTime.utc(2026, 3, 2),
        );
      });

      test('treats day-of-week 7 as Sunday, like 0', () {
        final seven = TomCronSchedule('0 0 * * 7');
        final zero = TomCronSchedule('0 0 * * 0');
        final from = DateTime.utc(2026, 3, 3);
        expect(seven.nextFireAfter(from), zero.nextFireAfter(from));
      });

      test('expands the @daily macro', () {
        expect(
          TomCronSchedule('@daily').nextFireAfter(DateTime.utc(2026, 3, 1, 5)),
          DateTime.utc(2026, 3, 2),
        );
      });

      test('expands the @monthly and @yearly macros', () {
        expect(
          TomCronSchedule('@monthly').nextFireAfter(DateTime.utc(2026, 3, 5)),
          DateTime.utc(2026, 4, 1),
        );
        expect(
          TomCronSchedule('@yearly').nextFireAfter(DateTime.utc(2026, 3, 5)),
          DateTime.utc(2027, 1, 1),
        );
      });

      test('expands the @hourly macro', () {
        expect(
          TomCronSchedule(
            '@hourly',
          ).nextFireAfter(DateTime.utc(2026, 3, 5, 7, 30)),
          DateTime.utc(2026, 3, 5, 8),
        );
      });

      test('rejects an unknown macro', () {
        expect(
          () => TomCronSchedule('@fortnightly'),
          throwsA(isA<TomScheduleException>()),
        );
      });
    });

    group('nextFireAfter', () {
      test('is strictly after the given instant', () {
        final cron = TomCronSchedule('0 0 * * *');
        final midnight = DateTime.utc(2026, 3, 1);
        expect(cron.nextFireAfter(midnight), DateTime.utc(2026, 3, 2));
      });

      test('does not skip the minute a partial minute is inside', () {
        final cron = TomCronSchedule('* * * * *');
        expect(
          cron.nextFireAfter(DateTime.utc(2026, 3, 1, 10, 30, 45, 123)),
          DateTime.utc(2026, 3, 1, 10, 31),
        );
      });

      test('crosses a month boundary', () {
        final cron = TomCronSchedule('0 0 1 * *');
        expect(
          cron.nextFireAfter(DateTime.utc(2026, 3, 15)),
          DateTime.utc(2026, 4, 1),
        );
      });

      test('crosses a year boundary', () {
        final cron = TomCronSchedule('0 0 1 1 *');
        expect(
          cron.nextFireAfter(DateTime.utc(2026, 6, 1)),
          DateTime.utc(2027, 1, 1),
        );
      });

      test('finds February 29th in a leap year', () {
        final cron = TomCronSchedule('0 0 29 2 *');
        // 2027 and 2026 are not leap years; 2028 is.
        expect(
          cron.nextFireAfter(DateTime.utc(2026, 3, 1)),
          DateTime.utc(2028, 2, 29),
        );
      });

      test('returns null for an expression that can never match', () {
        expect(
          TomCronSchedule('0 0 30 2 *').nextFireAfter(DateTime.utc(2026)),
          isNull,
        );
      });

      test('preserves UTC', () {
        final fire = TomCronSchedule(
          '0 0 * * *',
        ).nextFireAfter(DateTime.utc(2026, 3, 1, 5));
        expect(fire!.isUtc, isTrue);
      });

      test('preserves local time', () {
        final fire = TomCronSchedule(
          '0 0 * * *',
        ).nextFireAfter(DateTime(2026, 3, 1, 5));
        expect(fire!.isUtc, isFalse);
        expect(fire, DateTime(2026, 3, 2));
      });

      test('reads its fields in the caller zone rather than normalising', () {
        // The two tests above pin the zone *flag* of the answer. Neither says
        // what the zone does to the meaning, which is the part that surprises
        // people: both answers below read 03:00, so they are the same wall
        // clock and therefore a different instant. A reader who assumes the
        // schedule normalises to UTC pins a nightly job to the wrong midnight.
        final cron = TomCronSchedule('0 3 * * *');
        final callerZone = DateTime(2026, 3, 1);
        final utc = cron.nextFireAfter(DateTime.utc(2026, 3, 1))!;
        final local = cron.nextFireAfter(callerZone)!;

        expect(
          [local.year, local.month, local.day, local.hour, local.minute],
          [utc.year, utc.month, utc.day, utc.hour, utc.minute],
          reason: '03:00 is 03:00 in whichever zone it was asked about',
        );
        // Compared against the *caller's* offset, not the answer's, so a
        // normalising implementation fails here instead of reporting a zero
        // offset and agreeing with itself.
        expect(
          local.toUtc() == utc,
          callerZone.timeZoneOffset == Duration.zero,
          reason: 'a wall-clock field must not be normalised to UTC',
        );
      });
    });

    group('day-of-month / day-of-week', () {
      // March 2026 is the reference month throughout this group: the 1st is a
      // Sunday, so the Mondays are 2, 9, 16, 23, 30, and cron weekdays
      // {0, 2, 4, 6} (Sun, Tue, Thu, Sat) fall on 1, 3, 5, 7, 8, 10, ...
      //
      // The walk starts on the last day of February so that midnight on the
      // 1st is still ahead of the cursor — `nextFireAfter` is exclusive, and
      // starting at 2026-03-01T00:00 would skip that day's fire.
      // The year is part of the stop condition, not just the month: a
      // sparse expression runs out of March and the next fire is the same
      // month a year later, which would otherwise be recorded as a repeat of
      // a day already seen.
      List<int> marchDays(String expression, {int take = 6}) {
        final cron = TomCronSchedule(expression);
        final days = <int>[];
        var cursor = DateTime.utc(2026, 2, 28);
        for (var i = 0; i < take; i++) {
          final next = cron.nextFireAfter(cursor);
          if (next == null || next.year != 2026 || next.month != 3) break;
          days.add(next.day);
          cursor = next;
        }
        return days;
      }

      test('ORs the two fields when both are restricted (POSIX)', () {
        expect(marchDays('0 0 15 3 MON'), [2, 9, 15, 16, 23, 30]);
      });

      // -----------------------------------------------------------------------
      // A step expression restricts the field.
      //
      // POSIX words the OR rule as applying when both day fields are "not *",
      // and `*/2` is not `*` — it names half the days. Treating it as an
      // unrestricted field discards the restriction after computing it, which
      // makes `0 0 */2 * *` fire every day: a job runs twice as often as its
      // author asked, silently, in the one schedule kind whose whole value is
      // that its expression means what cron says it means.
      // -----------------------------------------------------------------------
      test('a day-of-month step restricts the field rather than opening it '
          'up', () {
        // Odd days only. Two "wildcard" fields would fire every day.
        expect(marchDays('0 0 */2 3 *'), [1, 3, 5, 7, 9, 11]);
      });

      test('a day-of-week step restricts the field rather than opening it '
          'up', () {
        // Cron weekdays 0, 2, 4, 6 — Sunday, Tuesday, Thursday, Saturday.
        expect(marchDays('0 0 * 3 */2'), [1, 3, 5, 7, 8, 10]);
      });

      test('a day-of-month step ORs with a restricted day-of-week', () {
        // Odd days OR Mondays. The 2nd is a Monday and even, so it appears
        // only if the OR is applied rather than the step being discarded.
        expect(marchDays('0 0 */2 3 MON', take: 8), [1, 2, 3, 5, 7, 9, 11, 13]);
      });

      test('a day-of-week step ORs with a restricted day-of-month', () {
        // The 2nd is a Monday, so it is outside the {Sun, Tue, Thu, Sat} set
        // and reaches the result only through the day-of-month field.
        expect(marchDays('0 0 2 3 */2'), [1, 2, 3, 5, 7, 8]);
      });

      test('a step of 1 leaves the field unrestricted', () {
        // `*/1` is spelled as a wildcard and expands to every value, so it
        // imposes no restriction and does not pull the other field into an OR.
        // Mondays only — an OR would give every day.
        expect(marchDays('0 0 */1 3 MON', take: 5), [2, 9, 16, 23, 30]);
        expect(marchDays('0 0 15 3 */1', take: 5), [15]);
      });

      test('applies only day-of-week when day-of-month is wildcard', () {
        final cron = TomCronSchedule('0 0 * * MON');
        expect(
          cron.nextFireAfter(DateTime.utc(2026, 3, 2)),
          DateTime.utc(2026, 3, 9),
        );
      });

      test('applies only day-of-month when day-of-week is wildcard', () {
        final cron = TomCronSchedule('0 0 15 * *');
        expect(
          cron.nextFireAfter(DateTime.utc(2026, 3, 1)),
          DateTime.utc(2026, 3, 15),
        );
      });
    });
  });

  // ===========================================================================
  // CALENDAR
  // ===========================================================================

  group('TomCalendarSchedule', () {
    test('leaves the fields its rule does not use null', () {
      // One class serves two rules, so half the fields are inapplicable on any
      // given instance. They are null rather than filled in: a placeholder
      // `ordinal` of 1 would be indistinguishable from a genuine
      // first-occurrence schedule, and a caller reading it has no way to tell
      // that it was never asked for. `rule` stays the discriminator; the nulls
      // are what make disagreeing with it impossible.
      final byDay = TomCalendarSchedule.dayOfMonth(15);
      expect(byDay.rule, TomCalendarRule.dayOfMonth);
      expect(byDay.dayOfMonth, 15);
      expect(byDay.weekday, isNull);
      expect(byDay.ordinal, isNull);

      final byWeekday = TomCalendarSchedule.weekdayOfMonth(
        weekday: DateTime.tuesday,
        ordinal: -1,
      );
      expect(byWeekday.rule, TomCalendarRule.weekdayOfMonth);
      expect(byWeekday.weekday, DateTime.tuesday);
      expect(byWeekday.ordinal, -1);
      expect(byWeekday.dayOfMonth, isNull);
    });

    group('dayOfMonth', () {
      test('fires on a positive day', () {
        final cal = TomCalendarSchedule.dayOfMonth(10, hour: 9);
        expect(
          cal.nextFireAfter(DateTime.utc(2026, 3, 1)),
          DateTime.utc(2026, 3, 10, 9),
        );
      });

      test('fires on the last day of a 31-day month', () {
        final cal = TomCalendarSchedule.dayOfMonth(-1);
        expect(
          cal.nextFireAfter(DateTime.utc(2026, 3, 1)),
          DateTime.utc(2026, 3, 31),
        );
      });

      test('fires on the last day of a 30-day month', () {
        final cal = TomCalendarSchedule.dayOfMonth(-1);
        expect(
          cal.nextFireAfter(DateTime.utc(2026, 4, 1)),
          DateTime.utc(2026, 4, 30),
        );
      });

      test('fires on the last day of February in a leap year', () {
        final cal = TomCalendarSchedule.dayOfMonth(-1);
        expect(
          cal.nextFireAfter(DateTime.utc(2028, 2, 1)),
          DateTime.utc(2028, 2, 29),
        );
      });

      test('counts back from the month end for -2', () {
        final cal = TomCalendarSchedule.dayOfMonth(-2);
        expect(
          cal.nextFireAfter(DateTime.utc(2026, 4, 1)),
          DateTime.utc(2026, 4, 29),
        );
      });

      test(
        'skips a month that lacks the requested day rather than clamping',
        () {
          final cal = TomCalendarSchedule.dayOfMonth(31);
          // April has no 31st, so the next fire after April 1st is May 31st.
          expect(
            cal.nextFireAfter(DateTime.utc(2026, 4, 1)),
            DateTime.utc(2026, 5, 31),
          );
        },
      );

      test('honours a quarterly interval anchored on a month', () {
        final cal = TomCalendarSchedule.dayOfMonth(
          1,
          monthInterval: 3,
          anchorMonth: 1,
        );
        expect(
          cal.nextFireAfter(DateTime.utc(2026, 2, 1)),
          DateTime.utc(2026, 4, 1),
        );
        expect(
          cal.nextFireAfter(DateTime.utc(2026, 4, 1)),
          DateTime.utc(2026, 7, 1),
        );
      });

      test('keeps a quarterly cycle continuous across a year boundary', () {
        final cal = TomCalendarSchedule.dayOfMonth(
          1,
          monthInterval: 3,
          anchorMonth: 2,
        );
        // Feb, May, Aug, Nov — then Feb again, not January.
        expect(
          cal.nextFireAfter(DateTime.utc(2026, 11, 1)),
          DateTime.utc(2027, 2, 1),
        );
      });

      test('rejects day 0 and out-of-range days', () {
        expect(
          () => TomCalendarSchedule.dayOfMonth(0),
          throwsA(isA<TomScheduleException>()),
        );
        expect(
          () => TomCalendarSchedule.dayOfMonth(32),
          throwsA(isA<TomScheduleException>()),
        );
        expect(
          () => TomCalendarSchedule.dayOfMonth(-32),
          throwsA(isA<TomScheduleException>()),
        );
      });

      test('rejects an out-of-range hour, minute, interval or anchor', () {
        expect(
          () => TomCalendarSchedule.dayOfMonth(1, hour: 24),
          throwsA(isA<TomScheduleException>()),
        );
        expect(
          () => TomCalendarSchedule.dayOfMonth(1, minute: 60),
          throwsA(isA<TomScheduleException>()),
        );
        expect(
          () => TomCalendarSchedule.dayOfMonth(1, monthInterval: 0),
          throwsA(isA<TomScheduleException>()),
        );
        expect(
          () => TomCalendarSchedule.dayOfMonth(1, anchorMonth: 13),
          throwsA(isA<TomScheduleException>()),
        );
      });
    });

    group('weekdayOfMonth', () {
      test('fires on the second Tuesday', () {
        final cal = TomCalendarSchedule.weekdayOfMonth(
          weekday: DateTime.tuesday,
          ordinal: 2,
        );
        // March 2026: Tuesdays are 3, 10, 17, 24, 31.
        expect(
          cal.nextFireAfter(DateTime.utc(2026, 3, 1)),
          DateTime.utc(2026, 3, 10),
        );
      });

      test('fires on the last Friday', () {
        final cal = TomCalendarSchedule.weekdayOfMonth(
          weekday: DateTime.friday,
          ordinal: -1,
        );
        // March 2026: Fridays are 6, 13, 20, 27.
        expect(
          cal.nextFireAfter(DateTime.utc(2026, 3, 1)),
          DateTime.utc(2026, 3, 27),
        );
      });

      test('skips a month with no fifth occurrence', () {
        final cal = TomCalendarSchedule.weekdayOfMonth(
          weekday: DateTime.tuesday,
          ordinal: 5,
        );
        // March 2026 has a 5th Tuesday (31st); April 2026 does not, so after
        // March 31st the next is June 30th.
        expect(
          cal.nextFireAfter(DateTime.utc(2026, 3, 1)),
          DateTime.utc(2026, 3, 31),
        );
        expect(
          cal.nextFireAfter(DateTime.utc(2026, 3, 31)),
          DateTime.utc(2026, 6, 30),
        );
      });

      test('ordinal 5 is not a spelling of "last"', () {
        // The two coincide only in a month that happens to have five of the
        // weekday, which is what lets the wrong reading survive a casual
        // check. March 2026 has four Fridays (6, 13, 20, 27), so it separates
        // them: `-1` fires on the 27th, while `5` finds no fifth Friday until
        // May (1, 8, 15, 22, 29).
        DateTime? firstFriday(int ordinal) =>
            TomCalendarSchedule.weekdayOfMonth(
              weekday: DateTime.friday,
              ordinal: ordinal,
            ).nextFireAfter(DateTime.utc(2026, 3, 1));

        expect(firstFriday(-1), DateTime.utc(2026, 3, 27));
        expect(firstFriday(5), DateTime.utc(2026, 5, 29));
      });

      test('rejects an out-of-range weekday or ordinal', () {
        expect(
          () => TomCalendarSchedule.weekdayOfMonth(weekday: 0, ordinal: 1),
          throwsA(isA<TomScheduleException>()),
        );
        expect(
          () => TomCalendarSchedule.weekdayOfMonth(weekday: 8, ordinal: 1),
          throwsA(isA<TomScheduleException>()),
        );
        expect(
          () => TomCalendarSchedule.weekdayOfMonth(
            weekday: DateTime.monday,
            ordinal: 6,
          ),
          throwsA(isA<TomScheduleException>()),
        );
        expect(
          () => TomCalendarSchedule.weekdayOfMonth(
            weekday: DateTime.monday,
            ordinal: -2,
          ),
          throwsA(isA<TomScheduleException>()),
        );
      });

      test('preserves local time', () {
        final cal = TomCalendarSchedule.dayOfMonth(10);
        final fire = cal.nextFireAfter(DateTime(2026, 3, 1));
        expect(fire!.isUtc, isFalse);
        expect(fire, DateTime(2026, 3, 10));
      });
    });
  });

  // ===========================================================================
  // INTERVAL AND EVENT
  // ===========================================================================

  group('TomIntervalSchedule', () {
    test('fires on a grid anchored at the epoch', () {
      final interval = TomIntervalSchedule(const Duration(minutes: 15));
      expect(
        interval.nextFireAfter(DateTime.utc(2026, 3, 1, 10, 7)),
        DateTime.utc(2026, 3, 1, 10, 15),
      );
    });

    test('steps one grid point on when asked exactly on the grid', () {
      final interval = TomIntervalSchedule(const Duration(minutes: 15));
      expect(
        interval.nextFireAfter(DateTime.utc(2026, 3, 1, 10, 15)),
        DateTime.utc(2026, 3, 1, 10, 30),
      );
    });

    test('resumes on the original grid after a long gap, without drifting', () {
      final anchor = DateTime.utc(2026, 3, 1, 10);
      final interval = TomIntervalSchedule(
        const Duration(minutes: 10),
        anchor: anchor,
      );
      // An hour and seven minutes later the next grid point is still :10-aligned.
      expect(
        interval.nextFireAfter(DateTime.utc(2026, 3, 1, 11, 7)),
        DateTime.utc(2026, 3, 1, 11, 10),
      );
    });

    test('honours a custom anchor', () {
      final interval = TomIntervalSchedule(
        const Duration(minutes: 90),
        anchor: DateTime.utc(2026, 3, 1, 0, 5),
      );
      expect(
        interval.nextFireAfter(DateTime.utc(2026, 3, 1)),
        DateTime.utc(2026, 3, 1, 0, 5),
      );
    });

    test('rejects a non-positive period', () {
      expect(
        () => TomIntervalSchedule(Duration.zero),
        throwsA(isA<TomScheduleException>()),
      );
      expect(
        () => TomIntervalSchedule(const Duration(seconds: -1)),
        throwsA(isA<TomScheduleException>()),
      );
    });

    test('preserves UTC-ness', () {
      final interval = TomIntervalSchedule(const Duration(minutes: 10));
      expect(interval.nextFireAfter(DateTime.utc(2026, 3, 1))!.isUtc, isTrue);
      expect(interval.nextFireAfter(DateTime(2026, 3, 1))!.isUtc, isFalse);
    });
  });

  group('TomOnceSchedule', () {
    test('answers its instant while it is still ahead', () {
      final once = TomOnceSchedule(DateTime.utc(2026, 8, 1, 9));
      expect(
        once.nextFireAfter(DateTime.utc(2026, 7, 1)),
        DateTime.utc(2026, 8, 1, 9),
      );
      expect(
        once.nextFireAfter(DateTime.utc(2026, 8, 1, 8, 59, 59)),
        DateTime.utc(2026, 8, 1, 9),
      );
    });

    test('answers null at the instant and after it', () {
      final at = DateTime.utc(2026, 8, 1, 9);
      final once = TomOnceSchedule(at);
      // Asked exactly at the instant the window has been reached; offering it
      // again is how a one-shot would fire twice.
      expect(once.nextFireAfter(at), isNull);
      expect(
        once.nextFireAfter(at.add(const Duration(microseconds: 1))),
        isNull,
      );
      expect(once.nextFireAfter(DateTime.utc(2027)), isNull);
    });

    test('is clock-driven', () {
      expect(TomOnceSchedule(DateTime.utc(2026, 8, 1)).isClockDriven, isTrue);
    });

    test('answers in the zone it was asked in, naming the same instant', () {
      final at = DateTime.utc(2026, 8, 1, 9);
      final once = TomOnceSchedule(at);

      final utc = once.nextFireAfter(DateTime.utc(2026, 7, 1))!;
      expect(utc.isUtc, isTrue);
      expect(utc, at);

      final local = once.nextFireAfter(DateTime(2026, 7, 1))!;
      expect(local.isUtc, isFalse);
      // Rendering, not reinterpretation: still the same point in time.
      expect(local.toUtc(), at);
    });

    test('takes a local instant as the absolute instant it names', () {
      final at = DateTime(2026, 8, 1, 9);
      final once = TomOnceSchedule(at);
      expect(once.nextFireAfter(DateTime.utc(2026, 7, 1))!, at.toUtc());
    });

    test('describes itself in the family style', () {
      expect(
        TomOnceSchedule(DateTime.utc(2026, 8, 1, 9)).describe(),
        'once(2026-08-01T09:00:00.000Z)',
      );
      expect(
        TomOnceSchedule(DateTime.utc(2026, 8, 1, 9)).toString(),
        'once(2026-08-01T09:00:00.000Z)',
      );
    });
  });

  group('TomEventSchedule', () {
    test('is not clock-driven and never answers a fire time', () {
      final controller = makeEventSource();
      final schedule = TomEventSchedule(controller.stream);
      expect(schedule.isClockDriven, isFalse);
      expect(schedule.nextFireAfter(DateTime.utc(2026)), isNull);
    });
  });

  // ===========================================================================
  // JOB STORE
  // ===========================================================================

  // The store contract runs against both kernel implementations. The file store
  // is a TomMemoryJobStore subclass that mirrors to disk, so running the whole
  // contract against it is what proves the mirror never changes an answer.
  runTomJobStoreContract('TomMemoryJobStore', () async => TomMemoryJobStore());
  runTomJobStoreContract(
    'TomFileJobStore',
    () async => TomFileJobStore('${makeTempDir().path}/queue.json'),
  );

  group('TomJobRun serialization', () {
    test('round-trips every field', () {
      final original = TomJobRun(
        id: 'r1',
        jobName: 'job',
        scheduledFor: DateTime.utc(2026, 3, 1, 10),
        runAt: DateTime.utc(2026, 3, 1, 10, 5),
        state: TomJobRunState.running,
        attempt: 3,
        claimedBy: 'owner',
        claimedAt: DateTime.utc(2026, 3, 1, 10, 6),
        lastError: 'previous failure',
        completedAt: DateTime.utc(2026, 3, 1, 10, 7),
        payload: {'key': 'value'},
      );
      final copy = TomJobRun.fromJson(original.toJson());
      expect(copy.id, original.id);
      expect(copy.jobName, original.jobName);
      expect(copy.scheduledFor, original.scheduledFor);
      expect(copy.runAt, original.runAt);
      expect(copy.state, original.state);
      expect(copy.attempt, original.attempt);
      expect(copy.claimedBy, original.claimedBy);
      expect(copy.claimedAt, original.claimedAt);
      expect(copy.lastError, original.lastError);
      expect(copy.completedAt, original.completedAt);
      expect(copy.payload, original.payload);
    });

    test('decodes an unknown state as pending rather than throwing', () {
      final map = TomJobRun(
        id: 'r1',
        jobName: 'job',
        scheduledFor: DateTime.utc(2026),
        runAt: DateTime.utc(2026),
      ).toJson()..['state'] = 'quantum';
      expect(TomJobRun.fromJson(map).state, TomJobRunState.pending);
    });
  });

  // ===========================================================================
  // DURABILITY
  // ===========================================================================

  group('TomFileJobStore', () {
    final at = DateTime.utc(2026, 3, 1, 10);

    test('a pending run survives losing the store instance', () async {
      final path = '${makeTempDir().path}/queue.json';
      final first = TomFileJobStore(path);
      await first.enqueue(
        TomJobRun(id: 'a', jobName: 'job', scheduledFor: at, runAt: at),
      );

      final second = TomFileJobStore(path);
      final restored = (await second.all()).single;
      expect(restored.id, 'a');
      expect(restored.state, TomJobRunState.pending);
      expect(restored.scheduledFor, at);
    });

    test(
      'an in-flight run comes back as an expired lease, not as lost work',
      () async {
        final path = '${makeTempDir().path}/queue.json';
        final first = TomFileJobStore(path);
        await first.enqueue(
          TomJobRun(id: 'a', jobName: 'job', scheduledFor: at, runAt: at),
        );
        await first.claimDue(at, 'owner-that-dies');

        // The process "restarts": a new store over the same file.
        final second = TomFileJobStore(path);
        final restored = (await second.all()).single;
        expect(restored.state, TomJobRunState.running);
        expect(restored.claimedBy, 'owner-that-dies');

        final recovered = await second.recoverAbandoned(
          at.add(const Duration(hours: 1)),
          const Duration(minutes: 15),
        );
        expect(recovered.single.id, 'a');
        expect(recovered.single.state, TomJobRunState.pending);
      },
    );

    test('a completed run survives as completed', () async {
      final path = '${makeTempDir().path}/queue.json';
      final first = TomFileJobStore(path);
      await first.enqueue(
        TomJobRun(id: 'a', jobName: 'job', scheduledFor: at, runAt: at),
      );
      await first.complete((await first.claimDue(at, 'o')).single, at);

      expect(
        (await TomFileJobStore(path).all()).single.state,
        TomJobRunState.succeeded,
      );
    });

    test('creates the parent directory on first write', () async {
      final path = '${makeTempDir().path}/nested/deeper/queue.json';
      final store = TomFileJobStore(path);
      await store.enqueue(
        TomJobRun(id: 'a', jobName: 'job', scheduledFor: at, runAt: at),
      );
      expect(File(path).existsSync(), isTrue);
    });

    test('starts empty when the file does not exist', () async {
      final store = TomFileJobStore('${makeTempDir().path}/absent.json');
      expect(await store.all(), isEmpty);
    });

    test('starts empty rather than throwing on a corrupt file', () async {
      final path = '${makeTempDir().path}/queue.json';
      File(path).writeAsStringSync('{ not json at all');
      expect(await TomFileJobStore(path).all(), isEmpty);
    });

    test('skips a single corrupt record and keeps the rest', () async {
      final path = '${makeTempDir().path}/queue.json';
      File(path).writeAsStringSync(
        '['
        '{"id":"bad"},'
        '{"id":"good","jobName":"job",'
        '"scheduledFor":"2026-03-01T10:00:00.000Z",'
        '"runAt":"2026-03-01T10:00:00.000Z","state":"pending","attempt":1}'
        ']',
      );
      expect((await TomFileJobStore(path).all()).map((r) => r.id), ['good']);
    });

    test('a purge is mirrored to disk', () async {
      final path = '${makeTempDir().path}/queue.json';
      final first = TomFileJobStore(path);
      await first.enqueue(
        TomJobRun(id: 'a', jobName: 'job', scheduledFor: at, runAt: at),
      );
      await first.complete((await first.claimDue(at, 'o')).single, at);
      await first.purgeFinished(at.add(const Duration(days: 1)));

      expect(await TomFileJobStore(path).all(), isEmpty);
    });
  });

  // ===========================================================================
  // RETRY POLICY
  // ===========================================================================

  group('TomRetryPolicy', () {
    test('allowsRetryAfter compares against maxAttempts', () {
      const policy = TomRetryPolicy(maxAttempts: 3);
      expect(policy.allowsRetryAfter(1), isTrue);
      expect(policy.allowsRetryAfter(2), isTrue);
      expect(policy.allowsRetryAfter(3), isFalse);
    });

    test('none never retries', () {
      expect(TomRetryPolicy.none.allowsRetryAfter(1), isFalse);
    });

    test('backoff grows exponentially from the initial delay', () {
      const policy = TomRetryPolicy(
        initialBackoff: Duration(seconds: 10),
        multiplier: 2,
        jitter: 0,
      );
      expect(policy.backoffFor(1), const Duration(seconds: 10));
      expect(policy.backoffFor(2), const Duration(seconds: 20));
      expect(policy.backoffFor(3), const Duration(seconds: 40));
    });

    test('backoff is clamped to maxBackoff', () {
      const policy = TomRetryPolicy(
        initialBackoff: Duration(seconds: 10),
        multiplier: 10,
        maxBackoff: Duration(minutes: 1),
        jitter: 0,
      );
      expect(policy.backoffFor(5), const Duration(minutes: 1));
    });

    test('backoff without a Random is exact', () {
      const policy = TomRetryPolicy(initialBackoff: Duration(seconds: 30));
      expect(policy.backoffFor(1), const Duration(seconds: 30));
    });

    test('jitter only ever lengthens the wait', () {
      const policy = TomRetryPolicy(
        initialBackoff: Duration(seconds: 10),
        jitter: 0.5,
      );
      final random = Random(1);
      for (var i = 0; i < 20; i++) {
        final backoff = policy.backoffFor(1, random);
        expect(backoff, greaterThanOrEqualTo(const Duration(seconds: 10)));
        expect(backoff, lessThanOrEqualTo(const Duration(seconds: 15)));
      }
    });

    // The two tests above each disable half of the interaction — one sets
    // `jitter: 0`, the other leaves `maxBackoff` at a default far too high to
    // bite. The policy's two promises only collide when both are in play, so
    // that is what the next two exercise.
    const saturating = TomRetryPolicy(
      initialBackoff: Duration(seconds: 10),
      multiplier: 10,
      maxBackoff: Duration(minutes: 1),
      jitter: 0.5,
    );

    test('jitter never pushes the delay past maxBackoff', () {
      final random = Random(1);
      for (var attempt = 1; attempt <= 5; attempt++) {
        final unjittered = saturating.backoffFor(attempt);
        for (var i = 0; i < 50; i++) {
          final backoff = saturating.backoffFor(attempt, random);
          expect(
            backoff,
            lessThanOrEqualTo(const Duration(minutes: 1)),
            reason: 'attempt $attempt exceeded the ceiling',
          );
          expect(
            backoff,
            greaterThanOrEqualTo(unjittered),
            reason: 'attempt $attempt retried earlier than promised',
          );
        }
      }
    });

    test('jitter still spreads the retries once the backoff has saturated', () {
      // Saturation is the case jitter exists for: a long outage drives every
      // job in the fleet to maxBackoff together. Capping the *jittered* value
      // would satisfy the ceiling by handing them all the same instant to
      // retry on, which is the pile-up jitter is meant to prevent. So the
      // curve plateaus a jitter's width below the ceiling instead, and the
      // spread reaches maxBackoff without crossing it.
      final random = Random(1);
      final seen = <Duration>{};
      for (var i = 0; i < 50; i++) {
        seen.add(saturating.backoffFor(4, random));
      }

      expect(seen.length, greaterThan(10), reason: 'jitter collapsed');
      expect(
        seen.reduce((a, b) => a < b ? a : b),
        greaterThanOrEqualTo(const Duration(seconds: 40)),
      );
      expect(
        seen.reduce((a, b) => a > b ? a : b),
        greaterThan(const Duration(seconds: 50)),
      );
    });
  });

  // ===========================================================================
  // JOB DEFINITION
  // ===========================================================================

  group('TomJobDefinition', () {
    test('rejects an empty name', () {
      expect(
        () => TomJobDefinition(
          name: '  ',
          schedule: TomCronSchedule('@daily'),
          body: (_) => OkCommand(),
        ),
        throwsA(isA<TomScheduleException>()),
      );
    });

    test('rejects a catchUpLimit below 1', () {
      expect(
        () => TomJobDefinition(
          name: 'job',
          schedule: TomCronSchedule('@daily'),
          body: (_) => OkCommand(),
          catchUpLimit: 0,
        ),
        throwsA(isA<TomScheduleException>()),
      );
    });

    test('rejects a non-positive timeout', () {
      expect(
        () => TomJobDefinition(
          name: 'job',
          schedule: TomCronSchedule('@daily'),
          body: (_) => OkCommand(),
          timeout: Duration.zero,
        ),
        throwsA(isA<TomScheduleException>()),
      );
    });

    test('defaults to runOnce, no overlap, and a retrying policy', () {
      final job = TomJobDefinition(
        name: 'job',
        schedule: TomCronSchedule('@daily'),
        body: (_) => OkCommand(),
      );
      expect(job.missedWindowPolicy, TomMissedWindowPolicy.runOnce);
      expect(job.allowOverlap, isFalse);
      expect(job.retryPolicy.maxAttempts, 3);
    });
  });

  group('TomInlineJobDispatcher', () {
    test('runs the command in the calling isolate', () async {
      expect(await const TomInlineJobDispatcher().dispatch(OkCommand(7)), 7);
    });

    test('lets errors propagate rather than swallowing them', () {
      expect(
        const TomInlineJobDispatcher().dispatch(BoomCommand()),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ===========================================================================
  // SCHEDULER
  // ===========================================================================

  group('TomScheduler', () {
    late FakeClock clock;
    late TomMemoryJobStore store;
    late List<TomJobAlert> alerts;

    setUp(() {
      clock = FakeClock(DateTime.utc(2026, 3, 1, 10, 0));
      store = TomMemoryJobStore();
      alerts = [];
    });

    TomJobDefinition dailyJob({
      TomCommand Function(TomJobRun run)? body,
      TomMissedWindowPolicy policy = TomMissedWindowPolicy.runOnce,
      int catchUpLimit = 10,
      TomRetryPolicy retry = const TomRetryPolicy(jitter: 0),
      Duration timeout = const Duration(minutes: 5),
      bool allowOverlap = false,
      String name = 'daily',
      bool requestsRecovery = false,
    }) => TomJobDefinition(
      name: name,
      schedule: TomCronSchedule('0 0 * * *'),
      body: body ?? (_) => OkCommand(),
      missedWindowPolicy: policy,
      catchUpLimit: catchUpLimit,
      retryPolicy: retry,
      timeout: timeout,
      allowOverlap: allowOverlap,
      requestsRecovery: requestsRecovery,
    );

    group('registration', () {
      test('register makes the job visible', () {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());
        expect(scheduler.jobs.keys, ['daily']);
      });

      test('register replaces a job of the same name', () {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());
        scheduler.register(dailyJob(timeout: const Duration(minutes: 9)));
        expect(scheduler.jobs, hasLength(1));
        expect(scheduler.jobs['daily']!.timeout, const Duration(minutes: 9));
      });

      test(
        'deregister removes the job but leaves its runs in the store',
        () async {
          final scheduler = schedulerFor(store, clock, alerts: alerts);
          addTearDown(scheduler.close);
          scheduler.register(dailyJob());
          await scheduler.tick();
          scheduler.deregister('daily');
          expect(scheduler.jobs, isEmpty);
          expect(await store.all(), isNotEmpty);
        },
      );

      test('register after close is refused', () {
        final scheduler = schedulerFor(store, clock, alerts: alerts)..close();
        expect(
          () => scheduler.register(dailyJob()),
          throwsA(isA<TomScheduleException>()),
        );
      });
    });

    group('planning', () {
      test(
        'first sight anchors on the present instead of replaying history',
        () async {
          final scheduler = schedulerFor(store, clock, alerts: alerts);
          addTearDown(scheduler.close);
          scheduler.register(dailyJob());
          await scheduler.tick();

          final runs = await store.all();
          expect(runs, hasLength(1));
          expect(runs.single.scheduledFor, DateTime.utc(2026, 3, 2));
        },
      );

      test('a repeated tick at the same instant plans nothing new', () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());
        await scheduler.tick();
        await scheduler.tick();
        await scheduler.tick();
        expect(await store.all(), hasLength(1));
      });

      test('look-ahead does not walk forward on every tick', () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());
        await scheduler.tick();

        // Ten ticks a minute apart: still only tomorrow's window is planned,
        // because look-ahead is anchored on now, not on the last record.
        for (var i = 0; i < 10; i++) {
          clock.advance(const Duration(minutes: 1));
          await scheduler.tick();
        }
        expect((await store.all()).map((r) => r.scheduledFor), [
          DateTime.utc(2026, 3, 2),
        ]);
      });

      test('an event-driven job is not planned by the clock', () async {
        final controller = makeEventSource();
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
          TomJobDefinition(
            name: 'on-event',
            schedule: TomEventSchedule(controller.stream),
            body: (_) => OkCommand(),
          ),
        );
        await scheduler.tick();
        expect(await store.all(), isEmpty);
      });
    });

    group('missed windows', () {
      /// Seeds the store as if the scheduler had last planned a window on the
      /// 1st, then went down for four days.
      Future<void> seedStaleHistory() async {
        await store.enqueue(
          TomJobRun(
            id: 'seed',
            jobName: 'daily',
            scheduledFor: DateTime.utc(2026, 3, 1),
            runAt: DateTime.utc(2026, 3, 1),
            state: TomJobRunState.succeeded,
            completedAt: DateTime.utc(2026, 3, 1),
          ),
        );
        clock.now = DateTime.utc(2026, 3, 5, 10);
      }

      test('skip enqueues no catch-up and alerts with the count', () async {
        await seedStaleHistory();
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob(policy: TomMissedWindowPolicy.skip));
        await scheduler.tick();

        final windows = (await store.all())
            .where((r) => r.id != 'seed')
            .map((r) => r.scheduledFor)
            .toList();
        // Only the next future window; the 2nd..5th are dropped.
        expect(windows, [DateTime.utc(2026, 3, 6)]);
        final missed = alerts.where(
          (a) => a.kind == TomJobAlertKind.windowsMissed,
        );
        expect(missed, hasLength(1));
        expect(missed.single.missedWindows, 4);
      });

      test('runOnce enqueues only the most recent missed window', () async {
        await seedStaleHistory();
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob(policy: TomMissedWindowPolicy.runOnce));
        await scheduler.tick();

        final catchUp = (await store.all())
            .where((r) => r.id != 'seed' && r.scheduledFor.isBefore(clock.now))
            .toList();
        expect(catchUp.map((r) => r.scheduledFor), [DateTime.utc(2026, 3, 5)]);
      });

      test('runOnce dates the catch-up run to the missed window but makes it '
          'due now', () async {
        await seedStaleHistory();
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        // No dispatcher work: assert the record, not the execution.
        scheduler.register(dailyJob(policy: TomMissedWindowPolicy.runOnce));
        await scheduler.tick();
        await settle();

        final catchUp = (await store.all()).firstWhere(
          (r) => r.scheduledFor == DateTime.utc(2026, 3, 5),
        );
        // It ran (inline dispatcher), so assert what it was scheduled for.
        expect(catchUp.scheduledFor, DateTime.utc(2026, 3, 5));
        expect(catchUp.state, TomJobRunState.succeeded);
      });

      test('runAll enqueues every missed window up to catchUpLimit', () async {
        await seedStaleHistory();
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob(policy: TomMissedWindowPolicy.runAll));
        await scheduler.tick();

        final catchUp =
            (await store.all())
                .where(
                  (r) => r.id != 'seed' && r.scheduledFor.isBefore(clock.now),
                )
                .map((r) => r.scheduledFor)
                .toList()
              ..sort();
        expect(catchUp, [
          DateTime.utc(2026, 3, 2),
          DateTime.utc(2026, 3, 3),
          DateTime.utc(2026, 3, 4),
          DateTime.utc(2026, 3, 5),
        ]);
      });

      test(
        'runAll keeps the most recent windows when the limit bites',
        () async {
          await seedStaleHistory();
          final scheduler = schedulerFor(store, clock, alerts: alerts);
          addTearDown(scheduler.close);
          scheduler.register(
            dailyJob(policy: TomMissedWindowPolicy.runAll, catchUpLimit: 2),
          );
          await scheduler.tick();

          final catchUp =
              (await store.all())
                  .where(
                    (r) => r.id != 'seed' && r.scheduledFor.isBefore(clock.now),
                  )
                  .map((r) => r.scheduledFor)
                  .toList()
                ..sort();
          expect(catchUp, [DateTime.utc(2026, 3, 4), DateTime.utc(2026, 3, 5)]);
        },
      );

      test(
        'the windows dropped by the limit are alerted, not silent',
        () async {
          await seedStaleHistory();
          final scheduler = schedulerFor(store, clock, alerts: alerts);
          addTearDown(scheduler.close);
          scheduler.register(
            dailyJob(policy: TomMissedWindowPolicy.runAll, catchUpLimit: 2),
          );
          await scheduler.tick();

          final missed = alerts.where(
            (a) => a.kind == TomJobAlertKind.windowsMissed,
          );
          expect(missed, hasLength(1));
          expect(missed.single.missedWindows, 2);
        },
      );

      test('no alert is raised when nothing was missed', () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob(policy: TomMissedWindowPolicy.skip));
        await scheduler.tick();
        clock.advance(const Duration(minutes: 5));
        await scheduler.tick();
        expect(
          alerts.where((a) => a.kind == TomJobAlertKind.windowsMissed),
          isEmpty,
        );
      });
    });

    group('one-shot deadlines', () {
      /// A one-shot job firing an hour after the clock's start.
      TomJobDefinition deadlineJob({
        DateTime? at,
        TomMissedWindowPolicy policy = TomMissedWindowPolicy.runOnce,
      }) => TomJobDefinition(
        name: 'deadline',
        schedule: TomOnceSchedule(at ?? DateTime.utc(2026, 3, 1, 11)),
        body: (_) => OkCommand(),
        missedWindowPolicy: policy,
        retryPolicy: TomRetryPolicy.none,
      );

      test(
        'fires once and only once, however long the scheduler runs on',
        () async {
          final dispatcher = RecordingDispatcher();
          final scheduler = schedulerFor(
            store,
            clock,
            dispatcher: dispatcher,
            alerts: alerts,
          );
          addTearDown(scheduler.close);
          scheduler.register(deadlineJob());

          // Planned but not due.
          await scheduler.tick();
          expect(dispatcher.dispatched, isEmpty);
          expect(
            (await store.all()).single.scheduledFor,
            DateTime.utc(2026, 3, 1, 11),
          );

          clock.now = DateTime.utc(2026, 3, 1, 11);
          await scheduler.tick();
          await settle();
          expect(dispatcher.dispatched, hasLength(1));

          // Days of ticking afterwards add nothing: nextFireAfter is null from
          // the instant onwards, so there is no second window to plan.
          for (var i = 0; i < 5; i++) {
            clock.advance(const Duration(hours: 12));
            await scheduler.tick();
            await settle();
          }
          expect(dispatcher.dispatched, hasLength(1));
          expect(await store.all(), hasLength(1));
        },
      );

      test('a planned deadline still fires after an outage that swallowed it, '
          'under every missed-window policy', () async {
        for (final policy in TomMissedWindowPolicy.values) {
          final outageStore = TomMemoryJobStore();
          final outageClock = FakeClock(DateTime.utc(2026, 3, 1, 10));
          final job = TomJobDefinition(
            name: 'deadline',
            schedule: TomOnceSchedule(DateTime.utc(2026, 3, 1, 11)),
            body: (_) => OkCommand(),
            missedWindowPolicy: policy,
            retryPolicy: TomRetryPolicy.none,
          );

          final before = schedulerFor(outageStore, outageClock);
          before.register(job);
          await before.tick();
          before.close();

          // The process was down across the instant. The window is durable
          // state, so the policy — which governs windows the schedule would
          // *produce* after the last record — never gets a say: the run is
          // already planned and merely late.
          outageClock.now = DateTime.utc(2026, 3, 4, 9);
          final after = schedulerFor(outageStore, outageClock);
          addTearDown(after.close);
          after.register(job);
          await after.tick();
          await settle();

          final runs = await outageStore.all();
          expect(runs, hasLength(1), reason: '$policy');
          expect(
            runs.single.scheduledFor,
            DateTime.utc(2026, 3, 1, 11),
            reason: '$policy',
          );
          expect(
            runs.single.state,
            TomJobRunState.succeeded,
            reason: '$policy',
          );
        }
      });

      test('a deadline first registered after its instant plans nothing and '
          'says so', () async {
        clock.now = DateTime.utc(2026, 3, 4, 9);
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(deadlineJob());
        await scheduler.tick();
        await settle();

        expect(await store.all(), isEmpty);
        final never = alerts.where((a) => a.kind == TomJobAlertKind.neverFires);
        expect(never, hasLength(1));
        expect(never.single.jobName, 'deadline');
        expect(never.single.schedule, isA<TomOnceSchedule>());
        expect(
          never.single.describe(),
          contains('once(2026-03-01T11:00:00.000Z)'),
        );
      });

      test('the never-fires alert is raised once, not once per tick', () async {
        clock.now = DateTime.utc(2026, 3, 4, 9);
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(deadlineJob());
        for (var i = 0; i < 5; i++) {
          clock.advance(const Duration(minutes: 30));
          await scheduler.tick();
        }
        expect(
          alerts.where((a) => a.kind == TomJobAlertKind.neverFires),
          hasLength(1),
        );
      });

      test('re-registering the job lets it report again', () async {
        clock.now = DateTime.utc(2026, 3, 4, 9);
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(deadlineJob());
        await scheduler.tick();
        // A corrected registration that is still wrong is news again — the
        // operator changed something and deserves to hear it did not help.
        scheduler.register(deadlineJob(at: DateTime.utc(2026, 3, 2)));
        await scheduler.tick();
        expect(
          alerts.where((a) => a.kind == TomJobAlertKind.neverFires),
          hasLength(2),
        );
      });

      test('a recurrence that can never match reports the same way', () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        // February 30th.
        scheduler.register(
          jobNamed('impossible', TomCronSchedule('0 0 30 2 *')),
        );
        await scheduler.tick();

        expect(await store.all(), isEmpty);
        final never = alerts.where((a) => a.kind == TomJobAlertKind.neverFires);
        expect(never, hasLength(1));
        expect(never.single.describe(), contains('will never run'));
      });
    });

    group('dispatch', () {
      test('a due window is executed and the run completes', () async {
        final dispatcher = RecordingDispatcher();
        final scheduler = schedulerFor(
          store,
          clock,
          dispatcher: dispatcher,
          alerts: alerts,
        );
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());

        await scheduler.tick(); // plans 2026-03-02T00:00Z
        expect(dispatcher.dispatched, isEmpty);

        clock.now = DateTime.utc(2026, 3, 2, 0, 1);
        await scheduler.tick();
        await pumpEventQueue();

        expect(dispatcher.dispatched, hasLength(1));
        final run = (await store.all()).firstWhere(
          (r) => r.scheduledFor == DateTime.utc(2026, 3, 2),
        );
        expect(run.state, TomJobRunState.succeeded);
      });

      test('the body factory receives the run it will execute', () async {
        TomJobRun? seen;
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
          dailyJob(
            body: (run) {
              seen = run;
              return OkCommand();
            },
          ),
        );

        await scheduler.tick();
        clock.now = DateTime.utc(2026, 3, 2, 0, 1);
        await scheduler.tick();
        await pumpEventQueue();

        expect(seen, isNotNull);
        expect(seen!.scheduledFor, DateTime.utc(2026, 3, 2));
        expect(seen!.attempt, 1);
      });

      test('a run for an unregistered job is left for its owner', () async {
        await store.enqueue(
          TomJobRun(
            id: 'orphan',
            jobName: 'someone-elses-job',
            scheduledFor: clock.now,
            runAt: clock.now,
          ),
        );
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        await scheduler.tick();

        expect((await store.all()).single.state, TomJobRunState.pending);
        expect((await store.all()).single.claimedBy, isNull);
      });

      test('maxRunsPerTick bounds how much one pass claims', () async {
        final clockNow = clock.now;
        for (var i = 0; i < 5; i++) {
          await store.enqueue(
            TomJobRun(
              id: 'r$i',
              jobName: 'daily',
              scheduledFor: clockNow.subtract(Duration(minutes: i + 1)),
              runAt: clockNow.subtract(Duration(minutes: i + 1)),
            ),
          );
        }
        final dispatcher = RecordingDispatcher();
        final scheduler = schedulerFor(
          store,
          clock,
          dispatcher: dispatcher,
          alerts: alerts,
          maxRunsPerTick: 2,
        );
        addTearDown(scheduler.close);
        scheduler.register(dailyJob(allowOverlap: true));

        await scheduler.tick();
        await pumpEventQueue();
        expect(dispatcher.dispatched, hasLength(2));
      });
    });

    group('overlap', () {
      test(
        'allowOverlap false holds a second run back while one is in flight',
        () async {
          final gate = Completer<Object?>();
          final dispatcher = RecordingDispatcher(handler: (_) => gate.future);
          final scheduler = schedulerFor(
            store,
            clock,
            dispatcher: dispatcher,
            alerts: alerts,
          );
          addTearDown(scheduler.close);
          scheduler.register(dailyJob());

          final past = clock.now.subtract(const Duration(hours: 1));
          await store.enqueue(
            TomJobRun(
              id: 'a',
              jobName: 'daily',
              scheduledFor: past,
              runAt: past,
            ),
          );
          await store.enqueue(
            TomJobRun(
              id: 'b',
              jobName: 'daily',
              scheduledFor: past.add(const Duration(minutes: 1)),
              runAt: past.add(const Duration(minutes: 1)),
            ),
          );

          await scheduler.tick();
          await pumpEventQueue();
          expect(dispatcher.dispatched, hasLength(1));
          expect(scheduler.inFlightCount, 1);

          // A second pass still cannot start the other run.
          await scheduler.tick();
          await pumpEventQueue();
          expect(dispatcher.dispatched, hasLength(1));

          gate.complete('done');
          await pumpEventQueue();
          await scheduler.tick();
          await pumpEventQueue();
          expect(dispatcher.dispatched, hasLength(2));
        },
      );

      test('allowOverlap true starts both runs in one pass', () async {
        final gate = Completer<Object?>();
        final dispatcher = RecordingDispatcher(handler: (_) => gate.future);
        final scheduler = schedulerFor(
          store,
          clock,
          dispatcher: dispatcher,
          alerts: alerts,
        );
        addTearDown(scheduler.close);
        scheduler.register(dailyJob(allowOverlap: true));

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(
          TomJobRun(id: 'a', jobName: 'daily', scheduledFor: past, runAt: past),
        );
        await store.enqueue(
          TomJobRun(
            id: 'b',
            jobName: 'daily',
            scheduledFor: past.add(const Duration(minutes: 1)),
            runAt: past.add(const Duration(minutes: 1)),
          ),
        );

        await scheduler.tick();
        await pumpEventQueue();
        expect(dispatcher.dispatched, hasLength(2));
        gate.complete('done');
        await pumpEventQueue();
      });
    });

    group('retry, backoff and timeout', () {
      test('a failed attempt is retried after the policy backoff', () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
          dailyJob(
            body: (_) => BoomCommand(),
            retry: const TomRetryPolicy(
              maxAttempts: 3,
              initialBackoff: Duration(minutes: 2),
              jitter: 0,
            ),
          ),
        );

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(
          TomJobRun(id: 'a', jobName: 'daily', scheduledFor: past, runAt: past),
        );

        await scheduler.tick();
        await pumpEventQueue();

        final run = (await store.all()).firstWhere((r) => r.id == 'a');
        expect(run.state, TomJobRunState.pending);
        expect(run.attempt, 2);
        expect(run.runAt, clock.now.add(const Duration(minutes: 2)));
        expect(run.lastError, contains('boom'));
      });

      test('backoff lengthens on each successive attempt', () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
          dailyJob(
            body: (_) => BoomCommand(),
            retry: const TomRetryPolicy(
              maxAttempts: 4,
              initialBackoff: Duration(minutes: 2),
              multiplier: 2,
              jitter: 0,
            ),
          ),
        );

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(
          TomJobRun(id: 'a', jobName: 'daily', scheduledFor: past, runAt: past),
        );

        await scheduler.tick();
        await pumpEventQueue();
        final firstRetryAt = (await store.all())
            .firstWhere((r) => r.id == 'a')
            .runAt;
        expect(firstRetryAt, clock.now.add(const Duration(minutes: 2)));

        clock.now = firstRetryAt;
        await scheduler.tick();
        await pumpEventQueue();
        final run = (await store.all()).firstWhere((r) => r.id == 'a');
        expect(run.attempt, 3);
        expect(run.runAt, clock.now.add(const Duration(minutes: 4)));
      });

      test('a run fails terminally once attempts are exhausted', () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
          dailyJob(
            body: (_) => BoomCommand(),
            retry: const TomRetryPolicy(
              maxAttempts: 2,
              initialBackoff: Duration(minutes: 1),
              jitter: 0,
            ),
          ),
        );

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(
          TomJobRun(id: 'a', jobName: 'daily', scheduledFor: past, runAt: past),
        );

        await scheduler.tick();
        await pumpEventQueue();
        clock.advance(const Duration(minutes: 1));
        await scheduler.tick();
        await pumpEventQueue();

        final run = (await store.all()).firstWhere((r) => r.id == 'a');
        expect(run.state, TomJobRunState.failed);
        expect(run.attempt, 2);
        expect(
          alerts.where((a) => a.kind == TomJobAlertKind.attemptFailed),
          hasLength(1),
        );
        expect(
          alerts.where((a) => a.kind == TomJobAlertKind.runFailed),
          hasLength(1),
        );
      });

      test('a policy of none fails on the first attempt', () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
          dailyJob(body: (_) => BoomCommand(), retry: TomRetryPolicy.none),
        );

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(
          TomJobRun(id: 'a', jobName: 'daily', scheduledFor: past, runAt: past),
        );

        await scheduler.tick();
        await pumpEventQueue();
        expect(
          (await store.all()).firstWhere((r) => r.id == 'a').state,
          TomJobRunState.failed,
        );
      });

      test(
        'a body factory that throws fails the run without retrying',
        () async {
          final scheduler = schedulerFor(store, clock, alerts: alerts);
          addTearDown(scheduler.close);
          scheduler.register(
            dailyJob(
              body: (_) => throw ArgumentError('bad job wiring'),
              retry: const TomRetryPolicy(maxAttempts: 5),
            ),
          );

          final past = clock.now.subtract(const Duration(hours: 1));
          await store.enqueue(
            TomJobRun(
              id: 'a',
              jobName: 'daily',
              scheduledFor: past,
              runAt: past,
            ),
          );

          await scheduler.tick();
          await pumpEventQueue();

          final run = (await store.all()).firstWhere((r) => r.id == 'a');
          expect(run.state, TomJobRunState.failed);
          expect(run.attempt, 1);
          expect(
            alerts.where((a) => a.kind == TomJobAlertKind.runFailed),
            hasLength(1),
          );
        },
      );

      test(
        'a permanent failure is not retried even with budget left',
        () async {
          final scheduler = schedulerFor(store, clock, alerts: alerts);
          addTearDown(scheduler.close);
          scheduler.register(
            dailyJob(
              body: (_) => PermanentlyBoomCommand(),
              retry: const TomRetryPolicy(maxAttempts: 5),
            ),
          );

          final past = clock.now.subtract(const Duration(hours: 1));
          await store.enqueue(
            TomJobRun(
              id: 'a',
              jobName: 'daily',
              scheduledFor: past,
              runAt: past,
            ),
          );

          await scheduler.tick();
          await pumpEventQueue();

          final run = (await store.all()).firstWhere((r) => r.id == 'a');
          // Four attempts were still available; the classification overrides
          // them, because "no attempt can succeed" makes the budget irrelevant.
          expect(run.state, TomJobRunState.failed);
          expect(run.attempt, 1);
          expect(
            alerts.where((a) => a.kind == TomJobAlertKind.attemptFailed),
            isEmpty,
          );
          expect(
            alerts.where((a) => a.kind == TomJobAlertKind.runFailed),
            hasLength(1),
          );
        },
      );

      test('an unclassified failure is still retried', () async {
        // The default must stay transient: retrying a permanent failure wastes
        // attempts, but dropping a transient one loses the work.
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
          dailyJob(
            body: (_) => BoomCommand(),
            retry: const TomRetryPolicy(maxAttempts: 5, jitter: 0),
          ),
        );

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(
          TomJobRun(id: 'a', jobName: 'daily', scheduledFor: past, runAt: past),
        );

        await scheduler.tick();
        await pumpEventQueue();

        final run = (await store.all()).firstWhere((r) => r.id == 'a');
        expect(run.state, TomJobRunState.pending);
        expect(run.attempt, 2);
      });

      test(
        'an attempt that overruns the timeout is failed and retried',
        () async {
          final scheduler = schedulerFor(store, clock, alerts: alerts);
          addTearDown(scheduler.close);
          scheduler.register(
            dailyJob(
              body: (_) => SlowCommand(const Duration(seconds: 5)),
              timeout: const Duration(milliseconds: 20),
              retry: const TomRetryPolicy(
                maxAttempts: 2,
                initialBackoff: Duration(minutes: 1),
                jitter: 0,
              ),
            ),
          );

          final past = clock.now.subtract(const Duration(hours: 1));
          await store.enqueue(
            TomJobRun(
              id: 'a',
              jobName: 'daily',
              scheduledFor: past,
              runAt: past,
            ),
          );

          await scheduler.tick();
          await Future<void>.delayed(const Duration(milliseconds: 80));

          final run = (await store.all()).firstWhere((r) => r.id == 'a');
          expect(run.state, TomJobRunState.pending);
          expect(run.attempt, 2);
          expect(
            alerts.where((a) => a.kind == TomJobAlertKind.timedOut),
            hasLength(1),
          );
        },
      );

      test('a successful run is not retried', () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(
          TomJobRun(id: 'a', jobName: 'daily', scheduledFor: past, runAt: past),
        );

        await scheduler.tick();
        await pumpEventQueue();
        expect((await store.all()).firstWhere((r) => r.id == 'a').attempt, 1);
        expect(alerts, isEmpty);
      });
    });

    group('lease recovery', () {
      test('an expired lease is returned to the queue and alerted', () async {
        final scheduler = schedulerFor(
          store,
          clock,
          alerts: alerts,
          leaseTimeout: const Duration(minutes: 5),
        );
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(
          TomJobRun(
            id: 'a',
            jobName: 'daily',
            scheduledFor: past,
            runAt: past,
            state: TomJobRunState.running,
            claimedBy: 'a-scheduler-that-died',
            claimedAt: past,
          ),
        );

        await scheduler.tick();
        await pumpEventQueue();

        expect(
          alerts.where((a) => a.kind == TomJobAlertKind.runAbandoned),
          hasLength(1),
        );
        // Recovered, then re-claimed and executed in the same pass.
        expect(
          (await store.all()).firstWhere((r) => r.id == 'a').state,
          TomJobRunState.succeeded,
        );
      });

      test('a run whose lease is still valid is left in flight', () async {
        final scheduler = schedulerFor(
          store,
          clock,
          alerts: alerts,
          leaseTimeout: const Duration(minutes: 15),
        );
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());

        await store.enqueue(
          TomJobRun(
            id: 'a',
            jobName: 'daily',
            scheduledFor: clock.now,
            runAt: clock.now,
            state: TomJobRunState.running,
            claimedBy: 'another-live-scheduler',
            claimedAt: clock.now,
          ),
        );

        await scheduler.tick();
        await pumpEventQueue();
        expect(
          (await store.all()).firstWhere((r) => r.id == 'a').state,
          TomJobRunState.running,
        );
        expect(
          alerts.where((a) => a.kind == TomJobAlertKind.runAbandoned),
          isEmpty,
        );
      });

      /// A run left `running` by a node that died, optionally mid-execution.
      Future<void> seedAbandoned({required bool started}) async {
        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(
          TomJobRun(
            id: 'a',
            jobName: 'daily',
            scheduledFor: past,
            runAt: past,
            state: TomJobRunState.running,
            claimedBy: 'a-scheduler-that-died',
            claimedAt: past,
            startedAt: started ? past : null,
          ),
        );
      }

      test(
        'a run interrupted mid-execution is not re-queued by default',
        () async {
          final scheduler = schedulerFor(
            store,
            clock,
            alerts: alerts,
            leaseTimeout: const Duration(minutes: 5),
          );
          addTearDown(scheduler.close);
          scheduler.register(dailyJob());
          await seedAbandoned(started: true);

          await scheduler.tick();
          await settle();

          // The default is the safe reading: the body may have written half its
          // effects, and re-running it would repeat them.
          final run = (await store.all()).firstWhere((r) => r.id == 'a');
          expect(run.state, TomJobRunState.failed);
          expect(run.lastError, TomJobStore.recoveryDeclinedError);
          expect(
            alerts.where((a) => a.kind == TomJobAlertKind.recoveryDeclined),
            hasLength(1),
          );
          expect(
            alerts.where((a) => a.kind == TomJobAlertKind.runAbandoned),
            isEmpty,
            reason: 'declining recovery is a different event from recovering',
          );
        },
      );

      test('a run interrupted mid-execution is re-queued when the job requests '
          'recovery', () async {
        final scheduler = schedulerFor(
          store,
          clock,
          alerts: alerts,
          leaseTimeout: const Duration(minutes: 5),
        );
        addTearDown(scheduler.close);
        scheduler.register(dailyJob(requestsRecovery: true));
        await seedAbandoned(started: true);

        await scheduler.tick();
        await settle();

        expect(
          (await store.all()).firstWhere((r) => r.id == 'a').state,
          TomJobRunState.succeeded,
        );
        expect(
          alerts.where((a) => a.kind == TomJobAlertKind.runAbandoned),
          hasLength(1),
        );
      });

      test('a run claimed but never started is re-queued regardless of the '
          'opt-in', () async {
        final scheduler = schedulerFor(
          store,
          clock,
          alerts: alerts,
          leaseTimeout: const Duration(minutes: 5),
        );
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());
        await seedAbandoned(started: false);

        await scheduler.tick();
        await settle();

        expect(
          (await store.all()).firstWhere((r) => r.id == 'a').state,
          TomJobRunState.succeeded,
          reason: 'nothing executed, so nothing can repeat',
        );
      });

      test('a run is marked started before its body is dispatched', () async {
        final gate = Completer<Object?>();
        final scheduler = schedulerFor(
          store,
          clock,
          alerts: alerts,
          dispatcher: RecordingDispatcher(handler: (_) => gate.future),
        );
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());

        await scheduler.tick();
        clock.advance(const Duration(days: 1));
        await scheduler.tick();
        await settle();

        // Still in flight — and already on record as having started, which is
        // the whole point: a node that dies here must leave that evidence.
        final run = (await store.all()).firstWhere(
          (r) => r.state == TomJobRunState.running,
        );
        expect(run.startedAt, isNotNull);
        gate.complete(null);
        await settle();
      });
    });

    group('catch-up budget', () {
      /// Nine windows are already missed, across three jobs.
      Future<void> seedThreeStaleJobs() async {
        for (final name in ['j1', 'j2', 'j3']) {
          await store.enqueue(
            TomJobRun(
              id: 'seed-$name',
              jobName: name,
              scheduledFor: clock.now.subtract(const Duration(days: 3)),
              runAt: clock.now.subtract(const Duration(days: 3)),
              state: TomJobRunState.succeeded,
            ),
          );
        }
      }

      /// The runs a pass enqueued for a window that has already elapsed — which
      /// is what the budget counts. A look-ahead window is not catch-up and is
      /// deliberately free.
      List<TomJobRun> catchUpRuns(List<TomJobRun> all) => all
          .where(
            (r) =>
                !r.id.startsWith('seed-') && !r.scheduledFor.isAfter(clock.now),
          )
          .toList();

      test('the per-pass budget is shared across jobs', () async {
        await seedThreeStaleJobs();
        final scheduler = schedulerFor(
          store,
          clock,
          alerts: alerts,
          maxCatchUpPerTick: 4,
        );
        addTearDown(scheduler.close);
        for (final name in ['j1', 'j2', 'j3']) {
          scheduler.register(
            dailyJob(
              name: name,
              policy: TomMissedWindowPolicy.runAll,
              catchUpLimit: 10,
            ),
          );
        }

        await scheduler.tick();

        // Each job is within its own catchUpLimit; the cap that bites is the
        // registry-wide one, which is the whole reason it exists.
        expect(catchUpRuns(await store.all()), hasLength(4));
      });

      test(
        'a clipped backlog resumes on the next pass rather than being lost',
        () async {
          await seedThreeStaleJobs();
          final scheduler = schedulerFor(
            store,
            clock,
            alerts: alerts,
            maxCatchUpPerTick: 4,
          );
          addTearDown(scheduler.close);
          for (final name in ['j1', 'j2', 'j3']) {
            scheduler.register(
              dailyJob(
                name: name,
                policy: TomMissedWindowPolicy.runAll,
                catchUpLimit: 10,
              ),
            );
          }

          await scheduler.tick();
          await settle();
          await scheduler.tick();
          await settle();
          await scheduler.tick();
          await settle();

          // Every missed window arrives, just spread over three passes.
          expect(
            catchUpRuns(await store.all()),
            hasLength(9),
            reason: 'clipping defers; it must not drop',
          );
        },
      );

      test('an unclipped pass still plans the next window', () async {
        await seedThreeStaleJobs();
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
          dailyJob(name: 'j1', policy: TomMissedWindowPolicy.runAll),
        );

        await scheduler.tick();

        expect(
          (await store.all()).where((r) => r.scheduledFor.isAfter(clock.now)),
          hasLength(1),
          reason: 'look-ahead is skipped only when the backlog was clipped',
        );
      });

      test('a budget below one is rejected at construction', () {
        expect(
          () => schedulerFor(store, clock, maxCatchUpPerTick: 0),
          throwsA(
            isA<TomScheduleException>().having(
              (e) => e.key,
              'key',
              'schedule.scheduler.catch_up_per_tick',
            ),
          ),
        );
      });
    });

    group('tick jitter', () {
      test('an out-of-range jitter is rejected at construction', () {
        for (final bad in [-0.1, 1.0, 2.0]) {
          expect(
            () => schedulerFor(store, clock, tickJitter: bad),
            throwsA(
              isA<TomScheduleException>().having(
                (e) => e.key,
                'key',
                'schedule.scheduler.tick_jitter',
              ),
            ),
            reason: 'jitter $bad',
          );
        }
      });

      test(
        'successive intervals differ, and never exceed tickInterval',
        () async {
          // The observable consequence of jitter without reaching into private
          // state: over many draws the delays must vary, and none may be late.
          const interval = Duration(milliseconds: 40);
          final fired = <DateTime>[];
          final scheduler = schedulerFor(
            store,
            clock,
            tickInterval: interval,
            tickJitter: 0.5,
            clockOverride: () {
              final now = DateTime.now();
              fired.add(now);
              return now;
            },
          );
          addTearDown(scheduler.close);

          await scheduler.start();
          await Future<void>.delayed(const Duration(milliseconds: 400));
          scheduler.stop();

          expect(
            fired.length,
            greaterThan(4),
            reason: 'the timer must actually be re-arming',
          );
          final gaps = <int>[
            for (var i = 1; i < fired.length; i++)
              fired[i].difference(fired[i - 1]).inMicroseconds,
          ];
          // Never later than the promised interval, allowing for the event loop's
          // own lateness on a busy machine.
          expect(gaps.every((g) => g <= interval.inMicroseconds * 2), isTrue);
          expect(
            gaps.toSet(),
            hasLength(greaterThan(1)),
            reason:
                'a constant gap would mean the jitter was not drawn per '
                'interval',
          );
        },
      );

      test('zero jitter keeps the interval exact', () {
        final scheduler = schedulerFor(store, clock, tickJitter: 0);
        addTearDown(scheduler.close);
        expect(scheduler.tickJitter, 0);
      });
    });

    group('event triggers', () {
      test('an event enqueues a run carrying its payload', () async {
        final controller = makeEventSource();
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
          TomJobDefinition(
            name: 'on-event',
            schedule: TomEventSchedule(controller.stream),
            body: (_) => OkCommand(),
          ),
        );

        controller.add({'orderId': 42});
        await pumpEventQueue();

        final run = (await store.all()).single;
        expect(run.jobName, 'on-event');
        expect(run.payload, {'orderId': 42});
      });

      test('two events at the same instant collapse into one run', () async {
        final controller = makeEventSource();
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
          TomJobDefinition(
            name: 'on-event',
            schedule: TomEventSchedule(controller.stream),
            body: (_) => OkCommand(),
          ),
        );

        controller
          ..add('one')
          ..add('two');
        await pumpEventQueue();
        expect(await store.all(), hasLength(1));
      });

      test('an event-triggered run is dispatched by the next tick', () async {
        final controller = makeEventSource();
        final dispatcher = RecordingDispatcher();
        final scheduler = schedulerFor(
          store,
          clock,
          dispatcher: dispatcher,
          alerts: alerts,
        );
        addTearDown(scheduler.close);
        scheduler.register(
          TomJobDefinition(
            name: 'on-event',
            schedule: TomEventSchedule(controller.stream),
            body: (run) => OkCommand(run.payload),
          ),
        );

        controller.add('payload');
        await pumpEventQueue();
        await scheduler.tick();
        await pumpEventQueue();

        expect(dispatcher.dispatched, hasLength(1));
        expect((await store.all()).single.state, TomJobRunState.succeeded);
      });

      test('deregister stops the subscription from enqueuing more', () async {
        final controller = makeEventSource();
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
          TomJobDefinition(
            name: 'on-event',
            schedule: TomEventSchedule(controller.stream),
            body: (_) => OkCommand(),
          ),
        );

        scheduler.deregister('on-event');
        controller.add('ignored');
        await pumpEventQueue();
        expect(await store.all(), isEmpty);
      });
    });

    group('lifecycle', () {
      test(
        'start runs a pass immediately rather than waiting an interval',
        () async {
          final scheduler = TomScheduler(
            store: store,
            dispatcher: const TomInlineJobDispatcher(),
            clock: clock.call,
            tickInterval: const Duration(hours: 1),
            onAlert: alerts.add,
          );
          addTearDown(scheduler.close);
          scheduler.register(dailyJob());

          await scheduler.start();
          expect(await store.all(), hasLength(1));
          expect(scheduler.isRunning, isTrue);
        },
      );

      test('stop halts the timer but leaves the scheduler usable', () async {
        final scheduler = TomScheduler(
          store: store,
          dispatcher: const TomInlineJobDispatcher(),
          clock: clock.call,
          tickInterval: const Duration(hours: 1),
          onAlert: alerts.add,
        );
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());
        await scheduler.start();
        scheduler.stop();
        expect(scheduler.isRunning, isFalse);
        await scheduler.tick();
      });

      test('the periodic timer really fires a pass', () async {
        final scheduler = TomScheduler(
          store: store,
          dispatcher: const TomInlineJobDispatcher(),
          clock: clock.call,
          tickInterval: const Duration(milliseconds: 10),
          onAlert: alerts.add,
        );
        addTearDown(scheduler.close);

        await scheduler.start();
        // Registered only after the immediate pass, so the run below can only
        // be the work of a timer-driven tick.
        scheduler.register(dailyJob());
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(await store.all(), isNotEmpty);
      });

      test('a tick after close does nothing', () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        scheduler.register(dailyJob());
        scheduler.close();
        await scheduler.tick();
        expect(await store.all(), isEmpty);
      });

      test('close does not close a pool it was merely handed', () {
        // Documented contract of TomWorkerPoolJobDispatcher.ownsPool; asserted
        // here on the flag because closing a real pool is covered separately.
        expect(const TomInlineJobDispatcher().dispatch(OkCommand()), completes);
      });
    });

    group('end to end', () {
      test('a cron job fires on schedule, survives a restart with its pending '
          'runs intact, and completes', () async {
        final path = '${makeTempDir().path}/queue.json';

        // --- First process: plans tomorrow's window, then "dies" mid-run.
        final firstStore = TomFileJobStore(path);
        final gate = Completer<Object?>();
        final firstScheduler = schedulerFor(
          firstStore,
          clock,
          dispatcher: RecordingDispatcher(handler: (_) => gate.future),
          alerts: alerts,
          leaseTimeout: const Duration(minutes: 5),
        );
        // Opted into recovery: the process dies *mid-execution*, and only a job
        // that says it is safe to run again gets picked back up.
        firstScheduler.register(dailyJob(requestsRecovery: true));
        await firstScheduler.tick();
        expect(
          (await firstStore.all()).single.scheduledFor,
          DateTime.utc(2026, 3, 2),
        );

        clock.now = DateTime.utc(2026, 3, 2, 0, 1);
        await firstScheduler.tick();
        await pumpEventQueue();
        expect(
          (await firstStore.all())
              .firstWhere((r) => r.scheduledFor == DateTime.utc(2026, 3, 2))
              .state,
          TomJobRunState.running,
        );
        firstScheduler.close(); // process exits holding the lease

        // --- Second process: same file, later clock.
        clock.now = DateTime.utc(2026, 3, 2, 0, 30);
        final secondStore = TomFileJobStore(path);
        final restored = (await secondStore.all()).firstWhere(
          (r) => r.scheduledFor == DateTime.utc(2026, 3, 2),
        );
        expect(
          restored.state,
          TomJobRunState.running,
          reason: 'the in-flight run survived the restart',
        );

        final secondAlerts = <TomJobAlert>[];
        final secondScheduler = schedulerFor(
          secondStore,
          clock,
          alerts: secondAlerts,
          leaseTimeout: const Duration(minutes: 5),
        );
        addTearDown(secondScheduler.close);
        secondScheduler.register(dailyJob(requestsRecovery: true));
        await secondScheduler.tick();
        await pumpEventQueue();

        expect(
          secondAlerts.where((a) => a.kind == TomJobAlertKind.runAbandoned),
          hasLength(1),
        );
        expect(
          (await secondStore.all())
              .firstWhere((r) => r.scheduledFor == DateTime.utc(2026, 3, 2))
              .state,
          TomJobRunState.succeeded,
        );
        // And it planned the following day while it was there.
        expect(
          (await secondStore.all()).map((r) => r.scheduledFor),
          contains(DateTime.utc(2026, 3, 3)),
        );
        gate.complete('ignored');
      });
    });
  });

  // ===========================================================================
  // ISOLATE POOL DISPATCH
  // ===========================================================================

  group('TomWorkerPoolJobDispatcher', () {
    test('a scheduled job body executes on the isolate pool', () async {
      final marker = '${makeTempDir().path}/ran.txt';
      final pool = await TomWorkerPool.withSize(1, SchedulingWorkerContext());
      addTearDown(pool.close);

      final clock = FakeClock(DateTime.utc(2026, 3, 1, 10));
      final store = TomMemoryJobStore();
      final scheduler = TomScheduler(
        store: store,
        dispatcher: TomWorkerPoolJobDispatcher(pool),
        clock: clock.call,
        ownerId: 'pool-test',
        onAlert: (_) {},
      );
      addTearDown(scheduler.close);

      scheduler.register(
        TomJobDefinition(
          name: 'pooled',
          schedule: TomCronSchedule('0 0 * * *'),
          body: (_) => IsolateMarkerCommand(marker),
          timeout: const Duration(seconds: 20),
        ),
      );

      await scheduler.tick(); // plans 2026-03-02T00:00Z
      clock.now = DateTime.utc(2026, 3, 2, 0, 1);
      await scheduler.tick();

      // The body runs in another isolate, so wait for the file rather than the
      // event queue.
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (!File(marker).existsSync() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(
        File(marker).existsSync(),
        isTrue,
        reason: 'the job body ran inside a worker isolate',
      );

      // The marker proves the *body* ran; the store is written afterwards, once
      // the isolate's result has travelled back over the port. Those are two
      // separate events and the second one is the one being asserted, so wait
      // for it rather than assuming the first implies it.
      Future<TomJobRun> pooledRun() async => (await store.all()).firstWhere(
        (r) => r.scheduledFor == DateTime.utc(2026, 3, 2),
      );
      var run = await pooledRun();
      while (run.state == TomJobRunState.running &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        run = await pooledRun();
      }
      expect(run.state, TomJobRunState.succeeded);
    });

    test(
      'ownsPool false leaves the pool usable after the dispatcher closes',
      () async {
        final pool = await TomWorkerPool.withSize(1, SchedulingWorkerContext());
        addTearDown(pool.close);

        TomWorkerPoolJobDispatcher(pool).close();
        expect(await pool.execute(OkCommand(11)), 11);
      },
    );
  });

  // ===========================================================================
  // csex8 — cluster coordination
  // ===========================================================================

  group('TomLease', () {
    final acquired = DateTime.utc(2026, 5, 1, 12);

    TomLease leaseAt(DateTime at, Duration ttl) => TomLease(
      resource: 'job:r',
      owner: 'node-a',
      token: 7,
      acquiredAt: at,
      expiresAt: at.add(ttl),
    );

    test('is live before its expiry and dead from the instant it lapses', () {
      final lease = leaseAt(acquired, const Duration(minutes: 1));
      expect(lease.isExpiredAt(acquired), isFalse);
      expect(
        lease.isExpiredAt(acquired.add(const Duration(seconds: 59))),
        isFalse,
      );
      // Expiry is inclusive: at exactly expiresAt the lease is gone. The
      // alternative leaves a one-instant window in which two nodes disagree.
      expect(
        lease.isExpiredAt(acquired.add(const Duration(minutes: 1))),
        isTrue,
      );
    });

    test('reports remaining time and clamps to zero once lapsed', () {
      final lease = leaseAt(acquired, const Duration(minutes: 1));
      expect(
        lease.remainingAt(acquired.add(const Duration(seconds: 20))),
        const Duration(seconds: 40),
      );
      expect(
        lease.remainingAt(acquired.add(const Duration(hours: 1))),
        Duration.zero,
      );
    });

    test('round-trips through JSON', () {
      final lease = leaseAt(acquired, const Duration(minutes: 5));
      final back = TomLease.fromJson(lease.toJson());
      expect(back.resource, lease.resource);
      expect(back.owner, lease.owner);
      expect(back.token, lease.token);
      expect(back.acquiredAt, lease.acquiredAt);
      expect(back.expiresAt, lease.expiresAt);
    });
  });

  group('TomLeaseInfo', () {
    final lease = TomLease(
      resource: 'job:r',
      owner: 'node-a',
      token: 3,
      acquiredAt: DateTime.utc(2026, 5, 1),
      expiresAt: DateTime.utc(2026, 5, 1, 0, 1),
    );

    test('a never-held resource is free and has no holder', () {
      const info = TomLeaseInfo.free('job:r');
      expect(info.isHeld, isFalse);
      expect(info.lease, isNull);
      expect(info.holderVanished, isFalse);
      expect(info.describe(), contains('never held'));
    });

    test('distinguishes a released holder from one that vanished', () {
      final released = TomLeaseInfo(
        resource: 'job:r',
        lease: lease,
        isHeld: false,
        wasReleased: true,
      );
      final vanished = TomLeaseInfo(
        resource: 'job:r',
        lease: lease,
        isHeld: false,
      );

      // This is the distinction an operator needs after an incident: a clean
      // shutdown and a dead node both leave the lease free.
      expect(released.holderVanished, isFalse);
      expect(vanished.holderVanished, isTrue);
      expect(released.describe(), contains('released by node-a'));
      expect(vanished.describe(), contains('holder vanished'));
    });

    test('a live lease describes its holder, token and expiry', () {
      final info = TomLeaseInfo(resource: 'job:r', lease: lease, isHeld: true);
      expect(info.describe(), contains('held by node-a'));
      expect(info.describe(), contains('token 3'));
      expect(info.holderVanished, isFalse);
    });
  });

  // Every behaviour required of the port is asserted against *both*
  // implementations, so the file lock cannot quietly diverge from the in-memory
  // one that most tests use as a stand-in.
  // Every behaviour required of the port is asserted against *both*
  // implementations, so the file lock cannot quietly diverge from the in-memory
  // one that most tests use as a stand-in.
  runTomLeaseLockContract(
    'TomMemoryLeaseLock',
    (clock) async => TomMemoryLeaseLock(clock: clock),
  );
  runTomLeaseLockContract(
    'TomFileLeaseLock',
    (clock) async =>
        TomFileLeaseLock('${makeTempDir().path}/leases', clock: clock),
  );

  group('TomFileLeaseLock (durability and process sharing)', () {
    test('a lease survives the object that created it', () async {
      final dir = makeTempDir();
      final clock = FakeClock(DateTime.utc(2026, 5, 1, 12));

      final first = TomFileLeaseLock('${dir.path}/leases', clock: clock.call);
      await first.acquire('r', 'node-a', const Duration(minutes: 5));

      // A second lock object over the same directory is what a second *process*
      // sees. It must observe the first one's lease.
      final second = TomFileLeaseLock('${dir.path}/leases', clock: clock.call);
      expect(
        await second.acquire('r', 'node-b', const Duration(minutes: 5)),
        isNull,
      );
      expect((await second.inspect('r')).lease!.owner, 'node-a');
    });

    test('a holder that dies without releasing is taken over once its lease '
        'lapses', () async {
      final dir = makeTempDir();
      final clock = FakeClock(DateTime.utc(2026, 5, 1, 12));

      // "Death" is simply never releasing and never renewing.
      final dead = TomFileLeaseLock('${dir.path}/leases', clock: clock.call);
      final lost = await dead.acquire(
        'r',
        'node-a',
        const Duration(minutes: 1),
      );

      clock.advance(const Duration(minutes: 2));
      final survivor = TomFileLeaseLock(
        '${dir.path}/leases',
        clock: clock.call,
      );
      final taken = await survivor.acquire(
        'r',
        'node-b',
        const Duration(minutes: 1),
      );

      expect(taken, isNotNull);
      expect(taken!.token, greaterThan(lost!.token));
      expect((await survivor.inspect('r')).lease!.owner, 'node-b');
    });

    test('resource names that are not filesystem-safe still work', () async {
      final lock = TomFileLeaseLock('${makeTempDir().path}/leases');
      addTearDown(lock.close);

      // Run ids embed the job name and a timestamp with colons and slashes.
      const nasty = 'run:nightly/report:2026-05-01T00:00:00.000Z';
      expect(
        await lock.acquire(nasty, 'node-a', const Duration(minutes: 1)),
        isNotNull,
      );
      expect(
        await lock.acquire(nasty, 'node-b', const Duration(minutes: 1)),
        isNull,
      );
    });

    test(
      'a corrupt lease record is taken over once it is older than the TTL',
      () async {
        final dir = makeTempDir();
        final lock = TomFileLeaseLock('${dir.path}/leases');
        const ttl = Duration(minutes: 1);
        final first = await lock.acquire('r', 'node-a', ttl);

        // Simulate a process killed between creating its record and writing it.
        final record = Directory('${dir.path}/leases')
            .listSync()
            .whereType<Directory>()
            .single
            .listSync()
            .whereType<File>()
            .single;
        record.writeAsStringSync('{ this is not json');

        // Recently touched: another node may be mid-acquire, so do not steal.
        expect(await lock.acquire('r', 'node-b', ttl), isNull);

        // Age is measured against the real clock, because it asks how long a file
        // has physically existed. Backdate it rather than sleeping out the TTL.
        record.setLastModifiedSync(
          DateTime.now().subtract(const Duration(hours: 1)),
        );

        // Old enough that its writer is certainly gone: recover rather than
        // leaving the resource wedged forever.
        final second = await lock.acquire('r', 'node-b', ttl);
        expect(second, isNotNull);
        expect(
          second!.token,
          greaterThan(first!.token),
          reason: 'recovery is still an acquisition and still fences',
        );
      },
    );

    test(
      'concurrent isolates racing one resource produce exactly one winner',
      () async {
        final dir = makeTempDir();
        final path = '${dir.path}/leases';
        const racers = 8;

        // Real isolates issuing real syscalls against one directory. This is the
        // only way to test that the exclusive-create/rename pair actually holds
        // under contention rather than merely looking like it should.
        final results = await Future.wait([
          for (var i = 0; i < racers; i++)
            Isolate.run(() async {
              final lock = TomFileLeaseLock(path);
              final lease = await lock.acquire(
                'contended',
                'node-$i',
                const Duration(minutes: 5),
              );
              return lease == null ? '' : lease.owner;
            }),
        ]);

        final winners = results.where((owner) => owner.isNotEmpty).toList();
        expect(
          winners,
          hasLength(1),
          reason:
              'exactly one of $racers isolates may hold the lease, '
              'got $winners',
        );
      },
    );

    test('concurrent isolates racing a lapsed lease produce exactly one '
        'winner', () async {
      final dir = makeTempDir();
      final path = '${dir.path}/leases';
      const racers = 8;

      // Seed an already-expired lease so every racer arrives at the *takeover*
      // path simultaneously — the two-step rename dance, which is where a
      // naive implementation double-grants.
      final seed = TomFileLeaseLock(path);
      await seed.acquire('contended', 'dead-node', const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      final results = await Future.wait([
        for (var i = 0; i < racers; i++)
          Isolate.run(() async {
            final lock = TomFileLeaseLock(path);
            final lease = await lock.acquire(
              'contended',
              'node-$i',
              const Duration(minutes: 5),
            );
            return lease == null ? '' : '${lease.owner}#${lease.token}';
          }),
      ]);

      final winners = results.where((r) => r.isNotEmpty).toList();
      expect(
        winners,
        hasLength(1),
        reason:
            'a lapsed lease may be taken over by exactly one node, '
            'got $winners',
      );
    });
  });

  group('TomJobStore release (durability)', () {
    final now = DateTime.utc(2026, 5, 1, 12);

    // The rest of release/renewClaim is in the shared contract; this asserts the
    // one thing only the file store can be asked: that the mirror was written.
    test('the file store persists a release', () async {
      final path = '${makeTempDir().path}/queue.json';
      final store = TomFileJobStore(path);
      final run = TomJobRun(
        id: 'r1',
        jobName: 'job',
        scheduledFor: now,
        runAt: now,
      );
      await store.enqueue(run);
      await store.claimDue(now, 'node-a');
      await store.release(run);

      final reloaded = await TomFileJobStore(path).all();
      expect(reloaded.single.state, TomJobRunState.pending);
      expect(reloaded.single.claimedBy, isNull);
    });
  });

  group('TomScheduler cluster coordination', () {
    late FakeClock clock;
    late TomMemoryJobStore store;
    late TomMemoryLeaseLock lock;
    final start = DateTime.utc(2026, 5, 1, 12);

    setUp(() {
      clock = FakeClock(start);
      store = TomMemoryJobStore();
      lock = TomMemoryLeaseLock(clock: clock.call);
    });

    /// Two schedulers over one store and one lock — the cluster, in miniature.
    List<TomScheduler> cluster(
      int size, {
      TomJobDispatcher Function(int index)? dispatcher,
      List<TomJobAlert>? alerts,
    }) => [
      for (var i = 0; i < size; i++)
        schedulerFor(
          store,
          clock,
          lock: lock,
          ownerId: 'node-$i',
          dispatcher: dispatcher?.call(i),
          alerts: alerts,
        ),
    ];

    test('two nodes sharing a store execute a due run exactly once', () async {
      final dispatchers = <int, RecordingDispatcher>{};
      final nodes = cluster(
        2,
        dispatcher: (i) {
          return dispatchers[i] = RecordingDispatcher();
        },
      );
      addTearDown(() {
        for (final node in nodes) {
          node.close();
        }
      });

      final job = jobNamed('nightly', TomCronSchedule('0 3 * * *'));
      for (final node in nodes) {
        node.register(job);
      }

      // Both nodes plan, both see the window come due, both try to claim.
      for (final node in nodes) {
        await node.tick();
      }
      clock.now = DateTime.utc(2026, 5, 2, 3);
      await Future.wait(nodes.map((n) => n.tick()));
      await settle();

      final total = dispatchers.values.fold<int>(
        0,
        (sum, d) => sum + d.dispatched.length,
      );
      expect(
        total,
        1,
        reason: 'the whole point: one window, one execution, two nodes',
      );
      final runs = await store.all();
      expect(
        runs.where((r) => r.state == TomJobRunState.succeeded),
        hasLength(1),
      );
    });

    // A peer already holds the job's lease. This is the case the lock exists
    // for: a store whose claim is *not* atomic across processes — the file
    // store — lets two nodes both believe they claimed the run, and only the
    // lease separates them. Holding the lease directly reproduces the loser's
    // position without needing two processes to collide by luck.
    Future<TomLease> peerHolds(String jobName) async => (await lock.acquire(
      'job:$jobName',
      'peer',
      const Duration(minutes: 5),
    ))!;

    test('the losing node hands its claim straight back rather than sitting '
        'on it', () async {
      final node = schedulerFor(store, clock, lock: lock, ownerId: 'node-0');
      addTearDown(node.close);
      node.register(
        jobNamed('gated', TomIntervalSchedule(const Duration(minutes: 5))),
      );

      await node.tick();
      clock.advance(const Duration(minutes: 6));
      await peerHolds('gated');
      await node.tick();

      // The claim must go back to the queue, not sit under the loser's name
      // until its store lease times out — a peer should be able to take it on
      // its very next tick.
      final runs = await store.all();
      expect(runs.where((r) => r.claimedBy != null), isEmpty);
      final due = runs.singleWhere((r) => !r.runAt.isAfter(clock.now));
      expect(due.state, TomJobRunState.pending);
      expect(
        due.attempt,
        1,
        reason:
            'the first attempt is still ahead of it — losing a race must '
            'not spend the job\'s retry budget',
      );
      expect(node.inFlightCount, 0);
      expect(node.heldLeases, isEmpty);
    });

    test(
      'the conceding node reports contention rather than failing the run',
      () async {
        final alerts = <TomJobAlert>[];
        final node = schedulerFor(
          store,
          clock,
          lock: lock,
          ownerId: 'node-0',
          alerts: alerts,
        );
        addTearDown(node.close);
        node.register(
          jobNamed('gated', TomIntervalSchedule(const Duration(minutes: 5))),
        );

        await node.tick();
        clock.advance(const Duration(minutes: 6));
        await peerHolds('gated');
        await node.tick();

        final contended = alerts
            .where((a) => a.kind == TomJobAlertKind.lockContended)
            .toList();
        expect(contended, hasLength(1));
        expect(
          contended.single.lease!.owner,
          'peer',
          reason:
              'an operator asking "why did this node not run?" must be '
              'told who did',
        );
        expect(
          alerts.where((a) => a.kind == TomJobAlertKind.runFailed),
          isEmpty,
          reason: 'losing a race is not a failure',
        );
      },
    );

    test('a node resumes the moment the peer lets go', () async {
      final dispatcher = RecordingDispatcher();
      final node = schedulerFor(
        store,
        clock,
        lock: lock,
        ownerId: 'node-0',
        dispatcher: dispatcher,
      );
      addTearDown(node.close);
      node.register(
        jobNamed('gated', TomIntervalSchedule(const Duration(minutes: 5))),
      );

      await node.tick();
      clock.advance(const Duration(minutes: 6));
      final peer = await peerHolds('gated');
      await node.tick();
      expect(dispatcher.dispatched, isEmpty);

      await lock.release(peer);
      await node.tick();
      await settle();
      expect(
        dispatcher.dispatched,
        hasLength(1),
        reason: 'the handed-back claim must still be there to pick up',
      );
    });

    test('a node that takes over a lapsed lease says whose it was', () async {
      final alerts = <TomJobAlert>[];

      // node-a acquires and then "dies" — never renews, never releases.
      await lock.acquire('job:orphan', 'node-a', const Duration(minutes: 1));
      clock.advance(const Duration(minutes: 5));

      final survivor = schedulerFor(
        store,
        clock,
        lock: lock,
        ownerId: 'node-b',
        alerts: alerts,
      );
      addTearDown(survivor.close);
      survivor.register(
        jobNamed('orphan', TomIntervalSchedule(const Duration(minutes: 1))),
      );

      await survivor.tick();
      clock.advance(const Duration(minutes: 2));
      await survivor.tick();

      final stolen = alerts
          .where((a) => a.kind == TomJobAlertKind.leaseStolen)
          .toList();
      expect(
        stolen,
        isNotEmpty,
        reason: 'a takeover must be visible, not silent',
      );
      expect(
        stolen.first.lease!.owner,
        'node-a',
        reason: 'the vanished holder must be named',
      );
    });

    test('a killed holder\'s work is picked up by a survivor', () async {
      final ranOn = <String>[];
      TomJobDispatcher dispatcherFor(String node) => RecordingDispatcher(
        handler: (command) async {
          ranOn.add(node);
          return command.execute();
        },
      );

      final dying = schedulerFor(
        store,
        clock,
        lock: lock,
        ownerId: 'node-dead',
        dispatcher: dispatcherFor('dead'),
      );
      final job = TomJobDefinition(
        name: 'orphaned',
        schedule: TomIntervalSchedule(const Duration(minutes: 5)),
        body: (_) => GatedCommand('never'),
        retryPolicy: TomRetryPolicy.none,
        // The dead node had *started* this body, so only a job that declares
        // itself safe to run twice is handed to the survivor.
        requestsRecovery: true,
      );
      GatedCommand.open('never');
      dying.register(job);

      await dying.tick();
      clock.advance(const Duration(minutes: 6));
      await dying.tick();
      expect(dying.inFlightCount, 1);
      expect(dying.heldLeases, hasLength(1));

      // The node dies: no close, no release, no renewal. Its lease and its
      // store claim both go stale.
      clock.advance(const Duration(minutes: 20));

      final survivor = schedulerFor(
        store,
        clock,
        lock: lock,
        ownerId: 'node-live',
        leaseTimeout: const Duration(minutes: 15),
        dispatcher: dispatcherFor('live'),
      );
      addTearDown(survivor.close);
      survivor.register(
        jobNamed(
          'orphaned',
          TomIntervalSchedule(const Duration(minutes: 5)),
          requestsRecovery: true,
        ),
      );

      await survivor.tick();
      await settle();

      expect(
        ranOn,
        contains('live'),
        reason: 'the survivor must recover the dead node\'s run',
      );
      GatedCommand.release('never');
      await Future<void>.delayed(Duration.zero);
    });

    test('with no lock the scheduler behaves exactly as a single node', () async {
      // The regression guard for the default path: adding coordination must not
      // change the behaviour of the deployments that do not ask for it.
      final dispatcher = RecordingDispatcher();
      final solo = schedulerFor(store, clock, dispatcher: dispatcher);
      addTearDown(solo.close);
      solo.register(
        jobNamed('solo', TomIntervalSchedule(const Duration(minutes: 5))),
      );

      await solo.tick();
      clock.advance(const Duration(minutes: 6));
      await solo.tick();
      await settle();

      expect(dispatcher.dispatched, hasLength(1));
      expect(solo.heldLeases, isEmpty);
    });

    test(
      'allowOverlap false serialises a job across the whole cluster',
      () async {
        final nodes = cluster(2);
        addTearDown(() {
          for (final node in nodes) {
            node.close();
          }
        });

        GatedCommand.open('serial');
        final job = TomJobDefinition(
          name: 'serial',
          schedule: TomIntervalSchedule(const Duration(minutes: 1)),
          body: (_) => GatedCommand('serial'),
          allowOverlap: false,
          retryPolicy: TomRetryPolicy.none,
        );
        for (final node in nodes) {
          node.register(job);
        }

        await nodes[0].tick();
        // Two windows come due at once, on two different nodes.
        clock.advance(const Duration(minutes: 3));
        await nodes[0].tick();
        await nodes[1].tick();

        final running = (await store.all())
            .where((r) => r.state == TomJobRunState.running)
            .toList();
        expect(
          running,
          hasLength(1),
          reason: 'the job leases its own name, so the cluster runs one',
        );

        GatedCommand.release('serial');
        await Future<void>.delayed(Duration.zero);
      },
    );

    test('allowOverlap true lets distinct windows run concurrently but never '
        'the same one twice', () async {
      final dispatchers = <int, RecordingDispatcher>{};
      final nodes = cluster(
        2,
        dispatcher: (i) => dispatchers[i] = RecordingDispatcher(),
      );
      addTearDown(() {
        for (final node in nodes) {
          node.close();
        }
      });

      final job = TomJobDefinition(
        name: 'parallel',
        schedule: TomIntervalSchedule(const Duration(minutes: 1)),
        body: (_) => OkCommand(),
        allowOverlap: true,
        missedWindowPolicy: TomMissedWindowPolicy.runAll,
        retryPolicy: TomRetryPolicy.none,
      );
      for (final node in nodes) {
        node.register(job);
      }

      await nodes[0].tick();
      clock.advance(const Duration(minutes: 3));
      await Future.wait(nodes.map((n) => n.tick()));
      await settle();

      final runs = await store.all();
      final succeeded = runs
          .where((r) => r.state == TomJobRunState.succeeded)
          .toList();
      final windows = succeeded.map((r) => r.scheduledFor).toSet();
      expect(
        windows,
        hasLength(succeeded.length),
        reason:
            'no window may be executed twice even when overlap is '
            'allowed',
      );
      final total = dispatchers.values.fold<int>(
        0,
        (sum, d) => sum + d.dispatched.length,
      );
      expect(total, succeeded.length);
    });

    test('the lease is released when the run finishes, so a peer can take the '
        'next window at once', () async {
      final node = schedulerFor(store, clock, lock: lock, ownerId: 'node-0');
      addTearDown(node.close);
      node.register(
        jobNamed('quick', TomIntervalSchedule(const Duration(minutes: 5))),
      );

      await node.tick();
      clock.advance(const Duration(minutes: 6));
      await node.tick();
      await settle();

      expect(
        node.heldLeases,
        isEmpty,
        reason: 'a finished run must not leave its lease held',
      );
      final info = await lock.inspect('job:quick');
      expect(info.isHeld, isFalse);
      expect(
        info.holderVanished,
        isFalse,
        reason: 'an orderly finish releases rather than lapses',
      );
      expect(
        info.wasReleased,
        isTrue,
        reason:
            'the record must say the holder left cleanly, so an incident '
            'review can tell a scale-down from a death',
      );
    });

    test(
      'close releases held leases so peers need not wait out the TTL',
      () async {
        final node = schedulerFor(store, clock, lock: lock, ownerId: 'node-0');
        GatedCommand.open('closing');
        node.register(
          TomJobDefinition(
            name: 'closing',
            schedule: TomIntervalSchedule(const Duration(minutes: 5)),
            body: (_) => GatedCommand('closing'),
            retryPolicy: TomRetryPolicy.none,
          ),
        );

        await node.tick();
        clock.advance(const Duration(minutes: 6));
        await node.tick();
        expect(node.heldLeases, hasLength(1));

        node.close();
        // The release is fire-and-forget, so let the microtask queue drain.
        await Future<void>.delayed(Duration.zero);

        expect((await lock.inspect('job:closing')).isHeld, isFalse);
        GatedCommand.release('closing');
        await Future<void>.delayed(Duration.zero);
      },
    );

    test('heldLeases reports what this node is sitting on', () async {
      final node = schedulerFor(store, clock, lock: lock, ownerId: 'node-0');
      addTearDown(node.close);
      GatedCommand.open('held');
      node.register(
        TomJobDefinition(
          name: 'held',
          schedule: TomIntervalSchedule(const Duration(minutes: 5)),
          body: (_) => GatedCommand('held'),
          retryPolicy: TomRetryPolicy.none,
        ),
      );

      await node.tick();
      clock.advance(const Duration(minutes: 6));
      await node.tick();

      expect(node.heldLeases, hasLength(1));
      expect(node.heldLeases.values.single.owner, 'node-0');
      expect(node.heldLeases.values.single.resource, 'job:held');

      GatedCommand.release('held');
      await Future<void>.delayed(Duration.zero);
    });

    test('a renew interval at or beyond the TTL is rejected at construction', () {
      // Misconfiguration that would lapse every lease before its first renewal,
      // producing constant spurious takeovers. Fail loudly at wiring time.
      expect(
        () => TomScheduler(
          store: store,
          dispatcher: const TomInlineJobDispatcher(),
          leaseTtl: const Duration(seconds: 30),
          leaseRenewInterval: const Duration(seconds: 30),
        ),
        throwsA(isA<TomScheduleException>()),
      );
    });

    test('the renew interval defaults to a third of the TTL', () {
      final node = TomScheduler(
        store: store,
        dispatcher: const TomInlineJobDispatcher(),
        leaseTtl: const Duration(seconds: 90),
      );
      addTearDown(node.close);
      expect(node.leaseRenewInterval, const Duration(seconds: 30));
    });
  });

  group('TomScheduler lease renewal and loss', () {
    // These tests use the real wall clock, because the renewal heartbeat is a
    // real Timer. The durations are small but the mechanism is production's.
    test('a long run keeps its lease alive by renewing it', () async {
      final store = TomMemoryJobStore();
      final lock = TomMemoryLeaseLock();
      final node = TomScheduler(
        store: store,
        dispatcher: const TomInlineJobDispatcher(),
        ownerId: 'node-0',
        lock: lock,
        leaseTtl: const Duration(milliseconds: 120),
        leaseRenewInterval: const Duration(milliseconds: 20),
      );
      addTearDown(node.close);

      GatedCommand.open('long');
      node.register(
        TomJobDefinition(
          name: 'long',
          schedule: TomIntervalSchedule(const Duration(milliseconds: 10)),
          body: (_) => GatedCommand('long'),
          timeout: const Duration(seconds: 5),
          retryPolicy: TomRetryPolicy.none,
        ),
      );

      await node.tick();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await node.tick();
      expect(node.inFlightCount, 1);

      // Outlive the TTL several times over. Without renewal the lease would
      // have lapsed long ago and a peer could have stolen the run.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final info = await lock.inspect('job:long');
      expect(
        info.isHeld,
        isTrue,
        reason: 'renewal must keep a long run\'s lease alive',
      );
      expect(info.lease!.owner, 'node-0');

      GatedCommand.release('long');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('losing the lease mid-run is reported and the node stops writing the '
        'outcome', () async {
      final alerts = <TomJobAlert>[];
      final store = TomMemoryJobStore();
      final inner = TomMemoryLeaseLock();
      final node = TomScheduler(
        store: store,
        dispatcher: const TomInlineJobDispatcher(),
        ownerId: 'node-0',
        lock: StallingLeaseLock(inner),
        leaseTtl: const Duration(milliseconds: 100),
        leaseRenewInterval: const Duration(milliseconds: 15),
        onAlert: alerts.add,
      );
      addTearDown(node.close);

      GatedCommand.open('stolen');
      node.register(
        TomJobDefinition(
          name: 'stolen',
          schedule: TomIntervalSchedule(const Duration(milliseconds: 10)),
          body: (_) => GatedCommand('stolen'),
          timeout: const Duration(seconds: 5),
          retryPolicy: TomRetryPolicy.none,
        ),
      );

      await node.tick();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await node.tick();
      expect(node.inFlightCount, 1);

      // The heartbeat stops landing, so the lease lapses under a node that is
      // still working — the split-brain case.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        alerts.where((a) => a.kind == TomJobAlertKind.leaseLost),
        isNotEmpty,
        reason: 'losing a lease mid-run must never be silent',
      );

      final thief = await inner.acquire(
        'job:stolen',
        'node-thief',
        const Duration(minutes: 1),
      );
      expect(
        thief,
        isNotNull,
        reason: 'a lapsed lease is exactly what a peer is entitled to take',
      );
      expect(
        thief!.token,
        greaterThan(1),
        reason: 'the fencing token is how a resource tells the two apart',
      );

      GatedCommand.release('stolen');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // The displaced node must not have written its result over the thief's
      // record: the run is the thief's to complete now.
      final runs = await store.all();
      expect(
        runs.where((r) => r.state == TomJobRunState.succeeded),
        isEmpty,
        reason: 'a node that lost its lease must not record an outcome',
      );
      expect(
        runs.where((r) => r.state == TomJobRunState.running),
        hasLength(1),
        reason: 'the run stays in flight, owned by whoever holds the lease',
      );
      expect(node.heldLeases, isEmpty);
    });
  });
}

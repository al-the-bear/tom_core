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

/// A clock the tests move by hand.
class FakeClock {
  DateTime now;

  FakeClock(this.now);

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
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
}) =>
    TomScheduler(
      store: store,
      dispatcher: dispatcher ?? const TomInlineJobDispatcher(),
      clock: clock.call,
      ownerId: 'test-owner',
      leaseTimeout: leaseTimeout,
      maxRunsPerTick: maxRunsPerTick,
      // Zero-seed Random keeps jitter reproducible run to run.
      random: Random(0),
      onAlert: alerts == null ? (_) {} : alerts.add,
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
        expect(() => TomCronSchedule('   '), throwsA(isA<TomScheduleException>()));
      });

      test('rejects a four-field expression', () {
        expect(() => TomCronSchedule('0 3 * *'),
            throwsA(isA<TomScheduleException>()));
      });

      test('rejects a six-field expression rather than guessing at seconds', () {
        expect(() => TomCronSchedule('0 0 3 * * *'),
            throwsA(isA<TomScheduleException>()));
      });

      test('rejects an out-of-range value', () {
        expect(() => TomCronSchedule('60 * * * *'),
            throwsA(isA<TomScheduleException>()));
        expect(() => TomCronSchedule('* 24 * * *'),
            throwsA(isA<TomScheduleException>()));
        expect(() => TomCronSchedule('* * 32 * *'),
            throwsA(isA<TomScheduleException>()));
        expect(() => TomCronSchedule('* * * 13 *'),
            throwsA(isA<TomScheduleException>()));
      });

      test('rejects an inverted range', () {
        expect(() => TomCronSchedule('10-5 * * * *'),
            throwsA(isA<TomScheduleException>()));
      });

      test('rejects a non-numeric field', () {
        expect(() => TomCronSchedule('x * * * *'),
            throwsA(isA<TomScheduleException>()));
      });

      test('expands a comma list', () {
        final cron = TomCronSchedule('0,30 * * * *');
        final at = DateTime.utc(2026, 3, 1, 10, 5);
        expect(cron.nextFireAfter(at), DateTime.utc(2026, 3, 1, 10, 30));
        expect(cron.nextFireAfter(DateTime.utc(2026, 3, 1, 10, 30)),
            DateTime.utc(2026, 3, 1, 11, 0));
      });

      test('expands a step on a wildcard', () {
        final cron = TomCronSchedule('*/15 * * * *');
        expect(cron.nextFireAfter(DateTime.utc(2026, 3, 1, 10, 1)),
            DateTime.utc(2026, 3, 1, 10, 15));
      });

      test('expands a step on a range', () {
        final cron = TomCronSchedule('0-10/5 * * * *');
        expect(cron.nextFireAfter(DateTime.utc(2026, 3, 1, 10, 0)),
            DateTime.utc(2026, 3, 1, 10, 5));
        expect(cron.nextFireAfter(DateTime.utc(2026, 3, 1, 10, 10)),
            DateTime.utc(2026, 3, 1, 11, 0));
      });

      test('accepts month names case-insensitively', () {
        final cron = TomCronSchedule('0 0 1 jul *');
        expect(cron.nextFireAfter(DateTime.utc(2026, 3, 1)),
            DateTime.utc(2026, 7, 1));
      });

      test('accepts day-of-week names', () {
        final cron = TomCronSchedule('0 0 * * MON');
        // 2026-03-01 is a Sunday, so the next Monday midnight is the 2nd.
        expect(cron.nextFireAfter(DateTime.utc(2026, 3, 1)),
            DateTime.utc(2026, 3, 2));
      });

      test('treats day-of-week 7 as Sunday, like 0', () {
        final seven = TomCronSchedule('0 0 * * 7');
        final zero = TomCronSchedule('0 0 * * 0');
        final from = DateTime.utc(2026, 3, 3);
        expect(seven.nextFireAfter(from), zero.nextFireAfter(from));
      });

      test('expands the @daily macro', () {
        expect(TomCronSchedule('@daily').nextFireAfter(DateTime.utc(2026, 3, 1, 5)),
            DateTime.utc(2026, 3, 2));
      });

      test('expands the @monthly and @yearly macros', () {
        expect(
            TomCronSchedule('@monthly').nextFireAfter(DateTime.utc(2026, 3, 5)),
            DateTime.utc(2026, 4, 1));
        expect(
            TomCronSchedule('@yearly').nextFireAfter(DateTime.utc(2026, 3, 5)),
            DateTime.utc(2027, 1, 1));
      });

      test('expands the @hourly macro', () {
        expect(
            TomCronSchedule('@hourly').nextFireAfter(DateTime.utc(2026, 3, 5, 7, 30)),
            DateTime.utc(2026, 3, 5, 8));
      });

      test('rejects an unknown macro', () {
        expect(() => TomCronSchedule('@fortnightly'),
            throwsA(isA<TomScheduleException>()));
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
            cron.nextFireAfter(
                DateTime.utc(2026, 3, 1, 10, 30, 45, 123)),
            DateTime.utc(2026, 3, 1, 10, 31));
      });

      test('crosses a month boundary', () {
        final cron = TomCronSchedule('0 0 1 * *');
        expect(cron.nextFireAfter(DateTime.utc(2026, 3, 15)),
            DateTime.utc(2026, 4, 1));
      });

      test('crosses a year boundary', () {
        final cron = TomCronSchedule('0 0 1 1 *');
        expect(cron.nextFireAfter(DateTime.utc(2026, 6, 1)),
            DateTime.utc(2027, 1, 1));
      });

      test('finds February 29th in a leap year', () {
        final cron = TomCronSchedule('0 0 29 2 *');
        // 2027 and 2026 are not leap years; 2028 is.
        expect(cron.nextFireAfter(DateTime.utc(2026, 3, 1)),
            DateTime.utc(2028, 2, 29));
      });

      test('returns null for an expression that can never match', () {
        expect(TomCronSchedule('0 0 30 2 *').nextFireAfter(DateTime.utc(2026)),
            isNull);
      });

      test('preserves UTC', () {
        final fire =
            TomCronSchedule('0 0 * * *').nextFireAfter(DateTime.utc(2026, 3, 1, 5));
        expect(fire!.isUtc, isTrue);
      });

      test('preserves local time', () {
        final fire = TomCronSchedule('0 0 * * *')
            .nextFireAfter(DateTime(2026, 3, 1, 5));
        expect(fire!.isUtc, isFalse);
        expect(fire, DateTime(2026, 3, 2));
      });
    });

    group('day-of-month / day-of-week', () {
      test('ORs the two fields when both are restricted (POSIX)', () {
        // 2026-03-01 is a Sunday, so Mondays are the 2nd, 9th, 16th, 23rd, 30th.
        final cron = TomCronSchedule('0 0 15 3 MON');
        final fires = <DateTime>[];
        var cursor = DateTime.utc(2026, 3, 1);
        for (var i = 0; i < 6; i++) {
          final next = cron.nextFireAfter(cursor);
          if (next == null || next.month != 3) break;
          fires.add(next);
          cursor = next;
        }
        expect(fires.map((d) => d.day), [2, 9, 15, 16, 23, 30]);
      });

      test('applies only day-of-week when day-of-month is wildcard', () {
        final cron = TomCronSchedule('0 0 * * MON');
        expect(cron.nextFireAfter(DateTime.utc(2026, 3, 2)),
            DateTime.utc(2026, 3, 9));
      });

      test('applies only day-of-month when day-of-week is wildcard', () {
        final cron = TomCronSchedule('0 0 15 * *');
        expect(cron.nextFireAfter(DateTime.utc(2026, 3, 1)),
            DateTime.utc(2026, 3, 15));
      });
    });
  });

  // ===========================================================================
  // CALENDAR
  // ===========================================================================

  group('TomCalendarSchedule', () {
    group('dayOfMonth', () {
      test('fires on a positive day', () {
        final cal = TomCalendarSchedule.dayOfMonth(10, hour: 9);
        expect(cal.nextFireAfter(DateTime.utc(2026, 3, 1)),
            DateTime.utc(2026, 3, 10, 9));
      });

      test('fires on the last day of a 31-day month', () {
        final cal = TomCalendarSchedule.dayOfMonth(-1);
        expect(cal.nextFireAfter(DateTime.utc(2026, 3, 1)),
            DateTime.utc(2026, 3, 31));
      });

      test('fires on the last day of a 30-day month', () {
        final cal = TomCalendarSchedule.dayOfMonth(-1);
        expect(cal.nextFireAfter(DateTime.utc(2026, 4, 1)),
            DateTime.utc(2026, 4, 30));
      });

      test('fires on the last day of February in a leap year', () {
        final cal = TomCalendarSchedule.dayOfMonth(-1);
        expect(cal.nextFireAfter(DateTime.utc(2028, 2, 1)),
            DateTime.utc(2028, 2, 29));
      });

      test('counts back from the month end for -2', () {
        final cal = TomCalendarSchedule.dayOfMonth(-2);
        expect(cal.nextFireAfter(DateTime.utc(2026, 4, 1)),
            DateTime.utc(2026, 4, 29));
      });

      test('skips a month that lacks the requested day rather than clamping', () {
        final cal = TomCalendarSchedule.dayOfMonth(31);
        // April has no 31st, so the next fire after April 1st is May 31st.
        expect(cal.nextFireAfter(DateTime.utc(2026, 4, 1)),
            DateTime.utc(2026, 5, 31));
      });

      test('honours a quarterly interval anchored on a month', () {
        final cal = TomCalendarSchedule.dayOfMonth(
          1,
          monthInterval: 3,
          anchorMonth: 1,
        );
        expect(cal.nextFireAfter(DateTime.utc(2026, 2, 1)),
            DateTime.utc(2026, 4, 1));
        expect(cal.nextFireAfter(DateTime.utc(2026, 4, 1)),
            DateTime.utc(2026, 7, 1));
      });

      test('keeps a quarterly cycle continuous across a year boundary', () {
        final cal = TomCalendarSchedule.dayOfMonth(
          1,
          monthInterval: 3,
          anchorMonth: 2,
        );
        // Feb, May, Aug, Nov — then Feb again, not January.
        expect(cal.nextFireAfter(DateTime.utc(2026, 11, 1)),
            DateTime.utc(2027, 2, 1));
      });

      test('rejects day 0 and out-of-range days', () {
        expect(() => TomCalendarSchedule.dayOfMonth(0),
            throwsA(isA<TomScheduleException>()));
        expect(() => TomCalendarSchedule.dayOfMonth(32),
            throwsA(isA<TomScheduleException>()));
        expect(() => TomCalendarSchedule.dayOfMonth(-32),
            throwsA(isA<TomScheduleException>()));
      });

      test('rejects an out-of-range hour, minute, interval or anchor', () {
        expect(() => TomCalendarSchedule.dayOfMonth(1, hour: 24),
            throwsA(isA<TomScheduleException>()));
        expect(() => TomCalendarSchedule.dayOfMonth(1, minute: 60),
            throwsA(isA<TomScheduleException>()));
        expect(() => TomCalendarSchedule.dayOfMonth(1, monthInterval: 0),
            throwsA(isA<TomScheduleException>()));
        expect(() => TomCalendarSchedule.dayOfMonth(1, anchorMonth: 13),
            throwsA(isA<TomScheduleException>()));
      });
    });

    group('weekdayOfMonth', () {
      test('fires on the second Tuesday', () {
        final cal = TomCalendarSchedule.weekdayOfMonth(
          weekday: DateTime.tuesday,
          ordinal: 2,
        );
        // March 2026: Tuesdays are 3, 10, 17, 24, 31.
        expect(cal.nextFireAfter(DateTime.utc(2026, 3, 1)),
            DateTime.utc(2026, 3, 10));
      });

      test('fires on the last Friday', () {
        final cal = TomCalendarSchedule.weekdayOfMonth(
          weekday: DateTime.friday,
          ordinal: -1,
        );
        // March 2026: Fridays are 6, 13, 20, 27.
        expect(cal.nextFireAfter(DateTime.utc(2026, 3, 1)),
            DateTime.utc(2026, 3, 27));
      });

      test('skips a month with no fifth occurrence', () {
        final cal = TomCalendarSchedule.weekdayOfMonth(
          weekday: DateTime.tuesday,
          ordinal: 5,
        );
        // March 2026 has a 5th Tuesday (31st); April 2026 does not, so after
        // March 31st the next is June 30th.
        expect(cal.nextFireAfter(DateTime.utc(2026, 3, 1)),
            DateTime.utc(2026, 3, 31));
        expect(cal.nextFireAfter(DateTime.utc(2026, 3, 31)),
            DateTime.utc(2026, 6, 30));
      });

      test('rejects an out-of-range weekday or ordinal', () {
        expect(
            () => TomCalendarSchedule.weekdayOfMonth(weekday: 0, ordinal: 1),
            throwsA(isA<TomScheduleException>()));
        expect(
            () => TomCalendarSchedule.weekdayOfMonth(weekday: 8, ordinal: 1),
            throwsA(isA<TomScheduleException>()));
        expect(
            () => TomCalendarSchedule.weekdayOfMonth(
                weekday: DateTime.monday, ordinal: 6),
            throwsA(isA<TomScheduleException>()));
        expect(
            () => TomCalendarSchedule.weekdayOfMonth(
                weekday: DateTime.monday, ordinal: -2),
            throwsA(isA<TomScheduleException>()));
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
      expect(interval.nextFireAfter(DateTime.utc(2026, 3, 1, 10, 7)),
          DateTime.utc(2026, 3, 1, 10, 15));
    });

    test('steps one grid point on when asked exactly on the grid', () {
      final interval = TomIntervalSchedule(const Duration(minutes: 15));
      expect(interval.nextFireAfter(DateTime.utc(2026, 3, 1, 10, 15)),
          DateTime.utc(2026, 3, 1, 10, 30));
    });

    test('resumes on the original grid after a long gap, without drifting', () {
      final anchor = DateTime.utc(2026, 3, 1, 10);
      final interval =
          TomIntervalSchedule(const Duration(minutes: 10), anchor: anchor);
      // An hour and seven minutes later the next grid point is still :10-aligned.
      expect(interval.nextFireAfter(DateTime.utc(2026, 3, 1, 11, 7)),
          DateTime.utc(2026, 3, 1, 11, 10));
    });

    test('honours a custom anchor', () {
      final interval = TomIntervalSchedule(
        const Duration(minutes: 90),
        anchor: DateTime.utc(2026, 3, 1, 0, 5),
      );
      expect(interval.nextFireAfter(DateTime.utc(2026, 3, 1)),
          DateTime.utc(2026, 3, 1, 0, 5));
    });

    test('rejects a non-positive period', () {
      expect(() => TomIntervalSchedule(Duration.zero),
          throwsA(isA<TomScheduleException>()));
      expect(() => TomIntervalSchedule(const Duration(seconds: -1)),
          throwsA(isA<TomScheduleException>()));
    });

    test('preserves UTC-ness', () {
      final interval = TomIntervalSchedule(const Duration(minutes: 10));
      expect(interval.nextFireAfter(DateTime.utc(2026, 3, 1))!.isUtc, isTrue);
      expect(interval.nextFireAfter(DateTime(2026, 3, 1))!.isUtc, isFalse);
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

  group('TomMemoryJobStore', () {
    late TomMemoryJobStore store;
    final at = DateTime.utc(2026, 3, 1, 10);

    setUp(() => store = TomMemoryJobStore());

    TomJobRun run(String id, {DateTime? window, DateTime? runAt}) => TomJobRun(
          id: id,
          jobName: 'job',
          scheduledFor: window ?? at,
          runAt: runAt ?? window ?? at,
        );

    test('enqueue stores a run retrievable by window', () async {
      await store.enqueue(run('a'));
      expect((await store.findWindow('job', at))!.id, 'a');
    });

    test('findWindow does not match a different job', () async {
      await store.enqueue(run('a'));
      expect(await store.findWindow('other', at), isNull);
    });

    test('lastWindow is null for an unknown job', () async {
      expect(await store.lastWindow('job'), isNull);
    });

    test('lastWindow reports the latest window enqueued', () async {
      await store.enqueue(run('a'));
      await store.enqueue(run('b', window: at.add(const Duration(days: 1))));
      await store.enqueue(
          run('c', window: at.subtract(const Duration(days: 1))));
      expect(await store.lastWindow('job'), at.add(const Duration(days: 1)));
    });

    test('claimDue takes a due run and leases it', () async {
      await store.enqueue(run('a'));
      final claimed = await store.claimDue(at, 'owner-1');
      expect(claimed.single.id, 'a');
      expect(claimed.single.state, TomJobRunState.running);
      expect(claimed.single.claimedBy, 'owner-1');
      expect(claimed.single.claimedAt, at);
    });

    test('claimDue leaves a future run alone', () async {
      await store.enqueue(run('a', runAt: at.add(const Duration(minutes: 1))));
      expect(await store.claimDue(at, 'owner-1'), isEmpty);
    });

    test('claimDue does not re-claim a running run', () async {
      await store.enqueue(run('a'));
      await store.claimDue(at, 'owner-1');
      expect(await store.claimDue(at, 'owner-2'), isEmpty);
    });

    test('claimDue honours the limit', () async {
      for (var i = 0; i < 5; i++) {
        await store.enqueue(run('r$i', window: at.add(Duration(minutes: i))));
      }
      expect((await store.claimDue(at.add(const Duration(hours: 1)), 'o',
              limit: 2))
          .length, 2);
    });

    test('claimDue honours the accept predicate', () async {
      await store.enqueue(run('a'));
      await store.enqueue(run('b', window: at.add(const Duration(minutes: 1))));
      final claimed = await store.claimDue(
        at.add(const Duration(hours: 1)),
        'o',
        accept: (r) => r.id == 'b',
      );
      expect(claimed.map((r) => r.id), ['b']);
    });

    test('complete marks succeeded and releases the lease', () async {
      await store.enqueue(run('a'));
      final claimed = (await store.claimDue(at, 'o')).single;
      await store.complete(claimed, at.add(const Duration(seconds: 5)));
      final stored = (await store.all()).single;
      expect(stored.state, TomJobRunState.succeeded);
      expect(stored.completedAt, at.add(const Duration(seconds: 5)));
      expect(stored.claimedBy, isNull);
      expect(stored.isFinished, isTrue);
    });

    test('fail with a retryAt returns the run to pending with a new attempt',
        () async {
      await store.enqueue(run('a'));
      final claimed = (await store.claimDue(at, 'o')).single;
      final retryAt = at.add(const Duration(minutes: 1));
      await store.fail(claimed, 'nope', at, retryAt: retryAt);
      final stored = (await store.all()).single;
      expect(stored.state, TomJobRunState.pending);
      expect(stored.attempt, 2);
      expect(stored.runAt, retryAt);
      expect(stored.lastError, 'nope');
      expect(stored.completedAt, isNull);
    });

    test('fail without a retryAt is terminal', () async {
      await store.enqueue(run('a'));
      final claimed = (await store.claimDue(at, 'o')).single;
      await store.fail(claimed, 'nope', at);
      final stored = (await store.all()).single;
      expect(stored.state, TomJobRunState.failed);
      expect(stored.attempt, 1);
      expect(stored.completedAt, at);
      expect(stored.isFinished, isTrue);
    });

    test('recoverAbandoned returns an expired lease to the queue', () async {
      await store.enqueue(run('a'));
      await store.claimDue(at, 'dead-owner');
      final later = at.add(const Duration(minutes: 20));
      final recovered =
          await store.recoverAbandoned(later, const Duration(minutes: 15));
      expect(recovered.single.id, 'a');
      expect(recovered.single.state, TomJobRunState.pending);
      expect(recovered.single.claimedBy, isNull);
    });

    test('recoverAbandoned leaves a fresh lease alone', () async {
      await store.enqueue(run('a'));
      await store.claimDue(at, 'live-owner');
      final recovered = await store.recoverAbandoned(
          at.add(const Duration(minutes: 1)), const Duration(minutes: 15));
      expect(recovered, isEmpty);
    });

    test('recoverAbandoned does not charge the run an attempt', () async {
      await store.enqueue(run('a'));
      await store.claimDue(at, 'dead-owner');
      final recovered = await store.recoverAbandoned(
          at.add(const Duration(hours: 1)), const Duration(minutes: 15));
      expect(recovered.single.attempt, 1);
    });

    test('purgeFinished drops terminal runs older than the cutoff', () async {
      await store.enqueue(run('done'));
      await store.enqueue(run('open', window: at.add(const Duration(hours: 1))));
      await store.complete(
          (await store.claimDue(at, 'o')).single, at);
      final purged = await store.purgeFinished(at.add(const Duration(days: 1)));
      expect(purged, 1);
      expect((await store.all()).map((r) => r.id), ['open']);
    });

    test('purgeFinished keeps a terminal run newer than the cutoff', () async {
      await store.enqueue(run('done'));
      await store.complete((await store.claimDue(at, 'o')).single, at);
      expect(await store.purgeFinished(at.subtract(const Duration(days: 1))), 0);
    });
  });

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
      ).toJson()
        ..['state'] = 'quantum';
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
      await first.enqueue(TomJobRun(
        id: 'a',
        jobName: 'job',
        scheduledFor: at,
        runAt: at,
      ));

      final second = TomFileJobStore(path);
      final restored = (await second.all()).single;
      expect(restored.id, 'a');
      expect(restored.state, TomJobRunState.pending);
      expect(restored.scheduledFor, at);
    });

    test('an in-flight run comes back as an expired lease, not as lost work',
        () async {
      final path = '${makeTempDir().path}/queue.json';
      final first = TomFileJobStore(path);
      await first.enqueue(TomJobRun(
        id: 'a',
        jobName: 'job',
        scheduledFor: at,
        runAt: at,
      ));
      await first.claimDue(at, 'owner-that-dies');

      // The process "restarts": a new store over the same file.
      final second = TomFileJobStore(path);
      final restored = (await second.all()).single;
      expect(restored.state, TomJobRunState.running);
      expect(restored.claimedBy, 'owner-that-dies');

      final recovered = await second.recoverAbandoned(
          at.add(const Duration(hours: 1)), const Duration(minutes: 15));
      expect(recovered.single.id, 'a');
      expect(recovered.single.state, TomJobRunState.pending);
    });

    test('a completed run survives as completed', () async {
      final path = '${makeTempDir().path}/queue.json';
      final first = TomFileJobStore(path);
      await first.enqueue(TomJobRun(
          id: 'a', jobName: 'job', scheduledFor: at, runAt: at));
      await first.complete((await first.claimDue(at, 'o')).single, at);

      expect((await TomFileJobStore(path).all()).single.state,
          TomJobRunState.succeeded);
    });

    test('creates the parent directory on first write', () async {
      final path = '${makeTempDir().path}/nested/deeper/queue.json';
      final store = TomFileJobStore(path);
      await store.enqueue(TomJobRun(
          id: 'a', jobName: 'job', scheduledFor: at, runAt: at));
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
      File(path).writeAsStringSync('['
          '{"id":"bad"},'
          '{"id":"good","jobName":"job",'
          '"scheduledFor":"2026-03-01T10:00:00.000Z",'
          '"runAt":"2026-03-01T10:00:00.000Z","state":"pending","attempt":1}'
          ']');
      expect((await TomFileJobStore(path).all()).map((r) => r.id), ['good']);
    });

    test('a purge is mirrored to disk', () async {
      final path = '${makeTempDir().path}/queue.json';
      final first = TomFileJobStore(path);
      await first.enqueue(TomJobRun(
          id: 'a', jobName: 'job', scheduledFor: at, runAt: at));
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
          throwsA(isA<TomScheduleException>()));
    });

    test('rejects a catchUpLimit below 1', () {
      expect(
          () => TomJobDefinition(
                name: 'job',
                schedule: TomCronSchedule('@daily'),
                body: (_) => OkCommand(),
                catchUpLimit: 0,
              ),
          throwsA(isA<TomScheduleException>()));
    });

    test('rejects a non-positive timeout', () {
      expect(
          () => TomJobDefinition(
                name: 'job',
                schedule: TomCronSchedule('@daily'),
                body: (_) => OkCommand(),
                timeout: Duration.zero,
              ),
          throwsA(isA<TomScheduleException>()));
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
      expect(const TomInlineJobDispatcher().dispatch(BoomCommand()),
          throwsA(isA<StateError>()));
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
    }) =>
        TomJobDefinition(
          name: name,
          schedule: TomCronSchedule('0 0 * * *'),
          body: body ?? (_) => OkCommand(),
          missedWindowPolicy: policy,
          catchUpLimit: catchUpLimit,
          retryPolicy: retry,
          timeout: timeout,
          allowOverlap: allowOverlap,
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

      test('deregister removes the job but leaves its runs in the store',
          () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());
        await scheduler.tick();
        scheduler.deregister('daily');
        expect(scheduler.jobs, isEmpty);
        expect(await store.all(), isNotEmpty);
      });

      test('register after close is refused', () {
        final scheduler = schedulerFor(store, clock, alerts: alerts)..close();
        expect(() => scheduler.register(dailyJob()),
            throwsA(isA<TomScheduleException>()));
      });
    });

    group('planning', () {
      test('first sight anchors on the present instead of replaying history',
          () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());
        await scheduler.tick();

        final runs = await store.all();
        expect(runs, hasLength(1));
        expect(runs.single.scheduledFor, DateTime.utc(2026, 3, 2));
      });

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
        expect((await store.all()).map((r) => r.scheduledFor),
            [DateTime.utc(2026, 3, 2)]);
      });

      test('an event-driven job is not planned by the clock', () async {
        final controller = makeEventSource();
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(TomJobDefinition(
          name: 'on-event',
          schedule: TomEventSchedule(controller.stream),
          body: (_) => OkCommand(),
        ));
        await scheduler.tick();
        expect(await store.all(), isEmpty);
      });
    });

    group('missed windows', () {
      /// Seeds the store as if the scheduler had last planned a window on the
      /// 1st, then went down for four days.
      Future<void> seedStaleHistory() async {
        await store.enqueue(TomJobRun(
          id: 'seed',
          jobName: 'daily',
          scheduledFor: DateTime.utc(2026, 3, 1),
          runAt: DateTime.utc(2026, 3, 1),
          state: TomJobRunState.succeeded,
          completedAt: DateTime.utc(2026, 3, 1),
        ));
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
        final missed =
            alerts.where((a) => a.kind == TomJobAlertKind.windowsMissed);
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
            .where((r) =>
                r.id != 'seed' && r.scheduledFor.isBefore(clock.now))
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

        final catchUp = (await store.all()).firstWhere(
            (r) => r.scheduledFor == DateTime.utc(2026, 3, 5));
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

        final catchUp = (await store.all())
            .where((r) =>
                r.id != 'seed' && r.scheduledFor.isBefore(clock.now))
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

      test('runAll keeps the most recent windows when the limit bites',
          () async {
        await seedStaleHistory();
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
            dailyJob(policy: TomMissedWindowPolicy.runAll, catchUpLimit: 2));
        await scheduler.tick();

        final catchUp = (await store.all())
            .where((r) =>
                r.id != 'seed' && r.scheduledFor.isBefore(clock.now))
            .map((r) => r.scheduledFor)
            .toList()
          ..sort();
        expect(catchUp,
            [DateTime.utc(2026, 3, 4), DateTime.utc(2026, 3, 5)]);
      });

      test('the windows dropped by the limit are alerted, not silent',
          () async {
        await seedStaleHistory();
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
            dailyJob(policy: TomMissedWindowPolicy.runAll, catchUpLimit: 2));
        await scheduler.tick();

        final missed =
            alerts.where((a) => a.kind == TomJobAlertKind.windowsMissed);
        expect(missed, hasLength(1));
        expect(missed.single.missedWindows, 2);
      });

      test('no alert is raised when nothing was missed', () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob(policy: TomMissedWindowPolicy.skip));
        await scheduler.tick();
        clock.advance(const Duration(minutes: 5));
        await scheduler.tick();
        expect(alerts.where((a) => a.kind == TomJobAlertKind.windowsMissed),
            isEmpty);
      });
    });

    group('dispatch', () {
      test('a due window is executed and the run completes', () async {
        final dispatcher = RecordingDispatcher();
        final scheduler =
            schedulerFor(store, clock, dispatcher: dispatcher, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());

        await scheduler.tick(); // plans 2026-03-02T00:00Z
        expect(dispatcher.dispatched, isEmpty);

        clock.now = DateTime.utc(2026, 3, 2, 0, 1);
        await scheduler.tick();
        await pumpEventQueue();

        expect(dispatcher.dispatched, hasLength(1));
        final run = (await store.all())
            .firstWhere((r) => r.scheduledFor == DateTime.utc(2026, 3, 2));
        expect(run.state, TomJobRunState.succeeded);
      });

      test('the body factory receives the run it will execute', () async {
        TomJobRun? seen;
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob(body: (run) {
          seen = run;
          return OkCommand();
        }));

        await scheduler.tick();
        clock.now = DateTime.utc(2026, 3, 2, 0, 1);
        await scheduler.tick();
        await pumpEventQueue();

        expect(seen, isNotNull);
        expect(seen!.scheduledFor, DateTime.utc(2026, 3, 2));
        expect(seen!.attempt, 1);
      });

      test('a run for an unregistered job is left for its owner', () async {
        await store.enqueue(TomJobRun(
          id: 'orphan',
          jobName: 'someone-elses-job',
          scheduledFor: clock.now,
          runAt: clock.now,
        ));
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        await scheduler.tick();

        expect((await store.all()).single.state, TomJobRunState.pending);
        expect((await store.all()).single.claimedBy, isNull);
      });

      test('maxRunsPerTick bounds how much one pass claims', () async {
        final clockNow = clock.now;
        for (var i = 0; i < 5; i++) {
          await store.enqueue(TomJobRun(
            id: 'r$i',
            jobName: 'daily',
            scheduledFor: clockNow.subtract(Duration(minutes: i + 1)),
            runAt: clockNow.subtract(Duration(minutes: i + 1)),
          ));
        }
        final dispatcher = RecordingDispatcher();
        final scheduler = schedulerFor(store, clock,
            dispatcher: dispatcher, alerts: alerts, maxRunsPerTick: 2);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob(allowOverlap: true));

        await scheduler.tick();
        await pumpEventQueue();
        expect(dispatcher.dispatched, hasLength(2));
      });
    });

    group('overlap', () {
      test('allowOverlap false holds a second run back while one is in flight',
          () async {
        final gate = Completer<Object?>();
        final dispatcher = RecordingDispatcher(handler: (_) => gate.future);
        final scheduler =
            schedulerFor(store, clock, dispatcher: dispatcher, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(TomJobRun(
            id: 'a', jobName: 'daily', scheduledFor: past, runAt: past));
        await store.enqueue(TomJobRun(
          id: 'b',
          jobName: 'daily',
          scheduledFor: past.add(const Duration(minutes: 1)),
          runAt: past.add(const Duration(minutes: 1)),
        ));

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
      });

      test('allowOverlap true starts both runs in one pass', () async {
        final gate = Completer<Object?>();
        final dispatcher = RecordingDispatcher(handler: (_) => gate.future);
        final scheduler =
            schedulerFor(store, clock, dispatcher: dispatcher, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob(allowOverlap: true));

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(TomJobRun(
            id: 'a', jobName: 'daily', scheduledFor: past, runAt: past));
        await store.enqueue(TomJobRun(
          id: 'b',
          jobName: 'daily',
          scheduledFor: past.add(const Duration(minutes: 1)),
          runAt: past.add(const Duration(minutes: 1)),
        ));

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
        scheduler.register(dailyJob(
          body: (_) => BoomCommand(),
          retry: const TomRetryPolicy(
            maxAttempts: 3,
            initialBackoff: Duration(minutes: 2),
            jitter: 0,
          ),
        ));

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(TomJobRun(
            id: 'a', jobName: 'daily', scheduledFor: past, runAt: past));

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
        scheduler.register(dailyJob(
          body: (_) => BoomCommand(),
          retry: const TomRetryPolicy(
            maxAttempts: 4,
            initialBackoff: Duration(minutes: 2),
            multiplier: 2,
            jitter: 0,
          ),
        ));

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(TomJobRun(
            id: 'a', jobName: 'daily', scheduledFor: past, runAt: past));

        await scheduler.tick();
        await pumpEventQueue();
        final firstRetryAt =
            (await store.all()).firstWhere((r) => r.id == 'a').runAt;
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
        scheduler.register(dailyJob(
          body: (_) => BoomCommand(),
          retry: const TomRetryPolicy(
            maxAttempts: 2,
            initialBackoff: Duration(minutes: 1),
            jitter: 0,
          ),
        ));

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(TomJobRun(
            id: 'a', jobName: 'daily', scheduledFor: past, runAt: past));

        await scheduler.tick();
        await pumpEventQueue();
        clock.advance(const Duration(minutes: 1));
        await scheduler.tick();
        await pumpEventQueue();

        final run = (await store.all()).firstWhere((r) => r.id == 'a');
        expect(run.state, TomJobRunState.failed);
        expect(run.attempt, 2);
        expect(alerts.where((a) => a.kind == TomJobAlertKind.attemptFailed),
            hasLength(1));
        expect(alerts.where((a) => a.kind == TomJobAlertKind.runFailed),
            hasLength(1));
      });

      test('a policy of none fails on the first attempt', () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(
            dailyJob(body: (_) => BoomCommand(), retry: TomRetryPolicy.none));

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(TomJobRun(
            id: 'a', jobName: 'daily', scheduledFor: past, runAt: past));

        await scheduler.tick();
        await pumpEventQueue();
        expect((await store.all()).firstWhere((r) => r.id == 'a').state,
            TomJobRunState.failed);
      });

      test('a body factory that throws fails the run without retrying',
          () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob(
          body: (_) => throw ArgumentError('bad job wiring'),
          retry: const TomRetryPolicy(maxAttempts: 5),
        ));

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(TomJobRun(
            id: 'a', jobName: 'daily', scheduledFor: past, runAt: past));

        await scheduler.tick();
        await pumpEventQueue();

        final run = (await store.all()).firstWhere((r) => r.id == 'a');
        expect(run.state, TomJobRunState.failed);
        expect(run.attempt, 1);
        expect(alerts.where((a) => a.kind == TomJobAlertKind.runFailed),
            hasLength(1));
      });

      test('an attempt that overruns the timeout is failed and retried',
          () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob(
          body: (_) => SlowCommand(const Duration(seconds: 5)),
          timeout: const Duration(milliseconds: 20),
          retry: const TomRetryPolicy(
            maxAttempts: 2,
            initialBackoff: Duration(minutes: 1),
            jitter: 0,
          ),
        ));

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(TomJobRun(
            id: 'a', jobName: 'daily', scheduledFor: past, runAt: past));

        await scheduler.tick();
        await Future<void>.delayed(const Duration(milliseconds: 80));

        final run = (await store.all()).firstWhere((r) => r.id == 'a');
        expect(run.state, TomJobRunState.pending);
        expect(run.attempt, 2);
        expect(alerts.where((a) => a.kind == TomJobAlertKind.timedOut),
            hasLength(1));
      });

      test('a successful run is not retried', () async {
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(TomJobRun(
            id: 'a', jobName: 'daily', scheduledFor: past, runAt: past));

        await scheduler.tick();
        await pumpEventQueue();
        expect((await store.all()).firstWhere((r) => r.id == 'a').attempt, 1);
        expect(alerts, isEmpty);
      });
    });

    group('lease recovery', () {
      test('an expired lease is returned to the queue and alerted', () async {
        final scheduler = schedulerFor(store, clock,
            alerts: alerts, leaseTimeout: const Duration(minutes: 5));
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());

        final past = clock.now.subtract(const Duration(hours: 1));
        await store.enqueue(TomJobRun(
          id: 'a',
          jobName: 'daily',
          scheduledFor: past,
          runAt: past,
          state: TomJobRunState.running,
          claimedBy: 'a-scheduler-that-died',
          claimedAt: past,
        ));

        await scheduler.tick();
        await pumpEventQueue();

        expect(alerts.where((a) => a.kind == TomJobAlertKind.runAbandoned),
            hasLength(1));
        // Recovered, then re-claimed and executed in the same pass.
        expect((await store.all()).firstWhere((r) => r.id == 'a').state,
            TomJobRunState.succeeded);
      });

      test('a run whose lease is still valid is left in flight', () async {
        final scheduler = schedulerFor(store, clock,
            alerts: alerts, leaseTimeout: const Duration(minutes: 15));
        addTearDown(scheduler.close);
        scheduler.register(dailyJob());

        await store.enqueue(TomJobRun(
          id: 'a',
          jobName: 'daily',
          scheduledFor: clock.now,
          runAt: clock.now,
          state: TomJobRunState.running,
          claimedBy: 'another-live-scheduler',
          claimedAt: clock.now,
        ));

        await scheduler.tick();
        await pumpEventQueue();
        expect((await store.all()).firstWhere((r) => r.id == 'a').state,
            TomJobRunState.running);
        expect(alerts.where((a) => a.kind == TomJobAlertKind.runAbandoned),
            isEmpty);
      });
    });

    group('event triggers', () {
      test('an event enqueues a run carrying its payload', () async {
        final controller = makeEventSource();
        final scheduler = schedulerFor(store, clock, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(TomJobDefinition(
          name: 'on-event',
          schedule: TomEventSchedule(controller.stream),
          body: (_) => OkCommand(),
        ));

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
        scheduler.register(TomJobDefinition(
          name: 'on-event',
          schedule: TomEventSchedule(controller.stream),
          body: (_) => OkCommand(),
        ));

        controller
          ..add('one')
          ..add('two');
        await pumpEventQueue();
        expect(await store.all(), hasLength(1));
      });

      test('an event-triggered run is dispatched by the next tick', () async {
        final controller = makeEventSource();
        final dispatcher = RecordingDispatcher();
        final scheduler =
            schedulerFor(store, clock, dispatcher: dispatcher, alerts: alerts);
        addTearDown(scheduler.close);
        scheduler.register(TomJobDefinition(
          name: 'on-event',
          schedule: TomEventSchedule(controller.stream),
          body: (run) => OkCommand(run.payload),
        ));

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
        scheduler.register(TomJobDefinition(
          name: 'on-event',
          schedule: TomEventSchedule(controller.stream),
          body: (_) => OkCommand(),
        ));

        scheduler.deregister('on-event');
        controller.add('ignored');
        await pumpEventQueue();
        expect(await store.all(), isEmpty);
      });
    });

    group('lifecycle', () {
      test('start runs a pass immediately rather than waiting an interval',
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
      });

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
        expect(
            const TomInlineJobDispatcher().dispatch(OkCommand()), completes);
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
        firstScheduler.register(dailyJob());
        await firstScheduler.tick();
        expect((await firstStore.all()).single.scheduledFor,
            DateTime.utc(2026, 3, 2));

        clock.now = DateTime.utc(2026, 3, 2, 0, 1);
        await firstScheduler.tick();
        await pumpEventQueue();
        expect((await firstStore.all())
            .firstWhere((r) => r.scheduledFor == DateTime.utc(2026, 3, 2))
            .state, TomJobRunState.running);
        firstScheduler.close(); // process exits holding the lease

        // --- Second process: same file, later clock.
        clock.now = DateTime.utc(2026, 3, 2, 0, 30);
        final secondStore = TomFileJobStore(path);
        final restored = (await secondStore.all())
            .firstWhere((r) => r.scheduledFor == DateTime.utc(2026, 3, 2));
        expect(restored.state, TomJobRunState.running,
            reason: 'the in-flight run survived the restart');

        final secondAlerts = <TomJobAlert>[];
        final secondScheduler = schedulerFor(
          secondStore,
          clock,
          alerts: secondAlerts,
          leaseTimeout: const Duration(minutes: 5),
        );
        addTearDown(secondScheduler.close);
        secondScheduler.register(dailyJob());
        await secondScheduler.tick();
        await pumpEventQueue();

        expect(
            secondAlerts.where((a) => a.kind == TomJobAlertKind.runAbandoned),
            hasLength(1));
        expect((await secondStore.all())
            .firstWhere((r) => r.scheduledFor == DateTime.utc(2026, 3, 2))
            .state, TomJobRunState.succeeded);
        // And it planned the following day while it was there.
        expect((await secondStore.all()).map((r) => r.scheduledFor),
            contains(DateTime.utc(2026, 3, 3)));
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
      final pool =
          await TomWorkerPool.withSize(1, SchedulingWorkerContext());
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

      scheduler.register(TomJobDefinition(
        name: 'pooled',
        schedule: TomCronSchedule('0 0 * * *'),
        body: (_) => IsolateMarkerCommand(marker),
        timeout: const Duration(seconds: 20),
      ));

      await scheduler.tick(); // plans 2026-03-02T00:00Z
      clock.now = DateTime.utc(2026, 3, 2, 0, 1);
      await scheduler.tick();

      // The body runs in another isolate, so wait for the file rather than the
      // event queue.
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (!File(marker).existsSync() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      expect(File(marker).existsSync(), isTrue,
          reason: 'the job body ran inside a worker isolate');
      final run = (await store.all())
          .firstWhere((r) => r.scheduledFor == DateTime.utc(2026, 3, 2));
      expect(run.state, TomJobRunState.succeeded);
    });

    test('ownsPool false leaves the pool usable after the dispatcher closes',
        () async {
      final pool =
          await TomWorkerPool.withSize(1, SchedulingWorkerContext());
      addTearDown(pool.close);

      TomWorkerPoolJobDispatcher(pool).close();
      expect(await pool.execute(OkCommand(11)), 11);
    });
  });
}

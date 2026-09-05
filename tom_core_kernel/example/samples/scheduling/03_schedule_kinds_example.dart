/// The three kinds of trigger, and the one interaction between them that is
/// routinely got wrong: a one-shot deadline meeting a missed-window policy.
///
/// A schedule answers exactly one question — *when is the next window after
/// this instant* — and the three kinds differ only in how they answer it:
///
/// | Kind | Classes | `nextFireAfter` |
/// | ---- | ------- | --------------- |
/// | Clock-recurring | [TomCronSchedule], [TomIntervalSchedule], [TomCalendarSchedule] | a window, forever |
/// | One-shot | [TomOnceSchedule] | one window, then never |
/// | Event | [TomEventSchedule] | always `null` — the source drives it |
///
/// The examples below ask each kind directly, then run the two that only make
/// sense in motion. The last two are the point of the file: what a missed-window
/// policy governs is **windows after the last one on record**, which decides a
/// one-shot deadline's fate in a way that reads backwards until you see it.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'scheduling_support.dart';

import '../../sample_preamble.dart';

// =============================================================================
// A body that records the window it was given
// =============================================================================

/// Appends its window to a list the example owns.
class RecordInto extends TomCommand {
  final List<DateTime> into;
  final DateTime window;

  RecordInto(this.into, this.window);

  @override
  Future<Object?> execute() async {
    into.add(window);
    return null;
  }
}

TomScheduler _scheduler(
  TomJobStore store,
  FakeClock clock,
  List<TomJobAlert> alerts,
) => TomScheduler(
  store: store,
  dispatcher: const TomInlineJobDispatcher(),
  clock: clock.call,
  ownerId: 'node-a',
  tickJitter: 0,
  onAlert: alerts.add,
);

// =============================================================================
// EXAMPLE 1: What Each Kind Answers
// =============================================================================

/// The taxonomy, read straight off the schedules with no scheduler involved.
class ScheduleKindsExample {
  static DateTime? cronWindow;
  static DateTime? intervalWindow;
  static DateTime? calendarWindow;
  static DateTime? onceWindow;
  static DateTime? onceAgain;
  static DateTime? eventWindow;
  static bool eventIsClockDriven = true;

  static Future<void> example1WhatEachKindAnswers() async {
    final now = DateTime.utc(2026, 3, 2, 9, 30);

    // --- Clock-recurring: three spellings of the same behaviour -------------
    // 03:00 every day.
    cronWindow = TomCronSchedule('0 3 * * *').nextFireAfter(now);
    // Every 15 minutes on an absolute grid measured from the epoch, so the
    // windows are the same in every process and do not drift after an outage.
    intervalWindow = TomIntervalSchedule(
      const Duration(minutes: 15),
    ).nextFireAfter(now);
    // The month-relative rule cron cannot spell: the last day of the month at
    // 23:30.
    calendarWindow = TomCalendarSchedule.dayOfMonth(
      -1,
      hour: 23,
      minute: 30,
    ).nextFireAfter(now);

    // --- One-shot: a deadline, not a recurrence -----------------------------
    final deadline = TomOnceSchedule(DateTime.utc(2026, 3, 2, 12));
    onceWindow = deadline.nextFireAfter(now);
    // Asked at or after the instant, the answer is "never again" — strictly
    // after, like every other schedule. Offering the instant a second time is
    // how a deadline fires twice.
    onceAgain = deadline.nextFireAfter(DateTime.utc(2026, 3, 2, 12));

    // --- Event: not a clock at all ------------------------------------------
    final events = TomEventSchedule(const Stream<Object?>.empty());
    eventWindow = events.nextFireAfter(now);
    eventIsClockDriven = events.isClockDriven;

    assert(
      cronWindow == DateTime.utc(2026, 3, 3, 3),
      '09:30 is past today\'s 03:00, so the next one is tomorrow\'s',
    );
    assert(
      intervalWindow == DateTime.utc(2026, 3, 2, 9, 45),
      'The grid is absolute: 09:45, not "15 minutes from now"',
    );
    assert(
      calendarWindow == DateTime.utc(2026, 3, 31, 23, 30),
      'Negative days count back from the end of the month, which is the rule '
      'cron has no way to express',
    );
    assert(onceWindow == DateTime.utc(2026, 3, 2, 12), 'The deadline itself');
    assert(
      onceAgain == null,
      'And nothing after it — a one-shot schedule is exhausted by being reached',
    );
    assert(
      eventWindow == null && !eventIsClockDriven,
      'An event schedule never produces a window, and says so, so the '
      'scheduler subscribes to its source instead of polling it',
    );
  }
}

// =============================================================================
// EXAMPLE 2: An Event Job In Motion
// =============================================================================

/// What an event trigger does that a clock cannot: carry *what* happened.
///
/// It also has one rule with no clock-driven counterpart. A clock job's window
/// comes from its grid; an event job has no grid, so **the window is the instant
/// the event arrived**. Everything below follows from that single sentence,
/// including the case where an event does not produce a run at all.
class EventTriggerExample {
  static List<Object?> payloads = [];

  /// How many runs the three events produced, before any tick executed one.
  static int enqueued = 0;
  static int runCount = 0;
  static List<DateTime> windows = [];

  static Future<void> example2AnEventJobInMotion() async {
    final events = StreamController<Object?>();
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final store = TomMemoryJobStore();
    final scheduler = _scheduler(store, clock, []);

    payloads = [];
    scheduler.register(
      TomJobDefinition(
        name: 'on-invoice-issued',
        schedule: TomEventSchedule(events.stream, sourceName: 'invoices'),
        // The emitted element reaches the body as the run's payload, so the job
        // can act on the invoice rather than merely on the fact that one exists.
        body: (run) => _RecordPayload(payloads, run.payload),
      ),
    );

    events.add('invoice-42');
    await settle();

    // A second later — and the second matters. Under a real clock this line is
    // simply "time passed", because two events cannot arrive in the same
    // microsecond. Under a clock the example holds still, moving it is what
    // stops the two events from sharing a window.
    clock.advance(const Duration(seconds: 1));
    events.add('invoice-43');
    await settle();

    // A third event at the *same* instant as the second. It is discarded before
    // it reaches the store: the scheduler looks for an existing run in that
    // window first, and one window holds one run. That check is not fussiness
    // about duplicates — it is what makes an at-least-once *delivery* (a broker
    // that re-delivers, a reconnect that replays) safe to point at a job.
    events.add('invoice-44');
    await settle();

    enqueued = (await store.all()).length;

    // The subscription enqueued the runs; the tick dispatches what is due,
    // exactly as it does for a clock-driven job. Only the *source* of the
    // window differs.
    //
    // Two ticks, because this job takes the default `allowOverlap: false`: a
    // pass claims at most one run of a non-overlapping job, so a burst of
    // events drains one per pass rather than starting two bodies at once. That
    // is the same rule a clock-driven backlog obeys — example 3 leans on it.
    await scheduler.tick();
    await settle();
    await scheduler.tick();
    await settle();

    final runs = await store.all();
    runCount = runs.length;
    windows = runs.map((run) => run.scheduledFor).toList()..sort();

    scheduler.close();
    await events.close();

    assert(
      enqueued == 2,
      'Three events, two runs: the third shared a window with the second and '
      'was collapsed into it',
    );
    assert(runCount == 2, 'And a tick executes runs, it does not create them');
    assert(
      windows.first == DateTime.utc(2026, 3, 2, 9) &&
          windows.last == DateTime.utc(2026, 3, 2, 9, 0, 1),
      'An event run is dated when it arrived — there is no grid to round it to',
    );
    assert(
      payloads.toSet().length == 2 &&
          payloads.contains('invoice-42') &&
          payloads.contains('invoice-43'),
      'Each body received its own event — what happened, not merely that '
      'something did',
    );
  }
}

/// Records a run's payload.
class _RecordPayload extends TomCommand {
  final List<Object?> into;
  final Object? payload;

  _RecordPayload(this.into, this.payload);

  @override
  Future<Object?> execute() async {
    into.add(payload);
    return null;
  }
}

// =============================================================================
// EXAMPLE 3: What A Missed-Window Policy Actually Governs
// =============================================================================

/// A recurring job across an outage, under each of the three policies.
///
/// This has to come before the one-shot case, because the one-shot case only
/// reads correctly once you can see what the policy is measuring: the windows
/// **after the last one on record**. A window already written to the store is
/// not "missed" under any policy — it is simply late, and it runs.
class MissedWindowPolicyExample {
  static List<DateTime> skipRan = [];
  static List<DateTime> runOnceRan = [];
  static List<DateTime> runAllRan = [];

  /// Plans a window at 10:00, goes dark until 14:30, and comes back.
  static Future<List<DateTime>> _outageUnder(
    TomMissedWindowPolicy policy,
  ) async {
    final ran = <DateTime>[];
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final scheduler = _scheduler(TomMemoryJobStore(), clock, []);

    scheduler.register(
      TomJobDefinition(
        name: 'hourly-rollup',
        schedule: TomIntervalSchedule(const Duration(hours: 1)),
        body: (run) => RecordInto(ran, run.scheduledFor),
        missedWindowPolicy: policy,
      ),
    );

    // Before the outage: the 10:00 window is planned and written to the store.
    await scheduler.tick();
    await settle();

    // The outage. Nothing ran; the clock moved anyway.
    clock.advance(const Duration(hours: 5, minutes: 30));

    // Coming back at 14:30, then eight ordinary ticks a minute apart — still
    // well before the 15:00 window, so nothing new is due. Eight rather than
    // one because the job takes the default `allowOverlap: false`: a pass
    // claims at most one run of a non-overlapping job, so a replayed backlog
    // drains one window per pass instead of starting four bodies at once. The
    // loop is what "the scheduler catches up over the next few minutes" looks
    // like, compressed.
    for (var pass = 0; pass < 8; pass++) {
      await scheduler.tick();
      await settle();
      clock.advance(const Duration(minutes: 1));
    }

    scheduler.close();
    ran.sort();
    return ran;
  }

  static Future<void> example3WhatAPolicyGoverns() async {
    skipRan = await _outageUnder(TomMissedWindowPolicy.skip);
    runOnceRan = await _outageUnder(TomMissedWindowPolicy.runOnce);
    runAllRan = await _outageUnder(TomMissedWindowPolicy.runAll);

    assert(
      skipRan.length == 1 && skipRan.single == DateTime.utc(2026, 3, 2, 10),
      'skip dropped 11:00 through 14:00 — and did NOT drop 10:00, because '
      '10:00 was already a row in the store before the outage. That row is not '
      'a missed window, it is a late run, and no policy governs it',
    );
    assert(
      runOnceRan.length == 2 && runOnceRan.last == DateTime.utc(2026, 3, 2, 14),
      'runOnce replays only the most recent missed window: the 10:00 row plus '
      '14:00. The right default for a job that recomputes a current state, '
      'where running four times in a row would compute the same answer four '
      'times',
    );
    assert(
      runAllRan.length == 5 &&
          runAllRan.last == DateTime.utc(2026, 3, 2, 14) &&
          runAllRan.first == DateTime.utc(2026, 3, 2, 10),
      'runAll replays every missed window up to catchUpLimit — for a job whose '
      'windows each own a distinct slice of work, where skipping one loses that '
      'slice for good',
    );
  }
}

// =============================================================================
// EXAMPLE 4: A One-Shot Deadline Survives An Outage
// =============================================================================

/// The half readers expect to fail, and it does not.
///
/// The instinct is that `skip` will drop a deadline the process slept through.
/// It does not, because the deadline's window was written to the store the first
/// time the scheduler saw the job — the same 10:00 row example 3 just showed
/// surviving. A durable window is the whole reason to run a scheduler rather
/// than a `Timer`, and this is what that buys.
class OneShotSurvivesExample {
  static List<DateTime> ran = [];
  static List<TomJobAlertKind> alertKinds = [];
  static int storedRuns = 0;
  static int ranAfterMoreTicks = 0;

  static Future<void> example4AOneShotSurvivesAnOutage() async {
    ran = [];
    final alerts = <TomJobAlert>[];
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final store = TomMemoryJobStore();
    final scheduler = _scheduler(store, clock, alerts);

    scheduler.register(
      TomJobDefinition(
        name: 'grant-expiry',
        schedule: TomOnceSchedule(DateTime.utc(2026, 3, 2, 12)),
        body: (run) => RecordInto(ran, run.scheduledFor),
        // The most pessimistic policy available, chosen to show it changes
        // nothing here.
        missedWindowPolicy: TomMissedWindowPolicy.skip,
      ),
    );

    // 09:00: the deadline is three hours away, and is written down now.
    await scheduler.tick();
    await settle();

    // The process is down from before noon until 20:00.
    clock.advance(const Duration(hours: 11));
    await scheduler.tick();
    await settle();

    storedRuns = (await store.all()).length;
    alertKinds = alerts.map((alert) => alert.kind).toList();

    // Keep ticking. A deadline that fires twice is worse than one that fires
    // late, so this is the assertion that matters most.
    clock.advance(const Duration(days: 1));
    await scheduler.tick();
    await settle();
    ranAfterMoreTicks = ran.length;

    scheduler.close();

    assert(
      ran.length == 1 && ran.single == DateTime.utc(2026, 3, 2, 12),
      'It ran, eight hours late, dated to the deadline rather than to the '
      'recovery — which is why a body should work on run.scheduledFor and not '
      'on "now"',
    );
    assert(
      alertKinds.isEmpty,
      'And nothing was reported as missed: skip governs windows after the last '
      'one on record, and this window IS the record',
    );
    assert(storedRuns == 1, 'One window, one row, however late it ran');
    assert(
      ranAfterMoreTicks == 1,
      'Exhausted: the schedule has no window after its instant, so no later '
      'tick can produce a second firing',
    );
  }
}

// =============================================================================
// EXAMPLE 5: A One-Shot Deadline That Was Already Past
// =============================================================================

/// The half readers expect to work, and it cannot.
///
/// Same schedule, same policy question — but the scheduler never saw the job
/// until after its instant. There is no record to be late against, so there is
/// nothing for a missed-window policy to measure and no policy setting that
/// helps. What the kernel does instead is *say so*, once, because a job that can
/// never run looks exactly like a job that is merely not due yet.
class OneShotAlreadyPastExample {
  static List<DateTime> ran = [];
  static int storedRuns = 0;
  static List<TomJobAlertKind> alertKinds = [];
  static String? alertSchedule;
  static int alertsAfterMoreTicks = 0;

  static Future<void> example5AOneShotAlreadyPast() async {
    ran = [];
    final alerts = <TomJobAlert>[];
    // 20:00 — the deadline was at noon, and this scheduler is starting now.
    // A deadline restored at start-up after a long outage looks exactly like
    // this.
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 20));
    final store = TomMemoryJobStore();
    final scheduler = _scheduler(store, clock, alerts);

    scheduler.register(
      TomJobDefinition(
        name: 'grant-expiry',
        schedule: TomOnceSchedule(DateTime.utc(2026, 3, 2, 12)),
        body: (run) => RecordInto(ran, run.scheduledFor),
        // The most eager policy available, chosen to show it changes nothing
        // here either. The policy is not the lever; the record is.
        missedWindowPolicy: TomMissedWindowPolicy.runAll,
      ),
    );

    await scheduler.tick();
    await settle();

    storedRuns = (await store.all()).length;
    alertKinds = alerts.map((alert) => alert.kind).toList();
    alertSchedule = alerts.single.schedule?.describe();

    // The condition cannot resolve itself, so repeating the alert every tick
    // forever is how operators learn to filter a channel.
    clock.advance(const Duration(hours: 1));
    await scheduler.tick();
    await settle();
    alertsAfterMoreTicks = alerts.length;

    scheduler.close();

    assert(
      ran.isEmpty && storedRuns == 0,
      'Nothing was planned: the schedule has no window after "now", and '
      'anchoring on the present is what stops a newly registered daily job '
      'replaying every day since the epoch',
    );
    assert(
      alertKinds.single == TomJobAlertKind.neverFires,
      'The quiet misconfiguration, made loud — under runAll, the most eager '
      'policy there is',
    );
    assert(
      alertSchedule == 'once(2026-03-02T12:00:00.000Z)',
      'The alert carries the schedule, because "job X will never run" is only '
      'actionable next to the expression that cannot match',
    );
    assert(
      alertsAfterMoreTicks == 1,
      'Raised once per job per scheduler, not once per tick',
    );
  }
}

// =============================================================================
// EXAMPLE 6: A Cron Job In Motion
// =============================================================================

/// The schedule kind most readers arrive with, driven by the scheduler rather
/// than merely asked a question.
///
/// Example 1 read a window off `TomCronSchedule.nextFireAfter`. That shows the
/// expression parses; it does not show a cron job *running*, and the two are
/// worth separating because everything a cron job inherits — the durable
/// look-ahead row, the window handed to the body, the next window planned as the
/// current one completes — comes from the scheduler and not from the expression.
///
/// The second half is the cron rule that is got wrong more than any other, and
/// it lives here rather than in a doc note because it is only convincing as a
/// list of dates.
class CronInMotionExample {
  static List<DateTime> ran = [];
  static DateTime? nextPlanned;
  static List<int> orDays = [];
  static List<int> mondayDays = [];

  static Future<void> example6ACronJobInMotion() async {
    ran = [];
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 1));
    final store = TomMemoryJobStore();
    final scheduler = _scheduler(store, clock, []);

    scheduler.register(
      TomJobDefinition(
        name: 'nightly-vacuum',
        // 03:00 every day — the expression nine cron jobs in ten actually are.
        schedule: TomCronSchedule('0 3 * * *'),
        body: (run) => RecordInto(ran, run.scheduledFor),
      ),
    );

    // 01:00: nothing is due, but the 03:00 window is written down.
    await scheduler.tick();
    await settle();

    // Two nights, each reached by moving the clock rather than waiting for it.
    // Five minutes *past* the window on purpose: a tick is a poll, so it almost
    // never lands on a window exactly, and that gap is what makes the first
    // assertion below say something.
    clock.advance(const Duration(hours: 2, minutes: 5));
    await scheduler.tick();
    await settle();
    clock.advance(const Duration(hours: 24));
    await scheduler.tick();
    await settle();

    // Nullable, and read without a `single` that could throw: if the look-ahead
    // row were missing, the assertion below is what should say so.
    final pending = (await store.all())
        .where((run) => run.state == TomJobRunState.pending)
        .toList();
    nextPlanned = pending.length == 1 ? pending.single.scheduledFor : null;

    scheduler.close();

    // --- The day fields are OR'd, not AND'ed --------------------------------
    // Both day fields restricted means "day-of-month OR day-of-week", which is
    // POSIX and is the opposite of the intersection most readers expect. It is
    // only visible when *both* are restricted: the moment either is `*`, the
    // union collapses to the other one and the two readings agree, which is
    // exactly why the mistake survives so long in a codebase.
    orDays = _marchDaysOf('0 12 */2 3 MON', 12);
    mondayDays = _marchDaysOf('0 12 * 3 MON', 5);

    assert(
      ran.length == 2 &&
          ran.first == DateTime.utc(2026, 3, 2, 3) &&
          ran.last == DateTime.utc(2026, 3, 3, 3),
      'Two nights, each dated to its own 03:00 — the body is handed the window '
      'it was due for, not the instant the tick happened to reach it',
    );
    assert(
      nextPlanned == DateTime.utc(2026, 3, 4, 3),
      'And the third night is already a durable row before it is due. A cron '
      'job is not re-derived at fire time; it is planned ahead, which is what '
      'lets a restart between two nights still know what it owed',
    );
    assert(
      orDays.join(',') == '1,2,3,5,7,9,11,13,15,16,17,19',
      'Odd days OR Mondays: the 2nd and the 16th are in there for being '
      'Mondays, not for being odd. Under the intersection reading the list '
      'would be Mondays that are also odd — the 9th, and little else',
    );
    assert(
      mondayDays.join(',') == '2,9,16,23,30',
      'With day-of-month left as `*` there is nothing to union with, so the '
      'same job reads as plain "Mondays". This is the case that makes the rule '
      'easy to miss: it is the common one, and both readings agree on it',
    );
  }

  /// The first [take] days in March 2026 that [expression] fires on.
  static List<int> _marchDaysOf(String expression, int take) {
    final schedule = TomCronSchedule(expression);
    final days = <int>[];
    var at = DateTime.utc(2026, 3, 1);
    for (var i = 0; i < take; i++) {
      final next = schedule.nextFireAfter(at);
      if (next == null) break;
      days.add(next.day);
      at = next;
    }
    return days;
  }
}

// =============================================================================
// EXAMPLE 7: The Rule Cron Cannot Spell
// =============================================================================

/// `TomCalendarSchedule.weekdayOfMonth`, and the two things about an ordinal
/// that a sentence of prose keeps failing to settle.
///
/// Cron's day-of-week field can say "Friday". It cannot say "the *last* Friday",
/// because that is a fact about the month rather than about the day, and cron
/// fields do not see months. The calendar schedule exists for exactly the rules
/// that need that extra context — and its two sharp edges are both about the
/// ordinal:
///
/// - **`-1` is the last occurrence, not the fifth.** Most months have four of a
///   given weekday and some have five, so "last" and "5th" are different rules
///   that agree only occasionally.
/// - **An ordinal a month does not have simply does not fire** — the month is
///   skipped in silence, rather than clamping to the nearest occurrence.
class CalendarWeekdayExample {
  static List<DateTime> quarterlyFridays = [];
  static String? described;
  static List<DateTime> fifthMondays = [];
  static List<DateTime> lastMondays = [];

  static Future<void> example7TheRuleCronCannotSpell() async {
    // The last Friday of every third month at 18:00, anchored on March — a
    // quarterly close, spelled once.
    final quarterly = TomCalendarSchedule.weekdayOfMonth(
      weekday: DateTime.friday,
      ordinal: -1,
      hour: 18,
      monthInterval: 3,
      anchorMonth: 3,
    );
    described = quarterly.describe();

    quarterlyFridays = [];
    var at = DateTime.utc(2026, 3, 2, 9, 30);
    for (var i = 0; i < 4; i++) {
      at = quarterly.nextFireAfter(at)!;
      quarterlyFridays.add(at);
    }

    // The 5th Monday of every month — a rule that is unsatisfiable in most of
    // them.
    final fifthMonday = TomCalendarSchedule.weekdayOfMonth(
      weekday: DateTime.monday,
      ordinal: 5,
    );
    fifthMondays = [];
    var when = DateTime.utc(2026, 3, 1);
    for (var i = 0; i < 3; i++) {
      when = fifthMonday.nextFireAfter(when)!;
      fifthMondays.add(when);
    }

    // The same weekday under `-1`, walked over the same stretch of calendar, so
    // the two rules can be read side by side rather than described.
    final lastMonday = TomCalendarSchedule.weekdayOfMonth(
      weekday: DateTime.monday,
      ordinal: -1,
    );
    lastMondays = [];
    var each = DateTime.utc(2026, 3, 1);
    for (var i = 0; i < 3; i++) {
      each = lastMonday.nextFireAfter(each)!;
      lastMondays.add(each);
    }

    assert(
      quarterlyFridays.map((day) => day.toIso8601String()).join(' ') ==
          '2026-03-27T18:00:00.000Z 2026-06-26T18:00:00.000Z '
              '2026-09-25T18:00:00.000Z 2026-12-25T18:00:00.000Z',
      'March, June, September, December — the month cycle is measured on an '
      'absolute month index, so a quarterly schedule stays on its quarters '
      'across the year boundary instead of restarting every January',
    );
    assert(
      quarterlyFridays.every((day) => day.weekday == DateTime.friday),
      'And every one of them is a Friday, on four different days of the month: '
      'the 27th, 26th, 25th and 25th. No day-of-month rule could have produced '
      'that set, which is the whole reason this factory exists',
    );
    assert(
      described == 'calendar(last weekday 5, every 3 months, 18:00)',
      'Schedules describe themselves, which is what makes a neverFires alert '
      '(example 5) actionable',
    );
    assert(
      fifthMondays.map((day) => day.toIso8601String()).join(' ') ==
          '2026-03-30T00:00:00.000Z 2026-06-29T00:00:00.000Z '
              '2026-08-31T00:00:00.000Z',
      'April, May and July are skipped outright — they have four Mondays, and '
      'a 5th occurrence a month does not have does not fire. Note what this is '
      'NOT: it does not clamp to the 4th Monday. If you wanted the last one, '
      'ordinal -1 is the rule that says so, and it fires every month',
    );
    assert(
      lastMondays.map((day) => day.toIso8601String()).join(' ') ==
          '2026-03-30T00:00:00.000Z 2026-04-27T00:00:00.000Z '
              '2026-05-25T00:00:00.000Z',
      'Which is what -1 does: three consecutive months, no gaps. It coincides '
      'with the 5th Monday in March — the one month here that has five — and '
      'diverges in April and May. Two rules that agree on the months you '
      'happen to test are still two rules',
    );
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

Future<void> run() async {
  print('=== 03: Schedule Kinds Example ===\n');

  await ScheduleKindsExample.example1WhatEachKindAnswers();
  print('1. The next window each kind of schedule answers with, at 09:30:');
  print('   cron 0 3 * * *    : ${ScheduleKindsExample.cronWindow}');
  print('   interval 15 min   : ${ScheduleKindsExample.intervalWindow}');
  print('   calendar last day : ${ScheduleKindsExample.calendarWindow}');
  print('   once (deadline)   : ${ScheduleKindsExample.onceWindow}');
  print('   once, asked again : ${ScheduleKindsExample.onceAgain}');
  print('   event             : ${ScheduleKindsExample.eventWindow}');
  print('   event clock-driven: ${ScheduleKindsExample.eventIsClockDriven}');
  print('');

  await EventTriggerExample.example2AnEventJobInMotion();
  print('2. An event job in motion — the arrival instant is the window:');
  print('   runs enqueued by 3 events : ${EventTriggerExample.enqueued}');
  print('   runs after two ticks      : ${EventTriggerExample.runCount}');
  print('   windows                   : ${EventTriggerExample.windows}');
  print('   payloads the bodies saw   : ${EventTriggerExample.payloads}');
  print('');

  await MissedWindowPolicyExample.example3WhatAPolicyGoverns();
  print('3. What a missed-window policy governs, across an outage:');
  print('   (each replays the 10:00 row planned before the outage)');
  print(
    '   skip    : ${MissedWindowPolicyExample.skipRan.length} ran, '
    'last ${MissedWindowPolicyExample.skipRan.last}',
  );
  print(
    '   runOnce : ${MissedWindowPolicyExample.runOnceRan.length} ran, '
    'last ${MissedWindowPolicyExample.runOnceRan.last}',
  );
  print(
    '   runAll  : ${MissedWindowPolicyExample.runAllRan.length} ran, '
    'last ${MissedWindowPolicyExample.runAllRan.last}',
  );
  print('');

  await OneShotSurvivesExample.example4AOneShotSurvivesAnOutage();
  print('4. A one-shot deadline slept through, under skip:');
  print('   windows that ran  : ${OneShotSurvivesExample.ran}');
  print('   rows in the store : ${OneShotSurvivesExample.storedRuns}');
  print('   alerts raised     : ${OneShotSurvivesExample.alertKinds.length}');
  print('   runs a day later  : ${OneShotSurvivesExample.ranAfterMoreTicks}');
  print('');

  await OneShotAlreadyPastExample.example5AOneShotAlreadyPast();
  print('5. A one-shot deadline that was already past when registered:');
  print('   windows that ran : ${OneShotAlreadyPastExample.ran.length}');
  print('   rows planned     : ${OneShotAlreadyPastExample.storedRuns}');
  print('   alerts           : ${OneShotAlreadyPastExample.alertKinds}');
  print('   alert schedule   : ${OneShotAlreadyPastExample.alertSchedule}');
  print(
    '   alerts after another tick : '
    '${OneShotAlreadyPastExample.alertsAfterMoreTicks}',
  );
  print('');

  await CronInMotionExample.example6ACronJobInMotion();
  print('6. A cron job in motion, and the OR-ed day fields:');
  print('   nights that ran     : ${CronInMotionExample.ran}');
  print('   next window planned : ${CronInMotionExample.nextPlanned}');
  print('   0 12 */2 3 MON      : March days ${CronInMotionExample.orDays}');
  print(
    '   0 12 * 3 MON        : March days ${CronInMotionExample.mondayDays}',
  );
  print('');

  await CalendarWeekdayExample.example7TheRuleCronCannotSpell();
  print('7. The rule cron cannot spell:');
  print('   quarterly rule    : ${CalendarWeekdayExample.described}');
  print('   last Fridays      : ${CalendarWeekdayExample.quarterlyFridays}');
  print('   5th Mondays       : ${CalendarWeekdayExample.fifthMondays}');
  print('   last Mondays      : ${CalendarWeekdayExample.lastMondays}');
  print('');
}

Future<void> main() {
  prepareSampleProcess();
  return run();
}

/// Tests for reflection-discovered scheduled jobs.
///
/// Discovery reads a *global* registry — every class in this suite's reflection
/// build — so a negative case cannot simply be declared and scanned: one
/// malformed class would fail every other test's scan. Each test therefore
/// narrows the scan with `where:`, which is the same seam an application uses
/// to run different jobs per profile.
///
/// The end-to-end tests drive [TomScheduler.tick] against an injected clock,
/// exactly as `scheduling_test.dart` does, so nothing here waits on wall time.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'contracts/scheduling_contract.dart';
import 'scheduled_job_test.reflection.dart';

// =============================================================================
// Job classes under test
// =============================================================================

/// Records every execution of every job in this suite, keyed by job name.
///
/// A discovered body is built by the framework, so a test cannot hold a
/// reference to the instance it will run — it has to observe from the outside.
final Map<String, List<TomJobRun?>> executions = {};

void _record(String job, TomJobRun? run) => (executions[job] ??= []).add(run);

@tomReflector
@TomScheduledJob(cron: '0 3 * * *')
class NightlyReconciliation extends TomJobBase {
  @override
  Future<Object?> execute() async {
    _record('NightlyReconciliation', run);
    return 'reconciled';
  }
}

@tomReflector
@TomScheduledJob(
  name: 'legacy-cleanup',
  interval: Duration(minutes: 15),
  retry: TomRetryPolicy(maxAttempts: 5),
  timeout: Duration(seconds: 30),
  missedWindow: TomMissedWindowPolicy.skip,
  catchUpLimit: 3,
  allowOverlap: true,
)
class RenamedCleanup extends TomJobBase {
  @override
  Future<Object?> execute() async {
    _record('legacy-cleanup', run);
    return 'cleaned';
  }
}

@tomReflector
@TomScheduledJob(calendar: 'day:-1 at:23:30')
class MonthEndClose extends TomJobBase {
  @override
  Future<Object?> execute() async => 'closed';
}

@tomReflector
@TomScheduledJob(calendar: 'weekday:2/tue at:09:00 every:3 from:2')
class QuarterlyReview extends TomJobBase {
  @override
  Future<Object?> execute() async => 'reviewed';
}

@tomReflector
@TomScheduledJob(event: true)
class OnInvoiceIssued extends TomJobBase {
  @override
  Future<Object?> execute() async {
    _record('OnInvoiceIssued', run);
    return run.payload;
  }
}

/// A plain [TomCommand] — accepted, but with no access to its run.
@tomReflector
@TomScheduledJob(cron: '@hourly')
class PlainCommandJob extends TomCommand {
  @override
  Future<Object?> execute() async {
    _record('PlainCommandJob', null);
    return 'plain';
  }
}

/// Reflected but not annotated as a job: discovery must ignore it.
@tomReflector
class NotAJob extends TomJobBase {
  @override
  Future<Object?> execute() async => 'never';
}

// --- Malformed declarations, each reached only through `where:` -------------

@tomReflector
@TomScheduledJob()
class NoTriggerJob extends TomJobBase {
  @override
  Future<Object?> execute() async => null;
}

@tomReflector
@TomScheduledJob(cron: '@daily', interval: Duration(minutes: 1))
class TwoTriggerJob extends TomJobBase {
  @override
  Future<Object?> execute() async => null;
}

@tomReflector
@TomScheduledJob(cron: 'not a cron expression')
class BadCronJob extends TomJobBase {
  @override
  Future<Object?> execute() async => null;
}

@tomReflector
@TomScheduledJob(calendar: 'day:99')
class BadCalendarJob extends TomJobBase {
  @override
  Future<Object?> execute() async => null;
}

@tomReflector
@TomScheduledJob(calendar: 'sometime soon')
class UnparseableCalendarJob extends TomJobBase {
  @override
  Future<Object?> execute() async => null;
}

@tomReflector
@TomScheduledJob(cron: '@daily')
class NotACommandJob {
  NotACommandJob();
}

@tomReflector
@TomScheduledJob(cron: '@daily')
class NeedsCollaboratorsJob extends TomJobBase {
  final String dependency;

  NeedsCollaboratorsJob(this.dependency);

  @override
  Future<Object?> execute() async => dependency;
}

@tomReflector
@TomScheduledJob(cron: '@daily', catchUpLimit: 0)
class BadPolicyJob extends TomJobBase {
  @override
  Future<Object?> execute() async => null;
}

@tomReflector
@TomScheduledJob(event: true)
class UnsourcedEventJob extends TomJobBase {
  @override
  Future<Object?> execute() async => null;
}

// The next two are scanned by `scheduling_error_keys_test.dart`, which pins the
// key each one is refused under. They live here because a scan reads this
// suite's reflection build, and a class outside it is invisible to discovery.

@tomReflector
@TomScheduledJob(name: '   ', cron: '@daily')
class BlankNameJob extends TomJobBase {
  @override
  Future<Object?> execute() async => null;
}

@tomReflector
@TomScheduledJob(interval: Duration.zero)
class ZeroIntervalJob extends TomJobBase {
  @override
  Future<Object?> execute() async => null;
}

@tomReflector
@TomScheduledJob(name: 'collides', cron: '@daily')
class FirstColliding extends TomJobBase {
  @override
  Future<Object?> execute() async => null;
}

@tomReflector
@TomScheduledJob(name: 'collides', cron: '@hourly')
class SecondColliding extends TomJobBase {
  @override
  Future<Object?> execute() async => null;
}

// =============================================================================
// Helpers
// =============================================================================

/// Restricts a scan to the named classes.
bool Function(ClassMirror) only(Set<String> names) =>
    (candidate) => names.contains(candidate.simpleName);

/// The well-formed job classes, which several tests scan as a group.
const Set<String> wellFormed = {
  'NightlyReconciliation',
  'RenamedCleanup',
  'MonthEndClose',
  'QuarterlyReview',
  'PlainCommandJob',
};

/// The job *names* [wellFormed] resolves to — not the same set, because one of
/// them pins an explicit name.
const List<String> wellFormedNames = [
  'NightlyReconciliation',
  'legacy-cleanup',
  'MonthEndClose',
  'QuarterlyReview',
  'PlainCommandJob',
];

/// A clock parked well away from any of the suite's fire times.
FakeClock idleClock() => FakeClock(DateTime.utc(2026, 3, 1, 1));

TomScheduler schedulerOver(TomJobStore store, FakeClock clock) => TomScheduler(
  store: store,
  dispatcher: const TomInlineJobDispatcher(),
  clock: clock.call,
  ownerId: 'discovery-test',
);

void main() {
  setUpAll(initializeReflection);
  setUp(executions.clear);

  // ===========================================================================
  group('discovery', () {
    // =========================================================================
    test('finds the annotated classes, and only those', () {
      final names = TomScheduledJobs.discover(
        where: only({...wellFormed, 'NotAJob'}),
      ).map((job) => job.name).toSet();

      expect(names, wellFormedNames.toSet());
      // Reflected, a perfectly good TomJobBase — and not a job, because
      // nothing declared it one.
      expect(names, isNot(contains('NotAJob')));
    });

    test('the job name defaults to the class name', () {
      final job = TomScheduledJobs.discover(
        where: only({'NightlyReconciliation'}),
      ).single;
      expect(job.name, 'NightlyReconciliation');
    });

    test('an explicit name overrides the class name', () {
      // The name is the store key, so a class rename must be able to keep the
      // old identity rather than orphan the job's history.
      final job = TomScheduledJobs.discover(
        where: only({'RenamedCleanup'}),
      ).single;
      expect(job.name, 'legacy-cleanup');
    });

    test('every policy field reaches the definition', () {
      final job = TomScheduledJobs.discover(
        where: only({'RenamedCleanup'}),
      ).single;

      expect(job.retryPolicy.maxAttempts, 5);
      expect(job.timeout, const Duration(seconds: 30));
      expect(job.missedWindowPolicy, TomMissedWindowPolicy.skip);
      expect(job.catchUpLimit, 3);
      expect(job.allowOverlap, isTrue);
    });

    test('each trigger field builds its own schedule kind', () {
      TomSchedule scheduleOf(String className) =>
          TomScheduledJobs.discover(where: only({className})).single.schedule;

      expect(scheduleOf('NightlyReconciliation'), isA<TomCronSchedule>());
      expect(scheduleOf('RenamedCleanup'), isA<TomIntervalSchedule>());
      expect(scheduleOf('MonthEndClose'), isA<TomCalendarSchedule>());
      expect(
        TomScheduledJobs.discover(
          where: only({'OnInvoiceIssued'}),
          eventSource: (_) => const Stream<Object?>.empty(),
        ).single.schedule,
        isA<TomEventSchedule>(),
      );
    });

    test('the body is a factory: a fresh instance per run', () {
      final job = TomScheduledJobs.discover(
        where: only({'NightlyReconciliation'}),
      ).single;
      final run = TomJobRun(
        id: 'r1',
        jobName: job.name,
        scheduledFor: DateTime.utc(2026, 3, 1, 3),
        runAt: DateTime.utc(2026, 3, 1, 3),
      );

      expect(job.body(run), isNot(same(job.body(run))));
    });

    test('a TomJobBase body is handed its run', () async {
      final job = TomScheduledJobs.discover(
        where: only({'NightlyReconciliation'}),
      ).single;
      final run = TomJobRun(
        id: 'r1',
        jobName: job.name,
        scheduledFor: DateTime.utc(2026, 3, 1, 3),
        runAt: DateTime.utc(2026, 3, 1, 3),
      );

      await job.body(run).execute();
      expect(executions['NightlyReconciliation']!.single, same(run));
    });
  });

  // ===========================================================================
  group('calendar expressions', () {
    // =========================================================================
    test('day-of-month, counted from the end, at a time of day', () {
      final schedule = TomScheduledJobs.discover(
        where: only({'MonthEndClose'}),
      ).single.schedule;

      expect(
        schedule.nextFireAfter(DateTime.utc(2026, 3, 1)),
        DateTime.utc(2026, 3, 31, 23, 30),
      );
    });

    test('ordinal weekday, with a month interval and an anchor', () {
      final schedule = TomScheduledJobs.discover(
        where: only({'QuarterlyReview'}),
      ).single.schedule;

      // Anchored on February, every third month: February, May, August,
      // November. The second Tuesday of February 2026 is the 10th.
      expect(
        schedule.nextFireAfter(DateTime.utc(2026)),
        DateTime.utc(2026, 2, 10, 9),
      );
    });
  });

  // ===========================================================================
  group('scan-time validation', () {
    // =========================================================================
    /// Asserts that scanning [className] fails with [key].
    ///
    /// Also asserts the class is named in the message: a start-up failure that
    /// does not say which declaration is wrong is barely better than one that
    /// happens at 03:00.
    void expectScanFailure(String className, String key) {
      expect(
        () => TomScheduledJobs.discover(where: only({className})),
        throwsA(
          isA<TomScheduledJobException>()
              .having((e) => e.key, 'key', key)
              .having(
                (e) => e.defaultUserMessage,
                'message',
                contains(className),
              ),
        ),
      );
    }

    test(
      'no trigger at all',
      () => expectScanFailure('NoTriggerJob', 'scheduled_job.no_schedule'),
    );

    test(
      'two triggers',
      () => expectScanFailure(
        'TwoTriggerJob',
        'scheduled_job.multiple_schedules',
      ),
    );

    test(
      'an unparseable cron expression',
      () => expectScanFailure('BadCronJob', 'scheduled_job.invalid_cron'),
    );

    test(
      'a calendar expression with an impossible value',
      () =>
          expectScanFailure('BadCalendarJob', 'scheduled_job.invalid_calendar'),
    );

    test(
      'a calendar expression that is not an expression',
      () => expectScanFailure(
        'UnparseableCalendarJob',
        'scheduled_job.invalid_calendar',
      ),
    );

    test(
      'a class that is not a TomCommand',
      () => expectScanFailure('NotACommandJob', 'scheduled_job.not_a_command'),
    );

    test(
      'a class with no no-argument constructor',
      () => expectScanFailure(
        'NeedsCollaboratorsJob',
        'scheduled_job.not_constructible',
      ),
    );

    test(
      'an out-of-range policy',
      () => expectScanFailure('BadPolicyJob', 'scheduled_job.invalid_policy'),
    );

    test(
      'an event job with no source',
      () => expectScanFailure(
        'UnsourcedEventJob',
        'scheduled_job.no_event_source',
      ),
    );

    test('two classes claiming one job name', () {
      expect(
        () => TomScheduledJobs.discover(
          where: only({'FirstColliding', 'SecondColliding'}),
        ),
        throwsA(
          isA<TomScheduledJobException>()
              .having((e) => e.key, 'key', 'scheduled_job.duplicate_name')
              // Both names, because the operator has to find *two* declarations
              // to delete one of them, and the scan has aborted — this message
              // is all they get. Naming only the second leaves them grepping
              // for the job name across the codebase to find the first.
              .having(
                (e) => e.defaultUserMessage,
                'message',
                allOf(
                  contains('FirstColliding'),
                  contains('SecondColliding'),
                  isNot(contains('TomJobDefinition')),
                ),
              )
              .having(
                (e) => e.parameters?['classes'],
                'classes',
                containsAll(['FirstColliding', 'SecondColliding']),
              ),
        ),
      );
    });

    test('a failing scan registers nothing', () {
      final scheduler = schedulerOver(TomMemoryJobStore(), idleClock());
      addTearDown(scheduler.close);

      expect(
        () => TomScheduledJobs.registerAll(
          scheduler,
          where: only({'NightlyReconciliation', 'BadCronJob'}),
        ),
        throwsA(isA<TomScheduledJobException>()),
      );
      // Half-registered start-up is the failure mode this avoids: the good job
      // in the same scan must not be live while the bad one is unreported.
      expect(scheduler.jobs, isEmpty);
    });
  });

  // ===========================================================================
  group('registration', () {
    // =========================================================================
    test('registerAll puts every discovered job on the scheduler', () {
      final scheduler = schedulerOver(TomMemoryJobStore(), idleClock());
      addTearDown(scheduler.close);

      TomScheduledJobs.registerAll(scheduler, where: only(wellFormed));

      expect(scheduler.jobs.keys, unorderedEquals(wellFormedNames));
    });

    test('a hand-written definition and a discovered one coexist', () async {
      final store = TomMemoryJobStore();
      final clock = FakeClock(DateTime.utc(2026, 3, 1, 2, 59));
      final scheduler = schedulerOver(store, clock);
      addTearDown(scheduler.close);

      // The escape hatch: a schedule computed at start-up, which no annotation
      // could carry.
      final handWritten = TomJobDefinition(
        name: 'configured',
        schedule: TomIntervalSchedule(const Duration(hours: 1)),
        body: (run) => _InlineCommand(() => _record('configured', run)),
      );
      scheduler.register(handWritten);
      TomScheduledJobs.registerAll(
        scheduler,
        where: only({'NightlyReconciliation'}),
      );

      expect(
        scheduler.jobs.keys,
        containsAll(<String>['configured', 'NightlyReconciliation']),
      );

      await scheduler.tick();
      clock.advance(const Duration(hours: 2));
      await scheduler.tick();
      await pumpEventQueue();

      expect(executions['configured'], isNotEmpty);
      expect(executions['NightlyReconciliation'], isNotEmpty);
    });

    test('a discovered job may not silently replace a registered one', () {
      final scheduler = schedulerOver(TomMemoryJobStore(), idleClock());
      addTearDown(scheduler.close);

      scheduler.register(
        TomJobDefinition(
          name: 'NightlyReconciliation',
          schedule: TomIntervalSchedule(const Duration(hours: 1)),
          body: (run) => _InlineCommand(() {}),
        ),
      );

      expect(
        () => TomScheduledJobs.registerAll(
          scheduler,
          where: only({'NightlyReconciliation'}),
        ),
        throwsA(
          isA<TomScheduledJobException>().having(
            (e) => e.key,
            'key',
            'scheduled_job.name_already_registered',
          ),
        ),
      );
    });
  });

  // ===========================================================================
  group('end to end', () {
    // =========================================================================
    test('a discovered job runs with no start-up wiring', () async {
      final store = TomMemoryJobStore();
      final clock = FakeClock(DateTime.utc(2026, 3, 1, 2, 59));
      final scheduler = schedulerOver(store, clock);
      addTearDown(scheduler.close);

      TomScheduledJobs.registerAll(
        scheduler,
        where: only({'NightlyReconciliation'}),
      );

      await scheduler.tick();
      expect(executions['NightlyReconciliation'], isNull);

      clock.advance(const Duration(minutes: 2));
      await scheduler.tick();
      await pumpEventQueue();

      final runs = executions['NightlyReconciliation']!;
      expect(runs, hasLength(1));
      // The body knew its window without anyone passing it in.
      expect(runs.single!.scheduledFor, DateTime.utc(2026, 3, 1, 3));
      expect(
        (await store.all())
            .where((run) => run.state == TomJobRunState.succeeded)
            .map((run) => run.jobName),
        ['NightlyReconciliation'],
      );
    });

    test('a plain TomCommand job runs too', () async {
      final clock = FakeClock(DateTime.utc(2026, 3, 1, 0, 59));
      final scheduler = schedulerOver(TomMemoryJobStore(), clock);
      addTearDown(scheduler.close);

      TomScheduledJobs.registerAll(scheduler, where: only({'PlainCommandJob'}));

      await scheduler.tick();
      clock.advance(const Duration(minutes: 2));
      await scheduler.tick();
      await pumpEventQueue();

      expect(executions['PlainCommandJob'], hasLength(1));
    });

    test(
      'an event job runs once per emitted event, carrying its payload',
      () async {
        final events = StreamController<Object?>();
        addTearDown(events.close);
        final clock = FakeClock(DateTime.utc(2026, 3, 1));
        final scheduler = schedulerOver(TomMemoryJobStore(), clock);
        addTearDown(scheduler.close);

        TomScheduledJobs.registerAll(
          scheduler,
          where: only({'OnInvoiceIssued'}),
          eventSource: (name) =>
              name == 'OnInvoiceIssued' ? events.stream : null,
        );

        events.add('invoice-42');
        await pumpEventQueue();
        await scheduler.tick();
        await pumpEventQueue();

        final runs = executions['OnInvoiceIssued']!;
        expect(runs, hasLength(1));
        expect(runs.single!.payload, 'invoice-42');
      },
    );
  });
}

/// Runs a callback supplied by the test, for the hand-written definitions.
class _InlineCommand extends TomCommand {
  final void Function() action;

  _InlineCommand(this.action);

  @override
  Future<Object?> execute() async {
    action();
    return 'done';
  }
}

/// Pins the error key of every scheduling refusal that was otherwise asserted
/// only by exception type, or not at all.
///
/// A [TomScheduleException] or [TomScheduledJobException] carries its key so a
/// caller can branch on *which* refusal it got, and so a log line can be looked
/// up. A test that only checks the exception type passes just as well when the
/// key is misspelled, renamed or raised from the wrong branch — so a key no
/// test names is a failure mode nobody checks. Each case here drives the
/// smallest real input that reaches one raise and asserts the exact literal.
///
/// The behaviour around each refusal (why the value is refused, what the
/// message says) is tested in `scheduling_test.dart` and
/// `scheduled_job_test.dart`; this file only pins the vocabulary.
///
/// The discovery cases scan classes declared in `scheduled_job_test.dart`,
/// because discovery reads that suite's reflection build. Each scan is narrowed
/// with `where:` to the one malformed class, as that suite does, so the other
/// fixtures in the build cannot fail it first.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'scheduled_job_test.reflection.dart';

/// A command that is never run: the definitions below are refused first.
class _NeverRun extends TomCommand {
  @override
  Future<Object?> execute() async => null;
}

/// Matches a [TomException] whose key is exactly [key].
Matcher _throwsKey(String key) =>
    throwsA(isA<TomException>().having((e) => e.key, 'key', key));

/// A scheduler over an empty in-memory store with every limit left at its
/// default except those the caller overrides.
TomScheduler _scheduler({
  Duration tickInterval = const Duration(seconds: 30),
  Duration leaseTimeout = const Duration(minutes: 15),
  Duration leaseTtl = const Duration(minutes: 1),
  Duration? leaseRenewInterval,
  int maxRunsPerTick = 16,
  int maxCatchUpPerTick = 20,
  double tickJitter = 0,
}) => TomScheduler(
  store: TomMemoryJobStore(),
  dispatcher: const TomInlineJobDispatcher(),
  ownerId: 'error-keys',
  tickInterval: tickInterval,
  leaseTimeout: leaseTimeout,
  leaseTtl: leaseTtl,
  leaseRenewInterval: leaseRenewInterval,
  maxRunsPerTick: maxRunsPerTick,
  maxCatchUpPerTick: maxCatchUpPerTick,
  tickJitter: tickJitter,
);

void main() {
  setUpAll(initializeReflection);

  group('TomCronSchedule', () {
    final cases = <String, String>{
      'schedule.cron.empty': '   ',
      'schedule.cron.field_count': '0 3 * *',
      'schedule.cron.invalid_field': 'x * * * *',
    };
    cases.forEach((key, expression) {
      test('"$expression" is refused under $key', () {
        expect(() => TomCronSchedule(expression), _throwsKey(key));
      });
    });
  });

  group('TomCalendarSchedule', () {
    final cases = <String, TomCalendarSchedule Function()>{
      'schedule.calendar.day_of_month': () => TomCalendarSchedule.dayOfMonth(0),
      'schedule.calendar.weekday': () =>
          TomCalendarSchedule.weekdayOfMonth(weekday: 0, ordinal: 1),
      'schedule.calendar.ordinal': () => TomCalendarSchedule.weekdayOfMonth(
        weekday: DateTime.monday,
        ordinal: 6,
      ),
      'schedule.calendar.month_interval': () =>
          TomCalendarSchedule.dayOfMonth(1, monthInterval: 0),
      'schedule.calendar.anchor_month': () =>
          TomCalendarSchedule.dayOfMonth(1, anchorMonth: 13),
      'schedule.calendar.hour': () =>
          TomCalendarSchedule.dayOfMonth(1, hour: 24),
      'schedule.calendar.minute': () =>
          TomCalendarSchedule.dayOfMonth(1, minute: 60),
    };
    cases.forEach((key, build) {
      test('refused under $key', () => expect(build, _throwsKey(key)));
    });
  });

  test('a zero-length interval is refused under schedule.interval.period', () {
    expect(
      () => TomIntervalSchedule(Duration.zero),
      _throwsKey('schedule.interval.period'),
    );
  });

  group('TomJobDefinition', () {
    TomJobDefinition define({
      String name = 'job',
      int catchUpLimit = 1,
      Duration timeout = const Duration(minutes: 1),
    }) => TomJobDefinition(
      name: name,
      schedule: TomCronSchedule('@daily'),
      body: (_) => _NeverRun(),
      catchUpLimit: catchUpLimit,
      timeout: timeout,
    );

    final cases = <String, TomJobDefinition Function()>{
      'schedule.job.unnamed': () => define(name: '  '),
      'schedule.job.catch_up_limit': () => define(catchUpLimit: 0),
      'schedule.job.timeout': () => define(timeout: Duration.zero),
    };
    cases.forEach((key, build) {
      test('refused under $key', () => expect(build, _throwsKey(key)));
    });
  });

  test(
    'a payload that is not JSON-encodable is refused under schedule.job.payload',
    () async {
      final at = DateTime.utc(2026, 3, 1);
      await expectLater(
        TomMemoryJobStore().enqueue(
          TomJobRun(
            id: 'run',
            jobName: 'job',
            scheduledFor: at,
            runAt: at,
            payload: DateTime.utc(2026),
          ),
        ),
        _throwsKey('schedule.job.payload'),
      );
    },
  );

  test(
    'an empty lease resource is refused under schedule.lease.unnamed_resource',
    () async {
      final dir = Directory.systemTemp.createTempSync('tom_error_keys_lease_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final lock = TomFileLeaseLock('${dir.path}/leases');
      await expectLater(
        lock.acquire('', 'owner', const Duration(minutes: 1)),
        _throwsKey('schedule.lease.unnamed_resource'),
      );
    },
  );

  group('TomScheduler', () {
    final cases = <String, TomScheduler Function()>{
      'schedule.scheduler.tick_interval': () =>
          _scheduler(tickInterval: Duration.zero),
      'schedule.scheduler.lease_timeout': () =>
          _scheduler(leaseTimeout: Duration.zero),
      'schedule.scheduler.lease_ttl': () => _scheduler(leaseTtl: Duration.zero),
      // Equal to the TTL: a lease would lapse before its first renewal.
      'schedule.scheduler.renew_interval': () =>
          _scheduler(leaseRenewInterval: const Duration(minutes: 1)),
      // The default renewal interval is a third of the one-minute TTL, so a
      // ten-second lease timeout is shorter than one renewal.
      'schedule.scheduler.lease_timeout_renewal': () =>
          _scheduler(leaseTimeout: const Duration(seconds: 10)),
      'schedule.scheduler.runs_per_tick': () => _scheduler(maxRunsPerTick: 0),
      'schedule.scheduler.catch_up_per_tick': () =>
          _scheduler(maxCatchUpPerTick: 0),
      'schedule.scheduler.tick_jitter': () => _scheduler(tickJitter: 1),
    };
    cases.forEach((key, build) {
      test('refused under $key', () => expect(build, _throwsKey(key)));
    });

    test(
      'a closed scheduler refuses work under schedule.scheduler.closed',
      () async {
        final scheduler = _scheduler();
        await scheduler.close();
        expect(
          () => scheduler.register(
            TomJobDefinition(
              name: 'job',
              schedule: TomCronSchedule('@daily'),
              body: (_) => _NeverRun(),
            ),
          ),
          _throwsKey('schedule.scheduler.closed'),
        );
      },
    );
  });

  group('TomJobStore', () {
    test('a checkpoint that is not JSON-encodable is refused under '
        'schedule.job.checkpoint', () {
      final run = TomJobRun(
        id: 'r',
        jobName: 'job',
        scheduledFor: DateTime.utc(2026),
        runAt: DateTime.utc(2026),
      );
      expect(
        () => TomJobStore.encodeCheckpoint(run, {'at': DateTime.utc(2026)}),
        _throwsKey('schedule.job.checkpoint'),
      );
    });
  });

  group('TomJobRunContext', () {
    test('require outside a job body is refused under '
        'schedule.run_context.missing', () {
      expect(
        TomJobRunContext.require,
        _throwsKey('schedule.run_context.missing'),
      );
    });
  });

  group('TomScheduledJobs.discover', () {
    bool Function(ClassMirror) only(String className) =>
        (candidate) => candidate.simpleName == className;

    final cases = <String, String>{
      'scheduled_job.unnamed': 'BlankNameJob',
      'scheduled_job.invalid_interval': 'ZeroIntervalJob',
    };
    cases.forEach((key, className) {
      test('$className is refused under $key', () {
        expect(
          () => TomScheduledJobs.discover(where: only(className)),
          throwsA(
            isA<TomScheduledJobException>().having((e) => e.key, 'key', key),
          ),
        );
      });
    });
  });
}

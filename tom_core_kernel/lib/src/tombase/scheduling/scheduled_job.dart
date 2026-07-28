/// Declarative jobs — a class annotated with [TomScheduledJob] *is* its own
/// registration.
///
/// Without this library a job is declared twice: once as the class that does
/// the work, and once as a hand-written [TomJobDefinition] at start-up that
/// wires a closure to a name, a schedule and a set of policies. Nothing relates
/// the two. A job class can exist and never be registered; a registration can
/// out-live the class it names; and a rename silently breaks the pairing,
/// because the only thing joining them is a string a human typed twice.
///
/// Here the class carries its own schedule:
///
/// ```dart
/// @tomReflector
/// @TomScheduledJob(cron: '0 3 * * *')
/// class NightlyReconciliation extends TomJobBase {
///   @override
///   Future<Object?> execute() async { /* ... */ }
/// }
/// ```
///
/// and start-up becomes one line:
///
/// ```dart
/// TomScheduledJobs.registerAll(scheduler);
/// ```
///
/// ## Why reflection is the right answer *here*
///
/// The kernel deliberately does **not** discover file-storage backends by
/// annotation (see `blob_store_registry.dart`): a backend is routinely the
/// deployment's own, its factory is a closure precisely so it can capture a
/// configured HTTP client or credential provider, and an annotation would put a
/// codegen step in front of a one-line registration.
///
/// None of those three apply to a job. A job is application code that is
/// already inside the application's own reflection build; its settings are
/// literals — a cron string, a retry count, a timeout — that an annotation
/// expresses natively; and it needs no captured collaborators, because the body
/// is built fresh per run and can resolve what it needs from the bean locator
/// (see [TomJobBase]). The closure in [TomJobDefinition.body] exists only to
/// make the body *per-run*, and `newInstance('', [])` per run does that.
///
/// ## Everything is checked at scan time
///
/// This is the whole robustness claim. Quartz stores a job's class as a
/// **string** (`QRTZ_JOB_DETAILS.JOB_CLASS_NAME`) and resolves it at fire time:
/// a rename parks the trigger in `ERROR` permanently, and cluster recovery
/// silently skips a firing whose class no longer resolves. A reflected class is
/// present at compile time — the class *is* the registration, so a rename is
/// just a rename — and every remaining way to get a declaration wrong is
/// reported by [TomScheduledJobs.discover] at start-up, naming the offending
/// class, rather than at 03:00 into a log nobody reads.
///
/// ## Discovery produces definitions; it does not replace them
///
/// [TomJobDefinition] and [TomScheduler] are untouched by this library. A job
/// whose schedule is computed from configuration, or whose body has to close
/// over something, can never be an annotation — so a hand-written definition
/// stays fully registrable and the two coexist in one scheduler.
library;

import 'package:tom_reflection/tom_reflection.dart';

import '../isolate_pooling/tom_worker.dart';
import '../little_things/exception_base.dart';
import '../reflection/reflection.dart';
import 'job_definition.dart';
import 'job_store.dart';
import 'schedule.dart';
import 'scheduler.dart';

// =============================================================================
// EXCEPTION
// =============================================================================

/// Raised when an annotated job cannot be turned into a [TomJobDefinition].
///
/// Always thrown from the scan, never from a firing, and always naming the
/// class at fault — the point of the annotation route is that a malformed
/// declaration stops start-up instead of failing in the small hours.
class TomScheduledJobException extends TomException {
  /// Creates a [TomScheduledJobException] with the given error details.
  TomScheduledJobException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

// =============================================================================
// JOB CONTRACT
// =============================================================================

/// The base class for a declaratively scheduled job.
///
/// A job is a [TomCommand] — that is what the scheduler dispatches, and nothing
/// about that changes here. [TomJobBase] adds the one thing a command built by
/// reflection cannot be handed through its constructor: the [run] it was
/// created for. Extending it is therefore optional in the strict sense (any
/// [TomCommand] with a no-argument constructor is accepted), but a job that
/// wants to know its window, its attempt number or its event payload has to.
///
/// ## Why the constructor takes no arguments
///
/// The body is instantiated per run by `newInstance('', [])`, so there is no
/// call site to pass collaborators from. Resolve them instead — in the
/// constructor or in [execute] — from the bean locator:
///
/// ```dart
/// @tomReflector
/// @TomScheduledJob(cron: '@daily')
/// class ExpireSessions extends TomJobBase {
///   final TomBean<SessionService> _sessions = TomBean<SessionService>();
///
///   @override
///   Future<Object?> execute() async =>
///       _sessions.get().expireBefore(run.scheduledFor);
/// }
/// ```
///
/// That is not a workaround for the annotation; it is the same wiring every
/// other framework component uses, and it keeps the job's dependencies
/// resolvable in a worker isolate, where a captured reference would not have
/// survived the copy.
abstract class TomJobBase extends TomCommand {
  /// The run this instance was created for.
  ///
  /// Assigned by [TomScheduledJobs] immediately after construction and before
  /// [execute] is called. Reading it from an instance built by hand — in a unit
  /// test, say — throws, which is the honest answer: there is no run.
  late final TomJobRun run;
}

// =============================================================================
// ANNOTATION
// =============================================================================

/// Declares that the annotated class is a scheduled job.
///
/// Carries what [TomJobDefinition] takes as constructor arguments, with one
/// unavoidable difference: a [TomSchedule] is not a constant, so it cannot be
/// an annotation argument. The trigger is instead declared by four **mutually
/// exclusive** fields — [cron], [interval], [calendar] and [event] — of which
/// exactly one must be set. Setting none, or two, is a scan-time error.
///
/// The class must also carry `@tomReflector`: the reflection substrate exposes
/// only `annotatedClasses`, with no by-annotation and no by-supertype query, so
/// a job that is not in the reflection build is not discoverable at all.
class TomScheduledJob {
  /// The job's identity, defaulting to the class's simple name.
  ///
  /// **This is the store key.** Runs in a [TomJobStore] are keyed by it, so
  /// renaming the class of a job that already has stored runs orphans them —
  /// the history stays under the old name and the job re-anchors as if new.
  /// Pin the old name here when renaming a job that is already in production;
  /// that is the entire reason this field is overridable.
  final String? name;

  /// A POSIX cron expression, e.g. `'0 3 * * *'`, or a macro such as
  /// `'@daily'`. Parsed and validated at scan time.
  final String? cron;

  /// A fixed period, e.g. `const Duration(minutes: 15)`.
  ///
  /// Fire times are computed from the Unix epoch by whole multiples of the
  /// period, so they are reproducible across processes and do not drift after
  /// an outage.
  final Duration? interval;

  /// A calendar expression — the month-relative rules cron cannot spell.
  ///
  /// Whitespace-separated `key:value` terms, exactly one of which selects the
  /// rule:
  ///
  /// | Term | Meaning |
  /// | ---- | ------- |
  /// | `day:<n>` | day of month, `1`..`31`, or `-1`..`-31` counting from the month's end |
  /// | `weekday:<ordinal>/<day>` | ordinal `1`..`5` or `last`; day `mon`..`sun` |
  /// | `at:<HH:MM>` | time of day, default `00:00` |
  /// | `every:<months>` | month interval `1`..`12`, default `1` |
  /// | `from:<month>` | the month `1`..`12` the interval is anchored on, default `1` |
  ///
  /// For example `'day:-1 at:23:30'` is the last day of every month at 23:30,
  /// and `'weekday:2/tue at:09:00 every:3'` is the second Tuesday of every
  /// third month at 09:00.
  final String? calendar;

  /// Declares the job event-triggered rather than clock-driven.
  ///
  /// A stream is not a constant either, so the source is supplied at scan time
  /// through [TomScheduledJobs.discover]'s `eventSource` resolver, keyed by job
  /// name. An event job discovered without a resolvable source is a scan-time
  /// error, not a job that quietly never fires.
  final bool event;

  /// How failed attempts are retried.
  final TomRetryPolicy retry;

  /// How long one attempt may take before it is treated as failed.
  final Duration timeout;

  /// What to do about windows missed while the scheduler was down.
  final TomMissedWindowPolicy missedWindow;

  /// The most windows [TomMissedWindowPolicy.runAll] will replay.
  final int catchUpLimit;

  /// Whether a new run may start while a previous one is still in flight.
  final bool allowOverlap;

  /// Declares a scheduled job. Exactly one of [cron], [interval], [calendar]
  /// and [event] must be given.
  const TomScheduledJob({
    this.name,
    this.cron,
    this.interval,
    this.calendar,
    this.event = false,
    this.retry = const TomRetryPolicy(),
    this.timeout = const Duration(minutes: 5),
    this.missedWindow = TomMissedWindowPolicy.runOnce,
    this.catchUpLimit = 10,
    this.allowOverlap = false,
  });
}

// =============================================================================
// DISCOVERY
// =============================================================================

/// Turns [TomScheduledJob]-annotated classes into registered jobs.
///
/// See the library documentation for why discovery is the recommended way to
/// declare a job and why it leaves [TomJobDefinition] and [TomScheduler]
/// untouched.
class TomScheduledJobs {
  TomScheduledJobs._();

  /// Scans the reflected classes and returns one definition per annotated job.
  ///
  /// Validates every declaration before returning any of them, so a start-up
  /// that has one bad job registers none of them rather than half of them.
  ///
  /// [eventSource] supplies the stream for a job declared `event: true`, keyed
  /// by the job's resolved name; returning `null` (or omitting the resolver)
  /// makes such a job a scan-time error.
  ///
  /// [where] narrows the scan to the classes it accepts. The default — every
  /// reflected class — is what an application wants; a deployment that ships
  /// one binary but runs different jobs per profile filters here rather than
  /// registering and then deregistering, and the validation suite uses it to
  /// examine one malformed declaration at a time.
  static List<TomJobDefinition> discover({
    Stream<Object?>? Function(String jobName)? eventSource,
    bool Function(ClassMirror candidate)? where,
  }) {
    final definitions = <String, TomJobDefinition>{};
    for (final candidate in tomReflector.annotatedClasses) {
      if (!candidate.metadata.any((o) => o is TomScheduledJob)) continue;
      if (where != null && !where(candidate)) continue;
      final annotation =
          candidate.metadata.firstWhere((o) => o is TomScheduledJob)
              as TomScheduledJob;
      final definition = _defineJob(candidate, annotation, eventSource);
      final existing = definitions[definition.name];
      if (existing != null) {
        throw TomScheduledJobException(
          'scheduled_job.duplicate_name',
          "Two classes declare the job '${definition.name}': "
              '$existing and ${_nameOf(candidate)}. A job name is the '
              'store key, so it must identify exactly one class.',
          parameters: {'job': definition.name},
          autoLog: true,
        );
      }
      definitions[definition.name] = definition;
    }
    return definitions.values.toList(growable: false);
  }

  /// Discovers every annotated job and registers it on [scheduler].
  ///
  /// Refuses to overwrite a name [scheduler] already knows: a discovered job
  /// silently replacing a hand-written one — or the reverse, depending on
  /// start-up order — is exactly the kind of pairing bug the annotation exists
  /// to remove. Registration happens only after the whole scan has validated.
  ///
  /// Returns the definitions it registered.
  static List<TomJobDefinition> registerAll(
    TomScheduler scheduler, {
    Stream<Object?>? Function(String jobName)? eventSource,
    bool Function(ClassMirror candidate)? where,
  }) {
    final definitions = discover(eventSource: eventSource, where: where);
    final registered = scheduler.jobs;
    for (final definition in definitions) {
      if (registered.containsKey(definition.name)) {
        throw TomScheduledJobException(
          'scheduled_job.name_already_registered',
          "The scheduler already has a job named '${definition.name}'; the "
              'discovered declaration would replace it. Rename one of them, or '
              'drop the hand-written registration.',
          parameters: {'job': definition.name},
          autoLog: true,
        );
      }
    }
    for (final definition in definitions) {
      scheduler.register(definition);
    }
    return definitions;
  }

  /// How a class is identified in a scan failure.
  ///
  /// The qualified name where there is one — two classes with the same simple
  /// name in different libraries are exactly the case worth disambiguating —
  /// but a mirror whose library is unnamed reports a bare `.ClassName`, and
  /// leading punctuation in an error message reads like a typo.
  static String _nameOf(ClassMirror candidate) {
    final qualified = candidate.qualifiedName;
    return qualified.startsWith('.') ? candidate.simpleName : qualified;
  }

  /// Builds one definition, validating everything about the declaration.
  static TomJobDefinition _defineJob(
    ClassMirror candidate,
    TomScheduledJob annotation,
    Stream<Object?>? Function(String jobName)? eventSource,
  ) {
    final name = (annotation.name ?? candidate.simpleName).trim();
    if (name.isEmpty) {
      throw TomScheduledJobException(
        'scheduled_job.unnamed',
        'The job declared on ${_nameOf(candidate)} has a blank name.',
        autoLog: true,
      );
    }
    // Instantiate once, here, for the two checks that cannot be made any other
    // way: that the class has a usable no-argument constructor, and that what
    // it produces is something the scheduler can dispatch. Both would otherwise
    // surface at fire time — the failure mode this whole library exists to
    // remove. The instance is then thrown away; every run builds its own.
    _newCommand(candidate, name);
    final schedule = _scheduleFor(candidate, annotation, name, eventSource);
    try {
      return TomJobDefinition(
        name: name,
        schedule: schedule,
        body: (run) => _newCommand(candidate, name, run),
        retryPolicy: annotation.retry,
        timeout: annotation.timeout,
        missedWindowPolicy: annotation.missedWindow,
        catchUpLimit: annotation.catchUpLimit,
        allowOverlap: annotation.allowOverlap,
      );
    } on TomScheduleException catch (error) {
      throw TomScheduledJobException(
        'scheduled_job.invalid_policy',
        "The job '$name' on ${_nameOf(candidate)} has an invalid policy: "
            '${error.defaultUserMessage}',
        parameters: {'job': name},
        rootException: error,
        autoLog: true,
      );
    }
  }

  /// Builds the body for one run — and, at scan time, the throwaway instance
  /// that proves the class can produce one at all.
  static TomCommand _newCommand(
    ClassMirror candidate,
    String name, [
    TomJobRun? run,
  ]) {
    Object? instance;
    try {
      instance = candidate.newInstance('', const []);
    } catch (error, stack) {
      throw TomScheduledJobException(
        'scheduled_job.not_constructible',
        "The job '$name' on ${_nameOf(candidate)} could not be "
            'instantiated. A scheduled job needs a no-argument constructor, '
            'because its body is built fresh for every run; resolve '
            'collaborators from the bean locator instead of taking them as '
            'constructor arguments.',
        parameters: {'job': name},
        rootException: error,
        stack: stack,
        autoLog: true,
      );
    }
    if (instance is! TomCommand) {
      throw TomScheduledJobException(
        'scheduled_job.not_a_command',
        "The job '$name' on ${_nameOf(candidate)} is not a TomCommand. "
            'Extend TomJobBase (or TomCommand) so the scheduler can dispatch '
            'it.',
        parameters: {'job': name},
        autoLog: true,
      );
    }
    if (run != null && instance is TomJobBase) instance.run = run;
    return instance;
  }

  /// Resolves the annotation's mutually exclusive trigger fields to a schedule.
  static TomSchedule _scheduleFor(
    ClassMirror candidate,
    TomScheduledJob annotation,
    String name,
    Stream<Object?>? Function(String jobName)? eventSource,
  ) {
    final declared = <String>[
      if (annotation.cron != null) 'cron',
      if (annotation.interval != null) 'interval',
      if (annotation.calendar != null) 'calendar',
      if (annotation.event) 'event',
    ];
    if (declared.length != 1) {
      throw TomScheduledJobException(
        declared.isEmpty
            ? 'scheduled_job.no_schedule'
            : 'scheduled_job.multiple_schedules',
        declared.isEmpty
            ? "The job '$name' on ${_nameOf(candidate)} declares no "
                'trigger. Set exactly one of cron:, interval:, calendar: or '
                'event:.'
            : "The job '$name' on ${_nameOf(candidate)} declares "
                '${declared.length} triggers (${declared.join(', ')}). Exactly '
                'one of cron:, interval:, calendar: or event: may be set.',
        parameters: {'job': name, 'declared': declared},
        autoLog: true,
      );
    }
    final cron = annotation.cron;
    if (cron != null) {
      try {
        return TomCronSchedule(cron);
      } on TomScheduleException catch (error) {
        throw TomScheduledJobException(
          'scheduled_job.invalid_cron',
          "The job '$name' on ${_nameOf(candidate)} has an unparseable "
              "cron expression '$cron': ${error.defaultUserMessage}",
          parameters: {'job': name, 'cron': cron},
          rootException: error,
          autoLog: true,
        );
      }
    }
    final interval = annotation.interval;
    if (interval != null) {
      try {
        return TomIntervalSchedule(interval);
      } on TomScheduleException catch (error) {
        throw TomScheduledJobException(
          'scheduled_job.invalid_interval',
          "The job '$name' on ${_nameOf(candidate)} has an invalid "
              'interval: ${error.defaultUserMessage}',
          parameters: {'job': name, 'interval': '$interval'},
          rootException: error,
          autoLog: true,
        );
      }
    }
    final calendar = annotation.calendar;
    if (calendar != null) {
      return _parseCalendar(calendar, candidate, name);
    }
    final events = eventSource?.call(name);
    if (events == null) {
      throw TomScheduledJobException(
        'scheduled_job.no_event_source',
        "The job '$name' on ${_nameOf(candidate)} is declared "
            'event-triggered, but no source was supplied for it. Pass an '
            'eventSource resolver that answers for this job name — a stream '
            'cannot be a constant, so it is the one part of an event job the '
            'annotation cannot carry.',
        parameters: {'job': name},
        autoLog: true,
      );
    }
    return TomEventSchedule(events, sourceName: name);
  }

  // ---------------------------------------------------------------------------
  // Calendar expressions
  // ---------------------------------------------------------------------------

  static const Map<String, int> _weekdays = {
    'mon': DateTime.monday,
    'tue': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'thu': DateTime.thursday,
    'fri': DateTime.friday,
    'sat': DateTime.saturday,
    'sun': DateTime.sunday,
  };

  /// Parses a [TomScheduledJob.calendar] expression.
  ///
  /// Strict on purpose: an unknown term, a duplicated term or a malformed value
  /// is rejected rather than ignored, because a silently dropped `at:` term
  /// would move a month-end job to midnight and nothing would say so.
  static TomCalendarSchedule _parseCalendar(
    String expression,
    ClassMirror candidate,
    String name,
  ) {
    Never fail(String detail) {
      throw TomScheduledJobException(
        'scheduled_job.invalid_calendar',
        "The job '$name' on ${_nameOf(candidate)} has an unparseable "
            "calendar expression '$expression': $detail",
        parameters: {'job': name, 'calendar': expression},
        autoLog: true,
      );
    }

    final terms = <String, String>{};
    for (final token in expression.toLowerCase().trim().split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final separator = token.indexOf(':');
      if (separator < 1) fail("'$token' is not a key:value term");
      final key = token.substring(0, separator);
      if (!const {'day', 'weekday', 'at', 'every', 'from'}.contains(key)) {
        fail("unknown term '$key'");
      }
      if (terms.containsKey(key)) fail("term '$key' appears twice");
      terms[key] = token.substring(separator + 1);
    }
    if (terms.containsKey('day') == terms.containsKey('weekday')) {
      fail('set exactly one of day: and weekday:');
    }

    int hour = 0;
    int minute = 0;
    final at = terms['at'];
    if (at != null) {
      final parts = at.split(':');
      if (parts.length != 2) fail("at: must be HH:MM; got '$at'");
      hour = int.tryParse(parts[0]) ?? fail("at: hour is not a number in '$at'");
      minute =
          int.tryParse(parts[1]) ?? fail("at: minute is not a number in '$at'");
    }
    final monthInterval = terms.containsKey('every')
        ? (int.tryParse(terms['every']!) ??
              fail("every: is not a number: '${terms['every']}'"))
        : 1;
    final anchorMonth = terms.containsKey('from')
        ? (int.tryParse(terms['from']!) ??
              fail("from: is not a number: '${terms['from']}'"))
        : 1;

    try {
      final day = terms['day'];
      if (day != null) {
        return TomCalendarSchedule.dayOfMonth(
          int.tryParse(day) ?? fail("day: is not a number: '$day'"),
          hour: hour,
          minute: minute,
          monthInterval: monthInterval,
          anchorMonth: anchorMonth,
        );
      }
      final parts = terms['weekday']!.split('/');
      if (parts.length != 2) {
        fail("weekday: must be <ordinal>/<day>; got '${terms['weekday']}'");
      }
      final ordinal = parts[0] == 'last'
          ? -1
          : (int.tryParse(parts[0]) ??
                fail("weekday: ordinal is not a number or 'last': '${parts[0]}'"));
      final weekday =
          _weekdays[parts[1]] ?? fail("unknown weekday '${parts[1]}'");
      return TomCalendarSchedule.weekdayOfMonth(
        weekday: weekday,
        ordinal: ordinal,
        hour: hour,
        minute: minute,
        monthInterval: monthInterval,
        anchorMonth: anchorMonth,
      );
    } on TomScheduleException catch (error) {
      fail(error.defaultUserMessage);
    }
  }
}

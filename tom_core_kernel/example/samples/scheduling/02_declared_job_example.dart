/// The other way to declare a job: annotate the class and let the start-up read
/// it back.
///
/// Example 01 wired everything by hand, which is the honest way to *see* a
/// scheduler but not how an application should declare fifty jobs. Hand-wiring
/// states a job twice — once as the class that does the work, once as a
/// `TomJobDefinition` somewhere in `main()` — and nothing joins the two but a
/// string a human typed in both places. A class can exist and never be
/// registered; a registration can outlive the class it names.
///
/// With `@TomScheduledJob` the class *is* the registration, and start-up is one
/// line. The point that is invisible unless you watch it happen: **everything is
/// checked during the scan**, before the scheduler is running, naming the class
/// at fault. That is the whole difference from a scheduler that stores a job's
/// class as a string and resolves it at fire time, where a rename fails at
/// 03:00 into a log nobody reads.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/scheduling/02_declared_job_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_bootstrap.dart';
import 'scheduling_support.dart';

// =============================================================================
// Declared jobs
// =============================================================================

/// Every execution in this file, keyed by job name.
///
/// A discovered body is built by the framework — one fresh instance per attempt
/// — so nothing here can hold a reference to the instance that will run. The
/// observation has to come from outside it, which is also true of the real
/// thing.
final Map<String, List<TomJobRun>> executions = {};

void _record(String job, TomJobRun run) => (executions[job] ??= []).add(run);

/// A job that says when it runs and nothing else.
///
/// No name, so the job's identity is the class's own simple name; no policy
/// arguments, so it takes the same defaults [TomJobDefinition] does.
@tomReflector
@TomScheduledJob(interval: Duration(hours: 1))
class HourlyRollup extends TomJobBase {
  @override
  Future<Object?> execute() async {
    // `run` is the one thing a reflected body cannot be handed through its
    // constructor, so [TomJobBase] assigns it after construction. This is why a
    // job that needs its window extends TomJobBase rather than TomCommand.
    _record('HourlyRollup', this.run);
    return 'rolled up';
  }
}

/// The same job after a rename — with its identity pinned to the old one.
///
/// The name is the *store key*. Renaming the class of a job that already has
/// stored runs would orphan its history under the old name and re-anchor the
/// job as if it were new, which is exactly what `name:` exists to prevent. The
/// rest of the arguments are here to show that a policy set on the annotation
/// reaches the definition unchanged; they are not defaults worth copying.
@tomReflector
@TomScheduledJob(
  name: 'nightly-reconciliation',
  cron: '0 3 * * *',
  retry: TomRetryPolicy(maxAttempts: 5),
  timeout: Duration(seconds: 30),
  missedWindow: TomMissedWindowPolicy.skip,
  catchUpLimit: 3,
)
class NightlyReconciliationV2 extends TomJobBase {
  @override
  Future<Object?> execute() async {
    _record('nightly-reconciliation', this.run);
    return 'reconciled';
  }
}

/// Reflected, a perfectly good job body — and not a job.
///
/// Discovery keys on the annotation, not on the supertype, so extending
/// [TomJobBase] schedules nothing by itself.
@tomReflector
class ReportBuilder extends TomJobBase {
  @override
  Future<Object?> execute() async => 'never scheduled';
}

/// A declaration that cannot be turned into a job: two triggers.
///
/// `cron:`, `interval:`, `calendar:` and `event:` are mutually exclusive and
/// exactly one must be set — there is no rule for which of two wins, so the scan
/// refuses rather than picking. This class is deliberately malformed and is
/// reached only through the `where:` filter below; an unscoped scan of this
/// library would fail on it, which is precisely the behaviour example 3 is
/// about.
@tomReflector
@TomScheduledJob(cron: '@daily', interval: Duration(minutes: 15))
class AmbiguousTrigger extends TomJobBase {
  @override
  Future<Object?> execute() async => null;
}

// =============================================================================
// Scoping the scan
// =============================================================================

/// Restricts a scan to the named classes.
///
/// `discover()` reads a *global* registry — every reflected class in the build,
/// which for this example folder means every class in every kernel sample. An
/// application scans everything and that is the right default; here each example
/// narrows to its own declarations so that the malformed one above is only ever
/// seen by the example that wants it. `where:` is not a testing affordance: it
/// is the same seam a deployment uses to ship one binary and run different jobs
/// per profile.
bool Function(ClassMirror) only(Set<String> names) =>
    (candidate) => names.contains(candidate.simpleName);

TomScheduler _scheduler(TomJobStore store, FakeClock clock) => TomScheduler(
  store: store,
  dispatcher: const TomInlineJobDispatcher(),
  clock: clock.call,
  ownerId: 'node-a',
  tickJitter: 0,
  onAlert: (_) {},
);

// =============================================================================
// EXAMPLE 1: The Class Is The Registration
// =============================================================================

/// What one line of start-up produces, and where each part of it came from.
class DiscoveryExample {
  static List<String> registeredNames = [];
  static TomSchedule? rollupSchedule;
  static int? reconciliationAttempts;
  static Duration? reconciliationTimeout;
  static TomMissedWindowPolicy? reconciliationPolicy;

  static Future<void> example1TheClassIsTheRegistration() async {
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final scheduler = _scheduler(TomMemoryJobStore(), clock);

    // The whole of start-up. No name, no schedule and no policy is repeated
    // here — every one of them is read back off the class that carries it.
    TomScheduledJobs.registerAll(
      scheduler,
      where: only({'HourlyRollup', 'NightlyReconciliationV2', 'ReportBuilder'}),
    );

    registeredNames = scheduler.jobs.keys.toList()..sort();
    rollupSchedule = scheduler.jobs['HourlyRollup']!.schedule;
    final reconciliation = scheduler.jobs['nightly-reconciliation']!;
    reconciliationAttempts = reconciliation.retryPolicy.maxAttempts;
    reconciliationTimeout = reconciliation.timeout;
    reconciliationPolicy = reconciliation.missedWindowPolicy;

    await scheduler.close();

    assert(
      registeredNames.length == 2,
      'ReportBuilder is a TomJobBase and is not a job: discovery keys on the '
      'annotation, so a job body is only scheduled when something says so',
    );
    assert(
      registeredNames.contains('HourlyRollup'),
      'With no name: given, the class name is the job name',
    );
    assert(
      registeredNames.contains('nightly-reconciliation'),
      'With name: given, the class may be renamed freely — the store key is '
      'the pinned name, not the class',
    );
    assert(
      rollupSchedule is TomIntervalSchedule,
      'The trigger field chose the schedule kind: interval: built an interval '
      'schedule, with no TomSchedule ever named at a call site',
    );
    assert(
      reconciliationAttempts == 5 &&
          reconciliationTimeout == const Duration(seconds: 30) &&
          reconciliationPolicy == TomMissedWindowPolicy.skip,
      'Policies declared on the annotation reach the definition unchanged',
    );
  }
}

// =============================================================================
// EXAMPLE 2: A Discovered Job Runs, And Knows Its Window
// =============================================================================

/// The declared job doing the thing example 01 wired by hand.
class DeclaredRunExample {
  static int runsAfterPlanning = 0;
  static DateTime? window;
  static int attempt = 0;
  static TomJobRunState? storedState;

  static Future<void> example2ADeclaredJobRuns() async {
    executions.clear();

    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final store = TomMemoryJobStore();
    final scheduler = _scheduler(store, clock);

    TomScheduledJobs.registerAll(scheduler, where: only({'HourlyRollup'}));

    await scheduler.tick();
    await settle();
    runsAfterPlanning = executions['HourlyRollup']?.length ?? 0;

    clock.advance(const Duration(hours: 1));
    await scheduler.tick();
    await settle();

    final run = executions['HourlyRollup']!.single;
    window = run.scheduledFor;
    attempt = run.attempt;
    // Beside it sits the pending look-ahead row for 11:00, exactly as in
    // example 01 — a discovered job is planned by the same code path.
    storedState = (await store.all())
        .firstWhere((r) => r.state != TomJobRunState.pending)
        .state;

    await scheduler.close();

    assert(runsAfterPlanning == 0, 'The first tick plans; it does not execute');
    assert(
      window == DateTime.utc(2026, 3, 2, 10),
      'The same absolute interval grid example 01 showed, reached through an '
      'annotation instead of a constructor',
    );
    assert(
      attempt == 1,
      'The body reads its own attempt number off the run — which is how a job '
      'can behave differently on a retry without anyone passing a flag',
    );
    assert(
      storedState == TomJobRunState.succeeded,
      'A discovered job is an ordinary job: same store, same lifecycle',
    );
  }
}

// =============================================================================
// EXAMPLE 3: A Bad Declaration Stops Start-Up, Naming The Class
// =============================================================================

/// The robustness claim, stated as an outcome rather than a promise.
class ScanValidationExample {
  static String? errorKey;
  static bool messageNamesTheClass = false;
  static bool nothingRegistered = false;

  static Future<void> example3ABadDeclarationStopsStartUp() async {
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final scheduler = _scheduler(TomMemoryJobStore(), clock);

    try {
      // One good declaration and one bad one, scanned together — the shape of a
      // real start-up, where the bad one is a typo among forty.
      quietly(
        () => TomScheduledJobs.registerAll(
          scheduler,
          where: only({'HourlyRollup', 'AmbiguousTrigger'}),
        ),
      );
    } on TomScheduledJobException catch (error) {
      errorKey = error.key;
      messageNamesTheClass = error.defaultUserMessage.contains(
        'AmbiguousTrigger',
      );
    }
    nothingRegistered = scheduler.jobs.isEmpty;

    await scheduler.close();

    assert(
      errorKey == 'scheduled_job.multiple_schedules',
      'Two triggers is a scan-time error, not a coin toss at fire time',
    );
    assert(
      messageNamesTheClass,
      'A start-up failure that does not say which declaration is wrong is '
      'barely better than one that happens at 03:00',
    );
    assert(
      nothingRegistered,
      'The scan validates every declaration before registering any of them: a '
      'start-up with one bad job registers none rather than half, so the '
      'process never runs in a state nobody described',
    );
  }
}

// =============================================================================
// EXAMPLE 4: Declared And Hand-Written Jobs Coexist
// =============================================================================

/// Discovery produces definitions; it does not replace them.
///
/// A job whose schedule is computed from configuration, or whose body must close
/// over something, can never be an annotation — so the hand-written route from
/// example 01 stays fully open, and the two live in one scheduler.
class CoexistenceExample {
  static List<String> bothRegistered = [];
  static String? collisionKey;

  /// Stands in for a period that arrives at run time — from settings, an
  /// environment variable, a tenant's configuration row.
  static Duration sweepPeriodFromSettings() => const Duration(minutes: 30);

  static Future<void> example4DeclaredAndHandWrittenCoexist() async {
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final scheduler = _scheduler(TomMemoryJobStore(), clock);

    // The escape hatch: an interval that arrives at start-up rather than at
    // compile time. An annotation argument is a constant, so this job is out of
    // the annotation's reach by construction — and stays perfectly registrable.
    scheduler.register(
      TomJobDefinition(
        name: 'configured-sweep',
        schedule: TomIntervalSchedule(sweepPeriodFromSettings()),
        body: (_) => _NoOpCommand(),
      ),
    );
    TomScheduledJobs.registerAll(scheduler, where: only({'HourlyRollup'}));

    bothRegistered = scheduler.jobs.keys.toList()..sort();

    // Now the pairing bug the annotation exists to remove: a second declaration
    // claiming a name the scheduler already knows. Registering it would mean the
    // live job depends on start-up *order*, so it is refused instead.
    scheduler.register(
      TomJobDefinition(
        name: 'HourlyRollup',
        schedule: TomIntervalSchedule(const Duration(hours: 2)),
        body: (run) => _NoOpCommand(),
      ),
    );
    try {
      quietly(
        () => TomScheduledJobs.registerAll(
          scheduler,
          where: only({'HourlyRollup'}),
        ),
      );
    } on TomScheduledJobException catch (error) {
      collisionKey = error.key;
    }

    await scheduler.close();

    assert(
      bothRegistered.length == 2,
      'One scheduler holds both routes; discovery adds to it, it does not own '
      'it',
    );
    assert(
      collisionKey == 'scheduled_job.name_already_registered',
      'A discovered job silently replacing a hand-written one — or the reverse, '
      'depending on which start-up line ran first — is refused rather than '
      'resolved',
    );
  }
}

/// A body for the hand-written definitions, which need one and do nothing.
class _NoOpCommand extends TomCommand {
  @override
  Future<Object?> execute() async => null;
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

Future<void> run() async {
  print('=== 02: Declared Job Example ===\n');

  await DiscoveryExample.example1TheClassIsTheRegistration();
  print('1. One line of start-up, read back off the annotated classes:');
  print('   registered jobs : ${DiscoveryExample.registeredNames}');
  print('   rollup schedule : ${DiscoveryExample.rollupSchedule.runtimeType}');
  print('   retry attempts  : ${DiscoveryExample.reconciliationAttempts}');
  print('   timeout         : ${DiscoveryExample.reconciliationTimeout}');
  print('   missed window   : ${DiscoveryExample.reconciliationPolicy}');
  print('');

  await DeclaredRunExample.example2ADeclaredJobRuns();
  print('2. The discovered job runs, and knows its window:');
  print('   runs after planning : ${DeclaredRunExample.runsAfterPlanning}');
  print('   window handed to it : ${DeclaredRunExample.window}');
  print('   attempt             : ${DeclaredRunExample.attempt}');
  print('   stored run state    : ${DeclaredRunExample.storedState}');
  print('');

  await ScanValidationExample.example3ABadDeclarationStopsStartUp();
  print('3. A bad declaration stops start-up, naming the class:');
  print('   error key          : ${ScanValidationExample.errorKey}');
  print(
    '   names the class    : '
    '${ScanValidationExample.messageNamesTheClass}',
  );
  print('   nothing registered : ${ScanValidationExample.nothingRegistered}');
  print('');

  await CoexistenceExample.example4DeclaredAndHandWrittenCoexist();
  print('4. Declared and hand-written jobs in one scheduler:');
  print('   both registered : ${CoexistenceExample.bothRegistered}');
  print('   collision key   : ${CoexistenceExample.collisionKey}');
  print('');
}

Future<void> main() async {
  bootstrapSamples();
  await run();
}

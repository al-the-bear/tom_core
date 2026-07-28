/// The smallest complete scheduler: an in-memory store, an in-memory lease
/// lock, and a clock the example moves by hand.
///
/// Everything else in this folder is built on this substrate, so it is worth
/// being clear about what it is and is not. It needs no database, no files and
/// no containers — but it is not a toy. `TomMemoryJobStore` implements the same
/// `TomJobStore` contract as the file and SQL stores and is verified against the
/// same parameterised contract suite, so the lifecycle you watch here is the
/// lifecycle production runs. What memory does not give you is durability
/// (nothing survives a restart) and sharing (one process only) — which is
/// exactly why the cluster story needs a database, and why it is demonstrated
/// in `tom_core_server` rather than here.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'scheduling_support.dart';

// =============================================================================
// A job body worth watching
// =============================================================================

/// Records the window it was asked to process.
///
/// The body works on `run.scheduledFor` — the instant the job was *supposed* to
/// fire — rather than on "now". That distinction is the whole reason a run
/// carries a window, and example 04 shows what it buys.
class RecordWindowCommand extends TomCommand {
  /// Every window processed, in the order the scheduler dispatched them.
  static final List<DateTime> processed = [];

  final DateTime window;

  RecordWindowCommand(this.window);

  @override
  Future<Object?> execute() async {
    processed.add(window);
    return 'processed';
  }
}

// =============================================================================
// EXAMPLE 1: One Window, End To End
// =============================================================================

/// A single tick, watched from registration to a completed row.
class LifecycleExample {
  static List<DateTime> processed = [];
  static int rowsAfterPlanning = 0;
  static TomJobRunState? plannedState;
  static TomJobRunState? finalState;
  static DateTime? completedWindow;
  static DateTime? lookAheadWindow;
  static int runCount = 0;

  static Future<void> example1OneWindowEndToEnd() async {
    RecordWindowCommand.processed.clear();

    // 09:00 exactly. Every instant in these examples is UTC: a schedule takes
    // its meaning from the zone of the instant it is asked about, so mixing
    // zones would make the assertions about *which* window fired unreadable.
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final store = TomMemoryJobStore();

    final scheduler = TomScheduler(
      store: store,
      dispatcher: const TomInlineJobDispatcher(),
      clock: clock.call,
      ownerId: 'node-a',
      // No jitter: jitter exists to keep a cluster's nodes from waking in
      // lockstep, and there is one node here. Left at its default it would make
      // nothing wrong, only unreproducible.
      tickJitter: 0,
      onAlert: (_) {},
    );

    scheduler.register(
      TomJobDefinition(
        name: 'hourly-rollup',
        schedule: TomIntervalSchedule(const Duration(hours: 1)),
        // A *factory*, called once per attempt — not the work itself. That is
        // what lets the same job run on an isolate pool, where the command is
        // the unit that crosses the boundary.
        body: (run) => RecordWindowCommand(run.scheduledFor),
      ),
    );

    // First sight of the job anchors on the present: the scheduler has no
    // record of it, so it plans the next window rather than replaying history.
    // Nothing is due yet, so this tick executes nothing — but it does *write*,
    // and that write is the point of the next few assertions.
    await scheduler.tick();
    await settle();
    final afterPlanning = RecordWindowCommand.processed.length;
    final planned = (await store.all()).single;
    rowsAfterPlanning = 1;
    plannedState = planned.state;

    // Move to the planned window and tick again. `tick()` is public and
    // awaitable precisely so an example — or a test — never has to wait on
    // wall-clock time.
    clock.advance(const Duration(hours: 1));
    await scheduler.tick();
    await settle();

    processed = List.of(RecordWindowCommand.processed);
    final runs = await store.all();
    runCount = runs.length;

    final completed = runs.firstWhere((r) => r.state != TomJobRunState.pending);
    finalState = completed.state;
    completedWindow = completed.scheduledFor;
    lookAheadWindow = runs
        .firstWhere((r) => r.state == TomJobRunState.pending)
        .scheduledFor;

    scheduler.close();

    assert(afterPlanning == 0, 'Planning a window does not execute it');
    assert(
      plannedState == TomJobRunState.pending,
      'The plan is durable before it is due: a tick writes the window it '
      'intends to run as a pending row, so a node that dies between planning '
      'and firing leaves evidence behind rather than silently forgetting',
    );
    assert(rowsAfterPlanning == 1, 'One window ahead, not a whole horizon');
    assert(processed.length == 1, 'One window, one execution');
    assert(
      completedWindow == DateTime.utc(2026, 3, 2, 10),
      'The interval grid is absolute, so the window is the hour mark itself',
    );
    assert(
      processed.single == completedWindow,
      'The body was handed the window it was dispatched for',
    );
    assert(
      finalState == TomJobRunState.succeeded,
      'A body that returns normally completes the run',
    );
    assert(
      runCount == 2,
      'Two rows, not one: every tick plans the next window as well as running '
      'the due one, so a completed run always sits beside its successor',
    );
    assert(
      lookAheadWindow == DateTime.utc(2026, 3, 2, 11),
      'And the successor is the next window on the same grid',
    );
  }
}

// =============================================================================
// EXAMPLE 2: The Store Is The Durable Record
// =============================================================================

/// What a `TomJobRun` carries, and why a scheduler keeps one at all.
///
/// An in-process `Timer` has no equivalent of this row. It is the row that
/// answers "did the 09:00 run happen", "how many attempts did it take", and
/// "who was holding it when the node died".
class StoreRecordExample {
  static String? jobName;
  static DateTime? scheduledFor;
  static DateTime? runAt;
  static int attempt = 0;
  static bool startedAtRecorded = false;
  static bool claimReleased = false;

  static Future<void> example2TheStoreIsTheRecord() async {
    RecordWindowCommand.processed.clear();

    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final store = TomMemoryJobStore();
    final scheduler = TomScheduler(
      store: store,
      dispatcher: const TomInlineJobDispatcher(),
      clock: clock.call,
      ownerId: 'node-a',
      tickJitter: 0,
      onAlert: (_) {},
    );

    scheduler.register(
      TomJobDefinition(
        name: 'hourly-rollup',
        schedule: TomIntervalSchedule(const Duration(hours: 1)),
        body: (run) => RecordWindowCommand(run.scheduledFor),
      ),
    );

    await scheduler.tick();
    clock.advance(const Duration(hours: 1));
    await scheduler.tick();
    await settle();

    // The store also holds the look-ahead row for 11:00 (example 1). The one
    // worth reading is the run that actually executed.
    final run = (await store.all()).firstWhere(
      (r) => r.state == TomJobRunState.succeeded,
    );
    jobName = run.jobName;
    scheduledFor = run.scheduledFor;
    runAt = run.runAt;
    attempt = run.attempt;
    startedAtRecorded = run.startedAt != null;
    claimReleased = run.claimedBy == null;

    scheduler.close();

    assert(jobName == 'hourly-rollup', 'Runs are keyed by the job name');
    assert(
      scheduledFor == runAt,
      'A first attempt is due at its own window; only a backed-off retry is '
      'due later',
    );
    assert(attempt == 1, 'Attempts are 1-based and count the first one');
    assert(
      startedAtRecorded,
      'startedAt is written before dispatch, so a surviving peer can tell a '
      'run that was reserved and lost from one that was interrupted mid-flight',
    );
    assert(
      claimReleased,
      'A finished run holds no claim — the claim is the store\'s own lease',
    );
  }
}

// =============================================================================
// EXAMPLE 3: The Lease Lock, And What It Is Taken On
// =============================================================================

/// The lock is opt-in and costs nothing when absent; with one, the resource key
/// *is* the concurrency policy.
class LeaseLockExample {
  static String? leaseResource;
  static int? token;
  static bool heldDuringRun = false;
  static bool releasedAfterRun = false;
  static bool holderVanished = false;

  static Future<void> example3TheLeaseAndItsResource() async {
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final store = TomMemoryJobStore();
    final lock = TomMemoryLeaseLock(clock: clock.call);

    final scheduler = TomScheduler(
      store: store,
      dispatcher: const TomInlineJobDispatcher(),
      clock: clock.call,
      // Distinct per node. Two schedulers sharing an ownerId would each read
      // the other's lease as their own, which silently disables the lock.
      ownerId: 'node-a',
      lock: lock,
      leaseTtl: const Duration(minutes: 5),
      tickJitter: 0,
      onAlert: (_) {},
    );

    scheduler.register(
      TomJobDefinition(
        name: 'hourly-rollup',
        schedule: TomIntervalSchedule(const Duration(hours: 1)),
        body: (run) => RecordWindowCommand(run.scheduledFor),
        // allowOverlap: false is the default and the safe reading. It is what
        // makes the lease resource the *job* rather than the run — the whole
        // cluster then runs at most one of this job at a time.
        allowOverlap: false,
      ),
    );

    await scheduler.tick();
    clock.advance(const Duration(hours: 1));
    await scheduler.tick();
    await settle();

    final info = await lock.inspect('job:hourly-rollup');
    leaseResource = info.lease?.resource;
    token = info.lease?.token;
    releasedAfterRun = info.wasReleased;
    holderVanished = info.holderVanished;
    heldDuringRun = info.lease != null;

    scheduler.close();
    lock.close();

    assert(
      leaseResource == 'job:hourly-rollup',
      'allowOverlap: false takes the lease on the job, not on the run',
    );
    assert(token == 1, 'Fencing tokens start at 1 and strictly increase');
    assert(heldDuringRun, 'The run acquired a lease before executing');
    assert(
      releasedAfterRun,
      'A finished run releases its lease immediately rather than waiting out '
      'the TTL',
    );
    assert(
      !holderVanished,
      'A released lease and a lapsed one are different news: this node shut '
      'the run down cleanly, it did not die holding it',
    );
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

Future<void> run() async {
  await LifecycleExample.example1OneWindowEndToEnd();
  await StoreRecordExample.example2TheStoreIsTheRecord();
  await LeaseLockExample.example3TheLeaseAndItsResource();
}

Future<void> main() => run();

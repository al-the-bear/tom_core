/// Three controls over runs that are already in the queue: which goes first,
/// which waits, and where an interrupted one picks up.
///
/// 1. **Priority** — a job's `priority` is copied onto every run it plans, and
///    a claim takes the most urgent due run first, queue order among equals.
/// 2. **Pausing** — `pauseJob` holds a job's runs out of every claim and out of
///    the backlog until `resumeJob`; nothing is lost while it waits.
/// 3. **Checkpoints** — a body saves its progress through `TomJobRunContext`,
///    and the next attempt of the same run starts from it.
///
/// Everything runs on the in-memory store with a clock moved by hand, so every
/// outcome is an equality rather than a timing.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/scheduling/06_priority_pause_checkpoint_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'scheduling_support.dart';

import '../../sample_preamble.dart';

/// Appends [label] to [into] when it runs.
class RecordLabel extends TomCommand {
  final List<String> into;
  final String label;

  RecordLabel(this.into, this.label);

  @override
  Future<Object?> execute() async {
    into.add(label);
    return null;
  }
}

TomScheduler _scheduler(
  TomJobStore store,
  FakeClock clock, {
  int maxRunsPerTick = 16,
}) => TomScheduler(
  store: store,
  dispatcher: const TomInlineJobDispatcher(),
  clock: clock.call,
  ownerId: 'node-a',
  tickJitter: 0,
  maxRunsPerTick: maxRunsPerTick,
  onAlert: (_) {},
);

// =============================================================================
// EXAMPLE 1: The Most Urgent Due Run Is Claimed First
// =============================================================================

/// Two jobs due in the same window, and room for one run per pass.
///
/// `cleanup` is registered first, so its run is first in the queue; `billing`
/// carries priority 10. With one run per pass the claim has to choose, and it
/// chooses by priority rather than by queue order.
class PriorityExample {
  static List<String> order = [];
  static int? billingPriority;

  static Future<void> example1TheMostUrgentRunGoesFirst() async {
    final store = TomMemoryJobStore();
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final scheduler = _scheduler(store, clock, maxRunsPerTick: 1);
    order = [];

    scheduler
      ..register(
        TomJobDefinition(
          name: 'cleanup',
          schedule: TomIntervalSchedule(const Duration(hours: 1)),
          body: (_) => RecordLabel(order, 'cleanup'),
        ),
      )
      ..register(
        TomJobDefinition(
          name: 'billing',
          schedule: TomIntervalSchedule(const Duration(hours: 1)),
          body: (_) => RecordLabel(order, 'billing'),
          priority: 10,
        ),
      );

    // Plans the 10:00 window of both jobs; nothing is due yet.
    await scheduler.tick();
    await scheduler.drain();
    billingPriority = (await store.all())
        .firstWhere((run) => run.jobName == 'billing')
        .priority;

    clock.advance(const Duration(hours: 1));
    await scheduler.tick();
    await scheduler.drain();
    await scheduler.tick();
    await scheduler.drain();
    await scheduler.close();

    assert(
      billingPriority == 10,
      'The run carries its job\'s priority — the claim reads the run, not the '
      'registry, so every node sharing the store orders it the same way',
    );
    assert(
      order.length == 2 && order.first == 'billing' && order.last == 'cleanup',
      'With room for one run, the claim took billing although cleanup was '
      'queued first; cleanup ran on the next pass',
    );
  }
}

// =============================================================================
// EXAMPLE 2: A Paused Job Waits, And Loses Nothing
// =============================================================================

/// A pause holds the runs that are already queued, not just future planning.
///
/// The 10:00 window is in the queue before the pause; while the job is paused
/// it is neither claimed nor counted in the backlog, and after the resume it
/// runs on the next pass.
class PauseExample {
  static List<String> ran = [];
  static DateTime? pausedAt;
  static int ranWhilePaused = -1;
  static int backlogWhilePaused = -1;
  static bool listedAfterResume = true;

  static Future<void> example2APausedJobWaits() async {
    final store = TomMemoryJobStore();
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final scheduler = _scheduler(store, clock);
    ran = [];

    scheduler.register(
      TomJobDefinition(
        name: 'export',
        schedule: TomIntervalSchedule(const Duration(hours: 1)),
        body: (_) => RecordLabel(ran, 'export'),
      ),
    );
    await scheduler.tick();
    await scheduler.drain();

    await scheduler.pauseJob('export');
    pausedAt = (await scheduler.pausedJobs())['export'];

    clock.advance(const Duration(hours: 1));
    await scheduler.tick();
    await scheduler.drain();
    ranWhilePaused = ran.length;
    backlogWhilePaused = (await store.backlog(clock())).length;

    await scheduler.resumeJob('export');
    listedAfterResume = (await scheduler.pausedJobs()).containsKey('export');
    await scheduler.tick();
    await scheduler.drain();
    await scheduler.close();

    assert(
      pausedAt == DateTime.utc(2026, 3, 2, 9),
      'The pause records when it began — the answer to "since when"',
    );
    assert(
      ranWhilePaused == 0 && backlogWhilePaused == 0,
      'Its due 10:00 run was not claimed, and the backlog does not count it: '
      'a paused job is waiting by decision, not falling behind',
    );
    assert(
      !listedAfterResume && ran.length == 1,
      'Resumed, the waiting run is claimed on the next pass — the pause lost '
      'nothing',
    );
  }
}

// =============================================================================
// EXAMPLE 3: A Retried Attempt Starts From The Checkpoint
// =============================================================================

/// Copies ten rows in batches of three, saving the offset after each batch.
///
/// The first attempt fails after its second batch. Without a checkpoint the
/// retry would copy rows 0–5 a second time; with it, the retry starts at row 6.
class CopyRows extends TomCommand {
  final List<int> copied;
  final List<int> startedAt;
  final bool failAfterTwoBatches;

  CopyRows(this.copied, this.startedAt, {required this.failAfterTwoBatches});

  @override
  Future<Object?> execute() async {
    final context = TomJobRunContext.require();
    var offset = context.checkpoint?['offset'] as int? ?? 0;
    startedAt.add(offset);
    var batches = 0;
    while (offset < 10) {
      final end = offset + 3 > 10 ? 10 : offset + 3;
      copied.addAll([for (var row = offset; row < end; row++) row]);
      offset = end;
      await context.saveCheckpoint({'offset': offset});
      batches++;
      if (failAfterTwoBatches && batches == 2) {
        throw StateError('the target went away');
      }
    }
    return null;
  }
}

class CheckpointExample {
  static List<int> copied = [];
  static List<int> startedAt = [];
  static Map<String, Object?>? storedCheckpoint;
  static TomJobRunState? finalState;
  static bool contextOutsideBody = true;
  static String? requireOutsideBody;

  static Future<void> example3ARetryStartsFromTheCheckpoint() async {
    final store = TomMemoryJobStore();
    final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
    final scheduler = _scheduler(store, clock);
    copied = [];
    startedAt = [];
    var attempt = 0;

    scheduler.register(
      TomJobDefinition(
        name: 'copy-rows',
        schedule: TomOnceSchedule(DateTime.utc(2026, 3, 2, 10)),
        body: (_) =>
            CopyRows(copied, startedAt, failAfterTwoBatches: ++attempt == 1),
        retryPolicy: const TomRetryPolicy(
          maxAttempts: 2,
          initialBackoff: Duration(minutes: 1),
          jitter: 0,
        ),
      ),
    );
    await scheduler.tick();
    await scheduler.drain();

    clock.advance(const Duration(hours: 1));
    await scheduler.tick();
    await scheduler.drain();

    clock.advance(const Duration(minutes: 1));
    await scheduler.tick();
    await scheduler.drain();
    await scheduler.close();

    final run = (await store.all()).single;
    storedCheckpoint = run.checkpoint;
    finalState = run.state;

    contextOutsideBody = TomJobRunContext.current != null;
    try {
      TomJobRunContext.require();
    } on TomScheduleException catch (error) {
      requireOutsideBody = error.key;
    }

    assert(
      startedAt.length == 2 && startedAt.first == 0 && startedAt.last == 6,
      'The first attempt started at row 0; the retry started at row 6, the '
      'offset the first attempt saved before it failed',
    );
    assert(
      copied.length == 10 &&
          [for (var row = 0; row < 10; row++) row].every(copied.contains),
      'Every row was copied exactly once across the two attempts',
    );
    assert(
      finalState == TomJobRunState.succeeded &&
          storedCheckpoint?['offset'] == 10,
      'The run succeeded, and its last checkpoint is stored with it',
    );
    assert(
      !contextOutsideBody &&
          requireOutsideBody == 'schedule.run_context.missing',
      'Outside a job body there is no run: current is null, and require() '
      'refuses under schedule.run_context.missing',
    );
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

Future<void> run() async {
  print('=== 06: Priority, Pause And Checkpoint Example ===\n');

  await PriorityExample.example1TheMostUrgentRunGoesFirst();
  print('1. The most urgent due run is claimed first:');
  print('   billing priority : ${PriorityExample.billingPriority}');
  print('   run order        : ${PriorityExample.order}');
  print('');

  await PauseExample.example2APausedJobWaits();
  print('2. A paused job waits, and loses nothing:');
  print('   paused at           : ${PauseExample.pausedAt}');
  print('   ran while paused    : ${PauseExample.ranWhilePaused}');
  print('   backlog while paused: ${PauseExample.backlogWhilePaused}');
  print('   listed after resume : ${PauseExample.listedAfterResume}');
  print('   ran after resume    : ${PauseExample.ran}');
  print('');

  await CheckpointExample.example3ARetryStartsFromTheCheckpoint();
  print('3. A retried attempt starts from the checkpoint:');
  print('   attempts started at : ${CheckpointExample.startedAt}');
  print('   rows copied         : ${CheckpointExample.copied}');
  print('   stored checkpoint   : ${CheckpointExample.storedCheckpoint}');
  print('   final state         : ${CheckpointExample.finalState}');
  print('   require() outside   : ${CheckpointExample.requireOutsideBody}');
  print('');
}

Future<void> main() {
  prepareSampleProcess();
  return run();
}

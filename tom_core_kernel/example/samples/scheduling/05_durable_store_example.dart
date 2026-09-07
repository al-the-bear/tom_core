/// The file-backed pair, and what "survives a restart" actually buys.
///
/// Every other file in this folder uses `TomMemoryJobStore`, which is honest
/// about what it is: one process, nothing survives. This one runs the module's
/// headline claim instead —
///
/// > **`TomFileJobStore`** survives a restart; an in-flight run comes back as an
/// > *expired claim* rather than as lost work, so the scheduler recovers it on
/// > its next tick.
///
/// — and the only way to demonstrate that is to actually stop using a store and
/// build another one over the same bytes. Each example below does exactly that:
/// the "first process" closes its scheduler and drops its store, and a *second*
/// store is constructed over the same path. Nothing is shared between them but
/// the file, which is the whole point.
///
/// The four steps are the four things durability is made of:
///
/// 1. A planned window outlives the process that planned it.
/// 2. A run that was *executing* when the process died comes back as an expired
///    claim — visible, attributable, and recoverable.
/// 3. A lease outlives the process that took it, and its fencing token keeps
///    increasing across the restart.
/// 4. And the honest limit: a file store's claim is not atomic between
///    processes, which is *why* the file pair wants the lock beside it.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/scheduling/05_durable_store_example.dart
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'scheduling_support.dart';

import '../../sample_preamble.dart';

// =============================================================================
// A scratch directory, and a body worth watching
// =============================================================================

/// A directory the example writes into and removes when it is done.
///
/// Durability is a property of a *filesystem*, so unlike the rest of this
/// folder these examples cannot run entirely in memory. They still leave
/// nothing behind: every example deletes its directory in a `finally`, so a
/// failing assertion does not litter the temp folder either.
Directory _scratch() =>
    Directory.systemTemp.createTempSync('tom_scheduling_sample_');

/// Records the window it was asked to process, and by which "process".
class RecordRun extends TomCommand {
  final List<String> into;
  final String node;
  final TomJobRun run;

  RecordRun(this.into, this.node, this.run);

  @override
  Future<Object?> execute() async {
    into.add('$node ran ${run.scheduledFor.toIso8601String()}');
    return null;
  }
}

TomScheduler _scheduler(TomJobStore store, FakeClock clock, String ownerId) =>
    TomScheduler(
      store: store,
      dispatcher: const TomInlineJobDispatcher(),
      clock: clock.call,
      ownerId: ownerId,
      tickJitter: 0,
      onAlert: (_) {},
    );

// =============================================================================
// EXAMPLE 1: A Planned Window Outlives The Process That Planned It
// =============================================================================

/// The claim in its simplest form: plan, exit, restart, run.
///
/// The assertion that carries the weight is the one about the run **id**. That a
/// job scheduled "hourly" fires at 10:00 after a restart proves nothing — the
/// second process would have planned a 10:00 window all by itself. That the run
/// which executed is *the same row* the first process wrote is what makes this
/// durability rather than coincidence.
class QueueOutlivesProcessExample {
  static bool fileIsJsonArray = false;
  static int rowsOnDisk = 0;
  static String? plannedId;
  static String? executedId;
  static List<String> ran = [];

  static Future<void> example1AQueueOutlivesItsProcess() async {
    final dir = _scratch();
    try {
      final path = '${dir.path}/queue.json';
      final clock = FakeClock(DateTime.utc(2026, 3, 2, 9));
      ran = [];

      // --- First process --------------------------------------------------
      final firstStore = TomFileJobStore(path);
      final first = _scheduler(firstStore, clock, 'node-a');
      first.register(
        TomJobDefinition(
          name: 'hourly-rollup',
          schedule: TomIntervalSchedule(const Duration(hours: 1)),
          body: (run) => RecordRun(ran, 'process-1', run),
        ),
      );

      // Nothing is due at 09:00, so this tick executes nothing — it only plans
      // the 10:00 window and writes it down. That write is the entire subject
      // of this example.
      await first.tick();
      await settle();
      plannedId = (await firstStore.all()).single.id;

      // The process exits. `close()` stops the timer chain; dropping the last
      // reference to `firstStore` is what makes the rest of this example a
      // genuine restart rather than a shared object with a file beside it.
      first.close();

      // --- What is on disk, between the two processes ----------------------
      // Readable without the kernel, which is the point of a JSON array: an
      // operator with `cat` can answer "is the 10:00 rollup queued?".
      final decoded = jsonDecode(File(path).readAsStringSync());
      fileIsJsonArray = decoded is List;
      rowsOnDisk = (decoded as List).length;

      // --- Second process ---------------------------------------------------
      // A fresh store over the same path. Constructing it *is* the reload.
      final secondStore = TomFileJobStore(path);
      final second = _scheduler(secondStore, clock, 'node-a');
      second.register(
        TomJobDefinition(
          name: 'hourly-rollup',
          schedule: TomIntervalSchedule(const Duration(hours: 1)),
          body: (run) => RecordRun(ran, 'process-2', run),
        ),
      );

      clock.advance(const Duration(hours: 1));
      await second.tick();
      await settle();

      // Nullable on purpose. If the plan had NOT survived, the second process
      // would have anchored on 10:00 and planned 11:00 — leaving nothing
      // succeeded here — and the assertion below should be what says so,
      // rather than a `firstWhere` throwing before the reader reaches it.
      final succeeded = (await secondStore.all())
          .where((run) => run.state == TomJobRunState.succeeded)
          .toList();
      executedId = succeeded.isEmpty ? null : succeeded.single.id;
      second.close();

      assert(
        fileIsJsonArray && rowsOnDisk == 1,
        'One array, one pending row — the queue is the file, not a log of '
        'changes to it, so there is no journal to replay and nothing to compact',
      );
      assert(
        ran.length == 1 &&
            ran.single == 'process-2 ran 2026-03-02T10:00:00.000Z',
        'The second process ran the 10:00 window — and the first ran nothing, '
        'having only ever planned it',
      );
      assert(
        executedId != null && executedId == plannedId,
        'And it ran the row the FIRST process wrote. Without this the example '
        'would prove only that an hourly job fires hourly — the second process '
        'would have planned its own 10:00 window regardless. Same id means the '
        'plan survived, which is the difference between a scheduler and a Timer',
      );
    } finally {
      dir.deleteSync(recursive: true);
    }
  }
}

// =============================================================================
// EXAMPLE 2: An In-Flight Run Comes Back As An Expired Claim
// =============================================================================

/// The half of durability that is easy to state and easy to get wrong.
///
/// A pending row surviving is the cheap case. The interesting one is the run
/// that was **executing** when the power went out. It does not come back as
/// lost work, and — just as importantly — it does not come back as `pending`
/// either. It comes back exactly as it was: `running`, claimed by a node that no
/// longer exists, with a `startedAt` on it. Everything an operator or a
/// surviving peer needs in order to decide is still there, and *deciding* is
/// left to recovery rather than done silently by the reload.
class InFlightRunSurvivesExample {
  static int rowsAfterRestart = 0;
  static TomJobRunState? stateAfterRestart;
  static String? claimedByAfterRestart;
  static bool startedAtSurvived = false;
  static TomJobRunState? stateAfterRecovery;
  static int attemptAfterRecovery = 0;

  static Future<void> example2AnInFlightRunComesBack() async {
    final dir = _scratch();
    try {
      final path = '${dir.path}/queue.json';
      final window = DateTime.utc(2026, 3, 2, 10);

      // --- First process: claims a run, starts it, and dies ----------------
      final firstStore = TomFileJobStore(path);
      await firstStore.enqueue(
        TomJobRun(
          id: 'run-1',
          jobName: 'rebuild-search-index',
          scheduledFor: window,
          runAt: window,
        ),
      );
      final claimed = (await firstStore.claimDue(window, 'node-a')).single;
      // Past the point of no return: the body is running. Compare example 2 of
      // sample 04, where the node died *before* this line and the run was
      // therefore free to re-offer unconditionally.
      await firstStore.markStarted(claimed, window);

      // --- Second process: reads what the crash left behind ----------------
      final secondStore = TomFileJobStore(path);
      // Read null-safely: "the run is still there at all" is the first thing
      // this example claims, so an empty reload has to fail as the assertion
      // below rather than as a stack trace two lines above it.
      final reloaded = (await secondStore.all()).singleOrNull;
      rowsAfterRestart = (await secondStore.all()).length;
      stateAfterRestart = reloaded?.state;
      claimedByAfterRestart = reloaded?.claimedBy;
      startedAtSurvived = reloaded?.startedAt != null;

      // Twenty minutes later, with a fifteen-minute lease: the claim has
      // outlived its timeout, so its holder is gone by definition.
      final recovered = await secondStore.recoverAbandoned(
        DateTime.utc(2026, 3, 2, 10, 20),
        const Duration(minutes: 15),
        // Rebuilding an index is safe to repeat, so this job opts in. A job that
        // charges cards would not, and would be failed terminally instead —
        // sample 04, example 3.
        requestsRecovery: (jobName) => jobName == 'rebuild-search-index',
      );
      stateAfterRecovery = recovered.singleOrNull?.state;
      attemptAfterRecovery = recovered.singleOrNull?.attempt ?? 0;

      assert(
        rowsAfterRestart == 1 && stateAfterRestart == TomJobRunState.running,
        'Not pending, and not gone: the reload restores the run as it was. A '
        'store that "helpfully" reset it to pending on load would erase the '
        'evidence that a body had already begun, and with it the job\'s right '
        'to refuse a second execution',
      );
      assert(
        claimedByAfterRestart == 'node-a',
        'Still attributed to the node that died holding it — which is the first '
        'question asked when a job stops finishing',
      );
      assert(
        startedAtSurvived,
        'And the timestamp that distinguishes "reserved and lost" from '
        '"interrupted mid-flight" is on disk too. That single field is what '
        'recovery branches on',
      );
      assert(
        stateAfterRecovery == TomJobRunState.pending,
        'The next tick picks it up: an expired claim is a run to recover, not '
        'work to mourn',
      );
      assert(
        attemptAfterRecovery == 1,
        'Still attempt 1 — the crash was the scheduler\'s, so it is not charged '
        'to the job\'s retry budget',
      );
    } finally {
      dir.deleteSync(recursive: true);
    }
  }
}

// =============================================================================
// EXAMPLE 3: A Lease Outlives The Process That Took It
// =============================================================================

/// The lock the file store is meant to be paired with, in the same failure
/// domain as the queue: a filesystem, no database required.
///
/// A lease is a fact on disk, not a fact in memory. That is what makes it worth
/// anything — an in-memory lock held by a process that has died is not a lock,
/// it is an empty map. Here the holder disappears and the lease is still there,
/// still attributed, still blocking, and still counting.
class FileLeaseLockExample {
  static int? firstToken;
  static bool heldAfterRestart = false;
  static String? ownerAfterRestart;
  static bool refusedWhileLive = false;
  static int? tokenAfterTakeover;

  static Future<void> example3ALeaseOutlivesItsProcess() async {
    final dir = _scratch();
    try {
      final locks = '${dir.path}/locks';
      final clock = FakeClock(DateTime.utc(2026, 3, 2, 10));
      const ttl = Duration(minutes: 1);

      // --- First process takes the lease, then dies ------------------------
      final firstLock = TomFileLeaseLock(locks, clock: clock.call);
      final held = (await firstLock.acquire('job:reconcile', 'node-a', ttl))!;
      firstToken = held.token;
      // No `release` — that is the point. A clean shutdown releases; a crash
      // does not, and the crash is the case a TTL exists for. `close()` is not
      // a release and does not pretend to be: for a file lock it has nothing to
      // free, because the lease was never in this object to begin with.
      firstLock.close();

      // --- Second process, over the same directory --------------------------
      final secondLock = TomFileLeaseLock(locks, clock: clock.call);
      final info = await secondLock.inspect('job:reconcile');
      heldAfterRestart = info.isHeld;
      ownerAfterRestart = info.lease?.owner;

      // Thirty seconds in, the lease has not lapsed, so node-b is refused. A
      // lock that let a newcomer through here would be a lock in name only:
      // node-a might be slow rather than dead, and nothing yet distinguishes
      // the two.
      clock.advance(const Duration(seconds: 30));
      refusedWhileLive =
          await secondLock.acquire('job:reconcile', 'node-b', ttl) == null;

      // Past the TTL, node-a is gone by definition and the resource must not
      // stay blocked forever.
      clock.advance(const Duration(minutes: 1));
      final takeover = await secondLock.acquire('job:reconcile', 'node-b', ttl);
      tokenAfterTakeover = takeover?.token;

      secondLock.close();

      assert(firstToken == 1, 'Fencing tokens start at 1');
      assert(
        heldAfterRestart && ownerAfterRestart == 'node-a',
        'The lease survived the process that took it, and still names its '
        'holder. An in-memory lock would have forgotten both, which is why a '
        'file-backed queue wants a file-backed lock rather than a memory one '
        'beside it',
      );
      assert(
        refusedWhileLive,
        'A live lease blocks, even though its holder is unreachable — being '
        'unreachable and being dead are the same thing from here, and the TTL '
        'is the only thing entitled to decide',
      );
      assert(
        tokenAfterTakeover == 2,
        'And the token kept counting across the restart. It is monotonic per '
        'resource, not per process, so a fenced resource (sample 04, example 4) '
        'can still tell a displaced holder from the current one after a whole '
        'node has been replaced',
      );
    } finally {
      dir.deleteSync(recursive: true);
    }
  }
}

// =============================================================================
// EXAMPLE 4: Why The File Pair Is A Pair
// =============================================================================

/// The limitation that makes the lock non-optional here, run rather than
/// warned about.
///
/// `TomFileJobStore` claims a run by rewriting the queue file, and two processes
/// doing that at once do not see each other in time. The claim is durable but it
/// is **not atomic between processes** — so on a shared mount two nodes can both
/// come away believing they own the same window. This is not a bug being
/// tolerated; it is the reason the substrate table pairs this store with a lock,
/// and the reason a cluster should take the relational pair from
/// `tom_core_server` instead.
class ClaimIsNotAtomicExample {
  static bool bothClaimed = false;
  static String? leaseWinner;
  static bool loserRefused = false;

  static Future<void> example4WhyTheFilePairIsAPair() async {
    final dir = _scratch();
    try {
      final path = '${dir.path}/queue.json';
      final clock = FakeClock(DateTime.utc(2026, 3, 2, 10));
      final window = DateTime.utc(2026, 3, 2, 10);

      // One queue, seeded once.
      final seed = TomFileJobStore(path);
      await seed.enqueue(
        TomJobRun(
          id: 'run-1',
          jobName: 'reconcile',
          scheduledFor: window,
          runAt: window,
        ),
      );

      // Two stores over that one file — two processes on a shared mount. Both
      // are constructed before either claims, which is the whole of the race:
      // each loaded the queue while the run was still pending.
      final nodeA = TomFileJobStore(path);
      final nodeB = TomFileJobStore(path);

      final claimedByA = await nodeA.claimDue(window, 'node-a');
      final claimedByB = await nodeB.claimDue(window, 'node-b');
      bothClaimed = claimedByA.length == 1 && claimedByB.length == 1;

      // The lock is the arbiter the store cannot be. Both nodes ask for the same
      // resource; exactly one is told yes, and the other hands its claim back
      // rather than running a body it does not own.
      final lock = TomFileLeaseLock('${dir.path}/locks', clock: clock.call);
      const ttl = Duration(minutes: 1);
      final aGot = await lock.acquire('job:reconcile', 'node-a', ttl);
      final bGot = await lock.acquire('job:reconcile', 'node-b', ttl);
      leaseWinner = aGot?.owner ?? bGot?.owner;
      loserRefused = (aGot == null) != (bGot == null);
      lock.close();

      assert(
        bothClaimed,
        'Both nodes claimed the same run. Shown rather than warned about, '
        'because "the claim is not atomic between processes" reads like a '
        'footnote until you watch it happen',
      );
      assert(
        leaseWinner == 'node-a',
        'The lease, unlike the claim, is decided by an exclusive create — one '
        'winner, and the filesystem picks it',
      );
      assert(
        loserRefused,
        'Exactly one of the two was refused. That is what makes the file pair a '
        'pair: the store makes the queue durable, the lock makes the claim '
        'mean something, and neither does the other\'s job',
      );
    } finally {
      dir.deleteSync(recursive: true);
    }
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

Future<void> run() async {
  print('=== 05: Durable Store Example ===\n');

  await QueueOutlivesProcessExample.example1AQueueOutlivesItsProcess();
  print('1. A planned window outlives the process that planned it:');
  print('   json array   : ${QueueOutlivesProcessExample.fileIsJsonArray}');
  print('   rows on disk : ${QueueOutlivesProcessExample.rowsOnDisk}');
  print('   planned id   : ${QueueOutlivesProcessExample.plannedId}');
  print('   executed id  : ${QueueOutlivesProcessExample.executedId}');
  print('   what ran     : ${QueueOutlivesProcessExample.ran}');
  print('');

  await InFlightRunSurvivesExample.example2AnInFlightRunComesBack();
  print('2. An in-flight run comes back as an expired claim:');
  print('   rows       : ${InFlightRunSurvivesExample.rowsAfterRestart}');
  print('   state      : ${InFlightRunSurvivesExample.stateAfterRestart}');
  print('   claimed by : ${InFlightRunSurvivesExample.claimedByAfterRestart}');
  print('   startedAt  : ${InFlightRunSurvivesExample.startedAtSurvived}');
  print('   recovered  : ${InFlightRunSurvivesExample.stateAfterRecovery}');
  print('   attempt    : ${InFlightRunSurvivesExample.attemptAfterRecovery}');
  print('');

  await FileLeaseLockExample.example3ALeaseOutlivesItsProcess();
  print('3. A lease outlives the process that took it:');
  print('   first token        : ${FileLeaseLockExample.firstToken}');
  print('   held after restart : ${FileLeaseLockExample.heldAfterRestart}');
  print('   owner              : ${FileLeaseLockExample.ownerAfterRestart}');
  print('   refused while live : ${FileLeaseLockExample.refusedWhileLive}');
  print('   token on takeover  : ${FileLeaseLockExample.tokenAfterTakeover}');
  print('');

  await ClaimIsNotAtomicExample.example4WhyTheFilePairIsAPair();
  print('4. Why the file pair is a pair:');
  print('   both claimed the run : ${ClaimIsNotAtomicExample.bothClaimed}');
  print('   lease winner         : ${ClaimIsNotAtomicExample.leaseWinner}');
  print('   loser refused        : ${ClaimIsNotAtomicExample.loserRefused}');
  print('');
}

Future<void> main() {
  prepareSampleProcess();
  return run();
}

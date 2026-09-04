/// One node of the cluster demonstration.
///
/// Started twice per scenario by `run_cluster_demo.sh`, with a different
/// `--node` and `--scenario` each time. Every node reports what it observed as
/// JSON lines on stdout; `cluster_verify.dart` turns those reports plus the
/// database's final state into the four assertions.
///
/// ```
/// dart run example/scheduling/cluster/cluster_node.dart \
///     --node=node-a --scenario=steady --seconds=6
/// ```
///
/// A node never asserts anything about the *cluster*. It cannot: each one sees
/// only its own half. Keeping the judgement in a third process is what makes the
/// demonstration an assertion rather than a narration — a node cannot report
/// success for behaviour it did not observe.
library;

import 'dart:async';
import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

import 'cluster_support.dart';

/// How often every polling loop in this file looks again.
const Duration _poll = Duration(milliseconds: 200);

/// The ceiling on any wait. A scenario that has not reached its point by now is
/// broken, and hanging forever would make the runner's timeout the only
/// diagnosis available.
const Duration _patience = Duration(seconds: 60);

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  final dsi = await connect();

  try {
    switch (options.scenario) {
      case 'steady':
        await _steady(options, dsi.datasource);
      case 'fence-holder':
        await _fenceHolder(options, dsi.datasource);
      case 'fence-taker':
        await _fenceTaker(options, dsi.datasource);
      case 'takeover-victim':
        await _takeoverVictim(options, dsi.datasource);
      case 'takeover-survivor':
        await _takeoverSurvivor(options, dsi.datasource);
      case 'rollcall-quitter':
        await _rollcallQuitter(options, dsi.datasource);
      case 'rollcall-watcher':
        await _rollcallWatcher(options, dsi.datasource);
      default:
        stderr.writeln('Unknown scenario "${options.scenario}".');
        exit(2);
    }
  } finally {
    await disconnect();
  }
}

// =============================================================================
// 1. SINGLE FIRE — one schedule, two nodes, N windows, N executions
// =============================================================================

/// Runs a real [TomScheduler] against the shared database for a fixed time.
///
/// Both nodes register the *same* job on the same interval and tick far faster
/// than the schedule fires, so every window is contended. Two distinct
/// mechanisms keep the total honest, and the scenario is shaped to exercise
/// both:
///
///  * The unique key on `(job_name, scheduled_for)` makes a window a single
///    row, and `claimDue` a guarded update of it. Two nodes reaching for the
///    same window means one claim and one refusal.
///  * The coordination lease on `job:<name>` makes the *job* single-flight
///    across the cluster, which the row cannot do — a second window is a
///    second row, and nothing about that row knows the first is still running.
///
/// The second only comes under load when a window is still executing as the
/// next falls due, which is why the body takes longer than the interval. Left
/// fast, the queue row would answer every question on its own and the lease
/// would sit untested behind it.
///
/// The node reports one `executed` event per *body invocation*. That is the
/// number the claim is about — the database holds one row per window whether the
/// body ran once or twice, so counting rows could never detect a double fire.
Future<void> _steady(_Options options, TomDataSource datasource) async {
  final roll = TomSqlSchedulerNodes(
    datasource,
    nodeId: options.node,
    checkinInterval: const Duration(seconds: 1),
    createSchema: false,
  );
  final store = TomSqlJobStore(datasource, createSchema: false, nodes: roll);
  final lock = TomSqlLeaseLock(datasource, createSchema: false);

  // Start together, or the demonstration is two nodes taking turns being the
  // only one awake — under which single-fire is true but untested.
  await _awaitPeer(roll, options.requirePeer());

  final scheduler = TomScheduler(
    store: store,
    dispatcher: const TomInlineJobDispatcher(),
    ownerId: options.node,
    lock: lock,
    tickInterval: _poll,
    // No jitter: the two nodes should collide on purpose. Jitter exists to stop
    // a cluster stampeding a database, and here the stampede is the experiment.
    tickJitter: 0,
    leaseTtl: const Duration(seconds: 6),
    leaseRenewInterval: const Duration(seconds: 2),
    leaseTimeout: const Duration(seconds: 30),
    // The losing side of every arbitration. Without it, a node that was
    // contended out of every window and a node that was never running at all
    // leave identical logs — silence — and the claim would rest on the absence
    // of evidence. `lockContended` is that node saying "I wanted this window
    // and the lease said no", which is the mechanism itself reporting.
    onAlert: (alert) => emit(options.node, 'steady', 'alert', {
      'kind': alert.kind.name,
      'job': alert.jobName,
      'window': alert.run?.scheduledFor.toIso8601String(),
      'heldBy': alert.lease?.owner,
    }),
  );

  scheduler.register(
    TomJobDefinition(
      name: heartbeatJob,
      schedule: TomIntervalSchedule(const Duration(seconds: 1)),
      body: (run) => _ReportWindow(options.node, run.scheduledFor),
    ),
  );

  await scheduler.start();
  await Future<void>.delayed(options.duration);
  scheduler.close();
  // The tick that is already in flight when close() returns may still be
  // completing a run. Wait out longer than one body, so a run that fired is
  // finished and recorded before the process exits — otherwise it stays
  // `running` in the queue and the verifier reads a truncated log.
  await Future<void>.delayed(const Duration(seconds: 3));
  emit(options.node, options.scenario, 'finished');
}

/// The job body: it reports the window it was invoked for, then takes its time.
///
/// Slower than the schedule's interval on purpose. It puts the job's
/// `allowOverlap: false` under real pressure — the next window falls due while
/// this one is still running, so the peer claims that row, finds the job's lease
/// held, and hands the claim straight back. A body that returned immediately
/// would leave that path unexercised and the lease unproven.
class _ReportWindow extends TomCommand {
  _ReportWindow(this.node, this.window);

  final String node;
  final DateTime window;

  @override
  Future<Object?> execute() async {
    emit(node, 'steady', 'executed', {'window': window.toIso8601String()});
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return 'ok';
  }
}

// =============================================================================
// 2. THE FENCING TOKEN — a stalled node's stale write is refused
// =============================================================================

/// Acquires the lease, writes under it, stalls past its expiry, then tries again.
///
/// The stall is the whole scenario. A node that is *killed* can do no harm — it
/// is gone. The dangerous node is the one that is merely stopped: descheduled,
/// in a long GC pause, or blocked on a socket that has not yet timed out. It
/// wakes up still holding an object it believes is a valid lease, and without a
/// fence its next write silently overwrites the work of whoever replaced it.
///
/// So this node does not die. It sleeps past its TTL and then does exactly what
/// a woken node would do: renew, and write.
Future<void> _fenceHolder(_Options options, TomDataSource datasource) async {
  final lock = TomSqlLeaseLock(datasource, createSchema: false);
  const ttl = Duration(seconds: 8);

  final lease = await lock.acquire(fencedResource, options.node, ttl);
  if (lease == null) {
    stderr.writeln('The holder could not take an uncontended lease.');
    exit(1);
  }
  emit(options.node, options.scenario, 'acquired', {'token': lease.token});

  emit(options.node, options.scenario, 'write', {
    'token': lease.token,
    'accepted': await fencedWrite(datasource, options.node, lease.token),
  });

  // Stalled — and deliberately not renewing. The lease lapses at +8s; the peer
  // takes it over; this node sleeps on to +16s in blissful ignorance.
  await Future<void>.delayed(const Duration(seconds: 16));

  // Awake, and still holding a lease object that is now worthless. Both of the
  // next two are refused by the database, and neither refusal needs this node's
  // cooperation — which is the point, because a node in this state cannot be
  // relied on to cooperate.
  final renewed = await lock.renew(lease, ttl);
  emit(options.node, options.scenario, 'late-renew', {
    'token': lease.token,
    'renewed': renewed != null,
  });

  emit(options.node, options.scenario, 'late-write', {
    'token': lease.token,
    'accepted': await fencedWrite(datasource, options.node, lease.token),
  });
}

/// Waits for the peer to hold the lease, is refused until it lapses, then takes
/// it over and writes under the higher token.
Future<void> _fenceTaker(_Options options, TomDataSource datasource) async {
  final lock = TomSqlLeaseLock(datasource, createSchema: false);

  // Do not start racing before there is anything to race. Starting early would
  // let this node win the *uncontended* lease and invert the scenario.
  final held = await _awaitCondition(() async {
    final info = await lock.inspect(fencedResource);
    return info.isHeld && info.lease!.owner != options.node ? info : null;
  }, 'the peer to take the lease');
  emit(options.node, options.scenario, 'observed-holder', {
    'owner': held.lease!.owner,
    'token': held.lease!.token,
  });

  // Every one of these refusals is a `null` from the database, not a thrown
  // error: a contended acquire is an ordinary answer, not an exception.
  var refusals = 0;
  final lease = await _awaitCondition(() async {
    final taken = await lock.acquire(
      fencedResource,
      options.node,
      const Duration(minutes: 5),
    );
    if (taken == null) refusals++;
    return taken;
  }, 'the peer\'s lease to lapse');
  emit(options.node, options.scenario, 'acquired', {
    'token': lease.token,
    'refusals': refusals,
  });

  emit(options.node, options.scenario, 'write', {
    'token': lease.token,
    'accepted': await fencedWrite(datasource, options.node, lease.token),
  });

  // The lease is kept, not released. The holder is about to wake up and try to
  // renew, and "a released lease is renewable again" would hide the refusal the
  // scenario is here to show.
}

// =============================================================================
// 3. TAKEOVER — a killed node's run is recovered after the lease, not before
// =============================================================================

/// Claims a run, starts it, and then hangs until the runner kills it.
///
/// It marks the run *started* on purpose. A run claimed and never started is
/// always re-queued, because nothing executed and nothing can therefore repeat;
/// a run interrupted mid-execution is re-queued only when its job opted in. The
/// harder of the two is the one worth demonstrating, so the survivor supplies
/// that opt-in explicitly.
Future<void> _takeoverVictim(_Options options, TomDataSource datasource) async {
  final store = TomSqlJobStore(datasource, createSchema: false);
  final window = DateTime.now().toUtc();

  await store.enqueue(
    TomJobRun(
      id: 'takeover-run',
      jobName: takeoverJob,
      scheduledFor: window,
      runAt: window,
    ),
  );

  // `claimDue` is a *queue* operation, not a per-job one — it hands back
  // everything that is due, which here includes heartbeat windows the steady
  // phase scheduled and never got to. Keep the one this scenario is about and
  // hand the rest straight back, exactly as the scheduler does when it claims a
  // run it turns out not to be able to execute. Sitting on them instead would
  // leave runs abandoned by a node that is about to be killed, and the survivor
  // would then recover several things and have to guess which one mattered.
  final claimed = await store.claimDue(window, options.node);
  final ours = claimed.where((c) => c.run.jobName == takeoverJob).toList();
  for (final other in claimed.where((c) => c.run.jobName != takeoverJob)) {
    await store.release(other);
  }
  if (ours.length != 1) {
    stderr.writeln(
      'The victim expected to claim exactly one $takeoverJob run, '
      'got ${ours.length}.',
    );
    exit(1);
  }
  // The ticket, not the run: every transition is fenced on it, so it is what
  // has to be carried. See `TomJobClaim`.
  final claim = ours.single;
  await store.markStarted(claim, DateTime.now().toUtc());
  emit(options.node, options.scenario, 'claimed', {
    'runId': claim.id,
    'claimedAt': claim.run.claimedAt!.toIso8601String(),
  });

  // Hangs. The runner reads the line above, kills this process, and the run is
  // left `running` with a lease nobody will ever renew.
  await Completer<void>().future;
}

/// Polls recovery until the abandoned run comes back, timing every attempt.
///
/// It is started *alongside* the victim rather than after it, so it is already
/// warm when the kill lands and its first attempt falls inside the lease. A
/// survivor booted afterwards spends the lease's whole duration compiling, and
/// could then only report that recovery had happened by the time it looked —
/// which says nothing about what gated it.
///
/// Its store is built **without** a roll call. That is the load-bearing detail:
/// with one, a departed node is noticed within a poll interval and the run comes
/// back early — which is a feature, but it would make "not before the lease
/// expires" untestable, because something else would have decided first. Here
/// the lease timeout is the only signal, so the elapsed time at recovery is a
/// statement about the lease and nothing else.
Future<void> _takeoverSurvivor(
  _Options options,
  TomDataSource datasource,
) async {
  final store = TomSqlJobStore(datasource, createSchema: false);
  final leaseTimeout = options.leaseTimeout;

  // Wait for the victim to be holding the run, and take the claim instant from
  // the database rather than from the clock — every elapsed figure this scenario
  // reports is then measured from the same stamp the store's own recovery
  // predicate compares against.
  final claimed = await _awaitCondition(() async {
    final runs = await store.all();
    for (final run in runs) {
      if (run.jobName == takeoverJob &&
          run.state == TomJobRunState.running &&
          run.claimedBy != null &&
          run.claimedBy != options.node) {
        return run;
      }
    }
    return null;
  }, 'the victim to claim the run');
  final claimedAt = claimed.claimedAt!;
  emit(options.node, options.scenario, 'observed-claim', {
    'runId': claimed.id,
    'claimedBy': claimed.claimedBy,
    'claimedAt': claimedAt.toIso8601String(),
    'leaseTimeoutMs': leaseTimeout.inMilliseconds,
  });

  final deadline = DateTime.now().add(_patience);
  while (DateTime.now().isBefore(deadline)) {
    final now = DateTime.now().toUtc();
    final recovered = await store.recoverAbandoned(
      now,
      leaseTimeout,
      // The opt-in the victim's mid-execution interruption needs. Without it the
      // store would write the run off as `failed` instead of re-queueing it —
      // also correct, and a different demonstration.
      requestsRecovery: (jobName) => jobName == takeoverJob,
    );
    // Recovery is a queue-wide sweep, so it may also pick up leftovers from
    // earlier phases. Only this scenario's run is evidence about this scenario.
    final ours = recovered.where((r) => r.jobName == takeoverJob).toList();
    final elapsed = now.difference(claimedAt);
    emit(options.node, options.scenario, 'attempt', {
      'elapsedMs': elapsed.inMilliseconds,
      'recovered': ours.length,
    });
    if (ours.isNotEmpty) {
      emit(options.node, options.scenario, 'recovered', {
        'runId': ours.single.id,
        'elapsedMs': elapsed.inMilliseconds,
        'state': ours.single.state.name,
      });
      return;
    }
    await Future<void>.delayed(_poll);
  }

  stderr.writeln('The survivor never recovered the abandoned run.');
  exit(1);
}

// =============================================================================
// 4. THE ROLL CALL — a node that stops checking in is named
// =============================================================================

/// Checks in a fixed number of times and leaves.
///
/// Leaving without removing its own row is the case that matters. A node that
/// calls `forget` on the way out is a tidy shutdown and proves nothing; the roll
/// call exists for the node that does not get the chance.
Future<void> _rollcallQuitter(
  _Options options,
  TomDataSource datasource,
) async {
  final roll = _rollCall(datasource, options.node);
  await _awaitPeer(roll, options.requirePeer());

  for (var index = 0; index < options.checkins; index++) {
    final now = DateTime.now().toUtc();
    await roll.checkIn(now);
    emit(options.node, options.scenario, 'checkin', {
      'index': index,
      'at': now.toIso8601String(),
    });
    // Spaced wider than the watcher's polling, so the watcher observes the row
    // *changing* rather than a single timestamp several times. "Rewritten, not
    // appended" is a claim about a row that moves, and a run in which the peer
    // only ever showed one instant could not distinguish the two.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
  emit(options.node, options.scenario, 'left');
}

/// Keeps checking in, and watches for the peer to be declared failed.
///
/// Reports the roster on every pass. The count of rows carrying the peer's id is
/// the "rewritten, not appended" half of the claim: the peer checks in many
/// times and must never occupy more than one row.
Future<void> _rollcallWatcher(
  _Options options,
  TomDataSource datasource,
) async {
  final roll = _rollCall(datasource, options.node);
  final peer = options.requirePeer();
  await _awaitPeer(roll, peer);

  final deadline = DateTime.now().add(_patience);
  while (DateTime.now().isBefore(deadline)) {
    final now = DateTime.now().toUtc();
    await roll.checkIn(now);
    final roster = await roll.nodes();
    final failed = await roll.failedNodes(now);

    emit(options.node, options.scenario, 'roster', {
      'peerRows': roster.where((n) => n.nodeId == peer).length,
      'peerCheckinAt': roster
          .where((n) => n.nodeId == peer)
          .map((n) => n.checkinAt.toIso8601String())
          .firstOrNull,
    });

    // A process cannot conclude its own death, and `failedNodes` is documented
    // to exclude the asking node. Reported rather than assumed, because it is a
    // real regression risk: the exclusion is one `!=` in one predicate.
    if (failed.any((n) => n.nodeId == options.node)) {
      emit(options.node, options.scenario, 'self-accused');
    }

    final verdict = failed.where((n) => n.nodeId == peer).firstOrNull;
    if (verdict != null) {
      emit(options.node, options.scenario, 'verdict', {
        'peer': verdict.nodeId,
        'lastCheckinAt': verdict.checkinAt.toIso8601String(),
        'silentMs': now.difference(verdict.checkinAt).inMilliseconds,
        'publishedIntervalMs': verdict.checkinInterval.inMilliseconds,
        'slackMs': roll.slack.inMilliseconds,
      });
      return;
    }
    await Future<void>.delayed(_poll);
  }

  stderr.writeln('The watcher never declared "$peer" failed.');
  exit(1);
}

/// The roll call both roll-call scenarios use.
///
/// A short published interval and a short slack, so the demonstration takes
/// seconds rather than the production-shaped half-minute. Both are deliberate
/// statements of cadence, not tuning knobs: a node must publish an interval no
/// shorter than its scheduler's tick, or it accuses itself of being late every
/// pass.
TomSqlSchedulerNodes _rollCall(TomDataSource datasource, String nodeId) =>
    TomSqlSchedulerNodes(
      datasource,
      nodeId: nodeId,
      checkinInterval: const Duration(seconds: 1),
      slack: const Duration(milliseconds: 500),
      createSchema: false,
    );

// =============================================================================
// SHARED
// =============================================================================

/// Checks in and waits until [peer] has too.
///
/// The roll call is the demonstration's start barrier, which is fortunate rather
/// than clever: it is already the table that answers "who else is here", so
/// nothing extra has to exist for the two processes to meet. Two processes
/// started by the same script are *not* otherwise simultaneous — `dart run`
/// cold-compiles, and the second node can be seconds behind the first.
///
/// It waits for a **named** peer rather than for "somebody else", because the
/// roll call outlives the phase that wrote to it: by the last phase the table
/// still carries rows from the first, and "somebody else is here" would be
/// satisfied by a node that has been dead for a minute.
Future<void> _awaitPeer(TomSqlSchedulerNodes roll, String peer) async {
  await roll.checkIn(DateTime.now().toUtc());
  await _awaitCondition(() async {
    await roll.checkIn(DateTime.now().toUtc());
    final present = await roll.nodes();
    return present.any((n) => n.nodeId == peer) ? present : null;
  }, 'peer "$peer" to appear in the roll call');
}

/// Polls [probe] until it returns a non-null value, or gives up.
///
/// Giving up is `exit(1)` rather than a thrown exception because these are the
/// preconditions of a scenario, not its subject: a node that never saw its peer
/// has not disproved anything, it has failed to set the experiment up, and the
/// runner should say so plainly.
Future<T> _awaitCondition<T extends Object>(
  Future<T?> Function() probe,
  String what,
) async {
  final deadline = DateTime.now().add(_patience);
  while (DateTime.now().isBefore(deadline)) {
    final value = await probe();
    if (value != null) return value;
    await Future<void>.delayed(_poll);
  }
  stderr.writeln('Timed out waiting for $what.');
  exit(1);
}

/// The node program's command line.
class _Options {
  const _Options({
    required this.node,
    required this.scenario,
    required this.duration,
    required this.leaseTimeout,
    required this.checkins,
    required this.peer,
  });

  /// Parses `--key=value` arguments.
  factory _Options.parse(List<String> args) {
    final values = <String, String>{};
    for (final arg in args) {
      final split = arg.indexOf('=');
      if (!arg.startsWith('--') || split < 0) {
        stderr.writeln('Arguments must be --key=value; got "$arg".');
        exit(2);
      }
      values[arg.substring(2, split)] = arg.substring(split + 1);
    }
    final node = values['node'];
    final scenario = values['scenario'];
    if (node == null || scenario == null) {
      stderr.writeln('--node and --scenario are required.');
      exit(2);
    }
    return _Options(
      node: node,
      scenario: scenario,
      duration: Duration(seconds: int.parse(values['seconds'] ?? '6')),
      leaseTimeout: Duration(
        milliseconds: int.parse(values['leaseTimeoutMs'] ?? '5000'),
      ),
      checkins: int.parse(values['checkins'] ?? '6'),
      peer: values['peer'] ?? '',
    );
  }

  /// This node's identity — also its `ownerId` and its roll-call `node_id`.
  final String node;

  /// Which scenario to play.
  final String scenario;

  /// How long the steady scenario runs its scheduler.
  final Duration duration;

  /// The lease timeout the takeover survivor recovers against.
  final Duration leaseTimeout;

  /// How many times the roll-call quitter checks in before leaving.
  final int checkins;

  /// The other node of this phase — the barrier waits for it, and the roll-call
  /// watcher watches it.
  final String peer;

  /// [peer], insisting it was supplied.
  ///
  /// The scenarios that need it cannot proceed without it, and an empty peer
  /// would leave them waiting out their patience on a node id that can never
  /// appear — a minute of silence followed by a timeout that names the symptom
  /// rather than the cause.
  String requirePeer() {
    if (peer.isEmpty) {
      stderr.writeln('Scenario "$scenario" requires --peer=<node>.');
      exit(2);
    }
    return peer;
  }
}

/// The judge of the cluster demonstration.
///
/// Run last by `run_cluster_demo.sh`, after every node has exited:
///
/// ```
/// dart run example/scheduling/cluster/cluster_verify.dart --events=<dir>
/// ```
///
/// Reads the nodes' JSON-line testimony from `<dir>/*.jsonl` and the database's
/// final state, then makes the four claims this directory's `readme.md` sets
/// out. Prints one line per check and exits non-zero if any failed.
///
/// ## Why the judge is a third process
///
/// A node sees one half of every claim. Node A can say "I ran window 12:00:03";
/// only something holding both logs can say "and nobody else did". Node B can
/// say "my acquire was refused"; only something that also read the database can
/// say "while the token it was refused under was still the live one". Asking a
/// participant to conclude anything about the cluster would be asking it to
/// vouch for evidence it never saw.
///
/// ## Why every check runs
///
/// Failures are collected, not thrown. Four independent claims break for four
/// independent reasons, and a run that stops at the first one costs a full
/// container cycle to learn about the second.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

import 'cluster_support.dart';

Future<void> main(List<String> args) async {
  final directory = _eventsDirectory(args);
  final events = readEvents(directory);
  if (events.isEmpty) {
    stderr.writeln(
      'No events under ${directory.path}: the nodes produced no '
      'testimony, so there is nothing to verify.',
    );
    exit(1);
  }

  final dsi = await connect();
  final report = _Report();

  try {
    await _verifySingleFire(report, events, dsi.datasource);
    await _verifyFencingToken(report, events, dsi.datasource);
    await _verifyTakeover(report, events, dsi.datasource);
    await _verifyRollCall(report, events, dsi.datasource);
  } finally {
    await disconnect();
  }

  report.print();
  exit(report.failed ? 1 : 0);
}

// =============================================================================
// CLAIM 1 — ONE SCHEDULE, TWO NODES, N WINDOWS, N EXECUTIONS
// =============================================================================

/// Asserts the job fired once per window across the cluster, not once per node.
///
/// The count that carries the claim is **body invocations**, taken from the two
/// nodes' logs. The database cannot supply it: the unique key on
/// `(job_name, scheduled_for)` means one row per window whether the body ran
/// once, twice, or not at all. So the logs answer "how many times did work
/// happen" and the database answers "how many windows were there", and the claim
/// is that those two numbers are the same.
Future<void> _verifySingleFire(
  _Report report,
  List<ClusterEvent> events,
  TomDataSource datasource,
) async {
  const claim = 'single fire';
  final steady = events.where((e) => e.scenario == 'steady').toList();
  final nodes = steady.map((e) => e.node).toSet();
  report.check(
    claim,
    'both nodes ran the scheduler',
    nodes.length == 2,
    'nodes seen: ${nodes.toList()..sort()}',
  );
  report.check(
    claim,
    'both nodes ran to completion',
    steady
            .where((e) => e.name == 'finished')
            .map((e) => e.node)
            .toSet()
            .length ==
        2,
    'a node that died early proves nothing about contention',
  );

  final executions = steady.where((e) => e.name == 'executed').toList();
  final windows = executions.map((e) => e.stringField('window')).toSet();

  // Enough windows to be a demonstration. One execution is not evidence of
  // arbitration; it is evidence that one node was quicker once.
  report.check(
    claim,
    'the job fired often enough to be contended',
    windows.length >= 3,
    '${windows.length} distinct windows executed',
  );

  // The claim itself.
  report.check(
    claim,
    'every window was executed exactly once across the cluster',
    executions.length == windows.length,
    '${executions.length} body invocations over ${windows.length} windows'
        '${_doubleFires(executions)}',
  );

  // ...and that it was *arbitration* that produced that number, not one node
  // quietly failing to run. A node contended out of a window says so; a node
  // that never started says nothing. Without this the strongest evidence for
  // the claim would be a silence that a broken node produces equally well.
  //
  // The refusals come from the coordination lease, not from the queue row: the
  // row makes a *window* singular, while the lease makes the *job* singular
  // across the cluster. Only the second can refuse a node that legitimately
  // claimed the next window while the previous one is still running, and it is
  // the one a job's `allowOverlap: false` rests on cluster-wide.
  final contended = steady
      .where(
        (e) =>
            e.name == 'alert' &&
            e.stringField('kind') == TomJobAlertKind.lockContended.name,
      )
      .toList();
  report.check(
    claim,
    'a node was refused the job lease while its peer was mid-run',
    contended.isNotEmpty,
    'no lockContended alert on either node: the job-wide lease was never '
        'exercised, so single-fire here rests on the queue row alone',
  );
  // A refusal must cost the window a tick, not the work. The refused node hands
  // its claim straight back, so the window returns to the queue and is run by
  // whoever next wins both the row and the lease. A scheduler that dropped the
  // run instead would satisfy every count above — the totals would simply be
  // lower — and lose work silently, which is the failure this catches.
  //
  // At least one, rather than all: a window contended in the final second of
  // the run has nobody left to execute it, and demanding otherwise would make
  // the check a statement about when the demo stops.
  final refusedWindows = contended
      .map((e) => e.stringField('window'))
      .whereType<String>()
      .toSet();
  report.check(
    claim,
    'a window whose lease was refused was still executed, not dropped',
    refusedWindows.any(windows.contains),
    'refused windows ${refusedWindows.toList()} — none of them ran',
  );

  // And the database's half: one row per window, no window duplicated. This is
  // the unique key doing its job, and it would still hold if the lease were
  // broken — which is why it is a separate check and not the claim.
  final runs = (await TomSqlJobStore(
    datasource,
    createSchema: false,
  ).all()).where((r) => r.jobName == heartbeatJob).toList();
  final rowWindows = runs.map((r) => r.scheduledFor.toIso8601String()).toSet();
  report.check(
    claim,
    'the queue holds one row per window',
    runs.length == rowWindows.length && runs.isNotEmpty,
    '${runs.length} rows over ${rowWindows.length} windows',
  );
  report.check(
    claim,
    'every executed window has a row in the queue',
    windows.every(rowWindows.contains),
    'executed windows missing a row: '
        '${windows.where((w) => !rowWindows.contains(w)).toList()}',
  );
}

/// Names the windows that were executed more than once, for the failure detail.
String _doubleFires(List<ClusterEvent> executions) {
  final counts = <String, int>{};
  for (final event in executions) {
    final window = event.stringField('window');
    if (window != null) counts[window] = (counts[window] ?? 0) + 1;
  }
  final doubled = counts.entries.where((e) => e.value > 1).toList();
  if (doubled.isEmpty) return '';
  return '; fired more than once: '
      '${doubled.map((e) => '${e.key} x${e.value}').join(', ')}';
}

// =============================================================================
// CLAIM 2 — A REACQUISITION CARRIES A HIGHER TOKEN, AND THE OLDER ONE IS DEAD
// =============================================================================

/// Asserts the fencing token both increases on takeover and is *load-bearing*.
///
/// A monotonic counter nobody consults is not a fence. So this checks two
/// separate things and would fail on either: that the taker's token is higher
/// than the holder's, and that the holder's write — attempted after its lease
/// lapsed, with the older token in hand — was refused by the database.
Future<void> _verifyFencingToken(
  _Report report,
  List<ClusterEvent> events,
  TomDataSource datasource,
) async {
  const claim = 'fencing token';
  final holder = _phase(events, 'fence-holder');
  final taker = _phase(events, 'fence-taker');

  final acquired = _one(holder, 'acquired');
  final taken = _one(taker, 'acquired');
  if (acquired == null || taken == null) {
    report.check(
      claim,
      'both nodes held the lease in turn',
      false,
      'missing an `acquired` event: the scenario did not run',
    );
    return;
  }

  final firstToken = acquired.intField('token')!;
  final secondToken = taken.intField('token')!;

  report.check(
    claim,
    'the reacquisition carries a higher token',
    secondToken > firstToken,
    'first $firstToken, second $secondToken',
  );
  report.check(
    claim,
    'the second node was refused while the lease was live',
    (taken.intField('refusals') ?? 0) > 0,
    '${taken.intField('refusals')} refusals before it won — zero would mean it '
        'never actually contended',
  );

  report.check(
    claim,
    'the holder\'s write under a live lease was accepted',
    _one(holder, 'write')?.boolField('accepted') == true,
    'the baseline: the fence must not refuse the legitimate holder',
  );
  report.check(
    claim,
    'the taker\'s write under the higher token was accepted',
    _one(taker, 'write')?.boolField('accepted') == true,
    'the new holder must be able to work',
  );

  // The two refusals that matter. Neither needed the stalled node's
  // cooperation, which is the entire value of a fence over a lock.
  report.check(
    claim,
    'the stalled node could not renew its lapsed lease',
    _one(holder, 'late-renew')?.boolField('renewed') == false,
    'a renew of a lease that was taken over must fail',
  );
  report.check(
    claim,
    'the stalled node\'s write under the stale token was refused',
    _one(holder, 'late-write')?.boolField('accepted') == false,
    'this is the claim: a woken node cannot overwrite its successor\'s work',
  );

  // And the database agrees with the logs about who ended up holding what.
  final info = await TomSqlLeaseLock(
    datasource,
    createSchema: false,
  ).inspect(fencedResource);
  report.check(
    claim,
    'the lease record names the second node at the higher token',
    info.lease?.owner == taken.node && info.lease?.token == secondToken,
    'lease: ${info.describe()}',
  );

  final row = await readFencedResource(datasource);
  report.check(
    claim,
    'the fenced resource carries the second node\'s write, not the stale one',
    row != null && row.holder == taken.node && row.fence == secondToken,
    'row: holder=${row?.holder} fence=${row?.fence}, '
        'expected holder=${taken.node} fence=$secondToken',
  );
}

// =============================================================================
// CLAIM 3 — A KILLED NODE'S RUN COMES BACK AFTER THE LEASE, AND NOT BEFORE
// =============================================================================

/// Asserts recovery happened, and that the lease timeout is what gated it.
///
/// "And not before" is the half that is easy to lose. A store that re-queued
/// every `running` run on sight would pass a check that only asked whether the
/// run came back — and would also hand live work to a second node. So the
/// survivor logs an attempt on every pass, and this asserts that the early ones
/// recovered nothing.
Future<void> _verifyTakeover(
  _Report report,
  List<ClusterEvent> events,
  TomDataSource datasource,
) async {
  const claim = 'takeover';
  final survivor = _phase(events, 'takeover-survivor');
  final observed = _one(survivor, 'observed-claim');
  final recovered = _one(survivor, 'recovered');
  if (observed == null || recovered == null) {
    report.check(
      claim,
      'the abandoned run was recovered',
      false,
      'missing `observed-claim` or `recovered`: the scenario did not run',
    );
    return;
  }

  final leaseTimeoutMs = observed.intField('leaseTimeoutMs')!;
  final attempts = survivor.where((e) => e.name == 'attempt').toList();
  final early = attempts
      .where((e) => (e.intField('elapsedMs') ?? 0) < leaseTimeoutMs)
      .toList();

  report.check(
    claim,
    'the victim held the run before it died',
    observed.stringField('claimedBy') != null &&
        observed.stringField('claimedBy') != recovered.node,
    'claimed by ${observed.stringField('claimedBy')}',
  );
  report.check(
    claim,
    'recovery was attempted before the lease expired',
    early.isNotEmpty,
    'no attempt landed inside the ${leaseTimeoutMs}ms lease — the timing of '
        'the recovery is then unproven, not proven',
  );
  report.check(
    claim,
    'nothing was recovered while the lease was still live',
    early.every((e) => e.intField('recovered') == 0),
    'attempts inside the lease that recovered anything: '
        '${early.where((e) => e.intField('recovered') != 0).map((e) => e.fields).toList()}',
  );
  report.check(
    claim,
    'the run was recovered only after the lease expired',
    (recovered.intField('elapsedMs') ?? 0) >= leaseTimeoutMs,
    'recovered at ${recovered.intField('elapsedMs')}ms, '
        'lease ${leaseTimeoutMs}ms',
  );
  report.check(
    claim,
    'the recovered run went back to the queue rather than being written off',
    recovered.stringField('state') == TomJobRunState.pending.name,
    'state ${recovered.stringField('state')} — `failed` would mean the job\'s '
        'recovery opt-in was not honoured',
  );

  // The database's own account: runnable again, and held by nobody.
  final runs = await TomSqlJobStore(datasource, createSchema: false).all();
  final run = runs
      .where((r) => r.id == recovered.stringField('runId'))
      .firstOrNull;
  report.check(
    claim,
    'the queue holds the run pending and unclaimed',
    run != null &&
        run.state == TomJobRunState.pending &&
        run.claimedBy == null &&
        run.claimedAt == null,
    'row: state=${run?.state.name} claimedBy=${run?.claimedBy}',
  );
  // `attempt` is 1-based: a run that has never been retried sits at 1, and the
  // run was claimed exactly once before its node died.
  report.check(
    claim,
    'recovery did not charge the dead node\'s crash to the job\'s retry budget',
    run != null && run.attempt == 1,
    'attempt=${run?.attempt}, expected 1 — a crash loop must not consume the '
        'retries a real failure is entitled to',
  );
}

// =============================================================================
// CLAIM 4 — A NODE THAT STOPS CHECKING IN IS NAMED, FROM ONE ROW PER NODE
// =============================================================================

/// Asserts the roll call names the departed node, and only for the right reason.
///
/// Three things have to hold together, and each fails differently: the quitter
/// occupied exactly one row however many times it checked in; the watcher never
/// accused *itself*; and the accusation, when it came, was later than the peer's
/// own published interval plus the configured slack. The last is what separates
/// "noticed it was gone" from "gave up on it too early", which is the failure
/// mode that steals live work from a node that was merely busy.
Future<void> _verifyRollCall(
  _Report report,
  List<ClusterEvent> events,
  TomDataSource datasource,
) async {
  const claim = 'roll call';
  final quitter = _phase(events, 'rollcall-quitter');
  final watcher = _phase(events, 'rollcall-watcher');
  final checkins = quitter.where((e) => e.name == 'checkin').toList();
  final rosters = watcher.where((e) => e.name == 'roster').toList();
  final verdict = _one(watcher, 'verdict');

  report.check(
    claim,
    'the departing node checked in repeatedly before leaving',
    checkins.length >= 3 && _one(quitter, 'left') != null,
    '${checkins.length} check-ins, left=${_one(quitter, 'left') != null}',
  );

  // Rewritten, not appended: many check-ins, one row, throughout.
  report.check(
    claim,
    'the peer occupied exactly one row on every observation',
    rosters.isNotEmpty && rosters.every((e) => e.intField('peerRows') == 1),
    '${rosters.length} observations, row counts '
        '${rosters.map((e) => e.intField('peerRows')).toSet().toList()}',
  );
  report.check(
    claim,
    'the row was rewritten as the peer checked in, not left stale',
    rosters
            .map((e) => e.stringField('peerCheckinAt'))
            .whereType<String>()
            .toSet()
            .length >
        1,
    'a single distinct check-in timestamp would mean the row stopped tracking',
  );

  report.check(
    claim,
    'no node ever declared itself failed',
    !events.any((e) => e.name == 'self-accused'),
    'a scheduler that fails itself takes its own live work away',
  );

  if (verdict == null) {
    report.check(
      claim,
      'the departed node was declared failed',
      false,
      'no `verdict` event: the watcher never named its peer',
    );
    return;
  }

  report.check(
    claim,
    'the departed node was declared failed',
    verdict.stringField('peer') == checkins.firstOrNull?.node,
    'named ${verdict.stringField('peer')}',
  );

  final silent = verdict.intField('silentMs')!;
  final threshold =
      verdict.intField('publishedIntervalMs')! + verdict.intField('slackMs')!;
  report.check(
    claim,
    'the verdict waited out the peer\'s own interval plus the slack',
    silent >= threshold,
    'silent for ${silent}ms against a ${threshold}ms floor — declaring a node '
        'failed sooner than it promised to speak is a false positive',
  );

  // The table's final state: the departed node is still on the roll, still one
  // row. `failedNodes` is a *judgement over* the roll call, not a deletion from
  // it — a node that vanished must remain visible, or an operator has no record
  // that it was ever there.
  final roll = TomSqlSchedulerNodes(
    datasource,
    nodeId: 'verifier',
    createSchema: false,
  );
  final rows = await roll.nodes();
  report.check(
    claim,
    'the departed node is still on the roll, in exactly one row',
    rows.where((n) => n.nodeId == verdict.stringField('peer')).length == 1,
    'rows for the peer: '
        '${rows.where((n) => n.nodeId == verdict.stringField('peer')).length}',
  );
}

// =============================================================================
// SUPPORT
// =============================================================================

/// Every event of one scenario, in the order the nodes reported them.
List<ClusterEvent> _phase(List<ClusterEvent> events, String scenario) =>
    events.where((e) => e.scenario == scenario).toList();

/// The first event named [name], or `null` when the scenario never got there.
///
/// `null` rather than a throw: a missing event is a *failed check* with a
/// readable message, not a crash inside the judge.
ClusterEvent? _one(List<ClusterEvent> events, String name) =>
    events.where((e) => e.name == name).firstOrNull;

/// The `--events=<dir>` argument, which must name an existing directory.
Directory _eventsDirectory(List<String> args) {
  const prefix = '--events=';
  final arg = args.where((a) => a.startsWith(prefix)).firstOrNull;
  if (arg == null) {
    stderr.writeln('Usage: cluster_verify.dart --events=<directory>');
    exit(2);
  }
  final directory = Directory(arg.substring(prefix.length));
  if (!directory.existsSync()) {
    stderr.writeln('No such events directory: ${directory.path}');
    exit(2);
  }
  return directory;
}

/// Collects check results so every claim is judged, then reported together.
class _Report {
  final List<_Result> _results = [];

  /// Whether any check failed.
  bool get failed => _results.any((r) => !r.ok);

  /// Records one check. [detail] is printed only when it fails, and should say
  /// what was actually observed — a bare "expected true" costs another run.
  void check(String claim, String description, bool ok, [String detail = '']) {
    _results.add(_Result(claim, description, ok, detail));
  }

  /// Prints the results grouped by claim, and a final tally.
  void print() {
    var claim = '';
    for (final result in _results) {
      if (result.claim != claim) {
        claim = result.claim;
        stdout.writeln('\n${claim.toUpperCase()}');
      }
      stdout.writeln('  ${result.ok ? 'ok  ' : 'FAIL'}  ${result.description}');
      if (!result.ok && result.detail.isNotEmpty) {
        stdout.writeln('        ${result.detail}');
      }
    }
    final failures = _results.where((r) => !r.ok).length;
    stdout.writeln(
      '\n${_results.length - failures}/${_results.length} checks passed.',
    );
    if (failures > 0) {
      stdout.writeln('$failures failed — the cluster behaviour regressed.');
    }
  }
}

/// One judged check.
class _Result {
  const _Result(this.claim, this.description, this.ok, this.detail);

  /// Which of the four claims it belongs to.
  final String claim;

  /// What was checked, phrased as the thing that is true when it passes.
  final String description;

  /// Whether it held.
  final bool ok;

  /// What was observed, printed on failure.
  final String detail;
}

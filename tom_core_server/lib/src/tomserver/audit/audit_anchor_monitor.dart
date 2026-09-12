/// Reading anchors back: the periodic check that turns a published anchor into
/// a detection, and the seam a finding travels along.
///
/// ## Why this is a `TomScheduler` job where publication is a `Timer`
///
/// [TomAuditAnchorPublisher] deliberately runs per process, because the chain
/// is per writer and each node must anchor its own head. Verification has the
/// opposite shape and therefore the opposite answer. It is a *read* over a
/// chain that already exists, it concludes the same thing whichever node asks,
/// and it is idempotent — which is precisely what the scheduler's
/// at-least-once guarantee wants. Running it on every node would multiply the
/// read cost by the cluster size and the alerts by the same factor, with no
/// extra coverage: a divergence one node sees, every node sees.
///
/// So [TomAuditAnchorVerificationJob] ships as a `@TomScheduledJob`, and the
/// audit module gains a dependency on the scheduler being installed that it
/// did not have before. That is the cost of the decision and it is paid
/// explicitly: a deployment that does not run a scheduler can still call
/// [TomAuditAnchorMonitor.verifyAll] from whatever runner it has.
///
/// ## Why the writers are declared rather than discovered
///
/// A verifier running once across the cluster has to know which chains to
/// check, and the tempting answer — enumerate them from the anchor store — has
/// a hole in exactly the shape of the attack. A store enumeration finds the
/// writers that have published at least once, so a node that never anchored
/// is invisible to it, and *that silence is the finding*: an unanchored chain
/// is the one a rewrite leaves no evidence of.
///
/// [TomAuditAnchorMonitor] therefore takes the chains it is to watch, and
/// reports [TomAuditAnchorCheckFailure.neverAnchored] for a declared writer the
/// store has nothing for. The deployment states what it expects to exist; the
/// monitor reports the difference between that and what it finds.
///
/// ## Why the chain is read through a supplied callback
///
/// Reading a trail back is per sink by design — `TomAuditSink` has no read
/// member, and `TomSqlAuditSink.readAll` says so on itself. A monitor that
/// wanted to read chains generically would have to invent the interface that
/// module deliberately does not have. So each watched chain carries a
/// [TomAuditChainReader], and the deployment supplies the read its own sink
/// offers.
///
/// ## What a finding reaches
///
/// Two things, and both ship: every finding is logged, and every finding is
/// handed to the caller's [TomAuditAnchorMonitor.onFinding]. The log is the
/// channel that always exists and the callback is the one that can do
/// something — route to the messaging outbox, fail a health check, page
/// somebody. The framework does not pick between those, because which of them
/// is right is a property of the deployment and not of the trail.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'audit_anchor.dart';
import 'audit_anchor_store.dart';
import 'audit_sink.dart';

// =============================================================================
// WHAT IS WATCHED
// =============================================================================

/// Reads back the retained entries of one chain, oldest first.
///
/// May return a *suffix* — retention prunes from the front — which
/// [verifyAgainstAnchor] handles by comparing on [TomAuditEntry.index] rather
/// than on position in the list.
typedef TomAuditChainReader = Future<List<TomAuditEntry>> Function();

/// One chain the deployment expects to exist, and how to read it back.
class TomAuditWatchedChain {
  /// The chain's name, matching the writer identity its anchors carry.
  final String writer;

  /// Reads this chain's retained entries.
  final TomAuditChainReader read;

  /// Declares a chain to watch.
  const TomAuditWatchedChain({required this.writer, required this.read});

  @override
  String toString() => 'TomAuditWatchedChain($writer)';
}

// =============================================================================
// WHAT A CHECK CONCLUDED
// =============================================================================

/// Why a declared chain produced no verification at all.
///
/// Distinct from [TomAuditAnchorStatus], which describes what a verification
/// *concluded*. These two are the cases where none could be performed, and both
/// are findings rather than gaps in the report.
enum TomAuditAnchorCheckFailure {
  /// The store holds no anchor for this writer.
  ///
  /// The finding the store cannot discover on its own: a chain that was never
  /// anchored has nothing to diverge from, so a rewrite of it leaves no trace.
  /// Reported because the deployment declared it, which is the whole reason
  /// the writers are declared.
  neverAnchored,

  /// Reading the chain back threw.
  ///
  /// Not evidence of tampering, and not evidence of its absence either — the
  /// check did not happen, and a check that did not happen must not read as a
  /// pass.
  readFailed,
}

/// What one declared chain's check concluded.
class TomAuditAnchorCheck {
  /// The chain that was checked.
  final String writer;

  /// The verification, or `null` when [failure] says none was performed.
  final TomAuditAnchorVerification? verification;

  /// Why no verification was performed, or `null` when one was.
  final TomAuditAnchorCheckFailure? failure;

  /// A one-line explanation, suitable for an operator alert.
  final String detail;

  /// Creates a result. Exactly one of [verification] and [failure] is set.
  const TomAuditAnchorCheck({
    required this.writer,
    required this.detail,
    this.verification,
    this.failure,
  }) : assert(
         (verification == null) != (failure == null),
         'A check either verified or explains why it could not.',
       );

  /// Whether an operator must act on this.
  ///
  /// Every [failure] counts, and so does every verification that
  /// [TomAuditAnchorVerification.indicatesTampering]. An inconclusive
  /// verification — the anchored position pruned away, or an anchor naming
  /// another chain — is reported but is not a finding: a deployment that prunes
  /// reaches `beforeRetention` on every ordinary run, and a check that cried
  /// wolf there would be switched off within a week.
  bool get isFinding =>
      failure != null || (verification?.indicatesTampering ?? false);

  /// Whether the chain verified against its anchor.
  bool get isClean => verification?.isMatch ?? false;

  @override
  String toString() => '$writer: $detail';
}

/// What one round of [TomAuditAnchorMonitor.verifyAll] concluded.
class TomAuditAnchorReport {
  /// One entry per declared chain, in the order they were declared.
  final List<TomAuditAnchorCheck> checks;

  /// When the round ran.
  final DateTime checkedAt;

  /// Where the anchors were read from — [TomAuditAnchorStore.description].
  final String storeDescription;

  /// Whether the deployment declares that store beyond the audited server's
  /// reach.
  ///
  /// Carried so that a reader of the report can weigh it, and **not** consulted
  /// by [isClean]. A round verifies a chain against the anchors it was given;
  /// whether those anchors were somewhere an attacker could also have rewritten
  /// is a different question, and one this object can report but not answer. A
  /// clean round over a store the server can reach is exactly what it says —
  /// the chain matches the claim — and the claim may be worth nothing. Letting
  /// this flag move the verdict would turn a declaration nobody verified into a
  /// status, which is the mistake the declaration exists to avoid.
  final bool storeIsIndependent;

  /// Creates a report.
  TomAuditAnchorReport({
    required List<TomAuditAnchorCheck> checks,
    required this.checkedAt,
    this.storeDescription = 'unknown',
    this.storeIsIndependent = false,
  }) : checks = List.unmodifiable(checks);

  /// The checks an operator must act on.
  Iterable<TomAuditAnchorCheck> get findings =>
      checks.where((c) => c.isFinding);

  /// Whether every declared chain verified against its anchor.
  ///
  /// Stricter than "no findings": an inconclusive check is not a finding but is
  /// not a clean bill of health either, and a report that called it one would
  /// be answering a question nobody asked.
  bool get isClean => checks.isNotEmpty && checks.every((c) => c.isClean);

  @override
  String toString() {
    final found = findings.length;
    // The caveat rides on the same line as the verdict, because the line is
    // what reaches a dashboard. "No findings" on its own, over a store the
    // audited server can rewrite, is the reassurance anchoring exists to
    // withhold.
    final store = storeIsIndependent
        ? 'store $storeDescription, declared independent'
        : 'store $storeDescription, NOT independent of this server';
    return found == 0
        ? 'audit anchors verified: ${checks.length} chain(s), no findings '
              '($store)'
        : 'audit anchors verified: ${checks.length} chain(s), '
              '$found finding(s) — ${findings.map((c) => c.writer).join(', ')} '
              '($store)';
  }
}

// =============================================================================
// THE MONITOR
// =============================================================================

/// Verifies each declared chain against the latest anchor published for it.
///
/// The counterpart of [TomAuditAnchorPublisher]: that one writes anchors and
/// this one reads them back. See the library documentation for why the writers
/// are declared, why the read is supplied, and why this is a scheduler job
/// where publication is a timer.
class TomAuditAnchorMonitor {
  /// Where anchors are read from.
  final TomAuditAnchorStore store;

  /// The chains the deployment expects to exist.
  final List<TomAuditWatchedChain> chains;

  /// Requires each anchor's signature when the deployment signs them.
  ///
  /// Omitting it checks the *position* only, which is the honest thing to do
  /// for an unsigned anchor taken from a store that is itself trusted — the
  /// same rule [verifyAgainstAnchor] states.
  final TomAuditAnchorVerifier? verifier;

  /// Called once per finding, after every chain has been checked and logged.
  ///
  /// Deliberately after, and not as each check completes: a callback that
  /// throws — which is how a deployment makes the scheduled run *fail* — then
  /// aborts the reporting rather than the checking, so the log already holds
  /// every finding of the round whatever the callback does with the first.
  final void Function(TomAuditAnchorCheck finding)? onFinding;

  /// Creates a monitor over [chains].
  TomAuditAnchorMonitor({
    required this.store,
    required List<TomAuditWatchedChain> chains,
    this.verifier,
    this.onFinding,
  }) : chains = List.unmodifiable(chains);

  /// Checks every declared chain and reports what was found.
  ///
  /// Never throws for a chain that cannot be read or has never been anchored —
  /// those are [TomAuditAnchorCheck]s, because a round that gave up on the
  /// first unreadable chain would leave the rest unchecked and report nothing
  /// about either. The only throw is the caller's own [onFinding].
  Future<TomAuditAnchorReport> verifyAll() async {
    final checks = <TomAuditAnchorCheck>[];
    for (final chain in chains) {
      checks.add(await _check(chain));
    }
    final report = TomAuditAnchorReport(
      checks: checks,
      checkedAt: DateTime.now().toUtc(),
      storeDescription: store.description,
      storeIsIndependent: store.independentOfServer,
    );

    for (final check in report.checks) {
      if (check.isFinding) {
        tomLog.error('audit anchor finding — $check');
      } else if (!check.isClean) {
        tomLog.warn('audit anchor check inconclusive — $check');
      }
    }
    final sink = onFinding;
    if (sink != null) {
      for (final finding in report.findings) {
        sink(finding);
      }
    }
    return report;
  }

  Future<TomAuditAnchorCheck> _check(TomAuditWatchedChain chain) async {
    final TomAuditAnchor? anchor;
    try {
      anchor = await store.latest(chain.writer);
    } on Object catch (e) {
      return TomAuditAnchorCheck(
        writer: chain.writer,
        failure: TomAuditAnchorCheckFailure.readFailed,
        detail: 'reading the latest anchor for "${chain.writer}" failed: $e',
      );
    }
    if (anchor == null) {
      return TomAuditAnchorCheck(
        writer: chain.writer,
        failure: TomAuditAnchorCheckFailure.neverAnchored,
        detail:
            'chain "${chain.writer}" is declared but the store holds no '
            'anchor for it — an unanchored chain cannot be shown to be intact',
      );
    }

    final List<TomAuditEntry> entries;
    try {
      entries = await chain.read();
    } on Object catch (e) {
      return TomAuditAnchorCheck(
        writer: chain.writer,
        failure: TomAuditAnchorCheckFailure.readFailed,
        detail: 'reading chain "${chain.writer}" back failed: $e',
      );
    }

    final verification = verifyAgainstAnchor(
      entries,
      anchor,
      writer: chain.writer,
      verifier: verifier,
    );
    return TomAuditAnchorCheck(
      writer: chain.writer,
      verification: verification,
      detail: verification.detail,
    );
  }
}

// =============================================================================
// THE SCHEDULED RUNNER
// =============================================================================

/// Bean name the [TomAuditAnchorVerificationJob] resolves its monitor under.
///
/// Named rather than resolved by type because a deployment may watch more than
/// one set of chains — a monitor per trail table, say — and only one of them is
/// the one this job runs.
const String tomAuditAnchorMonitorBean = 'tomAuditAnchorMonitor';

/// Store key of the verification job.
const String tomAuditAnchorVerificationJobName = 'tom.audit.anchorVerification';

/// Verifies the declared audit chains against their latest anchors, hourly.
///
/// Register a [TomAuditAnchorMonitor] under [tomAuditAnchorMonitorBean] and the
/// job verifies them. Register none and the run reports that it had nothing to
/// check — see below for why that is not a failure.
///
/// ## Why an unregistered monitor is reported rather than thrown
///
/// This class ships in the framework and carries `@tomReflector`, so it is in
/// the reflection build of *every* application that reflects `tom_core_server`
/// and [TomScheduledJobs.registerAll] picks it up in all of them — including
/// the ones that anchor nothing. A job that threw there would fail hourly, for
/// ever, in applications that never asked for it, and the noise would train an
/// operator to ignore the very channel a real divergence arrives on.
///
/// So a missing monitor is a *configuration* fact and is reported as one. It
/// is not silent: the run's result says plainly that no monitor was registered,
/// which is visible in the job store and distinguishable at a glance from a
/// round that verified and found nothing. An application that does not want the
/// job at all excludes it with `TomScheduledJobs.discover`'s `where` filter —
/// the mechanism that API ships for exactly this.
///
/// A missing monitor is the only exception treated this way. Anything else the
/// round throws is a real failure and propagates.
///
/// ## Why the run succeeds even when the chain diverged
///
/// A finding is routed through the monitor's two seams — the log and
/// `onFinding` — and the run itself reports the round, not the verdict. Failing
/// the run instead would be the third seam, and it would be the wrong shape:
/// [TomRetryPolicy] would retry it, and a diverged chain is still diverged on
/// the second attempt, so the retries would burn the alerting budget without
/// changing the answer. A deployment that *wants* the run to fail says so by
/// throwing from `onFinding`, which propagates out of `verifyAll` — with every
/// finding of the round already logged, by construction.
///
/// Hourly, matching [TomAuditAnchorPublisher]'s default interval. A check that
/// ran less often than the publisher would leave anchors unexamined for no
/// saving worth having; one that ran more often would re-read the same chains
/// to reach the same answer.
@tomReflector
@TomScheduledJob(
  name: tomAuditAnchorVerificationJobName,
  cron: '0 * * * *',
  // One attempt beyond the first, for the transient store outage. A second
  // failure is not transient, and the unverified chains are still there to
  // find on the next window.
  retry: TomRetryPolicy(maxAttempts: 2, initialBackoff: Duration(minutes: 5)),
  timeout: Duration(minutes: 10),
)
class TomAuditAnchorVerificationJob extends TomJobBase {
  /// What the run reports when no monitor is registered.
  static const String noMonitorRegistered =
      'no audit anchor monitor registered under '
      '"$tomAuditAnchorMonitorBean"; nothing was verified';

  @override
  Future<Object?> execute() async {
    final TomAuditAnchorMonitor monitor;
    try {
      monitor = TomBean<TomAuditAnchorMonitor>.fromName(
        tomAuditAnchorMonitorBean,
      ).get();
    } on TomBeanLocatorException {
      return noMonitorRegistered;
    }
    return (await monitor.verifyAll()).toString();
  }
}

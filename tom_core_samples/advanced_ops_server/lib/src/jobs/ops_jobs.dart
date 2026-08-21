/// The three scheduled jobs, and nothing else.
///
/// ## Why every class here is four lines
///
/// A job class is a *trigger*: a name, a schedule, a retry policy, and one call.
/// The work lives in [OpsRetentionService], [OpsDigestService] and
/// [OpsReportService], which take their collaborators through their
/// constructors and can therefore be exercised with a fake store, a memory
/// transport and a memory export store — no scheduler, no reflection, no
/// database.
///
/// That split is not tidiness. `scheduled_job.dart` builds a job body per run
/// with `newInstance('', const [])`, so a job class *cannot* take constructor
/// arguments; anything it needs it must resolve from the bean locator. A job
/// that also contained its logic would therefore be a class that only a running
/// scheduler with a populated bean context could execute — and the four claims
/// this server exists to make would all be untestable at once.
///
/// ## Why the bodies re-enter the ops zone
///
/// The scheduler dispatches through [TomInlineJobDispatcher], which runs the
/// body in whatever zone the tick happened to be in — the boot zone, in
/// practice, which has no principal. Everything downstream reads the actor from
/// the zone rather than from an argument, so a body that did not establish one
/// would write `SYSTEM` into the trail and resolve every row scope to nothing.
/// [runAsOpsService] is therefore the first thing each body does, and it is also
/// what gives the several entries of one pass a shared [TomRequestId].
///
/// ## Why the schedules are spread across the night
///
/// 03:00 purge, 05:00 report, 06:00 digest. The order is the dependency: the
/// digest counts open work and would be wrong if it ran while the purge was
/// still deleting, and the report describes a closed week that the purge must
/// not still be trimming. They are separate jobs rather than one because their
/// retry budgets are genuinely different — a failed purge should be retried, a
/// failed digest must not recompose after the outbox already accepted half of
/// it — and one job with three phases could only have one policy.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../ops_identity.dart';
import 'digest_service.dart';
import 'report_service.dart';
import 'retention_service.dart';

// =============================================================================
// BEAN NAMES
// =============================================================================

/// Bean name of the [OpsRetentionService] the purge job resolves.
const String opsRetentionServiceBean = 'opsRetentionService';

/// Bean name of the [OpsDigestService] the digest job resolves.
const String opsDigestServiceBean = 'opsDigestService';

/// Bean name of the [OpsReportService] the report job resolves.
const String opsReportServiceBean = 'opsReportService';

// =============================================================================
// JOB NAMES
// =============================================================================

/// Store key of the retention purge — see [TomScheduledJob.name].
const String opsPurgeJobName = 'ops.purge';

/// Store key of the weekly export.
const String opsReportJobName = 'ops.report';

/// Store key of the morning digest.
const String opsDigestJobName = 'ops.digest';

// =============================================================================
// JOBS
// =============================================================================

/// Deletes finished tasks that have aged out, one audited delete at a time.
///
/// `requestsRecovery: true` because the pass is idempotent by construction: a
/// row this run already destroyed is not returned by the next
/// [OpsRetentionStore.expiredItems], so replaying an interrupted run resumes
/// rather than repeats. A retention job that could *not* be recovered would
/// leave the backlog to the next window, which is the one outcome nobody wants
/// from the job that bounds data growth.
@tomReflector
@TomScheduledJob(
  name: opsPurgeJobName,
  cron: '0 3 * * *',
  // Two attempts, not three. The second exists for the transient failure — a
  // connection dropped mid-pass — and there is no third because a purge that
  // fails twice is failing for a reason the next window will not fix, and the
  // untouched rows are still there to find.
  retry: TomRetryPolicy(maxAttempts: 2, initialBackoff: Duration(minutes: 5)),
  timeout: Duration(minutes: 30),
  requestsRecovery: true,
)
class OpsPurgeJob extends TomJobBase {
  final TomBean<OpsRetentionService> _service =
      TomBean<OpsRetentionService>.fromName(opsRetentionServiceBean);

  @override
  Future<Object?> execute() => runAsOpsService(() async {
    // `run.scheduledFor`, never `DateTime.now()`. The cutoff is then the window
    // the run was *for*, so a run recovered four hours late deletes exactly what
    // the on-time run would have — and two nodes replaying the same window
    // compute the same cutoff instead of two.
    final report = await _service.get().purgeExpired(run.scheduledFor);
    return report.toString();
  });
}

/// Renders the weekly completion report into the blob store.
///
/// Sunday 05:00, over the seven days ending then. `allowOverlap: false` (the
/// default) matters more here than elsewhere: two concurrent runs would compute
/// two different windows, render two different reports, and store them under two
/// different date-partitioned keys — leaving a reader to guess which of two
/// plausible files is the week's.
@tomReflector
@TomScheduledJob(
  name: opsReportJobName,
  cron: '0 5 * * 0',
  retry: TomRetryPolicy(maxAttempts: 3, initialBackoff: Duration(minutes: 10)),
  timeout: Duration(minutes: 15),
)
class OpsReportJob extends TomJobBase {
  final TomBean<OpsReportService> _service = TomBean<OpsReportService>.fromName(
    opsReportServiceBean,
  );

  @override
  Future<Object?> execute() => runAsOpsService(() async {
    final outcome = await _service.get().publishReport(run.scheduledFor);
    return outcome.toString();
  });
}

/// Composes the morning digest and hands it to the outbox.
///
/// [TomRetryPolicy.none] — one attempt, and a failure is final. This is the job
/// whose retry budget belongs somewhere else: the messages are durable the
/// moment [OpsDigestService.queueDigests] enqueues them, and the outbox will
/// spend five attempts over a widening backoff getting each one delivered. A
/// scheduler retry on top of that would recompose a digest whose messages are
/// already queued, and although the message id keys the queue row — so the
/// duplicate would be absorbed rather than mailed twice — spending a retry to
/// re-derive a message the outbox already holds is work with no possible
/// outcome.
///
/// `TomMissedWindowPolicy.skip` for the reason a digest is not a report: a
/// summary of yesterday's open work, delivered at noon after an outage, is a
/// mail that arrives contradicted by the board the recipient is already looking
/// at. The next window is minutes away in the only sense that counts.
@tomReflector
@TomScheduledJob(
  name: opsDigestJobName,
  cron: '0 6 * * *',
  retry: TomRetryPolicy.none,
  timeout: Duration(minutes: 10),
  missedWindow: TomMissedWindowPolicy.skip,
)
class OpsDigestJob extends TomJobBase {
  final TomBean<OpsDigestService> _service = TomBean<OpsDigestService>.fromName(
    opsDigestServiceBean,
  );

  @override
  Future<Object?> execute() => runAsOpsService(() async {
    final report = await _service.get().queueDigests(run.scheduledFor);
    return report.toString();
  });
}

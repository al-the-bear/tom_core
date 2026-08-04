/// Everything the ops server *is* at run time, assembled in one place.
///
/// ## Why there is no `TomServer` here
///
/// The other two servers of this suite boot an HTTP listener and the isolate
/// stays alive because a socket is bound. This one has no endpoints — its whole
/// surface is the clock — so what keeps it alive is [TomScheduler]'s tick timer
/// and the anchor publisher's. That is not a lesser kind of server; it is the
/// shape a back-office process actually has, and giving it a health port it does
/// not serve would be a listener nobody calls.
///
/// ## Why one object owns all four things
///
/// The scheduler, the outbox, the anchor publisher and the audit sink have
/// entangled lifetimes: the sink must be installed before any job body runs (or
/// the first pass's mutations go unrecorded), and it must be *un*installed after
/// the last one has stopped (or the trail's own writes race a closing
/// connection). Four independent `start()` calls in a `main` are four chances to
/// get that order wrong, and the ordering constraint would live only in a
/// comment. [OpsRuntime.start] and [OpsRuntime.close] are that order, written
/// once and exercised by every test that boots the runtime.
///
/// ## Two schedulers, deliberately
///
/// [scheduler] runs the three declared jobs; [TomMessageOutbox] owns a second,
/// private one for delivery. They share the *store* — both queues are rows in
/// `tom_job_run` — but not the driver, because their tick rates differ by two
/// orders of magnitude: a cron job is due at most once an hour, a queued message
/// is due now. Folding delivery into the job scheduler would mean either ticking
/// the cron evaluator every fifteen seconds or making a queued message wait for
/// the next minute boundary.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

import 'jobs/digest_service.dart';
import 'jobs/ops_jobs.dart';
import 'jobs/report_service.dart';
import 'jobs/retention_service.dart';
import 'ops_anchoring.dart';
import 'ops_identity.dart';
import 'ops_texts.dart';

/// How often the job scheduler looks for due work.
///
/// A minute, not a second. Every job here is cron-scheduled at hour
/// granularity, so a finer tick would buy nothing but a query per second
/// against a table whose rows change three times a day.
const Duration opsTickInterval = Duration(minutes: 1);

/// How often the outbox looks for queued messages.
const Duration opsOutboxTickInterval = Duration(seconds: 15);

/// The blob-store key prefix scheduled exports are written under.
const String opsExportPrefix = opsExportKeyPrefix;

/// The assembled ops server.
class OpsRuntime {
  /// Creates a runtime over already-built collaborators.
  ///
  /// Public so a test can substitute a memory job store, a memory transport and
  /// a memory export store without a database in sight; [OpsRuntime.production]
  /// is what the boot calls.
  OpsRuntime({
    required this.scheduler,
    required this.outbox,
    required this.anchoring,
    required this.auditSink,
    this.nodes,
  });

  /// Builds the production arrangement over the registered `app_db`.
  ///
  /// [nodeId] identifies this process in `tom_scheduler_node` and, more
  /// importantly, in `tom_lease.owner` — two ops processes with one id would
  /// each accept the other's lease as its own, which is the one way to lose the
  /// single-fire guarantee while every table still looks correct.
  ///
  /// [transport] is where digests actually go. There is no default: a mail path
  /// chosen silently is a mail path nobody checked, and the two sensible sample
  /// answers (write `.eml` files, or discard) differ by whether the operator can
  /// read the output.
  factory OpsRuntime.production({
    required TomDataSource datasource,
    required String nodeId,
    required TomMessageTransport transport,
    required Directory anchorDirectory,
    TomRecipient? digestSender,
    bool anchorStoreIsIndependent = false,
  }) {
    // `createSchema: false` throughout: the tables come from migration [100],
    // which runs before this is built. A framework component quietly creating
    // its own table would mean the schema exists in two places — the migration
    // chain and a start-up side effect — and the schema-convergence test could
    // no longer tell which one the running server used.
    final nodes = TomSqlSchedulerNodes(
      datasource,
      nodeId: nodeId,
      createSchema: false,
    );
    final store = TomSqlJobStore(datasource, createSchema: false, nodes: nodes);
    final lock = TomSqlLeaseLock(datasource, createSchema: false);

    final auditSink = TomSqlAuditSink(
      datasource,
      writer: opsAuditWriter,
      createSchema: false,
      // The chain is only worth verifying if the rows cannot be edited, and
      // `requireWriteOnce` is what asks the database to say so at start-up
      // rather than letting a permissive grant be discovered during an
      // investigation.
      requireWriteOnce: true,
    );

    final scheduler = TomScheduler(
      store: store,
      dispatcher: const TomInlineJobDispatcher(),
      ownerId: nodeId,
      lock: lock,
      tickInterval: opsTickInterval,
      onAlert: _logAlert,
    );

    final outbox = TomMessageOutbox(
      router: TomMessageRouter([transport]),
      // The same durable queue the jobs use. An outbox on a memory store loses
      // exactly the messages queuing exists to protect — and this deployment
      // already has a `tom_job_run` table, so durability here costs nothing but
      // naming it.
      store: store,
      lock: lock,
      tickInterval: opsOutboxTickInterval,
      onAlert: _logAlert,
    );

    return OpsRuntime(
      scheduler: scheduler,
      outbox: outbox,
      auditSink: auditSink,
      nodes: nodes,
      anchoring: OpsAnchoring.toDirectory(
        anchorDirectory,
        sink: auditSink,
        independentOfServer: anchorStoreIsIndependent,
      ),
    )..registerServices(
      retention: OpsRetentionService(store: const RepositoryRetentionStore()),
      digest: OpsDigestService(
        audience: const RepositoryDigestAudience(),
        // The service, not the outbox: the digest must have no way to write a
        // subject line. `OpsTexts.resources()` reads `assets/text_*.yaml` here,
        // at boot, so a missing or malformed bundle stops the server rather
        // than being discovered at 06:00 as a blank mail.
        email: TomEmailService(outbox: outbox, texts: OpsTexts.resources()),
        sender: digestSender,
      ),
      report: OpsReportService(
        source: const RepositoryReportSource(),
        exports: TomExportService(
          store: TomBlobExportStore.named(null, keyPrefix: opsExportPrefix),
        ),
      ),
    );
  }

  /// Drives the three declared jobs.
  final TomScheduler scheduler;

  /// Delivers what the digest queues.
  final TomMessageOutbox outbox;

  /// Publishes the audit head on its own timer — not a job. See
  /// `ops_anchoring.dart`.
  final OpsAnchoring anchoring;

  /// Where audit records go while this runtime is started.
  final TomAuditSink auditSink;

  /// The cluster roll call, when this runtime has one.
  final TomSqlSchedulerNodes? nodes;

  /// Publishes the three services under the names the job classes resolve.
  ///
  /// Separate from the constructor because the job classes cannot be handed
  /// collaborators — they are built per run by `newInstance('', const [])` —
  /// so the bean locator is the only channel, and a test that wants a fake
  /// retention store registers it through this same door the production wiring
  /// uses.
  void registerServices({
    required OpsRetentionService retention,
    required OpsDigestService digest,
    required OpsReportService report,
  }) {
    TomBean<OpsRetentionService>.withName(opsRetentionServiceBean, retention);
    TomBean<OpsDigestService>.withName(opsDigestServiceBean, digest);
    TomBean<OpsReportService>.withName(opsReportServiceBean, report);
  }

  /// Installs the trail, registers the declared jobs, and starts everything.
  ///
  /// The order is the point:
  ///
  ///  1. the audit sink is installed **first**, so nothing that follows can
  ///     mutate or refuse without leaving a record;
  ///  2. the deployment principal is installed **before any job may fire**, or
  ///     the meet would degrade to "the actor's grade alone" for the first
  ///     window and nothing would say so;
  ///  3. jobs are registered, which validates every declaration — a malformed
  ///     one throws here, at boot, naming the class;
  ///  4. the timers start.
  Future<List<TomJobDefinition>> start() async {
    TomAuditTrail.install(auditSink);
    installOpsDeploymentPrincipal();
    final definitions = TomScheduledJobs.registerAll(scheduler);
    await scheduler.start();
    outbox.start();
    await anchoring.start();
    return definitions;
  }

  /// Stops the timers, then removes the trail.
  ///
  /// The reverse of [start], and the last step matters: uninstalling the sink
  /// before the schedulers had stopped would let an in-flight run's final
  /// mutation go unrecorded — the one record most worth having, because it is
  /// the one that happened during a shutdown.
  void close() {
    scheduler.close();
    anchoring.close();
    outbox.close();
    TomAuditTrail.uninstall();
  }

  /// One line per scheduler alert.
  ///
  /// Alerts are the losing side of arbitration and the exhausted retry budget —
  /// facts that are otherwise invisible, because a job that never ran logs
  /// nothing at all.
  static void _logAlert(TomJobAlert alert) => tomLog.warn(
    'ops scheduler: ${alert.kind.name} on ${alert.jobName}'
    '${alert.error == null ? '' : ' — ${alert.error}'}',
  );
}

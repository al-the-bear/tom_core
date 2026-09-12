/// The audit anchor publisher — the one piece of recurring work in this server
/// that is deliberately **not** a scheduled job.
///
/// ## Why it is not on the queue
///
/// `audit.md` §"Why the publisher is not a scheduled job" gives the reason, and
/// this server is where it stops being an argument and starts being a shape:
///
/// > `TomScheduler` runs a job once *across the cluster*, which is exactly
/// > wrong here.
///
/// The trail is a hash chain **per writer**, and the writer is the process —
/// that is precisely what allows several nodes to append to one
/// `tom_audit_trail` table without their entries interleaving into one
/// unverifiable chain. Each node therefore has its own head, and each node must
/// publish its own.
///
/// Put it on the scheduler and the cluster's single-fire guarantee does its job
/// perfectly and produces the wrong answer: one node anchors, the others do not,
/// and the operations dashboard reports the trail as anchored because *an*
/// anchor was published. That is worse than no anchoring at all, because it is
/// an assurance nobody will re-check.
///
/// So it runs on a plain [Timer] inside [TomAuditAnchorPublisher], per process,
/// unarbitrated. `test/ops_anchor_test.dart` asserts the design point directly —
/// that no `@TomScheduledJob` declares it — because a comment saying "this is
/// not a job" is exactly the kind of claim that stops being true the moment
/// somebody tidies up.
///
/// ## What the store is, and what it is not
///
/// [TomFileAuditAnchorStore] writes JSON Lines to a directory. Whether that
/// directory is an *anchor* is a deployment fact this package cannot establish:
/// an anchor is only worth the store's independence from the process it attests
/// to, and a directory inside the container's own writable tree is a second copy
/// of the same claim, rewritable by exactly the attacker who would need to
/// rewrite it.
///
/// [OpsAnchoring.describe] therefore reports what the arrangement *is* at boot
/// rather than asserting what it should be, and the README says the same thing
/// in prose. Note what is deliberately absent: a SQL anchor store. Anchoring the
/// trail into the database that holds it is one credential and one blast radius,
/// which is ceremony rather than a guarantee — which is why the framework ships
/// no such store for this server to reach for.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

import 'ops_identity.dart';

/// This process's chain name — the `writer` column of every entry it appends.
///
/// Stable across restarts by construction (it is a constant, not a pid or a
/// boot timestamp): [TomSqlAuditSink] recovers its head by looking up the last
/// entry for this writer, so a value that changed per start would abandon the
/// old chain and begin a fresh one from genesis on every deploy.
const String opsAuditWriter = 'advanced_ops_server';

/// How often the head is republished once [OpsAnchoring.start] is called.
///
/// Every tick publishes, including ticks over an unchanged head. An anchor over
/// an unchanged head is not redundant — it says *the head was still this at time
/// T*, which is what bounds the window a later divergence could have happened
/// in. Suppressing duplicates would buy back a couple of megabytes a year by
/// discarding exactly that evidence.
const Duration opsAnchorInterval = Duration(hours: 1);

/// The publisher, plus this deployment's rules about when it may run.
class OpsAnchoring {
  /// Creates the anchoring arrangement.
  OpsAnchoring({required this.publisher});

  /// Builds the file-backed arrangement this deployment ships.
  ///
  /// [directory] is where anchors are written. [independentOfServer] is the
  /// deployment's own assertion that the directory is beyond this process's
  /// reach — it defaults to `false`, because the honest default for a path
  /// handed in by configuration is "we do not know that it is". It is carried
  /// by the store, which is where the framework keeps it; see
  /// [TomAuditAnchorStore.independentOfServer].
  factory OpsAnchoring.toDirectory(
    Directory directory, {
    required TomAuditSink sink,
    Duration interval = opsAnchorInterval,
    bool independentOfServer = false,
  }) => OpsAnchoring(
    publisher: TomAuditAnchorPublisher(
      sink: sink,
      store: TomFileAuditAnchorStore(
        directory: directory,
        independentOfServer: independentOfServer,
      ),
      writer: opsAuditWriter,
      interval: interval,
    ),
  );

  /// The framework publisher doing the work.
  final TomAuditAnchorPublisher publisher;

  /// Whether the deployment asserts the store is out of this server's reach.
  ///
  /// Read from the store rather than kept beside it: two copies of one fact
  /// drift, and the store is where a deployment configures it.
  bool get independentOfServer => publisher.store.independentOfServer;

  /// Publishes immediately and every [TomAuditAnchorPublisher.interval] after.
  ///
  /// Gated on the deployment cap like every other recurring task here. The gate
  /// runs inside the ops zone so that a refusal is attributed to
  /// [opsServiceAccount] rather than to `SYSTEM`.
  Future<void> start() => runAsOpsService(() async {
    await requireOpsCapability(
      OpsCapabilities.publishAuditAnchor,
      operation: 'OpsAuditAnchor',
      entitlement: auditAnchorEntitlement,
    );
    await publisher.start();
  });

  /// Publishes one anchor now, returning it.
  Future<TomAuditAnchor> publishNow() =>
      runAsOpsService(() => publisher.publishNow());

  /// Publishes a final anchor, then closes the publisher for good — see
  /// [TomAuditAnchorPublisher.close].
  ///
  /// The anchor that pins the head a shutdown stops at is the one worth
  /// having. [OpsRuntime.close] calls this *after* draining the sink, so the
  /// final anchor covers the records the drain stored rather than the head as
  /// it stood before them.
  ///
  /// Not gated on [OpsCapabilities.publishAuditAnchor], unlike [start] and
  /// [publishNow]: a shutdown must not be the moment a capability check
  /// discovers it can refuse, and an anchor the server is closing on is
  /// evidence about work it has already done rather than new work it is asking
  /// permission for.
  Future<void> close() => runAsOpsService(publisher.close);

  /// Disarms the timer and leaves the publisher able to publish.
  ///
  /// The reversal of [start] is split in two, and this is the first half:
  /// [OpsRuntime.close] stops the schedule early, so no tick can pin a head its
  /// drain is about to move, and takes the *final* anchor afterwards. Between
  /// those two calls the publisher must still accept a publication — which is
  /// exactly what distinguishes this from [close].
  void stop() => publisher.stop();

  /// One line describing the arrangement, for the boot log.
  ///
  /// The framework's own line — see [TomAuditAnchorPublisher.describe]. A
  /// sample forwards it rather than phrasing the posture a second way: two
  /// wordings of one fact are two things to keep true.
  String describe() => publisher.describe();
}

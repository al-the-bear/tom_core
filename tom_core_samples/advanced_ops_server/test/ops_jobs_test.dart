/// The three job declarations, and the runtime that starts them.
///
/// A `@TomScheduledJob` annotation is a set of *decisions* — how often, how many
/// retries, what to do about a window that was missed while the process was
/// down — and every one of them is a sentence in `ops_jobs.dart` explaining why
/// this job is not like the other two. Prose alone would let the annotation and
/// its justification drift apart silently, so each decision is asserted here
/// against the discovered definition.
///
/// The point is not that `maxAttempts` is 2. It is that the digest and the purge
/// have *different* retry budgets for stated reasons, and that a later edit
/// making them uniform has to come past a failing test with the reason written
/// beside it.
///
/// Reflection is required (a job that is not in the build is not discoverable at
/// all) but nothing else is: [TomScheduledJobs.discover] reads annotations, and
/// the runtime group drives a real [TomScheduler] over a memory store.
library;

import 'dart:async';
import 'dart:io';

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_ops_server/advanced_ops_server.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../bin/ops_server_start.reflection.dart' show initializeReflection;
import 'support/retention_fixtures.dart';

/// The discovered definition named [name].
TomJobDefinition _definition(String name) =>
    TomScheduledJobs.discover().firstWhere((job) => job.name == name);

/// The jobs *this sample* declares.
const _sampleJobs = {opsPurgeJobName, opsReportJobName, opsDigestJobName};

/// The jobs the *framework* registers into the same scheduler.
///
/// Subtracted rather than counted, and that is the whole point of naming them.
/// The assertions below used to state that the scheduler holds exactly three
/// jobs, which stopped being true the day `tom_core_server` began registering
/// its own anchor-verification job — and read as a regression in this sample,
/// which had not changed. The framework will add more; what this sample can
/// assert is which jobs are *its own*.
const _frameworkJobs = {tomAuditAnchorVerificationJobName};

void main() {
  setUpAll(initializeReflection);

  setUp(() {
    TomServerPrincipal.clear();
    installOpsDeploymentPrincipal();
  });
  tearDown(() {
    TomServerPrincipal.clear();
    TomAuditTrail.uninstall();
  });

  group('the three jobs are discoverable and distinctly named', () {
    test('discovery finds exactly the three this server declares', () {
      // Filtered to this server's own namespace, because discovery scans the
      // whole reflection build and the framework declares jobs of its own —
      // `tom_core_server` ships an audit-anchor verification job, and any
      // package this one depends on may ship more. An unfiltered "exactly
      // three" would be an assertion about *everybody's* declarations, which
      // this suite has no business making and could not keep true.
      expect(
        TomScheduledJobs.discover()
            .map((job) => job.name)
            .where((name) => name.startsWith('ops.'))
            .toSet(),
        {opsPurgeJobName, opsReportJobName, opsDigestJobName},
      );
    });

    test('the names are namespaced, so two packages can share one store', () {
      // `tom_job_run` is keyed on the job name and this deployment already has
      // another package's rows in it. An unprefixed `purge` would collide with
      // any other package's purge — and the collision would look like a job
      // that mysteriously stopped firing.
      for (final name in [
        opsPurgeJobName,
        opsReportJobName,
        opsDigestJobName,
      ]) {
        expect(name, startsWith('ops.'));
      }
    });
  });

  group('the purge is retried twice and may be recovered', () {
    late TomJobDefinition purge;
    setUp(() => purge = _definition(opsPurgeJobName));

    test('it runs at 03:00, before the jobs that read what it trimmed', () {
      expect((purge.schedule as TomCronSchedule).expression, '0 3 * * *');
    });

    test('two attempts, not three', () {
      // The second exists for the transient failure — a connection dropped
      // mid-pass. There is no third because a purge that fails twice is failing
      // for a reason the next window will not fix, and the untouched rows are
      // still there to find.
      expect(purge.retryPolicy.maxAttempts, 2);
      expect(purge.retryPolicy.initialBackoff, const Duration(minutes: 5));
    });

    test('it requests recovery, because the pass is idempotent', () {
      // A row this run already destroyed is not returned by the next
      // `expiredItems`, so replaying an interrupted run resumes rather than
      // repeats. The job that bounds data growth is the last one that should
      // silently skip a window.
      expect(purge.requestsRecovery, isTrue);
    });

    test('it gets half an hour, because it deletes one row at a time', () {
      expect(purge.timeout, const Duration(minutes: 30));
    });
  });

  group('the report must not run twice over one week', () {
    late TomJobDefinition report;
    setUp(() => report = _definition(opsReportJobName));

    test('it runs Sunday at 05:00', () {
      expect((report.schedule as TomCronSchedule).expression, '0 5 * * 0');
    });

    test('overlap is refused', () {
      // Two concurrent runs would compute two windows, render two reports and
      // store them under two date-partitioned keys — leaving a reader to guess
      // which of two plausible files is the week's.
      expect(report.allowOverlap, isFalse);
    });

    test('three attempts over a widening backoff', () {
      expect(report.retryPolicy.maxAttempts, 3);
      expect(report.retryPolicy.initialBackoff, const Duration(minutes: 10));
    });
  });

  group('the digest spends its retry budget somewhere else', () {
    late TomJobDefinition digest;
    setUp(() => digest = _definition(opsDigestJobName));

    test('it runs at 06:00, after the purge and the report', () {
      expect((digest.schedule as TomCronSchedule).expression, '0 6 * * *');
    });

    test('one attempt, and a failure is final', () {
      // The messages are durable the moment `queueDigests` enqueues them, and
      // the outbox will spend five attempts over a widening backoff getting
      // each one delivered. A scheduler retry on top would recompose a digest
      // whose messages are already queued — work with no possible outcome.
      // `ops_digest_test.dart` asserts the redelivery this depends on.
      expect(digest.retryPolicy.maxAttempts, 1);
      expect(digest.retryPolicy, TomRetryPolicy.none);
    });

    test('a missed window is skipped, not caught up', () {
      // A summary of yesterday's open work, delivered at noon after an outage,
      // is a mail that arrives contradicted by the board the recipient is
      // already looking at. The next window is minutes away in the only sense
      // that counts.
      expect(digest.missedWindowPolicy, TomMissedWindowPolicy.skip);
    });

    test('the report, by contrast, is not skipped', () {
      // The mirror: `skip` above must be a decision about digests and not the
      // package's default. A week's report is worth having late.
      expect(
        _definition(opsReportJobName).missedWindowPolicy,
        isNot(TomMissedWindowPolicy.skip),
      );
    });
  });

  group('the retry budgets are genuinely different', () {
    test('no two jobs share a policy', () {
      // The reason these are three jobs rather than one with three phases: one
      // job could only have one policy, and the whole argument in `ops_jobs.dart`
      // is that these three need different ones.
      final attempts = [
        _definition(opsPurgeJobName).retryPolicy.maxAttempts,
        _definition(opsReportJobName).retryPolicy.maxAttempts,
        _definition(opsDigestJobName).retryPolicy.maxAttempts,
      ];
      expect(attempts.toSet(), hasLength(3));
    });
  });

  group('the runtime starts the declared jobs and stops them again', () {
    late OpsRuntime runtime;
    late TomMemoryAuditSink sink;
    late TomMemoryMessageTransport transport;

    setUp(() {
      sink = TomMemoryAuditSink();
      transport = TomMemoryMessageTransport();
      final outbox = TomMessageOutbox(
        router: TomMessageRouter([transport]),
        store: TomMemoryJobStore(),
      );
      runtime = OpsRuntime(
        scheduler: TomScheduler(
          store: TomMemoryJobStore(),
          dispatcher: const TomInlineJobDispatcher(),
          ownerId: 'test-node',
        ),
        outbox: outbox,
        auditSink: sink,
        anchoring: OpsAnchoring(
          publisher: TomAuditAnchorPublisher(
            sink: sink,
            store: TomMemoryAuditAnchorStore(),
            writer: opsAuditWriter,
          ),
        ),
      );
    });

    tearDown(() => runtime.close());

    test('start registers all three and installs the trail', () async {
      final definitions = await runtime.start();

      expect(
        definitions.map((d) => d.name).toSet().difference(_frameworkJobs),
        _sampleJobs,
      );
      expect(
        runtime.scheduler.jobs.keys.toSet().difference(_frameworkJobs),
        _sampleJobs,
      );
      // Installed first, so nothing that follows can mutate or refuse without
      // leaving a record.
      expect(TomAuditTrail.isEnabled, isTrue);
    });

    test('the framework registers its own jobs beside the sample\'s', () async {
      // What makes the subtraction above load-bearing. Without this the two
      // assertions would go on passing if the framework stopped registering
      // anything at all, having subtracted a name that is no longer there.
      await runtime.start();
      expect(
        runtime.scheduler.jobs.keys,
        contains(tomAuditAnchorVerificationJobName),
      );
    });

    test('start installs the deployment cap before any job may fire', () async {
      TomServerPrincipal.clear();
      expect(TomServerPrincipal.isConfigured, isFalse);

      await runtime.start();

      // Without this, the first window would run under "the actor's grade
      // alone" and nothing would say so — the meet would silently not apply.
      expect(TomServerPrincipal.isConfigured, isTrue);
      expect(
        OpsCapabilities.reassignItems.checkAccessibility(opsServiceAccount),
        isFalse,
      );
    });

    test('close removes the trail after the timers have stopped', () async {
      await runtime.start();
      expect(TomAuditTrail.isEnabled, isTrue);

      await runtime.close();

      // The reverse order matters: uninstalling first would let an in-flight
      // run's final mutation go unrecorded — the record most worth having,
      // because it is the one that happened during a shutdown.
      expect(TomAuditTrail.isEnabled, isFalse);
    });

    test('close leaves no process-global state behind', () async {
      await runtime.start();
      expect(TomServerPrincipal.isConfigured, isTrue);
      expect(runtime.anchoring.publisher.isScheduled, isTrue);

      await runtime.close();

      // The runtime is an object; these three are not. `TomServerPrincipal`
      // and `TomAuditTrail` are process-global and a live [Timer] holds the
      // isolate up on its own — so anything `start` put outside the object has
      // to come back out, or a closed runtime hands its deployment licence to
      // whatever runs next and its timer keeps the process alive.
      expect(TomServerPrincipal.isConfigured, isFalse);
      expect(runtime.anchoring.publisher.isScheduled, isFalse);
      expect(TomAuditTrail.isEnabled, isFalse);
    });

    test(
      'a second runtime does not inherit the cap the first installed',
      () async {
        // Two runtimes in one process is not a hypothetical — it is what this
        // group already builds. A cap that survived the first `close` would be
        // inherited silently, and every assertion about the second runtime's
        // authorization would then be about the first one's licence.
        await runtime.start();
        await runtime.close();

        final secondSink = TomMemoryAuditSink();
        final second = OpsRuntime(
          scheduler: TomScheduler(
            store: TomMemoryJobStore(),
            dispatcher: const TomInlineJobDispatcher(),
            ownerId: 'second-node',
          ),
          outbox: TomMessageOutbox(
            router: TomMessageRouter([TomMemoryMessageTransport()]),
            store: TomMemoryJobStore(),
          ),
          auditSink: secondSink,
          anchoring: OpsAnchoring(
            publisher: TomAuditAnchorPublisher(
              sink: secondSink,
              store: TomMemoryAuditAnchorStore(),
              writer: opsAuditWriter,
            ),
          ),
        );
        addTearDown(second.close);

        // Uncapped *between* the two: that is what says the first runtime's
        // cap really came off, rather than being overwritten by the second's.
        expect(TomServerPrincipal.isConfigured, isFalse);
        await second.start();
        expect(TomServerPrincipal.isConfigured, isTrue);
      },
    );

    test('close drains the audit sink rather than abandoning it', () async {
      // A *file* sink, not the memory one the other tests use: the claim under
      // test is that the shutdown waits for the queue, and a memory sink has
      // stored the entry before `write` even returns. Only a sink that really
      // queues can tell a drain apart from no drain.
      final dir = Directory.systemTemp.createTempSync('ops_shutdown_drain');
      addTearDown(() => dir.deleteSync(recursive: true));
      final fileSink = TomFileAuditSink(directory: dir);
      final draining = OpsRuntime(
        scheduler: TomScheduler(
          store: TomMemoryJobStore(),
          dispatcher: const TomInlineJobDispatcher(),
          ownerId: 'test-node',
        ),
        outbox: TomMessageOutbox(
          router: TomMessageRouter([TomMemoryMessageTransport()]),
          store: TomMemoryJobStore(),
        ),
        auditSink: fileSink,
        anchoring: OpsAnchoring(
          publisher: TomAuditAnchorPublisher(
            sink: fileSink,
            store: TomMemoryAuditAnchorStore(),
            writer: opsAuditWriter,
          ),
        ),
      );
      await draining.start();

      // Submitted and deliberately not awaited, so it is still in the sink's
      // queue when the shutdown begins. The runtime's shutdown drains the sink
      // before it completes, so the record is stored rather than refused.
      unawaited(
        TomAuditTrail.recordAction(
          action: TomAuditAction.execute,
          target: 'OpsRuntime',
          outcome: TomAuditOutcome.succeeded,
          detail: 'a record submitted as the process was going down',
        ),
      );

      await draining.close();

      // Read from disk the instant the shutdown returns. This is what lets
      // `ops_server_start.dart` call `exit(0)` on the next line: the trail is
      // complete, not merely closed.
      expect(fileSink.readAll(), hasLength(1));
    });

    test('close anchors the head the drain left, not the one before', () async {
      // The ordering claim in `OpsRuntime.close`, and `entryCount` is what
      // discriminates it. The record below reaches the sink's queue but is not
      // stored until the drain, so an anchor taken before the drain counts 0
      // and one taken after counts 1. Anchoring first would leave that record
      // outside the anchored range — which is the one place a truncation is
      // invisible, and so the one place it must not be left.
      final dir = Directory.systemTemp.createTempSync('ops_shutdown_anchor');
      addTearDown(() => dir.deleteSync(recursive: true));
      final fileSink = TomFileAuditSink(directory: dir);
      final anchors = TomMemoryAuditAnchorStore();
      final closing = OpsRuntime(
        scheduler: TomScheduler(
          store: TomMemoryJobStore(),
          dispatcher: const TomInlineJobDispatcher(),
          ownerId: 'test-node',
        ),
        outbox: TomMessageOutbox(
          router: TomMessageRouter([TomMemoryMessageTransport()]),
          store: TomMemoryJobStore(),
        ),
        auditSink: fileSink,
        anchoring: OpsAnchoring(
          publisher: TomAuditAnchorPublisher(
            sink: fileSink,
            store: anchors,
            writer: opsAuditWriter,
          ),
        ),
      );
      await closing.start();

      unawaited(
        TomAuditTrail.recordAction(
          action: TomAuditAction.execute,
          target: 'OpsRuntime',
          outcome: TomAuditOutcome.succeeded,
          detail: 'a record submitted as the process was going down',
        ),
      );

      await closing.close();

      expect(anchors.anchors, isNotEmpty);
      final last = anchors.anchors.last;
      expect(last.entryCount, 1);
      expect(last.headHash, fileSink.headHash);
    });

    test('registerServices publishes the beans the job bodies resolve', () async {
      final retention = OpsRetentionService(store: const NullRetentionStore());
      runtime.registerServices(
        retention: retention,
        digest: OpsDigestService(
          audience: _EmptyAudience(),
          email: TomEmailService(
            outbox: runtime.outbox,
            texts: OpsTexts.resources(),
          ),
        ),
        report: OpsReportService(
          source: _EmptyReportSource(),
          exports: TomExportService(store: TomMemoryExportStore()),
        ),
      );

      // The bean locator is the only channel a job class has — it is built per
      // run by `newInstance('', const [])` and cannot take collaborators — so a
      // test substitutes fakes through the very door the production wiring uses.
      expect(
        TomBean<OpsRetentionService>.fromName(opsRetentionServiceBean).get(),
        same(retention),
      );
    });

    test(
      'the anchor publisher is started by the runtime, not the scheduler',
      () async {
        await runtime.start();

        // It publishes at start; the scheduler knows nothing about it. Both
        // halves matter — see `ops_anchor_test.dart` for why putting it on the
        // scheduler would be a correctness bug.
        expect(runtime.scheduler.jobs.keys, isNot(contains('anchor')));
        expect(
          sink.records,
          isEmpty,
          reason: 'anchoring records no audit rows',
        );
      },
    );
  });
}

/// An audience with nobody in it.
class _EmptyAudience implements OpsDigestAudience {
  @override
  Future<List<OpsDigestSummary>> summariesFor(DateTime now) async => const [];
}

/// A report source with no rows.
class _EmptyReportSource implements OpsReportSource {
  @override
  Future<List<ItemRecord>> completedBetween(DateTime from, DateTime to) async =>
      const [];
}

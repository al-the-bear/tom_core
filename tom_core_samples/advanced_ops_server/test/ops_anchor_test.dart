/// The anchor publisher, and the assertion that it is still not a job.
///
/// `ops_anchoring.dart` argues at length that putting the publisher on the
/// scheduler would be a correctness bug rather than a style choice: the trail is
/// a hash chain *per writer*, the writer is the process, and the scheduler's
/// single-fire-across-the-cluster guarantee would anchor one node's head while
/// leaving the rest unattested — reporting the trail as anchored because *an*
/// anchor exists.
///
/// A comment saying "this is not a job" is exactly the kind of claim that stops
/// being true the moment somebody tidies up: the class looks like the three
/// beside it, `@TomScheduledJob` is two lines, and the change would pass every
/// other test in this package. So the first group below asks the reflector what
/// jobs this server actually declares, and fails if a fourth one appears.
///
/// Connection-free: the publisher takes a sink and a store, and both have memory
/// implementations.
library;

import 'dart:io';

import 'package:advanced_ops_server/advanced_ops_server.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../bin/ops_server_start.reflection.dart' show initializeReflection;

/// The publisher over two in-memory ends.
({
  OpsAnchoring anchoring,
  TomMemoryAuditAnchorStore store,
  TomMemoryAuditSink sink,
})
_arrangement({Duration interval = const Duration(hours: 1)}) {
  final sink = TomMemoryAuditSink();
  final store = TomMemoryAuditAnchorStore();
  return (
    anchoring: OpsAnchoring(
      publisher: TomAuditAnchorPublisher(
        sink: sink,
        store: store,
        writer: opsAuditWriter,
        interval: interval,
      ),
    ),
    store: store,
    sink: sink,
  );
}

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

  group('the publisher is not on the scheduler, and must stay off it', () {
    test('this server declares exactly three scheduled jobs', () {
      // Named rather than counted, so the failure message says *which* job
      // appeared — a bare `hasLength(3)` would report a number and leave the
      // reader to work out what it means. Scoped to this server's `ops.`
      // namespace: discovery scans the whole reflection build, and what the
      // framework declares is not this suite's to pin.
      final declaredHere = TomScheduledJobs.discover()
          .map((job) => job.name)
          .where((name) => name.startsWith('ops.'))
          .toSet();
      expect(declaredHere, {
        opsPurgeJobName,
        opsReportJobName,
        opsDigestJobName,
      });
    });

    test('no job this server declares publishes anchors', () {
      // The specific regression: somebody adds `@TomScheduledJob` to a class
      // that publishes anchors, and the cluster starts attesting one node's
      // chain on behalf of all of them.
      //
      // Publication, not the word "anchor". `tom_core_server` ships
      // `tom.audit.anchorVerification`, which is a scheduled job about anchors
      // and is *correctly* so: verification reads a chain that already exists,
      // concludes the same thing whichever node asks, and therefore wants
      // running once across the cluster — the exact argument that makes
      // publication belong on a timer instead. Matching the word alone cannot
      // tell those two apart, so the scope is this server's own declarations.
      for (final job in TomScheduledJobs.discover()) {
        if (!job.name.startsWith('ops.')) continue;
        expect(job.name, isNot(contains('anchor')));
      }
    });

    test('the anchor interval is a plain duration, not a cron expression', () {
      // A timer, per process, unarbitrated — which is the whole design point.
      // A cron string here would mean the publisher had acquired a schedule,
      // and a schedule is the thing the cluster arbitrates.
      expect(opsAnchorInterval, const Duration(hours: 1));
    });
  });

  group('every tick publishes, including one over an unchanged head', () {
    test('publishNow appends an anchor naming this process\'s chain', () async {
      final arrangement = _arrangement();
      addTearDown(arrangement.anchoring.close);

      final anchor = await arrangement.anchoring.publishNow();

      expect(anchor.writer, opsAuditWriter);
      expect(arrangement.store.anchors, hasLength(1));
      expect(await arrangement.store.read(opsAuditWriter), hasLength(1));
    });

    test(
      'a second publication over an unchanged head is still recorded',
      () async {
        final arrangement = _arrangement();
        addTearDown(arrangement.anchoring.close);

        final first = await arrangement.anchoring.publishNow();
        final second = await arrangement.anchoring.publishNow();

        // Not redundant: an anchor over an unchanged head says *the head was
        // still this at time T*, which is what bounds the window a later
        // divergence could have happened in. Suppressing it would discard exactly
        // that evidence to save a couple of megabytes a year.
        expect(arrangement.store.anchors, hasLength(2));
        expect(second.headHash, first.headHash);
        expect(second.entryCount, first.entryCount);
      },
    );

    test('the anchor moves with the trail', () async {
      final arrangement = _arrangement();
      addTearDown(arrangement.anchoring.close);
      TomAuditTrail.install(arrangement.sink);

      final before = await arrangement.anchoring.publishNow();
      await TomAuditTrail.recordAction(
        action: TomAuditAction.execute,
        target: 'OpsTest',
        outcome: TomAuditOutcome.succeeded,
      );
      final after = await arrangement.anchoring.publishNow();

      // The pair is what makes the assertion mean something: an anchor that
      // never changed would also pass a test that only checked one head.
      expect(after.entryCount, greaterThan(before.entryCount));
      expect(after.headHash, isNot(before.headHash));
    });

    test('the chain name is a constant, so a restart continues the chain', () {
      // A pid or a boot timestamp here would abandon the old chain and begin a
      // fresh one from genesis on every deploy — leaving a trail of short,
      // individually valid, collectively useless chains.
      expect(opsAuditWriter, 'advanced_ops_server');
    });
  });

  group('starting is gated like every other recurring task', () {
    test('a deployment without the anchor grant is refused', () async {
      TomServerPrincipal.clear();
      TomServerPrincipal.install(
        TomPrincipal(
          user: TomUser(id: 7, username: 'unlicensed-deployment'),
          aci: TomAccessControlInformation(entitlements: const []),
          authenticated: true,
        ),
      );
      final arrangement = _arrangement();
      addTearDown(arrangement.anchoring.close);

      await expectLater(
        arrangement.anchoring.start(),
        throwsA(isA<TomPermanentJobFailure>()),
      );
      expect(arrangement.store.anchors, isEmpty);
    });

    test('the licensed deployment starts and publishes immediately', () async {
      final arrangement = _arrangement();
      addTearDown(arrangement.anchoring.close);

      await arrangement.anchoring.start();

      // Immediately, not at the first interval: a process that crashed 55
      // minutes into its first hour would otherwise have published nothing at
      // all about the entries it wrote.
      expect(arrangement.store.anchors, hasLength(1));
    });

    test(
      'the refusal is attributed to the service account, not SYSTEM',
      () async {
        final sink = TomMemoryAuditSink();
        TomAuditTrail.install(sink);
        TomServerPrincipal.clear();
        TomServerPrincipal.install(
          TomPrincipal(
            user: TomUser(id: 7, username: 'unlicensed-deployment'),
            aci: TomAccessControlInformation(entitlements: const []),
            authenticated: true,
          ),
        );
        final arrangement = _arrangement();
        addTearDown(arrangement.anchoring.close);

        try {
          await arrangement.anchoring.start();
        } on TomPermanentJobFailure {
          // Asserted above; the interest here is the record.
        }

        // `SYSTEM` would mean the gate ran outside the ops zone — the same defect
        // a job body that forgot `runAsOpsService` would have.
        expect(sink.records.single.actor.username, opsServiceUsername);
        expect(sink.records.single.target, 'OpsAuditAnchor');
      },
    );
  });

  group('the arrangement describes itself honestly', () {
    test(
      'a directory this server can reach is called a copy, not an anchor',
      () {
        final anchoring = _arrangement().anchoring;
        addTearDown(anchoring.close);

        // The honest default. An anchor is only worth the store's independence
        // from the process it attests to, and a path handed in by configuration
        // is not known to have it.
        expect(anchoring.independentOfServer, isFalse);
        expect(anchoring.describe(), contains('NOT declared independent'));
        expect(anchoring.describe(), contains('a copy, not an anchor'));
        expect(anchoring.describe(), contains(opsAuditWriter));
      },
    );

    test(
      'a deployment that asserts independence is described as anchored',
      () async {
        // The assertion now rides on the store, which is where the framework
        // keeps it; this sample reads it back rather than carrying a second copy.
        final directory = await Directory.systemTemp.createTemp('ops-anchor');
        addTearDown(() => directory.delete(recursive: true));
        final sink = TomMemoryAuditSink();
        final anchoring = OpsAnchoring.toDirectory(
          directory,
          sink: sink,
          independentOfServer: true,
        );
        addTearDown(anchoring.close);

        expect(anchoring.independentOfServer, isTrue);
        expect(anchoring.describe(), contains('declared independent'));
        expect(anchoring.describe(), isNot(contains('NOT declared')));
        expect(anchoring.describe(), contains(directory.path));
      },
    );
  });
}

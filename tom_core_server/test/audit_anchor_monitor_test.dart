import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// Scheduled-verification tests: what happens *after* an anchor is published.
///
/// `audit_anchor_test.dart` covers what a single `verifyAgainstAnchor` call
/// concludes. These cover the layer above it — the thing that runs on a cadence,
/// decides which chains to look at, and routes what it finds — and the cases
/// they are built around are the ones that layer adds:
///
///  * a chain the deployment **declared and the store has never anchored**,
///    which no store enumeration could have discovered and which is the finding
///    an unanchored rewrite would otherwise leave no trace of;
///  * a **read that throws**, which must not read as a pass and must not stop
///    the round;
///  * the **routing** itself — that a finding reaches the callback and a clean
///    check does not, and that an *inconclusive* check reaches neither, because
///    a monitor that alerted on every retention pass is one an operator turns
///    off.

TomAuditRecord _record(String id) => TomAuditRecord(
  id: id,
  timestamp: DateTime.utc(2026, 9, 8, 10, 30),
  actor: TomAuditActor.system,
  action: TomAuditAction.update,
  target: 'Widget',
  outcome: TomAuditOutcome.succeeded,
);

/// Builds a chain of [count] entries starting at [startIndex] from [startHash].
List<TomAuditEntry> _chain(
  int count, {
  int startIndex = 0,
  String startHash = tomAuditGenesisHash,
}) {
  final entries = <TomAuditEntry>[];
  var previous = startHash;
  for (var i = 0; i < count; i++) {
    final entry = TomAuditEntry.chain(
      _record('r${startIndex + i}'),
      previous,
      index: startIndex + i,
    );
    entries.add(entry);
    previous = entry.hash;
  }
  return entries;
}

TomAuditAnchor _anchorAt(
  List<TomAuditEntry> entries, {
  required String writer,
}) => TomAuditAnchor(
  writer: writer,
  entryCount: entries.isEmpty ? 0 : entries.last.index + 1,
  headHash: entries.isEmpty ? tomAuditGenesisHash : entries.last.hash,
  createdAt: DateTime.utc(2026, 9, 8, 11),
);

TomAuditWatchedChain _watch(String writer, List<TomAuditEntry> entries) =>
    TomAuditWatchedChain(writer: writer, read: () async => entries);

void main() {
  group('TomAuditAnchorMonitor — the ordinary states', () {
    test(
      'a chain that still ends where its anchor says verifies clean',
      () async {
        final entries = _chain(4);
        final store = TomMemoryAuditAnchorStore();
        await store.append(_anchorAt(entries, writer: 'node-a'));

        final report = await TomAuditAnchorMonitor(
          store: store,
          chains: [_watch('node-a', entries)],
        ).verifyAll();

        expect(report.isClean, isTrue);
        expect(report.findings, isEmpty);
        expect(
          report.checks.single.verification!.status,
          TomAuditAnchorStatus.matched,
        );
      },
    );

    test(
      'a chain that has grown since its anchor is clean, not a finding',
      () async {
        // The ordinary state of a live trail: the publisher anchored at four
        // entries and the server kept writing. A monitor that reported this
        // would report it on every single run.
        final anchored = _chain(4);
        final store = TomMemoryAuditAnchorStore();
        await store.append(_anchorAt(anchored, writer: 'node-a'));
        final grown = [
          ...anchored,
          ..._chain(2, startIndex: 4, startHash: anchored.last.hash),
        ];

        final report = await TomAuditAnchorMonitor(
          store: store,
          chains: [_watch('node-a', grown)],
        ).verifyAll();

        expect(
          report.checks.single.verification!.status,
          TomAuditAnchorStatus.extended,
        );
        expect(report.isClean, isTrue);
        expect(report.findings, isEmpty);
      },
    );
  });

  group('TomAuditAnchorMonitor — the findings', () {
    test('a truncated chain is a finding', () async {
      final full = _chain(6);
      final store = TomMemoryAuditAnchorStore();
      await store.append(_anchorAt(full, writer: 'node-a'));

      // Two entries lopped off the end — a perfectly valid chain, which is
      // exactly why the chain check alone cannot see it.
      final truncated = full.sublist(0, 4);
      final report = await TomAuditAnchorMonitor(
        store: store,
        chains: [_watch('node-a', truncated)],
      ).verifyAll();

      expect(
        report.checks.single.verification!.status,
        TomAuditAnchorStatus.truncated,
      );
      expect(report.findings, hasLength(1));
      expect(report.isClean, isFalse);
    });

    test('a declared chain the store never anchored is a finding', () async {
      // The case a store enumeration cannot reach: there is no anchor to
      // enumerate, so a monitor that discovered its writers from the store
      // would report nothing at all about this chain.
      final report = await TomAuditAnchorMonitor(
        store: TomMemoryAuditAnchorStore(),
        chains: [_watch('node-never-anchored', _chain(3))],
      ).verifyAll();

      final check = report.checks.single;
      expect(check.failure, TomAuditAnchorCheckFailure.neverAnchored);
      expect(check.verification, isNull);
      expect(check.isFinding, isTrue);
      expect(check.isClean, isFalse);
      expect(check.detail, contains('no'));
    });

    test('a read that throws is a finding, not a pass', () async {
      final entries = _chain(3);
      final store = TomMemoryAuditAnchorStore();
      await store.append(_anchorAt(entries, writer: 'node-a'));

      final report = await TomAuditAnchorMonitor(
        store: store,
        chains: [
          TomAuditWatchedChain(
            writer: 'node-a',
            read: () async => throw StateError('datasource down'),
          ),
        ],
      ).verifyAll();

      final check = report.checks.single;
      expect(check.failure, TomAuditAnchorCheckFailure.readFailed);
      expect(check.isFinding, isTrue);
      expect(check.detail, contains('datasource down'));
    });
  });

  group('TomAuditAnchorMonitor — the round', () {
    test(
      'one unreadable chain does not stop the others being checked',
      () async {
        // A round that gave up on the first failure would leave every later
        // chain unchecked and say nothing about either.
        final good = _chain(3);
        final store = TomMemoryAuditAnchorStore();
        // Both writers are anchored, so `node-a` reaches its read and fails
        // *there* — the never-anchored short-circuit would otherwise answer
        // first and this test would not exercise the read path at all.
        await store.append(_anchorAt(good, writer: 'node-a'));
        await store.append(_anchorAt(good, writer: 'node-b'));

        final report = await TomAuditAnchorMonitor(
          store: store,
          chains: [
            TomAuditWatchedChain(
              writer: 'node-a',
              read: () async => throw StateError('down'),
            ),
            _watch('node-b', good),
          ],
        ).verifyAll();

        expect(report.checks, hasLength(2));
        expect(report.checks[0].failure, TomAuditAnchorCheckFailure.readFailed);
        expect(report.checks[1].isClean, isTrue);
        expect(report.findings, hasLength(1));
      },
    );

    test('checks are reported in the order the chains were declared', () async {
      final store = TomMemoryAuditAnchorStore();
      final report = await TomAuditAnchorMonitor(
        store: store,
        chains: [
          _watch('c', const []),
          _watch('a', const []),
          _watch('b', const []),
        ],
      ).verifyAll();

      expect(report.checks.map((c) => c.writer), ['c', 'a', 'b']);
    });

    test('an empty report is not clean', () async {
      // `every` on an empty list is vacuously true, and a monitor watching
      // nothing must not answer "all clear".
      final report = await TomAuditAnchorMonitor(
        store: TomMemoryAuditAnchorStore(),
        chains: const [],
      ).verifyAll();

      expect(report.checks, isEmpty);
      expect(report.isClean, isFalse);
    });
  });

  group('TomAuditAnchorMonitor — the seam', () {
    test('every finding reaches onFinding, and nothing else does', () async {
      final clean = _chain(3);
      final store = TomMemoryAuditAnchorStore();
      await store.append(_anchorAt(clean, writer: 'node-clean'));

      final seen = <String>[];
      await TomAuditAnchorMonitor(
        store: store,
        chains: [_watch('node-clean', clean), _watch('node-never', _chain(2))],
        onFinding: (finding) => seen.add(finding.writer),
      ).verifyAll();

      expect(seen, ['node-never']);
    });

    test(
      'an inconclusive check reaches neither the findings nor the callback',
      () async {
        // Retention pruned past the anchored position. A deployment that prunes
        // reaches this on every ordinary run, so alerting here would train the
        // operator to ignore the channel.
        final full = _chain(8);
        final store = TomMemoryAuditAnchorStore();
        await store.append(_anchorAt(full.sublist(0, 3), writer: 'node-a'));
        final retained = full.sublist(5);

        final seen = <String>[];
        final report = await TomAuditAnchorMonitor(
          store: store,
          chains: [_watch('node-a', retained)],
          onFinding: (f) => seen.add(f.writer),
        ).verifyAll();

        expect(
          report.checks.single.verification!.status,
          TomAuditAnchorStatus.beforeRetention,
        );
        expect(report.checks.single.isFinding, isFalse);
        expect(report.checks.single.isClean, isFalse);
        expect(report.isClean, isFalse);
        expect(seen, isEmpty);
      },
    );

    test(
      'a throwing callback propagates, with every finding already logged',
      () async {
        // This is how a deployment makes the scheduled run fail. The contract
        // that makes it safe is the ordering: the callback runs after every
        // chain has been checked, so aborting here abandons the reporting and
        // not the checking.
        final monitor = TomAuditAnchorMonitor(
          store: TomMemoryAuditAnchorStore(),
          chains: [_watch('node-a', const []), _watch('node-b', const [])],
          onFinding: (f) => throw StateError('paged: ${f.writer}'),
        );

        await expectLater(monitor.verifyAll(), throwsStateError);
      },
    );

    test('the signature is checked when a verifier is supplied', () async {
      final entries = _chain(3);
      final store = TomMemoryAuditAnchorStore();
      await store.append(_anchorAt(entries, writer: 'node-a'));

      final report = await TomAuditAnchorMonitor(
        store: store,
        chains: [_watch('node-a', entries)],
        verifier: const _RejectingVerifier(),
      ).verifyAll();

      // An unsigned anchor against a verifier that trusts nothing: the anchor
      // itself cannot be relied on, so nothing is concluded from it — and that
      // ambiguity counts as a finding rather than as a pass.
      expect(
        report.checks.single.verification!.status,
        TomAuditAnchorStatus.signatureInvalid,
      );
      expect(report.findings, hasLength(1));
    });
  });

  group('TomAuditAnchorVerificationJob', () {
    tearDown(TomBean.resetBeanContext);

    test('reports plainly when no monitor is registered', () async {
      // The job ships in the framework and is in every reflecting
      // application's build, so it runs in deployments that anchor nothing.
      // Throwing there would fail hourly for ever in applications that never
      // asked for it.
      final result = await TomAuditAnchorVerificationJob().execute();
      expect(result, TomAuditAnchorVerificationJob.noMonitorRegistered);
    });

    test('runs the registered monitor and reports its round', () async {
      final entries = _chain(3);
      final store = TomMemoryAuditAnchorStore();
      await store.append(_anchorAt(entries, writer: 'node-a'));
      TomBean.withName(
        tomAuditAnchorMonitorBean,
        TomAuditAnchorMonitor(
          store: store,
          chains: [_watch('node-a', entries)],
        ),
      );

      final result = await TomAuditAnchorVerificationJob().execute();
      expect(result, contains('1 chain(s)'));
      expect(result, contains('no findings'));
    });

    test(
      'a finding reaches the run result, and the run still succeeds',
      () async {
        // The run reports the round, not the verdict — retrying a diverged
        // chain would reach the same answer and burn the alerting budget.
        TomBean.withName(
          tomAuditAnchorMonitorBean,
          TomAuditAnchorMonitor(
            store: TomMemoryAuditAnchorStore(),
            chains: [_watch('node-a', _chain(2))],
          ),
        );

        final result = await TomAuditAnchorVerificationJob().execute();
        expect(result, contains('1 finding(s)'));
        expect(result, contains('node-a'));
      },
    );
  });

  group('TomAuditAnchorCheck', () {
    test('exactly one of verification and failure must be set', () {
      expect(
        () => TomAuditAnchorCheck(writer: 'a', detail: 'neither'),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

/// Trusts nothing, to exercise the verifier seam without an RSA key.
class _RejectingVerifier implements TomAuditAnchorVerifier {
  const _RejectingVerifier();

  @override
  bool verify(TomAuditAnchor anchor) => false;
}

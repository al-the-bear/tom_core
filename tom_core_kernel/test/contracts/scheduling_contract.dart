/// The behaviour every [TomJobStore] and every [TomLeaseLock] must exhibit,
/// written once and run against every implementation.
///
/// ## Why this file exists, and why it lives in `test/`
///
/// The kernel ships two implementations of each port (memory and file); the
/// relational pair lives one layer up in `tom_core_server`, over the same
/// contract. A second implementation that merely *resembles* the first is not
/// good enough — this very suite caught a file-lock divergence in which a live
/// holder re-acquiring its own lease was issued a *new* fencing token, silently
/// fencing itself out. So the suite is the shared artefact and
/// each implementation is a parameter.
///
/// It sits in `test/` rather than `lib/` deliberately. Putting it in `lib/`
/// would make `package:test` a *regular* dependency of `tom_core_kernel`, and
/// therefore of every consumer — including Flutter applications, which reach
/// the kernel through `tom_core_flutter` and whose `flutter_test` pins its own
/// `test_api` / `matcher`. Injecting `package:test` into that graph to serve a
/// test-only need is not a trade worth making. The alternatives were weighed
/// and rejected in the same pass:
///
///  * a separate `tom_core_scheduling_contract` package — the idiomatic Dart
///    answer, but it costs a pubspec, a `tom_master.yaml` registration and a
///    build-order entry to carry two functions;
///  * adding the SQL variants to the kernel's own parameterised loop — the DB
///    fixture (`tom_core_server/test/fixtures/test_database.dart`) is not
///    importable from the kernel, and the dependency direction would be wrong
///    anyway.
///
/// What remains is a relative import from the consuming package's test —
/// `import '../../tom_core_kernel/test/contracts/scheduling_contract.dart';`.
/// It is unusual, and it only works because the two packages sit side by side
/// in this monorepo, which they do by construction (`tom_ai/core/`).
///
/// ## What a portable contract may assert
///
/// The in-memory store hands back the *same objects* it was given, so the
/// kernel's own tests could assert on a caller-held run after a store call. A
/// relational store builds fresh objects from rows and can only mutate the
/// instances it is actually passed. The abstract class never promised object
/// identity, so this suite asserts against re-read state (`all()`,
/// `findWindow()`) wherever the distinction could bite. That is a narrowing of
/// the *tests*, not of the contract.
// intentionally-not-discovered: a shared contract suite, not a suite of
// its own. Each importing *_test.dart calls it once per implementation, so
// a *_test.dart name here would run it a further time against nothing.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A clock the test moves by hand.
///
/// Lease expiry is absolute-time arithmetic, so every lock implementation —
/// including the relational one, which computes `now` in Dart and stores the
/// resulting instant — can be driven by this without waiting on wall time.
class FakeClock {
  DateTime now;

  FakeClock(this.now);

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

/// Builds a fresh, empty store for one test.
typedef TomJobStoreFactory = Future<TomJobStore> Function();

/// Builds a fresh, empty lock for one test, bound to [clock].
typedef TomLeaseLockFactory =
    Future<TomLeaseLock> Function(DateTime Function() clock);

/// Declares the [TomJobStore] contract as a group named after [variant].
///
/// [create] must return a store with no runs in it; a durable implementation is
/// expected to clear its backing table or file first.
void runTomJobStoreContract(String variant, TomJobStoreFactory create) {
  group('$variant (TomJobStore contract)', () {
    late TomJobStore store;
    final at = DateTime.utc(2026, 3, 1, 10);

    setUp(() async => store = await create());

    TomJobRun makeRun(String id, {DateTime? window, DateTime? runAt}) =>
        TomJobRun(
          id: id,
          jobName: 'job',
          scheduledFor: window ?? at,
          runAt: runAt ?? window ?? at,
        );

    Future<TomJobRun> reload(String id) async =>
        (await store.all()).firstWhere((r) => r.id == id);

    test('enqueue stores a run retrievable by window', () async {
      await store.enqueue(makeRun('a'));
      expect((await store.findWindow('job', at))!.id, 'a');
    });

    test('findRun finds a run by id in every state, until it is '
        'purged', () async {
      expect(await store.findRun('a'), isNull);
      await store.enqueue(makeRun('a'));
      expect((await store.findRun('a'))!.state, TomJobRunState.pending);
      final claimed = (await store.claimDue(at, 'owner-1')).single;
      await store.complete(claimed, at);
      expect((await store.findRun('a'))!.state, TomJobRunState.succeeded);
      expect(await store.findRun('b'), isNull);
      await store.purgeFinished(at.add(const Duration(days: 1)));
      expect(await store.findRun('a'), isNull);
    });

    TomJobRun tenantRun(String id, String tenant) => TomJobRun(
      id: id,
      jobName: 'job',
      scheduledFor: at.add(Duration(minutes: id.length)),
      runAt: at,
      tenant: tenant,
    );

    test('a removed tenant\'s pending runs are cancelled, a running one '
        'finishes, another tenant\'s stay', () async {
      await store.enqueue(tenantRun('a1', 'acme'));
      await store.enqueue(tenantRun('a22', 'acme'));
      await store.enqueue(tenantRun('g1', 'globex'));
      final running = (await store.claimDue(
        at,
        'node',
        limit: 1,
        accept: (run) => run.id == 'a22',
      )).single;

      expect(await store.cancelTenantRuns('acme', at), 1);
      final a1 = await reload('a1');
      expect(a1.state, TomJobRunState.failed);
      expect(a1.lastError, TomJobStore.tenantRemovedError);
      expect((await reload('a22')).state, TomJobRunState.running);
      expect((await reload('g1')).state, TomJobRunState.pending);
      await store.complete(running, at);
      expect((await reload('a22')).state, TomJobRunState.succeeded);
    });

    test('a purged tenant\'s runs are deleted, in every state', () async {
      await store.enqueue(tenantRun('a1', 'acme'));
      await store.enqueue(tenantRun('a22', 'acme'));
      await store.enqueue(tenantRun('g1', 'globex'));
      await store.cancelTenantRuns('acme', at);
      expect(await store.purgeTenant('acme'), 2);
      expect((await store.all()).map((r) => r.id), ['g1']);
    });

    test(
      'a tenant\'s run keeps its tenant, and its window is its own',
      () async {
        await store.enqueue(
          TomJobRun(
            id: 'acme',
            jobName: 'job',
            scheduledFor: at,
            runAt: at,
            tenant: 'acme',
          ),
        );
        expect(await store.findWindow('job', at), isNull);
        expect(await store.findWindow('job', at, tenant: 'globex'), isNull);
        final found = await store.findWindow('job', at, tenant: 'acme');
        expect(found!.tenant, 'acme');
        await store.enqueue(
          TomJobRun(
            id: 'globex',
            jobName: 'job',
            scheduledFor: at,
            runAt: at,
            tenant: 'globex',
          ),
        );
        expect((await reload('globex')).tenant, 'globex');
        final claims = await store.claimDue(at, 'node', limit: 10);
        expect(
          {for (final claim in claims) claim.run.id: claim.run.tenant},
          {'acme': 'acme', 'globex': 'globex'},
        );
      },
    );

    test('enqueue rejects a payload that is not JSON-encodable', () async {
      await expectLater(
        store.enqueue(
          TomJobRun(
            id: 'bad',
            jobName: 'job',
            scheduledFor: at,
            runAt: at,
            payload: DateTime.utc(2026),
          ),
        ),
        throwsA(
          isA<TomScheduleException>()
              .having((e) => e.key, 'key', 'schedule.job.payload')
              .having((e) => e.parameters?['job'], 'job', 'job')
              .having((e) => e.parameters?['type'], 'type', 'DateTime'),
        ),
      );
    });

    test('a rejected payload leaves the queue as it was', () async {
      await store.enqueue(makeRun('a'));
      await expectLater(
        store.enqueue(
          TomJobRun(
            id: 'bad',
            jobName: 'job',
            scheduledFor: at.add(const Duration(hours: 1)),
            runAt: at.add(const Duration(hours: 1)),
            payload: DateTime.utc(2026),
          ),
        ),
        throwsA(isA<TomScheduleException>()),
      );
      expect((await store.all()).map((r) => r.id), ['a']);
    });

    test('an encodable payload survives the store', () async {
      await store.enqueue(
        TomJobRun(
          id: 'a',
          jobName: 'job',
          scheduledFor: at,
          runAt: at,
          payload: {
            'when': at.toIso8601String(),
            'ids': [1, 2],
          },
        ),
      );
      expect((await reload('a')).payload, {
        'when': at.toIso8601String(),
        'ids': [1, 2],
      });
    });

    TomJobRun eventRun(String id, {String? tenant}) => TomJobRun(
      id: id,
      jobName: 'job',
      scheduledFor: at,
      runAt: at,
      tenant: tenant,
      windowed: false,
    );

    test('runs enqueued under ids of their own keep apart at one instant, '
        'for one job and tenant', () async {
      // Two nodes enqueueing a message each in the same microsecond: the runs
      // share job, tenant and instant, and neither may replace the other.
      await store.enqueue(eventRun('message-1', tenant: 'acme'));
      await store.enqueue(eventRun('message-2', tenant: 'acme'));
      await store.enqueue(eventRun('message-3'));
      await store.enqueue(eventRun('message-4'));
      for (final id in ['message-1', 'message-2', 'message-3', 'message-4']) {
        final run = await store.findRun(id);
        expect(run, isNotNull, reason: id);
        expect(run!.windowed, isFalse, reason: id);
      }
      expect((await store.all()).map((r) => r.id).toSet(), {
        'message-1',
        'message-2',
        'message-3',
        'message-4',
      });
    });

    test('a run under an id of its own takes no window', () async {
      await store.enqueue(eventRun('message-1'));
      expect(await store.findWindow('job', at), isNull);
      expect(await store.lastWindow('job'), isNull);
      // The clock-driven run of that instant is planned beside it.
      await store.enqueue(makeRun('window'));
      expect((await store.findWindow('job', at))!.id, 'window');
      expect((await store.findRun('message-1'))!.windowed, isFalse);
      expect((await store.findRun('window'))!.windowed, isTrue);
    });

    test('findWindow does not match a different job', () async {
      await store.enqueue(makeRun('a'));
      expect(await store.findWindow('other', at), isNull);
    });

    test('lastWindow is null for an unknown job', () async {
      expect(await store.lastWindow('job'), isNull);
    });

    test('lastWindow reports the latest window enqueued', () async {
      await store.enqueue(makeRun('a'));
      await store.enqueue(
        makeRun('b', window: at.add(const Duration(days: 1))),
      );
      await store.enqueue(
        makeRun('c', window: at.subtract(const Duration(days: 1))),
      );
      expect(await store.lastWindow('job'), at.add(const Duration(days: 1)));
    });

    test('claimDue takes a due run and leases it', () async {
      await store.enqueue(makeRun('a'));
      final claimed = await store.claimDue(at, 'owner-1');
      expect(claimed.single.id, 'a');
      expect(claimed.single.owner, 'owner-1');
      expect(claimed.single.run.state, TomJobRunState.running);
      expect(claimed.single.run.claimedBy, 'owner-1');
      expect(claimed.single.run.claimedAt, at);
    });

    test(
      'claimDue raises the claim token, so two claims are orderable',
      () async {
        await store.enqueue(makeRun('a'));
        final first = (await store.claimDue(at, 'owner-1')).single;
        final later = at.add(const Duration(minutes: 20));
        await store.recoverAbandoned(later, const Duration(minutes: 15));
        final second = (await store.claimDue(later, 'owner-1')).single;

        // Same run, same owner: the token is the only thing that separates them,
        // which is exactly the case `claimedBy` alone cannot see.
        expect(second.token, greaterThan(first.token));
        expect((await reload('a')).claimToken, second.token);
      },
    );

    test('claimDue leaves a future run alone', () async {
      await store.enqueue(
        makeRun('a', runAt: at.add(const Duration(minutes: 1))),
      );
      expect(await store.claimDue(at, 'owner-1'), isEmpty);
    });

    test(
      'backlog counts the due, unclaimed runs per job, oldest first',
      () async {
        final earlier = at.subtract(const Duration(minutes: 5));
        await store.enqueue(makeRun('a', window: earlier));
        await store.enqueue(makeRun('b'));
        await store.enqueue(
          makeRun('future', window: at.add(const Duration(minutes: 1))),
        );
        await store.enqueue(
          TomJobRun(id: 'other', jobName: 'other', scheduledFor: at, runAt: at),
        );
        await store.enqueue(
          TomJobRun(
            id: 'claimed',
            jobName: 'claimed',
            scheduledFor: earlier,
            runAt: earlier,
          ),
        );
        await store.claimDue(
          at,
          'owner-1',
          accept: (run) => run.jobName == 'claimed',
        );

        final backlog = {for (final b in await store.backlog(at)) b.jobName: b};
        expect(backlog.keys, unorderedEquals(['job', 'other']));
        expect(backlog['job']!.due, 2);
        expect(backlog['job']!.oldestDueAt.toUtc(), earlier);
        expect(backlog['other']!.due, 1);
        expect(backlog['other']!.oldestDueAt.toUtc(), at);
      },
    );

    test('claimDue does not re-claim a running run', () async {
      await store.enqueue(makeRun('a'));
      await store.claimDue(at, 'owner-1');
      expect(await store.claimDue(at, 'owner-2'), isEmpty);
    });

    test('claimDue honours the limit', () async {
      for (var i = 0; i < 5; i++) {
        await store.enqueue(
          makeRun('r$i', window: at.add(Duration(minutes: i))),
        );
      }
      final claimed = await store.claimDue(
        at.add(const Duration(hours: 1)),
        'o',
        limit: 2,
      );
      expect(claimed.length, 2);
    });

    test('claimDue honours the accept predicate', () async {
      await store.enqueue(makeRun('a'));
      await store.enqueue(
        makeRun('b', window: at.add(const Duration(minutes: 1))),
      );
      final claimed = await store.claimDue(
        at.add(const Duration(hours: 1)),
        'o',
        accept: (r) => r.id == 'b',
      );
      expect(claimed.map((r) => r.id), ['b']);
      // A rejected run is not merely unreturned — it must still be pending, or
      // a peer that would have accepted it would find it claimed.
      expect((await reload('a')).state, TomJobRunState.pending);
    });

    test('complete marks succeeded and releases the lease', () async {
      await store.enqueue(makeRun('a'));
      final claimed = (await store.claimDue(at, 'o')).single;
      await store.complete(claimed, at.add(const Duration(seconds: 5)));
      final stored = (await store.all()).single;
      expect(stored.state, TomJobRunState.succeeded);
      expect(stored.completedAt, at.add(const Duration(seconds: 5)));
      expect(stored.claimedBy, isNull);
      expect(stored.isFinished, isTrue);
    });

    test(
      'fail with a retryAt returns the run to pending with a new attempt',
      () async {
        await store.enqueue(makeRun('a'));
        final claimed = (await store.claimDue(at, 'o')).single;
        final retryAt = at.add(const Duration(minutes: 1));
        await store.fail(claimed, 'nope', at, retryAt: retryAt);
        final stored = (await store.all()).single;
        expect(stored.state, TomJobRunState.pending);
        expect(stored.attempt, 2);
        expect(stored.runAt, retryAt);
        expect(stored.lastError, 'nope');
        expect(stored.completedAt, isNull);
      },
    );

    test('fail without a retryAt is terminal', () async {
      await store.enqueue(makeRun('a'));
      final claimed = (await store.claimDue(at, 'o')).single;
      await store.fail(claimed, 'nope', at);
      final stored = (await store.all()).single;
      expect(stored.state, TomJobRunState.failed);
      expect(stored.attempt, 1);
      expect(stored.completedAt, at);
      expect(stored.isFinished, isTrue);
    });

    // -------------------------------------------------------------------------
    // A terminal transition records an outcome; it never creates a record.
    //
    // `complete` and `fail` are the only mutators a caller reaches holding a
    // run object it obtained some time ago, so they are the ones that can be
    // handed an id the store no longer has — a dispatch still in flight when
    // purgeFinished ran. Writing it back would defeat the only thing that
    // bounds the queue, and would do so with a freshly stamped completedAt
    // that resets the retention clock.
    // -------------------------------------------------------------------------

    /// Enqueues, claims and finishes `r1`, then purges it away.
    Future<TomJobClaim> seedPurged({required bool succeeded}) async {
      await store.enqueue(makeRun('r1'));
      final claimed = (await store.claimDue(at, 'node-a')).single;
      if (succeeded) {
        await store.complete(claimed, at);
      } else {
        await store.fail(claimed, 'nope', at);
      }
      expect(await store.purgeFinished(at.add(const Duration(days: 1))), 1);
      expect(await store.all(), isEmpty);
      return claimed;
    }

    test('complete does not resurrect a purged run', () async {
      final purged = await seedPurged(succeeded: true);

      await store.complete(purged, at.add(const Duration(days: 2)));

      expect(await store.all(), isEmpty);
    });

    test('fail does not resurrect a purged run', () async {
      final purged = await seedPurged(succeeded: false);

      await store.fail(purged, 'late', at.add(const Duration(days: 2)));

      expect(await store.all(), isEmpty);
    });

    test('a retrying fail does not resurrect a purged run', () async {
      final purged = await seedPurged(succeeded: false);

      // The retry branch writes a *pending* row, so a resurrection here would
      // not merely leak a record — it would put work back into the queue that
      // the operator had already seen finish and age out.
      await store.fail(
        purged,
        'late',
        at.add(const Duration(days: 2)),
        retryAt: at.add(const Duration(days: 2)),
      );

      expect(await store.all(), isEmpty);
    });

    /// A ticket for [run] that no store ever issued.
    ///
    /// Forging one is the only way to reach the guards from outside a claim,
    /// and the token is deliberately 1 — the value a first genuine claim would
    /// have been given, so these tests fail if the guard degenerates into
    /// "any plausible ticket will do".
    TomJobClaim forge(
      TomJobRun run, {
      String owner = 'node-a',
      int token = 1,
    }) => TomJobClaim(run, owner, token);

    test('complete ignores a run the store never held', () async {
      await store.complete(forge(makeRun('ghost')), at);
      expect(await store.all(), isEmpty);
    });

    test('fail ignores a run the store never held', () async {
      await store.fail(forge(makeRun('ghost')), 'nope', at);
      expect(await store.all(), isEmpty);
    });

    test('complete ignores a run that is not running', () async {
      final run = makeRun('r1');
      await store.enqueue(run);

      await store.complete(forge(run), at);

      final stored = await reload('r1');
      expect(stored.state, TomJobRunState.pending);
      expect(stored.completedAt, isNull);
    });

    test('fail ignores a run that is not running', () async {
      final run = makeRun('r1');
      await store.enqueue(run);

      await store.fail(forge(run), 'nope', at);

      final stored = await reload('r1');
      expect(stored.state, TomJobRunState.pending);
      expect(stored.lastError, isNull);
    });

    // The displaced holder. Every test above reaches a row that is *not*
    // running — purged, pending, already terminal — and a guard on state alone
    // would satisfy all of them. This is the case that separates the two: the
    // row is running **again**, under somebody else, and the stale claim must
    // still be refused. Without the owner and token in the predicate, the
    // first node's completion overwrites the successor's live row and the
    // successor then runs to the end against a row that says the job is
    // already finished.
    //
    // Reached the way a cluster reaches it: claim, lose the lease to recovery,
    // let a peer take it, then have the first node report its outcome.
    Future<TomJobClaim> displacedHolderOf(String id) async {
      await store.enqueue(makeRun(id));
      final first = (await store.claimDue(at, 'node-a')).single;
      final later = at.add(const Duration(minutes: 20));
      await store.recoverAbandoned(later, const Duration(minutes: 15));
      final second = (await store.claimDue(later, 'node-b')).single;
      expect(
        second.owner,
        'node-b',
        reason: 'the peer must actually hold it, or the test proves nothing',
      );
      return first;
    }

    test(
      'complete from a displaced holder leaves the successor running',
      () async {
        final displaced = await displacedHolderOf('r1');

        await store.complete(displaced, at.add(const Duration(minutes: 25)));

        final stored = await reload('r1');
        expect(stored.state, TomJobRunState.running);
        expect(stored.claimedBy, 'node-b');
        expect(stored.completedAt, isNull);
      },
    );

    test('fail from a displaced holder leaves the successor running', () async {
      final displaced = await displacedHolderOf('r1');

      await store.fail(displaced, 'nope', at.add(const Duration(minutes: 25)));

      final stored = await reload('r1');
      expect(stored.state, TomJobRunState.running);
      expect(stored.claimedBy, 'node-b');
      expect(stored.lastError, isNull);
    });

    test(
      'a retrying fail from a displaced holder charges no attempt',
      () async {
        // The second reason the retrying branch is fenced: it increments the
        // attempt count, so an unguarded one spends a retry out of a budget the
        // caller no longer owns.
        final displaced = await displacedHolderOf('r1');
        final before = (await reload('r1')).attempt;

        await store.fail(
          displaced,
          'nope',
          at.add(const Duration(minutes: 25)),
          retryAt: at.add(const Duration(minutes: 30)),
        );

        final stored = await reload('r1');
        expect(stored.attempt, before);
        expect(stored.state, TomJobRunState.running);
      },
    );

    test('the successor can still complete after the stale attempt', () async {
      // The other half: the guard refuses the displaced holder without
      // damaging the live claim. A fence that rejected everything would pass
      // all three tests above.
      await store.enqueue(makeRun('r1'));
      final first = (await store.claimDue(at, 'node-a')).single;
      final later = at.add(const Duration(minutes: 20));
      await store.recoverAbandoned(later, const Duration(minutes: 15));
      final second = (await store.claimDue(later, 'node-b')).single;

      await store.complete(first, later);
      await store.complete(second, later);

      final stored = await reload('r1');
      expect(stored.state, TomJobRunState.succeeded);
      expect(stored.completedAt, later);
    });

    test('a second complete does not refresh the retention clock', () async {
      await store.enqueue(makeRun('r1'));
      final claimed = (await store.claimDue(at, 'node-a')).single;
      await store.complete(claimed, at);

      // The late duplicate. If it landed, completedAt would move to `later` and
      // the run would outlive every purge cutoff computed from the first one.
      final later = at.add(const Duration(days: 7));
      await store.complete(claimed, later);

      expect((await reload('r1')).completedAt, at);
    });

    test('recoverAbandoned returns an expired lease to the queue', () async {
      await store.enqueue(makeRun('a'));
      await store.claimDue(at, 'dead-owner');
      final later = at.add(const Duration(minutes: 20));
      final recovered = await store.recoverAbandoned(
        later,
        const Duration(minutes: 15),
      );
      expect(recovered.single.id, 'a');
      expect(recovered.single.state, TomJobRunState.pending);
      expect(recovered.single.claimedBy, isNull);
      expect((await reload('a')).state, TomJobRunState.pending);
    });

    test('recoverAbandoned leaves a fresh lease alone', () async {
      await store.enqueue(makeRun('a'));
      await store.claimDue(at, 'live-owner');
      final recovered = await store.recoverAbandoned(
        at.add(const Duration(minutes: 1)),
        const Duration(minutes: 15),
      );
      expect(recovered, isEmpty);
    });

    test('recoverAbandoned does not charge the run an attempt', () async {
      await store.enqueue(makeRun('a'));
      await store.claimDue(at, 'dead-owner');
      final recovered = await store.recoverAbandoned(
        at.add(const Duration(hours: 1)),
        const Duration(minutes: 15),
      );
      expect(recovered.single.attempt, 1);
    });

    test('purgeFinished drops terminal runs older than the cutoff', () async {
      await store.enqueue(makeRun('done'));
      await store.enqueue(
        makeRun('open', window: at.add(const Duration(hours: 1))),
      );
      await store.complete((await store.claimDue(at, 'o')).single, at);
      final purged = await store.purgeFinished(at.add(const Duration(days: 1)));
      expect(purged, 1);
      expect((await store.all()).map((r) => r.id), ['open']);
    });

    test('purgeFinished keeps a terminal run newer than the cutoff', () async {
      await store.enqueue(makeRun('done'));
      await store.complete((await store.claimDue(at, 'o')).single, at);
      expect(
        await store.purgeFinished(at.subtract(const Duration(days: 1))),
        0,
      );
    });

    // -------------------------------------------------------------------------
    // release / renewClaim
    // -------------------------------------------------------------------------

    Future<TomJobClaim> seedClaimed() async {
      await store.enqueue(makeRun('r1'));
      return (await store.claimDue(at, 'node-a')).single;
    }

    test(
      'release returns a claimed run to pending without charging an attempt',
      () async {
        final claim = await seedClaimed();
        expect(claim.run.state, TomJobRunState.running);

        await store.release(claim);

        final stored = await reload('r1');
        expect(stored.state, TomJobRunState.pending);
        expect(stored.claimedBy, isNull);
        // Contention is not failure. Charging an attempt would let a busy cluster
        // burn a job's whole retry budget without ever executing it.
        expect(stored.attempt, 1);
      },
    );

    test('a released run is immediately claimable again', () async {
      final claim = await seedClaimed();
      await store.release(claim);

      final claimed = await store.claimDue(at, 'node-b');
      expect(claimed.single.id, claim.id);
      expect(claimed.single.run.claimedBy, 'node-b');
    });

    test('release does not resurrect a finished run', () async {
      final claim = await seedClaimed();
      await store.complete(claim, at);

      await store.release(claim);

      expect(
        (await reload('r1')).state,
        TomJobRunState.succeeded,
        reason: 'a completion that raced a release must win',
      );
    });

    test(
      'renewClaim refreshes the lease so recovery leaves the run alone',
      () async {
        final claim = await seedClaimed();
        const leaseTimeout = Duration(minutes: 10);

        final later = at.add(const Duration(minutes: 9));
        await store.renewClaim(claim, later);

        // Without the renewal this run would be 15 minutes stale and recovered.
        final recovered = await store.recoverAbandoned(
          at.add(const Duration(minutes: 15)),
          leaseTimeout,
        );
        expect(recovered, isEmpty);
        final stored = await reload('r1');
        expect(stored.state, TomJobRunState.running);
        expect(stored.claimedAt, later);
      },
    );

    test('renewClaim ignores a run that is not running', () async {
      final run = makeRun('r1');
      await store.enqueue(run);

      await store.renewClaim(forge(run), at);

      expect((await reload('r1')).claimedAt, isNull);
    });

    test('a renewed claim may still record its own outcome', () async {
      final claim = await seedClaimed();

      // The heartbeat moves `claimedAt`, so a fence built on that instant would
      // invalidate the very attempt it certifies. The token does not move.
      await store.renewClaim(claim, at.add(const Duration(minutes: 5)));
      await store.complete(claim, at.add(const Duration(minutes: 6)));

      expect((await reload('r1')).state, TomJobRunState.succeeded);
    });

    // -------------------------------------------------------------------------
    // markStarted, and the recovery branch it exists to enable
    // -------------------------------------------------------------------------

    test('a claimed run has not started until it is marked', () async {
      final claim = await seedClaimed();
      expect(claim.run.startedAt, isNull);
      expect(
        (await reload('r1')).startedAt,
        isNull,
        reason: 'a reservation is not an execution',
      );
    });

    test('markStarted stamps the run and survives a reload', () async {
      final claim = await seedClaimed();
      final started = at.add(const Duration(seconds: 3));

      await store.markStarted(claim, started);

      expect(
        claim.run.startedAt,
        started,
        reason: 'the caller sees its own write',
      );
      expect((await reload('r1')).startedAt, started);
    });

    test('markStarted ignores a run that is not running', () async {
      final run = makeRun('r1');
      await store.enqueue(run);

      await store.markStarted(forge(run), at);

      expect((await reload('r1')).startedAt, isNull);
    });

    test('an abandoned run that never started is re-queued even when its job '
        'declines recovery', () async {
      await store.enqueue(makeRun('a'));
      await store.claimDue(at, 'dead-owner');

      final recovered = await store.recoverAbandoned(
        at.add(const Duration(minutes: 20)),
        const Duration(minutes: 15),
        requestsRecovery: (_) => false,
      );

      // Nothing executed, so nothing can repeat: the opt-in does not apply.
      expect(recovered.single.state, TomJobRunState.pending);
      expect((await reload('a')).state, TomJobRunState.pending);
    });

    test('an abandoned run that started is re-queued when its job requests '
        'recovery', () async {
      await store.enqueue(makeRun('a'));
      final claimed = (await store.claimDue(at, 'dead-owner')).single;
      await store.markStarted(claimed, at);

      final recovered = await store.recoverAbandoned(
        at.add(const Duration(minutes: 20)),
        const Duration(minutes: 15),
        requestsRecovery: (name) => name == 'job',
      );

      expect(recovered.single.state, TomJobRunState.pending);
      expect((await reload('a')).state, TomJobRunState.pending);
    });

    test('an abandoned run that started is failed, not re-queued, when its job '
        'declines recovery', () async {
      await store.enqueue(makeRun('a'));
      final claimed = (await store.claimDue(at, 'dead-owner')).single;
      await store.markStarted(claimed, at);
      final later = at.add(const Duration(minutes: 20));

      final recovered = await store.recoverAbandoned(
        later,
        const Duration(minutes: 15),
        requestsRecovery: (_) => false,
      );

      // Reported, because an operator has to know work was dropped — silently
      // leaving it `running` forever would be the worse failure.
      expect(recovered.single.state, TomJobRunState.failed);
      final stored = await reload('a');
      expect(stored.state, TomJobRunState.failed);
      expect(stored.completedAt, later);
      expect(stored.lastError, TomJobStore.recoveryDeclinedError);
      expect(stored.claimedBy, isNull);
    });

    test(
      'recoverAbandoned with no predicate re-queues a started run',
      () async {
        await store.enqueue(makeRun('a'));
        final claimed = (await store.claimDue(at, 'dead-owner')).single;
        await store.markStarted(claimed, at);

        // The pre-opt-in behaviour, kept for callers that cannot see the job
        // registry and therefore cannot answer the question at all.
        final recovered = await store.recoverAbandoned(
          at.add(const Duration(minutes: 20)),
          const Duration(minutes: 15),
        );

        expect(recovered.single.state, TomJobRunState.pending);
      },
    );

    // -------------------------------------------------------------------------
    // A transition records *this claim's* outcome, not merely *a* run's.
    //
    // "Still running" is not the same question as "still ours". A node that was
    // partitioned long enough for its lease to expire comes back holding a
    // claim the store has since handed to a peer: the row exists, its state is
    // `running`, and every state guard passes — while the outcome being written
    // belongs to an attempt nobody is waiting for any more. Each of the five
    // transitions is therefore fenced on the claim as well as on the state.
    // -------------------------------------------------------------------------

    /// Claims `r1` for `node-a`, lets the lease lapse, and re-claims it for
    /// `node-b` — leaving `node-a`'s claim superseded but the row `running`.
    ///
    /// Returns the stale claim; the fresh one is the store's current truth.
    Future<TomJobClaim> seedSuperseded() async {
      await store.enqueue(makeRun('r1'));
      final stale = (await store.claimDue(at, 'node-a')).single;
      final later = at.add(const Duration(minutes: 20));
      await store.recoverAbandoned(later, const Duration(minutes: 15));
      final fresh = (await store.claimDue(later, 'node-b')).single;
      expect(fresh.run.claimedBy, 'node-b');
      return stale;
    }

    final superseded = at.add(const Duration(minutes: 25));

    test(
      'complete from a superseded claim leaves the peer\'s run alone',
      () async {
        final stale = await seedSuperseded();

        await store.complete(stale, superseded);

        final stored = await reload('r1');
        expect(
          stored.state,
          TomJobRunState.running,
          reason: 'node-b is still executing it',
        );
        expect(stored.claimedBy, 'node-b');
        expect(stored.completedAt, isNull);
      },
    );

    test('fail from a superseded claim leaves the peer\'s run alone', () async {
      final stale = await seedSuperseded();

      await store.fail(stale, 'nope', superseded);

      final stored = await reload('r1');
      expect(stored.state, TomJobRunState.running);
      expect(stored.claimedBy, 'node-b');
      expect(stored.lastError, isNull);
    });

    test(
      'a retrying fail from a superseded claim charges no attempt',
      () async {
        final stale = await seedSuperseded();

        await store.fail(stale, 'nope', superseded, retryAt: superseded);

        final stored = await reload('r1');
        expect(stored.state, TomJobRunState.running);
        // The retry budget belongs to whoever holds the run now.
        expect(stored.attempt, 1);
      },
    );

    test('markStarted from a superseded claim does not stamp the peer\'s '
        'attempt', () async {
      final stale = await seedSuperseded();

      await store.markStarted(stale, superseded);

      // Left set, this would tell recovery that node-b's attempt had begun —
      // and a job that declines recovery would then be written off rather than
      // re-queued, on the strength of an execution that never happened.
      expect((await reload('r1')).startedAt, isNull);
    });

    test('renewClaim from a superseded claim does not extend the peer\'s '
        'lease', () async {
      final stale = await seedSuperseded();

      await store.renewClaim(stale, superseded);

      // node-b's lease, not node-a's heartbeat: a stale renewal would keep
      // recovery off a run whose real holder had itself gone quiet.
      expect(
        (await reload('r1')).claimedAt,
        at.add(const Duration(minutes: 20)),
      );
    });

    test(
      'release from a superseded claim does not re-queue the peer\'s run',
      () async {
        final stale = await seedSuperseded();

        await store.release(stale);

        final stored = await reload('r1');
        expect(stored.state, TomJobRunState.running);
        expect(stored.claimedBy, 'node-b');
      },
    );

    // -------------------------------------------------------------------------
    // Priority
    // -------------------------------------------------------------------------

    TomJobRun prioritised(String id, String job, int priority, int minute) =>
        TomJobRun(
          id: id,
          jobName: job,
          scheduledFor: at.add(Duration(minutes: minute)),
          runAt: at,
          priority: priority,
        );

    test('a higher priority is claimed first, equal priorities in queue '
        'order', () async {
      await store.enqueue(prioritised('low', 'a', -1, 0));
      await store.enqueue(prioritised('mid1', 'b', 0, 1));
      await store.enqueue(prioritised('high', 'c', 5, 2));
      await store.enqueue(prioritised('mid2', 'd', 0, 3));

      final claimed = await store.claimDue(at, 'o');

      expect(claimed.map((c) => c.id), ['high', 'mid1', 'mid2', 'low']);
    });

    test('the limit takes the most urgent runs', () async {
      await store.enqueue(prioritised('low', 'a', 0, 0));
      await store.enqueue(prioritised('high', 'b', 9, 1));

      final claimed = await store.claimDue(at, 'o', limit: 1);

      expect(claimed.single.id, 'high');
      expect((await reload('low')).state, TomJobRunState.pending);
    });

    test('a run keeps its priority in the store', () async {
      await store.enqueue(prioritised('p', 'a', 7, 0));
      expect((await reload('p')).priority, 7);
    });

    // -------------------------------------------------------------------------
    // Pausing a job
    // -------------------------------------------------------------------------

    TomJobRun ofJob(String id, String job, {int minute = 0}) => TomJobRun(
      id: id,
      jobName: job,
      scheduledFor: at.add(Duration(minutes: minute)),
      runAt: at,
    );

    test('a paused job\'s runs are not claimed; other jobs\' are', () async {
      await store.enqueue(ofJob('a1', 'paused'));
      await store.enqueue(ofJob('b1', 'live'));
      await store.pauseJob('paused', at);

      final claimed = await store.claimDue(at, 'o');

      expect(claimed.map((c) => c.id), ['b1']);
      expect((await reload('a1')).state, TomJobRunState.pending);
    });

    test('resuming makes the waiting runs claimable at once', () async {
      await store.enqueue(ofJob('a1', 'job2'));
      await store.pauseJob('job2', at);
      expect(await store.claimDue(at, 'o'), isEmpty);

      await store.resumeJob('job2');

      expect((await store.claimDue(at, 'o')).single.id, 'a1');
    });

    test('pausedJobs names each paused job and when it was paused; a second '
        'pause keeps the first instant', () async {
      final later = at.add(const Duration(hours: 1));
      await store.pauseJob('x', at);
      await store.pauseJob('x', later);
      await store.pauseJob('y', later);

      expect(await store.pausedJobs(), {'x': at, 'y': later});

      await store.resumeJob('x');
      await store.resumeJob('never-paused');
      expect(await store.pausedJobs(), {'y': later});
    });

    test('a paused job has no backlog', () async {
      await store.enqueue(ofJob('a1', 'paused'));
      await store.enqueue(ofJob('b1', 'live'));
      await store.pauseJob('paused', at);

      final backlog = await store.backlog(at);

      expect(backlog.map((b) => b.jobName), ['live']);
    });

    test('pausing does not touch a run already claimed', () async {
      await store.enqueue(ofJob('a1', 'job2'));
      final claim = (await store.claimDue(at, 'o')).single;
      await store.pauseJob('job2', at);

      await store.complete(claim, at);

      expect((await reload('a1')).state, TomJobRunState.succeeded);
    });

    // -------------------------------------------------------------------------
    // Checkpoints
    // -------------------------------------------------------------------------

    test('a saved checkpoint is stored with the run', () async {
      final claim = await seedClaimed();

      final stored = await store.saveCheckpoint(claim, {
        'offset': 500,
        'files': ['a', 'b'],
      });

      expect(stored, isTrue);
      expect((await reload('r1')).checkpoint, {
        'offset': 500,
        'files': ['a', 'b'],
      });
      expect(claim.run.checkpoint, {
        'offset': 500,
        'files': ['a', 'b'],
      });
    });

    test('a later save replaces the checkpoint, null clears it', () async {
      final claim = await seedClaimed();
      await store.saveCheckpoint(claim, {'offset': 1});
      await store.saveCheckpoint(claim, {'offset': 2});
      expect((await reload('r1')).checkpoint, {'offset': 2});

      await store.saveCheckpoint(claim, null);
      expect((await reload('r1')).checkpoint, isNull);
    });

    test('a recovered run is claimed again with its checkpoint', () async {
      await store.enqueue(makeRun('r1'));
      final first = (await store.claimDue(at, 'dead')).single;
      await store.markStarted(first, at);
      await store.saveCheckpoint(first, {'offset': 300});

      final later = at.add(const Duration(minutes: 20));
      await store.recoverAbandoned(later, const Duration(minutes: 15));
      final second = (await store.claimDue(later, 'survivor')).single;

      expect(second.run.checkpoint, {'offset': 300});
    });

    test('a retried run keeps its checkpoint', () async {
      final claim = await seedClaimed();
      await store.saveCheckpoint(claim, {'offset': 40});
      await store.fail(claim, 'boom', at, retryAt: at);

      final retry = (await store.claimDue(at, 'node-a')).single;

      expect(retry.run.checkpoint, {'offset': 40});
    });

    test('a save from a superseded claim is refused and changes '
        'nothing', () async {
      final stale = await seedSuperseded();

      expect(await store.saveCheckpoint(stale, {'offset': 9}), isFalse);
      expect((await reload('r1')).checkpoint, isNull);
    });

    test('a save for a finished run is refused', () async {
      final claim = await seedClaimed();
      await store.complete(claim, at);

      expect(await store.saveCheckpoint(claim, {'offset': 9}), isFalse);
      expect((await reload('r1')).checkpoint, isNull);
    });

    test('a checkpoint that is not JSON-encodable is refused before '
        'anything is written', () async {
      final claim = await seedClaimed();
      await store.saveCheckpoint(claim, {'offset': 1});

      await expectLater(
        store.saveCheckpoint(claim, {'when': DateTime.utc(2026)}),
        throwsA(
          isA<TomScheduleException>().having(
            (e) => e.key,
            'key',
            'schedule.job.checkpoint',
          ),
        ),
      );
      expect((await reload('r1')).checkpoint, {'offset': 1});
    });
  });
}

/// Declares the [TomLeaseLock] contract as a group named after [variant].
///
/// [create] must return a lock over a resource namespace with no live leases in
/// it, driven by the supplied clock.
void runTomLeaseLockContract(String variant, TomLeaseLockFactory create) {
  group('$variant (TomLeaseLock contract)', () {
    late FakeClock clock;
    late TomLeaseLock lock;

    setUp(() async {
      clock = FakeClock(DateTime.utc(2026, 5, 1, 12));
      lock = await create(clock.call);
      addTearDown(lock.close);
    });

    test('the first acquirer wins and the second is refused', () async {
      final first = await lock.acquire(
        'r',
        'node-a',
        const Duration(minutes: 1),
      );
      final second = await lock.acquire(
        'r',
        'node-b',
        const Duration(minutes: 1),
      );

      expect(first, isNotNull);
      expect(first!.owner, 'node-a');
      expect(second, isNull, reason: 'node-b must not get a second lease');
    });

    test('an unheld resource reports free', () async {
      final info = await lock.inspect('r');
      expect(info.isHeld, isFalse);
      expect(info.lease, isNull);
    });

    test('inspect names the holder and its expiry without acquiring', () async {
      await lock.acquire('r', 'node-a', const Duration(minutes: 1));

      final info = await lock.inspect('r');
      expect(info.isHeld, isTrue);
      expect(info.lease!.owner, 'node-a');
      expect(info.lease!.expiresAt, clock.now.add(const Duration(minutes: 1)));
      // Inspecting must not disturb the lease.
      expect(
        await lock.acquire('r', 'node-b', const Duration(minutes: 1)),
        isNull,
      );
    });

    test('a lapsed lease is taken over by the next acquirer', () async {
      final first = await lock.acquire(
        'r',
        'node-a',
        const Duration(minutes: 1),
      );
      clock.advance(const Duration(minutes: 2));

      final second = await lock.acquire(
        'r',
        'node-b',
        const Duration(minutes: 1),
      );

      expect(second, isNotNull, reason: 'a dead holder must not block forever');
      expect(second!.owner, 'node-b');
      expect(
        second.token,
        greaterThan(first!.token),
        reason: 'takeover must fence the previous holder out',
      );
    });

    test('a released lease frees the resource immediately', () async {
      final first = await lock.acquire(
        'r',
        'node-a',
        const Duration(minutes: 10),
      );
      await lock.release(first!);

      final second = await lock.acquire(
        'r',
        'node-b',
        const Duration(minutes: 1),
      );
      expect(second, isNotNull, reason: 'release must not wait out the TTL');
      expect(second!.token, greaterThan(first.token));
    });

    test('release reports the holder as gone but not vanished', () async {
      final lease = await lock.acquire(
        'r',
        'node-a',
        const Duration(minutes: 10),
      );
      await lock.release(lease!);

      final info = await lock.inspect('r');
      expect(info.isHeld, isFalse);
      expect(
        info.holderVanished,
        isFalse,
        reason: 'an orderly release is not a disappearance',
      );
    });

    test('a lapsed holder is reported as vanished', () async {
      await lock.acquire('r', 'node-a', const Duration(minutes: 1));
      clock.advance(const Duration(minutes: 2));

      final info = await lock.inspect('r');
      expect(info.isHeld, isFalse);
      expect(info.holderVanished, isTrue);
      expect(
        info.lease!.owner,
        'node-a',
        reason: 'the vanished holder must still be nameable',
      );
    });

    test('renewal pushes the expiry forward and keeps the token', () async {
      final lease = await lock.acquire(
        'r',
        'node-a',
        const Duration(minutes: 1),
      );
      clock.advance(const Duration(seconds: 30));

      final renewed = await lock.renew(lease!, const Duration(minutes: 1));

      expect(renewed, isNotNull);
      expect(renewed!.expiresAt, clock.now.add(const Duration(minutes: 1)));
      expect(
        renewed.token,
        lease.token,
        reason: 'renewing is not re-acquiring; the fence must not move',
      );
    });

    test('renewal keeps a long job safe past its original TTL', () async {
      var lease = await lock.acquire('r', 'node-a', const Duration(minutes: 1));

      // Four renewals across four minutes: a job far outliving the TTL.
      for (var i = 0; i < 4; i++) {
        clock.advance(const Duration(seconds: 40));
        lease = await lock.renew(lease!, const Duration(minutes: 1));
        expect(lease, isNotNull, reason: 'renewal $i must succeed');
        expect(
          await lock.acquire('r', 'node-b', const Duration(minutes: 1)),
          isNull,
          reason: 'a renewed lease must never look free to a peer',
        );
      }
    });

    test('a lease that was taken over can no longer be renewed', () async {
      final first = await lock.acquire(
        'r',
        'node-a',
        const Duration(minutes: 1),
      );
      clock.advance(const Duration(minutes: 2));
      await lock.acquire('r', 'node-b', const Duration(minutes: 1));

      // node-a wakes up late and tries to carry on.
      expect(
        await lock.renew(first!, const Duration(minutes: 1)),
        isNull,
        reason: 'the displaced holder must learn it is displaced',
      );
    });

    test(
      'releasing a lease already taken over does not disturb the new holder',
      () async {
        final first = await lock.acquire(
          'r',
          'node-a',
          const Duration(minutes: 1),
        );
        clock.advance(const Duration(minutes: 2));
        final second = await lock.acquire(
          'r',
          'node-b',
          const Duration(minutes: 1),
        );

        // The classic late-release bug: node-a finishes, releases, and frees a
        // lock it no longer owns.
        await lock.release(first!);

        final info = await lock.inspect('r');
        expect(info.isHeld, isTrue);
        expect(info.lease!.owner, 'node-b');
        expect(info.lease!.token, second!.token);
      },
    );

    test(
      'the holder re-acquiring its own lease extends rather than conflicts',
      () async {
        final first = await lock.acquire(
          'r',
          'node-a',
          const Duration(minutes: 1),
        );
        clock.advance(const Duration(seconds: 10));

        final again = await lock.acquire(
          'r',
          'node-a',
          const Duration(minutes: 1),
        );

        expect(again, isNotNull, reason: 'a node must not lock itself out');
        expect(again!.token, first!.token);
      },
    );

    test('fencing tokens increase strictly across takeovers', () async {
      final tokens = <int>[];
      for (var i = 0; i < 5; i++) {
        final lease = await lock.acquire(
          'r',
          'node-$i',
          const Duration(minutes: 1),
        );
        tokens.add(lease!.token);
        clock.advance(const Duration(minutes: 2));
      }

      // Strict monotonicity is the whole value of a fencing token: a repeated
      // token would let a stale holder's write past a token check.
      for (var i = 1; i < tokens.length; i++) {
        expect(tokens[i], greaterThan(tokens[i - 1]));
      }
    });

    test(
      'fencing tokens keep increasing across release and re-acquire',
      () async {
        final a = await lock.acquire('r', 'node-a', const Duration(minutes: 1));
        await lock.release(a!);
        final b = await lock.acquire('r', 'node-b', const Duration(minutes: 1));
        await lock.release(b!);
        final c = await lock.acquire('r', 'node-c', const Duration(minutes: 1));

        expect(b.token, greaterThan(a.token));
        expect(c!.token, greaterThan(b.token));
      },
    );

    test('forget discards a one-shot resource, token chain and all', () async {
      // The one operation that is not bookkeeping: it erases history. It is
      // typed to take only a TomOneShotResource because of what the second
      // acquisition shows — the chain restarts, and a token that repeats is
      // not a fencing token. For a name that is never acquired again that
      // costs nothing; for a recurring one it un-orders every holder.
      final resource = TomOneShotResource.run('forgotten-run');
      final first = await lock.acquire(
        resource,
        'node-a',
        const Duration(minutes: 1),
      );
      await lock.release(first!);

      await lock.forget(resource);

      final info = await lock.inspect(resource);
      expect(info.lease, isNull, reason: 'no record survives a forget');
      expect(info.wasReleased, isFalse);
      final again = await lock.acquire(
        resource,
        'node-b',
        const Duration(minutes: 1),
      );
      expect(again!.token, first.token, reason: 'the chain restarted');
    });

    test('forget leaves every other resource alone', () async {
      final kept = await lock.acquire(
        'job:kept',
        'node-a',
        const Duration(minutes: 1),
      );

      await lock.forget(TomOneShotResource.run('other'));

      expect((await lock.inspect('job:kept')).lease?.token, kept!.token);
    });

    test('different resources do not contend', () async {
      expect(
        await lock.acquire('a', 'node-a', const Duration(minutes: 1)),
        isNotNull,
      );
      expect(
        await lock.acquire('b', 'node-b', const Duration(minutes: 1)),
        isNotNull,
      );
    });
  });
}

/// The behaviour every [TomJobStore] and every [TomLeaseLock] must exhibit,
/// written once and run against every implementation.
///
/// ## Why this file exists, and why it lives in `test/`
///
/// The kernel ships two implementations of each port (memory and file); the
/// relational pair lives one layer up in `tom_core_server`, over the same
/// contract. A second implementation that merely *resembles* the first is not
/// good enough — during csex8 this very suite caught a file-lock divergence in
/// which a live holder re-acquiring its own lease was issued a *new* fencing
/// token, silently fencing itself out. So the suite is the shared artefact and
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
      expect(claimed.single.state, TomJobRunState.running);
      expect(claimed.single.claimedBy, 'owner-1');
      expect(claimed.single.claimedAt, at);
    });

    test('claimDue leaves a future run alone', () async {
      await store.enqueue(
        makeRun('a', runAt: at.add(const Duration(minutes: 1))),
      );
      expect(await store.claimDue(at, 'owner-1'), isEmpty);
    });

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
    Future<TomJobRun> seedPurged({required bool succeeded}) async {
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

    test('complete ignores a run the store never held', () async {
      await store.complete(makeRun('ghost'), at);
      expect(await store.all(), isEmpty);
    });

    test('fail ignores a run the store never held', () async {
      await store.fail(makeRun('ghost'), 'nope', at);
      expect(await store.all(), isEmpty);
    });

    test('complete ignores a run that is not running', () async {
      final run = makeRun('r1');
      await store.enqueue(run);

      await store.complete(run, at);

      final stored = await reload('r1');
      expect(stored.state, TomJobRunState.pending);
      expect(stored.completedAt, isNull);
    });

    test('fail ignores a run that is not running', () async {
      final run = makeRun('r1');
      await store.enqueue(run);

      await store.fail(run, 'nope', at);

      final stored = await reload('r1');
      expect(stored.state, TomJobRunState.pending);
      expect(stored.lastError, isNull);
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

    Future<TomJobRun> seedClaimed() async {
      await store.enqueue(makeRun('r1'));
      return (await store.claimDue(at, 'node-a')).single;
    }

    test(
      'release returns a claimed run to pending without charging an attempt',
      () async {
        final run = await seedClaimed();
        expect(run.state, TomJobRunState.running);

        await store.release(run);

        final stored = await reload('r1');
        expect(stored.state, TomJobRunState.pending);
        expect(stored.claimedBy, isNull);
        // Contention is not failure. Charging an attempt would let a busy cluster
        // burn a job's whole retry budget without ever executing it.
        expect(stored.attempt, 1);
      },
    );

    test('a released run is immediately claimable again', () async {
      final run = await seedClaimed();
      await store.release(run);

      final claimed = await store.claimDue(at, 'node-b');
      expect(claimed.single.id, run.id);
      expect(claimed.single.claimedBy, 'node-b');
    });

    test('release does not resurrect a finished run', () async {
      final run = await seedClaimed();
      await store.complete(run, at);

      await store.release(run);

      expect(
        (await reload('r1')).state,
        TomJobRunState.succeeded,
        reason: 'a completion that raced a release must win',
      );
    });

    test(
      'renewClaim refreshes the lease so recovery leaves the run alone',
      () async {
        final run = await seedClaimed();
        const leaseTimeout = Duration(minutes: 10);

        final later = at.add(const Duration(minutes: 9));
        await store.renewClaim(run, later);

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

      await store.renewClaim(run, at);

      expect((await reload('r1')).claimedAt, isNull);
    });

    // -------------------------------------------------------------------------
    // markStarted, and the recovery branch it exists to enable
    // -------------------------------------------------------------------------

    test('a claimed run has not started until it is marked', () async {
      final run = await seedClaimed();
      expect(run.startedAt, isNull);
      expect(
        (await reload('r1')).startedAt,
        isNull,
        reason: 'a reservation is not an execution',
      );
    });

    test('markStarted stamps the run and survives a reload', () async {
      final run = await seedClaimed();
      final started = at.add(const Duration(seconds: 3));

      await store.markStarted(run, started);

      expect(run.startedAt, started, reason: 'the caller sees its own write');
      expect((await reload('r1')).startedAt, started);
    });

    test('markStarted ignores a run that is not running', () async {
      final run = makeRun('r1');
      await store.enqueue(run);

      await store.markStarted(run, at);

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

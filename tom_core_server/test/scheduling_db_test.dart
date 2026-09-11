/// DB-backed tests for the relational scheduling pair.
///
/// Two halves, and the first is the important one.
///
/// **The shared contract.** `TomSqlJobStore` and `TomSqlLeaseLock` are run
/// against the *same* parameterised suite the kernel runs its own
/// implementations against, imported unmodified from
/// `tom_core_kernel/test/contracts/scheduling_contract.dart`. That is the point
/// of extracting it: a second implementation is then verified against the
/// required behaviour rather than merely resembling the first. The suite has
/// already earned this once, catching a file-lock divergence in which the live
/// holder re-acquiring its own lease was issued a *new* fencing token, quietly
/// fencing itself out.
///
/// **Integration.** What only a real server can substantiate: that the database
/// arbitrates a contended claim to exactly one winner across independent
/// connections, that a dead holder's work is recovered, and that the shipped
/// migration files build the schema on a clean database.
///
/// The whole file is `@Tags(['db'])` and skips itself when no MariaDB is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring a
/// server up with `tool/run_db_tests.sh`.
@Tags(['db'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

// The port contracts, defined once in the package that owns the abstractions.
// A relative import across package boundaries is unusual; the alternatives were
// weighed and rejected at the definition site (chiefly: putting it in the
// kernel's `lib/` would make `package:test` a regular dependency of every
// consumer, including Flutter apps). The two packages are siblings in this
// monorepo by construction.
import '../../tom_core_kernel/test/contracts/scheduling_contract.dart';
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// A migration directory shaped the way [TomDbMigrations.migrateDatabases]
/// expects — `<dir>/<datasource>/<schema>/` — holding the *shipped* migration
/// files verbatim.
///
/// Copying rather than re-typing the DDL is deliberate: the test then proves
/// that the files a deployment actually applies build a working schema, not
/// that some parallel copy of them does.
/// The migration schema name the reference migrations are applied under. Also
/// names the orchestrator's bookkeeping table, `<schema>_versioning`.
const String _migrationSchema = 'tomscheduling';

Directory _migrationDirectory() {
  final root = Directory.systemTemp.createTempSync('tom_scheduling_migration_');
  final target = Directory(
    '${root.path}/${TestDatabase.datasourceName}/$_migrationSchema',
  )..createSync(recursive: true);
  final source = Directory('example/scheduling/migrations/main/tomcore');
  for (final file in source.listSync().whereType<File>()) {
    file.copySync('${target.path}/${file.uri.pathSegments.last}');
  }
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  return root;
}

TomJobRun _run(String id, DateTime at) =>
    TomJobRun(id: id, jobName: 'job', scheduledFor: at, runAt: at);

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('relational scheduling over MariaDB', () {
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      // Dropped, not truncated: the stores create their tables on first use, so
      // a previous run with a different DDL would otherwise persist. Dropping
      // also clears `tom_lease`, whose rows *are* the fencing counters.
      await TestDatabase.dropSchedulingTables(dsi);
    });

    tearDownAll(TestDatabase.reset);

    // -------------------------------------------------------------------------
    // The kernel's own contract, unmodified
    // -------------------------------------------------------------------------

    runTomJobStoreContract('TomSqlJobStore', () async {
      final store = TomSqlJobStore(dsi.datasource);
      await store.deleteAll();
      return store;
    });

    runTomLeaseLockContract('TomSqlLeaseLock', (clock) async {
      final lock = TomSqlLeaseLock(dsi.datasource, clock: clock);
      await lock.deleteAll();
      return lock;
    });

    // -------------------------------------------------------------------------
    // What only a real database can show
    // -------------------------------------------------------------------------

    group('the database arbitrates', () {
      final at = DateTime.utc(2026, 5, 1, 12);
      late TomSqlJobStore store;

      setUp(() async {
        store = TomSqlJobStore(dsi.datasource);
        await store.deleteAll();
      });

      test('two nodes racing one due run produce exactly one winner', () async {
        await store.enqueue(_run('contended', at));

        // Two store objects, as two nodes would have. The claim is a conditional
        // UPDATE, so the loser sees zero affected rows and simply gets nothing —
        // no exception, no retry, no application-side lock.
        final a = TomSqlJobStore(dsi.datasource);
        final b = TomSqlJobStore(dsi.datasource);
        final results = await Future.wait([
          a.claimDue(at, 'node-a'),
          b.claimDue(at, 'node-b'),
        ]);

        final winners = results.expand((claims) => claims).toList();
        expect(
          winners,
          hasLength(1),
          reason:
              'exactly one node may hold the run, got '
              '${winners.map((c) => c.owner)}',
        );
        expect((await store.all()).single.state, TomJobRunState.running);
      });

      test('a rejected candidate stays claimable by a peer', () async {
        await store.enqueue(_run('skipped', at));

        // The accept predicate refuses everything. Had the store batch-claimed
        // first and released the rejects, this run would have been momentarily
        // `running` and a peer scanning in that window would have missed it.
        final mine = await store.claimDue(at, 'node-a', accept: (_) => false);
        expect(mine, isEmpty);

        final theirs = await store.claimDue(at, 'node-b');
        expect(theirs.single.id, 'skipped');
      });

      test(
        'the window uniqueness constraint is enforced by the database',
        () async {
          await store.enqueue(_run('first', at));
          // A second run for the same (job, window) under a different id: the
          // scheduler's idempotence key as a database invariant. REPLACE resolves
          // it by superseding, so the queue holds one row, not two.
          await store.enqueue(_run('second', at));

          final all = await store.all();
          expect(all, hasLength(1));
          expect(all.single.id, 'second');
        },
      );

      test(
        "a dead holder's run is recovered and taken by a survivor",
        () async {
          await store.enqueue(_run('orphan', at));
          final claimed = await store.claimDue(at, 'node-that-dies');
          expect(claimed, hasLength(1));

          // "Death" is simply never completing and never renewing. A survivor
          // arriving after the lease timeout recovers the row and re-claims it.
          final later = at.add(const Duration(minutes: 20));
          final survivor = TomSqlJobStore(dsi.datasource);
          final recovered = await survivor.recoverAbandoned(
            later,
            const Duration(minutes: 15),
          );
          expect(recovered.single.id, 'orphan');

          final retaken = await survivor.claimDue(later, 'node-b');
          expect(retaken.single.owner, 'node-b');
          // Recovery is not failure: the run must not have burned an attempt.
          expect(retaken.single.run.attempt, 1);
        },
      );

      test(
        'a renewed claim is left alone by a peer running recovery',
        () async {
          await store.enqueue(_run('long', at));
          final claimed = (await store.claimDue(at, 'node-a')).single;

          final peer = TomSqlJobStore(dsi.datasource);
          for (var i = 0; i < 4; i++) {
            final now = at.add(Duration(minutes: 9 * (i + 1)));
            await store.renewClaim(claimed, now);
            expect(
              await peer.recoverAbandoned(now, const Duration(minutes: 10)),
              isEmpty,
              reason: 'renewal $i must keep the run out of recovery',
            );
          }
        },
      );
    });

    // -------------------------------------------------------------------------
    // What a cluster needs beyond a working claim
    // -------------------------------------------------------------------------

    group('recovery distinguishes claimed from started', () {
      final at = DateTime.utc(2026, 5, 1, 12);
      final later = at.add(const Duration(minutes: 20));
      const leaseTimeout = Duration(minutes: 15);
      late TomSqlJobStore store;

      setUp(() async {
        store = TomSqlJobStore(dsi.datasource);
        await store.deleteAll();
      });

      test(
        'when execution began survives the store object that recorded it',
        () async {
          await store.enqueue(_run('started', at));
          final claimed = (await store.claimDue(at, 'node-a')).single;
          expect(
            claimed.run.startedAt,
            isNull,
            reason: 'a claim is not a start; the dispatcher marks the start',
          );

          final begun = at.add(const Duration(seconds: 5));
          await store.markStarted(claimed, begun);

          // Read back through a second store object — which is what the surviving
          // node is. The whole opt-in recovery rule rests on this column being
          // legible to a *peer*, not merely remembered in this process.
          final peer = TomSqlJobStore(dsi.datasource);
          expect((await peer.all()).single.startedAt, begun);
        },
      );

      test('a run claimed but never started is re-queued even when its job '
          'declines recovery', () async {
        await store.enqueue(_run('never-ran', at));
        await store.claimDue(at, 'node-that-dies');

        final survivor = TomSqlJobStore(dsi.datasource);
        final recovered = await survivor.recoverAbandoned(
          later,
          leaseTimeout,
          requestsRecovery: (_) => false,
        );

        // Nothing ran, so nothing can be repeated: the opt-in does not apply.
        expect(recovered.single.state, TomJobRunState.pending);
        expect(
          (await survivor.claimDue(later, 'node-b')).single.id,
          'never-ran',
        );
      });

      test('an interrupted run is re-queued only when its job asks', () async {
        await store.enqueue(_run('interrupted', at));
        final claimed = (await store.claimDue(at, 'node-that-dies')).single;
        await store.markStarted(claimed, at.add(const Duration(seconds: 5)));

        final survivor = TomSqlJobStore(dsi.datasource);
        final recovered = await survivor.recoverAbandoned(
          later,
          leaseTimeout,
          requestsRecovery: (_) => false,
        );

        // Written off rather than re-queued, and *stated* rather than left as a
        // silent gap: an operator reading the row must see why it was not run
        // again.
        final row = recovered.single;
        expect(row.state, TomJobRunState.failed);
        expect(row.completedAt, later);
        expect(row.lastError, TomJobStore.recoveryDeclinedError);
        expect(await survivor.claimDue(later, 'node-b'), isEmpty);
      });

      test('an interrupted run whose job opts in is re-queued', () async {
        await store.enqueue(_run('retryable', at));
        final claimed = (await store.claimDue(at, 'node-that-dies')).single;
        await store.markStarted(claimed, at.add(const Duration(seconds: 5)));

        final survivor = TomSqlJobStore(dsi.datasource);
        final recovered = await survivor.recoverAbandoned(
          later,
          leaseTimeout,
          requestsRecovery: (_) => true,
        );

        expect(recovered.single.state, TomJobRunState.pending);
        final retaken = await survivor.claimDue(later, 'node-b');
        expect(retaken.single.owner, 'node-b');
        // Recovery is not failure, so the retry budget is untouched.
        expect(retaken.single.run.attempt, 1);
      });
    });

    group('the roll call', () {
      final at = DateTime.utc(2026, 5, 1, 12);
      late TomSqlSchedulerNodes roll;

      setUp(() async {
        roll = TomSqlSchedulerNodes(dsi.datasource, nodeId: 'node-a');
        await roll.deleteAll();
      });

      test(
        'a check-in is one row per node, rewritten and not appended',
        () async {
          await roll.checkIn(at);
          await roll.checkIn(at.add(const Duration(seconds: 30)));

          final rows = await roll.nodes();
          expect(rows, hasLength(1));
          expect(rows.single.nodeId, 'node-a');
          expect(rows.single.checkinAt, at.add(const Duration(seconds: 30)));
          expect(rows.single.checkinInterval, roll.checkinInterval);
        },
      );

      test(
        'a peer that stopped checking in is reported failed, and only then',
        () async {
          final peer = TomSqlSchedulerNodes(
            dsi.datasource,
            nodeId: 'node-b',
            checkinInterval: const Duration(seconds: 30),
          );
          await peer.checkIn(at);
          await roll.checkIn(at);

          // Inside the peer's own interval plus the slack: alive.
          expect(
            await roll.failedNodes(at.add(const Duration(seconds: 20))),
            isEmpty,
          );

          // Past it — but the accuser has to be current too, so it checks in
          // first. A judgement made without that would be the stalled accuser the
          // formula exists to prevent.
          final late_ = at.add(const Duration(minutes: 5));
          await roll.checkIn(late_);
          final failed = await roll.failedNodes(late_);
          expect(
            failed.map((n) => n.nodeId),
            ['node-b'],
            reason: 'a node never reports itself failed',
          );
        },
      );

      test(
        "a departed node's work is recovered before its lease would lapse",
        () async {
          final store = TomSqlJobStore(dsi.datasource, nodes: roll);
          await store.deleteAll();
          await roll.deleteAll();

          // The dead node claims a run, then stops — both its heartbeat and its
          // renewals.
          final dead = TomSqlSchedulerNodes(
            dsi.datasource,
            nodeId: 'node-that-dies',
            checkinInterval: const Duration(seconds: 30),
          );
          await dead.checkIn(at);
          await store.enqueue(_run('orphan', at));
          expect(await store.claimDue(at, 'node-that-dies'), hasLength(1));

          // Two minutes later: far short of the fifteen-minute lease, so lease
          // expiry alone would still be waiting. The roll call is what makes the
          // difference, and this is the whole point of GAP 2.
          final soon = at.add(const Duration(minutes: 2));
          final recovered = await store.recoverAbandoned(
            soon,
            const Duration(minutes: 15),
          );

          expect(recovered.map((r) => r.id), ['orphan']);
          expect((await store.claimDue(soon, 'node-a')).single.owner, 'node-a');
          // The departed node is forgotten once its work is reattributed, so the
          // next pass does not re-scan a node that has nothing left.
          expect(
            (await roll.nodes()).map((n) => n.nodeId),
            isNot(contains('node-that-dies')),
          );
        },
      );

      test('a live node keeps its work, roll call or not', () async {
        final store = TomSqlJobStore(dsi.datasource, nodes: roll);
        await store.deleteAll();
        await roll.deleteAll();

        final peer = TomSqlSchedulerNodes(
          dsi.datasource,
          nodeId: 'node-b',
          checkinInterval: const Duration(seconds: 30),
        );
        await peer.checkIn(at);
        await store.enqueue(_run('busy', at));
        final claimed = (await store.claimDue(at, 'node-b')).single;

        final soon = at.add(const Duration(minutes: 2));
        await peer.checkIn(soon);
        await store.renewClaim(claimed, soon);

        expect(
          await store.recoverAbandoned(soon, const Duration(minutes: 15)),
          isEmpty,
        );
      });
    });

    group('the lease lock arbitrates', () {
      late TomSqlLeaseLock lock;
      final clock = FakeClock(DateTime.utc(2026, 5, 1, 12));

      setUp(() async {
        clock.now = DateTime.utc(2026, 5, 1, 12);
        lock = TomSqlLeaseLock(dsi.datasource, clock: clock.call);
        await lock.deleteAll();
      });

      test(
        'concurrent acquirers of a free resource produce exactly one winner',
        () async {
          const racers = 8;
          // Eight independent lock objects going for the same row at once. The
          // first acquisition is an INSERT IGNORE, so the primary key does the
          // arbitrating and seven of them see zero affected rows.
          final leases = await Future.wait([
            for (var i = 0; i < racers; i++)
              TomSqlLeaseLock(
                dsi.datasource,
                clock: clock.call,
              ).acquire('contended', 'node-$i', const Duration(minutes: 5)),
          ]);

          final winners = leases.whereType<TomLease>().toList();
          expect(
            winners,
            hasLength(1),
            reason:
                'exactly one of $racers may hold the lease, got '
                '${winners.map((l) => l.owner)}',
          );
        },
      );

      test(
        'concurrent acquirers of a lapsed lease produce exactly one winner',
        () async {
          // Seed an already-expired lease so every racer arrives at the *takeover*
          // path together — the compare-and-set on (token, version), which is
          // where a naive implementation double-grants.
          final dead = await lock.acquire(
            'contended',
            'dead-node',
            const Duration(minutes: 1),
          );
          clock.advance(const Duration(minutes: 2));

          const racers = 8;
          final leases = await Future.wait([
            for (var i = 0; i < racers; i++)
              TomSqlLeaseLock(
                dsi.datasource,
                clock: clock.call,
              ).acquire('contended', 'node-$i', const Duration(minutes: 5)),
          ]);

          final winners = leases.whereType<TomLease>().toList();
          expect(
            winners,
            hasLength(1),
            reason:
                'a lapsed lease may be taken over by exactly one node, got '
                '${winners.map((l) => '${l.owner}#${l.token}')}',
          );
          expect(
            winners.single.token,
            greaterThan(dead!.token),
            reason: 'a takeover must fence the dead holder out',
          );
        },
      );

      test('a lease survives the object that created it', () async {
        await lock.acquire('r', 'node-a', const Duration(minutes: 5));

        // A second lock object over the same table is what a second *process*
        // sees. It must observe the first one's lease.
        final other = TomSqlLeaseLock(dsi.datasource, clock: clock.call);
        expect(
          await other.acquire('r', 'node-b', const Duration(minutes: 5)),
          isNull,
        );
        expect((await other.inspect('r')).lease!.owner, 'node-a');
      });

      test('a holder that dies without releasing is taken over once its lease '
          'lapses', () async {
        final lost = await lock.acquire(
          'r',
          'node-a',
          const Duration(minutes: 1),
        );
        clock.advance(const Duration(minutes: 2));

        final survivor = TomSqlLeaseLock(dsi.datasource, clock: clock.call);
        final taken = await survivor.acquire(
          'r',
          'node-b',
          const Duration(minutes: 1),
        );

        expect(taken, isNotNull);
        expect(taken!.token, greaterThan(lost!.token));
        // The distinction an operator needs after an incident.
        expect((await survivor.inspect('r')).lease!.owner, 'node-b');
      });

      test(
        'the fencing counter survives release, so a token never repeats',
        () async {
          final seen = <int>[];
          for (var i = 0; i < 5; i++) {
            final lease = await lock.acquire(
              'r',
              'node-$i',
              const Duration(minutes: 1),
            );
            seen.add(lease!.token);
            await lock.release(lease);
          }
          // Deleting the row on release would restart at 1 — which is exactly the
          // reason the row is flagged rather than removed.
          expect(seen, [1, 2, 3, 4, 5]);
        },
      );

      test('resource names that are not filesystem-safe still work', () async {
        // Run ids embed the job name and a timestamp with colons and slashes.
        // Unlike the file lock, this store has no encoding to get wrong — the
        // test guards the contract, not the implementation.
        const nasty = 'run:nightly/report:2026-05-01T00:00:00.000Z';
        expect(
          await lock.acquire(nasty, 'node-a', const Duration(minutes: 1)),
          isNotNull,
        );
        expect(
          await lock.acquire(nasty, 'node-b', const Duration(minutes: 1)),
          isNull,
        );
      });

      test('forget removes the resource, counter and all', () async {
        final first = await lock.acquire(
          'r',
          'node-a',
          const Duration(minutes: 1),
        );
        await lock.forget(TomOneShotResource.unique('r'));

        expect((await lock.inspect('r')).lease, isNull);
        final again = await lock.acquire(
          'r',
          'node-b',
          const Duration(minutes: 1),
        );
        // The counter restarted, which is why forget() must stay restricted to
        // per-run resource names that are never reused.
        expect(again!.token, first!.token);
      });
    });

    group('the shipped migration builds the schema', () {
      test('on a clean database, and the stores then work against it', () async {
        await TestDatabase.dropSchedulingTables(dsi);
        // "Clean database" has to include the orchestrator's own record of what
        // it has applied. Without this the second run of the suite against the
        // same server finds versions 1 and 2 already recorded, applies nothing,
        // and the tables it just dropped stay dropped.
        await TestDatabase.dropMigrationVersioning(dsi, _migrationSchema);

        await TomDbMigrations.migrateDatabases(_migrationDirectory().path);

        // `createSchema: false` is the deployment shape this migration exists
        // for: the application user may not run DDL, so if the migration did not
        // build the tables, these calls fail.
        final store = TomSqlJobStore(dsi.datasource, createSchema: false);
        final lock = TomSqlLeaseLock(dsi.datasource, createSchema: false);
        final roll = TomSqlSchedulerNodes(
          dsi.datasource,
          nodeId: 'node-a',
          createSchema: false,
        );
        final at = DateTime.utc(2026, 5, 1, 12);

        await store.enqueue(_run('migrated', at));
        final claimed = (await store.claimDue(at, 'node-a')).single;
        expect(claimed.id, 'migrated');
        // Exercises `started_at`, the column the migration gained with the
        // opt-in recovery rule: a file that forgot it would pass every other
        // assertion here.
        await store.markStarted(claimed, at);
        expect((await store.all()).single.startedAt, at);
        expect(
          await lock.acquire('r', 'node-a', const Duration(minutes: 1)),
          isNotNull,
        );
        await roll.checkIn(at);
        expect((await roll.nodes()).single.nodeId, 'node-a');

        await store.deleteAll();
        await lock.deleteAll();
        await roll.deleteAll();
      });
    });
  }, skip: skipReason);
}

/// Executable example for the relational scheduling module of
/// `tom_core_server`.
///
/// [TomSqlJobStore] and [TomSqlLeaseLock] are the multi-node production pair
/// behind the kernel's `TomJobStore` / `TomLeaseLock` contracts: one shared
/// queue and one shared lock, in the database a server already has. Their
/// interesting behaviour — that a contended claim resolves to exactly one winner
/// and that a lapsed lease is taken over once — is *arbitrated by the database*
/// and so cannot be shown without one; it is asserted live in
/// `test/scheduling_db_test.dart`.
///
/// The arbitration itself — between *processes* rather than within one — is
/// demonstrated by `example/scheduling/cluster/`: two real nodes against one
/// MariaDB, asserting that a job fires once across the pair, that a stale
/// fencing token no longer authorises a write, that a killed node's run returns
/// to the queue when its lease expires and not before, and that a node which
/// stops checking in is named failed. Run it with
/// `./example/scheduling/cluster/run_cluster_demo.sh` (docker required); see
/// `example/scheduling/cluster/readme.md`.
///
/// What this example does show, connection-free: the schema the pair relies on
/// and why each part of it is load-bearing, the on-disk migration layout that
/// creates it in a deployment, the UTC instant encoding both stores use, the two
/// cluster decisions that are pure functions — when a peer node counts as failed
/// ([isSchedulerNodeFailed]) and whether a failed write leaves the claim in
/// doubt ([classifySqlFailure]) — the wiring, including the error you get
/// when the named data source is not registered, and the columns and tables
/// that carry priority, paused jobs, checkpoints and the run archive.
///
/// Run with `dart run example/scheduling/scheduling_example.dart`. Every step
/// checks its own result and the run fails when one does not hold, so a green
/// run is a verification and not just a transcript.
/// The same behaviour is covered by `test/scheduling_schema_test.dart` (schema
/// and encoding) and `test/scheduling_db_test.dart` (the live behaviour).
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

void run() {
  // 1. The queue table. The unique key on (job_name, tenant, scheduled_for)
  //    is the point: it makes the scheduler's idempotence key — one run per
  //    job per window, per tenant — a database invariant rather than a
  //    convention, so two nodes planning the same window at the same moment
  //    cannot both succeed.
  final queueDdl = jobRunTableDdl(defaultJobRunTable);
  print('1. queue table `$defaultJobRunTable`:');
  print(queueDdl);
  check(
    queueDdl.contains(
      'UNIQUE KEY uq_tom_job_run_window '
      '(job_name, tenant, window_at)',
    ),
    'the database itself enforces one run per job per window and tenant',
  );

  // 2. The lease table. `token` is the fencing counter and is why a released
  //    lease keeps its row (flagged `released = 1`) instead of being deleted: a
  //    deleted row would restart the counter at 1 for the next holder, and a
  //    token that repeats is not a fencing token. `version` exists because
  //    MariaDB reports *changed* rows, not matched rows — without it a renewal
  //    writing the values already present would affect zero rows and look like a
  //    lost lease.
  final leaseDdl = leaseTableDdl(defaultLeaseTable);
  print('\n2. lease table `$defaultLeaseTable`:');
  print(leaseDdl);
  check(
    leaseDdl.contains('token       BIGINT       NOT NULL'),
    'a lease carries a fencing counter every holder must present',
  );
  check(
    leaseDdl.contains('version     BIGINT       NOT NULL DEFAULT 1'),
    'a renewal that writes the same values still touches a row',
  );

  // 3. The table name is a constructor argument, so the index names follow it.
  //    Two queues over one schema would otherwise collide on `uq_..._window`.
  final other = jobRunTableDdl('billing_job_run');
  print('\n3. a second queue in the same schema gets its own index names:');
  print(
    '   ${other.contains('uq_billing_job_run_window') ? 'uq_billing_job_run_window' : '(missing)'}',
  );
  check(
    other.contains('uq_billing_job_run_window'),
    'two queues can share one schema without colliding',
  );

  // 4. Instants are stored as fixed-width UTC DATETIME(6) literals. Fixed width
  //    keeps the text ordered in SQL exactly as the instants are ordered in
  //    Dart, so a `run_at <= :now` comparison cannot be surprised by a shorter
  //    fraction; UTC keeps a cluster from ever comparing wall clocks.
  final window = DateTime.utc(2026, 3, 1, 10, 20, 30, 400, 500);
  final encoded = sqlInstant(window);
  final decoded = parseSqlInstant(encoded);
  print('\n4. instant encoding: $window -> "$encoded" -> $decoded');
  check(
    encoded == '2026-03-01 10:20:30.400500',
    'an instant is fixed width, so SQL orders text as Dart orders time',
  );
  check(decoded == window, 'an encoded instant round-trips unchanged');
  check(decoded.isUtc, 'a decoded instant is never a wall clock');

  // A local instant round-trips as the same *moment*, labelled UTC — the store
  // hands every caller back a UTC instant regardless of what it was given.
  final local = DateTime(2026, 3, 1, 10, 20, 30);
  final normalised = parseSqlInstant(sqlInstant(local));
  print(
    '   a local instant comes back as UTC: '
    '$normalised (same moment: ${normalised.isAtSameMomentAs(local)})',
  );
  check(
    normalised.isUtc && normalised.isAtSameMomentAs(local),
    'a local instant comes back as the same moment, labelled UTC',
  );

  // 5. The roll call. One row per node, rewritten on every check-in, so the
  //    cluster can notice a departed *node* rather than only an expired lease.
  //    `node_id` is the same string the node claims runs under, which is what
  //    lets a failed node's work join straight back to it.
  final nodeDdl = schedulerNodeTableDdl(defaultSchedulerNodeTable);
  print('\n5. roll call table `$defaultSchedulerNodeTable`:');
  print(nodeDdl);
  check(
    nodeDdl.contains('node_id          VARCHAR(191) NOT NULL'),
    'the roll call keys on the same node id a claim runs under',
  );
  check(
    nodeDdl.contains('checkin_interval BIGINT       NOT NULL'),
    'each node publishes the interval it wants to be judged by',
  );

  // 6. The failure test is Quartz's, and it is a pure function — which is the
  //    whole reason it can be shown here at all, and asserted in a test with no
  //    database:
  //
  //      failedAfter = checkin_at
  //                  + max(checkin_interval, now - my_last_checkin)
  //                  + 7.5s
  //
  //    Both halves of the `max` are load-bearing.
  final peer = TomSchedulerNode(
    nodeId: 'node-b',
    checkinAt: DateTime.utc(2026, 3, 1, 10),
    checkinInterval: const Duration(seconds: 30),
  );
  final healthy = DateTime.utc(2026, 3, 1, 10, 0, 40);
  print('\n6. the failed-node formula');
  print(
    '   a peer silent for 40s, judged by a node that is itself current: '
    '${isSchedulerNodeFailed(peer: peer, now: healthy, lastSelfCheckin: healthy) ? 'failed' : 'alive'}',
  );
  check(
    isSchedulerNodeFailed(peer: peer, now: healthy, lastSelfCheckin: healthy),
    'a peer that has missed its check-in window is named failed',
  );

  // The same peer, same instant — but the accuser has itself been silent for
  // two minutes. A node that was stalled must not accuse its peers of the
  // outage it was having.
  final stalledSince = DateTime.utc(2026, 3, 1, 9, 58, 40);
  print(
    '   the same peer, judged by a node that was itself stalled 2m: '
    '${isSchedulerNodeFailed(peer: peer, now: healthy, lastSelfCheckin: stalledSince) ? 'failed' : 'alive'}',
  );
  check(
    !isSchedulerNodeFailed(
      peer: peer,
      now: healthy,
      lastSelfCheckin: stalledSince,
    ),
    'a node that was itself stalled cannot accuse its peers of its outage',
  );

  // It accelerates recovery; it never replaces the lease. The lease TTL stays
  // the correctness floor, and the formula reads one node's clock against
  // another's — so the cluster needs its clocks within about a second. Claiming
  // and leasing are unaffected: those instants are database-written.

  // 7. A claim is the one statement whose affected-row count *is* the answer, so
  //    a lost acknowledgement is genuinely ambiguous. The store asks the
  //    inverted question — not "was this a transport failure" (an open set that
  //    grows with every driver and proxy) but "did the server answer" (a closed,
  //    recognisable one).
  print('\n7. classifying a failed write');
  print(
    '   the server reported it: '
    '${classifySqlFailure(MySQLServerException('deadlock', 1213)).name}',
  );
  print(
    '   the connection broke:   '
    '${classifySqlFailure(MySQLClientException('socket closed')).name}',
  );
  check(
    classifySqlFailure(MySQLServerException('deadlock', 1213)) ==
        TomSqlFailureMode.definite,
    'a write the server answered has a settled outcome',
  );
  check(
    classifySqlFailure(MySQLClientException('socket closed')) ==
        TomSqlFailureMode.ambiguous,
    'a lost acknowledgement leaves the claim in doubt',
  );
  // Anything unrecognised is ambiguous too, and that asymmetry is deliberate: a
  // false "ambiguous" costs one extra SELECT, a false "definite" an abandoned
  // run.
  check(
    classifySqlFailure(StateError('anything at all')) ==
        TomSqlFailureMode.ambiguous,
    'an unrecognised failure costs a SELECT rather than a run',
  );

  // 8. In a deployment the schema is created by the migration orchestrator, not
  //    by the stores. The shipped reference migrations live next to this file
  //    and are byte-checked against the DDL above by the schema test.
  print('\n8. migration layout walked by TomDbMigrations.migrateAll():');
  print(
    '   <directory>/<datasourceName>/<schemaName>/'
    '[<version>]-<description>[@<env>[,<env>...]].<anyfileextension>',
  );
  // The five shipped files below carry no @<env> tag, so they apply in every
  // environment — a scheduling schema is not a per-environment fixture.
  print(
    '   example/scheduling/migrations/system/main/tomcore/'
    '[1]-create_tom_job_run.sql',
  );
  print(
    '   example/scheduling/migrations/system/main/tomcore/'
    '[2]-create_tom_lease.sql',
  );
  print(
    '   example/scheduling/migrations/system/main/tomcore/'
    '[3]-create_tom_scheduler_node.sql',
  );
  print(
    '   example/scheduling/migrations/system/main/tomcore/'
    '[4]-create_tom_job_pause.sql',
  );
  print(
    '   example/scheduling/migrations/system/main/tomcore/'
    '[5]-create_tom_job_run_archive.sql',
  );
  print(
    '   With the tables already migrated, construct the stores with '
    '`createSchema: false`.',
  );

  // 9. Wiring. All three types resolve a registered data source by name, and all
  //    say so plainly when it is absent — a scheduler pointed at a data source
  //    that was never registered is a configuration error, not an empty queue.
  try {
    TomSqlJobStore.named('not_registered');
  } on TomServerException catch (e) {
    print('\n9. TomSqlJobStore.named on an unknown data source: ${e.key}');
    check(
      e.key == 'scheduling.store.unknown_datasource',
      'a queue on a missing data source is a configuration error, '
      'not an empty queue',
    );
  }
  try {
    TomSqlLeaseLock.named('not_registered');
  } on TomServerException catch (e) {
    print('   TomSqlLeaseLock.named on an unknown data source: ${e.key}');
    check(
      e.key == 'scheduling.lock.unknown_datasource',
      'the lock refuses a missing data source just as plainly',
    );
  }
  try {
    TomSqlSchedulerNodes.named('not_registered', nodeId: 'node-a');
  } on TomServerException catch (e) {
    print('   TomSqlSchedulerNodes.named on an unknown data source: ${e.key}');
    check(
      e.key == 'scheduling.nodes.unknown_datasource',
      'the roll call refuses a missing data source too',
    );
  }

  // 10. The set, as a scheduler would take them. All must address the *same*
  //     database: a queue and a lock in different systems can each be healthy
  //     while the other is unreachable, and the resulting disagreement — the
  //     queue says node A claimed the run, the lock says node B holds it — has
  //     no resolution. The roll call is optional; without it recovery simply
  //     waits out the lease.
  print('\n10. wiring for a cluster node (same data source throughout):');
  print('''
     final nodeId = Platform.localHostname;   // must differ per node
     final roll = TomSqlSchedulerNodes.named('main', nodeId: nodeId,
         createSchema: false);
     final store = TomSqlJobStore.named('main', createSchema: false,
         nodes: roll);
     final lock = TomSqlLeaseLock.named('main', createSchema: false);
     final scheduler = TomScheduler(
       store: store,
       dispatcher: const TomInlineJobDispatcher(),
       ownerId: nodeId,
       lock: lock,
       leaseTtl: const Duration(minutes: 1),
     );''');

  // 11. Priority, pauses, checkpoints and the archive. The claim scan orders by
  //     `priority DESC, seq`, so the queue carries each run's priority; the
  //     checkpoint a body saves is stored with its run. A pause belongs to the
  //     job, not its runs, so it is a table keyed by the job name — every node
  //     sees it, and a job with no runs yet can be paused. The archive holds
  //     every queue column plus `archived_at`, without the unique window key: a
  //     window may be planned again once its run was archived.
  final pauseDdl = jobPauseTableDdl(defaultJobPauseTable);
  final archiveDdl = jobRunArchiveTableDdl(defaultJobRunArchiveTable);
  print('\n11. priority, checkpoints, pauses and the archive:');
  print('   queue columns:');
  for (final line in queueDdl.split('\n')) {
    if (line.contains('priority') || line.contains('checkpoint')) {
      print('  $line');
    }
  }
  print('   pause table `$defaultJobPauseTable`:');
  print(pauseDdl);
  print('   archive table `$defaultJobRunArchiveTable`:');
  print(archiveDdl);
  check(
    queueDdl.contains('priority      INT          NOT NULL DEFAULT 0') &&
        queueDdl.contains('checkpoint    LONGTEXT     NULL'),
    'a run carries the priority the claim orders by and its checkpoint',
  );
  check(
    pauseDdl.contains('PRIMARY KEY (job_name)'),
    'a pause is one row per job, seen by every node',
  );
  check(
    archiveDdl.contains('archived_at   DATETIME(6)  NOT NULL') &&
        !archiveDdl.contains('UNIQUE') &&
        !archiveDdl.contains('AUTO_INCREMENT'),
    'the archive keeps the queue order and no window key, so a window may '
    'be planned again after its run was archived',
  );
  check(
    frameworkOwnedTables().map((t) => t.name).toSet().containsAll({
      defaultJobPauseTable,
      defaultJobRunArchiveTable,
    }),
    'both tables are framework-owned, so the schema check covers them',
  );

  print('\nScheduling example completed.');
}

void main() {
  run();
}

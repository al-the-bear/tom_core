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
/// What this example does show, connection-free: the schema the pair relies on
/// and why each part of it is load-bearing, the on-disk migration layout that
/// creates it in a deployment, the UTC instant encoding both stores use, and the
/// wiring — including the error you get when the named data source is not
/// registered.
///
/// Run with `dart run example/scheduling/scheduling_example.dart`.
/// The same behaviour is covered by `test/scheduling_schema_test.dart` (schema
/// and encoding) and `test/scheduling_db_test.dart` (the live behaviour).
library;

import 'package:tom_core_server/tom_core_server.dart';

void run() {
  // 1. The queue table. The unique key on (job_name, scheduled_for) is the
  //    point: it makes the scheduler's idempotence key — one run per job per
  //    window — a database invariant rather than a convention, so two nodes
  //    planning the same window at the same moment cannot both succeed.
  final queueDdl = jobRunTableDdl(defaultJobRunTable);
  print('1. queue table `$defaultJobRunTable`:');
  print(queueDdl);
  assert(queueDdl.contains('UNIQUE KEY uq_tom_job_run_window '
      '(job_name, scheduled_for)'));

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
  assert(leaseDdl.contains('token       BIGINT       NOT NULL'));
  assert(leaseDdl.contains('version     BIGINT       NOT NULL DEFAULT 1'));

  // 3. The table name is a constructor argument, so the index names follow it.
  //    Two queues over one schema would otherwise collide on `uq_..._window`.
  final other = jobRunTableDdl('billing_job_run');
  print('\n3. a second queue in the same schema gets its own index names:');
  print('   ${other.contains('uq_billing_job_run_window') ? 'uq_billing_job_run_window' : '(missing)'}');
  assert(other.contains('uq_billing_job_run_window'));

  // 4. Instants are stored as fixed-width UTC DATETIME(6) literals. Fixed width
  //    keeps the text ordered in SQL exactly as the instants are ordered in
  //    Dart, so a `run_at <= :now` comparison cannot be surprised by a shorter
  //    fraction; UTC keeps a cluster from ever comparing wall clocks.
  final window = DateTime.utc(2026, 3, 1, 10, 20, 30, 400, 500);
  final encoded = sqlInstant(window);
  final decoded = parseSqlInstant(encoded);
  print('\n4. instant encoding: $window -> "$encoded" -> $decoded');
  assert(encoded == '2026-03-01 10:20:30.400500');
  assert(decoded == window);
  assert(decoded.isUtc);

  // A local instant round-trips as the same *moment*, labelled UTC — the store
  // hands every caller back a UTC instant regardless of what it was given.
  final local = DateTime(2026, 3, 1, 10, 20, 30);
  final normalised = parseSqlInstant(sqlInstant(local));
  print('   a local instant comes back as UTC: '
      '$normalised (same moment: ${normalised.isAtSameMomentAs(local)})');
  assert(normalised.isUtc && normalised.isAtSameMomentAs(local));

  // 5. In a deployment the schema is created by the migration orchestrator, not
  //    by the stores. The shipped reference migrations live next to this file
  //    and are byte-checked against the DDL above by the schema test.
  print('\n5. migration layout walked by TomDbMigrations.migrateDatabases():');
  print('   <directory>/<datasourceName>/<schemaName>/'
      '[<version>]-<description>.sql');
  print('   example/scheduling/migrations/main/tomcore/'
      '[1]-create_tom_job_run.sql');
  print('   example/scheduling/migrations/main/tomcore/'
      '[2]-create_tom_lease.sql');
  print('   With the tables already migrated, construct the pair with '
      '`createSchema: false`.');

  // 6. Wiring. Both types resolve a registered data source by name, and both
  //    say so plainly when it is absent — a scheduler pointed at a data source
  //    that was never registered is a configuration error, not an empty queue.
  try {
    TomSqlJobStore.named('not_registered');
  } on TomServerException catch (e) {
    print('\n6. TomSqlJobStore.named on an unknown data source: ${e.key}');
    assert(e.key == 'scheduling.store.unknown_datasource');
  }
  try {
    TomSqlLeaseLock.named('not_registered');
  } on TomServerException catch (e) {
    print('   TomSqlLeaseLock.named on an unknown data source: ${e.key}');
    assert(e.key == 'scheduling.lock.unknown_datasource');
  }

  // 7. The pair, as a scheduler would take them. Both must address the *same*
  //    database: a queue and a lock in different systems can each be healthy
  //    while the other is unreachable, and the resulting disagreement — the
  //    queue says node A claimed the run, the lock says node B holds it — has no
  //    resolution.
  print('\n7. wiring for a cluster node (same data source for both):');
  print('''
     final store = TomSqlJobStore.named('main', createSchema: false);
     final lock = TomSqlLeaseLock.named('main', createSchema: false);
     final scheduler = TomScheduler(
       store: store,
       dispatcher: const TomInlineJobDispatcher(),
       ownerId: Platform.localHostname,   // must differ per node
       lock: lock,
       leaseTtl: const Duration(minutes: 1),
     );''');

  print('\nScheduling example completed.');
}

void main() {
  run();
}

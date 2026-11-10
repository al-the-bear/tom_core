/// Builds the demonstration's schema on a clean database.
///
/// Run once by `run_cluster_demo.sh` before any node starts.
///
/// The three framework tables are created by
/// [TomDbMigrations.migrateDatabases] from the **shipped** reference migrations
/// in `example/scheduling/migrations/system/`, not by the stores' `createSchema` path.
/// That is deliberate and is itself part of what the demo proves: the files a
/// deployment actually applies build a schema the stores can run on. Every store
/// the demo constructs therefore passes `createSchema: false`, exactly as a
/// deployment whose database user may not run DDL would.
///
/// Everything is dropped first. The stores create tables on first use, so a
/// previous run with different DDL would otherwise persist; dropping `tom_lease`
/// matters most, because its rows *are* the fencing counters and the fencing
/// scenario asserts against the tokens they hand out.
library;

import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

import 'cluster_support.dart';

Future<void> main() async {
  final dsi = await connect();
  final datasource = dsi.datasource;

  // 1. Drop everything the demo owns, including the orchestrator's own
  //    bookkeeping. Without that last one the orchestrator would find the
  //    migrations already recorded, skip them, and leave the schema missing —
  //    a demo that passes or fails depending only on whether the database was
  //    fresh.
  for (final table in [
    fencedResourceTable,
    defaultJobRunTable,
    defaultLeaseTable,
    defaultSchedulerNodeTable,
    '${clusterMigrationSchema}_versioning',
  ]) {
    await datasource.executeCommand('DROP TABLE IF EXISTS $table');
  }

  // 2. Apply the shipped migrations. The orchestrator walks
  //    <directory>/<datasourceName>/<schemaName>/, which is why the data source
  //    is named `main` and the folder is `migrations/system/main/tomcore`.
  await TomDbMigrations.migrateDatabases(
    'example/scheduling/migrations/system',
  );

  // 3. The one table that belongs to the demo rather than the framework, seeded
  //    at fence 0 so the first token any node holds can write.
  await datasource.executeCommand(fencedResourceDdl);
  await datasource.executeCommand(
    'INSERT INTO $fencedResourceTable (name, holder, fence) '
    'VALUES (:name, :holder, 0)',
    {'name': fencedResource, 'holder': 'nobody'},
  );

  // 4. Prove the migrations produced tables the stores can actually address,
  //    here rather than inside a node — a schema fault should fail provisioning
  //    with a clear message, not surface later as an odd scenario failure.
  final store = TomSqlJobStore(datasource, createSchema: false);
  final lock = TomSqlLeaseLock(datasource, createSchema: false);
  final roll = TomSqlSchedulerNodes(
    datasource,
    nodeId: 'provisioner',
    createSchema: false,
  );
  if ((await store.all()).isNotEmpty) {
    stderr.writeln('The job queue is not empty after provisioning.');
    exit(1);
  }
  if ((await lock.inspect(fencedResource)).lease != null) {
    stderr.writeln('The lease table is not empty after provisioning.');
    exit(1);
  }
  if ((await roll.nodes()).isNotEmpty) {
    stderr.writeln('The roll call is not empty after provisioning.');
    exit(1);
  }

  print('Provisioned: migrations applied, $fencedResourceTable seeded.');
  await disconnect();
}

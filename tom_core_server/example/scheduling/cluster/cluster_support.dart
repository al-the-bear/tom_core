/// Wiring shared by the cluster demonstration's node and verifier programs.
///
/// Everything here is deliberately small: connection coordinates read from the
/// environment, the one extra table the fencing scenario needs, and the event
/// record the two halves of the demo communicate through.
///
/// ## Why the two processes talk through files rather than the database
///
/// Each node writes what it *observed* as JSON lines on stdout, which the runner
/// script captures per node; the verifier reads those files and the database.
/// The split is the point. A node's log is its own testimony — "I invoked the
/// body for this window", "my write was refused" — and the database is the
/// shared fact. An assertion that only consulted one of them could not catch the
/// interesting failures: two nodes each believing they ran a window is invisible
/// to the database (which holds one row either way), and a row marked
/// `succeeded` proves nothing about how many times a body actually ran.
library;

import 'dart:convert';
import 'dart:io';

import 'package:tom_core_server/tom_core_server.dart';

// This file declares the row type; the example suite's shared reflection root
// (../../example_reflection.dart) captures it, and the generated file beside
// that root declares initializeReflection(). Both are needed here, and the
// generated one does not re-export what it captures.
import '../../example_reflection.reflection.dart';
import 'cluster_reflection.dart';

/// The registered data source name.
///
/// It is `main` because the shipped reference migrations live under
/// `example/scheduling/migrations/system/main/tomcore/` and the orchestrator walks
/// `<directory>/<datasourceName>/<schemaName>/`. Renaming the data source
/// without renaming that folder would leave the demo running against a schema
/// nothing had created.
const String clusterDatasource = 'main';

/// The migration schema name the reference migrations are applied under. Also
/// names the orchestrator's bookkeeping table, `tomcore_versioning`.
const String clusterMigrationSchema = 'tomcore';

/// The resource the fencing scenario contends for.
const String fencedResource = 'cluster:ledger';

/// The table [ClusterFenceRow] maps.
const String fencedResourceTable = 'demo_fenced_resource';

/// The job the steady-state scenario schedules on both nodes.
const String heartbeatJob = 'cluster-heartbeat';

/// The job the takeover scenario abandons.
const String takeoverJob = 'cluster-takeover';

String _env(String key, String fallback) =>
    Platform.environment[key]?.trim().isNotEmpty == true
    ? Platform.environment[key]!.trim()
    : fallback;

/// Connection coordinates, defaulted to `docker-compose.test.yaml`.
///
/// The same `TOM_CORE_SERVER_TEST_DB_*` variables the test fixture reads, so one
/// MariaDB serves both and a developer who has already pointed the suite
/// somewhere does not have to point the demo separately.
Map<String, dynamic> get clusterDatasourceConfig => <String, dynamic>{
  clusterDatasource: <String, dynamic>{
    'type': 'mariadb',
    'username': _env('TOM_CORE_SERVER_TEST_DB_USER', 'root'),
    'password': _env('TOM_CORE_SERVER_TEST_DB_PASSWORD', 'password'),
    'host': _env('TOM_CORE_SERVER_TEST_DB_HOST', '127.0.0.1'),
    'port': int.parse(_env('TOM_CORE_SERVER_TEST_DB_PORT', '3309')),
    'databaseName': _env(
      'TOM_CORE_SERVER_TEST_DB_NAME',
      'tom_core_server_test',
    ),
  },
};

/// Initialises reflection and opens the data source.
///
/// Reflection first, always: the MariaDB driver is discovered by scanning
/// `@TomDatasourceDriver` metadata, so a connect attempted before this fails
/// with a driver-not-found that looks like a configuration error.
Future<TomDataSourceInfo> connect() async {
  initializeReflection();
  await TomDataSourceInfo.initializeDatasourceInfo(clusterDatasourceConfig);
  return TomDataSourceInfo.getDataSourceInfo(clusterDatasource)!;
}

/// Closes every registered data source.
Future<void> disconnect() => TomDataSourceInfo.closeAll();

/// The fenced resource's table. Created by the provisioner, not by a store —
/// it belongs to the demo, not to the framework.
const String fencedResourceDdl =
    '''
CREATE TABLE IF NOT EXISTS $fencedResourceTable (
  name   VARCHAR(191) NOT NULL,
  holder VARCHAR(191) NOT NULL,
  fence  BIGINT       NOT NULL DEFAULT 0,
  PRIMARY KEY (name)
)
''';

/// Attempts a fenced write of [holder] to [fencedResource], stamped [token].
///
/// Returns `true` when the database accepted it. The guard is `fence <= :token`,
/// so a write carrying a token the resource has already surpassed affects zero
/// rows and is silently refused — which is exactly what should happen to a node
/// that woke from a stall still believing it holds the lease.
///
/// `<=` rather than `<` because the live holder must be able to write more than
/// once under one lease; only a *strictly older* token is refused.
Future<bool> fencedWrite(
  TomDataSource datasource,
  String holder,
  int token,
) async {
  final affected = await datasource.executeCommand(
    'UPDATE $fencedResourceTable SET holder = :holder, fence = :token '
    'WHERE name = :name AND fence <= :token',
    {'holder': holder, 'token': token, 'name': fencedResource},
  );
  return affected == BigInt.one;
}

/// Reads the fenced resource, or `null` before it has been seeded.
Future<ClusterFenceRow?> readFencedResource(TomDataSource datasource) async {
  final rows = await datasource.executeQuery<ClusterFenceRow>(
    'SELECT name, holder, fence FROM $fencedResourceTable WHERE name = :name',
    {'name': fencedResource},
  );
  return rows.isEmpty ? null : rows.first;
}

// =============================================================================
// EVENTS
// =============================================================================

/// One thing a node observed, as it goes onto stdout and comes back to the
/// verifier.
class ClusterEvent {
  /// Creates an event.
  const ClusterEvent(this.node, this.scenario, this.name, this.fields);

  /// Reconstructs an event from one JSON line.
  factory ClusterEvent.fromJson(Map<String, Object?> json) => ClusterEvent(
    json['node'] as String,
    json['scenario'] as String,
    json['event'] as String,
    Map<String, Object?>.from(json['fields'] as Map),
  );

  /// The node that observed it.
  final String node;

  /// The scenario it was observed during.
  final String scenario;

  /// What happened.
  final String name;

  /// Everything else, scenario-specific.
  final Map<String, Object?> fields;

  /// A field as an `int`, or `null` when absent.
  int? intField(String key) => (fields[key] as num?)?.toInt();

  /// A field as a `String`, or `null` when absent.
  String? stringField(String key) => fields[key] as String?;

  /// A field as a `bool`, or `null` when absent.
  bool? boolField(String key) => fields[key] as bool?;

  @override
  String toString() => '$node/$scenario: $name $fields';
}

/// Writes one event to stdout as a JSON line.
///
/// A line at a time, flushed by `print`, so a node that is `kill -9`ed mid-run
/// still leaves everything it had already reported. A buffered writer would lose
/// exactly the evidence the takeover scenario depends on.
void emit(
  String node,
  String scenario,
  String name, [
  Map<String, Object?> fields = const {},
]) {
  print(
    jsonEncode({
      'node': node,
      'scenario': scenario,
      'event': name,
      'fields': fields,
    }),
  );
}

/// Parses every event in [directory]'s `*.jsonl` files.
///
/// Non-JSON lines are ignored rather than fatal: the framework logger writes to
/// the same stdout, and a warning from the roll call is not a parse failure.
List<ClusterEvent> readEvents(Directory directory) {
  final events = <ClusterEvent>[];
  final files = directory.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    if (!file.path.endsWith('.jsonl')) continue;
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('{')) continue;
      try {
        events.add(
          ClusterEvent.fromJson(jsonDecode(trimmed) as Map<String, Object?>),
        );
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
  }
  return events;
}

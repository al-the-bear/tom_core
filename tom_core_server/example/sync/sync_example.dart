/// The sync module without a database: the routes a device calls, the change
/// log's tables on both databases, and the answers the server gives before an
/// entity is reached.
///
/// Run with `dart run example/sync/sync_example.dart`.
///
/// Exposing an entity, applying a push through its repository and pulling its
/// changes need a database, and run in `test/sync_db_test.dart` — the kernel's
/// sync contract over HTTP on MariaDB and PostgreSQL. Every step here checks
/// its own result, and the run fails when one does not hold.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

// ignore_for_file: avoid_print

Future<void> main() async {
  // 1. The routes come from the kernel's contract, which the server's
  //    endpoints and the device's TomHttpSyncTransport both read. Both are
  //    POSTs: a pull right after a push must not be answered by a replica.
  registerTomSyncApi();
  final base = Uri.parse('https://api.example.com');
  final push = tomSyncApi[tomSyncPushEndpointId];
  final pull = tomSyncApi[tomSyncPullEndpointId];
  print('1. ${push.method.name.toUpperCase()} ${push.resolveUri(base)}');
  print('   ${pull.method.name.toUpperCase()} ${pull.resolveUri(base)}');
  check(
    push.resolveUri(base).path == '/sync/push' &&
        pull.resolveUri(base).path == '/sync/pull' &&
        push.method == TomHttpMethod.post &&
        pull.method == TomHttpMethod.post,
    'the sync API is POST /sync/push and POST /sync/pull',
  );

  // 2. The change log: one row per change, numbered per collection, holding
  //    the id and version but no values; and one counter per collection.
  final change = syncChangeTable(defaultSyncChangeTable);
  final sequence = syncSequenceTable(defaultSyncSequenceTable);
  print('2. ${change.name}(${change.columnList})');
  print('   ${sequence.name}(${sequence.columnList})');
  check(
    change.has('seq') && change.has('entity_id') && !change.has('data'),
    'a change row holds its number and the entity id, no entity values',
  );
  final postgres = change.createStatements(PostgresSqlDialect()).first;
  check(
    postgres.contains('TIMESTAMP(6)'),
    'the log is created in PostgreSQL types on PostgreSQL',
  );

  // 3. A change of a collection nothing is exposed under is answered
  //    `rejected` — pushing it again would not help — and a pull of one is
  //    refused.
  final results = await TomSync.push([
    TomPendingChange(
      changeId: 'c1',
      collection: 'tasks',
      id: 't1',
      operation: TomChangeOperation.save,
      data: const {'id': 't1', 'title': 'Write the report'},
      queuedAt: DateTime.utc(2026, 11, 6, 12),
    ),
  ]);
  print(
    '3. push to tasks       : ${results.single.outcome.name} '
    '(${results.single.reason})',
  );
  check(
    results.single.outcome == TomPushOutcome.rejected &&
        results.single.reason == tomSyncUnknownCollectionErrorKey,
    'a change of an unknown collection is rejected',
  );
  String? refusal;
  try {
    await TomSync.pull('tasks', 0);
  } on TomSyncException catch (refused) {
    refusal = refused.key;
  }
  print('   pull of tasks       : $refusal');
  check(
    refusal == tomSyncUnknownCollectionErrorKey,
    'a pull of an unknown collection is refused',
  );

  // 4. What travels: a push request as the device sends it, read back as the
  //    endpoint reads it.
  final request = TomSyncPushRequest.fromJson(
    TomSyncPushRequest(
      changes: [
        TomPendingChange(
          changeId: 'c2',
          collection: 'notes',
          id: 'n1',
          operation: TomChangeOperation.save,
          data: const {'id': 'n1', 'text': 'Buy milk'},
          baseVersion: 3,
          queuedAt: DateTime.utc(2026, 11, 6, 12),
        ),
      ],
    ).toJson(),
  );
  print('4. ${request.changes.single}');
  check(
    request.changes.single.baseVersion == 3 &&
        request.changes.single.data!['text'] == 'Buy milk',
    'a pushed change keeps its base version and data on the wire',
  );
}

/// Demonstrates the offline store: entities read and changed on the device,
/// queued for the server, and synced — the server's changes pulled, a
/// conflict decided by the application.
///
/// The device's database is the in-memory engine and the server is
/// `TomMemorySyncServer`, the protocol's reference implementation; an
/// application supplies an engine over its own database and a transport to
/// its server, and the rest reads the same.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/offline/01_offline_sync_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A task, as the application models it.
class Task {
  final String id;
  final String title;
  final bool done;
  Task(this.id, this.title, {this.done = false});
}

/// How a task is stored on the device and sent to the server.
final taskCodec = TomLocalEntityCodec<Task>(
  toJson: (t) => {'id': t.id, 'title': t.title, 'done': t.done},
  fromJson: (j) =>
      Task(j['id']! as String, j['title']! as String, done: j['done']! as bool),
  idOf: (t) => t.id,
);

/// Run all offline-store examples.
Future<void> run() async {
  print('=== 01: Offline Sync Example ===\n');
  final server = TomMemorySyncServer();
  final store = TomOfflineStore(TomMemoryLocalStoreEngine());
  final tasks = TomLocalRepository<Task>(
    store: store,
    collection: 'tasks',
    codec: taskCodec,
  );
  final sync = TomSyncEngine(
    store: store,
    transport: server,
    collections: ['tasks'],
    // EXAMPLE 5's decision: a task done on either side stays done.
    resolver: (conflict) => TomConflictResolution.merge({
      ...conflict.serverData ?? conflict.change.data!,
      'done':
          (conflict.serverData?['done'] == true) ||
          (conflict.change.data?['done'] == true),
    }),
  );

  // EXAMPLE 1: written on the device, offline — read back at once, queued.
  await tasks.save(Task('t1', 'Write the report'));
  print(
    '1. on the device: ${(await tasks.findById('t1'))!.title}, '
    'pending ${(await store.pending()).length}',
  );
  assert((await store.pending()).length == 1);

  // EXAMPLE 2: the sync pushes it; the server answers version 1.
  var report = await sync.sync();
  print(
    '2. pushed ${report.applied.length}, version ${await tasks.versionOf('t1')}',
  );
  assert(await tasks.versionOf('t1') == 1);

  // EXAMPLE 3: another client adds a task; the next sync pulls it.
  server.put('tasks', 't2', {'id': 't2', 'title': 'Review', 'done': false});
  report = await sync.sync();
  print(
    '3. pulled ${report.pulled['tasks']}: '
    '${(await tasks.findAll()).map((t) => t.title).toList()}',
  );
  assert(await tasks.count() == 2);

  // EXAMPLE 4: deleted on the device — gone at once, gone on the server after
  // the sync.
  await tasks.deleteById('t2');
  await sync.sync();
  print('4. deleted: on the server ${server.entity('tasks', 't2')}');
  assert(server.entity('tasks', 't2') == null);

  // EXAMPLE 5: both sides change t1. The server keeps its title; the device
  // marked it done. The application's resolver merges the two.
  await tasks.save(Task('t1', 'Write the report', done: true));
  server.put('tasks', 't1', {
    'id': 't1',
    'title': 'Write the Q3 report',
    'done': false,
  });
  report = await sync.sync();
  final merged = (await tasks.findById('t1'))!;
  print(
    '5. conflicts ${report.conflicts.length}: '
    '"${merged.title}", done ${merged.done}',
  );
  assert(merged.title == 'Write the Q3 report' && merged.done);
  assert(server.entity('tasks', 't1')!.data['done'] == true);
  print('');
}

Future<void> main() => run();

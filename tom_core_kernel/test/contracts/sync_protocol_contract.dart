/// The behaviour a device sees syncing with any server of the sync protocol,
/// written once and run against every server: [TomMemorySyncServer] here, a
/// Tom server over HTTP on MariaDB and PostgreSQL in `tom_core_server`.
///
/// It sits in `test/` and is imported by relative path from the server's
/// tests, for the reasons `scheduling_contract.dart` gives.
///
/// The server under test serves one collection, `notes`, of entities with a
/// string `id` and a `text`, and refuses a save whose `text` is empty with the
/// reason `text.required`.
// intentionally-not-discovered: a shared contract suite, not a suite of
// its own. Each importing *_test.dart calls it once per server.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A server of the sync protocol as the contract drives it.
abstract class TomSyncContractServer {
  /// The way a device reaches the server.
  TomSyncTransport get transport;

  /// Saves note [id] with [text] on the server, as another client would;
  /// answers the note's version.
  Future<int> put(String id, String text);

  /// Deletes note [id] on the server, as another client would.
  Future<void> remove(String id);

  /// Note [id] as the server holds it, or `null`.
  Future<({String text, int version})?> note(String id);
}

class _Note {
  final String id;
  final String text;
  _Note(this.id, this.text);
}

final _codec = TomLocalEntityCodec<_Note>(
  toJson: (note) => {'id': note.id, 'text': note.text},
  fromJson: (json) => _Note(json['id']! as String, json['text']! as String),
  idOf: (note) => note.id,
);

/// A transport around the server's: counts pushes, can be offline, can run
/// something in the middle of a push, and can answer nothing for a push.
class _Wire extends TomSyncTransport {
  final TomSyncTransport server;
  Future<void> Function()? duringPush;
  bool silent = false;
  Object? offline;
  int pushes = 0;

  _Wire(this.server);

  @override
  Future<List<TomPushResult>> push(List<TomPendingChange> changes) async {
    if (offline != null) throw offline!;
    pushes++;
    if (silent) return const [];
    final results = await server.push(changes);
    final during = duringPush;
    duringPush = null;
    if (during != null) await during();
    return results;
  }

  @override
  Future<TomPullBatch> pull(String collection, int since, {int limit = 500}) {
    if (offline != null) throw offline!;
    return server.pull(collection, since, limit: limit);
  }
}

/// Runs the sync scenarios against the server [create] answers, fresh for
/// every test; [dispose] runs after each.
void runTomSyncContract(
  String label,
  Future<TomSyncContractServer> Function() create, {
  Future<void> Function()? dispose,
}) {
  group('syncing with $label', () {
    late TomSyncContractServer server;
    late _Wire wire;
    late TomOfflineStore store;
    late TomLocalRepository<_Note> notes;
    TomConflictResolver? resolver;

    TomSyncEngine engine({int pullLimit = 500}) => TomSyncEngine(
      store: store,
      transport: wire,
      collections: ['notes'],
      resolver: resolver,
      pullLimit: pullLimit,
    );

    setUp(() async {
      server = await create();
      wire = _Wire(server.transport);
      store = TomOfflineStore(TomMemoryLocalStoreEngine());
      notes = TomLocalRepository(
        store: store,
        collection: 'notes',
        codec: _codec,
      );
      resolver = null;
    });

    if (dispose != null) tearDown(dispose);

    test('pushes new and changed entities, and takes the versions the '
        'server answers', () async {
      await notes.save(_Note('a', 'first'));
      var report = await engine().sync();
      expect(report.applied, hasLength(1));
      expect((await server.note('a'))!.text, 'first');
      expect(await notes.versionOf('a'), 1);
      expect(await store.pending(), isEmpty);

      await notes.save(_Note('a', 'second'));
      report = await engine().sync();
      expect((await server.note('a'))!.version, 2);
      expect(await notes.versionOf('a'), 2);

      await notes.deleteById('a');
      await engine().sync();
      expect(await server.note('a'), isNull);
      expect(await notes.findById('a'), isNull);
    });

    test(
      'pulls what changed on the server since the last sync, in pages',
      () async {
        for (var i = 1; i <= 5; i++) {
          await server.put('n$i', 'server $i');
        }
        var report = await engine(pullLimit: 2).sync();
        expect(report.pulled['notes'], 5);
        expect(await notes.count(), 5);
        expect(await store.meta('cursor:notes'), 5);

        await server.remove('n2');
        await server.put('n3', 'edited elsewhere');
        report = await engine().sync();
        expect(report.pulled['notes'], 2, reason: 'only what changed since');
        expect(await notes.findById('n2'), isNull);
        expect((await notes.findById('n3'))!.text, 'edited elsewhere');
        expect(await notes.versionOf('n3'), 2);
      },
    );

    group('a conflict', () {
      setUp(() async {
        await server.put('a', 'original');
        await engine().sync();
        // Both sides edit version 1.
        await notes.save(_Note('a', 'device edit'));
        await server.put('a', 'server edit');
      });

      test('keeps the server\'s value by default, and reports the dropped '
          'change', () async {
        final report = await engine().sync();
        expect(report.conflicts.single.serverVersion, 2);
        expect(report.conflicts.single.serverData!['text'], 'server edit');
        expect(report.discarded.single.data!['text'], 'device edit');
        expect((await notes.findById('a'))!.text, 'server edit');
        expect(await notes.versionOf('a'), 2);
        expect(await store.pending(), isEmpty);
      });

      test('keeps the device\'s value when the application says so', () async {
        resolver = (_) => TomConflictResolution.keepLocal;
        final report = await engine().sync();
        expect(report.conflicts, hasLength(1));
        expect(report.applied, hasLength(1));
        expect((await server.note('a'))!.text, 'device edit');
        expect((await server.note('a'))!.version, 3);
        expect(await notes.versionOf('a'), 3);
      });

      test('pushes the application\'s merge', () async {
        resolver = (conflict) => TomConflictResolution.merge({
          'id': 'a',
          'text':
              '${conflict.serverData!['text']} + '
              '${conflict.change.data!['text']}',
        });
        await engine().sync();
        expect((await server.note('a'))!.text, 'server edit + device edit');
        expect((await notes.findById('a'))!.text, 'server edit + device edit');
        expect(await store.pending(), isEmpty);
      });

      test('with an entity the server deleted, keeping the server\'s state '
          'removes it on the device', () async {
        await server.remove('a');
        final report = await engine().sync();
        expect(report.conflicts.single.serverData, isNull);
        expect(await notes.findById('a'), isNull);
      });
    });

    test(
      'a refused change gives the device the server\'s value back',
      () async {
        await server.put('a', 'valid');
        await engine().sync();
        await notes.save(_Note('a', ''));
        final report = await engine().sync();
        expect(report.rejected.single.reason, 'text.required');
        expect((await notes.findById('a'))!.text, 'valid');
        expect(await store.pending(), isEmpty);
      },
    );

    test(
      'offline, a sync fails and keeps every change for the next one',
      () async {
        await notes.save(_Note('a', 'written offline'));
        wire.offline = StateError('no network');
        await expectLater(
          engine().sync(),
          throwsA(
            isA<TomOfflineException>().having(
              (e) => e.key,
              'key',
              'offline.sync.transport_failed',
            ),
          ),
        );
        expect(await store.pending(), hasLength(1));
        wire.offline = null;
        await engine().sync();
        expect((await server.note('a'))!.text, 'written offline');
      },
    );

    test(
      'a pull does not overwrite a change still waiting to be pushed',
      () async {
        await server.put('a', 'v1');
        await engine().sync();
        await notes.save(_Note('a', 'waiting'));
        await server.put('a', 'v2 elsewhere');
        wire.silent = true; // the push goes unanswered
        final report = await engine().sync();
        expect(report.stillPending, 1);
        expect((await notes.findById('a'))!.text, 'waiting');
      },
    );

    test('a save made while a push is out stays queued, based on the new '
        'version', () async {
      await notes.save(_Note('a', 'pushed'));
      wire.duringPush = () => notes.save(_Note('a', 'typed meanwhile'));
      await engine().sync();
      final queued = (await store.pending()).single.change;
      expect(queued.data!['text'], 'typed meanwhile');
      expect(queued.baseVersion, 1);
      await engine().sync();
      expect((await server.note('a'))!.text, 'typed meanwhile');
      expect((await server.note('a'))!.version, 2);
    });

    test('two syncs asked for at once run as one', () async {
      await notes.save(_Note('a', 'once'));
      final e = engine();
      final reports = await Future.wait([e.sync(), e.sync()]);
      expect(identical(reports.first, reports.last), isTrue);
      expect(wire.pushes, 1);
    });
  });
}

/// The offline store: the in-memory engine (transactions, JSON only), the
/// device-side repository and its queue of pending changes, and syncing with
/// the server — pushes under optimistic locking, every way a conflict can be
/// decided, refusals, incremental pulls, and what an interrupted or
/// overlapping sync leaves behind.
library;

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

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

/// A transport around [server] that can run something in the middle of a
/// push, and answer nothing for a push.
class _Wire extends TomSyncTransport {
  final TomMemorySyncServer server;
  Future<void> Function()? duringPush;
  bool silent = false;

  _Wire(this.server);

  @override
  Future<List<TomPushResult>> push(List<TomPendingChange> changes) async {
    if (silent) return const [];
    final results = await server.push(changes);
    final during = duringPush;
    duringPush = null;
    if (during != null) await during();
    return results;
  }

  @override
  Future<TomPullBatch> pull(String collection, int since, {int limit = 500}) =>
      server.pull(collection, since, limit: limit);
}

void main() {
  group('the in-memory engine', () {
    late TomMemoryLocalStoreEngine engine;
    setUp(() => engine = TomMemoryLocalStoreEngine());

    test('stores JSON documents by collection and id', () async {
      await engine.write('notes', 'a', {
        'text': 'one',
        'tags': ['x'],
      });
      await engine.write('notes', 'b', {'text': 'two'});
      expect(await engine.read('notes', 'a'), {
        'text': 'one',
        'tags': ['x'],
      });
      expect((await engine.readAll('notes')).keys, unorderedEquals(['a', 'b']));
      expect(await engine.delete('notes', 'a'), isTrue);
      expect(await engine.delete('notes', 'a'), isFalse);
      expect(await engine.read('notes', 'a'), isNull);
      expect(
        () => engine.write('notes', 'c', {'at': DateTime(2026)}),
        throwsA(
          isA<TomOfflineException>().having(
            (e) => e.key,
            'key',
            'offline.document.not_json',
          ),
        ),
      );
    });

    test('a transaction is all or nothing, one at a time, and a nested one '
        'joins it', () async {
      await engine.write('notes', 'a', {'text': 'kept'});
      await expectLater(
        engine.transaction(() async {
          await engine.write('notes', 'a', {'text': 'lost'});
          await engine.write('notes', 'b', {'text': 'lost'});
          throw StateError('half way');
        }),
        throwsStateError,
      );
      expect(await engine.read('notes', 'a'), {'text': 'kept'});
      expect(await engine.read('notes', 'b'), isNull);

      final order = <String>[];
      await Future.wait([
        engine.transaction(() async {
          order.add('first starts');
          await Future<void>.delayed(const Duration(milliseconds: 5));
          await engine.transaction(() async => order.add('nested'));
          order.add('first ends');
        }),
        engine.transaction(() async => order.add('second')),
      ]);
      expect(order, ['first starts', 'nested', 'first ends', 'second']);
    });

    test('a closed engine refuses', () async {
      await engine.close();
      expect(
        () => engine.read('notes', 'a'),
        throwsA(
          isA<TomOfflineException>().having(
            (e) => e.key,
            'key',
            'offline.store.closed',
          ),
        ),
      );
    });
  });

  group('the device-side repository', () {
    late TomOfflineStore store;
    late TomLocalRepository<_Note> notes;

    setUp(() {
      store = TomOfflineStore(TomMemoryLocalStoreEngine());
      notes = TomLocalRepository(
        store: store,
        collection: 'notes',
        codec: _codec,
      );
    });

    test('reads what it holds, as the server repository does', () async {
      await notes.saveAll([_Note('b', 'two'), _Note('a', 'one')]);
      expect((await notes.findById('a'))!.text, 'one');
      expect(await notes.findById('z'), isNull);
      expect((await notes.findAll()).map((n) => n.id), ['a', 'b']);
      expect((await notes.findAllById(['b', 'z', 'a'])).map((n) => n.id), [
        'b',
        'a',
      ]);
      expect(await notes.existsById(['a', 'b']), isTrue);
      expect(await notes.existsById(['a', 'z']), isFalse);
      expect(await notes.count(), 2);
      expect(await notes.deleteAllById(['a', 'z']), 1);
      expect(await notes.count(), 1);
    });

    test('queues one change per entity, based on the version the server '
        'gave', () async {
      await store.putEntity('notes', 'a', {'id': 'a', 'text': 'v3'}, 3);
      await notes.save(_Note('a', 'edit 1'));
      await notes.save(_Note('a', 'edit 2'));
      final queued = await store.pending();
      expect(queued, hasLength(1));
      expect(queued.single.change.data, {'id': 'a', 'text': 'edit 2'});
      expect(queued.single.change.baseVersion, 3);
      expect(await notes.versionOf('a'), 3);
      expect(await notes.hasPendingChange('a'), isTrue);

      await notes.deleteById('a');
      final deletion = (await store.pending()).single.change;
      expect(deletion.operation, TomChangeOperation.delete);
      expect(deletion.baseVersion, 3);
    });

    test('deleting an entity the server never saw sends nothing', () async {
      await notes.save(_Note('new', 'draft'));
      expect(await store.pending(), hasLength(1));
      await notes.deleteById('new');
      expect(await store.pending(), isEmpty);
    });

    test('refuses a collection name the framework keeps', () {
      expect(
        () => TomLocalRepository(
          store: store,
          collection: '_tom_x',
          codec: _codec,
        ),
        throwsA(
          isA<TomOfflineException>().having(
            (e) => e.key,
            'key',
            'offline.collection.reserved',
          ),
        ),
      );
    });
  });

  group('syncing', () {
    late TomMemorySyncServer server;
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

    setUp(() {
      server = TomMemorySyncServer(
        validate: (collection, data) =>
            (data['text'] as String).isEmpty ? 'text.required' : null,
      );
      wire = _Wire(server);
      store = TomOfflineStore(TomMemoryLocalStoreEngine());
      notes = TomLocalRepository(
        store: store,
        collection: 'notes',
        codec: _codec,
      );
      resolver = null;
    });

    test('pushes new and changed entities, and takes the versions the '
        'server answers', () async {
      await notes.save(_Note('a', 'first'));
      var report = await engine().sync();
      expect(report.applied, hasLength(1));
      expect(server.entity('notes', 'a')!.data['text'], 'first');
      expect(await notes.versionOf('a'), 1);
      expect(await store.pending(), isEmpty);

      await notes.save(_Note('a', 'second'));
      report = await engine().sync();
      expect(server.entity('notes', 'a')!.version, 2);
      expect(await notes.versionOf('a'), 2);

      await notes.deleteById('a');
      await engine().sync();
      expect(server.entity('notes', 'a'), isNull);
      expect(await notes.findById('a'), isNull);
    });

    test(
      'pulls what changed on the server since the last sync, in pages',
      () async {
        for (var i = 1; i <= 5; i++) {
          server.put('notes', 'n$i', {'id': 'n$i', 'text': 'server $i'});
        }
        var report = await engine(pullLimit: 2).sync();
        expect(report.pulled['notes'], 5);
        expect(await notes.count(), 5);
        expect(await store.meta('cursor:notes'), 5);

        server.remove('notes', 'n2');
        server.put('notes', 'n3', {'id': 'n3', 'text': 'edited elsewhere'});
        report = await engine().sync();
        expect(report.pulled['notes'], 2, reason: 'only what changed since');
        expect(await notes.findById('n2'), isNull);
        expect((await notes.findById('n3'))!.text, 'edited elsewhere');
        expect(await notes.versionOf('n3'), 2);
      },
    );

    group('a conflict', () {
      setUp(() async {
        server.put('notes', 'a', {'id': 'a', 'text': 'original'});
        await engine().sync();
        // Both sides edit version 1.
        await notes.save(_Note('a', 'device edit'));
        server.put('notes', 'a', {'id': 'a', 'text': 'server edit'});
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
        expect(server.entity('notes', 'a')!.data['text'], 'device edit');
        expect(server.entity('notes', 'a')!.version, 3);
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
        expect(
          server.entity('notes', 'a')!.data['text'],
          'server edit + device edit',
        );
        expect((await notes.findById('a'))!.text, 'server edit + device edit');
        expect(await store.pending(), isEmpty);
      });

      test('with an entity the server deleted, keeping the server\'s state '
          'removes it on the device', () async {
        server.remove('notes', 'a');
        final report = await engine().sync();
        expect(report.conflicts.single.serverData, isNull);
        expect(await notes.findById('a'), isNull);
      });
    });

    test(
      'a refused change gives the device the server\'s value back',
      () async {
        server.put('notes', 'a', {'id': 'a', 'text': 'valid'});
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
        server.offline = StateError('no network');
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
        server.offline = null;
        await engine().sync();
        expect(server.entity('notes', 'a')!.data['text'], 'written offline');
      },
    );

    test(
      'a pull does not overwrite a change still waiting to be pushed',
      () async {
        server.put('notes', 'a', {'id': 'a', 'text': 'v1'});
        await engine().sync();
        await notes.save(_Note('a', 'waiting'));
        server.put('notes', 'a', {'id': 'a', 'text': 'v2 elsewhere'});
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
      expect(server.entity('notes', 'a')!.data['text'], 'typed meanwhile');
      expect(server.entity('notes', 'a')!.version, 2);
    });

    test('two syncs asked for at once run as one', () async {
      await notes.save(_Note('a', 'once'));
      final e = engine();
      final reports = await Future.wait([e.sync(), e.sync()]);
      expect(identical(reports.first, reports.last), isTrue);
      expect(server.pushes, 1);
    });
  });
}

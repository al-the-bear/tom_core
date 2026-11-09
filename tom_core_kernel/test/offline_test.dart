/// The offline store: the in-memory engine (transactions, JSON only), the
/// device-side repository and its queue of pending changes, and syncing with
/// the server — pushes under optimistic locking, every way a conflict can be
/// decided, refusals, incremental pulls, and what an interrupted or
/// overlapping sync leaves behind.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'contracts/sync_protocol_contract.dart';

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

/// [TomMemorySyncServer] as the sync contract drives it: a `notes`
/// collection that refuses an empty text.
class _MemoryServer implements TomSyncContractServer {
  final server = TomMemorySyncServer(
    validate: (collection, data) =>
        (data['text'] as String).isEmpty ? 'text.required' : null,
  );

  /// The transport: the server itself, or [TomHttpSyncTransport] over a
  /// client that answers the sync API from it.
  @override
  late TomSyncTransport transport = server;

  _MemoryServer();

  _MemoryServer.overHttp() {
    transport = TomHttpSyncTransport(
      baseUri: Uri.parse('http://sync.test'),
      client: MockClient((request) async {
        final body = (jsonDecode(request.body) as Map).cast<String, Object?>();
        final Map<String, Object?> answer;
        if (request.url.path == '/sync/push') {
          final push = TomSyncPushRequest.fromJson(body);
          answer = TomSyncPushResponse(
            results: await server.push(push.changes),
          ).toJson();
        } else {
          final pull = TomSyncPullRequest.fromJson(body);
          answer = (await server.pull(
            pull.collection,
            pull.since,
            limit: pull.limit,
          )).toJson();
        }
        return http.Response(jsonEncode(answer), 200);
      }),
    );
  }

  @override
  Future<int> put(String id, String text) async =>
      server.put('notes', id, {'id': id, 'text': text});

  @override
  Future<void> remove(String id) async => server.remove('notes', id);

  @override
  Future<({String text, int version})?> note(String id) async {
    final held = server.entity('notes', id);
    return held == null
        ? null
        : (text: held.data['text']! as String, version: held.version);
  }
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

  runTomSyncContract('the in-memory server', () async => _MemoryServer());

  runTomSyncContract(
    'the in-memory server over HTTP',
    () async => _MemoryServer.overHttp(),
  );

  group('the HTTP transport', () {
    test(
      'posts to the routes of the sync API, with the bearer token',
      () async {
        final requests = <http.Request>[];
        final transport = TomHttpSyncTransport(
          baseUri: Uri.parse('https://api.example.com/base'),
          client: MockClient((request) async {
            requests.add(request);
            return http.Response(
              request.url.path.endsWith('/push')
                  ? '{"results":[]}'
                  : '{"changes":[],"cursor":7,"hasMore":false}',
              200,
            );
          }),
          headers: () => {'authorization': 'Bearer device-token'},
        );
        await transport.push(const []);
        final batch = await transport.pull('notes', 7, limit: 3);
        expect(batch.cursor, 7);
        expect([for (final r in requests) r.method], ['POST', 'POST']);
        expect(
          [for (final r in requests) r.url.path],
          ['/base/sync/push', '/base/sync/pull'],
        );
        expect(requests.last.headers['authorization'], 'Bearer device-token');
        expect(jsonDecode(requests.last.body), {
          'collection': 'notes',
          'since': 7,
          'limit': 3,
        });
      },
    );

    test('a sync whose server answers an error fails as a transport failure '
        'and keeps the change', () async {
      final store = TomOfflineStore(TomMemoryLocalStoreEngine());
      final notes = TomLocalRepository(
        store: store,
        collection: 'notes',
        codec: _codec,
      );
      await notes.save(_Note('a', 'kept'));
      final engine = TomSyncEngine(
        store: store,
        transport: TomHttpSyncTransport(
          baseUri: Uri.parse('https://api.example.com'),
          client: MockClient((_) async => http.Response('', 503)),
        ),
        collections: ['notes'],
      );
      await expectLater(
        engine.sync(),
        throwsA(
          isA<TomOfflineException>().having(
            (e) => e.key,
            'key',
            'offline.sync.transport_failed',
          ),
        ),
      );
      expect(await store.pending(), hasLength(1));
    });

    test('reads a refusal with its error key as a failed call', () async {
      final transport = TomHttpSyncTransport(
        baseUri: Uri.parse('https://api.example.com'),
        client: MockClient(
          (_) async => http.Response(
            '{"errorKey":"$tomSyncUnknownCollectionErrorKey"}',
            400,
          ),
        ),
      );
      await expectLater(
        transport.pull('tasks', 0),
        throwsA(
          isA<TomOfflineException>()
              .having((e) => e.key, 'key', 'offline.http.failed')
              .having(
                (e) => e.parameters!['errorKey'],
                'errorKey',
                tomSyncUnknownCollectionErrorKey,
              ),
        ),
      );
    });
  });
}

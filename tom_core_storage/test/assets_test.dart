/// The content-addressed asset store and its file-medium layout.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_basics/utilities.dart';
import 'package:tom_core_storage/tom_core_storage.dart';

const types = TomAssetTypes({
  'text/plain': (extension: 'txt', kind: 'text'),
  'application/json': (extension: 'json', kind: 'data'),
});

const unlimited = TomObjectCeiling();

Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('ASSETS-STORE the store', () {
    test('ASSETS-STORE-1: an id is the SHA-256 of the bytes, and identical '
        'bytes are one asset', () {
      final store = TomAssetStore(types: types);
      final a = store.ingest(
        bytesOf('a'),
        mime: 'text/plain',
        ceiling: unlimited,
      );
      final b = store.ingest(
        bytesOf('a'),
        mime: 'text/plain',
        ceiling: unlimited,
      );
      expect(a.id, tomSha256Hex(bytesOf('a')));
      expect(identical(a, b), isTrue);
      expect(store.assets, hasLength(1));
      expect(a.extension, 'txt');
      expect(a.kind, 'text');
      expect(a.metadata(), {'mime': 'text/plain', 'kind': 'text', 'bytes': 1});
    });

    test('ASSETS-STORE-2: ingest refuses a type it cannot file and a size over '
        'the ceiling, storing nothing', () {
      final store = TomAssetStore(types: types);
      expect(
        () => store.ingest(bytesOf('a'), mime: 'image/png', ceiling: unlimited),
        throwsArgumentError,
      );
      expect(
        () => store.ingest(
          Uint8List(11),
          mime: 'text/plain',
          ceiling: const TomObjectCeiling(configured: 10),
          what: 'This note',
        ),
        throwsA(isA<TomObjectTooLargeException>()),
      );
      expect(store.assets, isEmpty);
    });

    test('ASSETS-STORE-3: stored bytes are read on first use and verified; '
        'a mismatch is a corruption, not a missing asset', () async {
      var reads = 0;
      final good = TomAsset.stored(
        id: tomSha256Hex(bytesOf('a')),
        mime: 'text/plain',
        byteCount: 1,
        types: types,
        load: () async {
          reads++;
          return bytesOf('a');
        },
        where: 'container',
      );
      expect(good.isLoaded, isFalse);
      expect(await good.bytes(), bytesOf('a'));
      await good.bytes();
      expect(reads, 1, reason: 'read once, then held');
      expect(good.loadedBytes, bytesOf('a'));

      final bad = TomAsset.stored(
        id: tomSha256Hex(bytesOf('a')),
        mime: 'text/plain',
        byteCount: 1,
        types: types,
        load: () async => bytesOf('b'),
        where: 'container',
      );
      await expectLater(
        bad.bytes(),
        throwsA(
          isA<TomAssetCorruptException>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('container'), contains(bad.id)),
          ),
        ),
      );
      expect(() => bad.loadedBytes, throwsStateError);
      expect(
        () => TomAsset.verified(
          id: tomSha256Hex(bytesOf('a')),
          mime: 'text/plain',
          bytes: bytesOf('b'),
          types: types,
          where: 'entry',
        ),
        throwsA(isA<TomAssetCorruptException>()),
      );
    });

    test(
      'ASSETS-STORE-4: resolution is live, then the history area, then '
      'missing; revive brings a referenced asset back from history',
      () async {
        final store = TomAssetStore(types: types);
        final asset = store.ingest(
          bytesOf('a'),
          mime: 'text/plain',
          ceiling: unlimited,
        );
        expect(await store.resolve(asset.id), isA<TomAssetLive>());

        final archive = {asset.id: asset};
        store.history = (id) async => archive[id];
        store.retire(asset.id);
        expect(await store.resolve(asset.id), isA<TomAssetHistorical>());
        expect(await store.resolve('f' * 64), isA<TomAssetMissing>());

        expect(await store.reviveReferenced([asset.id, 'f' * 64]), {
          asset.id,
          'f' * 64,
        });
        expect(store.assets.keys, [asset.id]);
      },
    );

    test('ASSETS-STORE-5: copying brings only the named assets a source holds; '
        'a union shares every asset and the history', () {
      final source = TomAssetStore(types: types);
      final a = source.ingest(
        bytesOf('a'),
        mime: 'text/plain',
        ceiling: unlimited,
      );
      source.ingest(bytesOf('b'), mime: 'text/plain', ceiling: unlimited);
      Future<TomAsset?> history(String id) async => null;
      source.history = history;

      final target = TomAssetStore(types: types)
        ..copyReferenced(source, [a.id, 'f' * 64]);
      expect(target.assets.keys, [a.id]);
      target.copyReferenced(target, [a.id]);

      final union = TomAssetStore(types: types)..adoptAll(source);
      expect(union.assets, hasLength(2));
      expect(union.history, same(history));
    });
  });

  group('ASSETS-BUNDLE the file-medium layout', () {
    const layout = TomAssetBundleLayout(types: types);

    test('ASSETS-BUNDLE-1: a save writes referenced assets under assets/ and '
        'returns the manifest map; a load reads no bytes', () async {
      final medium = TomMemoryBundleMedium();
      final store = TomAssetStore(types: types);
      final a = store.ingest(
        bytesOf('a'),
        mime: 'text/plain',
        ceiling: unlimited,
      );
      final map = await layout.save(store, [a.id], medium);
      expect(map, {
        a.id: {
          'file': 'assets/${a.id}.txt',
          'mime': 'text/plain',
          'kind': 'text',
          'bytes': 1,
        },
      });
      expect(await medium.readBytes('assets/${a.id}.txt'), bytesOf('a'));

      final loaded = TomAssetStore(types: types);
      layout.load(loaded, map, medium);
      expect(loaded.assets[a.id]!.isLoaded, isFalse);
      expect(await loaded.assets[a.id]!.bytes(), bytesOf('a'));
    });

    test('ASSETS-BUNDLE-2: an unreferenced asset is retired into the history '
        'folder, never deleted, and resolves from there', () async {
      final medium = TomMemoryBundleMedium();
      final store = TomAssetStore(types: types);
      final a = store.ingest(
        bytesOf('a'),
        mime: 'text/plain',
        ceiling: unlimited,
      );
      final first = await layout.save(store, [a.id], medium);

      final second = await layout.save(
        store,
        const [],
        medium,
        previous: first,
      );
      expect(second, isEmpty);
      expect(await medium.exists('assets/${a.id}.txt'), isFalse);
      expect(await medium.exists('.history/.assets/${a.id}.txt'), isTrue);
      expect(store.assets, isEmpty);
      expect(layout.isHistoryPath('.history/.assets/${a.id}.txt'), isTrue);
      expect(layout.isHistoryPath('.history/x/1.yaml'), isFalse);

      final revived = await store.reviveReferenced([a.id]);
      expect(revived, {a.id});
      expect(await store.assets[a.id]!.bytes(), bytesOf('a'));
    });

    test('ASSETS-BUNDLE-3: an asset ingested and dropped before any save goes '
        'to the history folder too, so a later undo finds it', () async {
      final medium = TomMemoryBundleMedium();
      final store = TomAssetStore(types: types);
      final a = store.ingest(
        bytesOf('a'),
        mime: 'text/plain',
        ceiling: unlimited,
      );
      await layout.save(store, const [], medium);
      expect(await medium.exists('.history/.assets/${a.id}.txt'), isTrue);
      expect(await layout.historical(medium, a.id), isNotNull);
    });

    test(
      'ASSETS-BUNDLE-4: an existing file is not rewritten, and a referenced '
      'asset that is nowhere keeps its entry only while its file exists',
      () async {
        final medium = TomRecordingBundleMedium(TomMemoryBundleMedium());
        final store = TomAssetStore(types: types);
        final a = store.ingest(
          bytesOf('a'),
          mime: 'text/plain',
          ceiling: unlimited,
        );
        final first = await layout.save(store, [a.id], medium);
        final writes = medium.changeset.writes.length;
        await layout.save(store, [a.id], medium, previous: first);
        expect(medium.changeset.writes.length, writes, reason: 'nothing new');

        final empty = TomAssetStore(types: types);
        final kept = await layout.save(empty, [a.id], medium, previous: first);
        expect(kept, first, reason: 'its file is still there');
        await medium.delete('assets/${a.id}.txt');
        final gone = await layout.save(empty, [a.id], medium, previous: first);
        expect(gone, isEmpty);
      },
    );

    test(
      'ASSETS-BUNDLE-5: a manifest entry with an unknown type or kind, or no '
      'file, is refused',
      () {
        final medium = TomMemoryBundleMedium();
        for (final meta in [
          {
            'file': 'assets/x.png',
            'mime': 'image/png',
            'kind': 'text',
            'bytes': 1,
          },
          {
            'file': 'assets/x.txt',
            'mime': 'text/plain',
            'kind': 'image',
            'bytes': 1,
          },
          {'mime': 'text/plain', 'kind': 'text', 'bytes': 1},
          {'file': 'assets/x.txt', 'mime': 'text/plain', 'kind': 'text'},
        ]) {
          expect(
            () => layout.load(TomAssetStore(types: types), {'x': meta}, medium),
            throwsFormatException,
            reason: '$meta',
          );
        }
      },
    );
  });
}

/// Forgetting a storage location removes its `locations` entry and scrubs
/// every trace this device holds for it: its per-file key overrides (persisted
/// and session-only), the cache blobs reachable only from it, its `meta/`, and
/// its journal entries. Unpushed entries are reported by `survey` before
/// anything is removed.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:tom_core_settings/tom_core_settings.dart';
import 'package:tom_core_storage/github.dart';
import 'package:tom_core_storage/tom_core_storage.dart';
import 'package:tom_github_api/tom_github_api.dart';
import 'package:tom_github_api/testing.dart';

const docsLocation = 'github:al-the-bear/docs@main/notes';
const docA = 'github:al-the-bear/docs@main/notes/a.doc';
const docB = 'github:al-the-bear/docs@main/notes/b.doc';
const teammates = 'github:al-the-bear/docs@main/notes-archive/c.doc';
const otherDoc = 'github:al-the-bear/other@main/d.doc';

Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

const key = TomKeyMaterial(passphrase: 'secret');

TomChangeset change(String text) =>
    TomChangeset(writes: {'index.yaml': bytes(text)});

/// The `meta/` and `blobs/` files a medium holds, `index.json` aside.
Future<List<String>> cacheFiles(TomBundleMedium medium) async => [
  for (final path in await medium.listFiles())
    if (path != TomStorageCache.indexPath) path,
];

void main() {
  group('SETTINGS-FORGET cache scrub', () {
    test('SETTINGS-FORGET-1: scrubLocation removes the blobs only the location '
        'reaches, keeps a blob another location shares, and removes its '
        'meta/ scope only', () async {
      final medium = TomMemoryBundleMedium();
      final cache = TomStorageCache(medium: medium);
      await cache.writeBlob('only-a', bytes('a'), owner: docA);
      await cache.writeBlob('only-b', bytes('b'), owner: docB);
      await cache.writeBlob('shared', bytes('s'), owner: docA);
      // A hit for a second container records it as a second owner.
      expect(await cache.readBlob('shared', owner: otherDoc), bytes('s'));
      await cache.writeBlob('other', bytes('o'), owner: otherDoc);
      await cache.writeBlob('beside', bytes('t'), owner: teammates);
      await cache.writeMeta(
        ['github', 'al-the-bear', 'docs', 'branches', 'main'],
        {'commit': 'x'},
      );
      await cache.writeMeta(
        ['github', 'al-the-bear', 'other', 'branches', 'main'],
        {'commit': 'y'},
      );

      final scrub = await cache.scrubLocation(
        docsLocation,
        metaScope: ['github', 'al-the-bear', 'docs'],
      );
      expect(scrub.blobsRemoved, 2);
      expect(scrub.metaRemoved, 1);

      expect(await cache.readBlob('only-a'), isNull);
      expect(await cache.readBlob('only-b'), isNull);
      expect(await cache.readBlob('shared'), bytes('s'));
      expect(await cache.readBlob('other'), bytes('o'));
      expect(
        await cache.readBlob('beside'),
        bytes('t'),
        reason: 'notes-archive is not inside notes — a path boundary',
      );
      expect(
        await cache.readMeta([
          'github',
          'al-the-bear',
          'docs',
          'branches',
          'main',
        ]),
        isNull,
      );
      expect(
        await cache.readMeta([
          'github',
          'al-the-bear',
          'other',
          'branches',
          'main',
        ]),
        {'commit': 'y'},
      );

      // The owners survive a restart: a fresh cache over the same medium
      // still knows `shared` is reached from elsewhere.
      final reopened = TomStorageCache(medium: medium);
      await reopened.scrubLocation('github:al-the-bear/other@main');
      expect(await reopened.readBlob('shared'), isNull);
      expect(await reopened.readBlob('beside'), bytes('t'));
    });

    test(
      'SETTINGS-FORGET-2: a blob with no recorded owner is scrubbed — provenance '
      'unknown is not provenance elsewhere',
      () async {
        final medium = TomMemoryBundleMedium();
        final cache = TomStorageCache(medium: medium);
        await cache.writeBlob('anonymous', bytes('?'));
        await cache.writeBlob('kept', bytes('k'), owner: otherDoc);
        final scrub = await cache.scrubLocation(docsLocation);
        expect(scrub.blobsRemoved, 1);
        expect(await cache.readBlob('anonymous'), isNull);
        expect(await cache.readBlob('kept'), bytes('k'));
      },
    );
  });

  group('SETTINGS-FORGET journal scrub', () {
    for (final kind in ['memory', 'medium']) {
      test(
        'SETTINGS-FORGET-3 ($kind): scrubLocation drops the entries inside the '
        'location, returns them, and keeps the rest in order',
        () async {
          final journal = kind == 'memory'
              ? TomMemoryCommitJournal()
              : TomMediumCommitJournal(medium: TomMemoryBundleMedium());
          for (final locator in [docA, otherDoc, docB, teammates]) {
            await journal.append(
              locator: locator,
              changeset: change(locator),
              baseHead: 'h',
              version: 1,
            );
          }
          final dropped = await journal.scrubLocation(docsLocation);
          expect(dropped.map((e) => e.locator), [docA, docB]);
          expect((await journal.pending()).map((e) => e.locator), [
            otherDoc,
            teammates,
          ]);
          expect(await journal.scrubLocation(docsLocation), isEmpty);
        },
      );
    }
  });

  group('SETTINGS-FORGET forget', () {
    late TomInMemoryLocationRegistry locations;
    late TomInMemoryKeyStore keyStore;
    late TomMemoryKeyRegistry documents;
    late TomMemoryKeyRegistry collaboration;
    late TomMemoryCommitJournal journal;
    late TomMemoryBundleMedium medium;
    late TomStorageCache cache;

    TomLocationForgetting forgetting({List<TomStorage>? backends}) =>
        TomLocationForgetting(
          locations: locations,
          keyStore: keyStore,
          keyRegistries: [documents, collaboration],
          cache: cache,
          journal: journal,
          backends:
              backends ?? [TomGitHubStorage(tokens: TomInMemoryTokenSource())],
        );

    setUp(() async {
      locations = TomInMemoryLocationRegistry();
      await locations.register(
        const TomStorageLocation(displayName: 'notes', locator: docsLocation),
      );
      await locations.register(
        const TomStorageLocation(
          displayName: 'other',
          locator: 'github:al-the-bear/other@main',
        ),
      );
      keyStore = TomInMemoryKeyStore();
      documents = TomMemoryKeyRegistry();
      collaboration = TomMemoryKeyRegistry();
      // Persisted and registered.
      await keyStore.saveOverride(docA, key);
      documents.registerKeyFor(docA, key);
      collaboration.registerKeyFor(docA, key);
      // Session-only: in a registry, in no store.
      documents.registerKeyFor(docB, key);
      // Outside the location.
      await keyStore.saveOverride(otherDoc, key);
      documents.registerKeyFor(otherDoc, key);
      journal = TomMemoryCommitJournal();
      await journal.append(
        locator: docA,
        changeset: change('a'),
        baseHead: 'h',
        version: 2,
      );
      await journal.append(
        locator: otherDoc,
        changeset: change('o'),
        baseHead: 'h',
        version: 3,
      );
      medium = TomMemoryBundleMedium();
      cache = TomStorageCache(medium: medium);
      await cache.writeBlob('a', bytes('a'), owner: docA);
      await cache.writeBlob('o', bytes('o'), owner: otherDoc);
      await cache.writeMeta(
        ['github', 'al-the-bear', 'docs', 'default-branch'],
        {'b': 'main'},
      );
    });

    test('SETTINGS-FORGET-4: survey reports the unpushed entries and the key '
        'overrides inside the location, and changes nothing', () async {
      final traces = await forgetting().survey(docsLocation);
      expect(traces.unpushed, isNotEmpty);
      expect(traces.unpushedLocators, [docA]);
      expect(traces.keyOverrides, [docA, docB]);

      expect(locations.locations, hasLength(2));
      expect(await journal.pending(), hasLength(2));
      expect(documents.hasOverrideFor(docB), isTrue);
      expect(await cache.readBlob('a'), isNotNull);
    });

    test('SETTINGS-FORGET-5: forget removes the locations entry, every key '
        'override inside it, its journal entries, its blobs and its meta/ — '
        'and nothing outside it', () async {
      final result = await forgetting().forget(docsLocation);
      expect(result.journalEntriesRemoved, 1);
      expect(result.keyOverridesRemoved, 2);
      expect(result.cache.blobsRemoved, 1);
      expect(result.cache.metaRemoved, 1);

      expect(locations.locations.map((l) => l.locator), [
        'github:al-the-bear/other@main',
      ]);
      expect((await keyStore.loadOverrides()).keys, [otherDoc]);
      for (final registry in [documents, collaboration]) {
        expect(registry.hasOverrideFor(docA), isFalse);
        expect(registry.hasOverrideFor(docB), isFalse);
      }
      expect(documents.hasOverrideFor(otherDoc), isTrue);
      expect((await journal.pending()).map((e) => e.locator), [otherDoc]);
      expect(await cacheFiles(medium), [
        for (final path in await cacheFiles(medium))
          if (path.startsWith('blobs/')) path,
      ]);
      expect(await cache.readBlob('o'), bytes('o'));

      final again = await forgetting().survey(docsLocation);
      expect(again.unpushed, isEmpty);
      expect(again.keyOverrides, isEmpty);
    });

    test(
      'SETTINGS-FORGET-6: a meta/ scope another registered location shares is '
      'kept — GitHub keeps one listing per repository',
      () async {
        await locations.register(
          const TomStorageLocation(
            displayName: 'drafts',
            locator: 'github:al-the-bear/docs@main/drafts',
          ),
        );
        final result = await forgetting().forget(docsLocation);
        expect(result.cache.metaRemoved, 0);
        expect(
          await cache.readMeta([
            'github',
            'al-the-bear',
            'docs',
            'default-branch',
          ]),
          {'b': 'main'},
        );
        expect(
          result.cache.blobsRemoved,
          1,
          reason: 'blobs are owned per document, so these still go',
        );
      },
    );

    test('SETTINGS-FORGET-7: the GitHub backend answers its repository as the '
        'meta/ scope, a local backend none, and a Windows path continues a '
        'location at a backslash', () {
      final github = TomGitHubStorage(tokens: TomInMemoryTokenSource());
      expect(github.cacheMetaScope('github:o/r'), ['github', 'o', 'r']);
      expect(github.cacheMetaScope('github:o/r@dev/a/b'), ['github', 'o', 'r']);
      expect(github.cacheMetaScope('/Users/me/docs'), isNull);
      expect(tomLocationCovers(r'C:\Docs', r'C:\Docs\a.doc'), isTrue);
      expect(tomLocationCovers(r'C:\Docs', r'C:\Docsx\a.doc'), isFalse);
    });
  });

  test(
    'SETTINGS-FORGET-8: end to end over a GitHub server — what a backend cached '
    'while reading two repositories, forgetting one leaves the other\'s '
    'cache whole',
    () async {
      final server = FakeGitHubServer();
      server.repo('al-the-bear/docs').defaultBranch = 'main';
      server.repo('al-the-bear/other').defaultBranch = 'main';
      final medium = TomMemoryBundleMedium();
      final cache = TomStorageCache(medium: medium);
      final storage = TomGitHubStorage.withClient(
        GitHubApiClient(
          token: 'test-token',
          httpClient: _Passthrough(server.client),
          baseUrl: FakeGitHubServer.baseUrl,
          minMutativeInterval: Duration.zero,
        ),
        cache: cache,
      );
      const docsFile = '$docsLocation/a.doc.yaml';
      const otherFile = 'github:al-the-bear/other@main/b.doc.yaml';
      await storage.commit(docsFile, TomChangeset.singleFile(bytes('A')));
      await storage.commit(otherFile, TomChangeset.singleFile(bytes('B')));
      expect(await storage.readBytes(docsFile), bytes('A'));
      expect(await storage.readBytes(otherFile), bytes('B'));
      final before = await cacheFiles(medium);
      expect(
        before.where((p) => p.startsWith('meta/github/al-the-bear/docs')),
        isNotEmpty,
      );

      final locations = TomInMemoryLocationRegistry();
      await locations.register(
        const TomStorageLocation(displayName: 'notes', locator: docsLocation),
      );
      await locations.register(
        const TomStorageLocation(
          displayName: 'other',
          locator: 'github:al-the-bear/other@main',
        ),
      );
      final result = await TomLocationForgetting(
        locations: locations,
        cache: cache,
        backends: [storage],
      ).forget(docsLocation);
      expect(result.cache.blobsRemoved, greaterThan(0));

      final after = await cacheFiles(medium);
      expect(
        after.where((p) => p.startsWith('meta/github/al-the-bear/docs')),
        isEmpty,
      );
      expect(
        after.where((p) => p.startsWith('meta/github/al-the-bear/other')),
        isNotEmpty,
      );
      // The other repository's content is still served from the cache.
      final served = TomStorageCache(medium: medium);
      final blobs = after.where((p) => p.startsWith('blobs/')).toList();
      expect(blobs, isNotEmpty);
      var held = 0;
      for (final path in blobs) {
        final address = Uri.decodeComponent(path.split('/').last);
        if (await served.readBlob(address) != null) held++;
      }
      expect(held, blobs.length);
    },
  );
}

class _Passthrough extends http.BaseClient {
  final http.Client _inner;
  _Passthrough(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);
}

/// The deduplicating blob store, its quota and the orphan sweep, without a
/// database: the in-memory ledger in front of three content stores — memory,
/// a directory on the file system, and S3 served by an in-memory object
/// server. The SQL ledger and the repository-backed sweep run in
/// `deduplicating_blob_store_db_test.dart`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'package:test/fake.dart';

import 'fixtures/fake_s3_server.dart';
import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

Matcher _throwsKey(String key) =>
    throwsA(isA<TomStorageException>().having((e) => e.key, 'key', key));

Stream<List<int>> _text(String text) => Stream.value(utf8.encode(text));

/// A content store and a view of every key it physically holds.
class _Backend {
  _Backend(this.name, this.open);

  final String name;

  /// A fresh content store and the function listing its stored keys.
  final Future<(TomBlobStore, Future<Set<String>> Function())> Function() open;
}

final _backends = [
  _Backend('memory', () async {
    final store = TomMemoryBlobStore();
    return (store as TomBlobStore, () async => store.keys.toSet());
  }),
  _Backend('directory', () async {
    final root = await Directory(
      '${Directory.current.path}/../../../ztmp',
    ).createTemp('tom_core_dedup_test_');
    addTearDown(() => root.delete(recursive: true));
    Future<Set<String>> keys() async => {
      await for (final entity in root.list(recursive: true))
        if (entity is File &&
            !entity.path.contains(TomBlobStore.auxiliaryMarker))
          entity.path.substring(root.path.length + 1),
    };
    return (TomDirectoryBlobStore(root) as TomBlobStore, keys);
  }),
  _Backend('s3', () async {
    final server = FakeS3Server();
    return (
      server.store() as TomBlobStore,
      () async => server.objects.keys.toSet(),
    );
  }),
];

/// A source naming a fixed set of keys as referenced.
class _Rows extends TomBlobReferenceSource {
  _Rows(this.keys);

  final Set<String> keys;
  int asked = 0;

  @override
  Future<Set<String>> referenced(List<String> keys) async {
    asked++;
    return keys.where(this.keys.contains).toSet();
  }
}

void main() {
  for (final backend in _backends) {
    group('over the ${backend.name} content store', () {
      late TomBlobStore content;
      late Future<Set<String>> Function() storedKeys;
      late TomMemoryBlobLedger ledger;
      late DateTime now;

      TomDeduplicatingBlobStore store({
        TomBlobQuota? quota,
        String owner = '',
      }) => TomDeduplicatingBlobStore(
        content: content,
        ledger: ledger,
        quota: quota,
        ownerOf: () => owner,
        reclaimGrace: const Duration(minutes: 10),
        clock: () => now,
      );

      setUp(() async {
        (content, storedKeys) = await backend.open();
        ledger = TomMemoryBlobLedger();
        now = DateTime.utc(2026, 10, 27, 12);
      });

      group('deduplication', () {
        test(
          'identical content is stored once, under any number of keys',
          () async {
            final dedup = store();
            final a = await dedup.put(key: 'docs/a.txt', bytes: _text('same'));
            final b = await dedup.put(
              key: 'docs/b.txt',
              bytes: _text('same'),
              mediaType: 'text/plain',
              fileName: 'b.txt',
            );
            expect(a.digest, b.digest);
            expect(a.digest, TomBlobDigest.of(utf8.encode('same')));
            final stored = await storedKeys();
            expect(
              stored,
              hasLength(1),
              reason: 'one content, no staging left',
            );
            expect(
              stored.single,
              startsWith('${TomDeduplicatingBlobStore.defaultContentPrefix}/'),
            );
            expect(utf8.decode(await dedup.getBytes('docs/a.txt')), 'same');
            expect(utf8.decode(await dedup.getBytes('docs/b.txt')), 'same');
            expect(await ledger.referencesTo(a.digest), 2);

            final described = (await dedup.describe('docs/b.txt'))!;
            expect(described.mediaType, 'text/plain');
            expect(described.fileName, 'b.txt');
            expect(described.byteCount, 4);
            expect(described.digest, a.digest);
          },
        );

        test('different content is stored apart', () async {
          final dedup = store();
          await dedup.put(key: 'a', bytes: _text('one'));
          await dedup.put(key: 'b', bytes: _text('two'));
          expect(await storedKeys(), hasLength(2));
        });

        test('a copy names the same content and moves no bytes', () async {
          final dedup = store();
          await dedup.put(key: 'a', bytes: _text('shared'));
          final before = await storedKeys();
          final copied = await dedup.copy('a', 'b');
          expect(copied.key, 'b');
          expect(await storedKeys(), before);
          final moved = await dedup.move('b', 'c');
          expect(moved.key, 'c');
          expect(await dedup.exists('b'), isFalse);
          expect(utf8.decode(await dedup.getBytes('c')), 'shared');
          expect(await storedKeys(), before);
        });

        test('a range reads from the shared content', () async {
          final dedup = store();
          await dedup.put(key: 'a', bytes: _text('0123456789'));
          expect(
            utf8.decode(await dedup.getBytes('a', range: TomBlobRange(2, 5))),
            '234',
          );
        });

        test('an absent key is not_found on every read', () async {
          final dedup = store();
          await expectLater(
            dedup.getBytes('nope'),
            _throwsKey('storage.blob.not_found'),
          );
          expect(await dedup.describe('nope'), isNull);
          expect(await dedup.delete('nope'), isFalse);
          await expectLater(
            dedup.copy('nope', 'b'),
            _throwsKey('storage.blob.not_found'),
          );
        });

        test('a failed upload leaves neither a key nor staged bytes', () async {
          final dedup = store();
          Stream<List<int>> failing() async* {
            yield utf8.encode('partial');
            throw StateError('upload interrupted');
          }

          await expectLater(
            dedup.put(key: 'a', bytes: failing()),
            _throwsKey('storage.blob.write_failed'),
          );
          expect(await dedup.exists('a'), isFalse);
          expect(await storedKeys(), isEmpty);
        });

        test(
          'content whose bytes went missing is repaired by the next write of '
          'it',
          () async {
            final dedup = store();
            await dedup.put(key: 'a', bytes: _text('fragile'));
            final contentKey = (await ledger.find('a'))!.contentKey;
            await content.delete(contentKey);
            await dedup.put(key: 'b', bytes: _text('fragile'));
            expect((await ledger.find('b'))!.contentKey, contentKey);
            expect(utf8.decode(await dedup.getBytes('a')), 'fragile');
          },
        );
      });

      group('reclaim', () {
        test('content stays while a key names it, and goes after the grace '
            'once none does', () async {
          final dedup = store();
          await dedup.put(key: 'a', bytes: _text('kept'));
          await dedup.put(key: 'b', bytes: _text('kept'));
          await dedup.put(key: 'c', bytes: _text('dropped'));
          expect(await dedup.delete('a'), isTrue);
          expect(await dedup.delete('c'), isTrue);
          expect(await storedKeys(), hasLength(2), reason: 'not deleted yet');

          // Within the grace nothing goes.
          expect(
            await dedup.reclaim(now: now.add(const Duration(minutes: 5))),
            0,
          );
          expect(
            await dedup.reclaim(now: now.add(const Duration(minutes: 11))),
            1,
          );
          expect(await storedKeys(), hasLength(1));
          expect(utf8.decode(await dedup.getBytes('b')), 'kept');
          expect(
            await dedup.reclaim(now: now.add(const Duration(hours: 1))),
            0,
          );
        });

        test('replacing a key releases its old content', () async {
          final dedup = store();
          await dedup.put(key: 'a', bytes: _text('v1'));
          await dedup.put(key: 'a', bytes: _text('v2'));
          expect(await storedKeys(), hasLength(2));
          expect(
            await dedup.reclaim(now: now.add(const Duration(hours: 1))),
            1,
          );
          expect(await storedKeys(), hasLength(1));
          expect(utf8.decode(await dedup.getBytes('a')), 'v2');
        });

        test('content stored again after a reclaim takes a new key', () async {
          final dedup = store();
          await dedup.put(key: 'a', bytes: _text('again'));
          final first = (await ledger.find('a'))!.contentKey;
          await dedup.delete('a');
          now = now.add(const Duration(hours: 1));
          expect(await dedup.reclaim(), 1);
          await dedup.put(key: 'a', bytes: _text('again'));
          expect((await ledger.find('a'))!.contentKey, isNot(first));
          expect(utf8.decode(await dedup.getBytes('a')), 'again');
        });

        test(
          'a prefix delete removes the keys, and the reclaim the bytes',
          () async {
            final dedup = store();
            await dedup.put(key: 'p/1', bytes: _text('one'));
            await dedup.put(key: 'p/2', bytes: _text('two'));
            await dedup.put(key: 'p2', bytes: _text('three'));
            expect(await dedup.deletePrefix('p'), 2);
            expect(await dedup.exists('p2'), isTrue);
            expect(
              await dedup.reclaim(now: now.add(const Duration(hours: 1))),
              2,
            );
            expect(await storedKeys(), hasLength(1));
          },
        );
      });

      group('the per-owner quota', () {
        test('counts blobs per owner; replacing one is not another', () async {
          final dedup = store(
            quota: const TomBlobQuota(maxCount: 2),
            owner: 'ada',
          );
          await dedup.put(key: 'a', bytes: _text('1'));
          await dedup.put(key: 'b', bytes: _text('2'));
          await expectLater(
            dedup.put(key: 'c', bytes: _text('3')),
            _throwsKey('storage.quota.count_exceeded'),
          );
          await dedup.put(key: 'a', bytes: _text('1 again'));
          expect((await ledger.usageOf('ada')).count, 2);
          // Another owner, and a blob of no one, are counted apart.
          await TomDeduplicatingBlobStore.runAs(
            'bob',
            () => dedup.put(key: 'd', bytes: _text('4')),
          );
          await TomDeduplicatingBlobStore.runAs(
            '',
            () => dedup.put(key: 'e', bytes: _text('5')),
          );
          expect((await ledger.find('d'))!.owner, 'bob');
          expect((await ledger.find('e'))!.owner, '');
          // A copy is charged to whoever makes it.
          await expectLater(
            dedup.copy('d', 'f'),
            _throwsKey('storage.quota.count_exceeded'),
          );
        });

        test(
          'a write taking the owner past the bytes is undone and refused',
          () async {
            final dedup = store(
              quota: const TomBlobQuota(maxBytes: 10),
              owner: 'ada',
            );
            await dedup.put(key: 'a', bytes: _text('12345'));
            final before = await storedKeys();
            await expectLater(
              dedup.put(key: 'big', bytes: _text('1234567890')),
              _throwsKey('storage.quota.bytes_exceeded'),
            );
            expect(await dedup.exists('big'), isFalse);
            expect(
              await storedKeys(),
              before,
              reason: 'nothing staged is left',
            );
            expect(await ledger.usageOf('ada'), isA<TomBlobUsage>());
            expect((await ledger.usageOf('ada')).bytes, 5);

            // Owners are charged logical bytes: shared content still counts.
            await dedup.put(key: 'b', bytes: _text('12345'));
            await expectLater(
              dedup.put(key: 'c', bytes: _text('x')),
              _throwsKey('storage.quota.bytes_exceeded'),
            );
            // Replacing a held blob is charged only the difference.
            await dedup.put(key: 'b', bytes: _text('abc'));
            expect((await ledger.usageOf('ada')).bytes, 8);
          },
        );

        test('the default owner is the principal in the zone', () async {
          final dedup = TomDeduplicatingBlobStore(
            content: content,
            ledger: ledger,
            quota: const TomBlobQuota(maxCount: 1),
          );
          final principal = TomPrincipal(
            user: TomUser(id: '42', username: 'ada'),
            aci: TomAccessControlInformation(),
            authenticated: true,
          );
          await runZoned(
            () => dedup.put(key: 'a', bytes: _text('mine')),
            zoneValues: {TomPrincipal: principal},
          );
          expect((await ledger.find('a'))!.owner, principal.qualifiedId);
          await expectLater(
            runZoned(
              () => dedup.put(key: 'b', bytes: _text('more')),
              zoneValues: {TomPrincipal: principal},
            ),
            _throwsKey('storage.quota.count_exceeded'),
          );
        });
      });

      group('the orphan sweep', () {
        test(
          'deletes old keys no row refers to, and reclaims their bytes',
          () async {
            final dedup = store();
            await dedup.put(key: 'up/attached.txt', bytes: _text('kept'));
            await dedup.put(key: 'up/abandoned.txt', bytes: _text('orphan'));
            await dedup.put(key: 'other/x.txt', bytes: _text('elsewhere'));
            now = now.add(const Duration(days: 2));
            await dedup.put(key: 'up/fresh.txt', bytes: _text('young'));

            final rows = _Rows({'up/attached.txt'});
            final sweep = TomBlobOrphanSweep(
              store: dedup,
              sources: [rows],
              prefixes: const ['up'],
              batchSize: 1,
            );
            final report = await sweep.sweep(now: now);
            expect(report.deleted, ['up/abandoned.txt']);
            expect(report.scanned, 2);
            expect(report.reclaimed, 1);
            expect(await dedup.exists('up/attached.txt'), isTrue);
            expect(await dedup.exists('up/fresh.txt'), isTrue);
            expect(await dedup.exists('other/x.txt'), isTrue);
            expect(await storedKeys(), hasLength(3));
          },
        );

        test('a key referenced while the sweep ran is kept', () async {
          final dedup = store();
          await dedup.put(key: 'late.txt', bytes: _text('late'));
          now = now.add(const Duration(days: 2));
          final rows = _LateRows('late.txt');
          final report = await TomBlobOrphanSweep(
            store: dedup,
            sources: [rows],
          ).sweep(now: now);
          expect(report.deleted, isEmpty);
          expect(await dedup.exists('late.txt'), isTrue);
        });
      });
    });
  }

  group('the sweep refuses what it cannot do safely', () {
    final dedup = TomDeduplicatingBlobStore(
      content: TomMemoryBlobStore(),
      ledger: TomMemoryBlobLedger(),
    );

    test('no sources, no grace', () {
      expect(
        () => TomBlobOrphanSweep(store: dedup, sources: const []),
        throwsArgumentError,
      );
      expect(
        () => TomBlobOrphanSweep(
          store: dedup,
          sources: [_Rows({})],
          grace: Duration.zero,
        ),
        throwsArgumentError,
      );
    });

    test('inside a request', () async {
      final principal = TomPrincipal(
        user: TomUser(id: '1', username: 'u'),
        aci: TomAccessControlInformation(),
        authenticated: true,
      );
      await expectLater(
        runZoned(
          () => TomBlobOrphanSweep(store: dedup, sources: [_Rows({})]).sweep(),
          zoneValues: {TomPrincipal: principal},
        ),
        _throwsKey('storage.sweep.scoped_run'),
      );
    });

    test(
      'an entity storing no files, or a field that is not a file column',
      () {
        initializeReflection();
        expect(
          () => TomRepositoryBlobReferences<TomBlobChunkRow, int>(
            _Documents<TomBlobChunkRow>([]),
          ),
          _throwsKey('storage.sweep.no_file_columns'),
        );
        expect(
          () => TomRepositoryBlobReferences<FixtureDocumentRecord, int>(
            _Documents([]),
            fields: const {'title'},
          ),
          _throwsKey('storage.sweep.unknown_field'),
        );
      },
    );
  });

  group('a repository as a reference source', () {
    setUpAll(initializeReflection);

    FixtureDocumentRecord doc(String? attachment, String? secret) =>
        FixtureDocumentRecord()
          ..attachment = attachment
          ..secretAttachment = secret;

    test('asks a plain file column in batches, a graded one key by key, '
        'soft-deleted rows included', () async {
      final repository = _Documents([
        doc('k/1', null),
        doc(null, 'k/2'),
        doc('k/9', 'k/8'),
      ]);
      final source = TomRepositoryBlobReferences<FixtureDocumentRecord, int>(
        repository,
        batchSize: 2,
      );
      expect(await source.referenced(['k/1', 'k/2', 'k/3']), {'k/1', 'k/2'});
      // `attachment` is asked once per batch of two; `secret_attachment` is
      // graded, so its values may be masked, and is counted per key instead.
      expect(
        repository.sentences.where((s) => s.startsWith('FIND')),
        hasLength(2),
      );
      expect(repository.sentences.first, contains('IS IN ( :k0 , :k1 )'));
      expect(
        repository.sentences.where((s) => s.startsWith('COUNT')),
        hasLength(3),
      );
      expect(repository.includingDeleted, everyElement(isTrue));
    });

    test('only the fields it is given', () async {
      final repository = _Documents([doc(null, 'k/2')]);
      final source = TomRepositoryBlobReferences<FixtureDocumentRecord, int>(
        repository,
        fields: const {'attachment'},
      );
      expect(await source.referenced(['k/2']), isEmpty);
    });
  });

  group('the store refuses a layout it cannot keep apart', () {
    test('nested prefixes and a negative grace', () {
      expect(
        () => TomDeduplicatingBlobStore(
          content: TomMemoryBlobStore(),
          ledger: TomMemoryBlobLedger(),
          contentPrefix: 'a',
          stagingPrefix: 'a/staging',
        ),
        throwsArgumentError,
      );
      expect(
        () => TomDeduplicatingBlobStore(
          content: TomMemoryBlobStore(),
          ledger: TomMemoryBlobLedger(),
          reclaimGrace: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('jobs', () {
    test('the reclaim and the sweep run on a scheduler', () async {
      var now = DateTime.utc(2026, 10, 27, 12);
      final content = TomMemoryBlobStore();
      final dedup = TomDeduplicatingBlobStore(
        content: content,
        ledger: TomMemoryBlobLedger(),
        reclaimGrace: const Duration(minutes: 1),
        clock: () => now,
      );
      await dedup.put(key: 'a', bytes: _text('orphan'));
      now = now.add(const Duration(days: 2));
      final sweep = TomBlobOrphanSweep(
        store: dedup,
        sources: [_Rows({})],
        clock: () => now,
      );
      final scheduler = TomScheduler(
        store: TomMemoryJobStore(),
        dispatcher: const TomInlineJobDispatcher(),
        clock: () => now,
        onAlert: (_) {},
      );
      addTearDown(scheduler.close);
      final sweepJob = sweep.jobDefinition(
        schedule: TomIntervalSchedule(const Duration(minutes: 30)),
      );
      final reclaimJob = dedup.reclaimJobDefinition(
        schedule: TomIntervalSchedule(const Duration(minutes: 30)),
      );
      expect(sweepJob.name, 'tom.storage.orphan_sweep');
      expect(reclaimJob.name, 'tom.storage.reclaim');
      scheduler
        ..register(sweepJob)
        ..register(reclaimJob);
      await scheduler.tick();
      now = now.add(const Duration(minutes: 31));
      await scheduler.tick();
      await scheduler.drain();
      expect(await dedup.exists('a'), isFalse);
      expect(content.keys, isEmpty);
    });
  });
}

/// A source that does not see [key] on the first question and does on the
/// second — a row saved while the sweep was checking its page.
class _LateRows extends TomBlobReferenceSource {
  _LateRows(this.key);

  final String key;
  int _asked = 0;

  @override
  Future<Set<String>> referenced(List<String> keys) async =>
      _asked++ == 0 ? {} : keys.where((k) => k == key).toSet();
}

/// A repository over [rows] answering `FIND BY <field> IS IN ( ... )` by the
/// field the sentence names.
class _Documents<T extends Object> extends Fake
    implements TomRepository<T, int> {
  _Documents(this.rows);

  final List<T> rows;
  final List<String> sentences = [];
  final List<bool> includingDeleted = [];

  @override
  Future<TomDbInt> countByQuerySentence(
    String querySentence,
    Map<String, Object?> params,
  ) async {
    sentences.add(querySentence);
    includingDeleted.add(TomSoftDelete.isIncludingDeleted);
    final field = RegExp(r'COUNT BY (\w+) ').firstMatch(querySentence)![1]!;
    return TomDbInt(_matching(field, params.values.toSet()).length);
  }

  Iterable<T> _matching(String field, Set<Object?> wanted) => rows.where((row) {
    final value = switch (row) {
      FixtureDocumentRecord(:final attachment, :final secretAttachment) =>
        field == 'attachment' ? attachment : secretAttachment,
      _ => null,
    };
    return wanted.contains(value);
  });

  @override
  Future<Iterable<T>> findByQuerySentence(
    String querySentence,
    Map<String, Object?> parameters, [
    Type? resultType,
    TomPageRequest? page,
  ]) async {
    sentences.add(querySentence);
    includingDeleted.add(TomSoftDelete.isIncludingDeleted);
    final field = RegExp(r'FIND BY (\w+) ').firstMatch(querySentence)![1]!;
    return _matching(field, parameters.values.toSet());
  }
}

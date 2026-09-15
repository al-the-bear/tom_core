/// DB-backed tests for the two halves of file storage that need a real
/// database.
///
/// `file_storage_test.dart` and `file_reference_test.dart` cover everything
/// that can be decided without one — the key grammar, the directory and S3
/// backends, the signer, the registry, the key scheme, the annotation
/// resolution. Two claims are left, and neither can be made honestly against a
/// fake:
///
///  * **[TomDatabaseBlobStore] streams through SQL.** Its chunking, its
///    upload-id commit point and its base64 encoding exist because of what the
///    MariaDB driver does to bytes; a mock data source would test the code
///    against the assumption instead of against the driver.
///  * **File-reference columns are wired end to end.** A
///    [TomSqlDatasourceRepository] resolves a registered data source in its
///    constructor, so `saveFile` / `openFile` / the delete cascade cannot be
///    exercised at all without a database behind the entity. Here the *bytes*
///    go to a [TomMemoryBlobStore] and the *keys* to MariaDB, which is exactly
///    the split the feature claims: the row is ordinary, the payload is not in
///    it.
///
/// The whole file is `@Tags(['db'])` and skips itself when no server is
/// reachable, so the default `testkit :test` run stays green everywhere. Bring
/// one up with `tool/run_db_tests.sh`.
@Tags(['db'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart'
    show
        FixtureDocumentRecord,
        FixtureDocumentRepository,
        FixtureScopedDocumentRecord,
        FixtureScopedDocumentRepository;
import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

/// A one-shot stream of [chunks] — the shape every `put` takes.
Stream<List<int>> _stream(List<List<int>> chunks) =>
    Stream.fromIterable(chunks);

/// A single-chunk stream of [text].
Stream<List<int>> _text(String text) => _stream([utf8.encode(text)]);

/// A stream that delivers [chunks] and then fails — an upload whose source dies
/// mid-transfer, which is what the store's rollback path exists for.
Stream<List<int>> _failingStream(List<List<int>> chunks) async* {
  for (final chunk in chunks) {
    yield chunk;
  }
  throw StateError('upload interrupted');
}

/// [count] bytes whose values depend on their position, so a round trip that
/// silently reorders or truncates cannot pass.
Uint8List _bytes(int count, [int seed = 0]) => Uint8List.fromList([
  for (var i = 0; i < count; i++) (i * 31 + seed) & 0xff,
]);

/// A resolver that grades exactly the fixture's secret column, leaving every
/// other resource at [TomAuthState.full].
///
/// Installed globally because that is how the repository reads a grade — via
/// [TomAuthorization.resolveAuth], with no seam to inject one per call. Cleared
/// in `tearDown`, so a test that forgets cannot grade another one.
class _GradeAdapter implements TomAuthorizationAdapter {
  _GradeAdapter(this.grades);

  final Map<String, TomAuthState> grades;

  @override
  TomAuthState resolveAuth(String resourceKeyPath) =>
      grades[resourceKeyPath] ?? TomAuthState.full;
}

FixtureDocumentRecord _document(String title) =>
    FixtureDocumentRecord()..title = title;

FixtureScopedDocumentRecord _scopedDocument(String title, int ownerId) =>
    FixtureScopedDocumentRecord()
      ..title = title
      ..ownerId = ownerId;

/// The principal the `owner` data-scope resolver reads: its `id` is the value
/// matched against the row's `owner_id`.
TomPrincipal _principal(int id) => TomPrincipal(
  user: TomUser(id: id, username: 'user$id'),
  aci: TomAccessControlInformation(),
  authenticated: true,
);

/// Runs [body] as the principal with id [userId].
///
/// The repository reads the principal from the *zone*
/// (`getFromCurrentZone<TomPrincipal>()`), so acting as someone is expressed by
/// running inside a zone that carries them — there is no per-call seam.
Future<T> _as<T>(int userId, Future<T> Function() body) =>
    runZoned(body, zoneValues: {TomPrincipal: _principal(userId)});

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'MariaDB not reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh';

  group('TomDatabaseBlobStore', () {
    late TomDataSourceInfo dsi;
    late TomDatabaseBlobStore store;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
    });

    setUp(() async {
      // Dropped rather than truncated: the store creates its own tables, so a
      // fresh drop also proves `ensureSchema` provisions them.
      await TestDatabase.dropBlobTables(dsi);
      // A deliberately tiny chunk so a few kilobytes exercise the multi-row
      // path that a production 256 KiB default would swallow whole.
      store = TomDatabaseBlobStore(dsi.datasource, chunkSize: 1024);
    });

    tearDownAll(TestDatabase.reset);

    test(
      'creates its schema on first use and round-trips a small blob',
      () async {
        final stored = await store.put(
          key: 'db/small.txt',
          bytes: _text('hello database'),
          mediaType: 'text/plain',
          fileName: 'small.txt',
        );

        expect(stored.key, 'db/small.txt');
        expect(stored.byteCount, 14);
        expect(stored.mediaType, 'text/plain');
        expect(stored.fileName, 'small.txt');
        expect(
          utf8.decode(await store.getBytes('db/small.txt')),
          'hello database',
        );
      },
    );

    test(
      'describes and probes a stored blob without reading its bytes',
      () async {
        await store.put(
          key: 'db/described.bin',
          bytes: _stream([_bytes(300)]),
          mediaType: 'application/octet-stream',
          fileName: 'described.bin',
        );

        final described = await store.describe('db/described.bin');
        expect(described, isNotNull);
        expect(described!.byteCount, 300);
        expect(described.fileName, 'described.bin');
        expect(described.mediaType, 'application/octet-stream');
        expect(await store.exists('db/described.bin'), isTrue);
        expect(await store.exists('db/absent.bin'), isFalse);
        expect(await store.describe('db/absent.bin'), isNull);
      },
    );

    test('the write time survives the round trip exactly, and as UTC', () async {
      // The column is the only place a blob's metadata leaves the process and
      // comes back, so it is the only place the instant convention can actually
      // be checked. The store used to render `stored_at` itself — a local
      // `DateTime`, formatted to whole seconds and bound as text — which put
      // the writing host's wall-clock reading in a column everything else
      // treats as UTC. Read back on a host at a different offset, the same row
      // named a different moment; read back on the *same* host it still failed
      // to equal what `put` returned, because that was local and this is not.
      //
      // Both halves are asserted on purpose, and together they pin more than
      // either does alone. `isUtc` by itself would pass for a store that
      // mislabelled a local reading as UTC — precisely the old defect.
      //
      // Equality is the stronger half, and it reaches all the way into the
      // column, because the two sides are derived independently: `stored`
      // comes from `TomStoredBlob` normalising the writer's own `DateTime.now`,
      // while `described` comes from the text MariaDB actually holds. Anything
      // that writes local time into the column — the old formatter, or a
      // `sqlInstant` that forgot its `toUtc` — makes the second disagree with
      // the first by exactly the host's offset. So this cannot be satisfied by
      // a conversion applied symmetrically on both sides and wrong in the
      // database, which is the failure that would otherwise stay invisible
      // until some other client read the same rows.
      final stored = await store.put(
        key: 'db/stamped.bin',
        bytes: _stream([_bytes(64)]),
      );
      final described = await store.describe('db/stamped.bin');

      expect(stored.storedAt.isUtc, isTrue);
      expect(described!.storedAt.isUtc, isTrue);
      expect(described.storedAt, stored.storedAt);

      // Sub-second precision is part of "exactly". `sqlInstant` always writes
      // six fractional digits, so a column narrower than `DATETIME(6)` rounds
      // them and moves the stored moment by up to half a second — silently,
      // and in whichever direction the fraction happened to fall. A row whose
      // microseconds are all zero would be the tell.
      final roundTripped = await store.describe('db/stamped.bin');
      expect(roundTripped!.storedAt, stored.storedAt);
      expect(
        roundTripped.storedAt.microsecondsSinceEpoch,
        stored.storedAt.microsecondsSinceEpoch,
      );
    });

    test(
      'splits a payload across chunk rows and streams them back in order',
      () async {
        // 4.5 chunks at the 1 KiB chunk size: an uneven tail, so a store that
        // only handled exact multiples would fail here.
        final payload = _bytes(4608, 7);
        await store.put(key: 'db/chunked.bin', bytes: _stream([payload]));

        final received = <List<int>>[];
        await for (final chunk in store.get('db/chunked.bin')) {
          received.add(chunk);
        }
        // Streamed, not assembled: the caller saw one event per stored chunk —
        // four full 1 KiB rows and the 512-byte tail.
        expect(received, hasLength(5));
        expect(received.map((c) => c.length), [1024, 1024, 1024, 1024, 512]);
        expect(received.expand((c) => c).toList(), payload);
      },
    );

    test('carries arbitrary bytes through unchanged', () async {
      // The base64 encoding exists because the driver decodes column values as
      // text; this is the assertion that says so. Every byte value, including
      // 0x00 and the ones that are not valid UTF-8 on their own.
      final payload = Uint8List.fromList([for (var i = 0; i < 256; i++) i]);
      await store.put(key: 'db/binary.bin', bytes: _stream([payload]));
      expect(await store.getBytes('db/binary.bin'), payload);
    });

    test('reassembles a payload delivered in many small events', () async {
      // A source stream whose event boundaries have nothing to do with the
      // chunk size — the ordinary case for a socket or a file read.
      final chunks = [for (var i = 0; i < 40; i++) _bytes(100, i)];
      await store.put(key: 'db/dribble.bin', bytes: _stream(chunks));
      expect(
        await store.getBytes('db/dribble.bin'),
        chunks.expand((c) => c).toList(),
      );
    });

    test(
      'replacing a blob supersedes its chunks and keeps the store readable',
      () async {
        await store.put(key: 'db/replaced.txt', bytes: _text('first version'));
        await store.put(key: 'db/replaced.txt', bytes: _text('second version'));

        // The manifest is a single row keyed by the storage key, so the second
        // write replaced the first rather than shadowing it: the descriptor
        // reports the new length, and there is nothing of the old one left.
        expect(
          utf8.decode(await store.getBytes('db/replaced.txt')),
          'second version',
        );
        expect((await store.describe('db/replaced.txt'))!.byteCount, 14);
        // The superseded upload's chunk rows went with it — nothing to purge.
        expect(await store.purgeOrphanedChunks(), 0);
      },
    );

    test(
      'a failed write leaves the previous blob intact and no orphan rows',
      () async {
        await store.put(key: 'db/kept.txt', bytes: _text('the good copy'));

        await expectLater(
          store.put(
            key: 'db/kept.txt',
            bytes: _failingStream([utf8.encode('partial')]),
          ),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.write_failed',
            ),
          ),
        );

        // The manifest still names the committed upload...
        expect(
          utf8.decode(await store.getBytes('db/kept.txt')),
          'the good copy',
        );
        // ...and the failed write cleaned up after itself.
        expect(await store.purgeOrphanedChunks(), 0);
      },
    );

    // The backend's whole argument for a native copy: a manifest row is what
    // makes a blob visible, so a second row against the *same* upload is a
    // copy in which no chunk is read, written or counted. A gigabyte copies in
    // one statement. What makes it safe rather than clever is the guard on the
    // chunk delete, which these pin from both sides.
    group('copy and move are manifest work, not chunk work', () {
      /// How many chunk rows exist for [uploadId].
      Future<int> chunkRows(String uploadId) async {
        final rows = await dsi.datasource.executeQuery<TomBlobChunkRow>(
          'SELECT chunk_data FROM ${store.chunkTable} '
          'WHERE upload_id = :uploadId',
          {'uploadId': uploadId},
        );
        return rows.length;
      }

      /// The `upload_id` recorded for [key].
      Future<String> uploadOf(String key) async {
        final rows = await dsi.datasource.executeQuery<TomBlobManifestRow>(
          'SELECT ${store.manifestTable}.* FROM ${store.manifestTable} '
          'WHERE storage_key = :key',
          {'key': key},
        );
        return rows.single.uploadId;
      }

      test('a copy shares the upload rather than duplicating chunks', () async {
        // Four chunks at the 1 KiB the suite configures, so "no new chunks"
        // is a claim about several rows rather than about one.
        final payload = _bytes(4096);
        await store.put(key: 'db/a.bin', bytes: _stream([payload]));
        final upload = await uploadOf('db/a.bin');
        expect(await chunkRows(upload), 4);

        final copied = await store.copy('db/a.bin', 'db/b.bin');
        expect(copied.byteCount, 4096);
        expect(await uploadOf('db/b.bin'), upload);
        expect(
          await chunkRows(upload),
          4,
          reason: 'the copy wrote chunk rows it did not need to',
        );
        // Both keys serve the bytes, which is what makes the sharing a copy
        // rather than an alias with one reader.
        expect(await store.getBytes('db/a.bin'), payload);
        expect(await store.getBytes('db/b.bin'), payload);
      });

      test(
        'deleting one side of a shared upload leaves the other readable',
        () async {
          // The hazard the guard exists for, and the reason `doDelete` cannot
          // simply delete by upload id: without it this test reads back nothing
          // and the blob is gone with no error anywhere.
          final payload = _bytes(4096);
          await store.put(key: 'db/a.bin', bytes: _stream([payload]));
          await store.copy('db/a.bin', 'db/b.bin');

          expect(await store.delete('db/a.bin'), isTrue);
          expect(await store.exists('db/a.bin'), isFalse);
          expect(
            await store.getBytes('db/b.bin'),
            payload,
            reason: 'deleting one key took the chunks the other pointed at',
          );
          // And the sweep agrees: the upload is still referenced.
          expect(await store.purgeOrphanedChunks(), 0);
        },
      );

      test('overwriting one side of a shared upload leaves the other', () async {
        // The same hazard through the other door. `doPut` releases the
        // superseded upload's chunks, and the superseded upload here is one the
        // copy still names.
        final payload = _bytes(4096);
        await store.put(key: 'db/a.bin', bytes: _stream([payload]));
        await store.copy('db/a.bin', 'db/b.bin');

        await store.put(key: 'db/a.bin', bytes: _text('something else'));
        expect(utf8.decode(await store.getBytes('db/a.bin')), 'something else');
        expect(await store.getBytes('db/b.bin'), payload);
      });

      test('the last key released takes the chunks with it', () async {
        // The other side of the guard: sharing must not leak. Once no manifest
        // row names the upload, its chunks go on that delete rather than being
        // left for a sweep somebody has to remember to run.
        await store.put(key: 'db/a.bin', bytes: _stream([_bytes(4096)]));
        final upload = await uploadOf('db/a.bin');
        await store.copy('db/a.bin', 'db/b.bin');

        await store.delete('db/a.bin');
        expect(await chunkRows(upload), 4);
        await store.delete('db/b.bin');
        expect(await chunkRows(upload), 0);
        expect(await store.purgeOrphanedChunks(), 0);
      });

      test('a move is one update, keeping the upload and the chunks', () async {
        final payload = _bytes(4096);
        await store.put(
          key: 'db/a.bin',
          bytes: _stream([payload]),
          mediaType: 'image/png',
          fileName: 'picture.png',
        );
        final upload = await uploadOf('db/a.bin');

        final moved = await store.move('db/a.bin', 'db/moved.bin');
        expect(moved.mediaType, 'image/png');
        expect(moved.fileName, 'picture.png');
        expect(await uploadOf('db/moved.bin'), upload);
        expect(await chunkRows(upload), 4);
        expect(await store.exists('db/a.bin'), isFalse);
        expect(await store.getBytes('db/moved.bin'), payload);
      });

      test(
        'a move onto an occupied key replaces it and frees its chunks',
        () async {
          // The key is the primary key, so an UPDATE onto an occupied one is a
          // constraint violation rather than the replacement every other write
          // performs — the destination has to be released first, and releasing it
          // is what stops its chunks becoming orphans.
          await store.put(key: 'db/a.bin', bytes: _stream([_bytes(4096)]));
          await store.put(key: 'db/b.bin', bytes: _stream([_bytes(2048, 7)]));
          final displaced = await uploadOf('db/b.bin');

          await store.move('db/a.bin', 'db/b.bin');
          expect(await store.getBytes('db/b.bin'), _bytes(4096));
          expect(await chunkRows(displaced), 0);
          expect(await store.purgeOrphanedChunks(), 0);
        },
      );

      test('a copy onto an occupied key frees what it displaced', () async {
        await store.put(key: 'db/a.bin', bytes: _stream([_bytes(4096)]));
        await store.put(key: 'db/b.bin', bytes: _stream([_bytes(2048, 7)]));
        final displaced = await uploadOf('db/b.bin');

        await store.copy('db/a.bin', 'db/b.bin');
        expect(await store.getBytes('db/b.bin'), _bytes(4096));
        expect(await chunkRows(displaced), 0);
        expect(await store.purgeOrphanedChunks(), 0);
      });
    });

    test('purgeOrphanedChunks collects rows no manifest refers to', () async {
      await store.put(key: 'db/orphan.txt', bytes: _text('body'));
      // Simulates the one residue the store tolerates: a chunk-delete that did
      // not happen (a replace or delete whose cleanup failed).
      await dsi.datasource.executeCommand(
        'INSERT INTO ${store.chunkTable} '
        '(upload_id, chunk_index, chunk_data) '
        "VALUES ('vanished-upload', 0, 'AAAA')",
      );

      expect(await store.purgeOrphanedChunks(), 1);
      // The live blob is untouched by the sweep.
      expect(utf8.decode(await store.getBytes('db/orphan.txt')), 'body');
    });

    test(
      'deleting removes the blob and reports whether there was one',
      () async {
        await store.put(key: 'db/doomed.txt', bytes: _text('bye'));
        expect(await store.delete('db/doomed.txt'), isTrue);
        expect(await store.exists('db/doomed.txt'), isFalse);
        expect(await store.delete('db/doomed.txt'), isFalse);
        // Both tables, not just the visible one.
        expect(await store.purgeOrphanedChunks(), 0);
      },
    );

    test('reading an absent key is a named not-found', () async {
      await expectLater(
        store.get('db/nothing.txt').toList(),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.blob.not_found',
          ),
        ),
      );
    });

    test('a missing chunk is reported rather than served short', () async {
      // The corruption the upload-id scheme is designed to make impossible;
      // forced here so the detection is proven rather than assumed.
      await store.put(key: 'db/truncated.bin', bytes: _stream([_bytes(3000)]));
      await dsi.datasource.executeCommand(
        'DELETE FROM ${store.chunkTable} WHERE chunk_index = 1',
      );

      await expectLater(
        store.get('db/truncated.bin').toList(),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.blob.missing_chunk',
          ),
        ),
      );
    });

    test(
      '.named resolves a registered data source, and refuses an unknown one',
      () async {
        final named = TomDatabaseBlobStore.named(TestDatabase.datasourceName);
        await named.put(key: 'db/named.txt', bytes: _text('by name'));
        expect(utf8.decode(await named.getBytes('db/named.txt')), 'by name');

        expect(
          () => TomDatabaseBlobStore.named('nosuchdatasource'),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.database.unknown_datasource',
            ),
          ),
        );
      },
    );

    test('a key the grammar rejects never reaches the database', () async {
      await expectLater(
        store.put(key: '../escape', bytes: _text('nope')),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.blob.invalid_key',
          ),
        ),
      );
    });

    /// `createSchema: false` — the configuration a deployment runs in when the
    /// two tables belong to the migration chain rather than to first use, and
    /// its database user is not allowed to run DDL.
    ///
    /// The enclosing `setUp` has already dropped both tables, so every test
    /// here starts from the state that distinguishes this flag from the
    /// default: a store whose schema is *not* there. The three claims are that
    /// the flag is obeyed (no DDL), that the resulting failure is the module's
    /// own error rather than the driver's, and — the one the other two are
    /// worthless without — that the arrangement actually works once the schema
    /// arrives from elsewhere.
    group('with createSchema: false', () {
      late TomDatabaseBlobStore unprovisioned;

      setUp(() {
        unprovisioned = TomDatabaseBlobStore(
          dsi.datasource,
          chunkSize: 1024,
          createSchema: false,
        );
      });

      test('ensureSchema creates nothing', () async {
        // Not merely "no error": the point of the flag is that the DDL is not
        // issued, and only the database can testify to that.
        await unprovisioned.ensureSchema();

        expect(
          await TestDatabase.tableExists(dsi, defaultBlobManifestTable),
          isFalse,
        );
        expect(
          await TestDatabase.tableExists(dsi, defaultBlobChunkTable),
          isFalse,
        );
      });

      test(
        'a put reports a named storage error and still creates nothing',
        () async {
          Object? raised;
          try {
            await unprovisioned.put(
              key: 'db/unprovisioned.txt',
              bytes: _text('no schema here'),
            );
            fail('a put against a missing schema must not succeed');
          } on Object catch (error) {
            raised = error;
          }

          // The module's own vocabulary, not the driver's: a caller branching on
          // storage errors keeps working when the schema is the fault, and the
          // `MySQLServerException` never becomes part of anyone's API.
          expect(
            raised,
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.write_failed',
            ),
          );

          // The generic key is only defensible because the specific cause
          // survives underneath it — this is what an operator reads to learn that
          // the migration has not been applied, so it is asserted rather than
          // assumed.
          expect(
            classifySqlFailure(raised),
            TomSqlFailureMode.definite,
            reason:
                'the server answered 1146, so the write definitely did not '
                'take effect',
          );
          expect(raised.toString(), contains(defaultBlobManifestTable));

          // The failure must not have provisioned on the way out.
          expect(
            await TestDatabase.tableExists(dsi, defaultBlobManifestTable),
            isFalse,
          );
          expect(
            await TestDatabase.tableExists(dsi, defaultBlobChunkTable),
            isFalse,
          );
        },
      );

      test('the reads are named too, and by the operation that asked', () async {
        // `probe` rather than `read`, because the caller asked what was there.
        await expectLater(
          unprovisioned.describe('db/unprovisioned.txt'),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.probe_failed',
            ),
          ),
        );

        await expectLater(
          unprovisioned.get('db/unprovisioned.txt').toList(),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.read_failed',
            ),
          ),
        );
      });

      test(
        'round-trips a blob once the schema arrives from elsewhere',
        () async {
          // The production arrangement, and the control the two negative tests
          // above need: a store that simply never worked would satisfy them
          // both. The tables are created from the module's own exported DDL —
          // what the shipped `[1]`/`[2]` reference migrations apply — so the
          // store is running against the schema a migration chain would have
          // left it, not against one this test invented.
          await TestDatabase.createBlobTables(dsi);

          final stored = await unprovisioned.put(
            key: 'db/migrated.bin',
            bytes: _stream([_bytes(3000)]),
            mediaType: 'application/octet-stream',
          );

          expect(stored.byteCount, 3000);
          // A multi-chunk payload, so the chunk table is exercised too and not
          // merely the manifest.
          expect(await unprovisioned.getBytes('db/migrated.bin'), _bytes(3000));
          expect(await unprovisioned.delete('db/migrated.bin'), isTrue);
        },
      );
    });
  }, skip: skipReason);

  group('a database store built from configuration', () {
    // The registry's database backend had no test at all: it is the only
    // caller that cannot be reached without a registered data source, so the
    // suite that covers the other two backends stops at its door. That gap is
    // how it came to restate all three of the store's defaults as literals —
    // nothing ever asked it what a store with no settings comes out as.
    late TomDataSourceInfo dsi;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
    });

    setUp(() async => TestDatabase.dropBlobTables(dsi));
    tearDown(TomBlobStoreInfo.closeAll);
    tearDownAll(TestDatabase.reset);

    Future<TomDatabaseBlobStore> configured(Map<String, dynamic> what) async {
      await TomBlobStoreInfo.initializeBlobStores({
        'files': {'type': 'database', ...what},
      });
      return TomBlobStoreInfo.storeNamed('files') as TomDatabaseBlobStore;
    }

    test('takes its defaults from the declarations, not from copies', () async {
      // Asserted against the constants rather than against their values: this
      // has to keep holding after a rename, which is the only circumstance in
      // which the defect was ever visible.
      final store = await configured({
        'datasource': TestDatabase.datasourceName,
      });

      expect(store.manifestTable, defaultBlobManifestTable);
      expect(store.chunkTable, defaultBlobChunkTable);
      expect(store.chunkSize, TomDatabaseBlobStore.defaultChunkSize);
      expect(store.createSchema, isTrue);
    });

    test('settings still override each of them', () async {
      // The other half: the defaults must not have become unconditional. Table
      // names are deployment choices — two stores sharing one schema is the
      // reason the parameters exist.
      final store = await configured({
        'datasource': TestDatabase.datasourceName,
        'manifestTable': 'custom_blob',
        'chunkTable': 'custom_blob_chunk',
        'chunkSize': 4096,
        'createSchema': false,
      });

      expect(store.manifestTable, 'custom_blob');
      expect(store.chunkTable, 'custom_blob_chunk');
      expect(store.chunkSize, 4096);
      expect(store.createSchema, isFalse);
    });

    test('the configured store is usable, not merely constructed', () async {
      // Guards the assertions above against being satisfied by a store that
      // resolves its names correctly and works with none of them: the tables
      // the defaults name are the tables it actually provisions and reads.
      final store = await configured({
        'datasource': TestDatabase.datasourceName,
      });
      await store.put(key: 'cfg/round-trip.txt', bytes: _text('configured'));

      expect(
        utf8.decode(await store.getBytes('cfg/round-trip.txt')),
        'configured',
      );
      // Named explicitly rather than through `store.chunkTable`, so the
      // assertion is that the *declared* default is where the row landed and
      // not merely that the store agrees with itself.
      final deleted = await dsi.datasource.executeCommand(
        'DELETE FROM $defaultBlobManifestTable WHERE storage_key = :key',
        {'key': 'cfg/round-trip.txt'},
      );
      expect(deleted, BigInt.one);
    });

    test(
      'a chunk size of zero is refused at start-up, not on first put',
      () async {
        // The route the constructor check exists for. `file_storage_test.dart`
        // proves the constructor refuses it; this proves nothing between YAML and
        // the constructor swallows the value first — the registry reads the
        // setting, `.named` resolves the data source, and the refusal still
        // arrives out of `initializeBlobStores`.
        //
        // Which is where a deployment can act on it. Left to the store, the same
        // setting produces an upload that never returns: `doPut` slices with a
        // clamp that is 0 for every iteration, so the loop cannot advance and
        // there is no exception to log.
        await expectLater(
          configured({
            'datasource': TestDatabase.datasourceName,
            'chunkSize': 0,
          }),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.database.chunk_size_not_positive',
            ),
          ),
        );
      },
    );
  }, skip: skipReason);

  group('file-reference columns end to end', () {
    late TomDataSourceInfo dsi;
    late FixtureDocumentRepository repo;
    late TomMemoryBlobStore blobs;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.ensureFixtureDocumentTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateFixtureDocument(dsi);
      repo = FixtureDocumentRepository();
      blobs = TomMemoryBlobStore();
      TomBlobStoreInfo.register('fixture', blobs, asDefault: true);
    });

    tearDown(() async {
      TomAuthorization.reset();
      await TomBlobStoreInfo.closeAll();
    });

    tearDownAll(TestDatabase.reset);

    test(
      'saveFile uploads the bytes and stores only the key in the row',
      () async {
        final saved = await repo.saveFile(
          _document('quarterly'),
          'attachment',
          _text('report body'),
          mediaType: 'text/plain',
          fileName: 'report.txt',
        );

        // The column holds a key of the annotation's shape, not the content.
        expect(saved.attachment, startsWith('fixture/attachment/'));
        expect(blobs.keys, [saved.attachment]);
        expect(blobs.textOf(saved.attachment!), 'report body');

        // And what came back from the database in that column is the same short
        // string — the row carries the reference, the store carries the bytes.
        final reloaded = await repo.findById(saved.id!);
        expect(reloaded!.attachment, saved.attachment);
        expect(reloaded.title, 'quarterly');
      },
    );

    test('openFile streams the bytes back through the row', () async {
      final saved = await repo.saveFile(
        _document('readable'),
        'attachment',
        _stream([_bytes(500), _bytes(500, 9)]),
      );

      final received = <int>[];
      await for (final chunk in repo.openFile(saved.id!, 'attachment')) {
        received.addAll(chunk);
      }
      expect(received, [..._bytes(500), ..._bytes(500, 9)]);
    });

    test('describeFile reports the metadata a download needs', () async {
      final saved = await repo.saveFile(
        _document('described'),
        'attachment',
        _text('12345'),
        mediaType: 'text/csv',
        fileName: 'numbers.csv',
      );

      final described = await repo.describeFile(saved.id!, 'attachment');
      expect(described, isNotNull);
      expect(described!.byteCount, 5);
      expect(described.mediaType, 'text/csv');
      expect(described.fileName, 'numbers.csv');
    });

    test(
      'describeFile is null for a row with no file, and for no row',
      () async {
        final saved = await repo.save(_document('empty'));
        expect(await repo.describeFile(saved.id!, 'attachment'), isNull);
        expect(await repo.describeFile(999999, 'attachment'), isNull);
      },
    );

    test('the column name works as well as the declared name', () async {
      // The router hands over whatever the API surface called the field; both
      // spellings resolve to the same column.
      final saved = await repo.saveFile(
        _document('by column name'),
        'secret_attachment',
        _text('via column name'),
      );
      expect(saved.secretAttachment, startsWith('fixture/secret/'));
      expect(
        utf8.decode(
          await repo
              .openFile(saved.id!, 'secretAttachment')
              .expand((c) => c)
              .toList(),
        ),
        'via column name',
      );
    });

    test('a field that is not a file column is a named refusal', () async {
      // On the stream rather than at the call: `openFile` is an `async*`
      // generator, so every one of its refusals reaches the caller the same
      // way, and a consumer needs only one error path.
      await expectLater(
        repo.openFile(1, 'title').toList(),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.file_reference.unknown_column',
          ),
        ),
      );
      await expectLater(
        repo.saveFile(_document('x'), 'title', _text('body')),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.file_reference.unknown_column',
          ),
        ),
      );
    });

    test(
      'a row with no file attached is different from an absent one',
      () async {
        final saved = await repo.save(_document('bare'));
        await expectLater(
          repo.openFile(saved.id!, 'attachment').toList(),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.file_reference.no_file',
            ),
          ),
        );
        await expectLater(
          repo.openFile(999999, 'attachment').toList(),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.file_reference.row_not_found',
            ),
          ),
        );
      },
    );

    test('replacing a file deletes the one it superseded', () async {
      final first = await repo.saveFile(
        _document('versioned'),
        'attachment',
        _text('version one'),
      );
      final firstKey = first.attachment!;

      final second = await repo.saveFile(
        first,
        'attachment',
        _text('version two'),
      );

      expect(second.attachment, isNot(firstKey));
      expect(blobs.keys, [second.attachment]);
      expect(blobs.textOf(second.attachment!), 'version two');
    });

    test('clearFile removes both the key and the bytes', () async {
      final saved = await repo.saveFile(
        _document('temporary'),
        'attachment',
        _text('delete me'),
      );

      final cleared = await repo.clearFile(saved, 'attachment');
      expect(cleared.attachment, isNull);
      expect(blobs.keys, isEmpty);
    });

    test('a save that touches no file column leaves the file alone', () async {
      final saved = await repo.saveFile(
        _document('untouched'),
        'attachment',
        _text('still here'),
      );

      saved.title = 'renamed';
      final updated = await repo.save(saved);

      expect(updated.title, 'renamed');
      expect(updated.attachment, saved.attachment);
      expect(blobs.textOf(saved.attachment!), 'still here');
    });

    test('deleting the entity cascades to its file', () async {
      final saved = await repo.saveFile(
        _document('doomed'),
        'attachment',
        _text('goes with the row'),
      );

      await repo.delete(saved);

      expect(await repo.findById(saved.id!), isNull);
      expect(blobs.keys, isEmpty);
    });

    test('a non-cascading column keeps its bytes when the row goes', () async {
      // `cascadeDelete: false` is the opt-out for a column whose blob is shared
      // or owned elsewhere; a row delete must then leave it alone.
      var saved = await repo.saveFile(
        _document('mixed'),
        'attachment',
        _text('cascades'),
      );
      saved = await repo.saveFile(saved, 'secretAttachment', _text('survives'));
      final cascading = saved.attachment!;
      final retained = saved.secretAttachment!;

      await repo.delete(saved);

      expect(blobs.keys, [retained]);
      expect(blobs.textOf(retained), 'survives');
      expect(await blobs.exists(cascading), isFalse);
    });

    test('deleteById cascades', () async {
      final saved = await repo.saveFile(
        _document('by id'),
        'attachment',
        _text('bytes'),
      );
      await repo.deleteById(saved.id!);
      expect(blobs.keys, isEmpty);
    });

    test('deleteAllById cascades for every named row', () async {
      final a = await repo.saveFile(_document('a'), 'attachment', _text('a'));
      final b = await repo.saveFile(_document('b'), 'attachment', _text('b'));
      final kept = await repo.saveFile(
        _document('c'),
        'attachment',
        _text('c'),
      );

      await repo.deleteAllById([a.id!, b.id!]);

      expect(blobs.keys, [kept.attachment]);
    });

    test(
      'a query-based delete cascades for exactly the rows it removed',
      () async {
        final doomed = await repo.saveFile(
          _document('purge'),
          'attachment',
          _text('gone'),
        );
        final kept = await repo.saveFile(
          _document('keep'),
          'attachment',
          _text('stays'),
        );

        await repo.deleteByQuerySentence('DELETE BY title = :title', {
          'title': 'purge',
        });

        expect(await repo.findById(doomed.id!), isNull);
        expect(await repo.findById(kept.id!), isNotNull);
        expect(blobs.keys, [kept.attachment]);
      },
    );

    group('under a C-4 grade', () {
      const authKey = 'fixture.document.secret_attachment';

      test(
        'a masked column refuses a download by name, not by absence',
        () async {
          final saved = await repo.saveFile(
            _document('graded'),
            'secretAttachment',
            _text('classified'),
          );

          TomAuthorization.adapter = _GradeAdapter({
            authKey: TomAuthState.none,
          });

          // Not `no_file`: the file is there, the caller may not have it. The
          // masked key reads back as null, so without this check the refusal
          // would be indistinguishable from an empty column.
          await expectLater(
            repo.openFile(saved.id!, 'secretAttachment').toList(),
            throwsA(
              isA<TomColumnAuthorizationException>().having(
                (e) => e.key,
                'key',
                'column_authorization.read.field_forbidden',
              ),
            ),
          );
          await expectLater(
            repo.describeFile(saved.id!, 'secretAttachment'),
            throwsA(
              isA<TomColumnAuthorizationException>().having(
                (e) => e.key,
                'key',
                'column_authorization.read.field_forbidden',
              ),
            ),
          );
        },
      );

      test(
        'a read-only column refuses an upload before any bytes move',
        () async {
          TomAuthorization.adapter = _GradeAdapter({
            authKey: TomAuthState.read,
          });

          await expectLater(
            repo.saveFile(
              _document('graded'),
              'secretAttachment',
              _text('classified'),
            ),
            throwsA(
              isA<TomColumnAuthorizationException>().having(
                (e) => e.key,
                'key',
                'column_authorization.write.field_forbidden',
              ),
            ),
          );
          // The refusal arrived before the transfer, so nothing was stored.
          expect(blobs.keys, isEmpty);
        },
      );

      test('a masked round trip does not orphan the live blob', () async {
        // The failure this defends against: a masked column reads back as
        // `null`, so a naive "the key changed to null, delete the old blob"
        // would destroy a file the caller was not even allowed to see.
        var saved = await repo.saveFile(
          _document('graded'),
          'secretAttachment',
          _text('classified'),
        );
        saved = await repo.saveFile(saved, 'attachment', _text('ordinary'));
        final secretKey = saved.secretAttachment!;

        TomAuthorization.adapter = _GradeAdapter({authKey: TomAuthState.none});

        final masked = await repo.findById(saved.id!);
        expect(masked!.secretAttachment, isNull, reason: 'C-4 masks the key');
        masked.title = 'edited while masked';
        await repo.save(masked);

        TomAuthorization.reset();

        final reloaded = await repo.findById(saved.id!);
        expect(reloaded!.title, 'edited while masked');
        expect(reloaded.secretAttachment, secretKey);
        expect(blobs.textOf(secretKey), 'classified');
      });

      test(
        'a per-row resolver grades the same column differently on two rows',
        () async {
          // The column-wide adapter above can say "nobody may write secret
          // attachments". It cannot say "you may write the one on the row you
          // own and only read the one on the row shared with you" — that grade
          // is a property of the (principal, row) pair, and it is what a
          // relational deployment actually has. `TomRowColumnAuthorization` is
          // the seam for it; the file operations are the only paths that consult
          // it, because they are the only ones that address a single row and can
          // afford to await.
          final writable = await repo.saveFile(
            _document('row-writable'),
            'secretAttachment',
            _text('mine'),
          );
          final readOnly = await repo.saveFile(
            _document('row-readonly'),
            'secretAttachment',
            _text('theirs'),
          );

          TomRowColumnAuthorization.register(
            authKey,
            (principal, rowId) async =>
                rowId == writable.id ? TomAuthState.full : TomAuthState.read,
          );
          addTearDown(TomRowColumnAuthorization.reset);

          // The read-only row downloads — `read` shows content …
          expect(
            utf8.decode(
              await repo
                  .openFile(readOnly.id!, 'secretAttachment')
                  .expand((c) => c)
                  .toList(),
            ),
            'theirs',
          );
          // … and refuses the upload, because `read` is not interactive.
          await expectLater(
            repo.saveFile(readOnly, 'secretAttachment', _text('overwrite')),
            throwsA(
              isA<TomColumnAuthorizationException>().having(
                (e) => e.key,
                'key',
                'column_authorization.write.field_forbidden',
              ),
            ),
          );
          // … and refuses the *clear*, which is the write that would otherwise
          // slip through: `clearFile` delegates to `save`, and `save` grades the
          // column column-wide — which is not the answer for a per-row column. A
          // principal allowed only to download the file must not be able to
          // destroy it.
          await expectLater(
            repo.clearFile(readOnly, 'secretAttachment'),
            throwsA(
              isA<TomColumnAuthorizationException>().having(
                (e) => e.key,
                'key',
                'column_authorization.write.field_forbidden',
              ),
            ),
          );
          expect(
            blobs.textOf(readOnly.secretAttachment!),
            'theirs',
            reason: 'the refused clear left the stored blob untouched',
          );

          // The writable row, same column, same principal: the upload lands.
          final replaced = await repo.saveFile(
            writable,
            'secretAttachment',
            _text('replaced'),
          );
          expect(blobs.textOf(replaced.secretAttachment!), 'replaced');
        },
      );

      test('a per-row resolver overrides the column-wide adapter, and the row '
          'projection stops masking the column', () async {
        // Precedence matters and must not be accidental: a registered per-row
        // resolver is the answer, not a fallback consulted when the global
        // adapter is silent. The read mask has to step aside with it — a
        // projection grades a whole result set with one synchronous answer, so
        // it cannot decide a per-row grade, and the value it would null out is
        // the very blob key the row-level gate then needs to read.
        final saved = await repo.saveFile(
          _document('precedence'),
          'secretAttachment',
          _text('classified'),
        );
        TomAuthorization.adapter = _GradeAdapter({authKey: TomAuthState.none});
        TomRowColumnAuthorization.register(
          authKey,
          (principal, rowId) async => TomAuthState.read,
        );
        addTearDown(TomRowColumnAuthorization.reset);

        final reloaded = await repo.findById(saved.id!);
        expect(
          reloaded!.secretAttachment,
          saved.secretAttachment,
          reason: 'the column-wide `none` no longer masks a per-row column',
        );
        expect(
          utf8.decode(
            await repo
                .openFile(saved.id!, 'secretAttachment')
                .expand((c) => c)
                .toList(),
          ),
          'classified',
        );
      });

      test(
        'an unrestricted column is unaffected by a grade on its sibling',
        () async {
          var saved = await repo.saveFile(
            _document('graded'),
            'secretAttachment',
            _text('classified'),
          );
          saved = await repo.saveFile(saved, 'attachment', _text('ordinary'));

          TomAuthorization.adapter = _GradeAdapter({
            authKey: TomAuthState.none,
          });

          expect(
            utf8.decode(
              await repo
                  .openFile(saved.id!, 'attachment')
                  .expand((c) => c)
                  .toList(),
            ),
            'ordinary',
          );
        },
      );
    });
  }, skip: skipReason);

  /// Blob access under a **row scope** (C-3) — the other half of the
  /// requirement that file access honour the same gates as the owning entity.
  ///
  /// The C-4 group above answers *may this principal see this column*; a breach
  /// there leaks one field. These answer *may this principal see this row at
  /// all*; a breach leaks another principal's document whole. A file slot is
  /// addressed as `<table>/<id>/<column>` with the **id supplied by the
  /// caller**, so the row scope is the only thing between a guessed id and
  /// someone else's file.
  ///
  /// Reads and writes report a violation differently, and that asymmetry is the
  /// design, not an accident:
  ///
  ///  * a **read** ANDs the scope predicate into the `WHERE`, so an out-of-scope
  ///    row is simply *not found* — `openFile` raises `row_not_found` and
  ///    `describeFile` returns `null`, exactly as for an id that never existed.
  ///    Reporting "forbidden" would confirm the row exists, which is itself the
  ///    disclosure the scope is there to prevent;
  ///  * a **write** names a specific row, so silence would be a lie about what
  ///    happened. `saveFile` raises [TomDataScopeAuthorizationException].
  ///
  /// So the read tests assert *indistinguishability from an absent row*, which
  /// is a stronger claim than "it refuses", and the write test asserts the
  /// explicit refusal.
  // Moving a deployment's files from one backend to another has the hardest
  // precondition in the module: it means enumerating what to move, and the blob
  // contract deliberately cannot. The rows can — a `@TomFileReference` column
  // *is* the index of what a deployment stored — so the sweep reads the table
  // and uses only `get` / `describe` / `put`.
  group('migrating blobs between backends, driven by the rows', () {
    late TomDataSourceInfo dsi;
    late FixtureDocumentRepository repo;
    late TomMemoryBlobStore oldStore;
    late TomMemoryBlobStore newStore;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.ensureFixtureDocumentTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateFixtureDocument(dsi);
      repo = FixtureDocumentRepository();
      oldStore = TomMemoryBlobStore();
      newStore = TomMemoryBlobStore();
      TomBlobStoreInfo.register('fixture', oldStore, asDefault: true);
    });

    tearDown(() async {
      TomAuthorization.reset();
      await TomBlobStoreInfo.closeAll();
    });

    tearDownAll(TestDatabase.reset);

    /// Stores [count] documents, each with an attachment, and answers the keys.
    Future<List<String>> seed(int count) async {
      final keys = <String>[];
      for (var i = 0; i < count; i++) {
        final saved = await repo.saveFile(
          _document('doc $i'),
          'attachment',
          _text('body of $i'),
          mediaType: 'text/plain',
          fileName: 'doc$i.txt',
        );
        keys.add(saved.attachment!);
      }
      return keys;
    }

    TomBlobMigration migration({
      bool deleteFromSource = false,
      int pageSize = 200,
    }) => TomBlobMigration(
      source: oldStore,
      target: newStore,
      pageSize: pageSize,
      deleteFromSource: deleteFromSource,
    );

    test('every blob a row names arrives, with its media type and name', () async {
      final keys = await seed(3);

      final report = await migration().migrate(repo);
      expect(report.rows, 3);
      expect(report.copied, 3);
      expect(report.alreadyPresent, 0);
      expect(report.complete, isTrue);
      // Sorted copies: the keys carry a UUID, so the sweep's order is the
      // table's and not the seeding order, and mutating either list here would
      // make the per-key assertions below read the wrong document.
      expect([...report.claimed]..sort(), [...keys]..sort());

      for (var i = 0; i < keys.length; i++) {
        final described = await newStore.describe(keys[i]);
        expect(described, isNotNull, reason: keys[i]);
        // The descriptor travels, not just the bytes: a migrated blob served as
        // application/octet-stream downloads as a file nothing opens.
        expect(described!.mediaType, 'text/plain');
        expect(described.fileName, endsWith('.txt'));
      }
      expect(utf8.decode(await newStore.getBytes(keys.first)), 'body of 0');
    });

    test('the rows are not written, only read', () async {
      // The premise worth correcting: a backend migration changes no key. The
      // column holds the key; which *store* it is read from is configuration.
      // Saving each row back would be a no-op that ran the authorization gates,
      // stamped the audit trail and moved every `updated` timestamp — so this
      // is a read-only sweep and can run against a live system.
      final keys = await seed(2);
      final before = await repo.findAll();

      await migration().migrate(repo);

      final after = await repo.findAll();
      expect(
        after.map((row) => row.attachment).toList(),
        before.map((row) => row.attachment).toList(),
      );
      expect(
        keys.every((key) => after.any((r) => r.attachment == key)),
        isTrue,
      );
    });

    test('a second run copies nothing and confirms the first', () async {
      // What makes an interrupted migration resumable: run it again. The
      // "already present" check is a digest comparison, so it is a fact rather
      // than a guess about a key that happens to exist.
      await seed(3);
      await migration().migrate(repo);

      final again = await migration().migrate(repo);
      expect(again.copied, 0);
      expect(again.alreadyPresent, 3);
      expect(again.bytes, 0);
      expect(again.complete, isTrue);
    });

    test(
      'a target holding different bytes under the same key is overwritten',
      () async {
        // The other side of the digest check. A key that exists in the target but
        // holds something else is not a completed copy, and treating it as one
        // would leave the deployment serving the wrong file for ever.
        final keys = await seed(1);
        await newStore.putBytes(key: keys.single, bytes: utf8.encode('stale'));

        final report = await migration().migrate(repo);
        expect(report.copied, 1);
        expect(utf8.decode(await newStore.getBytes(keys.single)), 'body of 0');
      },
    );

    test('a dangling reference is reported, not thrown', () async {
      // One row pointing at a blob that is gone must not stop a migration of
      // ten thousand. It is a fault in the data that predates the migration, so
      // an operator wants the whole list rather than the first one.
      final keys = await seed(3);
      await oldStore.delete(keys[1]);

      final report = await migration().migrate(repo);
      expect(report.copied, 2);
      expect(report.absent, [keys[1]]);
      expect(report.complete, isFalse);
      expect(report.claimed, isNot(contains(keys[1])));
    });

    test(
      'deleteFromSource empties the old store only after verifying',
      () async {
        final keys = await seed(2);

        final report = await migration(deleteFromSource: true).migrate(repo);
        expect(report.copied, 2);
        for (final key in keys) {
          expect(await oldStore.exists(key), isFalse, reason: key);
          expect(await newStore.exists(key), isTrue, reason: key);
        }
      },
    );

    test('paging reaches every row', () async {
      // The sweep is run against the table that grew large enough to need one,
      // so reading it whole is the shape that fails in production and nowhere
      // else. A page size below the row count is the only way to see it.
      await seed(7);
      final report = await migration(pageSize: 2).migrate(repo);
      expect(report.rows, 7);
      expect(report.copied, 7);
    });

    test('a column the entity does not have is refused by name', () async {
      await seed(1);
      await expectLater(
        migration().migrate(repo, fields: const {'attachment', 'nope'}),
        throwsA(
          isA<TomBlobMigrationException>()
              .having((e) => e.key, 'key', 'storage.migration.unknown_field')
              .having((e) => e.parameters?['fields'], 'fields', 'nope'),
        ),
      );
    });

    test('fields narrows the sweep to the named column', () async {
      final keys = await seed(2);
      final report = await migration().migrate(
        repo,
        fields: const {'secretAttachment'},
      );
      // Nothing is stored in that column, so the sweep reads two rows and
      // claims nothing — which is the difference between "no files" and "not
      // looked at" being visible in the report.
      expect(report.rows, 2);
      expect(report.copied, 0);
      expect(report.claimed, isEmpty);
      for (final key in keys) {
        expect(await newStore.exists(key), isFalse);
      }
    });
  });

  group('blob access under a row scope', () {
    late TomDataSourceInfo dsi;
    late FixtureScopedDocumentRepository repo;
    late TomMemoryBlobStore blobs;

    /// The id of a row owned by principal 1, holding an attachment.
    late int ownedId;

    /// The key of that row's blob, so a test can prove the bytes never moved.
    late String ownedKey;

    /// An id no row has ever had — the control every "not found" is compared
    /// against.
    const absentId = 987654;

    setUpAll(() async {
      initializeReflection();
      dsi = await TestDatabase.register();
      await TestDatabase.ensureFixtureScopedDocumentTable(dsi);
    });

    setUp(() async {
      await TestDatabase.truncateFixtureScopedDocument(dsi);
      repo = FixtureScopedDocumentRepository();
      blobs = TomMemoryBlobStore();
      TomBlobStoreInfo.register('fixture', blobs, asDefault: true);

      final seeded = await _as(1, () async {
        return repo.saveFile(
          _scopedDocument('owned by one', 1),
          'attachment',
          _text('private to one'),
          mediaType: 'text/plain',
          fileName: 'private.txt',
        );
      });
      ownedId = seeded.id!;
      ownedKey = seeded.attachment!;
    });

    tearDown(() async {
      await TomBlobStoreInfo.closeAll();
    });

    tearDownAll(TestDatabase.reset);

    test('the owner reads their own file through all three paths', () async {
      // The positive control. Without it every assertion below would also pass
      // against a repository that refused everyone.
      await _as(1, () async {
        expect(
          utf8.decode(
            await repo
                .openFile(ownedId, 'attachment')
                .expand((c) => c)
                .toList(),
          ),
          'private to one',
        );
        final described = await repo.describeFile(ownedId, 'attachment');
        expect(described, isNotNull);
        expect(described!.fileName, 'private.txt');

        final row = await repo.findById(ownedId);
        final replaced = await repo.saveFile(
          row!,
          'attachment',
          _text('replaced by one'),
        );
        expect(blobs.textOf(replaced.attachment!), 'replaced by one');
      });
    });

    test('openFile refuses an out-of-scope row as not found', () async {
      await _as(2, () async {
        await expectLater(
          repo.openFile(ownedId, 'attachment').toList(),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.file_reference.row_not_found',
            ),
          ),
          reason:
              'principal 2 must not reach a row owned by principal 1, and '
              'the refusal must not be a column-authorization error — that '
              'would say the row is there and only the field is withheld',
        );
      });
      // The bytes are untouched and still readable by their owner: the scope
      // denied the *reader*, it did not disturb the file.
      expect(blobs.textOf(ownedKey), 'private to one');
    });

    test('describeFile returns null for an out-of-scope row', () async {
      await _as(2, () async {
        expect(await repo.describeFile(ownedId, 'attachment'), isNull);
      });
    });

    test(
      'an out-of-scope row is indistinguishable from an absent one',
      () async {
        // The property that actually protects the row, and the reason the two
        // read paths above do not raise an authorization error: if a caller can
        // tell "yours but hidden" from "no such row", they can enumerate other
        // principals' ids by probing. Both answers must be byte-identical.
        await _as(2, () async {
          expect(await repo.describeFile(ownedId, 'attachment'), isNull);
          expect(await repo.describeFile(absentId, 'attachment'), isNull);

          final outOfScope = await repo
              .openFile(ownedId, 'attachment')
              .toList()
              .then<TomStorageException?>((_) => null)
              .onError<TomStorageException>((e, _) => e);
          final absent = await repo
              .openFile(absentId, 'attachment')
              .toList()
              .then<TomStorageException?>((_) => null)
              .onError<TomStorageException>((e, _) => e);

          expect(outOfScope, isNotNull);
          expect(absent, isNotNull);
          expect(outOfScope!.key, absent!.key);
          expect(outOfScope.defaultUserMessage, absent.defaultUserMessage);
        });
      },
    );

    test('an unauthenticated caller reaches no scoped file at all', () async {
      // No principal in the zone: the built-in `owner` resolver yields no
      // allowed values, which renders a FALSE predicate rather than an absent
      // one. The secure default has to be asserted, because "no scope values"
      // and "no scoping" are one keystroke apart in the resolver.
      await expectLater(
        repo.openFile(ownedId, 'attachment').toList(),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.file_reference.row_not_found',
          ),
        ),
      );
      expect(await repo.describeFile(ownedId, 'attachment'), isNull);
    });

    test(
      'saveFile refuses to write an out-of-scope row, and moves no bytes',
      () async {
        // The breach in the other direction: overwriting a file on a row you
        // cannot read. Principal 2 cannot *load* the row, so it forges the
        // reference — which is precisely what an attacker holding a guessed id
        // would do.
        final forged = _scopedDocument('hijacked', 2)..id = ownedId;

        await _as(2, () async {
          await expectLater(
            repo.saveFile(forged, 'attachment', _text('overwritten by two')),
            throwsA(
              isA<TomDataScopeAuthorizationException>().having(
                (e) => e.key,
                'key',
                'data_scope.write.out_of_scope',
              ),
            ),
            reason:
                'a write names one specific row, so unlike a read it cannot '
                'be answered by filtering it away — it has to be refused',
          );
        });

        // Refused before the transfer: the store still holds exactly the one
        // blob the owner put there, with its original content.
        expect(blobs.keys, [ownedKey]);
        expect(blobs.textOf(ownedKey), 'private to one');
      },
    );

    test(
      'saveFile refuses to create a row scoped to another principal',
      () async {
        await _as(2, () async {
          await expectLater(
            repo.saveFile(
              _scopedDocument('planted', 1),
              'attachment',
              _text('planted by two'),
            ),
            throwsA(
              isA<TomDataScopeAuthorizationException>().having(
                (e) => e.key,
                'key',
                'data_scope.write.insert_out_of_scope',
              ),
            ),
            reason:
                'without the insert gate a principal could seed a row it '
                'cannot itself read, and reach its file only through the owner',
          );
        });
        expect(blobs.keys, [ownedKey]);
      },
    );
  }, skip: skipReason);
}

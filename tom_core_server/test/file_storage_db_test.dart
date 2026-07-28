/// DB-backed tests for the two halves of CSFS1 that need a real database.
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
Stream<List<int>> _stream(List<List<int>> chunks) => Stream.fromIterable(chunks);

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
Uint8List _bytes(int count, [int seed = 0]) =>
    Uint8List.fromList([for (var i = 0; i < count; i++) (i * 31 + seed) & 0xff]);

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

    test('creates its schema on first use and round-trips a small blob',
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
      expect(utf8.decode(await store.getBytes('db/small.txt')),
          'hello database');
    });

    test('describes and probes a stored blob without reading its bytes',
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
    });

    test('splits a payload across chunk rows and streams them back in order',
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
    });

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

    test('replacing a blob supersedes its chunks and keeps the store readable',
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
    });

    test('a failed write leaves the previous blob intact and no orphan rows',
        () async {
      await store.put(key: 'db/kept.txt', bytes: _text('the good copy'));

      await expectLater(
        store.put(
          key: 'db/kept.txt',
          bytes: _failingStream([utf8.encode('partial')]),
        ),
        throwsA(isA<TomStorageException>()
            .having((e) => e.key, 'key', 'storage.blob.write_failed')),
      );

      // The manifest still names the committed upload...
      expect(utf8.decode(await store.getBytes('db/kept.txt')), 'the good copy');
      // ...and the failed write cleaned up after itself.
      expect(await store.purgeOrphanedChunks(), 0);
    });

    test('purgeOrphanedChunks collects rows no manifest refers to', () async {
      await store.put(key: 'db/orphan.txt', bytes: _text('body'));
      // Simulates the one residue the store tolerates: a chunk-delete that did
      // not happen (a replace or delete whose cleanup failed).
      await dsi.datasource.executeCommand(
        'INSERT INTO tom_blob_chunk (upload_id, chunk_index, chunk_data) '
        "VALUES ('vanished-upload', 0, 'AAAA')",
      );

      expect(await store.purgeOrphanedChunks(), 1);
      // The live blob is untouched by the sweep.
      expect(utf8.decode(await store.getBytes('db/orphan.txt')), 'body');
    });

    test('deleting removes the blob and reports whether there was one',
        () async {
      await store.put(key: 'db/doomed.txt', bytes: _text('bye'));
      expect(await store.delete('db/doomed.txt'), isTrue);
      expect(await store.exists('db/doomed.txt'), isFalse);
      expect(await store.delete('db/doomed.txt'), isFalse);
      // Both tables, not just the visible one.
      expect(await store.purgeOrphanedChunks(), 0);
    });

    test('reading an absent key is a named not-found', () async {
      await expectLater(
        store.get('db/nothing.txt').toList(),
        throwsA(isA<TomStorageException>()
            .having((e) => e.key, 'key', 'storage.blob.not_found')),
      );
    });

    test('a missing chunk is reported rather than served short', () async {
      // The corruption the upload-id scheme is designed to make impossible;
      // forced here so the detection is proven rather than assumed.
      await store.put(key: 'db/truncated.bin', bytes: _stream([_bytes(3000)]));
      await dsi.datasource.executeCommand(
        'DELETE FROM tom_blob_chunk WHERE chunk_index = 1',
      );

      await expectLater(
        store.get('db/truncated.bin').toList(),
        throwsA(isA<TomStorageException>()
            .having((e) => e.key, 'key', 'storage.blob.missing_chunk')),
      );
    });

    test('.named resolves a registered data source, and refuses an unknown one',
        () async {
      final named = TomDatabaseBlobStore.named(TestDatabase.datasourceName);
      await named.put(key: 'db/named.txt', bytes: _text('by name'));
      expect(utf8.decode(await named.getBytes('db/named.txt')), 'by name');

      expect(
        () => TomDatabaseBlobStore.named('nosuchdatasource'),
        throwsA(isA<TomStorageException>().having(
          (e) => e.key,
          'key',
          'storage.database.unknown_datasource',
        )),
      );
    });

    test('a key the grammar rejects never reaches the database', () async {
      await expectLater(
        store.put(key: '../escape', bytes: _text('nope')),
        throwsA(isA<TomStorageException>()
            .having((e) => e.key, 'key', 'storage.blob.invalid_key')),
      );
    });
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

    test('saveFile uploads the bytes and stores only the key in the row',
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
    });

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

    test('describeFile is null for a row with no file, and for no row',
        () async {
      final saved = await repo.save(_document('empty'));
      expect(await repo.describeFile(saved.id!, 'attachment'), isNull);
      expect(await repo.describeFile(999999, 'attachment'), isNull);
    });

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
        throwsA(isA<TomStorageException>().having(
          (e) => e.key,
          'key',
          'storage.file_reference.unknown_column',
        )),
      );
      await expectLater(
        repo.saveFile(_document('x'), 'title', _text('body')),
        throwsA(isA<TomStorageException>().having(
          (e) => e.key,
          'key',
          'storage.file_reference.unknown_column',
        )),
      );
    });

    test('a row with no file attached is different from an absent one',
        () async {
      final saved = await repo.save(_document('bare'));
      await expectLater(
        repo.openFile(saved.id!, 'attachment').toList(),
        throwsA(isA<TomStorageException>()
            .having((e) => e.key, 'key', 'storage.file_reference.no_file')),
      );
      await expectLater(
        repo.openFile(999999, 'attachment').toList(),
        throwsA(isA<TomStorageException>().having(
          (e) => e.key,
          'key',
          'storage.file_reference.row_not_found',
        )),
      );
    });

    test('replacing a file deletes the one it superseded', () async {
      final first = await repo.saveFile(
        _document('versioned'),
        'attachment',
        _text('version one'),
      );
      final firstKey = first.attachment!;

      final second = await repo.saveFile(first, 'attachment', _text('version two'));

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
      final kept =
          await repo.saveFile(_document('c'), 'attachment', _text('c'));

      await repo.deleteAllById([a.id!, b.id!]);

      expect(blobs.keys, [kept.attachment]);
    });

    test('a query-based delete cascades for exactly the rows it removed',
        () async {
      final doomed =
          await repo.saveFile(_document('purge'), 'attachment', _text('gone'));
      final kept =
          await repo.saveFile(_document('keep'), 'attachment', _text('stays'));

      await repo.deleteByQuerySentence(
        'DELETE BY title = :title',
        {'title': 'purge'},
      );

      expect(await repo.findById(doomed.id!), isNull);
      expect(await repo.findById(kept.id!), isNotNull);
      expect(blobs.keys, [kept.attachment]);
    });

    group('under a C-4 grade', () {
      const authKey = 'fixture.document.secret_attachment';

      test('a masked column refuses a download by name, not by absence',
          () async {
        final saved = await repo.saveFile(
          _document('graded'),
          'secretAttachment',
          _text('classified'),
        );

        TomAuthorization.adapter = _GradeAdapter({authKey: TomAuthState.none});

        // Not `no_file`: the file is there, the caller may not have it. The
        // masked key reads back as null, so without this check the refusal
        // would be indistinguishable from an empty column.
        await expectLater(
          repo.openFile(saved.id!, 'secretAttachment').toList(),
          throwsA(isA<TomColumnAuthorizationException>().having(
            (e) => e.key,
            'key',
            'column_authorization.read.field_forbidden',
          )),
        );
        await expectLater(
          repo.describeFile(saved.id!, 'secretAttachment'),
          throwsA(isA<TomColumnAuthorizationException>().having(
            (e) => e.key,
            'key',
            'column_authorization.read.field_forbidden',
          )),
        );
      });

      test('a read-only column refuses an upload before any bytes move',
          () async {
        TomAuthorization.adapter = _GradeAdapter({authKey: TomAuthState.read});

        await expectLater(
          repo.saveFile(
            _document('graded'),
            'secretAttachment',
            _text('classified'),
          ),
          throwsA(isA<TomColumnAuthorizationException>().having(
            (e) => e.key,
            'key',
            'column_authorization.write.field_forbidden',
          )),
        );
        // The refusal arrived before the transfer, so nothing was stored.
        expect(blobs.keys, isEmpty);
      });

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

      test('an unrestricted column is unaffected by a grade on its sibling',
          () async {
        var saved = await repo.saveFile(
          _document('graded'),
          'secretAttachment',
          _text('classified'),
        );
        saved = await repo.saveFile(saved, 'attachment', _text('ordinary'));

        TomAuthorization.adapter = _GradeAdapter({authKey: TomAuthState.none});

        expect(
          utf8.decode(
            await repo
                .openFile(saved.id!, 'attachment')
                .expand((c) => c)
                .toList(),
          ),
          'ordinary',
        );
      });
    });
  }, skip: skipReason);

  /// Blob access under a **row scope** (C-3) — the other half of the CSFS1
  /// requirement that file access honour the same gates as the owning entity
  /// (CSEXD2).
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
            await repo.openFile(ownedId, 'attachment').expand((c) => c).toList(),
          ),
          'private to one',
        );
        final described = await repo.describeFile(ownedId, 'attachment');
        expect(described, isNotNull);
        expect(described!.fileName, 'private.txt');

        final row = await repo.findById(ownedId);
        final replaced =
            await repo.saveFile(row!, 'attachment', _text('replaced by one'));
        expect(blobs.textOf(replaced.attachment!), 'replaced by one');
      });
    });

    test('openFile refuses an out-of-scope row as not found', () async {
      await _as(2, () async {
        await expectLater(
          repo.openFile(ownedId, 'attachment').toList(),
          throwsA(isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.file_reference.row_not_found',
          )),
          reason: 'principal 2 must not reach a row owned by principal 1, and '
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

    test('an out-of-scope row is indistinguishable from an absent one',
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
    });

    test('an unauthenticated caller reaches no scoped file at all', () async {
      // No principal in the zone: the built-in `owner` resolver yields no
      // allowed values, which renders a FALSE predicate rather than an absent
      // one. The secure default has to be asserted, because "no scope values"
      // and "no scoping" are one keystroke apart in the resolver.
      await expectLater(
        repo.openFile(ownedId, 'attachment').toList(),
        throwsA(isA<TomStorageException>().having(
          (e) => e.key,
          'key',
          'storage.file_reference.row_not_found',
        )),
      );
      expect(await repo.describeFile(ownedId, 'attachment'), isNull);
    });

    test('saveFile refuses to write an out-of-scope row, and moves no bytes',
        () async {
      // The breach in the other direction: overwriting a file on a row you
      // cannot read. Principal 2 cannot *load* the row, so it forges the
      // reference — which is precisely what an attacker holding a guessed id
      // would do.
      final forged = _scopedDocument('hijacked', 2)..id = ownedId;

      await _as(2, () async {
        await expectLater(
          repo.saveFile(forged, 'attachment', _text('overwritten by two')),
          throwsA(isA<TomDataScopeAuthorizationException>().having(
            (e) => e.key,
            'key',
            'data_scope.write.out_of_scope',
          )),
          reason: 'a write names one specific row, so unlike a read it cannot '
              'be answered by filtering it away — it has to be refused',
        );
      });

      // Refused before the transfer: the store still holds exactly the one
      // blob the owner put there, with its original content.
      expect(blobs.keys, [ownedKey]);
      expect(blobs.textOf(ownedKey), 'private to one');
    });

    test('saveFile refuses to create a row scoped to another principal',
        () async {
      await _as(2, () async {
        await expectLater(
          repo.saveFile(
            _scopedDocument('planted', 1),
            'attachment',
            _text('planted by two'),
          ),
          throwsA(isA<TomDataScopeAuthorizationException>().having(
            (e) => e.key,
            'key',
            'data_scope.write.insert_out_of_scope',
          )),
          reason: 'without the insert gate a principal could seed a row it '
              'cannot itself read, and reach its file only through the owner',
        );
      });
      expect(blobs.keys, [ownedKey]);
    });
  }, skip: skipReason);
}

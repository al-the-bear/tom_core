/// Connection-free tests for the file/blob storage module (CSFS1).
///
/// Everything here runs without a database, a bucket or a network: the memory
/// and directory backends are real, the S3 backend is driven through an
/// injected [MockClient] so its *requests* are asserted rather than a live
/// object store's behaviour, and the signer is checked against AWS's published
/// vectors. The database backend needs a server and is covered by
/// `file_storage_db_test.dart`.
///
/// The properties worth pinning here are the ones the rest of the framework
/// relies on: keys cannot escape their store, a failed write leaves nothing
/// readable, and a read is a stream rather than a buffer.
///
/// **`TomBlobExportStore` is not covered here**, although it is the one class
/// that puts these backends behind another module's interface. It is declared
/// in `lib/src/tomserver/export/` and is the export module's, so its tests are
/// in `export_test.dart`, beside the two backends it is interchangeable with.
/// This module does not know the export module exists, and a suite that covered
/// the adaptor here was the only thing suggesting otherwise.
///
/// What stays is the one claim that is about the two modules *agreeing*: an
/// export key and a blob key are one grammar in two vocabularies, and the
/// grammar is defined here.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';
import 'package:yaml/yaml.dart';

import 'fixtures/posix_permissions.dart';

/// A stream that delivers [chunks] and then fails — the interrupted upload.
Stream<List<int>> _failingStream(List<List<int>> chunks) async* {
  for (final chunk in chunks) {
    yield chunk;
  }
  throw StateError('upload interrupted');
}

/// `count` bytes of predictable content, as one chunk.
Uint8List _bytes(int count, [int seed = 0]) =>
    Uint8List.fromList([for (var i = 0; i < count; i++) (i + seed) % 251]);

/// Credentials from AWS's own signing examples.
const TomAwsCredentials _exampleCredentials = TomAwsCredentials(
  accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
  secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
);

/// Builds an S3 store whose every request goes to [handler].
TomS3BlobStore _s3(
  Future<http.Response> Function(http.Request request) handler, {
  bool pathStyle = true,
  int partSize = TomS3BlobStore.minimumPartSize,
  String? keyPrefix,
}) => TomS3BlobStore(
  endpoint: Uri.parse('https://s3.example.com'),
  bucket: 'examplebucket',
  region: 'us-east-1',
  credentials: _exampleCredentials,
  pathStyle: pathStyle,
  partSize: partSize,
  keyPrefix: keyPrefix,
  client: MockClient(handler),
);

/// A data source that fails the test if anything asks it to do work.
///
/// The point of a key check is that it happens *before* the backend acts, and
/// the only way to assert "before" is to make acting observable. `noSuchMethod`
/// covers the whole interface, so this cannot fall out of step with
/// `TomDataSource` the way a hand-written stub of two methods would.
class _UntouchableDataSource implements TomDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => fail(
    'the key reached SQL: '
    '${invocation.memberName.toString().split('"').elementAtOrNull(1)}',
  );
}

/// A data source whose every statement fails the way a driver's does.
///
/// `noSuchMethod` for the same reason [_UntouchableDataSource] uses it: the
/// whole interface is covered, so a method added to `TomDataSource` later
/// cannot slip past a hand-written stub of four. The throw is *synchronous*,
/// which is the harder of the two shapes — a backend's `async` body turns it
/// into a failed future, and a wrapper that caught only failed futures would
/// let it through.
class _FailingDataSource implements TomDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const SocketException('connection reset by peer');
}

/// The error key each method reports when the layer underneath it fails.
///
/// The division is by *what the caller asked for*, not by which call threw, so
/// `describe` and `exists` share one key: both are the caller asking storage a
/// question about a blob rather than for one.
const Map<String, String> _failureKeyOf = {
  'put': 'storage.blob.write_failed',
  'get': 'storage.blob.read_failed',
  'describe': 'storage.blob.probe_failed',
  'exists': 'storage.blob.probe_failed',
  'delete': 'storage.blob.delete_failed',
};

/// Asserts every method of [store] names its own failure and keeps [cause].
Future<void> _namesEveryFailure(TomBlobStore store, Matcher cause) async {
  for (final method in _everyMethod(store, 'reports/blob.bin').entries) {
    await expectLater(
      method.value(),
      throwsA(
        isA<TomStorageException>()
            .having((e) => e.key, 'key', _failureKeyOf[method.key])
            .having((e) => e.rootException, 'rootException', cause),
      ),
      reason: '${method.key} must name the operation the caller asked for',
    );
  }
}

/// Every method on the contract, named, so a test can walk the whole surface
/// instead of naming four of the five and leaving the fifth to drift.
///
/// `putBytes`/`getBytes` rather than `put`/`get` only because a buffered call
/// is one expression; they are the same two methods underneath.
///
/// The bodies are `async` so that a backend which rejects the key *before* its
/// first `await` — a synchronous throw — is accepted alongside one that returns
/// a failed future. A caller's `try`/`await` catches both identically, so
/// insisting on one of the two would pin an incidental detail.
Map<String, Future<Object?> Function()> _everyMethod(
  TomBlobStore store,
  String key,
) => {
  'put': () async => store.putBytes(key: key, bytes: const [1]),
  'get': () async => store.getBytes(key),
  'describe': () async => store.describe(key),
  'exists': () async => store.exists(key),
  'delete': () async => store.delete(key),
};

/// Asserts [store] refuses [key] with `storage.blob.invalid_key` everywhere.
Future<void> _refusesEverywhere(TomBlobStore store, String key) async {
  for (final method in _everyMethod(store, key).entries) {
    await expectLater(
      method.value(),
      throwsA(
        isA<TomStorageException>().having(
          (e) => e.key,
          'key',
          'storage.blob.invalid_key',
        ),
      ),
      reason: '${method.key} must refuse the key before it acts on it',
    );
  }
}

void main() {
  group('every backend refuses an invalid key on every method', () {
    // The grammar was enforced on `put` and left to each backend elsewhere, so
    // the same rejected key answered differently depending on which backend was
    // configured: `get('../escape')` was `invalid_key` on a directory store and
    // `not_found` on a memory one — the wrong error, and for a caller branching
    // on the two, the wrong branch. Three of the four backends checked `put`
    // alone; the directory backend was right only because `_fileFor` happened
    // to be the single point at which a key became an address.
    //
    // Each store below is built so that *acting* on the key is observable: the
    // S3 client fails the test if a request is made, the data source fails it
    // if a statement is run, and the directory root does not exist. So these
    // assert the documented property — an invalid key never reaches the
    // filesystem, the network or SQL — and not merely the error key.

    const traversal = '../escape';

    test('memory', () => _refusesEverywhere(TomMemoryBlobStore(), traversal));

    test('directory', () {
      final root = Directory(
        '${Directory.systemTemp.path}/tom_never_created_${pid}',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      return _refusesEverywhere(TomDirectoryBlobStore(root), traversal);
    });

    test('database', () {
      final store = TomDatabaseBlobStore(_UntouchableDataSource());
      return _refusesEverywhere(store, traversal);
    });

    test('s3', () {
      final store = _s3(
        (request) => fail('the key reached the network: ${request.url}'),
      );
      return _refusesEverywhere(store, traversal);
    });

    test('and a key that is merely too long is refused the same way', () {
      // The one clause that cannot be seen by reading the key: a prefix and a
      // key may each be valid and still join past the maximum. It shares the
      // error with a traversal because both are "this key is not usable", and
      // splitting them would make a caller handle two.
      final store = TomMemoryBlobStore();
      return _refusesEverywhere(store, 'a' * (TomBlobStore.maxKeyLength + 1));
    });
  });

  group('every backend names an infrastructure failure as a storage error', () {
    // The companion sweep to the one above, and the other half of what the
    // contract's wrappers are for. The directory backend's failure paths are
    // pinned in detail further down (they need real permissions to provoke);
    // these two are the ones whose infrastructure a connection-free suite can
    // only take away, which is also why they had never been asserted at all —
    // a `MySqlException` or a socket error escaping either of them would have
    // been the same defect the directory backend was fixed for, with a
    // different exception type and no test to notice.
    //
    // One fault, asked about five ways, gets five names: the operation the
    // *caller* asked for is what the key reports, not the statement that threw.
    // The original stays reachable as `rootException` — a caller needs a key it
    // can branch on, whoever reads the log needs the errno that explains it.

    final socketFailure = isA<SocketException>();

    test('database', () {
      final store = TomDatabaseBlobStore(_FailingDataSource());
      return _namesEveryFailure(store, socketFailure);
    });

    test('s3', () {
      final store = _s3(
        (request) => throw const SocketException('connection reset by peer'),
      );
      return _namesEveryFailure(store, socketFailure);
    });
  });

  group('key grammar', () {
    test('accepts relative, slash-separated, unreserved keys', () {
      for (final key in const [
        'a',
        'file.pdf',
        '2026/07/invoice.pdf',
        'exports/report-2026_07.xlsx',
        'a/b/c/d/e',
      ]) {
        expect(TomBlobStore.isValidKey(key), isTrue, reason: key);
      }
    });

    test('rejects traversal, absolute, and backslash keys', () {
      for (final key in const [
        '',
        '/absolute',
        'trailing/',
        '../escape',
        'a/../../etc/passwd',
        'a/./b',
        r'windows\path',
        'double//slash',
        'has space',
        'quest?ion',
      ]) {
        expect(TomBlobStore.isValidKey(key), isFalse, reason: '"$key"');
      }
    });

    test('rejects a key longer than the shared maximum', () {
      final long = 'a' * (TomBlobStore.maxKeyLength + 1);
      expect(TomBlobStore.isValidKey(long), isFalse);
      expect(TomBlobStore.isValidKey('a' * TomBlobStore.maxKeyLength), isTrue);
    });

    test('validateKey returns the key or throws storage.blob.invalid_key', () {
      expect(TomBlobStore.validateKey('ok/key.txt'), 'ok/key.txt');
      expect(
        () => TomBlobStore.validateKey('../escape'),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.blob.invalid_key',
          ),
        ),
      );
    });

    test('the export module enforces the same rule with its own error', () {
      // One grammar, two vocabularies: an export key that passes here is
      // storable by any blob backend, and a caller catching the export error
      // keeps catching it.
      expect(TomExportStore.validateKey('exports/a.csv'), 'exports/a.csv');
      expect(
        () => TomExportStore.validateKey('../escape'),
        throwsA(
          isA<TomExportException>().having(
            (e) => e.key,
            'key',
            'export.store.invalid_key',
          ),
        ),
      );
    });

    test('a key prefix is held to the key grammar it will be joined to', () {
      // A prefix is namespacing, not a separate notion: it is joined as
      // `"$prefix/$key"`, and every clause a key must satisfy the prefix must
      // satisfy too or the join produces something no backend accepts.
      for (final prefix in const ['exports', 'a/b', 'exports-2026_07']) {
        expect(TomBlobStore.isValidKeyPrefix(prefix), isTrue, reason: prefix);
      }
      for (final prefix in const [
        '..',
        'a/../..',
        '/exports',
        'a//b',
        r'a\b',
        'has space',
      ]) {
        expect(
          TomBlobStore.isValidKeyPrefix(prefix),
          isFalse,
          reason: '"$prefix"',
        );
      }
    });

    test('the empty prefix means no namespace; a trailing slash is not a '
        'prefix form', () {
      // Two ways to say "no prefix" would be one too many, and null is what a
      // configured backend leaves unset, so both spell the same thing.
      expect(TomBlobStore.isValidKeyPrefix(''), isTrue);
      expect(TomBlobStore.isValidKeyPrefix(null), isTrue);
      // The join supplies the separator, so `exports/` would produce
      // `exports//sales.csv` — rejected by the very grammar it must satisfy.
      expect(TomBlobStore.isValidKeyPrefix('exports/'), isFalse);
    });

    test('validateKeyPrefix names the prefix, not a key derived from it', () {
      expect(TomBlobStore.validateKeyPrefix('exports'), 'exports');
      expect(TomBlobStore.validateKeyPrefix(null), isNull);
      expect(
        () => TomBlobStore.validateKeyPrefix('..'),
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.blob.invalid_key_prefix')
              .having((e) => e.parameters?['keyPrefix'], 'keyPrefix', '..'),
        ),
      );
    });
  });

  group('TomMemoryBlobStore', () {
    late TomMemoryBlobStore store;
    setUp(() => store = TomMemoryBlobStore());

    test('round-trips content and reports what was written', () async {
      final stored = await store.put(
        key: 'a/b.txt',
        bytes: Stream.fromIterable([utf8.encode('hello '), utf8.encode('sky')]),
        mediaType: 'text/plain',
        fileName: 'greeting.txt',
      );
      expect(stored.key, 'a/b.txt');
      expect(stored.byteCount, 9);
      expect(stored.mediaType, 'text/plain');
      expect(stored.fileName, 'greeting.txt');
      expect(utf8.decode(await store.getBytes('a/b.txt')), 'hello sky');
      expect(store.textOf('a/b.txt'), 'hello sky');
    });

    test(
      'describe answers null for an absent key; get throws not_found',
      () async {
        expect(await store.describe('missing'), isNull);
        expect(await store.exists('missing'), isFalse);
        expect(
          () => store.getBytes('missing'),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.not_found',
            ),
          ),
        );
      },
    );

    test('delete reports whether anything was there', () async {
      await store.putBytes(key: 'k', bytes: utf8.encode('x'));
      expect(await store.delete('k'), isTrue);
      expect(await store.delete('k'), isFalse);
      expect(store.length, 0);
    });

    test('a stream that fails mid-way stores nothing', () async {
      // `write_failed`, like every other backend: the producer's `StateError`
      // is the *cause*, and a caller that has to name it to catch it would be
      // handling a different exception type per backend. It is not discarded —
      // it arrives as `rootException`, which is where the errno-level detail
      // belongs.
      await expectLater(
        store.put(key: 'k', bytes: _failingStream([utf8.encode('half')])),
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.blob.write_failed')
              .having(
                (e) => e.rootException,
                'rootException',
                isA<StateError>(),
              ),
        ),
      );
      expect(await store.exists('k'), isFalse);
    });

    test('an invalid key is refused before anything is read', () async {
      var read = false;
      Stream<List<int>> watched() async* {
        read = true;
        yield utf8.encode('x');
      }

      await expectLater(
        store.put(key: '../escape', bytes: watched()),
        throwsA(isA<TomStorageException>()),
      );
      expect(read, isFalse);
    });

    test('a chunk handed to a reader belongs to the reader', () async {
      // Writable, because every other backend reads its chunks off a file, a
      // socket or a row and hands the consumer something it owns; and
      // disconnected, because this backend used to yield the very list held in
      // its map, so a consumer decoding in place edited the stored blob.
      await store.putBytes(key: 'k', bytes: utf8.encode('abc'));

      final chunk = (await store.get('k').toList()).single;
      chunk[0] = 0x7a; // 'z'

      expect(chunk[0], 0x7a, reason: 'the chunk is the reader\'s to write to');
      expect(store.textOf('k'), 'abc', reason: 'and the store is untouched');
    });

    test('getBytes hands back a buffer of the caller\'s own', () async {
      // The buffered convenience is where a caller most plausibly writes in
      // place — it exists for the blobs small enough to decode whole. It
      // collects with a non-copying builder, which returns a lone chunk
      // untouched, so it is only as safe as what [get] yields.
      await store.putBytes(key: 'k', bytes: utf8.encode('abc'));

      final bytes = await store.getBytes('k');
      bytes[0] = 0x7a;

      expect(store.textOf('k'), 'abc');
    });

    test('a writer that reuses one buffer stores what it streamed', () async {
      // A fixed-size scratch buffer refilled per chunk is the normal shape of
      // an encoder, and this store collected with `BytesBuilder(copy: false)`,
      // which retains the lists it is given. Every chunk being the same list,
      // the join saw its last state once per chunk: 'ccc', not 'abc'.
      final scratch = Uint8List(1);
      Stream<List<int>> reusing() async* {
        for (final byte in 'abc'.codeUnits) {
          scratch[0] = byte;
          yield scratch;
        }
      }

      await store.put(key: 'k', bytes: reusing());
      expect(store.textOf('k'), 'abc');

      scratch[0] = 0x7a;
      expect(store.textOf('k'), 'abc', reason: 'and later writes miss it');
    });

    test('putBytes does not adopt the list it was handed', () async {
      // The one-shot form of the same fault: `putBytes` wraps the caller's list
      // in a single-element stream, which is exactly the case a non-copying
      // builder passes through without copying.
      final source = Uint8List.fromList(utf8.encode('abc'));
      await store.putBytes(key: 'k', bytes: source);

      source[0] = 0x7a;

      expect(store.textOf('k'), 'abc');
    });
  });

  group('TomDirectoryBlobStore', () {
    late Directory root;
    late TomDirectoryBlobStore store;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('tom_blob_dir_test');
      store = TomDirectoryBlobStore(root);
    });

    tearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });

    test('a key becomes a path beneath the root', () async {
      final stored = await store.putBytes(
        key: '2026/07/invoice.pdf',
        bytes: utf8.encode('%PDF-1.7'),
        mediaType: 'application/pdf',
        fileName: 'invoice.pdf',
      );
      final file = File('${root.path}/2026/07/invoice.pdf');
      expect(file.existsSync(), isTrue);
      expect(stored.location, file.absolute.uri);
      expect(await file.readAsString(), '%PDF-1.7');
    });

    test('media type and file name survive in the sidecar', () async {
      await store.putBytes(
        key: 'doc.bin',
        bytes: utf8.encode('x'),
        mediaType: 'application/pdf',
        fileName: 'Quarterly Report.pdf',
      );
      final described = await store.describe('doc.bin');
      expect(described!.mediaType, 'application/pdf');
      expect(described.fileName, 'Quarterly Report.pdf');
      expect(
        File(
          '${root.path}/doc.bin${TomDirectoryBlobStore.metadataSuffix}',
        ).existsSync(),
        isTrue,
      );
    });

    test('a blob dropped in by hand still reads and describes', () async {
      // No sidecar: describe falls back to the file's own size and mtime, so a
      // directory populated by `scp` is usable.
      await File('${root.path}/hand.txt').writeAsString('placed');
      final described = await store.describe('hand.txt');
      expect(described!.byteCount, 6);
      expect(described.mediaType, TomStoredBlob.defaultMediaType);
      expect(described.fileName, isNull);
      expect(utf8.decode(await store.getBytes('hand.txt')), 'placed');
    });

    test('a large blob is read back in several chunks', () async {
      // The point of the streaming contract: the consumer sees pieces, so the
      // whole object never has to exist at once.
      await store.putBytes(key: 'big.bin', bytes: _bytes(512 * 1024));
      final chunks = await store.get('big.bin').toList();
      expect(chunks.length, greaterThan(1));
      expect(chunks.fold<int>(0, (sum, c) => sum + c.length), 512 * 1024);
    });

    test('a failed write leaves neither the blob nor its partial', () async {
      await expectLater(
        store.put(key: 'k.bin', bytes: _failingStream([utf8.encode('half')])),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.blob.write_failed',
          ),
        ),
      );
      expect(File('${root.path}/k.bin').existsSync(), isFalse);
      expect(
        File(
          '${root.path}/k.bin${TomDirectoryBlobStore.partialSuffix}',
        ).existsSync(),
        isFalse,
      );
    });

    test('a failed overwrite leaves the previous content intact', () async {
      await store.putBytes(key: 'k.bin', bytes: utf8.encode('original'));
      await expectLater(
        store.put(key: 'k.bin', bytes: _failingStream([utf8.encode('new')])),
        throwsA(isA<TomStorageException>()),
      );
      expect(utf8.decode(await store.getBytes('k.bin')), 'original');
    });

    group('a commit step fails like the copy it follows', () {
      // The rollback used to guard the stream copy alone: `close`, `rename` and
      // the sidecar write sat one line past the `try` that deletes the partial.
      // That is backwards — the copy fails on the producer's terms, while the
      // three steps after it are the ones with filesystem failure modes of
      // their own, and each of them fails *after* the partial exists.

      test('a rename that cannot commit is a write failure', () async {
        // A directory standing where the blob goes: `rename` cannot replace it,
        // which is the same fault as a cross-device root or a read-only mount
        // and the cheapest of the three to arrange.
        Directory('${root.path}/k.bin').createSync(recursive: true);

        await expectLater(
          store.putBytes(key: 'k.bin', bytes: utf8.encode('mine')),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.write_failed',
            ),
          ),
        );
        expect(
          File(
            '${root.path}/k.bin${TomDirectoryBlobStore.partialSuffix}',
          ).existsSync(),
          isFalse,
          reason: 'the rollback that owns the partial must have run',
        );
      });

      test('a sidecar that cannot be written takes the blob with it', () async {
        // The sidecar is written after the rename, so by the time it fails the
        // commit has already happened and the residue is the blob itself. A
        // rollback that only knew about the partial would leave a blob readable
        // under a key whose `put` reported failure — and with the media type
        // and file name of the descriptor the caller never received.
        Directory(
          '${root.path}/k.bin${TomDirectoryBlobStore.metadataSuffix}',
        ).createSync(recursive: true);

        await expectLater(
          store.putBytes(
            key: 'k.bin',
            bytes: utf8.encode('mine'),
            mediaType: 'application/pdf',
          ),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.write_failed',
            ),
          ),
        );
        expect(await store.exists('k.bin'), isFalse);
      });

      test('an invalid key is still invalid_key, not the step it stopped', () {
        // The translation must not swallow the module's own errors: a caller
        // who spelled the key wrong needs to hear that, not that a write
        // failed.
        expect(
          store.putBytes(key: '../escape', bytes: utf8.encode('x')),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.invalid_key',
            ),
          ),
        );
      });
    });

    group('a read that fails is named, not a raw FileSystemException', () {
      // Absence is `not_found` and always was. What the filesystem reports for
      // everything *else* — a permission denied, an I/O error — reached the
      // caller as the platform's own exception type, so a pipeline catching
      // `TomServerException` did not catch it at all.

      test(
        'reading a file the filesystem refuses is a read failure',
        () async {
          final file = File('${root.path}/locked.bin')
            ..writeAsStringSync('secret');
          Process.runSync('chmod', ['000', file.path]);
          addTearDown(() => Process.runSync('chmod', ['600', file.path]));

          await expectLater(
            store.getBytes('locked.bin'),
            throwsA(
              isA<TomStorageException>().having(
                (e) => e.key,
                'key',
                'storage.blob.read_failed',
              ),
            ),
          );
        },
        skip: chmodSkipReason,
      );

      test('describing a file the filesystem refuses is a probe '
          'failure', () async {
        // `describe` reads the sidecar, so an unreadable sidecar is a fault
        // even though the blob itself is fine — and a fault about *asking*,
        // which is what `probe` names.
        await store.putBytes(
          key: 'locked.bin',
          bytes: utf8.encode('x'),
          mediaType: 'application/pdf',
        );
        final meta = File(
          '${root.path}/locked.bin${TomDirectoryBlobStore.metadataSuffix}',
        );
        Process.runSync('chmod', ['000', meta.path]);
        addTearDown(() => Process.runSync('chmod', ['600', meta.path]));

        await expectLater(
          store.describe('locked.bin'),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.probe_failed',
            ),
          ),
        );
      }, skip: chmodSkipReason);

      test('a delete that fails is a delete failure', () async {
        final dir = Directory('${root.path}/ro')..createSync();
        File('${dir.path}/a.bin').writeAsStringSync('x');
        Process.runSync('chmod', ['500', dir.path]);
        addTearDown(() => Process.runSync('chmod', ['700', dir.path]));

        await expectLater(
          store.delete('ro/a.bin'),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.delete_failed',
            ),
          ),
        );
      }, skip: chmodSkipReason);

      test('a blob the process may not see is reported absent, not '
          'a probe failure', () async {
        // The one method that does *not* translate, because it has nothing to
        // translate: `File.exists` answers from a `stat` and turns every
        // failure of it — this unreadable parent included — into `false`. So
        // `exists` means "visible to this process" here, and this test pins
        // that rather than the probe failure the other three paths raise. If
        // `dart:io` ever surfaces the errno, this is the test that should fail
        // and send someone to the note on `exists`.
        final dir = Directory('${root.path}/hidden')..createSync();
        File('${dir.path}/a.bin').writeAsStringSync('x');
        Process.runSync('chmod', ['000', dir.path]);
        addTearDown(() => Process.runSync('chmod', ['700', dir.path]));

        expect(await store.exists('hidden/a.bin'), isFalse);
      }, skip: chmodSkipReason);

      test('a missing key is still not_found, not a read failure', () {
        // The one filesystem answer that is not a fault. It has to keep its own
        // error key through the translation, because callers branch on it —
        // `TomBlobExportStore` translates exactly this one and lets the rest
        // through, and the file endpoint maps it to a 404.
        expect(
          store.getBytes('absent.bin'),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.not_found',
            ),
          ),
        );
      });
    });

    test('delete removes the blob and its sidecar', () async {
      await store.putBytes(key: 'k.bin', bytes: utf8.encode('x'));
      expect(await store.delete('k.bin'), isTrue);
      expect(await store.delete('k.bin'), isFalse);
      expect(
        File(
          '${root.path}/k.bin${TomDirectoryBlobStore.metadataSuffix}',
        ).existsSync(),
        isFalse,
      );
    });

    test('delete works on a blob that never had a sidecar', () async {
      // The other half of "a blob dropped in by hand still reads": having
      // accepted a file placed by `scp`, the store has to be able to remove it
      // again, and there is nothing beside it to remove. `delete` checks the
      // sidecar exists before unlinking it for exactly this case — a mutation
      // run found the check unguarded by any test.
      await File('${root.path}/hand.txt').writeAsString('placed');

      expect(await store.delete('hand.txt'), isTrue);
      expect(await store.exists('hand.txt'), isFalse);
    });

    group('one key cannot reach another key\'s bookkeeping', () {
      // The backend keeps two auxiliary files beside each blob — the sidecar
      // and the partial a write is staged in. Both used to be named with a
      // suffix the key grammar can spell, so a caller who chose `a.meta` or
      // `a.part` was addressing another caller's bookkeeping without either of
      // them doing anything wrong: `.` is an ordinary key character, and only
      // the segments `.` and `..` are reserved.

      test('the auxiliary suffixes are unspellable in a key', () {
        // The load-bearing assertion. Every case below follows from this one,
        // so if the suffixes ever move back inside the grammar this fails
        // first and names the reason, rather than leaving four scenario tests
        // to fail with a mysterious `hasLength`.
        for (final suffix in const [
          TomDirectoryBlobStore.metadataSuffix,
          TomDirectoryBlobStore.partialSuffix,
        ]) {
          expect(
            TomBlobStore.isValidKey('a$suffix'),
            isFalse,
            reason: 'a caller could name "a$suffix" and collide with "a"',
          );
        }
      });

      test('deleting a blob leaves a same-named neighbour readable', () async {
        // `delete` removed the sidecar unconditionally, so this reported
        // success while destroying a blob the caller never named.
        await store.putBytes(key: 'a', bytes: utf8.encode('first'));
        await store.putBytes(key: 'a.meta', bytes: utf8.encode('second'));

        expect(await store.delete('a'), isTrue);

        expect(await store.exists('a.meta'), isTrue);
        expect(utf8.decode(await store.getBytes('a.meta')), 'second');
      });

      test('writing a same-named neighbour keeps a blob describable', () async {
        // The other direction: the second `put` overwrote the sidecar with
        // blob content, and `describe('a')` fell back to the generic media
        // type — a silent loss, since the bytes still read back fine.
        await store.putBytes(
          key: 'a',
          bytes: utf8.encode('first'),
          mediaType: 'application/pdf',
          fileName: 'Quarterly Report.pdf',
        );
        await store.putBytes(key: 'a.meta', bytes: utf8.encode('not json'));

        final described = await store.describe('a');
        expect(described!.mediaType, 'application/pdf');
        expect(described.fileName, 'Quarterly Report.pdf');
      });

      test('a sidecar is not served as a blob of its own', () async {
        // Nothing was ever stored under `a.meta`, so reading it is a miss —
        // not a stream of the store's own JSON bookkeeping.
        await store.putBytes(
          key: 'a',
          bytes: utf8.encode('first'),
          mediaType: 'application/pdf',
        );

        expect(await store.exists('a.meta'), isFalse);
        expect(await store.describe('a.meta'), isNull);
        expect(
          () => store.getBytes('a.meta'),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.not_found',
            ),
          ),
        );
      });

      test('a write does not stage over a same-named neighbour', () async {
        // The same defect in the write path, which the todo did not report:
        // `put('a')` staged into `a.part` and renamed it away, so the
        // neighbour was first overwritten and then gone.
        await store.putBytes(key: 'a.part', bytes: utf8.encode('neighbour'));
        await store.putBytes(key: 'a', bytes: utf8.encode('mine'));

        expect(utf8.decode(await store.getBytes('a.part')), 'neighbour');
        expect(utf8.decode(await store.getBytes('a')), 'mine');
      });
    });

    test('a traversal key cannot reach outside the root', () async {
      expect(
        () => store.getBytes('../escape'),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.blob.invalid_key',
          ),
        ),
      );
    });
  });

  group('TomAwsV4Signer', () {
    test('derives the published signing key', () {
      // AWS docs, "Examples of how to derive a signing key": the one vector
      // that isolates the key derivation from the request canonicalisation.
      const signer = TomAwsV4Signer(
        credentials: TomAwsCredentials(
          accessKeyId: 'AKIDEXAMPLE',
          secretAccessKey: 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY',
        ),
        region: 'us-east-1',
        service: 'iam',
      );
      final hex = [
        for (final b in signer.signingKey('20120215'))
          b.toRadixString(16).padLeft(2, '0'),
      ].join();
      expect(
        hex,
        'f4780e2d9f65fa895f9c67b32ce1baf0b0d8a43505a000a1a9e090d414db404d',
      );
    });

    test('signs the published S3 GET Object example', () {
      // AWS docs, "Signature Calculations … Transferring Payload in a Single
      // Chunk", Example: GET Object. Every input is fixed — including the
      // timestamp, which is why [signedHeaders] takes one.
      const signer = TomAwsV4Signer(
        credentials: _exampleCredentials,
        region: 'us-east-1',
      );
      final headers = signer.signedHeaders(
        method: 'GET',
        uri: Uri.parse('https://examplebucket.s3.amazonaws.com/test.txt'),
        headers: const {'range': 'bytes=0-9'},
        payloadHash: TomAwsV4Signer.emptyPayloadHash,
        now: DateTime.utc(2013, 5, 24),
      );
      expect(headers['x-amz-date'], '20130524T000000Z');
      expect(headers['host'], 'examplebucket.s3.amazonaws.com');
      expect(
        headers['authorization'],
        'AWS4-HMAC-SHA256 '
        'Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, '
        'SignedHeaders=host;range;x-amz-content-sha256;x-amz-date, '
        'Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c603'
        '6bdb41',
      );
    });

    test('carries a session token into the signed headers', () {
      const signer = TomAwsV4Signer(
        credentials: TomAwsCredentials(
          accessKeyId: 'id',
          secretAccessKey: 'secret',
          sessionToken: 'token-value',
        ),
        region: 'eu-central-1',
      );
      final headers = signer.signedHeaders(
        method: 'GET',
        uri: Uri.parse('https://s3.example.com/b/k'),
        headers: const {},
        payloadHash: TomAwsV4Signer.emptyPayloadHash,
      );
      expect(headers['x-amz-security-token'], 'token-value');
      expect(
        headers['authorization'],
        contains(
          'SignedHeaders=host;x-amz-content-sha256;'
          'x-amz-date;x-amz-security-token',
        ),
      );
    });

    test('canonicalises paths, queries and reserved characters', () {
      expect(
        TomAwsV4Signer.canonicalPath(Uri.parse('https://h/a/b c/d')),
        '/a/b%20c/d',
      );
      expect(TomAwsV4Signer.canonicalPath(Uri.parse('https://h')), '/');
      expect(
        TomAwsV4Signer.canonicalQuery(
          Uri.parse('https://h/k?uploadId=7&partNumber=2'),
        ),
        'partNumber=2&uploadId=7',
      );
      // An empty value still signs with its `=`, which is what `?uploads` is.
      expect(
        TomAwsV4Signer.canonicalQuery(Uri.parse('https://h/k?uploads=')),
        'uploads=',
      );
      // Stricter than Uri.encodeComponent, which leaves these alone.
      expect(TomAwsV4Signer.encodeRfc3986("a!*'()b"), 'a%21%2A%27%28%29b');
      expect(
        TomAwsV4Signer.hashPayload(const []),
        TomAwsV4Signer.emptyPayloadHash,
      );
    });
  });

  group('TomS3BlobStore', () {
    test('rejects a part size below the protocol minimum', () {
      expect(
        () => _s3((_) async => http.Response('', 200), partSize: 1024),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.s3.part_size_too_small',
          ),
        ),
      );
    });

    test('a small object goes out as one signed PUT', () async {
      final requests = <http.Request>[];
      final store = _s3((request) async {
        requests.add(request);
        return http.Response('', 200);
      });
      final stored = await store.putBytes(
        key: 'a/b.txt',
        bytes: utf8.encode('hello'),
        mediaType: 'text/plain',
        fileName: 'greeting.txt',
      );

      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'PUT');
      expect(request.url.host, 's3.example.com');
      expect(request.url.path, '/examplebucket/a/b.txt');
      expect(request.body, 'hello');
      expect(request.headers['content-type'], 'text/plain');
      expect(request.headers[TomS3BlobStore.fileNameHeader], 'greeting.txt');
      expect(
        request.headers['x-amz-content-sha256'],
        TomAwsV4Signer.hashPayload(utf8.encode('hello')),
      );
      expect(
        request.headers['authorization'],
        startsWith('${TomAwsV4Signer.algorithm} Credential='),
      );
      expect(stored.byteCount, 5);
    });

    test('virtual-host addressing puts the bucket in the host', () async {
      late http.Request seen;
      final store = _s3((request) async {
        seen = request;
        return http.Response('', 200);
      }, pathStyle: false);
      await store.putBytes(key: 'k.txt', bytes: utf8.encode('x'));
      expect(seen.url.host, 'examplebucket.s3.example.com');
      expect(seen.url.path, '/k.txt');
    });

    test('a key prefix namespaces every request', () async {
      late http.Request seen;
      final store = _s3((request) async {
        seen = request;
        return http.Response('', 200);
      }, keyPrefix: 'tenant-7');
      await store.putBytes(key: 'k.txt', bytes: utf8.encode('x'));
      expect(seen.url.path, '/examplebucket/tenant-7/k.txt');
    });

    test('a key prefix that is not a key is refused at construction', () {
      // Worse here than anywhere else: this prefix is not re-validated, it is
      // joined and handed to `Uri.replace(pathSegments:)`. A `..` prefix became
      // a traversal segment in a *signed* request path rather than an error.
      for (final prefix in const ['..', '/tenant-7', 'a//b', 'tenant-7/']) {
        expect(
          () =>
              _s3((request) async => http.Response('', 200), keyPrefix: prefix),
          throwsA(
            isA<TomStorageException>()
                .having((e) => e.key, 'key', 'storage.blob.invalid_key_prefix')
                .having((e) => e.parameters?['keyPrefix'], 'keyPrefix', prefix),
          ),
          reason: '"$prefix"',
        );
      }
    });

    test(
      'an object larger than the part size becomes a multipart upload',
      () async {
        final requests = <http.Request>[];
        final store = _s3((request) async {
          requests.add(request);
          if (request.method == 'POST' &&
              request.url.query.contains('uploads')) {
            return http.Response(
              '<InitiateMultipartUploadResult>'
              '<UploadId>upload-7</UploadId>'
              '</InitiateMultipartUploadResult>',
              200,
            );
          }
          if (request.method == 'PUT') {
            return http.Response('', 200, headers: {'etag': '"etag-x"'});
          }
          return http.Response('<CompleteMultipartUploadResult/>', 200);
        });

        // 11 MiB in 1 MiB pieces against a 5 MiB part size: three parts, the last
        // of them short, and the buffer never holds more than one part.
        const mib = 1024 * 1024;
        final stored = await store.put(
          key: 'big.bin',
          bytes: Stream.fromIterable([
            for (var i = 0; i < 11; i++) _bytes(mib),
          ]),
        );

        expect(stored.byteCount, 11 * mib);
        expect(requests.first.method, 'POST');
        expect(requests.first.url.query, contains('uploads'));

        final parts = requests
            .where((r) => r.method == 'PUT')
            .map((r) => r.url.queryParameters['partNumber'])
            .toList();
        expect(parts, ['1', '2', '3']);
        for (final part in requests.where((r) => r.method == 'PUT')) {
          expect(part.url.queryParameters['uploadId'], 'upload-7');
        }
        expect(
          requests
              .where((r) => r.method == 'PUT')
              .map((r) => r.bodyBytes.length),
          [5 * mib, 5 * mib, mib],
        );

        final complete = requests.last;
        expect(complete.method, 'POST');
        expect(complete.url.queryParameters['uploadId'], 'upload-7');
        expect(complete.body, contains('<PartNumber>3</PartNumber>'));
        expect(complete.body, contains('"etag-x"'));
      },
    );

    test('a failure mid-upload aborts the multipart upload', () async {
      final requests = <http.Request>[];
      final store = _s3((request) async {
        requests.add(request);
        if (request.method == 'POST' && request.url.query.contains('uploads')) {
          return http.Response('<UploadId>upload-9</UploadId>', 200);
        }
        if (request.method == 'PUT') {
          return http.Response(
            '<Error><Code>SlowDown</Code><Message>later</Message></Error>',
            503,
          );
        }
        return http.Response('', 204);
      });

      const mib = 1024 * 1024;
      await expectLater(
        store.put(
          key: 'big.bin',
          bytes: Stream.fromIterable([for (var i = 0; i < 6; i++) _bytes(mib)]),
        ),
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.s3.request_failed')
              .having((e) => e.parameters?['code'], 'code', 'SlowDown'),
        ),
      );

      final abort = requests.last;
      expect(abort.method, 'DELETE');
      expect(abort.url.queryParameters['uploadId'], 'upload-9');
    });

    // The two ways an object store can answer a multipart request with a 200
    // and still not have done the job. Both are protocol violations rather than
    // transport failures, so nothing below the store will catch them — and both
    // are silently survivable if unchecked: an upload with no id would address
    // its parts to `uploadId=null`, and a part with no ETag would be omitted
    // from the completion manifest, truncating the object without an error.
    test('an initiate response with no upload id is refused', () async {
      final store = _s3((request) async {
        if (request.method == 'POST' && request.url.query.contains('uploads')) {
          // A well-formed envelope; the one element that matters is absent.
          return http.Response(
            '<InitiateMultipartUploadResult><Bucket>examplebucket</Bucket>'
            '</InitiateMultipartUploadResult>',
            200,
          );
        }
        return http.Response('', 200, headers: {'etag': '"etag-x"'});
      });

      const mib = 1024 * 1024;
      await expectLater(
        store.put(
          key: 'big.bin',
          bytes: Stream.fromIterable([for (var i = 0; i < 6; i++) _bytes(mib)]),
        ),
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.s3.no_upload_id')
              .having((e) => e.parameters?['key'], 'key parameter', 'big.bin'),
        ),
      );
    });

    test(
      'a part the store did not acknowledge with an ETag is refused',
      () async {
        final requests = <http.Request>[];
        final store = _s3((request) async {
          requests.add(request);
          if (request.method == 'POST' &&
              request.url.query.contains('uploads')) {
            return http.Response('<UploadId>upload-3</UploadId>', 200);
          }
          // 200, no `etag` header: accepted, unidentifiable, uncompletable.
          return http.Response('', 200);
        });

        const mib = 1024 * 1024;
        await expectLater(
          store.put(
            key: 'big.bin',
            bytes: Stream.fromIterable([
              for (var i = 0; i < 6; i++) _bytes(mib),
            ]),
          ),
          throwsA(
            isA<TomStorageException>()
                .having((e) => e.key, 'key', 'storage.s3.part_without_etag')
                .having((e) => e.parameters?['partNumber'], 'partNumber', 1),
          ),
        );

        // The failure travels the same abort path as any other mid-upload
        // failure, so the bucket is not left paying for an orphaned upload.
        expect(requests.last.method, 'DELETE');
        expect(requests.last.url.queryParameters['uploadId'], 'upload-3');
      },
    );

    test('get streams the body and translates a 404', () async {
      final store = _s3((request) async {
        if (request.url.path.endsWith('missing.txt')) {
          return http.Response('<Error><Code>NoSuchKey</Code></Error>', 404);
        }
        return http.Response('object body', 200);
      });
      expect(utf8.decode(await store.getBytes('k.txt')), 'object body');
      expect(
        () => store.getBytes('missing.txt'),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.blob.not_found',
          ),
        ),
      );
    });

    test('describe reads the object metadata, or answers null', () async {
      final store = _s3((request) async {
        expect(request.method, 'HEAD');
        if (request.url.path.endsWith('missing.txt')) {
          return http.Response('', 404);
        }
        return http.Response(
          '',
          200,
          headers: {
            'content-type': 'application/pdf',
            'content-length': '4096',
            'last-modified': 'Wed, 21 Oct 2015 07:28:00 GMT',
            TomS3BlobStore.fileNameHeader: 'report.pdf',
          },
        );
      });
      final described = await store.describe('k.pdf');
      expect(described!.mediaType, 'application/pdf');
      expect(described.byteCount, 4096);
      expect(described.storedAt, DateTime.utc(2015, 10, 21, 7, 28));
      expect(described.fileName, 'report.pdf');
      expect(await store.describe('missing.txt'), isNull);
    });

    test('delete answers whether the object was there', () async {
      final methods = <String>[];
      final store = _s3((request) async {
        methods.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('missing.txt')) {
          return http.Response('', 404);
        }
        return http.Response('', request.method == 'DELETE' ? 204 : 200);
      });
      expect(await store.delete('k.txt'), isTrue);
      expect(await store.delete('missing.txt'), isFalse);
      // No DELETE is sent for an object that is not there — S3 answers 204
      // either way, so the existence probe is what makes the contract true.
      expect(methods.where((m) => m.startsWith('DELETE')), hasLength(1));
    });

    test('parseHttpDate reads an IMF-fixdate and rejects anything else', () {
      expect(
        TomS3BlobStore.parseHttpDate('Wed, 21 Oct 2015 07:28:00 GMT'),
        DateTime.utc(2015, 10, 21, 7, 28),
      );
      expect(
        () => TomS3BlobStore.parseHttpDate('2015-10-21'),
        throwsFormatException,
      );
    });
  });

  group('TomBlobStoreInfo (registry and configuration)', () {
    tearDown(TomBlobStoreInfo.closeAll);

    test('a ready-made store can be registered as the default', () async {
      final store = TomMemoryBlobStore();
      TomBlobStoreInfo.register('files', store, asDefault: true);
      expect(TomBlobStoreInfo.storeNamed('files'), same(store));
      expect(TomBlobStoreInfo.defaultStore, same(store));
      expect(TomBlobStoreInfo.hasDefaultStore, isTrue);
    });

    test('an unknown name and an absent default are named errors', () {
      expect(
        () => TomBlobStoreInfo.storeNamed('nope'),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.registry.unknown_store',
          ),
        ),
      );
      expect(
        () => TomBlobStoreInfo.defaultStore,
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.registry.no_default_store',
          ),
        ),
      );
      expect(TomBlobStoreInfo.hasDefaultStore, isFalse);
    });

    test(
      'a single configured store becomes the default without saying so',
      () async {
        final count = await TomBlobStoreInfo.initializeBlobStores({
          'files': {'type': 'memory'},
        });
        expect(count, 1);
        expect(TomBlobStoreInfo.defaultStoreName, 'files');
        expect(TomBlobStoreInfo.defaultStore, isA<TomMemoryBlobStore>());
      },
    );

    test('with several stores, `default: true` nominates one', () async {
      final root = await Directory.systemTemp.createTemp('tom_blob_cfg_test');
      addTearDown(() => root.delete(recursive: true));
      await TomBlobStoreInfo.initializeBlobStores({
        'scratch': {'type': 'memory'},
        'archive': {'type': 'directory', 'root': root.path, 'default': true},
      });
      expect(TomBlobStoreInfo.defaultStoreName, 'archive');
      expect(TomBlobStoreInfo.defaultStore, isA<TomDirectoryBlobStore>());
      expect(TomBlobStoreInfo.storeNamed('scratch'), isA<TomMemoryBlobStore>());
    });

    test('reads a configuration decoded from YAML', () async {
      // The shape that actually arrives at start-up: a `YamlMap`, which is a
      // `Map<dynamic, dynamic>` and matches no reified `Map<String, Object>`.
      final document =
          loadYaml('''
fileStores:
  s3archive:
    type: s3
    endpoint: https://s3.example.com
    bucket: archive
    region: eu-central-1
    accessKeyId: id
    secretAccessKey: secret
    partSize: 5242880
    keyPrefix: tenant-7
''')
              as YamlMap;
      final config = <String, dynamic>{
        for (final entry in (document['fileStores'] as YamlMap).entries)
          '${entry.key}': entry.value,
      };
      await TomBlobStoreInfo.initializeBlobStores(config);

      final store = TomBlobStoreInfo.storeNamed('s3archive') as TomS3BlobStore;
      expect(store.bucket, 'archive');
      expect(store.region, 'eu-central-1');
      expect(store.partSize, TomS3BlobStore.minimumPartSize);
      expect(store.keyPrefix, 'tenant-7');
      expect(TomBlobStoreInfo.getBlobStoreInfo('s3archive')!.type, 's3');
    });

    test('an application backend is registered with one line', () async {
      TomBlobStoreInfo.registerBackend(
        'fixture',
        (name, settings) => TomMemoryBlobStore(),
      );
      expect(TomBlobStoreInfo.backendTypes, contains('fixture'));
      await TomBlobStoreInfo.initializeBlobStores({
        'custom': {'type': 'fixture'},
      });
      expect(TomBlobStoreInfo.storeNamed('custom'), isA<TomMemoryBlobStore>());
    });

    test('an unregistered backend type fails at configuration time', () async {
      await expectLater(
        TomBlobStoreInfo.initializeBlobStores({
          'files': {'type': 'nosuchbackend'},
        }),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.registry.unknown_backend',
          ),
        ),
      );
    });

    test('a missing required setting names the setting', () async {
      await expectLater(
        TomBlobStoreInfo.initializeBlobStores({
          'files': {'type': 'directory'},
        }),
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.registry.missing_setting')
              .having((e) => e.parameters?['setting'], 'setting', 'root'),
        ),
      );
    });

    test('closeAll empties the registry and forgets the default', () async {
      TomBlobStoreInfo.register('files', TomMemoryBlobStore(), asDefault: true);
      await TomBlobStoreInfo.closeAll();
      expect(TomBlobStoreInfo.stores, isEmpty);
      expect(TomBlobStoreInfo.defaultStoreName, isNull);
    });
  });
}

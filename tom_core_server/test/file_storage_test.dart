/// Connection-free tests for the file/blob storage module.
///
/// Everything here runs without a database, a bucket or a network: the memory
/// and directory backends are real, the S3 backend is driven through an
/// injected [MockClient] so its *requests* are asserted rather than a live
/// object store's behaviour, and the signer is checked against AWS's published
/// vectors. The database backend needs a server for a real round trip and is
/// covered by `file_storage_db_test.dart` — but the one property of it that is
/// a *rule* rather than a behaviour, that a blob's write time reaches the
/// column as an instant, is pinned here against a recording data source: a
/// `db`-tagged assertion is skipped on every machine without a database, and a
/// rule nothing checks on an ordinary run is a rule that returns.
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
// For the migration's guards, which read a *reflected* entity's file columns:
// the annotations are the subject, so a real fixture entity is the fixture.
import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

/// A stream that delivers [chunks] and then fails with [error].
///
/// Both halves of a transfer that breaks partway: an upload whose source dies
/// after the first chunk, and a download whose socket does. The default is the
/// upload case; the download cases pass the transport's own exception, so the
/// translation under test has something realistic to translate.
Stream<List<int>> _failingStream(
  List<List<int>> chunks, {
  Object? error,
}) async* {
  for (final chunk in chunks) {
    yield chunk;
  }
  throw error ?? StateError('upload interrupted');
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
}) => _s3WithClient(
  MockClient(handler),
  pathStyle: pathStyle,
  partSize: partSize,
  keyPrefix: keyPrefix,
);

/// Builds an S3 store whose responses are *streamed* rather than buffered.
///
/// [MockClient] turns its handler's `http.Response` into bytes before the store
/// ever sees it, so a body that fails partway cannot be expressed through it at
/// all: the failure would surface from `send`, before `doGet` returned, which
/// is the easy case and already covered. `MockClient.streaming` hands the store
/// the stream itself, which is the only way to put the error where a real
/// interrupted download puts it — after the first bytes have already reached
/// the caller.
TomS3BlobStore _s3Streaming(
  Future<http.StreamedResponse> Function(
    http.BaseRequest request,
    http.ByteStream body,
  )
  handler,
) => _s3WithClient(MockClient.streaming(handler));

/// The store both builders above return; only the client differs.
TomS3BlobStore _s3WithClient(
  http.Client client, {
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
  client: client,
);

/// A data source that fails the test if anything asks it to do work.
///
/// The point of a key check is that it happens *before* the backend acts, and
/// the only way to assert "before" is to make acting observable. `noSuchMethod`
/// covers the whole interface, so this cannot fall out of step with
/// `TomDataSource` the way a hand-written stub of two methods would.
class _UntouchableDataSource implements TomDataSource {
  @override
  TomStandardSqlDialect get sqlDialect => MariadbSqlDialect();

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
  TomStandardSqlDialect get sqlDialect => MariadbSqlDialect();

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

/// Asserts [store] refuses [key] with [errorKey] on every one of its methods.
///
/// [errorKey] defaults to the caller's-mistake case; a store whose *prefix* is
/// what makes the key unusable reports the deployment's fault instead, and gets
/// the same sweep rather than a second one shaped like it.
Future<void> _refusesEverywhere(
  TomBlobStore store,
  String key, {
  String errorKey = 'storage.blob.invalid_key',
}) async {
  for (final method in _everyMethod(store, key).entries) {
    await expectLater(
      method.value(),
      throwsA(isA<TomStorageException>().having((e) => e.key, 'key', errorKey)),
      reason: '${method.key} must refuse the key before it acts on it',
    );
  }
}

/// The backend's own exception, from inside the one a caller catches.
///
/// Every failure that is not one of [TomBlobStore.passThroughErrorKeys] reaches
/// a caller as its operation's generic key, so the backend's `status`, `code`
/// and `objectPath` are one level down — still in the log, still readable here,
/// no longer something a caller has to know the backend to branch on.
TomStorageException _backendFault(Object error) =>
    (error as TomStorageException).rootException as TomStorageException;

/// Matches a caller-visible storage failure of [operation] wrapping a backend
/// exception of [backendKey].
TypeMatcher<TomStorageException> _translated(
  String operationKey,
  String backendKey,
) => isA<TomStorageException>()
    .having((e) => e.key, 'key', operationKey)
    .having((e) => _backendFault(e).key, 'rootException.key', backendKey);

/// A backend whose every operation fails with a chosen error.
///
/// Raising a `TomStorageException` from a backend is the case under test, and no
/// shipped backend can be made to do it on demand — the S3 store needs a rigged
/// HTTP handler and reaches only its own keys.
class _ThrowingBlobStore extends TomBlobStore {
  _ThrowingBlobStore(this.error, {this.afterChunks = const []});

  /// What every operation throws.
  final Object error;

  /// Chunks [doGet] yields before failing, so a partial delivery can be seen.
  final List<List<int>> afterChunks;

  @override
  Stream<List<int>> doGet(String key) async* {
    yield* Stream.fromIterable(afterChunks);
    throw error;
  }

  @override
  Future<TomStoredBlob> doPut({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  }) async => throw error;

  @override
  Future<TomStoredBlob?> doDescribe(String key) async => throw error;

  @override
  Future<bool> doDelete(String key) async => throw error;

  @override
  Future<bool> doExists(String key) async => throw error;
}

/// One statement the store issued, with the parameters it bound.
class _IssuedStatement {
  _IssuedStatement(this.sql, this.params);

  final String sql;
  final Map<String, dynamic>? params;
}

/// A data source that records what the blob store asked of it and answers
/// nothing.
///
/// Enough for the subject: nothing here reads a row back, only what was handed
/// to the bind boundary on the way in. Modelled on the recorder in
/// `oauth_state_store_test.dart`, and keeping the parameters for the same
/// reason it does — the claim is about a bound *value*, not about the SQL text
/// around it.
class _RecordingBlobDataSource implements TomDataSource {
  @override
  TomStandardSqlDialect get sqlDialect => MariadbSqlDialect();

  /// Every statement issued, command and query alike, in order.
  final List<_IssuedStatement> issued = [];

  @override
  Future<BigInt> executeCommand(
    String command, [
    Map<String, dynamic>? params,
  ]) async {
    issued.add(_IssuedStatement(command, params));
    return BigInt.one;
  }

  @override
  Future<List<T>> executeQuery<T extends Object>(
    String command, [
    Map<String, dynamic>? params,
    Type? resultType,
  ]) async {
    issued.add(_IssuedStatement(command, params));
    return <T>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The recording data source was asked for ${invocation.memberName}, which '
    'no test needs. Implement it here if that changes.',
  );
}

/// A backend that implements nothing but [doGet], to exercise the inherited
/// range read.
///
/// Yields its content in fixed-size pieces so the default's arithmetic is
/// driven across chunk boundaries rather than over a single list, which is the
/// only shape in which it can be wrong.
class _WholeReadsOnlyBlobStore extends TomBlobStore {
  _WholeReadsOnlyBlobStore(this.content);

  final List<int> content;

  /// The piece size [doGet] yields in. Small, odd, and coprime with every
  /// boundary the ranges below sit on, so the default's arithmetic is exercised
  /// mid-piece at both ends rather than only on a piece boundary.
  static const int chunk = 7;

  /// How many bytes [doGet] has yielded across every read, so a test can show
  /// that the fallback pays for the whole object.
  int yielded = 0;

  @override
  Stream<List<int>> doGet(String key) async* {
    for (var at = 0; at < content.length; at += chunk) {
      final piece = content.sublist(at, (at + chunk).clamp(0, content.length));
      yielded += piece.length;
      yield piece;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not under test');
}

/// A repository that answers from a list, for the migration's own guards.
///
/// The sweep itself is exercised against a real database in
/// `file_storage_db_test.dart`; what belongs here are the checks that run
/// before any row is read, and the verification that runs after a copy.
class _ListRepository<T extends Object> implements TomRepository<T, int> {
  _ListRepository(this.rows);

  final List<T> rows;

  /// How many times the sweep asked for a page.
  int pages = 0;

  @override
  Future<List<T>> findAll([TomPageRequest? page]) async {
    pages++;
    final offset = page?.offset ?? 0;
    final limit = page?.limit ?? 0;
    if (offset >= rows.length) return [];
    final end = limit == 0
        ? rows.length
        : (offset + limit).clamp(0, rows.length);
    return rows.sublist(offset, end);
  }

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The list repository was asked for ${invocation.memberName}, which the '
    'migration does not use.',
  );
}

/// A store whose `put` reports a different size than it was given.
///
/// The one failure a later pass cannot detect: the next run finds the key
/// present and moves on, so a copy that silently differs has to be caught on
/// the pass that made it.
class _LyingBlobStore extends TomMemoryBlobStore {
  @override
  Future<TomStoredBlob> doPut({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  }) async {
    final stored = await super.doPut(
      key: key,
      bytes: bytes,
      mediaType: mediaType,
      fileName: fileName,
    );
    return TomStoredBlob(
      key: stored.key,
      mediaType: stored.mediaType,
      byteCount: stored.byteCount - 1,
      storedAt: stored.storedAt,
      digest: 'f' * 64,
      fileName: stored.fileName,
    );
  }
}

/// A backend that implements only the four required methods, to exercise the
/// inherited copy and move.
///
/// Deliberately not `TomMemoryBlobStore`: that one overrides both, so a test
/// driven through it would say nothing about the defaults a backend an
/// application writes will actually get.
class _FourMethodBlobStore extends TomBlobStore {
  final Map<String, List<int>> content = {};
  final Map<String, TomStoredBlob> _descriptors = {};

  @override
  Future<TomStoredBlob> doPut({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  }) async {
    final collected = <int>[];
    await for (final chunk in bytes) {
      collected.addAll(chunk);
    }
    content[key] = collected;
    return _descriptors[key] = TomStoredBlob(
      key: key,
      mediaType: mediaType,
      byteCount: collected.length,
      storedAt: DateTime.utc(2026, 7, 8),
      digest: TomBlobDigest.of(collected),
      fileName: fileName,
    );
  }

  @override
  Stream<List<int>> doGet(String key) async* {
    final bytes = content[key];
    if (bytes == null) throw TomBlobStore.notFound(key);
    yield bytes;
  }

  @override
  Future<TomStoredBlob?> doDescribe(String key) async => _descriptors[key];

  @override
  Future<bool> doDelete(String key) async {
    _descriptors.remove(key);
    return content.remove(key) != null;
  }
}

/// A backend that claims a prefix delete and does not implement one.
///
/// The half-finished backend: it must fail loudly rather than report an empty
/// purge, which is what the contract's throwing default is for. Built on the
/// four-method store because that one inherits the default — a subclass of the
/// memory backend would get its working override instead.
class _ClaimsPrefixDelete extends _WholeReadsOnlyBlobStore {
  _ClaimsPrefixDelete() : super(const []);

  @override
  bool get supportsPrefixDelete => true;
}

/// A data source that answers one blob's manifest and chunk rows from memory.
///
/// Enough to drive [TomDatabaseBlobStore]'s reads without a database, which is
/// what makes "only the chunks the range touches are fetched" assertable in the
/// default suite rather than only under `--tags db`.
class _StoredBlobDataSource implements TomDataSource {
  @override
  TomStandardSqlDialect get sqlDialect => MariadbSqlDialect();

  _StoredBlobDataSource({
    required this.key,
    required this.content,
    required this.chunkSize,
  });

  final String key;
  final List<int> content;
  final int chunkSize;

  /// The `chunk_index` of every chunk row queried, in order.
  final List<int> chunksRead = [];

  /// Whether the manifest answers `chunk_size` as `0`, the shape a row written
  /// without one has.
  bool unrecordedChunkSize = false;

  int get _chunkCount => (content.length + chunkSize - 1) ~/ chunkSize;

  @override
  Future<BigInt> executeCommand(
    String command, [
    Map<String, dynamic>? params,
  ]) async => BigInt.one;

  @override
  Future<List<T>> executeQuery<T extends Object>(
    String command, [
    Map<String, dynamic>? params,
    Type? resultType,
  ]) async {
    if (command.contains('chunk_index = :chunkIndex')) {
      final index = params!['chunkIndex'] as int;
      chunksRead.add(index);
      final at = index * chunkSize;
      final row = TomBlobChunkRow()
        ..chunkData = base64.encode(
          content.sublist(at, (at + chunkSize).clamp(0, content.length)),
        );
      return <TomBlobChunkRow>[row].cast<T>();
    }
    if (params?['key'] != key) return <T>[];
    final row = TomBlobManifestRow()
      ..storageKey = key
      ..uploadId = 'upload-1'
      ..mediaType = 'application/octet-stream'
      ..byteCount = content.length
      ..chunkCount = _chunkCount
      ..chunkSize = unrecordedChunkSize ? 0 : chunkSize
      ..digest = 'd' * 64
      ..storedAt = DateTime.utc(2026, 7, 8);
    return <TomBlobManifestRow>[row].cast<T>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The stored-blob data source was asked for ${invocation.memberName}, '
    'which no test needs.',
  );
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

  // `get` took a key and nothing else, so a download endpoint honouring HTTP
  // `Range` had to read from zero and throw the prefix away — paying the full
  // transfer for every seek, on backends that can all seek natively. The
  // contract now carries a range, with a default on [TomBlobStore] that reads
  // and discards so that no backend is *obliged* to implement two read paths,
  // and an override on each of the four that can do better.
  //
  // The reference every case is checked against is the same sublist, because
  // four native implementations and one fallback agreeing with `List.sublist`
  // is the whole claim. What differs between them is cost, and cost is what the
  // last three tests assert directly.
  group('a byte range reads only the bytes asked for', () {
    /// 5,000 bytes with a position-dependent value, so a slice taken from the
    /// wrong offset is a different slice rather than the same zeros.
    final content = Uint8List.fromList([
      for (var i = 0; i < 5000; i++) (i * 7 + i ~/ 251) % 251,
    ]);

    /// The ranges every backend is driven through: the head, the tail, an
    /// interior slice, the whole thing by two spellings, and the last byte
    /// alone.
    final ranges = <TomBlobRange>[
      TomBlobRange(0, 10),
      TomBlobRange(4990),
      TomBlobRange(1234, 3456),
      TomBlobRange(0),
      TomBlobRange(0, 5000),
      TomBlobRange(4999, 5000),
    ];

    Future<void> agreesWithSublist(TomBlobStore store, String key) async {
      for (final range in ranges) {
        final end = range.endExclusive ?? content.length;
        expect(
          await store.getBytes(key, range: range),
          content.sublist(range.start, end),
          reason: '$store served the wrong bytes for $range',
        );
      }
    }

    test('memory', () async {
      final store = TomMemoryBlobStore();
      await store.putBytes(key: 'k.bin', bytes: content);
      await agreesWithSublist(store, 'k.bin');
    });

    test('directory', () async {
      final root = Directory.systemTemp.createTempSync('tom_range_');
      addTearDown(() => root.deleteSync(recursive: true));
      final store = TomDirectoryBlobStore(root);
      await store.putBytes(key: 'k.bin', bytes: content);
      await agreesWithSublist(store, 'k.bin');
    });

    test('database', () async {
      final source = _StoredBlobDataSource(
        key: 'k.bin',
        content: content,
        chunkSize: 512,
      );
      final store = TomDatabaseBlobStore(source, createSchema: false);
      await agreesWithSublist(store, 'k.bin');
    });

    test('s3', () async {
      // The backend asks the object store for the range, so the fake has to
      // serve it — which is also what makes the header assertable below.
      final store = _s3((request) async {
        final header = request.headers['range'];
        if (header == null) return http.Response.bytes(content, 200);
        final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(header)!;
        final start = int.parse(match.group(1)!);
        final to = match.group(2)!;
        final end = to.isEmpty ? content.length : int.parse(to) + 1;
        return http.Response.bytes(content.sublist(start, end), 206);
      });
      await agreesWithSublist(store, 'k.bin');
    });

    test('a backend that implements only doGet', () async {
      // The inherited default, which is what decision (B) buys: a backend
      // author writes one read path and a ranged read still works.
      final store = _WholeReadsOnlyBlobStore(content);
      await agreesWithSublist(store, 'k.bin');
    });

    test('the default pays for the prefix, and the natives do not', () async {
      // The cost, stated as a number rather than as prose. All three serve
      // the last ten bytes of a 5,000-byte blob. The fallback reads the 4,990
      // before them and throws them away; the S3 backend sends one header and
      // receives ten; the database backend touches one chunk row out of ten.
      final tail = TomBlobRange(4990, 5000);
      final fallback = _WholeReadsOnlyBlobStore(content);
      expect(await fallback.getBytes('k.bin', range: tail), hasLength(10));
      expect(
        fallback.yielded,
        greaterThanOrEqualTo(4990),
        reason: 'the fallback is supposed to read the prefix and discard it',
      );

      var received = 0;
      final s3 = _s3((request) async {
        final match = RegExp(
          r'^bytes=(\d+)-(\d*)$',
        ).firstMatch(request.headers['range']!)!;
        final start = int.parse(match.group(1)!);
        final to = match.group(2)!;
        final body = content.sublist(
          start,
          to.isEmpty ? content.length : int.parse(to) + 1,
        );
        received += body.length;
        return http.Response.bytes(body, 206);
      });
      await s3.getBytes('k.bin', range: tail);
      expect(received, 10, reason: 'the prefix crossed the wire anyway');

      final source = _StoredBlobDataSource(
        key: 'k.bin',
        content: content,
        chunkSize: 500,
      );
      final database = TomDatabaseBlobStore(source, createSchema: false);
      await database.getBytes('k.bin', range: tail);
      expect(
        source.chunksRead,
        [9],
        reason: 'the rows before the range were fetched and thrown away',
      );
    });

    test('the S3 range header is inclusive at the end, and is signed', () {
      // Two facts about one line. The header is inclusive where this module's
      // range is exclusive, so an off-by-one here serves one byte too many
      // without failing anywhere; and a header S3 does not see in the signature
      // makes the whole request a 403.
      final seen = <String, String>{};
      final store = _s3((request) async {
        seen.addAll(request.headers);
        return http.Response.bytes(content.sublist(0, 10), 206);
      });
      return store.getBytes('k.bin', range: TomBlobRange(0, 10)).then((_) {
        expect(seen['range'], 'bytes=0-9');
        expect(seen['authorization'], contains('SignedHeaders='));
        expect(seen['authorization'], contains('range'));
      });
    });

    test('an open-ended range asks S3 for one too', () async {
      // `bytes=500-` rather than a computed end: the store does not know the
      // object's size, and inventing one would be the second place that size is
      // decided.
      late String header;
      final store = _s3((request) async {
        header = request.headers['range']!;
        return http.Response.bytes(content.sublist(500), 206);
      });
      await store.getBytes('k.bin', range: TomBlobRange(500));
      expect(header, 'bytes=500-');
    });

    test('a manifest with no recorded chunk size still reads correctly', () {
      // The database backend divides a byte offset by the recorded chunk size.
      // A manifest that does not carry one cannot be seeked into, and the
      // answer is the slow correct read rather than a guess: `byte_count` and
      // `chunk_count` do not determine it — 10 bytes in 2 chunks is 6+4 or 9+1
      // or 5+5.
      final source = _StoredBlobDataSource(
        key: 'k.bin',
        content: content,
        chunkSize: 500,
      )..unrecordedChunkSize = true;
      final store = TomDatabaseBlobStore(source, createSchema: false);
      return expectLater(
        store.getBytes('k.bin', range: TomBlobRange(4800, 4810)),
        completion(content.sublist(4800, 4810)),
      );
    });

    test('a range that is not one is refused before any backend sees it', () {
      for (final build in <TomBlobRange Function()>[
        () => TomBlobRange(-1),
        () => TomBlobRange(-1, 10),
        () => TomBlobRange(10, 10),
        () => TomBlobRange(10, 9),
      ]) {
        expect(
          build,
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.invalid_range',
            ),
          ),
        );
      }
    });

    test('clampedTo separates unsatisfiable from merely overshooting', () {
      // The distinction an endpoint answers 416 or 206 on. A start at or past
      // the end names no byte and must be refused; a range that runs off the
      // end is how a resumed download ends and must be served.
      expect(TomBlobRange(100).clampedTo(100), isNull);
      expect(TomBlobRange(101).clampedTo(100), isNull);
      expect(TomBlobRange(0, 500).clampedTo(100)!.endExclusive, 100);
      expect(TomBlobRange(90).clampedTo(100)!.endExclusive, 100);
      final exact = TomBlobRange(10, 20);
      expect(identical(exact.clampedTo(100), exact), isTrue);
      expect(TomBlobRange(10, 20).length, 10);
      expect(TomBlobRange(10).length, isNull);
    });
  });

  // Relocating a blob meant streaming it out of the store and back in, which is
  // not theoretical: the documented pattern for expiry is a date-prefixed key,
  // so re-partitioning is a thing deployments do. Every backend has a native
  // answer — a filesystem copies and renames, a map assigns, a manifest row is
  // a second row against the same chunks, S3 has CopyObject — and the contract
  // now has the two methods to reach them through.
  //
  // The default is concrete rather than abstract, which is the decision worth
  // holding: unlike a listing, a stream round trip costs exactly what it looks
  // like it costs, so a concrete default hides nothing.
  group('copy and move', () {
    final payload = Uint8List.fromList([
      for (var i = 0; i < 2048; i++) (i * 31) % 251,
    ]);

    /// Every backend a connection-free suite can build, by name.
    Map<String, TomBlobStore> backends() {
      final root = Directory.systemTemp.createTempSync('tom_relocate_');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      return {
        'memory': TomMemoryBlobStore(),
        'directory': TomDirectoryBlobStore(root),
        'only the four methods': _FourMethodBlobStore(),
      };
    }

    test(
      'a copy is the same bytes under a second key, on every backend',
      () async {
        for (final entry in backends().entries) {
          final store = entry.value;
          await store.putBytes(
            key: 'a/source.bin',
            bytes: payload,
            mediaType: 'image/png',
            fileName: 'picture.png',
          );

          final copied = await store.copy('a/source.bin', 'b/copy.bin');
          expect(copied.key, 'b/copy.bin', reason: entry.key);
          expect(copied.byteCount, payload.length, reason: entry.key);
          // The media type and the file name travel with the bytes. A copy that
          // lost its Content-Type would be served as application/octet-stream
          // and download as a file nothing opens.
          expect(copied.mediaType, 'image/png', reason: entry.key);
          expect(copied.fileName, 'picture.png', reason: entry.key);
          expect(
            await store.getBytes('b/copy.bin'),
            payload,
            reason: entry.key,
          );
          // And the source is still there — that is what makes it a copy.
          expect(
            await store.getBytes('a/source.bin'),
            payload,
            reason: entry.key,
          );
          expect(
            (await store.describe('b/copy.bin'))!.mediaType,
            'image/png',
            reason: '${entry.key} did not persist the copied media type',
          );
        }
      },
    );

    test('a move leaves nothing behind, on every backend', () async {
      for (final entry in backends().entries) {
        final store = entry.value;
        await store.putBytes(
          key: 'a/source.bin',
          bytes: payload,
          mediaType: 'image/png',
          fileName: 'picture.png',
        );

        final moved = await store.move('a/source.bin', 'b/moved.bin');
        expect(moved.key, 'b/moved.bin', reason: entry.key);
        expect(moved.mediaType, 'image/png', reason: entry.key);
        expect(moved.fileName, 'picture.png', reason: entry.key);
        expect(await store.getBytes('b/moved.bin'), payload, reason: entry.key);
        expect(await store.exists('a/source.bin'), isFalse, reason: entry.key);
        expect(
          store.getBytes('a/source.bin'),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.not_found',
            ),
          ),
          reason: entry.key,
        );
      }
    });

    test('both replace whatever the destination held', () async {
      // The same rule `put` has, and stated because the alternative — refusing
      // an occupied destination — would be a second rule to remember for the
      // one operation most likely to be run over a key space in bulk.
      for (final entry in backends().entries) {
        final store = entry.value;
        await store.putBytes(key: 'a.bin', bytes: payload);
        await store.putBytes(key: 'b.bin', bytes: const [1, 2, 3]);
        await store.copy('a.bin', 'b.bin');
        expect(await store.getBytes('b.bin'), payload, reason: entry.key);

        await store.putBytes(key: 'c.bin', bytes: const [4, 5, 6]);
        await store.move('b.bin', 'c.bin');
        expect(await store.getBytes('c.bin'), payload, reason: entry.key);
      }
    });

    test('an absent source is not_found, not an empty destination', () async {
      // The failure that matters most: a relocation loop over a key list that
      // silently created empty blobs for the keys that had gone would be worse
      // than one that stopped.
      for (final entry in backends().entries) {
        final store = entry.value;
        for (final relocate in <Future<TomStoredBlob> Function()>[
          () => store.copy('gone.bin', 'new.bin'),
          () => store.move('gone.bin', 'new.bin'),
        ]) {
          await expectLater(
            relocate(),
            throwsA(
              isA<TomStorageException>().having(
                (e) => e.key,
                'key',
                'storage.blob.not_found',
              ),
            ),
            reason: entry.key,
          );
        }
        expect(await store.exists('new.bin'), isFalse, reason: entry.key);
      }
    });

    test('a key onto itself is refused before any backend is touched', () {
      // There is no reading of this that is worth guessing at, and the obvious
      // implementation — read it, write it back — is a truncation on any
      // backend whose write is not atomic. S3 refuses it outright. So it is one
      // error rather than four behaviours, raised by the contract: the stores
      // below fail the test if a request or a statement reaches them.
      for (final store in <TomBlobStore>[
        TomMemoryBlobStore(),
        TomDatabaseBlobStore(_UntouchableDataSource()),
        _s3(
          (request) => fail('the request reached the network: ${request.url}'),
        ),
      ]) {
        for (final relocate in <Future<TomStoredBlob> Function()>[
          () => store.copy('same.bin', 'same.bin'),
          () => store.move('same.bin', 'same.bin'),
        ]) {
          expect(
            relocate,
            throwsA(
              isA<TomStorageException>()
                  .having((e) => e.key, 'key', 'storage.blob.same_key')
                  .having(
                    (e) => e.parameters?['key'],
                    'key parameter',
                    'same.bin',
                  ),
            ),
            reason: '$store',
          );
        }
      }
    });

    test('an invalid key on either side is refused, on every backend', () {
      // Both sides, because validating only the source would let a traversal in
      // through the destination — which is the half a caller building a new key
      // from a date or a user-supplied name is most likely to get wrong.
      for (final store in backends().values) {
        for (final relocate in <Future<TomStoredBlob> Function()>[
          () => store.copy('../escape', 'ok.bin'),
          () => store.copy('ok.bin', '../escape'),
          () => store.move('../escape', 'ok.bin'),
          () => store.move('ok.bin', '../escape'),
        ]) {
          expect(
            relocate,
            throwsA(
              isA<TomStorageException>().having(
                (e) => e.key,
                'key',
                'storage.blob.invalid_key',
              ),
            ),
            reason: '$store',
          );
        }
      }
    });

    test('overwriting a copied key leaves the copy alone', () async {
      // Two keys, two blobs — the property a bulk relocation depends on. The
      // memory backend also copies the *list*, which this cannot see: nothing
      // mutates a stored list in place, so an aliased one has no observable
      // consequence. That copy is defensive, and the source says so rather than
      // this test implying it is checked.
      final store = TomMemoryBlobStore();
      await store.putBytes(
        key: 'a.bin',
        bytes: payload,
        mediaType: 'image/png',
      );
      await store.copy('a.bin', 'b.bin');
      await store.putBytes(key: 'a.bin', bytes: const [9, 9, 9]);
      expect(await store.getBytes('b.bin'), payload);
      expect((await store.describe('b.bin'))!.mediaType, 'image/png');
      expect((await store.describe('a.bin'))!.byteCount, 3);
    });

    test('the directory backend moves by renaming, not by copying', () async {
      // The claim is what makes a re-partitioning of a terabyte affordable, and
      // it is not visible in the bytes. What is visible: the source file is
      // gone from the filesystem, the destination exists, and the metadata
      // sidecar travelled with it — a move that left the sidecar behind would
      // serve the blob as application/octet-stream.
      final root = Directory.systemTemp.createTempSync('tom_rename_');
      addTearDown(() => root.deleteSync(recursive: true));
      final store = TomDirectoryBlobStore(root);
      await store.putBytes(
        key: 'old/a.bin',
        bytes: payload,
        mediaType: 'image/png',
      );

      await store.move('old/a.bin', 'new/b.bin');
      expect(File('${root.path}/old/a.bin').existsSync(), isFalse);
      expect(File('${root.path}/new/b.bin').existsSync(), isTrue);
      expect(
        File(
          '${root.path}/old/a.bin${TomDirectoryBlobStore.metadataSuffix}',
        ).existsSync(),
        isFalse,
        reason: 'the sidecar was left behind, describing a blob that moved',
      );
      expect((await store.describe('new/b.bin'))!.mediaType, 'image/png');
    });

    test('the directory backend leaves no partial when a copy fails', () {
      // The staging protocol `doPut` uses, applied here for the same reason: a
      // copy interrupted half way must not leave a truncated blob under a key
      // that already held a complete one. Provoked with a destination whose
      // parent is a *file*, so creating the directory fails.
      final root = Directory.systemTemp.createTempSync('tom_partial_');
      addTearDown(() => root.deleteSync(recursive: true));
      final store = TomDirectoryBlobStore(root);
      File('${root.path}/blocked').writeAsStringSync('not a directory');
      return store.putBytes(key: 'a.bin', bytes: payload).then((_) async {
        await expectLater(
          store.copy('a.bin', 'blocked/b.bin'),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.blob.copy_failed',
            ),
          ),
        );
        // Nothing staged survives under the root, whatever the failure was.
        final leftovers = root
            .listSync(recursive: true)
            .where((e) => e.path.contains(TomDirectoryBlobStore.partialSuffix));
        expect(leftovers, isEmpty);
      });
    });

    test('the S3 backend copies inside the object store', () async {
      // `CopyObject`: a PUT at the destination naming the source in a header,
      // with no body. The inherited default would have pulled every byte down
      // to this process and pushed it back up, which for an object store is the
      // one cost the native operation exists to avoid.
      final requests = <http.Request>[];
      final store = _s3((request) async {
        requests.add(request);
        if (request.method == 'HEAD') {
          return http.Response(
            '',
            200,
            headers: const {
              'content-type': 'image/png',
              'content-length': '2048',
              TomS3BlobStore.fileNameHeader: 'picture.png',
            },
          );
        }
        return http.Response('', 200);
      }, keyPrefix: 'tenant-7');

      final copied = await store.copy('a/source.bin', 'b/copy.bin');
      final put = requests.singleWhere((r) => r.method == 'PUT');
      expect(put.url.path, '/examplebucket/tenant-7/b/copy.bin');
      expect(
        put.headers['x-amz-copy-source'],
        '/examplebucket/tenant-7/a/source.bin',
        reason: 'the source names the bucket and the configured prefix',
      );
      expect(put.bodyBytes, isEmpty, reason: 'the bytes crossed the wire');
      expect(put.headers['authorization'], contains('x-amz-copy-source'));
      // The descriptor is the source's, under the new key: S3 answers a copy
      // with an XML body carrying no size, so re-describing would be a second
      // round trip for what is already known.
      expect(copied.mediaType, 'image/png');
      expect(copied.byteCount, 2048);
      expect(copied.fileName, 'picture.png');
    });

    test('an S3 move is a copy and then a delete, in that order', () async {
      // S3 has no rename, so the inherited `doMove` is the right one — and the
      // *order* is the contract: an interrupted move leaves the blob readable
      // under both keys rather than under neither. A duplicate converges on a
      // retry; a deletion does not.
      final calls = <String>[];
      final store = _s3((request) async {
        calls.add(request.method);
        if (request.method == 'HEAD') {
          return http.Response('', 200, headers: const {'content-length': '3'});
        }
        return http.Response('', request.method == 'DELETE' ? 204 : 200);
      });

      await store.move('a.bin', 'b.bin');
      expect(calls.where((c) => c == 'PUT' || c == 'DELETE'), [
        'PUT',
        'DELETE',
      ]);
    });

    test('a failure reaches the caller as copy_failed or move_failed', () {
      // The operation the caller asked for, not the one the default happened to
      // run underneath. A `move` that reported `write_failed` from the copy
      // inside it would send whoever reads the log to the wrong half.
      final failing = _ThrowingBlobStore(
        const SocketException('connection reset by peer'),
      );
      for (final entry in <String, Future<TomStoredBlob> Function()>{
        'storage.blob.copy_failed': () => failing.copy('a.bin', 'b.bin'),
        'storage.blob.move_failed': () => failing.move('a.bin', 'b.bin'),
      }.entries) {
        expect(
          entry.value,
          throwsA(
            isA<TomStorageException>()
                .having((e) => e.key, 'key', entry.key)
                .having((e) => e.parameters?['key'], 'key parameter', 'a.bin'),
          ),
        );
      }
    });
  });

  // Nothing hashed what was stored, so two identical uploads were two copies, a
  // caller could not ask whether the bytes it was about to send were already
  // there, and nothing could verify that what came back was what went in. The
  // digest is computed on the pass the backend is already making, which is what
  // makes it affordable enough to be unconditional — and unconditional is what
  // makes it something a caller can build on rather than a field to check for.
  group('a stored blob carries the SHA-256 of its content', () {
    /// The published SHA-256 of "abc", so the hash is checked against a value
    /// from outside this codebase rather than against itself.
    const abc =
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

    /// The published SHA-256 of the empty input — the value that makes a
    /// sentinel of `''` necessary, since "no digest" must not read as this.
    const empty =
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

    test('the hash agrees with the published vectors', () {
      expect(TomBlobDigest.of(utf8.encode('abc')), abc);
      expect(TomBlobDigest.of(const []), empty);
      // Fed in pieces, which is how every backend feeds it. A chunked hash that
      // disagreed with a whole one would be wrong on exactly the blobs too big
      // to check by hand.
      final chunked = TomBlobDigest()
        ..add(utf8.encode('a'))
        ..add(utf8.encode('b'))
        ..add(utf8.encode('c'));
      expect(chunked.close(), abc);
      // Idempotent, because a backend with more than one exit path should not
      // have to track which one closed it.
      expect(chunked.close(), abc);
    });

    test(
      'every backend records it on write and reports it on describe',
      () async {
        final root = Directory.systemTemp.createTempSync('tom_digest_');
        addTearDown(() => root.deleteSync(recursive: true));
        final backends = <String, TomBlobStore>{
          'memory': TomMemoryBlobStore(),
          'directory': TomDirectoryBlobStore(root),
          'database': TomDatabaseBlobStore(
            _RecordingBlobDataSource(),
            createSchema: false,
          ),
          's3': _s3((request) async => http.Response('', 200)),
        };

        for (final entry in backends.entries) {
          final stored = await entry.value.putBytes(
            key: 'a/abc.txt',
            bytes: utf8.encode('abc'),
          );
          expect(stored.digest, abc, reason: entry.key);
          expect(stored.hasDigest, isTrue, reason: entry.key);
        }

        // Read back, which is the half that needs the digest *persisted* rather
        // than merely returned. The database and S3 backends are driven against
        // fakes that do not store, so they are covered by the db suite and the
        // round trip below instead.
        for (final key in const ['memory', 'directory']) {
          final store = backends[key]!;
          expect((await store.describe('a/abc.txt'))!.digest, abc, reason: key);
        }
      },
    );

    test('the digest survives a copy and a move, without a re-read', () async {
      // Carried rather than recomputed: a copy that does not read the blob
      // cannot hash it, and it does not need to — the same bytes have the same
      // hash. A backend that dropped the digest here would make every relocated
      // blob unverifiable.
      final root = Directory.systemTemp.createTempSync('tom_digest_move_');
      addTearDown(() => root.deleteSync(recursive: true));
      for (final store in <TomBlobStore>[
        TomMemoryBlobStore(),
        TomDirectoryBlobStore(root),
      ]) {
        await store.putBytes(key: 'a.txt', bytes: utf8.encode('abc'));
        expect(
          (await store.copy('a.txt', 'b.txt')).digest,
          abc,
          reason: '$store',
        );
        expect((await store.describe('b.txt'))!.digest, abc, reason: '$store');
        expect(
          (await store.move('b.txt', 'c.txt')).digest,
          abc,
          reason: '$store',
        );
        expect((await store.describe('c.txt'))!.digest, abc, reason: '$store');
      }
    });

    test('a blob this framework did not write reports no digest', () async {
      // The one case a non-nullable field has to answer honestly. A file
      // dropped into the tree by hand has no sidecar, so no media type and no
      // hash; `unknownDigest` says that without pretending the file is empty,
      // which is what a digest of `e3b0c442…` would have said.
      final root = Directory.systemTemp.createTempSync('tom_foreign_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/dropped.txt').writeAsStringSync('abc');

      final described = await TomDirectoryBlobStore(
        root,
      ).describe('dropped.txt');
      expect(described!.digest, TomStoredBlob.unknownDigest);
      expect(described.hasDigest, isFalse);
      expect(
        described.digest,
        isNot(empty),
        reason: '"not recorded" must not read as "the empty file"',
      );
      expect(described.mediaType, TomStoredBlob.defaultMediaType);
    });

    test(
      'identical bytes under two keys hash the same, and different bytes do not',
      () async {
        // The property deduplication is built on, which is the reason the todo
        // asked for a digest at all. The framework does not deduplicate — it
        // gives a caller the key it would need to.
        final store = TomMemoryBlobStore();
        final first = await store.putBytes(
          key: 'one.txt',
          bytes: utf8.encode('abc'),
        );
        final second = await store.putBytes(
          key: 'two.txt',
          bytes: utf8.encode('abc'),
          mediaType: 'text/plain',
          fileName: 'other-name.txt',
        );
        final third = await store.putBytes(
          key: 'three.txt',
          bytes: utf8.encode('abd'),
        );

        // The media type and the name differ and the digest does not: it is a
        // hash of the *content*, not of the descriptor around it.
        expect(second.digest, first.digest);
        expect(third.digest, isNot(first.digest));
      },
    );

    test('the S3 backend records the digest as user metadata', () async {
      // S3 has no protocol header that means this. `x-amz-content-sha256` is
      // the signature's payload hash — on a multipart upload it is a *part's*
      // hash — and `ETag` is an MD5 only for single-part objects. So the store
      // records its own, and reads its own back.
      final requests = <http.Request>[];
      final store = _s3((request) async {
        requests.add(request);
        if (request.method == 'HEAD') {
          return http.Response(
            '',
            200,
            headers: {'content-length': '3', TomS3BlobStore.digestHeader: abc},
          );
        }
        return http.Response('', 200);
      });

      await store.putBytes(key: 'a.txt', bytes: utf8.encode('abc'));
      expect(requests.single.headers[TomS3BlobStore.digestHeader], abc);
      expect((await store.describe('a.txt'))!.digest, abc);
    });

    test('a multipart upload sets the digest after the parts are in', () async {
      // The one path where the digest cannot ride the upload: multipart
      // metadata is fixed when the upload is created, before the last part has
      // been seen. Without the follow-up the largest objects — the ones a
      // caller most wants to verify — would come back with no digest at all.
      final requests = <http.Request>[];
      final store = _s3((request) async {
        requests.add(request);
        if (request.method == 'POST' && request.url.query.contains('uploads')) {
          return http.Response('<UploadId>upload-1</UploadId>', 200);
        }
        if (request.method == 'PUT') {
          return http.Response('', 200, headers: {'etag': '"e"'});
        }
        return http.Response('<CompleteMultipartUploadResult/>', 200);
      });

      const mib = 1024 * 1024;
      final payload = [for (var i = 0; i < 6; i++) _bytes(mib)];
      final stored = await store.put(
        key: 'big.bin',
        bytes: Stream.fromIterable(payload),
      );

      final whole = TomBlobDigest();
      for (final part in payload) {
        whole.add(part);
      }
      expect(
        stored.digest,
        whole.close(),
        reason: 'the digest is of the object, not of one part',
      );

      // The last request rewrites the metadata in place rather than re-uploading
      // the object: a copy onto the same key with REPLACE.
      final last = requests.last;
      expect(last.method, 'PUT');
      expect(last.headers['x-amz-metadata-directive'], 'REPLACE');
      expect(last.headers['x-amz-copy-source'], '/examplebucket/big.bin');
      expect(last.headers[TomS3BlobStore.digestHeader], stored.digest);
      expect(last.bodyBytes, isEmpty);
    });
  });

  // Moving a deployment's files to a different backend means knowing what to
  // move, and the blob contract cannot enumerate itself. The rows can: a
  // `@TomFileReference` column *is* the index of what a deployment stored. What
  // is asserted here is the part that runs before and after the sweep — the
  // guards. The sweep itself needs real rows and lives in the db suite.
  group('TomBlobMigration guards what it cannot see', () {
    // The file columns come from the reflected entity, so the mirror has to be
    // registered before the first `findFileColumns` — this is the only group in
    // the file that reads annotations rather than bytes.
    setUpAll(initializeReflection);

    test('it refuses to run inside a request', () async {
      // The trap this exists for. `findAll` applies the entity's row scope
      // (C-3) and masks the columns the principal may not read (C-4), so under
      // a request principal the sweep would migrate *that principal's view* and
      // report success — and a masked file column reads back `null`, which is
      // indistinguishable from a row holding no file. A migration that quietly
      // moved a subset is the worst outcome available, so it refuses.
      final repository = _ListRepository<FixtureDocumentRecord>([]);
      final migration = TomBlobMigration(
        source: TomMemoryBlobStore(),
        target: TomMemoryBlobStore(),
      );

      await runZoned(() async {
        await expectLater(
          migration.migrate(repository),
          throwsA(
            isA<TomBlobMigrationException>().having(
              (e) => e.key,
              'key',
              'storage.migration.scoped_run',
            ),
          ),
        );
      }, zoneValues: {TomPrincipal: TomPrincipal(authenticated: true)});

      expect(
        repository.pages,
        0,
        reason: 'it read rows before deciding it should not',
      );
    });

    test('allowScopedRun is how an operator says the scope opens', () async {
      // The escape, and it is explicit rather than a default: a deployment
      // whose scope resolver opts out for its system principal has a legitimate
      // reason to run inside one.
      final repository = _ListRepository<FixtureDocumentRecord>([]);
      final migration = TomBlobMigration(
        source: TomMemoryBlobStore(),
        target: TomMemoryBlobStore(),
        allowScopedRun: true,
      );

      final report = await runZoned(
        () => migration.migrate(repository),
        zoneValues: {TomPrincipal: TomPrincipal(authenticated: true)},
      );
      expect(report.rows, 0);
      expect(repository.pages, greaterThan(0));
    });

    test('an entity that stores no files is refused, not swept', () {
      // Naming it is the point: a migration that reported "0 blobs" for an
      // entity with no file columns would look exactly like one that worked.
      expect(
        TomBlobMigration(
          source: TomMemoryBlobStore(),
          target: TomMemoryBlobStore(),
        ).migrate(_ListRepository<TomBlobChunkRow>([])),
        throwsA(
          isA<TomBlobMigrationException>().having(
            (e) => e.key,
            'key',
            'storage.migration.no_file_columns',
          ),
        ),
      );
    });

    test(
      'a copy that does not match what was read stops the migration',
      () async {
        final source = TomMemoryBlobStore();
        await source.putBytes(key: 'fixture/a.txt', bytes: utf8.encode('abc'));
        final row = FixtureDocumentRecord()..attachment = 'fixture/a.txt';

        await expectLater(
          TomBlobMigration(
            source: source,
            target: _LyingBlobStore(),
          ).migrate(_ListRepository<FixtureDocumentRecord>([row])),
          throwsA(
            isA<TomBlobMigrationException>()
                .having(
                  (e) => e.key,
                  'key',
                  'storage.migration.verification_failed',
                )
                .having(
                  (e) => e.parameters?['key'],
                  'key parameter',
                  'fixture/a.txt',
                ),
          ),
        );
      },
    );

    test('a row holding no key costs nothing', () async {
      // The ordinary case in any table with an optional attachment, and it must
      // not become a `describe` per empty column against an object store.
      final source = TomMemoryBlobStore();
      final target = TomMemoryBlobStore();
      final report = await TomBlobMigration(source: source, target: target)
          .migrate(
            _ListRepository<FixtureDocumentRecord>([
              FixtureDocumentRecord(),
              FixtureDocumentRecord()..attachment = '',
            ]),
          );
      expect(report.rows, 2);
      expect(report.copied, 0);
      expect(report.claimed, isEmpty);
      expect(report.complete, isTrue);
    });
  });

  // A store grew without limit and forgot nothing. Quota and expiry are the
  // deployment's — they are questions about *its* data, answered against its own
  // record of what it stored — but one operation that record cannot assemble
  // from outside is the reclaim: deleting a partition key by key is a call per
  // blob where a prefix delete is a call per partition. So the module owns that
  // one primitive and nothing else of retention.
  group('deletePrefix (the reclaim retention is built on)', () {
    /// A store of each kind that can be built without infrastructure, seeded
    /// with three blobs across two day partitions plus one deliberate trap.
    Future<Map<String, TomBlobStore>> seeded() async {
      final root = Directory.systemTemp.createTempSync('tom_purge_');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final stores = <String, TomBlobStore>{
        'memory': TomMemoryBlobStore(),
        'directory': TomDirectoryBlobStore(root),
      };
      for (final store in stores.values) {
        for (final key in const [
          '2026/07/08/a.bin',
          '2026/07/08/b.bin',
          '2026/07/09/c.bin',
          // The sibling a character-wise prefix would take with it.
          '2026/070/d.bin',
        ]) {
          await store.putBytes(key: key, bytes: const [1, 2, 3]);
        }
      }
      return stores;
    }

    test('a partition goes in one call, on every backend that can', () async {
      for (final entry in (await seeded()).entries) {
        final store = entry.value;
        expect(store.supportsPrefixDelete, isTrue, reason: entry.key);
        expect(await store.deletePrefix('2026/07/08'), 2, reason: entry.key);
        expect(
          await store.exists('2026/07/08/a.bin'),
          isFalse,
          reason: entry.key,
        );
        expect(
          await store.exists('2026/07/08/b.bin'),
          isFalse,
          reason: entry.key,
        );
        expect(
          await store.exists('2026/07/09/c.bin'),
          isTrue,
          reason: entry.key,
        );
      }
    });

    test('the prefix is matched by segment, never by characters', () async {
      // The defect this rules out: `2026/07` taking `2026/070` with it. A
      // string prefix that can reach a sibling is an ordinary convenience
      // everywhere except in a delete, where it is how a month's retention
      // takes the next month.
      for (final entry in (await seeded()).entries) {
        final store = entry.value;
        expect(await store.deletePrefix('2026/07'), 3, reason: entry.key);
        expect(
          await store.exists('2026/070/d.bin'),
          isTrue,
          reason: '${entry.key} took the sibling partition',
        );
      }
    });

    test('a prefix naming one blob removes that blob', () async {
      // The segment rule read the other way: a key is under itself. Without
      // this a retention pass over a key space with no partitions — which
      // `keyFor` does not produce but an application may — would silently
      // reclaim nothing.
      for (final entry in (await seeded()).entries) {
        final store = entry.value;
        expect(
          await store.deletePrefix('2026/07/09/c.bin'),
          1,
          reason: entry.key,
        );
        expect(
          await store.exists('2026/07/09/c.bin'),
          isFalse,
          reason: entry.key,
        );
        expect(
          await store.exists('2026/07/08/a.bin'),
          isTrue,
          reason: entry.key,
        );
      }
    });

    test('a prefix holding nothing answers zero', () async {
      for (final entry in (await seeded()).entries) {
        expect(await entry.value.deletePrefix('2027/01'), 0, reason: entry.key);
      }
    });

    test(
      'the directory backend counts blobs, not its own bookkeeping',
      () async {
        // Each blob has a `~meta` sidecar beside it, so a count of files in the
        // tree reports twice what was reclaimed — and tells a retention pass it
        // freed more than it did.
        final root = Directory.systemTemp.createTempSync('tom_purge_meta_');
        addTearDown(() => root.deleteSync(recursive: true));
        final store = TomDirectoryBlobStore(root);
        await store.putBytes(key: '2026/07/a.bin', bytes: const [1]);
        await store.putBytes(key: '2026/07/b.bin', bytes: const [2]);
        expect(
          root.listSync(recursive: true).whereType<File>().length,
          4,
          reason: 'the fixture is supposed to have a sidecar per blob',
        );
        expect(await store.deletePrefix('2026/07'), 2);
      },
    );

    test('an empty prefix is refused before any backend is touched', () {
      // It names every file there is, and a delete whose argument came from a
      // configuration value that turned out empty should not empty the store.
      // The stores below fail the test if a request or a statement reaches
      // them.
      for (final store in <TomBlobStore>[
        TomMemoryBlobStore(),
        TomDatabaseBlobStore(_UntouchableDataSource()),
        _s3(
          (request) => fail('the request reached the network: ${request.url}'),
        ),
      ]) {
        expect(
          () => store.deletePrefix(''),
          throwsA(
            isA<TomStorageException>()
                .having((e) => e.key, 'key', 'storage.blob.invalid_key')
                .having(
                  (e) => e.defaultUserMessage,
                  'message',
                  contains('every file'),
                ),
          ),
          reason: '$store',
        );
      }
    });

    test('an invalid prefix is refused like an invalid key', () {
      expect(
        () => TomMemoryBlobStore().deletePrefix('../escape'),
        throwsA(
          isA<TomStorageException>().having(
            (e) => e.key,
            'key',
            'storage.blob.invalid_key',
          ),
        ),
      );
    });

    test('a backend that cannot says so rather than answering zero', () {
      // "The purge found nothing" and "this backend cannot purge" must not be
      // the same answer: a deployment would learn the difference from a disk
      // filling up.
      expect(
        () => _WholeReadsOnlyBlobStore(const []).deletePrefix('2026/07'),
        throwsA(
          isA<TomStorageException>()
              .having(
                (e) => e.key,
                'key',
                'storage.blob.prefix_delete_unsupported',
              )
              .having((e) => e.parameters?['prefix'], 'prefix', '2026/07'),
        ),
      );
    });

    test(
      'a backend claiming the capability without the method fails loudly',
      () {
        // The default `doDeletePrefix` throws rather than returning zero, so
        // the half-finished backend reports a failure and not an empty purge.
        //
        // It arrives *wrapped*, and that is right rather than incidental. A
        // backend declaring `false` refuses before the translation and the
        // caller hears `prefix_delete_unsupported` directly — a condition a
        // caller asks about with `supportsPrefixDelete` and branches on. A
        // backend that claims the capability and forgets the method is a defect
        // in that backend, which is what `prefix_delete_failed` carrying the
        // cause says.
        expect(
          () => _ClaimsPrefixDelete().deletePrefix('2026/07'),
          throwsA(
            _translated(
              'storage.blob.prefix_delete_failed',
              'storage.blob.prefix_delete_unsupported',
            ),
          ),
        );
      },
    );

    test('the S3 backend lists, deletes in batches, and pages', () async {
      // S3 has no prefix delete: it has a paginated listing and a batched
      // delete, and this is those two. The cost is stated rather than hidden —
      // which is the difference between this and the `list` the contract
      // refused, where a caller would have been handed a paginated scan wearing
      // the shape of a map lookup.
      final requests = <http.Request>[];
      final store = _s3((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          final first = !request.url.queryParameters.containsKey(
            'continuation-token',
          );
          return http.Response(
            '<ListBucketResult>'
            '<Key>2026/07/08/a.bin</Key>'
            '<Key>2026/07/08/b.bin</Key>'
            // The sibling S3's own prefix match returns and the segment rule
            // filters out: `prefix=2026/07/08` matches `2026/07/080` too.
            '<Key>2026/07/080/z.bin</Key>'
            '<IsTruncated>${first ? 'true' : 'false'}</IsTruncated>'
            '${first ? '<NextContinuationToken>page-2</NextContinuationToken>' : ''}'
            '</ListBucketResult>',
            200,
          );
        }
        return http.Response('<DeleteResult/>', 200);
      });

      expect(await store.deletePrefix('2026/07/08'), 4);

      final lists = requests.where((r) => r.method == 'GET').toList();
      expect(lists, hasLength(2), reason: 'the second page was not fetched');
      expect(lists.first.url.queryParameters['list-type'], '2');
      expect(lists.first.url.queryParameters['prefix'], '2026/07/08');
      expect(lists.last.url.queryParameters['continuation-token'], 'page-2');

      final deletes = requests.where((r) => r.method == 'POST').toList();
      expect(deletes, hasLength(2));
      expect(deletes.first.url.queryParameters.containsKey('delete'), isTrue);
      expect(deletes.first.body, contains('<Key>2026/07/08/a.bin</Key>'));
      expect(
        deletes.first.body,
        isNot(contains('080')),
        reason: 'the sibling S3 matched by characters was deleted',
      );
      // Required by the protocol rather than chosen: S3 refuses a
      // `DeleteObjects` without it.
      expect(deletes.first.headers['content-md5'], isNotNull);
      expect(deletes.first.headers['authorization'], contains('content-md5'));
    });

    test('a failure S3 reports inside a 200 is still a failure', () async {
      // `Quiet` suppresses the per-key success entries, so anything left in the
      // body is a failure — and S3 reports those with a 200, which is the one
      // place the status code is not the answer.
      final store = _s3((request) async {
        if (request.method == 'GET') {
          return http.Response(
            '<ListBucketResult><Key>2026/07/a.bin</Key>'
            '<IsTruncated>false</IsTruncated></ListBucketResult>',
            200,
          );
        }
        return http.Response(
          '<DeleteResult><Error><Key>2026/07/a.bin</Key>'
          '<Code>AccessDenied</Code></Error></DeleteResult>',
          200,
        );
      });

      await expectLater(
        store.deletePrefix('2026/07'),
        throwsA(
          _translated(
            'storage.blob.prefix_delete_failed',
            'storage.s3.request_failed',
          ),
        ),
      );
    });

    test('an export store over a blob store reclaims a partition', () async {
      // The gap this closes: the adaptor used to answer `false`, on the
      // argument that widening the blob contract for the export module's
      // retention was the wrong direction. File storage then acquired the same
      // need of its own, and a prefix delete turned out not to be the listing
      // that argument was about.
      final blobs = TomMemoryBlobStore();
      final exports = TomBlobExportStore(blobs, keyPrefix: 'exports');
      for (final key in const ['2026/07/08/a.csv', '2026/07/09/b.csv']) {
        await exports.store(
          key: key,
          bytes: Stream.value(utf8.encode('x')),
          mediaType: 'text/csv',
        );
      }

      expect(exports.supportsPrefixDelete, isTrue);
      expect(await exports.deletePrefix('2026/07/08'), 1);
      expect(await exports.exists('2026/07/08/a.csv'), isFalse);
      expect(await exports.exists('2026/07/09/b.csv'), isTrue);
      // And it reached the *prefixed* key space, not the caller's.
      expect(blobs.keys, ['exports/2026/07/09/b.csv']);
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

  group('the database backend hands its write time to the bind boundary', () {
    // The defect this replaced: the store rendered `stored_at` itself, with a
    // `toIso8601String().substring(0, 19)` that had no `toUtc()` in it, and
    // took its reading from a local `DateTime.now()`. The read side parses
    // every `DateTime` column as UTC — so the value came back wrong by the
    // writing node's offset, and by a *different* amount per node in a
    // cluster. It was accidentally right on a UTC host, which is why nothing
    // caught it.
    //
    // What is asserted is the shape rather than the text: the store must hand
    // the data source a `DateTime` and let the bind boundary render it, which
    // is where `sqlInstant` lives and where every other instant in this package
    // is converted. A store that formats its own text is the defect, whatever
    // that text happens to say — so the *type* of the bound value is what fails
    // when it comes back.

    /// The instant every case injects: local, and at an offset from UTC on any
    /// host that has one. A UTC host cannot tell the two renderings apart,
    /// which is exactly how the original defect survived.
    final injected = DateTime(2026, 3, 14, 15, 9, 26, 535, 897);

    test('the write time is bound as a DateTime, not as text', () async {
      final datasource = _RecordingBlobDataSource();
      final store = TomDatabaseBlobStore(
        datasource,
        createSchema: false,
        clock: () => injected,
      );

      final stored = await store.putBytes(key: 'k', bytes: const [1, 2, 3]);

      final manifest = datasource.issued.lastWhere(
        (issued) => issued.params?.containsKey('storedAt') ?? false,
      );
      final bound = manifest.params!['storedAt'];

      expect(
        bound,
        isA<DateTime>(),
        reason:
            'a String here means the store formatted the instant itself, which '
            'is the defect: only the bind boundary applies sqlInstant',
      );
      expect(
        (bound as DateTime).microsecondsSinceEpoch,
        injected.microsecondsSinceEpoch,
        reason: 'the moment handed over must be the moment the clock read',
      );
      // And the descriptor the caller gets names the same moment, labelled.
      expect(stored.storedAt.isUtc, isTrue);
      expect(
        stored.storedAt.microsecondsSinceEpoch,
        injected.microsecondsSinceEpoch,
      );
    });

    test('the store reads the injected clock rather than the wall', () async {
      // Without this the case above proves nothing about the store: a store
      // that ignored the seam would still pass it on a host whose wall clock
      // happens to be close enough, and would pass every assertion about the
      // descriptor, which is built from the same reading either way.
      var reads = 0;
      final datasource = _RecordingBlobDataSource();
      final store = TomDatabaseBlobStore(
        datasource,
        createSchema: false,
        clock: () {
          reads++;
          return injected;
        },
      );

      await store.putBytes(key: 'k', bytes: const [1]);

      expect(reads, greaterThan(0));
    });
  });

  group('every backend reports storedAt as UTC', () {
    // An instant carrying no zone is not an instant. `storedAt` is the only
    // field of `TomStoredBlob` that denotes a moment, and every backend built
    // it from a local source — `DateTime.now()` on three of them, the
    // filesystem's `stat.modified` on the fourth — so a descriptor written in
    // Berlin and read in Denver disagreed with itself by the offset. Worse,
    // `DateTime.==` compares `isUtc` as well as the instant, so the value a
    // round trip through storage gave back did not compare equal to the one
    // `put` had just returned even on a single host.
    //
    // Normalising inside `TomStoredBlob` rather than at each construction site
    // is what makes this a property of the *type*: a backend added later cannot
    // forget it, and there is one place to read the rule. That is the same
    // arrangement `TomAuditAnchor` and `TomOAuthTokens` already use.
    //
    // The database backend needs a server; its round trip is asserted in
    // `file_storage_db_test.dart`.

    test('the descriptor normalises what it is given, rather than trusting '
        'its caller', () {
      // The single point the other cases depend on. A local `DateTime` is not
      // rejected — it is the ordinary thing a backend has in hand — it is
      // relabelled, and the instant it denotes must survive that exactly.
      final local = DateTime(2026, 3, 14, 15, 9, 26, 535, 897);
      final blob = TomStoredBlob(
        key: 'k',
        mediaType: 'text/plain',
        byteCount: 1,
        storedAt: local,
      );
      expect(blob.storedAt.isUtc, isTrue);
      expect(blob.storedAt, local.toUtc());
      expect(
        blob.storedAt.microsecondsSinceEpoch,
        local.microsecondsSinceEpoch,
        reason: 'relabelling must not move the moment',
      );
    });

    test('a value that is already UTC is left exactly as it is', () {
      // The other half: normalising must be idempotent, or a descriptor built
      // from a stored value would drift each time it was rebuilt.
      final utc = DateTime.utc(2026, 3, 14, 15, 9, 26, 535, 897);
      expect(
        TomStoredBlob(
          key: 'k',
          mediaType: 'text/plain',
          byteCount: 1,
          storedAt: utc,
        ).storedAt,
        utc,
      );
    });

    test('memory', () async {
      final store = TomMemoryBlobStore();
      final stored = await store.putBytes(key: 'k', bytes: const [1]);
      expect(stored.storedAt.isUtc, isTrue);
      expect((await store.describe('k'))!.storedAt.isUtc, isTrue);
    });

    test('directory', () async {
      // The backend worth naming separately: `describe` does not replay what
      // `put` recorded, it reads the file's `stat.modified`, which the platform
      // hands back in local time. So this is the one case where the conversion
      // is doing work rather than confirming a `DateTime.now()` was relabelled.
      final root = await Directory.systemTemp.createTemp('tom_blob_utc_test');
      addTearDown(() async {
        if (root.existsSync()) await root.delete(recursive: true);
      });
      final store = TomDirectoryBlobStore(root);
      final stored = await store.putBytes(key: 'k', bytes: const [1]);
      expect(stored.storedAt.isUtc, isTrue);

      final described = await store.describe('k');
      expect(described!.storedAt.isUtc, isTrue);
      // Same file, same moment: the mtime the store reports is the mtime the
      // filesystem holds, converted rather than reinterpreted.
      expect(
        described.storedAt,
        File('${root.path}/k').statSync().modified.toUtc(),
      );
    });

    test('s3', () async {
      // `put` has no server-supplied time to use — S3's PUT response carries
      // none — so it stamps its own, and that stamp is the one at risk.
      final store = _s3((request) async => http.Response('', 200));
      final stored = await store.putBytes(key: 'k', bytes: const [1]);
      expect(stored.storedAt.isUtc, isTrue);
    });

    test('s3 falls back to a UTC stamp when the object carries no date', () {
      // The fallback path inside `describe`: a HEAD without `last-modified`
      // (or with one that will not parse) still has to produce an instant, and
      // that manufactured one is as much a moment as a parsed one.
      final store = _s3(
        (request) async => http.Response(
          '',
          200,
          headers: const {
            'content-length': '1',
            'last-modified': 'not a date at all',
          },
        ),
      );
      return expectLater(
        store.describe('k').then((d) => d!.storedAt.isUtc),
        completion(isTrue),
      );
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
      // and the partial a write is staged in. Name either with a suffix the key
      // grammar can spell and a caller who picks `a.meta` or `a.part` is
      // addressing another caller's bookkeeping without either of them doing
      // anything wrong: `.` is an ordinary key character, and only the segments
      // `.` and `..` are reserved.

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

  group('TomDatabaseBlobStore, on what needs no database', () {
    // Everything else this store does needs a real driver and lives in
    // `file_storage_db_test.dart`. What a construction check must *not* need is
    // a database, which is the whole point of moving it to construction:
    // `_UntouchableDataSource` fails the test if the store touches its data
    // source, so these cases assert the refusal and its timing at once.
    //
    // The `.named` factory and the registry reach the same check by delegating
    // to the constructor below, and the route a `chunkSize: 0` in YAML actually
    // takes is asserted end to end where a data source exists to register —
    // `file_storage_db_test.dart`, 'a database store built from configuration'.

    Matcher refusesChunkSize(int chunkSize) => throwsA(
      isA<TomStorageException>()
          .having(
            (e) => e.key,
            'key',
            'storage.database.chunk_size_not_positive',
          )
          .having((e) => e.parameters?['chunkSize'], 'chunkSize', chunkSize),
    );

    test('a chunk size of zero is refused at construction', () {
      // Not a preference about efficiency: `doPut` slices its incoming events
      // with `(chunkSize - buffer.length).clamp(0, ...)`, which is 0 for every
      // iteration when `chunkSize` is 0, so `offset` never advances and the
      // upload loops forever. The store cannot report that itself — a hung
      // request has nothing to throw — so construction is the last moment at
      // which the deployment can still be told.
      expect(
        () => TomDatabaseBlobStore(_UntouchableDataSource(), chunkSize: 0),
        refusesChunkSize(0),
      );
    });

    test('a negative chunk size is refused the same way', () {
      // The clamp floors at 0, so a negative size is the identical hang rather
      // than a different failure, and deserves the identical answer.
      expect(
        () => TomDatabaseBlobStore(_UntouchableDataSource(), chunkSize: -1),
        refusesChunkSize(-1),
      );
    });

    test('one byte is odd but legal, and the default is accepted', () {
      // The other half of a validity check, without which "refuses everything"
      // would pass the two above. One byte per row is a terrible configuration
      // and a working one; the boundary is positivity, not sensibleness.
      expect(
        TomDatabaseBlobStore(_UntouchableDataSource(), chunkSize: 1).chunkSize,
        1,
      );
      expect(
        TomDatabaseBlobStore(_UntouchableDataSource()).chunkSize,
        TomDatabaseBlobStore.defaultChunkSize,
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

    test('a repeated query parameter signs every value, in order', () {
      // SigV4 canonicalises *every* parameter, sorted by name and then by
      // value. Reading `uri.queryParameters` — a `Map<String, String>` — keeps
      // only the last value of a repeated name, so `?x=2&x=1` would be signed
      // over `x=1` alone while both were sent, and the store would answer
      // SignatureDoesNotMatch with nothing in this module able to say why.
      //
      // Latent rather than live: no request this store issues repeats a name.
      // It is pinned because `canonicalQuery` is a public static documented as
      // a SigV4 implementation, so the caller who first repeats one will be
      // someone signing a request this module never makes.
      expect(
        TomAwsV4Signer.canonicalQuery(Uri.parse('https://h/k?x=2&x=1')),
        'x=1&x=2',
      );

      // Sorted by value, not left in the order they were written — which is
      // the half of the rule a single repeated pair cannot distinguish, since
      // `x=1&x=2` is both the sorted order and the insertion order above.
      expect(
        TomAwsV4Signer.canonicalQuery(Uri.parse('https://h/k?b=1&a=2&a=1')),
        'a=1&a=2&b=1',
      );

      // An empty value is a value: it sorts first and keeps its `=`. This is
      // the case a naive rewrite drops — and dropping it would break every
      // multipart upload, whose initiate call is `?uploads` and nothing else.
      expect(
        TomAwsV4Signer.canonicalQuery(Uri.parse('https://h/k?x=1&x=')),
        'x=&x=1',
      );

      // Encoded before being compared, so the sort is over the bytes the
      // server re-derives rather than over what Dart decoded them into.
      expect(
        TomAwsV4Signer.canonicalQuery(Uri.parse('https://h/k?x=b%20c&x=b!')),
        'x=b%20c&x=b%21',
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

    test("a rejected request names the caller's key, not the object "
        'path', () async {
      // `parameters['key']` is a contract rather than a label: every other
      // error in both storage modules puts the caller's key there, and a
      // handler that logs or renders it cannot know that one backend meant
      // something else. The path the test above pins —
      // `/examplebucket/tenant-7/k.txt` — is a value the caller never supplied
      // and cannot look up, and in a multi-tenant deployment the prefix *is*
      // the tenant.
      //
      // Driven across the whole surface rather than one method, because the
      // leak was in `_send`, which five of them share, while the two paths that
      // build their own failure were already correct. A test of a single
      // method would have passed either way depending on which one it picked.
      final store = _s3(
        (request) async => http.Response(
          '<Error><Code>AccessDenied</Code><Message>no</Message></Error>',
          403,
        ),
        keyPrefix: 'tenant-7',
      );

      final operations = <String, Future<void> Function()>{
        'put': () => store.putBytes(key: 'a.txt', bytes: utf8.encode('x')),
        'get': () => store.getBytes('a.txt'),
        'describe': () => store.describe('a.txt'),
        'exists': () => store.exists('a.txt'),
        'delete': () => store.delete('a.txt'),
      };

      // Collected and compared as a whole rather than asserted in the loop: a
      // per-iteration expectation stops at the first leak, and which methods
      // leak is the whole diagnosis.
      final reported = <String, Object?>{};
      for (final entry in operations.entries) {
        try {
          await entry.value();
          fail('${entry.key} did not fail');
        } on TomStorageException catch (error) {
          reported[entry.key] = error.parameters?['key'];
        }
      }
      expect(reported, {
        'put': 'a.txt',
        'get': 'a.txt',
        'describe': 'a.txt',
        'exists': 'a.txt',
        'delete': 'a.txt',
      });
    });

    test('a rejected request still reports where it went, under a name that '
        'says so', () async {
      // Renaming the leak away would have cost the one thing it was good for.
      // Which bucket, which prefix, and whether the URI was even built the way
      // the deployment intended is what an operator reading a 403 needs, and
      // `autoLog: true` means these go to a log. So the path stays — under
      // `objectPath`, where a handler rendering parameters wholesale is
      // visibly opting into infrastructure detail rather than being handed it
      // by a field called `key`.
      final store = _s3(
        (request) async => http.Response(
          '<Error><Code>AccessDenied</Code><Message>no</Message></Error>',
          403,
        ),
        keyPrefix: 'tenant-7',
      );

      // The caller hears `probe_failed`, the same key the directory backend
      // would give for the same fault; the S3 detail is one level down. Both
      // halves matter: the branch is backend-independent, the diagnosis is not
      // lost.
      await expectLater(
        store.describe('a.txt'),
        throwsA(
          _translated('storage.blob.probe_failed', 'storage.s3.request_failed')
              .having(
                (e) => _backendFault(e).parameters?['objectPath'],
                'objectPath',
                '/examplebucket/tenant-7/a.txt',
              )
              // The store operation, not the HTTP verb. `_send` used to report
              // the method, so a failed part upload and a failed single PUT
              // were both `PUT` and told an operator nothing about which one
              // stopped — while the two paths building their own failure named
              // `get` and `complete`. One parameter, one vocabulary.
              .having(
                (e) => _backendFault(e).parameters?['operation'],
                'operation',
                'describe',
              )
              .having(
                (e) => _backendFault(e).parameters?['status'],
                'status',
                403,
              )
              .having(
                (e) => _backendFault(e).parameters?['code'],
                'code',
                'AccessDenied',
              ),
        ),
      );
    });

    test('every operation names itself in a rejected request', () async {
      // The `operation` parameter is only worth having if it distinguishes the
      // requests a single method issues. A multipart upload makes four
      // different ones and three of them are POST or PUT, so the HTTP verb
      // cannot tell them apart — which is what it was reporting.
      var partsSeen = 0;
      final store = _s3((request) async {
        if (request.method == 'POST' && request.url.query.contains('uploads')) {
          return http.Response('<UploadId>upload-1</UploadId>', 200);
        }
        if (request.method == 'PUT') {
          partsSeen++;
          return http.Response(
            '<Error><Code>SlowDown</Code><Message>later</Message></Error>',
            503,
          );
        }
        return http.Response('', 204);
      }, keyPrefix: 'tenant-7');

      const mib = 1024 * 1024;
      await expectLater(
        store.put(
          key: 'big.bin',
          bytes: Stream.fromIterable([for (var i = 0; i < 6; i++) _bytes(mib)]),
        ),
        throwsA(
          _translated('storage.blob.write_failed', 'storage.s3.request_failed')
              .having(
                (e) => _backendFault(e).parameters?['operation'],
                'operation',
                'uploadPart',
              )
              .having(
                (e) => _backendFault(e).parameters?['key'],
                'key',
                'big.bin',
              )
              .having(
                (e) => _backendFault(e).parameters?['objectPath'],
                'objectPath',
                '/examplebucket/tenant-7/big.bin',
              ),
        ),
      );
      expect(partsSeen, 1, reason: 'the first part failing ends the upload');
    });

    test('a key prefix that is not a key is refused at construction', () {
      // Worse here than anywhere else: this prefix is not re-validated, it is
      // joined and handed to `Uri.replace(pathSegments:)`. A `..` prefix became
      // a traversal segment in a *signed* request path rather than an error.
      for (final prefix in const ['..', '/tenant-7', 'a//b', 'tenant-7/']) {
        expect(
          // The handler makes "before any request is issued" an assertion
          // rather than a claim: reaching the network at all fails the test.
          () => _s3(
            (request) => fail('a request was issued: ${request.url}'),
            keyPrefix: prefix,
          ),
          throwsA(
            isA<TomStorageException>()
                .having((e) => e.key, 'key', 'storage.blob.invalid_key_prefix')
                .having((e) => e.parameters?['keyPrefix'], 'keyPrefix', prefix),
          ),
          reason: '"$prefix"',
        );
      }
    });

    test('a prefix and a key that each fit can still be refused together', () {
      // The one clause a valid prefix cannot settle at construction, because it
      // depends on the key it will be joined to. Both halves are inside
      // maxKeyLength and their join is not, and S3 would have accepted the
      // result — its own limit is 1024 — so nothing downstream would object to
      // a key this framework does not accept, and the same blob key would be
      // refused by every other backend. Reported against the *prefix*: that is
      // the half a deployment can shorten, and the half that is wrong for every
      // key this store will ever be asked for.
      final store = _s3(
        (request) => fail('the joined key reached the network: ${request.url}'),
        keyPrefix: 'p' * 400,
      );
      return _refusesEverywhere(
        store,
        'k' * 200,
        errorKey: 'storage.blob.invalid_key_prefix',
      );
    });

    test('a join of exactly the maximum is accepted', () async {
      // The other side of the same boundary, so that "too long" cannot quietly
      // become "as long as the limit". 300 + separator + 211 is maxKeyLength
      // exactly, and the request is expected to go out.
      late http.Request seen;
      final prefix = 'p' * 300;
      final key = 'k' * (TomBlobStore.maxKeyLength - prefix.length - 1);
      final store = _s3((request) async {
        seen = request;
        return http.Response('', 200);
      }, keyPrefix: prefix);
      await store.putBytes(key: key, bytes: utf8.encode('x'));
      expect(seen.url.path, '/examplebucket/$prefix/$key');
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

        // Selected on `partNumber` rather than on the method: a multipart
        // upload ends with a *fourth* PUT that carries no part, the copy onto
        // the same key that records the object's digest once the last part has
        // been seen. Its own assertions live in the digest group.
        final uploads = requests
            .where((r) => r.url.queryParameters.containsKey('partNumber'))
            .toList();
        expect(uploads.map((r) => r.url.queryParameters['partNumber']), [
          '1',
          '2',
          '3',
        ]);
        for (final part in uploads) {
          expect(part.url.queryParameters['uploadId'], 'upload-7');
        }
        expect(uploads.map((r) => r.bodyBytes.length), [5 * mib, 5 * mib, mib]);

        final complete = requests.firstWhere(
          (r) => r.method == 'POST' && !r.url.query.contains('uploads'),
        );
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
          _translated(
            'storage.blob.write_failed',
            'storage.s3.request_failed',
          ).having(
            (e) => _backendFault(e).parameters?['code'],
            'code',
            'SlowDown',
          ),
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
          _translated(
            'storage.blob.write_failed',
            'storage.s3.no_upload_id',
          ).having(
            (e) => _backendFault(e).parameters?['key'],
            'key parameter',
            'big.bin',
          ),
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
            _translated(
              'storage.blob.write_failed',
              'storage.s3.part_without_etag',
            ).having(
              (e) => _backendFault(e).parameters?['partNumber'],
              'partNumber',
              1,
            ),
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

    test('a download that fails after the first bytes is still a named '
        'storage error', () async {
      // The longest-lived operation the module has, and the one place a
      // transport error is most likely to arrive *after* the call that could
      // have translated it returned. Everything before the first byte is
      // covered by the 404 and 5xx cases above; this covers everything after.
      //
      // A caller has been taught to catch `TomStorageException`, so a
      // `ClientException` — a type from `package:http` — reaching it mid-
      // download would be the module's abstraction leaking at exactly the
      // point the caller is least able to do anything about it.
      final store = _s3Streaming(
        (request, _) async => http.StreamedResponse(
          _failingStream(
            [utf8.encode('the first part')],
            error: http.ClientException(
              'Connection reset by peer',
              request.url,
            ),
          ),
          200,
        ),
      );

      await expectLater(
        store.get('big.bin').toList(),
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.blob.read_failed')
              .having(
                (e) => e.parameters?['key'],
                "the caller's key",
                'big.bin',
              )
              // The transport error is kept rather than summarised: the caller
              // needs a key it can branch on, whoever reads the log needs the
              // reason the socket actually died.
              .having(
                (e) => e.rootException,
                'rootException',
                isA<http.ClientException>(),
              ),
        ),
      );
    });

    test('the bytes that arrived before a mid-download failure are still '
        'delivered', () async {
      // Translating the error must not turn a partial download into an empty
      // one. A consumer that has already written the first bytes to a file and
      // then sees the failure can truncate; a consumer handed nothing at all
      // cannot tell a broken download from an empty object.
      final store = _s3Streaming(
        (request, _) async => http.StreamedResponse(
          _failingStream(
            [utf8.encode('the first part')],
            error: http.ClientException(
              'Connection reset by peer',
              request.url,
            ),
          ),
          200,
        ),
      );

      final received = <int>[];
      await expectLater(
        store.get('big.bin').forEach(received.addAll),
        throwsA(isA<TomStorageException>()),
      );
      expect(utf8.decode(received), 'the first part');
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

    test('the answer is a recent observation, not a fact', () async {
      // The documented caveat, demonstrated rather than asserted in prose.
      // `TomBlobStore.delete` promises an exact boolean on the backends that
      // can delete conditionally and a best-effort one here, because S3 has no
      // conditional delete and the probe and the request are two calls. This is
      // the window: the object appears between them, the DELETE removes bytes
      // this store never saw, and `false` is what the caller is told.
      var probed = false;
      final store = _s3((request) async {
        if (request.method == 'HEAD') {
          probed = true;
          // Not there *yet*.
          return http.Response('', 404);
        }
        return http.Response('', 204);
      });

      // Answered from the probe, so the DELETE is never sent and the object a
      // concurrent writer is about to create survives — which is the benign
      // half of the race.
      expect(await store.delete('racing.txt'), isFalse);
      expect(probed, isTrue);
    });

    test('two deletes of one key can both answer true', () async {
      // The other half, and the one that misleads: the probe says yes for both
      // callers, so both send a DELETE and both report having removed
      // something. Only one did. A caller that must not see this holds a lock
      // of its own — nothing in a storage API can supply one.
      final store = _s3(
        (request) async =>
            http.Response('', request.method == 'DELETE' ? 204 : 200),
      );

      final answers = await Future.wait([
        store.delete('contended.txt'),
        store.delete('contended.txt'),
      ]);
      expect(answers, [isTrue, isTrue]);
    });

    test('the backends that can delete conditionally answer exactly', () async {
      // The other side of the caveat, so "exact on the others" is a checked
      // claim rather than a sentence. One operation answers both questions
      // there, so a second delete of the same key is `false` with no window in
      // which it could be anything else.
      final root = Directory.systemTemp.createTempSync('tom_delete_');
      addTearDown(() => root.deleteSync(recursive: true));
      for (final store in <TomBlobStore>[
        TomMemoryBlobStore(),
        TomDirectoryBlobStore(root),
      ]) {
        await store.putBytes(key: 'k.bin', bytes: const [1]);
        expect(await store.delete('k.bin'), isTrue, reason: '$store');
        expect(await store.delete('k.bin'), isFalse, reason: '$store');
      }
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

  group('a caller hears the operation, not the backend', () {
    // The module's headline: "a backend that lets those through makes the
    // caller's error handling depend on which backend it was configured with".
    // The translation used to catch `TomStorageException` by *type*, which is
    // also what every backend raises its own failures as — so for one fault a
    // caller heard `storage.s3.request_failed` on S3 and
    // `storage.blob.write_failed` on the directory backend, which is exactly
    // what the four generic keys were introduced to prevent.

    /// A store whose every operation fails with [error].
    TomBlobStore failing(Object error) => _ThrowingBlobStore(error);

    test(
      'a backend-specific storage key is translated on every method',
      () async {
        final store = failing(
          TomStorageException(
            'storage.s3.request_failed',
            'no',
            parameters: {'status': 503},
          ),
        );
        for (final method in _everyMethod(store, 'a.txt').entries) {
          await expectLater(
            method.value(),
            throwsA(
              isA<TomStorageException>().having(
                (e) => e.key,
                'key',
                startsWith('storage.blob.'),
              ),
            ),
            reason: '${method.key} must not report a backend key',
          );
        }
      },
    );

    test('the backend exception survives as rootException', () async {
      // The other half of the decision. Wrapping is what makes the key
      // branchable; keeping the original is what keeps the fault diagnosable —
      // a 403 and a 503 are still told apart in a log, they are simply no
      // longer part of the contract code is written against.
      final backend = TomStorageException(
        'storage.s3.request_failed',
        'no',
        parameters: {'status': 503, 'code': 'SlowDown'},
      );
      await expectLater(
        failing(backend).describe('a.txt'),
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.blob.probe_failed')
              .having((e) => e.rootException, 'rootException', same(backend)),
        ),
      );
    });

    test(
      'every pass-through key reaches the caller as it was raised',
      () async {
        // The list is the contract, so it is asserted as a list rather than one
        // key at a time: a key quietly dropped from it would otherwise only
        // surface as whichever caller stopped being able to branch.
        for (final key in TomBlobStore.passThroughErrorKeys) {
          final raised = TomStorageException(key, 'the module\'s own answer');
          await expectLater(
            failing(raised).describe('a.txt'),
            throwsA(same(raised)),
            reason: '$key is one of the module\'s own answers',
          );
        }
      },
    );

    test('the pass-through list is the five the module raises itself', () {
      // Pinned by name, because membership is a judgement — "raised by code
      // every backend shares, or by a rule every backend is held to" — and a
      // key added without that argument being made is the drift this guards.
      // `same_key` earns it on both counts: it is raised by the contract's own
      // key check, before any backend is reached, and every backend is held to
      // the rule. Wrapped as `copy_failed` instead, it would tell a caller the
      // storage broke when what broke was their arithmetic.
      expect(TomBlobStore.passThroughErrorKeys, {
        'storage.blob.not_found',
        'storage.blob.invalid_key',
        'storage.blob.invalid_key_prefix',
        'storage.blob.missing_chunk',
        'storage.blob.same_key',
      });
      expect(
        TomBlobStore.passThroughErrorKeys.intersection({
          for (final operation in TomBlobStoreOperation.values)
            operation.errorKey,
        }),
        isEmpty,
        reason:
            'an operation key is what a translation produces, never what '
            'passes through it',
      );
    });

    test('a read translates without buffering what already arrived', () async {
      // `get` cannot go through `_translating` — an `async*` body owns its own
      // `try` — so it carries its own copy of the rule, and this is the test
      // that keeps the two in step. The partial delivery is asserted alongside,
      // because the reason `get` is written that way is that draining the
      // backend's stream first would turn every interrupted download into an
      // empty one.
      final store = _ThrowingBlobStore(
        TomStorageException('storage.s3.request_failed', 'no'),
        afterChunks: const [
          [1, 2, 3],
        ],
      );
      final delivered = <int>[];
      await expectLater(
        store.get('a.txt').forEach(delivered.addAll),
        throwsA(
          _translated('storage.blob.read_failed', 'storage.s3.request_failed'),
        ),
      );
      expect(delivered, [1, 2, 3]);
    });

    test('a read still answers not_found as itself', () async {
      final store = _ThrowingBlobStore(TomBlobStore.notFound('a.txt'));
      await expectLater(
        store.get('a.txt').drain<void>(),
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

  group('TomBlobStoreInfo (registry and configuration)', () {
    tearDown(TomBlobStoreInfo.closeAll);

    test('a ready-made store can be registered as the default', () async {
      final store = TomMemoryBlobStore();
      TomBlobStoreInfo.register('files', store, asDefault: true);
      expect(TomBlobStoreInfo.storeNamed('files'), same(store));
      expect(TomBlobStoreInfo.defaultStore, same(store));
      expect(TomBlobStoreInfo.hasDefaultStore, isTrue);
    });

    test(
      'a store handed over as an instance describes itself buildably',
      () async {
        final store = TomMemoryBlobStore();
        final info = TomBlobStoreInfo.register('files', store);

        // The configured path has its `.type` asserted further down; this is
        // the other half of the same claim and the half that was missing. An
        // entry naming a type its own `open()` cannot resolve is not a
        // description of itself, only a label that happens to be a string.
        expect(info.type, TomBlobStoreInfo.providedType);

        // Self-consistent means the entry can act on what it says about
        // itself. This used to raise `unknown_backend` — the entry's own type
        // was absent from the one table its own `open()` consults.
        await info.open();
        expect(TomBlobStoreInfo.storeNamed('files'), same(store));
      },
    );

    test(
      'the provided type is not a backend a configuration can name',
      () async {
        // The type names how the store arrived, not a way to build one from
        // settings: there is no instance in a YAML file to hand over. Making
        // `open()` work by adding it to the backend table would have bought
        // self-consistency by advertising a configurable backend that cannot
        // be configured, so this pins the boundary the fix chose.
        expect(
          TomBlobStoreInfo.backendTypes,
          isNot(contains(TomBlobStoreInfo.providedType)),
        );
        await expectLater(
          TomBlobStoreInfo.initializeBlobStores({
            'files': {'type': TomBlobStoreInfo.providedType},
          }),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.registry.unknown_backend',
            ),
          ),
        );
      },
    );

    test(
      'closeAll then reopen returns the store that was handed over',
      () async {
        final store = TomMemoryBlobStore();
        final info = TomBlobStoreInfo.register('files', store);
        await TomBlobStoreInfo.closeAll();
        expect(TomBlobStoreInfo.stores, isEmpty);

        await info.open();

        // The registry hands back what it was given, because it cannot rebuild
        // an instance it did not build. That is the honest answer rather than a
        // convenient one — and `close()` is idempotent by contract, so the
        // store is usable rather than merely present.
        expect(TomBlobStoreInfo.storeNamed('files'), same(store));
        await store.putBytes(
          key: 'reopened.txt',
          bytes: utf8.encode('still here'),
        );
        expect(utf8.decode(await store.getBytes('reopened.txt')), 'still here');
      },
    );

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

    test(
      'a store registered in code does not suppress the implicit default',
      () async {
        // The rule is about what the *configuration* says, and the test above
        // cannot tell: from an empty registry, "the stores this call made" and
        // "every store in the process" are the same collection, so a rule
        // stated over either one passes. Here they differ, which is the
        // ordinary case for a server that builds a store in code — a scratch
        // area, a test double, an application-specific archive — and then
        // reads its real configuration from YAML. Its configuration names one
        // place to put files, so there is nothing to resolve and it should not
        // have to say `default: true` to get what the dartdoc promises.
        TomBlobStoreInfo.register('scratch', TomMemoryBlobStore());

        final count = await TomBlobStoreInfo.initializeBlobStores({
          'files': {'type': 'memory'},
        });

        // `scratch` was registered first, so it is `stores.keys.first`. Both
        // halves of the old rule pointed at it: the count included it and the
        // name it picked *was* it. So this also pins that the implicit default
        // is chosen from the entries the call registered, not merely counted
        // over them.
        expect(count, 1, reason: 'the call configured exactly one store');
        expect(TomBlobStoreInfo.defaultStoreName, 'files');
        expect(
          TomBlobStoreInfo.storeNamed('scratch'),
          isA<TomMemoryBlobStore>(),
          reason: 'the code-registered store is still there, just not default',
        );
      },
    );

    test('a default nominated in code outranks the implicit rule', () async {
      // The other side of the guard. `asDefault: true` is a statement; the
      // single-store rule is an inference drawn when nothing was stated. An
      // inference must not overturn a statement, or a server could not name
      // its own default in code and then configure anything at all.
      final scratch = TomMemoryBlobStore();
      TomBlobStoreInfo.register('scratch', scratch, asDefault: true);

      await TomBlobStoreInfo.initializeBlobStores({
        'files': {'type': 'memory'},
      });

      expect(TomBlobStoreInfo.defaultStoreName, 'scratch');
      expect(TomBlobStoreInfo.defaultStore, same(scratch));
    });

    test('an explicit `default: true` still outranks a code default', () async {
      // Explicit against explicit, where the later word wins: configuration is
      // read after the code that registered the store, and a deployment saying
      // `default: true` means it. Distinguishes "an inference is weaker than a
      // statement" from "whatever was set first cannot be changed".
      TomBlobStoreInfo.register(
        'scratch',
        TomMemoryBlobStore(),
        asDefault: true,
      );

      await TomBlobStoreInfo.initializeBlobStores({
        'files': {'type': 'memory', 'default': true},
      });

      expect(TomBlobStoreInfo.defaultStoreName, 'files');
    });

    test('a non-store entry is not a store for either purpose', () async {
      // Entries that are not maps are skipped, and the only outward sign of
      // that is the returned count — so asserting the count alone would leave
      // the part that matters unpinned. The same collection decides the
      // implicit default: a scalar sitting beside the stores — a comment key,
      // a stray setting a hand-edited config grew — must not make a one-store
      // deployment look like a two-store one and take its default away.
      // Skipped and uncounted are the same claim, so this pins both.
      final count = await TomBlobStoreInfo.initializeBlobStores({
        'note': 'files live on the SAN now',
        'files': {'type': 'memory'},
      });

      expect(count, 1, reason: 'only the map-valued entry is a store');
      expect(TomBlobStoreInfo.stores.keys, ['files']);
      expect(TomBlobStoreInfo.defaultStoreName, 'files');
    });

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
      TomBlobStoreInfo.registerBackend('fixture', FixtureBlobStoreBackend.new);
      expect(TomBlobStoreInfo.backendTypes, contains('fixture'));
      await TomBlobStoreInfo.initializeBlobStores({
        'custom': {'type': 'fixture', 'label': 'archive'},
      });
      expect(TomBlobStoreInfo.storeNamed('custom'), isA<TomMemoryBlobStore>());
      expect(FixtureBlobStoreBackend.lastLabel, 'archive');
    });

    group('a settings key no backend field reads is refused', () {
      // A key that binds nothing is a mistake in a file the operator wrote.
      // Absorbed, it leaves the default it meant to change standing with
      // nothing to say so: `createSchma: false` creates the tables anyway.
      Matcher unknownSetting(String store, List<String> keys) => throwsA(
        isA<TomStorageException>()
            .having((e) => e.key, 'key', 'storage.registry.unknown_setting')
            .having((e) => e.parameters?['store'], 'store', store)
            .having((e) => e.parameters?['keys'], 'keys', keys),
      );

      test('on the memory backend', () async {
        await expectLater(
          TomBlobStoreInfo.initializeBlobStores({
            'scratch': {'type': 'memory', 'rooot': '/tmp'},
          }),
          unknownSetting('scratch', ['rooot']),
        );
      });

      test('on the directory backend', () async {
        await expectLater(
          TomBlobStoreInfo.initializeBlobStores({
            'files': {'type': 'directory', 'root': '/tmp', 'Root': '/srv'},
          }),
          unknownSetting('files', ['Root']),
        );
      });

      test('on the database backend, naming every offending key', () async {
        // Refused before the data source is looked up, so no database is
        // needed: `main` is registered nowhere in this suite.
        await expectLater(
          TomBlobStoreInfo.initializeBlobStores({
            'attachments': {
              'type': 'database',
              'datasource': 'main',
              'createSchma': false,
              'chunk_size': 4096,
            },
          }),
          unknownSetting('attachments', ['createSchma', 'chunk_size']),
        );
      });

      test('on the s3 backend', () async {
        await expectLater(
          TomBlobStoreInfo.initializeBlobStores({
            'archive': {
              'type': 's3',
              'endpoint': 'https://s3.example.com',
              'bucket': 'archive',
              'region': 'eu-central-1',
              'accessKeyId': 'id',
              'secretAccessKey': 'secret',
              'keyPrefx': 'tenant-7',
            },
          }),
          unknownSetting('archive', ['keyPrefx']),
        );
      });

      test('on a backend a deployment registered', () async {
        TomBlobStoreInfo.registerBackend(
          'fixture',
          FixtureBlobStoreBackend.new,
        );
        await expectLater(
          TomBlobStoreInfo.initializeBlobStores({
            'custom': {'type': 'fixture', 'lable': 'archive'},
          }),
          unknownSetting('custom', ['lable']),
        );
      });

      test('the registry\'s own keys are not passed to the backend', () async {
        // `type` and `default` are the registry's; neither is a field of any
        // backend, and both must pass the check on every backend.
        TomBlobStoreInfo.registerBackend(
          'fixture',
          FixtureBlobStoreBackend.new,
        );
        await TomBlobStoreInfo.initializeBlobStores({
          'scratch': {'type': 'memory', 'default': false},
          'custom': {'type': 'fixture', 'default': true},
        });
        expect(TomBlobStoreInfo.defaultStoreName, 'custom');
        expect(TomBlobStoreInfo.registryKeys, {'type', 'default'});
      });
    });

    test('a value its field cannot take names the setting', () async {
      await expectLater(
        TomBlobStoreInfo.initializeBlobStores({
          'attachments': {
            'type': 'database',
            'datasource': 'main',
            'chunkSize': 'large',
          },
        }),
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.registry.invalid_setting')
              .having((e) => e.parameters?['setting'], 'setting', 'chunkSize'),
        ),
      );
    });

    test('a number given as text is read as the number', () async {
      // An environment substitution always yields a string, so a part size
      // written `\${PART_SIZE:5242880}` arrives as text.
      await TomBlobStoreInfo.initializeBlobStores({
        'archive': {
          'type': 's3',
          'endpoint': 'https://s3.example.com',
          'bucket': 'archive',
          'region': 'eu-central-1',
          'accessKeyId': 'id',
          'secretAccessKey': 'secret',
          'partSize': '5242880',
        },
      });
      final store = TomBlobStoreInfo.storeNamed('archive') as TomS3BlobStore;
      expect(store.partSize, TomS3BlobStore.minimumPartSize);
    });

    test('a backend outside the reflection is refused by name', () async {
      // Its settings could be neither checked nor bound; building it with every
      // field at its default would be the silent drop over again.
      TomBlobStoreInfo.registerBackend('unreflected', _UnreflectedBackend.new);
      await expectLater(
        TomBlobStoreInfo.initializeBlobStores({
          'files': {'type': 'unreflected'},
        }),
        throwsA(
          isA<TomStorageException>()
              .having(
                (e) => e.key,
                'key',
                'storage.registry.backend_not_reflected',
              )
              .having(
                (e) => e.parameters?['backend'],
                'backend',
                '_UnreflectedBackend',
              ),
        ),
      );
    });

    test('an entry with no type reports an empty one, not the word null', () {
      // `type` is interpolated into the `unknown_backend` report and compared
      // against the backend table, so an entry whose settings name no type must
      // read as absent rather than as a backend called "null" -- which is what
      // a bare interpolation of a missing key produces, and which would send a
      // reader looking for a backend of that name. Found by mutation: dropping
      // the `?? ''` left the suite green.
      TomBlobStoreInfo.register('provided', TomMemoryBlobStore());
      final entry = TomBlobStoreInfo.getBlobStoreInfo('provided')!;
      expect(entry.type, TomBlobStoreInfo.providedType);

      expect(TomBlobStoreInfo('bare', const {}).type, isEmpty);
    });

    test('a provided entry does not defer to a backend of its type', () async {
      // Precedence between the two ways an entry can get its store. `open`
      // hands back a provided store before it consults the backend table;
      // reversed, a backend registered under the provided type's name would
      // build a different store from the one the caller handed over.
      //
      // Reached through `open` after `closeAll` rather than straight after
      // `register`, which assigns the store directly and so never consults
      // either.
      final own = TomMemoryBlobStore();
      TomBlobStoreInfo.registerBackend(
        TomBlobStoreInfo.providedType,
        FixtureBlobStoreBackend.new,
      );
      addTearDown(
        () => TomBlobStoreInfo.unregisterBackend(TomBlobStoreInfo.providedType),
      );

      final entry = TomBlobStoreInfo.register('either', own);
      await TomBlobStoreInfo.closeAll();
      await entry.open();

      expect(entry.store, same(own));
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

    group('an entry exists before its store does', () {
      // Every configured entry passes through the interval between
      // construction and `open`, and the two things that read the store during
      // it used to answer with a `LateError` -- which names the private field
      // and not the mistake.
      test('toString renders rather than throwing', () {
        final entry = TomBlobStoreInfo('files', <String, dynamic>{
          'type': 'directory',
        });
        expect(entry.toString(), 'TomBlobStoreInfo files directory <unopened>');
      });

      test('the rendering keeps its shape once the store is built', () async {
        // Same three fields either way, with the store in the third place
        // rather than the placeholder. A `toString` that dropped the field
        // when there was nothing to put in it would be the *short* form in
        // exactly the case a reader is trying to understand, and one a log
        // filter would have to know about.
        //
        // Compared against the store's own rendering rather than counted in
        // words: `TomMemoryBlobStore` renders as `TomMemoryBlobStore(0 blobs)`,
        // which contains a space, so a word count measures the store's
        // spelling and not this class's shape.
        final entry = TomBlobStoreInfo('files', <String, dynamic>{
          'type': 'memory',
        });
        await entry.open();
        expect(
          entry.toString(),
          'TomBlobStoreInfo files memory ${entry.store}',
        );
        expect(entry.toString(), isNot(contains('<unopened>')));
      });

      test('store names the fault instead of raising a LateError', () {
        final entry = TomBlobStoreInfo('files', <String, dynamic>{
          'type': 'directory',
        });
        expect(
          () => entry.store,
          throwsA(
            isA<TomStorageException>()
                .having(
                  (e) => e.key,
                  'key',
                  'storage.registry.store_not_opened',
                )
                .having((e) => e.parameters?['store'], 'store', 'files')
                .having((e) => e.parameters?['type'], 'type', 'directory'),
          ),
        );
      });

      test('isOpen answers without throwing, in both states', () async {
        final entry = TomBlobStoreInfo('files', <String, dynamic>{
          'type': 'memory',
        });
        expect(entry.isOpen, isFalse);
        await entry.open();
        expect(entry.isOpen, isTrue);
      });

      test('a failed open leaves an entry that still renders', () async {
        // The way an unopened entry is most often met: not held deliberately,
        // but left behind by the `open` whose failure is being diagnosed. The
        // rendering is what an error report interpolates, so it is the worst
        // place for a throw.
        final entry = TomBlobStoreInfo('files', <String, dynamic>{
          'type': 'directory',
        });
        await expectLater(
          entry.open(),
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.registry.missing_setting',
            ),
          ),
        );
        expect(entry.isOpen, isFalse);
        expect(entry.toString(), 'TomBlobStoreInfo files directory <unopened>');
        expect(
          () => entry.store,
          throwsA(
            isA<TomStorageException>().having(
              (e) => e.key,
              'key',
              'storage.registry.store_not_opened',
            ),
          ),
        );
      });

      test('a failed open registers nothing', () async {
        // `stores[name] = this` runs after the factory, so the registry never
        // holds an entry whose `store` would throw -- which is what lets
        // `closeAll` read `info.store` directly.
        final entry = TomBlobStoreInfo('files', <String, dynamic>{
          'type': 'nosuchbackend',
        });
        await expectLater(entry.open(), throwsA(isA<TomStorageException>()));
        expect(TomBlobStoreInfo.stores, isNot(contains('files')));
      });
    });
  });

  group('the defaults are declared once', () {
    // `database_blob_sql.dart` exists so that a table or column name "exists in
    // the code in exactly one place" — its own words. A default restated as a
    // literal somewhere else breaks that silently: both spellings agree today,
    // so no test can tell them apart by *value*, and the divergence only
    // appears when one of them is renamed and the other is not. The check has
    // to be on the declaration, not on what it currently says.
    //
    // Searched for by deriving the patterns from the constants, so this test
    // does not restate the names it is guarding either.
    //
    // Matched on a word boundary rather than as a quoted token: the names also
    // appear mid-string in hand-written SQL (`DELETE FROM tom_blob_chunk ...`),
    // which a quoted-token search silently misses — and that is exactly the
    // shape the fixtures had. The boundary also keeps `tom_blob` from matching
    // inside `tom_blob_chunk` or the `tom_blob_dir_test` temp-directory
    // prefixes, since `_` is a word character. Comment lines are skipped: prose
    // naming the default is documentation, not a second declaration.
    const declaringFile = 'database_blob_sql.dart';

    List<String> literalsIn(Iterable<String> names) {
      final patterns = {for (final name in names) name: RegExp('\\b$name\\b')};
      final offenders = <String>[];
      for (final root in const ['lib', 'test']) {
        for (final entry in Directory(root).listSync(recursive: true)) {
          if (entry is! File || !entry.path.endsWith('.dart')) continue;
          if (entry.path.endsWith(declaringFile)) continue;
          final lines = entry.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].trimLeft().startsWith('//')) continue;
            for (final entry2 in patterns.entries) {
              if (entry2.value.hasMatch(lines[i])) {
                offenders.add('${entry.path}:${i + 1} — ${entry2.key}');
              }
            }
          }
        }
      }
      return offenders;
    }

    test('no source spells a blob table name as a literal', () {
      // The registry did, three files from the constants, and defeated the
      // rule for every configured store: a rename would have left them all
      // pointing at the old name with nothing failing to compile. The fixtures
      // did too — `dropBlobTables` right above a `dropSchedulingTables` that
      // uses its constants, and two raw statements in the DB suite.
      expect(
        literalsIn(const [defaultBlobManifestTable, defaultBlobChunkTable]),
        isEmpty,
        reason: 'use the exported constants, not the names they hold',
      );
    });

    test('the two size defaults are declared once as well', () {
      // The same defect, on the two lines beside it: `256 * 1024` stood in the
      // primary constructor, the factory and the registry, and `8 * 1024 *
      // 1024` in two of the three. A number restated is worse than a name
      // restated, because nothing about it reads as a default.
      //
      // Scoped to this module, unlike the table names above, because a number
      // carries no namespace: `TomMultipartForm.globalSettingMaxFilePartBytes`
      // is also 8 MiB and is also declared exactly once, and it is a different
      // setting that happens to agree. Widening this scan would make it a test
      // of arithmetic coincidence rather than of the single-declaration rule.
      final offenders = <String>[];
      final module = Directory('lib/src/tomserver/file_storage');
      for (final entry in module.listSync(recursive: true)) {
        if (entry is! File || !entry.path.endsWith('.dart')) continue;
        final lines = entry.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('defaultChunkSize =') ||
              line.contains('defaultPartSize =')) {
            continue; // the one declaration each is allowed
          }
          if (RegExp(r'\b256 \* 1024\b|\b8 \* 1024 \* 1024\b').hasMatch(line)) {
            offenders.add('${entry.path}:${i + 1} — ${line.trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'use TomDatabaseBlobStore.defaultChunkSize / '
            'TomS3BlobStore.defaultPartSize',
      );
    });
  });
}

/// A backend whose class carries no `@tomReflector`, as a deployment's own
/// backend does until its reflection is regenerated.
class _UnreflectedBackend extends TomBlobStoreBackend {
  @override
  TomBlobStore build(String name) => TomMemoryBlobStore();
}

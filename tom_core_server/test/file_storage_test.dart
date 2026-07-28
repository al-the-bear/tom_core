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
}) =>
    TomS3BlobStore(
      endpoint: Uri.parse('https://s3.example.com'),
      bucket: 'examplebucket',
      region: 'us-east-1',
      credentials: _exampleCredentials,
      pathStyle: pathStyle,
      partSize: partSize,
      keyPrefix: keyPrefix,
      client: MockClient(handler),
    );

void main() {
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
      expect(
        TomBlobStore.isValidKey('a' * TomBlobStore.maxKeyLength),
        isTrue,
      );
    });

    test('validateKey returns the key or throws storage.blob.invalid_key', () {
      expect(TomBlobStore.validateKey('ok/key.txt'), 'ok/key.txt');
      expect(
        () => TomBlobStore.validateKey('../escape'),
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.blob.invalid_key'),
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
          isA<TomExportException>()
              .having((e) => e.key, 'key', 'export.store.invalid_key'),
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

    test('describe answers null for an absent key; get throws not_found',
        () async {
      expect(await store.describe('missing'), isNull);
      expect(await store.exists('missing'), isFalse);
      expect(
        () => store.getBytes('missing'),
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.blob.not_found'),
        ),
      );
    });

    test('delete reports whether anything was there', () async {
      await store.putBytes(key: 'k', bytes: utf8.encode('x'));
      expect(await store.delete('k'), isTrue);
      expect(await store.delete('k'), isFalse);
      expect(store.length, 0);
    });

    test('a stream that fails mid-way stores nothing', () async {
      await expectLater(
        store.put(key: 'k', bytes: _failingStream([utf8.encode('half')])),
        throwsA(isA<StateError>()),
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
        File('${root.path}/doc.bin${TomDirectoryBlobStore.metadataSuffix}')
            .existsSync(),
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
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.blob.write_failed'),
        ),
      );
      expect(File('${root.path}/k.bin').existsSync(), isFalse);
      expect(File('${root.path}/k.bin.part').existsSync(), isFalse);
    });

    test('a failed overwrite leaves the previous content intact', () async {
      await store.putBytes(key: 'k.bin', bytes: utf8.encode('original'));
      await expectLater(
        store.put(key: 'k.bin', bytes: _failingStream([utf8.encode('new')])),
        throwsA(isA<TomStorageException>()),
      );
      expect(utf8.decode(await store.getBytes('k.bin')), 'original');
    });

    test('delete removes the blob and its sidecar', () async {
      await store.putBytes(key: 'k.bin', bytes: utf8.encode('x'));
      expect(await store.delete('k.bin'), isTrue);
      expect(await store.delete('k.bin'), isFalse);
      expect(
        File('${root.path}/k.bin${TomDirectoryBlobStore.metadataSuffix}')
            .existsSync(),
        isFalse,
      );
    });

    test('a traversal key cannot reach outside the root', () async {
      expect(
        () => store.getBytes('../escape'),
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.blob.invalid_key'),
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
        contains('SignedHeaders=host;x-amz-content-sha256;'
            'x-amz-date;x-amz-security-token'),
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
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.s3.part_size_too_small'),
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
      final store = _s3(
        (request) async {
          seen = request;
          return http.Response('', 200);
        },
        pathStyle: false,
      );
      await store.putBytes(key: 'k.txt', bytes: utf8.encode('x'));
      expect(seen.url.host, 'examplebucket.s3.example.com');
      expect(seen.url.path, '/k.txt');
    });

    test('a key prefix namespaces every request', () async {
      late http.Request seen;
      final store = _s3(
        (request) async {
          seen = request;
          return http.Response('', 200);
        },
        keyPrefix: 'tenant-7',
      );
      await store.putBytes(key: 'k.txt', bytes: utf8.encode('x'));
      expect(seen.url.path, '/examplebucket/tenant-7/k.txt');
    });

    test('an object larger than the part size becomes a multipart upload',
        () async {
      final requests = <http.Request>[];
      final store = _s3((request) async {
        requests.add(request);
        if (request.method == 'POST' && request.url.query.contains('uploads')) {
          return http.Response('<InitiateMultipartUploadResult>'
              '<UploadId>upload-7</UploadId>'
              '</InitiateMultipartUploadResult>', 200);
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
        bytes: Stream.fromIterable([for (var i = 0; i < 11; i++) _bytes(mib)]),
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
        requests.where((r) => r.method == 'PUT').map((r) => r.bodyBytes.length),
        [5 * mib, 5 * mib, mib],
      );

      final complete = requests.last;
      expect(complete.method, 'POST');
      expect(complete.url.queryParameters['uploadId'], 'upload-7');
      expect(complete.body, contains('<PartNumber>3</PartNumber>'));
      expect(complete.body, contains('"etag-x"'));
    });

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
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.blob.not_found'),
        ),
      );
    });

    test('describe reads the object metadata, or answers null', () async {
      final store = _s3((request) async {
        expect(request.method, 'HEAD');
        if (request.url.path.endsWith('missing.txt')) {
          return http.Response('', 404);
        }
        return http.Response('', 200, headers: {
          'content-type': 'application/pdf',
          'content-length': '4096',
          'last-modified': 'Wed, 21 Oct 2015 07:28:00 GMT',
          TomS3BlobStore.fileNameHeader: 'report.pdf',
        });
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
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.registry.unknown_store'),
        ),
      );
      expect(
        () => TomBlobStoreInfo.defaultStore,
        throwsA(
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.registry.no_default_store'),
        ),
      );
      expect(TomBlobStoreInfo.hasDefaultStore, isFalse);
    });

    test('a single configured store becomes the default without saying so',
        () async {
      final count = await TomBlobStoreInfo.initializeBlobStores({
        'files': {'type': 'memory'},
      });
      expect(count, 1);
      expect(TomBlobStoreInfo.defaultStoreName, 'files');
      expect(TomBlobStoreInfo.defaultStore, isA<TomMemoryBlobStore>());
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
      final document = loadYaml('''
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
''') as YamlMap;
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
          isA<TomStorageException>()
              .having((e) => e.key, 'key', 'storage.registry.unknown_backend'),
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

  group('TomBlobExportStore (the export module over blob storage)', () {
    late TomMemoryBlobStore blobs;
    late TomBlobExportStore exports;

    setUp(() {
      blobs = TomMemoryBlobStore();
      exports = TomBlobExportStore(blobs, keyPrefix: 'exports');
    });

    test('an export is stored in the blob store under the prefix', () async {
      final stored = await exports.store(
        key: '2026/07/sales.csv',
        bytes: Stream.fromIterable([utf8.encode('a,b\n'), utf8.encode('1,2\n')]),
        mediaType: 'text/csv',
      );
      // The caller's key comes back, not the prefixed one: the prefix is the
      // adapter's business and a recorded key must be passable back to `open`.
      expect(stored.key, '2026/07/sales.csv');
      expect(stored.byteCount, 8);
      expect(stored.mediaType, 'text/csv');
      expect(blobs.keys, ['exports/2026/07/sales.csv']);
      expect(
        utf8.decode(
          await exports.open('2026/07/sales.csv').expand((c) => c).toList(),
        ),
        'a,b\n1,2\n',
      );
    });

    test('exists and delete work in the caller\'s key space', () async {
      await exports.store(
        key: 'r.csv',
        bytes: Stream.value(utf8.encode('x')),
        mediaType: 'text/csv',
      );
      expect(await exports.exists('r.csv'), isTrue);
      expect(await exports.delete('r.csv'), isTrue);
      expect(await exports.exists('r.csv'), isFalse);
      expect(await exports.delete('r.csv'), isFalse);
    });

    test('a missing export raises the export module\'s own error', () async {
      // Translated, not propagated: a caller of the export module should not
      // have to learn a storage error type because of the configured backend.
      expect(
        () => exports.open('gone.csv').toList(),
        throwsA(
          isA<TomExportException>()
              .having((e) => e.key, 'key', 'export.store.not_found')
              .having((e) => e.parameters?['key'], 'key parameter', 'gone.csv'),
        ),
      );
    });

    test('an invalid key is refused before the prefix is applied', () {
      expect(
        () => exports.exists('../escape'),
        throwsA(
          isA<TomExportException>()
              .having((e) => e.key, 'key', 'export.store.invalid_key')
              .having((e) => e.parameters?['key'], 'key parameter', '../escape'),
        ),
      );
    });

    test('the named constructor resolves a configured store', () async {
      TomBlobStoreInfo.register('files', blobs, asDefault: true);
      addTearDown(TomBlobStoreInfo.closeAll);
      expect(TomBlobExportStore.named(null).blobStore, same(blobs));
      expect(TomBlobExportStore.named('files').blobStore, same(blobs));
    });
  });
}

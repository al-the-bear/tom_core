/// Unit tests for the streaming file transfer layer: the value types
/// ([TomFileSource], [TomFileMetadata], [TomTransferProgress],
/// [TomTransferCancellation]), the in-memory client, and the HTTP client
/// against a **real** `HttpServer` that implements the documented wire
/// contract.
///
/// The server is real on purpose. The point of this layer is that bytes are
/// never buffered and that a cancel reaches the socket — neither claim can be
/// checked against a mock `Client`, which would let a fake pass while the real
/// transport deadlocked on `AbortableStreamedRequest`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' show Client;
import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// TEST SERVER
// =============================================================================

/// A minimal file server speaking the wire contract from
/// `http_file_transfer.dart`, backed by a map.
class _FileTestServer {
  _FileTestServer(this._server) {
    unawaited(_serve());
  }

  static Future<_FileTestServer> start() async =>
      _FileTestServer(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;

  /// The stored bytes per slot path (e.g. `/invoices/4711/scan`).
  final Map<String, Uint8List> bytes = {};

  /// The descriptor per slot path.
  final Map<String, TomFileMetadata> metadata = {};

  /// Request paths seen, in order — lets a test assert the slot was escaped
  /// into the URL the way the client claims.
  final List<String> seenPaths = [];

  /// Authorization headers seen, in order.
  final List<String?> seenAuthorization = [];

  /// When set, every response uses this status and an empty body.
  int? forcedStatus;

  /// Delay inserted between download chunks, so a cancel has time to land.
  Duration chunkDelay = Duration.zero;

  Uri get baseUri => Uri.parse('http://127.0.0.1:${_server.port}');

  Future<void> _serve() async {
    await for (final request in _server) {
      seenPaths.add(request.uri.path);
      seenAuthorization.add(request.headers.value('authorization'));
      try {
        await _handle(request);
      } catch (_) {
        // A client that aborts mid-transfer makes the write fail; that is the
        // scenario under test, not a server fault.
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    if (forcedStatus != null) {
      response.statusCode = forcedStatus!;
      await response.close();
      return;
    }
    final slot = request.uri.path;
    switch (request.method) {
      case 'POST':
        final builder = BytesBuilder();
        await for (final chunk in request) {
          builder.add(chunk);
        }
        final stored = builder.takeBytes();
        final meta = TomFileMetadata(
          key: 'test/${metadata.length}',
          mediaType:
              request.headers.value('content-type') ??
              TomMimeType.octetStream.toHeaderValue(),
          byteCount: stored.length,
          fileName: _fileName(request.headers.value('content-disposition')),
          storedAt: DateTime.utc(2026, 7, 28, 9),
        );
        bytes[slot] = stored;
        metadata[slot] = meta;
        response.statusCode = HttpStatus.created;
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(meta.toJson()));
        await response.close();

      case 'GET':
        final stored = bytes[slot];
        if (stored == null) {
          response.statusCode = HttpStatus.notFound;
          await response.close();
          return;
        }
        response.headers.contentType = ContentType.parse(
          metadata[slot]!.mediaType,
        );
        response.contentLength = stored.length;
        // Written in pieces so a download really is a stream of chunks and a
        // mid-transfer cancel has somewhere to land.
        const chunk = 8;
        for (var i = 0; i < stored.length; i += chunk) {
          response.add(
            Uint8List.sublistView(
              stored,
              i,
              (i + chunk).clamp(0, stored.length),
            ),
          );
          await response.flush();
          if (chunkDelay > Duration.zero) await Future.delayed(chunkDelay);
        }
        await response.close();

      case 'HEAD':
        final meta = metadata[slot];
        if (meta == null) {
          response.statusCode = HttpStatus.notFound;
          await response.close();
          return;
        }
        tomFileDescriptorHeaders(meta).forEach((name, value) {
          // Content-length is owned by the response object, not by us: a HEAD
          // response writes no body, and dart:io would object.
          if (name.toLowerCase() != 'content-length') {
            response.headers.set(name, value);
          }
        });
        await response.close();

      case 'DELETE':
        final existed = metadata.remove(slot) != null;
        bytes.remove(slot);
        response.statusCode = existed
            ? HttpStatus.noContent
            : HttpStatus.notFound;
        await response.close();

      default:
        response.statusCode = HttpStatus.methodNotAllowed;
        await response.close();
    }
  }

  static String? _fileName(String? disposition) {
    if (disposition == null) return null;
    final match = RegExp(r'filename="([^"]*)"').firstMatch(disposition);
    return match?.group(1);
  }

  Future<void> stop() => _server.close(force: true);
}

/// Supplies a plain `dart:io` HTTP client.
///
/// The kernel's default factory delegates to `TomPlatformUtils.current`, whose
/// fallback implementation has no client — a Flutter or server host installs a
/// real one. A test is its own host, so it installs one too.
class _TestClientFactory extends TomHttpClientFactory {
  @override
  Client getClient() => Client();
}

/// Builds an unsigned, undecrypted JWT whose middle segment carries [payload].
/// [TomBearerAuthentication.setTokens] parses what it is given, so the token
/// pair in these tests has to be JWT-shaped rather than an arbitrary string.
String _makeJwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg(payload)}.sig';
}

/// The authentication half of a stored token pair (`TomBearerAuthentication
/// .token`) — what the client sends by default.
final String _authJwt = _makeJwt({'sub': 'auth'});

/// The authorization half (`TomBearerAuthentication.authorizationToken`) — the
/// credential an application whose endpoints gate on access rights sends
/// instead, through the header provider.
final String _authzJwt = _makeJwt({'sub': 'authz'});

// =============================================================================
// TESTS
// =============================================================================

void main() {
  group('TomFileSource', () {
    test('bytes() knows its size and can be opened repeatedly', () async {
      final source = TomFileSource.bytes('note.txt', utf8.encode('hello'));
      expect(source.byteCount, 5);
      expect(source.hasKnownSize, isTrue);
      expect(await _collect(source.open()), utf8.encode('hello'));
      expect(await _collect(source.open()), utf8.encode('hello'));
    });

    test('bytes() snapshots the buffer so a later mutation cannot leak in',
        () async {
      final buffer = <int>[1, 2, 3];
      final source = TomFileSource.bytes('blob.bin', buffer);
      buffer[0] = 99;
      expect(await _collect(source.open()), [1, 2, 3]);
    });

    test('the media type is guessed from the extension', () {
      expect(
        TomFileSource.bytes('doc.pdf', const []).mediaType,
        TomMimeType.pdf.toHeaderValue(),
      );
      expect(
        TomFileSource.bytes('data.JSON', const []).mediaType,
        TomMimeType.json.toHeaderValue(),
      );
    });

    test('an unknown or missing extension falls back to octet-stream', () {
      final expected = TomMimeType.octetStream.toHeaderValue();
      expect(TomFileSource.bytes('thing.zzz', const []).mediaType, expected);
      expect(TomFileSource.bytes('README', const []).mediaType, expected);
      expect(TomFileSource.bytes('trailing.', const []).mediaType, expected);
    });

    test('an explicit media type wins over the guess', () {
      expect(
        TomFileSource.bytes('doc.pdf', const [], mediaType: 'text/plain')
            .mediaType,
        'text/plain',
      );
    });

    test('a streamed source may have an unknown size', () {
      final source = TomFileSource.stream(
        fileName: 'live.bin',
        open: () => const Stream<List<int>>.empty(),
      );
      expect(source.byteCount, isNull);
      expect(source.hasKnownSize, isFalse);
    });
  });

  group('TomFileMetadata', () {
    test('round-trips through JSON', () {
      final meta = TomFileMetadata(
        key: 'files/2026/07/abc.pdf',
        mediaType: 'application/pdf',
        byteCount: 42,
        fileName: 'invoice.pdf',
        storedAt: DateTime.utc(2026, 7, 28, 9, 30),
      );
      expect(TomFileMetadata.fromJson(meta.toJson()), meta);
    });

    test('omits absent optional members instead of writing nulls', () {
      const meta = TomFileMetadata(
        key: 'k',
        mediaType: 'application/octet-stream',
        byteCount: 0,
      );
      expect(meta.toJson().containsKey('fileName'), isFalse);
      expect(meta.toJson().containsKey('storedAt'), isFalse);
    });

    test('a descriptor missing a required member is a protocol error', () {
      expect(
        () => TomFileMetadata.fromJson({'key': 'k', 'mediaType': 'text/plain'}),
        throwsA(
          isA<TomFileTransferException>().having(
            (e) => e.key,
            'key',
            'file_transfer.invalid_descriptor',
          ),
        ),
      );
    });

    test('decodeFileDescriptor rejects non-JSON and non-object bodies', () {
      expect(
        () => decodeFileDescriptor('not json'),
        throwsA(isA<TomFileTransferException>()),
      );
      expect(
        () => decodeFileDescriptor('[1,2,3]'),
        throwsA(isA<TomFileTransferException>()),
      );
    });
  });

  group('TomTransferProgress', () {
    test('is indeterminate without a total', () {
      const progress = TomTransferProgress(10, null);
      expect(progress.isDeterminate, isFalse);
      expect(progress.fraction, isNull);
    });

    test('reports a fraction when the total is known', () {
      expect(const TomTransferProgress(25, 100).fraction, 0.25);
    });

    test('clamps an overshoot to 1.0', () {
      expect(const TomTransferProgress(150, 100).fraction, 1.0);
    });
  });

  group('TomTransferCancellation', () {
    test('cancel is idempotent and completes the trigger', () async {
      final cancellation = TomTransferCancellation();
      expect(cancellation.isCancelled, isFalse);
      cancellation.cancel();
      cancellation.cancel();
      expect(cancellation.isCancelled, isTrue);
      await expectLater(cancellation.trigger, completes);
    });

    test('throwIfCancelled throws only after cancel', () {
      final cancellation = TomTransferCancellation();
      expect(cancellation.throwIfCancelled, returnsNormally);
      cancellation.cancel();
      expect(
        cancellation.throwIfCancelled,
        throwsA(
          isA<TomFileTransferException>().having(
            (e) => e.key,
            'key',
            'file_transfer.cancelled',
          ),
        ),
      );
    });
  });

  group('TomMemoryFileTransferClient', () {
    late TomMemoryFileTransferClient client;

    setUp(() => client = TomMemoryFileTransferClient(chunkSize: 4));
    tearDown(() => client.close());

    test('stores, describes and reads back a file', () async {
      final stored = await client.upload(
        slot: 'a/b',
        source: TomFileSource.bytes('note.txt', utf8.encode('hello world')),
      );
      expect(stored.byteCount, 11);
      expect(stored.fileName, 'note.txt');
      expect(await client.describe('a/b'), stored);
      expect(
        utf8.decode(await _collect(client.download('a/b'))),
        'hello world',
      );
    });

    test('reports upload and download progress', () async {
      final uploads = <TomTransferProgress>[];
      final downloads = <TomTransferProgress>[];
      await client.upload(
        slot: 'a',
        source: TomFileSource.bytes('x.bin', List.filled(10, 7)),
        onProgress: uploads.add,
      );
      await _collect(client.download('a', onProgress: downloads.add));
      expect(uploads.last.transferred, 10);
      expect(uploads.last.fraction, 1.0);
      expect(downloads.map((p) => p.transferred), [4, 8, 10]);
    });

    test('describe of an empty slot is null, not an error', () async {
      expect(await client.describe('nothing'), isNull);
    });

    test('download of an empty slot fails with not_found', () {
      expect(
        () => _collect(client.download('nothing')),
        throwsA(
          isA<TomFileTransferException>().having(
            (e) => e.key,
            'key',
            'file_transfer.not_found',
          ),
        ),
      );
    });

    test('remove reports whether anything was there', () async {
      await client.upload(
        slot: 'a',
        source: TomFileSource.bytes('x.bin', const [1]),
      );
      expect(await client.remove('a'), isTrue);
      expect(await client.remove('a'), isFalse);
    });

    test('a cancelled upload throws instead of storing', () async {
      final cancellation = TomTransferCancellation()..cancel();
      await expectLater(
        client.upload(
          slot: 'a',
          source: TomFileSource.bytes('x.bin', const [1, 2, 3]),
          cancellation: cancellation,
        ),
        throwsA(
          isA<TomFileTransferException>().having(
            (e) => e.key,
            'key',
            'file_transfer.cancelled',
          ),
        ),
      );
      expect(await client.describe('a'), isNull);
    });

    test('a re-upload replaces the previous content', () async {
      await client.upload(
        slot: 'a',
        source: TomFileSource.bytes('one.txt', utf8.encode('one')),
      );
      await client.upload(
        slot: 'a',
        source: TomFileSource.bytes('two.txt', utf8.encode('two')),
      );
      expect(utf8.decode(await _collect(client.download('a'))), 'two');
    });
  });

  group('TomHttpFileTransferClient', () {
    late _FileTestServer server;
    late TomHttpFileTransferClient client;

    setUpAll(
      () => TomHttpClientFactory.setGlobalHttpClientFactory(
        _TestClientFactory(),
      ),
    );

    setUp(() async {
      server = await _FileTestServer.start();
      client = TomHttpFileTransferClient(baseUri: server.baseUri);
    });

    tearDown(() async {
      client.close();
      await server.stop();
    });

    test('uploads a file and returns the server-generated descriptor',
        () async {
      final stored = await client.upload(
        slot: 'invoices/4711/scan',
        source: TomFileSource.bytes('scan.pdf', utf8.encode('%PDF-1.7')),
      );
      expect(stored.key, 'test/0');
      expect(stored.byteCount, 8);
      expect(stored.fileName, 'scan.pdf');
      expect(stored.mediaType, TomMimeType.pdf.toHeaderValue());
      expect(server.seenPaths.single, '/invoices/4711/scan');
    });

    test('streams a large upload without buffering it whole', () async {
      // 2 MiB produced lazily in 64 KiB pieces: if the client buffered, the
      // chunk counter below would still be at its start value when the request
      // headers went out — this asserts the body is pumped, and that the whole
      // payload arrives intact.
      const chunkCount = 32;
      final chunk = Uint8List(64 * 1024)..fillRange(0, 64 * 1024, 65);
      final stored = await client.upload(
        slot: 'big',
        source: TomFileSource.stream(
          fileName: 'big.bin',
          byteCount: chunkCount * chunk.length,
          open: () => Stream.fromIterable(List.filled(chunkCount, chunk)),
        ),
      );
      expect(stored.byteCount, chunkCount * chunk.length);
      expect(server.bytes['/big']!.length, chunkCount * chunk.length);
    });

    test('reports upload progress as bytes leave the client', () async {
      final progress = <TomTransferProgress>[];
      await client.upload(
        slot: 'a',
        source: TomFileSource.stream(
          fileName: 'x.bin',
          byteCount: 30,
          open: () => Stream.fromIterable([
            List.filled(10, 1),
            List.filled(10, 2),
            List.filled(10, 3),
          ]),
        ),
        onProgress: progress.add,
      );
      expect(progress.map((p) => p.transferred), [10, 20, 30]);
      expect(progress.last.fraction, 1.0);
    });

    test('an upload from an unmeasurable source is sent chunked', () async {
      final progress = <TomTransferProgress>[];
      final stored = await client.upload(
        slot: 'a',
        source: TomFileSource.stream(
          fileName: 'x.bin',
          open: () => Stream.fromIterable([
            utf8.encode('ab'),
            utf8.encode('cd'),
          ]),
        ),
        onProgress: progress.add,
      );
      expect(stored.byteCount, 4);
      expect(progress.every((p) => !p.isDeterminate), isTrue);
    });

    test('downloads the stored bytes as a stream', () async {
      await client.upload(
        slot: 'a',
        source: TomFileSource.bytes('x.txt', utf8.encode('hello world')),
      );
      final chunks = <List<int>>[];
      await for (final chunk in client.download('a')) {
        chunks.add(chunk);
      }
      expect(utf8.decode(chunks.expand((c) => c).toList()), 'hello world');
    });

    test('reports download progress against the content length', () async {
      await client.upload(
        slot: 'a',
        source: TomFileSource.bytes('x.bin', List.filled(24, 9)),
      );
      final progress = <TomTransferProgress>[];
      await _collect(client.download('a', onProgress: progress.add));
      expect(progress.last.transferred, 24);
      expect(progress.last.total, 24);
      expect(progress.last.fraction, 1.0);
    });

    test('downloading an empty slot fails with not_found', () async {
      await expectLater(
        _collect(client.download('missing')),
        throwsA(
          isA<TomFileTransferException>().having(
            (e) => e.key,
            'key',
            'file_transfer.not_found',
          ),
        ),
      );
    });

    test('the download stream is lazy — nothing is sent until it is listened to',
        () async {
      client.download('a');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(server.seenPaths, isEmpty);
    });

    test('describe answers from HEAD without transferring the file', () async {
      final stored = await client.upload(
        slot: 'a',
        source: TomFileSource.bytes('doc.pdf', List.filled(1000, 1)),
      );
      final described = await client.describe('a');
      expect(described, stored);
      expect(server.seenPaths.last, '/a');
    });

    test('describe of an empty slot is null', () async {
      expect(await client.describe('missing'), isNull);
    });

    test('remove deletes and reports whether anything was there', () async {
      await client.upload(
        slot: 'a',
        source: TomFileSource.bytes('x.bin', const [1]),
      );
      expect(await client.remove('a'), isTrue);
      expect(await client.remove('a'), isFalse);
      expect(await client.describe('a'), isNull);
    });

    test('a non-2xx response becomes a rejected error carrying the status',
        () async {
      server.forcedStatus = HttpStatus.forbidden;
      await expectLater(
        client.upload(
          slot: 'a',
          source: TomFileSource.bytes('x.bin', const [1]),
        ),
        throwsA(
          isA<TomFileTransferException>()
              .having((e) => e.key, 'key', 'file_transfer.rejected')
              .having((e) => e.parameters?['statusCode'], 'statusCode', 403),
        ),
      );
    });

    test('cancelling mid-download aborts the transfer', () async {
      await client.upload(
        slot: 'a',
        source: TomFileSource.bytes('x.bin', List.filled(200, 3)),
      );
      server.chunkDelay = const Duration(milliseconds: 20);
      final cancellation = TomTransferCancellation();
      final received = <int>[];
      final done = Completer<Object?>();
      // A stream that errors still runs onDone afterwards, so the first of the
      // two callbacks wins and the second is ignored.
      void finish(Object? outcome) {
        if (!done.isCompleted) done.complete(outcome);
      }

      client
          .download('a', cancellation: cancellation)
          .listen(received.addAll, onError: finish, onDone: () => finish(null));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      cancellation.cancel();
      final outcome = await done.future;
      expect(
        outcome,
        isA<TomFileTransferException>().having(
          (e) => e.key,
          'key',
          'file_transfer.cancelled',
        ),
      );
      expect(received.length, lessThan(200));
    });

    test('a transfer cancelled before it starts fails immediately', () async {
      final cancellation = TomTransferCancellation()..cancel();
      await expectLater(
        client.upload(
          slot: 'a',
          source: TomFileSource.bytes('x.bin', const [1]),
          cancellation: cancellation,
        ),
        throwsA(
          isA<TomFileTransferException>().having(
            (e) => e.key,
            'key',
            'file_transfer.cancelled',
          ),
        ),
      );
      expect(server.seenPaths, isEmpty);
    });

    test('a retry re-opens the source and succeeds', () async {
      server.forcedStatus = HttpStatus.serviceUnavailable;
      final source = TomFileSource.bytes('x.txt', utf8.encode('retry me'));
      await expectLater(
        client.upload(slot: 'a', source: source),
        throwsA(isA<TomFileTransferException>()),
      );
      server.forcedStatus = null;
      final stored = await client.upload(slot: 'a', source: source);
      expect(stored.byteCount, 8);
      expect(utf8.decode(server.bytes['/a']!), 'retry me');
    });

    test('the bearer header is omitted when no one is logged in', () async {
      await client.upload(
        slot: 'a',
        source: TomFileSource.bytes('x.bin', const [1]),
      );
      expect(server.seenAuthorization.single, isNull);
    });

    test('extra headers are sent with every request', () async {
      final tagged = TomHttpFileTransferClient(
        baseUri: server.baseUri,
        headers: const {'x-tenant': 'acme'},
      );
      addTearDown(tagged.close);
      await tagged.upload(
        slot: 'a',
        source: TomFileSource.bytes('x.bin', const [1]),
      );
      expect(server.bytes.containsKey('/a'), isTrue);
    });

    test('a header provider is consulted per request, not captured once',
        () async {
      // The reason the seam is a callback and not a map: a credential rotates,
      // and a client built at startup must present the *current* one — which is
      // exactly what makes a refresh-and-retry able to succeed.
      var issued = 0;
      final rotating = TomHttpFileTransferClient(
        baseUri: server.baseUri,
        headerProvider: () => {'Authorization': 'Bearer token-${++issued}'},
      );
      addTearDown(rotating.close);

      final source = TomFileSource.bytes('x.bin', const [1]);
      await rotating.upload(slot: 'a', source: source);
      await rotating.upload(slot: 'a', source: source);

      expect(server.seenAuthorization,
          ['Bearer token-1', 'Bearer token-2']);
    });

    test('a provider Authorization header replaces the built-in bearer',
        () async {
      // Two credentials on one request is the ambiguity the seam removes: when
      // the application names the header, its answer is the only one sent.
      TomBearerAuthentication.setTokens(_authJwt, _authzJwt, false);
      addTearDown(TomBearerAuthentication.clearTokens);

      final explicit = TomHttpFileTransferClient(
        baseUri: server.baseUri,
        headerProvider: () => {
          'Authorization':
              'Bearer ${TomBearerAuthentication.authorizationToken}',
        },
      );
      addTearDown(explicit.close);
      await explicit.upload(
        slot: 'a',
        source: TomFileSource.bytes('x.bin', const [1]),
      );

      expect(server.seenAuthorization.single, 'Bearer $_authzJwt');
    });

    test('the built-in bearer still applies when the provider names no header',
        () async {
      TomBearerAuthentication.setTokens(_authJwt, _authzJwt, false);
      addTearDown(TomBearerAuthentication.clearTokens);

      final tagged = TomHttpFileTransferClient(
        baseUri: server.baseUri,
        headerProvider: () => const {'x-request': 'r1'},
      );
      addTearDown(tagged.close);
      await tagged.upload(
        slot: 'a',
        source: TomFileSource.bytes('x.bin', const [1]),
      );

      expect(server.seenAuthorization.single, 'Bearer $_authJwt');
    });

    test('a base path prefixes every slot', () async {
      final prefixed = TomHttpFileTransferClient(
        baseUri: server.baseUri.replace(path: '/api/files/'),
      );
      addTearDown(prefixed.close);
      await prefixed.upload(
        slot: 'a/b',
        source: TomFileSource.bytes('x.bin', const [1]),
      );
      expect(server.seenPaths.single, '/api/files/a/b');
    });

    test('a slot with traversal or empty segments is rejected', () {
      expect(
        () => client.uriForSlot('a/../b'),
        throwsA(
          isA<TomFileTransferException>().having(
            (e) => e.key,
            'key',
            'file_transfer.invalid_slot',
          ),
        ),
      );
      expect(
        () => client.uriForSlot('///'),
        throwsA(isA<TomFileTransferException>()),
      );
    });

    test('a shared channel is left open by close()', () async {
      final channel = TomServerChannel(
        server.baseUri.host,
        server.baseUri.port,
      );
      final shared = TomHttpFileTransferClient(
        baseUri: server.baseUri,
        channel: channel,
      );
      await shared.upload(
        slot: 'a',
        source: TomFileSource.bytes('x.bin', const [1]),
      );
      shared.close();
      // The channel still works, so a second client sharing it is unaffected.
      final second = TomHttpFileTransferClient(
        baseUri: server.baseUri,
        channel: channel,
      );
      expect(await second.describe('a'), isNotNull);
      channel.close();
    });
  });
}

/// Collects a byte stream into one list.
Future<List<int>> _collect(Stream<List<int>> stream) async {
  final builder = BytesBuilder();
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

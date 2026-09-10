/// Moves a file end to end without ever holding it whole: the in-memory client
/// first, then the same contract over HTTP against a loopback file server.
///
/// [TomFileTransferClient] is the contract both clients implement, so a widget
/// wired to [TomMemoryFileTransferClient] in a test exercises the same code
/// paths it will use against [TomHttpFileTransferClient] in production:
///
/// * a transfer addresses a **slot** — an application-owned path such as
///   `invoices/4711/scan` — and never a storage key, because a client that
///   could name its own key would turn any upload endpoint into an open write
///   surface;
/// * bytes are handed to the socket as the source produces them, and a
///   download is a `Stream<List<int>>` the caller consumes as it arrives;
/// * progress is reported per chunk, and is *indeterminate* when the size is
///   not known ahead of time, so a UI reads [TomTransferProgress.isDeterminate]
///   rather than guessing;
/// * a [TomTransferCancellation] stops the transfer rather than merely stopping
///   the caller from waiting.
///
/// The server half writes its descriptor with [tomFileDescriptorHeaders] —
/// public, and living beside the client, precisely so the code that writes the
/// header and the code that reads it cannot drift apart.
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/http_connection/08_file_transfer_example.dart
/// ```
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// ============================================================================
// The server
// ============================================================================

/// A loopback file store speaking the wire contract of
/// `TomHttpFileTransferClient`: `POST` stores, `GET` reads, `HEAD` describes,
/// `DELETE` removes, and every operation addresses `<baseUri>/<slot>`.
class FileServer {
  FileServer._(this._server);

  /// Binds to a free loopback port and starts serving.
  static Future<FileServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final instance = FileServer._(server);
    instance._serve();
    return instance;
  }

  final HttpServer _server;

  /// The stored bytes per slot path.
  final Map<String, Uint8List> bytes = {};

  /// The descriptor per slot path.
  final Map<String, TomFileMetadata> metadata = {};

  /// Where a client should address this store.
  Uri get baseUri => Uri.parse('http://127.0.0.1:${_server.port}');

  void _serve() async {
    await for (final request in _server) {
      final slot = request.uri.path;
      final response = request.response;
      switch (request.method) {
        case 'POST':
          final builder = BytesBuilder();
          await for (final chunk in request) {
            builder.add(chunk);
          }
          final stored = builder.takeBytes();
          // The key is the server's to assign — that is the whole reason a
          // client addresses a slot instead.
          final descriptor = TomFileMetadata(
            key: 'store/${metadata.length}',
            mediaType:
                request.headers.value(TomHeader.contentType) ??
                TomMimeType.octetStream.toHeaderValue(),
            byteCount: stored.length,
            fileName: tomFileNameFromDisposition(
              request.headers.value(TomHeader.contentDisposition),
            ),
            storedAt: DateTime.utc(2026, 7, 28, 9),
          );
          bytes[slot] = stored;
          metadata[slot] = descriptor;
          response.statusCode = HttpStatus.created;
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode(descriptor.toJson()));

        case 'GET':
          final stored = bytes[slot];
          if (stored == null) {
            response.statusCode = HttpStatus.notFound;
            break;
          }
          response.headers.contentType = ContentType.parse(
            metadata[slot]!.mediaType,
          );
          response.contentLength = stored.length;
          // Written in pieces, so a download really is a stream of chunks.
          for (var offset = 0; offset < stored.length; offset += 16) {
            response.add(
              Uint8List.sublistView(
                stored,
                offset,
                (offset + 16).clamp(0, stored.length),
              ),
            );
            await response.flush();
          }

        case 'HEAD':
          final descriptor = metadata[slot];
          if (descriptor == null) {
            response.statusCode = HttpStatus.notFound;
            break;
          }
          tomFileDescriptorHeaders(descriptor).forEach((name, value) {
            // Content-length belongs to the response object: a HEAD writes no
            // body, and `dart:io` would object to being told otherwise.
            if (name.toLowerCase() != 'content-length') {
              response.headers.set(name, value);
            }
          });

        case 'DELETE':
          final existed = metadata.remove(slot) != null;
          bytes.remove(slot);
          response.statusCode = existed
              ? HttpStatus.noContent
              : HttpStatus.notFound;

        default:
          response.statusCode = HttpStatus.methodNotAllowed;
      }
      await response.close();
    }
  }

  /// Stops serving.
  Future<void> stop() => _server.close(force: true);
}

// ============================================================================
// Example class
// ============================================================================

class FileTransferExample {
  // Captured results, asserted at the end of [run].
  static late TomFileMetadata memoryStored;
  static late String memoryReadBack;
  static late List<int> memoryChunkSizes;
  static late List<int> memoryProgress;
  static late bool memoryRemoved;
  static late String? memoryCancelKey;

  static late TomFileMetadata httpStored;
  static late String httpReadBack;
  static late TomFileMetadata httpDescribed;
  static late List<double?> httpUploadFractions;
  static late bool httpRemoved;
  static late String? httpNotFoundKey;

  /// The payload every transfer here moves.
  static final Uint8List payload = Uint8List.fromList(
    utf8.encode('a small invoice scan, standing in for 400 MB of one'),
  );

  // -------------------------------------------------------------------------
  // Example 1: the in-memory client — the same contract, no server
  // -------------------------------------------------------------------------
  static Future<void> example1InMemory() async {
    print('1. In-memory transfer:');

    // A small chunk size so a modest payload still produces several progress
    // events; the default is 64 KiB.
    final client = TomMemoryFileTransferClient(chunkSize: 16);
    final progress = <TomTransferProgress>[];

    memoryStored = await client.upload(
      slot: 'invoices/4711/scan',
      source: TomFileSource.bytes('scan.txt', payload),
      onProgress: progress.add,
    );
    print('   - stored as : ${memoryStored.key}');
    print('   - media type: ${memoryStored.mediaType}');

    final chunks = await client
        .download('invoices/4711/scan', onProgress: progress.add)
        .toList();
    memoryChunkSizes = chunks.map((chunk) => chunk.length).toList();
    memoryReadBack = utf8.decode(chunks.expand((chunk) => chunk).toList());
    memoryProgress = progress.map((p) => p.transferred).toList();
    print('   - chunks    : $memoryChunkSizes');
    print('   - read back : "$memoryReadBack"');

    memoryRemoved = await client.remove('invoices/4711/scan');
    print('   - removed   : $memoryRemoved');

    // A cancellation that arrived before the transfer started refuses it with
    // the same key one arriving mid-flight would.
    final cancellation = TomTransferCancellation()..cancel();
    try {
      await client.upload(
        slot: 'invoices/4712/scan',
        source: TomFileSource.bytes('scan.txt', payload),
        cancellation: cancellation,
      );
    } on TomFileTransferException catch (refused) {
      memoryCancelKey = refused.key;
    }
    print('   - cancelled : $memoryCancelKey');
    client.close();
  }

  // -------------------------------------------------------------------------
  // Example 2: the same contract over HTTP
  // -------------------------------------------------------------------------
  static Future<void> example2OverHttp(FileServer server) async {
    print('\n2. The same operations over HTTP:');

    final client = TomHttpFileTransferClient(baseUri: server.baseUri);
    final progress = <TomTransferProgress>[];
    try {
      httpStored = await client.upload(
        slot: 'invoices/4711/scan',
        source: TomFileSource.bytes('scan.txt', payload),
        onProgress: progress.add,
      );
      httpUploadFractions = progress.map((p) => p.fraction).toList();
      print('   - stored as : ${httpStored.key}');
      print('   - file name : ${httpStored.fileName}');
      print('   - fractions : $httpUploadFractions');

      // `describe` answers from the descriptor headers of a HEAD response, so
      // it never transfers the file to report on it.
      httpDescribed = (await client.describe('invoices/4711/scan'))!;
      print(
        '   - described : ${httpDescribed.byteCount} bytes, '
        'key ${httpDescribed.key}',
      );

      final downloaded = <int>[];
      await for (final chunk in client.download('invoices/4711/scan')) {
        downloaded.addAll(chunk);
      }
      httpReadBack = utf8.decode(downloaded);
      print('   - read back : "$httpReadBack"');

      httpRemoved = await client.remove('invoices/4711/scan');
      print('   - removed   : $httpRemoved');

      // A slot with nothing in it is a `file_transfer.not_found`, not an empty
      // stream: a caller must be able to tell "no file" from "an empty file".
      try {
        await client.download('invoices/4711/scan').toList();
      } on TomFileTransferException catch (missing) {
        httpNotFoundKey = missing.key;
      }
      print('   - missing   : $httpNotFoundKey');
    } finally {
      client.close();
    }
  }

  // -------------------------------------------------------------------------
  // Run all examples
  // -------------------------------------------------------------------------
  static Future<void> run() async {
    print('=== 08: File Transfer Example ===\n');

    final server = await FileServer.start();
    try {
      await example1InMemory();
      await example2OverHttp(server);
    } finally {
      await server.stop();
    }

    // Assertions — the in-memory half
    assert(
      memoryStored.byteCount == payload.length,
      'The descriptor should report what was stored',
    );
    assert(
      memoryStored.mediaType == TomMimeType.plainText.toHeaderValue(),
      'The media type should be guessed from the file name',
    );
    assert(
      memoryChunkSizes.every((size) => size <= 16) &&
          memoryChunkSizes
              .take(memoryChunkSizes.length - 1)
              .every((size) => size == 16) &&
          memoryChunkSizes.last == payload.length % 16 &&
          memoryChunkSizes.reduce((a, b) => a + b) == payload.length,
      'The replay slices into chunkSize pieces, the last one partial',
    );
    assert(
      memoryReadBack == utf8.decode(payload),
      'What comes back must be what went in',
    );
    assert(
      memoryProgress.last == payload.length,
      'The last progress event should report the whole payload',
    );
    assert(memoryRemoved, 'remove reports that something was there');
    assert(
      memoryCancelKey == 'file_transfer.cancelled',
      'A cancelled transfer is refused under its own key',
    );

    // Assertions — the HTTP half
    assert(
      httpStored.key == 'store/0',
      'The key is the server\'s to assign, and the client reports it back',
    );
    assert(
      httpStored.fileName == 'scan.txt',
      'The file name travels in the Content-Disposition and comes back',
    );
    assert(
      httpStored.byteCount == payload.length,
      'The server reports what it stored',
    );
    assert(
      httpUploadFractions.last == 1.0,
      'A measurable source reports a determinate fraction, ending at 1.0',
    );
    assert(
      httpDescribed == httpStored,
      'describe reads the same descriptor back out of the HEAD headers',
    );
    assert(
      httpReadBack == utf8.decode(payload),
      'What comes back over the wire must be what went in',
    );
    assert(httpRemoved, 'remove reports that something was there');
    assert(
      httpNotFoundKey == 'file_transfer.not_found',
      'An absent slot is an error, not an empty stream',
    );

    print('\n=== File Transfer Example Complete ===\n');
  }
}

/// Runs this example.
Future<void> run() => FileTransferExample.run();

Future<void> main() async {
  prepareSampleProcess();
  await run();
}

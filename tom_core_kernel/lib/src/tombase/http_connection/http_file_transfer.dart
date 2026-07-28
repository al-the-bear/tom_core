/// The HTTP implementation of the streaming file transfer contract.
///
/// [TomHttpFileTransferClient] speaks the wire contract below to the file
/// endpoints of a Tom server, moving bytes without ever holding a whole file.
///
/// ## The wire contract
///
/// Every operation addresses `<baseUri>/<slot>`:
///
/// | Method   | Request                                          | Response                          |
/// | -------- | ------------------------------------------------ | --------------------------------- |
/// | `POST`   | the file's bytes, `Content-Type`, optional `Content-Length`, `Content-Disposition: attachment; filename="…"` | `200`/`201` + JSON descriptor |
/// | `GET`    | —                                                | `200` + the file's bytes, `404` when empty |
/// | `HEAD`   | —                                                | `200` + descriptor headers, `404` when empty |
/// | `DELETE` | —                                                | `200`/`204` when deleted, `404` when empty |
///
/// The descriptor is `{"key", "mediaType", "byteCount", "fileName"?,
/// "storedAt"?}` — see `TomFileMetadata.fromJson`.
///
/// `HEAD` answers [TomFileTransferClient.describe] from headers alone, because
/// a describe that transferred the file would defeat its purpose.
///
/// ## Streaming and cancellation
///
/// Uploads use `AbortableStreamedRequest`, so bytes are handed to the socket as
/// the source produces them; downloads read `StreamedResponse.stream` directly.
/// Both take their abort trigger from a [TomTransferCancellation], which is
/// what makes a "Cancel" button stop the socket rather than merely stop the
/// caller from waiting.
///
/// ## Example
///
/// ```dart
/// final client = TomHttpFileTransferClient(
///   baseUri: Uri.parse('https://api.example.com/files'),
/// );
/// final stored = await client.upload(
///   slot: 'invoices/4711/scan',
///   source: TomFileSource.bytes('scan.pdf', bytes),
/// );
/// print(stored.key);
/// ```
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// A [TomFileTransferClient] over HTTP.
///
/// Connections are pooled by a [TomServerChannel], so a client used for many
/// transfers reuses one underlying HTTP client; [close] releases it.
class TomHttpFileTransferClient extends TomFileTransferClient {
  /// Creates a client for the file endpoints rooted at [baseUri].
  ///
  /// [channel] is optional; when omitted one is created for [baseUri]'s host
  /// and port. Pass an existing channel to share a connection pool with the
  /// rest of an application's calls.
  ///
  /// [includeBearerAuthentication] mirrors [TomServerCallSpecs] — leave it on
  /// unless the endpoints are genuinely public, since a file store is exactly
  /// the kind of endpoint that should not be.
  ///
  /// [headerProvider] supplies headers that must be computed *per request*,
  /// which [headers] cannot: a credential rotates, and a client built once at
  /// startup would otherwise keep presenting the value it captured. It is also
  /// the seam an application uses when its server gates on a different
  /// credential than [TomBearerAuthentication.token] — returning an
  /// `Authorization` header from here suppresses the built-in bearer, so there
  /// is one credential on the request rather than two spellings of one.
  TomHttpFileTransferClient({
    required Uri baseUri,
    TomServerChannel? channel,
    this.includeBearerAuthentication = true,
    Map<String, String> headers = const {},
    Map<String, String> Function()? headerProvider,
  }) : baseUri = _withoutTrailingSlash(baseUri),
       headers = Map.unmodifiable(headers),
       _headerProvider = headerProvider,
       channel = channel ?? TomServerChannel(baseUri.host, _portOf(baseUri)),
       _ownsChannel = channel == null;

  /// The root the slot paths are resolved against.
  final Uri baseUri;

  /// The channel providing the pooled HTTP client.
  final TomServerChannel channel;

  /// Whether to send the bearer token from [TomBearerAuthentication].
  final bool includeBearerAuthentication;

  /// Extra headers sent with every request.
  final Map<String, String> headers;

  final bool _ownsChannel;

  final Map<String, String> Function()? _headerProvider;

  /// The URL for [slot], with each path segment escaped.
  ///
  /// Segments are escaped individually so a slot cannot smuggle a `..` or a
  /// query string past the base URI — the client's half of the same
  /// key-validation discipline the server applies.
  Uri uriForSlot(String slot) {
    final segments = slot
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty || segments.any((s) => s == '.' || s == '..')) {
      throw TomFileTransferException(
        'file_transfer.invalid_slot',
        'A file slot must be a non-empty path without "." or ".." segments.',
        parameters: {'slot': slot},
      );
    }
    return baseUri.replace(
      pathSegments: [...baseUri.pathSegments.where((s) => s.isNotEmpty), ...segments],
    );
  }

  Map<String, String> _requestHeaders([Map<String, String> extra = const {}]) {
    final token = TomBearerAuthentication.token;
    final merged = <String, String>{
      ...headers,
      ...?_headerProvider?.call(),
      ...extra,
    };
    // Omitted rather than sent as "Bearer null" when no one has logged in: an
    // absent header is a clean 401, a malformed one is a puzzle. A provider
    // that already named an Authorization header wins — it is answering the
    // same question with better information, and two credentials on one request
    // is the ambiguity this whole seam exists to remove.
    if (includeBearerAuthentication &&
        token != null &&
        !merged.containsKey('Authorization')) {
      merged['Authorization'] = 'Bearer $token';
    }
    return merged;
  }

  @override
  Future<TomFileMetadata> upload({
    required String slot,
    required TomFileSource source,
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final request = AbortableStreamedRequest(
      TomHttpMethod.post.name,
      uriForSlot(slot),
      abortTrigger: cancellation?.trigger,
    );
    request.headers.addAll(
      _requestHeaders({
        TomHeader.contentType: source.mediaType,
        TomHeader.contentDisposition:
            'attachment; filename="${tomEscapeFileNameForDisposition(source.fileName)}"',
      }),
    );
    if (source.hasKnownSize) request.contentLength = source.byteCount;

    // The response future is awaited *after* the body is written: the server
    // cannot answer before it has the bytes, so awaiting first would deadlock.
    final responseFuture = channel.getClient().send(request);
    unawaited(_pumpBody(request, source, onProgress));

    final response = await _awaitResponse(responseFuture, slot);
    final body = await _readBody(response, slot);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _rejected(slot, response.statusCode, body);
    }
    return decodeFileDescriptor(body);
  }

  /// Copies [source] into [request]'s sink, reporting progress and closing the
  /// sink exactly once.
  ///
  /// Errors are pushed into the sink rather than thrown: this runs unawaited,
  /// and an uncaught async error here would escape to the zone instead of
  /// surfacing at the `await` on the response.
  Future<void> _pumpBody(
    AbortableStreamedRequest request,
    TomFileSource source,
    void Function(TomTransferProgress progress)? onProgress,
  ) async {
    var sent = 0;
    try {
      await for (final chunk in source.open()) {
        request.sink.add(chunk);
        sent += chunk.length;
        onProgress?.call(TomTransferProgress(sent, source.byteCount));
      }
    } catch (error, stack) {
      request.sink.addError(error, stack);
    } finally {
      await request.sink.close();
    }
  }

  @override
  Stream<List<int>> download(
    String slot, {
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  }) async* {
    cancellation?.throwIfCancelled();
    final request = AbortableRequest(
      TomHttpMethod.get.name,
      uriForSlot(slot),
      abortTrigger: cancellation?.trigger,
    );
    request.headers.addAll(_requestHeaders());

    final response = await _awaitResponse(
      channel.getClient().send(request),
      slot,
    );
    if (response.statusCode == 404) {
      throw _notFound(slot);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _rejected(slot, response.statusCode, await _readBody(response, slot));
    }

    final total = response.contentLength;
    var received = 0;
    try {
      // `await for` rather than `yield*`: a `yield*` forwards the inner
      // stream's errors straight past this try, so an abort would surface as a
      // raw RequestAbortedException instead of the module's own error.
      await for (final chunk in response.stream) {
        received += chunk.length;
        yield chunk;
        onProgress?.call(TomTransferProgress(received, total));
      }
    } on RequestAbortedException catch (error, stack) {
      throw _cancelled(slot, error, stack);
    }
  }

  @override
  Future<TomFileMetadata?> describe(String slot) async {
    final request = Request(TomHttpMethod.head.name, uriForSlot(slot));
    request.headers.addAll(_requestHeaders());
    final response = await channel.getClient().send(request);
    // Drained even though HEAD has no body: an undrained streamed response
    // keeps the connection out of the pool.
    await response.stream.drain<void>();
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _rejected(slot, response.statusCode, null);
    }
    return _metadataFromHeaders(response.headers, slot);
  }

  @override
  Future<bool> remove(String slot) async {
    final request = Request(TomHttpMethod.delete.name, uriForSlot(slot));
    request.headers.addAll(_requestHeaders());
    final response = await channel.getClient().send(request);
    final body = await _readBody(response, slot);
    if (response.statusCode == 404) return false;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _rejected(slot, response.statusCode, body);
    }
    return true;
  }

  @override
  void close() {
    // Only a channel this client created is closed: a shared one belongs to
    // whoever passed it in and may still be serving other calls.
    if (_ownsChannel) channel.close();
  }

  /// Awaits [responseFuture], translating an abort into the module's own error.
  Future<StreamedResponse> _awaitResponse(
    Future<StreamedResponse> responseFuture,
    String slot,
  ) async {
    try {
      return await responseFuture;
    } on RequestAbortedException catch (error, stack) {
      throw _cancelled(slot, error, stack);
    }
  }

  /// Reads a (small) response body — a JSON descriptor or an error message.
  ///
  /// Safe to buffer: this is never the file's own bytes, which
  /// [download] streams instead.
  Future<String> _readBody(StreamedResponse response, String slot) async {
    try {
      return await response.stream.bytesToString();
    } on RequestAbortedException catch (error, stack) {
      throw _cancelled(slot, error, stack);
    }
  }

  /// Builds metadata from the headers of a `HEAD` response.
  TomFileMetadata _metadataFromHeaders(
    Map<String, String> responseHeaders,
    String slot,
  ) {
    // Header names arrive lower-cased from `package:http`.
    final descriptor = responseHeaders['x-tom-file'];
    if (descriptor != null) return decodeFileDescriptor(descriptor);

    final key = responseHeaders['x-tom-file-key'];
    final length = int.tryParse(responseHeaders['content-length'] ?? '');
    if (key == null || length == null) {
      throw TomFileTransferException(
        'file_transfer.invalid_descriptor',
        'The server did not describe the stored file.',
        parameters: {'slot': slot, 'headers': responseHeaders},
      );
    }
    return TomFileMetadata(
      key: key,
      mediaType:
          responseHeaders['content-type'] ??
          TomMimeType.octetStream.toHeaderValue(),
      byteCount: length,
      fileName: tomFileNameFromDisposition(
        responseHeaders['content-disposition'],
      ),
      storedAt: DateTime.tryParse(responseHeaders['x-tom-file-stored-at'] ?? ''),
    );
  }

  TomFileTransferException _notFound(String slot) => TomFileTransferException(
    'file_transfer.not_found',
    'No file is stored for the requested slot.',
    parameters: {'slot': slot},
  );

  TomFileTransferException _cancelled(
    String slot,
    Object error,
    StackTrace stack,
  ) => TomFileTransferException(
    'file_transfer.cancelled',
    'The file transfer was cancelled.',
    parameters: {'slot': slot},
    rootException: error,
    stack: stack,
  );

  TomFileTransferException _rejected(String slot, int statusCode, String? body) {
    if (statusCode == 404) return _notFound(slot);
    return TomFileTransferException(
      'file_transfer.rejected',
      'The server rejected the file transfer.',
      parameters: {
        'slot': slot,
        'statusCode': statusCode,
        if (body != null && body.isNotEmpty) 'response': body,
      },
    );
  }

  static Uri _withoutTrailingSlash(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return uri.replace(pathSegments: segments);
  }

  static int _portOf(Uri uri) =>
      uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);

}

/// Writes the descriptor header a `HEAD` response needs so
/// [TomFileTransferClient.describe] can answer without a body.
///
/// Lives here rather than in the server package because it is the *contract*,
/// not an implementation: the client reads `x-tom-file`, so whatever writes it
/// has to agree, and keeping both halves in one file is what stops them
/// drifting.
Map<String, String> tomFileDescriptorHeaders(TomFileMetadata metadata) => {
  'x-tom-file': jsonEncode(metadata.toJson()),
  TomHeader.contentType: metadata.mediaType,
  'content-length': '${metadata.byteCount}',
  if (metadata.fileName != null)
    TomHeader.contentDisposition:
        'attachment; filename="${tomEscapeFileNameForDisposition(metadata.fileName!)}"',
};

/// Escapes a file name for a quoted `Content-Disposition` parameter.
///
/// Only the two characters that can terminate or escape the quoted string are
/// touched; anything more aggressive would mangle legitimate names.
String tomEscapeFileNameForDisposition(String fileName) =>
    fileName.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

/// Extracts `filename="…"` from a `Content-Disposition` header, or `null` when
/// the header is absent or names no file.
///
/// Public, and here beside [tomFileDescriptorHeaders], for the same reason that
/// helper is: the file name travels in both directions — the client writes it on
/// an upload, the server writes it back on a download — so the code that writes
/// it and the code that reads it have to be one piece. A server that hand-rolled
/// its own parser would drift the moment either side learned a new form (the
/// RFC 5987 `filename*=` case below is exactly such a form).
String? tomFileNameFromDisposition(String? disposition) {
  if (disposition == null) return null;
  final match = RegExp(
    r'filename\*?=(?:"((?:[^"\\]|\\.)*)"|([^;]+))',
  ).firstMatch(disposition);
  if (match == null) return null;
  final quoted = match.group(1);
  if (quoted != null) {
    return quoted.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
  }
  final bare = match.group(2)?.trim();
  if (bare == null || bare.isEmpty) return null;
  // RFC 5987 form: `filename*=UTF-8''name.pdf`.
  final encoded = bare.split("''").last;
  return Uri.decodeFull(encoded);
}

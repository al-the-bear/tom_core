/// Streaming file transfer — the client half of the framework's file storage.
///
/// The server side (`tom_core_server`'s `file_storage` module) stores a file as
/// a stream and reads it back as a stream, so a large attachment never has to
/// exist in memory at either end. This library is the matching client contract:
/// a [TomFileSource] to send, a [TomFileMetadata] to describe what was stored,
/// and a [TomFileTransferClient] that moves bytes between them with progress
/// reporting and cancellation.
///
/// ## Why this is not the existing [TomServerCall]
///
/// `TomServerCall` is a request/response API: a body is a `String`, a
/// `Uint8List` or form fields, and `read()` accumulates the whole response into
/// a `BytesBuilder`. That is the right shape for JSON endpoints and the wrong
/// shape for a 400 MB video. This library keeps the same connection machinery
/// ([TomServerChannel], the bearer token, the client factory) but never
/// materialises the payload.
///
/// ## Slots, not keys
///
/// A transfer addresses a **slot** — an application-owned path such as
/// `invoices/4711/scan` — and never a storage key. Storage keys are generated
/// by the server and handed back in [TomFileMetadata.key]; a client that could
/// name its own key would turn any upload endpoint into an open write surface
/// on the blob store. The slot is what the application already controls through
/// its own authorization rules.
///
/// ## Example
///
/// ```dart
/// final client = TomHttpFileTransferClient(
///   baseUri: Uri.parse('https://api.example.com/files'),
/// );
/// final cancellation = TomTransferCancellation();
///
/// final stored = await client.upload(
///   slot: 'invoices/4711/scan',
///   source: TomFileSource.bytes('scan.pdf', pdfBytes),
///   onProgress: (p) => print('${(p.fraction ?? 0) * 100}%'),
///   cancellation: cancellation,
/// );
///
/// await for (final chunk in client.download('invoices/4711/scan')) {
///   sink.add(chunk);
/// }
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// EXCEPTIONS
// =============================================================================

/// Exception thrown when a file transfer fails.
///
/// Error keys are stable and worth matching on. Each names a condition a
/// running system can meet — a caller may branch on one, and `tom_flutter_ui`
/// turns each into a user-facing line — so a mistake in the calling code is
/// deliberately not among them:
///
/// - `file_transfer.not_found` — no file is stored in the requested slot.
/// - `file_transfer.cancelled` — the caller cancelled the transfer.
/// - `file_transfer.rejected` — the server refused the transfer (status code in
///   `parameters['statusCode']`).
/// - `file_transfer.invalid_descriptor` — the server's description of a stored
///   file was unreadable: not valid JSON, not a JSON object, missing `key` /
///   `mediaType` / `byteCount`, or a `HEAD` that described nothing at all.
/// - `file_transfer.invalid_slot` — the slot was empty or contained `.` or `..`
///   segments (see [TomHttpFileTransferClient.uriForSlot]).
class TomFileTransferException extends TomException {
  TomFileTransferException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.requestUuid,
    super.uuid,
  });
}

// =============================================================================
// FILE SOURCE
// =============================================================================

/// The bytes to upload, together with what the server needs to know about them.
///
/// ## Why [open] is a function and not a stream
///
/// A Dart stream can be listened to once. Retry-after-failure — which the whole
/// progress/cancel UX exists to offer — needs the same bytes a second time, so
/// the source hands out a *factory*: every call to [open] starts a fresh read.
/// A source built from an in-memory buffer replays trivially; one built from a
/// file replays by re-opening the file.
///
/// ## Example
///
/// ```dart
/// // Small file, already in memory.
/// final small = TomFileSource.bytes('note.txt', utf8.encode('hello'));
///
/// // Large file, streamed from disk and re-openable.
/// final large = TomFileSource.stream(
///   fileName: 'video.mp4',
///   byteCount: await file.length(),
///   open: () => file.openRead(),
/// );
/// ```
class TomFileSource {
  /// Creates a source that streams from [open].
  ///
  /// [byteCount] is optional because a source is not always measurable ahead of
  /// time; when it is `null` the upload is sent chunked and progress is
  /// indeterminate.
  TomFileSource.stream({
    required this.fileName,
    required Stream<List<int>> Function() open,
    this.byteCount,
    String? mediaType,
  }) : _open = open,
       mediaType = mediaType ?? guessMediaType(fileName);

  /// Creates a source over an in-memory buffer.
  ///
  /// The buffer is captured, so [open] can be called any number of times.
  factory TomFileSource.bytes(
    String fileName,
    List<int> bytes, {
    String? mediaType,
  }) {
    // Copied into a Uint8List so a caller mutating its own list afterwards
    // cannot change what a retry uploads.
    final snapshot = Uint8List.fromList(bytes);
    return TomFileSource.stream(
      fileName: fileName,
      byteCount: snapshot.length,
      mediaType: mediaType,
      open: () => Stream<List<int>>.value(snapshot),
    );
  }

  /// The name to store the file under, as the user knows it.
  ///
  /// This is a *display* name — the server derives the storage key itself and
  /// only keeps this for `Content-Disposition` when the file is served back.
  final String fileName;

  /// The total size in bytes, or `null` when it is not known in advance.
  final int? byteCount;

  /// The media type sent as `Content-Type`.
  final String mediaType;

  final Stream<List<int>> Function() _open;

  /// Starts a fresh read of the file's bytes.
  ///
  /// Every call returns an independent stream; see the class doc for why.
  ///
  /// A factory that hands back the *same* single-subscription stream instead of
  /// building a new one satisfies the type but breaks that contract, and the
  /// second transfer fails with Dart's own `StateError: Stream has already been
  /// listened to`. That is left as it is rather than being translated into a
  /// transfer error key: it is a defect in the calling code, not a condition a
  /// running system can encounter, and Dart's message already names it exactly.
  Stream<List<int>> open() => _open();

  /// Whether the total size is known, which decides whether a transfer over
  /// this source can report a determinate progress fraction.
  bool get hasKnownSize => byteCount != null;

  /// The media type for [fileName], falling back to `application/octet-stream`.
  ///
  /// Guessing is deliberately conservative: an unknown extension becomes a
  /// binary blob rather than something a browser might decide to render.
  static String guessMediaType(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) {
      return TomMimeType.octetStream.toHeaderValue();
    }
    final mapped = StaticFileMimetypeMapping.getMimeType(
      fileName.substring(dot),
    );
    return (mapped ?? TomMimeType.octetStream).toHeaderValue();
  }

  @override
  String toString() =>
      'TomFileSource($fileName, $mediaType'
      '${byteCount == null ? '' : ', $byteCount bytes'})';
}

// =============================================================================
// FILE METADATA
// =============================================================================

/// What the server knows about a stored file.
///
/// Returned by [TomFileTransferClient.upload] and
/// [TomFileTransferClient.describe]. The [key] is the server-generated storage
/// key — opaque to the client, but worth carrying around because it is what
/// identifies this exact stored revision.
class TomFileMetadata {
  /// Creates metadata for a stored file.
  const TomFileMetadata({
    required this.key,
    required this.mediaType,
    required this.byteCount,
    this.fileName,
    this.storedAt,
  });

  /// Reads metadata from the JSON descriptor the server returns.
  ///
  /// Tolerant of missing optional members so a server can grow the descriptor
  /// without breaking older clients; a missing [key], [mediaType] or
  /// [byteCount] is a protocol error and throws.
  factory TomFileMetadata.fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    final mediaType = json['mediaType'];
    final byteCount = json['byteCount'];
    if (key is! String || mediaType is! String || byteCount is! int) {
      throw TomFileTransferException(
        'file_transfer.invalid_descriptor',
        'The server returned a file descriptor without key, mediaType or byteCount.',
        parameters: {'descriptor': json},
      );
    }
    final storedAt = json['storedAt'];
    return TomFileMetadata(
      key: key,
      mediaType: mediaType,
      byteCount: byteCount,
      fileName: json['fileName'] as String?,
      storedAt: storedAt is String ? DateTime.tryParse(storedAt) : null,
    );
  }

  /// The server-generated storage key.
  final String key;

  /// The media type the file was stored with.
  final String mediaType;

  /// The stored size in bytes.
  final int byteCount;

  /// The original file name, when the server kept one.
  final String? fileName;

  /// When the file was stored, when the server reports it.
  final DateTime? storedAt;

  /// The JSON descriptor for this metadata.
  ///
  /// Optional members are omitted rather than written as `null` so a round trip
  /// through [TomFileMetadata.fromJson] produces an equal object.
  Map<String, dynamic> toJson() => {
    'key': key,
    'mediaType': mediaType,
    'byteCount': byteCount,
    if (fileName != null) 'fileName': fileName,
    if (storedAt != null) 'storedAt': storedAt!.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is TomFileMetadata &&
      other.key == key &&
      other.mediaType == mediaType &&
      other.byteCount == byteCount &&
      other.fileName == fileName &&
      other.storedAt == storedAt;

  @override
  int get hashCode => Object.hash(key, mediaType, byteCount, fileName, storedAt);

  @override
  String toString() =>
      'TomFileMetadata($key, $mediaType, $byteCount bytes'
      '${fileName == null ? '' : ', "$fileName"'})';
}

// =============================================================================
// PROGRESS
// =============================================================================

/// How far a transfer has got.
///
/// [total] is `null` whenever the size is not known ahead of time — an upload
/// from an unmeasurable source, or a download whose response has no
/// `Content-Length`. A UI should read [isDeterminate] rather than guess, and
/// fall back to a spinner when it is `false`.
class TomTransferProgress {
  /// Creates a progress report.
  const TomTransferProgress(this.transferred, this.total);

  /// Bytes moved so far.
  final int transferred;

  /// Total bytes, or `null` when unknown.
  final int? total;

  /// Whether a meaningful percentage can be shown.
  bool get isDeterminate => total != null && total! > 0;

  /// The completed fraction in `0.0 .. 1.0`, or `null` when indeterminate.
  ///
  /// Clamped because a server may report a `Content-Length` that a chunked
  /// re-encoding then exceeds, and a progress bar past 100 % looks like a bug.
  double? get fraction => isDeterminate
      ? (transferred / total!).clamp(0.0, 1.0).toDouble()
      : null;

  @override
  String toString() => 'TomTransferProgress($transferred/${total ?? '?'})';
}

// =============================================================================
// CANCELLATION
// =============================================================================

/// A cancel signal shared with an in-flight transfer.
///
/// Wraps the `Future`-based abort trigger `package:http` expects, so callers
/// deal with a `cancel()` method instead of hand-rolling a `Completer`. One
/// instance covers one transfer; [cancel] is idempotent so a UI can wire it to
/// a button without tracking whether it already fired.
///
/// ## Example
///
/// ```dart
/// final cancellation = TomTransferCancellation();
/// final upload = client.upload(slot: slot, source: source, cancellation: cancellation);
/// cancelButton.onPressed = cancellation.cancel;
/// ```
class TomTransferCancellation {
  final Completer<void> _completer = Completer<void>();

  /// The future that completes when [cancel] is called.
  Future<void> get trigger => _completer.future;

  /// Whether cancellation has been requested.
  bool get isCancelled => _completer.isCompleted;

  /// Requests cancellation; does nothing if already cancelled.
  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }

  /// Throws [TomFileTransferException] with key `file_transfer.cancelled` when
  /// cancellation has already been requested.
  ///
  /// Used at the start of a transfer so a cancellation that arrived before the
  /// request was built produces the same error as one that arrived mid-flight.
  void throwIfCancelled() {
    if (isCancelled) {
      throw TomFileTransferException(
        'file_transfer.cancelled',
        'The file transfer was cancelled.',
      );
    }
  }
}

// =============================================================================
// TRANSFER CLIENT
// =============================================================================

/// Moves file bytes between an application and a file store.
///
/// Four operations, matching the server-side `TomBlobStore` contract one for
/// one, addressed by slot rather than by storage key (see the library doc).
/// Implementations must stream: neither [upload] nor [download] may buffer a
/// whole file.
abstract class TomFileTransferClient {
  /// Creates a transfer client.
  const TomFileTransferClient();

  /// Uploads [source] into [slot], returning what the server stored.
  ///
  /// [onProgress] is called as bytes leave the client. [cancellation] aborts
  /// the request; the returned future then completes with a
  /// [TomFileTransferException] keyed `file_transfer.cancelled`.
  Future<TomFileMetadata> upload({
    required String slot,
    required TomFileSource source,
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  });

  /// Streams the file stored in [slot].
  ///
  /// The stream is lazy — nothing is requested until it is listened to — and
  /// errors with `file_transfer.not_found` when the slot is empty.
  Stream<List<int>> download(
    String slot, {
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  });

  /// Describes the file stored in [slot], or `null` when the slot is empty.
  ///
  /// Cheap by design: it must not transfer the file's bytes, so a UI can show
  /// name, type and size without downloading anything.
  Future<TomFileMetadata?> describe(String slot);

  /// Deletes the file in [slot], returning whether anything was deleted.
  ///
  /// Deleting an empty slot returns `false` rather than throwing — the caller's
  /// intent ("make sure nothing is stored here") is already satisfied.
  Future<bool> remove(String slot);

  /// Releases any connections held by this client.
  void close();
}

// =============================================================================
// IN-MEMORY CLIENT
// =============================================================================

/// A [TomFileTransferClient] that keeps everything in a map.
///
/// For tests, for previews, and for offline modes — it honours the same
/// progress and cancellation contract as the HTTP client, so a widget wired to
/// it exercises the real code paths without a server.
class TomMemoryFileTransferClient extends TomFileTransferClient {
  /// Creates an empty in-memory transfer client.
  ///
  /// [chunkSize] is how large the pieces handed to `onProgress` are; the
  /// default is small enough that a test can observe several progress events
  /// for a modest payload.
  TomMemoryFileTransferClient({this.chunkSize = 64 * 1024});

  /// The chunk size used when replaying stored bytes.
  final int chunkSize;

  final Map<String, TomFileMetadata> _metadata = {};
  final Map<String, Uint8List> _bytes = {};

  int _keyCounter = 0;

  /// The slots currently holding a file.
  Iterable<String> get slots => _metadata.keys;

  @override
  Future<TomFileMetadata> upload({
    required String slot,
    required TomFileSource source,
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final builder = BytesBuilder();
    await for (final chunk in source.open()) {
      // Checked per chunk rather than once up front: this is the only place an
      // in-memory transfer can notice a cancellation that arrives mid-flight,
      // and a test that cancels needs it to behave like the HTTP client.
      if (cancellation?.isCancelled ?? false) {
        throw TomFileTransferException(
          'file_transfer.cancelled',
          'The file transfer was cancelled.',
          parameters: {'slot': slot},
        );
      }
      builder.add(chunk);
      onProgress?.call(TomTransferProgress(builder.length, source.byteCount));
    }
    final stored = builder.takeBytes();
    final metadata = TomFileMetadata(
      key: 'memory/${_keyCounter++}/${source.fileName}',
      mediaType: source.mediaType,
      byteCount: stored.length,
      fileName: source.fileName,
      storedAt: DateTime.now(),
    );
    _bytes[slot] = stored;
    _metadata[slot] = metadata;
    return metadata;
  }

  @override
  Stream<List<int>> download(
    String slot, {
    void Function(TomTransferProgress progress)? onProgress,
    TomTransferCancellation? cancellation,
  }) async* {
    cancellation?.throwIfCancelled();
    final stored = _bytes[slot];
    if (stored == null) {
      throw TomFileTransferException(
        'file_transfer.not_found',
        'No file is stored for the requested slot.',
        parameters: {'slot': slot},
      );
    }
    var offset = 0;
    while (offset < stored.length) {
      if (cancellation?.isCancelled ?? false) {
        throw TomFileTransferException(
          'file_transfer.cancelled',
          'The file transfer was cancelled.',
          parameters: {'slot': slot},
        );
      }
      final end = (offset + chunkSize).clamp(0, stored.length);
      yield Uint8List.sublistView(stored, offset, end);
      offset = end;
      onProgress?.call(TomTransferProgress(offset, stored.length));
    }
  }

  @override
  Future<TomFileMetadata?> describe(String slot) async => _metadata[slot];

  @override
  Future<bool> remove(String slot) async {
    _bytes.remove(slot);
    return _metadata.remove(slot) != null;
  }

  @override
  void close() {
    _bytes.clear();
    _metadata.clear();
  }
}

// =============================================================================
// DESCRIPTOR CODEC
// =============================================================================

/// Decodes the JSON descriptor body shared by the upload and describe
/// responses.
///
/// Extracted because both the HTTP client and any server implementing the wire
/// contract need the same shape, and a descriptor that only one side can read
/// is the classic way for a wire contract to drift.
TomFileMetadata decodeFileDescriptor(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (error, stack) {
    throw TomFileTransferException(
      'file_transfer.invalid_descriptor',
      'The server returned a file descriptor that is not valid JSON.',
      parameters: {'body': body},
      rootException: error,
      stack: stack,
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw TomFileTransferException(
      'file_transfer.invalid_descriptor',
      'The server returned a file descriptor that is not a JSON object.',
      parameters: {'body': body},
    );
  }
  return TomFileMetadata.fromJson(decoded);
}

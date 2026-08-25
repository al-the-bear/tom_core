/// The blob-storage contract: bytes under a key, put and got as streams.
///
/// This is the framework's general file/blob storage — the capability the
/// export module's deliberately narrow `TomExportStore` was written to be
/// adapted onto, and the server half of a persisted entity's *file-reference
/// column* (a column that holds a storage key rather than the bytes).
///
/// ## Why streams on both sides, and not `Uint8List`
///
/// A blob worth storing separately from its row is a blob large enough that
/// holding it — and the copy the next layer makes of it — is the failure. Every
/// method here therefore speaks in `Stream<List<int>>`: a 400 MB upload flows
/// from the socket into the backend without ever being whole in memory, and a
/// download flows back out the same way. A convenience that buffers is easy to
/// write at a call site that knows its blobs are small ([TomBlobStore.getBytes]
/// is that convenience); a streaming API cannot be recovered from a buffering
/// one.
///
/// ## Why four operations and no directory
///
/// Put, get, describe, delete. There is no `list`, no rename, no partial read,
/// no metadata update — not because they are hard, but because nothing in the
/// framework needs them and every one of them constrains the backends. `list`
/// in particular is the expensive lie: it is a cheap `readdir` on a filesystem
/// and a paginated, eventually-consistent API call on an object store, and an
/// interface that promises it invites callers to build on the filesystem's
/// version of it.
///
/// Keys are hierarchical by spelling (`2026/07/invoice.pdf`), so partitioning
/// is available without the store having to model directories.
///
/// ## Why a failed write must leave nothing
///
/// A truncated blob is indistinguishable from a complete one to whoever
/// downloads it next. Every backend here therefore commits atomically —
/// filesystem by writing a sibling `.part` and renaming, database by writing
/// chunks and only then the manifest row, S3 by aborting an incomplete
/// multipart upload. A [TomBlobStore.put] that throws has left the key holding
/// either its previous content or nothing at all.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../little_things/server_exception.dart';

/// The base error for every file-storage failure.
///
/// Subtypes [TomServerException], so the isolate attribution and request
/// correlation every other server error carries apply here too, and a
/// `catch (e) on TomServerException` in a pipeline reaches storage faults
/// without knowing about them.
class TomStorageException extends TomServerException {
  /// Creates a storage exception with a stable [key] and a user-facing
  /// [defaultUserMessage].
  TomStorageException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.clientThrow,
  });
}

/// What a stored blob is: its key, what it contains, how big it turned out.
///
/// Returned by [TomBlobStore.put] rather than assembled by the caller —
/// [byteCount] is only known once the stream has drained, and it is the field a
/// caller most often needs next (a `Content-Length`, a quota check, a log line).
class TomStoredBlob {
  /// Creates a stored-blob descriptor.
  const TomStoredBlob({
    required this.key,
    required this.mediaType,
    required this.byteCount,
    required this.storedAt,
    this.fileName,
    this.location,
  });

  /// The key the blob is stored under.
  final String key;

  /// The IANA media type the bytes should be served as.
  final String mediaType;

  /// The number of bytes stored.
  final int byteCount;

  /// When the write completed.
  final DateTime storedAt;

  /// The original file name, when one was supplied.
  ///
  /// Kept because a storage key is chosen by the framework (opaque, collision
  /// free, safe to put in a path) while the name a person expects to see in
  /// their downloads folder is the one they uploaded. Losing it means the
  /// application has to store it in a second column beside the key.
  final String? fileName;

  /// A backend-specific address — a `file:` URI, an object-store URL.
  ///
  /// Useful to a human chasing a blob down; never the thing to read it back
  /// with. [TomBlobStore.get] takes the [key], because only the store knows how
  /// its keys map to addresses.
  final Uri? location;

  /// The media type used when a caller states none.
  static const String defaultMediaType = 'application/octet-stream';

  @override
  String toString() => 'TomStoredBlob($key, $byteCount bytes, $mediaType)';
}

/// Stores and retrieves blobs by key.
///
/// Implemented by [TomMemoryBlobStore], `TomDirectoryBlobStore`,
/// `TomDatabaseBlobStore` and `TomS3BlobStore`; an application registers its own
/// with `TomBlobStoreInfo.registerBackend`.
abstract class TomBlobStore {
  /// Creates a store.
  const TomBlobStore();

  /// Writes [bytes] under [key], replacing anything already there.
  ///
  /// Returns the descriptor of what was written — notably [TomStoredBlob
  /// .byteCount], which is not known until the stream drains.
  ///
  /// A failure must leave **nothing** readable under [key] beyond what was
  /// there before: implementations commit atomically or not at all.
  Future<TomStoredBlob> put({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  });

  /// Reads the blob stored under [key].
  ///
  /// Throws a [TomStorageException] (`storage.blob.not_found`) when the key
  /// holds nothing: a caller reading a blob it holds a reference to and finding
  /// it gone has hit a real fault — an expiry it did not expect, a store it is
  /// not pointed at — and an empty stream would disguise that as an empty file.
  Stream<List<int>> get(String key);

  /// The descriptor for [key], or `null` when it holds nothing.
  ///
  /// The one read that is *allowed* to answer "nothing" without throwing,
  /// because asking what is there is a different question from asking for it.
  Future<TomStoredBlob?> describe(String key);

  /// Deletes [key], returning whether anything was there to delete.
  Future<bool> delete(String key);

  /// Whether [key] currently holds a blob.
  ///
  /// Defined in terms of [describe] so a backend implements one lookup, not
  /// two; override when a cheaper existence probe exists.
  Future<bool> exists(String key) async => await describe(key) != null;

  /// Reads [key] fully into memory.
  ///
  /// The convenience for the call sites that genuinely know their blobs are
  /// small — an avatar, a signature image, a CSV of a hundred rows. It is a
  /// helper on the streaming API rather than a second method on the contract
  /// precisely so that a backend author cannot implement it *instead of*
  /// streaming.
  Future<Uint8List> getBytes(String key) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in get(key)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// Writes [bytes] under [key] — the buffered counterpart to [getBytes].
  Future<TomStoredBlob> putBytes({
    required String key,
    required List<int> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  }) => put(
    key: key,
    bytes: Stream<List<int>>.value(bytes),
    mediaType: mediaType,
    fileName: fileName,
  );

  /// Releases whatever the backend holds open. Idempotent; the default does
  /// nothing, because most backends hold nothing.
  Future<void> close() async {}

  /// Whether [key] is a well-formed storage key.
  ///
  /// The single definition of the key grammar, exposed as a predicate so that
  /// every surface with its own error vocabulary — [validateKey] here,
  /// `TomExportStore.validateKey` in the export module — can enforce the same
  /// rule while throwing its own exception type.
  ///
  /// Keys are relative, slash-separated, and made of unreserved characters.
  /// The rule exists because the obvious backend maps keys onto paths, and a
  /// key of `../../etc/passwd` would then be a directory traversal handed to
  /// whatever built the key from a user-supplied file name.
  static bool isValidKey(String key) =>
      key.isNotEmpty &&
      key.length <= maxKeyLength &&
      !key.startsWith('/') &&
      !key.endsWith('/') &&
      !key.contains('\\') &&
      !key.contains('//') &&
      _keyPattern.hasMatch(key) &&
      !key.split('/').any((segment) => segment == '.' || segment == '..');

  /// Whether [keyPrefix] is usable as a key namespace.
  ///
  /// A prefix is not a separate notion from a key: it is joined to one as
  /// `"$keyPrefix/$key"`, so it must satisfy [isValidKey] itself or the join
  /// produces something no backend accepts. `null` and `''` both mean *no
  /// namespace* — a configured store leaves the setting unset, an unconfigured
  /// one defaults it to empty, and neither should have to say so twice.
  ///
  /// A trailing slash is deliberately **not** a second accepted spelling: the
  /// join supplies the separator, so `exports/` would yield
  /// `exports//sales.csv`, which the grammar rejects for the doubled slash.
  ///
  /// Length is the one clause a valid prefix cannot settle on its own — a
  /// prefix and a key may each be within [maxKeyLength] and still exceed it
  /// once joined. That depends on the key, so it stays where it can be seen:
  /// [validateKey], on the joined key, at the point of use.
  static bool isValidKeyPrefix(String? keyPrefix) =>
      keyPrefix == null || keyPrefix.isEmpty || isValidKey(keyPrefix);

  /// The longest key any backend accepts.
  ///
  /// 512 is comfortably under the shortest limit in play (S3 allows 1024 bytes;
  /// a filesystem path component 255) while being longer than any key a sane
  /// prefix scheme produces. Bounding it here means the database backend can
  /// declare a fixed-width indexed column and the filesystem backend cannot be
  /// handed a name the OS will reject.
  static const int maxKeyLength = 512;

  static final RegExp _keyPattern = RegExp(r'^[A-Za-z0-9._/-]+$');

  /// Validates [key] and returns it, throwing `storage.blob.invalid_key` when
  /// it does not satisfy [isValidKey].
  static String validateKey(String key) {
    if (!isValidKey(key)) {
      throw TomStorageException(
        'storage.blob.invalid_key',
        'The storage key is not a valid relative key.',
        parameters: {'key': key},
      );
    }
    return key;
  }

  /// Validates [keyPrefix] and returns it, throwing
  /// `storage.blob.invalid_key_prefix` when it does not satisfy
  /// [isValidKeyPrefix].
  ///
  /// A distinct error key from [validateKey], because the two faults call for
  /// different actions: a bad key is a caller's mistake, a bad prefix is a
  /// deployment's. The parameter is named `keyPrefix` and carries the prefix
  /// itself rather than a key derived from it — the derived key is one the
  /// caller never wrote, and naming it sends the reader to the wrong place.
  static String? validateKeyPrefix(String? keyPrefix) {
    if (!isValidKeyPrefix(keyPrefix)) {
      throw TomStorageException(
        'storage.blob.invalid_key_prefix',
        'The configured key prefix is not a valid key namespace.',
        parameters: {'keyPrefix': keyPrefix},
      );
    }
    return keyPrefix;
  }

  /// The error raised when [key] holds nothing — one spelling, so a caller can
  /// match on the key string and every backend agrees on it.
  static TomStorageException notFound(String key) => TomStorageException(
    'storage.blob.not_found',
    'No stored file exists for the requested key.',
    parameters: {'key': key},
  );
}

/// A store that keeps its contents in memory.
///
/// For tests, and for a development server that should not leave files behind.
/// It buffers whole blobs by definition, so it is the one place in this module
/// where that is acceptable — and the reason it is not the default.
class TomMemoryBlobStore extends TomBlobStore {
  /// Creates an empty in-memory store.
  TomMemoryBlobStore();

  final Map<String, Uint8List> _content = {};
  final Map<String, TomStoredBlob> _descriptors = {};

  /// The keys currently held, in insertion order.
  Iterable<String> get keys => _content.keys;

  /// The number of blobs held.
  int get length => _content.length;

  /// The stored bytes for [key] as text, for tests that assert on content.
  String textOf(String key) {
    final bytes = _content[key];
    if (bytes == null) throw TomBlobStore.notFound(key);
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Forgets everything, for a test that reuses one store across cases.
  void clear() {
    _content.clear();
    _descriptors.clear();
  }

  @override
  Future<TomStoredBlob> put({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  }) async {
    TomBlobStore.validateKey(key);
    final builder = BytesBuilder(copy: false);
    // Drained before either map is touched: a stream that throws half way must
    // not leave a half-written blob behind, exactly as on the other backends.
    await for (final chunk in bytes) {
      builder.add(chunk);
    }
    final content = builder.takeBytes();
    final descriptor = TomStoredBlob(
      key: key,
      mediaType: mediaType,
      byteCount: content.length,
      storedAt: DateTime.now(),
      fileName: fileName,
    );
    _content[key] = content;
    _descriptors[key] = descriptor;
    return descriptor;
  }

  @override
  Stream<List<int>> get(String key) async* {
    final bytes = _content[key];
    if (bytes == null) throw TomBlobStore.notFound(key);
    yield bytes;
  }

  @override
  Future<TomStoredBlob?> describe(String key) async => _descriptors[key];

  @override
  Future<bool> exists(String key) async => _content.containsKey(key);

  @override
  Future<bool> delete(String key) async {
    _descriptors.remove(key);
    return _content.remove(key) != null;
  }

  @override
  String toString() => 'TomMemoryBlobStore(${_content.length} blobs)';
}

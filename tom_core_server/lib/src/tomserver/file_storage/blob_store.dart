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
///
/// ## Why every failure arrives as a storage error
///
/// The faults that stop a store come from the layer underneath it and speak
/// that layer's language: a `FileSystemException`, a driver error, an HTTP
/// status. A backend that lets those through makes the caller's error handling
/// depend on which backend it was configured with, and slips past every
/// `on TomServerException` between it and the request boundary.
///
/// So a failure is translated into one of [TomBlobStoreOperation]'s keys,
/// keeping the original as `rootException`. The module's own answers —
/// `not_found`, `invalid_key`, `missing_chunk`, `same_key` — pass through
/// untranslated, because callers branch on them.
///
/// The translation is [TomBlobStore]'s own, not each backend's: a backend
/// implements `doPut`, `doGet`, `doDescribe`, `doDelete` and the public methods
/// wrap them. The same wrapper is what validates the key, so both obligations
/// hold for every backend including ones written later — see [TomBlobStore]'s
/// "Why the public methods are final".
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

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

/// What a store was doing when its infrastructure refused.
///
/// Storage faults come from somewhere else — a full disk, a denied permission,
/// a bucket that answered 500 — and arrive as that layer's own exception type:
/// a `FileSystemException`, a `MySqlException`, a socket error. Letting those
/// reach the caller means a pipeline that catches [TomServerException] does not
/// catch storage at all, and a caller that wants to distinguish *what failed*
/// has to know which backend it was configured with.
///
/// So each backend translates, and this enum is the vocabulary it translates
/// into: four operations, one error key and one user-facing message each,
/// spelled once so every backend agrees. It mirrors `TomExportStoreOperation`
/// in the export module deliberately — the same four questions are being asked
/// of the same kinds of infrastructure, and two different answers for one fault
/// would be an accident of which module the caller came through.
///
/// The division is by *what the caller asked for*, not by which call threw:
/// [read] is "give me the bytes", [probe] is "tell me about the blob"
/// ([TomBlobStore.describe] and [TomBlobStore.exists]), and a sidecar that
/// cannot be read during a `describe` is therefore a [probe] failure even
/// though a file read is what failed.
enum TomBlobStoreOperation {
  /// Storing bytes under a key.
  write(
    'storage.blob.write_failed',
    'The file could not be written to storage.',
  ),

  /// Reading a blob's bytes back.
  read('storage.blob.read_failed', 'The stored file could not be read.'),

  /// Asking what is stored under a key, or whether anything is.
  probe(
    'storage.blob.probe_failed',
    'Storage could not be asked about the file.',
  ),

  /// Removing what a key holds.
  delete('storage.blob.delete_failed', 'The stored file could not be deleted.'),

  /// Putting what one key holds under a second one as well.
  copy('storage.blob.copy_failed', 'The stored file could not be copied.'),

  /// Moving what one key holds to another.
  move('storage.blob.move_failed', 'The stored file could not be moved.');

  const TomBlobStoreOperation(this.errorKey, this.message);

  /// The stable error key a caller matches on.
  final String errorKey;

  /// The user-facing message carried by the raised exception.
  final String message;
}

/// What a stored blob is: its key, what it contains, how big it turned out.
///
/// Returned by [TomBlobStore.put] rather than assembled by the caller —
/// [byteCount] is only known once the stream has drained, and it is the field a
/// caller most often needs next (a `Content-Length`, a quota check, a log line).
class TomStoredBlob {
  /// Creates a stored-blob descriptor.
  ///
  /// [storedAt] is normalised to UTC here rather than at each construction
  /// site, which is what makes the zone a property of the *type*: a backend
  /// added later cannot forget it, and there is one place to read the rule.
  /// Every backend sources the value locally — `DateTime.now()` on three of
  /// them, the filesystem's `stat.modified` on the fourth — so without this a
  /// descriptor written in Berlin and read in Denver disagreed with itself by
  /// the offset. `TomAuditAnchor` and `TomOAuthTokens` normalise the same way.
  TomStoredBlob({
    required this.key,
    required this.mediaType,
    required this.byteCount,
    required DateTime storedAt,
    this.digest = unknownDigest,
    this.fileName,
    this.location,
  }) : storedAt = storedAt.toUtc();

  /// The key the blob is stored under.
  final String key;

  /// The IANA media type the bytes should be served as.
  final String mediaType;

  /// The number of bytes stored.
  final int byteCount;

  /// When the write completed, always in UTC.
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

  /// The lowercase hex SHA-256 of the stored bytes, or [unknownDigest].
  ///
  /// **Every blob written through [TomBlobStore.put] has one**, whichever
  /// backend is configured: the hash is computed while the bytes stream past,
  /// on a pass the backend is making anyway, and recorded beside the media type
  /// and the file name. That is what makes it something a caller can build on —
  /// an integrity check after a transfer, a deduplication key before one, an
  /// `ETag` a download endpoint can serve.
  ///
  /// It is [unknownDigest] for a blob **this framework did not write**: a file
  /// dropped into a directory store's tree by hand, an object already in a
  /// bucket the store was pointed at. Those have no recorded media type either
  /// and fall back to [defaultMediaType]; the digest's counterpart is a named
  /// empty string rather than `null`, so that "not recorded" cannot be confused
  /// with the digest of zero bytes — which is a real, well-known value.
  /// [hasDigest] is the question to ask.
  final String digest;

  /// The media type used when a caller states none.
  static const String defaultMediaType = 'application/octet-stream';

  /// The [digest] of a blob whose hash was never recorded.
  static const String unknownDigest = '';

  /// Whether [digest] holds a hash rather than [unknownDigest].
  bool get hasDigest => digest != unknownDigest;

  @override
  String toString() => 'TomStoredBlob($key, $byteCount bytes, $mediaType)';
}

/// The running SHA-256 of a blob, fed chunk by chunk as it is stored.
///
/// A backend hashes on the pass it is already making — a file write, a chunk
/// insert, a part upload — so the digest costs no extra read. Public because
/// [TomStoredBlob.digest] is a promise every backend has to keep, including one
/// an application writes, and a promise the framework does not make easy to
/// keep is one that gets broken.
///
/// ```dart
/// final digest = TomBlobDigest();
/// await for (final chunk in bytes) {
///   digest.add(chunk);
///   await sink.add(chunk);
/// }
/// final hex = digest.close();
/// ```
class TomBlobDigest {
  /// Starts an empty hash.
  TomBlobDigest() {
    _input = sha256.startChunkedConversion(_output);
  }

  final _DigestSink _output = _DigestSink();
  late final ByteConversionSink _input;
  String? _hex;

  /// Feeds [chunk] to the running hash.
  ///
  /// The chunk is read, never retained — which is what lets a backend pass the
  /// same borrowed buffer here that it is about to write.
  void add(List<int> chunk) {
    if (_hex != null) {
      throw StateError('TomBlobDigest.add after close');
    }
    _input.add(chunk);
  }

  /// The lowercase hex digest of everything added.
  ///
  /// Idempotent: calling it again returns the same string rather than closing a
  /// closed hash, so a backend with more than one exit path does not have to
  /// track which one ran.
  String close() {
    if (_hex != null) return _hex!;
    _input.close();
    return _hex = _output.value
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// The hex SHA-256 of [bytes], for a caller holding them whole.
  static String of(List<int> bytes) => (TomBlobDigest()..add(bytes)).close();
}

/// Catches the one digest `startChunkedConversion` emits on close.
class _DigestSink implements Sink<Digest> {
  late final List<int> value;

  @override
  void add(Digest data) => value = data.bytes;

  @override
  void close() {}
}

/// A half-open byte range of a stored blob: [start] inclusive, [endExclusive]
/// exclusive.
///
/// Half-open because that is what `File.openRead` and `List.sublist` take, and
/// the backends are where this ends up. HTTP's `Range` is inclusive-at-both-ends
/// and a *suffix* form (`bytes=-500`) has no start at all; both are resolved
/// against the blob's known size before they reach here, by whoever read the
/// header. This type is the resolved one, so a backend never has to reason
/// about a range it cannot check.
///
/// Both ends are checked at construction rather than at the backend, so every
/// store refuses the same nonsense the same way — the same reason key
/// validation sits on [TomBlobStore] and not in each `do*`.
class TomBlobRange {
  /// A range from [start] up to but not including [endExclusive].
  ///
  /// [endExclusive] `null` means *to the end of the blob*, which is the form a
  /// `bytes=500-` header takes and the only one that needs no size to resolve.
  ///
  /// Throws [TomStorageException] (`storage.blob.invalid_range`) for a negative
  /// start or an end at or before it. An empty range is refused rather than
  /// answered with an empty stream: a zero-length read is a caller's arithmetic
  /// going wrong, and an empty body is how that mistake reaches a user as a
  /// corrupt download.
  TomBlobRange(this.start, [this.endExclusive]) {
    if (start < 0 || (endExclusive != null && endExclusive! <= start)) {
      throw TomStorageException(
        'storage.blob.invalid_range',
        'That byte range is not a range.',
        parameters: {'start': start, 'endExclusive': endExclusive},
      );
    }
  }

  /// The first byte to read, counted from zero.
  final int start;

  /// One past the last byte to read, or `null` to read to the end.
  final int? endExclusive;

  /// How many bytes this range covers, or `null` when it runs to the end.
  int? get length => endExclusive == null ? null : endExclusive! - start;

  /// This range clamped to a blob of [byteCount] bytes, or `null` when it lies
  /// wholly beyond it.
  ///
  /// `null` is the answer HTTP calls *unsatisfiable*: a start at or past the
  /// end names no byte, and the correct response is a refusal rather than an
  /// empty body. A range that merely *overshoots* is not unsatisfiable — it is
  /// clamped, because asking for more than there is and getting what there is
  /// is how a resumed download ends.
  TomBlobRange? clampedTo(int byteCount) {
    if (start >= byteCount) return null;
    final end = endExclusive;
    if (end == null || end > byteCount) return TomBlobRange(start, byteCount);
    return this;
  }

  @override
  String toString() => 'TomBlobRange($start, $endExclusive)';
}

/// Stores and retrieves blobs by key.
///
/// Implemented by [TomMemoryBlobStore], `TomDirectoryBlobStore`,
/// `TomDatabaseBlobStore` and `TomS3BlobStore`; an application registers its own
/// with `TomBlobStoreInfo.registerBackend`.
///
/// ## Why the public methods are final
///
/// A backend implements [doPut], [doGet], [doDescribe] and [doDelete], and
/// optionally sharpens [doExists], [doGetRange], [doCopy] and [doMove], each of
/// which is concrete and built from the four; the public methods are this
/// class's own and wrap them. That indirection buys two guarantees no backend can forget:
///
/// - **Every key is validated**, on reads as well as writes, so a key that is
///   refused is refused the same way whichever backend is configured — and a
///   backend written later, or by an application, cannot be handed a directory
///   traversal.
/// - **Every failure arrives as a [TomStorageException]** carrying the error key
///   [TomBlobStoreOperation] names for the operation that failed, so a caller
///   catches one type rather than a socket exception here and a database
///   exception there.
///
/// Both properties were previously left to each backend to honour, and each
/// backend honoured a different subset of them: three of the four validated on
/// `put` alone, so `get('../escape')` answered `invalid_key` on a directory
/// store and `not_found` on a memory one — the wrong error, and for a caller
/// branching on the two, the wrong branch.
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
  ///
  /// A chunk arriving from [bytes] is **borrowed for the duration of the
  /// `await`**: an implementation must consume or copy it before asking for the
  /// next one, and must not retain it. A producer refilling one scratch buffer
  /// per chunk is the ordinary shape of an encoder, and a store that kept the
  /// list would record that buffer's last state once per chunk.
  Future<TomStoredBlob> put({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  }) => _translating(
    TomBlobStoreOperation.write,
    key,
    () => doPut(
      key: validateKey(key),
      bytes: bytes,
      mediaType: mediaType,
      fileName: fileName,
    ),
  );

  /// Reads the blob stored under [key].
  ///
  /// Throws a [TomStorageException] (`storage.blob.not_found`) when the key
  /// holds nothing: a caller reading a blob it holds a reference to and finding
  /// it gone has hit a real fault — an expiry it did not expect, a store it is
  /// not pointed at — and an empty stream would disguise that as an empty file.
  ///
  /// Each chunk **belongs to the caller**: writable, and not aliased with
  /// anything the store keeps. The backends that read from a file, a row or a
  /// socket get this for free — the memory backend is the only one that has to
  /// choose, and it copies. Both halves are load-bearing. Handing back an
  /// internal buffer lets a consumer decoding in place edit the stored blob;
  /// handing back an unmodifiable view would instead make that same consumer
  /// throw on the backend the tests run on and succeed on every other, which is
  /// the worse trade.
  ///
  /// A transfer that breaks partway **still delivers the chunks that arrived**,
  /// and then fails. Both halves are the contract. A consumer that has already
  /// written the first megabytes to a file can truncate what it has; one handed
  /// nothing at all cannot tell a broken download from an empty object. That is
  /// why the failure is translated *around* the forwarding rather than by
  /// draining the backend's stream first: buffering here would be invisible to
  /// anyone reading a small blob, and would quietly turn every interrupted
  /// download into an empty one.
  Stream<List<int>> get(String key, {TomBlobRange? range}) async* {
    try {
      final validated = validateKey(key);
      // `await for`, not `yield*`: a `yield*` forwards the inner stream's
      // *errors* straight to the output stream, past the enclosing try, so the
      // translation below would never see the failure it exists to translate.
      // Re-yielding each chunk as it arrives is also what keeps the read
      // streaming, and so what keeps the partial delivery above true.
      await for (final chunk
          in range == null ? doGet(validated) : doGetRange(validated, range)) {
        yield chunk;
      }
    } on TomStorageException catch (error, stack) {
      // The same rule [_translating] applies, spelled out here because a
      // `Stream` cannot be routed through it: an `async*` body owns its own
      // `try`, and handing the stream to a helper would put the helper's
      // `await` between the backend and the consumer — which is exactly the
      // buffering the partial-delivery contract above forbids.
      if (passThroughErrorKeys.contains(error.key)) rethrow;
      throw _asStorageException(TomBlobStoreOperation.read, key, error, stack);
    } on Object catch (error, stack) {
      throw _asStorageException(TomBlobStoreOperation.read, key, error, stack);
    }
  }

  /// The descriptor for [key], or `null` when it holds nothing.
  ///
  /// The one read that is *allowed* to answer "nothing" without throwing,
  /// because asking what is there is a different question from asking for it.
  Future<TomStoredBlob?> describe(String key) => _translating(
    TomBlobStoreOperation.probe,
    key,
    () => doDescribe(validateKey(key)),
  );

  /// Copies the blob at [fromKey] to [toKey], returning the new descriptor.
  ///
  /// A relocation is an ordinary thing to want: the documented pattern for
  /// expiry is a date-prefixed key, so re-partitioning happens, and without
  /// this it means pulling every byte through the server and pushing it back.
  ///
  /// Anything already at [toKey] is **replaced**, as it is by [put] — the same
  /// rule, because a copy is a write and a second one about overwriting would
  /// be a rule to remember. The media type and file name travel with the bytes:
  /// a copy that lost its `Content-Type` would be served as
  /// `application/octet-stream` and download as a file nothing opens.
  ///
  /// Throws [TomStorageException] (`storage.blob.not_found`) when [fromKey]
  /// holds nothing, (`storage.blob.invalid_key`) for a key outside the grammar,
  /// (`storage.blob.same_key`) when the two are equal, and
  /// (`storage.blob.copy_failed`) when the backend fails.
  Future<TomStoredBlob> copy(String fromKey, String toKey) => _translating(
    TomBlobStoreOperation.copy,
    fromKey,
    () => doCopy(
      validateKey(fromKey),
      _differentKey(TomBlobStoreOperation.copy, fromKey, toKey),
    ),
  );

  /// Moves the blob at [fromKey] to [toKey], returning the new descriptor.
  ///
  /// The source is gone when this returns. Ordering is the whole contract: the
  /// destination is committed *before* the source is removed, so an interrupted
  /// move leaves the blob readable under both keys rather than under neither.
  /// The residue of a failed move is a duplicate, which a retry converges on;
  /// the residue of the other order is a deletion.
  ///
  /// Same replacement rule, same errors as [copy], under
  /// `storage.blob.move_failed`.
  Future<TomStoredBlob> move(String fromKey, String toKey) => _translating(
    TomBlobStoreOperation.move,
    fromKey,
    () => doMove(
      validateKey(fromKey),
      _differentKey(TomBlobStoreOperation.move, fromKey, toKey),
    ),
  );

  /// [toKey] validated, and refused when it is [fromKey].
  ///
  /// Copying a key onto itself has no meaning worth guessing at, and the
  /// obvious implementation — read it, write it back — is a truncation on any
  /// backend whose write is not atomic. S3 refuses it outright without a
  /// metadata directive. So it is one error rather than four behaviours.
  static String _differentKey(
    TomBlobStoreOperation operation,
    String fromKey,
    String toKey,
  ) {
    final validated = validateKey(toKey);
    if (validated == validateKey(fromKey)) {
      throw TomStorageException(
        'storage.blob.same_key',
        'A file cannot be ${operation == TomBlobStoreOperation.copy ? 'copied' : 'moved'} onto itself.',
        parameters: {'key': toKey, 'operation': operation.name},
      );
    }
    return validated;
  }

  /// Deletes [key], returning whether anything was there to delete.
  Future<bool> delete(String key) => _translating(
    TomBlobStoreOperation.delete,
    key,
    () => doDelete(validateKey(key)),
  );

  /// Whether [key] currently holds a blob.
  Future<bool> exists(String key) => _translating(
    TomBlobStoreOperation.probe,
    key,
    () => doExists(validateKey(key)),
  );

  /// Writes a validated [key]. Implemented by backends; called by [put].
  ///
  /// A backend that fails part-way through cleans up and lets the failure out:
  /// [put] names the operation. Throwing a [TomStorageException] by hand is for
  /// the cases where the backend knows something the wrapper cannot.
  Future<TomStoredBlob> doPut({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  });

  /// Reads a validated [key]. Implemented by backends; called by [get].
  Stream<List<int>> doGet(String key);

  /// Reads [range] of a validated [key]. Called by [get] when one is given.
  ///
  /// Defined in terms of [doGet] so a backend implements one read path, not
  /// two — the same arrangement as [doExists] over [doDescribe]. **Override it
  /// when the backend can seek**, which is every backend shipped here: a file
  /// opens at an offset, a chunked row set skips whole rows, and S3 takes a
  /// `Range` header. The default reads from zero and discards everything before
  /// the range, stopping once the range is served — correct, and costing the
  /// prefix, which for a seek near the end of a large blob is the whole thing.
  ///
  /// Putting the discarding here rather than in the caller is the point. A
  /// download endpoint honouring HTTP `Range` needs *a* range read from every
  /// backend, and writing the fallback at the endpoint would mean the S3
  /// backend's native capability were unreachable through the interface.
  ///
  /// A range that runs past the end of the blob yields what there is rather
  /// than failing: [get] cannot know the size without a second lookup, and the
  /// caller that does know — the endpoint — has already refused an
  /// unsatisfiable one with [TomBlobRange.clampedTo].
  Stream<List<int>> doGetRange(String key, TomBlobRange range) async* {
    var position = 0;
    await for (final chunk in doGet(key)) {
      final end = position + chunk.length;
      if (end > range.start) {
        final from = range.start > position ? range.start - position : 0;
        final limit = range.endExclusive;
        final to = limit == null || limit >= end
            ? chunk.length
            : limit - position;
        yield chunk.sublist(from, to);
      }
      position = end;
      if (range.endExclusive != null && position >= range.endExclusive!) return;
    }
  }

  /// Describes a validated [key]. Implemented by backends; called by [describe].
  Future<TomStoredBlob?> doDescribe(String key);

  /// Deletes a validated [key]. Implemented by backends; called by [delete].
  Future<bool> doDelete(String key);

  /// Copies a validated [fromKey] to a validated [toKey]. Called by [copy].
  ///
  /// Concrete, and a stream round trip: read the source, write it to the
  /// destination. **Override it wherever the backend can do it without the
  /// bytes leaving** — which is every backend shipped here, because each has a
  /// native answer: a filesystem copy, a map entry, an `INSERT` that shares the
  /// chunks, an `x-amz-copy-source` header.
  ///
  /// A concrete default is right here in a way it would not be for a listing.
  /// The cost of this one is not misleading — a stream round trip is exactly as
  /// expensive as it looks — whereas a default `list` would hide a paginated
  /// scan behind a method that reads like a map lookup.
  Future<TomStoredBlob> doCopy(String fromKey, String toKey) async {
    final source = await doDescribe(fromKey);
    if (source == null) throw notFound(fromKey);
    return doPut(
      key: toKey,
      bytes: doGet(fromKey),
      mediaType: source.mediaType,
      fileName: source.fileName,
    );
  }

  /// Moves a validated [fromKey] to a validated [toKey]. Called by [move].
  ///
  /// Concrete, and defined as a copy followed by a delete — in that order, so
  /// an interruption leaves a duplicate rather than a hole. Override it where
  /// the backend can rename: a filesystem does, and a manifest row's key is a
  /// column to update.
  Future<TomStoredBlob> doMove(String fromKey, String toKey) async {
    final moved = await doCopy(fromKey, toKey);
    await doDelete(fromKey);
    return moved;
  }

  /// Whether a validated [key] holds a blob. Called by [exists].
  ///
  /// Defined in terms of [doDescribe] so a backend implements one lookup, not
  /// two; override when a cheaper existence probe exists.
  Future<bool> doExists(String key) async => await doDescribe(key) != null;

  /// Reads [key] fully into memory.
  ///
  /// The convenience for the call sites that genuinely know their blobs are
  /// small — an avatar, a signature image, a CSV of a hundred rows. It is a
  /// helper on the streaming API rather than a second method on the contract
  /// precisely so that a backend author cannot implement it *instead of*
  /// streaming.
  Future<Uint8List> getBytes(String key, {TomBlobRange? range}) async {
    // Non-copying, which is safe only because [get] yields chunks the caller
    // owns: a lone chunk comes back from `takeBytes` untouched, so this method
    // is exactly as aliased as what the backend yielded.
    final builder = BytesBuilder(copy: false);
    await for (final chunk in get(key, range: range)) {
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

  /// [name] rewritten into one key segment, so that a human-chosen name can
  /// *become* a key rather than merely be tested against the grammar.
  ///
  /// It lives beside [isValidKey] because the two are one grammar spelled
  /// twice, and a sanitiser that drifts from its own validator produces the
  /// worst outcome available: output that is refused by the check it was
  /// written to satisfy. `sanitiseKeySegment(x)` is a valid key for every [name]
  /// short enough to be one — asserted over the code-unit range in
  /// `export_test.dart`, not merely intended.
  ///
  /// **One segment, never two.** `/` and `\` are replaced like any other
  /// disallowed character, so a name cannot contribute path structure. Whatever
  /// builds a key decides its shape; a name is only ever a part of it. That is
  /// also what defuses `../../etc/passwd` — not by refusing it, but by leaving
  /// it nothing to traverse with.
  ///
  /// **Length is the one fault it does not repair.** A name over
  /// [maxKeyLength] comes back over [maxKeyLength] and [validateKey] refuses
  /// it. Truncating would silently give two different names the same key, and
  /// the second write would replace the first with nothing reported anywhere —
  /// a refusal the caller can see is strictly better than a collision it
  /// cannot.
  ///
  /// [fallback] is returned when nothing usable survives — an empty name,
  /// whitespace, or one of the two segments the grammar reserves. It must
  /// itself be a valid key.
  static String sanitiseKeySegment(String name, {String fallback = 'file'}) {
    assert(isValidKey(fallback), 'the fallback must itself be a valid key');
    final sanitised = name.trim().replaceAll(_unsafeSegmentCharacters, '_');
    if (sanitised.isEmpty || sanitised == '.' || sanitised == '..') {
      return fallback;
    }
    return sanitised;
  }

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
  /// Length is the one clause this cannot settle — a prefix and a key may each
  /// be within [maxKeyLength] and still exceed it once joined, which depends on
  /// a key that has not arrived yet. So the obligation belongs to whoever
  /// performs the join, and every site that performs one discharges it: those
  /// that join *above* a store hand the result to [validateKey] and get it for
  /// free, and `TomS3BlobStore`, which joins below that boundary — the prefix
  /// goes straight into a signed URI — checks the length itself.
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

  /// A character no valid key can contain, for backends that keep bookkeeping
  /// files alongside the blobs themselves.
  ///
  /// A backend storing blobs as files needs somewhere to put what a filesystem
  /// will not hold — a metadata sidecar, the partial a write is staged in — and
  /// the obvious naming, `<key>.meta`, is a trap: `.` is an ordinary key
  /// character and only the segments `.` and `..` are reserved, so `a.meta` is
  /// a key a caller may legitimately choose. Two callers picking ordinary keys
  /// then destroy each other's data, neither having done anything wrong.
  ///
  /// Suffixing with this marker instead makes the bookkeeping *unaddressable*:
  /// [isValidKey] admits `[A-Za-z0-9._/-]` and nothing else, so no key that
  /// reaches a backend can name a file suffixed with it. `~` is legal in a
  /// filename everywhere this runs — POSIX reserves only `/`, Windows only
  /// `<>:"/\|?*` — and is the conventional mark of an auxiliary file.
  ///
  /// It lives on the contract rather than in a backend because it is a fact
  /// about [isValidKey], which is defined here and shared by every store
  /// including `TomExportStore`. The *suffixes* are each backend's own storage
  /// layout and stay with the backend; only the guarantee that they cannot be
  /// spelled is common.
  static const String auxiliaryMarker = '~';

  static final RegExp _keyPattern = RegExp(r'^[A-Za-z0-9._/-]+$');

  /// What [sanitiseKeySegment] replaces: [_keyPattern]'s character class
  /// negated, minus the separator — a *segment* may not contain one even though
  /// a key may. Kept adjacent so the one deliberate difference between the two
  /// is visible rather than inferred.
  static final RegExp _unsafeSegmentCharacters = RegExp(r'[^A-Za-z0-9._-]');

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

  /// The error keys that reach a caller as the backend raised them.
  ///
  /// Everything a store can go wrong at is reported under one of the four
  /// [TomBlobStoreOperation] keys, whichever backend is configured. These four
  /// are the exceptions, and they are exceptions because they are *answers*
  /// rather than failures: the key held nothing, the key was not a key, the
  /// deployment's prefix leaves no room for one, the blob's chunks do not add
  /// up. A caller branches on them — `TomBlobExportStore` on `not_found`, the
  /// file endpoint on its 404 — so translating them would turn a decision the
  /// caller can make into a failure it can only report.
  ///
  /// Every one is raised by code every backend shares, or by a rule every
  /// backend is held to, so none of them tells a caller which backend it got.
  /// That is the test for membership, not "the module happens to raise it":
  /// `invalid_key_prefix` is raised inside the S3 backend as well as by
  /// [validateKeyPrefix], and belongs here because the limit it enforces is
  /// [maxKeyLength] — the rule every backend obeys — rather than S3's own.
  ///
  /// The list is closed on purpose, and that is the whole of the module's
  /// backend-independence claim. A `TomStorageException` a backend raises under
  /// any other key is wrapped like any other fault, so a caller switching on
  /// `error.key` sees the same key whether the deployment is configured with
  /// the S3 backend, the directory backend or one the application wrote. The
  /// backend's own exception survives as `rootException`: still in the log,
  /// still carrying its `status` and `code`, no longer part of the contract a
  /// caller is written against.
  static const Set<String> passThroughErrorKeys = {
    'storage.blob.not_found',
    'storage.blob.invalid_key',
    'storage.blob.invalid_key_prefix',
    'storage.blob.missing_chunk',
    'storage.blob.same_key',
  };

  /// The error raised when [key] holds nothing — one spelling, so a caller can
  /// match on the key string and every backend agrees on it.
  static TomStorageException notFound(String key) => TomStorageException(
    'storage.blob.not_found',
    'No stored file exists for the requested key.',
    parameters: {'key': key},
  );

  /// [error] restated as the storage failure of [operation] on [key].
  ///
  /// The original is kept as `rootException` rather than summarised into the
  /// message: the caller needs a key it can branch on, and whoever reads the
  /// log needs the `errno` that actually explains it.
  static TomStorageException _asStorageException(
    TomBlobStoreOperation operation,
    String key,
    Object error,
    StackTrace stack,
  ) => TomStorageException(
    operation.errorKey,
    operation.message,
    parameters: {'key': key},
    rootException: error,
    stack: stack,
  );

  /// Runs [body], reporting any infrastructure failure as [operation] on [key].
  ///
  /// A [TomStorageException] passes through only when its key is one of
  /// [passThroughErrorKeys], which is the clause that makes this safe to wrap a
  /// whole method in without also making the caller's error handling depend on
  /// which backend the deployment configured.
  ///
  /// Matched on the key rather than on the type. The type is what every
  /// backend's own failures are raised as too, so catching it let
  /// `storage.s3.request_failed` and its siblings past the translation the
  /// module exists to perform — for the same fault, a caller heard one key on
  /// S3 and another on the directory backend.
  ///
  /// Private, because the wrapping is now the contract's own job rather than
  /// something a backend opts into: a helper a backend *may* call is a helper a
  /// backend may forget, which is the state this replaced.
  static Future<T> _translating<T>(
    TomBlobStoreOperation operation,
    String key,
    Future<T> Function() body,
  ) async {
    try {
      return await body();
    } on TomStorageException catch (error, stack) {
      if (passThroughErrorKeys.contains(error.key)) rethrow;
      throw _asStorageException(operation, key, error, stack);
    } on Object catch (error, stack) {
      throw _asStorageException(operation, key, error, stack);
    }
  }
}

/// A store that keeps its contents in memory.
///
/// For tests, and for a development server that should not leave files behind.
/// It buffers whole blobs by definition, so it is the one place in this module
/// where that is acceptable — and the reason it is not the default.
///
/// Because it holds the bytes instead of reading them back off a disk or a
/// bucket, it is the only backend that can accidentally share a buffer with a
/// caller, in either direction. So it is the only one that copies on purpose:
/// what [get] yields is the reader's own, and what [put] is streamed is copied
/// before the next chunk is asked for. [TomBlobStore] requires both of every
/// backend; they are noted here because here they are a choice.
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
  ///
  /// Validates like the contract's own methods do, so a test that mistypes a
  /// key is told it mistyped one rather than that the blob is missing.
  String textOf(String key) {
    final bytes = _content[TomBlobStore.validateKey(key)];
    if (bytes == null) throw TomBlobStore.notFound(key);
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Forgets everything, for a test that reuses one store across cases.
  void clear() {
    _content.clear();
    _descriptors.clear();
  }

  @override
  Future<TomStoredBlob> doPut({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  }) async {
    // Copying, because the chunks are the caller's and are only borrowed for
    // the `await`. The non-copying builder retains the lists it is given, so a
    // producer refilling one scratch buffer stored that buffer's last state
    // once per chunk, and `putBytes` — a single-element stream — adopted the
    // caller's list outright.
    final builder = BytesBuilder();
    // Drained before either map is touched: a stream that throws half way must
    // not leave a half-written blob behind, exactly as on the other backends.
    await for (final chunk in bytes) {
      builder.add(chunk);
    }
    final content = builder.takeBytes();
    // Hashed from the assembled buffer rather than chunk by chunk: this is the
    // one backend that holds the whole blob anyway, so there is nothing to
    // stream past.
    final descriptor = TomStoredBlob(
      key: key,
      mediaType: mediaType,
      byteCount: content.length,
      storedAt: DateTime.now(),
      digest: TomBlobDigest.of(content),
      fileName: fileName,
    );
    _content[key] = content;
    _descriptors[key] = descriptor;
    return descriptor;
  }

  @override
  Stream<List<int>> doGet(String key) async* {
    final bytes = _content[key];
    if (bytes == null) throw TomBlobStore.notFound(key);
    // Copied, so the caller gets what [TomBlobStore.get] promises and what
    // every other backend produces without trying: a writable chunk of its own.
    // The cost is one memcpy per read on the backend that exists for tests and
    // development servers — the one place where fidelity beats speed.
    yield Uint8List.fromList(bytes);
  }

  @override
  Stream<List<int>> doGetRange(String key, TomBlobRange range) async* {
    final bytes = _content[key];
    if (bytes == null) throw TomBlobStore.notFound(key);
    // The inherited default would read the whole blob and discard the prefix.
    // Here the whole blob is a list, so the range is a sublist — and `sublist`
    // copies, which is the same promise `doGet` keeps one line above.
    final end = (range.endExclusive ?? bytes.length).clamp(0, bytes.length);
    final start = range.start.clamp(0, end);
    yield Uint8List.fromList(bytes.sublist(start, end));
  }

  @override
  Future<TomStoredBlob> doCopy(String fromKey, String toKey) async {
    final bytes = _content[fromKey];
    final source = _descriptors[fromKey];
    if (bytes == null || source == null) throw TomBlobStore.notFound(fromKey);
    // Copied rather than aliased. Defensive rather than load-bearing, and worth
    // saying which: nothing mutates a stored list in place today — `doGet`
    // hands out a copy and `doPut` assigns a fresh buffer — so a shared list
    // has no observable consequence and no test can catch its absence. What it
    // buys is that the first code to mutate one in place finds two blobs rather
    // than one, on the backend whose stated trade is fidelity over speed.
    final copied = Uint8List.fromList(bytes);
    final descriptor = TomStoredBlob(
      key: toKey,
      mediaType: source.mediaType,
      byteCount: copied.length,
      storedAt: DateTime.now(),
      // The same bytes, so the same hash — and carried rather than recomputed,
      // which is the point of a copy that does not read the blob.
      digest: source.digest,
      fileName: source.fileName,
    );
    _content[toKey] = copied;
    _descriptors[toKey] = descriptor;
    return descriptor;
  }

  @override
  Future<TomStoredBlob> doMove(String fromKey, String toKey) async {
    final moved = await doCopy(fromKey, toKey);
    _content.remove(fromKey);
    _descriptors.remove(fromKey);
    return moved;
  }

  @override
  Future<TomStoredBlob?> doDescribe(String key) async => _descriptors[key];

  @override
  Future<bool> doExists(String key) async => _content.containsKey(key);

  @override
  Future<bool> doDelete(String key) async {
    _descriptors.remove(key);
    return _content.remove(key) != null;
  }

  @override
  String toString() => 'TomMemoryBlobStore(${_content.length} blobs)';
}

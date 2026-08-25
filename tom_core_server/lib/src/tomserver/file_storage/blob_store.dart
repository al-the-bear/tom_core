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
/// So a failure is translated into [TomBlobStoreOperation]'s four keys, keeping
/// the original as `rootException`. The module's own answers — `not_found`,
/// `invalid_key`, `missing_chunk` — pass through untranslated, because callers
/// branch on them.
///
/// The translation is [TomBlobStore]'s own, not each backend's: a backend
/// implements `doPut`, `doGet`, `doDescribe`, `doDelete` and the five public
/// methods wrap them. The same wrapper is what validates the key, so both
/// obligations hold for every backend including ones written later — see
/// [TomBlobStore]'s "Why the five methods are final".
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
  delete('storage.blob.delete_failed', 'The stored file could not be deleted.');

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
///
/// ## Why the five methods are final
///
/// A backend implements [doPut], [doGet], [doDescribe], [doDelete] and
/// optionally [doExists]; the five public methods are this class's own and wrap
/// them. That indirection buys two guarantees no backend can forget:
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
  Stream<List<int>> get(String key) async* {
    try {
      // `await for`, not `yield*`: a `yield*` forwards the inner stream's
      // *errors* straight to the output stream, past the enclosing try, so the
      // translation below would never see the failure it exists to translate.
      await for (final chunk in doGet(validateKey(key))) {
        yield chunk;
      }
    } on TomStorageException {
      rethrow;
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

  /// Describes a validated [key]. Implemented by backends; called by [describe].
  Future<TomStoredBlob?> doDescribe(String key);

  /// Deletes a validated [key]. Implemented by backends; called by [delete].
  Future<bool> doDelete(String key);

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
  Future<Uint8List> getBytes(String key) async {
    // Non-copying, which is safe only because [get] yields chunks the caller
    // owns: a lone chunk comes back from `takeBytes` untouched, so this method
    // is exactly as aliased as what the backend yielded.
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
  /// A [TomStorageException] passes through untouched, which is the clause that
  /// makes this safe to wrap a whole method in: `not_found`, `invalid_key` and
  /// `missing_chunk` are the module's own answers, and a caller branching on
  /// them (`TomBlobExportStore` on `not_found`, the file endpoint on its 404)
  /// must keep hearing them rather than the operation that stopped.
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
    } on TomStorageException {
      rethrow;
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

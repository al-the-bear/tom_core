/// Where a rendered export is kept when it is stored rather than streamed.
///
/// `codespecs_mapping.md` §5.28 lets a report name one of three delivery
/// channels. Two of them — `apiResponse` and `email` — consume the renderer's
/// byte stream and keep nothing; the third, `fileExport`, has to put the
/// document *somewhere* and hand back a reference to it. This library is that
/// somewhere.
///
/// ## Why a four-method interface and not the persistence layer's blob API
///
/// This is deliberately *not* a general file store. It is the narrowest
/// interface an export needs — put a stream under a key, read it back, ask
/// whether it is there, delete it — with no directories to list, no metadata to
/// update, no partial reads. It was written before the framework's general
/// blob storage (`file_storage/`) existed, on the reasoning that guessing the
/// shape of an API someone else is designing produces two APIs that nearly
/// match.
///
/// That storage now exists, and the adaptation turned out to be exactly what
/// was predicted: [TomBlobExportStore] — one class, four delegating methods —
/// puts every blob backend (filesystem, database, S3, or an application's own)
/// behind this interface, and nothing that renders or delivers an export
/// changed. The two backends below remain because an export module that can
/// run with no storage configured at all is worth the hundred lines.
///
/// ## Why streams on both sides
///
/// The same reason the renderers produce one: an export large enough to be
/// worth storing is large enough that holding it and its copy at once is the
/// failure. [TomExportStore.store] takes the renderer's stream directly, so a
/// result flows from the database to the disk without ever being whole in
/// memory.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../file_storage/blob_store.dart';
import 'tabular_result.dart';

/// A stored export: what was written, where, and how big it turned out.
///
/// Returned by [TomExportStore.store] rather than assembled by the caller —
/// [byteCount] is only known once the stream has drained, and it is the field a
/// caller most often needs next (a `Content-Length`, a quota check, a log line).
class TomStoredExport {
  /// Creates a stored-export descriptor.
  ///
  /// [storedAt] is normalised to UTC for the same reason [TomStoredBlob] does
  /// it, and this type needed it more: the directory and memory backends stamp
  /// `DateTime.now()` while the blob-backed one forwards the blob's own stamp,
  /// so without normalising here the three backends of one interface would have
  /// disagreed with each other about the zone.
  TomStoredExport({
    required this.key,
    required this.mediaType,
    required this.byteCount,
    required DateTime storedAt,
    this.location,
  }) : storedAt = storedAt.toUtc();

  /// The key the export was stored under, as given to [TomExportStore.store].
  final String key;

  /// The IANA media type the bytes should be served as.
  final String mediaType;

  /// The number of bytes written.
  final int byteCount;

  /// When the write completed, always in UTC.
  final DateTime storedAt;

  /// A backend-specific address — a `file:` URI, an object-store URL.
  ///
  /// Present for the backends that have one and useful for a human chasing an
  /// export down; never the thing to read it back with. [TomExportStore.open]
  /// takes the [key], because only the store knows how its keys map to
  /// addresses.
  final Uri? location;

  @override
  String toString() => 'TomStoredExport($key, $byteCount bytes)';
}

/// The four things a store does, and how each one reports a failure.
///
/// The keys are named here rather than spelled at each throw site so that the
/// same failure of the same operation carries the same key whichever backend
/// is configured — which is the entire promise [TomExportStore] makes by being
/// an interface at all.
enum TomExportStoreOperation {
  /// Writing an export: [TomExportStore.store].
  write('export.store.write_failed', 'The export could not be written.'),

  /// Reading one back: [TomExportStore.open].
  read('export.store.read_failed', 'The stored export could not be read.'),

  /// Asking whether one is there: [TomExportStore.exists].
  probe(
    'export.store.probe_failed',
    'Storage could not be asked whether the export exists.',
  ),

  /// Removing one: [TomExportStore.delete].
  delete(
    'export.store.delete_failed',
    'The stored export could not be deleted.',
  );

  const TomExportStoreOperation(this.errorKey, this.message);

  /// The `export.store.*` key a failure of this operation carries.
  final String errorKey;

  /// The default user-facing message for that key.
  final String message;
}

/// Stores and retrieves rendered exports by key.
///
/// ## Why the four methods are final
///
/// A backend implements [doStore], [doOpen], [doExists] and [doDelete]; the
/// four public methods are this class's own and wrap them. That indirection
/// buys two guarantees no backend can forget:
///
/// - **Every key is validated**, so a backend written later — or by an
///   application — cannot be handed a directory traversal.
/// - **Every failure arrives as a [TomExportException]** carrying the key
///   [TomExportStoreOperation] names for the operation that failed. A backend
///   touches a filesystem, an S3 client or a database driver, each with an
///   exception vocabulary of its own; without this, which exception a caller
///   had to catch depended on which backend was configured.
///
/// Both properties were previously left to each backend to honour, and each
/// backend honoured a different subset of them.
abstract class TomExportStore {
  /// Creates a store.
  const TomExportStore();

  /// Writes [bytes] under [key], replacing anything already there.
  ///
  /// A failed write leaves **nothing** readable under [key] — a truncated
  /// export is indistinguishable from a complete one to whoever downloads it
  /// next, which is the one outcome worse than a failure that is reported.
  ///
  /// Throws [TomExportException] (`export.store.invalid_key`) for a key that is
  /// not relative, or (`export.store.write_failed`) when the write fails.
  Future<TomStoredExport> store({
    required String key,
    required Stream<List<int>> bytes,
    required String mediaType,
  }) => _translating(
    TomExportStoreOperation.write,
    key,
    () => doStore(key: validateKey(key), bytes: bytes, mediaType: mediaType),
  );

  /// Reads the export stored under [key].
  ///
  /// Throws [TomExportException] (`export.store.not_found`) when the key holds
  /// nothing: a caller reading an export it has a reference to and finding it
  /// gone has hit a real fault — an expiry it did not expect, a store it is not
  /// pointed at — and an empty stream would disguise that as an empty file. A
  /// read that fails for any other reason is `export.store.read_failed`.
  ///
  /// A transfer that breaks partway still delivers the chunks that arrived, and
  /// then fails — the same contract [TomBlobStore.get] states, for the same
  /// reason and by the same means. Stated here too because the two are only
  /// *coincidentally* the same code: a reader of this method has no cause to go
  /// looking at the other module for what this one promises.
  Stream<List<int>> open(String key) async* {
    try {
      // `await for`, not `yield*`: a `yield*` forwards the inner stream's
      // *errors* straight to the output stream, past the enclosing try — so the
      // translation below would never run. Re-yielding each chunk keeps the
      // read streaming and puts the errors back inside the handler.
      await for (final chunk in doOpen(validateKey(key))) {
        yield chunk;
      }
    } on TomExportException {
      rethrow;
    } on Object catch (error, stack) {
      throw _asExportException(TomExportStoreOperation.read, key, error, stack);
    }
  }

  /// Whether [key] currently holds an export.
  ///
  /// Throws [TomExportException] (`export.store.probe_failed`) when storage
  /// could not answer — which is not the same as answering `false`.
  Future<bool> exists(String key) => _translating(
    TomExportStoreOperation.probe,
    key,
    () => doExists(validateKey(key)),
  );

  /// Deletes [key], returning whether anything was there to delete.
  ///
  /// Throws [TomExportException] (`export.store.delete_failed`) when the
  /// deletion itself fails; a key that held nothing is `false`, not an error.
  Future<bool> delete(String key) => _translating(
    TomExportStoreOperation.delete,
    key,
    () => doDelete(validateKey(key)),
  );

  /// Writes [bytes] under [key]. Implemented by backends; called by [store].
  ///
  /// [key] has already been validated. A failure may be thrown in whatever
  /// vocabulary the backend has — [store] translates it — but a backend that
  /// has a *better* key than `export.store.write_failed` for the failure should
  /// throw a [TomExportException] carrying it, which passes through untouched.
  ///
  /// A chunk from [bytes] is **borrowed for the duration of the `await`**:
  /// consume or copy it before asking for the next, and do not retain it. A
  /// renderer refilling one scratch buffer per chunk is ordinary, and a backend
  /// that kept the list would store that buffer's last state once per chunk.
  Future<TomStoredExport> doStore({
    required String key,
    required Stream<List<int>> bytes,
    required String mediaType,
  });

  /// Reads [key]. Implemented by backends; called by [open].
  ///
  /// Throws [TomExportException] (`export.store.not_found`) when the key holds
  /// nothing — the one error a backend must raise itself, because only it knows
  /// the difference between absent and unreadable.
  ///
  /// Each chunk **belongs to the caller**: writable, and aliased with nothing
  /// the backend keeps. A backend reading from a file or a blob has this
  /// already; one holding its exports in memory must copy. Both halves are
  /// load-bearing — yielding an internal buffer lets a consumer decoding in
  /// place edit the stored export, while yielding an unmodifiable view would
  /// make that consumer throw on the backend the tests use and work on every
  /// backend they deploy to.
  Stream<List<int>> doOpen(String key);

  /// Whether [key] holds an export. Implemented by backends; called by
  /// [exists].
  Future<bool> doExists(String key);

  /// Deletes [key]. Implemented by backends; called by [delete].
  Future<bool> doDelete(String key);

  /// Runs [operation], reporting any failure in this module's vocabulary.
  static Future<T> _translating<T>(
    TomExportStoreOperation kind,
    String key,
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } on TomExportException {
      // The module's own errors pass through: a caller catching
      // `export.store.invalid_key` should keep catching it, rather than meeting
      // the name of whichever operation happened to refuse the key.
      rethrow;
    } on Object catch (error, stack) {
      throw _asExportException(kind, key, error, stack);
    }
  }

  /// The exception [kind]'s failure on [key] is reported as.
  static TomExportException _asExportException(
    TomExportStoreOperation kind,
    String key,
    Object error,
    StackTrace stack,
  ) => TomExportException(
    kind.errorKey,
    kind.message,
    parameters: {'key': key},
    rootException: error,
    stack: stack,
  );

  /// Validates a storage key and returns it.
  ///
  /// Keys are relative, slash-separated, and made of unreserved characters.
  /// The rule exists because the obvious backend maps keys onto paths, and a
  /// key of `../../etc/passwd` would then be a directory traversal handed to
  /// whatever built the key from a report name. Validating centrally means
  /// every backend gets the check, including ones written later.
  ///
  /// The *rule* is [TomBlobStore.isValidKey] — one definition, so an export key
  /// and a file-reference key cannot drift apart and a key that passes here is
  /// storable by any blob backend. Only the error is this module's own, because
  /// a caller catching `export.store.invalid_key` should keep catching it.
  static String validateKey(String key) {
    if (!TomBlobStore.isValidKey(key)) {
      throw TomExportException(
        'export.store.invalid_key',
        'The export storage key is not a valid relative key.',
        parameters: {'key': key},
      );
    }
    return key;
  }
}

/// An export store over a directory tree on the local filesystem.
///
/// The default backend, and the one that needs no infrastructure: a mounted
/// volume, a container's writable layer, a developer's `ztmp`. Keys become
/// paths beneath [root], so `2026/07/sales.xlsx` is a file two directories
/// down — which makes the stored exports browsable with `ls`, and date
/// partitioning a matter of how the caller spells the key.
class TomDirectoryExportStore extends TomExportStore {
  /// Creates a store rooted at [root], **without touching the filesystem**.
  ///
  /// [root] is created by the first [store] call, together with whatever
  /// directories that call's key names — one `create(recursive: true)` covers
  /// both, so a store is configured long before it is a directory. The three
  /// read paths do *not* create it: [open] on a missing root is
  /// `export.store.not_found`, and [exists] and [delete] answer `false`.
  /// Asking a store whether it holds something is a question, and a question
  /// should not leave a directory behind.
  ///
  /// Deferring the creation is what makes a store safe to configure at startup:
  /// a constructor cannot await, so creating the root here would mean a
  /// blocking `createSync` on a path that may be a slow mount, throwing out of
  /// a field initialiser on a store the application may never write to. It also
  /// means the root is created *again* if it goes away — a remounted volume, a
  /// reaped tmpfs — where a store that made it once would report itself
  /// configured and fail every write after.
  TomDirectoryExportStore(this.root);

  /// The directory every key resolves beneath.
  ///
  /// Created on demand — see the constructor for when.
  final Directory root;

  /// The suffix a write stages under before renaming into place.
  ///
  /// Hung off [TomBlobStore.auxiliaryMarker], which [TomExportStore.validateKey]
  /// cannot admit, so the staging file is unreachable from the key space. With
  /// the obvious `<key>.part` it was not: `a.csv.part` is a key a caller may
  /// legitimately choose, and storing `a.csv` overwrote that caller's export
  /// with a half-written stream and then renamed it away.
  static const String partialSuffix = '${TomBlobStore.auxiliaryMarker}part';

  @override
  Future<TomStoredExport> doStore({
    required String key,
    required Stream<List<int>> bytes,
    required String mediaType,
  }) async {
    final file = _fileFor(key);
    await file.parent.create(recursive: true);

    // Written under a sibling name and renamed on success. A rename within one
    // filesystem is atomic, so a reader either sees the previous export or the
    // complete new one — never the half of it that had been flushed when the
    // query failed on its last row.
    final partial = File('${file.path}$partialSuffix');
    var written = 0;
    final sink = partial.openWrite();
    try {
      await sink.addStream(
        bytes.map((chunk) {
          written += chunk.length;
          return chunk;
        }),
      );
      await sink.flush();
      await sink.close();
      // Inside the try, because the rename is the step that publishes the
      // export and has failure modes of its own — a cross-device destination,
      // a name already taken by a directory. Outside it, those left the
      // partial behind and reached the caller untranslated.
      await partial.rename(file.path);
    } on Object {
      await sink.close().catchError((Object _) {});
      await partial.delete().catchError((Object _) => partial);
      rethrow;
    }

    return TomStoredExport(
      key: key,
      mediaType: mediaType,
      byteCount: written,
      storedAt: DateTime.now(),
      location: file.absolute.uri,
    );
  }

  @override
  Stream<List<int>> doOpen(String key) async* {
    final file = _fileFor(key);
    if (!file.existsSync()) {
      throw TomExportException(
        'export.store.not_found',
        'No stored export exists for the requested key.',
        parameters: {'key': key},
      );
    }
    yield* file.openRead();
  }

  @override
  Future<bool> doExists(String key) => _fileFor(key).exists();

  @override
  Future<bool> doDelete(String key) async {
    final file = _fileFor(key);
    if (!file.existsSync()) return false;
    await file.delete();
    return true;
  }

  /// The file [key] names, beneath [root].
  ///
  /// [key] arrives validated — [TomExportStore] checks it before dispatching to
  /// any backend — so this is a join, not a gate.
  File _fileFor(String key) => File(p.join(root.path, key));

  @override
  String toString() => 'TomDirectoryExportStore(${root.path})';
}

/// An export store that keeps its contents in memory.
///
/// For tests, and for the development server that should not leave files
/// behind. It buffers whole exports by definition, so it is the one place in
/// this module where that is acceptable — and the reason it is not the default.
///
/// Holding the bytes rather than reading them off a disk makes it the only
/// backend that could hand a caller a reference into its own state, so it is
/// the only one that has to copy on purpose: a chunk it yields is the reader's
/// own, and a chunk streamed into it is copied before the next is asked for.
/// Both are what [TomExportStore.doOpen] and [TomExportStore.doStore] require
/// of any backend — stated here because here they cost something.
class TomMemoryExportStore extends TomExportStore {
  /// Creates an empty in-memory store.
  TomMemoryExportStore();

  final Map<String, List<int>> _content = {};
  final Map<String, TomStoredExport> _descriptors = {};

  /// The keys currently held, in insertion order.
  Iterable<String> get keys => _content.keys;

  /// The descriptor recorded for [key], or `null` when it holds nothing.
  ///
  /// Throws [TomExportException] (`export.store.invalid_key`) for a key the
  /// store would not have accepted, rather than answering `null`: `null` means
  /// *this valid key holds nothing*, and using it for *this is not a key* would
  /// send the reader looking for a write that never happened.
  TomStoredExport? descriptorFor(String key) =>
      _descriptors[TomExportStore.validateKey(key)];

  /// The stored bytes for [key] as text, for tests that assert on content.
  ///
  /// Validates like the four store methods do. This backend is what tests and
  /// development servers run on, so a key it accepts and a production backend
  /// rejects is a failure that appears only on deployment.
  String textOf(String key) {
    final bytes = _content[TomExportStore.validateKey(key)];
    if (bytes == null) {
      throw TomExportException(
        'export.store.not_found',
        'No stored export exists for the requested key.',
        parameters: {'key': key},
      );
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Future<TomStoredExport> doStore({
    required String key,
    required Stream<List<int>> bytes,
    required String mediaType,
  }) async {
    final buffer = <int>[];
    // Drained fully before anything is recorded, so a source stream that fails
    // halfway leaves the key holding what it held before — the same "a failed
    // write leaves nothing readable" the filesystem backend gets from its
    // `.part` rename, and the reason both report `export.store.write_failed`.
    //
    // `addAll` copies each chunk as it arrives, which is what [doStore] asks
    // of a backend: the chunk is the renderer's, lent for this iteration only.
    await for (final chunk in bytes) {
      buffer.addAll(chunk);
    }
    final descriptor = TomStoredExport(
      key: key,
      mediaType: mediaType,
      byteCount: buffer.length,
      storedAt: DateTime.now(),
    );
    _content[key] = buffer;
    _descriptors[key] = descriptor;
    return descriptor;
  }

  @override
  Stream<List<int>> doOpen(String key) async* {
    final bytes = _content[key];
    if (bytes == null) {
      throw TomExportException(
        'export.store.not_found',
        'No stored export exists for the requested key.',
        parameters: {'key': key},
      );
    }
    // Copied, so a consumer decoding in place edits its own chunk and not the
    // stored export. See [doOpen] on the base class for why a copy rather than
    // an unmodifiable view: the backend the tests run on must not refuse what
    // the backends they deploy to allow.
    yield Uint8List.fromList(bytes);
  }

  @override
  Future<bool> doExists(String key) async => _content.containsKey(key);

  @override
  Future<bool> doDelete(String key) async {
    _descriptors.remove(key);
    return _content.remove(key) != null;
  }

  @override
  String toString() => 'TomMemoryExportStore(${_content.length} exports)';
}

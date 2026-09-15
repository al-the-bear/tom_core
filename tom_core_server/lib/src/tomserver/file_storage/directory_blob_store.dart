/// The filesystem backend: a key is a path beneath a root directory.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'blob_store.dart';

/// A blob store over a directory tree on the local filesystem.
///
/// The backend that needs no infrastructure: a mounted volume, a container's
/// writable layer, a developer's `ztmp`. Keys become paths beneath [root], so
/// `2026/07/invoice.pdf` is a file two directories down — which makes the
/// stored blobs browsable with `ls`, and date partitioning a matter of how the
/// caller spells the key.
///
/// ## Where the metadata goes
///
/// A filesystem stores bytes and nothing else, so the media type and original
/// file name are written to a sidecar `<key>~meta` holding one JSON object.
/// The alternative — extended attributes — is not portable across the
/// filesystems this runs on (and is silently dropped by most copy tools), and
/// encoding the media type into the key would make the key un-chooseable by the
/// caller. A blob whose sidecar is missing still reads back: [describe] falls
/// back to the file's size and mtime with a generic media type, so a directory
/// populated by `scp` is usable.
///
/// ## The bookkeeping is out of the caller's reach
///
/// Both auxiliary files — the [metadataSuffix] sidecar and the [partialSuffix]
/// a write is staged in — hang off [TomBlobStore.auxiliaryMarker], a character
/// the shared key grammar cannot produce. That is the whole of the guarantee,
/// and it is why the marker is not a matter of taste: with a spellable suffix
/// such as `.meta`, one caller's perfectly valid key named another caller's
/// bookkeeping, and the two of them destroyed each other's data without either
/// doing anything wrong. `put('a')` followed by `put('a.meta')` cost the first
/// blob its media type; `delete('a')` then deleted the second blob outright and
/// reported success.
///
/// Note that the *keys* are not restricted: `a.meta` remains a perfectly good
/// key and stores a perfectly ordinary blob. Refusing it here would have made
/// the accepted key space depend on which backend is configured — the same key
/// working on S3 and failing on disk — and the stores would stop being drop-in
/// replacements for one another.
///
/// ## What a failed write leaves behind
///
/// [put] stages into a sibling [partialSuffix] file and renames it into place,
/// so the rename is the commit — and therefore the line that decides what a
/// later failure has to clean up. Before it, the leftover is the partial and
/// the key still holds whatever it held; after it, the partial is gone and the
/// leftover is the new blob. The rollback deletes whichever of the two exists,
/// which gives the honest guarantee:
///
/// - a failure **before** the rename leaves the previous content intact;
/// - a failure **after** it leaves the key empty.
///
/// The second half is the best a rename-based commit can offer, because the
/// rename is itself the destructive step — the previous blob is gone the
/// instant the new one is in place, and there is nothing left to restore. Only
/// the sidecar write happens after it, and it is not tolerated silently: see
/// [put].
///
/// Every failure here is a [TomStorageException] carrying the original
/// `FileSystemException` as its `rootException`, per
/// [TomBlobStoreOperation].
class TomDirectoryBlobStore extends TomBlobStore {
  /// Creates a store rooted at [root]; the directory is created on first write.
  TomDirectoryBlobStore(this.root);

  /// Creates a store rooted at [path].
  TomDirectoryBlobStore.at(String path) : root = Directory(path);

  /// The directory every key resolves beneath.
  final Directory root;

  /// The sidecar suffix, holding one JSON object per blob.
  ///
  /// Hung off [TomBlobStore.auxiliaryMarker], which no valid key can contain,
  /// so the sidecar is unreachable from the key space rather than merely
  /// unlikely to be hit. Adjacent to its blob rather than in a parallel
  /// `root/.meta/` tree: that keeps the directory browsable with `ls`, and it
  /// would not have helped anyway — `.meta` is a valid key *segment*, so the
  /// key `.meta/a` would collide in turn.
  static const String metadataSuffix = '${TomBlobStore.auxiliaryMarker}meta';

  /// The suffix a write stages under before renaming into place.
  static const String partialSuffix = '${TomBlobStore.auxiliaryMarker}part';

  @override
  Future<TomStoredBlob> doPut({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  }) async {
    final file = _fileFor(key);

    // Written under a sibling name and renamed on success. A rename within one
    // filesystem is atomic, so a reader either sees the previous blob or the
    // complete new one — never the half of it that had been flushed when the
    // upload connection dropped.
    final partial = File('${file.path}$partialSuffix');
    var written = 0;
    // Hashed on the same pass that writes: the chunks are already flowing
    // through this `map`, so the digest costs no second read of the file.
    final digest = TomBlobDigest();
    // Whether the rename has happened, which is what decides *what the residue
    // is* if a later step fails. Before it, the leftover is the partial and the
    // previous blob is untouched; after it, there is no partial and the
    // leftover is the new blob itself.
    var committed = false;
    IOSink? sink;
    try {
      await file.parent.create(recursive: true);
      sink = partial.openWrite();
      await sink.addStream(
        bytes.map((chunk) {
          written += chunk.length;
          digest.add(chunk);
          return chunk;
        }),
      );
      await sink.flush();
      // Inside the guard, all three of them. `close` is where the buffer is
      // actually flushed, so it is where a full disk surfaces; `rename` fails
      // on a cross-device root, a read-only mount or a target occupied by a
      // directory; the sidecar write fails for the same reasons the blob write
      // does. Outside, each of them escaped as a raw `FileSystemException` and
      // left behind exactly the residue this rollback exists to prevent.
      await sink.close();
      sink = null;
      await partial.rename(file.path);
      committed = true;

      final descriptor = TomStoredBlob(
        key: key,
        mediaType: mediaType,
        byteCount: written,
        storedAt: DateTime.now(),
        digest: digest.close(),
        fileName: fileName,
        location: file.absolute.uri,
      );
      // After the rename: the blob is the thing that must be complete, and a
      // sidecar written first would describe a file that does not exist yet.
      //
      // A failure here is *not* tolerated even though a blob without a sidecar
      // reads back fine (see the class comment). `put` is about to return a
      // descriptor naming a media type and a file name that a later `describe`
      // would contradict — and it will not return at all, so the caller is
      // entitled to assume nothing was stored.
      await _writeMetadata(file, descriptor);
      return descriptor;
    } on Object catch (error, stack) {
      await sink?.close().catchError((Object _) {});
      final residue = committed ? file : partial;
      await residue.delete().catchError((Object _) => residue);
      // Rethrown rather than wrapped: [TomBlobStore.put] names the operation.
      // This block exists for the rollback, and having done it must not swallow
      // what caused it.
      Error.throwWithStackTrace(error, stack);
    }
  }

  @override
  Stream<List<int>> doGet(String key) async* {
    final file = _fileFor(key);
    if (!file.existsSync()) throw TomBlobStore.notFound(key);
    // `yield*` is safe for the same reason it is in the S3 backend: the errors
    // `openRead` raises after the first bytes — a disk that goes away, a file
    // truncated under the reader — are translated by [TomBlobStore.get], which
    // consumes this with `await for` inside its `try` rather than forwarding it.
    yield* file.openRead();
  }

  @override
  Stream<List<int>> doGetRange(String key, TomBlobRange range) async* {
    final file = _fileFor(key);
    if (!file.existsSync()) throw TomBlobStore.notFound(key);
    // A real seek: `openRead` takes the offsets straight to the file
    // descriptor, so a request for the last megabyte of a gigabyte reads a
    // megabyte. The inherited default would read the gigabyte and throw away
    // all but the tail.
    yield* file.openRead(range.start, range.endExclusive);
  }

  @override
  Future<TomStoredBlob?> doDescribe(String key) async {
    final file = _fileFor(key);
    if (!file.existsSync()) return null;
    final stat = await file.stat();
    final meta = await _readMetadata(file);
    return TomStoredBlob(
      key: key,
      mediaType:
          meta?['mediaType'] as String? ?? TomStoredBlob.defaultMediaType,
      byteCount: stat.size,
      storedAt: stat.modified,
      // Read back rather than recomputed. `describe` is the cheap question —
      // one `stat` and one small file — and hashing here would turn it into a
      // full read of a blob the caller may not want. A file this store did not
      // write has no sidecar and so no digest, which is what
      // `TomStoredBlob.unknownDigest` is for.
      digest: meta?['digest'] as String? ?? TomStoredBlob.unknownDigest,
      fileName: meta?['fileName'] as String?,
      location: file.absolute.uri,
    );
  }

  /// Whether [key] is *visible* — see the note below on what that excludes.
  ///
  /// [TomBlobStore.exists] translates whatever this throws, but on this backend
  /// it has nothing to translate: `File.exists` cannot fail. `dart:io` answers
  /// it from a `stat` and maps every failure of that `stat` — permission denied
  /// on a parent directory, a symlink loop, an over-long name, a dead NFS mount
  /// — to plain `false`.
  ///
  /// The consequence is the caller's to know: on this backend a blob the
  /// process is not *allowed* to see is reported absent rather than as a probe
  /// failure, and `exists` therefore means "visible to this process", not "not
  /// present in storage". It cannot be fixed from here — `File.stat` swallows
  /// the same errors the same way, and `dart:io` exposes no errno to tell
  /// `ENOENT` from `EACCES`. [doDescribe] does reach real I/O (it reads the
  /// sidecar) and so a probe through [TomBlobStore.describe] does report
  /// [TomBlobStoreOperation.probe] failures; a caller that must tell the two
  /// apart should ask it instead.
  @override
  Future<bool> doExists(String key) => _fileFor(key).exists();

  @override
  Future<bool> doDelete(String key) async {
    final file = _fileFor(key);
    if (!file.existsSync()) return false;
    await file.delete();
    final meta = _metadataFileFor(file);
    if (meta.existsSync()) await meta.delete();
    return true;
  }

  @override
  Future<TomStoredBlob> doCopy(String fromKey, String toKey) async {
    final source = _fileFor(fromKey);
    if (!source.existsSync()) throw TomBlobStore.notFound(fromKey);
    final target = _fileFor(toKey);
    await target.parent.create(recursive: true);

    // Staged and renamed, the same protocol `doPut` uses and for the same
    // reason: a copy interrupted half way must not leave a truncated blob under
    // a key that already held a complete one.
    final partial = File('${target.path}$partialSuffix');
    try {
      await source.copy(partial.path);
      final meta = _metadataFileFor(source);
      // The sidecar before the rename, so the blob is never visible without the
      // media type that says how to serve it. An absent sidecar is copied as an
      // absent sidecar: `describe` already falls back for one.
      if (meta.existsSync()) {
        await meta.copy(_metadataFileFor(target).path);
      } else if (_metadataFileFor(target).existsSync()) {
        // The destination's own sidecar would otherwise survive its bytes and
        // describe the wrong blob.
        await _metadataFileFor(target).delete();
      }
      await partial.rename(target.path);
    } on Object {
      if (partial.existsSync()) await partial.delete();
      rethrow;
    }
    final described = await doDescribe(toKey);
    if (described == null) throw TomBlobStore.notFound(toKey);
    return described;
  }

  @override
  Future<TomStoredBlob> doMove(String fromKey, String toKey) async {
    final source = _fileFor(fromKey);
    if (!source.existsSync()) throw TomBlobStore.notFound(fromKey);
    final target = _fileFor(toKey);
    await target.parent.create(recursive: true);

    // A rename, not a copy and a delete: within one filesystem it moves no
    // bytes and is atomic, which makes a re-partitioning of a terabyte of blobs
    // a metadata operation. The sidecar goes first, so the window in which the
    // two disagree holds a blob whose metadata has already arrived rather than
    // one whose metadata is still elsewhere.
    final meta = _metadataFileFor(source);
    final targetMeta = _metadataFileFor(target);
    if (meta.existsSync()) {
      await meta.rename(targetMeta.path);
    } else if (targetMeta.existsSync()) {
      await targetMeta.delete();
    }
    await source.rename(target.path);

    final described = await doDescribe(toKey);
    if (described == null) throw TomBlobStore.notFound(toKey);
    return described;
  }

  File _metadataFileFor(File file) => File('${file.path}$metadataSuffix');

  Future<void> _writeMetadata(File file, TomStoredBlob descriptor) async {
    await _metadataFileFor(file).writeAsString(
      jsonEncode({
        'mediaType': descriptor.mediaType,
        if (descriptor.hasDigest) 'digest': descriptor.digest,
        if (descriptor.fileName != null) 'fileName': descriptor.fileName,
      }),
      flush: true,
    );
  }

  Future<Map<String, Object?>?> _readMetadata(File file) async {
    final meta = _metadataFileFor(file);
    if (!meta.existsSync()) return null;
    try {
      final decoded = jsonDecode(await meta.readAsString());
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      // A corrupt sidecar is not a reason to refuse the blob: the bytes are the
      // payload and the metadata is a convenience. `describe` falls back.
      return null;
    }
  }

  /// The file [key] names, having checked that it stays under [root].
  File _fileFor(String key) =>
      File(p.join(root.path, TomBlobStore.validateKey(key)));

  @override
  String toString() => 'TomDirectoryBlobStore(${root.path})';
}

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
/// file name are written to a sidecar `<key>.meta` holding one JSON object.
/// The alternative — extended attributes — is not portable across the
/// filesystems this runs on (and is silently dropped by most copy tools), and
/// encoding the media type into the key would make the key un-chooseable by the
/// caller. A blob whose sidecar is missing still reads back: [describe] falls
/// back to the file's size and mtime with a generic media type, so a directory
/// populated by `scp` is usable.
class TomDirectoryBlobStore extends TomBlobStore {
  /// Creates a store rooted at [root]; the directory is created on first write.
  TomDirectoryBlobStore(this.root);

  /// Creates a store rooted at [path].
  TomDirectoryBlobStore.at(String path) : root = Directory(path);

  /// The directory every key resolves beneath.
  final Directory root;

  /// The sidecar suffix. Chosen to be invalid in a key ([TomBlobStore
  /// .isValidKey] allows it, but a caller's key plus this suffix can only
  /// collide with a caller who deliberately spells one), so a metadata file can
  /// never be mistaken for a blob.
  static const String metadataSuffix = '.meta';

  @override
  Future<TomStoredBlob> put({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  }) async {
    final file = _fileFor(key);
    await file.parent.create(recursive: true);

    // Written under a sibling name and renamed on success. A rename within one
    // filesystem is atomic, so a reader either sees the previous blob or the
    // complete new one — never the half of it that had been flushed when the
    // upload connection dropped.
    final partial = File('${file.path}.part');
    var written = 0;
    final sink = partial.openWrite();
    try {
      await sink.addStream(bytes.map((chunk) {
        written += chunk.length;
        return chunk;
      }));
      await sink.flush();
    } on Object catch (error, stack) {
      await sink.close().catchError((Object _) {});
      await partial.delete().catchError((Object _) => partial);
      throw TomStorageException(
        'storage.blob.write_failed',
        'The file could not be written to storage.',
        parameters: {'key': key},
        rootException: error,
        stack: stack,
      );
    }
    await sink.close();
    await partial.rename(file.path);

    final descriptor = TomStoredBlob(
      key: key,
      mediaType: mediaType,
      byteCount: written,
      storedAt: DateTime.now(),
      fileName: fileName,
      location: file.absolute.uri,
    );
    // After the rename: the blob is the thing that must be complete, and a
    // sidecar written first would describe a file that does not exist yet.
    await _writeMetadata(file, descriptor);
    return descriptor;
  }

  @override
  Stream<List<int>> get(String key) async* {
    final file = _fileFor(key);
    if (!file.existsSync()) throw TomBlobStore.notFound(key);
    yield* file.openRead();
  }

  @override
  Future<TomStoredBlob?> describe(String key) async {
    final file = _fileFor(key);
    if (!file.existsSync()) return null;
    final stat = await file.stat();
    final meta = await _readMetadata(file);
    return TomStoredBlob(
      key: key,
      mediaType: meta?['mediaType'] as String? ?? TomStoredBlob.defaultMediaType,
      byteCount: stat.size,
      storedAt: stat.modified,
      fileName: meta?['fileName'] as String?,
      location: file.absolute.uri,
    );
  }

  @override
  Future<bool> exists(String key) => _fileFor(key).exists();

  @override
  Future<bool> delete(String key) async {
    final file = _fileFor(key);
    if (!file.existsSync()) return false;
    await file.delete();
    final meta = _metadataFileFor(file);
    if (meta.existsSync()) await meta.delete();
    return true;
  }

  File _metadataFileFor(File file) => File('${file.path}$metadataSuffix');

  Future<void> _writeMetadata(File file, TomStoredBlob descriptor) async {
    await _metadataFileFor(file).writeAsString(
      jsonEncode({
        'mediaType': descriptor.mediaType,
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

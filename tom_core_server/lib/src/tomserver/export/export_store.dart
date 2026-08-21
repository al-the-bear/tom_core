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
  const TomStoredExport({
    required this.key,
    required this.mediaType,
    required this.byteCount,
    required this.storedAt,
    this.location,
  });

  /// The key the export was stored under, as given to [TomExportStore.store].
  final String key;

  /// The IANA media type the bytes should be served as.
  final String mediaType;

  /// The number of bytes written.
  final int byteCount;

  /// When the write completed.
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

/// Stores and retrieves rendered exports by key.
abstract class TomExportStore {
  /// Creates a store.
  const TomExportStore();

  /// Writes [bytes] under [key], replacing anything already there.
  ///
  /// A failed write must leave **nothing** readable under [key] — a truncated
  /// export is indistinguishable from a complete one to whoever downloads it
  /// next, which is the one outcome worse than a failure that is reported.
  Future<TomStoredExport> store({
    required String key,
    required Stream<List<int>> bytes,
    required String mediaType,
  });

  /// Reads the export stored under [key].
  ///
  /// Throws [TomExportException] when the key holds nothing: a caller reading
  /// an export it has a reference to and finding it gone has hit a real fault
  /// — an expiry it did not expect, a store it is not pointed at — and an empty
  /// stream would disguise that as an empty file.
  Stream<List<int>> open(String key);

  /// Whether [key] currently holds an export.
  Future<bool> exists(String key);

  /// Deletes [key], returning whether anything was there to delete.
  Future<bool> delete(String key);

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
  /// Creates a store rooted at [root], which is created if it does not exist.
  TomDirectoryExportStore(this.root);

  /// The directory every key resolves beneath.
  final Directory root;

  @override
  Future<TomStoredExport> store({
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
    final partial = File('${file.path}.part');
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
    } on Object catch (error, stack) {
      await sink.close().catchError((Object _) {});
      await partial.delete().catchError((Object _) => partial);
      throw TomExportException(
        'export.store.write_failed',
        'The export could not be written to storage.',
        parameters: {'key': key},
        rootException: error,
        stack: stack,
      );
    }
    await sink.close();
    await partial.rename(file.path);

    return TomStoredExport(
      key: key,
      mediaType: mediaType,
      byteCount: written,
      storedAt: DateTime.now(),
      location: file.absolute.uri,
    );
  }

  @override
  Stream<List<int>> open(String key) async* {
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
  Future<bool> exists(String key) => _fileFor(key).exists();

  @override
  Future<bool> delete(String key) async {
    final file = _fileFor(key);
    if (!file.existsSync()) return false;
    await file.delete();
    return true;
  }

  /// The file [key] names, having checked that it stays under [root].
  File _fileFor(String key) =>
      File(p.join(root.path, TomExportStore.validateKey(key)));

  @override
  String toString() => 'TomDirectoryExportStore(${root.path})';
}

/// An export store that keeps its contents in memory.
///
/// For tests, and for the development server that should not leave files
/// behind. It buffers whole exports by definition, so it is the one place in
/// this module where that is acceptable — and the reason it is not the default.
class TomMemoryExportStore extends TomExportStore {
  /// Creates an empty in-memory store.
  TomMemoryExportStore();

  final Map<String, List<int>> _content = {};
  final Map<String, TomStoredExport> _descriptors = {};

  /// The keys currently held, in insertion order.
  Iterable<String> get keys => _content.keys;

  /// The descriptor recorded for [key], or `null` when it holds nothing.
  TomStoredExport? descriptorFor(String key) => _descriptors[key];

  /// The stored bytes for [key] as text, for tests that assert on content.
  String textOf(String key) {
    final bytes = _content[key];
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
  Future<TomStoredExport> store({
    required String key,
    required Stream<List<int>> bytes,
    required String mediaType,
  }) async {
    TomExportStore.validateKey(key);
    final buffer = <int>[];
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
  Stream<List<int>> open(String key) async* {
    final bytes = _content[key];
    if (bytes == null) {
      throw TomExportException(
        'export.store.not_found',
        'No stored export exists for the requested key.',
        parameters: {'key': key},
      );
    }
    yield bytes;
  }

  @override
  Future<bool> exists(String key) async => _content.containsKey(key);

  @override
  Future<bool> delete(String key) async {
    _descriptors.remove(key);
    return _content.remove(key) != null;
  }

  @override
  String toString() => 'TomMemoryExportStore(${_content.length} exports)';
}

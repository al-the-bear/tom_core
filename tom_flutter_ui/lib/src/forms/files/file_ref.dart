/// The value a file field holds: a reference to a file, whether it is sitting
/// in memory, waiting on disk, or already stored on a server.
///
/// [FileRef] stays a small value type so `tom_flutter_ui` never has to depend
/// on a file-picker package (see `tom_file_picker_registry.dart` for how a
/// concrete picker is wired in without one). What it gained beyond name, size
/// and bytes are the two things a *streaming* upload needs:
///
///   * [FileRef.source] — a re-openable byte stream, so a 400 MB file is
///     uploaded straight from disk instead of being read into memory first;
///   * [FileRef.storageKey] — the server-generated key of an already-stored
///     file, so a form can be re-opened and show its attachment without
///     re-uploading it.
///
/// All three content forms are optional and a reference may carry none of them
/// — a stored file describes itself by name, size and key alone.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Lightweight, framework-agnostic file reference. Apps may extend or
/// adapt to richer types (e.g. wrap a `PlatformFile` from `file_picker`).
@immutable
class FileRef {
  /// The file name as the user knows it, including its extension.
  final String name;

  /// The file's size in bytes.
  final int sizeBytes;

  /// The media type, when the picker or server reported one.
  final String? mimeType;

  /// Optional in-memory bytes, for small files a picker already read.
  ///
  /// Prefer [source] for anything large: bytes held here are held for as long
  /// as the form is open.
  final Uint8List? bytes;

  /// Optional re-openable byte source, for files streamed from disk.
  ///
  /// A source can be opened repeatedly, which is what makes "retry" possible
  /// after a failed upload.
  final TomFileSource? source;

  /// The server-generated storage key, once the file has been stored.
  ///
  /// Opaque to the client: the server derives it and the client only carries
  /// it back. A reference with a key is a reference to a file that exists
  /// somewhere other than this device.
  final String? storageKey;

  const FileRef({
    required this.name,
    required this.sizeBytes,
    this.mimeType,
    this.bytes,
    this.source,
    this.storageKey,
  });

  /// A reference to a file that is already stored on a server.
  ///
  /// Built from the descriptor the transfer client returns, so a form
  /// re-opened later can show the attachment without downloading it.
  factory FileRef.stored(TomFileMetadata metadata) => FileRef(
    name: metadata.fileName ?? metadata.key.split('/').last,
    sizeBytes: metadata.byteCount,
    mimeType: metadata.mediaType,
    storageKey: metadata.key,
  );

  /// Whether this reference can produce the file's bytes without a download.
  bool get hasLocalContent => bytes != null || source != null;

  /// Whether this reference points at a file the server holds.
  bool get isStored => storageKey != null;

  /// The bytes to upload, as a re-openable source.
  ///
  /// Throws [StateError] when the reference carries no local content — a
  /// stored-only reference has nothing to upload, and silently uploading an
  /// empty file would be worse than saying so.
  TomFileSource toSource() {
    final existing = source;
    if (existing != null) return existing;
    final buffer = bytes;
    if (buffer != null) {
      return TomFileSource.bytes(name, buffer, mediaType: mimeType);
    }
    throw StateError(
      'FileRef "$name" has no local content to upload; it carries only '
      '${isStored ? 'a storage key' : 'metadata'}.',
    );
  }

  /// A copy with the given fields replaced.
  ///
  /// [storageKey] is the one field worth setting after the fact: it is what
  /// turns a just-picked reference into a stored one when an upload completes.
  FileRef copyWith({
    String? name,
    int? sizeBytes,
    String? mimeType,
    Uint8List? bytes,
    TomFileSource? source,
    String? storageKey,
  }) => FileRef(
    name: name ?? this.name,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    mimeType: mimeType ?? this.mimeType,
    bytes: bytes ?? this.bytes,
    source: source ?? this.source,
    storageKey: storageKey ?? this.storageKey,
  );

  /// The lowercase extension without its dot, or `''` when there is none.
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileRef &&
          other.name == name &&
          other.sizeBytes == sizeBytes &&
          other.mimeType == mimeType &&
          // Included because two references to the same-named file are *not*
          // the same file once one of them has been stored — a form that
          // compared only the name would think an upload changed nothing.
          other.storageKey == storageKey;

  @override
  int get hashCode => Object.hash(name, sizeBytes, mimeType, storageKey);

  @override
  String toString() =>
      'FileRef($name, $sizeBytes B'
      '${mimeType != null ? ', $mimeType' : ''}'
      '${storageKey != null ? ', stored as $storageKey' : ''})';
}

/// Picker callback contract. Returns the chosen file (or `null` if the
/// user cancels). Implementations can wrap `file_picker`, `image_picker`,
/// or any platform-specific picker.
typedef FilePicker = Future<FileRef?> Function(BuildContext context);

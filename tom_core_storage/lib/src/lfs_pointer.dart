import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'storage.dart';

/// A Git-LFS pointer file — the ~130 bytes git-lfs leaves in the tree in place
/// of the object it moved to an LFS server.
///
/// A backend here never writes one: LFS is a **client-side** clean/smudge
/// filter, and the git-data REST API never consults `.gitattributes`, so a
/// 1 MiB write to an LFS-tracked path stores 1 MiB of raw bytes. Nothing in
/// this package uses or configures LFS.
///
/// Reading is the other direction, and it is a real path rather than a
/// hypothetical: the repository is an ordinary one that other tools push to,
/// and a git client that *did* have the filter installed leaves a pointer where
/// the content should be. Delivered as content, a pointer is a broken render
/// for an image and a parse error with a misleading message for a container —
/// so it is [tomRefuseLfsPointer]'s job to say what actually happened.
///
/// Parsing is deliberately **strict**, not a prefix test. It is what makes a
/// false positive impossible to construct by accident rather than merely
/// unlikely: the version line is 41 exact bytes of URL, and the oid and size
/// lines have to be there and well-formed as well.
class TomLfsPointer {
  /// The object id exactly as the pointer states it, hash prefix included
  /// (`sha256:<64 lowercase hex>`).
  final String oid;

  /// The real object's size in bytes, as the pointer states it.
  ///
  /// Reported in the refusal because it is the one useful fact a pointer
  /// carries: it tells a reader the difference between "the file is empty" and
  /// "the file is 4 MB and lives somewhere this backend cannot reach".
  final int size;

  const TomLfsPointer({required this.oid, required this.size});

  /// The size past which bytes cannot be a pointer.
  ///
  /// 1024 is git-lfs's own `blobSizeCutoff` — the size at which it stops even
  /// looking — rather than a number invented here. It is checked first, so the
  /// overwhelmingly common case (a blob of real content) costs one integer
  /// comparison and never a decode.
  @visibleForTesting
  static const maxPointerBytes = 1024;

  /// The version lines git-lfs itself accepts. The two legacy URLs are not
  /// decoration: a pointer written by an old client is still a pointer, and
  /// recognising only the current URL would deliver it as content — the exact
  /// defect this class exists to prevent.
  static const _versionLines = {
    'version https://git-lfs.github.com/spec/v1',
    'version https://hawser.github.com/spec/v1',
    'version https://git-media.io/v/2',
  };

  static final _oidLine = RegExp(r'^oid (sha256:[0-9a-f]{64})$');
  static final _sizeLine = RegExp(r'^size (\d+)$');
  static final _otherLine = RegExp(r'^[a-z0-9][a-z0-9.\-]* .+$');

  /// The pointer [bytes] describe, or null when they are content.
  static TomLfsPointer? tryParse(Uint8List bytes) {
    if (bytes.length > maxPointerBytes) return null;
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      return null;
    }

    final lines = text.split('\n');
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    if (lines.length < 3) return null;
    if (!_versionLines.contains(lines.first)) return null;

    String? oid;
    int? size;
    for (final line in lines.skip(1)) {
      final oidMatch = _oidLine.firstMatch(line);
      if (oidMatch != null) {
        if (oid != null) return null;
        oid = oidMatch.group(1);
        continue;
      }
      final sizeMatch = _sizeLine.firstMatch(line);
      if (sizeMatch != null) {
        if (size != null) return null;
        size = int.tryParse(sizeMatch.group(1)!);
        if (size == null) return null;
        continue;
      }
      // The LFS spec reserves `ext-N-<name>` keys for extensions, so an
      // unrecognised but well-formed `key value` line is still a pointer.
      // Anything else is not.
      if (!_otherLine.hasMatch(line)) return null;
    }
    if (oid == null || size == null) return null;
    return TomLfsPointer(oid: oid, size: size);
  }

  @override
  String toString() => 'TomLfsPointer($oid, $size bytes)';
}

/// A stored object is a Git-LFS pointer, so its content is not where the
/// backend can reach it.
///
/// A named diagnostic rather than a generic failure because the two readings of
/// the same 130 bytes are worlds apart: as content they are a corrupt document,
/// and the error a user sees is a YAML parse failure or a blank image with
/// nothing pointing at the cause. This says the cause.
///
/// It extends [TomStorageException] for the reason
/// [TomKeyRequiredException] does: the sync loop catches that base on a
/// timer tick, and a read outcome it cannot name is one that escapes into an
/// unhandled async error.
class TomLfsObjectException extends TomStorageException {
  /// The path inside the container, which for a bundle is the member that is a
  /// pointer rather than the bundle as a whole.
  final String path;

  /// What the pointer says about the object it replaced.
  final TomLfsPointer pointer;

  TomLfsObjectException(
    String locator, {
    required this.path,
    required this.pointer,
    required String remedy,
  }) : super(
         locator,
         '$path is stored with Git LFS: the tree holds a pointer to a '
         '${pointer.size}-byte object (${pointer.oid}), not the object '
         'itself. $remedy',
       );
}

/// Throws [TomLfsObjectException] when [bytes] are a pointer.
///
/// One implementation, called by every backend that reads foreign bytes, so
/// the refusal cannot say one thing on GitHub and another on disk. [remedy] is
/// the part that legitimately differs — what the *reader* can do about it —
/// and is therefore supplied by the backend rather than guessed here.
void tomRefuseLfsPointer(
  String locator,
  String path,
  Uint8List bytes, {
  required String remedy,
}) {
  final pointer = TomLfsPointer.tryParse(bytes);
  if (pointer == null) return;
  throw TomLfsObjectException(
    locator,
    path: path,
    pointer: pointer,
    remedy: remedy,
  );
}

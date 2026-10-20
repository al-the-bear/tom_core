import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../bundle_medium.dart';

/// A medium backed by a real directory on disk.
///
/// Separated from the [TomBundleMedium] contract and the in-memory
/// implementation so that the one `dart:io` import stays behind `io.dart`: a
/// store written against [TomBundleMedium] therefore links on web, where there
/// is no local filesystem at all.
class TomDirectoryBundleMedium extends TomBundleMedium {
  final Directory root;

  TomDirectoryBundleMedium(this.root);

  File _file(String path) => File(p.join(root.path, path));

  @override
  Future<bool> exists(String path) async => _file(path).existsSync();

  @override
  Future<Uint8List> readBytes(String path) async =>
      _file(path).readAsBytesSync();

  /// Writes through a sibling temp file and renames it over the target.
  ///
  /// The rename is what makes the write atomic (see [TomBundleMedium]): it is a
  /// single directory operation on every filesystem a desktop or server runs,
  /// so a
  /// reader sees the old file or the new one and never a prefix. A **sibling**
  /// rather than a system temp directory, because rename is only atomic — and
  /// on POSIX only possible — within one filesystem, and the platform's temp
  /// directory is routinely on another.
  ///
  /// `flush: true` is the strongest durability Dart offers here: it fsyncs the
  /// file before the rename, so the bytes are on the device before anything
  /// points at them. It is **expected-green under mutation** — its effect is
  /// observable only after a power loss, which no in-process test can stage —
  /// and it is not decoration: without it the rename can publish a file whose
  /// contents the device has not yet written. What is *not* available is an fsync of the directory
  /// itself, so a power loss in the window after the rename can still lose the
  /// rename on some filesystems. That is a smaller hole than the one this
  /// closes — it loses the *new* content rather than corrupting the file — and
  /// closing it needs an API `dart:io` does not expose.
  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    final file = _file(path);
    file.parent.createSync(recursive: true);
    _sweepStaleTemps(file);
    final temp = File('${file.path}.$_pid.${_counter++}$tempSuffix');
    temp.writeAsBytesSync(bytes, flush: true);
    temp.renameSync(file.path);
  }

  /// Marks the temp files this class creates.
  ///
  /// Excluded from [listFiles], which is what keeps a crash-left temp from
  /// being read back as a file of the container — a stray entry in a listing is
  /// exactly the failure an interrupted write would otherwise cause *after*
  /// the interruption.
  static const tempSuffix = '.tom-tmp';

  /// Makes each temp name unique.
  ///
  /// **Expected-green under mutation**, and worth saying why rather than
  /// leaving the next reader to wonder: a fixed temp name passes every test
  /// here, because `writeBytes` is synchronous and one isolate cannot
  /// interleave two of them. What uniqueness buys is the case where two
  /// writers *do* reach the same path at once — with one shared temp name,
  /// each would write into the other's bytes and the rename would publish a
  /// mixture, which is exactly the torn file this method exists to prevent.
  /// The margin is three lines and the failure it guards is silent, so it is
  /// kept against a medium that becomes asynchronous or a second isolate that
  /// gains a write path. The pid is in the name for the same reason one
  /// directory may be open in two processes.
  static final _pid = pid;
  static var _counter = 0;

  /// Removes temps left for [target] by an earlier write.
  ///
  /// Safe because it runs **before** this write creates its own: any temp for
  /// this target is from a write that has already finished or died. Two
  /// processes writing the same path at the same time would be a lost-update
  /// race the CAS layer forbids long before this line is reached.
  ///
  /// Swept rather than left to accumulate: a crash otherwise leaves a file
  /// behind for ever, and "invisible but growing" is a leak whether or not
  /// anything reads it.
  void _sweepStaleTemps(File target) {
    final parent = target.parent;
    if (!parent.existsSync()) return;
    final prefix = '${p.basename(target.path)}.';
    for (final entry in parent.listSync()) {
      if (entry is! File) continue;
      final name = p.basename(entry.path);
      if (name.startsWith(prefix) && name.endsWith(tempSuffix)) {
        try {
          entry.deleteSync();
        } on FileSystemException {
          // Another process may be mid-write. Leaving it is the safe answer:
          // it is invisible to `listFiles`, and this write does not depend on
          // it being gone.
        }
      }
    }
  }

  /// Renames, rather than copying and deleting.
  ///
  /// Two things the base class's default cannot give: the move is **atomic**,
  /// so an interruption leaves the file at exactly one path; and it never
  /// reads the bytes, so retiring a asset into `.history/.assets/` does
  /// not pull tens of megabytes through memory to move a file a few inches.
  ///
  /// **Expected-green under mutation**: copy-and-delete reaches the same end
  /// state, so no outcome-based test can tell them apart. Both properties this
  /// buys are invisible from the outside — one needs an interruption, the
  /// other a memory measurement — which is the same reason the fsync and the
  /// unique temp name below are expected-green. Kept because the cost is one
  /// line and the failures are silent.
  @override
  Future<void> move(String from, String to) async {
    final target = _file(to);
    target.parent.createSync(recursive: true);
    _file(from).renameSync(target.path);
  }

  @override
  Future<void> delete(String path) async {
    final file = _file(path);
    if (file.existsSync()) file.deleteSync();
  }

  @override
  Future<List<String>> listFiles() async {
    if (!root.existsSync()) return [];
    return root
        .listSync(recursive: true)
        .whereType<File>()
        // A temp from an interrupted write is not a bundle file. Filtered on
        // the way out rather than cleaned up here, because listing is a read
        // and a read that deletes is a surprise.
        .where((f) => !f.path.endsWith(tempSuffix))
        .map((f) => p.relative(f.path, from: root.path))
        .map((rel) => rel.replaceAll(r'\', '/'))
        .toList()
      ..sort();
  }
}

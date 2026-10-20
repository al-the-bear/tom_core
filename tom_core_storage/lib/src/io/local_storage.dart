import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../bundle_medium.dart';
import '../commit_progress.dart';
import '../lfs_pointer.dart';
import '../object_ceiling.dart';
import '../storage.dart';

/// Containers on the local filesystem: a file, or a directory of files.
///
/// A multi-file changeset is applied **all-or-nothing** in three steps:
///
/// 1. **Stage.** Every write lands in a `.tom-tmp` sibling of its target.
///    A failure here removes the temps and leaves the container untouched.
/// 2. **Record.** One intent file, [intentName], names every rename and every
///    delete the changeset makes. It is written to a temp and renamed into
///    place, so it is either whole or absent — that rename is the commit
///    point.
/// 3. **Apply.** The temps are renamed over their targets, the deletes are
///    applied, and the intent is removed.
///
/// A crash before step 2 leaves temps beside an unchanged container; they are
/// ignored by every read and swept by the next commit. A crash after it leaves
/// an intent, and **every** entry point — reads included — finishes the
/// recorded renames and deletes before it looks at the container. So no reader
/// ever sees a half-applied changeset: it sees the old container until the
/// intent exists and the whole new one from then on.
///
/// The head token is a digest of the container's own state — for a single file
/// its size and modification time, for a directory the same over every part.
/// It is opaque and only ever compared, which is what makes it interchangeable
/// with a git commit sha.
class TomLocalFileSystemStorage extends TomStorage {
  /// Marks a staged write. Shared with `TomDirectoryBundleMedium`, so a
  /// temp either of them leaves is invisible to the other.
  static const tempSuffix = '.tom-tmp';

  /// The recorded intent of a directory commit, inside the container.
  @visibleForTesting
  static const intentName = '.tom-commit.json';

  /// Called between the steps of a directory commit — a test's way of failing
  /// one midway, as a crash would. Null in every production composition.
  final TomLocalCommitProbe? probe;

  const TomLocalFileSystemStorage({this.probe});

  /// Anything without a `<scheme>:` prefix. A bare Windows drive letter
  /// (`C:\…`) is a path, not a scheme, so it is deliberately not matched.
  @override
  bool handles(String locator) =>
      !RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]+:').hasMatch(locator);

  /// Whether [locator] addresses an existing directory.
  ///
  /// Only the filesystem is asked, never the name: a path that does not exist
  /// yet reads, lists and heads the same way whether it would become a file or
  /// a directory (not found, null), and a commit decides the shape from its
  /// changeset ([TomChangeset.isSingleFile]). A backend addresses more than
  /// documents — folders and files whose names carry no format suffix — so a
  /// name-based answer would be wrong for most of them.
  static bool _isDirectoryLocator(String locator) =>
      Directory(locator).existsSync();

  @override
  Future<List<TomStorageEntry>> list(String locator) async {
    if (!_isDirectoryLocator(locator)) {
      final file = File(locator);
      if (!file.existsSync()) {
        throw TomContainerNotFoundException(locator);
      }
      return [
        TomStorageEntry(
          name: p.basename(locator),
          path: TomChangeset.containerPath,
          kind: TomEntryKind.file,
          revision: _fileToken(file),
        ),
      ];
    }

    final dir = Directory(locator);
    if (!dir.existsSync()) throw TomContainerNotFoundException(locator);
    _recover(dir);
    final entries = <TomStorageEntry>[];
    for (final entity in dir.listSync(recursive: true)) {
      final relative = _relative(dir, entity.path);
      if (_isScratch(relative)) continue;
      if (entity is File) {
        entries.add(
          TomStorageEntry(
            name: p.basename(relative),
            path: relative,
            kind: TomEntryKind.file,
            revision: _fileToken(entity),
          ),
        );
      } else if (entity is Directory) {
        entries.add(
          TomStorageEntry(
            name: p.basename(relative),
            path: relative,
            kind: TomEntryKind.directory,
          ),
        );
      }
    }
    entries.sort((a, b) => a.path.compareTo(b.path));
    return entries;
  }

  @override
  Future<Uint8List> readBytes(String locator) async {
    final file = File(locator);
    if (!file.existsSync()) throw TomContainerNotFoundException(locator);
    final bytes = file.readAsBytesSync();
    tomRefuseLfsPointer(locator, p.basename(locator), bytes, remedy: lfsRemedy);
    return bytes;
  }

  /// The remedy here is a different one from the GitHub backend's, and that is
  /// the whole reason the sentence is supplied per backend rather than baked
  /// into the refusal: on disk a pointer means the working tree was never
  /// smudged, which `git lfs pull` fixes. The diagnosis is identical; what the
  /// reader can do about it is not.
  static const lfsRemedy =
      'This working tree holds the pointer rather than the object; run '
      '`git lfs pull` (or install git-lfs and re-checkout) to materialise it.';

  /// A read-through view of the folder, not a copy of it.
  ///
  /// It used to read **every** file into memory before returning — including
  /// `.history/`, so the cost of opening a bundle grew with the document's
  /// entire edit history and a one-word save paid for all of it. Reading on
  /// demand makes a save cost the manifest plus the sections it compares.
  ///
  /// The LFS refusal moves with the read, which is an improvement
  /// rather than a compromise: a pointer is now refused when the file holding
  /// it is actually read, instead of failing the whole open because some
  /// unrelated snapshot nobody was going to look at is LFS-stored.
  @override
  Future<TomBundleMedium> readBundle(String locator) async {
    final dir = Directory(locator);
    if (!dir.existsSync()) throw TomContainerNotFoundException(locator);
    _recover(dir);
    return TomReadOnlyBundleMedium(_LocalBundleMedium(dir, locator));
  }

  @override
  Future<String> commit(
    String locator,
    TomChangeset changeset, {
    String? expectedHead,
    String? message,
    // Deliberately unused: a local save is a handful of `writeAsBytesSync`
    // calls and is over before a frame renders, so reporting progress through
    // it would be inventing a wait to display. The port makes the sink
    // optional for exactly this backend.
    TomCommitProgressSink? onProgress,
  }) async {
    tomGuardChangeset(locator, changeset, this);
    final directory = !changeset.isSingleFile;
    if (directory && Directory(locator).existsSync()) {
      final dir = Directory(locator);
      _recover(dir);
      _sweep(dir);
    } else if (!directory) {
      final stray = File('$locator$tempSuffix');
      if (stray.existsSync()) stray.deleteSync();
    }
    final actualHead = await headOf(locator);
    if (actualHead != expectedHead) {
      throw TomCasConflictException(
        locator,
        expectedHead: expectedHead,
        actualHead: actualHead,
      );
    }
    if (changeset.isEmpty) return actualHead ?? TomStorage.emptyHead;

    if (!directory) {
      // One file is one rename, which the filesystem already makes atomic.
      final temp = _stage({locator: changeset.containerBytes});
      File(temp.keys.single).renameSync(locator);
      return (await headOf(locator))!;
    }

    final dir = Directory(locator)..createSync(recursive: true);
    final staged = _stage({
      for (final entry in changeset.writes.entries)
        p.join(dir.path, entry.key): entry.value,
    });
    try {
      probe?.call(TomLocalCommitStep.staged);
      _recordIntent(dir, staged, changeset.deletes);
    } catch (_) {
      // Before the commit point: the container is untouched, and the temps
      // are all that has to go.
      _discard(staged.keys);
      rethrow;
    }
    // Past the commit point a failure is not undone. The intent stays, and
    // the next access to the container finishes what it records.
    probe?.call(TomLocalCommitStep.recorded);
    _applyIntent(dir);
    return (await headOf(locator))!;
  }

  @override
  Future<void> delete(String locator) async {
    if (_isDirectoryLocator(locator)) {
      final dir = Directory(locator);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      return;
    }
    final file = File(locator);
    if (file.existsSync()) file.deleteSync();
  }

  @override
  Future<String?> headOf(String locator) async {
    if (!_isDirectoryLocator(locator)) {
      final file = File(locator);
      return file.existsSync() ? _fileToken(file) : null;
    }
    final dir = Directory(locator);
    if (!dir.existsSync()) return null;
    _recover(dir);
    // A staged temp is not part of the container: counting one would move the
    // head of a container nobody changed, and turn a crashed save into a CAS
    // conflict for the next one.
    final tokens = <String>[
      for (final file in dir.listSync(recursive: true).whereType<File>())
        if (!_isScratch(_relative(dir, file.path)))
          '${_relative(dir, file.path)}=${_fileToken(file)}',
    ]..sort();
    return _digest(tokens.join('\n'));
  }

  // ── Internals ───────────────────────────────────────────────────────────

  /// Writes every entry to a temp sibling, returning temp → target.
  ///
  /// All-or-nothing on its own terms: a failure removes the temps it wrote.
  Map<String, String> _stage(Map<String, Uint8List> writes) {
    final staged = <String, String>{};
    try {
      for (final entry in writes.entries) {
        final target = File(entry.key);
        target.parent.createSync(recursive: true);
        final temp = '${entry.key}$tempSuffix';
        File(temp).writeAsBytesSync(entry.value, flush: true);
        staged[temp] = entry.key;
      }
    } catch (_) {
      _discard(staged.keys);
      rethrow;
    }
    return staged;
  }

  static void _discard(Iterable<String> paths) {
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }
  }

  /// Writes the intent whole or not at all: to a temp, then one rename.
  static void _recordIntent(
    Directory dir,
    Map<String, String> staged,
    Set<String> deletes,
  ) {
    final intent = File(p.join(dir.path, intentName));
    final temp = File('${intent.path}$tempSuffix');
    temp.writeAsStringSync(
      jsonEncode({
        'renames': [for (final target in staged.values) _relative(dir, target)],
        'deletes': deletes.toList()..sort(),
      }),
      flush: true,
    );
    temp.renameSync(intent.path);
  }

  /// Finishes a recorded commit, if one is pending.
  ///
  /// Idempotent, so a crash *during* recovery is recovered by the next access
  /// just the same: a rename whose temp is gone has already happened, and a
  /// delete of a file that is gone has too.
  void _recover(Directory dir) {
    if (File(p.join(dir.path, intentName)).existsSync()) _applyIntent(dir);
  }

  void _applyIntent(Directory dir) {
    final intent = File(p.join(dir.path, intentName));
    final decoded = jsonDecode(intent.readAsStringSync()) as Map;
    for (final relative in (decoded['renames'] as List).cast<String>()) {
      final target = p.join(dir.path, relative);
      final temp = File('$target$tempSuffix');
      if (temp.existsSync()) {
        temp.renameSync(target);
        probe?.call(TomLocalCommitStep.renamed);
      }
    }
    for (final relative in (decoded['deletes'] as List).cast<String>()) {
      final file = File(p.join(dir.path, relative));
      if (file.existsSync()) file.deleteSync();
    }
    intent.deleteSync();
  }

  /// Removes every temp a crashed commit left behind before its commit point.
  ///
  /// Run by a commit only, never by a read, and after [_recover]: by then any
  /// temp still present belongs to a changeset that never committed.
  static void _sweep(Directory dir) {
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      if (file.path.endsWith(tempSuffix)) file.deleteSync();
    }
  }

  /// A staged temp or the intent file — bookkeeping, never container content.
  static bool _isScratch(String relative) =>
      relative.endsWith(tempSuffix) || relative == intentName;

  static String _relative(Directory root, String path) =>
      p.relative(path, from: root.path).replaceAll(r'\', '/');

  static String _fileToken(File file) {
    final stat = file.statSync();
    return '${stat.size}:${stat.modified.microsecondsSinceEpoch}';
  }

  /// A stable, short token for an arbitrary string. Not a security digest —
  /// the only requirement is that a changed container yields a changed token.
  ///
  /// FNV-1a 64, carried as two 32-bit halves. The halves are not an
  /// optimization: written the obvious way, the offset basis and the mask are
  /// integer literals above 2^53, which dart2js rejects outright — so the
  /// obvious spelling makes every library that reaches this one unlinkable on
  /// web. Split this way, no literal and no intermediate leaves the
  /// range a double represents exactly, and only `*`, `+`, `%`, `~/` and `^`
  /// are used, all of which agree across the VM and dart2js.
  ///
  /// The 64-bit value is unchanged. The *rendering* is not: the direct version
  /// masked with `0xFFFFFFFFFFFFFFFF`, which is `-1` in signed 64-bit and
  /// therefore a no-op, so `toRadixString` emitted a leading `-` whenever the
  /// top bit was set — a 17-character token that `padLeft(16, '0')` was
  /// evidently meant to prevent. Tokens are opaque and recomputed on read, so
  /// the change costs at most one spurious CAS mismatch per directory-backed
  /// container, which resolves through the ordinary conflict path.
  static String _digest(String input) {
    const wrap = 0x100000000; // 2^32
    var high = 0xcbf29ce4;
    var low = 0x84222325;
    for (final byte in utf8.encode(input)) {
      low ^= byte;
      // (high:low) * 0x100000001b3, truncated to 64 bits. The prime's halves
      // are 0x100 and 0x1b3, so the widest intermediate is under 2^42.
      final product = low * 0x1b3;
      high = (high * 0x1b3 + low * 0x100 + product ~/ wrap) % wrap;
      low = product % wrap;
    }
    return high.toRadixString(16).padLeft(8, '0') +
        low.toRadixString(16).padLeft(8, '0');
  }
}

/// Reads a folder's files on demand, guarding each against the LFS
/// pointer.
///
/// Separate from `TomDirectoryBundleMedium`, which is the *writable* medium the
/// io convenience pair and the device-local journal use. The guard belongs to
/// the storage tier rather than to the medium: an LFS pointer is a fact about
/// a repository working tree, and the journal's own medium has no business
/// knowing about it.
class _LocalBundleMedium extends TomBundleMedium {
  final Directory root;
  final String locator;

  _LocalBundleMedium(this.root, this.locator);

  File _file(String path) => File(p.join(root.path, path));

  @override
  Future<bool> exists(String path) async => _file(path).existsSync();

  @override
  Future<Uint8List> readBytes(String path) async {
    final file = _file(path);
    if (!file.existsSync()) {
      throw TomContainerNotFoundException('$locator/$path');
    }
    final bytes = file.readAsBytesSync();
    tomRefuseLfsPointer(
      locator,
      path,
      bytes,
      remedy: TomLocalFileSystemStorage.lfsRemedy,
    );
    return bytes;
  }

  @override
  Future<List<String>> listFiles() async {
    if (!root.existsSync()) return [];
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => p.relative(f.path, from: root.path))
        .map((rel) => rel.replaceAll(r'\', '/'))
        .where((rel) => !TomLocalFileSystemStorage._isScratch(rel))
        .toList()
      ..sort();
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async =>
      throw UnsupportedError('unreachable: wrapped read-only');

  @override
  Future<void> delete(String path) async =>
      throw UnsupportedError('unreachable: wrapped read-only');
}

/// The points between which a directory commit can be interrupted.
enum TomLocalCommitStep {
  /// Every write is staged; the intent is not yet recorded.
  staged,

  /// The intent is recorded — the commit point — and nothing is renamed yet.
  recorded,

  /// One staged write has been renamed over its target.
  renamed,
}

/// Observes [TomLocalFileSystemStorage.commit]; throwing from it is how a
/// test simulates a crash at that step.
typedef TomLocalCommitProbe = void Function(TomLocalCommitStep step);

/// A [TomFileSystem] over one [TomStorage] container, so an editor that takes
/// its storage as a file system opens files from any storage tier: the local
/// filesystem, a GitHub repository, a git server, memory.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:tom_file_system/tom_file_system.dart';

import '../storage.dart';

/// The files of the container at [locator] as a [TomFileSystem].
///
/// A path of the file system is a path inside the container: `notes/a.txt`
/// under the root is the member `notes/a.txt` of the container. Folders are
/// what the members' paths imply; storage keeps no empty folder.
///
/// - **Revisions** are the content hash of the bytes read
///   ([TomFileRevision.of]), the identity every backend's object has; storage
///   keeps no modification time, so [TomFileRevision.modified] is the epoch.
/// - A **write** is one commit of the container, guarded by the container's
///   head. With an expected revision it is refused with a [TomFileConflict]
///   when the file is no longer that revision; a commit that loses the race
///   only to a change of *another* file is retried, so two editors on two
///   files of one container do not refuse each other.
/// - **Listing** is as deep as the backend lists; an entry's size is not
///   known without reading it and is answered as 0.
/// - **Watch** and **trash** are not supported: [watch] answers null and
///   [trash] false, so a caller asks before [delete].
class TomStorageFileSystem extends TomFileSystemBase {
  /// The file system of [locator] in [storage]. [root] is the URI the files
  /// are addressed under; the default is `tomstorage:/`.
  TomStorageFileSystem(
    this.storage,
    this.locator, {
    Uri? root,
    this.maxCommitAttempts = 5,
    this.commitMessage = _defaultMessage,
  }) : super(root ?? Uri.parse('tomstorage:/'));

  /// The backend.
  final TomStorage storage;

  /// The container this file system shows.
  final String locator;

  /// How often a write that lost the container's compare-and-swap to a change
  /// of another file is tried again before the conflict is rethrown.
  final int maxCommitAttempts;

  /// The commit message of a change, from its kind and the paths it touches.
  final String Function(String action, List<String> paths) commitMessage;

  static String _defaultMessage(String action, List<String> paths) =>
      '$action ${paths.join(', ')}';

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// The container's member paths, or none when it does not exist yet.
  Future<List<String>> _files() async {
    try {
      final entries = await storage.list(locator);
      return [
        for (final entry in entries)
          if (entry.isFile && entry.path != TomChangeset.containerPath)
            entry.path,
      ];
    } on TomContainerNotFoundException {
      return const [];
    }
  }

  /// [uri]'s path in the container; refused outside the root.
  String _path(Uri uri) {
    final path = pathOf(uri);
    if (path == null) {
      throw TomFileSystemException('Outside the file system', uri);
    }
    return path;
  }

  /// The bytes of [path] now, or null when there is no such file.
  Future<Uint8List?> _bytesOf(String path) async {
    if (path.isEmpty) return null;
    try {
      final medium = await storage.readBundle(locator);
      if (!await medium.exists(path)) return null;
      return await medium.readBytes(path);
    } on TomContainerNotFoundException {
      return null;
    }
  }

  bool _under(String file, String folder) =>
      folder.isEmpty || file.startsWith('$folder/');

  TomFileEntry _fileEntry(String path) => TomFileEntry(
    name: path.split('/').last,
    path: path,
    uri: uriOf(path),
    kind: TomFileEntryKind.file,
    modified: _epoch,
  );

  TomFileEntry _folderEntry(String path) => TomFileEntry(
    name: path.isEmpty ? '' : path.split('/').last,
    path: path,
    uri: uriOf(path.isEmpty ? '' : '$path/'),
    kind: TomFileEntryKind.directory,
    modified: _epoch,
  );

  /// Commits what [build] makes of the container's files, retrying when the
  /// container moved under it; [build] runs again on each attempt, so its
  /// checks see the files as they are.
  Future<void> _commit(
    String action,
    Future<TomChangeset> Function(List<String> files) build,
  ) async {
    for (var attempt = 1; ; attempt++) {
      final head = await storage.headOf(locator);
      final changeset = await build(await _files());
      if (changeset.isEmpty) return;
      try {
        await storage.commit(
          locator,
          changeset,
          expectedHead: head,
          message: commitMessage(action, [
            ...changeset.writes.keys,
            ...changeset.deletes,
          ]),
        );
        return;
      } on TomCasConflictException {
        if (attempt >= maxCommitAttempts) rethrow;
      }
    }
  }

  @override
  Future<List<TomFileEntry>> list(Uri directory) async {
    final folder = _path(directory);
    final files = await _files();
    final children = <String, TomFileEntry>{};
    for (final file in files) {
      if (!_under(file, folder)) continue;
      final rest = folder.isEmpty ? file : file.substring(folder.length + 1);
      final slash = rest.indexOf('/');
      if (slash < 0) {
        children[rest] = _fileEntry(file);
      } else {
        final name = rest.substring(0, slash);
        children.putIfAbsent(
          name,
          () => _folderEntry(folder.isEmpty ? name : '$folder/$name'),
        );
      }
    }
    if (children.isEmpty && folder.isNotEmpty) {
      throw TomFileSystemException('No such folder', directory);
    }
    return children.values.toList();
  }

  @override
  Future<TomFileEntry?> stat(Uri uri) async {
    final path = _path(uri);
    if (path.isEmpty) return _folderEntry('');
    final files = await _files();
    if (files.contains(path)) return _fileEntry(path);
    if (files.any((file) => _under(file, path))) return _folderEntry(path);
    return null;
  }

  @override
  Future<TomFileContent> read(Uri uri) async {
    final bytes = await _bytesOf(_path(uri));
    if (bytes == null) throw TomFileSystemException('No such file', uri);
    return TomFileContent(bytes, TomFileRevision.of(bytes, _epoch));
  }

  @override
  Future<String?> readSlice(
    Uri uri, {
    required int maxBytes,
    required bool fromEnd,
  }) async {
    final bytes = await _bytesOf(_path(uri));
    if (bytes == null) return null;
    final cut = bytes.length > maxBytes;
    final start = fromEnd && cut ? bytes.length - maxBytes : 0;
    final end = cut ? start + maxBytes : bytes.length;
    final text = utf8.decode(bytes.sublist(start, end), allowMalformed: true);
    if (!cut) return text;
    return fromEnd ? tomTrimToLineStart(text) : tomTrimToLineEnd(text);
  }

  @override
  Future<TomFileRevision> write(
    Uri uri,
    Uint8List bytes, {
    TomFileRevision? expected,
  }) async {
    final path = _path(uri);
    if (path.isEmpty) throw TomFileSystemException('Not a file', uri);
    var isNew = false;
    await _commit('write', (files) async {
      isNew = !files.contains(path);
      if (expected != null) {
        final current = await _bytesOf(path);
        final revision = current == null
            ? null
            : TomFileRevision.of(current, _epoch);
        if (revision != expected) {
          throw TomFileConflict(absolute(uri), revision);
        }
      }
      return TomChangeset(writes: {path: Uint8List.fromList(bytes)});
    });
    emitChange(
      uri,
      isNew ? TomFileChangeType.created : TomFileChangeType.modified,
    );
    return TomFileRevision.of(bytes, _epoch);
  }

  /// A folder needs nothing: storage keeps no empty folder, and one exists as
  /// soon as a file is written under it. A file is created empty.
  @override
  Future<void> create(Uri uri, {bool directory = false}) async {
    final path = _path(uri);
    if (directory) return;
    await _commit('create', (files) async {
      if (files.contains(path) || files.any((file) => _under(file, path))) {
        throw TomFileSystemException('Already exists', uri);
      }
      return TomChangeset(writes: {path: Uint8List(0)});
    });
    emitChange(uri, TomFileChangeType.created);
  }

  /// One commit: every file of [from] written under [to] and deleted from
  /// [from].
  @override
  Future<void> rename(Uri from, Uri to) async {
    final source = _path(from);
    final target = _path(to);
    await _commit('rename', (files) async {
      if (files.contains(target) || files.any((f) => _under(f, target))) {
        throw TomFileSystemException('Already exists', to);
      }
      final moved = files.contains(source)
          ? [source]
          : [
              for (final f in files)
                if (source.isNotEmpty && _under(f, source)) f,
            ];
      if (moved.isEmpty) throw TomFileSystemException('No such entry', from);
      final medium = await storage.readBundle(locator);
      return TomChangeset(
        writes: {
          for (final f in moved)
            target + f.substring(source.length): await medium.readBytes(f),
        },
        deletes: moved.toSet(),
      );
    });
    emitChange(from, TomFileChangeType.deleted);
    emitChange(to, TomFileChangeType.created);
  }

  /// Storage has no trash: answers false, and the caller asks before
  /// [delete].
  @override
  Future<bool> trash(Uri uri) async => false;

  @override
  Future<void> delete(Uri uri) async {
    final path = _path(uri);
    await _commit('delete', (files) async {
      final gone = {
        for (final f in files)
          if (f == path || _under(f, path)) f,
      };
      if (gone.isEmpty) throw TomFileSystemException('No such entry', uri);
      return TomChangeset(deletes: gone);
    });
    emitChange(uri, TomFileChangeType.deleted);
  }

  @override
  Future<bool> exists(Uri uri) async => await stat(uri) != null;

  /// Storage tiers report no changes: answers null.
  @override
  Stream<TomFileChange>? watch({bool Function(String path)? descend}) => null;
}

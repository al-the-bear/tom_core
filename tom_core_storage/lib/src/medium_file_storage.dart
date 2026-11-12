import 'dart:typed_data';

import 'package:tom_basics/utilities.dart';

import 'bundle_medium.dart';
import 'commit_progress.dart';
import 'object_ceiling.dart';
import 'storage.dart';

/// Single-file containers kept on a [TomBundleMedium], each under its own
/// locator — the storage a root has when its device storage is a keyed medium
/// and not a file system: a browser's IndexedDB (`tomOpenBrowserMedium`).
///
/// A locator is [prefix] followed by the key the bytes are kept under on the
/// medium, so `browser:settings.webwork.kdbx` is the medium's
/// `settings.webwork.kdbx`. Only whole-container writes are taken
/// ([TomChangeset.isSingleFile]): a bundle of member files has no single
/// place on a flat medium, and a medium is not a folder.
///
/// **Compare-and-swap by content.** A head is the SHA-256 of the bytes stored,
/// so a commit whose `expectedHead` is not the stored content's hash — or that
/// expects none where a file exists, or one where none does — is refused with
/// [TomCasConflictException], which is the contract every backend keeps: a
/// second tab that wrote first is detected, not overwritten. Writes are as
/// atomic as the medium's, which `TomBundleMedium` requires.
class TomMediumFileStorage extends TomStorage {
  /// Where the containers are kept.
  final TomBundleMedium medium;

  /// The locator scheme this storage answers for, e.g. `browser:`.
  final String prefix;

  const TomMediumFileStorage({required this.medium, required this.prefix});

  @override
  bool handles(String locator) => locator.startsWith(prefix);

  String _key(String locator) {
    if (!handles(locator)) {
      throw TomStorageException(locator, 'not a $prefix locator');
    }
    return locator.substring(prefix.length);
  }

  @override
  Future<List<TomStorageEntry>> list(String locator) async {
    final key = _key(locator);
    final under = key.isEmpty || key.endsWith('/') ? key : '$key/';
    return [
      for (final path in await medium.listFiles())
        if (path.startsWith(under))
          TomStorageEntry(
            name: path.split('/').last,
            path: '$prefix$path',
            kind: TomEntryKind.file,
          ),
    ];
  }

  @override
  Future<Uint8List> readBytes(String locator) async {
    final key = _key(locator);
    if (!await medium.exists(key)) {
      throw TomContainerNotFoundException(locator);
    }
    return medium.readBytes(key);
  }

  @override
  Future<TomBundleMedium> readBundle(String locator) async =>
      throw TomStorageException(
        locator,
        'a medium keeps single-file containers only; there is no bundle here',
      );

  @override
  Future<String> commit(
    String locator,
    TomChangeset changeset, {
    String? expectedHead,
    String? message,
    TomCommitProgressSink? onProgress,
  }) async {
    final key = _key(locator);
    tomGuardChangeset(locator, changeset, this);
    final actual = await headOf(locator);
    if (actual != expectedHead) {
      throw TomCasConflictException(
        locator,
        expectedHead: expectedHead,
        actualHead: actual,
      );
    }
    if (changeset.isEmpty) return actual ?? TomStorage.emptyHead;
    if (!changeset.isSingleFile) {
      throw TomStorageException(
        locator,
        'a medium keeps single-file containers only; this changeset writes '
        '${changeset.writes.length} paths and deletes '
        '${changeset.deletes.length}',
      );
    }
    final bytes = changeset.writes[TomChangeset.containerPath]!;
    await medium.writeBytes(key, bytes);
    return tomSha256Hex(bytes);
  }

  @override
  Future<void> delete(String locator) => medium.delete(_key(locator));

  @override
  Future<String?> headOf(String locator) async {
    final key = _key(locator);
    if (!await medium.exists(key)) return null;
    return tomSha256Hex(await medium.readBytes(key));
  }
}

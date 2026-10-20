/// A single-file [TomStorage] over a map, with compare-and-swap heads.
library;

import 'dart:typed_data';

import 'package:tom_core_storage/tom_core_storage.dart';

/// Holds one byte string per locator and refuses a commit whose expected head
/// is not the current one, as every real backend does.
class MemoryStorage extends TomStorage {
  final Map<String, Uint8List> files = {};
  final Map<String, int> _revisions = {};

  /// How many commits landed.
  int commits = 0;

  @override
  bool handles(String locator) => locator.startsWith('mem:');

  @override
  Future<List<TomStorageEntry>> list(String locator) async => const [];

  @override
  Future<Uint8List> readBytes(String locator) async {
    final bytes = files[locator];
    if (bytes == null) throw TomContainerNotFoundException(locator);
    return bytes;
  }

  @override
  Future<TomBundleMedium> readBundle(String locator) async =>
      throw TomContainerNotFoundException(locator);

  @override
  Future<String> commit(
    String locator,
    TomChangeset changeset, {
    String? expectedHead,
    String? message,
    TomCommitProgressSink? onProgress,
  }) async {
    final current = await headOf(locator);
    if (current != expectedHead) {
      throw TomCasConflictException(
        locator,
        expectedHead: expectedHead,
        actualHead: current,
      );
    }
    files[locator] = changeset.containerBytes;
    _revisions[locator] = (_revisions[locator] ?? 0) + 1;
    commits++;
    return (await headOf(locator))!;
  }

  @override
  Future<void> delete(String locator) async {
    files.remove(locator);
    _revisions.remove(locator);
  }

  @override
  Future<String?> headOf(String locator) async {
    final revision = _revisions[locator];
    return revision == null ? null : 'r$revision';
  }
}

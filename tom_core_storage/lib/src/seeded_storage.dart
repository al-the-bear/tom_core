import 'dart:typed_data';

import 'bundle_medium.dart';
import 'commit_progress.dart';
import 'storage.dart';

/// A read-only view of [inner], except that [locator]'s container is [seed] —
/// what a conversion between container forms (a directory and its ZIP form)
/// serializes over. It never commits, so it carries no `tomGuardChangeset`:
/// the conversion commits through [inner] itself, which guards its own.
class TomSeededStorage extends TomStorage {
  final TomStorage inner;
  final String locator;
  final TomMemoryBundleMedium seed;

  TomSeededStorage(this.inner, this.locator, this.seed);

  @override
  bool handles(String locator) => inner.handles(locator);

  @override
  int? get maxObjectBytes => inner.maxObjectBytes;

  @override
  Future<List<TomStorageEntry>> list(String locator) => inner.list(locator);

  @override
  Future<Uint8List> readBytes(String locator) async =>
      locator == this.locator ? seed.toZip() : inner.readBytes(locator);

  @override
  Future<TomBundleMedium> readBundle(String locator) async =>
      locator == this.locator ? seed : inner.readBundle(locator);

  @override
  Future<String> commit(
    String locator,
    TomChangeset changeset, {
    String? expectedHead,
    String? message,
    TomCommitProgressSink? onProgress,
  }) => throw UnsupportedError('A seeded view is read-only');

  @override
  Future<void> delete(String locator) =>
      throw UnsupportedError('A seeded view is read-only');

  @override
  Future<String?> headOf(String locator) => inner.headOf(locator);
}

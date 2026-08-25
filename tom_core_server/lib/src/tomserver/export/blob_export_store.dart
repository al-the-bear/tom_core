/// The adaptor that puts the framework's blob storage behind the export
/// module's own store interface.
///
/// `export_store.dart` was written to a deliberately narrow four-method
/// contract, before the general blob storage existed, and said so: *"a
/// `TomExportStore` implementation over its blob API is the whole adaptation,
/// and nothing that renders or delivers an export changes."* This file is that
/// implementation, and the prediction held — it is four delegating methods and
/// a descriptor translation.
///
/// What it buys is every backend at once: an export can be written to a
/// database, an S3 bucket, or an application's own store without the export
/// module knowing any of them exist.
library;

import 'dart:async';

import '../file_storage/blob_store.dart';
import '../file_storage/blob_store_registry.dart';
import 'export_store.dart';
import 'tabular_result.dart';

/// A [TomExportStore] backed by a [TomBlobStore].
class TomBlobExportStore extends TomExportStore {
  /// Wraps [blobStore], optionally namespacing every key under [keyPrefix].
  ///
  /// [keyPrefix] exists because an export store is often pointed at a bucket
  /// that holds other things; `exports/2026/07/sales.xlsx` keeps them apart and
  /// makes a retention rule expressible as a prefix.
  TomBlobExportStore(this.blobStore, {this.keyPrefix = ''});

  /// Wraps the blob store registered under [name], or the default store when
  /// [name] is `null` — the constructor a configured deployment uses.
  factory TomBlobExportStore.named(String? name, {String keyPrefix = ''}) =>
      TomBlobExportStore(
        name == null
            ? TomBlobStoreInfo.defaultStore
            : TomBlobStoreInfo.storeNamed(name),
        keyPrefix: keyPrefix,
      );

  /// The blob store the exports are kept in.
  ///
  /// Named `blobStore` rather than `store` because [TomExportStore.store] is
  /// this interface's write *method*.
  final TomBlobStore blobStore;

  /// The prefix prepended to every key before it reaches [blobStore].
  final String keyPrefix;

  /// The blob key for the export key [key].
  ///
  /// [key] arrives validated — [TomExportStore] checks it before dispatching —
  /// and the prefix is applied *after*, so a traversal cannot be smuggled in
  /// relative to the prefix and the rejected key in the error is the one the
  /// caller actually passed.
  String _blobKey(String key) => keyPrefix.isEmpty ? key : '$keyPrefix/$key';

  @override
  Future<TomStoredExport> doStore({
    required String key,
    required Stream<List<int>> bytes,
    required String mediaType,
  }) async {
    final blob = await blobStore.put(
      key: _blobKey(key),
      bytes: bytes,
      mediaType: mediaType,
    );
    // The caller's key, not the prefixed one: the prefix is this store's
    // business, and an export whose recorded key could not be passed back to
    // [open] would be a trap.
    return TomStoredExport(
      key: key,
      mediaType: blob.mediaType,
      byteCount: blob.byteCount,
      storedAt: blob.storedAt,
      location: blob.location,
    );
  }

  @override
  Stream<List<int>> doOpen(String key) async* {
    try {
      // `await for`, not `yield*`: a `yield*` forwards the inner stream's
      // *errors* straight to the output stream, past the enclosing try — so the
      // translation below would never run. Re-yielding each chunk keeps the
      // read streaming and puts the errors back inside the handler.
      await for (final chunk in blobStore.get(_blobKey(key))) {
        yield chunk;
      }
    } on TomStorageException catch (error) {
      // Only the missing-key case is named here, because it is the only one
      // this adaptor knows something about that [TomExportStore.open] does not:
      // a blob store reports absence as an error, and it has to become the
      // export module's own `not_found` rather than its `read_failed`. Every
      // other storage failure falls through to `open`, which translates it —
      // a caller catches [TomExportException] whichever backend is configured.
      if (error.key != 'storage.blob.not_found') rethrow;
      throw TomExportException(
        'export.store.not_found',
        'No stored export exists for the requested key.',
        parameters: {'key': key},
        rootException: error,
      );
    }
  }

  @override
  Future<bool> doExists(String key) => blobStore.exists(_blobKey(key));

  @override
  Future<bool> doDelete(String key) => blobStore.delete(_blobKey(key));

  @override
  String toString() =>
      'TomBlobExportStore($blobStore'
      '${keyPrefix.isEmpty ? '' : ', prefix "$keyPrefix"'})';
}

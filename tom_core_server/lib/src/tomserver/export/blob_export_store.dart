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
  ///
  /// Throws [TomExportException] (`export.store.invalid_key`) when [keyPrefix]
  /// is not a usable namespace — it is joined to keys the store has already
  /// checked, so an unchecked prefix would produce a key no backend accepts.
  TomBlobExportStore(this.blobStore, {String keyPrefix = ''})
    : keyPrefix = _validPrefix(keyPrefix);

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
  ///
  /// Checked at construction, and `''` when there is none.
  final String keyPrefix;

  /// Returns [keyPrefix] if it is a usable namespace, in the export module's
  /// own error vocabulary.
  ///
  /// The rule is [TomBlobStore]'s, because the prefixed key is what a blob
  /// backend has to accept; the exception type is this module's, because a
  /// caller configuring an export store should not have to catch a storage
  /// error to learn its own setting is wrong. The parameter is `keyPrefix`
  /// rather than `key` for the same reason — this is a misconfiguration, and
  /// the derived key it would otherwise name is one nobody wrote.
  static String _validPrefix(String keyPrefix) {
    if (!TomBlobStore.isValidKeyPrefix(keyPrefix)) {
      throw TomExportException(
        'export.store.invalid_key',
        'The configured export key prefix is not a valid key namespace.',
        parameters: {'keyPrefix': keyPrefix},
      );
    }
    return keyPrefix;
  }

  /// The blob key for the export key [key].
  ///
  /// Both halves are checked, in the two places each belongs. [key] arrives
  /// validated — [TomExportStore] checks it before dispatching — and the prefix
  /// was validated at construction, where a deployment setting can be blamed
  /// for itself. The prefix is applied *after* the key check, so a traversal
  /// cannot be smuggled in relative to the prefix and the rejected key in a
  /// key error is the one the caller actually passed.
  ///
  /// What neither check can settle is length: two individually valid parts can
  /// join past [TomBlobStore.maxKeyLength]. That depends on the caller's key,
  /// so the backend's own [TomBlobStore.validateKey] remains the one that
  /// catches it — as `export.store.write_failed` and friends, translated by
  /// [TomExportStore], like any other backend refusal.
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

  /// Whatever the blob store underneath answers.
  ///
  /// This was `false`, on the argument that widening the blob contract to serve
  /// the export module's retention would be the wrong direction. What changed
  /// is that file storage acquired its *own* caller for the same primitive —
  /// nothing bounded how much a deployment stored there either — and a prefix
  /// delete turned out not to be the listing that argument was about. A listing
  /// is a method whose cost differs by an order of magnitude between backends
  /// while looking like a map lookup; a prefix delete is one operation a
  /// backend can either perform or refuse, which is what
  /// `supportsPrefixDelete` says out loud.
  ///
  /// So this delegates, and an export store over a blob store reclaims a
  /// partition exactly as the directory and memory stores do — including over
  /// S3, where the blob backend pays a paginated list and a batched delete and
  /// says so.
  @override
  bool get supportsPrefixDelete => blobStore.supportsPrefixDelete;

  @override
  Future<int> doDeletePrefix(String prefix) =>
      blobStore.deletePrefix(_blobKey(prefix));

  @override
  String toString() =>
      'TomBlobExportStore($blobStore'
      '${keyPrefix.isEmpty ? '' : ', prefix "$keyPrefix"'})';
}

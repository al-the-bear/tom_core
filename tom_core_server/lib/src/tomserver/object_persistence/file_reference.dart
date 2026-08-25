/// The runtime half of `@TomFileReference`: resolving a column's store and
/// minting the keys it stores.
///
/// The annotation is declarative and lives with the other persistence
/// annotations; the behaviour it implies — which store, what key — is here, as
/// pure functions over the annotation. Keeping them apart is what lets the key
/// scheme be unit-tested without a database, a store, or the reflection
/// runtime: [TomFileReferenceKeys.generate] takes a clock and a name and
/// returns a string.
library;

import 'package:uuid/uuid.dart';

import '../file_storage/blob_store.dart';
import '../file_storage/blob_store_registry.dart';
import 'persistence_annotations.dart';

/// Resolves the store and the keys for a `@TomFileReference` column.
class TomFileReferenceKeys {
  TomFileReferenceKeys._();

  static const Uuid _uuid = Uuid();

  /// The blob store [reference] names, or the default store when it names none.
  ///
  /// Resolved per call rather than cached on the column metadata: the registry
  /// is populated at start-up and replaced wholesale by a test, and a column
  /// that captured a store at first use would keep serving the previous test's.
  static TomBlobStore storeFor(TomFileReference reference) =>
      reference.store == null
      ? TomBlobStoreInfo.defaultStore
      : TomBlobStoreInfo.storeNamed(reference.store!);

  /// Mints a fresh key for a blob stored under [reference].
  ///
  /// The shape is `<keyPrefix>/<yyyy>/<mm>/<uuid><.ext>`:
  ///
  /// - the **prefix** separates one column's blobs from another's, so a store
  ///   shared by several entities stays navigable and a lifecycle rule can be
  ///   written against a path;
  /// - the **date partition** bounds how many objects land in one directory —
  ///   which matters to a filesystem backend, and makes "everything from July"
  ///   expressible as a prefix on an object store;
  /// - the **UUID** makes the key collision-free without a round trip, so a
  ///   fresh upload never silently overwrites a live one, and unguessable, so
  ///   holding one key does not let a caller enumerate its neighbours;
  /// - the **extension** of the original [fileName] is carried over because it
  ///   costs nothing and makes a key readable to whoever is looking at the
  ///   bucket. It is decoration: the media type of record lives in the
  ///   descriptor, not in the key.
  ///
  /// [now] is injectable so a test can assert the exact partition.
  static String generate(
    TomFileReference reference, {
    String? fileName,
    DateTime? now,
  }) {
    // Checked separately from the joined key below, and first, because the two
    // faults have different fixes: the annotation's prefix is something a
    // developer wrote and can go and correct, whereas the key it appears in is
    // mostly a UUID nobody chose. Checked here rather than on the annotation
    // because that is a `const` constructor and cannot refuse a value.
    TomBlobStore.validateKeyPrefix(reference.keyPrefix);
    final stamp = now ?? DateTime.now();
    final month = stamp.month.toString().padLeft(2, '0');
    final segments = <String>[
      if (reference.keyPrefix.isNotEmpty) reference.keyPrefix,
      '${stamp.year}',
      month,
      '${_uuid.v4()}${extensionOf(fileName)}',
    ];
    // Still validated as a whole: the joined key can exceed the length limit
    // that neither part breaches on its own.
    return TomBlobStore.validateKey(segments.join('/'));
  }

  /// The lower-cased extension of [fileName] including the dot (`.pdf`), or the
  /// empty string when there is none worth carrying.
  ///
  /// Deliberately conservative: only a short, purely alphanumeric suffix is
  /// carried, because the extension is appended to a key whose grammar is
  /// narrow ([TomBlobStore.isValidKey]) and a "file name" arriving from a
  /// browser is caller-supplied text, not a vetted identifier.
  static String extensionOf(String? fileName) {
    if (fileName == null) return '';
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    final extension = fileName.substring(dot + 1).toLowerCase();
    if (extension.length > 12) return '';
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(extension)) return '';
    return '.$extension';
  }
}

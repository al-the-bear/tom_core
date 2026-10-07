/// Blob-store backends: what a configured file store of one `type` accepts as
/// settings, and how it builds the store from them.
///
/// A backend is a class, and its settings are its fields. That is what lets the
/// registry hold a configuration block to the backend it names: the keys a
/// backend reads are the fields it declares, so a key that names none is a
/// misspelling, reported at start-up — not a setting read by nobody, leaving
/// its default to stand in silence. It is the same rule, derived the same way,
/// that `TomDataSourceInfo` applies to a data-source driver.
library;

import 'dart:async';
import 'dart:io';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'aws_v4_signer.dart';
import 'blob_store.dart';
import 'database_blob_sql.dart';
import 'database_blob_store.dart';
import 'directory_blob_store.dart';
import 's3_blob_store.dart';

/// One blob-store backend: its settings, as fields, and the store they build.
///
/// The registry creates a fresh instance for every configured store, rejects
/// any settings key the instance declares no field for, binds the rest onto its
/// fields, and calls [build]. So a subclass declares each setting it reads as a
/// plain, non-`final`, public field with its default as the initialiser, and
/// carries `@tomReflector` — the fields are found and written through
/// reflection, which is why an application registering its own backend has to
/// regenerate its reflection before the backend can be configured.
///
/// Anything that is not a setting — an HTTP client, a credential provider — is
/// a constructor argument, captured by the factory handed to
/// `TomBlobStoreInfo.registerBackend`:
///
/// ```dart
/// TomBlobStoreInfo.registerBackend('gcs', () => GcsBackend(httpClient));
/// ```
abstract class TomBlobStoreBackend {
  /// Builds the store configured as [name] from this backend's bound fields.
  ///
  /// A required setting the configuration did not supply is reported here,
  /// with [missingSetting], because only the backend knows which of its fields
  /// may keep their defaults.
  FutureOr<TomBlobStore> build(String name);

  /// Returns [settings] with each value in the shape its field takes.
  ///
  /// Called before the settings are bound. The default changes nothing; a
  /// backend with an `int` setting overrides it to accept the string a
  /// configuration produces when the number comes from an environment
  /// substitution (`chunkSize: ${CHUNK_SIZE:65536}`), which binding alone would
  /// refuse.
  Map<String, dynamic> normalize(Map<String, dynamic> settings) => settings;

  /// The error a [build] raises for a required [setting] left unset in the
  /// configuration of store [store].
  static TomStorageException missingSetting(String store, String setting) =>
      TomStorageException(
        'storage.registry.missing_setting',
        'A required file-store setting is missing.',
        parameters: {'store': store, 'setting': setting},
      );

  /// [settings] with the value under each of [keys] parsed to an `int` when it
  /// arrived as a string holding one.
  ///
  /// A string that does not parse is left as it is, so binding refuses it and
  /// the refusal names the key.
  static Map<String, dynamic> parseInts(
    Map<String, dynamic> settings,
    Iterable<String> keys,
  ) {
    final result = Map<String, dynamic>.of(settings);
    for (final key in keys) {
      final raw = result[key];
      if (raw is String) {
        final parsed = int.tryParse(raw.trim());
        if (parsed != null) result[key] = parsed;
      }
    }
    return result;
  }
}

/// The `memory` backend: a [TomMemoryBlobStore], which takes no settings.
@tomReflector
class TomMemoryBlobStoreBackend extends TomBlobStoreBackend {
  @override
  TomBlobStore build(String name) => TomMemoryBlobStore();
}

/// The `directory` backend: a [TomDirectoryBlobStore] under [root].
@tomReflector
class TomDirectoryBlobStoreBackend extends TomBlobStoreBackend {
  /// The directory the store keeps its files in. Required.
  String root = '';

  @override
  TomBlobStore build(String name) {
    if (root.isEmpty) throw TomBlobStoreBackend.missingSetting(name, 'root');
    return TomDirectoryBlobStore(Directory(root));
  }
}

/// The `database` backend: a [TomDatabaseBlobStore] over a registered data
/// source.
@tomReflector
class TomDatabaseBlobStoreBackend extends TomBlobStoreBackend {
  /// The registered data source the two tables live in. Required.
  String datasource = '';

  /// The table holding one manifest row per blob.
  String manifestTable = defaultBlobManifestTable;

  /// The table holding a blob's chunks.
  String chunkTable = defaultBlobChunkTable;

  /// The size of one stored chunk, in raw bytes.
  int chunkSize = TomDatabaseBlobStore.defaultChunkSize;

  /// Whether the store creates its two tables when they are missing. `false`
  /// where a migration owns the schema.
  bool createSchema = true;

  @override
  Map<String, dynamic> normalize(Map<String, dynamic> settings) =>
      TomBlobStoreBackend.parseInts(settings, const ['chunkSize']);

  @override
  TomBlobStore build(String name) {
    if (datasource.isEmpty) {
      throw TomBlobStoreBackend.missingSetting(name, 'datasource');
    }
    return TomDatabaseBlobStore.named(
      datasource,
      manifestTable: manifestTable,
      chunkTable: chunkTable,
      chunkSize: chunkSize,
      createSchema: createSchema,
    );
  }
}

/// The `s3` backend: a [TomS3BlobStore] against any SigV4-compatible object
/// store.
@tomReflector
class TomS3BlobStoreBackend extends TomBlobStoreBackend {
  /// The service endpoint, e.g. `https://s3.eu-central-1.amazonaws.com`.
  /// Required.
  String endpoint = '';

  /// The bucket the store writes to. Required.
  String bucket = '';

  /// The signing region. Required.
  String region = '';

  /// The access key id. Required.
  String accessKeyId = '';

  /// The secret access key — secret-bearing. Required.
  String secretAccessKey = '';

  /// The session token of temporary credentials, or `null` for long-lived
  /// ones. Secret-bearing.
  String? sessionToken;

  /// Whether the bucket is addressed in the path rather than the host name.
  /// `true` suits MinIO and most S3-compatible stores.
  bool pathStyle = true;

  /// The multipart part size in bytes; an upload larger than one part is
  /// sent in parts of this size.
  int partSize = TomS3BlobStore.defaultPartSize;

  /// A prefix joined in front of every key, so several stores can share one
  /// bucket. `null` for none.
  String? keyPrefix;

  @override
  Map<String, dynamic> normalize(Map<String, dynamic> settings) =>
      TomBlobStoreBackend.parseInts(settings, const ['partSize']);

  @override
  TomBlobStore build(String name) {
    for (final (setting, value) in [
      ('endpoint', endpoint),
      ('bucket', bucket),
      ('region', region),
      ('accessKeyId', accessKeyId),
      ('secretAccessKey', secretAccessKey),
    ]) {
      if (value.isEmpty)
        throw TomBlobStoreBackend.missingSetting(name, setting);
    }
    return TomS3BlobStore(
      endpoint: Uri.parse(endpoint),
      bucket: bucket,
      region: region,
      credentials: TomAwsCredentials(
        accessKeyId: accessKeyId,
        secretAccessKey: secretAccessKey,
        sessionToken: sessionToken,
      ),
      pathStyle: pathStyle,
      partSize: partSize,
      keyPrefix: keyPrefix,
    );
  }
}

/// Named, configured blob stores — the registry an application resolves a
/// store out of, and the configuration block that fills it.
///
/// Deliberately the same shape as `TomDataSourceInfo`: a map of named entries,
/// each a `type` plus that type's settings, built once at start-up from the
/// configuration and looked up by name thereafter. An application that already
/// knows how to configure a data source knows how to configure a file store.
///
/// ## Where it differs, and why
///
/// A data-source *driver* is discovered by scanning reflection metadata for
/// `@TomDatasourceDriver`. A blob-store **backend** is registered explicitly,
/// with [TomBlobStoreInfo.registerBackend]. The difference is not an oversight:
///
/// - the set of database drivers is small, fixed, and shipped with the
///   framework, whereas a blob backend is routinely the deployment's own — a
///   corporate object store, a content-addressed archive, a test double;
/// - a factory is a closure, so a backend can capture whatever it needs
///   (a configured HTTP client, an existing credential provider) instead of
///   being restricted to a no-argument constructor plus a settings map; and
///   most concretely,
/// - the annotation route needs the application to regenerate its reflection
///   before a new backend is visible, which is a build step in the way of a
///   one-line registration.
///
/// The four built-ins register themselves, so a configuration naming
/// `database`, `directory`, `memory` or `s3` needs no code at all.
library;

import 'dart:async';
import 'dart:io';

import 'aws_v4_signer.dart';
import 'blob_store.dart';
import 'database_blob_store.dart';
import 'directory_blob_store.dart';
import 's3_blob_store.dart';

/// Builds a store of one backend type from its configured [settings].
typedef TomBlobStoreFactory =
    FutureOr<TomBlobStore> Function(String name, Map<String, dynamic> settings);

/// The process-wide registry of named, configured blob stores.
class TomBlobStoreInfo {
  /// Creates an (unopened) registry entry from [name] and [settings].
  TomBlobStoreInfo(this.name, this.settings);

  /// The registry key / logical name of this store.
  final String name;

  /// The raw configuration for this store.
  final Map<String, dynamic> settings;

  late TomBlobStore _store;

  /// The live store.
  TomBlobStore get store => _store;

  /// The backend type, from `settings['type']`.
  String get type => '${settings['type'] ?? ''}';

  /// All registered stores, keyed by name.
  static final Map<String, TomBlobStoreInfo> stores = {};

  /// The name [defaultStore] resolves to, or `null` when none is nominated.
  static String? defaultStoreName;

  static final Map<String, TomBlobStoreFactory> _backends = {
    'memory': (name, settings) => TomMemoryBlobStore(),
    'directory': _directoryBackend,
    'database': _databaseBackend,
    's3': _s3Backend,
  };

  /// Registers [factory] as the builder for backend [type], replacing any
  /// previous registration of the same name.
  ///
  /// Call before [initializeBlobStores]; a type the registry does not know when
  /// the configuration is read is a start-up failure, not a lazy one.
  static void registerBackend(String type, TomBlobStoreFactory factory) {
    _backends[type] = factory;
  }

  /// The backend type names currently registered.
  static Iterable<String> get backendTypes => _backends.keys;

  /// Returns the registered info for [name], or `null` if none.
  static TomBlobStoreInfo? getBlobStoreInfo(String name) => stores[name];

  /// The store registered as [name].
  ///
  /// Throws `storage.registry.unknown_store` when there is none — a typo in a
  /// `@TomFileReference(store: …)` or an unconfigured deployment, both of which
  /// are better reported than silently written somewhere else.
  static TomBlobStore storeNamed(String name) {
    final info = stores[name];
    if (info == null) {
      throw TomStorageException(
        'storage.registry.unknown_store',
        'No file store is configured under that name.',
        parameters: {'store': name, 'configured': stores.keys.toList()},
      );
    }
    return info.store;
  }

  /// The store to use when nothing names one.
  ///
  /// Throws `storage.registry.no_default_store` when no default was nominated.
  static TomBlobStore get defaultStore {
    final name = defaultStoreName;
    if (name == null) {
      throw TomStorageException(
        'storage.registry.no_default_store',
        'This server has no default file store configured.',
        parameters: {'configured': stores.keys.toList()},
      );
    }
    return storeNamed(name);
  }

  /// Whether a default store is available.
  static bool get hasDefaultStore =>
      defaultStoreName != null && stores.containsKey(defaultStoreName);

  /// Builds and registers a store for every map-valued entry of
  /// [configuration], returning the number registered.
  ///
  /// Each entry carries a `type` naming a registered backend and that backend's
  /// settings. One entry may carry `default: true`; when exactly one store is
  /// configured it becomes the default without saying so, because a server with
  /// one place to put files has no ambiguity to resolve.
  ///
  /// Keys are read defensively for the same reason [TomDataSourceInfo] reads
  /// them defensively: configuration decoded from YAML arrives as a `YamlMap`
  /// (`Map<dynamic, dynamic>`), which no reified `Map<String, Object>` check
  /// matches.
  static Future<int> initializeBlobStores(
    Map<String, dynamic> configuration,
  ) async {
    var count = 0;
    for (final entry in configuration.entries) {
      if (entry.value is! Map) continue;
      final raw = entry.value as Map;
      final settings = <String, dynamic>{
        for (final e in raw.entries) '${e.key}': e.value,
      };
      final info = TomBlobStoreInfo(entry.key, settings);
      await info.open();
      if (settings['default'] == true) defaultStoreName = entry.key;
      count++;
    }
    if (defaultStoreName == null && stores.length == 1) {
      defaultStoreName = stores.keys.first;
    }
    return count;
  }

  /// Registers a ready-made [store] under [name] — the seam a test, or an
  /// application that builds its store in code, uses instead of configuration.
  static TomBlobStoreInfo register(
    String name,
    TomBlobStore store, {
    bool asDefault = false,
  }) {
    final info = TomBlobStoreInfo(name, <String, dynamic>{'type': 'provided'});
    info._store = store;
    stores[name] = info;
    if (asDefault) defaultStoreName = name;
    return info;
  }

  /// Closes every registered store and empties the registry.
  static Future<void> closeAll() async {
    for (final info in stores.values) {
      await info.store.close();
    }
    stores.clear();
    defaultStoreName = null;
  }

  /// Builds this entry's store from its [settings] and registers it.
  Future<void> open() async {
    final factory = _backends[type];
    if (factory == null) {
      throw TomStorageException(
        'storage.registry.unknown_backend',
        'The configured file-store backend type is not registered.',
        parameters: {
          'store': name,
          'type': type,
          'known': _backends.keys.toList(),
        },
      );
    }
    _store = await factory(name, settings);
    stores[name] = this;
  }

  static TomBlobStore _directoryBackend(
    String name,
    Map<String, dynamic> settings,
  ) {
    final root = settings['root'];
    if (root is! String || root.isEmpty) {
      throw _missing(name, 'root');
    }
    return TomDirectoryBlobStore(Directory(root));
  }

  static TomBlobStore _databaseBackend(
    String name,
    Map<String, dynamic> settings,
  ) {
    final datasource = settings['datasource'];
    if (datasource is! String || datasource.isEmpty) {
      throw _missing(name, 'datasource');
    }
    return TomDatabaseBlobStore.named(
      datasource,
      manifestTable: '${settings['manifestTable'] ?? 'tom_blob'}',
      chunkTable: '${settings['chunkTable'] ?? 'tom_blob_chunk'}',
      chunkSize: _asInt(settings['chunkSize']) ?? 256 * 1024,
      createSchema: settings['createSchema'] != false,
    );
  }

  static TomBlobStore _s3Backend(String name, Map<String, dynamic> settings) {
    String required(String key) {
      final value = settings[key];
      if (value is! String || value.isEmpty) throw _missing(name, key);
      return value;
    }

    return TomS3BlobStore(
      endpoint: Uri.parse(required('endpoint')),
      bucket: required('bucket'),
      region: required('region'),
      credentials: TomAwsCredentials(
        accessKeyId: required('accessKeyId'),
        secretAccessKey: required('secretAccessKey'),
        sessionToken: settings['sessionToken'] as String?,
      ),
      pathStyle: settings['pathStyle'] != false,
      partSize: _asInt(settings['partSize']) ?? 8 * 1024 * 1024,
      keyPrefix: settings['keyPrefix'] as String?,
    );
  }

  static int? _asInt(Object? raw) => raw is int
      ? raw
      : raw is String
      ? int.tryParse(raw.trim())
      : null;

  static TomStorageException _missing(String store, String setting) =>
      TomStorageException(
        'storage.registry.missing_setting',
        'A required file-store setting is missing.',
        parameters: {'store': store, 'setting': setting},
      );

  @override
  String toString() => 'TomBlobStoreInfo $name $type $_store';
}

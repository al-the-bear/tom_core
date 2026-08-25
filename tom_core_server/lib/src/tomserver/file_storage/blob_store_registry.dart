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
///
/// A store already in hand takes the same route by the shortest path:
/// [TomBlobStoreInfo.register] gives its entry a factory that closes over the
/// instance. Nothing about such an entry is special-cased — it is the closure
/// argument carried to its limit.
library;

import 'dart:async';
import 'dart:io';

import 'aws_v4_signer.dart';
import 'blob_store.dart';
import 'database_blob_sql.dart';
import 'database_blob_store.dart';
import 'directory_blob_store.dart';
import 's3_blob_store.dart';

/// Builds a store of one backend type from its configured [settings].
typedef TomBlobStoreFactory =
    FutureOr<TomBlobStore> Function(String name, Map<String, dynamic> settings);

/// The process-wide registry of named, configured blob stores.
class TomBlobStoreInfo {
  /// Creates an (unopened) registry entry from [name] and [settings].
  ///
  /// [factory] builds the store when [open] is called. When it is null — the
  /// configured case — the backend named by `settings['type']` is looked up
  /// among the registered backends instead. Passing one is how a store that no
  /// settings map could describe still gets an entry that can build itself;
  /// see [register], which passes a factory closing over the instance it was
  /// handed.
  TomBlobStoreInfo(this.name, this.settings, {TomBlobStoreFactory? factory})
    : _factory = factory;

  /// The registry key / logical name of this store.
  final String name;

  /// The raw configuration for this store.
  final Map<String, dynamic> settings;

  /// This entry's own builder, when it has one; see the constructor.
  final TomBlobStoreFactory? _factory;

  late TomBlobStore _store;

  /// The live store.
  TomBlobStore get store => _store;

  /// The backend type, from `settings['type']`.
  String get type => '${settings['type'] ?? ''}';

  /// The [type] recorded for a store handed over as an instance.
  ///
  /// Deliberately *not* a registered backend: it names how the store arrived
  /// rather than a way to build one, and there is no instance in a YAML file
  /// to hand over. A configuration naming it fails like any other unknown
  /// type, and [backendTypes] does not list it.
  static const String providedType = 'provided';

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
  /// settings. One entry may carry `default: true`; when [configuration] names
  /// exactly one store it becomes the default without saying so, because a
  /// server with one place to put files has no ambiguity to resolve.
  ///
  /// That count is over the entries **this call** registered, not over
  /// [stores]. The two differ whenever an application built a store in code
  /// before reading its configuration — a scratch area, a test double — and it
  /// is the configuration that the rule is about: a deployment naming one place
  /// to put files should not have to say `default: true` because the process
  /// happens to hold another store it never mentioned.
  ///
  /// Only ever fills a default that is still unset, so it cannot overturn an
  /// [register] that passed `asDefault`. That is a statement and this is an
  /// inference drawn when nothing was stated. A `default: true` *in this
  /// configuration* does overturn it, being a statement of its own and a later
  /// one.
  ///
  /// Keys are read defensively for the same reason [TomDataSourceInfo] reads
  /// them defensively: configuration decoded from YAML arrives as a `YamlMap`
  /// (`Map<dynamic, dynamic>`), which no reified `Map<String, Object>` check
  /// matches.
  static Future<int> initializeBlobStores(
    Map<String, dynamic> configuration,
  ) async {
    final registered = <String>[];
    for (final entry in configuration.entries) {
      if (entry.value is! Map) continue;
      final raw = entry.value as Map;
      final settings = <String, dynamic>{
        for (final e in raw.entries) '${e.key}': e.value,
      };
      final info = TomBlobStoreInfo(entry.key, settings);
      await info.open();
      if (settings['default'] == true) defaultStoreName = entry.key;
      registered.add(entry.key);
    }
    if (defaultStoreName == null && registered.length == 1) {
      defaultStoreName = registered.single;
    }
    return registered.length;
  }

  /// Registers a ready-made [store] under [name] — the seam a test, or an
  /// application that builds its store in code, uses instead of configuration.
  ///
  /// The entry records [providedType] and carries a factory closing over
  /// [store], which is the same trick the module argues for above: a factory
  /// is a closure, so it can capture what no settings map could carry. The
  /// entry is therefore buildable like any other, and [open] on it — after a
  /// [closeAll], say — hands back the store it was given. That is the only
  /// honest answer, since the registry cannot rebuild an instance it did not
  /// build; `close()` is idempotent by contract, so the store is usable and
  /// not merely present.
  static TomBlobStoreInfo register(
    String name,
    TomBlobStore store, {
    bool asDefault = false,
  }) {
    final info = TomBlobStoreInfo(
      name,
      <String, dynamic>{'type': providedType},
      factory: (_, _) => store,
    );
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

  /// Builds this entry's store and registers it.
  ///
  /// From the entry's own factory when it has one, and otherwise from the
  /// backend its [type] names. An entry always has one or the other, so
  /// `unknown_backend` reports a configuration naming a backend nobody
  /// registered and never an entry that cannot describe itself.
  Future<void> open() async {
    final factory = _factory ?? _backends[type];
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
      manifestTable: '${settings['manifestTable'] ?? defaultBlobManifestTable}',
      chunkTable: '${settings['chunkTable'] ?? defaultBlobChunkTable}',
      chunkSize:
          _asInt(settings['chunkSize']) ?? TomDatabaseBlobStore.defaultChunkSize,
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
      partSize: _asInt(settings['partSize']) ?? TomS3BlobStore.defaultPartSize,
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

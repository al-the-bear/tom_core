/// Named, configured blob stores — the registry an application resolves a
/// store out of, and the configuration block that fills it.
///
/// Deliberately the same shape as `TomDataSourceInfo`: a map of named entries,
/// each a `type` plus that type's settings, built once at start-up from the
/// configuration and looked up by name thereafter. An application that already
/// knows how to configure a data source knows how to configure a file store.
///
/// The settings are held to the backend the same way, too. A backend is a
/// [TomBlobStoreBackend] class whose fields are its settings, so a key in a
/// store's block that names no field of its backend is rejected at start-up,
/// naming the key and the store — a misspelt `createSchma: false` is reported
/// rather than read by nobody while the default silently stands.
///
/// ## Where it differs, and why
///
/// A data-source *driver* is discovered by scanning reflection metadata for
/// `@TomDatasourceDriver`. A blob-store backend is registered explicitly, with
/// [TomBlobStoreInfo.registerBackend], as a factory returning a fresh backend.
/// A blob backend is routinely the deployment's own — a corporate object store,
/// a content-addressed archive, a test double — and the factory is where it
/// receives what is not a setting: a configured HTTP client, an existing
/// credential provider, captured by the closure and passed to the backend's
/// constructor.
///
/// The four built-ins register themselves, so a configuration naming
/// `database`, `directory`, `memory` or `s3` needs no code at all.
///
/// A store already in hand is registered with [TomBlobStoreInfo.register],
/// which records [TomBlobStoreInfo.providedType] and keeps the instance; there
/// is no backend behind it and no settings to check.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'blob_store.dart';
import 'blob_store_backends.dart';

/// Creates a fresh, unconfigured backend of one type; see
/// [TomBlobStoreInfo.registerBackend].
typedef TomBlobStoreBackendFactory = TomBlobStoreBackend Function();

/// The process-wide registry of named, configured blob stores.
class TomBlobStoreInfo {
  /// Creates an (unopened) registry entry from [name] and [settings].
  ///
  /// [open] builds the store with the backend `settings['type']` names.
  TomBlobStoreInfo(this.name, this.settings) : _provided = null;

  /// Creates an entry for a [store] already in hand; see [register].
  TomBlobStoreInfo._provided(this.name, TomBlobStore store)
    : settings = const <String, dynamic>{'type': providedType},
      _provided = store;

  /// The registry key / logical name of this store.
  final String name;

  /// The raw configuration for this store.
  final Map<String, dynamic> settings;

  /// The store handed to [register], which [open] hands back rather than
  /// building one; `null` for a configured entry.
  final TomBlobStore? _provided;

  /// The built store, or `null` while the entry is unopened.
  ///
  /// Nullable rather than `late`, because an entry spends a real interval
  /// without one and two things read it during that interval. A `late` field
  /// answers both with a `LateError`, which names the field and not the
  /// mistake — and one of the two is [toString], where throwing is worst of
  /// all: it fires in a debugger's variable pane and inside the error report
  /// about the failed [open] that left the entry this way.
  TomBlobStore? _store;

  /// Whether [open] has built this entry's store.
  ///
  /// The question [store] answers by throwing, asked without throwing — which
  /// is what a caller holding an entry of uncertain provenance needs.
  bool get isOpen => _store != null;

  /// The live store.
  ///
  /// Throws `storage.registry.store_not_opened` when [open] has not run or did
  /// not complete. An entry is constructed unopened and stays that way until
  /// [open] builds its store, and an [open] that throws — an unregistered
  /// backend, a missing setting — leaves one behind; [isOpen] answers the same
  /// question without throwing.
  TomBlobStore get store {
    final built = _store;
    if (built == null) {
      throw TomStorageException(
        'storage.registry.store_not_opened',
        'This file store has not been opened yet.',
        parameters: {'store': name, 'type': type},
      );
    }
    return built;
  }

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

  static final Map<String, TomBlobStoreBackendFactory> _backends = {
    'memory': TomMemoryBlobStoreBackend.new,
    'directory': TomDirectoryBlobStoreBackend.new,
    'database': TomDatabaseBlobStoreBackend.new,
    's3': TomS3BlobStoreBackend.new,
  };

  /// The [settings] keys this registry reads itself, and so does not pass on.
  ///
  /// `type` selects the backend and `default` nominates the default store;
  /// neither is a field of any backend. They are removed before the settings
  /// reach the backend, so every key it is handed has to bind.
  static const Set<String> registryKeys = {'type', 'default'};

  /// Registers [factory] as the creator of backend [type], replacing any
  /// previous registration of the same name.
  ///
  /// [factory] is called once per configured store of this type and must
  /// return a fresh backend, since the store's settings are bound onto it. The
  /// backend's class must carry `@tomReflector` and be in the application's
  /// generated reflection.
  ///
  /// Call before [initializeBlobStores]; a type the registry does not know when
  /// the configuration is read is a start-up failure, not a lazy one.
  static void registerBackend(String type, TomBlobStoreBackendFactory factory) {
    _backends[type] = factory;
  }

  /// Removes backend [type], answering whether one was registered.
  ///
  /// A built-in can be removed too; a configuration naming it then fails as
  /// `storage.registry.unknown_backend`, like any type nobody registered.
  static bool unregisterBackend(String type) => _backends.remove(type) != null;

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
  /// The entry records [providedType] and keeps [store], so [open] on it —
  /// after a [closeAll], say — hands back the store it was given. That is the
  /// only honest answer, since the registry cannot rebuild an instance it did
  /// not build; `close()` is idempotent by contract, so the store is usable and
  /// not merely present.
  static TomBlobStoreInfo register(
    String name,
    TomBlobStore store, {
    bool asDefault = false,
  }) {
    final info = TomBlobStoreInfo._provided(name, store);
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
  /// An entry made by [register] hands back the store it was given. A
  /// configured entry creates the backend its [type] names, strips
  /// [registryKeys] from [settings], rejects any remaining key the backend
  /// declares no field for (`storage.registry.unknown_setting`), binds the rest
  /// onto the backend's fields (`storage.registry.invalid_setting` for a value
  /// its field cannot take), and builds the store.
  Future<void> open() async {
    final provided = _provided;
    if (provided != null) {
      _store = provided;
      stores[name] = this;
      return;
    }
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
    final backend = factory();
    if (!tomReflectionInfo.canReflect(backend)) {
      throw TomStorageException(
        'storage.registry.backend_not_reflected',
        'The file-store backend class is not in this application\'s '
            'reflection, so its settings cannot be checked or bound.',
        parameters: {
          'store': name,
          'type': type,
          'backend': '${backend.runtimeType}',
        },
      );
    }
    final backendSettings = backend.normalize(<String, dynamic>{
      for (final e in settings.entries)
        if (!registryKeys.contains(e.key)) e.key: e.value,
    });
    _rejectUnknownSettings(backend, backendSettings);
    for (final entry in backendSettings.entries) {
      try {
        tomReflectionInfo.setValues(backend, {entry.key: entry.value});
      } catch (error) {
        throw TomStorageException(
          'storage.registry.invalid_setting',
          'A file-store setting has a value its backend cannot take.',
          parameters: {
            'store': name,
            'type': type,
            'setting': entry.key,
            'value': '${entry.value}',
          },
          rootException: error,
        );
      }
    }
    _store = await backend.build(name);
    stores[name] = this;
  }

  /// Throws when [backendSettings] carries a key [backend] declares no field
  /// for.
  ///
  /// A store's block is a file the operator wrote, for a backend whose field
  /// set is fixed — so a key that binds nothing is a mistake, and absorbed it
  /// would leave the default it meant to change standing with nothing to say
  /// so. Every offending key is named, not just the first: a block with two
  /// typos in it should not take two restarts to fix. The store's name is in
  /// the message because it is the half that tells an operator which block to
  /// open, and only the registry knows it.
  void _rejectUnknownSettings(
    TomBlobStoreBackend backend,
    Map<String, dynamic> backendSettings,
  ) {
    final unknown = tomReflectionInfo.unknownFields(backend, backendSettings);
    if (unknown.isEmpty) return;
    throw TomStorageException(
      'storage.registry.unknown_setting',
      "File store '$name' (type '$type') is configured with "
          "${unknown.length == 1 ? 'a setting' : 'settings'} "
          "${unknown.map((k) => "'$k'").join(', ')} that "
          "${unknown.length == 1 ? 'names' : 'name'} no field of "
          "${backend.runtimeType}. Check the spelling in the file-store "
          "configuration for '$name'.",
      parameters: {'store': name, 'type': type, 'keys': unknown},
    );
  }

  /// `TomBlobStoreInfo <name> <type> <store>`, with `<unopened>` in the store's
  /// place while the entry has none.
  ///
  /// The shape is constant either way. A rendering that dropped the third
  /// segment would be shorter in exactly the case a reader is trying to
  /// understand, and a `toString` that varies its arity is one a log filter has
  /// to know about.
  @override
  String toString() => 'TomBlobStoreInfo $name $type ${_store ?? '<unopened>'}';
}

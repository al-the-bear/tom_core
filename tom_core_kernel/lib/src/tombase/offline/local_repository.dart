/// The device-side repository: server entities read and changed on the device,
/// each change queued for the server.
library;

import 'dart:async';

import 'local_store.dart';
import 'sync_protocol.dart';

/// The device's copy of server entities over a [TomLocalStoreEngine]: each
/// entity with the server version it is based on, and the queue of changes
/// that have not reached the server yet.
///
/// [TomLocalRepository] writes through it and [TomSyncEngine] reconciles it
/// with the server; an application normally uses those two and not this.
class TomOfflineStore {
  /// The engine the data lives in.
  final TomLocalStoreEngine engine;

  final DateTime Function() _clock;

  /// The collection holding the queue of pending changes.
  static const String pendingCollection = '_tom_pending';

  /// The collection holding the framework's own values (counters, cursors).
  static const String metaCollection = '_tom_meta';

  /// Keeps the device's data in [engine].
  TomOfflineStore(this.engine, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Refuses (`offline.collection.reserved`) a collection name the framework
  /// keeps for itself.
  static void checkCollection(String collection) {
    if (collection.isEmpty || collection.startsWith('_tom')) {
      throw TomOfflineException(
        'offline.collection.reserved',
        "'$collection' is not a usable collection name.",
        parameters: {'collection': collection},
      );
    }
  }

  /// The entity [id] of [collection] with its server version, or `null`.
  Future<({Map<String, Object?> data, int? version})?> entity(
    String collection,
    String id,
  ) async {
    final stored = await engine.read(collection, id);
    return stored == null ? null : _entityOf(stored);
  }

  /// Every entity of [collection] with its version, by id.
  Future<Map<String, ({Map<String, Object?> data, int? version})>> entities(
    String collection,
  ) async => {
    for (final entry in (await engine.readAll(collection)).entries)
      entry.key: _entityOf(entry.value),
  };

  static ({Map<String, Object?> data, int? version}) _entityOf(
    Map<String, Object?> stored,
  ) => (
    data: (stored['data']! as Map).cast<String, Object?>(),
    version: stored['version'] as int?,
  );

  /// Stores [data] as entity [id] of [collection] at [version], without
  /// queueing anything — what the sync engine writes when the server spoke.
  Future<void> putEntity(
    String collection,
    String id,
    Map<String, Object?> data,
    int? version,
  ) => engine.write(collection, id, {'data': data, 'version': ?version});

  /// The queued changes, oldest first.
  Future<List<({String key, TomPendingChange change})>> pending() async {
    final entries = (await engine.readAll(pendingCollection)).entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return [
      for (final entry in entries)
        (key: entry.key, change: TomPendingChange.fromJson(entry.value)),
    ];
  }

  /// The queued change of entity [id] of [collection], or `null`.
  Future<({String key, TomPendingChange change})?> pendingFor(
    String collection,
    String id,
  ) async {
    for (final queued in await pending()) {
      if (queued.change.collection == collection && queued.change.id == id) {
        return queued;
      }
    }
    return null;
  }

  /// Replaces the queued change under [key].
  Future<void> replacePending(String key, TomPendingChange change) =>
      engine.write(pendingCollection, key, change.toJson());

  /// Removes the queued change under [key].
  Future<void> dropPending(String key) => engine.delete(pendingCollection, key);

  /// The value [name] of the framework's own values.
  Future<Object?> meta(String name) async =>
      (await engine.read(metaCollection, name))?['value'];

  /// Sets the framework value [name].
  Future<void> setMeta(String name, Object? value) =>
      engine.write(metaCollection, name, {'value': value});

  /// Saves [data] as entity [id] of [collection] on the device and queues the
  /// change. A change still queued for the same entity is replaced by this one
  /// and keeps its place and its base version — the server sees the latest
  /// state once, based on what it last gave the device.
  Future<void> save(String collection, String id, Map<String, Object?> data) =>
      engine.transaction(() async {
        final current = await entity(collection, id);
        await putEntity(collection, id, data, current?.version);
        await _queue(
          collection,
          id,
          TomChangeOperation.save,
          data,
          current?.version,
        );
      });

  /// Removes entity [id] of [collection] on the device and queues the
  /// deletion. An entity the server has never seen (no version) is simply
  /// forgotten: its queued creation goes, and nothing is sent. Answers
  /// whether the device had it.
  Future<bool> delete(String collection, String id) =>
      engine.transaction(() async {
        final current = await entity(collection, id);
        if (current == null) return false;
        await engine.delete(collection, id);
        if (current.version == null) {
          final queued = await pendingFor(collection, id);
          if (queued != null) await dropPending(queued.key);
        } else {
          await _queue(
            collection,
            id,
            TomChangeOperation.delete,
            null,
            current.version,
          );
        }
        return true;
      });

  Future<void> _queue(
    String collection,
    String id,
    TomChangeOperation operation,
    Map<String, Object?>? data,
    int? version,
  ) async {
    final queued = await pendingFor(collection, id);
    if (queued != null) {
      await replacePending(
        queued.key,
        TomPendingChange(
          changeId: queued.change.changeId,
          collection: collection,
          id: id,
          operation: operation,
          data: data,
          baseVersion: queued.change.baseVersion,
          queuedAt: _clock(),
        ),
      );
      return;
    }
    final next = ((await meta('pendingSequence') as int?) ?? 0) + 1;
    await setMeta('pendingSequence', next);
    final key = next.toString().padLeft(12, '0');
    await replacePending(
      key,
      TomPendingChange(
        changeId: 'change-$next',
        collection: collection,
        id: id,
        operation: operation,
        data: data,
        baseVersion: version,
        queuedAt: _clock(),
      ),
    );
  }
}

/// How a repository turns its entities into the JSON it stores, and back, and
/// which id an entity has.
class TomLocalEntityCodec<T> {
  /// The entity as JSON.
  final Map<String, Object?> Function(T entity) toJson;

  /// The entity from JSON.
  final T Function(Map<String, Object?> json) fromJson;

  /// The entity's id.
  final String Function(T entity) idOf;

  /// Creates a codec.
  const TomLocalEntityCodec({
    required this.toJson,
    required this.fromJson,
    required this.idOf,
  });
}

/// The device-side counterpart of the server's `TomRepository`: the same
/// reads and writes, against the device's copy, every write queued for the
/// server.
///
/// Reads answer what the device holds, its own unsynced changes included.
/// Ids are strings — an entity's server key in its string form.
class TomLocalRepository<T extends Object> {
  /// The device's store.
  final TomOfflineStore store;

  /// The collection the entities live in — the server's name for the entity
  /// kind, which pushes and pulls use too.
  final String collection;

  /// How entities become JSON.
  final TomLocalEntityCodec<T> codec;

  /// Creates a repository; refuses a reserved [collection] name.
  TomLocalRepository({
    required this.store,
    required this.collection,
    required this.codec,
  }) {
    TomOfflineStore.checkCollection(collection);
  }

  /// The entity [id], or `null`.
  Future<T?> findById(String id) async {
    final stored = await store.entity(collection, id);
    return stored == null ? null : codec.fromJson(stored.data);
  }

  /// Every entity, ordered by id.
  Future<List<T>> findAll() async {
    final all = await store.entities(collection);
    final ids = all.keys.toList()..sort();
    return [for (final id in ids) codec.fromJson(all[id]!.data)];
  }

  /// The entities with [ids] that the device holds, in the order asked.
  Future<List<T>> findAllById(Iterable<String> ids) async => [
    for (final id in ids)
      if (await findById(id) case final entity?) entity,
  ];

  /// Whether the device holds every one of [ids].
  Future<bool> existsById(Iterable<String> ids) async {
    for (final id in ids) {
      if (await store.entity(collection, id) == null) return false;
    }
    return true;
  }

  /// How many entities the device holds.
  Future<int> count() async => (await store.entities(collection)).length;

  /// Saves [entity] on the device and queues it for the server; answers it.
  Future<T> save(T entity) async {
    await store.save(collection, codec.idOf(entity), codec.toJson(entity));
    return entity;
  }

  /// Saves every one of [entities], in one transaction.
  Future<List<T>> saveAll(Iterable<T> entities) =>
      store.engine.transaction(() async {
        for (final entity in entities) {
          await save(entity);
        }
        return entities.toList();
      });

  /// Deletes [entity].
  Future<void> delete(T entity) => deleteById(codec.idOf(entity));

  /// Deletes entity [id]; answers how many went (0 or 1).
  Future<int> deleteById(String id) async =>
      await store.delete(collection, id) ? 1 : 0;

  /// Deletes every one of [ids], in one transaction; answers how many went.
  Future<int> deleteAllById(Iterable<String> ids) =>
      store.engine.transaction(() async {
        var removed = 0;
        for (final id in ids) {
          removed += await deleteById(id);
        }
        return removed;
      });

  /// The server version entity [id] is based on — `null` for one the server
  /// has not seen.
  Future<int?> versionOf(String id) async =>
      (await store.entity(collection, id))?.version;

  /// Whether entity [id] has a change the server has not taken yet.
  Future<bool> hasPendingChange(String id) async =>
      await store.pendingFor(collection, id) != null;
}

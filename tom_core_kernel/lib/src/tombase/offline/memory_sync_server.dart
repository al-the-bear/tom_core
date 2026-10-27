/// The sync protocol's server side, in memory: the reference a server
/// endpoint follows, and the transport tests sync against.
library;

import 'dart:async';

import 'sync_protocol.dart';

/// A server holding entities with versions and numbering every change it
/// applies — the sync protocol's semantics, in memory.
///
/// A pushed change is applied only when the entity's version is the change's
/// base: a creation (no base) only when the server does not have the entity, a
/// save or deletion only when its version is the base. Otherwise the answer is
/// a conflict carrying what the server holds. [validate] may refuse a save's
/// data (a rejection). Every applied change — pushed, or made on the server
/// through [put] and [remove], as another client's would be — takes the next
/// number of its collection's change sequence, which is what [pull] reads.
class TomMemorySyncServer extends TomSyncTransport {
  final Map<String, Map<String, ({Map<String, Object?> data, int version})>>
  _entities = {};
  final Map<String, List<TomPulledChange>> _log = {};

  /// Refuses a save's data with a reason, or answers `null` to accept it.
  final String? Function(String collection, Map<String, Object?> data)?
  validate;

  /// How many pushes were received.
  int pushes = 0;

  /// When set, every push and pull fails with it — the network is down.
  Object? offline;

  /// Creates an empty server.
  TomMemorySyncServer({this.validate});

  /// Entity [id] of [collection] as the server holds it, or `null`.
  ({Map<String, Object?> data, int version})? entity(
    String collection,
    String id,
  ) => _entities[collection]?[id];

  /// Saves [data] as entity [id] on the server, as another client would.
  int put(String collection, String id, Map<String, Object?> data) {
    final version = (entity(collection, id)?.version ?? 0) + 1;
    (_entities[collection] ??= {})[id] = (
      data: Map.unmodifiable(data),
      version: version,
    );
    _record(collection, id, data, version);
    return version;
  }

  /// Deletes entity [id] on the server, as another client would.
  void remove(String collection, String id) {
    final current = _entities[collection]?.remove(id);
    if (current != null) _record(collection, id, null, current.version + 1);
  }

  void _record(
    String collection,
    String id,
    Map<String, Object?>? data,
    int version,
  ) {
    final log = _log[collection] ??= [];
    log.add(
      TomPulledChange(
        id: id,
        data: data == null ? null : Map.unmodifiable(data),
        version: version,
        sequence: log.length + 1,
      ),
    );
  }

  @override
  Future<List<TomPushResult>> push(List<TomPendingChange> changes) async {
    if (offline != null) throw offline!;
    pushes++;
    return [for (final change in changes) _apply(change)];
  }

  TomPushResult _apply(TomPendingChange change) {
    final current = entity(change.collection, change.id);
    if (current?.version != change.baseVersion) {
      return TomPushResult(
        changeId: change.changeId,
        outcome: TomPushOutcome.conflict,
        version: current?.version,
        serverData: current?.data,
      );
    }
    switch (change.operation) {
      case TomChangeOperation.save:
        final refusal = validate?.call(change.collection, change.data!);
        if (refusal != null) {
          return TomPushResult(
            changeId: change.changeId,
            outcome: TomPushOutcome.rejected,
            version: current?.version,
            serverData: current?.data,
            reason: refusal,
          );
        }
        return TomPushResult(
          changeId: change.changeId,
          outcome: TomPushOutcome.applied,
          version: put(change.collection, change.id, change.data!),
        );
      case TomChangeOperation.delete:
        remove(change.collection, change.id);
        return TomPushResult(
          changeId: change.changeId,
          outcome: TomPushOutcome.applied,
          version: current!.version + 1,
        );
    }
  }

  @override
  Future<TomPullBatch> pull(
    String collection,
    int since, {
    int limit = 500,
  }) async {
    if (offline != null) throw offline!;
    final after = [
      for (final change in _log[collection] ?? const <TomPulledChange>[])
        if (change.sequence > since) change,
    ];
    final batch = after.take(limit).toList();
    return TomPullBatch(
      changes: batch,
      cursor: batch.isEmpty ? since : batch.last.sequence,
      hasMore: after.length > batch.length,
    );
  }
}

/// The sync engine: brings the device's copy and the server into line —
/// pushing the queued changes, resolving conflicts, pulling what changed on
/// the server.
library;

import 'dart:async';
import 'dart:convert';

import 'local_repository.dart';
import 'local_store.dart';
import 'sync_protocol.dart';

/// A pushed change the server did not apply because it holds a newer version.
class TomSyncConflict {
  /// The device's change.
  final TomPendingChange change;

  /// The entity as the server holds it — `null` when the server deleted it.
  final Map<String, Object?>? serverData;

  /// The server's version — `null` when the server does not have the entity.
  final int? serverVersion;

  /// Creates a conflict.
  const TomSyncConflict({
    required this.change,
    required this.serverData,
    required this.serverVersion,
  });
}

/// What to do about a conflict.
sealed class TomConflictResolution {
  const TomConflictResolution();

  /// Take the server's entity and drop the device's change.
  static const TomConflictResolution keepServer = _KeepServer();

  /// Keep the device's change and push it again, based on the server's
  /// version — the device's state wins.
  static const TomConflictResolution keepLocal = _KeepLocal();

  /// Push [data] — a merge of the two — based on the server's version.
  const factory TomConflictResolution.merge(Map<String, Object?> data) = _Merge;
}

class _KeepServer extends TomConflictResolution {
  const _KeepServer();
}

class _KeepLocal extends TomConflictResolution {
  const _KeepLocal();
}

class _Merge extends TomConflictResolution {
  final Map<String, Object?> data;
  const _Merge(this.data);
}

/// Decides a conflict; the application's to supply.
typedef TomConflictResolver =
    FutureOr<TomConflictResolution> Function(TomSyncConflict conflict);

/// What one [TomSyncEngine.sync] did.
class TomSyncReport {
  /// The changes the server applied.
  final List<TomPendingChange> applied;

  /// The conflicts met, whatever was decided about them.
  final List<TomSyncConflict> conflicts;

  /// The device's changes dropped for the server's state: conflicts resolved
  /// as [TomConflictResolution.keepServer], and refusals.
  final List<TomPendingChange> discarded;

  /// The changes the server refused, with its reason.
  final List<({TomPendingChange change, String? reason})> rejected;

  /// How many server changes were pulled into the device's copy, by
  /// collection.
  final Map<String, int> pulled;

  /// Changes still queued after the sync — a conflict decided for the
  /// device's state that met another conflict on its second push.
  final int stillPending;

  /// Creates a report.
  TomSyncReport({
    required this.applied,
    required this.conflicts,
    required this.discarded,
    required this.rejected,
    required this.pulled,
    required this.stillPending,
  });
}

/// Brings a device's [TomOfflineStore] and the server into line.
///
/// A [sync] pushes the queued changes, oldest first, and handles each answer:
///
/// - **applied**: the device's entity takes the new version, the change leaves
///   the queue;
/// - **conflict**: [resolver] decides — keep the server's entity, keep the
///   device's (pushed again on the server's version), or a merge (pushed
///   again); the default keeps the server's and reports the dropped change
///   in [TomSyncReport.discarded];
/// - **rejected**: the device takes the server's entity back and the change is
///   reported.
///
/// Changes decided for the device's state are pushed again in the same sync,
/// up to [maxPushRounds] times; one still in conflict after that stays queued
/// for the next sync.
///
/// It then pulls, for each of [collections], the server's changes after the
/// cursor it saved last time, and writes them into the device's copy — except
/// for an entity with a change still queued, which the next push settles.
/// Everything a sync writes to the device happens in transactions of the
/// engine, so an interrupted sync leaves a consistent copy and the next one
/// carries on.
class TomSyncEngine {
  /// The device's store.
  final TomOfflineStore store;

  /// The way to the server.
  final TomSyncTransport transport;

  /// The collections pulled.
  final List<String> collections;

  /// Decides conflicts.
  final TomConflictResolver resolver;

  /// How many times one sync pushes a change again after a conflict.
  final int maxPushRounds;

  /// How many changes one pull asks for.
  final int pullLimit;

  Future<TomSyncReport>? _running;

  /// Creates the engine.
  TomSyncEngine({
    required this.store,
    required this.transport,
    required List<String> collections,
    TomConflictResolver? resolver,
    this.maxPushRounds = 3,
    this.pullLimit = 500,
  }) : collections = List.unmodifiable(collections),
       resolver = resolver ?? _keepServer {
    collections.forEach(TomOfflineStore.checkCollection);
  }

  static TomConflictResolution _keepServer(TomSyncConflict _) =>
      TomConflictResolution.keepServer;

  /// Pushes, then pulls. A sync asked for while one runs joins it.
  Future<TomSyncReport> sync() {
    final running = _running;
    if (running != null) return running;
    return _running = _sync().whenComplete(() => _running = null);
  }

  Future<TomSyncReport> _sync() async {
    final applied = <TomPendingChange>[];
    final conflicts = <TomSyncConflict>[];
    final discarded = <TomPendingChange>[];
    final rejected = <({TomPendingChange change, String? reason})>[];
    for (var round = 0; round < maxPushRounds; round++) {
      final queued = await store.pending();
      if (queued.isEmpty) break;
      final results = await _push([for (final q in queued) q.change]);
      var again = false;
      for (final entry in queued) {
        final change = entry.change;
        final result = results[change.changeId];
        if (result == null) continue; // not answered: stays queued
        switch (result.outcome) {
          case TomPushOutcome.applied:
            await store.engine.transaction(() async {
              final now = await store.pendingFor(change.collection, change.id);
              final changedSince =
                  now != null &&
                  (now.change.queuedAt != change.queuedAt ||
                      now.change.operation != change.operation ||
                      jsonEncode(now.change.data) != jsonEncode(change.data));
              if (change.operation == TomChangeOperation.save) {
                final current = await store.entity(
                  change.collection,
                  change.id,
                );
                if (current != null) {
                  await store.putEntity(
                    change.collection,
                    change.id,
                    current.data,
                    result.version,
                  );
                }
              }
              if (changedSince) {
                // Changed again on the device while the push was out: that
                // newer change stays queued, now based on the version the
                // server just answered.
                await store.replacePending(
                  now.key,
                  now.change.rebased(result.version),
                );
              } else {
                await store.dropPending(entry.key);
              }
            });
            applied.add(change);
          case TomPushOutcome.rejected:
            await store.engine.transaction(() async {
              await _takeServer(change, result.serverData, result.version);
              await store.dropPending(entry.key);
            });
            rejected.add((change: change, reason: result.reason));
            discarded.add(change);
          case TomPushOutcome.conflict:
            final conflict = TomSyncConflict(
              change: change,
              serverData: result.serverData,
              serverVersion: result.version,
            );
            conflicts.add(conflict);
            final decision = await resolver(conflict);
            await store.engine.transaction(() async {
              switch (decision) {
                case _KeepServer():
                  await _takeServer(change, result.serverData, result.version);
                  await store.dropPending(entry.key);
                  discarded.add(change);
                case _KeepLocal():
                  await store.replacePending(
                    entry.key,
                    change.rebased(result.version),
                  );
                  again = true;
                case _Merge(:final data):
                  await store.putEntity(
                    change.collection,
                    change.id,
                    data,
                    result.version,
                  );
                  await store.replacePending(
                    entry.key,
                    change.rebased(result.version, data: data),
                  );
                  again = true;
              }
            });
        }
      }
      if (!again) break;
    }

    final pulled = <String, int>{};
    for (final collection in collections) {
      pulled[collection] = await _pull(collection);
    }
    return TomSyncReport(
      applied: applied,
      conflicts: conflicts,
      discarded: discarded,
      rejected: rejected,
      pulled: pulled,
      stillPending: (await store.pending()).length,
    );
  }

  Future<Map<String, TomPushResult>> _push(
    List<TomPendingChange> changes,
  ) async {
    final List<TomPushResult> results;
    try {
      results = await transport.push(changes);
    } on TomOfflineException {
      rethrow;
    } on Object catch (error, stack) {
      throw TomOfflineException(
        'offline.sync.transport_failed',
        'The changes could not be sent to the server.',
        parameters: {'changes': changes.length},
        rootException: error,
        stack: stack,
      );
    }
    return {for (final result in results) result.changeId: result};
  }

  /// Puts the server's entity (or its absence) in place of the device's.
  Future<void> _takeServer(
    TomPendingChange change,
    Map<String, Object?>? serverData,
    int? serverVersion,
  ) async {
    if (serverData == null) {
      await store.engine.delete(change.collection, change.id);
    } else {
      await store.putEntity(
        change.collection,
        change.id,
        serverData,
        serverVersion,
      );
    }
  }

  Future<int> _pull(String collection) async {
    var count = 0;
    while (true) {
      final cursor = (await store.meta('cursor:$collection') as int?) ?? 0;
      final TomPullBatch batch;
      try {
        batch = await transport.pull(collection, cursor, limit: pullLimit);
      } on Object catch (error, stack) {
        throw TomOfflineException(
          'offline.sync.transport_failed',
          'The server changes of $collection could not be fetched.',
          parameters: {'collection': collection, 'since': cursor},
          rootException: error,
          stack: stack,
        );
      }
      await store.engine.transaction(() async {
        for (final change in batch.changes) {
          if (await store.pendingFor(collection, change.id) != null) continue;
          if (change.deleted) {
            await store.engine.delete(collection, change.id);
          } else {
            await store.putEntity(
              collection,
              change.id,
              change.data!,
              change.version,
            );
          }
          count++;
        }
        await store.setMeta('cursor:$collection', batch.cursor);
      });
      if (!batch.hasMore || batch.changes.isEmpty) return count;
    }
  }
}

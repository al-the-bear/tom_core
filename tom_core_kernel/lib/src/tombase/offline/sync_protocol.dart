/// The sync protocol between a device and the server: what a device pushes,
/// what the server answers, what a device pulls.
///
/// The server is authoritative. A device queues each local change with the
/// entity version it was based on; the server applies it under optimistic
/// locking — only when its stored version is still that base — and answers
/// the new version, or the conflict with what it holds. Pulls are incremental:
/// the server numbers every change it applies (a change sequence per
/// collection), and a device asks for the changes after the last number it
/// saw.
library;

import 'dart:async';

/// What a pending change does.
enum TomChangeOperation {
  /// Create or replace the entity with the change's data.
  save,

  /// Remove the entity.
  delete,
}

/// A local change waiting to reach the server.
class TomPendingChange {
  /// Identifies the change; the server answers by it.
  final String changeId;

  /// The collection (entity kind) changed.
  final String collection;

  /// The entity's id.
  final String id;

  /// What the change does.
  final TomChangeOperation operation;

  /// The entity as the device holds it, for [TomChangeOperation.save].
  final Map<String, Object?>? data;

  /// The version the change was based on — the server's version when the
  /// device last had it — or `null` for an entity the server has never seen.
  final int? baseVersion;

  /// When the change was made.
  final DateTime queuedAt;

  /// Creates a change.
  TomPendingChange({
    required this.changeId,
    required this.collection,
    required this.id,
    required this.operation,
    Map<String, Object?>? data,
    this.baseVersion,
    required this.queuedAt,
  }) : data = data == null ? null : Map.unmodifiable(data);

  /// The change as JSON (how it is queued, and how it travels).
  Map<String, Object?> toJson() => {
    'changeId': changeId,
    'collection': collection,
    'id': id,
    'operation': operation.name,
    'data': ?data,
    'baseVersion': ?baseVersion,
    'queuedAt': queuedAt.toUtc().toIso8601String(),
  };

  /// Reads [toJson]'s form.
  factory TomPendingChange.fromJson(Map<String, Object?> json) =>
      TomPendingChange(
        changeId: json['changeId']! as String,
        collection: json['collection']! as String,
        id: json['id']! as String,
        operation: TomChangeOperation.values.byName(
          json['operation']! as String,
        ),
        data: (json['data'] as Map?)?.cast<String, Object?>(),
        baseVersion: json['baseVersion'] as int?,
        queuedAt: DateTime.parse(json['queuedAt']! as String),
      );

  /// This change based on [baseVersion], carrying [data] when given.
  TomPendingChange rebased(int? baseVersion, {Map<String, Object?>? data}) =>
      TomPendingChange(
        changeId: changeId,
        collection: collection,
        id: id,
        operation: operation,
        data: data ?? this.data,
        baseVersion: baseVersion,
        queuedAt: queuedAt,
      );

  @override
  String toString() =>
      'TomPendingChange(${operation.name} $collection/$id @${baseVersion ?? '-'})';
}

/// How the server took a pushed change.
enum TomPushOutcome {
  /// Applied; [TomPushResult.version] is the entity's version now.
  applied,

  /// Not applied: the server's version is not the change's base. The result
  /// carries what the server holds.
  conflict,

  /// Not applied, and pushing it again will not help (the server refused the
  /// data). The result carries what the server holds.
  rejected,
}

/// The server's answer to one pushed change.
class TomPushResult {
  /// The change answered.
  final String changeId;

  /// How the server took it.
  final TomPushOutcome outcome;

  /// For [TomPushOutcome.applied], the new version; otherwise the server's
  /// current version, `null` when the server does not have the entity.
  final int? version;

  /// For a conflict or a refusal, the entity as the server holds it — `null`
  /// when the server does not have it (it was deleted, or never created).
  final Map<String, Object?>? serverData;

  /// For [TomPushOutcome.rejected], why.
  final String? reason;

  /// Creates a result.
  const TomPushResult({
    required this.changeId,
    required this.outcome,
    this.version,
    this.serverData,
    this.reason,
  });
}

/// One change the server applied, as a device pulls it.
class TomPulledChange {
  /// The entity's id.
  final String id;

  /// The entity now, or `null` when the change deleted it.
  final Map<String, Object?>? data;

  /// The entity's version after the change.
  final int version;

  /// The change's number in the collection's change sequence.
  final int sequence;

  /// Creates a pulled change.
  const TomPulledChange({
    required this.id,
    required this.data,
    required this.version,
    required this.sequence,
  });

  /// Whether the change deleted the entity.
  bool get deleted => data == null;
}

/// The answer to a pull: the changes after the cursor asked for, in sequence
/// order.
class TomPullBatch {
  /// The changes.
  final List<TomPulledChange> changes;

  /// The cursor to ask from next time: the last sequence number included.
  final int cursor;

  /// Whether more changes follow this batch.
  final bool hasMore;

  /// Creates a batch.
  TomPullBatch({
    required List<TomPulledChange> changes,
    required this.cursor,
    this.hasMore = false,
  }) : changes = List.unmodifiable(changes);
}

/// How a device reaches the server's sync endpoint.
///
/// The framework defines the exchange; the transport is the wire (HTTP to the
/// server, or [TomMemorySyncServer] in a test).
abstract class TomSyncTransport {
  /// Creates a transport.
  const TomSyncTransport();

  /// Pushes [changes], in order; answers one result per change.
  Future<List<TomPushResult>> push(List<TomPendingChange> changes);

  /// The changes of [collection] after sequence number [since], at most
  /// [limit].
  Future<TomPullBatch> pull(String collection, int since, {int limit = 500});
}

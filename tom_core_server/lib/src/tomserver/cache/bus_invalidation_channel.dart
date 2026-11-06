/// Invalidations carried between nodes over a message bus, with a log that
/// remembers the revocations still in force.
library;

import 'dart:async';

import 'package:tom_core_message_bus/tom_core_message_bus.dart';

import '../authorization/authorization_cache.dart';
import 'cache_invalidation.dart';

/// Where invalidations are remembered, so a node starting later still applies
/// the revocations raised before it was there.
///
/// `TomSqlInvalidationChannel` is one — its table is the log — and
/// [TomMemoryInvalidationLog] keeps one in memory, for a single process and
/// for tests.
abstract interface class TomInvalidationLog {
  /// Remembers [invalidation].
  Future<void> record(TomCacheInvalidation invalidation);

  /// The principal revocations raised within the log's retention — the ones
  /// still in force — oldest first.
  Future<List<TomCacheInvalidation>> revocationsInForce();
}

/// A [TomInvalidationLog] in memory: what one process recorded, for
/// [retention].
class TomMemoryInvalidationLog implements TomInvalidationLog {
  /// A log keeping revocations for [retention]
  /// ([TomAuthorizationCache.revocationRetention] by default).
  TomMemoryInvalidationLog({Duration? retention, DateTime Function()? clock})
    : retention = retention ?? TomAuthorizationCache.revocationRetention,
      _clock = clock ?? DateTime.now;

  /// How long a revocation is kept.
  final Duration retention;

  final DateTime Function() _clock;
  final List<TomCacheInvalidation> _revocations = [];

  @override
  Future<void> record(TomCacheInvalidation invalidation) async {
    if (invalidation.kind == TomInvalidationKind.principal) {
      _revocations.add(invalidation);
    }
  }

  @override
  Future<List<TomCacheInvalidation>> revocationsInForce() async {
    final cutoff = _clock().toUtc().subtract(retention);
    _revocations.removeWhere((r) => r.at.isBefore(cutoff));
    return List.of(_revocations);
  }
}

/// The bus topic invalidations travel on unless a channel names another.
const String tomInvalidationTopic = 'tom.cache.invalidation';

/// A [TomInvalidationChannel] over a [TomMessageBus]: near-immediate eviction
/// on every node, for a deployment that runs a broker.
///
/// [publish] records the invalidation in [log] and publishes it on [topic].
/// Every node subscribes to the topic with a consumer group of its own —
/// `tom-cache-invalidation-<node id>`, ephemeral — so every node receives
/// every invalidation (a fan-out, not a work queue), and a node that stops
/// leaves nothing behind on the broker. A node drops the invalidations it
/// raised itself.
///
/// On [start] the node subscribes first and then applies the revocations
/// still in force from [log], so a revocation raised while it was starting is
/// applied either way — twice at worst, which revocation tolerates. The log,
/// not the broker, is the memory: broker retention differs per broker, and the
/// log holds exactly the revocation window.
///
/// The staleness bound is the bus's delivery time, which the bus contract does
/// not promise; [stalenessBound] states the bound the deployment expects of its
/// broker (a second by default).
class TomBusInvalidationChannel implements TomInvalidationChannel {
  /// A channel publishing on [bus] and remembering in [log].
  ///
  /// [nodeId] is this node's id ([TomCacheInvalidator.nodeId] by default) —
  /// what tells its own invalidations from the others'.
  TomBusInvalidationChannel({
    required this.bus,
    required this.log,
    this.topic = tomInvalidationTopic,
    this.stalenessBound = const Duration(seconds: 1),
    String? nodeId,
  }) : _nodeId = nodeId;

  /// The bus invalidations travel on.
  final TomMessageBus bus;

  /// Where they are remembered.
  final TomInvalidationLog log;

  /// The topic they are published to.
  final String topic;

  /// The delivery time expected of the broker: the bus promises delivery at
  /// least once, not a latency.
  @override
  final Duration stalenessBound;

  final String? _nodeId;
  TomBusSubscription? _subscription;

  /// This node's id.
  String get nodeId => _nodeId ?? TomCacheInvalidator.nodeId;

  /// The consumer group of this node: its own, so every node gets every
  /// invalidation.
  String get group => 'tom-cache-invalidation-$nodeId';

  /// Whether the channel is subscribed.
  bool get isRunning => _subscription != null;

  @override
  Future<void> start(
    Future<void> Function(TomCacheInvalidation invalidation) deliver,
  ) async {
    await stop();
    _subscription = await bus.subscribe<Map<String, Object?>>(
      topic,
      group: group,
      ephemeral: true,
      handler: (delivery) async {
        final invalidation = invalidationFromJson(delivery.payload);
        if (invalidation.origin == nodeId) return;
        await deliver(invalidation);
      },
    );
    for (final revocation in await log.revocationsInForce()) {
      if (revocation.origin != nodeId) await deliver(revocation);
    }
  }

  @override
  Future<void> publish(TomCacheInvalidation invalidation) async {
    await log.record(invalidation);
    await bus.publish<Map<String, Object?>>(
      topic,
      invalidationToJson(invalidation),
    );
  }

  @override
  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  /// [invalidation] as the JSON a bus message carries.
  static Map<String, Object?> invalidationToJson(
    TomCacheInvalidation invalidation,
  ) => {
    'kind': invalidation.kind.name,
    'target': invalidation.target,
    'key': ?invalidation.key,
    'at': invalidation.at.toUtc().toIso8601String(),
    'origin': invalidation.origin,
  };

  /// The invalidation [invalidationToJson] wrote.
  static TomCacheInvalidation invalidationFromJson(Map<String, Object?> json) =>
      TomCacheInvalidation.fromParts(
        kind: json['kind']! as String,
        target: json['target']! as String,
        key: json['key'] as String?,
        at: DateTime.parse(json['at']! as String),
        origin: json['origin']! as String,
      );
}

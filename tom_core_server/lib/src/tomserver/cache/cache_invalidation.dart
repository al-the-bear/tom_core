/// Carries cache invalidations — and principal revocations — to every node.
///
/// The server's caches live in each process: [TomCacheManager]'s named caches
/// and the [TomAuthorizationCache]. On one node, removing an entry or revoking
/// a principal there is the whole job. On a cluster it is not: the other
/// nodes keep serving what they cached, and for the authorization cache that
/// is a security problem rather than a performance one — a revoked grant
/// stays usable on every node but the one that revoked it.
///
/// [TomCacheInvalidator] is the cluster-wide entry point. Each call applies the
/// invalidation here and hands it to the installed [TomInvalidationChannel],
/// which delivers it to the other nodes, where the invalidator applies it in
/// turn. The channel decides how fast that is and says so in
/// [TomInvalidationChannel.stalenessBound]:
///
/// * [TomLocalInvalidationChannel], the default, reaches no other node — the
///   right channel for one process, and a bound of zero;
/// * `TomSqlInvalidationChannel` writes each invalidation to a table in a
///   database every node already has, and every node polls it; the poll
///   interval is the bound.
library;

import 'dart:async';
import 'dart:math';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../authorization/authorization_cache.dart';
import 'server_cache.dart';

/// What a [TomCacheInvalidation] invalidates.
enum TomInvalidationKind {
  /// Every token a user holds that was issued at or before the invalidation:
  /// [TomCacheInvalidation.target] is the username.
  principal,

  /// One entry of a named cache: [TomCacheInvalidation.target] is the cache
  /// name and [TomCacheInvalidation.key] the entry key.
  cacheEntry,

  /// Every entry of a named cache: [TomCacheInvalidation.target] is the cache
  /// name.
  cache,
}

/// One invalidation, as it travels between nodes.
class TomCacheInvalidation {
  const TomCacheInvalidation._(
    this.kind,
    this.target,
    this.key,
    this.at,
    this.origin,
  );

  /// Revokes [username]'s tokens issued at or before [at] (now by default).
  factory TomCacheInvalidation.principal(
    String username, {
    DateTime? at,
    String? origin,
  }) => TomCacheInvalidation._(
    TomInvalidationKind.principal,
    username,
    null,
    (at ?? DateTime.now()).toUtc(),
    origin ?? TomCacheInvalidator.nodeId,
  );

  /// Removes [key] from the cache named [cacheName].
  factory TomCacheInvalidation.cacheEntry(
    String cacheName,
    String key, {
    DateTime? at,
    String? origin,
  }) => TomCacheInvalidation._(
    TomInvalidationKind.cacheEntry,
    cacheName,
    key,
    (at ?? DateTime.now()).toUtc(),
    origin ?? TomCacheInvalidator.nodeId,
  );

  /// Empties the cache named [cacheName].
  factory TomCacheInvalidation.cache(
    String cacheName, {
    DateTime? at,
    String? origin,
  }) => TomCacheInvalidation._(
    TomInvalidationKind.cache,
    cacheName,
    null,
    (at ?? DateTime.now()).toUtc(),
    origin ?? TomCacheInvalidator.nodeId,
  );

  /// Rebuilds an invalidation from its stored parts; throws [ArgumentError]
  /// for a [kind] name no [TomInvalidationKind] carries.
  factory TomCacheInvalidation.fromParts({
    required String kind,
    required String target,
    String? key,
    required DateTime at,
    required String origin,
  }) => TomCacheInvalidation._(
    TomInvalidationKind.values.byName(kind),
    target,
    key,
    at.toUtc(),
    origin,
  );

  /// What is invalidated.
  final TomInvalidationKind kind;

  /// The username, or the cache name.
  final String target;

  /// The entry key of a [TomInvalidationKind.cacheEntry]; `null` otherwise.
  final String? key;

  /// When the invalidation was raised, in UTC. For a principal, tokens issued
  /// at or before it are revoked.
  final DateTime at;

  /// The node that raised it ([TomCacheInvalidator.nodeId] there).
  final String origin;

  @override
  String toString() =>
      'TomCacheInvalidation(${kind.name} $target${key == null ? '' : '/$key'} '
      'at $at from $origin)';
}

/// How invalidations reach the other nodes of a cluster.
///
/// Implementations deliver what other nodes [publish]ed to the callback given
/// to [start], and must not deliver a node's own invalidations back to it.
abstract interface class TomInvalidationChannel {
  /// The longest time from [publish] on one node to delivery on another.
  Duration get stalenessBound;

  /// Starts delivering other nodes' invalidations to [deliver]. Completes once
  /// the channel is ready — including, for a channel that keeps history, after
  /// delivering the revocations still in force, so a node joining a cluster
  /// does not serve a token another node has revoked.
  Future<void> start(
    Future<void> Function(TomCacheInvalidation invalidation) deliver,
  );

  /// Sends [invalidation] to every other node. Throws when it could not be
  /// sent, so a caller revoking a grant learns that the revocation did not
  /// leave this node.
  Future<void> publish(TomCacheInvalidation invalidation);

  /// Stops delivering. Idempotent.
  Future<void> stop();
}

/// The single-process channel: nothing to send, nothing to receive.
///
/// The default, and the right channel for a deployment of one node — an
/// invalidation applied here is applied everywhere there is.
class TomLocalInvalidationChannel implements TomInvalidationChannel {
  /// Creates the channel.
  const TomLocalInvalidationChannel();

  @override
  Duration get stalenessBound => Duration.zero;

  @override
  Future<void> start(
    Future<void> Function(TomCacheInvalidation invalidation) deliver,
  ) async {}

  @override
  Future<void> publish(TomCacheInvalidation invalidation) async {}

  @override
  Future<void> stop() async {}
}

/// The cluster-wide entry point for invalidating caches and revoking
/// principals.
///
/// Call [revokePrincipal] whenever a user's grants change — a role removed, a
/// resource grant withdrawn, an account disabled. It revokes every token the
/// user holds on every node within the installed channel's
/// [TomInvalidationChannel.stalenessBound]; the client re-authorizes and
/// receives a token carrying the current grants.
///
/// Callable from any isolate: a worker forwards the call to the main isolate,
/// where the caches and the channel live.
abstract final class TomCacheInvalidator {
  /// Identifies this process to the other nodes, so a channel can skip the
  /// invalidations it published itself. Random per process.
  static final String nodeId = [
    for (var i = 0; i < 4; i++)
      Random.secure().nextInt(1 << 16).toRadixString(16).padLeft(4, '0'),
  ].join();

  static TomInvalidationChannel _channel = const TomLocalInvalidationChannel();

  /// The installed channel; [TomLocalInvalidationChannel] until [install].
  static TomInvalidationChannel get channel => _channel;

  /// Installs [channel], stopping the one it replaces, and starts it.
  ///
  /// Call it once at start-up, before serving requests, so the revocations
  /// still in force reach this node before it answers anyone.
  static Future<void> install(TomInvalidationChannel channel) async {
    final previous = _channel;
    _channel = channel;
    await previous.stop();
    await channel.start(apply);
  }

  /// Revokes, on every node, the tokens [username] holds that were issued now
  /// or earlier, and drops the principals cached for them.
  static Future<void> revokePrincipal(String username) =>
      _raise(TomCacheInvalidation.principal(username));

  /// Removes [key] from the cache named [cacheName] on every node.
  static Future<void> invalidateCacheEntry(String cacheName, String key) =>
      _raise(TomCacheInvalidation.cacheEntry(cacheName, key));

  /// Empties the cache named [cacheName] on every node.
  static Future<void> invalidateCache(String cacheName) =>
      _raise(TomCacheInvalidation.cache(cacheName));

  /// Applies [invalidation] here, then publishes it — on the main isolate; a
  /// worker forwards it there.
  static Future<void> raise(TomCacheInvalidation invalidation) =>
      _raise(invalidation);

  static Future<void> _raise(TomCacheInvalidation invalidation) async {
    if (!TomWorker.isMainIsolate) {
      await TomWorker.executeInCreator(TomCacheInvalidateMessage(invalidation));
      return;
    }
    // Applied here first, so this node is consistent even when publishing
    // fails — and the failure still propagates, so the caller knows the other
    // nodes did not hear of it.
    await apply(invalidation);
    await _channel.publish(invalidation);
  }

  /// Applies [invalidation] to this process's caches, whichever node raised
  /// it. A cache name nothing registered here is nothing to invalidate.
  static Future<void> apply(TomCacheInvalidation invalidation) async {
    switch (invalidation.kind) {
      case TomInvalidationKind.principal:
        TomAuthorizationCache.revokeLocally(
          invalidation.target,
          invalidation.at,
        );
      case TomInvalidationKind.cacheEntry:
        TomCacheManager.getCache(
          invalidation.target,
        )?.removeEntry(invalidation.key!);
      case TomInvalidationKind.cache:
        TomCacheManager.getCache(invalidation.target)?.clear();
    }
  }

  /// Puts back the local channel, stopping the installed one. Test support.
  static Future<void> reset() => install(const TomLocalInvalidationChannel());
}

/// Cross-isolate command raising [invalidation] on the main isolate, where the
/// caches and the channel live.
class TomCacheInvalidateMessage extends TomCommand {
  /// The invalidation to raise.
  final TomCacheInvalidation invalidation;

  /// Creates the command for [invalidation].
  TomCacheInvalidateMessage(this.invalidation);

  @override
  Future<bool> execute() async {
    await TomCacheInvalidator.raise(invalidation);
    return true;
  }
}

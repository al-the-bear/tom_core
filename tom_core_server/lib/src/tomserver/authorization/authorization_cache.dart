import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Raised by [TomAuthorizationCache] when a cached principal cannot be
/// returned — currently when a matching entry exists but its expiry has
/// already passed.
///
/// The distinct type lets a caller catch it specifically: an expired
/// principal is a signal that the client should re-authorize, as opposed to a
/// cache miss (which simply returns `null`).
class TomAuthorizationCacheException extends TomException {
  TomAuthorizationCacheException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.uuid,
    super.serverCallError,
  });
}

/// A single entry in the [TomAuthorizationCache]: the authorized
/// [TomPrincipal] paired with the [deletionTime] at which it should be
/// considered stale and evicted.
///
/// When no explicit deletion time is supplied the entry lives for one day.
class TomAuthorizationCacheEntry {
  /// The instant after which this entry is expired and may be evicted. Set to
  /// the token's `validUntil` when stored via [TomAuthorizationCache.storePrincipal].
  late DateTime deletionTime;

  /// The principal resolved for the associated authentication token.
  TomPrincipal authorizedPrincipal;

  /// Creates an entry for [authorizedPrincipal]. [deletionTime] defaults to one
  /// day from now when omitted.
  TomAuthorizationCacheEntry(
    this.authorizedPrincipal, [
    DateTime? deletionTime,
  ]) {
    this.deletionTime = deletionTime ?? DateTime.now().add(Duration(days: 1));
  }
}

/// Caches the [TomPrincipal] resolved for an authentication token so that the
/// authorization lookup runs once per token rather than on every request.
///
/// The cache lives in the **main isolate** and is keyed by the JWT token
/// string. Worker isolates do not hold their own copy: [getPrincipal] and
/// [storePrincipal] detect when they run off the main isolate and forward the
/// request to the creator isolate via [TomWorker.executeInCreator], where the
/// [TomAuthorizationCacheExecutor] services the [TomAuthorizationCacheStoreMessage]
/// / [TomAuthorizationCacheRetrieveMessage] against the single shared map.
///
/// A periodic timer evicts entries whose [TomAuthorizationCacheEntry.deletionTime]
/// has passed once an hour; reads also reject an expired entry by throwing a
/// [TomAuthorizationCacheException].
class TomAuthorizationCache {
  static final TomAuthorizationCache _current = TomAuthorizationCache();

  TomAuthorizationCache() {
    Zone.current.createPeriodicTimer(Duration(hours: 1), (Timer t) {
      var now = DateTime.now();
      List<String> entriesToDelete = [];
      for (var entry in _cache.entries) {
        if (entry.value.deletionTime.isBefore(now)) {
          entriesToDelete.add(entry.key);
        }
      }
      if (entriesToDelete.isNotEmpty) {
        tomLog.debug(
          "TomAuthorizationCache timer is deleting keys $entriesToDelete",
        );
        for (var key in entriesToDelete) {
          _cache.remove(key);
        }
      }
    });
  }

  final Map<String, TomAuthorizationCacheEntry> _cache = {};

  /// Returns the cached principal for [authenticationToken], or `null` if no
  /// entry exists (a cache miss).
  ///
  /// Throws [TomAuthorizationCacheException] when an entry exists but has
  /// expired — the caller should treat that as a prompt to re-authorize.
  ///
  /// When called from a worker isolate the lookup is forwarded to the main
  /// isolate, and all three answers survive the trip: a hit returns the
  /// principal, a miss returns `null`, and an expiry rethrows on this side.
  /// Callers therefore need no isolate-dependent handling — which matters
  /// because the two non-hit answers mean opposite things ("no principal yet,
  /// go resolve one" versus "there was one and it has aged out"), and merging
  /// them would send a stale session back through resolution instead of
  /// re-authorization.
  static Future<TomPrincipal?> getPrincipal(
    TomClientJwtToken authenticationToken,
  ) async {
    if (TomWorker.isMainIsolate) {
      TomAuthorizationCacheEntry? entry =
          _current._cache[authenticationToken.tokenString];
      if (entry != null) {
        if (entry.deletionTime.isAfter(DateTime.now())) {
          tomLog.trace(
            "Found authorization principal for ${limited(authenticationToken.tokenString, 100)}",
          );
          return entry.authorizedPrincipal;
        } else {
          throw TomAuthorizationCacheException(
            "tomclient.authorization_cache.expired_principal",
            "AuthorizedPrincipal expired for user $authenticationToken",
          );
        }
      }
    } else {
      // An expiry raised on the creator side arrives here as a throw and
      // propagates untouched, so this branch only has to separate a hit from a
      // miss. A miss reaches us as TomExecutor.noResult rather than `null`,
      // because executeInCreator substitutes the sentinel for a `null` result
      // -- which is also what a command no executor claimed comes back as, so
      // a process that never registered TomAuthorizationCacheExecutor reads as
      // one long cache miss. The creator logs a warning in that case and this
      // side cannot see it.
      Object? cachedResult = await TomWorker.executeInCreator(
        TomAuthorizationCacheRetrieveMessage(authenticationToken),
      );
      if (cachedResult is TomPrincipal) {
        return cachedResult;
      }
    }
    return null;
  }

  /// Stores [authorizedPrincipal] under [authenticationToken], using the
  /// token's `validUntil` payload claim as the entry's expiry.
  ///
  /// When called from a worker isolate the store is forwarded to the main
  /// isolate. Always returns `0`.
  static Future<int> storePrincipal(
    TomClientJwtToken authenticationToken,
    TomPrincipal authorizedPrincipal,
  ) async {
    if (TomWorker.isMainIsolate) {
      DateTime expiry = DateTime.parse(
        authenticationToken.token.payload["validUntil"],
      );
      tomLog.trace(
        "Storing principal ${limited(authenticationToken.tokenString, 100)} with expiry $expiry",
      );
      _current._cache[authenticationToken.tokenString] =
          TomAuthorizationCacheEntry(authorizedPrincipal, expiry);
    } else {
      await TomWorker.executeInCreator(
        TomAuthorizationCacheStoreMessage(
          authenticationToken,
          authorizedPrincipal,
        ),
      );
    }
    return 0;
  }
}

/// Cross-isolate command asking the main isolate to store
/// [authorizedPrincipal] for [authenticationToken]. Handled by
/// [TomAuthorizationCacheExecutor].
class TomAuthorizationCacheStoreMessage {
  TomClientJwtToken authenticationToken;
  TomPrincipal authorizedPrincipal;
  TomAuthorizationCacheStoreMessage(
    this.authenticationToken,
    this.authorizedPrincipal,
  );
}

/// Cross-isolate command asking the main isolate to return the cached
/// principal for [authenticationToken]. Handled by
/// [TomAuthorizationCacheExecutor].
class TomAuthorizationCacheRetrieveMessage {
  TomClientJwtToken authenticationToken;
  TomAuthorizationCacheRetrieveMessage(this.authenticationToken);
}

/// Runs in the main isolate and services the [TomAuthorizationCacheStoreMessage]
/// and [TomAuthorizationCacheRetrieveMessage] commands forwarded from worker
/// isolates, delegating to [TomAuthorizationCache]. Returns
/// [TomExecutor.noResult] for any other command.
class TomAuthorizationCacheExecutor extends TomExecutor {
  @override
  Object execute(Object command) {
    if (command is TomAuthorizationCacheStoreMessage) {
      tomLog.trace(
        "Storing authorizedPrincipal ${limited(command.authenticationToken.tokenString, 100)} in main Isolate",
      );
      // ignore: discarded_futures
      TomAuthorizationCache.storePrincipal(
        command.authenticationToken,
        command.authorizedPrincipal,
      );
      return true;
    }
    if (command is TomAuthorizationCacheRetrieveMessage) {
      tomLog.trace(
        "Retrieving authorizedPrincipal ${limited(command.authenticationToken.tokenString, 100)}",
      );
      return TomAuthorizationCache.getPrincipal(command.authenticationToken);
    }
    return TomExecutor.noResult;
  }
}

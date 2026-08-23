import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Raised by [TomAuthorizationCache] when a principal cannot be returned or
/// cached. Three conditions carry three keys, because they call for three
/// different responses:
///
/// | Key | Meaning |
/// | --- | ------- |
/// | `tomclient.authorization_cache.expired_principal` | A matching entry exists but its expiry has passed. The client should re-authorize. |
/// | `tomclient.authorization_cache.missing_valid_until` | The token carries no readable `validUntil` claim, so nothing was cached. |
/// | `tomclient.authorization_cache.invalid_valid_until` | The token's `validUntil` claim is not an ISO 8601 instant, so nothing was cached. |
///
/// The distinct type lets a caller catch these specifically: an expired
/// principal is a signal to re-authorize, as opposed to a cache miss (which
/// simply returns `null`), and the two `validUntil` keys report a malformed
/// token rather than anything about the principal.
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
/// A periodic sweep evicts entries whose [TomAuthorizationCacheEntry.deletionTime]
/// has passed; reads also reject an expired entry by throwing a
/// [TomAuthorizationCacheException]. The sweep starts with the first stored
/// principal and can be stopped again through [stopEviction] — or, on a server,
/// by registering [instance] with `tomShutdownCleanup`. It runs in [Zone.root]
/// regardless of who starts it, so the request that happens to store first does
/// not end up owning process-lifetime work.
class TomAuthorizationCache implements TomDisposable {
  static final TomAuthorizationCache _current = TomAuthorizationCache._();

  /// The one cache the static API reads and writes.
  ///
  /// Exposed so that a server can hand it to the shutdown-cleanup path:
  ///
  /// ```dart
  /// tomShutdownCleanup.addDisposable(TomAuthorizationCache.instance);
  /// ```
  ///
  /// A getter onto the singleton rather than a public constructor, so that
  /// reaching for the cache cannot conjure a second one: every instance owns a
  /// sweep, and a second instance's sweep would walk a map that nothing can
  /// ever populate — the static API only ever touches this one.
  static TomAuthorizationCache get instance => _current;

  TomAuthorizationCache._();

  /// How often the eviction sweep runs when nobody asks for another interval.
  static const Duration evictionInterval = Duration(hours: 1);

  final Map<String, TomAuthorizationCacheEntry> _cache = {};

  /// The running eviction sweep, or `null` when none is running.
  ///
  /// Held in a field for two reasons: a periodic timer nothing references can
  /// never be stopped and keeps the isolate alive, and holding exactly one
  /// makes "at most one sweep" a property of the structure rather than a rule
  /// each starter has to remember.
  Timer? _evictionTimer;

  /// Whether an eviction sweep is currently running.
  static bool get isEvicting => _current._evictionTimer != null;

  /// Starts the eviction sweep at [interval], replacing any sweep already
  /// running.
  ///
  /// Callers do not normally need this: [storePrincipal] starts the sweep at
  /// [evictionInterval] with the first entry it caches. It exists for the two
  /// cases that do — a server that wants a different interval than the hourly
  /// default, and a test that cannot wait an hour.
  ///
  /// It is *not* needed to control which zone the sweep runs in: the timer is
  /// created in [Zone.root] whichever of the two paths starts it, so a sweep
  /// started from inside a request is no different from one started at boot.
  ///
  /// Replacing rather than ignoring a second call is what makes the postcondition
  /// "a sweep is running at [interval]" true whenever this returns.
  static void startEviction({Duration interval = evictionInterval}) =>
      _current._startEviction(interval);

  /// Stops the eviction sweep. Does nothing when none is running, because a
  /// shutdown path cannot know which parts of the process ever started.
  ///
  /// Entries already cached are left alone: stopping the sweep suspends the
  /// bounding of the map, it does not invalidate what is in it. Expired entries
  /// are still rejected on read. Use [dispose] to drop them as well.
  static void stopEviction() => _current._stopEviction();

  void _startEviction(Duration interval) {
    _evictionTimer?.cancel();
    // Why: Zone.root, not Zone.current. This timer lives as long as the
    // process, while the caller that happens to store the first principal is
    // usually a single request — the endpoint pipeline runs each one in its own
    // zone to carry the principal. Parenting process-lifetime work to a request
    // zone leaves it answering to that request's error handling and teardown
    // long after the request is gone, and makes the sweep's zone depend on
    // which caller arrived first rather than on a decision anyone made.
    //
    // Root rather than a zone the server installs at boot, because the sweep
    // needs nothing a zone could give it: it walks a plain map, wants no
    // principal and no transaction, and an error in it belongs to the process
    // rather than to any request. Its one log line carries no request logging
    // context for the same reason — the sweep is not part of a request. A boot
    // zone would only tie the sweep to start-up ordering it cannot use.
    _evictionTimer = Zone.root.createPeriodicTimer(
      interval,
      (Timer t) => _evictExpired(),
    );
  }

  void _stopEviction() {
    _evictionTimer?.cancel();
    _evictionTimer = null;
  }

  /// Starts the sweep at [evictionInterval] unless one is already running.
  ///
  /// Distinct from [_startEviction] so that the automatic start cannot undo a
  /// deliberate one: a server or a test that chose an interval keeps it, and
  /// the next store does not silently reset it to the default.
  void _ensureEviction() {
    if (_evictionTimer != null) return;
    _startEviction(evictionInterval);
  }

  /// Removes every entry whose [TomAuthorizationCacheEntry.deletionTime] has
  /// passed. Collected first and removed after, because removing while
  /// iterating [_cache] would invalidate the iteration.
  void _evictExpired() {
    final DateTime now = DateTime.now();
    final List<String> entriesToDelete = [
      for (final entry in _cache.entries)
        if (entry.value.deletionTime.isBefore(now)) entry.key,
    ];
    if (entriesToDelete.isEmpty) return;
    tomLog.debug(
      "TomAuthorizationCache timer is deleting ${entriesToDelete.length} expired entries",
    );
    for (final key in entriesToDelete) {
      _cache.remove(key);
    }
  }

  /// Stops the sweep and drops every cached principal — the shutdown contract,
  /// so that registering [instance] with `tomShutdownCleanup` both releases the
  /// isolate and leaves no authorized principals behind in memory.
  ///
  /// Synchronous, as [TomDisposable] requires: the cleanup discards a returned
  /// future rather than awaiting it, and cancelling a timer needs nothing more.
  @override
  void dispose() {
    _stopEviction();
    _cache.clear();
  }

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

  /// Reads the entry's expiry from the token's `validUntil` payload claim.
  ///
  /// Throws [TomAuthorizationCacheException] when the claim is absent or not a
  /// string (`missing_valid_until`), or when it is a string that is not an ISO
  /// 8601 instant (`invalid_valid_until`). Both name the claim, the value seen
  /// and the token.
  ///
  /// The token comes from a client, so this is a boundary: the claim is
  /// untrusted input rather than internal data, and the three shapes above are
  /// what a caller can actually present.
  ///
  /// Refusing the write is the only safe answer, which is why there is no
  /// fallback lifetime. The entry's lifetime *is* the token's — that is the
  /// whole reason the claim is read — so a default invented here would keep a
  /// principal cached after the token authorizing it had expired, and every
  /// later request bearing that token would be served from the cache instead
  /// of being re-authorized.
  static DateTime _expiryFromToken(TomClientJwtToken authenticationToken) {
    final Object? payload = authenticationToken.token.payload;
    final Object? claim = payload is Map ? payload['validUntil'] : null;
    final String tokenExcerpt = limited(authenticationToken.tokenString, 100);

    if (claim is! String) {
      throw TomAuthorizationCacheException(
        "tomclient.authorization_cache.missing_valid_until",
        "Authentication token carries no readable validUntil claim, so the "
            "principal cannot be cached",
        parameters: {
          'claim': 'validUntil',
          'value': claim,
          'token': tokenExcerpt,
        },
      );
    }

    // tryParse rather than parse: the FormatException would name the value but
    // not the claim it came from, and this is the one frame that still knows.
    final DateTime? parsed = DateTime.tryParse(claim);
    if (parsed == null) {
      throw TomAuthorizationCacheException(
        "tomclient.authorization_cache.invalid_valid_until",
        "Authentication token carries a validUntil claim that is not an ISO "
            "8601 instant, so the principal cannot be cached",
        parameters: {
          'claim': 'validUntil',
          'value': claim,
          'token': tokenExcerpt,
        },
      );
    }
    return parsed;
  }

  /// Stores [authorizedPrincipal] under [authenticationToken], using the
  /// token's `validUntil` payload claim as the entry's expiry.
  ///
  /// Throws [TomAuthorizationCacheException] when that claim is missing or
  /// unreadable; nothing is cached in that case, and the caller keeps resolving
  /// the principal per request. See [_expiryFromToken] for why there is no
  /// fallback expiry.
  ///
  /// The first entry cached also starts the eviction sweep (see
  /// [startEviction]): the sweep exists to bound this map, so it runs from the
  /// moment there is something in it to bound and not before — a process that
  /// only ever reads the cache never starts a timer at all.
  ///
  /// When called from a worker isolate the store is forwarded to the main
  /// isolate. Always returns `0`.
  static Future<int> storePrincipal(
    TomClientJwtToken authenticationToken,
    TomPrincipal authorizedPrincipal,
  ) async {
    if (TomWorker.isMainIsolate) {
      DateTime expiry = _expiryFromToken(authenticationToken);
      tomLog.trace(
        "Storing principal ${limited(authenticationToken.tokenString, 100)} with expiry $expiry",
      );
      _current._ensureEviction();
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
///
/// Both handled commands return the delegate's future rather than awaiting it
/// here, so a creator-side failure — an expired entry on a retrieve, an
/// unreadable `validUntil` on a store — reaches the asking worker as a throw
/// instead of being swallowed on this side.
class TomAuthorizationCacheExecutor extends TomExecutor {
  @override
  Object execute(Object command) {
    if (command is TomAuthorizationCacheStoreMessage) {
      tomLog.trace(
        "Storing authorizedPrincipal ${limited(command.authenticationToken.tokenString, 100)} in main Isolate",
      );
      // Returned rather than discarded, for the same reason the retrieve below
      // is: the transport awaits whatever comes back, so a returned future
      // carries a refusal to the worker as a throw, while a discarded one
      // leaves the worker reading `0` -- success -- for a store that never
      // happened. The value it settles to is storePrincipal's own `0`; nothing
      // reads it, but it is not null, so executeInCreator does not mistake it
      // for an unclaimed command.
      return TomAuthorizationCache.storePrincipal(
        command.authenticationToken,
        command.authorizedPrincipal,
      );
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

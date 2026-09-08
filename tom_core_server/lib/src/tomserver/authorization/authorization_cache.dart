import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';

/// Raised by [TomAuthorizationCache] when a principal cannot be returned or
/// cached. Three conditions carry three keys, because they call for three
/// different responses:
///
/// | Key | Meaning |
/// | --- | ------- |
/// | `authorization.cache.expired_principal` | A matching entry existed but its expiry had passed; it has been dropped, so the next read of the same token is a miss. The client should re-authorize. |
/// | `authorization.cache.missing_valid_until` | The token carries no readable `validUntil` claim, so nothing was cached. |
/// | `authorization.cache.invalid_valid_until` | The token's `validUntil` claim is not an ISO 8601 instant, so nothing was cached. |
///
/// The distinct type lets a caller catch these specifically: an expired
/// principal is a signal to re-authorize, as opposed to a cache miss (which
/// simply returns `null`), and the two `validUntil` keys report a malformed
/// token rather than anything about the principal.
///
/// `clientThrow` defaults to `true`, which is the opposite of most of the
/// package and is the point: all three conditions are about the token the
/// caller presented, and two of them tell the caller what to do next
/// (re-authorize; send a well-formed `validUntil`). An answer the caller
/// cannot read leaves it retrying a token that will never be accepted. A raise
/// site whose message came to describe the server's own state would pass
/// `clientThrow: false` — none does.
class TomAuthorizationCacheException extends TomServerException {
  TomAuthorizationCacheException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.clientThrow = true,
  });
}

/// A single entry in the [TomAuthorizationCache]: the authorized
/// [TomPrincipal] paired with the [deletionTime] at which it should be
/// considered stale and evicted.
///
/// Both are required, and neither changes afterwards. An entry's lifetime is
/// not its own — it is the lifetime of the token the principal was authorized
/// under, which is why [TomAuthorizationCache.storePrincipal] takes the instant
/// off the token's `validUntil` claim and refuses to cache a token it cannot
/// read one from. There is therefore no instant this class could default to
/// that would be right: a default would be an invented lifetime, the one thing
/// that refusal exists to avoid, and it would apply exactly to the callers who
/// had no token expiry in hand. A settable field would let the expiry be moved
/// afterwards to one the token never granted, which is the same hole with a
/// later entrance.
class TomAuthorizationCacheEntry {
  /// The instant after which this entry is expired and may be evicted. Set to
  /// the token's `validUntil` when stored via [TomAuthorizationCache.storePrincipal].
  final DateTime deletionTime;

  /// The principal resolved for the associated authentication token.
  final TomPrincipal authorizedPrincipal;

  /// Creates an entry for [authorizedPrincipal] that expires at [deletionTime]
  /// — normally the `validUntil` of the token it was authorized under.
  TomAuthorizationCacheEntry(this.authorizedPrincipal, this.deletionTime);
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
/// has passed; a read that meets one first rejects it with a
/// [TomAuthorizationCacheException] and drops it in the same breath, so the
/// sweep bounds the map rather than being the only thing that does. The map
/// therefore holds about one entry per live session.
///
/// The sweep starts with the first stored
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
  /// are still rejected on read — and dropped by that read, so a stopped cache
  /// still sheds the tokens anyone asks about, just not the ones nobody does.
  /// Use [dispose] to drop them all.
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
  /// That read also removes the entry it rejected, so the expiry is reported
  /// once: a second read of the same token is an ordinary miss. A caller that
  /// wants to know a session died still learns it, from the exception; a
  /// caller retrying with the dead token is told there is nothing there, which
  /// is by then the truth.
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
          // Why: dropped here rather than left for the sweep. This frame has
          // just established the entry is dead, and it holds both the map and
          // the key -- there is no cheaper place to remove it. Left in, the row
          // would survive until the sweep next came round (an hour, by
          // default), and every request bearing the same dead token in the
          // meantime would repeat this lookup, this throw and this stack for an
          // answer that cannot change. It also decides the map's high-water
          // mark: one entry per live session with the removal, one per
          // successful login per sweep interval without it.
          _current._cache.remove(authenticationToken.tokenString);
          throw TomAuthorizationCacheException(
            "authorization.cache.expired_principal",
            "AuthorizedPrincipal expired for the presented token",
            parameters: {
              'token': limited(authenticationToken.tokenString, 100),
            },
          );
        }
      }
    } else {
      // An expiry raised on the creator side arrives here as a throw and
      // propagates untouched, so this branch has two answers to separate: a
      // hit, and a miss. A miss reaches us as TomExecutor.noResult rather than
      // `null`, because executeInCreator substitutes the sentinel for a `null`
      // result.
      //
      // TomExecutor.notHandled is the third answer and is neither. It means
      // the creator received the message and nothing claimed it, which for
      // this command has exactly one cause: the process never registered
      // TomAuthorizationCacheExecutor. Read as a miss -- which it was until
      // the transport learned to tell the two apart -- it made every lookup in
      // such a process re-resolve its principal for ever, plausibly and
      // silently, with the only evidence a warning on the creator that this
      // side cannot see.
      Object? cachedResult = await TomWorker.executeInCreator(
        TomAuthorizationCacheRetrieveMessage(authenticationToken),
      );
      _refuseUnhandled(cachedResult, 'read');
      if (cachedResult is TomPrincipal) {
        return cachedResult;
      }
    }
    return null;
  }

  /// Throws when [response] says nothing on the creator claimed the command.
  ///
  /// A configuration error rather than a cache outcome, so it is raised rather
  /// than folded into the answer: the cache cannot serve this isolate at all,
  /// and every call will do the same thing until a boot registers the
  /// executor. [operation] names which call found it, because the two fail
  /// differently — a read degrades to re-resolving the principal, a write is
  /// simply lost.
  ///
  /// `clientThrow: false`: the message names a start-up mistake in this
  /// deployment, which is operator-facing and no business of whoever's request
  /// happened to arrive first.
  static void _refuseUnhandled(Object? response, String operation) {
    if (!identical(response, TomExecutor.notHandled)) return;
    throw TomAuthorizationCacheException(
      'authorization.cache.executor_not_registered',
      'The authorization cache cannot $operation from a worker isolate: the '
          'creator answered that nothing handled the command. Register '
          'TomAuthorizationCacheExecutor with TomWorker.addExecutor on the '
          'main isolate at start-up.',
      parameters: {'operation': operation},
      clientThrow: false,
    );
  }

  /// Reads the entry's expiry from the token's standard `exp` claim.
  ///
  /// ## Why `exp` and not `validUntil`
  ///
  /// A `TomServerJwtToken` carries both. `exp` is the registered JWT claim, in
  /// epoch seconds; `validUntil` is a Tom convenience written beside it, as an
  /// ISO 8601 string. Two claims naming one instant is one claim too many for
  /// a cache to choose between, and the standard one wins on two counts.
  ///
  /// It is the claim a JWT verifier enforces. `verifyBearerToken` hands this
  /// module tokens whose signature it has checked, and any deployment fronted
  /// by a gateway is checking `exp` there too — so reading anything else means
  /// the cache's notion of expiry can diverge from the one the rest of the
  /// system enforces, silently, in whichever direction the two happen to
  /// disagree.
  ///
  /// And it is unambiguous. `exp` is an absolute instant by definition. An ISO
  /// string is only absolute if it carries an offset, and one written without
  /// means whatever the *reader's* zone says it means: [DateTime.tryParse]
  /// answers with a local `DateTime`, so a token minted in one zone and cached
  /// by a server in another was off by the difference between them.
  ///
  /// `validUntil` remains in the payload as the human-readable form of the same
  /// instant — see `TomServerJwtToken`, which derives both from one clock read
  /// so they cannot drift — and nothing on the server reads it.
  ///
  /// ## What it refuses
  ///
  /// Throws [TomAuthorizationCacheException] when the claim is absent or is not
  /// an integer (`missing_expiry`), and when it is an integer no instant can be
  /// built from (`invalid_expiry`). Both name the claim, the value seen and the
  /// token.
  ///
  /// The token comes from a client, so this is a boundary: the claim is
  /// untrusted input rather than internal data, and both shapes are what a
  /// caller can actually present.
  ///
  /// Refusing the write is the only safe answer, which is why there is no
  /// fallback lifetime. The entry's lifetime *is* the token's — that is the
  /// whole reason the claim is read — so a default invented here would keep a
  /// principal cached after the token authorizing it had expired, and every
  /// later request bearing that token would be served from the cache instead
  /// of being re-authorized.
  static DateTime _expiryFromToken(TomClientJwtToken authenticationToken) {
    final Object? payload = authenticationToken.token.payload;
    final Object? claim = payload is Map ? payload['exp'] : null;
    final String tokenExcerpt = limited(authenticationToken.tokenString, 100);

    if (claim is! int) {
      throw TomAuthorizationCacheException(
        "authorization.cache.missing_expiry",
        "Authentication token carries no readable exp claim, so the principal "
            "cannot be cached",
        parameters: {'claim': 'exp', 'value': claim, 'token': tokenExcerpt},
      );
    }

    // Seconds to milliseconds, in UTC because that is what an epoch offset is.
    // The multiplication is where an absurd claim stops being representable, so
    // it is the range check: `fromMillisecondsSinceEpoch` throws past roughly
    // ±275 000 years, and a client can put any integer here.
    try {
      return DateTime.fromMillisecondsSinceEpoch(claim * 1000, isUtc: true);
    } on Object {
      throw TomAuthorizationCacheException(
        "authorization.cache.invalid_expiry",
        "Authentication token carries an exp claim that is not an instant any "
            "clock can represent, so the principal cannot be cached",
        parameters: {'claim': 'exp', 'value': claim, 'token': tokenExcerpt},
      );
    }
  }

  /// Stores [authorizedPrincipal] under [authenticationToken], using the
  /// token's standard `exp` payload claim as the entry's expiry.
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
  /// isolate.
  ///
  /// The future carries only completion and failure: there is no count or
  /// status to report, since a store either happens or throws.
  static Future<void> storePrincipal(
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
      // The response was ignored entirely until the transport could say
      // "nothing claimed this": a store into a process with no executor
      // completed normally and reported success, so the write was lost and the
      // caller was told it had happened. Checked rather than returned, because
      // this method's contract is that a store either happens or throws.
      final response = await TomWorker.executeInCreator(
        TomAuthorizationCacheStoreMessage(
          authenticationToken,
          authorizedPrincipal,
        ),
      );
      _refuseUnhandled(response, 'store');
    }
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
      // leaves the worker reading success for a store that never happened.
      //
      // The future settles to nothing, which is the right answer and not a
      // missing one: the creator awaits it and compares against
      // TomExecutor.noResult to decide whether an executor claimed the
      // command, and `null` is not that sentinel, so the chain stops here as
      // it should. What the worker finally reads is the substituted sentinel,
      // and nothing reads it.
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

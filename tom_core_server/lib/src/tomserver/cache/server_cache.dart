import 'dart:async';
import 'dart:isolate';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../little_things/server_exception.dart';

/// Raised by the cache API when an operation cannot be completed: the named
/// cache does not exist in this isolate (and cannot be forwarded), or a
/// retrieved value does not match the requested type parameter.
///
/// Defaults to `clientThrow: false`. Both failures are about the server's own
/// wiring and neither is actionable by a caller: a missing cache names an entry
/// in a server-side registry, which is a deployment detail, and a type mismatch
/// says the server stored something other than what it now reads back. A caller
/// that asked for a value cannot fix either, and the cache is a facility the
/// caller never addressed in the first place — a request asks for a resource,
/// not for a cache lookup, so the very existence of the cache is an
/// implementation choice that the error should not disclose.
///
/// The flag is forwarded, so a caller with a cache whose names are genuinely
/// public can pass `clientThrow: true` at the raise site.
class TomCacheException extends TomServerException {
  TomCacheException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
    super.clientThrow = false,
  });
}

/// A single cached value paired with the optional [deletionTime] after which
/// it is considered expired.
///
/// When a cache is bounded ([TomCache.maximumEntries] set) the entries are also
/// linked into a most-recently-used list via the private `_next`/`_before`
/// pointers so the least-recently-used entry can be evicted in O(1).
class TomCacheEntry {
  /// The instant after which this entry is expired. `null` means the entry does
  /// not expire on its own (it may still be evicted by an LRU bound or a clear).
  DateTime? deletionTime;

  /// The cached value. Never `null`.
  ///
  /// `null` is what a read answers for a miss and for an expiry, so an entry
  /// holding `null` would be a value no read could surface: the caller would be
  /// told the cache is empty of a key the cache is in fact holding, while the
  /// entry went on occupying a slot and counting against a bounded cache's
  /// [TomCache.maximumEntries]. Making the field non-nullable is what closes
  /// that off at both entrances — the [TomCache.toNameCache] helpers and a
  /// hand-built entry passed to [TomCache.putEntry] — and is what lets
  /// [TomCache.fromNameCache] read `null` as "absent" with no second meaning.
  Object value;

  TomCacheEntry? _next;
  TomCacheEntry? _before;
  String? _key;

  /// Creates an entry holding [value], optionally expiring at [deletionTime].
  TomCacheEntry(this.value, [this.deletionTime]);
}

/// Holds the set of named [TomCache] instances for an isolate and decides
/// whether cache operations run locally or are forwarded to the creator
/// isolate.
///
/// Caches physically live in the main isolate. [useInThisIsolate] is forced to
/// `true` there; in a worker isolate it stays `false` (unless explicitly set),
/// so operations on a cache the worker does not hold are forwarded to the main
/// isolate via [TomWorker.executeInCreator].
class TomCacheManager {
  /// Whether caches are served from this isolate. Always `true` in the main
  /// isolate; `false` in a worker isolate forwards missing-cache operations to
  /// the creator.
  bool useInThisIsolate;

  /// Creates a manager. [useInThisIsolate] defaults to `false`, but is forced
  /// to `true` when constructed in the main isolate.
  TomCacheManager([this.useInThisIsolate = false]) {
    if (TomWorker.isMainIsolate) {
      useInThisIsolate = true;
    }
  }

  /// Replaces the process-wide current manager and returns the one it replaced.
  /// Useful in tests or to install a pre-populated manager.
  ///
  /// **The *outgoing* manager is what comes back**, which is the only answer
  /// that is worth anything: the incoming one is the argument the caller just
  /// passed. A caller that installs a fresh manager without having kept a
  /// reference to the old one would otherwise have displaced a registry it can
  /// no longer reach — whose caches are still sweeping.
  ///
  /// **A pure swap: the outgoing caches keep running.** Their timers are not
  /// stopped, and that is deliberate — a caller swapping a manager out in order
  /// to swap it back would otherwise get its caches returned dead, and a
  /// `setCurrent` that restarted them on the way back would be doing two things
  /// and guessing which. The returned manager is the handle for releasing what
  /// was displaced: call [dispose] on it when the swap is final.
  ///
  /// See [removeCache] to release a single cache, and [dispose] for a whole
  /// registry.
  static TomCacheManager setCurrent(TomCacheManager manager) {
    final previous = _current;
    _current = manager;
    return previous;
  }

  static var _current = TomCacheManager();

  /// Returns the cache registered under [name], or `null` if none is.
  static TomCache? getCache(String name) => _current._caches[name];

  /// Registers [cache] under its [TomCache.cacheName].
  static void addCache(TomCache cache) {
    _current._caches[cache.cacheName] = cache;
  }

  /// Unregisters the cache named [name], **stops its timers**, and returns it;
  /// `null` when no cache of that name was registered.
  ///
  /// The counterpart [addCache] lacked. A cache installs its periodic timers in
  /// its constructor, so one that merely leaves the registry goes on sweeping
  /// and clearing a map no lookup can reach — and a pending timer keeps the
  /// isolate alive. Unregistering and stopping are therefore one operation:
  /// splitting them would leave the caller holding the half that matters and
  /// no reason to think so.
  ///
  /// The cache is **returned rather than destroyed**, and [TomCache.stopTimers]
  /// is reversible: its entries are still there, and
  /// [TomCache.createTimers] restarts it. A caller that wants the contents, or
  /// means to re-register it later, has both.
  ///
  /// An unknown name answers `null` rather than raising: a caller tidying up
  /// should not have to know whether it got as far as registering.
  static TomCache? removeCache(String name) {
    final removed = _current._caches.remove(name);
    removed?.stopTimers();
    return removed;
  }

  /// Unregisters every cache this manager holds and stops each one's timers.
  ///
  /// What a caller invokes when it is finished with a registry — a test between
  /// cases, a process shutting down, or the manager [setCurrent] handed back
  /// after a final swap. `setCurrent` deliberately does not do this itself; see
  /// there for why.
  ///
  /// Idempotent: a second call finds an empty registry and does nothing, so a
  /// shutdown path that reaches it twice is not a fault. The caches themselves
  /// survive and are restartable, exactly as with [removeCache].
  void dispose() {
    for (final cache in _caches.values) {
      cache.stopTimers();
    }
    _caches.clear();
  }

  /// The registry itself. Keyed by [TomCache.cacheName], which is the only key
  /// [addCache] can write and the only one [getCache] can read — a cache is
  /// reachable under its own name and under nothing else.
  final Map<String, TomCache> _caches = {};
}

/// A named in-memory cache of [TomCacheEntry] values keyed by string.
///
/// A cache may be:
/// - **unbounded** (default) — a plain map with optional time-based expiry, or
/// - **bounded** ([maximumEntries] set) — a most-recently-used list where the
///   least-recently-used entry is evicted once the bound is exceeded; [getEntry]
///   and [putEntry] move the touched entry to the front.
///
/// Two background timers can be installed at construction: a *deletion* timer
/// (every [deletionIntervalSeconds]) that drops entries past their
/// `deletionTime`, and a *clearance* timer (every [clearIntervalSeconds]) that
/// empties the whole cache.
///
/// The static `…NameCache` / `…TypeCache` helpers are the usual entry points:
/// they look the cache up by name through [TomCacheManager] and, in a worker
/// isolate that does not hold the cache, forward the operation to the main
/// isolate.
class TomCache {
  TomCacheEntry? _first;
  TomCacheEntry? _last;

  final Map<String, TomCacheEntry> _cache = {};

  /// Removes the entry stored under [key], unlinking it from the MRU list if the
  /// cache is bounded, and answers whether there was one to remove.
  ///
  /// A key the cache does not hold is not an error — it answers `false`. The
  /// distinction is worth returning because the caller cannot otherwise make
  /// it without a second read, which from a worker isolate is a second crossing.
  ///
  /// This is the module's only chain-unlink routine. The deletion sweep, and
  /// both of [putEntry]'s removals — replacing an existing key and evicting the
  /// least-recently-used entry — all go through it, so a map removal cannot be
  /// paired with a partial chain repair in one of them. Every earlier defect in
  /// this area was a second copy of these ten lines that had drifted: repairing
  /// the head but not the tail, or removing from the map with no repair at all.
  bool removeEntry(String key) {
    TomCacheEntry? oldEntry = _cache[key];
    // Remove old entry;
    if (oldEntry != null) {
      // remove from chain
      if (oldEntry._before != null) {
        oldEntry._before!._next = oldEntry._next;
      } else {
        _first = oldEntry._next;
      }
      if (oldEntry._next != null) {
        oldEntry._next!._before = oldEntry._before;
      } else {
        _last = oldEntry._before;
      }
      _cache.remove(key);
      return true;
    }
    return false;
  }

  /// Returns the entry under [key], or `null` if absent. In a bounded cache the
  /// returned entry is promoted to the most-recently-used position. Does not
  /// check expiry — callers (e.g. [fromNameCache]) enforce that.
  TomCacheEntry? getEntry(String key) {
    if (maximumEntries == null) {
      return _cache[key];
    } else {
      TomCacheEntry? entry = _cache[key];
      if (entry != null) {
        if (_first != entry) {
          // make this the first entry
          var oldBefore = entry._before;
          var oldNext = entry._next;
          var oldFirst = _first;
          _first = entry;
          if (oldBefore != null) {
            oldBefore._next = oldNext;
          }
          if (oldNext != null) {
            oldNext._before = oldBefore;
          } else {
            // The promoted entry was the tail; the new tail is its predecessor.
            _last = oldBefore;
          }
          entry._before = null;
          entry._next = oldFirst;
          oldFirst!._before = entry;
        }
        return entry;
      } else {
        return null;
      }
    }
  }

  /// Stores [entry] under [key], inserting it at the most-recently-used
  /// position. In a bounded cache, exceeding [maximumEntries] evicts the
  /// least-recently-used entry.
  ///
  /// Storing under a key the cache already holds *replaces* the entry: in a
  /// bounded cache the previous one is unlinked through [removeEntry] first, so
  /// it leaves the MRU chain rather than staying in it unreachable. Reads would
  /// not notice either way — the map holds one value per key regardless — but a
  /// superseded entry left in the chain eventually becomes its tail, and the
  /// eviction that follows would then drop the live replacement by its key.
  bool putEntry(String key, TomCacheEntry entry) {
    // Captured before anything is written, because every branch below mutates
    // the map and the sole-entry replacement clears it and re-enters — a
    // reading taken later would report that recursion's view, not this call's.
    final replaced = _cache.containsKey(key);
    if (maximumEntries == null) {
      _cache[key] = entry;
    } else {
      int cacheSize = _cache.length;
      if (cacheSize == 0) {
        // Why: no bound check here. The constructor rejects a non-positive
        // [maximumEntries], so a bound is at least 1 and the first entry can
        // never exceed it. That invariant is what makes this branch correct;
        // without it, a bound of 0 would hold one entry forever.
        _cache[key] = entry;
        _first = entry;
        _last = entry;
        entry._before = null;
        entry._next = null;
        entry._key = key;
      } else {
        // Replacing an existing key: drop the old entry first, so the
        // insertion below links one entry into the chain rather than leaving
        // the previous one in it unreachable.
        if (_cache.containsKey(key)) {
          // The sole entry of the cache — restarting from empty is shorter
          // than unlinking a one-element chain, and lands in the branch above.
          if (cacheSize == 1) {
            _cache.clear();
            putEntry(key, entry);
            return replaced;
          }
          removeEntry(key);
        }
        // insert new element at the beginning
        _cache[key] = entry;
        entry._before = null;
        entry._next = _first;
        entry._key = key;
        _first!._before = entry;
        _first = entry;
        // remove one from end if maximum is exceeded
        if (_cache.length > maximumEntries!) {
          removeEntry(_last!._key!);
        }
      }
    }
    // An eviction is not a replacement: the answer is about *this* key having
    // been held, not about something having left the cache.
    return replaced;
  }

  /// The name this cache is registered under in [TomCacheManager].
  final String cacheName;

  /// How often (seconds) the deletion timer sweeps expired entries. `null`
  /// disables the timer; a value must be positive — see the constructor.
  /// Defaults to one hour.
  final int? deletionIntervalSeconds;

  /// Default lifetime (seconds) applied to a stored value when no explicit
  /// deletion time is given. `null` means entries do not expire by age; a value
  /// must be positive — see the constructor.
  final int? deleteEntriesAfterSeconds;

  /// How often (seconds) the clearance timer empties the whole cache. `null`
  /// disables it; a value must be positive — see the constructor.
  final int? clearIntervalSeconds;

  /// Upper bound on the number of entries. `null` makes the cache unbounded; a
  /// value turns on LRU eviction and must be positive — see the constructor.
  ///
  /// Defaults to [defaultMaximumEntries]: a cache is bounded unless the caller
  /// says otherwise.
  final int? maximumEntries;

  /// The bound a cache gets when the caller names none.
  ///
  /// A hundred, and the number matters less than the fact that there is one.
  /// The alternative default was no bound at all, which is safe exactly when
  /// the key space is itself bounded — routing tables, compiled templates,
  /// resolved configuration — and a leak for the life of the process when the
  /// key is a user id or a request parameter. Nothing in the API tells those
  /// apart, so the default has to be the answer that is merely *wrong* in the
  /// first case rather than *unbounded* in the second: a cache that holds a
  /// hundred routing entries instead of a hundred and twenty misses a little
  /// more, while a cache that holds every user id a long-running server ever
  /// saw is a defect nothing in the process will correct.
  ///
  /// Chosen to be large enough that a small fixed key space fits — most such
  /// caches hold a handful — and small enough that a hundred of anything is
  /// cheap to hold. A deployment that knows its key space says so, and one that
  /// knows it is bounded by its own shape passes `maximumEntries: null`.
  static const int defaultMaximumEntries = 100;

  /// Creates a named cache and installs its background timers.
  ///
  /// [deleteEntriesAfterSeconds] sets the default per-entry lifetime,
  /// [deletionIntervalSeconds] the expiry-sweep period (default 3600),
  /// [maximumEntries] the LRU bound (default [defaultMaximumEntries]), and
  /// [clearIntervalSeconds] a full-clear period.
  ///
  /// **A cache is bounded unless the caller says otherwise.** Passing
  /// `maximumEntries: null` is the opt-out and means exactly what it always
  /// meant — no bound — but it is now something a caller asks for rather than
  /// something they get by not thinking about it. An unbounded cache with no
  /// lifetime grows for the life of the process, and whether that is a leak
  /// depends on the shape of the key, which the cache cannot see.
  ///
  /// **Every one of the four must be positive or `null`**, and an
  /// [ArgumentError] naming the offending parameter is thrown otherwise. `null`
  /// is how each is switched off — no bound, no deletion sweep, no clearance
  /// sweep, no expiry by age — so zero is not a second way of saying that; it
  /// is a caller whose arithmetic produced a number the cache cannot honour.
  /// Refusing it tells that caller, instead of handing back a cache that
  /// quietly contradicts the numbers it was given:
  ///
  /// - a non-positive [maximumEntries] or [deleteEntriesAfterSeconds] makes the
  ///   cache a black hole — every store reports success and every read misses,
  ///   for want of room in the first case and because the entry is stored
  ///   already expired in the second;
  /// - a non-positive interval makes the corresponding sweep a busy loop.
  ///   [Timer.periodic] reads a zero period as "as fast as the event loop will
  ///   run it" rather than as "never", and treats a negative period as zero, so
  ///   the sweep burns a core walking the map and reports nothing.
  TomCache(
    this.cacheName, {
    this.deleteEntriesAfterSeconds,
    this.deletionIntervalSeconds = 3600,
    this.maximumEntries = defaultMaximumEntries,
    this.clearIntervalSeconds,
  }) {
    // Why: all four checks before createTimers(). A throw after a timer was
    // installed would strand it in the isolate — the construction failed, so no
    // caller holds the object through which to cancel it. createTimers builds
    // the clearance timer first, so checking inside the builders instead would
    // strand exactly that one whenever the deletion interval beside it is the
    // bad number.
    _requirePositive(
      maximumEntries,
      'maximumEntries',
      'pass null for an unbounded cache',
    );
    _requirePositive(
      deletionIntervalSeconds,
      'deletionIntervalSeconds',
      'pass null to run no deletion sweep',
    );
    _requirePositive(
      clearIntervalSeconds,
      'clearIntervalSeconds',
      'pass null to run no clearance sweep',
    );
    _requirePositive(
      deleteEntriesAfterSeconds,
      'deleteEntriesAfterSeconds',
      'pass null for entries that do not expire by age',
    );
    createTimers();
  }

  /// Refuses a configuration number the cache cannot honour.
  ///
  /// One routine for all four of the constructor's numbers, because they share
  /// the rule — positive or `null` — and differ only in what to pass instead,
  /// which [remedy] supplies. Naming the parameter is the point of the message:
  /// four numbers arrive through one constructor, so an error that reported
  /// only the value would leave the caller to guess which of its own settings
  /// produced it.
  static void _requirePositive(int? value, String name, String remedy) {
    if (value != null && value <= 0) {
      // throws-outside-family: programmer error — the cache's numbers are
      // constructor arguments, not configuration.
      throw ArgumentError.value(value, name, 'must be positive; $remedy');
    }
  }

  /// Creates a cache named after [type] (`type.toString()`), so callers can key
  /// a cache by the Dart type it holds. Parameters mirror the default
  /// constructor.
  factory TomCache.forType(
    Type type, {
    int? deleteEntriesAfterSeconds,
    int? deletionIntervalSeconds = 3600,
    int? maximumEntries = defaultMaximumEntries,
    int? clearIntervalSeconds,
  }) {
    return TomCache(
      type.toString(),
      deleteEntriesAfterSeconds: deleteEntriesAfterSeconds,
      deletionIntervalSeconds: deletionIntervalSeconds,
      maximumEntries: maximumEntries,
      clearIntervalSeconds: clearIntervalSeconds,
    );
  }

  /// Cancels any running timers and installs the deletion and/or clearance
  /// timers for which an interval is configured.
  ///
  /// Both timers are created in [Zone.root], so it does not matter where the
  /// cache was constructed or from where this is called.
  void createTimers() {
    stopTimers();
    // Why: Zone.root, not Zone.current. A cache lives as long as the process --
    // TomCacheManager holds it in a static map for the life of the isolate --
    // but nothing constrains where it is constructed, and `TomCache.forType` is
    // reached lazily from endpoint code. The endpoint pipeline runs each request
    // in its own zone to carry the principal, so a cache first needed on a
    // request path would parent both process-lifetime timers to that one
    // request's zone: answering to its error handling and teardown long after
    // the request is gone, with the zone decided by whichever caller happened to
    // arrive first rather than by anyone.
    //
    // Root rather than a zone the server installs at boot, because neither sweep
    // needs anything a zone could give it: both walk a plain map, want no
    // principal and no transaction, and an error in either belongs to the
    // process rather than to any request. Their log lines carry no request
    // logging context for the same reason. This matches
    // TomAuthorizationCache._startEviction, which made the same call.
    if (clearIntervalSeconds != null) {
      clearanceTimer = createClearanceTimer();
    }
    if (deletionIntervalSeconds != null) {
      deletionTimer = createDeletionTimer();
    }
  }

  /// Cancels the deletion and clearance timers if they are running, and clears
  /// both fields.
  ///
  /// Clearing is part of the contract, not tidiness: [deletionTimer] and
  /// [clearanceTimer] are documented as the *running* timer or `null`, so
  /// leaving a cancelled timer in place would give a caller testing
  /// `deletionTimer != null` the wrong answer for the rest of the cache's life.
  /// The cache is restartable — [createTimers] reinstalls from the intervals,
  /// which this does not touch.
  void stopTimers() {
    deletionTimer?.cancel();
    deletionTimer = null;
    clearanceTimer?.cancel();
    clearanceTimer = null;
  }

  /// The periodic timer that sweeps expired entries, or `null` when no such
  /// timer is running — either because [deletionIntervalSeconds] is unset or
  /// because [stopTimers] has since cleared it.
  Timer? deletionTimer;

  /// Builds the periodic timer that removes entries past their `deletionTime`.
  ///
  /// The timer is created in [Zone.root]; see [createTimers] for why.
  Timer createDeletionTimer() {
    return Zone.root.createPeriodicTimer(
      Duration(seconds: deletionIntervalSeconds!),
      (Timer t) {
        var now = DateTime.now();
        List<String> entriesToDelete = [];
        for (var entry in _cache.entries) {
          if (entry.value.deletionTime != null &&
              entry.value.deletionTime!.isBefore(now)) {
            entriesToDelete.add(entry.key);
          }
        }
        if (entriesToDelete.isNotEmpty) {
          tomLog.debug(
            "Deleting ${entriesToDelete.length} expired entries in cache $cacheName.",
          );
        }
        for (var key in entriesToDelete) {
          // Evict via removeEntry so the MRU chain is unlinked too; a direct
          // _cache.remove leaves dangling _next/_before/_first/_last pointers
          // in a bounded cache.
          removeEntry(key);
        }
      },
    );
  }

  /// The periodic timer that clears the whole cache, or `null` when no such
  /// timer is running — either because [clearIntervalSeconds] is unset or
  /// because [stopTimers] has since cleared it.
  Timer? clearanceTimer;

  /// Builds the periodic timer that empties the entire cache.
  ///
  /// The timer is created in [Zone.root]; see [createTimers] for why.
  Timer createClearanceTimer() {
    return Zone.root.createPeriodicTimer(
      Duration(seconds: clearIntervalSeconds!),
      (Timer t) {
        tomLog.debug(
          "Clearing cache $cacheName, deleting ${_cache.length} entries",
        );
        // Reset the MRU chain along with the backing map so a bounded cache is
        // left in a consistent empty state, not with dangling head/tail
        // pointers.
        _cache.clear();
        _first = null;
        _last = null;
      },
    );
  }

  /// Reads the value of type [T] keyed by [key] from the cache named after [T].
  /// See [fromNameCache].
  static Future<T?> fromTypeCache<T>(String key) async {
    return fromNameCache(T.toString(), key);
  }

  /// Reads the value keyed by [key] from the cache named [cacheName].
  ///
  /// Returns `null` on a miss or when the entry has expired (the expired entry
  /// is also removed), and on nothing else: a cached value is never `null`,
  /// because [toNameCache] refuses one. So `null` here means the cache does not
  /// hold [key], and a caller may treat it as the signal to compute the value
  /// and store it. Throws [TomCacheException] if the cached value is not a
  /// [T], or — in an isolate that owns no caches and cannot forward — if the
  /// named cache does not exist. In a worker isolate that does not hold the
  /// cache, the read is forwarded to the main isolate.
  ///
  /// The mismatch carries the cast's `TypeError` as its `rootException` and the
  /// cast site's trace as its `stack`; the runtime's message names the target
  /// type as it was resolved, which this method's own message cannot.
  ///
  /// A forwarded read that fails on the main isolate — because no cache of that
  /// name exists there either — throws here too, rather than answering `null`:
  /// "there is no such cache" is a configuration mistake and must not be
  /// mistaken for "the cache is empty".
  ///
  /// A forwarded read answers exactly as a local one does. The type mismatch
  /// throws on both paths, and a miss is `null` on both — neither follows from
  /// the transport, which reports a *remote throw* as a throw but has nothing to
  /// say about a value that came back intact and then failed to convert.
  static Future<T?> fromNameCache<T>(String cacheName, String key) async {
    var cache = TomCacheManager.getCache(cacheName);
    if (cache != null) {
      TomCacheEntry? entry = cache.getEntry(key);
      if (entry != null) {
        // An entry with no deletionTime never expires ("cache forever"); one
        // with a deletionTime is dropped once that instant has passed.
        if (entry.deletionTime != null &&
            !entry.deletionTime!.isAfter(DateTime.now())) {
          cache.removeEntry(key);
          return null;
        }
        tomLog.trace(
          "Found cache entry for $key ${entry.deletionTime} ${entry.value}",
        );
        try {
          return entry.value as T;
        } on TypeError catch (e, s) {
          // Narrow, because the cast is the only statement in the `try` and a
          // failed cast is the only thing it can raise. A bare `catch` would
          // relabel any other failure as a type mismatch, which is the one
          // diagnosis this site is certain of.
          //
          // The value's *type* is what explains the mismatch; its contents
          // explain nothing and are whatever the caller cached — a session
          // token as easily as a greeting. Naming the type diagnoses the fault
          // without rendering a payload into a message that is logged.
          //
          // The cause is carried rather than dropped. This is the module's only
          // failure with a genuine underlying error, and the TypeError says
          // something the message above cannot: it names the *target* type as
          // the runtime resolved it, generics and nullability included, where
          // `$T` is only as specific as the caller's type argument. `s` is the
          // trace of the cast rather than of this catch block — a wrapper that
          // keeps its cause should report where the cause arose.
          throw TomCacheException(
            "error.cache_retrieve.types_dont_match",
            "Cached value of type ${entry.value.runtimeType} "
                "is not of type $T",
            rootException: e,
            stack: s,
          );
        }
      }
    } else if (!TomCacheManager._current.useInThisIsolate) {
      // A creator-side failure arrives as a throw and leaves on its own.
      Object? cachedResult = await TomWorker.executeInCreator(
        TomCacheRetrieveMessage(cacheName, key),
      );
      if (cachedResult is T) return cachedResult;
      // A miss is the creator answering `null`, which arrives as `null`. It
      // has to be recognised here, before the mismatch below: `null is T` is
      // false for a non-nullable `T`, so the test above lets it through.
      //
      // The reading is exact because a creator-side `null` has only the one
      // meaning: a cached value is never `null` (see toNameCache).
      if (cachedResult == null) return null;
      // The value crossed intact and it is the *conversion* that failed, so
      // the transport cannot report this — only the call site can. Answering
      // `null` would say "the cache is empty" to a caller who has the wrong
      // type for an entry that is present, sending it off to recompute a value
      // it will then fail to store any more successfully than it read it.
      throw TomCacheException(
        "error.cache_retrieve.types_dont_match",
        "Cached value of type ${cachedResult.runtimeType} is not of type $T",
      );
    } else {
      throw TomCacheException(
        "error.cache_retrieve.not_found",
        "No cache with name $cacheName found.",
      );
    }
    return null;
  }

  /// Stores [value] under [key] in the cache named after [T]. See [toNameCache],
  /// including for what the answer means.
  static Future<bool> toTypeCache<T>(String key, Object value) {
    return toNameCache(T.toString(), key, value);
  }

  /// Stores [value] under [key] in the cache named [cacheName].
  ///
  /// If [deletionTime] is omitted the entry expires after the cache's
  /// [deleteEntriesAfterSeconds] (or never, if that is also unset). Passing a
  /// [TomCacheEntry] as [value] stores that entry directly (its own
  /// `deletionTime` is kept), linking it into the LRU chain like any other
  /// entry. In a worker isolate that does not hold the cache the store is
  /// forwarded to the main isolate;
  /// otherwise a missing cache throws [TomCacheException].
  ///
  /// Answers **whether the key was already held** — `true` for a replacement,
  /// `false` for an insert. The fact is free at the write site, and a caller
  /// that had to establish it otherwise would have to read first: a second
  /// operation, and from a worker isolate a second crossing. A forwarded store
  /// carries the same answer back, so it reports what a local one reports.
  ///
  /// It is *not* "something left the cache": an insert that pushes a bounded
  /// cache past its bound evicts a different key and still answers `false`,
  /// because the question is about this key.
  ///
  /// A forwarded store that fails on the main isolate throws here too. A write
  /// that reports success while the value went nowhere is the worst of the
  /// available outcomes, since the mistake only surfaces at some later read.
  ///
  /// [value] is non-nullable, so a `null` is refused — by the analyzer at an
  /// ordinary call site, and at the call itself for one arriving dynamically.
  /// It is refused for the same reason the constructor refuses a non-positive
  /// [maximumEntries]: a stored `null` is a per-entry black hole. `null` is
  /// what [fromNameCache] answers for a miss and for an expiry, so an entry
  /// holding one is a value no read can surface, while it goes on occupying a
  /// slot and counting against a bounded cache's bound. A caller with a
  /// nullable value must decide what absence means to it — skip the store, or
  /// store a sentinel of its own that a read can hand back.
  static Future<bool> toNameCache(
    String cacheName,
    String key,
    Object value, [
    DateTime? deletionTime,
  ]) async {
    var cache = TomCacheManager.getCache(cacheName);
    if (cache != null) {
      if (value is TomCacheEntry) {
        return cache.putEntry(key, value);
      } else {
        var deleteAt =
            deletionTime ??
            (cache.deleteEntriesAfterSeconds != null
                ? DateTime.now().add(
                    Duration(seconds: cache.deleteEntriesAfterSeconds!),
                  )
                : null);
        var entry = TomCacheEntry(value, deleteAt);
        return cache.putEntry(key, entry);
      }
    } else if (!TomCacheManager._current.useInThisIsolate) {
      // `== true` rather than a cast: only `null` is substituted in transit, so
      // a creator-side `false` arrives as `false` — and anything that is
      // neither is a transport fault, which reads better as "did not replace"
      // than as a crash inside a store that succeeded.
      return await TomWorker.executeInCreator(
            TomCacheStoreMessage(cacheName, key, value, deletionTime),
          ) ==
          true;
    } else {
      throw TomCacheException(
        "error.cache_store.not_found",
        "No cache with name $cacheName found.",
      );
    }
  }

  /// Removes the entry keyed by [key] from the cache named after [T]. See
  /// [removeFromNameCache], including for what the answer means.
  static Future<bool> removeFromTypeCache<T>(String key) {
    return removeFromNameCache(T.toString(), key);
  }

  /// Removes the entry keyed by [key] from the cache named [cacheName].
  ///
  /// In a worker isolate that does not hold the cache the removal is forwarded
  /// to the main isolate; otherwise a missing cache throws [TomCacheException].
  /// A forwarded removal that fails on the main isolate throws here too.
  ///
  /// Answers **whether anything was removed**. Removing a key the cache does not
  /// hold is still not an error; it is merely distinguishable now, which it was
  /// not — a caller wanting to know had to read first, and from a worker
  /// isolate that is a second crossing. A forwarded removal carries the same
  /// answer back.
  static Future<bool> removeFromNameCache(String cacheName, String key) async {
    var cache = TomCacheManager.getCache(cacheName);
    if (cache != null) {
      return cache.removeEntry(key);
    } else if (!TomCacheManager._current.useInThisIsolate) {
      // See [toNameCache] for why the answer is compared rather than cast.
      return await TomWorker.executeInCreator(
            TomCacheRemoveMessage(cacheName, key),
          ) ==
          true;
    } else {
      throw TomCacheException(
        "error.cache_remove.cache_not_found",
        "No cache with name $cacheName found.",
      );
    }
  }
}

/// Cross-isolate command that stores [value] under [key] in cache [cacheName],
/// expiring at [deletionTime]. Dispatched to the main isolate via
/// [TomWorker.executeInCreator] when a worker isolate stores into a cache it
/// does not hold.
class TomCacheStoreMessage extends TomCommand {
  String cacheName;
  String key;

  /// The value to store. Non-nullable, like [TomCache.toNameCache]'s own
  /// parameter — a `null` is refused in the worker, at the statement that made
  /// the mistake, rather than crossing to be refused where the caller cannot
  /// see it.
  Object value;

  /// The expiry the *caller* asked for, carried across the isolate boundary.
  ///
  /// It has to travel with the message and be applied on arrival, because the
  /// worker side of a forwarded store does not hold the cache and so cannot
  /// apply it itself. `null` means "no explicit expiry", which
  /// [TomCache.toNameCache] then fills from the target cache's
  /// `deleteEntriesAfterSeconds` — so dropping a non-null value here does not
  /// fail loudly, it silently substitutes the cache default and the write goes
  /// on reporting success.
  DateTime? deletionTime;

  TomCacheStoreMessage(this.cacheName, this.key, this.value, this.deletionTime);

  @override
  Future<bool> execute() async {
    tomLog.trace(
      "Storing in main isolate cache $key $cacheName ${Isolate.current.debugName}",
    );
    // The answer the local call produced, sent back rather than replaced by a
    // constant: a forwarded store reports what a local one reports.
    return await TomCache.toNameCache(cacheName, key, value, deletionTime);
  }
}

/// Cross-isolate command that removes [key] from cache [cacheName]. Dispatched
/// to the main isolate via [TomWorker.executeInCreator] when a worker isolate
/// removes from a cache it does not hold.
class TomCacheRemoveMessage extends TomCommand {
  String cacheName;
  String key;

  TomCacheRemoveMessage(this.cacheName, this.key);

  @override
  Future<bool> execute() async {
    tomLog.trace(
      "Removing from main isolate cache $key $cacheName ${Isolate.current.debugName}",
    );
    return await TomCache.removeFromNameCache(cacheName, key);
  }
}

/// Cross-isolate command that reads [key] from cache [cacheName] and returns
/// the value. Dispatched to the main isolate via [TomWorker.executeInCreator]
/// when a worker isolate reads from a cache it does not hold.
class TomCacheRetrieveMessage extends TomCommand {
  String cacheName;
  String key;

  TomCacheRetrieveMessage(this.cacheName, this.key);

  @override
  Future<Object?> execute() async {
    tomLog.trace(
      "Retrieving from main isolate cache $key $cacheName ${Isolate.current.debugName}",
    );
    return await TomCache.fromNameCache(cacheName, key);
  }
}

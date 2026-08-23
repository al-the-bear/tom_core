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
    super.userMessage, {
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

  /// The cached value.
  Object? value;

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

  /// Replaces the process-wide current manager and returns it. Useful in tests
  /// or to install a pre-populated manager.
  static TomCacheManager setCurrent(TomCacheManager manager) =>
      _current = manager;

  static var _current = TomCacheManager();

  /// Returns the cache registered under [name], or `null` if none is.
  static TomCache? getCache(String name) => _current._caches[name];

  /// Registers [cache] under its [TomCache.cacheName].
  static void addCache(TomCache cache) {
    _current._caches[cache.cacheName] = cache;
  }

  final Map<Object, TomCache> _caches = {};
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
  /// cache is bounded. A no-op when the key is absent.
  void removeEntry(String key) {
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
    }
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
  void putEntry(String key, TomCacheEntry entry) {
    if (maximumEntries == null) {
      _cache[key] = entry;
    } else {
      int cacheSize = _cache.length;
      if (cacheSize == 0) {
        _cache[key] = entry;
        _first = entry;
        _last = entry;
        entry._before = null;
        entry._next = null;
        entry._key = key;
      } else {
        TomCacheEntry? oldEntry = _cache[key];
        // Remove old entry;
        if (oldEntry != null) {
          // if this was the only entry, start with empty cache again
          if (cacheSize == 1) {
            _cache.clear();
            putEntry(key, entry);
            return;
          }
          // else remove from chain
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
          var oldLast = _last;
          if (oldLast!._before != null) {
            oldLast._before!._next = null;
            _last = oldLast._before;
          }
          _cache.remove(oldLast._key);
        }
      }
    }
  }

  /// The name this cache is registered under in [TomCacheManager].
  final String cacheName;

  /// How often (seconds) the deletion timer sweeps expired entries. `null`
  /// disables the timer. Defaults to one hour.
  final int? deletionIntervalSeconds;

  /// Default lifetime (seconds) applied to a stored value when no explicit
  /// deletion time is given. `null` means entries do not expire by age.
  final int? deleteEntriesAfterSeconds;

  /// How often (seconds) the clearance timer empties the whole cache. `null`
  /// disables it.
  final int? clearIntervalSeconds;

  /// Upper bound on the number of entries. `null` makes the cache unbounded; a
  /// value turns on LRU eviction.
  final int? maximumEntries;

  /// Creates a named cache and installs its background timers.
  ///
  /// [deleteEntriesAfterSeconds] sets the default per-entry lifetime,
  /// [deletionIntervalSeconds] the expiry-sweep period (default 3600),
  /// [maximumEntries] the LRU bound, and [clearIntervalSeconds] a full-clear
  /// period.
  TomCache(
    this.cacheName, {
    this.deleteEntriesAfterSeconds,
    this.deletionIntervalSeconds = 3600,
    this.maximumEntries,
    this.clearIntervalSeconds,
  }) {
    createTimers();
  }

  /// Creates a cache named after [type] (`type.toString()`), so callers can key
  /// a cache by the Dart type it holds. Parameters mirror the default
  /// constructor.
  factory TomCache.forType(
    Type type, {
    int? deleteEntriesAfterSeconds,
    int? deletionIntervalSeconds = 3600,
    int? maximumEntries,
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
  void createTimers() {
    stopTimers();
    if (clearIntervalSeconds != null) {
      clearanceTimer = createClearanceTimer();
    }
    if (deletionIntervalSeconds != null) {
      deletionTimer = createDeletionTimer();
    }
  }

  /// Cancels the deletion and clearance timers if they are running.
  void stopTimers() {
    deletionTimer?.cancel();
    clearanceTimer?.cancel();
  }

  /// The periodic timer that sweeps expired entries, or `null` if disabled.
  Timer? deletionTimer;

  /// Builds the periodic timer that removes entries past their `deletionTime`.
  Timer createDeletionTimer() {
    return Zone.current.createPeriodicTimer(
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

  /// The periodic timer that clears the whole cache, or `null` if disabled.
  Timer? clearanceTimer;

  /// Builds the periodic timer that empties the entire cache.
  Timer createClearanceTimer() {
    return Zone.current.createPeriodicTimer(
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
  /// is also removed). Throws [TomCacheException] if the cached value is not a
  /// [T], or — in an isolate that owns no caches and cannot forward — if the
  /// named cache does not exist. In a worker isolate that does not hold the
  /// cache, the read is forwarded to the main isolate.
  ///
  /// A forwarded read that fails on the main isolate — because no cache of that
  /// name exists there either — throws here too, rather than answering `null`:
  /// "there is no such cache" is a configuration mistake and must not be
  /// mistaken for "the cache is empty".
  ///
  /// A forwarded read answers exactly as a local one does. The type mismatch
  /// throws on both paths, and a miss is `null` on both — neither follows from
  /// the transport, which reports a *remote throw* as a throw but has nothing to
  /// say about a value that came back intact and then failed to convert, nor
  /// about a miss that reaches this side as [TomExecutor.noResult].
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
        } catch (e) {
          // The value's *type* is what explains the mismatch; its contents
          // explain nothing and are whatever the caller cached — a session
          // token as easily as a greeting. Naming the type diagnoses the fault
          // without rendering a payload into a message that is logged.
          throw TomCacheException(
            "error.cache_retrieve.types_dont_match",
            "Cached value of type ${entry.value.runtimeType} "
                "is not of type $T",
          );
        }
      }
    } else if (!TomCacheManager._current.useInThisIsolate) {
      // A creator-side failure arrives as a throw and leaves on its own.
      Object? cachedResult = await TomWorker.executeInCreator(
        TomCacheRetrieveMessage(cacheName, key),
      );
      // A miss is the creator answering `null`, and executeInCreator never
      // resolves to `null` — it substitutes this sentinel. Translating it back
      // is what makes a forwarded miss read as a miss; without it a `T` that
      // admits any object (`Object`, or the `dynamic` of an uninstantiated
      // call) accepts the sentinel as the cached value.
      if (identical(cachedResult, TomExecutor.noResult)) return null;
      if (cachedResult is T) return cachedResult;
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

  /// Stores [value] under [key] in the cache named after [T]. See [toNameCache].
  static Future<int> toTypeCache<T>(String key, Object? value) {
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
  /// otherwise a missing cache throws [TomCacheException]. Always returns `0`.
  ///
  /// A forwarded store that fails on the main isolate throws here too. A write
  /// that reports success while the value went nowhere is the worst of the
  /// available outcomes, since the mistake only surfaces at some later read.
  static Future<int> toNameCache(
    String cacheName,
    String key,
    Object? value, [
    DateTime? deletionTime,
  ]) async {
    var cache = TomCacheManager.getCache(cacheName);
    if (cache != null) {
      if (value is TomCacheEntry) {
        cache.putEntry(key, value);
      } else {
        var deleteAt =
            deletionTime ??
            (cache.deleteEntriesAfterSeconds != null
                ? DateTime.now().add(
                    Duration(seconds: cache.deleteEntriesAfterSeconds!),
                  )
                : null);
        var entry = TomCacheEntry(value, deleteAt);
        cache.putEntry(key, entry);
      }
    } else if (!TomCacheManager._current.useInThisIsolate) {
      await TomWorker.executeInCreator(
        TomCacheStoreMessage(cacheName, key, value, deletionTime),
      );
    } else {
      throw TomCacheException(
        "error.cache_store.not_found",
        "No cache with name $cacheName found.",
      );
    }
    return 0;
  }

  /// Removes the entry keyed by [key] from the cache named after [T]. See
  /// [removeFromNameCache].
  static Future<int> removeFromTypeCache<T>(String key) {
    return removeFromNameCache(T.toString(), key);
  }

  /// Removes the entry keyed by [key] from the cache named [cacheName].
  ///
  /// In a worker isolate that does not hold the cache the removal is forwarded
  /// to the main isolate; otherwise a missing cache throws [TomCacheException].
  /// A forwarded removal that fails on the main isolate throws here too.
  /// Always returns `0`.
  static Future<int> removeFromNameCache(String cacheName, String key) async {
    var cache = TomCacheManager.getCache(cacheName);
    if (cache != null) {
      cache.removeEntry(key);
    } else if (!TomCacheManager._current.useInThisIsolate) {
      await TomWorker.executeInCreator(TomCacheRemoveMessage(cacheName, key));
    } else {
      throw TomCacheException(
        "error.cache_remove.cache_not_found",
        "No cache with name $cacheName found.",
      );
    }
    return 0;
  }
}

/// Cross-isolate command that stores [value] under [key] in cache [cacheName],
/// expiring at [deletionTime]. Dispatched to the main isolate via
/// [TomWorker.executeInCreator] when a worker isolate stores into a cache it
/// does not hold.
class TomCacheStoreMessage extends TomCommand {
  String cacheName;
  String key;
  Object? value;

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
    await TomCache.toNameCache(cacheName, key, value, deletionTime);
    return true;
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
    await TomCache.removeFromNameCache(cacheName, key);
    return true;
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

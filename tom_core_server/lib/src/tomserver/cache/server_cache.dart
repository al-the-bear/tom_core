import 'dart:async';
import 'dart:isolate';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../little_things/server_exception.dart';

class TomCacheException extends TomServerException {
  TomCacheException(
    super.key,
    super.userMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

class TomCacheEntry {
  DateTime? deletionTime;

  Object? value;

  TomCacheEntry? _next;
  TomCacheEntry? _before;
  String? _key;

  TomCacheEntry(this.value, [this.deletionTime]);
}

class TomCacheManager {
  bool useInThisIsolate;

  TomCacheManager([this.useInThisIsolate = false]) {
    if (TomWorker.isMainIsolate) {
      useInThisIsolate = true;
    }
  }

  static TomCacheManager setCurrent(TomCacheManager manager) =>
      _current = manager;

  static var _current = TomCacheManager();

  static TomCache? getCache(String name) => _current._caches[name];

  static void addCache(TomCache cache) {
    _current._caches[cache.cacheName] = cache;
  }

  final Map<Object, TomCache> _caches = {};
}

class TomCache {
  TomCacheEntry? _first;
  TomCacheEntry? _last;

  final Map<String, TomCacheEntry> _cache = {};

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

  final String cacheName;
  final int? deletionIntervalSeconds;
  final int? deleteEntriesAfterSeconds;
  final int? clearIntervalSeconds;
  final int? maximumEntries;

  TomCache(
    this.cacheName, {
    this.deleteEntriesAfterSeconds,
    this.deletionIntervalSeconds = 3600,
    this.maximumEntries,
    this.clearIntervalSeconds,
  }) {
    createTimers();
  }

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

  void createTimers() {
    stopTimers();
    if (clearIntervalSeconds != null) {
      clearanceTimer = createClearanceTimer();
    }
    if (deletionIntervalSeconds != null) {
      deletionTimer = createDeletionTimer();
    }
  }

  void stopTimers() {
    deletionTimer?.cancel();
    clearanceTimer?.cancel();
  }

  Timer? deletionTimer;

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
          _cache.remove(key);
        }
      },
    );
  }

  Timer? clearanceTimer;

  Timer createClearanceTimer() {
    return Zone.current.createPeriodicTimer(
      Duration(seconds: clearIntervalSeconds!),
      (Timer t) {
        tomLog.debug(
          "Clearing cache $cacheName, deleting ${_cache.length} entries",
        );
        _cache.clear();
      },
    );
  }

  static Future<T?> fromTypeCache<T>(String key) async {
    return fromNameCache(T.toString(), key);
  }

  static Future<T?> fromNameCache<T>(String cacheName, String key) async {
    var cache = TomCacheManager.getCache(cacheName);
    if (cache != null) {
      TomCacheEntry? entry = cache.getEntry(key);
      if (entry != null && entry.deletionTime != null) {
        if (entry.deletionTime!.isAfter(DateTime.now())) {
          tomLog.trace(
            "Found cache entry for $key ${entry.deletionTime} ${entry.value}",
          );
          try {
            return entry.value as T;
          } catch (e) {
            throw TomCacheException(
              "error.cache_retrieve.types_dont_match",
              "Cached value ${entry.value} is not of type $T",
            );
          }
        } else {
          cache.removeEntry(key);
          return null;
        }
      }
    } else if (!TomCacheManager._current.useInThisIsolate) {
      Object? cachedResult = await TomWorker.executeInCreator(
        TomCacheRetrieveMessage(cacheName, key),
      );
      if (cachedResult != null && cachedResult is T) {
        return cachedResult as T;
      }
    } else {
      throw TomCacheException(
        "error.cache_retrieve.not_found",
        "No cache with name $cacheName found.",
      );
    }
    return null;
  }

  static Future<int> toTypeCache<T>(String key, Object? value) {
    return toNameCache(T.toString(), key, value);
  }

  static Future<int> toNameCache(
    String cacheName,
    String key,
    Object? value, [
    DateTime? deletionTime,
  ]) async {
    var cache = TomCacheManager.getCache(cacheName);
    if (cache != null) {
      if (value is TomCacheEntry) {
        cache._cache[key] = value;
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

  static Future<int> removeFromTypeCache<T>(String key) {
    return removeFromNameCache(T.toString(), key);
  }

  static Future<int> removeFromNameCache(String cacheName, String key) async {
    var cache = TomCacheManager.getCache(cacheName);
    if (cache != null) {
      cache.removeEntry(key);
    } else if (TomCacheManager._current.useInThisIsolate) {
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

class TomCacheStoreMessage extends TomCommand {
  String cacheName;
  String key;
  Object? value;
  DateTime? deletionTime;

  TomCacheStoreMessage(this.cacheName, this.key, this.value, this.deletionTime);

  @override
  Future<bool> execute() async {
    tomLog.trace(
      "Storing in main isolate cache $key $cacheName ${Isolate.current.debugName}",
    );
    await TomCache.toNameCache(cacheName, key, value);
    return true;
  }
}

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

// This is an embedded test function, not meant for production use.
void main() async {
  var cache = TomCache("cacheName", maximumEntries: 4);
  TomCacheManager.addCache(cache);

  assert(TomCacheManager.getCache("cacheName") != null);

  await TomCache.toNameCache("cacheName", "key1", "value1");
  await TomCache.toNameCache("cacheName", "key2", "value2");
  await TomCache.toNameCache("cacheName", "key3", "value3");

  assert(cache._first != null && cache._last != null);
  assert(cache._first!._key == "key3");
  assert(cache._last!._key == "key1");

  var cacheEntry3 = cache.getEntry("key3")!;

  assert(cacheEntry3._next!._key == "key2");
  assert(cacheEntry3._before == null);

  await TomCache.toNameCache("cacheName", "key4", "value4");

  assert(cache._first!._key == "key4");
  assert(cache._first!._next!._key == "key3");

  await TomCache.toNameCache("cacheName", "key3", "value3b");
  assert(cache._first!._key == "key3");
  assert(cache._first!.value == "value3b");
  assert(cache._first!._next!._key == "key4");
  assert(cache._cache.length == 4);

  assert(cache._last!._key == "key1");

  await TomCache.toNameCache("cacheName", "key5", "value5");
  assert(cache._last!._key == "key2");
  assert(cache._cache.length == 4);
  assert(cache._first!._key == "key5");

  await TomCache.toNameCache("cacheName", "key3", "value3c");
  assert(cache._first!._key == "key3");
  assert(cache._first!.value == "value3c");
  assert(cache._first!._next!._key == "key5");
  assert(cache._last!._key == "key2");
  assert(cache._cache.length == 4);

  await TomCache.removeFromNameCache("cacheName", "key1");
  assert(cache._first!._key == "key3");
  assert(cache._first!.value == "value3c");
  assert(cache._first!._next!._key == "key5");
  assert(cache._last!._key == "key2");
  assert(cache._cache.length == 4);

  await TomCache.removeFromNameCache("cacheName", "key2");
  assert(cache._first!._key == "key3");
  assert(cache._first!.value == "value3c");
  assert(cache._first!._next!._key == "key5");
  assert(cache._last!._key == "key4");
  assert(cache._cache.length == 3);

  await TomCache.removeFromNameCache("cacheName", "key3");
  assert(cache._first!._key == "key5");
  assert(cache._first!.value == "value5");
  assert(cache._first!._next!._key == "key4");
  assert(cache._last!._key == "key4");
  assert(cache._cache.length == 2);

  await TomCache.toNameCache("cacheName", "key4", "value4b");
  assert(cache._first!._key == "key4");
  assert(cache._first!.value == "value4b");
  assert(cache._first!._next!._key == "key5");
  assert(cache._last!._key == "key5");
  assert(cache._cache.length == 2);

  await TomCache.removeFromNameCache("cacheName", "key5");
  assert(cache._first!._key == "key4");
  assert(cache._first!.value == "value4b");
  assert(cache._first!._next == null);
  assert(cache._last!._key == "key4");
  assert(cache._cache.length == 1);

  await TomCache.toNameCache("cacheName", "key4", "value4c");
  assert(cache._first!._key == "key4");
  assert(cache._first!.value == "value4c");
  assert(cache._first!._next == null);
  assert(cache._last!._key == "key4");
  assert(cache._cache.length == 1);

  await TomCache.removeFromNameCache("cacheName", "key4");
  assert(cache._cache.isEmpty);

  await TomCache.toNameCache("cacheName", "key4", "value4d");
  assert(cache._first!._key == "key4");
  assert(cache._first!.value == "value4d");
  assert(cache._first!._next == null);
  assert(cache._last!._key == "key4");
  assert(cache._cache.length == 1);

  await TomCache.toNameCache("cacheName", "key1", "value1");
  await TomCache.toNameCache("cacheName", "key2", "value2");
  await TomCache.toNameCache("cacheName", "key3", "value3");
  assert(cache._first!._key == "key3");
  assert(cache._first!.value == "value3");
  assert(cache._first!._next!._key == "key2");
  assert(cache._last!._key == "key4");
  assert(cache._cache.length == 4);

  await TomCache.toNameCache("cacheName", "key6", "value6");
  await TomCache.toNameCache("cacheName", "key7", "value7");
  await TomCache.toNameCache("cacheName", "key8", "value8");
  assert(cache._first!._key == "key8");
  assert(cache._first!.value == "value8");
  assert(cache._first!._next!._key == "key7");
  assert(cache._last!._key == "key3");
  assert(cache._last!._before!._key == "key6");
  assert(cache._cache.length == 4);

  print("All ok");
}

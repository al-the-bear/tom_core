/// Where a device keeps its copy of server entities: the storage engine
/// contract an application implements over the database it chose, and an
/// in-memory engine.
///
/// The framework never picks the on-device database. An engine stores JSON
/// documents in named collections, keyed by id, and runs a block of reads and
/// writes as one transaction; that is all [TomLocalRepository] and
/// [TomSyncEngine] ask of it. An adapter over SQLite, Isar, Hive, IndexedDB or a
/// file is a few dozen lines.
library;

import 'dart:async';
import 'dart:convert';

import '../little_things/exception_base.dart';

/// Raised by the offline store; [key] names why (`offline.store.closed`,
/// `offline.document.not_json`, `offline.sync.transport_failed`, …).
class TomOfflineException extends TomException {
  /// Creates the exception; parameters mirror [TomException].
  TomOfflineException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
  });
}

/// A device-side document store: JSON documents in named collections.
///
/// Collections whose name starts with `_tom` are the framework's own (the
/// queue of pending changes, the sync cursors); an application's collections
/// must not use that prefix.
abstract class TomLocalStoreEngine {
  /// Creates an engine.
  const TomLocalStoreEngine();

  /// The document [id] of [collection], or `null`.
  Future<Map<String, Object?>?> read(String collection, String id);

  /// Every document of [collection], by id.
  Future<Map<String, Map<String, Object?>>> readAll(String collection);

  /// Stores [document] as [id] of [collection], replacing what was there.
  Future<void> write(
    String collection,
    String id,
    Map<String, Object?> document,
  );

  /// Removes [id] from [collection]; answers whether it was there.
  Future<bool> delete(String collection, String id);

  /// Runs [body] so that its writes happen all or not at all, and no other
  /// transaction of this engine interleaves with it. A transaction started
  /// inside [body] joins it rather than waiting for it.
  Future<T> transaction<T>(Future<T> Function() body);

  /// Releases the engine.
  Future<void> close();
}

/// [TomLocalStoreEngine] in memory: for tests, and for an application that
/// wants a session cache that does not outlive the process.
///
/// A transaction runs one at a time and works on a copy of the data, which
/// replaces the data only when the body completes — so a failing body leaves
/// nothing behind, as a database would. One started inside another joins it. Documents are stored as JSON text,
/// so a value that would not survive a real engine (a `DateTime`, an object)
/// is refused here too (`offline.document.not_json`).
class TomMemoryLocalStoreEngine extends TomLocalStoreEngine {
  static final Object _transactionKey = Object();
  Map<String, Map<String, String>> _data = {};
  Map<String, Map<String, String>>? _staged;
  Future<void> _last = Future.value();
  bool _closed = false;

  /// Creates an empty engine.
  TomMemoryLocalStoreEngine();

  Map<String, Map<String, String>> get _current => _staged ?? _data;

  @override
  Future<Map<String, Object?>?> read(String collection, String id) async {
    _requireOpen();
    final text = _current[collection]?[id];
    return text == null
        ? null
        : (jsonDecode(text) as Map).cast<String, Object?>();
  }

  @override
  Future<Map<String, Map<String, Object?>>> readAll(String collection) async {
    _requireOpen();
    return {
      for (final entry in (_current[collection] ?? const {}).entries)
        entry.key: (jsonDecode(entry.value) as Map).cast<String, Object?>(),
    };
  }

  @override
  Future<void> write(
    String collection,
    String id,
    Map<String, Object?> document,
  ) async {
    _requireOpen();
    final String text;
    try {
      text = jsonEncode(document);
    } on JsonUnsupportedObjectError catch (error, stack) {
      throw TomOfflineException(
        'offline.document.not_json',
        'A stored document must be JSON.',
        parameters: {'collection': collection, 'id': id},
        rootException: error,
        stack: stack,
      );
    }
    (_current[collection] ??= {})[id] = text;
  }

  @override
  Future<bool> delete(String collection, String id) async {
    _requireOpen();
    return _current[collection]?.remove(id) != null;
  }

  @override
  Future<T> transaction<T>(Future<T> Function() body) {
    _requireOpen();
    if (identical(Zone.current[_transactionKey], this)) return body();
    final result = Completer<T>();
    _last = _last.then((_) async {
      _staged = {
        for (final entry in _data.entries) entry.key: {...entry.value},
      };
      try {
        final value = await runZoned(body, zoneValues: {_transactionKey: this});
        _data = _staged!;
        result.complete(value);
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        _staged = null;
      }
    });
    return result.future;
  }

  @override
  Future<void> close() async => _closed = true;

  void _requireOpen() {
    if (_closed) {
      throw TomOfflineException(
        'offline.store.closed',
        'The local store has been closed.',
      );
    }
  }
}

/// The browser half of `tomOpenBrowserMedium`'s conditional import: a
/// [TomBundleMedium] over IndexedDB.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../bundle_medium.dart';
import 'browser_medium.dart' show TomBrowserStorageException;

TomBundleMedium openBrowserMediumImpl(String namespace) =>
    TomIndexedDbBundleMedium(namespace);

/// A [TomBundleMedium] whose files are records in one IndexedDB database per
/// namespace, keyed by path.
///
/// **IndexedDB rather than `localStorage`, by decision**. `localStorage` is a few megabytes per origin and holds only
/// strings, so the journal's bytes were base64-encoded (4/3 of the size) into
/// a store a single queued asset could fill — losing the very commit the
/// journal exists to keep. IndexedDB stores the bytes as they are and its
/// quota is a share of the disk. That removes the ceiling for practical
/// purposes, not in principle: a refused write still surfaces as a
/// [TomBrowserStorageException], and the sync engine says so rather than
/// dropping the commit.
///
/// **One database per namespace** (named exactly the namespace), so a clear of
/// one medium cannot reach another component's records.
///
/// **A write is atomic and durable.** Each one is a single `put` in its own
/// `readwrite` transaction opened with `durability: 'strict'`, and the future
/// completes on the transaction's `complete` — after the browser has committed
/// it — rather than on the request's `success`. A torn record cannot exist,
/// which is the [TomBundleMedium] contract the journal relies on.
class TomIndexedDbBundleMedium extends TomBundleMedium {
  TomIndexedDbBundleMedium(this.namespace);

  final String namespace;

  /// The database this medium's records live in.
  String get databaseName => namespace;

  static const _store = 'files';

  Future<web.IDBDatabase>? _database;

  Future<web.IDBDatabase> _open() => _database ??= _openDatabase();

  Future<web.IDBDatabase> _openDatabase() {
    final done = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(databaseName, 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result! as web.IDBDatabase).createObjectStore(_store);
    }).toJS;
    request.onsuccess = ((web.Event _) {
      done.complete(request.result! as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event _) {
      done.completeError(_refusal(request.error));
    }).toJS;
    return done.future;
  }

  /// Runs [op] in one transaction and answers its request's result once the
  /// transaction has **completed**.
  Future<JSAny?> _run(
    web.IDBTransactionMode mode,
    web.IDBRequest Function(web.IDBObjectStore store) op,
  ) async {
    final db = await _open();
    final tx = mode == 'readwrite'
        ? db.transaction(
            _store.toJS,
            mode,
            web.IDBTransactionOptions(durability: 'strict'),
          )
        : db.transaction(_store.toJS, mode);
    final request = op(tx.objectStore(_store));
    final done = Completer<JSAny?>();
    JSAny? result;
    request.onsuccess = ((web.Event _) {
      result = request.result;
    }).toJS;
    void fail(web.Event _) {
      if (!done.isCompleted)
        done.completeError(_refusal(tx.error ?? request.error));
    }

    tx.oncomplete = ((web.Event _) {
      if (!done.isCompleted) done.complete(result);
    }).toJS;
    tx.onerror = fail.toJS;
    tx.onabort = fail.toJS;
    return done.future;
  }

  static TomBrowserStorageException _refusal(web.DOMException? error) =>
      TomBrowserStorageException(
        error?.name ?? 'UnknownError',
        error?.message ?? 'no reason given',
      );

  @override
  Future<bool> exists(String path) async {
    final count = await _run('readonly', (store) => store.count(path.toJS));
    return (count! as JSNumber).toDartInt > 0;
  }

  @override
  Future<Uint8List> readBytes(String path) async {
    final value = await _run('readonly', (store) => store.get(path.toJS));
    if (value == null) {
      throw StateError('No such file in browser storage: $path');
    }
    // Copied out, so the bytes a caller holds are not a view onto a buffer the
    // browser may reuse.
    return Uint8List.fromList((value as JSUint8Array).toDart);
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    await _run('readwrite', (store) => store.put(bytes.toJS, path.toJS));
  }

  @override
  Future<void> delete(String path) async {
    await _run('readwrite', (store) => store.delete(path.toJS));
  }

  @override
  Future<List<String>> listFiles() async {
    final keys = await _run('readonly', (store) => store.getAllKeys());
    return [for (final key in (keys! as JSArray<JSString>).toDart) key.toDart]
      ..sort();
  }
}

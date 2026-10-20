import 'dart:typed_data';

import 'bundle_medium.dart';
import 'storage.dart';

/// A [TomBundleMedium] that remembers what was changed.
///
/// This is what lets a store that writes and deletes files on a medium
/// produce a [TomChangeset] without knowing about storage: the store writes as
/// it would to any medium, and the recorder turns that into the unit of work a
/// [TomStorage] commits. There is no second save implementation for remote
/// backends, and therefore no way for the two to drift apart.
///
/// It is also where **detachment** lives. `readBundle` hands back a lazy,
/// read-through view of the container, which cannot be a copy, so the
/// guarantee that a save touches nothing until it commits sits at the one
/// place a save passes through: writes are buffered here and `base` is never
/// mutated.
class TomRecordingBundleMedium extends TomBundleMedium {
  final TomBundleMedium base;

  /// Writes, buffered rather than passed through.
  ///
  /// This is what makes the medium **detached**: `readBundle` hands back a
  /// live, read-through view of the container — it has to, or it could not be
  /// lazy — so the promise that nothing reaches storage until `commit` is kept
  /// here, at the one place a save goes through. A write lands in this map,
  /// later reads see it, and `base` is never touched.
  ///
  /// Buffering also means [changeset] takes its bytes from memory rather than
  /// reading every written path back out of `base`, which on a remote would be
  /// a fetch per file the save had just composed.
  final Map<String, Uint8List> _writes = {};
  final Set<String> _deleted = {};

  TomRecordingBundleMedium(this.base);

  /// Everything written and deleted since construction.
  ///
  /// Synchronous, because the bytes are already here.
  TomChangeset get changeset =>
      TomChangeset(writes: {..._writes}, deletes: {..._deleted});

  @override
  Future<bool> exists(String path) async {
    if (_writes.containsKey(path)) return true;
    if (_deleted.contains(path)) return false;
    return base.exists(path);
  }

  @override
  Future<Uint8List> readBytes(String path) async {
    final written = _writes[path];
    if (written != null) return written;
    if (_deleted.contains(path)) {
      throw StateError('No such bundle file: $path');
    }
    return base.readBytes(path);
  }

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    _writes[path] = bytes;
    _deleted.remove(path);
  }

  @override
  Future<void> delete(String path) async {
    _writes.remove(path);
    _deleted.add(path);
  }

  @override
  Future<List<String>> listFiles() async => <String>{
    ...await base.listFiles(),
    ..._writes.keys,
  }.difference(_deleted).toList()..sort();
}

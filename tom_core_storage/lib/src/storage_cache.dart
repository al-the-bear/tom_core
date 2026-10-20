/// The on-disk cache: what a storage backend has already read, kept
/// where the next process can find it.
///
/// Two areas, which differ in the one property that matters:
///
/// | Area | Holds | Keyed by | Trusted |
/// | ---- | ----- | -------- | ------- |
/// | `blobs/` | file contents | content address | always — a sha is content |
/// | `meta/` | tree listings, branch heads, ETags | backend key | only once revalidated |
///
/// The cache decides nothing about freshness. A blob cannot be stale, and
/// whether a `meta/` record may be served is the backend's question — it is
/// the one holding the conditional request that answers it.
///
/// **Disposable.** Every read treats a missing, torn or undecipherable file as
/// a miss and every write failure as a write that did not happen, so deleting
/// the cache — all of it, or any file in it, at any moment — costs a re-read
/// and nothing else. What is *not* re-readable, an unpushed commit, lives in
/// the journal, which is not in this medium at all.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'package:tom_basics/diagnostics.dart';
import 'location_prefix.dart';
import 'bundle_medium.dart';

/// Where a cache cipher keeps its key (`TomAesGcmCacheCipher` in
/// `cipher.dart`): the platform secret store as the cipher needs it — a value read and written under a handle.
///
/// An application's own secret-store port satisfies it by having these two
/// members; nothing else of the store is needed here.
abstract interface class TomCacheKeyStore {
  /// The value held under [handle], or null when there is none.
  Future<String?> read(String handle);

  /// Holds [value] under [handle], replacing any value already there.
  Future<void> write(String handle, String value);
}

/// Seals and opens cache files.
///
/// A port, because the cipher needs a crypto implementation and a key from
/// the platform secret store, and the default entry point links neither. The
/// AES-GCM binding is `cipher.dart`'s `TomAesGcmCacheCipher`.
abstract interface class TomCacheCipher {
  /// [plain], sealed so that [open] returns it and nothing else does.
  Future<Uint8List> seal(Uint8List plain);

  /// The bytes [seal] was given. Throws when [sealed] is not something this
  /// cipher sealed — a different key, a truncated file, a tampered one.
  Future<Uint8List> open(Uint8List sealed);
}

/// What a device decided about its cache.
class TomCachePolicy {
  /// the desktop default: 1 GiB.
  static const desktopQuotaBytes = 1 << 30;

  /// How much `blobs/` may hold. `meta/` is outside it.
  final int quotaBytes;

  /// Seals plaintext cache files, or null when the device keeps them as they
  /// are and relies on OS-level disk encryption.
  final TomCacheCipher? cipher;

  const TomCachePolicy({this.quotaBytes = desktopQuotaBytes, this.cipher});
}

/// The two choices a device makes about its cache, as device settings state
/// them — the form a settings surface edits
/// and a root turns into a [TomCachePolicy] by supplying the cipher.
class TomCacheSettings {
  final int quotaBytes;

  /// Whether plaintext cache files are sealed.
  final bool encrypted;

  const TomCacheSettings({
    this.quotaBytes = TomCachePolicy.desktopQuotaBytes,
    this.encrypted = false,
  });

  TomCacheSettings copyWith({int? quotaBytes, bool? encrypted}) =>
      TomCacheSettings(
        quotaBytes: quotaBytes ?? this.quotaBytes,
        encrypted: encrypted ?? this.encrypted,
      );

  @override
  bool operator ==(Object other) =>
      other is TomCacheSettings &&
      other.quotaBytes == quotaBytes &&
      other.encrypted == encrypted;

  @override
  int get hashCode => Object.hash(quotaBytes, encrypted);
}

/// One blob's place in the least-recently-used order.
class _Held {
  int size;
  int usedAt;
  final bool sealed;

  /// The container locators this blob has been read or written for — what
  /// [TomStorageCache.scrubLocation] asks to tell a blob reachable only
  /// from a forgotten location from one another location still reaches.
  final Set<String> owners;

  _Held({
    required this.size,
    required this.usedAt,
    required this.sealed,
    Set<String>? owners,
  }) : owners = owners ?? {};
}

/// What [TomStorageCache.scrubLocation] removed.
class TomCacheScrub {
  /// Blobs no remaining owner reaches, deleted.
  final int blobsRemoved;

  /// `meta/` records under the scrubbed scope, deleted.
  final int metaRemoved;

  const TomCacheScrub({this.blobsRemoved = 0, this.metaRemoved = 0});

  @override
  String toString() =>
      'TomCacheScrub($blobsRemoved blobs, $metaRemoved meta records)';
}

/// The cache over one [TomBundleMedium].
///
/// The medium is the cache's own: everything in it is the cache, so clearing
/// the cache is emptying the medium and a listing of it is a listing of the
/// cache. A composition root gives it a directory, browser storage or memory,
/// as it does for the journal.
class TomStorageCache {
  static const _blobsArea = 'blobs';
  static const _metaArea = 'meta';

  /// The least-recently-used order of `blobs/`, kept beside what it orders.
  ///
  /// Rebuilt from a listing when it is missing or unreadable, so losing it
  /// costs the order and not the blobs.
  @visibleForTesting
  static const indexPath = '$_blobsArea/index.json';

  static const _sealedSuffix = '.sealed';

  /// How stale a blob's recorded use may get before a read rewrites the
  /// index. Coarse on purpose: the order only has to tell this week's blobs
  /// from last month's, and a write per read would make a cache hit cost a
  /// disk write.
  static const _useGranularity = Duration(minutes: 1);

  final TomBundleMedium medium;
  final TomDiagnostics diagnostics;
  final DateTime Function() _clock;
  final Future<TomCachePolicy> Function()? _resolvePolicy;

  TomCachePolicy? _policy;
  Map<String, _Held>? _index;
  int _heldBytes = 0;

  /// Serialises every operation that reads or writes the index, so two reads
  /// finishing together cannot each write an index missing the other's blob.
  Future<void> _tail = Future.value();

  /// [policy] is asked once, on first use, because a root builds its backends
  /// before it has read its device settings and the cache must not be used
  /// under a policy the device did not choose.
  TomStorageCache({
    required this.medium,
    Future<TomCachePolicy> Function()? policy,
    this.diagnostics = const TomNullDiagnostics(),
    DateTime Function()? clock,
  }) : _resolvePolicy = policy,
       _clock = clock ?? (() => DateTime.now().toUtc());

  /// Bytes currently held in `blobs/`, as stored.
  Future<int> get heldBytes => _serial(() async {
    await _load();
    return _heldBytes;
  });

  /// Replaces the policy while the cache is in use — a setting the user just
  /// changed.
  ///
  /// Turning sealing on or off **empties the cache**. It is the only way to
  /// make the new setting true of what is already on disk: a cache switched
  /// to sealed that kept its plaintext files would be sealed in name, and
  /// re-sealing them in place is work spent preserving something whose whole
  /// contract is that it can be thrown away. A smaller quota evicts down to
  /// itself.
  Future<void> adopt(TomCachePolicy next) => _serial(() async {
    final previous = await _policyNow();
    _policy = next;
    if ((previous.cipher == null) != (next.cipher == null)) {
      for (final path in await medium.listFiles()) {
        await _deleteQuietly(path);
      }
      _index = {};
      _heldBytes = 0;
      return;
    }
    await _load();
    if (_heldBytes > next.quotaBytes) {
      await _evict(next.quotaBytes, keep: '');
      await _writeIndex();
    }
  });

  // ── blobs/ ──────────────────────────────────────────────────────────────

  /// The content at [address], or null when the cache does not hold it.
  ///
  /// [owner] is the container locator the read is for. A hit for a container
  /// that had not reached this blob before records it as a second owner, so a
  /// blob two locations share survives either one being forgotten.
  Future<Uint8List?> readBlob(String address, {String? owner}) =>
      _serial(() async {
        final index = await _load();
        final held = index[address];
        if (held == null) return null;
        final path = _blobPath(address, sealed: held.sealed);
        try {
          final stored = await medium.readBytes(path);
          final bytes = held.sealed ? await _open(stored) : stored;
          if (bytes == null) {
            await _forget(address);
            return null;
          }
          final now = _clock().millisecondsSinceEpoch;
          final adopted = owner != null && held.owners.add(owner);
          if (now - held.usedAt >= _useGranularity.inMilliseconds) {
            held.usedAt = now;
            await _writeIndex();
          } else if (adopted) {
            await _writeIndex();
          }
          return bytes;
        } on Object {
          // Gone or unreadable: the file was deleted under us, which the
          // cache promises is harmless.
          await _forget(address);
          return null;
        }
      });

  /// Stores [bytes] as the content at [address].
  ///
  /// [opaque] content is already encrypted — a KDBX container — and is stored
  /// exactly as it is whatever the policy says: sealing it would add
  /// nothing, and leaving it alone is what makes the cached file the
  /// container.
  ///
  /// [owner] is the container locator the bytes were read or written for
  /// (see [readBlob]).
  ///
  /// Never throws. A cache that could fail a read it was only asked to
  /// remember would make reading less reliable than having no cache.
  Future<void> writeBlob(
    String address,
    Uint8List bytes, {
    bool opaque = false,
    String? owner,
  }) => _serial(() async {
    final index = await _load();
    final policy = await _policyNow();
    final existing = index[address];
    if (existing != null) {
      if (owner != null && existing.owners.add(owner)) await _writeIndex();
      return;
    }
    final cipher = opaque ? null : policy.cipher;
    try {
      final stored = cipher == null ? bytes : await cipher.seal(bytes);
      // A blob larger than the whole quota would evict everything and
      // then itself.
      if (stored.length > policy.quotaBytes) return;
      await medium.writeBytes(
        _blobPath(address, sealed: cipher != null),
        stored,
      );
      index[address] = _Held(
        size: stored.length,
        usedAt: _clock().millisecondsSinceEpoch,
        sealed: cipher != null,
        owners: {?owner},
      );
      _heldBytes += stored.length;
      await _evict(policy.quotaBytes, keep: address);
      await _writeIndex();
    } on Object catch (error) {
      _report('cache.blob.write-failed', error);
    }
  });

  // ── meta/ ───────────────────────────────────────────────────────────────

  /// The record at [key], or null. [key] is `/`-separated and each segment is
  /// encoded, so a branch named `feature/x` is one segment.
  Future<Map<String, Object?>?> readMeta(List<String> key) => _serial(() async {
    for (final sealed in [true, false]) {
      final path = _metaPath(key, sealed: sealed);
      try {
        if (!await medium.exists(path)) continue;
        final stored = await medium.readBytes(path);
        final bytes = sealed ? await _open(stored) : stored;
        if (bytes == null) continue;
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is Map<String, Object?>) return decoded;
      } on Object {
        // Unreadable is absent.
      }
    }
    return null;
  });

  /// Replaces the record at [key]. Never throws.
  Future<void> writeMeta(List<String> key, Map<String, Object?> record) =>
      _serial(() async {
        final policy = await _policyNow();
        final cipher = policy.cipher;
        try {
          final plain = Uint8List.fromList(utf8.encode(jsonEncode(record)));
          await medium.writeBytes(
            _metaPath(key, sealed: cipher != null),
            cipher == null ? plain : await cipher.seal(plain),
          );
          // One form per key: a record written plain and then sealed must not
          // leave the plain one behind to be read.
          await _deleteQuietly(_metaPath(key, sealed: cipher == null));
        } on Object catch (error) {
          _report('cache.meta.write-failed', error);
        }
      });

  /// Removes the record at [key]. Never throws.
  Future<void> removeMeta(List<String> key) => _serial(() async {
    await _deleteQuietly(_metaPath(key, sealed: true));
    await _deleteQuietly(_metaPath(key, sealed: false));
  });

  /// Removes every trace of the storage location [location].
  ///
  /// A blob is removed when, after every owner [location] covers is dropped,
  /// **no owner is left** — the blobs reachable only from the forgotten
  /// location. A blob another location also reaches stays, and so does its
  /// place in the eviction order. A blob with no recorded owner at all is
  /// removed too: its provenance is unknown, and a scrub that kept what it
  /// could not account for would not be a scrub. The cache is disposable, so
  /// the worst a wrong guess costs is a re-read.
  ///
  /// [metaScope], when given, is the `meta/` key prefix the location's backend
  /// keeps its records under (`TomStorage.cacheMetaScope`); every record
  /// under it is removed. The caller passes null when another registered
  /// location shares the scope, because those records are reachable from it
  /// too.
  ///
  /// Never throws, like every other write here.
  Future<TomCacheScrub> scrubLocation(
    String location, {
    List<String>? metaScope,
  }) => _serial(() async {
    final index = await _load();
    var blobs = 0;
    for (final address in index.keys.toList()) {
      final held = index[address]!;
      final hadOwners = held.owners.isNotEmpty;
      held.owners.removeWhere((owner) => tomLocationCovers(location, owner));
      if (hadOwners && held.owners.isNotEmpty) continue;
      await _forget(address, writeIndex: false);
      blobs++;
    }
    if (blobs > 0) await _writeIndex();

    var meta = 0;
    if (metaScope != null && metaScope.isNotEmpty) {
      final prefix =
          '$_metaArea/${metaScope.map(Uri.encodeComponent).join('/')}';
      try {
        for (final path in await medium.listFiles()) {
          if (path != '$prefix.json' &&
              path != '$prefix.json$_sealedSuffix' &&
              !path.startsWith('$prefix/')) {
            continue;
          }
          await _deleteQuietly(path);
          meta++;
        }
      } on Object catch (error) {
        _report('cache.scrub.list-failed', error);
      }
    }
    return TomCacheScrub(blobsRemoved: blobs, metaRemoved: meta);
  });

  /// Empties the cache. Loses nothing.
  Future<void> clear() => _serial(() async {
    for (final path in await medium.listFiles()) {
      await _deleteQuietly(path);
    }
    _index = {};
    _heldBytes = 0;
  });

  // ── Internals ───────────────────────────────────────────────────────────

  Future<T> _serial<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<TomCachePolicy> _policyNow() async {
    final resolved = _policy;
    if (resolved != null) return resolved;
    final resolve = _resolvePolicy;
    return _policy = resolve == null ? const TomCachePolicy() : await resolve();
  }

  Future<Uint8List?> _open(Uint8List stored) async {
    final cipher = (await _policyNow()).cipher;
    // Sealed under a policy that no longer has the cipher: unreadable, which
    // is a miss.
    if (cipher == null) return null;
    try {
      return await cipher.open(stored);
    } on Object {
      return null;
    }
  }

  static String _blobPath(String address, {required bool sealed}) {
    final safe = Uri.encodeComponent(address);
    final shard = safe.length < 2 ? safe : safe.substring(0, 2);
    return '$_blobsArea/$shard/$safe${sealed ? _sealedSuffix : ''}';
  }

  static String _metaPath(List<String> key, {required bool sealed}) =>
      '$_metaArea/${key.map(Uri.encodeComponent).join('/')}.json'
      '${sealed ? _sealedSuffix : ''}';

  /// The index, read once per process and reconciled with what is actually in
  /// `blobs/` — a file the index does not name is adopted as the oldest, and
  /// an entry with no file is dropped.
  Future<Map<String, _Held>> _load() async {
    final loaded = _index;
    if (loaded != null) return loaded;
    final index = <String, _Held>{};
    try {
      if (await medium.exists(indexPath)) {
        final decoded = jsonDecode(await medium.readString(indexPath));
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            if (value is! List || value.length < 3) continue;
            index[entry.key as String] = _Held(
              size: (value[0] as num).toInt(),
              usedAt: (value[1] as num).toInt(),
              sealed: value[2] == true,
              owners: {
                if (value.length > 3 && value[3] is List)
                  for (final owner in value[3] as List)
                    if (owner is String) owner,
              },
            );
          }
        }
      }
    } on Object {
      index.clear();
    }

    final present = <String, bool>{};
    try {
      for (final path in await medium.listFiles()) {
        if (!path.startsWith('$_blobsArea/') || path == indexPath) continue;
        var name = path.substring(path.lastIndexOf('/') + 1);
        final sealed = name.endsWith(_sealedSuffix);
        if (sealed) {
          name = name.substring(0, name.length - _sealedSuffix.length);
        }
        present[Uri.decodeComponent(name)] = sealed;
      }
    } on Object {
      // No listing, no reconciliation; reads still miss safely.
    }
    index.removeWhere((address, held) => present[address] != held.sealed);
    for (final entry in present.entries) {
      if (index.containsKey(entry.key)) continue;
      try {
        final bytes = await medium.readBytes(
          _blobPath(entry.key, sealed: entry.value),
        );
        index[entry.key] = _Held(
          size: bytes.length,
          usedAt: 0,
          sealed: entry.value,
        );
      } on Object {
        // Listed and unreadable: not held.
      }
    }
    _heldBytes = index.values.fold(0, (sum, held) => sum + held.size);
    return _index = index;
  }

  Future<void> _writeIndex() async {
    final index = _index;
    if (index == null) return;
    try {
      await medium.writeString(
        indexPath,
        jsonEncode({
          for (final entry in index.entries)
            entry.key: [
              entry.value.size,
              entry.value.usedAt,
              entry.value.sealed,
              entry.value.owners.toList()..sort(),
            ],
        }),
      );
    } on Object catch (error) {
      _report('cache.index.write-failed', error);
    }
  }

  /// Drops least-recently-used blobs until `blobs/` fits [quota]. Only
  /// `blobs/` is ever walked: `meta/` is not in the index, so it cannot be
  /// chosen.
  Future<void> _evict(int quota, {required String keep}) async {
    final index = _index!;
    if (_heldBytes <= quota) return;
    final oldestFirst = index.keys.where((a) => a != keep).toList()
      ..sort((a, b) => index[a]!.usedAt.compareTo(index[b]!.usedAt));
    var evicted = 0;
    for (final address in oldestFirst) {
      if (_heldBytes <= quota) break;
      await _forget(address, writeIndex: false);
      evicted++;
    }
    if (evicted > 0) {
      diagnostics.log(
        TomDiagnosticEvent(
          operation: 'cache.blob.evicted',
          level: TomDiagnosticLevel.debug,
          at: _clock(),
          fields: {
            'evicted': evicted,
            'heldBytes': _heldBytes,
            'quotaBytes': quota,
          },
        ),
      );
    }
  }

  Future<void> _forget(String address, {bool writeIndex = true}) async {
    final held = _index?.remove(address);
    if (held == null) return;
    _heldBytes -= held.size;
    await _deleteQuietly(_blobPath(address, sealed: held.sealed));
    if (writeIndex) await _writeIndex();
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      if (await medium.exists(path)) await medium.delete(path);
    } on Object {
      // Already gone, or not ours to remove; either way not held.
    }
  }

  void _report(String operation, Object error) {
    diagnostics.log(
      TomDiagnosticEvent(
        operation: operation,
        level: TomDiagnosticLevel.warn,
        at: _clock(),
        // The error's class and never its text: a path in a message is a
        // headline slug, and the log is what gets attached to a bug report.
        fields: {'error': error.runtimeType.toString()},
      ),
    );
  }
}

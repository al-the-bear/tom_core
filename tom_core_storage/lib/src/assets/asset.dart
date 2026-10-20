/// A content-addressed asset store: bytes filed under their SHA-256.
library;

import 'dart:collection';
import 'dart:typed_data';

import 'package:tom_basics/utilities.dart';

import '../object_ceiling.dart';

/// What an asset of one MIME type is filed as: its file [extension], and the
/// [kind] an application renders it by (an image may be a `bitmap` or a
/// `vector`, for instance).
typedef TomAssetType = ({String extension, String kind});

/// The asset types a store accepts, by MIME type.
///
/// Closed on purpose. The extension is part of a stored file's name and the
/// kind selects how the asset is used, so an unknown MIME type has no answer
/// for either — it is refused at the door rather than stored under a guess.
class TomAssetTypes {
  final Map<String, TomAssetType> byMime;

  const TomAssetTypes(this.byMime);

  /// The type of [mime], or null when this registry does not accept it.
  TomAssetType? operator [](String mime) => byMime[mime];

  /// Whether [kind] is one of the kinds this registry files.
  bool hasKind(Object? kind) => byMime.values.any((type) => type.kind == kind);
}

/// A stored asset's bytes disagree with the id they are filed under.
///
/// Distinct from an asset that is simply **absent**, which an application
/// shows as a placeholder: absence is a partial store, a mismatch is a
/// corrupted one, and reporting the second as the first would hide it.
class TomAssetCorruptException implements Exception {
  final String assetId;
  final String _actualHash;

  /// The container or file the bytes came from.
  final String where;

  const TomAssetCorruptException(this.assetId, this._actualHash, this.where);

  @override
  String toString() =>
      'Asset $assetId in $where does not match its id: its bytes hash to '
      '$_actualHash. The container is corrupted; the asset was not used.';
}

/// One content-addressed asset: bytes filed under the lowercase hex SHA-256 of
/// exactly those bytes, with the metadata derived on ingest.
///
/// The bytes are **loaded on demand**. A document opened from a lazily read
/// container must not download every asset to open, and must not download any
/// to save into the same container — an asset's file name *is* its hash, so an
/// existing file already holds exactly these bytes. Bytes are needed only to
/// render, to export, or to write into a container that lacks them.
///
/// The hash is checked the first time the bytes are read, and a mismatch is a
/// [TomAssetCorruptException]: a hard error raised by the operation that needed
/// the bytes, never a silent wrong asset.
class TomAsset {
  /// Lowercase hex SHA-256 of the exact stored bytes.
  final String id;
  final String mime;

  /// The file extension the asset is stored with.
  final String extension;

  /// How an application uses it — see [TomAssetType].
  final String kind;

  /// The stored size, from the metadata.
  final int byteCount;

  Uint8List? _bytes;
  final Future<Uint8List> Function()? _load;
  final String _where;

  TomAsset._(
    this.id,
    this.mime,
    this.extension,
    this.kind,
    this.byteCount,
    this._bytes,
    this._load,
    this._where,
  );

  /// An asset whose bytes are in hand — an ingest. Its id is computed here.
  ///
  /// Throws [ArgumentError] for a MIME type [types] does not accept.
  factory TomAsset.fromBytes(
    Uint8List bytes, {
    required String mime,
    required TomAssetTypes types,
  }) {
    final type = _typeOf(mime, types);
    return TomAsset._(
      tomSha256Hex(bytes),
      mime,
      type.extension,
      type.kind,
      bytes.length,
      Uint8List.fromList(bytes),
      null,
      'memory',
    );
  }

  /// An asset described by a container's metadata whose bytes are read when
  /// first needed; [where] names the container for the corruption error.
  factory TomAsset.stored({
    required String id,
    required String mime,
    required int byteCount,
    required TomAssetTypes types,
    required Future<Uint8List> Function() load,
    required String where,
  }) {
    final type = _typeOf(mime, types);
    return TomAsset._(
      id,
      mime,
      type.extension,
      type.kind,
      byteCount,
      null,
      load,
      where,
    );
  }

  /// An asset read from a container that already holds its bytes in memory —
  /// verified **now**, since that costs nothing more than the read already
  /// made.
  factory TomAsset.verified({
    required String id,
    required String mime,
    required Uint8List bytes,
    required TomAssetTypes types,
    required String where,
  }) {
    final actual = tomSha256Hex(bytes);
    if (actual != id) throw TomAssetCorruptException(id, actual, where);
    final type = _typeOf(mime, types);
    return TomAsset._(
      id,
      mime,
      type.extension,
      type.kind,
      bytes.length,
      bytes,
      null,
      where,
    );
  }

  static TomAssetType _typeOf(String mime, TomAssetTypes types) =>
      types[mime] ??
      (throw ArgumentError.value(
        mime,
        'mime',
        'is not an asset type (allowed: ${types.byMime.keys.join(', ')})',
      ));

  /// Whether the bytes are already in memory.
  bool get isLoaded => _bytes != null;

  /// The bytes, read and verified on first use.
  Future<Uint8List> bytes() async {
    final cached = _bytes;
    if (cached != null) return cached;
    final read = await _load!();
    final actual = tomSha256Hex(read);
    if (actual != id) throw TomAssetCorruptException(id, actual, _where);
    return _bytes = read;
  }

  /// The bytes when they are already in memory; throws otherwise. For a
  /// synchronous writer, after [TomAssetStore.materialize].
  Uint8List get loadedBytes =>
      _bytes ??
      (throw StateError('Asset $id is not loaded; materialize it first'));

  /// The metadata a container records for the asset.
  Map<String, Object?> metadata() => {
    'mime': mime,
    'kind': kind,
    'bytes': byteCount,
  };
}

/// How an asset reference resolves: live, from the history area, or not at
/// all — which an application shows as a placeholder.
sealed class TomAssetResolution {
  const TomAssetResolution();
}

class TomAssetLive extends TomAssetResolution {
  final TomAsset asset;
  const TomAssetLive(this.asset);
}

class TomAssetHistorical extends TomAssetResolution {
  final TomAsset asset;
  const TomAssetHistorical(this.asset);
}

class TomAssetMissing extends TomAssetResolution {
  final String assetId;
  const TomAssetMissing(this.assetId);
}

/// Where a container keeps assets it has removed from the live store.
typedef TomAssetHistory = Future<TomAsset?> Function(String assetId);

/// A document's content-addressed asset store.
///
/// The store holds bytes that document content may name; which assets are
/// live follows from that content — live while anything live references them
/// — and is applied when the document is **saved**, never inline. That is
/// what lets an undo work without the store taking part in it: removing the
/// reference and undoing the removal before the next save finds the asset
/// still here, and after a save, [reviveReferenced] brings it back from the
/// history area.
class TomAssetStore {
  /// The types this store accepts.
  final TomAssetTypes types;

  final Map<String, TomAsset> _assets = {};

  /// The container's history area, set by the layout that read or wrote it.
  TomAssetHistory? history;

  TomAssetStore({required this.types});

  /// Every asset currently held, keyed by id — read-only.
  late final Map<String, TomAsset> assets = UnmodifiableMapView(_assets);

  /// Stores [bytes] and returns the asset, deduplicating by content: identical
  /// bytes yield the one existing asset.
  ///
  /// [ceiling] is required because the size limit has to be met **at ingest**
  /// — a limit learned at save time costs the user the editing done in
  /// between. The refusal is [TomObjectTooLargeException], naming [what] at
  /// [locator], and nothing is stored.
  TomAsset ingest(
    Uint8List bytes, {
    required String mime,
    required TomObjectCeiling ceiling,
    String locator = 'this document',
    String what = 'This asset',
  }) {
    ceiling.enforce(bytes.length, locator: locator, what: what);
    final asset = TomAsset.fromBytes(bytes, mime: mime, types: types);
    return _assets.putIfAbsent(asset.id, () => asset);
  }

  /// Adds an asset a container described, or one arriving from another store.
  void adopt(TomAsset asset) => _assets.putIfAbsent(asset.id, () => asset);

  /// Removes [assetId] from the live store — called by a layout **after** the
  /// asset's bytes are safe in the history area.
  void retire(String assetId) => _assets.remove(assetId);

  /// Live, then the history area, then missing.
  Future<TomAssetResolution> resolve(String assetId) async {
    final live = _assets[assetId];
    if (live != null) return TomAssetLive(live);
    final old = await history?.call(assetId);
    if (old != null) return TomAssetHistorical(old);
    return TomAssetMissing(assetId);
  }

  /// Brings back from the history area every one of [referenced] this store no
  /// longer holds, and returns [referenced] as a set — the ids now live.
  ///
  /// The case is an undo across a save: the save retired an asset whose
  /// reference was gone, the undo put the reference back, and the next save
  /// must find the bytes. A layout calls this before writing.
  Future<Set<String>> reviveReferenced(Iterable<String> referenced) async {
    final live = referenced.toSet();
    for (final id in live) {
      if (_assets.containsKey(id)) continue;
      final resolved = await resolve(id);
      if (resolved is TomAssetHistorical) adopt(resolved.asset);
    }
    return live;
  }

  /// Loads the bytes of every asset in [ids] (all when null) — what a
  /// synchronous writer needs before it runs.
  Future<void> materialize([Iterable<String>? ids]) async {
    for (final id in ids ?? _assets.keys.toList()) {
      await _assets[id]?.bytes();
    }
  }

  /// Copies [ids] from [source] into this store — content moving between
  /// documents brings its bytes. A same-store call is a no-op, and an id
  /// [source] does not hold is skipped: it was already a gap there.
  void copyReferenced(TomAssetStore source, Iterable<String> ids) {
    if (identical(source, this)) return;
    for (final id in ids) {
      final asset = source._assets[id];
      if (asset != null) adopt(asset);
    }
  }

  /// Shares every asset of [other] — a clone, a merge: identical ids are
  /// identical bytes, so a union never conflicts.
  void adoptAll(TomAssetStore other) {
    for (final asset in other._assets.values) {
      adopt(asset);
    }
    history ??= other.history;
  }
}

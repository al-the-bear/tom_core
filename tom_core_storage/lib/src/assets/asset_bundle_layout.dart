/// Assets in a container of files: `assets/<id>.<ext>`, an append-only history
/// folder, and a metadata map the container's manifest carries.
library;

import '../bundle_medium.dart';
import 'asset.dart';

/// How a [TomAssetStore] is laid out in a [TomBundleMedium].
///
/// - Live assets are files `<assetsDir>/<id>.<extension>`. The file name is the
///   hash, so a file that exists already holds exactly the asset's bytes, and
///   a save writes only the assets the container lacks — which keeps it
///   proportional to the edit.
/// - Retired assets are moved to `<historyDir>/<id>.<extension>`, never
///   deleted. The history folder is **append-only**: content kept in a
///   container's history may still name a retired asset, and proving that
///   nothing does would mean reading every retained version on every save.
/// - The container's manifest carries the metadata map [save] returns and
///   [load] reads: per id, the `file` and the asset's [TomAsset.metadata].
class TomAssetBundleLayout {
  /// The types the assets are filed as.
  final TomAssetTypes types;

  /// The folder of live assets.
  final String assetsDir;

  /// The append-only folder of retired assets.
  final String historyDir;

  const TomAssetBundleLayout({
    required this.types,
    this.assetsDir = 'assets',
    this.historyDir = '.history/.assets',
  });

  /// Whether [path] is in the history folder — which a history-pruning policy
  /// must leave alone.
  bool isHistoryPath(String path) => path.startsWith('$historyDir/');

  /// Adopts into [store] every asset the manifest map [entries] describes,
  /// reading no bytes: each is read from [medium] when first needed and
  /// verified then. Sets [store]'s history to this container's.
  ///
  /// Throws [FormatException] for an entry that names no file, a MIME type
  /// [types] does not accept, a kind it does not file, or a size that is not
  /// a number.
  void load(
    TomAssetStore store,
    Map<String, Map<String, Object?>> entries,
    TomBundleMedium medium,
  ) {
    for (final entry in entries.entries) {
      final meta = entry.value;
      final file = meta['file'];
      final mime = meta['mime'];
      final bytes = meta['bytes'];
      if (file is! String || file.isEmpty) {
        throw FormatException('asset ${entry.key} names no file');
      }
      if (mime is! String || types[mime] == null) {
        throw FormatException(
          'asset ${entry.key} has MIME type "$mime", which is not an asset '
          'type',
        );
      }
      if (!types.hasKind(meta['kind'])) {
        throw FormatException(
          'asset ${entry.key} has kind "${meta['kind']}", which is not a kind '
          'this container files',
        );
      }
      if (bytes is! num) {
        throw FormatException('asset ${entry.key} states no byte count');
      }
      store.adopt(
        TomAsset.stored(
          id: entry.key,
          mime: mime,
          byteCount: bytes.toInt(),
          types: types,
          load: () => medium.readBytes(file),
          where: file,
        ),
      );
    }
    store.history = (id) => historical(medium, id);
  }

  /// Brings [assetsDir] in line with [referenced] and returns the manifest map
  /// for the container.
  ///
  /// - A referenced asset already in [assetsDir] costs nothing; one the
  ///   container lacks is written.
  /// - A referenced asset [store] no longer holds — retired by an earlier save
  ///   and named again by an undo — comes back from the history area first.
  /// - A referenced asset that is nowhere keeps its old manifest entry only if
  ///   its file is still there; otherwise it is left out, and resolves as
  ///   missing.
  /// - An asset nothing references is copied to [historyDir] and removed from
  ///   [assetsDir] — never hard-deleted. One the container never held (ingested
  ///   and dropped before any save) goes to [historyDir] too, so an undo after
  ///   this save still finds it.
  ///
  /// [previous] is the map the container's manifest held before this save.
  /// Sets [store]'s history to this container's.
  Future<Map<String, Map<String, Object?>>> save(
    TomAssetStore store,
    Iterable<String> referenced,
    TomBundleMedium medium, {
    Map<String, Map<String, Object?>> previous = const {},
  }) async {
    final live = await store.reviveReferenced(referenced);
    final written = <String, Map<String, Object?>>{};

    for (final id in (live.toList()..sort())) {
      final asset = store.assets[id];
      if (asset == null) {
        final stale = previous[id];
        if (stale != null && await medium.exists(stale['file'] as String)) {
          written[id] = stale;
        }
        continue;
      }
      final file = '$assetsDir/${asset.id}.${asset.extension}';
      if (!await medium.exists(file)) {
        await medium.writeBytes(file, await asset.bytes());
      }
      written[id] = {'file': file, ...asset.metadata()};
    }

    for (final entry in previous.entries) {
      if (live.contains(entry.key)) continue;
      final file = entry.value['file'] as String;
      if (!await medium.exists(file)) continue;
      final retired = '$historyDir/${file.split('/').last}';
      if (!await medium.exists(retired)) {
        await medium.writeBytes(retired, await medium.readBytes(file));
      }
      await medium.delete(file);
    }
    for (final asset in store.assets.values.toList()) {
      if (live.contains(asset.id)) continue;
      if (!previous.containsKey(asset.id)) {
        final retired = '$historyDir/${asset.id}.${asset.extension}';
        if (!await medium.exists(retired)) {
          await medium.writeBytes(retired, await asset.bytes());
        }
      }
      store.retire(asset.id);
    }
    store.history = (id) => historical(medium, id);
    return written;
  }

  /// A retired asset from [historyDir], or null when there is none.
  ///
  /// The file name is all the metadata there is — the manifest entry that
  /// named the file is gone with the asset — so the MIME type comes back from
  /// the extension. The bytes are still verified against the id.
  Future<TomAsset?> historical(TomBundleMedium medium, String id) async {
    for (final entry in types.byMime.entries) {
      final path = '$historyDir/$id.${entry.value.extension}';
      if (!await medium.exists(path)) continue;
      return TomAsset.verified(
        id: id,
        mime: entry.key,
        bytes: await medium.readBytes(path),
        types: types,
        where: path,
      );
    }
    return null;
  }
}

/// The application's cache of item-authorization answers: which level a
/// subject holds on an item, as the authority that keeps item authorizations
/// last answered.
///
/// An application that asks a remote authority — Tom UAM — "which level does
/// this user hold on this document?" keeps the answer for a while instead of
/// asking on every request. The answer stays good until the authority says the
/// item or the subject changed; [TomCacheInvalidator.invalidateItemAuthorization]
/// is how that news drops the answer on every node, and the webhook receiver and
/// the change-feed follower in `item_authorization_changes.dart` are how the news
/// arrives. Each entry also carries a lifetime, so a change that never arrives
/// still ages out.
///
/// The cache is a [TomCache] named [TomItemAuthorizationCache.cacheName]: it
/// lives on the main isolate, a worker's read and store are forwarded there,
/// and entries are the current tenant's. The **local copies** — a signed-in
/// user's complete levels on one item type, loaded at sign-in — live beside it
/// in [TomItemAuthorizationCache.copyCacheName], with a lifetime of their own,
/// and drop with the same changes.
library;

import 'cache_invalidation.dart';
import 'server_cache.dart';

/// One cached answer: the [level] a subject holds on an item, or `null` when
/// the authority answered that it holds none.
class TomCachedItemLevel {
  /// Creates the answer.
  const TomCachedItemLevel(this.level);

  /// The level held, or `null` for none.
  final String? level;

  @override
  bool operator ==(Object other) =>
      other is TomCachedItemLevel && other.level == level;

  @override
  int get hashCode => level.hashCode;

  @override
  String toString() => 'TomCachedItemLevel(${level ?? 'none'})';
}

/// The process-wide cache of item-authorization answers, keyed by item and
/// subject.
///
/// An item is named by its resource key, `<type>:<id>`
/// (`TomItemType.keyFor`); a subject by the id the authority names it by in
/// its change events — the user's id.
///
/// Beside the answers on single items it keeps the **accessible-item lists**:
/// the ids of the items of one type a subject reaches at a minimum level, the
/// input of a row scope. A list is dropped with every change that names its
/// subject — or no subject — on an item of its type.
///
/// And it keeps the **local copies**: for a subject and one item type, the
/// level the subject holds on every item it reaches — complete, so an item the
/// copy does not hold is one the subject does not reach. A copy is held in
/// memory on each node for the length of a working session, not persisted, and
/// dropped like a list: by every change that names its subject, or no subject,
/// on an item of its type, or names every item.
abstract final class TomItemAuthorizationCache {
  /// The name of the underlying [TomCache].
  static const String cacheName = 'tom.itemAuthorization';

  /// The name of the [TomCache] holding the local copies.
  static const String copyCacheName = 'tom.itemAuthorization.copy';

  /// How long an answer is kept when no change names it.
  static const Duration defaultTimeToLive = Duration(minutes: 5);

  /// How long a local copy is kept when no change names it: a working
  /// session, since a copy is loaded at sign-in.
  static const Duration defaultCopyTimeToLive = Duration(hours: 12);

  /// The bound on local copies — one per signed-in user and copied item type —
  /// when [install] names none.
  static const int defaultMaximumCopies = 1000;

  /// The bound on entries when [install] names none.
  static const int defaultMaximumEntries = 10000;

  /// Separates item and subject in a stored key. Neither may contain it.
  static const String _separator = '\u0000';

  /// Marks the item part of an accessible-item list: `<type>:<marker><level>`.
  static const String _listMarker = '\u0001';

  /// Marks the item part of a local copy: `<type>:<marker>`.
  static const String _copyMarker = '\u0002';

  static int _generation = 0;

  /// Counts the invalidations applied on this isolate. A reader that asked the
  /// authority stores the answer only when the count did not move meanwhile:
  /// an invalidation that arrived during the question may concern the answer,
  /// which is then already stale. Invalidations are applied on the main
  /// isolate, so the guard holds for a reader there.
  static int get generation => _generation;

  /// Registers the cache and the local-copy cache on this isolate's
  /// [TomCacheManager], replacing ones of the same names. Call it once at
  /// start-up on the main isolate.
  static void install({
    Duration timeToLive = defaultTimeToLive,
    int? maximumEntries = defaultMaximumEntries,
    Duration copyTimeToLive = defaultCopyTimeToLive,
    int? maximumCopies = defaultMaximumCopies,
  }) {
    uninstall();
    TomCacheManager.addCache(
      TomCache(
        cacheName,
        deleteEntriesAfterSeconds: timeToLive.inSeconds,
        deletionIntervalSeconds: timeToLive.inSeconds,
        maximumEntries: maximumEntries,
      ),
    );
    TomCacheManager.addCache(
      TomCache(
        copyCacheName,
        deleteEntriesAfterSeconds: copyTimeToLive.inSeconds,
        deletionIntervalSeconds: timeToLive.inSeconds,
        maximumEntries: maximumCopies,
      ),
    );
  }

  /// Removes both caches from this isolate's [TomCacheManager]. Test support.
  static void uninstall() {
    TomCacheManager.removeCache(cacheName);
    TomCacheManager.removeCache(copyCacheName);
  }

  /// The cached answer for [subject] on [item], or `null` on a miss.
  static Future<TomCachedItemLevel?> lookup(String subject, String item) =>
      TomCache.fromNameCache<TomCachedItemLevel>(
        cacheName,
        _key(item, subject),
      );

  /// Caches [level] — `null` for none — as [subject]'s answer on [item].
  static Future<void> store(String subject, String item, String? level) =>
      TomCache.toNameCache(
        cacheName,
        _key(item, subject),
        TomCachedItemLevel(level),
      );

  /// The cached ids of the items of [itemType] that [subject] reaches at
  /// [minimumLevel] or above, or `null` on a miss.
  static Future<List<String>?> lookupAccessible(
    String subject,
    String itemType,
    String minimumLevel,
  ) => TomCache.fromNameCache<List<String>>(
    cacheName,
    _key(_listItem(itemType, minimumLevel), subject),
  );

  /// Caches [itemIds] as the items of [itemType] that [subject] reaches at
  /// [minimumLevel] or above.
  static Future<void> storeAccessible(
    String subject,
    String itemType,
    String minimumLevel,
    List<String> itemIds,
  ) => TomCache.toNameCache(
    cacheName,
    _key(_listItem(itemType, minimumLevel), subject),
    List<String>.unmodifiable(itemIds),
  );

  /// [subject]'s local copy of [itemType] — item id to level, every item the
  /// subject reaches — or `null` when none is held.
  static Future<Map<String, String>?> lookupCopy(
    String subject,
    String itemType,
  ) => TomCache.fromNameCache<Map<String, String>>(
    copyCacheName,
    _key(_copyItem(itemType), subject),
  );

  /// Holds [levels] — item id to level, every item [subject] reaches — as
  /// [subject]'s local copy of [itemType].
  static Future<void> storeCopy(
    String subject,
    String itemType,
    Map<String, String> levels,
  ) => TomCache.toNameCache(
    copyCacheName,
    _key(_copyItem(itemType), subject),
    Map<String, String>.unmodifiable(levels),
  );

  /// Drops, on this node only, the answers [item] and [subject] name:
  /// [qualifiedItem] is an item key, a pattern `<type>:<prefix>*` or `*`,
  /// tenant-qualified as the invalidation carries it; a `null` [subject] is
  /// every subject. The accessible-item lists and local copies of the subject —
  /// or of every subject — for the item's type go with them, since the change
  /// may add the item to a list or take it out; `*` drops them for every type.
  /// Answers how many were dropped.
  ///
  /// [TomCacheInvalidator.apply] calls it; to reach every node, raise
  /// [TomCacheInvalidator.invalidateItemAuthorization] instead.
  static int invalidateLocally(String qualifiedItem, String? subject) {
    _generation++;
    final typePrefix = _typePrefix(qualifiedItem);
    final copyPrefix = typePrefix ?? _tenantPart(qualifiedItem);
    var dropped =
        TomCacheManager.getCache(copyCacheName)?.removeWhere(
          (stored) => _matches(
            stored,
            subject,
            (storedItem) => storedItem.startsWith(copyPrefix),
          ),
        ) ??
        0;
    final cache = TomCacheManager.getCache(cacheName);
    if (cache == null) return dropped;
    final itemPrefix = qualifiedItem.endsWith('*')
        ? qualifiedItem.substring(0, qualifiedItem.length - 1)
        : null;
    final listPrefix = typePrefix == null ? null : '$typePrefix$_listMarker';
    dropped += cache.removeWhere(
      (stored) => _matches(
        stored,
        subject,
        (storedItem) =>
            (itemPrefix == null
                ? storedItem == qualifiedItem
                : storedItem.startsWith(itemPrefix)) ||
            (listPrefix != null && storedItem.startsWith(listPrefix)),
      ),
    );
    return dropped;
  }

  /// Whether the stored key [stored] has an item [itemMatches] accepts and is
  /// [subject]'s — or [subject] is `null`, every subject.
  static bool _matches(
    String stored,
    String? subject,
    bool Function(String storedItem) itemMatches,
  ) {
    final at = stored.lastIndexOf(_separator);
    if (at < 0) return false;
    return itemMatches(stored.substring(0, at)) &&
        (subject == null || stored.substring(at + 1) == subject);
  }

  static String _listItem(String itemType, String minimumLevel) =>
      '$itemType:$_listMarker$minimumLevel';

  static String _copyItem(String itemType) => '$itemType:$_copyMarker';

  /// The `tenant:<id>/` an invalidation is qualified with, or `''`.
  static String _tenantPart(String qualifiedItem) =>
      qualifiedItem.startsWith('tenant:')
      ? qualifiedItem.substring(0, qualifiedItem.indexOf('/') + 1)
      : '';

  /// The tenant-qualified `<type>:` an item, pattern or key starts with, or
  /// `null` for `*`, which names no type.
  static String? _typePrefix(String qualifiedItem) {
    final start = qualifiedItem.startsWith('tenant:')
        ? qualifiedItem.indexOf('/') + 1
        : 0;
    final colon = qualifiedItem.indexOf(':', start);
    return colon < 0 ? null : qualifiedItem.substring(0, colon + 1);
  }

  static String _key(String item, String subject) {
    if (item.contains(_separator) || subject.contains(_separator)) {
      // throws-outside-family: programmer error — item keys and subject ids
      // are identifiers and never carry a NUL character.
      throw ArgumentError('An item key or subject id contains a NUL character');
    }
    return '$item$_separator$subject';
  }
}

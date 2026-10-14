/// The client a Tom application uses for item authorizations kept by an
/// external authority: checks and accessible-item queries answered from the
/// cache where it can, the user's sharing acts passed through, and the
/// authority's change feed followed.
///
/// The application keeps no item authorizations of its own. Each answer the
/// authority gives is cached ([TomItemAuthorizationCache]) until a change names
/// its item or subject — through the webhook or the feed
/// (`cache/item_authorization_changes.dart`) — or its lifetime ends.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../cache/cache_invalidation.dart';
import '../cache/item_authorization_cache.dart';
import '../cache/item_authorization_changes.dart';
import '../little_things/server_exception.dart';
import 'item_authority.dart';

/// A row scope over more items than the client is configured to hold. The
/// scope is refused rather than cut short, since a shortened scope hides rows
/// without saying so; an application this large keeps a local copy instead.
class TomItemAuthorizationException extends TomServerException {
  /// Creates the exception.
  TomItemAuthorizationException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.clientThrow = false,
  });
}

/// Asks the [authority] about items, caching each answer, and carries the
/// user's sharing acts to it.
///
/// A principal is the subject by its id ([TomPrincipal.id]) — the id the
/// authority names users by in its change reports. A principal that is not
/// signed in holds no level on any item.
///
/// Answers given while acting for a delegator ([actingFor] on each call) are
/// not cached: the cache is keyed by subject, and a delegation's changes do not
/// name the delegate.
class TomItemAuthorizationClient {
  /// Creates the client for [authority].
  TomItemAuthorizationClient(
    this.authority, {
    this.maximumScopeItems = defaultMaximumScopeItems,
  });

  /// The most item ids one accessible-item query may gather when nothing else
  /// is said.
  static const int defaultMaximumScopeItems = 10000;

  /// The authority asked.
  final TomItemAuthority authority;

  /// The most item ids [accessibleItemIds] gathers before refusing.
  final int maximumScopeItems;

  /// The level [principal] holds on item [itemId] of [type], or `null` for
  /// none.
  Future<String?> levelOn(
    TomPrincipal? principal,
    TomItemType type,
    String itemId, {
    String? actingFor,
  }) async =>
      (await levelsOn(principal, type, [itemId], actingFor: actingFor))[itemId];

  /// The level [principal] holds on each of [itemIds] of [type], `null` for
  /// none, keyed by item id.
  ///
  /// Cached answers are used as they are; the others are asked in calls of at
  /// most [TomItemAuthority.maximumItemsPerCheck] items. A level the type does
  /// not declare is answered as none.
  Future<Map<String, String?>> levelsOn(
    TomPrincipal? principal,
    TomItemType type,
    List<String> itemIds, {
    String? actingFor,
  }) async {
    final ids = itemIds.toSet().toList();
    final levels = <String, String?>{};
    if (principal == null || !principal.authenticated) {
      return {for (final id in ids) id: null};
    }
    final subject = principal.id;
    final cacheable = actingFor == null;
    final missing = <String>[];
    for (final id in ids) {
      final cached = cacheable
          ? await TomItemAuthorizationCache.lookup(subject, type.keyFor(id))
          : null;
      if (cached == null) {
        missing.add(id);
      } else {
        levels[id] = cached.level;
      }
    }
    for (var start = 0; start < missing.length;) {
      final end = start + TomItemAuthority.maximumItemsPerCheck;
      final chunk = missing.sublist(
        start,
        end < missing.length ? end : missing.length,
      );
      final generation = TomItemAuthorizationCache.generation;
      final answers = await authority.checkItemPermission(subject, [
        for (final id in chunk) type.keyFor(id),
      ], actingFor: actingFor);
      final fresh = generation == TomItemAuthorizationCache.generation;
      for (var i = 0; i < chunk.length; i++) {
        final answer = i < answers.length ? answers[i] : null;
        final level = answer != null && type.rankOf(answer) >= 0
            ? answer
            : null;
        levels[chunk[i]] = level;
        if (cacheable && fresh) {
          await TomItemAuthorizationCache.store(
            subject,
            type.keyFor(chunk[i]),
            level,
          );
        }
      }
      start += chunk.length;
    }
    return {for (final id in ids) id: levels[id]};
  }

  /// Whether [principal] holds [level] or a stronger one on item [itemId] of
  /// [type].
  ///
  /// Throws [ArgumentError] when [type] does not declare [level].
  Future<bool> allows(
    TomPrincipal? principal,
    TomItemType type,
    String itemId,
    String level, {
    String? actingFor,
  }) async {
    final wanted = type.rankOf(level);
    if (wanted < 0) {
      // throws-outside-family: programmer error — asking for a level the
      // vocabulary does not have is a bug, not a denial.
      throw ArgumentError.value(
        level,
        'level',
        'is not a level of ${type.name}',
      );
    }
    final held = await levelOn(principal, type, itemId, actingFor: actingFor);
    return held != null && type.rankOf(held) >= wanted;
  }

  /// The ids of the items of [type] that [principal] reaches at
  /// [minimumLevel] or above, gathered page by page and cached.
  ///
  /// Throws `error.item_authority.scope_too_large` when the authority
  /// answers more than [maximumScopeItems] ids, and [ArgumentError] when
  /// [type] does not declare [minimumLevel].
  Future<List<String>> accessibleItemIds(
    TomPrincipal? principal,
    TomItemType type, {
    required String minimumLevel,
    String? actingFor,
  }) async {
    if (type.rankOf(minimumLevel) < 0) {
      // throws-outside-family: programmer error — see [allows].
      throw ArgumentError.value(
        minimumLevel,
        'minimumLevel',
        'is not a level of ${type.name}',
      );
    }
    if (principal == null || !principal.authenticated) return const [];
    final subject = principal.id;
    final cacheable = actingFor == null;
    if (cacheable) {
      final cached = await TomItemAuthorizationCache.lookupAccessible(
        subject,
        type.name,
        minimumLevel,
      );
      if (cached != null) return cached;
    }
    final generation = TomItemAuthorizationCache.generation;
    final ids = <String>[];
    String? page;
    do {
      final answer = await authority.queryAccessibleItems(
        subject,
        type.name,
        minimumLevel: minimumLevel,
        actingFor: actingFor,
        page: page,
      );
      ids.addAll(answer.itemIds);
      if (ids.length > maximumScopeItems) {
        throw TomItemAuthorizationException(
          'error.item_authority.scope_too_large',
          'More items are accessible than a row scope may hold.',
          parameters: {'itemType': type.name, 'maximum': maximumScopeItems},
        );
      }
      page = answer.nextPage;
    } while (page != null && page.isNotEmpty);
    if (cacheable && generation == TomItemAuthorizationCache.generation) {
      await TomItemAuthorizationCache.storeAccessible(
        subject,
        type.name,
        minimumLevel,
        ids,
      );
    }
    return ids;
  }

  /// Shares an item as the user [userToken] belongs to, and drops the
  /// subject's cached answers on it on every node.
  Future<TomItemAuthorizationRecord> share(
    String userToken,
    TomItemShareRequest request,
  ) async {
    final record = await authority.shareItem(userToken, request);
    await _invalidate(record);
    return record;
  }

  /// Changes [authorization]'s level or end of validity as the user
  /// [userToken] belongs to, and drops the cached answers it affects.
  Future<TomItemAuthorizationRecord> change(
    String userToken,
    TomItemAuthorizationRecord authorization, {
    String? level,
    DateTime? validTo,
  }) async {
    final record = await authority.changeItemAuthorization(
      userToken,
      authorization.id,
      level: level,
      validTo: validTo,
    );
    await _invalidate(record);
    return record;
  }

  /// Revokes [authorization] — or leaves it, when the user is its subject —
  /// as the user [userToken] belongs to, and drops the cached answers it
  /// affects, so the subject loses the access on this node at once and on
  /// every other within the invalidation channel's bound.
  Future<void> revoke(
    String userToken,
    TomItemAuthorizationRecord authorization,
  ) async {
    await authority.revokeItemAuthorization(userToken, authorization.id);
    await _invalidate(authorization);
  }

  /// One page of what was shared with the user [userToken] belongs to. Not
  /// cached: it is a list the user reads, not a decision.
  Future<TomSharedItemsPage> sharedWithMe(
    String userToken, {
    String? itemType,
    String? page,
  }) => authority.listItemsSharedWithMe(
    userToken,
    itemType: itemType,
    page: page,
  );

  /// A follower of the authority's change feed, which drops the cached answers
  /// each change names; start it once per tenant at start-up.
  TomItemAuthorizationFeedFollower followChanges({
    Duration pollInterval =
        TomItemAuthorizationFeedFollower.defaultPollInterval,
    String? tenantId,
  }) => TomItemAuthorizationFeedFollower(
    authority.readItemAuthorizationChanges,
    pollInterval: pollInterval,
    tenantId: tenantId,
  );

  Future<void> _invalidate(TomItemAuthorizationRecord record) =>
      TomCacheInvalidator.invalidateItemAuthorization(
        record.item,
        subject: record.invalidationSubject,
      );
}

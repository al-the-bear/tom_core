/// The port to an external item-authorization authority — Tom UAM — and the
/// values that cross it.
///
/// [TomItemAuthority] names the operations a Tom application needs from the
/// authority that keeps who may view, comment on or edit which of its items.
/// It is transport-neutral: an adapter speaks the authority's protocol, and a
/// test speaks to an in-memory fake. Items cross it as resource keys,
/// `<type>:<id>` (`TomItemType.keyFor`), and levels as the level names of
/// their type; `null` is "no level".
///
/// Two kinds of call cross it, with different credentials:
///
/// - **the application's own questions** — checks, the accessible-item query,
///   the change feed — are asked with the application's credentials and name
///   the principal they are about;
/// - **the user's acts** — sharing, changing, revoking, listing what was shared
///   with them — carry the signed-in user's token, exchanged for the
///   authority's item interface, so that the decision and its audit entry are
///   the user's.
///
/// An adapter in a multi-tenant deployment reads the tenant from
/// `TomTenantContext` and uses that tenant's credentials.
library;

import '../cache/item_authorization_changes.dart';

/// Whom an item is shared with: one user, or a group of users.
enum TomShareSubjectKind {
  /// One user.
  user,

  /// A group; every member reaches the item.
  group,
}

/// One item authorization as the authority keeps it: [subjectKind]
/// [subjectId] holds [level] on [item], from [validFrom] to [validTo].
class TomItemAuthorizationRecord {
  /// Creates the record.
  const TomItemAuthorizationRecord({
    required this.id,
    required this.item,
    required this.subjectKind,
    required this.subjectId,
    required this.level,
    this.validFrom,
    this.validTo,
  });

  /// The authorization's id at the authority.
  final String id;

  /// The item key, `<type>:<id>`.
  final String item;

  /// Whether [subjectId] is a user or a group.
  final TomShareSubjectKind subjectKind;

  /// The user or group.
  final String subjectId;

  /// The level, a level name of the item's type.
  final String level;

  /// When the authorization starts, or `null` for at once.
  final DateTime? validFrom;

  /// When it ends, or `null` for never.
  final DateTime? validTo;

  /// The subject an invalidation of this authorization names: the user, or
  /// `null` for a group, whose members the application cannot list.
  String? get invalidationSubject =>
      subjectKind == TomShareSubjectKind.user ? subjectId : null;

  @override
  String toString() =>
      'TomItemAuthorizationRecord($id: ${subjectKind.name} $subjectId '
      '$level on $item)';
}

/// What a user asks for when sharing [item]: [level] for [subjectKind]
/// [subjectId], optionally only from [validFrom] to [validTo].
class TomItemShareRequest {
  /// Creates the request.
  const TomItemShareRequest({
    required this.item,
    required this.subjectKind,
    required this.subjectId,
    required this.level,
    this.validFrom,
    this.validTo,
    this.idempotencyKey,
  });

  /// The item key, `<type>:<id>`.
  final String item;

  /// Whether [subjectId] is a user or a group.
  final TomShareSubjectKind subjectKind;

  /// The user or group.
  final String subjectId;

  /// The level to give.
  final String level;

  /// When the authorization starts, or `null` for at once.
  final DateTime? validFrom;

  /// When it ends, or `null` for never.
  final DateTime? validTo;

  /// Makes a repeated request — a retry after a lost answer — share once.
  final String? idempotencyKey;
}

/// One page of the items of a type a principal reaches.
class TomAccessibleItemsPage {
  /// Creates the page.
  const TomAccessibleItemsPage({required this.itemIds, this.nextPage});

  /// The application's ids of the items (the part after `<type>:`).
  final List<String> itemIds;

  /// The token of the next page, or `null` on the last.
  final String? nextPage;
}

/// One page of the authorizations shared with the signed-in user.
class TomSharedItemsPage {
  /// Creates the page.
  const TomSharedItemsPage({required this.authorizations, this.nextPage});

  /// The authorizations, each naming its item, level and validity.
  final List<TomItemAuthorizationRecord> authorizations;

  /// The token of the next page, or `null` on the last.
  final String? nextPage;
}

/// The operations a Tom application needs from its item-authorization
/// authority. See the library comment for the credentials each kind uses.
abstract interface class TomItemAuthority {
  /// The most items one [checkItemPermission] call may name.
  static const int maximumItemsPerCheck = 100;

  /// The level [principalId] holds on each of [items] — at most
  /// [maximumItemsPerCheck] — in request order; `null` where it holds none or
  /// the item is unknown. With [actingFor], the levels the principal reaches
  /// acting for that delegator.
  Future<List<String?>> checkItemPermission(
    String principalId,
    List<String> items, {
    String? actingFor,
  });

  /// One page of the ids of the items of [itemType] that [principalId]
  /// reaches at [minimumLevel] or above — through ownership, direct and group
  /// authorizations and the item's ancestors; [page] is the previous page's
  /// token.
  Future<TomAccessibleItemsPage> queryAccessibleItems(
    String principalId,
    String itemType, {
    required String minimumLevel,
    String? actingFor,
    String? page,
  });

  /// The changes since [cursor] — `null` for the current position. Throws
  /// `TomItemAuthorizationFeedExpiredException` for a cursor the feed no longer
  /// holds.
  Future<TomItemAuthorizationChangePage> readItemAuthorizationChanges(
    String? cursor,
  );

  /// Shares an item as the user [userToken] belongs to.
  Future<TomItemAuthorizationRecord> shareItem(
    String userToken,
    TomItemShareRequest request,
  );

  /// Changes the level or the end of validity of authorization
  /// [authorizationId], as the user [userToken] belongs to.
  Future<TomItemAuthorizationRecord> changeItemAuthorization(
    String userToken,
    String authorizationId, {
    String? level,
    DateTime? validTo,
  });

  /// Revokes authorization [authorizationId] — or leaves it, when the user is
  /// its subject — as the user [userToken] belongs to.
  Future<void> revokeItemAuthorization(
    String userToken,
    String authorizationId,
  );

  /// One page of the authorizations shared with the user [userToken] belongs
  /// to, optionally of one [itemType]; [page] is the previous page's token.
  Future<TomSharedItemsPage> listItemsSharedWithMe(
    String userToken, {
    String? itemType,
    String? page,
  });
}

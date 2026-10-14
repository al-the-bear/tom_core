/// Executable example for the item_authorization module of `tom_core_server`.
///
/// A small in-memory authority plays Tom UAM: it knows who owns which document
/// and who it was shared with, and writes every change to a change feed. The
/// example asks it through [TomItemAuthorizationClient] — a level, a check by
/// the type's order, the same check answered from the cache — shares and
/// revokes for the signed-in user, feeds the row scope from it, and follows the
/// feed when another application revokes a share.
///
/// Run with `dart run example/item_authorization/item_authorization_example.dart`.
/// Every step checks its own result and the run fails when one does not hold,
/// so a green run is a verification and not just a transcript.
///
/// The behaviour shown here is pinned by
/// `test/item_authorization_client_test.dart`.
library;

import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// Owners and direct user shares, the change feed, and a call counter.
class _Authority implements TomItemAuthority {
  final Map<String, String> owners = {'document:plan': 'alice'};
  final Map<String, TomItemAuthorizationRecord> shares = {};
  final List<TomItemAuthorizationChange> feed = [];
  int checks = 0;
  var _ids = 0;

  String? _level(String user, String item) {
    if (owners[item] == user) return 'manage';
    for (final share in shares.values) {
      if (share.item == item && share.subjectId == user) return share.level;
    }
    return null;
  }

  @override
  Future<List<String?>> checkItemPermission(
    String principalId,
    List<String> items, {
    String? actingFor,
  }) async {
    checks++;
    return [for (final item in items) _level(principalId, item)];
  }

  @override
  Future<TomAccessibleItemsPage> queryAccessibleItems(
    String principalId,
    String itemType, {
    required String minimumLevel,
    String? actingFor,
    String? page,
  }) async {
    final type = TomItemTypeRegistry.lookup(itemType)!;
    final items = {...owners.keys, for (final s in shares.values) s.item};
    return TomAccessibleItemsPage(
      itemIds: [
        for (final item in items)
          if (_level(principalId, item) case final held?
              when type.rankOf(held) >= type.rankOf(minimumLevel))
            item.substring(itemType.length + 1),
      ],
    );
  }

  @override
  Future<TomItemAuthorizationChangePage> readItemAuthorizationChanges(
    String? cursor,
  ) async {
    final from = cursor == null ? feed.length : int.parse(cursor);
    return TomItemAuthorizationChangePage(
      changes: feed.sublist(from),
      nextCursor: '${feed.length}',
    );
  }

  @override
  Future<TomItemAuthorizationRecord> shareItem(
    String userToken,
    TomItemShareRequest request,
  ) async {
    final record = TomItemAuthorizationRecord(
      id: 'share-${++_ids}',
      item: request.item,
      subjectKind: request.subjectKind,
      subjectId: request.subjectId,
      level: request.level,
    );
    shares[record.id] = record;
    feed.add(
      TomItemAuthorizationChange(record.item, subject: record.subjectId),
    );
    return record;
  }

  @override
  Future<TomItemAuthorizationRecord> changeItemAuthorization(
    String userToken,
    String authorizationId, {
    String? level,
    DateTime? validTo,
  }) async => throw UnimplementedError('not used by this example');

  @override
  Future<void> revokeItemAuthorization(
    String userToken,
    String authorizationId,
  ) async {
    final record = shares.remove(authorizationId)!;
    feed.add(
      TomItemAuthorizationChange(record.item, subject: record.subjectId),
    );
  }

  @override
  Future<TomSharedItemsPage> listItemsSharedWithMe(
    String userToken, {
    String? itemType,
    String? page,
  }) async => const TomSharedItemsPage(authorizations: []);
}

TomPrincipal _user(String id) => TomPrincipal(
  authenticated: true,
  user: TomUser(id: id, username: id),
);

Future<void> main() async {
  final document = TomItemType.standard('document');
  TomItemTypeRegistry.register(document);
  TomItemAuthorizationCache.install();
  final authority = _Authority();
  final client = TomItemAuthorizationClient(authority);
  final source = TomItemAuthorityScopeSource(client, [document])..install();
  final alice = _user('alice');
  final bob = _user('bob');

  // 1. The owner holds the strongest level; anyone else holds none.
  final owner = await client.levelOn(alice, document, 'plan');
  final other = await client.levelOn(bob, document, 'plan');
  print('1. alice / bob on the plan    => $owner / $other');
  check(owner == 'manage' && other == null, 'only the owner holds a level');

  // 2. Alice shares the plan with Bob to comment on, with her own token.
  final share = await client.share(
    'alice-token',
    TomItemShareRequest(
      item: document.keyFor('plan'),
      subjectKind: TomShareSubjectKind.user,
      subjectId: 'bob',
      level: 'comment',
    ),
  );
  final shared = await client.levelOn(bob, document, 'plan');
  print('2. bob after the share        => $shared');
  check(
    shared == 'comment',
    'the share drops the cached "none" and Bob reaches comment',
  );

  // 3. Checks compare by the type's order.
  final mayComment = await client.allows(bob, document, 'plan', 'comment');
  final mayEdit = await client.allows(bob, document, 'plan', 'edit');
  print('3. bob may comment / edit     => $mayComment / $mayEdit');
  check(mayComment && !mayEdit, 'comment is enough to comment and not to edit');

  // 4. A repeated question is answered from the cache.
  final asked = authority.checks;
  await client.levelOn(bob, document, 'plan');
  print('4. calls for a repeated check => ${authority.checks - asked}');
  check(authority.checks == asked, 'the cache answers');

  // 5. The row scope shows Bob what was shared with him.
  final readable = await source.readableResourceKeys(bob);
  final writable = await source.writableResourceKeys(bob);
  print('5. bob reads / writes rows    => $readable / $writable');
  check(
    readable.length == 1 &&
        readable.single == 'document:plan' &&
        writable.isEmpty,
    'comment admits the row to queries but not to writes',
  );

  // 6. Revoking drops Bob's access at once.
  await client.revoke('alice-token', share);
  final revoked = await client.levelOn(bob, document, 'plan');
  final rowsAfter = await source.readableResourceKeys(bob);
  print('6. bob after the revocation   => $revoked, rows $rowsAfter');
  check(revoked == null && rowsAfter.isEmpty, 'the revocation is in effect');

  // 7. A change made elsewhere reaches the cache through the change feed.
  final follower = client.followChanges();
  await follower.poll();
  final again = await client.share(
    'alice-token',
    TomItemShareRequest(
      item: document.keyFor('plan'),
      subjectKind: TomShareSubjectKind.user,
      subjectId: 'bob',
      level: 'view',
    ),
  );
  await follower.poll(); // the share's own change, already applied here
  final viewing = await client.levelOn(bob, document, 'plan');
  check(viewing == 'view', 'the new share is cached');
  authority.shares.remove(again.id);
  authority.feed.add(
    const TomItemAuthorizationChange('document:plan', subject: 'bob'),
  );
  final applied = await follower.poll();
  final afterFeed = await client.levelOn(bob, document, 'plan');
  print('7. revoked elsewhere, polled  => $applied change, bob $afterFeed');
  check(applied == 1 && afterFeed == null, 'the feed drops the cached answer');

  TomItemAuthorizationCache.uninstall();
  TomDataScopeRegistry.resourceScopeSource = null;
}

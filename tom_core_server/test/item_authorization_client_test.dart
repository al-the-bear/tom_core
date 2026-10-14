/// The item-authorization client and the row scope it feeds, against a fake
/// authority that keeps owners, groups and authorizations the way Tom UAM
/// does: answers are cached, asked in chunks and pages, dropped when a change
/// names them, and the row scope shows what the principal owns and what was
/// shared with it.
library;

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// An in-memory authority. Users act by token (`token-<user>`); every change
/// is written to its change feed.
class _FakeUam implements TomItemAuthority {
  _FakeUam(this.types);

  final Map<String, TomItemType> types;
  final Map<String, String> owners = {}; // item key → owner
  final Map<String, Set<String>> groups = {}; // group → members
  final Map<String, TomItemAuthorizationRecord> authorizations = {};
  final List<TomItemAuthorizationChange> feed = [];
  final List<List<String>> checkCalls = [];
  int queryCalls = 0;
  int pageSize = 2;
  Future<void> Function()? duringCheck;
  var _ids = 0;

  TomItemType _typeOf(String item) => types[item.split(':').first]!;

  String? level(String principal, String item, {String? actingFor}) {
    final who = actingFor ?? principal;
    final type = _typeOf(item);
    if (owners[item] == who) return type.levels.last;
    String? best;
    for (final auth in authorizations.values) {
      if (auth.item != item) continue;
      final reaches = auth.subjectKind == TomShareSubjectKind.user
          ? auth.subjectId == who
          : (groups[auth.subjectId] ?? const {}).contains(who);
      if (!reaches) continue;
      best = best == null ? auth.level : type.stronger(best, auth.level);
    }
    return best;
  }

  @override
  Future<List<String?>> checkItemPermission(
    String principalId,
    List<String> items, {
    String? actingFor,
  }) async {
    expect(
      items.length,
      lessThanOrEqualTo(TomItemAuthority.maximumItemsPerCheck),
    );
    checkCalls.add(items);
    final answers = [
      for (final item in items) level(principalId, item, actingFor: actingFor),
    ];
    await duringCheck?.call();
    return answers;
  }

  @override
  Future<TomAccessibleItemsPage> queryAccessibleItems(
    String principalId,
    String itemType, {
    required String minimumLevel,
    String? actingFor,
    String? page,
  }) async {
    queryCalls++;
    final type = types[itemType]!;
    final known = {
      ...owners.keys,
      for (final a in authorizations.values) a.item,
    }.where((item) => item.startsWith('$itemType:')).toList()..sort();
    final reached = [
      for (final item in known)
        if (level(principalId, item, actingFor: actingFor) case final held?
            when type.rankOf(held) >= type.rankOf(minimumLevel))
          item.substring(itemType.length + 1),
    ];
    final from = int.parse(page ?? '0');
    final to = (from + pageSize).clamp(0, reached.length);
    return TomAccessibleItemsPage(
      itemIds: reached.sublist(from, to),
      nextPage: to < reached.length ? '$to' : null,
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

  String _user(String token) => token.substring('token-'.length);

  /// What Tom UAM does when anyone — this application or another — changes
  /// an authorization: it is recorded and reported on the feed.
  TomItemAuthorizationRecord put(TomItemAuthorizationRecord record) {
    authorizations[record.id] = record;
    feed.add(
      TomItemAuthorizationChange(
        record.item,
        subject: record.invalidationSubject,
      ),
    );
    return record;
  }

  void remove(String id) {
    final record = authorizations.remove(id)!;
    feed.add(
      TomItemAuthorizationChange(
        record.item,
        subject: record.invalidationSubject,
      ),
    );
  }

  @override
  Future<TomItemAuthorizationRecord> shareItem(
    String userToken,
    TomItemShareRequest request,
  ) async {
    final sharer = _user(userToken);
    final own = level(sharer, request.item);
    final type = _typeOf(request.item);
    if (own == null || type.rankOf(own) < type.rankOf(request.level)) {
      throw StateError('UAM-403-ACCESS-DENIED');
    }
    return put(
      TomItemAuthorizationRecord(
        id: 'auth-${++_ids}',
        item: request.item,
        subjectKind: request.subjectKind,
        subjectId: request.subjectId,
        level: request.level,
      ),
    );
  }

  @override
  Future<TomItemAuthorizationRecord> changeItemAuthorization(
    String userToken,
    String authorizationId, {
    String? level,
    DateTime? validTo,
  }) async {
    final old = authorizations[authorizationId]!;
    return put(
      TomItemAuthorizationRecord(
        id: old.id,
        item: old.item,
        subjectKind: old.subjectKind,
        subjectId: old.subjectId,
        level: level ?? old.level,
        validTo: validTo ?? old.validTo,
      ),
    );
  }

  @override
  Future<void> revokeItemAuthorization(
    String userToken,
    String authorizationId,
  ) async => remove(authorizationId);

  @override
  Future<TomSharedItemsPage> listItemsSharedWithMe(
    String userToken, {
    String? itemType,
    String? page,
  }) async {
    final me = _user(userToken);
    return TomSharedItemsPage(
      authorizations: [
        for (final auth in authorizations.values)
          if (auth.subjectId == me &&
              (itemType == null || auth.item.startsWith('$itemType:')))
            auth,
      ],
    );
  }
}

TomPrincipal _user(String id, {bool authenticated = true}) => TomPrincipal(
  authenticated: authenticated,
  user: TomUser(id: id, username: id),
);

void main() {
  final document = TomItemType.standard('document');
  final report = TomItemType('report', ['see'], {'see': TomAuthState.read});
  late _FakeUam uam;
  late TomItemAuthorizationClient client;
  final alice = _user('alice');
  final bob = _user('bob');

  setUp(() async {
    await TomCacheInvalidator.reset();
    TomItemAuthorizationCache.install();
    uam = _FakeUam({'document': document, 'report': report});
    client = TomItemAuthorizationClient(uam);
    uam.owners['document:a1'] = 'alice';
    uam.owners['document:a2'] = 'alice';
    uam.owners['document:b1'] = 'bob';
  });

  tearDown(() {
    TomItemAuthorizationCache.uninstall();
    TomDataScopeRegistry.resourceScopeSource = null;
  });

  group('checks', () {
    test('ask the authority once, then answer from the cache', () async {
      expect(await client.levelOn(alice, document, 'a1'), 'manage');
      expect(await client.levelOn(bob, document, 'a1'), isNull);
      expect(await client.levelOn(alice, document, 'a1'), 'manage');
      expect(await client.levelOn(bob, document, 'a1'), isNull);
      expect(uam.checkCalls, hasLength(2));
    });

    test('ask only for what is not cached, at most 100 items a call', () async {
      await client.levelOn(alice, document, 'a1');
      uam.checkCalls.clear();
      final ids = ['a1', for (var i = 0; i < 150; i++) 'x$i'];
      final levels = await client.levelsOn(alice, document, ids);
      expect(levels['a1'], 'manage');
      expect(levels['x7'], isNull);
      expect(levels.keys, ids);
      expect(uam.checkCalls.map((call) => call.length), [100, 50]);
    });

    test('compare levels by the type\'s order', () async {
      uam.put(
        const TomItemAuthorizationRecord(
          id: 'given',
          item: 'document:a1',
          subjectKind: TomShareSubjectKind.user,
          subjectId: 'bob',
          level: 'comment',
        ),
      );
      expect(await client.allows(bob, document, 'a1', 'view'), isTrue);
      expect(await client.allows(bob, document, 'a1', 'comment'), isTrue);
      expect(await client.allows(bob, document, 'a1', 'edit'), isFalse);
      expect(
        () => client.allows(bob, document, 'a1', 'approve'),
        throwsArgumentError,
      );
    });

    test('a level the type does not declare is none', () async {
      uam.owners.remove('document:a1');
      uam.put(
        const TomItemAuthorizationRecord(
          id: 'odd',
          item: 'document:a1',
          subjectKind: TomShareSubjectKind.user,
          subjectId: 'bob',
          level: 'approve',
        ),
      );
      expect(await client.levelOn(bob, document, 'a1'), isNull);
    });

    test(
      'a principal that is not signed in reaches nothing, unasked',
      () async {
        expect(
          await client.levelOn(
            _user('alice', authenticated: false),
            document,
            'a1',
          ),
          isNull,
        );
        expect(await client.levelOn(null, document, 'a1'), isNull);
        expect(uam.checkCalls, isEmpty);
      },
    );

    test('acting for a delegator is asked every time', () async {
      expect(
        await client.levelOn(bob, document, 'a1', actingFor: 'alice'),
        'manage',
      );
      expect(
        await client.levelOn(bob, document, 'a1', actingFor: 'alice'),
        'manage',
      );
      expect(uam.checkCalls, hasLength(2));
      expect(await client.levelOn(bob, document, 'a1'), isNull);
    });

    test('an answer overtaken by a change is not cached', () async {
      uam.duringCheck = () async {
        uam.duringCheck = null;
        await TomCacheInvalidator.invalidateItemAuthorization('document:a1');
      };
      await client.levelOn(alice, document, 'a1');
      await client.levelOn(alice, document, 'a1');
      expect(uam.checkCalls, hasLength(2));
    });
  });

  group('a revoked share stops granting', () {
    late TomItemAuthorizationRecord shared;

    setUp(() async {
      shared = await client.share(
        'token-alice',
        const TomItemShareRequest(
          item: 'document:a1',
          subjectKind: TomShareSubjectKind.user,
          subjectId: 'bob',
          level: 'edit',
        ),
      );
      expect(await client.levelOn(bob, document, 'a1'), 'edit');
    });

    test('at once, when revoked through this client', () async {
      await client.revoke('token-alice', shared);
      expect(await client.levelOn(bob, document, 'a1'), isNull);
    });

    test('when changed through this client', () async {
      await client.change('token-alice', shared, level: 'view');
      expect(await client.levelOn(bob, document, 'a1'), 'view');
    });

    test(
      'at the next poll, when revoked elsewhere and the feed reports it',
      () async {
        final follower = client.followChanges();
        await follower.poll();
        await client.levelOn(bob, document, 'a1');
        uam.remove(shared.id);
        expect(
          await client.levelOn(bob, document, 'a1'),
          'edit',
          reason: 'still cached until the change arrives',
        );
        expect(await follower.poll(), 1);
        expect(await client.levelOn(bob, document, 'a1'), isNull);
      },
    );
  });

  test(
    'a share with a group reaches its members once the cache drops',
    () async {
      uam.groups['sales'] = {'bob', 'carol'};
      final carol = _user('carol');
      expect(await client.levelOn(carol, document, 'a2'), isNull);
      await client.share(
        'token-alice',
        const TomItemShareRequest(
          item: 'document:a2',
          subjectKind: TomShareSubjectKind.group,
          subjectId: 'sales',
          level: 'view',
        ),
      );
      expect(await client.levelOn(carol, document, 'a2'), 'view');
    },
  );

  test('a share above the sharer\'s own level is the authority\'s refusal', () {
    expect(
      () => client.share(
        'token-bob',
        const TomItemShareRequest(
          item: 'document:a1',
          subjectKind: TomShareSubjectKind.user,
          subjectId: 'carol',
          level: 'view',
        ),
      ),
      throwsStateError,
    );
  });

  test('what was shared with me passes through', () async {
    await client.share(
      'token-alice',
      const TomItemShareRequest(
        item: 'document:a1',
        subjectKind: TomShareSubjectKind.user,
        subjectId: 'bob',
        level: 'view',
      ),
    );
    final page = await client.sharedWithMe('token-bob', itemType: 'document');
    expect(page.authorizations.single.item, 'document:a1');
  });

  group('accessible items', () {
    test('are gathered page by page and cached', () async {
      final ids = await client.accessibleItemIds(
        alice,
        document,
        minimumLevel: 'view',
      );
      expect(ids, ['a1', 'a2']);
      uam.pageSize = 1;
      await TomCacheInvalidator.invalidateItemAuthorization('*');
      uam.queryCalls = 0;
      expect(
        await client.accessibleItemIds(alice, document, minimumLevel: 'view'),
        ['a1', 'a2'],
      );
      expect(uam.queryCalls, 2, reason: 'two pages of one');
      await client.accessibleItemIds(alice, document, minimumLevel: 'view');
      expect(uam.queryCalls, 2, reason: 'cached');
    });

    test('drop with a change for their subject or type, not another', () async {
      await client.accessibleItemIds(bob, document, minimumLevel: 'view');
      uam.queryCalls = 0;
      await TomCacheInvalidator.invalidateItemAuthorization(
        'report:r1',
        subject: 'bob',
      );
      await TomCacheInvalidator.invalidateItemAuthorization(
        'document:a1',
        subject: 'carol',
      );
      await client.accessibleItemIds(bob, document, minimumLevel: 'view');
      expect(uam.queryCalls, 0);
      await TomCacheInvalidator.invalidateItemAuthorization('document:a1');
      await client.accessibleItemIds(bob, document, minimumLevel: 'view');
      expect(uam.queryCalls, 1);
    });

    test('more than a row scope may hold are refused, not cut short', () {
      final small = TomItemAuthorizationClient(uam, maximumScopeItems: 1);
      expect(
        () => small.accessibleItemIds(alice, document, minimumLevel: 'view'),
        throwsA(
          isA<TomItemAuthorizationException>().having(
            (e) => e.key,
            'key',
            'error.item_authority.scope_too_large',
          ),
        ),
      );
    });
  });

  group('the row scope', () {
    late TomItemAuthorityScopeSource source;

    setUp(() {
      source = TomItemAuthorityScopeSource(client, [document, report])
        ..install();
      uam.owners['report:r1'] = 'alice';
    });

    test('shows what is mine and what was shared with me', () async {
      await client.share(
        'token-alice',
        const TomItemShareRequest(
          item: 'document:a1',
          subjectKind: TomShareSubjectKind.user,
          subjectId: 'bob',
          level: 'comment',
        ),
      );
      final resolve = TomDataScopeRegistry.asyncResolverFor(
        TomDbScope.resourceScope,
      )!;
      expect(await resolve(bob), [
        ['document:a1', 'document:b1'],
      ]);
      expect(await source.readableResourceKeys(alice), [
        'document:a1',
        'document:a2',
        'report:r1',
      ]);
    });

    test('writes only where a level grants full', () async {
      await client.share(
        'token-alice',
        const TomItemShareRequest(
          item: 'document:a1',
          subjectKind: TomShareSubjectKind.user,
          subjectId: 'bob',
          level: 'comment',
        ),
      );
      expect(await source.writableResourceKeys(bob), ['document:b1']);
      expect(
        await source.writableResourceKeys(alice),
        ['document:a1', 'document:a2'],
        reason: 'report has no level that grants full',
      );
    });

    test('follows a revocation', () async {
      final shared = await client.share(
        'token-alice',
        const TomItemShareRequest(
          item: 'document:a1',
          subjectKind: TomShareSubjectKind.user,
          subjectId: 'bob',
          level: 'view',
        ),
      );
      expect(await source.readableResourceKeys(bob), contains('document:a1'));
      await client.revoke('token-alice', shared);
      expect(
        await source.readableResourceKeys(bob),
        isNot(contains('document:a1')),
      );
    });

    test('shows nothing to a principal that is not signed in', () async {
      expect(await source.readableResourceKeys(null), isEmpty);
    });
  });
}

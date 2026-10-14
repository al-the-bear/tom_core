/// Item-authorization answers: cached per item and subject, dropped on every
/// node when the authority reports a change — through its webhook, or through
/// its change feed as the catch-up.
///
/// The other node is played by a fake channel, as in
/// `cache_invalidation_test.dart`.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

class _FakeChannel implements TomInvalidationChannel {
  final List<TomCacheInvalidation> published = [];
  Future<void> Function(TomCacheInvalidation)? deliver;

  @override
  Duration get stalenessBound => const Duration(seconds: 2);

  @override
  Future<void> start(
    Future<void> Function(TomCacheInvalidation invalidation) deliver,
  ) async => this.deliver = deliver;

  @override
  Future<void> publish(TomCacheInvalidation invalidation) async =>
      published.add(invalidation);

  @override
  Future<void> stop() async {}
}

/// A change feed the test writes to; cursors are positions in [log].
class _Feed {
  final List<TomItemAuthorizationChange> log = [];
  int pageSize = 100;
  int retainedFrom = 0;
  int calls = 0;
  Object? failure;

  Future<TomItemAuthorizationChangePage> fetch(String? cursor) async {
    calls++;
    if (failure != null) throw failure!;
    if (cursor == null) {
      return TomItemAuthorizationChangePage(
        changes: const [],
        nextCursor: '${log.length}',
      );
    }
    final from = int.parse(cursor);
    if (from < retainedFrom) {
      throw TomItemAuthorizationFeedExpiredException(cursor);
    }
    final to = (from + pageSize).clamp(0, log.length);
    return TomItemAuthorizationChangePage(
      changes: log.sublist(from, to),
      nextCursor: '$to',
      hasMore: to < log.length,
    );
  }
}

Future<String?> _level(String subject, String item) async =>
    (await TomItemAuthorizationCache.lookup(subject, item))?.level;

Future<bool> _cached(String subject, String item) async =>
    await TomItemAuthorizationCache.lookup(subject, item) != null;

void main() {
  late _FakeChannel channel;

  setUp(() async {
    channel = _FakeChannel();
    await TomCacheInvalidator.install(channel);
    TomItemAuthorizationCache.install();
    await TomItemAuthorizationCache.store('u-1', 'document:a1', 'edit');
    await TomItemAuthorizationCache.store('u-2', 'document:a1', 'view');
    await TomItemAuthorizationCache.store('u-1', 'document:finance/q1', 'edit');
    await TomItemAuthorizationCache.store('u-1', 'todo:t1', 'manage');
  });

  tearDown(() async {
    TomItemAuthorizationCache.uninstall();
    await TomCacheInvalidator.reset();
  });

  group('the cache', () {
    test('answers the level, none, or a miss', () async {
      await TomItemAuthorizationCache.store('u-3', 'document:a1', null);
      expect(await _level('u-1', 'document:a1'), 'edit');
      expect(
        await TomItemAuthorizationCache.lookup('u-3', 'document:a1'),
        const TomCachedItemLevel(null),
      );
      expect(
        await TomItemAuthorizationCache.lookup('u-9', 'document:a1'),
        isNull,
      );
    });

    test('keeps each tenant\'s answers apart', () async {
      await TomTenantContext.run(
        'acme',
        () => TomItemAuthorizationCache.store('u-1', 'document:a1', 'view'),
      );
      expect(await _level('u-1', 'document:a1'), 'edit');
      expect(
        await TomTenantContext.run('acme', () => _level('u-1', 'document:a1')),
        'view',
      );
    });
  });

  group('an invalidation', () {
    test('of an item and subject drops that answer only', () async {
      await TomCacheInvalidator.invalidateItemAuthorization(
        'document:a1',
        subject: 'u-1',
      );
      expect(await _cached('u-1', 'document:a1'), isFalse);
      expect(await _cached('u-2', 'document:a1'), isTrue);
      expect(await _cached('u-1', 'todo:t1'), isTrue);
    });

    test('of an item drops every subject\'s answer on it', () async {
      await TomCacheInvalidator.invalidateItemAuthorization('document:a1');
      expect(await _cached('u-1', 'document:a1'), isFalse);
      expect(await _cached('u-2', 'document:a1'), isFalse);
      expect(await _cached('u-1', 'document:finance/q1'), isTrue);
    });

    test('of a pattern drops the items it covers', () async {
      await TomCacheInvalidator.invalidateItemAuthorization(
        'document:finance/*',
      );
      expect(await _cached('u-1', 'document:finance/q1'), isFalse);
      expect(await _cached('u-1', 'document:a1'), isTrue);
      await TomCacheInvalidator.invalidateItemAuthorization(
        '*',
        subject: 'u-1',
      );
      expect(await _cached('u-1', 'document:a1'), isFalse);
      expect(await _cached('u-1', 'todo:t1'), isFalse);
      expect(await _cached('u-2', 'document:a1'), isTrue);
    });

    test('in a tenant\'s context drops that tenant\'s answers only', () async {
      await TomTenantContext.run(
        'acme',
        () => TomItemAuthorizationCache.store('u-1', 'document:a1', 'view'),
      );
      await TomTenantContext.run(
        'acme',
        () => TomCacheInvalidator.invalidateItemAuthorization('*'),
      );
      expect(
        await TomTenantContext.run('acme', () => _cached('u-1', 'document:a1')),
        isFalse,
      );
      expect(await _cached('u-1', 'document:a1'), isTrue);
    });

    group('of local copies', () {
      Future<bool> held(String subject, String type) async =>
          await TomItemAuthorizationCache.lookupCopy(subject, type) != null;

      setUp(() async {
        for (final subject in ['u-1', 'u-2']) {
          for (final type in ['document', 'todo']) {
            await TomItemAuthorizationCache.storeCopy(subject, type, {
              'x': 'view',
            });
          }
        }
        await TomTenantContext.run(
          'acme',
          () => TomItemAuthorizationCache.storeCopy('u-1', 'document', {
            'y': 'edit',
          }),
        );
      });

      test('are kept apart per tenant', () async {
        expect(await TomItemAuthorizationCache.lookupCopy('u-1', 'document'), {
          'x': 'view',
        });
        expect(
          await TomTenantContext.run(
            'acme',
            () => TomItemAuthorizationCache.lookupCopy('u-1', 'document'),
          ),
          {'y': 'edit'},
        );
      });

      test('drop by item type and subject', () async {
        await TomCacheInvalidator.invalidateItemAuthorization(
          'document:a1',
          subject: 'u-1',
        );
        expect(await held('u-1', 'document'), isFalse);
        expect(await held('u-1', 'todo'), isTrue);
        expect(await held('u-2', 'document'), isTrue);
        await TomCacheInvalidator.invalidateItemAuthorization('todo:t1');
        expect(await held('u-1', 'todo'), isFalse);
        expect(await held('u-2', 'todo'), isFalse);
        expect(await held('u-2', 'document'), isTrue);
      });

      test('drop for a user on every item, as a group or delegation change '
          'is reported', () async {
        await TomCacheInvalidator.invalidateItemAuthorization(
          '*',
          subject: 'u-2',
        );
        expect(await held('u-2', 'document'), isFalse);
        expect(await held('u-2', 'todo'), isFalse);
        expect(await held('u-1', 'document'), isTrue);
      });

      test('drop in a tenant\'s context for that tenant only', () async {
        await TomTenantContext.run(
          'acme',
          () => TomCacheInvalidator.invalidateItemAuthorization('*'),
        );
        expect(
          await TomTenantContext.run('acme', () => held('u-1', 'document')),
          isFalse,
        );
        expect(await held('u-1', 'document'), isTrue);
      });
    });

    test('is published for the other nodes', () async {
      await TomTenantContext.run(
        'acme',
        () => TomCacheInvalidator.invalidateItemAuthorization(
          'document:a1',
          subject: 'u-1',
        ),
      );
      final sent = channel.published.single;
      expect(sent.kind, TomInvalidationKind.item);
      expect(sent.target, 'tenant:acme/document:a1');
      expect(sent.key, 'u-1');
    });

    test('raised on another node drops the answer here', () async {
      await channel.deliver!(
        TomCacheInvalidation.item(
          'document:a1',
          subject: 'u-2',
          origin: 'other-node',
        ),
      );
      expect(await _cached('u-2', 'document:a1'), isFalse);
      expect(await _cached('u-1', 'document:a1'), isTrue);
    });

    test('survives being rebuilt from its stored parts', () {
      final rebuilt = TomCacheInvalidation.fromParts(
        kind: 'item',
        target: 'document:a1',
        key: 'u-1',
        at: DateTime.utc(2026, 10, 14),
        origin: 'n1',
      );
      expect(rebuilt.kind, TomInvalidationKind.item);
      expect(rebuilt.key, 'u-1');
    });
  });

  group('the webhook', () {
    const secret = 'subscription-secret';
    final now = DateTime.utc(2026, 10, 14, 12);
    final stamp = '${now.millisecondsSinceEpoch ~/ 1000}';

    String event(
      List<Map<String, Object?>> changes, {
      String type = 'itemAuthorization.changed',
    }) => jsonEncode({'type': type, 'changes': changes});

    Map<String, String> headers(
      String body, {
      String key = secret,
      String? timestamp,
      String id = 'ev-1',
    }) => {
      'X-Tom-Event-Id': id,
      'X-Tom-Timestamp': timestamp ?? stamp,
      'X-Tom-Signature': TomItemAuthorizationWebhook.sign(
        key,
        id,
        timestamp ?? stamp,
        body,
      ),
    };

    TomItemAuthorizationWebhook receiver({
      List<String> secrets = const [secret],
    }) => TomItemAuthorizationWebhook(secrets, clock: () => now);

    test('a revoked share stops granting at once', () async {
      final body = event([
        {'item': 'document:a1', 'subject': 'u-1', 'subjectKind': 'user'},
      ]);
      expect(await receiver().receive(headers(body), body), 1);
      expect(await _cached('u-1', 'document:a1'), isFalse);
      expect(await _cached('u-2', 'document:a1'), isTrue);
      expect(channel.published.single.key, 'u-1');
    });

    test('a change for a group drops every subject\'s answer', () async {
      final body = event([
        {'item': 'document:a1', 'subject': 'g-sales', 'subjectKind': 'group'},
      ]);
      await receiver().receive(headers(body), body);
      expect(await _cached('u-1', 'document:a1'), isFalse);
      expect(await _cached('u-2', 'document:a1'), isFalse);
    });

    test('accepts the second secret during a rotation', () async {
      final body = event([
        {'item': 'todo:t1'},
      ]);
      expect(
        await receiver(
          secrets: const ['old', secret],
        ).receive(headers(body), body),
        1,
      );
    });

    test('applies a subscription\'s tenant', () async {
      await TomTenantContext.run(
        'acme',
        () => TomItemAuthorizationCache.store('u-1', 'document:a1', 'view'),
      );
      final body = event([
        {'item': 'document:a1'},
      ]);
      await TomItemAuthorizationWebhook(
        const [secret],
        tenantId: 'acme',
        clock: () => now,
      ).receive(headers(body), body);
      expect(
        await TomTenantContext.run('acme', () => _cached('u-1', 'document:a1')),
        isFalse,
      );
      expect(await _cached('u-1', 'document:a1'), isTrue);
    });

    test('ignores other event types', () async {
      final body = event(const [], type: 'user.created');
      expect(await receiver().receive(headers(body), body), 0);
      expect(channel.published, isEmpty);
    });

    Matcher refused(String key) => throwsA(
      isA<TomItemAuthorizationWebhookException>().having(
        (e) => e.key,
        'key',
        key,
      ),
    );

    test('refuses a wrong or missing signature', () async {
      final body = event([
        {'item': 'document:a1'},
      ]);
      expect(
        () => receiver().receive(headers(body, key: 'guess'), body),
        refused('error.item_authorization.webhook.signature_invalid'),
      );
      expect(
        () => receiver().receive(headers(body), '$body '),
        refused('error.item_authorization.webhook.signature_invalid'),
      );
      expect(
        () => receiver().receive(const {}, body),
        refused('error.item_authorization.webhook.signature_invalid'),
      );
      expect(await _cached('u-1', 'document:a1'), isTrue);
    });

    test('refuses a delivery outside the tolerance', () {
      final body = event([
        {'item': 'document:a1'},
      ]);
      final old = '${now.millisecondsSinceEpoch ~/ 1000 - 301}';
      expect(
        () => receiver().receive(headers(body, timestamp: old), body),
        refused('error.item_authorization.webhook.timestamp_stale'),
      );
    });

    test('refuses a body that is not an event', () {
      for (final body in [
        'not json',
        '[]',
        jsonEncode({'type': 'itemAuthorization.changed'}),
        jsonEncode({
          'type': 'itemAuthorization.changed',
          'changes': [
            {'subject': 'u-1'},
          ],
        }),
      ]) {
        expect(
          () => receiver().receive(headers(body), body),
          refused('error.item_authorization.webhook.payload_invalid'),
          reason: body,
        );
      }
    });

    test('is configured with one secret or two', () {
      expect(() => TomItemAuthorizationWebhook(const []), throwsArgumentError);
      expect(
        () => TomItemAuthorizationWebhook(const ['a', 'b', 'c']),
        throwsArgumentError,
      );
    });
  });

  group('the feed follower', () {
    late _Feed feed;
    late TomItemAuthorizationFeedFollower follower;

    setUp(() {
      feed = _Feed();
      follower = TomItemAuthorizationFeedFollower(feed.fetch);
    });

    tearDown(() => follower.stop());

    test('takes the current position and drops every answer first', () async {
      feed.log.add(const TomItemAuthorizationChange('todo:old'));
      expect(await follower.poll(), 0);
      expect(follower.cursor, '1');
      expect(await _cached('u-1', 'document:a1'), isFalse);
      expect(channel.published.single.target, '*');
    });

    test(
      'then drops what each change names, catching up a missed webhook',
      () async {
        await follower.poll();
        await TomItemAuthorizationCache.store('u-1', 'document:a1', 'edit');
        await TomItemAuthorizationCache.store('u-2', 'document:a1', 'view');
        feed.log.add(
          const TomItemAuthorizationChange('document:a1', subject: 'u-1'),
        );
        expect(await follower.poll(), 1);
        expect(await _cached('u-1', 'document:a1'), isFalse);
        expect(await _cached('u-2', 'document:a1'), isTrue);
        expect(follower.cursor, '1');
        expect(await follower.poll(), 0);
      },
    );

    test('reads every page waiting', () async {
      await follower.poll();
      feed.pageSize = 2;
      for (var i = 0; i < 5; i++) {
        feed.log.add(TomItemAuthorizationChange('document:x$i'));
      }
      expect(await follower.poll(), 5);
      expect(follower.cursor, '5');
    });

    test('an expired cursor drops every answer and starts again', () async {
      await follower.poll();
      await TomItemAuthorizationCache.store('u-1', 'document:a1', 'edit');
      feed.log.addAll(const [
        TomItemAuthorizationChange('todo:1'),
        TomItemAuthorizationChange('todo:2'),
      ]);
      feed.retainedFrom = 1;
      expect(await follower.poll(), 0);
      expect(follower.cursor, '2');
      expect(await _cached('u-1', 'document:a1'), isFalse);
    });

    test('a failed read keeps the cursor for the next poll', () async {
      await follower.poll();
      feed.log.add(const TomItemAuthorizationChange('document:a1'));
      feed.failure = StateError('authority unreachable');
      expect(await follower.poll(), 0);
      expect(follower.cursor, '0');
      feed.failure = null;
      expect(await follower.poll(), 1);
    });

    test('follows a tenant\'s feed in its context', () async {
      final tenantFollower = TomItemAuthorizationFeedFollower(
        feed.fetch,
        tenantId: 'acme',
      );
      await tenantFollower.poll();
      expect(channel.published.single.target, 'tenant:acme/*');
      expect(await _cached('u-1', 'document:a1'), isTrue);
    });

    test('states its delay: the poll interval and the channel\'s', () {
      expect(
        TomItemAuthorizationFeedFollower(
          feed.fetch,
          pollInterval: const Duration(seconds: 30),
        ).stalenessBound,
        const Duration(seconds: 32),
      );
    });

    test('starts with a poll and keeps polling on a timer', () async {
      await follower.start();
      expect(follower.isRunning, isTrue);
      expect(feed.calls, 1);
      follower.stop();
      expect(follower.isRunning, isFalse);
    });
  });
}

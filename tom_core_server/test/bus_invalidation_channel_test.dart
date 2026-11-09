/// The message-bus invalidation channel over the in-memory bus: invalidations
/// reach every other node and not their own, a revocation raised on one node
/// is refused on the other within the bound, and a node starting later
/// applies the revocations still in force from the log.
///
/// The same channel between two processes over a real broker is
/// `tom_core_message_bus_nats`'s NB-V1; the SQL table as its log is
/// `cache_invalidation_db_test.dart`'s.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tom_core_message_bus/tom_core_message_bus.dart';
import 'package:tom_core_server/tom_core_server.dart';

TomClientJwtToken _token(String username, DateTime issuedAt) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final payload = {
    'username': username,
    'iat': issuedAt.toUtc().millisecondsSinceEpoch ~/ 1000,
    'exp':
        issuedAt.toUtc().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000,
  };
  return TomClientJwtToken(
    '${segment({'alg': 'HS256', 'typ': 'JWT'})}.${segment(payload)}.sig',
    decrypt: false,
  );
}

void main() {
  late TomMemoryMessageBus bus;
  late TomMemoryInvalidationLog log;

  setUp(() {
    bus = TomMemoryMessageBus();
    log = TomMemoryInvalidationLog();
    TomAuthorizationCache.instance.dispose();
  });
  tearDown(() async {
    await TomCacheInvalidator.reset();
    TomAuthorizationCache.instance.dispose();
    await bus.close();
  });

  TomBusInvalidationChannel node(String id) =>
      TomBusInvalidationChannel(bus: bus, log: log, nodeId: id);

  test(
    'BI-1: an invalidation reaches every other node, and not its own',
    () async {
      final received = <String, List<TomCacheInvalidation>>{
        'node-a': [],
        'node-b': [],
        'node-c': [],
      };
      final channels = {for (final id in received.keys) id: node(id)};
      for (final entry in channels.entries) {
        await entry.value.start((i) async => received[entry.key]!.add(i));
      }

      await channels['node-a']!.publish(
        TomCacheInvalidation.cacheEntry('settings', 'theme', origin: 'node-a'),
      );
      await bus.settled();

      expect(received['node-a'], isEmpty);
      for (final id in ['node-b', 'node-c']) {
        final got = received[id]!.single;
        expect(got.kind, TomInvalidationKind.cacheEntry);
        expect(got.target, 'settings');
        expect(got.key, 'theme');
        expect(got.origin, 'node-a');
      }
      for (final channel in channels.values) {
        await channel.stop();
      }
    },
  );

  test('BI-2: a grant revoked on one node is refused on the other within the '
      'bound', () async {
    // This isolate is node B, through the invalidator; node A is a channel
    // of its own on the same bus.
    final channel = TomBusInvalidationChannel(bus: bus, log: log);
    await TomCacheInvalidator.install(channel);
    final token = _token(
      'alice',
      DateTime.now().subtract(const Duration(minutes: 5)),
    );
    await TomAuthorizationCache.storePrincipal(
      token,
      TomPrincipal(user: TomUser(username: 'alice'), authenticated: true),
    );
    expect(await TomAuthorizationCache.getPrincipal(token), isNotNull);

    final nodeA = node('node-a');
    await nodeA.start((_) async {});
    final clock = Stopwatch()..start();
    await nodeA.publish(
      TomCacheInvalidation.principal('alice', origin: 'node-a'),
    );

    var refusedAfter = -1;
    while (clock.elapsed < const Duration(seconds: 5)) {
      try {
        await TomAuthorizationCache.getPrincipal(token);
      } on TomAuthorizationCacheException catch (e) {
        if (e.key == 'authorization.cache.revoked_principal') {
          refusedAfter = clock.elapsedMilliseconds;
          break;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await nodeA.stop();
    expect(refusedAfter, isNot(-1), reason: 'node B never refused');
    expect(refusedAfter, lessThan(channel.stalenessBound.inMilliseconds));
  });

  test('BI-3: a node starting later applies the revocations still in force '
      'from the log', () async {
    final nodeA = node('node-a');
    await nodeA.start((_) async {});
    await nodeA.publish(
      TomCacheInvalidation.principal('alice', origin: 'node-a'),
    );
    await nodeA.publish(
      TomCacheInvalidation.cache('settings', origin: 'node-a'),
    );
    await bus.settled();

    final received = <TomCacheInvalidation>[];
    final late = node('node-late');
    await late.start((i) async => received.add(i));
    expect(received.map((i) => (i.kind, i.target)), [
      (TomInvalidationKind.principal, 'alice'),
    ], reason: 'revocations only: a cache flush before the start is moot');
    await late.stop();
    await nodeA.stop();
  });

  test('BI-4: a stopped node leaves nothing behind on the bus', () async {
    final received = <TomCacheInvalidation>[];
    final nodeB = node('node-b');
    await nodeB.start((i) async => received.add(i));
    expect(nodeB.isRunning, isTrue);
    await nodeB.stop();
    expect(nodeB.isRunning, isFalse);

    await node(
      'node-a',
    ).publish(TomCacheInvalidation.cache('settings', origin: 'node-a'));
    // Node B's ephemeral group is gone: a restart sees no backlog.
    await nodeB.start((i) async => received.add(i));
    await bus.settled();
    expect(received, isEmpty);
    await nodeB.stop();
  });

  test('BI-5: the memory log keeps revocations for its retention', () async {
    var now = DateTime.utc(2026, 11, 6, 12);
    final shortLog = TomMemoryInvalidationLog(
      retention: const Duration(hours: 1),
      clock: () => now,
    );
    await shortLog.record(
      TomCacheInvalidation.principal('alice', at: now, origin: 'node-a'),
    );
    await shortLog.record(
      TomCacheInvalidation.cache('settings', at: now, origin: 'node-a'),
    );
    expect(await shortLog.revocationsInForce(), hasLength(1));
    now = now.add(const Duration(hours: 2));
    expect(await shortLog.revocationsInForce(), isEmpty);
  });

  test('BI-6: the bound is stated, a second by default', () {
    expect(node('node-a').stalenessBound, const Duration(seconds: 1));
    expect(
      TomBusInvalidationChannel(
        bus: bus,
        log: log,
        stalenessBound: const Duration(milliseconds: 250),
      ).stalenessBound,
      const Duration(milliseconds: 250),
    );
  });

  test('BI-7: an invalidation survives its JSON form', () {
    final at = DateTime.utc(2026, 11, 6, 12);
    final back = TomBusInvalidationChannel.invalidationFromJson(
      TomBusInvalidationChannel.invalidationToJson(
        TomCacheInvalidation.item(
          'task:7',
          subject: 'bob',
          at: at,
          origin: 'n',
        ),
      ),
    );
    expect(back.kind, TomInvalidationKind.item);
    expect(back.target, 'task:7');
    expect(back.key, 'bob');
    expect(back.at, at);
    expect(back.origin, 'n');
  });
}

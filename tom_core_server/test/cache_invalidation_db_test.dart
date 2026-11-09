/// The database invalidation channel, and a revocation crossing two nodes.
///
/// A node is a process with caches of its own. Two isolates have separate
/// static state — their own authorization cache, their own invalidator — so a
/// spawned isolate is a second node in every respect that matters here; the
/// only thing the two share is the database, which is exactly what the
/// channel relies on.
@Tags(['db'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:tom_core_message_bus/tom_core_message_bus.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const _pollInterval = Duration(milliseconds: 200);

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

/// Node B: joins the cluster through the same table, caches alice's principal,
/// reports ready, then reports how long after that it began refusing alice's
/// token (or `-1` if it never did within ten seconds).
Future<void> _nodeB(List<Object> args) async {
  final config = (args[0] as Map).cast<String, dynamic>();
  final ready = args[1] as SendPort;
  final result = args[2] as SendPort;
  final go = ReceivePort();
  ready.send(go.sendPort);

  initializeReflection();
  await TomDataSourceInfo.initializeDatasourceInfo(config);
  final channel = TomSqlInvalidationChannel.named(
    TestDatabase.datasourceName,
    pollInterval: _pollInterval,
  );
  await TomCacheInvalidator.install(channel);
  final token = _token(
    'alice',
    DateTime.now().subtract(const Duration(minutes: 5)),
  );
  await TomAuthorizationCache.storePrincipal(
    token,
    TomPrincipal(user: TomUser(username: 'alice'), authenticated: true),
  );
  // Serving alice's token before the revocation.
  final before = await TomAuthorizationCache.getPrincipal(token);
  ready.send(before?.username ?? 'miss');

  // Node A revokes once it hears we are ready; measure from its signal.
  await go.first;
  final clock = Stopwatch()..start();
  var refusedAfter = -1;
  while (clock.elapsed < const Duration(seconds: 10)) {
    try {
      await TomAuthorizationCache.getPrincipal(token);
    } on TomAuthorizationCacheException catch (e) {
      if (e.key == 'authorization.cache.revoked_principal') {
        refusedAfter = clock.elapsedMilliseconds;
        break;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  await TomCacheInvalidator.reset();
  result.send(refusedAfter);
}

void main() async {
  final reachable = await TestDatabase.isReachable();
  final String? skipReason = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable on ${TestDatabase.host}:${TestDatabase.port} — '
            'start one with tool/run_db_tests.sh or tool/run_db_tests_postgres.sh';

  group('TomSqlInvalidationChannel (DB-backed)', () {
    late TomDataSource ds;

    setUpAll(() async {
      initializeReflection();
      ds = (await TestDatabase.register()).datasource;
    });

    setUp(() async {
      await TestDatabase.execute(
        ds,
        invalidationTableDdl(defaultInvalidationTable),
      );
      await ds.executeCommand('DELETE FROM $defaultInvalidationTable');
      TomAuthorizationCache.instance.dispose();
    });

    tearDown(() async {
      await TomCacheInvalidator.reset();
      TomAuthorizationCache.instance.dispose();
    });

    test('delivers what another node published, and not its own', () async {
      final writer = TomSqlInvalidationChannel(ds);
      final reader = TomSqlInvalidationChannel(ds);
      final received = <TomCacheInvalidation>[];
      await reader.start((i) async => received.add(i));
      addTearDown(reader.stop);

      await writer.publish(
        TomCacheInvalidation.principal('alice', origin: 'node-b'),
      );
      await writer.publish(TomCacheInvalidation.cache('settings'));
      await reader.poll();

      expect(received, hasLength(1), reason: 'own-origin rows are skipped');
      expect(received.single.kind, TomInvalidationKind.principal);
      expect(received.single.target, 'alice');
      expect(received.single.origin, 'node-b');
    });

    test(
      'a revoked item share reaches the other node through the table',
      () async {
        // Node B: a reader with a cached item answer of its own.
        TomItemAuthorizationCache.install();
        addTearDown(TomItemAuthorizationCache.uninstall);
        await TomItemAuthorizationCache.store('u-1', 'document:a1', 'edit');
        await TomItemAuthorizationCache.store('u-2', 'document:a1', 'view');
        final nodeB = TomSqlInvalidationChannel(ds);
        await nodeB.start(TomCacheInvalidator.apply);
        addTearDown(nodeB.stop);

        // Node A received the webhook and published the item invalidation.
        await TomSqlInvalidationChannel(ds).publish(
          TomCacheInvalidation.item(
            'tenant:acme/document:a1',
            subject: 'u-1',
            origin: 'node-a',
          ),
        );
        await TomTenantContext.run(
          'acme',
          () => TomItemAuthorizationCache.store('u-1', 'document:a1', 'edit'),
        );
        await nodeB.poll();

        expect(
          await TomTenantContext.run(
            'acme',
            () => TomItemAuthorizationCache.lookup('u-1', 'document:a1'),
          ),
          isNull,
        );
        expect(
          await TomItemAuthorizationCache.lookup('u-1', 'document:a1'),
          isNotNull,
          reason: 'another tenant\'s answer is not touched',
        );
      },
    );

    test('a node starting up applies the revocations still in force', () async {
      final writer = TomSqlInvalidationChannel(ds);
      await writer.publish(
        TomCacheInvalidation.principal('alice', origin: 'node-b'),
      );
      await writer.publish(
        TomCacheInvalidation.principal(
          'old',
          origin: 'node-b',
          at: DateTime.now().subtract(const Duration(days: 2)),
        ),
      );
      await writer.publish(
        TomCacheInvalidation.cache('settings', origin: 'node-b'),
      );

      final received = <TomCacheInvalidation>[];
      final joining = TomSqlInvalidationChannel(ds);
      await joining.start((i) async => received.add(i));
      addTearDown(joining.stop);

      expect(received.map((i) => i.target), ['alice']);
      // Already-applied history is not delivered again by the next poll.
      await joining.poll();
      expect(received, hasLength(1));
    });

    test('rows past their retention are deleted', () async {
      final writer = TomSqlInvalidationChannel(ds);
      await writer.publish(
        TomCacheInvalidation.principal(
          'old',
          origin: 'node-b',
          at: DateTime.now().subtract(const Duration(days: 2)),
        ),
      );
      await writer.publish(
        TomCacheInvalidation.principal('alice', origin: 'node-b'),
      );
      final reader = TomSqlInvalidationChannel(ds);
      await reader.start((_) async {});
      addTearDown(reader.stop);
      await reader.poll();

      final left = await ds.executeQuery<TomCacheInvalidationRow>(
        'SELECT target FROM $defaultInvalidationTable',
      );
      expect(left.map((r) => r.target), ['alice']);
    });

    test('the table is the bus channel\'s log: a node starting later applies '
        'the revocations in force from it', () async {
      final sqlLog = TomSqlInvalidationChannel(ds, pollInterval: _pollInterval);
      final bus = TomMemoryMessageBus();
      addTearDown(bus.close);
      final nodeA = TomBusInvalidationChannel(
        bus: bus,
        log: sqlLog,
        nodeId: 'node-a',
      );
      await nodeA.publish(
        TomCacheInvalidation.principal('alice', origin: 'node-a'),
      );
      await nodeA.publish(
        TomCacheInvalidation.cache('settings', origin: 'node-a'),
      );
      await nodeA.publish(
        TomCacheInvalidation.principal(
          'old',
          at: DateTime.now().subtract(
            TomAuthorizationCache.revocationRetention +
                const Duration(hours: 1),
          ),
          origin: 'node-a',
        ),
      );
      expect((await sqlLog.revocationsInForce()).map((i) => i.target), [
        'alice',
      ], reason: 'principal revocations within the retention only');

      final received = <TomCacheInvalidation>[];
      final late = TomBusInvalidationChannel(
        bus: bus,
        log: sqlLog,
        nodeId: 'node-late',
      );
      await late.start((i) async => received.add(i));
      expect(received.map((i) => i.target), ['alice']);
      await late.stop();
    });

    test('the staleness bound is the poll interval', () {
      expect(
        TomSqlInvalidationChannel(
          ds,
          pollInterval: _pollInterval,
        ).stalenessBound,
        _pollInterval,
      );
    });

    test('a grant revoked on one node is refused on the other within the '
        'bound', () async {
      final config = TestDatabase.datasourceConfig;
      final readyPort = ReceivePort();
      final resultPort = ReceivePort();
      await Isolate.spawn(_nodeB, <Object>[
        config,
        readyPort.sendPort,
        resultPort.sendPort,
      ]);
      final readyMessages = StreamIterator(readyPort);
      await readyMessages.moveNext();
      final go = readyMessages.current as SendPort;
      await readyMessages.moveNext();
      expect(
        readyMessages.current,
        'alice',
        reason: 'node B served alice before the revocation',
      );

      // Node A: this isolate.
      await TomCacheInvalidator.install(
        TomSqlInvalidationChannel(ds, pollInterval: _pollInterval),
      );
      go.send(true);
      await TomCacheInvalidator.revokePrincipal('alice');

      final refusedAfterMs =
          await resultPort.first.timeout(const Duration(seconds: 20)) as int;
      readyPort.close();
      expect(refusedAfterMs, isNot(-1), reason: 'node B never refused');
      expect(
        refusedAfterMs,
        lessThan(_pollInterval.inMilliseconds + 1000),
        reason: 'refused within the poll interval plus one query',
      );
    });
  }, skip: skipReason);
}

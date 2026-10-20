/// The SQL idempotency store against a live database: claiming, completing,
/// releasing, replacing an expired record and taking over a dead claim, and a
/// retried request answered from the stored response.
///
/// `@Tags(['db'])`, self-skipping without a server; bring one up with
/// `tool/run_db_tests.sh` (MariaDB) or `tool/run_db_tests_postgres.sh`.
@Tags(['db'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';
import 'fixtures/test_database.dart';

const _scope = TomIdempotencyScope(
  tenant: '',
  principal: 'alice',
  operation: 'POST /orders',
  key: 'k-1',
);

void main() async {
  final reachable = await TestDatabase.isReachable();
  final skip = reachable
      ? null
      : 'No ${TestDatabase.engine} server reachable at '
            '${TestDatabase.host}:${TestDatabase.port} — start one with '
            'tool/run_db_tests.sh or tool/run_db_tests_postgres.sh.';

  group('TomSqlIdempotencyStore', () {
    late TomSqlIdempotencyStore store;
    final now = DateTime.utc(2026, 10, 20, 12);

    Future<TomIdempotencyClaim> claim(
      String hash, {
      DateTime? at,
      Duration life = const Duration(days: 1),
      Duration stale = const Duration(minutes: 5),
    }) {
      final t = at ?? now;
      return store.claim(
        _scope,
        hash,
        now: t,
        expiresAt: t.add(life),
        staleBefore: t.subtract(stale),
      );
    }

    setUpAll(() async {
      initializeReflection();
      await TestDatabase.register();
    });

    setUp(() async {
      store = TomSqlIdempotencyStore(TestDatabase.datasourceName);
      await store.deleteAll();
      TomIdempotency.reset();
    });
    tearDown(TomIdempotency.reset);

    test('the first claim wins; the second sees the record', () async {
      expect((await claim('h1')).won, isTrue);
      final second = await claim('h1');
      expect(second.won, isFalse);
      expect(second.existing!.requestHash, 'h1');
      expect(second.existing!.isCompleted, isFalse);
    });

    test('a completed record carries the response', () async {
      await claim('h1');
      await store.complete(
        _scope,
        status: 201,
        headers: {'content-type': 'application/json'},
        body: utf8.encode('{"order":7}'),
      );
      final record = (await claim('h1')).existing!;
      expect(record.status, 201);
      expect(record.headers, {'content-type': 'application/json'});
      expect(utf8.decode(record.body!), '{"order":7}');
    });

    test('a released key is claimed again', () async {
      await claim('h1');
      await store.release(_scope);
      expect((await claim('h2')).won, isTrue);
    });

    test('an expired record is replaced', () async {
      await claim('h1', life: const Duration(minutes: 1));
      final later = now.add(const Duration(minutes: 2));
      expect((await claim('h2', at: later)).won, isTrue);
      expect((await claim('h2', at: later)).existing!.requestHash, 'h2');
    });

    test('a claim older than the in-progress timeout is taken over', () async {
      await claim('h1');
      final later = now.add(const Duration(minutes: 6));
      expect((await claim('h1', at: later)).won, isTrue);
    });

    test('purgeExpired removes what has expired', () async {
      await claim('h1', life: const Duration(minutes: 1));
      expect(await store.purgeExpired(now.add(const Duration(hours: 1))), 1);
      expect((await claim('h2')).won, isTrue);
    });

    test('a retried request runs once through the SQL store', () async {
      TomIdempotency.store = store;
      var runs = 0;
      Future<Response> send() => runZoned(
        () => TomIdempotency.handle(
          Request(
            'POST',
            Uri.parse('http://localhost/orders'),
            body: '{"item":1}',
            headers: {'idempotency-key': 'db-key'},
          ),
          'POST /orders',
          const TomIdempotent(),
          (request) async {
            runs++;
            return Response(201, body: '{"order":$runs}');
          },
        ),
        zoneValues: {
          TomPrincipal: TomPrincipal(
            user: TomUser(id: 'alice', username: 'alice'),
            authenticated: true,
          ),
        },
      );
      final first = await send();
      final retry = await send();
      expect(runs, 1);
      expect(await retry.readAsString(), await first.readAsString());
      expect(retry.headers[TomIdempotency.replayedHeader], 'true');
    });
  }, skip: skip);
}

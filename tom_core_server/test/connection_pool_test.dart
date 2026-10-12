/// The connection pool every SQL driver shares.
///
/// Driven through a fake factory and an injected clock, so sizing, reuse,
/// waiting, hand-over, retirement and closing are each observable without a
/// database. How a driver pins a pooled connection to a transaction is the
/// MariaDB data source's suite; how two transactions run side by side against
/// a real server is `datasources_db_test.dart`.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

class _Conn {
  _Conn(this.id);
  final int id;
  bool usable = true;
  bool valid = true;
  bool closed = false;
  @override
  String toString() => 'conn#$id';
}

class _Factory implements TomConnectionFactory<_Conn> {
  int opened = 0;
  int validations = 0;
  Object? openFailure;
  final List<_Conn> closedConns = [];

  @override
  Future<_Conn> open() async {
    if (openFailure != null) throw openFailure!;
    return _Conn(++opened);
  }

  @override
  Future<void> close(_Conn c) async {
    c.closed = true;
    closedConns.add(c);
  }

  @override
  bool isUsable(_Conn c) => c.usable && !c.closed;

  @override
  Future<bool> validate(_Conn c) async {
    validations++;
    return c.valid;
  }
}

Matcher _poolError(String key) =>
    throwsA(isA<TomConnectionPoolException>().having((e) => e.key, 'key', key));

void main() {
  late _Factory factory;
  late DateTime now;
  TomConnectionPool<_Conn> pool([
    TomConnectionPoolSettings settings = const TomConnectionPoolSettings(),
  ]) => TomConnectionPool(factory, settings: settings, clock: () => now);

  setUp(() {
    factory = _Factory();
    now = DateTime.utc(2026, 10, 12, 12);
  });

  group('settings', () {
    test('the defaults are the common JDBC-pool values', () {
      const s = TomConnectionPoolSettings();
      expect(s.maxSize, 10);
      expect(s.minIdle, 0);
      expect(s.acquireTimeout, const Duration(seconds: 30));
      expect(s.idleTimeout, const Duration(minutes: 10));
      expect(s.maxLifetime, const Duration(minutes: 30));
      expect(s.validateAfterIdle, const Duration(seconds: 30));
    });

    test('unusable settings are refused when the pool is built', () {
      for (final s in const [
        TomConnectionPoolSettings(maxSize: 0),
        TomConnectionPoolSettings(maxSize: 2, minIdle: 3),
        TomConnectionPoolSettings(minIdle: -1),
        TomConnectionPoolSettings(acquireTimeout: Duration.zero),
      ]) {
        expect(
          () => pool(s),
          _poolError('error.datasource.pool.invalid_settings'),
          reason: '$s',
        );
      }
    });
  });

  group('lending', () {
    test('opens nothing until asked, and one connection per caller', () async {
      final p = pool();
      expect(factory.opened, 0);
      final a = await p.acquire();
      final b = await p.acquire();
      expect(identical(a, b), isFalse);
      expect(factory.opened, 2);
      expect(p.lentCount, 2);
    });

    test('a released connection is lent again rather than a new one', () async {
      final p = pool();
      final a = await p.acquire();
      await p.release(a);
      expect(p.idleCount, 1);
      expect(await p.acquire(), same(a));
      expect(factory.opened, 1);
    });

    test('never opens more than maxSize', () async {
      final p = pool(const TomConnectionPoolSettings(maxSize: 2));
      await Future.wait([p.acquire(), p.acquire()]);
      final third = p.acquire();
      await Future<void>.delayed(Duration.zero);
      expect(factory.opened, 2);
      expect(p.waitingCount, 1);
      unawaited(third.catchError((_) => _Conn(0)));
      await p.close();
    });

    test('releasing what was not lent is a bookkeeping error', () async {
      final p = pool();
      expect(() => p.release(_Conn(99)), throwsStateError);
    });

    test('a failed open propagates and frees its slot', () async {
      final p = pool(const TomConnectionPoolSettings(maxSize: 1));
      factory.openFailure = StateError('server down');
      await expectLater(p.acquire(), throwsStateError);
      factory.openFailure = null;
      expect(p.size, 0);
      expect((await p.acquire()).id, 1);
    });
  });

  group('waiting', () {
    test('a waiter receives the next released connection', () async {
      final p = pool(const TomConnectionPoolSettings(maxSize: 1));
      final a = await p.acquire();
      final waiting = p.acquire();
      await Future<void>.delayed(Duration.zero);
      await p.release(a);
      expect(await waiting, same(a));
      expect(p.lentCount, 1);
      expect(p.idleCount, 0);
    });

    test('waiters are served in arrival order', () async {
      final p = pool(const TomConnectionPoolSettings(maxSize: 1));
      final a = await p.acquire();
      final order = <String>[];
      final first = p.acquire().then((c) {
        order.add('first');
        return c;
      });
      final second = p.acquire().then((c) {
        order.add('second');
        return c;
      });
      await Future<void>.delayed(Duration.zero);
      await p.release(a);
      await p.release(await first);
      await second;
      expect(order, ['first', 'second']);
    });

    test('a discarded connection lets a waiter open a fresh one', () async {
      final p = pool(const TomConnectionPoolSettings(maxSize: 1));
      final a = await p.acquire();
      final waiting = p.acquire();
      await Future<void>.delayed(Duration.zero);
      await p.release(a, discard: true);
      final b = await waiting;
      expect(identical(a, b), isFalse);
      expect(a.closed, isTrue);
    });

    test('the wait ends with a typed timeout', () async {
      final p = pool(
        const TomConnectionPoolSettings(
          maxSize: 1,
          acquireTimeout: Duration(milliseconds: 20),
        ),
      );
      await p.acquire();
      await expectLater(
        p.acquire(),
        _poolError('error.datasource.pool.acquire_timeout'),
      );
      expect(p.waitingCount, 0);
    });
  });

  group('retiring', () {
    test('a connection that went down is replaced, not lent', () async {
      final p = pool();
      final a = await p.acquire();
      await p.release(a);
      a.usable = false;
      final b = await p.acquire();
      expect(identical(a, b), isFalse);
      expect(a.closed, isTrue);
    });

    test('a connection released unusable is closed', () async {
      final p = pool();
      final a = await p.acquire();
      a.usable = false;
      await p.release(a);
      expect(a.closed, isTrue);
      expect(p.idleCount, 0);
    });

    test('a briefly idle connection is lent without validation', () async {
      final p = pool();
      final a = await p.acquire();
      await p.release(a);
      now = now.add(const Duration(seconds: 10));
      await p.acquire();
      expect(factory.validations, 0);
    });

    test(
      'a long-idle connection is validated, and replaced when it fails',
      () async {
        final p = pool();
        final a = await p.acquire();
        await p.release(a);
        now = now.add(const Duration(minutes: 1));
        a.valid = false;
        final b = await p.acquire();
        expect(factory.validations, 1);
        expect(identical(a, b), isFalse);
        expect(a.closed, isTrue);
      },
    );

    test('an idle connection past the idle timeout is closed', () async {
      final p = pool();
      final a = await p.acquire();
      final b = await p.acquire();
      await p.release(a);
      now = now.add(const Duration(minutes: 11));
      await p.release(b);
      expect(a.closed, isTrue);
      expect(p.idleConnections, [b]);
    });

    test('minIdle connections survive the idle timeout', () async {
      final p = pool(const TomConnectionPoolSettings(minIdle: 1));
      final a = await p.acquire();
      await p.release(a);
      now = now.add(const Duration(minutes: 11));
      final b = await p.acquire();
      expect(b, same(a));
    });

    test('a connection past its lifetime is replaced on release', () async {
      final p = pool();
      final a = await p.acquire();
      now = now.add(const Duration(minutes: 31));
      await p.release(a);
      expect(a.closed, isTrue);
      expect(p.idleCount, 0);
    });
  });

  group('closing', () {
    test(
      'closes idle connections, then the lent ones as they return',
      () async {
        final p = pool();
        final a = await p.acquire();
        final b = await p.acquire();
        await p.release(a);
        await p.close();
        expect(a.closed, isTrue);
        expect(b.closed, isFalse);
        await p.release(b);
        expect(b.closed, isTrue);
      },
    );

    test('refuses to lend once closed, and fails its waiters', () async {
      final p = pool(const TomConnectionPoolSettings(maxSize: 1));
      await p.acquire();
      final waiting = p.acquire();
      await Future<void>.delayed(Duration.zero);
      final refused = expectLater(
        waiting,
        _poolError('error.datasource.pool.closed'),
      );
      await p.close();
      await refused;
      await expectLater(
        p.acquire(),
        _poolError('error.datasource.pool.closed'),
      );
    });

    test('closing twice is harmless', () async {
      final p = pool();
      await p.close();
      await p.close();
      expect(p.isClosed, isTrue);
    });
  });
}

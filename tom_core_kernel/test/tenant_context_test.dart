/// The tenant context, and the work that carries a tenant out of the request:
/// the token claim, the scheduler's runs, and a command crossing into a worker.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';

/// Records the tenant it ran in.
class _TenantProbe extends TomCommand {
  _TenantProbe(this.seen);

  final List<String?> seen;

  @override
  Future<Object?> execute() async {
    seen.add(TomTenantContext.currentId);
    return null;
  }
}

/// Records its tenant on start and waits for [gate].
class _Gated extends TomCommand {
  _Gated(this.gate, this.started);

  final Completer<void> gate;
  final List<String?> started;

  @override
  Future<Object?> execute() async {
    started.add(TomTenantContext.currentId);
    await gate.future;
    return null;
  }
}

void main() {
  group('the tenant context', () {
    test('holds the tenant for the work run inside it', () {
      expect(TomTenantContext.currentId, isNull);
      expect(TomTenantContext.isSet, isFalse);
      TomTenantContext.run('acme', () {
        expect(TomTenantContext.currentId, 'acme');
        TomTenantContext.run('globex', () {
          expect(TomTenantContext.currentId, 'globex');
        });
        TomTenantContext.run(null, () {
          expect(TomTenantContext.currentId, isNull);
          expect(TomTenantContext.isSet, isTrue);
        });
        expect(TomTenantContext.currentId, 'acme');
      });
    });

    test('follows asynchronous work', () async {
      final seen = await TomTenantContext.run('acme', () async {
        await Future<void>.delayed(Duration.zero);
        return TomTenantContext.currentId;
      });
      expect(seen, 'acme');
    });

    test('a tenant id is a short lower-case identifier', () {
      for (final good in ['acme', 'a', 'tenant_42', 'x' * 32]) {
        TomTenantContext.validate(good);
      }
      for (final bad in ['Acme', '1acme', 'ac-me', 'a.b', '', 'x' * 33]) {
        expect(
          () => TomTenantContext.validate(bad),
          throwsA(
            isA<TomTenantException>().having(
              (e) => e.key,
              'key',
              'tenancy.id.invalid',
            ),
          ),
          reason: bad,
        );
      }
      expect(
        () => TomTenantContext.run('Acme', () {}),
        throwsA(isA<TomTenantException>()),
      );
    });

    test('require names what needed a tenant', () {
      expect(
        () => TomTenantContext.require('A note'),
        throwsA(
          isA<TomTenantException>().having(
            (e) => e.key,
            'key',
            'tenancy.context.missing',
          ),
        ),
      );
      expect(
        TomTenantContext.run('acme', () => TomTenantContext.require('x')),
        'acme',
      );
    });

    test('qualifies a name by tenant, and leaves it alone without one', () {
      expect(TomTenantContext.qualify('alice', 'acme'), 'tenant:acme/alice');
      expect(TomTenantContext.qualify('alice'), 'alice');
    });

    test(
      'a tenant-scoped command runs inside its tenant wherever it runs',
      () async {
        final seen = <String?>[];
        await TomTenantScopedCommand('acme', _TenantProbe(seen)).execute();
        expect(seen, ['acme']);
      },
    );
  });

  group('the token claim', () {
    test('a principal\'s tenant survives the token round trip', () {
      final principal = TomPrincipal(
        user: TomUser(id: 1, username: 'alice'),
        authenticated: true,
        tenant: 'acme',
        organization: 'sales',
      );
      final (
        publicInfo,
        _,
      ) = TomBearerAuthentication.convertPrincipalToTokenPayload(
        principal,
        null,
        null,
        null,
      );
      expect(publicInfo['tenant'], 'acme');
    });
  });

  group('the scheduler', () {
    late TomMemoryJobStore store;
    late TomScheduler scheduler;
    late StreamController<Object?> events;
    late List<String?> seen;
    final now = DateTime.utc(2026, 10, 13, 9);

    setUp(() {
      store = TomMemoryJobStore();
      seen = [];
      events = StreamController<Object?>.broadcast();
      scheduler = TomScheduler(
        store: store,
        dispatcher: const TomInlineJobDispatcher(),
        clock: () => now,
      );
      scheduler.register(
        TomJobDefinition(
          name: 'tenant-job',
          schedule: TomEventSchedule(events.stream),
          body: (run) {
            // The factory itself runs inside the tenant.
            seen.add('factory:${TomTenantContext.currentId}');
            return _TenantProbe(seen);
          },
        ),
      );
    });

    tearDown(() async {
      await scheduler.close();
      await events.close();
    });

    test(
      'a tenant event becomes a run of that tenant, executed inside it',
      () async {
        events.add(TomTenantEvent('acme', {'n': 1}));
        await pumpEventQueue();
        final run = (await store.all()).single;
        expect(run.tenant, 'acme');
        expect(run.payload, {'n': 1});

        await scheduler.tick();
        await scheduler.drain();
        expect(seen, ['factory:acme', 'acme']);
      },
    );

    test('two tenants\' events in the same instant are two runs', () async {
      events
        ..add(TomTenantEvent('acme', 'a'))
        ..add(TomTenantEvent('globex', 'b'))
        ..add(TomTenantEvent('acme', 'a-again'));
      await pumpEventQueue();
      final runs = await store.all();
      expect({for (final run in runs) run.tenant}, {'acme', 'globex'});
      expect(runs, hasLength(2));
    });

    test('an event raised in a tenant\'s context names it', () async {
      TomTenantContext.run(
        'globex',
        () => events.add(TomTenantEvent.inCurrentTenant('x')),
      );
      await pumpEventQueue();
      expect((await store.all()).single.tenant, 'globex');
    });

    test('overlap protection is per tenant: one tenant\'s run does not wait '
        'for another\'s', () async {
      final gate = Completer<void>();
      final started = <String?>[];
      scheduler.register(
        TomJobDefinition(
          name: 'slow',
          schedule: TomEventSchedule(events.stream),
          body: (run) => _Gated(gate, started),
        ),
      );
      events
        ..add(TomTenantEvent('acme', 1))
        ..add(TomTenantEvent('globex', 2));
      await pumpEventQueue();
      await scheduler.tick();
      await pumpEventQueue();
      expect(started, unorderedEquals(['acme', 'globex']));
      gate.complete();
      await scheduler.drain();
    });

    test('a plain event is a run of no tenant', () async {
      events.add('plain');
      await pumpEventQueue();
      await scheduler.tick();
      await scheduler.drain();
      expect((await store.all()).single.tenant, isNull);
      expect(seen, ['factory:null', null]);
    });
  });

  test('a run\'s tenant survives serialization', () {
    final run = TomJobRun(
      id: 'r',
      jobName: 'j',
      scheduledFor: DateTime.utc(2026),
      runAt: DateTime.utc(2026),
      tenant: 'acme',
    );
    expect(TomJobRun.fromJson(run.toJson()).tenant, 'acme');
  });
}

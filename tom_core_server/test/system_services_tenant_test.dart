/// The system services that queue work for tenants keep each item in the
/// tenant it was raised in, without a database: the outbox and the bus relay
/// file two tenants' messages of one id apart and send each in its tenant; a
/// relayed message reaches its consumer in its tenant; a digest is per
/// tenant; a cache emptied in a tenant loses that tenant's entries only; an
/// audit question is answered and delivered in its auditor's tenant, and held
/// while that tenant is not served; the installed tenancy answers the
/// scheduler which tenants a per-tenant job is planned for.
///
/// `system_services_tenant_db_test.dart` covers the services over SQL tables.
library;

import 'package:test/test.dart';
import 'package:tom_core_message_bus/tom_core_message_bus.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

TomMessage _mail(String id) => TomMessage.email(
  id: id,
  to: [TomRecipient('ada@example.com')],
  from: TomRecipient('shop@example.com'),
  subject: 'Subject',
  text: 'Body',
);

TomAuditRecord _record(String id, String? tenant) => TomAuditRecord(
  id: id,
  timestamp: DateTime.utc(2026, 11, 7, 9),
  actor: const TomAuditActor(username: 'ada', userId: 'ada'),
  action: TomAuditAction.update,
  target: 'Order',
  targetKey: id,
  outcome: TomAuditOutcome.succeeded,
  tenant: tenant,
);

void main() {
  setUpAll(initializeReflection);

  group('the outbox', () {
    test('ST-1: two tenants queue the same message id as two messages, each '
        'delivered in its tenant', () async {
      final transport = TomMemoryMessageTransport();
      final outbox = TomMessageOutbox(router: TomMessageRouter([transport]));
      addTearDown(outbox.close);
      for (final tenant in ['acme', 'globex']) {
        expect(
          await TomTenantContext.run(tenant, () => outbox.send(_mail('m-1'))),
          isTrue,
        );
      }
      expect(
        await TomTenantContext.run('acme', () => outbox.send(_mail('m-1'))),
        isFalse,
        reason: 'the same tenant\'s message is queued once',
      );
      final runs = await outbox.store.all();
      expect(runs.map((r) => r.tenant).toList()..sort(), ['acme', 'globex']);
      expect(runs.map((r) => r.id).toSet(), {
        TomTenantContext.run('acme', () => outbox.runIdOf('m-1')),
        TomTenantContext.run('globex', () => outbox.runIdOf('m-1')),
      });
      await outbox.tick();
      expect(transport.count, 2);
    });
  });

  group('the bus relay', () {
    test('ST-2: two tenants relay the same message id as two messages; each '
        'reaches the consumer in its tenant', () async {
      final bus = TomMemoryMessageBus();
      final relay = TomBusRelay(bus: bus);
      addTearDown(() async {
        await relay.close();
        await bus.close();
      });
      final seen = <String?>[];
      await bus.subscribe<Object?>(
        'orders',
        group: 'billing',
        handler: (d) => seen.add(TomTenantContext.currentId),
      );
      for (final tenant in ['acme', 'globex']) {
        await TomTenantContext.run(
          tenant,
          () => relay.publish('orders', {'order': 1}, id: 'o-1'),
        );
      }
      await relay.tick();
      await bus.settled();
      expect(seen..sort(), ['acme', 'globex']);
    });
  });

  group('notification digests', () {
    test('ST-3: two tenants\' recipients of one id collect two digests, each '
        'in its tenant', () async {
      final outbox = TomMessageOutbox(
        router: TomMessageRouter([TomMemoryMessageTransport()]),
      );
      addTearDown(outbox.close);
      final digests = TomNotificationDigests(
        outbox: outbox,
        renderer: TomTemplatedNotificationRenderer(
          texts: TomLocalizedTextResources(
            defaultLocale: TomTextLocale('en'),
            bundles: const {},
          ),
        ),
      );
      addTearDown(digests.close);
      final due = DateTime.utc(2026, 11, 10, 18);
      final type = TomNotificationType(
        name: 'taskAssigned',
        allowedChannels: {TomMessageChannel.email},
      );
      // A principal that names no tenant: its id is the same in both.
      final u1 = TomPrincipal(
        user: TomUser(id: 'u1', username: 'u1'),
      );
      for (final tenant in ['acme', 'globex']) {
        await TomTenantContext.run(
          tenant,
          () => digests.add(
            notification: TomNotification(type: type, id: 'n-$tenant'),
            recipient: TomNotificationRecipient(
              principal: u1,
              addresses: {
                TomMessageChannel.email: [TomRecipient('u1@$tenant.example')],
              },
            ),
            channel: TomMessageChannel.email,
            dueAt: due,
            messageId: 'n-$tenant-u1',
          ),
        );
      }
      final runs = await digests.store.all();
      expect(runs.map((r) => r.tenant).toList()..sort(), ['acme', 'globex']);
      expect(runs.map((r) => r.id).toSet(), hasLength(2));
    });
  });

  group('the cache invalidation channel', () {
    test('ST-4: a cache emptied in a tenant loses that tenant\'s entries '
        'only; emptied outside any tenant, every entry', () async {
      final cache = TomCache('st_cache');
      TomCacheManager.addCache(cache);
      addTearDown(() => TomCacheManager.removeCache('st_cache'));
      Future<void> put(String? tenant) => TomTenantContext.run(
        tenant,
        () => TomCache.toNameCache('st_cache', 'k', 'v-$tenant'),
      );
      Future<Object?> get(String? tenant) => TomTenantContext.run(
        tenant,
        () => TomCache.fromNameCache<String>('st_cache', 'k'),
      );
      for (final tenant in ['acme', 'globex', null]) {
        await put(tenant);
      }
      await TomTenantContext.run(
        'acme',
        () => TomCacheInvalidator.invalidateCache('st_cache'),
      );
      expect(await get('acme'), isNull);
      expect(await get('globex'), 'v-globex');
      expect(await get(null), 'v-null');

      await TomCacheInvalidator.invalidateCache('st_cache');
      expect(await get('globex'), isNull);
      expect(await get(null), isNull);
    });

    test('ST-5: the tenant travels with the invalidation', () {
      final invalidation = TomCacheInvalidation.cache(
        'st_cache',
        tenant: 'acme',
      );
      final back = TomCacheInvalidation.fromParts(
        kind: invalidation.kind.name,
        target: invalidation.target,
        key: invalidation.key,
        at: invalidation.at,
        origin: invalidation.origin,
      );
      expect(back.key, 'acme');
    });
  });

  group('audit reports and the scheduler under a tenancy', () {
    late TomMemoryTenantRegistry registry;
    late TomTenancy tenancy;

    setUp(() async {
      registry = TomMemoryTenantRegistry();
      for (final name in ['main', 'acme_db', 'globex_db']) {
        TomDataSourceInfo.datasources[name] = TomDataSourceInfo(name, const {});
      }
      tenancy = TomTenancy(
        tenants: [
          for (final id in ['acme', 'globex'])
            TomTenant(
              id,
              isolation: TomTenantIsolation.database,
              datasources: {'main': '${id}_db'},
            ),
        ],
        registry: registry,
      );
      await TomTenancy.install(tenancy);
    });

    tearDown(() async {
      await TomTenancy.reset();
      TomAuditTrail.uninstall();
      TomDataSourceInfo.datasources.clear();
    });

    test('ST-6: the tenancy answers the scheduler its active tenants, by '
        'type', () async {
      expect(TomScheduler.tenantsFor!(const []), ['acme', 'globex']);
      expect(TomScheduler.tenantsFor!(const ['default']), ['acme', 'globex']);
      expect(TomScheduler.tenantsFor!(const ['enterprise']), isEmpty);
      await tenancy.suspendTenant('acme');
      expect(TomScheduler.tenantsFor!(const []), ['globex']);
      await TomTenancy.reset();
      expect(TomScheduler.tenantsFor, isNull);
    });

    test('ST-7: a question asked in a tenant reads that tenant\'s entries; '
        'outside any tenant every entry', () async {
      final sink = TomMemoryAuditSink();
      for (final (id, tenant) in [
        ('a1', 'acme'),
        ('g1', 'globex'),
        ('s1', null),
      ]) {
        await sink.write(_record(id, tenant));
      }
      final reports = TomAuditReports(
        view: TomAuditView(TomMemoryAuditTrailSource({'node': sink})),
        questions: TomMemoryAuditQuestionStore(),
      );
      Future<List<String>> ids(String? tenant) async => [
        for (final e in (await TomTenantContext.run(
          tenant,
          () => reports.ask(TomAuditQuestionFilter()),
        )).entries)
          e.entry.record.id,
      ];
      expect(await ids('acme'), ['a1']);
      expect(await ids('globex'), ['g1']);
      expect((await ids(null))..sort(), ['a1', 'g1', 's1']);
    });

    test('ST-8: a due question is delivered in its auditor\'s tenant, held '
        'while that tenant is suspended, and purged with it', () async {
      final trail = TomMemoryAuditSink();
      TomAuditTrail.install(trail);
      final questions = TomMemoryAuditQuestionStore();
      final now = DateTime.utc(2026, 11, 10, 6);
      final reports = TomAuditReports(
        view: TomAuditView(TomMemoryAuditTrailSource({'node': trail})),
        questions: questions,
        clock: () => now,
      );
      for (final tenant in ['acme', 'globex']) {
        await questions.save(
          TomAuditQuestion(
            id: 'q-$tenant',
            name: 'All',
            owner: TomTenantContext.qualify('u1', tenant),
            filter: TomAuditQuestionFilter(),
            recipients: const ['auditor@example.com'],
            nextDeliveryAt: now,
          ),
        );
      }
      await tenancy.suspendTenant('globex');
      final delivered = await reports.deliverDue();
      expect(delivered.map((d) => d.question.id), ['q-acme']);
      // No export service here: the delivery fails, and its audit entry is
      // the tenant's.
      final entry = trail.entries.single.record;
      expect(entry.targetKey, 'q-acme');
      expect(entry.tenant, 'acme');
      expect(
        (await questions.find('q-globex'))!.nextDeliveryAt,
        now,
        reason: 'held: still due',
      );

      expect(await questions.purgeTenant('globex'), 1);
      expect(await questions.find('q-globex'), isNull);
      expect(await questions.find('q-acme'), isNotNull);
    });
  });
}

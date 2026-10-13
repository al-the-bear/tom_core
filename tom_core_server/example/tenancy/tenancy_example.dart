/// Multi-tenancy, step by step, without a database.
///
/// Run with `dart run example/tenancy/tenancy_example.dart`.
///
/// Two tenants, `acme` and `globex`, share one deployment: requests name their
/// tenant, a token binds to it, caches, revocations, jobs and the outbox keep
/// the two apart. Where each tenant's rows live — a shared table, a schema of
/// its own, a database of its own — needs a database to show, and
/// `test/tenancy_db_test.dart` shows it under all three. Every step checks its
/// own result, and the run fails when one does not hold.
library;

import 'dart:async';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';

/// Records the tenant a job body ran in.
class _Probe extends TomCommand {
  _Probe(this.seen);

  final List<String?> seen;

  @override
  Future<Object?> execute() async {
    seen.add(TomTenantContext.currentId);
    return null;
  }
}

/// Records the tenant each message was delivered in.
class _Transport extends TomMessageTransport {
  final Map<String, String?> deliveredIn = {};

  @override
  TomMessageChannel get channel => TomMessageChannel.email;

  @override
  Future<TomDeliveryReceipt> send(TomMessage message) async {
    deliveredIn[message.id] = TomTenantContext.currentId;
    return TomDeliveryReceipt(
      messageId: message.id,
      outcome: TomDeliveryOutcome.delivered,
    );
  }
}

Future<void> main() async {
  // The deployment's tenants. Both share the database here; one line per
  // tenant would give either a schema or a database of its own.
  final tenancy = TomTenancy(
    tenants: [
      TomTenant('acme', name: 'Acme'),
      TomTenant('globex', name: 'Globex'),
    ],
    resolvers: const [
      TomTenantHostResolver(suffix: 'app.example.com'),
      TomTenantHeaderResolver(),
    ],
  );
  await TomTenancy.install(tenancy);

  // 1. A request names its tenant by its host, or by a header.
  final byHost = tenancy.resolveRequest(
    Request('GET', Uri.parse('https://acme.app.example.com/')),
  );
  final byHeader = tenancy.resolveRequest(
    Request(
      'GET',
      Uri.parse('https://app.example.com/'),
      headers: {'x-tenant-id': 'globex'},
    ),
  );
  print('1. by host / by header      : ${byHost.tenant} / ${byHeader.tenant}');
  check(
    byHost.tenant == 'acme' && byHeader.tenant == 'globex',
    'the host and the header each name a tenant',
  );

  // 2. Once signed in, the token's claim decides; naming another tenant is
  //    refused.
  final conflict = tenancy.resolveRequest(
    Request(
      'GET',
      Uri.parse('https://app.example.com/'),
      headers: {'x-tenant-id': 'globex'},
    ),
    claim: 'acme',
  );
  print('2. acme token, globex header: ${conflict.status} ${conflict.key}');
  check(
    conflict.status == 403 && conflict.key == 'tenancy.resolution.conflict',
    'a token is not a pass to another tenant',
  );

  // 3. A login in a tenant's context binds the token to it.
  final saved = TomAuthenticationServer.globalSettingUserAuthenticationService;
  TomAuthenticationServer.globalSettingUserAuthenticationService =
      TomDummyAuthenticationService()..showErrorMessage = false;
  final login = await tenancy.runFor(
    'acme',
    () => TomAuthenticationServer().authenticatePass1(
      TomAuthenticationMessage()
        ..userName = 'alice'
        ..password = 'secret'
        ..organization = 'sales'
        ..clientLanguage = 'en'
        ..clientCountry = 'US'
        ..clientTimezone = 'UTC',
    ),
  );
  TomAuthenticationServer.globalSettingUserAuthenticationService = saved;
  final claims = TomClientJwtToken(
    login.authenticationToken,
    decrypt: false,
  ).payload!;
  print(
    '3. token tenant / org       : ${claims['tenant']} / '
    '${claims['organization']}',
  );
  check(
    claims['tenant'] == 'acme' && claims['organization'] == 'sales',
    'the token carries the tenant, and the organization separately',
  );

  // 4. Two tenants caching one key hold two entries.
  final cache = TomCache('example-tenancy');
  TomCacheManager.addCache(cache);
  await tenancy.runFor(
    'acme',
    () => TomCache.toNameCache('example-tenancy', 'plan', 'gold'),
  );
  final globexPlan = await tenancy.runFor(
    'globex',
    () => TomCache.fromNameCache<String>('example-tenancy', 'plan'),
  );
  final acmePlan = await tenancy.runFor(
    'acme',
    () => TomCache.fromNameCache<String>('example-tenancy', 'plan'),
  );
  print('4. acme / globex "plan"     : $acmePlan / $globexPlan');
  check(
    acmePlan == 'gold' && globexPlan == null,
    'a cache entry is the tenant\'s own',
  );
  TomCacheManager.removeCache('example-tenancy');
  cache.stopTimers();

  // 5. Revoking alice in acme leaves globex's alice — another person — alone.
  await tenancy.runFor(
    'acme',
    () => TomCacheInvalidator.revokePrincipal('alice'),
  );
  final acmeAliceRevoked = TomAuthorizationCache.revokedAt(
    TomTenantContext.qualify('alice', 'acme'),
  );
  final globexAliceRevoked = TomAuthorizationCache.revokedAt(
    TomTenantContext.qualify('alice', 'globex'),
  );
  print(
    '5. acme / globex alice revoked: ${acmeAliceRevoked != null} / '
    '${globexAliceRevoked != null}',
  );
  check(
    acmeAliceRevoked != null && globexAliceRevoked == null,
    'a revocation is the tenant\'s own',
  );
  TomAuthorizationCache.instance.dispose();

  // 6. A job run carries its tenant, and its body runs inside it.
  final events = StreamController<Object?>.broadcast();
  final seen = <String?>[];
  final scheduler =
      TomScheduler(
        store: TomMemoryJobStore(),
        dispatcher: const TomInlineJobDispatcher(),
      )..register(
        TomJobDefinition(
          name: 'example-tenancy-job',
          schedule: TomEventSchedule(events.stream),
          body: (_) => _Probe(seen),
        ),
      );
  await tenancy.runFor(
    'globex',
    () => events.add(TomTenantEvent.inCurrentTenant(null)),
  );
  events.add(TomTenantEvent('acme', null));
  await Future<void>.delayed(Duration.zero);
  await scheduler.tick();
  await scheduler.drain();
  print('6. job bodies ran in        : $seen');
  check(
    seen.length == 2 && seen.toSet().containsAll(['acme', 'globex']),
    'each run executes inside the tenant that raised it',
  );
  await scheduler.close();
  await events.close();

  // 7. The outbox delivers a message inside the tenant that sent it.
  final transport = _Transport();
  final outbox = TomMessageOutbox(router: TomMessageRouter([transport]));
  TomMessage mail(String id) => TomMessage.email(
    id: id,
    to: [TomRecipient('someone@example.com')],
    subject: id,
    text: id,
  );
  await tenancy.runFor('acme', () => outbox.send(mail('welcome-acme')));
  await tenancy.runFor('globex', () => outbox.send(mail('welcome-globex')));
  await outbox.tick();
  print('7. delivered in             : ${transport.deliveredIn}');
  check(
    transport.deliveredIn['welcome-acme'] == 'acme' &&
        transport.deliveredIn['welcome-globex'] == 'globex',
    'each message is delivered inside its own tenant',
  );
  await outbox.close();

  // 8. Work for a tenant the deployment does not have is refused.
  var refusal = '';
  try {
    await tenancy.runFor('initech', () => null);
  } on TomTenancyException catch (e) {
    refusal = e.key;
  }
  print('8. an unknown tenant        : $refusal');
  check(
    refusal == 'tenancy.tenant.unknown',
    'there is no tenant the deployment does not have',
  );

  await TomTenancy.reset();
}

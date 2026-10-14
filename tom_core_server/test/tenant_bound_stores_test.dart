/// The framework stores that follow the tenant, without a database: SCIM (its
/// resources and the secrets its callers present), the pending state of an
/// external sign-in, and the external-identity provider sets.
///
/// The database half — the SQL SCIM store routed per tenant under every
/// isolation model, the SQL state store's tenant predicate — is
/// tenant_bound_stores_db_test.dart.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart' show registerFixtureAccessApi;
import 'fixtures/reflection_fixture.reflection.dart';

const _acmeToken = 'scim-secret-acme';
const _globexToken = 'scim-secret-globex';
const _deploymentToken = 'scim-secret-deployment';

/// Two tenants, named by subdomain of `app.example.test`.
TomTenancy _tenancy() => TomTenancy(
  tenants: [TomTenant('acme'), TomTenant('globex')],
  resolvers: const [TomTenantHostResolver(suffix: 'app.example.test')],
);

TomOAuthProviderConfig _provider(String id) =>
    TomOAuthProviderConfig.fromMap(id, {
      'issuer': 'https://$id.example.test',
      'authorizationEndpoint': 'https://$id.example.test/authorize',
      'tokenEndpoint': 'https://$id.example.test/token',
      'clientId': 'client-$id',
      'clientSecret': 'secret-$id',
      'redirectUri': 'https://app.example.test/oauth/callback',
      'scopes': ['openid'],
    });

void main() {
  setUpAll(() {
    initializeReflection();
    registerFixtureAccessApi();
  });
  tearDown(TomTenancy.reset);

  group('SCIM per tenant', () {
    late Handler pipeline;

    setUp(() async {
      await TomTenancy.install(_tenancy());
      TomBean.resetBeanContext();
      TomBean.withType<TomScimServer>(const TomScimServer());
      TomScimProvisioning.install(
        TomScimProvisioning(
          service: TomScimService(TomMemoryScimStore(), revoke: (_) async {}),
          bearerTokens: const [_deploymentToken],
          tenantBearerTokens: const {
            'acme': [_acmeToken],
            'globex': [_globexToken],
          },
        ),
      );
      final router = TomEndpointRouting().initializeRouter();
      pipeline = tomDefaultAuthenticationMiddleware('scim-tenancy-test')(
        router.call,
      );
    });

    tearDown(() {
      TomScimProvisioning.reset();
      TomBean.resetBeanContext();
    });

    /// A SCIM call to [tenant]'s host (or the bare host) with [token].
    Future<(int, Map<String, Object?>)> call(
      String method,
      String path, {
      String? tenant,
      required String token,
      Object? body,
    }) async {
      final host = tenant == null
          ? 'app.example.test'
          : '$tenant.app.example.test';
      final response = await pipeline(
        Request(
          method,
          Uri.parse('https://$host/scim/v2$path'),
          body: body == null ? null : jsonEncode(body),
          headers: {
            'content-type': 'application/scim+json',
            'authorization': 'Bearer $token',
          },
          context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
        ),
      );
      final text = await response.readAsString();
      return (
        response.statusCode,
        text.isEmpty
            ? const <String, Object?>{}
            : (jsonDecode(text) as Map).cast<String, Object?>(),
      );
    }

    Map<String, Object?> user(String name) => {
      'schemas': [TomScimSchemas.user],
      'userName': name,
      'active': true,
    };

    List<String> userNames(Map<String, Object?> list) => [
      for (final resource in (list['Resources'] as List).cast<Map>())
        '${resource['userName']}',
    ];

    test('two tenants\' clients see only their own users', () async {
      expect(
        (await call(
          'POST',
          '/Users',
          tenant: 'acme',
          token: _acmeToken,
          body: user('alice'),
        )).$1,
        201,
      );
      // The same userName in the other tenant is another person, not a clash.
      expect(
        (await call(
          'POST',
          '/Users',
          tenant: 'globex',
          token: _globexToken,
          body: user('alice'),
        )).$1,
        201,
      );
      expect(
        (await call(
          'POST',
          '/Users',
          tenant: 'globex',
          token: _globexToken,
          body: user('bob'),
        )).$1,
        201,
      );

      final acme = await call(
        'GET',
        '/Users',
        tenant: 'acme',
        token: _acmeToken,
      );
      final globex = await call(
        'GET',
        '/Users',
        tenant: 'globex',
        token: _globexToken,
      );
      expect(acme.$1, 200);
      expect(userNames(acme.$2), ['alice']);
      expect(userNames(globex.$2)..sort(), ['alice', 'bob']);
    });

    test('a tenant admits only its own secret', () async {
      expect(
        (await call('GET', '/Users', tenant: 'acme', token: _globexToken)).$1,
        401,
        reason: 'another tenant\'s secret',
      );
      expect(
        (await call(
          'GET',
          '/Users',
          tenant: 'acme',
          token: _deploymentToken,
        )).$1,
        401,
        reason: 'the deployment\'s secret writes into no tenant',
      );
      expect(
        (await call('GET', '/Users', token: _acmeToken)).$1,
        401,
        reason: 'a tenant\'s secret admits nothing outside its tenant',
      );
      expect((await call('GET', '/Users', token: _deploymentToken)).$1, 200);
    });

    test('the secrets are read per tenant from the configuration', () {
      final provisioning = TomScimProvisioning.fromConfiguration(
        TomScimService(TomMemoryScimStore()),
        TomServerConfigResourceProvider.from({
          'scim': {
            'tenants': {
              'acme': {
                'bearerTokens': [_acmeToken],
              },
              'globex': {'bearerTokens': _globexToken},
            },
          },
        }),
      );
      expect(provisioning.tenants, {'acme', 'globex'});
      expect(
        TomTenantContext.run(
          'acme',
          () => provisioning.authorizes('Bearer $_acmeToken'),
        ),
        isTrue,
      );
      expect(
        TomTenantContext.run(
          'globex',
          () => provisioning.authorizes('Bearer $_acmeToken'),
        ),
        isFalse,
      );
    });
  });

  group('the memory SCIM store per tenant', () {
    test('keeps an id sequence per tenant', () async {
      final store = TomMemoryScimStore();
      final acme = await TomTenantContext.run(
        'acme',
        () => store.create(TomScimResourceType.user, {'userName': 'alice'}),
      );
      final globex = await TomTenantContext.run(
        'globex',
        () => store.create(TomScimResourceType.user, {'userName': 'alice'}),
      );
      expect(acme.id, '1');
      expect(globex.id, '1');
      expect(
        await TomTenantContext.run(
          'globex',
          () => store.delete(TomScimResourceType.user, '1'),
        ),
        isTrue,
      );
      expect(
        await TomTenantContext.run(
          'acme',
          () => store.read(TomScimResourceType.user, '1'),
        ),
        isNotNull,
        reason: 'globex removed its own user 1, not acme\'s',
      );
      expect(await store.list(TomScimResourceType.user), isEmpty);
    });
  });

  group('the pending sign-in state per tenant', () {
    test(
      'a record is found and spent only in the tenant it began in',
      () async {
        final store = TomOAuthMemoryStateStore();
        await TomTenantContext.run(
          'acme',
          () => store.store(
            TomOAuthAuthorizationState(
              state: 's1',
              providerId: 'staff',
              createdAt: DateTime.now().toUtc(),
            ),
          ),
        );
        expect(
          await TomTenantContext.run('globex', () => store.consume('s1')),
          isNull,
        );
        expect(await store.peek('s1'), isNull);
        final record = await TomTenantContext.run(
          'acme',
          () => store.consume('s1'),
        );
        expect(record?.tenant, 'acme');
        expect(
          await TomTenantContext.run('acme', () => store.consume('s1')),
          isNull,
        );
      },
    );
  });

  group('provider sets per tenant', () {
    setUp(() {
      TomBean.resetBeanContext();
      TomOAuthProviders.tenants.clear();
      TomSamlProviders.tenants.clear();
      TomBean.withType<TomOAuthProviders>(
        TomOAuthProviders({'google': _provider('google')}),
      );
    });

    tearDown(() {
      TomOAuthProviders.tenants.clear();
      TomSamlProviders.tenants.clear();
      TomBean.resetBeanContext();
    });

    Set<String> idsIn(String? tenant) => TomTenantContext.run(
      tenant,
      () => TomOAuthProviders.resolve()!.providers.keys.toSet(),
    );

    test('a tenant with a set of its own sees only it', () {
      TomOAuthProviders.tenants.install(
        'acme',
        TomOAuthProviders({'staff': _provider('staff')}),
      );
      expect(idsIn('acme'), {'staff'});
      expect(idsIn('globex'), {'google'}, reason: 'the deployment\'s set');
      expect(idsIn(null), {'google'});

      TomOAuthProviders.tenants.remove('acme');
      expect(idsIn('acme'), {'google'});
    });

    test('a flow in a tenant offers that tenant\'s providers', () {
      TomOAuthProviders.tenants.install(
        'acme',
        TomOAuthProviders({'staff': _provider('staff')}),
      );
      final offered = TomTenantContext.run(
        'acme',
        () => [for (final d in TomOAuthFlow.fromBeans().descriptors) d.id],
      );
      expect(offered, ['staff']);
    });

    test('the sets are read per tenant from the configuration', () async {
      await TomOAuthProviders.loadTenants(
        config: TomServerConfigResourceProvider.from({
          'oauth': {
            'tenants': {
              'acme': {
                'providers': {
                  'staff': {
                    'issuer': 'https://staff.example.test',
                    'authorizationEndpoint':
                        'https://staff.example.test/authorize',
                    'tokenEndpoint': 'https://staff.example.test/token',
                    'clientId': 'client-staff',
                    'clientSecret': 'secret-staff',
                    'redirectUri': 'https://acme.app.example.test/callback',
                    'scopes': ['openid'],
                  },
                },
              },
            },
          },
        }),
      );
      expect(TomOAuthProviders.tenants.tenants, {'acme'});
      expect(idsIn('acme'), {'staff'});
    });

    test('a tenants block that is not a map is refused', () async {
      await expectLater(
        TomOAuthProviders.loadTenants(
          config: TomServerConfigResourceProvider.from({
            'oauth': {'tenants': 'acme'},
          }),
        ),
        throwsA(
          isA<TomOAuthException>().having(
            (e) => e.key,
            'key',
            'oauth.config.tenants_not_a_map',
          ),
        ),
      );
    });

    test('a SAML tenants block that is not a map is refused', () async {
      await expectLater(
        TomSamlProviders.loadTenants(
          config: TomServerConfigResourceProvider.from({
            'saml': {
              'tenants': {'acme': 'staff'},
            },
          }),
        ),
        throwsA(
          isA<TomSamlException>().having(
            (e) => e.key,
            'key',
            'saml.config.tenants_not_a_map',
          ),
        ),
      );
    });

    test('an id that is not a tenant id is refused', () {
      expect(
        () => TomSamlProviders.tenants.install(
          'Not A Tenant',
          TomSamlProviders({}),
        ),
        throwsA(isA<TomTenantException>()),
      );
    });
  });
}

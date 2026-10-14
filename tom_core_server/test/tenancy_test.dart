/// Multi-tenancy without a database: how a request's tenant is resolved, how
/// the configuration is read, how the request pipeline runs a request inside
/// its tenant, how routing refuses a tenant that does not exist, and how a
/// login binds its token to the tenant it happened in.
///
/// What crosses tenants through storage is `tenancy_db_test.dart`.
library;

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

Request _request({
  String host = 'app.example.test',
  Map<String, String> headers = const {},
}) => Request('GET', Uri.parse('https://$host/things'), headers: headers);

Request _at(String path, {Map<String, String> headers = const {}}) => Request(
  'GET',
  Uri.parse('https://app.example.test$path'),
  headers: headers,
);

/// A deployment whose URLs name tenants by a slug: `acme-gmbh` is `acme`.
TomTenancy _bySlug() => _tenancy(
  resolvers: [
    TomTenantPathResolver(
      lookup: (segment) =>
          const {'acme-gmbh': 'acme', 'globex': 'globex'}[segment],
    ),
  ],
);

TomTenancy _tenancy({List<TomTenantResolver>? resolvers}) => TomTenancy(
  tenants: [TomTenant('acme'), TomTenant('globex')],
  datasources: const {'tenant_data'},
  resolvers:
      resolvers ??
      const [
        TomTenantHostResolver(
          suffix: 'app.example.test',
          hosts: {'portal.globex.test': 'globex'},
        ),
        TomTenantHeaderResolver(),
      ],
);

/// A token signed by this deployment, carrying [claims].
String _signed(Map<String, dynamic> claims) =>
    TomServerJwtToken(claims).getJWT(TomJwtSigning.current.issuer);

void main() {
  tearDown(TomTenancy.reset);

  group('resolving a request\'s tenant', () {
    final tenancy = _tenancy();

    test('by a subdomain, or by a host of its own', () {
      expect(
        tenancy.resolveRequest(_request(host: 'acme.app.example.test')).tenant,
        'acme',
      );
      expect(
        tenancy.resolveRequest(_request(host: 'portal.globex.test')).tenant,
        'globex',
      );
      expect(
        tenancy.resolveRequest(_request(host: 'a.b.app.example.test')).tenant,
        isNull,
        reason: 'one label only',
      );
    });

    test('by a header, when the host names none', () {
      expect(
        tenancy
            .resolveRequest(_request(headers: {'x-tenant-id': 'globex'}))
            .tenant,
        'globex',
      );
    });

    test('the token claim is authoritative', () {
      expect(tenancy.resolveRequest(_request(), claim: 'acme').tenant, 'acme');
      expect(
        tenancy
            .resolveRequest(
              _request(host: 'acme.app.example.test'),
              claim: 'acme',
            )
            .tenant,
        'acme',
      );
    });

    test('a request naming another tenant than its token is refused', () {
      final refused = tenancy.resolveRequest(
        _request(headers: {'x-tenant-id': 'globex'}),
        claim: 'acme',
      );
      expect(refused.isRejected, isTrue);
      expect(refused.status, 403);
      expect(refused.key, 'tenancy.resolution.conflict');
    });

    test('an unknown or malformed tenant is refused; none is not', () {
      final unknown = tenancy.resolveRequest(
        _request(headers: {'x-tenant-id': 'initech'}),
      );
      expect((unknown.status, unknown.key), (404, 'tenancy.tenant.unknown'));
      final malformed = tenancy.resolveRequest(
        _request(headers: {'x-tenant-id': 'Not A Tenant'}),
      );
      expect((malformed.status, malformed.key), (400, 'tenancy.id.invalid'));
      final none = tenancy.resolveRequest(_request());
      expect(none.isRejected, isFalse);
      expect(none.tenant, isNull);
    });
  });

  group('resolving a request\'s tenant by its path', () {
    test('a slug the lookup maps names its tenant', () {
      final tenancy = _bySlug();
      expect(
        tenancy.resolveRequest(_at('/t/acme-gmbh/sign-in')).tenant,
        'acme',
      );
      expect(tenancy.resolveRequest(_at('/t/globex')).tenant, 'globex');
    });

    test('an unknown slug is refused, not taken for no tenant', () {
      final unknown = _bySlug().resolveRequest(_at('/t/initech/sign-in'));
      expect((unknown.status, unknown.key), (404, 'tenancy.tenant.unknown'));
    });

    test('a path outside the prefix names no tenant', () {
      final tenancy = _bySlug();
      for (final path in ['/sign-in', '/t', '/t/', '/u/acme-gmbh', '/']) {
        final none = tenancy.resolveRequest(_at(path));
        expect(none.isRejected, isFalse, reason: path);
        expect(none.tenant, isNull, reason: path);
      }
    });

    test('without a lookup the segment is the tenant id', () {
      final tenancy = _tenancy(resolvers: const [TomTenantPathResolver()]);
      expect(tenancy.resolveRequest(_at('/t/globex/x')).tenant, 'globex');
      final unknown = tenancy.resolveRequest(_at('/t/initech/x'));
      expect((unknown.status, unknown.key), (404, 'tenancy.tenant.unknown'));
      final malformed = tenancy.resolveRequest(_at('/t/Not%20A%20Tenant/x'));
      expect((malformed.status, malformed.key), (400, 'tenancy.id.invalid'));
    });

    test('a prefix of several segments', () {
      final tenancy = _tenancy(
        resolvers: const [TomTenantPathResolver(prefix: '/api/t/')],
      );
      expect(tenancy.resolveRequest(_at('/api/t/acme/users')).tenant, 'acme');
      expect(tenancy.resolveRequest(_at('/t/acme/users')).tenant, isNull);
    });

    test('a token for another tenant is refused', () {
      final refused = _bySlug().resolveRequest(
        _at('/t/acme-gmbh/users'),
        claim: 'globex',
      );
      expect(
        (refused.status, refused.key),
        (403, 'tenancy.resolution.conflict'),
      );
      expect(
        _bySlug()
            .resolveRequest(_at('/t/acme-gmbh/users'), claim: 'acme')
            .tenant,
        'acme',
      );
    });
  });

  group('the configuration', () {
    test('reads tenants, models, data sources and resolution', () {
      final tenancy = TomTenancy.fromConfiguration(
        TomServerConfigResourceProvider.from({
          'tenancy': {
            'isolation': 'schema',
            'datasources': ['main', 'reporting'],
            'resolution': ['host', 'header'],
            'hostSuffix': 'app.example.com',
            'header': 'X-Customer',
            'createSchemas': true,
            'tenants': {
              'acme': null,
              'globex': {'isolation': 'shared', 'name': 'Globex'},
              'initech': {
                'isolation': 'database',
                'datasources': {
                  'main': {'type': 'mariadb', 'databaseName': 'initech'},
                  'reporting': 'initech_reporting',
                },
              },
            },
          },
        }),
      );
      expect(tenancy.defaultIsolation, TomTenantIsolation.schema);
      expect(tenancy.datasources, {'main', 'reporting'});
      expect(tenancy.createSchemas, isTrue);
      expect(
        tenancy.isolationOf(tenancy.tenants['acme']!),
        TomTenantIsolation.schema,
      );
      expect(
        tenancy.isolationOf(tenancy.tenants['globex']!),
        TomTenantIsolation.shared,
      );
      expect(tenancy.tenants['globex']!.name, 'Globex');
      final initech = tenancy.tenants['initech']!;
      expect(initech.datasources['reporting'], 'initech_reporting');
      expect((initech.datasources['main']! as Map)['databaseName'], 'initech');
      expect(
        tenancy
            .resolveRequest(_request(headers: {'x-customer': 'acme'}))
            .tenant,
        'acme',
      );
      expect(
        tenancy.resolveRequest(_request(host: 'globex.app.example.com')).tenant,
        'globex',
      );
    });

    test('reads the path resolution, its prefix and its segments', () {
      final tenancy = TomTenancy.fromConfiguration(
        TomServerConfigResourceProvider.from({
          'tenancy': {
            'resolution': ['path'],
            'pathPrefix': 'tenants',
            'pathSegments': {'acme-gmbh': 'acme'},
            'tenants': {'acme': null, 'globex': null},
          },
        }),
      );
      expect(
        tenancy.resolveRequest(_at('/tenants/acme-gmbh/x')).tenant,
        'acme',
      );
      final unknown = tenancy.resolveRequest(_at('/tenants/globex/x'));
      expect(unknown.status, 404, reason: 'only mapped segments name a tenant');
      final plain = TomTenancy.fromConfiguration(
        TomServerConfigResourceProvider.from({
          'tenancy': {
            'resolution': 'path',
            'tenants': {'acme': null},
          },
        }),
      );
      expect(plain.resolveRequest(_at('/t/acme/x')).tenant, 'acme');
    });

    test('refuses an unknown model, resolver or tenant id', () {
      Matcher refused(String key) =>
          throwsA(isA<TomException>().having((e) => e.key, 'key', key));
      TomTenancy read(Map<String, Object?> tenancy) =>
          TomTenancy.fromConfiguration(
            TomServerConfigResourceProvider.from({'tenancy': tenancy}),
          );
      expect(
        () => read({'isolation': 'sharded'}),
        refused('tenancy.config.unknown_isolation'),
      );
      expect(
        () => read({
          'resolution': ['cookie'],
        }),
        refused('tenancy.config.unknown_resolver'),
      );
      expect(
        () => read({
          'tenants': {'Acme Corp': null},
        }),
        refused('tenancy.id.invalid'),
      );
      expect(
        () => read({'tenants': 'acme'}),
        refused('tenancy.config.not_a_map'),
      );
      expect(
        () => read({
          'resolution': ['path'],
          'pathSegments': ['acme'],
        }),
        refused('tenancy.config.not_a_map'),
      );
    });
  });

  group('routing', () {
    late TomDataSourceInfo tenantData;
    late TomDataSourceInfo other;

    setUp(() {
      tenantData = TomDataSourceInfo('tenant_data', const {});
      other = TomDataSourceInfo('other', const {});
      TomDataSourceInfo.datasources['tenant_data'] = tenantData;
      TomDataSourceInfo.datasources['other'] = other;
    });

    tearDown(() {
      TomDataSourceInfo.datasources.remove('tenant_data');
      TomDataSourceInfo.datasources.remove('other');
    });

    test('a shared tenant reaches the shared data source', () async {
      await TomTenancy.install(_tenancy());
      final routed = TomTenantContext.run(
        'acme',
        () => TomDataSourceInfo.getDataSourceInfo('tenant_data'),
      );
      expect(routed, same(tenantData));
      expect(TomDataSourceInfo.getDataSourceInfo('other'), same(other));
    });

    test('a tenant the deployment does not have reaches nothing', () async {
      await TomTenancy.install(_tenancy());
      expect(
        () => TomTenantContext.run(
          'initech',
          () => TomDataSourceInfo.getDataSourceInfo('tenant_data'),
        ),
        throwsA(
          isA<TomTenancyException>().having(
            (e) => e.key,
            'key',
            'tenancy.tenant.unknown',
          ),
        ),
      );
      // A data source that holds no tenant data is not routed at all.
      expect(
        TomTenantContext.run(
          'initech',
          () => TomDataSourceInfo.getDataSourceInfo('other'),
        ),
        same(other),
      );
    });

    test(
      'a removed tenant is refused everywhere; the others are not',
      () async {
        final acmeData = TomDataSourceInfo('acme_data', const {});
        TomDataSourceInfo.datasources['acme_data'] = acmeData;
        addTearDown(() => TomDataSourceInfo.datasources.remove('acme_data'));
        final tenancy = TomTenancy(
          tenants: [
            TomTenant(
              'acme',
              isolation: TomTenantIsolation.database,
              datasources: const {'': 'acme_data'},
            ),
            TomTenant('globex'),
          ],
          datasources: const {'tenant_data'},
          resolvers: const [TomTenantHeaderResolver()],
        );
        await TomTenancy.install(tenancy);
        expect(
          TomTenantContext.run(
            'acme',
            () => TomDataSourceInfo.getDataSourceInfo('tenant_data'),
          ),
          same(acmeData),
        );

        final removed = await tenancy.removeTenant('acme');

        expect(removed.id, 'acme');
        expect(tenancy.tenants.keys, ['globex']);
        Matcher unknown() => throwsA(
          isA<TomTenancyException>().having(
            (e) => e.key,
            'key',
            'tenancy.tenant.unknown',
          ),
        );
        expect(
          () => TomTenantContext.run(
            'acme',
            () => TomDataSourceInfo.getDataSourceInfo('tenant_data'),
          ),
          unknown(),
        );
        final byToken = tenancy.resolveRequest(_request(), claim: 'acme');
        expect((byToken.status, byToken.key), (404, 'tenancy.tenant.unknown'));
        final byHeader = tenancy.resolveRequest(
          _request(headers: {'x-tenant-id': 'acme'}),
        );
        expect(byHeader.status, 404);
        expect(() => tenancy.runFor('acme', () => null), unknown());
        // A data source the tenant only named is the deployment's: still there.
        expect(TomDataSourceInfo.datasources['acme_data'], same(acmeData));
        // The other tenant is untouched.
        expect(
          TomTenantContext.run(
            'globex',
            () => TomDataSourceInfo.getDataSourceInfo('tenant_data'),
          ),
          same(tenantData),
        );
        expect(
          tenancy.resolveRequest(_request(), claim: 'globex').tenant,
          'globex',
        );
        await expectLater(tenancy.removeTenant('acme'), unknown());
      },
    );

    test('runFor and forEachTenant run work inside each tenant', () async {
      final tenancy = _tenancy();
      await TomTenancy.install(tenancy);
      final seen = <String?>[];
      await tenancy.forEachTenant((_) => seen.add(TomTenantContext.currentId));
      expect(seen, ['acme', 'globex']);
      expect(
        await tenancy.runFor('globex', () => TomTenantContext.currentId),
        'globex',
      );
      await expectLater(
        tenancy.runFor('initech', () => null),
        throwsA(isA<TomTenancyException>()),
      );
    });

    test('a database-isolated tenant without a data source is refused at '
        'install', () async {
      await expectLater(
        TomTenancy.install(
          TomTenancy(
            tenants: [
              TomTenant('acme', isolation: TomTenantIsolation.database),
            ],
            datasources: const {'tenant_data'},
          ),
        ),
        throwsA(
          isA<TomTenancyException>().having(
            (e) => e.key,
            'key',
            'tenancy.config.missing_datasource',
          ),
        ),
      );
    });

    test('schema isolation needs a data source naming its database', () async {
      await expectLater(
        TomTenancy.install(
          TomTenancy(
            tenants: [TomTenant('acme', isolation: TomTenantIsolation.schema)],
            datasources: const {'tenant_data'},
          ),
        ),
        throwsA(
          isA<TomTenancyException>().having(
            (e) => e.key,
            'key',
            'tenancy.config.schema_unsupported',
          ),
        ),
      );
    });

    test('a routed data source that is not registered is refused', () async {
      await expectLater(
        TomTenancy.install(
          TomTenancy(
            tenants: [TomTenant('acme', isolation: TomTenantIsolation.schema)],
            datasources: const {'nowhere'},
          ),
        ),
        throwsA(
          isA<TomTenancyException>().having(
            (e) => e.key,
            'key',
            'tenancy.config.unknown_datasource',
          ),
        ),
      );
    });

    test('a schema name that is not an identifier is refused', () async {
      TomDataSourceInfo.datasources['tenant_data'] = TomDataSourceInfo(
        'tenant_data',
        const {'databaseName': 'main'},
      );
      await expectLater(
        TomTenancy.install(
          TomTenancy(
            tenants: [
              TomTenant(
                'acme',
                isolation: TomTenantIsolation.schema,
                schema: 'acme; DROP DATABASE main',
              ),
            ],
            datasources: const {'tenant_data'},
          ),
        ),
        throwsA(
          isA<TomTenancyException>().having(
            (e) => e.key,
            'key',
            'tenancy.config.invalid_schema',
          ),
        ),
      );
    });
  });

  group('the request pipeline', () {
    Future<(int, String?)> serve(Request request) async {
      String? seen;
      final handler = tomDefaultAuthenticationMiddleware('tenancy-test')((
        request,
      ) {
        seen = TomTenantContext.currentId;
        return Response.ok('');
      });
      final response = await handler(request);
      return (response.statusCode, seen);
    }

    test('runs a request inside the tenant it names', () async {
      await TomTenancy.install(_tenancy());
      expect(await serve(_request(host: 'acme.app.example.test')), (
        200,
        'acme',
      ));
      expect(await serve(_request()), (200, null));
    });

    test('a token is not a pass to another tenant', () async {
      await TomTenancy.install(_tenancy());
      final token = _signed({'username': 'alice', 'tenant': 'acme'});
      expect(
        await serve(
          _request(
            host: 'acme.app.example.test',
            headers: {'authorization': 'Bearer $token'},
          ),
        ),
        (200, 'acme'),
      );
      expect(
        await serve(
          _request(
            headers: {
              'authorization': 'Bearer $token',
              'x-tenant-id': 'globex',
            },
          ),
        ),
        (403, null),
      );
    });

    test('runs a request inside the tenant its path names', () async {
      await TomTenancy.install(_bySlug());
      expect(await serve(_at('/t/acme-gmbh/sign-in')), (200, 'acme'));
      expect(await serve(_at('/t/initech/sign-in')), (404, null));
      final token = _signed({'username': 'alice', 'tenant': 'globex'});
      expect(
        await serve(
          _at(
            '/t/acme-gmbh/users',
            headers: {'authorization': 'Bearer $token'},
          ),
        ),
        (403, null),
      );
    });

    test('a removed tenant\'s token and header are refused', () async {
      final tenancy = _tenancy();
      await TomTenancy.install(tenancy);
      await tenancy.removeTenant('acme');
      final token = _signed({'username': 'alice', 'tenant': 'acme'});
      expect(
        await serve(_request(headers: {'authorization': 'Bearer $token'})),
        (404, null),
      );
      expect(await serve(_request(headers: {'x-tenant-id': 'acme'})), (
        404,
        null,
      ));
      expect(await serve(_request(headers: {'x-tenant-id': 'globex'})), (
        200,
        'globex',
      ));
    });

    test('a deployment without tenancy runs every request in none', () async {
      expect(await serve(_request(headers: {'x-tenant-id': 'acme'})), (
        200,
        null,
      ));
    });
  });

  group('a login', () {
    late TomAuthenticationService saved;

    setUp(
      () => saved =
          TomAuthenticationServer.globalSettingUserAuthenticationService,
    );
    tearDown(
      () => TomAuthenticationServer.globalSettingUserAuthenticationService =
          saved,
    );

    TomAuthenticationMessage message() => TomAuthenticationMessage()
      ..client = 'web'
      ..userName = 'alice'
      ..password = 'secret'
      ..organization = 'sales'
      ..application = 'console'
      ..process = 'login'
      ..clientLanguage = 'en'
      ..clientCountry = 'US'
      ..clientTimezone = 'UTC';

    test('binds the token to the tenant it happened in', () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          TomDummyAuthenticationService()..showErrorMessage = false;
      final result = await TomTenantContext.run(
        'acme',
        () => TomAuthenticationServer().authenticatePass1(message()),
      );
      expect(result.error, isEmpty);
      final token = TomClientJwtToken(
        result.authenticationToken,
        decrypt: false,
      );
      expect(token.payload?['tenant'], 'acme');
      expect(
        token.payload?['organization'],
        'sales',
        reason: 'the organization is a separate thing',
      );
    });

    test('refuses an account of another tenant', () async {
      TomAuthenticationServer.globalSettingUserAuthenticationService =
          _OtherTenantService();
      final result = await TomTenantContext.run(
        'acme',
        () => TomAuthenticationServer().authenticatePass1(message()),
      );
      expect(result.error, 'login.error.tenant-mismatch');
      expect(result.authenticationToken, isEmpty);
    });
  });

  group('one principal id in two tenants', () {
    // `alice`, id `u1`, in acme and in globex: two people. A principal id is
    // unique within its tenant only; the per-principal stores key by the
    // tenant-qualified id, so under `shared` isolation, where both tenants'
    // rows share a table, they stay apart. The database half is
    // principal_per_tenant_db_test.dart.
    TomPrincipal alice(String tenant) => TomPrincipal(
      authenticated: true,
      tenant: tenant,
      user: TomUser(id: 'u1', username: 'alice'),
    );
    Tom2FAContext context(String tenant) =>
        Tom2FAContext(principal: alice(tenant));

    test('2FA enrolments are kept per tenant', () async {
      final store = TomMemory2FAEnrolmentStore();
      await store.store(
        context('acme'),
        Tom2FAEnrolment(type: 'totp', enrolmentId: 'acme-phone'),
      );
      expect(
        [
          for (final e in await store.enrolmentsFor(context('acme')))
            e.enrolmentId,
        ],
        ['acme-phone'],
      );
      expect(await store.enrolmentsFor(context('globex')), isEmpty);
    });

    test('2FA grace is spent per tenant', () async {
      final store = TomMemory2FAGraceStore();
      await store.recordConsumed(context('acme'));
      expect(await store.consumedBy(context('acme')), 1);
      expect(await store.consumedBy(context('globex')), 0);
    });

    test('the owner scope admits only the tenant\'s own rows', () {
      final owner = TomDataScopeRegistry.resolverFor('owner')!;
      expect(owner(alice('acme')), ['tenant:acme/u1']);
      expect(owner(alice('globex')), ['tenant:globex/u1']);
    });

    test('resource grants are looked up by the qualified id', () async {
      final grants = InMemoryPrincipalResourceGrantStore([
        TomPrincipalResourceGrant(
          principalId: TomTenantContext.qualify('u1', 'acme'),
          resourceKey: 'doc-1',
          role: 'owner',
        ),
      ]);
      final resolver = TomPrincipalResourceRoleResolver(grants);
      final scope = TomResourceDataScope(
        TomDelegationResolver(
          InMemoryPrincipalDelegationStore(const []),
          resolver,
        ),
      );
      expect(
        await resolver.resolveResourceRoles(scope.principalId(alice('acme'))),
        {'doc-1': 'owner'},
      );
      expect(
        await resolver.resolveResourceRoles(scope.principalId(alice('globex'))),
        isEmpty,
      );
    });
  });
}

/// A directory whose accounts all belong to `globex`.
class _OtherTenantService implements TomAuthenticationService {
  @override
  Future<TomAuthenticationInfo> authenticateUser(
    TomAuthenticationData a,
  ) async {
    final info =
        await (TomDummyAuthenticationService()..showErrorMessage = false)
            .authenticateUser(a);
    info.principal.tenant = 'globex';
    return info;
  }
}

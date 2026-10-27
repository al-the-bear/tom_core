/// The server half of feature flags: the flags of the configuration, read for
/// the request at hand, and `GET /feature-flags`, which hands a caller the
/// flags it may see, evaluated for it. The evaluation rules themselves are the
/// kernel's, and are tested there.
library;

import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart';
import 'fixtures/reflection_fixture.reflection.dart';

/// A JWT signed with this deployment's configuration.
String _signed(Map<String, dynamic> claims) =>
    TomServerJwtToken(claims).getJWT(TomJwtSigning.current.issuer);

const Map<String, Object?> _flags = {
  'new-checkout': {
    'default': false,
    'exposed': true,
    'rules': [
      {
        'roles': ['beta'],
        'value': true,
      },
    ],
  },
  'acme-banner': {
    'default': 'none',
    'exposed': true,
    'rules': [
      {
        'tenants': ['acme'],
        'value': 'Welcome, Acme',
      },
    ],
  },
  'kill-switch': {'default': false},
};

void main() {
  late TomFlagProvider previous;

  setUpAll(() {
    initializeReflection();
    registerFixtureAccessApi();
  });
  setUp(() => previous = TomFeatureFlags.provider);
  tearDown(() {
    TomFeatureFlags.provider = previous;
    TomBean.resetBeanContext();
  });

  group('the configured flags', () {
    test('are installed from featureFlags at start', () async {
      TomServer.configureFeatureFlags(
        TomServerConfigResourceProvider.from({'featureFlags': _flags}),
      );
      expect(TomFeatureFlags.provider, isA<TomRuleFlagProvider>());
      expect(await TomFeatureFlags.isEnabled('kill-switch'), isFalse);
      final beta = await runZoned(
        () => TomFeatureFlags.isEnabled('new-checkout'),
        zoneValues: {
          TomPrincipal: TomPrincipal(
            user: TomUser(id: 'ada', username: 'ada'),
            aci: TomAccessControlInformation(roles: const ['beta']),
            authenticated: true,
          ),
        },
      );
      expect(beta, isTrue);
    });

    test('a malformed definition stops the start, naming the flag', () {
      final before = TomFeatureFlags.provider;
      expect(
        () => TomServer.configureFeatureFlags(
          TomServerConfigResourceProvider.from({
            'featureFlags': {
              'broken': {'rules': <Object>[]},
            },
          }),
        ),
        throwsA(
          isA<TomConfigurationException>()
              .having(
                (e) => e.key,
                'key',
                'configuration.feature_flags.invalid',
              )
              .having(
                (e) => e.parameters?['reason'],
                'reason',
                contains("'broken'"),
              ),
        ),
      );
      expect(TomFeatureFlags.provider, same(before));
      // Without the key nothing changes.
      TomServer.configureFeatureFlags(TomServerConfigResourceProvider.from({}));
      expect(TomFeatureFlags.provider, same(before));
    });
  });

  group('GET /feature-flags', () {
    late Handler handler;

    setUp(() {
      TomFeatureFlagsServer.configure(_flags);
      TomBean.resetBeanContext();
      final router = TomEndpointRouting().initializeRouter();
      handler = const Pipeline()
          .addMiddleware(
            contextSetupMiddleware('feature flags test', {
              TomRequestLogInfo.contextName: TomRequestLogInfo(),
            }),
          )
          .addMiddleware(tomDefaultAuthenticationMiddleware('feature flags'))
          .addHandler(router.call);
    });

    Future<Map<String, Object?>> flagsFor({
      String? token,
      String? tenant,
    }) async {
      Future<Response> call() async => handler(
        Request(
          'GET',
          Uri.parse('http://localhost/feature-flags'),
          headers: {'authorization': ?(token == null ? null : 'Bearer $token')},
        ),
      );
      final response = tenant == null
          ? await call()
          : await TomTenantContext.run(tenant, call);
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString()) as Map;
      return (body['flags'] as Map).cast<String, Object?>();
    }

    test('answers the exposed flags for an anonymous caller', () async {
      expect(await flagsFor(), {'new-checkout': false, 'acme-banner': 'none'});
    });

    test('evaluates them for the caller, never sending a server-only '
        'flag', () async {
      final flags = await flagsFor(
        token: _signed({'userId': 'ada', 'username': 'ada'}),
        tenant: 'acme',
      );
      expect(flags['acme-banner'], 'Welcome, Acme');
      expect(flags['new-checkout'], isFalse);
      expect(flags.keys, isNot(contains('kill-switch')));
    });

    test('a client reads the snapshot it fetched', () async {
      TomFeatureFlags.provider = TomStaticFlagProvider(await flagsFor());
      expect(await TomFeatureFlags.isEnabled('new-checkout'), isFalse);
      expect(
        await TomFeatureFlags.getString('acme-banner', defaultValue: ''),
        'none',
      );
      expect(
        await TomFeatureFlags.isEnabled('kill-switch', defaultValue: true),
        isTrue,
        reason: 'a server-only flag is unknown to the client',
      );
    });
  });
}

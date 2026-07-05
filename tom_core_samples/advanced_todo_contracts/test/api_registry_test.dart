/// Locks the three-way alignment that makes the wire contract trustworthy: the
/// registry's endpoints, their companion access maps, and the global
/// `tomRemoteApis` registration must all agree. A drift here (an endpoint added
/// without an access entry, or registered under the wrong id) is exactly the
/// kind of silent wire mismatch this package exists to prevent.
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart'
    show
        TomAccessControl,
        TomApi,
        TomAuthenticatedAccess,
        TomHttpMethod,
        TomPublicAccess,
        TomRoleAccess,
        tomRemoteApis;
import 'package:test/test.dart';

void main() {
  group('api registry', () {
    test('every endpoint has exactly one access entry, and vice versa', () {
      void checkCoverage(TomApi api, Map<String, TomAccessControl> access) {
        expect(
          access.keys.toSet(),
          api.endpoints.keys.toSet(),
          reason: '${api.id}: access map and endpoints must cover the same ids',
        );
      }

      checkCoverage(authApi, authApiAccess);
      checkCoverage(adminApi, adminApiAccess);
      checkCoverage(appApi, appApiAccess);
    });

    test('only the documented endpoints are public', () {
      final public = <String>[
        for (final entry in {
          ...authApiAccess,
          ...adminApiAccess,
          ...appApiAccess,
        }.entries)
          if (entry.value is TomPublicAccess) entry.key,
      ];
      expect(public,
          unorderedEquals(['authLogin', 'authLoginResources', 'appHealth']));
    });

    test('public endpoints skip bearer authentication', () {
      expect(authApi.endpoints['authLogin']!.includeBearerAuthentication,
          isFalse);
      expect(authApi.endpoints['authLoginResources']!.includeBearerAuthentication,
          isFalse);
      expect(
          appApi.endpoints['appHealth']!.includeBearerAuthentication, isFalse);
    });

    test('every admin endpoint requires the admin role', () {
      for (final access in adminApiAccess.values) {
        expect(access, isA<TomRoleAccess>());
        expect((access as TomRoleAccess).roles, ['admin']);
      }
    });

    test('the admin gate is the single centralized adminAccess constant', () {
      // G-API-4 (light form of G-API-3): the `admin` role and its access policy
      // are declared once (`adminRole`/`adminAccess`) and reused everywhere —
      // both the registry's companion map and the server handlers' `@adminAccess`
      // annotation point at this same constant, so there is no second definition
      // to drift. Asserting *identity* (not just equality) locks that.
      expect(adminRole, 'admin');
      expect(adminAccess.roles, [adminRole]);
      for (final access in adminApiAccess.values) {
        expect(
          identical(access, adminAccess),
          isTrue,
          reason: 'every adminApiAccess entry must be the shared adminAccess '
              'constant, not a re-stated TomRoleAccess literal',
        );
      }
    });

    test('the resource endpoints are GETs with the documented access', () {
      // Login texts: public, on the auth API.
      expect(authApi.endpoints['authLoginResources']!.method,
          TomHttpMethod.get);
      expect(authApiAccess['authLoginResources'], isA<TomPublicAccess>());

      // Admin console full bundle: admin-gated, on the admin API.
      expect(adminApi.endpoints['adminResources']!.method, TomHttpMethod.get);
      expect(adminApiAccess['adminResources'], isA<TomRoleAccess>());

      // App client full bundle: authenticated, on the app API.
      expect(appApi.endpoints['appResources']!.method, TomHttpMethod.get);
      expect(appApiAccess['appResources'], isA<TomAuthenticatedAccess>());
    });

    test('registerAdvancedTodoApis is idempotent and registers all three', () {
      registerAdvancedTodoApis();
      registerAdvancedTodoApis(); // second call must not throw or duplicate.

      expect(tomRemoteApis['auth'], same(authApi));
      expect(tomRemoteApis['admin'], same(adminApi));
      expect(tomRemoteApis['app'], same(appApi));
    });
  });
}

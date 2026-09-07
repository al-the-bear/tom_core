/// Locks the two-way alignment that makes the wire contract trustworthy: every
/// endpoint declares its access policy directly (`TomApiEndpoint.access`,
/// G-API-3), and the three APIs register under their expected ids. A drift here
/// (an endpoint added without an access policy, or registered under the wrong
/// id) is exactly the kind of silent wire mismatch this package exists to
/// prevent.
import 'package:advanced_todo_contracts/advanced_todo_contracts.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart'
    show
        TomApi,
        TomAuthenticatedAccess,
        TomHttpMethod,
        TomPublicAccess,
        TomRoleAccess,
        tomRemoteApis;
import 'package:test/test.dart';

void main() {
  group('api registry', () {
    test('every endpoint declares an access policy', () {
      void checkCoverage(TomApi api) {
        for (final endpoint in api.endpoints.values) {
          expect(
            endpoint.access,
            isNotNull,
            reason:
                '${api.id}.${endpoint.id}: every endpoint must declare a '
                'contract-side access policy (TomApiEndpoint.access)',
          );
        }
      }

      checkCoverage(authApi);
      checkCoverage(adminApi);
      checkCoverage(appApi);
    });

    test('only the documented endpoints are public', () {
      final public = <String>[
        for (final api in [authApi, adminApi, appApi])
          for (final endpoint in api.endpoints.values)
            if (endpoint.access is TomPublicAccess) endpoint.id,
      ];
      expect(
        public,
        unorderedEquals([
          'authLogin',
          // Public because its caller is mid-login and holds no bearer yet;
          // the interim challenge token travels in the body instead.
          'authSecondFactor',
          // The three enrolment passes, public for the same reason: they are
          // reached *during* a half-finished login, by a caller holding a
          // token that by construction authenticates nobody. Listing them
          // individually rather than widening the guard to a prefix is the
          // point of this test — a fourth enrolment endpoint should have to
          // be justified here.
          'authBeginEnrolment',
          'authConfirmEnrolment',
          'authSkipEnrolment',
          'authLoginResources',
          'appHealth',
        ]),
      );
    });

    test('public endpoints skip bearer authentication', () {
      for (final id in [
        'authLogin',
        'authSecondFactor',
        'authBeginEnrolment',
        'authConfirmEnrolment',
        'authSkipEnrolment',
        'authLoginResources',
      ]) {
        expect(
          authApi.endpoints[id]!.includeBearerAuthentication,
          isFalse,
          reason: '$id is public and must not be bearer-gated',
        );
      }
      expect(
        appApi.endpoints['appHealth']!.includeBearerAuthentication,
        isFalse,
      );
    });

    test('every admin endpoint requires the admin role', () {
      for (final endpoint in adminApi.endpoints.values) {
        expect(endpoint.access, isA<TomRoleAccess>());
        expect((endpoint.access as TomRoleAccess).roles, ['admin']);
      }
    });

    test('the admin gate is the single centralized adminAccess constant', () {
      // G-API-4 / G-API-3: the `admin` role and its access policy are declared
      // once (`adminRole`/`adminAccess`) and reused directly as every
      // `/admin/*` endpoint's `access:`, so there is no second definition to
      // drift. Asserting *identity* (not just equality) locks that.
      expect(adminRole, 'admin');
      expect(adminAccess.roles, [adminRole]);
      for (final endpoint in adminApi.endpoints.values) {
        expect(
          identical(endpoint.access, adminAccess),
          isTrue,
          reason:
              'every /admin/* endpoint must reference the shared '
              'adminAccess constant, not a re-stated TomRoleAccess literal',
        );
      }
    });

    test('the resource endpoints are GETs with the documented access', () {
      // Login texts: public, on the auth API.
      expect(
        authApi.endpoints['authLoginResources']!.method,
        TomHttpMethod.get,
      );
      expect(
        authApi.endpoints['authLoginResources']!.access,
        isA<TomPublicAccess>(),
      );

      // Admin console full bundle: admin-gated, on the admin API.
      expect(adminApi.endpoints['adminResources']!.method, TomHttpMethod.get);
      expect(
        adminApi.endpoints['adminResources']!.access,
        isA<TomRoleAccess>(),
      );

      // App client full bundle: authenticated, on the app API.
      expect(appApi.endpoints['appResources']!.method, TomHttpMethod.get);
      expect(
        appApi.endpoints['appResources']!.access,
        isA<TomAuthenticatedAccess>(),
      );
    });

    test('the attachment descriptors are an authenticated GET that moves no '
        'bytes', () {
      // The board's paperclip source. It must be a GET (a read), authenticated
      // (attachment names are as private as the items they hang off), and carry
      // no request body — the list is selected by the `listId` query string,
      // exactly like `appListItems` next to it.
      final endpoint = appApi.endpoints['appListAttachments']!;
      expect(endpoint.uri, '/attachments');
      expect(endpoint.method, TomHttpMethod.get);
      expect(endpoint.access, isA<TomAuthenticatedAccess>());
      expect(endpoint.requestTypes, isEmpty);
    });

    test('no PUT states its subject twice', () {
      // A PUT carries the whole entity, so its request DTO necessarily names
      // the subject. Adding a `{id}` capture on top would let one request name
      // two — `PUT /users/7` with `{"id": 9}` — and the pipeline resolves that
      // silently, by folding the body first and letting the path overwrite it.
      // Precedence is the answer to a question the contract should not be
      // asking, so every PUT here addresses the bare collection. See
      // `TomApiEndpoint.urlParameterMapping`.
      //
      // Scoped to PUT deliberately. A DELETE or a GET carries no body, so its
      // capture is the only statement; and whether a POST to a nested
      // subcollection (`POST /items/{id}/comments`, whose `TodoComment` also
      // carries `itemId`) should lose its nesting is a separate question about
      // the sample's REST surface, not about this rule.
      for (final api in [authApi, adminApi, appApi]) {
        for (final endpoint in api.endpoints.values) {
          if (endpoint.method != TomHttpMethod.put) continue;
          expect(
            endpoint.uri,
            isNot(contains('{')),
            reason:
                '${api.id}.${endpoint.id}: a PUT must address the bare '
                'collection — its body already names the subject',
          );
          expect(
            endpoint.urlParameterMapping,
            isEmpty,
            reason:
                '${api.id}.${endpoint.id}: a PUT declares no URL parameter '
                'mapping — there is no capture for one to bind',
          );
        }
      }
    });

    test('the by-id deletes keep the capture that addresses them', () {
      // The other half of the rule, asserted so that "no captures anywhere"
      // cannot pass for a repair: a DELETE has no body, so the path is the only
      // place its subject can be stated.
      final byId = <String>[
        'adminDeleteUser',
        'adminDeleteRole',
        'adminDeleteGroup',
        'appDeleteWorkspace',
        'appDeleteItem',
      ];
      final found = <String>[];
      for (final api in [authApi, adminApi, appApi]) {
        for (final endpoint in api.endpoints.values) {
          if (!byId.contains(endpoint.id)) continue;
          found.add(endpoint.id);
          expect(endpoint.method, TomHttpMethod.delete);
          expect(
            endpoint.uri,
            contains('{'),
            reason: '${endpoint.id}: addressed by path, having no body',
          );
        }
      }
      expect(found..sort(), equals(byId.toList()..sort()));
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

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

    test('no body-carrying endpoint states its subject twice', () {
      // A POST, PUT or PATCH carries a request DTO in its body. A `{id}`
      // capture on top lets one request name its subject twice — `PUT
      // /users/7` with `{"id": 9}`, or `POST /items/7/comments` with
      // `{"itemId": "9"}` — and the pipeline resolves that silently, by folding
      // the body first and letting the path overwrite it. Precedence is the
      // answer to a question the contract should not be asking; see
      // `TomApiEndpoint.urlParameterMapping`.
      //
      // So such an endpoint has two legal shapes. Either it addresses the bare
      // collection and its body is the single statement — every PUT here, and
      // every POST that creates a top-level row — or its request type is one of
      // the path-addressed request DTOs below, whose `id` field exists only to
      // receive the capture and is left out of the body by the client. An
      // entity DTO (`TodoComment`, `Subtask`, …) carries its links as data, so
      // binding a capture onto one is the hazard itself.
      //
      // A DELETE or a GET carries no body, so its capture is the only
      // statement and is not judged here.
      const bodyCarrying = [
        TomHttpMethod.post,
        TomHttpMethod.put,
        TomHttpMethod.patch,
      ];
      const pathAddressed = <Type>{AddCommentRequest, AddSubtaskRequest};
      for (final api in [authApi, adminApi, appApi]) {
        for (final endpoint in api.endpoints.values) {
          if (!bodyCarrying.contains(endpoint.method)) continue;
          final where = '${api.id}.${endpoint.id}';
          if (!(endpoint.uri ?? '').contains('{')) {
            expect(
              endpoint.urlParameterMapping,
              isEmpty,
              reason:
                  '$where: a bare collection declares no URL parameter '
                  'mapping — there is no capture for one to bind',
            );
            continue;
          }
          expect(
            endpoint.requestTypes,
            everyElement(isIn(pathAddressed)),
            reason:
                '$where: a capture on a body-carrying endpoint must bind onto '
                'a path-addressed request DTO, not onto an entity whose body '
                'already names the subject',
          );
          expect(
            endpoint.urlParameterMapping.values,
            everyElement('id'),
            reason: '$where: the capture binds onto the request\'s `id`',
          );
        }
      }
    });

    test('the nested child writes keep the capture that addresses them', () {
      // The other half, asserted so that dropping the nesting cannot pass for
      // the repair: the parent is stated in the path, and only there.
      for (final id in ['appAddComment', 'appAddSubtask']) {
        final endpoint = appApi.endpoints[id]!;
        expect(endpoint.method, TomHttpMethod.post, reason: id);
        expect(endpoint.uri, startsWith('/items/{id}/'), reason: id);
        expect(endpoint.urlParameterMapping, {'id': 'id'}, reason: id);
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

    test('an endpoint that answers with an empty body declares void', () {
      // A handler returning nothing makes the pipeline answer 200 with no
      // payload, so there is no value for a caller to read and no type to give
      // it. `Object?` promised a JSON value that never arrives, and it promised
      // it in the only place a reader, a generated client or a documentation
      // mirror can look: nothing in the framework reads
      // `TomApiEndpoint.responseType`, so the declaration is not checked by
      // anything else and is not corrected by any behaviour.
      //
      // Stated as a universal rather than as a list of the ten endpoints that
      // were wrong, so an endpoint added later cannot reintroduce the spelling.
      // An endpoint that genuinely returns an arbitrary JSON value would need
      // an exemption here — which is the point: it would be a deliberate one.
      for (final api in [authApi, adminApi, appApi]) {
        for (final endpoint in api.endpoints.values) {
          expect(
            endpoint.responseType.toString(),
            isNot(anyOf('Object?', 'Object')),
            reason:
                '${api.id}.${endpoint.id}: declare the result type it answers '
                'with, or `void` when it answers with an empty body',
          );
        }
      }
    });

    test('the void endpoints are the ones whose service returns nothing', () {
      // The other half: `void` everywhere would satisfy the rule above and be
      // just as dishonest. These ten are exactly the endpoints whose
      // counterpart in `api_services.dart` is a `Future<void>`, which is the
      // correspondence the declaration is supposed to mirror.
      final empty = <String>[
        for (final api in [authApi, adminApi, appApi])
          for (final endpoint in api.endpoints.values)
            if (endpoint.responseType.toString() == 'void') endpoint.id,
      ];
      expect(empty..sort(), [
        'adminAssign',
        'adminDeleteGroup',
        'adminDeleteRole',
        'adminDeleteUser',
        'adminPutGrants',
        'appDeleteItem',
        'appDeleteWorkspace',
        'appRevokeShare',
        'appShare',
        'authLogout',
      ]);
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

import 'package:test/test.dart';
import 'package:tom_core_codespecs/tom_core_codespecs.dart';

const _minimal = TomOperationBinding(
  'listUsers',
  method: 'GET',
  path: '/Users',
);

const _full = TomOperationBinding(
  'createUser',
  method: 'POST',
  path: '/Users',
  versionPrefix: '/scim/v2',
  parameters: [
    TomBindingParameter(
      'userName',
      source: TomBindingSource.body,
      member: 'login',
    ),
  ],
  successStatus: 201,
  responseHeaders: ['Location'],
  consumes: 'application/scim+json',
  produces: 'application/scim+json',
  errorFormat: TomBindingErrorFormat.scim,
);

void main() {
  group('CE-API TomOperationBinding', () {
    test('constructs as a compile-time constant', () {
      // Canonicalised consts are identical — which only holds when the whole
      // value, its parameter list included, is constant.
      expect(
        identical(
          _minimal,
          const TomOperationBinding('listUsers', method: 'GET', path: '/Users'),
        ),
        isTrue,
      );
      expect(_full.operation, 'createUser');
      expect(_full.method, 'POST');
      expect(_full.parameters.single.name, 'userName');
      expect(_full.parameters.single.source, TomBindingSource.body);
      expect(_full.parameters.single.member, 'login');
      expect(_full.successStatus, 201);
      expect(_full.responseHeaders, ['Location']);
      expect(_full.consumes, 'application/scim+json');
      expect(_full.produces, 'application/scim+json');
      expect(_full.errorFormat, TomBindingErrorFormat.scim);
    });

    test('defaults describe the primary CE-API shape', () {
      expect(_minimal.versionPrefix, '');
      expect(_minimal.parameters, isEmpty);
      expect(_minimal.successStatus, 200);
      expect(_minimal.responseHeaders, isEmpty);
      expect(_minimal.consumes, isNull);
      expect(_minimal.produces, 'application/json');
      expect(_minimal.errorFormat, TomBindingErrorFormat.resultEnvelope);
    });

    test('route is the version prefix followed by the path', () {
      expect(_minimal.route, '/Users');
      expect(_full.route, '/scim/v2/Users');
    });

    group('pathCaptures', () {
      test('is empty for a path with no captures', () {
        expect(_minimal.pathCaptures, isEmpty);
      });

      test('names a single capture', () {
        const b = TomOperationBinding(
          'getUser',
          method: 'GET',
          path: '/Users/{id}',
        );
        expect(b.pathCaptures, ['id']);
      });

      test('names several captures in path order', () {
        const b = TomOperationBinding(
          'getGroupMember',
          method: 'GET',
          path: '/Groups/{groupId}/members/{userId}/{attr}',
        );
        expect(b.pathCaptures, ['groupId', 'userId', 'attr']);
      });

      test('reads the path only, never the version prefix', () {
        const b = TomOperationBinding(
          'getUser',
          method: 'GET',
          path: '/Users/{id}',
          versionPrefix: '/{tenant}',
        );
        expect(b.pathCaptures, ['id']);
      });
    });

    test('methods is the closed set of five', () {
      expect(TomOperationBinding.methods, {
        'GET',
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
      });
    });

    test('the closed vocabularies have the documented members', () {
      expect(TomBindingSource.values.map((v) => v.name), [
        'path',
        'query',
        'body',
        'header',
      ]);
      expect(TomBindingErrorFormat.values.map((v) => v.name), [
        'resultEnvelope',
        'problemJson',
        'scim',
        'oauth',
      ]);
    });
  });
}

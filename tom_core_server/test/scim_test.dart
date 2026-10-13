/// SCIM 2.0 provisioning: the filter and path language, a conformance subset
/// driven over HTTP through the endpoint pipeline, and deprovisioning that
/// revokes access.
///
/// The conformance subset follows what the identity providers' own validators
/// exercise — the request shapes Microsoft Entra ID and Okta send, including
/// their PATCH variants — rather than the whole of RFC 7644.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.dart' show registerFixtureAccessApi;
import 'fixtures/reflection_fixture.reflection.dart';

const _token = 'scim-secret-for-tests';
const _enterprise = TomScimSchemas.enterpriseUser;

/// What the router answered.
typedef _Answer = ({
  int status,
  Map<String, Object?> body,
  Map<String, String> headers,
});

Matcher _scimError(int status, [String? scimType]) => isA<_Answer>()
    .having((a) => a.status, 'status', status)
    .having((a) => a.body['schemas'], 'schemas', [TomScimSchemas.error])
    .having((a) => a.body['scimType'], 'scimType', scimType);

/// An Entra ID-shaped user creation.
Map<String, Object?> _user(String userName, {String externalId = 'ext'}) => {
  'schemas': [TomScimSchemas.user, _enterprise],
  'externalId': '$externalId-$userName',
  'userName': userName,
  'active': true,
  'displayName': 'Display $userName',
  'emails': [
    {'primary': true, 'type': 'work', 'value': '$userName@example.test'},
  ],
  'name': {
    'formatted': 'Given Family',
    'familyName': 'Family',
    'givenName': 'Given',
  },
  _enterprise: {'employeeNumber': '42', 'department': 'Ops'},
};

void main() {
  setUpAll(() {
    initializeReflection();
    registerFixtureAccessApi();
  });

  group('the filter language', () {
    final alice = {
      'id': '7',
      'userName': 'Alice@Example.test',
      'active': true,
      'name': {'familyName': 'Example', 'givenName': 'Alice'},
      'emails': [
        {'type': 'work', 'value': 'alice@example.test'},
        {'type': 'home', 'value': 'alice@home.test'},
      ],
      'meta': {'created': '2026-10-13T09:00:00.000Z'},
      _enterprise: {'employeeNumber': '42'},
    };

    bool matches(String filter) =>
        TomScimFilter.parse(filter, TomScimResourceType.user).matches(alice);

    test('compares the way SCIM attributes compare', () {
      expect(matches('userName eq "alice@example.test"'), isTrue);
      expect(matches('USERNAME Eq "ALICE@EXAMPLE.TEST"'), isTrue);
      expect(matches('id eq "7"'), isTrue);
      expect(matches('name.familyName sw "Ex"'), isTrue);
      expect(matches('name.givenName ew "ice"'), isTrue);
      expect(matches('userName co "example"'), isTrue);
      expect(matches('userName ne "bob"'), isTrue);
      expect(matches('active eq true'), isTrue);
      expect(matches('active eq false'), isFalse);
      expect(matches('meta.created gt "2026-10-01T00:00:00Z"'), isTrue);
      expect(matches('title pr'), isFalse);
      expect(matches('emails pr'), isTrue);
    });

    test('combines with and, or, not and parentheses', () {
      expect(
        matches('active eq true and (userName sw "x" or id eq "7")'),
        isTrue,
      );
      expect(matches('not (active eq true)'), isFalse);
      expect(
        matches('userName eq "x" or userName eq "y" and id eq "7"'),
        isFalse,
      );
    });

    test('filters the values of a multi-valued attribute', () {
      expect(matches('emails[type eq "work" and value co "example"]'), isTrue);
      expect(matches('emails[type eq "other"]'), isFalse);
      expect(matches('emails.value eq "alice@home.test"'), isTrue);
    });

    test('reads a schema-qualified attribute', () {
      expect(
        matches(
          'urn:ietf:params:scim:schemas:core:2.0:User:userName sw "alice"',
        ),
        isTrue,
      );
      expect(matches('$_enterprise:employeeNumber eq "42"'), isTrue);
    });

    test('a filter it cannot read is refused', () {
      for (final bad in [
        'userName xx "a"',
        'userName eq',
        'userName eq "unterminated',
        '(userName eq "a"',
      ]) {
        expect(
          () => TomScimFilter.parse(bad, TomScimResourceType.user),
          throwsA(
            isA<TomScimException>()
                .having((e) => e.key, 'key', 'scim.invalid_filter')
                .having((e) => e.status, 'status', 400),
          ),
          reason: bad,
        );
      }
    });

    test('a path names an attribute, a value filter and a sub-attribute', () {
      final path = TomScimPath.parse(
        'emails[type eq "work"].value',
        TomScimResourceType.user,
      );
      expect(path.attribute, 'emails');
      expect(path.subAttribute, 'value');
      expect(path.filter, isNotNull);
      final extension = TomScimPath.parse(
        '$_enterprise:manager.value',
        TomScimResourceType.user,
      );
      expect(extension.schema, _enterprise);
      expect(extension.attribute, 'manager');
      expect(extension.subAttribute, 'value');
      expect(
        () => TomScimPath.parse('a.b.c', TomScimResourceType.user),
        throwsA(
          isA<TomScimException>().having(
            (e) => e.key,
            'key',
            'scim.invalid_path',
          ),
        ),
      );
    });
  });

  group('every refusal names its key', () {
    final service = TomScimService(TomMemoryScimStore(), revoke: (_) async {});
    const base = 'https://app.example.test/scim/v2';

    Matcher refused(String key, int status) => throwsA(
      isA<TomScimException>()
          .having((e) => e.key, 'key', key)
          .having((e) => e.status, 'status', status),
    );

    test('the service refusals', () async {
      final alice = await service.create(TomScimResourceType.user, {
        'userName': 'alice',
      }, base);
      final id = alice['id']! as String;
      await expectLater(
        service.get(TomScimResourceType.user, '404', base),
        refused('scim.not_found', 404),
      );
      await expectLater(
        service.create(TomScimResourceType.user, {'userName': 'ALICE'}, base),
        refused('scim.uniqueness', 409),
      );
      await expectLater(
        service.create(TomScimResourceType.user, {'active': true}, base),
        refused('scim.invalid_value', 400),
      );
      await expectLater(
        service.create(TomScimResourceType.user, ['not', 'an', 'object'], base),
        refused('scim.invalid_syntax', 400),
      );
      await expectLater(
        service.patch(TomScimResourceType.user, id, {
          'Operations': [
            {'op': 'replace', 'path': 'meta', 'value': {}},
          ],
        }, base),
        refused('scim.mutability', 400),
      );
      await expectLater(
        service.patch(TomScimResourceType.user, id, {
          'Operations': [
            {'op': 'remove'},
          ],
        }, base),
        refused('scim.no_target', 400),
      );
    });

    test('the configuration refusals', () {
      expect(
        () => TomScimProvisioning(service: service, bearerTokens: const []),
        refused('scim.not_enabled', 404),
      );
      final provisioning = TomScimProvisioning(
        service: service,
        bearerTokens: const [_token],
      );
      expect(
        () => provisioning.requireAuthorized('Bearer a-guess'),
        refused('scim.unauthorized', 401),
      );
      provisioning.requireAuthorized('bearer $_token');
      expect(
        () => TomSqlScimStore.named('no-such-datasource'),
        throwsA(
          isA<TomServerException>().having(
            (e) => e.key,
            'key',
            'scim.store.unknown_datasource',
          ),
        ),
      );
    });
  });

  group('the SCIM endpoints', () {
    late Router router;
    late TomMemoryScimStore store;
    late List<String> revoked;

    setUp(() {
      store = TomMemoryScimStore();
      revoked = [];
      TomBean.resetBeanContext();
      TomBean.withType<TomScimServer>(const TomScimServer());
      TomScimProvisioning.install(
        TomScimProvisioning(
          service: TomScimService(
            store,
            revoke: (username) async => revoked.add(username),
          ),
          bearerTokens: const ['an-old-token', _token],
        ),
      );
      router = TomEndpointRouting().initializeRouter();
    });

    tearDown(() {
      TomScimProvisioning.reset();
      TomBean.resetBeanContext();
    });

    Future<_Answer> call(
      String method,
      String path, {
      Object? body,
      String? token = _token,
    }) async {
      final response = await router.call(
        Request(
          method,
          Uri.parse('http://localhost/scim/v2$path'),
          body: body == null
              ? null
              : (body is String ? body : jsonEncode(body)),
          headers: {
            'content-type': 'application/scim+json',
            'authorization': ?(token == null ? null : 'Bearer $token'),
          },
          context: {TomRequestLogInfo.contextName: TomRequestLogInfo()},
        ),
      );
      final text = await response.readAsString();
      return (
        status: response.statusCode,
        body: text.isEmpty
            ? const <String, Object?>{}
            : (jsonDecode(text) as Map).cast<String, Object?>(),
        headers: response.headers,
      );
    }

    Future<String> create(String userName) async =>
        (await call('POST', '/Users', body: _user(userName))).body['id']!
            as String;

    group('discovery', () {
      test(
        'the service provider configuration states what is supported',
        () async {
          final config = await call('GET', '/ServiceProviderConfig');
          expect(config.status, 200);
          expect(config.headers['content-type'], 'application/scim+json');
          expect((config.body['patch'] as Map)['supported'], isTrue);
          expect((config.body['filter'] as Map)['supported'], isTrue);
          expect((config.body['bulk'] as Map)['supported'], isFalse);
          expect(
            ((config.body['authenticationSchemes'] as List).single
                as Map)['type'],
            'oauthbearertoken',
          );
        },
      );

      test('the resource types and schemas are published', () async {
        final types = await call('GET', '/ResourceTypes');
        expect(
          [for (final t in types.body['Resources'] as List) (t as Map)['name']],
          ['User', 'Group'],
        );
        expect((await call('GET', '/ResourceTypes/User')).status, 200);
        expect((await call('GET', '/ResourceTypes/Device')).status, 404);
        final schemas = await call('GET', '/Schemas');
        expect(schemas.body['totalResults'], 2);
        expect(
          (await call('GET', '/Schemas/${TomScimSchemas.group}')).body['name'],
          'Group',
        );
      });
    });

    group('authentication', () {
      test('a request without the secret is refused', () async {
        final none = await call('GET', '/Users', token: null);
        expect(none, _scimError(401));
        expect(none.headers['www-authenticate'], startsWith('Bearer'));
        expect(await call('GET', '/Users', token: 'guess'), _scimError(401));
      });

      test('every configured secret is admitted, for a rotation', () async {
        expect(
          (await call('GET', '/Users', token: 'an-old-token')).status,
          200,
        );
      });

      test('nothing is served before provisioning is installed', () async {
        TomScimProvisioning.reset();
        expect(await call('GET', '/Users'), _scimError(404));
      });

      test('the framework leaves the claimed header to the endpoint', () {
        final request = Request(
          'GET',
          Uri.parse('http://localhost/scim/v2/Users'),
          headers: {'authorization': 'Bearer $_token'},
        );
        expect(
          extractAuthentication(request).$3,
          TomCredentialOutcome.endpointCredential,
        );
        final elsewhere = Request(
          'GET',
          Uri.parse('http://localhost/api/things'),
          headers: {'authorization': 'Bearer $_token'},
        );
        expect(
          extractAuthentication(elsewhere).$3,
          TomCredentialOutcome.unreadableToken,
        );
      });
    });

    group('users', () {
      test('a created user is answered 201 with its location', () async {
        final created = await call('POST', '/Users', body: _user('alice'));
        expect(created.status, 201);
        final id = created.body['id'];
        expect(id, isNotNull);
        final meta = created.body['meta']! as Map;
        expect(meta['resourceType'], 'User');
        expect(meta['location'], 'http://localhost/scim/v2/Users/$id');
        expect(created.headers['location'], meta['location']);
        expect(created.body['schemas'], [TomScimSchemas.user, _enterprise]);
        expect((created.body[_enterprise]! as Map)['employeeNumber'], '42');
        expect(created.body['groups'], isEmpty);
      });

      test(
        'a second user of the same name is a conflict, in any case',
        () async {
          await create('alice');
          expect(
            await call('POST', '/Users', body: _user('ALICE')),
            _scimError(409, 'uniqueness'),
          );
        },
      );

      test('a user without a userName is refused', () async {
        expect(
          await call('POST', '/Users', body: {'active': true}),
          _scimError(400, 'invalidValue'),
        );
      });

      test('reads a user, and answers 404 for an unknown id', () async {
        final id = await create('alice');
        final read = await call('GET', '/Users/$id');
        expect(read.status, 200);
        expect(read.body['userName'], 'alice');
        expect(await call('GET', '/Users/999'), _scimError(404));
      });

      test('finds a user by userName, case-insensitively', () async {
        await create('alice');
        await create('bob');
        final found = await call(
          'GET',
          '/Users?filter=${Uri.encodeQueryComponent('userName eq "ALICE"')}',
        );
        expect(found.body['schemas'], [TomScimSchemas.listResponse]);
        expect(found.body['totalResults'], 1);
        expect(
          ((found.body['Resources']! as List).single as Map)['userName'],
          'alice',
        );
        final none = await call(
          'GET',
          '/Users?filter=${Uri.encodeQueryComponent('userName eq "nobody"')}',
        );
        expect(none.body['totalResults'], 0);
        expect(none.body['Resources'], isEmpty);
      });

      test('finds users by externalId and by a value filter', () async {
        await create('alice');
        await create('bob');
        Future<int> total(String filter) async =>
            (await call(
                  'GET',
                  '/Users?filter=${Uri.encodeQueryComponent(filter)}',
                )).body['totalResults']!
                as int;
        expect(await total('externalId eq "ext-bob"'), 1);
        expect(await total('emails[type eq "work" and value sw "ali"]'), 1);
        expect(await total('active eq true'), 2);
      });

      test('pages through the users', () async {
        for (final name in ['a', 'b', 'c']) {
          await create(name);
        }
        final page = await call('GET', '/Users?startIndex=2&count=1');
        expect(page.body['totalResults'], 3);
        expect(page.body['startIndex'], 2);
        expect(page.body['itemsPerPage'], 1);
        expect(
          ((page.body['Resources']! as List).single as Map)['userName'],
          'b',
        );
        final counted = await call('GET', '/Users?count=0');
        expect(counted.body['totalResults'], 3);
        expect(counted.body['Resources'], isEmpty);
      });

      test('returns the attributes asked for', () async {
        final id = await create('alice');
        final narrow = await call('GET', '/Users/$id?attributes=userName');
        expect(
          narrow.body.keys,
          unorderedEquals(['schemas', 'id', 'userName', 'meta']),
        );
        final without = await call(
          'GET',
          '/Users/$id?excludedAttributes=emails,name',
        );
        expect(without.body, isNot(contains('emails')));
        expect(without.body, isNot(contains('name')));
        expect(without.body['userName'], 'alice');
      });

      test('an unreadable filter is refused', () async {
        expect(
          await call(
            'GET',
            '/Users?filter=${Uri.encodeQueryComponent('userName xx "a"')}',
          ),
          _scimError(400, 'invalidFilter'),
        );
      });

      test('a body that is not JSON is refused', () async {
        expect(
          await call('POST', '/Users', body: '{not json'),
          _scimError(400, 'invalidSyntax'),
        );
      });

      test('PATCH applies the operations Entra ID sends', () async {
        final id = await create('alice');
        final patched = await call(
          'PATCH',
          '/Users/$id',
          body: {
            'schemas': [TomScimSchemas.patchOp],
            'Operations': [
              {
                'op': 'Replace',
                'path': 'displayName',
                'value': 'Alice Example',
              },
              {'op': 'Replace', 'path': 'name.givenName', 'value': 'Alice'},
              {
                'op': 'Add',
                'path': 'emails[type eq "home"].value',
                'value': 'alice@home.test',
              },
              {
                'op': 'Replace',
                'path': '$_enterprise:department',
                'value': 'Engineering',
              },
              {
                'op': 'Add',
                'value': {'title': 'Engineer', 'nickName': 'Al'},
              },
            ],
          },
        );
        expect(patched.status, 200);
        expect(patched.body['displayName'], 'Alice Example');
        expect((patched.body['name']! as Map)['givenName'], 'Alice');
        expect((patched.body['name']! as Map)['familyName'], 'Family');
        expect(
          [
            for (final e in patched.body['emails']! as List)
              (e as Map)['value'],
          ],
          ['alice@example.test', 'alice@home.test'],
        );
        expect(
          (patched.body[_enterprise]! as Map)['department'],
          'Engineering',
        );
        expect(patched.body['title'], 'Engineer');
        expect((patched.body['meta']! as Map)['version'], 'W/"2"');
        expect(revoked, isEmpty, reason: 'nothing was taken away');
      });

      test(
        'PATCH removes a value and a value of a multi-valued attribute',
        () async {
          final id = await create('alice');
          final patched = await call(
            'PATCH',
            '/Users/$id',
            body: {
              'Operations': [
                {'op': 'remove', 'path': 'displayName'},
                {'op': 'remove', 'path': 'emails[type eq "work"]'},
              ],
            },
          );
          expect(patched.body, isNot(contains('displayName')));
          expect(patched.body['emails'], isEmpty);
        },
      );

      test('PATCH of an attribute the service owns is refused', () async {
        final id = await create('alice');
        expect(
          await call(
            'PATCH',
            '/Users/$id',
            body: {
              'Operations': [
                {'op': 'replace', 'path': 'id', 'value': '99'},
              ],
            },
          ),
          _scimError(400, 'mutability'),
        );
        expect(
          await call(
            'PATCH',
            '/Users/$id',
            body: {
              'Operations': [
                {'op': 'remove'},
              ],
            },
          ),
          _scimError(400, 'noTarget'),
        );
        expect(
          await call(
            'PATCH',
            '/Users/$id',
            body: {
              'Operations': [
                {'op': 'move', 'path': 'title'},
              ],
            },
          ),
          _scimError(400, 'invalidSyntax'),
        );
      });

      test('PUT replaces the user; renaming revokes the old name', () async {
        final id = await create('alice');
        final replaced = await call(
          'PUT',
          '/Users/$id',
          body: {..._user('alice.new'), 'title': 'Lead'},
        );
        expect(replaced.status, 200);
        expect(replaced.body['userName'], 'alice.new');
        expect(replaced.body['id'], id);
        expect(revoked, ['alice']);
      });
    });

    group('groups', () {
      test('a group with members references them, and they list it', () async {
        final alice = await create('alice');
        final created = await call(
          'POST',
          '/Groups',
          body: {
            'schemas': [TomScimSchemas.group],
            'displayName': 'Admins',
            'members': [
              {'value': alice, 'display': 'alice'},
            ],
          },
        );
        expect(created.status, 201);
        final member = (created.body['members']! as List).single as Map;
        expect(member['value'], alice);
        expect(member[r'$ref'], 'http://localhost/scim/v2/Users/$alice');
        final user = await call('GET', '/Users/$alice');
        final group = (user.body['groups']! as List).single as Map;
        expect(group['value'], created.body['id']);
        expect(group['display'], 'Admins');
      });

      test('a member that does not exist is refused', () async {
        expect(
          await call(
            'POST',
            '/Groups',
            body: {
              'displayName': 'Admins',
              'members': [
                {'value': '404'},
              ],
            },
          ),
          _scimError(400, 'invalidValue'),
        );
      });

      test('is found by displayName without its members', () async {
        final alice = await create('alice');
        await call(
          'POST',
          '/Groups',
          body: {
            'displayName': 'Admins',
            'members': [
              {'value': alice},
            ],
          },
        );
        final found = await call(
          'GET',
          '/Groups?filter=${Uri.encodeQueryComponent('displayName eq "admins"')}'
              '&excludedAttributes=members',
        );
        final group = (found.body['Resources']! as List).single as Map;
        expect(group['displayName'], 'Admins');
        expect(group, isNot(contains('members')));
      });

      test('membership changes in every form identity providers send, and '
          'each revokes the member it touches', () async {
        final alice = await create('alice');
        final bob = await create('bob');
        final carol = await create('carol');
        final id = (await call(
          'POST',
          '/Groups',
          body: {'displayName': 'Admins'},
        )).body['id'];

        // Entra ID and Okta: add members with a list value.
        await call(
          'PATCH',
          '/Groups/$id',
          body: {
            'Operations': [
              {
                'op': 'Add',
                'path': 'members',
                'value': [
                  {'value': alice},
                  {'value': bob},
                  {'value': carol},
                ],
              },
            ],
          },
        );
        expect(revoked, unorderedEquals(['alice', 'bob', 'carol']));
        revoked.clear();

        // Okta: remove one member by a value filter.
        await call(
          'PATCH',
          '/Groups/$id',
          body: {
            'Operations': [
              {'op': 'remove', 'path': 'members[value eq "$alice"]'},
            ],
          },
        );
        expect(revoked, ['alice']);
        revoked.clear();

        // Entra ID: remove members with a list value.
        final group = await call(
          'PATCH',
          '/Groups/$id',
          body: {
            'Operations': [
              {
                'op': 'Remove',
                'path': 'members',
                'value': [
                  {'value': bob},
                ],
              },
            ],
          },
        );
        expect(revoked, ['bob']);
        expect(
          [for (final m in group.body['members']! as List) (m as Map)['value']],
          [carol],
        );
      });

      test('a rename revokes every member; a delete does too', () async {
        final alice = await create('alice');
        final id = (await call(
          'POST',
          '/Groups',
          body: {
            'displayName': 'Admins',
            'members': [
              {'value': alice},
            ],
          },
        )).body['id'];
        revoked.clear();
        await call(
          'PATCH',
          '/Groups/$id',
          body: {
            'Operations': [
              {
                'op': 'replace',
                'value': {'displayName': 'Administrators'},
              },
            ],
          },
        );
        expect(revoked, ['alice']);
        revoked.clear();
        expect((await call('DELETE', '/Groups/$id')).status, 204);
        expect(revoked, ['alice']);
        expect(await call('GET', '/Groups/$id'), _scimError(404));
      });
    });

    group('deprovisioning', () {
      test(
        'deactivating a user revokes them, whatever spelling of false',
        () async {
          final id = await create('alice');
          final deactivated = await call(
            'PATCH',
            '/Users/$id',
            body: {
              'Operations': [
                {'op': 'Replace', 'path': 'active', 'value': 'False'},
              ],
            },
          );
          expect(deactivated.body['active'], isFalse);
          expect(revoked, ['alice']);
          // Reactivating takes nothing away.
          await call(
            'PATCH',
            '/Users/$id',
            body: {
              'Operations': [
                {
                  'op': 'replace',
                  'value': {'active': true},
                },
              ],
            },
          );
          expect(revoked, ['alice']);
        },
      );

      test(
        'deleting a user revokes them and takes them out of their groups',
        () async {
          final alice = await create('alice');
          final group = (await call(
            'POST',
            '/Groups',
            body: {
              'displayName': 'Admins',
              'members': [
                {'value': alice},
              ],
            },
          )).body['id'];
          revoked.clear();
          expect((await call('DELETE', '/Users/$alice')).status, 204);
          expect(revoked, ['alice']);
          expect(await call('GET', '/Users/$alice'), _scimError(404));
          expect(
            (await call('GET', '/Groups/$group')).body['members'],
            isEmpty,
          );
        },
      );
    });
  });

  group('deprovisioning revokes access', () {
    late TomMemoryScimStore store;
    late TomScimService service;
    late TomScimIdentityDirectory directory;
    const base = 'https://app.example.test/scim/v2';

    setUp(() async {
      TomAuthorizationCache.instance.dispose();
      store = TomMemoryScimStore();
      // The default revocation: TomCacheInvalidator.revokePrincipal.
      service = TomScimService(store);
      directory = TomScimIdentityDirectory(
        store,
        roleMapping: const TomExternalRoleMapping(
          roles: {
            'Admins': ['tom.admin'],
          },
          defaultRoles: ['employee'],
        ),
      );
    });

    tearDown(() => TomAuthorizationCache.instance.dispose());

    TomAuthenticationData login(String username) => TomAuthenticationData(
      username: username,
      key: null,
      organization: 'acme',
      application: '',
      process: '',
      language: 'en',
      country: 'XX',
      timezone: 'utc',
      client: '',
    );

    /// A session token issued to [username] at [issuedAt] — a minute ago by
    /// default.
    TomClientJwtToken session(String username, {DateTime? issuedAt}) {
      String segment(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final issued =
          issuedAt ??
          DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      return TomClientJwtToken(
        '${segment({'alg': 'HS256'})}.${segment({'username': username, 'iat': issued.millisecondsSinceEpoch ~/ 1000, 'exp': issued.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})}.signature',
        decrypt: false,
      );
    }

    test(
      'a provisioned user signs in with the roles of their groups',
      () async {
        final alice = await service.create(
          TomScimResourceType.user,
          _user('alice'),
          base,
        );
        await service.create(TomScimResourceType.group, {
          'displayName': 'Admins',
          'members': [
            {'value': alice['id']},
          ],
        }, base);
        final info = await directory.authenticatedPrincipalFor(
          'ALICE',
          login('ALICE'),
        );
        expect(info!.principal.username, 'alice');
        expect(info.principal.user.email, 'alice@example.test');
        expect(info.principal.user.firstname, 'Given');
        expect(info.principal.aci.roles, ['employee', 'tom.admin']);
        expect(info.principal.aci.groups, ['Admins']);
        expect(
          await directory.authenticatedPrincipalFor('nobody', login('nobody')),
          isNull,
        );
      },
    );

    test(
      'deactivation refuses the session the user holds and the next login',
      () async {
        final alice = await service.create(
          TomScimResourceType.user,
          _user('alice'),
          base,
        );
        final token = session('alice');
        await TomAuthorizationCache.storePrincipal(
          token,
          (await directory.authenticatedPrincipalFor(
            'alice',
            login('alice'),
          ))!.principal,
        );
        expect(await TomAuthorizationCache.getPrincipal(token), isNotNull);

        await service.patch(TomScimResourceType.user, alice['id']! as String, {
          'Operations': [
            {'op': 'replace', 'path': 'active', 'value': false},
          ],
        }, base);

        await expectLater(
          TomAuthorizationCache.getPrincipal(token),
          throwsA(
            isA<TomAuthorizationCacheException>().having(
              (e) => e.key,
              'key',
              'authorization.cache.revoked_principal',
            ),
          ),
        );
        await expectLater(
          directory.authenticatedPrincipalFor('alice', login('alice')),
          throwsA(
            isA<TomLoginException>().having(
              (e) => e.key,
              'key',
              'login.error.scim.inactive',
            ),
          ),
        );
      },
    );

    test('removal from a group refuses the session carrying its role', () async {
      final alice = await service.create(
        TomScimResourceType.user,
        _user('alice'),
        base,
      );
      final group = await service.create(TomScimResourceType.group, {
        'displayName': 'Admins',
        'members': [
          {'value': alice['id']},
        ],
      }, base);
      // Joining the group revoked alice's earlier sessions too; this one is
      // issued after that, in a later second, as a re-authentication would be.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final token = session('alice', issuedAt: DateTime.now().toUtc());
      expect(TomAuthorizationCache.isRevoked(token), isFalse);

      await service.patch(TomScimResourceType.group, group['id']! as String, {
        'Operations': [
          {'op': 'remove', 'path': 'members[value eq "${alice['id']}"]'},
        ],
      }, base);

      expect(TomAuthorizationCache.isRevoked(token), isTrue);
      final next = await directory.authenticatedPrincipalFor(
        'alice',
        login('alice'),
      );
      expect(next!.principal.aci.roles, ['employee']);
    });
  });
}

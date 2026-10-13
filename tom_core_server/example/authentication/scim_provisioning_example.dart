/// SCIM 2.0 provisioning, from the identity provider's first call to the
/// deprovisioning that ends a session.
///
/// Run with `dart run example/authentication/scim_provisioning_example.dart`.
///
/// The identity provider's requests are made to the SCIM endpoints exactly as
/// it makes them — `Authorization: Bearer <secret>`, `application/scim+json`,
/// the Entra ID shape of a PATCH — through the server's own router. Every step
/// checks its own result, and the run fails when one does not hold.
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../_support/check.dart';
import '../example_reflection.reflection.dart';

const _secret = 'the-secret-the-identity-provider-is-given';

Future<void> main() async {
  initializeReflection();
  TomBean.resetBeanContext();
  TomBean.withType<TomScimServer>(const TomScimServer());

  // The deployment's start-up: a store, the service over it, and the bearer
  // secret the identity provider is configured with. Installing claims
  // `/scim/v2/` so the framework leaves that header to the SCIM endpoints.
  final store = TomMemoryScimStore();
  TomScimProvisioning.install(
    TomScimProvisioning(
      service: TomScimService(store),
      bearerTokens: [_secret],
    ),
  );
  final router = TomEndpointRouting().initializeRouter();

  Future<(int, Map<String, Object?>)> scim(
    String method,
    String path, [
    Object? body,
    String token = _secret,
  ]) async {
    final response = await router.call(
      Request(
        method,
        Uri.parse('https://app.example.com/scim/v2$path'),
        body: body == null ? null : jsonEncode(body),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': TomScimServer.mediaType,
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

  // 1. The identity provider reads what this service supports.
  final (_, config) = await scim('GET', '/ServiceProviderConfig');
  print(
    '1. PATCH supported           : ${(config['patch']! as Map)['supported']}',
  );
  check(
    (config['patch']! as Map)['supported'] == true,
    'the service provider configuration offers PATCH',
  );

  // 2. A caller without the secret is refused.
  final (refused, _) = await scim('GET', '/Users', null, 'a guess');
  print('2. without the secret        : $refused');
  check(refused == 401, 'a caller without the configured secret is refused');

  // 3. The identity provider looks for the user before creating them — the
  //    query every reconciliation starts with — and creates them.
  final (_, before) = await scim(
    'GET',
    '/Users?filter=${Uri.encodeQueryComponent('userName eq "ada@example.com"')}',
  );
  final (created, ada) = await scim('POST', '/Users', {
    'schemas': [TomScimSchemas.user],
    'userName': 'ada@example.com',
    'name': {'givenName': 'Ada', 'familyName': 'Lovelace'},
    'emails': [
      {'value': 'ada@example.com', 'type': 'work', 'primary': true},
    ],
    'active': true,
  });
  print('3. found before / created    : ${before['totalResults']} / $created');
  check(
    before['totalResults'] == 0 && created == 201,
    'an unknown user is found nowhere, then created',
  );

  // 4. A group, and the user added to it with the PATCH Entra ID sends.
  final (_, admins) = await scim('POST', '/Groups', {'displayName': 'Admins'});
  await scim('PATCH', '/Groups/${admins['id']}', {
    'schemas': [TomScimSchemas.patchOp],
    'Operations': [
      {
        'op': 'Add',
        'path': 'members',
        'value': [
          {'value': ada['id']},
        ],
      },
    ],
  });
  final (_, adaNow) = await scim('GET', '/Users/${ada['id']}');
  final groups = [
    for (final group in adaNow['groups']! as List) (group as Map)['display'],
  ];
  print('4. ada is a member of        : $groups');
  check(groups.single == 'Admins', 'the user lists the group they joined');

  // 5. Single sign-on resolves the provisioned account, with the roles its
  //    groups map to. (The OAuth/SAML provider is configured
  //    `provisioning: linkExisting`, so the login links to this account.)
  final directory = TomScimIdentityDirectory(
    store,
    roleMapping: const TomExternalRoleMapping(
      roles: {
        'Admins': ['tom.admin'],
      },
    ),
  );
  TomAuthenticationData login() => TomAuthenticationData(
    username: 'ada@example.com',
    key: null,
    organization: 'acme',
    application: '',
    process: '',
    language: 'en',
    country: 'GB',
    timezone: 'Europe/London',
    client: '',
  );
  final signedIn = await directory.authenticatedPrincipalFor(
    'ada@example.com',
    login(),
  );
  print('5. signed in with roles      : ${signedIn!.principal.aci.roles}');
  check(
    signedIn.principal.aci.roles.contains('tom.admin'),
    'the provisioned account carries the role its group maps to',
  );

  // 6. Joining the group in step 4 changed ada's grants, so it revoked the
  //    sessions she held then: the one issued before it is refused, and she
  //    signs in again for a session carrying the new role.
  String segment(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  TomClientJwtToken sessionIssuedAt(DateTime issued) => TomClientJwtToken(
    '${segment({'alg': 'HS256'})}.'
    '${segment({'username': 'ada@example.com', 'iat': issued.millisecondsSinceEpoch ~/ 1000})}.sig',
    decrypt: false,
  );
  final older = sessionIssuedAt(
    DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
  );
  // A token's `iat` has whole-second precision, and one issued within the
  // second of a revocation counts as revoked; the new session comes a second
  // later, as a real re-authentication would.
  await Future<void>.delayed(const Duration(milliseconds: 1100));
  final session = sessionIssuedAt(DateTime.now().toUtc());
  print(
    '6. older / new session refused : '
    '${TomAuthorizationCache.isRevoked(older)} / '
    '${TomAuthorizationCache.isRevoked(session)}',
  );
  check(
    TomAuthorizationCache.isRevoked(older) &&
        !TomAuthorizationCache.isRevoked(session),
    'a group change revokes the sessions issued before it, not after',
  );

  // 7. The identity provider deactivates ada — the way Entra ID spells false.
  final (_, deactivated) = await scim('PATCH', '/Users/${ada['id']}', {
    'schemas': [TomScimSchemas.patchOp],
    'Operations': [
      {'op': 'Replace', 'path': 'active', 'value': 'False'},
    ],
  });
  print(
    '7. active / session refused  : ${deactivated['active']} / '
    '${TomAuthorizationCache.isRevoked(session)}',
  );
  check(
    deactivated['active'] == false && TomAuthorizationCache.isRevoked(session),
    'deactivation refuses the session ada already holds',
  );

  // 8. And the next login.
  var refusal = '';
  try {
    await directory.authenticatedPrincipalFor('ada@example.com', login());
  } on TomLoginException catch (e) {
    refusal = e.key;
  }
  print('8. next login                : $refusal');
  check(
    refusal == 'login.error.scim.inactive',
    'a deactivated account cannot sign in again',
  );

  TomScimProvisioning.reset();
  // The revocations started the authorization cache's eviction sweep, which
  // would otherwise keep this process alive.
  TomAuthorizationCache.stopEviction();
}
